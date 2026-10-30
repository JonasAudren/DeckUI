local _, ns = ...

-------------------------------------------------------------------
-- A stand-in for the AuraContainer in Mists of Pandaria Classic
-------------------------------------------------------------------
-- Only in DeckUI_Orbs_Mists.toc, loaded before oUF (MISTS_PLAN.md, phase 3).
-- oUF 14's Auras element is built on the engine's AuraContainer widget and
-- CustomAuraContainerTemplate (retail 12.0); Mists has neither. Its element
-- (libs/oUF/elements/auras.lua, "DeckUI: Mists") calls ns.MistsAuraContainer
-- instead of CreateFrame("AuraContainer"), and everything oUF and DeckUI
-- ask of the container and its buttons is answered here - only that:
--  container: the flow layout setters, AddAuraGroup / AddAuraSlot,
--    SetAuraGroupCandidateFilters, SetAuraGroupFilterString,
--    SetUnit / GetUnit, UpdateAllAuras,
--    SetEnabled, SetAuraProcessingPolicy (ignored)
--  button: SetIcon, SetDurationCooldown, SetApplicationCount,
--    SetDurationText, AddDispelTypeTexture, SetCancelAuraButtons,
--    SetTooltipAnchorPoint, SetHideTooltipInCombat
--  candidate filters: maxDuration (drops permanent auras, as retail's
--    does), includeSpellIDs, excludeSpellIDs, isFromPlayerOrPlayerPet
--  weapon enchants: AddItemEnchantment / SetItemEnchantmentLayout (the
--    buff bar, buffs.lua) from GetWeaponEnchantInfo, laid out first
--
-- The data is C_UnitAuras.GetAuraDataByIndex, which Mists has; tooltip and
-- cancel are what Blizzard's own buff buttons there call (SetUnitAura,
-- CancelUnitBuff - the latter only out of combat). The dispel colour comes
-- from oUF's colors.dispel, handed in by the element. Auras are read on
-- UNIT_AURA once per frame at most.
-------------------------------------------------------------------
ns.MistsFlowAxis = { Horizontal = "H", Vertical = "V" }

-- Temporary weapon enchants (buffs.lua, WeaponEnchants): slot numbers of our
-- own, Mists has no AuraContainerItemEnchantmentSlot. The number is the item
-- index GetWeaponEnchantInfo counts (1 main hand, 2 off hand, 3 ranged - no
-- such slot in Mists, read as nil) and 15 + it the inventory slot.
ns.MistsEnchantSlots = { MainHand = 1, OffHand = 2, Ranged = 3 }
local ENCHANT_RETURNS = 4   -- per item: hasEnchant, expiration (ms), charges, enchantID

local DEBUFF_BORDER = "Interface\\Buttons\\UI-Debuff-Overlays"   -- oUF 1.x's border
local NO_DISPEL = CreateColor(0.8, 0, 0)

-------------------------------------------------------------------
-- Buttons
-------------------------------------------------------------------
local buttonMixin = {}

function buttonMixin:SetIcon(texture) self.mIcon = texture end
function buttonMixin:SetDurationCooldown(cooldown) self.mCooldown = cooldown end
function buttonMixin:SetApplicationCount(fontString) self.mCount = fontString end
function buttonMixin:SetDurationText(fontString) self.mTime = fontString end
function buttonMixin:SetHideTooltipInCombat(hide) self.mTipHideInCombat = hide end

function buttonMixin:SetTooltipAnchorPoint(anchor, x, y)
    self.mTipAnchor, self.mTipX, self.mTipY = anchor, x, y
end

function buttonMixin:AddDispelTypeTexture(texture, opts)
    self.mDispel = self.mDispel or {}
    table.insert(self.mDispel, { texture = texture, opts = opts or {} })
    -- the "Border" look (style nil here: Mists has no such enum): the old
    -- debuff frame round the icon. The stealable border keeps its own art;
    -- oUF marks it with showWithoutDispelType (its stealableFilter is an
    -- enum Mists lacks, so nil)
    if not (opts and opts.showWithoutDispelType) then
        texture:SetTexture(DEBUFF_BORDER)
        texture:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
    end
    texture:Hide()
end

function buttonMixin:SetCancelAuraButtons(buttons)
    self:RegisterForClicks(buttons)
    self.mCancel = true
end

local function OnEnter(self)
    if self.mTipHideInCombat and InCombatLockdown() then return end
    if not (self.mIndex or self.mInvSlot) then return end
    GameTooltip:SetOwner(self, self.mTipAnchor or "ANCHOR_BOTTOMLEFT", self.mTipX or 0, self.mTipY or 0)
    if self.mInvSlot then
        GameTooltip:SetInventoryItem("player", self.mInvSlot)   -- a weapon enchant: the weapon's tooltip
    else
        GameTooltip:SetUnitAura(self.mUnit, self.mIndex, self.mFilter)
    end
end

local function OnLeave()
    GameTooltip:Hide()
end

-- A weapon enchant (mIndex nil) is not cancelled: CancelItemTempEnchantment
-- is a protected call, Blizzard's own buff frame alone may make it.
local function OnClick(self)
    if self.mCancel and self.mIndex and not InCombatLockdown() and self.mFilter:find("HELPFUL") then
        CancelUnitBuff(self.mUnit, self.mIndex, self.mFilter)
    end
end

-- remaining time, short: 45, 12m, 2h
local function ShortTime(seconds)
    if seconds >= 3600 then return ("%dh"):format(math.ceil(seconds / 3600)) end
    if seconds >= 60 then return ("%dm"):format(math.ceil(seconds / 60)) end
    return ("%d"):format(math.ceil(seconds))
end

local function UpdateTime(self, now)
    local expires = self.mExpires
    if not (self.mTime and expires and expires > 0) then return end
    local left = expires - now
    self.mTime:SetText(left > 0 and ShortTime(left) or "")
end

local function Paint(self, aura, unit, index, filter)
    self.mUnit, self.mIndex, self.mFilter, self.mInvSlot = unit, index, filter, nil
    if self.mIcon then self.mIcon:SetTexture(aura.icon) end

    local count = aura.applications
    if self.mCount then
        self.mCount:SetText((count and count > 1) and count or "")
    end

    -- secret values (none were seen in Mists, but the API is there): the
    -- engine takes a duration object; we compute nothing with them
    local secret = issecretvalue and (issecretvalue(aura.duration) or issecretvalue(aura.expirationTime))
    self.mExpires = nil
    if self.mCooldown then
        if secret then
            local d = C_UnitAuras.GetAuraDuration and C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID)
            if d then self.mCooldown:SetCooldownFromDurationObject(d) else self.mCooldown:Clear() end
        elseif aura.duration and aura.duration > 0 then
            self.mCooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration, aura.timeMod)
        else
            self.mCooldown:Clear()
        end
    end
    if self.mTime then
        if not secret and aura.duration and aura.duration > 0 then
            self.mExpires = aura.expirationTime
            UpdateTime(self, GetTime())
        else
            self.mTime:SetText("")
        end
    end

    for _, d in ipairs(self.mDispel or {}) do
        local o, show, color = d.opts, false, nil
        if o.showWithoutDispelType then
            -- the stealable border (see AddDispelTypeTexture)
            show = aura.isHelpful and aura.isStealable and true or false
        elseif aura.isHarmful and o.showWhenHarmful or aura.isHelpful and o.showWhenHelpful then
            local name = aura.dispelName
            if name or aura.isHarmful then
                show = true
                color = (name and o.customDispelColorMap and o.customDispelColorMap[name]) or NO_DISPEL
            end
        end
        d.texture:SetShown(show)
        if show and color then d.texture:SetVertexColor(color:GetRGB()) end
    end
    self:Show()
end

-- a temporary weapon enchant as a status: the weapon's icon, the charges
-- as count, the time left below; no swipe - the game tells only what is
-- left, not how long it was
local function PaintEnchant(self, invSlot, expiration, charges)
    self.mUnit, self.mIndex, self.mFilter, self.mInvSlot = nil, nil, nil, invSlot
    if self.mIcon then self.mIcon:SetTexture(GetInventoryItemTexture("player", invSlot)) end
    if self.mCount then self.mCount:SetText((charges and charges > 1) and charges or "") end
    if self.mCooldown then self.mCooldown:Clear() end
    self.mExpires = (expiration and expiration > 0) and (GetTime() + expiration / 1000) or nil
    if self.mTime then
        if self.mExpires then UpdateTime(self, GetTime()) else self.mTime:SetText("") end
    end
    for _, d in ipairs(self.mDispel or {}) do d.texture:Hide() end
    self:Show()
end

-------------------------------------------------------------------
-- The container
-------------------------------------------------------------------
local containerMixin = {}

function containerMixin:SetFlowLayoutAnchorPoint(point) self.mPoint = point end
function containerMixin:SetFlowLayoutAxis(axis) self.mAxis = axis end
function containerMixin:SetFlowLayoutMaximumLineSize(size) self.mLineSize = size end
function containerMixin:SetFlowLayoutGrowthDirection(x, y) self.mGrowX, self.mGrowY = x, y end
function containerMixin:SetFlowLayoutPadding(l, r, t, b) self.mPad = { l, r, t, b } end
function containerMixin:SetAuraProcessingPolicy() end

function containerMixin:AddAuraGroup(key, filter, options)
    table.insert(self.mGroups, { key = key, filter = filter, options = options or {}, buttons = {} })
    self:MarkDirty()
end

-- a single aura with its own options: a group of one
function containerMixin:AddAuraSlot(key, filter, options)
    options = options or {}
    options.maxFrameCount = 1
    self:AddAuraGroup(key, filter, options)
end

-- Temporary weapon enchants, one pseudo-group laid out before the aura
-- groups (retail's default placement). Only for "player"; the enchant
-- events are Blizzard's own buff frame's. hidePermanent is moot here:
-- GetWeaponEnchantInfo knows temporary enchants only.
function containerMixin:AddItemEnchantment(slot, options)
    options = options or {}
    local g = self.mEnchants
    if not g then
        g = { options = { initializeFrame = options.initializeFrame, layout = {} }, buttons = {}, slots = {} }
        self.mEnchants = g
        for _, event in ipairs({ "WEAPON_ENCHANT_CHANGED", "WEAPON_SLOT_CHANGED" }) do
            pcall(self.RegisterEvent, self, event)
        end
        pcall(self.RegisterUnitEvent, self, "UNIT_INVENTORY_CHANGED", "player")
    end
    g.slots[#g.slots + 1] = slot
    self:MarkDirty()
end

function containerMixin:SetItemEnchantmentLayout(layout)
    if self.mEnchants then self.mEnchants.options.layout = layout or {} end
    self:MarkDirty()
end

function containerMixin:SetAuraGroupCandidateFilters(key, filters)
    for _, g in ipairs(self.mGroups) do
        if g.key == key then g.options.candidateFilters = filters end
    end
    self:MarkDirty()
end

-- the Orbs page's "only my debuffs" switches a group's filter live
function containerMixin:SetAuraGroupFilterString(key, filter)
    for _, g in ipairs(self.mGroups) do
        if g.key == key then g.filter = filter end
    end
    self:MarkDirty()
end

function containerMixin:GetUnit() return self.mUnit end

function containerMixin:SetUnit(unit)
    self.mUnit = unit
    self:UnregisterEvent("UNIT_AURA")
    if unit and self.mEnabled then self:RegisterUnitEvent("UNIT_AURA", unit) end
    self:UpdateAllAuras()
end

function containerMixin:SetEnabled(on)
    self.mEnabled = on and true or false
    self:SetUnit(self.mUnit)
end

function containerMixin:MarkDirty()
    self.mDirty = true
    self:SetScript("OnUpdate", self.OnUpdate)
end

local function Passes(aura, filters)
    if not filters then return true end
    local id = aura.spellId
    if filters.includeSpellIDs and not filters.includeSpellIDs[id] then return false end
    if filters.excludeSpellIDs and filters.excludeSpellIDs[id] then return false end
    if filters.maxDuration then
        local d = aura.duration
        if issecretvalue and issecretvalue(d) then return true end
        if not d or d <= 0 or d > filters.maxDuration then return false end
    end
    if filters.isFromPlayerOrPlayerPet and not aura.isFromPlayerOrPlayerPet then return false end
    return true
end

-- what retail's ExpirationOnly does: soonest gone first, permanent last
local function ByExpiration(a, b)
    local ea, eb = a.aura.expirationTime or 0, b.aura.expirationTime or 0
    if issecretvalue and (issecretvalue(ea) or issecretvalue(eb)) then return a.index < b.index end
    if (ea == 0) ~= (eb == 0) then return eb == 0 end
    if ea ~= eb then return ea < eb end
    return a.index < b.index
end

local function Collect(unit, filter, filters, limit)
    local list = {}
    for i = 1, 255 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
        if not aura then break end
        if Passes(aura, filters) then list[#list + 1] = { aura = aura, index = i } end
    end
    table.sort(list, ByExpiration)
    for i = #list, (limit or #list) + 1, -1 do list[i] = nil end
    return list
end

function containerMixin:Button(group, i)
    local b = group.buttons[i]
    if not b then
        b = Mixin(CreateFrame("Button", nil, self), buttonMixin)
        b:SetScript("OnEnter", OnEnter)
        b:SetScript("OnLeave", OnLeave)
        b:SetScript("OnClick", OnClick)
        b:RegisterForClicks()   -- no clicks unless a cancel button is set
        if group.options.initializeFrame then group.options.initializeFrame(b) end
        group.buttons[i] = b
        table.insert(self.mAllButtons, b)
    end
    return b
end

-- the flow layout: along the axis until the line is full, then the next
-- line in the other growth direction; groups follow on with groupSpacing
function containerMixin:Layout(shown)
    local point = self.mPoint or "TOPLEFT"
    local gx, gy = self.mGrowX or 1, self.mGrowY or 1
    local vertical = self.mAxis == ns.MistsFlowAxis.Vertical
    local limit = self.mLineSize or (vertical and self:GetHeight() or self:GetWidth())
    local pad = self.mPad or { 0, 0, 0, 0 }
    local padX = gx > 0 and pad[1] or pad[2]
    local padY = gy < 0 and pad[3] or pad[4]
    local along, across, lineDepth = 0, 0, 0

    for _, entry in ipairs(shown) do
        local layout = entry.group.options.layout or {}
        local es, ls = layout.elementSpacing or 0, layout.lineSpacing or 0
        if entry.newGroup and along > 0 then
            if layout.forceNewLine then
                along, across, lineDepth = 0, across + lineDepth + (layout.groupLineSpacing or ls), 0
            else
                along = along + (layout.groupSpacing or es) - es
            end
        end
        local b = entry.button
        local w, h = b:GetWidth(), b:GetHeight()
        local size, depth = vertical and h or w, vertical and w or h
        if along > 0 and limit and limit > 0 and along + size > limit + 0.5 then
            along, across, lineDepth = 0, across + lineDepth + ls, 0
        end
        local x, y = along, across
        if vertical then x, y = across, along end
        b:ClearAllPoints()
        b:SetPoint(point, self, point, gx * (x + padX), gy * (y + padY))
        along = along + size + es
        lineDepth = math.max(lineDepth, depth)
    end
end

function containerMixin:UpdateAllAuras()
    self.mDirty = false
    local unit = self.mUnit
    local shown = {}
    local g = self.mEnchants
    if g then
        local n = 0
        if self.mEnabled and unit == "player" then
            local info = { GetWeaponEnchantInfo() }
            for _, slot in ipairs(g.slots) do
                local at = ENCHANT_RETURNS * (slot - 1)
                if info[at + 1] then
                    n = n + 1
                    local b = self:Button(g, n)
                    PaintEnchant(b, 15 + slot, info[at + 2], info[at + 3])
                    shown[#shown + 1] = { group = g, button = b, newGroup = n == 1 }
                end
            end
        end
        for i = n + 1, #g.buttons do
            g.buttons[i]:Hide()
            g.buttons[i].mInvSlot = nil
        end
    end
    for _, group in ipairs(self.mGroups) do
        local list = (self.mEnabled and unit and UnitExists(unit))
            and Collect(unit, group.filter, group.options.candidateFilters, group.options.maxFrameCount) or {}
        for i, entry in ipairs(list) do
            local b = self:Button(group, i)
            Paint(b, entry.aura, unit, entry.index, group.filter)
            shown[#shown + 1] = { group = group, button = b, newGroup = i == 1 }
        end
        for i = #list + 1, #group.buttons do
            group.buttons[i]:Hide()
            group.buttons[i].mIndex = nil
        end
    end
    self:Layout(shown)
    self.mTicking = false
    for _, entry in ipairs(shown) do
        if entry.button.mExpires then self.mTicking = true break end
    end
    if not self.mTicking then self:SetScript("OnUpdate", nil) else self:SetScript("OnUpdate", self.OnUpdate) end
end

-- once per frame for a pending UNIT_AURA, five times a second for the times
function containerMixin:OnUpdate(elapsed)
    if self.mDirty then
        self:UpdateAllAuras()
        return
    end
    self.mElapsed = (self.mElapsed or 0) + elapsed
    if self.mElapsed < 0.2 then return end
    self.mElapsed = 0
    local now = GetTime()
    for _, b in ipairs(self.mAllButtons) do
        if b:IsShown() then UpdateTime(b, now) end
    end
end

local function OnEvent(self)
    self:MarkDirty()
end

function ns.MistsAuraContainer(parent)
    local f = Mixin(CreateFrame("Frame", nil, parent), containerMixin)
    f.mGroups, f.mAllButtons, f.mEnabled = {}, {}, true
    f:SetScript("OnEvent", OnEvent)
    return f
end

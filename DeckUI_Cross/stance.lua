local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- The stance row: forms, stances, auras, stealth - docked at the crosses
-------------------------------------------------------------------
-- Owner's wish (2026-10-02): Blizzard's stance bar as round buttons in the
-- crosses' look, sitting between the two small middle crosses and scaling
-- and moving with the hotbar (DeckCrossDB.stanceBar, off by default).
-- Blizzard's own bar is hidden while it is on, the same way as the bars
-- the crosses mirror.
--
-- The buttons are SecureActionButtons casting the form's spell (type
-- "spell", spell = 4th return of GetShapeshiftFormInfo) - casting a form
-- from untainted secure code, in combat too. What they show (icon, active
-- form, usable, cooldown) is read on the stance events and drawn only.
-- Attributes, the number of buttons and the row's width change only out
-- of combat; the set of forms changes only with talents, out of combat too.
--
-- Keys:
--  - Steam Deck: LB becomes Alt (as with LB zoom, input.lua). LB + X / Y /
--    B / A pick stance 1-4 (left to right, the way the face buttons sit),
--    LB + D-pad right / left the next / previous one. Next and previous
--    depend on the form you are in, so they are re-bound by a secure state
--    driver on [form:n] - in combat too, where insecure code cannot bind.
--  - Both devices: the player's own keys for Blizzard's stance buttons
--    (SHAPESHIFTBUTTON1-10) are pointed at ours, since Blizzard's bar is
--    hidden. Read at login and when the option changes - a key bound
--    later needs a /reload.
-------------------------------------------------------------------
local MAX = NUM_STANCE_SLOTS or 10
local SIZE, GAP = ns.SIZE_MID, 4
local GOLD, GREY = { 0.9, 0.75, 0.2 }, { 0.25, 0.25, 0.25 }

-- LB + these face buttons pick stance 1-4, left to right on the pad
local FACE = { { "PAD3", "face_x" }, { "PAD4", "face_y" }, { "PAD2", "face_b" }, { "PAD1", "face_a" } }

local function Plain(v)
    return not issecretvalue or not issecretvalue(v)
end

local row = CreateFrame("Frame", "DeckCrossStance", ns.anchor)
row:SetSize(SIZE, SIZE)
row:SetPoint("CENTER", ns.anchor, "CENTER", 0, ns.MID_OFFSET_Y)
row:Hide()

-------------------------------------------------------------------
-- Buttons
-------------------------------------------------------------------
local buttons = {}

for i = 1, MAX do
    local b = CreateFrame("CheckButton", "DeckStanceButton" .. i, row, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    -- down and up, like LibActionButton: Blizzard's secure handler decides
    -- by ActionButtonUseKeyDown which of the two a key press acts on
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetAttribute("type", "spell")
    b.index = i
    b.icon = b:CreateTexture(nil, "BACKGROUND")
    b.icon:SetAllPoints()
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints()
    ns.MakeRound(b, SIZE)

    if i <= #FACE then
        local glyph = b:CreateTexture(nil, "OVERLAY")
        glyph:SetSize(12, 12)
        glyph:SetPoint("CENTER", b, "BOTTOM", 0, 1)
        glyph:SetTexture(ns.TEX_PATH .. FACE[i][2])
        glyph:Hide()
        b.glyph = glyph
    end

    -- a key press shows no pushed state of its own; hold our glow a moment
    b:HookScript("PreClick", function(self)
        self.DeckPushed:Show()
        C_Timer.After(0.18, function() self.DeckPushed:Hide() end)
    end)
    -- a CheckButton ticks itself on click; the form says what is true
    b:HookScript("PostClick", function(self)
        self:SetChecked(self.index == GetShapeshiftForm())
    end)
    b:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetShapeshift(self.index)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", GameTooltip_Hide)
    buttons[i] = b
end

-------------------------------------------------------------------
-- Deck keys: re-bound by form, in secure code
-------------------------------------------------------------------
local keys = CreateFrame("Frame", "DeckCrossStanceKeys", UIParent, "SecureHandlerStateTemplate")
for i, face in ipairs(FACE) do keys:SetAttribute("key" .. i, "ALT-" .. face[1]) end
keys:SetAttribute("_onstate-form", [[
    self:ClearBindings()
    if not self:GetAttribute("bind") then return end
    local count = self:GetAttribute("count") or 0
    if count == 0 then return end
    local n = tonumber(newstate) or 0
    if n > count then n = 0 end
    for i = 1, count < 4 and count or 4 do
        self:SetBindingClick(true, self:GetAttribute("key" .. i), "DeckStanceButton" .. i)
    end
    local nextForm = n % count + 1
    local prevForm = n <= 1 and count or n - 1
    self:SetBindingClick(true, "ALT-PADDRIGHT", "DeckStanceButton" .. nextForm)
    self:SetBindingClick(true, "ALT-PADDLEFT", "DeckStanceButton" .. prevForm)
]])
do
    local cond = {}
    for i = 1, MAX do cond[#cond + 1] = ("[form:%d]%d"):format(i, i) end
    RegisterStateDriver(keys, "form", table.concat(cond, ";") .. ";0")
end

-- the player's own keys for Blizzard's stance buttons, pointed at ours
local pcKeys = CreateFrame("Frame")

local function BindKeys()
    local on = DeckCrossDB.stanceBar
    ClearOverrideBindings(pcKeys)
    if on then
        for i = 1, MAX do
            for _, key in ipairs({ GetBindingKey("SHAPESHIFTBUTTON" .. i) }) do
                SetOverrideBindingClick(pcKeys, false, key, "DeckStanceButton" .. i)
            end
        end
    end
    keys:SetAttribute("bind", (on and D.IsDeck()) and true or nil)
    -- re-runs the snippet above with the bindings the attributes now ask for
    keys:SetAttribute("state-form", tostring(GetShapeshiftForm() or 0))
end

-------------------------------------------------------------------
-- Layout (out of combat) and looks (any time)
-------------------------------------------------------------------
local pending = false
local count = 0
local blizzardHidden = false   -- shown again only if it was us who hid it

local function Paint()
    local form = GetShapeshiftForm()
    local deckKeys = DeckCrossDB.stanceBar and D.IsDeck()
    for i = 1, count do
        local b = buttons[i]
        local icon, _, castable = GetShapeshiftFormInfo(i)
        b.icon:SetTexture(icon)
        if Plain(castable) then b.icon:SetDesaturated(not castable) end
        local on = (i == form)
        b:SetChecked(on)
        local c = on and GOLD or GREY
        b.DeckRing:SetVertexColor(c[1], c[2], c[3], 1)
        -- possibly secret: handed to the cooldown as they are, never compared
        local start, duration = GetShapeshiftFormCooldown(i)
        if start and duration then b.cooldown:SetCooldown(start, duration) end
        if b.glyph then b.glyph:SetShown(deckKeys) end
    end
end

local function Layout()
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local on = DeckCrossDB.stanceBar
    count = on and math.min(GetNumShapeshiftForms() or 0, MAX) or 0
    for i, b in ipairs(buttons) do
        if i <= count then
            local _, _, _, spellID = GetShapeshiftFormInfo(i)
            b:SetAttribute("spell", spellID)
            b:ClearAllPoints()
            b:SetPoint("LEFT", row, "LEFT", (i - 1) * (SIZE + GAP), 0)
            b:Show()
        else
            b:SetAttribute("spell", nil)
            b:Hide()
        end
    end
    row:SetWidth(math.max(1, count * (SIZE + GAP) - GAP))
    -- in a vehicle or a pet battle the crosses show other things; so does the row
    RegisterStateDriver(row, "visibility",
        count > 0 and "[petbattle][vehicleui][overridebar][possessbar] hide; show" or "hide")
    keys:SetAttribute("count", count)
    if on ~= blizzardHidden then
        ns.SetBlizzardBarHidden("StanceButton1", on)
        blizzardHidden = on
    end
    BindKeys()
    Paint()
end

-- Deck: bright while LB (Alt) is held, dim while a trigger arms the crosses
local function RowAlpha(base)
    if D.IsDeck() then
        if IsAltKeyDown() then return 1 end
        if IsShiftKeyDown() or IsControlKeyDown() then return 0.35 end
    end
    return base
end

local setGroupAlpha = ns.SetGroupAlpha
function ns.SetGroupAlpha(left, right, mid)
    setGroupAlpha(left, right, mid)
    row:SetAlpha(RowAlpha(left))
end

-------------------------------------------------------------------
-- Settings, events, debug
-------------------------------------------------------------------
function ns.SetStanceBar(on)
    DeckCrossDB.stanceBar = on
    if InCombatLockdown() then print("DeckUI Cross: takes effect after combat.") end
    if D.IsDeck() then ns.ApplyLBModifier() end
    Layout()
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if not DeckCrossDB then return end
    if event == "UPDATE_SHAPESHIFT_FORMS" or event == "PLAYER_ENTERING_WORLD"
        or (event == "PLAYER_REGEN_ENABLED" and pending) then
        Layout()
    else
        Paint()
    end
end)

function ns.InitStance()
    for _, e in ipairs({ "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_USABLE",
                         "UPDATE_SHAPESHIFT_COOLDOWN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
        ev:RegisterEvent(e)
    end
    Layout()
end

-- /dc bars: the row, its keys and where Blizzard's stance bar hangs
function ns.PrintStance()
    print(("  stance row: option=%s forms=%d shown=%d form=%d deck keys=%s pending=%s"):format(
        tostring(DeckCrossDB.stanceBar), GetNumShapeshiftForms() or 0, count, GetShapeshiftForm() or 0,
        tostring(keys:GetAttribute("bind") or false), tostring(pending)))
    local b = _G["StanceButton1"]
    if b then
        local chain, frame = {}, b:GetParent()
        while frame and #chain < 10 do
            chain[#chain + 1] = frame:GetName() or "(unnamed)"
            if frame == UIParent then break end
            frame = frame:GetParent()
        end
        print("  StanceButton1 parents=" .. table.concat(chain, " > "))
    else
        print("  StanceButton1 not found")
    end
end

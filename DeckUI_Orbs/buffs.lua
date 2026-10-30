local ADDON, ns = ...
local D = DeckUI
local oUF = ns.oUF

-------------------------------------------------------------------
-- The buff bar: your status icons in Final Fantasy's style
-------------------------------------------------------------------
-- Owner's wish (2026-10-08): Blizzard's buff frame grew far too long in
-- combat and, on the Deck, ran into the minimap. In its place (it is
-- parked while this is on) a bar of our own, like FFXIV's status icons:
-- square icons with the time left below them, buffs in one block,
-- debuffs in a row below. Movable ("Buffs"), sizes per device,
-- DeckOrbsDB.buffBar, off by default, needs a reload.
--
-- What shows when (owner's choice):
--  - out of combat every buff, flasks and food included;
--  - in combat only buffs of a minute or less - procs and cooldowns -
--    by switching the group's candidate filter (maxDuration, which also
--    drops permanent auras) on PLAYER_REGEN_DISABLED / ENABLED;
--  - debuffs always, all of them, with their dispel colour.
-- The icons are the engine's own aura buttons (oUF's CreateAuras), so
-- durations and counts stay secret-safe; a right click cancels a buff.
-- With the bar on, the player frame (orb or FF bar) drops its own auras.
-------------------------------------------------------------------
-- FFXIV's status bar (owner's reference screenshot, 2026-10-08): one row,
-- mirrored at the owner's wish - buffs from the right edge growing left
-- (the bar sits beside the minimap), debuffs from the left edge; narrow icons standing a little
-- upright with a thin dark edge; the time small below each (the engine
-- sets its colour, so it stays white); above a debuff a short coloured strip when it can be dispelled -
-- FFXIV marks what Esuna removes the same way.
local GAP, TEXT, STRIP = 2, 12, 5   -- between icons; the time below; the strip above
local BUFF_ROWS, DEBUFFS = 2, 8
local IN_COMBAT = { maxDuration = 60 }
local OUT_OF_COMBAT = {}

local bar        -- the oUF frame
local buffs, buffKey

-- FFXIV's status icons are shaped (owner's close-up, 2026-10-08): a buff's
-- top edge rises to a point like a roof, a debuff's bottom edge falls to
-- one. Our own masks in textures/ (status_up / status_down, 64x64 TGA)
-- cut the icon, the dark edge behind it and the cooldown swipe alike.
local TEXTURES = "Interface\\AddOns\\DeckUI_Orbs\\textures\\"

-- The shape alone, for the buff bar and the target's status icons in the
-- Final Fantasy styles (ffstyle.lua, owner's wish 2026-10-26): down = a
-- debuff, its bottom falling to a point; otherwise a buff's roof.
function ns.ShapeStatusIcon(button, down)
    local shape = TEXTURES .. (down and "status_down" or "status_up")
    if button.Icon then
        button.Icon:SetTexCoord(0.12, 0.88, 0.06, 0.94)
        local mask = button:CreateMaskTexture()
        mask:SetTexture(shape, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(button.Icon)
        button.Icon:AddMaskTexture(mask)
    end
    -- the thin dark edge: the same shape, black, a pixel larger all round
    local edge = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetTexture(shape)
    edge:SetVertexColor(0, 0, 0, 0.95)
    if button.Cooldown then
        button.Cooldown:SetDrawEdge(false)
        button.Cooldown:SetSwipeTexture(shape)
        button.Cooldown:SetSwipeColor(0, 0, 0, 0.45)
    end
end

-- the dispel colour as a strip above the icon instead of a frame round it
function ns.DispelStrip(button)
    if not button.Border then return end
    button.Border:ClearAllPoints()
    button.Border:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 2)
    button.Border:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, 2)
    button.Border:SetHeight(3)
    -- Mists' stand-in (auras_mists.lua) draws the old debuff frame;
    -- the strip wants plain colour
    if D.IsMists then
        button.Border:SetTexture("Interface\\Buttons\\WHITE8x8")
        button.Border:SetTexCoord(0, 1, 0, 1)
    end
end

local function Style(element, button)
    ns.ShapeStatusIcon(button, element.shape == "down")
    if button.Cooldown then
        -- the time is written below the icon; no numbers on top of it
        button.Cooldown:SetHideCountdownNumbers(true)
    end
    if button.Time then
        button.Time:SetFont(ns.FONT, 9, "OUTLINE")
        button.Time:ClearAllPoints()
        button.Time:SetPoint("TOP", button, "BOTTOM", 0, -1)
    end
    if button.Count then
        button.Count:SetFont(ns.FONT, 10, "OUTLINE")
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", 2, -1)
    end
    ns.DispelStrip(button)
end

-- anchor "TOPLEFT" grows right (debuffs), "TOPRIGHT" grows left (buffs)
local function Block(self, w, h, count, rows, anchor)
    local width = count * (w + GAP)
    local auras = self:CreateAuras({
        layout        = ns.FLOW.Horizontal,
        layoutLimit   = width,
        initialAnchor = anchor,
        growthX       = anchor == "TOPLEFT" and "RIGHT" or "LEFT",
        growthY       = "DOWN",
    })
    auras:SetSize(width, rows * (h + TEXT))
    auras:SetPoint(anchor, self, anchor, 0, -STRIP)
    auras.width, auras.height = w, h
    auras.elementSpacing = GAP
    auras.lineSpacing = TEXT
    auras.groupSpacing = GAP   -- between the weapon enchants and the buffs
    auras.showCount = true
    auras.showDuration = true
    auras.PostCreateButton = Style
    return auras
end

-- Temporary weapon enchants - a shaman's imbues, oils, sharpening stones -
-- are no auras: Blizzard's buff frame reads them off the weapon slots, so
-- with it parked they were gone (2026-10-30). The container takes them as
-- item enchantment slots: in retail Blizzard_AuraContainer's own
-- AddItemEnchantment (C_PaperDollInfo.GetTemporaryEnchantmentInfo behind
-- it, the button fed like an aura's), in Mists the stand-in's reading of
-- GetWeaponEnchantInfo (auras_mists.lua). Laid out before the buffs, so
-- they sit at the right edge, shaped like a buff; a permanent enchant is
-- no status (hidePermanent). The buttons come from the same initializer
-- oUF gave the buff group, which AddGroup leaves in its options table.
local function WeaponEnchants(auras, initializeFrame)
    local slots = AuraContainerItemEnchantmentSlot or ns.MistsEnchantSlots
    if not (auras.AddItemEnchantment and slots and initializeFrame) then return end
    for _, slot in ipairs({ slots.MainHand, slots.OffHand, slots.Ranged }) do
        if slot then
            auras:AddItemEnchantment(slot, { initializeFrame = initializeFrame, hidePermanent = true })
        end
    end
    auras:SetItemEnchantmentLayout({ elementSpacing = GAP, lineSpacing = TEXT, groupSpacing = GAP })
end

local function BuildBar(self, unit)
    local dev = ns.DeviceDB()
    local h, perRow = dev.buffSize or 28, dev.buffPerRow or 12
    local w = math.floor(h * 0.86 + 0.5)
    self:SetSize((perRow + DEBUFFS) * (w + GAP) + 3 * w, STRIP + BUFF_ROWS * (h + TEXT))

    if not self.CreateAuras then return end
    buffs = Block(self, w, h, perRow, BUFF_ROWS, "TOPRIGHT")
    buffs.cancelButton = "RightButtonUp"
    buffs.shape = "up"
    local buffOptions = {
        maxFrameCount = BUFF_ROWS * perRow,
        candidateFilters = InCombatLockdown() and IN_COMBAT or OUT_OF_COMBAT,
    }
    buffKey = buffs:AddGroup("HELPFUL", buffOptions)

    local debuffs = Block(self, w, h, DEBUFFS, 1, "TOPLEFT")
    debuffs.shape = "down"
    debuffs:AddGroup("HARMFUL", { maxFrameCount = DEBUFFS, showDebuffBorder = true })

    WeaponEnchants(buffs, buffOptions.initializeFrame)
end

oUF:RegisterStyle("DeckOrbsBuffBar", BuildBar)

-- long buffs out of combat, short ones in it
local combat = CreateFrame("Frame")
combat:RegisterEvent("PLAYER_REGEN_DISABLED")
combat:RegisterEvent("PLAYER_REGEN_ENABLED")
combat:SetScript("OnEvent", function(_, event)
    if not (buffs and buffKey) then return end
    buffs:SetAuraGroupCandidateFilters(buffKey, event == "PLAYER_REGEN_DISABLED" and IN_COMBAT or OUT_OF_COMBAT)
end)

-------------------------------------------------------------------
-- Blizzard's buff and debuff frames, parked while the bar is on
-------------------------------------------------------------------
-- Both are Edit Mode systems; Edit Mode re-applies their points and scale,
-- never their parent, so a hidden parent keeps them out of sight (the
-- minimap cluster is parked the same way, DeckUI_Map). Nothing written
-- onto them but the parent.
local hidden = CreateFrame("Frame")
hidden:Hide()

local function ParkBlizzard()
    for _, name in ipairs({ "BuffFrame", "DebuffFrame" }) do
        local frame = _G[name]
        if frame and frame:GetParent() ~= hidden then frame:SetParent(hidden) end
    end
end

oUF:Factory(function(self)
    if not DeckOrbsDB.buffBar then return end
    self:SetActiveStyle("DeckOrbsBuffBar")
    bar = self:Spawn("player", "DeckOrbsBuffBar")
    bar.defaultPoint = { "TOPRIGHT", UIParent, "TOPRIGHT", -250, -20 }
    bar:SetPoint(unpack(bar.defaultPoint))
    D.MakeMovable(bar, "Buffs", DeckOrbsDB)
    ns.OutOfCombat("parkBuffs", function()
        ParkBlizzard()
        -- the bar's own area is not a button: clicks belong to the icons
        bar:EnableMouse(false)
    end)
end)

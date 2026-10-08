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

local function Style(element, button)
    if button.Icon then button.Icon:SetTexCoord(0.15, 0.85, 0.06, 0.94) end
    -- the thin dark edge
    local edge = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0, 0, 0, 0.9)
    if button.Cooldown then
        -- the time is written below the icon; no numbers on top of it
        button.Cooldown:SetHideCountdownNumbers(true)
        button.Cooldown:SetDrawEdge(false)
        button.Cooldown:SetSwipeColor(0, 0, 0, 0.45)
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
    -- the dispel colour as a strip above the icon instead of a frame round it
    if button.Border then
        button.Border:ClearAllPoints()
        button.Border:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 2)
        button.Border:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, 2)
        button.Border:SetHeight(3)
    end
end

-- anchor "TOPLEFT" grows right (debuffs), "TOPRIGHT" grows left (buffs)
local function Block(self, w, h, count, rows, anchor)
    local width = count * (w + GAP)
    local auras = self:CreateAuras({
        layout        = AnchorUtil.FlowLayoutAxis.Horizontal,
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
    auras.showCount = true
    auras.showDuration = true
    auras.PostCreateButton = Style
    return auras
end

local function BuildBar(self, unit)
    local dev = ns.DeviceDB()
    local h, perRow = dev.buffSize or 28, dev.buffPerRow or 12
    local w = math.floor(h * 0.86 + 0.5)
    self:SetSize((perRow + DEBUFFS) * (w + GAP) + 3 * w, STRIP + BUFF_ROWS * (h + TEXT))

    if not self.CreateAuras then return end
    buffs = Block(self, w, h, perRow, BUFF_ROWS, "TOPRIGHT")
    buffs.cancelButton = "RightButtonUp"
    buffKey = buffs:AddGroup("HELPFUL", {
        maxFrameCount = BUFF_ROWS * perRow,
        candidateFilters = InCombatLockdown() and IN_COMBAT or OUT_OF_COMBAT,
    })

    local debuffs = Block(self, w, h, DEBUFFS, 1, "TOPLEFT")
    debuffs:AddGroup("HARMFUL", { maxFrameCount = DEBUFFS, showDebuffBorder = true })
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

local D = DeckUI

-------------------------------------------------------------------
-- Enemy nameplates as FFXIV draws them
-------------------------------------------------------------------
-- The owner's wish (2026-10-09, his FFXIV screenshot): over an enemy just
-- its level, name and raid marker, and a thin health bar under the name.
-- DeckUIDB.xivPlates, off by default, undone by unticking.
--
-- Nothing on Blizzard's nameplate is written or re-parented. Ours is a
-- frame on UIParent, anchored to the plate (like the target arrow and the
-- interact target's name). Blizzard's own drawing - its UnitFrame - is only
-- faded: alpha 0, held there by a SetAlpha post-hook while we cover that
-- plate, and given back alpha 1 when the plate goes or the option does.
-- The plate itself stays: clicking it still targets, the engine still
-- places, stacks and fades it.
--
-- Secret values: name, level and health go to SetText and the StatusBar
-- as they are. Whether a unit can be attacked may be secret; then it is
-- treated as an enemy. Plates the game keeps to itself (in some
-- instances) are not handed out by GetNamePlateForUnit, so they keep
-- Blizzard's look.
-------------------------------------------------------------------
local W, BAR_H = 120, 4
local NAME_ENEMY = { 1, 0.45, 0.45 }
local BAR_ENEMY = { 0.9, 0.25, 0.25 }
-- neutral creatures (reaction 4) are yellow, as the game draws them
local NAME_NEUTRAL = { 1, 0.9, 0.4 }
local BAR_NEUTRAL = { 0.95, 0.8, 0.2 }
local TAPPED = { 0.55, 0.55, 0.55 }
local LEVEL_PLAIN = { 0.9, 0.85, 0.7 }
local LEVEL_SKULL = { 1, 0.1, 0.1 }

local function Secret(v) return issecretvalue and issecretvalue(v) end
local function Ask(v)
    if Secret(v) then return nil end
    return v
end

-------------------------------------------------------------------
-- Our plates, pooled
-------------------------------------------------------------------
local pool, active = {}, {}     -- active: unit token -> our frame

local function Text(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(D.FONT, size, "OUTLINE")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function NewPlate()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(W, 20)
    f:SetFrameStrata("BACKGROUND")

    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetSize(W, BAR_H)
    bar:SetPoint("BOTTOM")
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    local edge = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0, 0, 0, 0.9)
    local track = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
    track:SetAllPoints()
    track:SetColorTexture(0.2, 0.05, 0.05, 0.85)
    f.bar = bar

    -- level small, then marker and name, all left above the bar
    local level = Text(f, 10)
    level:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 2)
    level:SetTextColor(0.9, 0.85, 0.7)
    f.level = level
    -- elite, rare or boss: a diamond before the level (rankmark.lua)
    f.rank = D.RankMark(f, 12)
    f.rank:SetPoint("RIGHT", level, "LEFT", -3, 0)
    local marker = f:CreateTexture(nil, "OVERLAY")
    marker:SetSize(12, 12)
    marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    marker:Hide()
    f.marker = marker
    local name = Text(f, 12)
    name:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    f.name = name
    return f
end

local function Acquire()
    local f = table.remove(pool) or NewPlate()
    return f
end

local function Release(f)
    f:Hide()
    f:ClearAllPoints()
    f.unit, f.plate = nil, nil
    pool[#pool + 1] = f
end

-------------------------------------------------------------------
-- Fading Blizzard's drawing on the plates we cover
-------------------------------------------------------------------
local covered, hooked = {}, {}   -- Blizzard's UnitFrame -> true

local function Cover(unitFrame, state)
    if not unitFrame then return end
    if state and not hooked[unitFrame] then
        hooked[unitFrame] = true
        hooksecurefunc(unitFrame, "SetAlpha", function(self, alpha)
            if covered[self] and alpha ~= 0 then self:SetAlpha(0) end
        end)
    end
    covered[unitFrame] = state or nil
    unitFrame:SetAlpha(state and 0 or 1)
end

-------------------------------------------------------------------
-- Filling and placing
-------------------------------------------------------------------
local function Fill(f)
    local unit = f.unit
    f.name:SetText(UnitName(unit))
    -- a boss's level reads -1; FFXIV writes "??" there
    local level = UnitLevel(unit)
    -- coloured by how hard it is for you, as Blizzard colours levels
    -- (owner's wish, 2026-10-27): grey, green, yellow, orange, red - and
    -- red for "??". A secret level keeps the plain colour.
    local c = LEVEL_PLAIN
    if not Secret(level) then
        if level <= 0 then
            level, c = "??", LEVEL_SKULL
        elseif GetCreatureDifficultyColor then
            local d = GetCreatureDifficultyColor(level)
            if d then c = { d.r, d.g, d.b } end
        end
    end
    f.level:SetText(level)
    f.level:SetTextColor(c[1], c[2], c[3])
    local rank = f.rank:SetRank(D.UnitRank(unit)) and f.rank:GetWidth() + 3 or 0
    f.level:SetPoint("BOTTOMLEFT", f.bar, "TOPLEFT", rank, 2)
    f.bar:SetMinMaxValues(0, UnitHealthMax(unit))
    f.bar:SetValue(UnitHealth(unit))
    local tapped = Ask(UnitIsTapDenied(unit))
    local neutral = Ask(UnitReaction(unit, "player")) == 4
    local c = tapped and TAPPED or neutral and BAR_NEUTRAL or BAR_ENEMY
    f.bar:SetStatusBarColor(c[1], c[2], c[3])
    local n = tapped and TAPPED or neutral and NAME_NEUTRAL or NAME_ENEMY
    f.name:SetTextColor(n[1], n[2], n[3])

    local index = Ask(GetRaidTargetIndex(unit))
    f.name:ClearAllPoints()
    if index then
        SetRaidTargetIconTexture(f.marker, index)
        f.marker:ClearAllPoints()
        f.marker:SetPoint("LEFT", f.level, "RIGHT", 3, 0)
        f.marker:Show()
        f.name:SetPoint("LEFT", f.marker, "RIGHT", 2, 0)
    else
        f.marker:Hide()
        f.name:SetPoint("LEFT", f.level, "RIGHT", 4, 0)
    end
    f.name:SetPoint("RIGHT", f.bar, "RIGHT", 0, 0)
end

local function Enemy(unit)
    local attackable = UnitCanAttack("player", unit)
    if Secret(attackable) then return true end
    return attackable and true or false
end

local function Remove(unit)
    local f = active[unit]
    if not f then return end
    active[unit] = nil
    if f.plate then Cover(f.plate.UnitFrame, false) end
    Release(f)
end

local function Add(unit)
    Remove(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or not Enemy(unit) then return end
    local f = Acquire()
    f.unit, f.plate = unit, plate
    f:SetPoint("CENTER", plate, "CENTER", 0, 0)
    Fill(f)
    f:Show()
    Cover(plate.UnitFrame, true)
    active[unit] = f
end

local function UpdateHealth(unit)
    local f = active[unit]
    if not f then return end
    f.bar:SetMinMaxValues(0, UnitHealthMax(unit))
    f.bar:SetValue(UnitHealth(unit))
end

-------------------------------------------------------------------
-- Events and switching
-------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        Add(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        Remove(unit)
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        UpdateHealth(unit)
    elseif event == "UNIT_NAME_UPDATE" or event == "UNIT_FACTION" or event == "UNIT_LEVEL"
        or event == "UNIT_CLASSIFICATION_CHANGED" then
        if unit and unit:find("^nameplate") then Add(unit) end
    elseif event == "RAID_TARGET_UPDATE" then
        for _, f in pairs(active) do Fill(f) end
    end
end)

local function All(fn)
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) then fn(unit) end
    end
end

-- Room between the plates (owner 2026-10-28: ours sat on top of each
-- other in a pack). The engine stacks and spaces plates by its own CVars:
-- nameplateMotion 1 = stacking, nameplateOverlapV = how much of a plate's
-- height the next may cover, nameplateOverlapH = how far apart side by side
-- two plates must be before they count as overlapping. Ours are wider than
-- Blizzard's plate, so the CVars Motion and V alone left them on top of each
-- other (2026-10-29); OverlapH makes the engine stack plates that are that
-- much further apart sideways. With our plates on and DeckUIDB.plateSpace
-- (on by default) all are set, and the player's own values go back when
-- either is switched off (kept in DeckUIDB.plateCVars until then). A CVar
-- the client does not know is left alone.
--
-- Not the plate size (C_NamePlate.SetNamePlateSize, tried the same day):
-- a larger plate drew a grey band of Blizzard's over ours. Nor a layout of
-- our own: plates are restricted regions, GetCenter on one fails ("Can't
-- measure restricted regions") and taints.
local SPACED = { nameplateMotion = "1", nameplateOverlapV = "1.8", nameplateOverlapH = "1.4" }

local function ApplySpacing(on)
    if on then
        local saved = DeckUIDB.plateCVars
        if not saved then
            saved = {}
            DeckUIDB.plateCVars = saved
        end
        for k, v in pairs(SPACED) do
            local cur = GetCVar(k)
            if cur ~= nil then
                if saved[k] == nil then saved[k] = cur end
                if cur ~= v then SetCVar(k, v) end
            end
        end
    elseif DeckUIDB.plateCVars then
        local saved = DeckUIDB.plateCVars
        DeckUIDB.plateCVars = nil
        for k in pairs(SPACED) do
            if saved[k] then SetCVar(k, saved[k]) end
        end
    end
end

function D.ApplyPlates()
    if DeckUIDB.plateSpace == nil then DeckUIDB.plateSpace = true end
    ApplySpacing(DeckUIDB.xivPlates and DeckUIDB.plateSpace and true or false)
    if DeckUIDB.xivPlates then
        for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_HEALTH",
                             "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_FACTION", "UNIT_LEVEL",
                             "RAID_TARGET_UPDATE", "UNIT_CLASSIFICATION_CHANGED" }) do
            if not C_EventUtils or C_EventUtils.IsEventValid(e) then ev:RegisterEvent(e) end
        end
        All(Add)
    else
        ev:UnregisterAllEvents()
        for unit in pairs(active) do Remove(unit) end
    end
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function() D.ApplyPlates() end)
D.OnRankMarks(function() for _, f in pairs(active) do Fill(f) end end)

function D.PlatesDebug()
    local plates, ours = 0, 0
    All(function(unit)
        plates = plates + 1
        if active[unit] then ours = ours + 1 end
    end)
    print(("DeckUI nameplates: %s, %d nameplate units, %d drawn by DeckUI, %d in the pool."):format(
        DeckUIDB.xivPlates and "on" or "off", plates, ours, #pool))
    local cvars = {}
    for _, k in ipairs({ "nameplateMotion", "nameplateOverlapV", "nameplateOverlapH" }) do
        local yours = DeckUIDB.plateCVars and DeckUIDB.plateCVars[k]
        cvars[#cvars + 1] = ("%s %s%s"):format(k, tostring(GetCVar(k)), yours and (" (yours " .. yours .. ")") or "")
    end
    print(("  spacing %s: %s"):format(DeckUIDB.plateSpace and "on" or "off", table.concat(cvars, ", ")))
end

local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Delves: the power pick and the Delver's Journey bar
-------------------------------------------------------------------
-- Part of replacing Plumber (owner's decision, 2026-10-01: independent
-- of other addons). Read from Plumber 1.9.4 (DelvesAutomation.lua,
-- DelvesScenario.lua), rebuilt on our rules. The Nemesis count lives in
-- scenario.lua's DelveEntry, the hunt quest in quests.lua.
--
-- Power pick: a treasure or a rare in a delve offers one power through
-- Blizzard's player-choice window. With exactly one option and one
-- button there is nothing to decide, so it is answered at once - with
-- C_PlayerChoice calls only; Blizzard's window is never touched, it
-- closes itself on the game's answer. Off by default: an update should
-- not start choosing for anyone. Fields are checked with issecretvalue
-- before any comparison.
--
-- Journey bar: the season's renown faction (C_DelvesUI), compared with a
-- snapshot on every FACTION_STANDING_CHANGED for it. A gain shows a bar
-- of our own for a few seconds - level, progress, the gain - and fades.
-------------------------------------------------------------------
local Plain = function(...)
    if not issecretvalue then return true end
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return false end
    end
    return true
end

local function InDelve()
    -- Blizzard's own test (INSTANCE_WALK_IN_LEAVE); also right after a relog
    return C_PartyInfo.IsPartyWalkIn and C_PartyInfo.IsPartyWalkIn() or false
end

-------------------------------------------------------------------
-- The single power
-------------------------------------------------------------------
local function PickSinglePower()
    if not (DeckQuestsDB.autoDelvePower and InDelve()) then return end
    local choice = C_PlayerChoice.GetCurrentPlayerChoiceInfo()
    local options = choice and choice.options
    if type(options) ~= "table" or #options ~= 1 then return end
    local option = options[1]
    local buttons = option.buttons
    if type(buttons) ~= "table" or #buttons ~= 1 then return end
    local spellID, responseID = option.spellID, buttons[1].id
    if not (spellID and responseID and Plain(spellID, responseID)) then return end

    C_PlayerChoice.SendPlayerChoiceResponse(responseID)
    C_PlayerChoice.OnUIClosed()
    local name = Plain(option.header) and option.header or C_Spell.GetSpellName(spellID) or "?"
    print(("DeckUI Quests: delve power taken - |cffffd100|Hspell:%d:0|h[%s]|h|r"):format(spellID, name))
end

-------------------------------------------------------------------
-- Delver's Journey bar
-------------------------------------------------------------------
local W, H = 320, 14
local FADE_AFTER = 4

local bar = CreateFrame("Frame", "DeckQuestsJourney", UIParent)
bar:SetSize(W, H + 18)
bar.defaultPoint = { "TOP", UIParent, "TOP", 0, -120 }
bar:SetPoint(unpack(bar.defaultPoint))
bar:SetAlpha(0)
bar:Hide()

local fill = CreateFrame("StatusBar", nil, bar)
fill:SetPoint("BOTTOMLEFT")
fill:SetPoint("BOTTOMRIGHT")
fill:SetHeight(H)
fill:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
fill:SetStatusBarColor(0.9, 0.75, 0.2)
local bg = fill:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.05, 0.05, 0.05, 0.85)

local label = bar:CreateFontString(nil, "OVERLAY")
label:SetFont(D.FONT, 12, "OUTLINE")
label:SetPoint("BOTTOMLEFT", fill, "TOPLEFT", 0, 3)
local gain = bar:CreateFontString(nil, "OVERLAY")
gain:SetFont(D.FONT, 12, "OUTLINE")
gain:SetPoint("BOTTOMRIGHT", fill, "TOPRIGHT", 0, 3)
gain:SetTextColor(0.4, 0.9, 0.4)
local value = fill:CreateFontString(nil, "OVERLAY")
value:SetFont(D.FONT, 10, "OUTLINE")
value:SetPoint("CENTER")

local shownAt = 0
bar:SetScript("OnUpdate", function(self)
    local t = GetTime() - shownAt
    if t < FADE_AFTER then
        self:SetAlpha(1)
    elseif t < FADE_AFTER + 1 then
        self:SetAlpha(1 - (t - FADE_AFTER))
    else
        self:SetAlpha(0)
        self:Hide()
    end
end)

local seasonFaction
local last   -- { level, earned, threshold }

local function Progress()
    seasonFaction = seasonFaction or (C_DelvesUI and C_DelvesUI.GetDelvesFactionForSeason
        and C_DelvesUI.GetDelvesFactionForSeason()) or 0
    if seasonFaction == 0 then return end
    local info = C_MajorFactions.GetMajorFactionRenownInfo(seasonFaction)
    if not info then return end
    local level, earned, threshold = info.renownLevel or 1, info.renownReputationEarned or 0, info.renownLevelThreshold or 0
    if not Plain(level, earned, threshold) then return end
    return level, earned, threshold
end

local function OnStanding()
    local level, earned, threshold = Progress()
    if not level then return end
    local before = last
    last = { level, earned, threshold }
    if not before or not DeckQuestsDB.journeyBar then return end

    local delta
    if level > before[1] then
        delta = earned + before[3] - before[2]
    else
        delta = earned - before[2]
    end
    if delta <= 0 then return end

    local data = C_MajorFactions.GetMajorFactionData and C_MajorFactions.GetMajorFactionData(seasonFaction)
    local name = data and Plain(data.name) and data.name or "Delver's Journey"
    label:SetText(("%s - level %d"):format(name, level))
    gain:SetText(("+%d"):format(delta))
    if threshold > 0 then
        fill:SetMinMaxValues(0, threshold)
        fill:SetValue(earned)
        value:SetText(("%d / %d"):format(earned, threshold))
    else
        fill:SetMinMaxValues(0, 1)
        fill:SetValue(1)
        value:SetText(MAXIMUM or "Maximum")
    end
    shownAt = GetTime()
    bar:Show()
end

-------------------------------------------------------------------
-- Events
-------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_CHOICE_UPDATE")
ev:RegisterEvent("FACTION_STANDING_CHANGED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, event, factionID)
    if not DeckQuestsDB then return end
    if event == "PLAYER_CHOICE_UPDATE" then
        PickSinglePower()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- the first snapshot, so the first gain has something to compare with
        seasonFaction = nil
        local level, earned, threshold = Progress()
        if level then last = { level, earned, threshold } end
    elseif event == "FACTION_STANDING_CHANGED" then
        if seasonFaction and factionID == seasonFaction then OnStanding() end
    end
end)

function ns.InitDelves()
    if DeckQuestsDB.autoDelvePower == nil then DeckQuestsDB.autoDelvePower = false end
    if DeckQuestsDB.journeyBar == nil then DeckQuestsDB.journeyBar = true end
    if DeckQuestsDB.huntMarks == nil then DeckQuestsDB.huntMarks = true end   -- hunt.lua
    D.MakeMovable(bar, "Delver's Journey", DeckQuestsDB)
    local level, earned, threshold = Progress()
    if level then last = { level, earned, threshold } end
end

-- /quests journey: the bar with the current numbers, to place it
function ns.ShowJourney()
    local level, earned, threshold = Progress()
    if not level then
        print("DeckUI Quests: no Delver's Journey this season.")
        return
    end
    last = { level, earned - 1, threshold }
    OnStanding()
end

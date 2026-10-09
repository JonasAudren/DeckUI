local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- The scenario guide, as FFXIV keeps it at the top left
-------------------------------------------------------------------
-- The owner's wish (2026-10-09, his FFXIV screenshot "Szenarioführer"):
-- one small banner that always says how the main story goes on - the
-- quest you are on, or where the next one waits, or what you are missing
-- to get it. DeckQuestsDB.scenarioGuide, off by default; movable
-- "Scenario guide".
--
-- Read from Blizzard's 12.1.0 source (WarCampaignTemplates.lua,
-- Blizzard_ObjectAPI/Campaign.lua, 2026-10-09). The quest log asks the
-- same calls:
--   C_CampaignInfo.GetAvailableCampaigns()       the campaigns there are
--   C_CampaignInfo.GetState(id)                  InProgress / Stalled / Complete
--   C_CampaignInfo.GetFailureReason(id)          for a stalled one: the next
--       step as text ("Reach level 85", "Speak to ... in ..."), with the
--       next quest's ID and map when the game knows them
--   C_CampaignInfo.GetCurrentChapterID / GetChapterIDs / GetCampaignChapterInfo
-- The quest being played is the campaign's quest in the quest log. Which
-- campaign is "the story": the one with a quest in the log, else a
-- stalled one, the newest (highest ID) first.
--
-- A click super-tracks the quest; for a quest not taken yet it puts a
-- waypoint on where it starts (C_QuestLine.GetQuestLineInfo gives that
-- spot). No click opens the map - Blizzard's own banner calls
-- OpenWorldMap, which from our code would run the map's opening tainted
-- (see the Quests notes in CLAUDE.md).
-------------------------------------------------------------------
local W = 280
local IN_PROGRESS = Enum.CampaignState and Enum.CampaignState.InProgress or 2
local STALLED = Enum.CampaignState and Enum.CampaignState.Stalled or 3

local guide = CreateFrame("Button", "DeckQuestsGuide", UIParent)
guide:SetSize(W, 50)
guide.defaultPoint = { "TOPLEFT", UIParent, "TOPLEFT", 16, -16 }
guide:SetPoint(unpack(guide.defaultPoint))
guide:RegisterForClicks("LeftButtonUp", "RightButtonUp")
guide:Hide()

local function Text(size, r, g, b)
    local fs = guide:CreateFontString(nil, "OVERLAY")
    fs:SetFont(D.FONT, size, "OUTLINE")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetTextColor(r, g, b)
    return fs
end

local header = Text(10, 0.85, 0.8, 0.7)
header:SetPoint("TOPLEFT", 34, 0)
header:SetText("Current campaign")

-- the band behind the quest's name: dark on the left, fading out
local band = guide:CreateTexture(nil, "BACKGROUND")
band:SetPoint("TOPLEFT", 26, -13)
band:SetSize(W - 26, 22)
band:SetTexture("Interface\\Buttons\\WHITE8x8")
band:SetGradient("HORIZONTAL", CreateColor(0.12, 0.09, 0.05, 0.9), CreateColor(0.12, 0.09, 0.05, 0))
local bandEdge = guide:CreateTexture(nil, "BORDER")
bandEdge:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT")
bandEdge:SetSize(W - 26, 1)
bandEdge:SetTexture("Interface\\Buttons\\WHITE8x8")
bandEdge:SetGradient("HORIZONTAL", CreateColor(0.85, 0.68, 0.3, 1), CreateColor(0.85, 0.68, 0.3, 0))

-- the round emblem on the left, FFXIV's red seal in gold here
local emblem = guide:CreateTexture(nil, "ARTWORK")
emblem:SetSize(30, 30)
emblem:SetPoint("LEFT", band, "LEFT", -18, 0)
emblem:SetTexture(D.DISC)
emblem:SetVertexColor(0.55, 0.12, 0.08)
local emblemRing = guide:CreateTexture(nil, "BORDER")
emblemRing:SetSize(34, 34)
emblemRing:SetPoint("CENTER", emblem)
emblemRing:SetTexture(D.DISC)
emblemRing:SetVertexColor(0.85, 0.68, 0.3)
local mark = guide:CreateFontString(nil, "OVERLAY")
mark:SetFont(D.FONT, 16, "OUTLINE")
mark:SetPoint("CENTER", emblem)
mark:SetTextColor(1, 0.85, 0.4)
mark:SetText("!")

local title = Text(13, 1, 1, 1)
title:SetPoint("LEFT", band, "LEFT", 16, 0)
title:SetWidth(W - 60)
local arrow = Text(14, 0.85, 0.68, 0.3)
arrow:SetPoint("RIGHT", band, "RIGHT", -6, 0)
arrow:SetText(">")

local sub = Text(11, 0.85, 0.85, 0.85)
sub:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 16, -3)
sub:SetWidth(W - 46)

local hover = guide:CreateTexture(nil, "HIGHLIGHT")
hover:SetAllPoints(band)
hover:SetColorTexture(1, 1, 1, 0.06)

-------------------------------------------------------------------
-- What the story is doing
-------------------------------------------------------------------
-- the campaign's quest in the quest log, if one is there
local function QuestInLog(campaignID)
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and info.campaignID == campaignID then
            return info.questID
        end
    end
end

local function Chapter(campaignID)
    local current = C_CampaignInfo.GetCurrentChapterID(campaignID)
    local ids = C_CampaignInfo.GetChapterIDs(campaignID) or {}
    if not current then return nil end
    local chapter = C_CampaignInfo.GetCampaignChapterInfo(current)
    for i, id in ipairs(ids) do
        if id == current then
            return ("Chapter %d/%d: %s"):format(i, #ids, chapter and chapter.name or "")
        end
    end
    return chapter and chapter.name
end

-- Which expansion a campaign belongs to: the expansion of one of its
-- quests (GetQuestExpansion) - the one in the log, a chapter's reward
-- quest, or the next quest the game names. Only found answers are kept;
-- a quest the client has not loaded yet answers later.
-- The first version took any open campaign, and with Midnight's done it
-- showed an old one from a former expansion (owner, 2026-10-09).
local expansions = {}

local function QuestExpansion(questID)
    if not (questID and questID > 0 and GetQuestExpansion) then return nil end
    local e = GetQuestExpansion(questID)
    if e and e >= 0 then return e end
end

local function CampaignExpansion(id)
    if expansions[id] then return expansions[id] end
    local e = QuestExpansion(QuestInLog(id))
    if not e then
        for _, chapterID in ipairs(C_CampaignInfo.GetChapterIDs(id) or {}) do
            local chapter = C_CampaignInfo.GetCampaignChapterInfo(chapterID)
            e = QuestExpansion(chapter and chapter.rewardQuestID)
            if e then break end
        end
    end
    if not e then
        local reason = C_CampaignInfo.GetFailureReason(id)
        e = QuestExpansion(reason and reason.questID)
    end
    expansions[id] = e
    return e
end

local function CurrentExpansion()
    return (GetServerExpansionLevel and GetServerExpansionLevel()) or GetExpansionLevel()
end

local function ExpansionName(e)
    return e and _G["EXPANSION_NAME" .. e] or nil
end

local function Open(id)
    local state = C_CampaignInfo.GetState(id)
    return state == IN_PROGRESS or state == STALLED, state
end

-- { campaignID, name, questID, title, sub, mapID } for the story, or nil.
-- The campaign picked by right click (DeckQuestsDB.guideCampaign) while it
-- is still open; otherwise the current expansion's: one with a quest in
-- the log first, then the newest.
local function Story()
    local best
    local pinned = DeckQuestsDB.guideCampaign
    if pinned and not Open(pinned) then
        DeckQuestsDB.guideCampaign, pinned = nil, nil
    end
    local current = CurrentExpansion()
    for _, id in ipairs(C_CampaignInfo.GetAvailableCampaigns() or {}) do
        local open, state = Open(id)
        local wanted = pinned and id == pinned or (not pinned and CampaignExpansion(id) == current)
        if open and wanted then
            local info = C_CampaignInfo.GetCampaignInfo(id)
            local inLog = QuestInLog(id)
            local candidate = { id = id, name = info and info.name or "", state = state, questID = inLog }
            local better = not best
                or (inLog and not best.questID)
                or ((inLog ~= nil) == (best.questID ~= nil) and id > best.id)
            if better then best = candidate end
        end
    end
    if not best then return nil end

    local chapter = Chapter(best.id)
    if best.questID then
        best.title = C_QuestLog.GetTitleForQuestID(best.questID) or best.name
        best.sub = chapter or best.name
        best.ready = true
        return best
    end
    -- stalled: what the game says comes next
    local reason = C_CampaignInfo.GetFailureReason(best.id)
    best.questID = reason and reason.questID
    best.mapID = reason and reason.mapID
    local nextTitle = best.questID and C_QuestLog.GetTitleForQuestID(best.questID)
    best.title = nextTitle or best.name
    best.sub = reason and reason.text or chapter or ""
    return best
end

local story

local function Update()
    if not DeckQuestsDB.scenarioGuide then
        guide:Hide()
        return
    end
    story = Story()
    if not story then
        local name = ExpansionName(CurrentExpansion())
        header:SetText(name or "Current campaign")
        title:SetText("Story complete")
        title:SetTextColor(0.6, 0.85, 0.6)
        sub:SetText("Right click: an open campaign of another expansion")
        guide:Show()
        return
    end
    header:SetText(story.name ~= "" and story.name or "Current campaign")
    title:SetText(story.title)
    sub:SetText(story.sub)
    -- an open quest is white; a step still to be reached gold
    if story.ready then title:SetTextColor(1, 1, 1) else title:SetTextColor(1, 0.85, 0.45) end
    guide:Show()
end

-------------------------------------------------------------------
-- Click: follow it
-------------------------------------------------------------------
-- Every click answers in the chat: the first version returned silently
-- when the game named no next quest, and a click seemed to do nothing
-- (owner's test, 2026-10-09).
-- Right click: pick the campaign by hand - any open one, of any expansion
-- - or go back to the current expansion's.
local function Menu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("Scenario guide")
        root:CreateRadio("Current expansion (automatic)",
            function() return DeckQuestsDB.guideCampaign == nil end,
            function() DeckQuestsDB.guideCampaign = nil; Update() end)
        local any = false
        for _, id in ipairs(C_CampaignInfo.GetAvailableCampaigns() or {}) do
            if Open(id) then
                any = true
                local info = C_CampaignInfo.GetCampaignInfo(id)
                local e = ExpansionName(CampaignExpansion(id))
                local text = (info and info.name or ("Campaign " .. id)) .. (e and (" |cff999999(" .. e .. ")|r") or "")
                root:CreateRadio(text,
                    function() return DeckQuestsDB.guideCampaign == id end,
                    function() DeckQuestsDB.guideCampaign = id; Update() end)
            end
        end
        if not any then root:CreateTitle("No open campaigns") end
    end)
end

guide:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        Menu(self)
        return
    end
    if not story then
        print("DeckUI Quests: no campaign is waiting for you.")
        return
    end
    if not story.questID then
        print(("DeckUI Quests: %s - %s"):format(story.name, story.sub ~= "" and story.sub or story.title))
        return
    end
    -- a quest in the log: super-tracked; and with DeckUI Nav a waypoint in
    -- its list where the quest goes next, so a pin shows on both maps (the
    -- super-tracked quest alone showed nothing the owner could see,
    -- 2026-10-09)
    local mapID, x, y
    if C_QuestLog.IsOnQuest(story.questID) then
        C_SuperTrack.SetSuperTrackedQuestID(story.questID)
        mapID, x, y = C_QuestLog.GetNextWaypoint(story.questID)
        if not (mapID and x and y) then
            local here = C_Map.GetBestMapForUnit("player")
            for _, q in ipairs(here and C_QuestLog.GetQuestsOnMap(here) or {}) do
                if q.questID == story.questID then mapID, x, y = here, q.x, q.y end
            end
        end
    else
        -- not taken yet: where it starts, when the game says where
        mapID = story.mapID or C_Map.GetBestMapForUnit("player")
        local line = mapID and C_QuestLine.GetQuestLineInfo(story.questID, mapID)
        if line and line.x and line.y and line.x > 0 then x, y = line.x, line.y else mapID = nil end
    end
    if mapID and x and y and D.AddWaypoint then
        D.AddWaypoint(mapID, x, y, story.title)
        print(("DeckUI Quests: waypoint set - %s."):format(story.title))
    elseif mapID and x and y and C_Map.CanSetUserWaypointOnMap(mapID) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        print(("DeckUI Quests: waypoint set - %s."):format(story.title))
    elseif C_QuestLog.IsOnQuest(story.questID) then
        print(("DeckUI Quests: following %s - the game gives no place for it on this map."):format(story.title))
    else
        print(("DeckUI Quests: %s"):format(story.sub ~= "" and story.sub or story.title))
    end
end)

guide:SetScript("OnEnter", function(self)
    if not story then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText(story.name ~= "" and story.name or "Campaign", 1, 0.82, 0)
    GameTooltip:AddLine(story.title, 1, 1, 1, true)
    if story.sub ~= "" then GameTooltip:AddLine(story.sub, 0.85, 0.85, 0.85, true) end
    GameTooltip:AddLine(story.ready and "Click: follow it, with a waypoint" or "Click: a waypoint where it starts",
        0.6, 0.6, 0.6)
    GameTooltip:AddLine("Right click: choose the campaign", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)
guide:SetScript("OnLeave", GameTooltip_Hide)

-------------------------------------------------------------------
-- Events
-------------------------------------------------------------------
local pending = false
local function Request()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        Update()
    end)
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", Request)

function ns.ApplyGuide()
    if DeckQuestsDB.scenarioGuide then
        for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED",
                             "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" }) do
            ev:RegisterEvent(e)
        end
    else
        ev:UnregisterAllEvents()
    end
    Update()
end

function ns.InitGuide()
    if DeckQuestsDB.scenarioGuide == nil then DeckQuestsDB.scenarioGuide = false end
    D.MakeMovable(guide, "Scenario guide", DeckQuestsDB)
    ns.ApplyGuide()
end

-- /quests guide: what it found
function ns.GuideDebug()
    for _, id in ipairs(C_CampaignInfo.GetAvailableCampaigns() or {}) do
        local info = C_CampaignInfo.GetCampaignInfo(id)
        local reason = C_CampaignInfo.GetFailureReason(id)
        print(("  campaign %d %s (expansion %s): state %s, quest in log %s, next %s (quest %s, map %s)"):format(id,
            info and info.name or "?", tostring(CampaignExpansion(id)),
            tostring(C_CampaignInfo.GetState(id)), tostring(QuestInLog(id)),
            reason and reason.text or "-", tostring(reason and reason.questID), tostring(reason and reason.mapID)))
    end
    local s = Story()
    print(("DeckUI Quests guide: current expansion %s, picked %s, showing %s"):format(tostring(CurrentExpansion()),
        tostring(DeckQuestsDB.guideCampaign), s and (s.name .. " - " .. s.title) or "no story"))
end

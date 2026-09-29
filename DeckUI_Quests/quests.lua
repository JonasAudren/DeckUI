local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Tracked quests and the campaign
-------------------------------------------------------------------
-- The same sources as Blizzard's QuestObjectiveTracker (12.1.0 source,
-- read 2026-09-29): the watch list in the client's order - it re-sorts
-- by zone on its own - objective lines from GetQuestLogLeaderBoard, and
-- the campaign split by quest classification. Blizzard's frame keeps
-- running its own QUEST_ACCEPTED handler, so auto-tracking new quests
-- (CVar autoQuestWatch) still works with its tracker switched off.
-------------------------------------------------------------------
local CAMPAIGN = Enum.QuestClassification.Campaign

local COLOR_COMPLETE = { 0.4, 0.9, 0.4 }
local COLOR_SUPER    = { 1, 0.82, 0 }
local COLOR_FAILED   = { 1, 0.3, 0.3 }

-- Objective lines, shared with the world quest section: the quest log's
-- lines for quests in the log, GetQuestObjectiveInfo for tasks.
function ns.QuestLines(questID, logIndex)
    local lines = {}
    local numObjectives = logIndex and GetNumQuestLeaderBoards(logIndex) or 0
    local sequenced = IsQuestSequenced and IsQuestSequenced(questID)
    for i = 1, numObjectives do
        -- the third argument keeps the percentage out of the text; the bar shows it
        local text, objectiveType, finished = GetQuestLogLeaderBoard(i, logIndex, true)
        if text then
            local line = { text = text, done = finished }
            if objectiveType == "progressbar" and not finished then
                line.bar = (GetQuestProgressBarPercent(questID) or 0) / 100
            end
            lines[#lines + 1] = line
            -- a sequenced quest shows its steps one at a time, like Blizzard's
            if sequenced and not finished then break end
        end
    end
    return lines
end

local function IsCampaign(questID)
    return C_QuestInfoSystem.GetQuestClassification(questID) == CAMPAIGN
end

local function TitleColor(questID, complete, failed)
    if failed then return COLOR_FAILED end
    if C_SuperTrack.GetSuperTrackedQuestID() == questID then return COLOR_SUPER end
    if complete then return COLOR_COMPLETE end
    return nil
end

-------------------------------------------------------------------
-- Clicks: left opens the quest in the log, shift-left stops tracking,
-- right opens Blizzard's menu of the same things its tracker offers
-------------------------------------------------------------------
local function QuestMenu(row, questID)
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateTitle(C_QuestLog.GetTitleForQuestID(questID) or "")
        if C_SuperTrack.GetSuperTrackedQuestID() ~= questID then
            root:CreateButton(SUPER_TRACK_QUEST, function() C_SuperTrack.SetSuperTrackedQuestID(questID) end)
        else
            root:CreateButton(STOP_SUPER_TRACK_QUEST, function() C_SuperTrack.SetSuperTrackedQuestID(0) end)
        end
        root:CreateButton(OBJECTIVES_SHOW_QUEST_MAP, function() QuestMapFrame_OpenToQuestDetails(questID) end)
        if QuestUtil.CanRemoveQuestWatch() then
            root:CreateButton(OBJECTIVES_STOP_TRACKING, function() C_QuestLog.RemoveQuestWatch(questID) end)
        end
        if C_QuestLog.IsPushableQuest(questID) and IsInGroup() then
            root:CreateButton(SHARE_QUEST, function() QuestUtil.ShareQuest(questID) end)
        end
        root:CreateButton(ABANDON_QUEST_ABBREV, function() QuestMapQuestOptions_AbandonQuest(questID) end)
    end)
end

local function QuestClick(questID, info, complete)
    return function(row, button)
        if button == "RightButton" then
            QuestMenu(row, questID)
        elseif IsModifiedClick("QUESTWATCHTOGGLE") then
            if QuestUtil.CanRemoveQuestWatch() then C_QuestLog.RemoveQuestWatch(questID) end
        elseif info.isAutoComplete and complete then
            ShowQuestComplete(questID)
        else
            QuestMapFrame_OpenToQuestDetails(questID)
        end
    end
end

local function QuestTooltip(questID)
    return function(row)
        GameTooltip:SetOwner(row, "ANCHOR_LEFT")
        GameTooltip:SetText(C_QuestLog.GetTitleForQuestID(questID) or "")
        GameTooltip:AddLine("Left-click: quest log, Shift-click: stop tracking, Right-click: menu", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end
end

-------------------------------------------------------------------
-- Entries
-------------------------------------------------------------------
local function QuestEntry(questID, logIndex, info)
    local complete = C_QuestLog.IsComplete(questID)
    local failed = C_QuestLog.IsFailed and C_QuestLog.IsFailed(questID)
    local lines
    if failed then
        lines = { { text = FAILED or "Failed" } }
    elseif complete then
        local text = GetQuestLogCompletionText(logIndex)
        if not text or text == "" then text = QUEST_WATCH_QUEST_READY or "Ready for turn-in" end
        lines = { { text = text, done = true } }
    else
        lines = ns.QuestLines(questID, logIndex)
    end
    return {
        key = "quest" .. questID,
        title = info.title,
        color = TitleColor(questID, complete, failed),
        lines = lines,
        OnClick = QuestClick(questID, info, complete),
        OnEnter = QuestTooltip(questID),
        secure = ns.QuestItem(logIndex, complete),
    }
end

-- Both sections read the same watch list and keep their half of it.
local function Collect(wantCampaign)
    local entries = {}
    for i = 1, C_QuestLog.GetNumQuestWatches() do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        local logIndex = questID and C_QuestLog.GetLogIndexForQuestID(questID)
        local info = logIndex and C_QuestLog.GetInfo(logIndex)
        -- tasks belong to the world/bonus section, bounties only once done
        if info and not info.isTask and not (info.isBounty and not C_QuestLog.IsComplete(questID))
            and IsCampaign(questID) == wantCampaign then
            entries[#entries + 1] = QuestEntry(questID, logIndex, info)
        end
    end
    return entries
end

ns.RegisterSection("campaign", {
    title = "Campaign",
    order = 20,
    Collect = function() return Collect(true) end,
})

ns.RegisterSection("quests", {
    title = "Quests",
    order = 30,
    Collect = function() return Collect(false) end,
})

-------------------------------------------------------------------
-- Events
-------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({
    "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_ACCEPTED", "QUEST_REMOVED",
    "QUEST_TURNED_IN", "QUEST_AUTOCOMPLETE", "SUPER_TRACKING_CHANGED", "QUEST_POI_UPDATE",
    "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "PLAYER_ENTERING_WORLD",
}) do ev:RegisterEvent(e) end

ev:SetScript("OnEvent", function() ns.RequestUpdate() end)

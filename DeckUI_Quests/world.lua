local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- World quests and bonus objectives
-------------------------------------------------------------------
-- As Blizzard's WorldQuest and BonusObjective trackers do it (12.1.0):
-- GetTasksTable() lists the tasks whose area you are in; a task counts
-- while GetTaskInfo says it is in the area. Tracked (watched) world quests
-- show anywhere, from their own watch list. That is the whole difference
-- between "tracked" and "in the area".
-------------------------------------------------------------------
local function TaskLines(questID, numObjectives)
    local lines = {}
    for i = 1, numObjectives or 0 do
        local text, objectiveType, finished = GetQuestObjectiveInfo(questID, i, false)
        if text and text ~= "" then
            local line = { text = text, done = finished }
            if objectiveType == "progressbar" and not finished then
                line.bar = (GetQuestProgressBarPercent(questID) or 0) / 100
                line.text = nil   -- the bar says it; the text is usually just the name again
            end
            lines[#lines + 1] = line
        end
    end
    return lines
end

-- Time left, for world quests that warn about expiring (Blizzard shows it
-- under the same condition: the tag's displayExpiration).
local function TimeLeft(questID)
    local tag = C_QuestLog.GetQuestTagInfo(questID)
    if not (tag and tag.displayExpiration) then return nil end
    local minutes = C_TaskQuest.GetQuestTimeLeftMinutes(questID)
    if not minutes or minutes <= 0 then return nil end
    if minutes >= 60 then
        return ("%dh %02dm left"):format(math.floor(minutes / 60), minutes % 60)
    end
    return ("%dm left"):format(minutes)
end

local function WorldClick(questID, watched)
    return function(row, button)
        if button == "RightButton" then
            MenuUtil.CreateContextMenu(row, function(_, root)
                root:CreateTitle(C_TaskQuest.GetQuestInfoByQuestID(questID) or "")
                if C_SuperTrack.GetSuperTrackedQuestID() ~= questID then
                    root:CreateButton(SUPER_TRACK_QUEST, function() C_SuperTrack.SetSuperTrackedQuestID(questID) end)
                else
                    root:CreateButton(STOP_SUPER_TRACK_QUEST, function() C_SuperTrack.SetSuperTrackedQuestID(0) end)
                end
                if watched then
                    root:CreateButton(OBJECTIVES_STOP_TRACKING, function() C_QuestLog.RemoveWorldQuestWatch(questID) end)
                end
            end)
        elseif IsModifiedClick("QUESTWATCHTOGGLE") and watched then
            C_QuestLog.RemoveWorldQuestWatch(questID)
        else
            local mapID = C_TaskQuest.GetQuestZoneID(questID)
            if mapID then OpenWorldMap(mapID) end
        end
    end
end

local function WorldTooltip(questID)
    return function(row)
        GameTooltip:SetOwner(row, "ANCHOR_LEFT")
        GameTooltip:SetText(C_TaskQuest.GetQuestInfoByQuestID(questID) or "")
        local left = TimeLeft(questID)
        if left then GameTooltip:AddLine(left, 1, 1, 1) end
        GameTooltip:AddLine("Left-click: map, Right-click: menu", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end
end

-- set by TaskEntry while CollectWorld runs: is any countdown on screen?
local anyTimed = false

local function TaskEntry(questID, watched)
    local isInArea, _, numObjectives, taskName = GetTaskInfo(questID)
    if not numObjectives then return nil end
    if not (watched or isInArea) then return nil end
    local lines = TaskLines(questID, numObjectives)
    local left = TimeLeft(questID)
    if left then
        table.insert(lines, 1, { text = left })
        anyTimed = true
    end
    local title = C_TaskQuest.GetQuestInfoByQuestID(questID) or taskName or ("Quest " .. questID)
    return {
        key = "task" .. questID,
        title = title,
        color = C_SuperTrack.GetSuperTrackedQuestID() == questID and { 1, 0.82, 0 } or nil,
        lines = lines,
        OnClick = WorldClick(questID, watched),
        OnEnter = WorldTooltip(questID),
        -- tasks in the area are in the quest log, and some carry an item
        secure = ns.QuestItem(C_QuestLog.GetLogIndexForQuestID(questID), false),
    }
end

local function Watched(questID)
    return C_QuestLog.GetQuestWatchType(questID) ~= nil
end

local function CollectWorld()
    local entries, seen = {}, {}
    anyTimed = false
    -- in the area first, then the tracked ones from anywhere
    for _, questID in ipairs(GetTasksTable() or {}) do
        if C_QuestLog.IsWorldQuest(questID) and not Watched(questID) then
            local e = TaskEntry(questID, false)
            if e then entries[#entries + 1] = e; seen[questID] = true end
        end
    end
    for i = 1, C_QuestLog.GetNumWorldQuestWatches() do
        local questID = C_QuestLog.GetQuestIDForWorldQuestWatchIndex(i)
        if questID and not seen[questID] then
            local e = TaskEntry(questID, true)
            if e then entries[#entries + 1] = e end
        end
    end
    -- the countdown counts minutes, so a redraw a minute is enough; none,
    -- no clock. (The flag used to be declared below TaskEntry, which then
    -- wrote a global - the countdown never ticked on its own.)
    ns.ticking.world = anyTimed and "minute" or nil
    return entries
end

local function CollectBonus()
    local entries = {}
    for _, questID in ipairs(GetTasksTable() or {}) do
        if not C_QuestLog.IsWorldQuest(questID) and not Watched(questID)
            and not C_QuestLog.IsQuestBounty(questID) then
            local e = TaskEntry(questID, false)
            if e then entries[#entries + 1] = e end
        end
    end
    return entries
end

ns.RegisterSection("bonus", {
    title = "Bonus Objectives",
    order = 60,
    Collect = CollectBonus,
})

ns.RegisterSection("world", {
    title = "World Quests",
    order = 70,
    Collect = CollectWorld,
})

-- quests.lua listens to the quest events; tasks add their own progress
local ev = CreateFrame("Frame")
for _, e in ipairs({ "TASK_PROGRESS_UPDATE", "CRITERIA_COMPLETE", "SUPER_TRACKING_PATH_UPDATED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function() ns.RequestUpdate() end)

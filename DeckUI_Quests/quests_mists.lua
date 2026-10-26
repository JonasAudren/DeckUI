local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Tracked quests in Mists of Pandaria Classic (MISTS_PLAN.md, phase 7)
-------------------------------------------------------------------
-- Only in DeckUI_Quests_Mists.toc, in place of retail's quests.lua: Mists
-- has the old quest log API and no campaign, no C_SuperTrack. The data is
-- read the way its own WatchFrame reads it (Wrath/WatchFrame.lua, 5.5.4):
-- the watch list by GetQuestIndexForWatch, the quest from GetQuestLogTitle
-- (isComplete 1 done, -1 failed), objectives from GetQuestLogLeaderBoard,
-- a quest with no objectives done once its money is there. The entries are
-- the same as retail's, so the tracker draws them unchanged.
--
-- Left click makes the quest the super-tracked one (SetSuperTrackedQuestID,
-- the arrow on Mists' map), shift-left stops tracking, right opens a menu.
-- Abandoning asks in DeckUI's dialog, never the shared StaticPopup.
-------------------------------------------------------------------
local COLOR_COMPLETE = { 0.4, 0.9, 0.4 }
local COLOR_SUPER    = { 1, 0.82, 0 }
local COLOR_FAILED   = { 1, 0.3, 0.3 }

local function Lines(logIndex)
    local lines = {}
    for i = 1, GetNumQuestLeaderBoards(logIndex) or 0 do
        local text, _, finished = GetQuestLogLeaderBoard(i, logIndex)
        if text then lines[#lines + 1] = { text = text, done = finished } end
    end
    return lines
end

local function TitleColor(questID, complete, failed)
    if failed then return COLOR_FAILED end
    if GetSuperTrackedQuestID() == questID then return COLOR_SUPER end
    if complete then return COLOR_COMPLETE end
    return nil
end

-- the log entry a quest ID sits at now (indices move as quests come and go)
local function LogIndex(questID)
    local index = GetQuestLogIndexByID(questID)
    return index and index > 0 and index or nil
end

local function Abandon(questID)
    local index = LogIndex(questID)
    if not index then return end
    SelectQuestLogEntry(index)
    SetAbandonQuest()
    local title = GetAbandonQuestName() or ""
    local items = GetAbandonQuestItems and GetAbandonQuestItems()
    local text
    if items then
        text = (ABANDON_QUEST_CONFIRM_WITH_ITEMS or "Abandon \"%s\"? These items will be destroyed: %s"):format(title, items)
    else
        text = (ABANDON_QUEST_CONFIRM or "Abandon \"%s\"?"):format(title)
    end
    D.Dialog({
        text = text,
        onAccept = function()
            -- selected again: the log may have moved while the question was open
            local now = LogIndex(questID)
            if not now then return end
            SelectQuestLogEntry(now)
            SetAbandonQuest()
            AbandonQuest()
            PlaySound(SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST)
        end,
    })
end

local function StopTracking(questID)
    local index = LogIndex(questID)
    if index then RemoveQuestWatch(index) end
end

local function QuestMenu(row, questID, title)
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateTitle(title or "")
        if GetSuperTrackedQuestID() ~= questID then
            root:CreateButton(SUPER_TRACK_QUEST or "Focus", function() SetSuperTrackedQuestID(questID) end)
        else
            root:CreateButton(STOP_SUPER_TRACK_QUEST or "Stop focus", function() SetSuperTrackedQuestID(0) end)
        end
        root:CreateButton(OBJECTIVES_STOP_TRACKING or "Stop tracking", function() StopTracking(questID) end)
        local index = LogIndex(questID)
        if index and IsInGroup() then
            SelectQuestLogEntry(index)
            if GetQuestLogPushable() then
                root:CreateButton(SHARE_QUEST or "Share", function()
                    local now = LogIndex(questID)
                    if now then SelectQuestLogEntry(now); QuestLogPushQuest() end
                end)
            end
        end
        root:CreateButton(ABANDON_QUEST_ABBREV or "Abandon", function() Abandon(questID) end)
    end)
end

local function QuestClick(questID, title, autoComplete, complete)
    return function(row, button)
        if button == "RightButton" then
            QuestMenu(row, questID, title)
        elseif IsModifiedClick("QUESTWATCHTOGGLE") then
            StopTracking(questID)
        elseif autoComplete and complete then
            ShowQuestComplete(LogIndex(questID))
        else
            SetSuperTrackedQuestID(questID)
        end
    end
end

local function QuestTooltip(title)
    return function(row)
        GameTooltip:SetOwner(row, "ANCHOR_LEFT")
        GameTooltip:SetText(title or "")
        GameTooltip:AddLine("Left-click: focus it, Shift-click: stop tracking, Right-click: menu", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end
end

local function QuestEntry(logIndex)
    local title, _, _, isHeader, _, isComplete, _, questID, startEvent = GetQuestLogTitle(logIndex)
    if not title or isHeader or not questID then return nil end
    local failed = isComplete and isComplete < 0
    local complete = isComplete and isComplete > 0
    local lines = Lines(logIndex)
    if not complete and not failed and #lines == 0 and not startEvent
        and GetMoney() >= (GetQuestLogRequiredMoney(logIndex) or 0) then
        complete = true
    end
    if failed then
        lines = { { text = FAILED or "Failed" } }
    elseif complete then
        local text = GetQuestLogCompletionText(logIndex)
        if not text or text == "" then text = QUEST_WATCH_QUEST_READY or "Ready for turn-in" end
        lines = { { text = text, done = true } }
    else
        local money = GetQuestLogRequiredMoney(logIndex) or 0
        if money > GetMoney() then
            lines[#lines + 1] = { text = GetMoneyString(GetMoney()) .. " / " .. GetMoneyString(money) }
        end
    end
    local autoComplete = GetQuestLogIsAutoComplete and GetQuestLogIsAutoComplete(logIndex)
    return {
        key = "quest" .. questID,
        title = title,
        color = TitleColor(questID, complete, failed),
        lines = lines,
        OnClick = QuestClick(questID, title, autoComplete, complete),
        OnEnter = QuestTooltip(title),
        secure = ns.QuestItem(logIndex, complete),
    }
end

ns.RegisterSection("quests", {
    title = "Quests",
    order = 30,
    Collect = function()
        local entries = {}
        for i = 1, GetNumQuestWatches() do
            local logIndex = GetQuestIndexForWatch(i)
            local entry = logIndex and QuestEntry(logIndex)
            if entry then entries[#entries + 1] = entry end
        end
        return entries
    end,
})

local ev = CreateFrame("Frame")
for _, e in ipairs({
    "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_WATCH_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED",
    "QUEST_TURNED_IN", "QUEST_AUTOCOMPLETE", "SUPER_TRACKED_QUEST_CHANGED", "QUEST_POI_UPDATE",
    "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_MONEY",
}) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", function() ns.RequestUpdate("quests") end)

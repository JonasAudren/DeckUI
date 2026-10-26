local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- /week record: which quest did the game just flag?
-------------------------------------------------------------------
-- The owner's wish (2026-10-09): our IDs should come from the game, not
-- from other addons. The game's data files know currencies, achievements
-- and quest titles (check-game-data.py compares those), but not the hidden
-- tracking quests that mark a looted profession treasure, a handed-in
-- treatise or a finished hunt - those exist only as numbers the server
-- flags. This recorder watches for them: it remembers every quest the
-- character has completed, and while it runs, every quest flagged since
-- shows in the chat with its title (when it has one), the zone, and what
-- data.lua calls it - or that data.lua does not know it yet.
--
--   /week record          start (or say that it runs)
--   /week record stop     stop
--   /week record list     what was found, kept across sessions (the last 200)
--   /week record clear    forget the list
--
-- C_QuestLog.GetAllCompletedQuestIDs is a long list, so it is read every
-- two seconds and only while recording.
-------------------------------------------------------------------
local INTERVAL, KEEP = 2, 200

local seen, count, ticker

-- every completed quest ID; Mists has only the old call, a table keyed by ID
local function CompletedIDs()
    if C_QuestLog.GetAllCompletedQuestIDs then return C_QuestLog.GetAllCompletedQuestIDs() end
    local ids = {}
    for id in pairs(GetQuestsCompleted() or {}) do ids[#ids + 1] = id end
    return ids
end

local QuestTitle = C_QuestLog.GetTitleForQuestID or C_QuestLog.GetQuestInfo or function() end

-- what data.lua (data_mists.lua) says about a quest ID, or nil
local function Known(id)
    if ns.PREY and ns.PREY[id] then return "prey hunt (" .. ns.PREY[id] .. ")" end
    if ns.DELVES and id == ns.DELVES.weeklyQuest then return "delve weekly" end
    if ns.DELVES and id == ns.DELVES.bountyQuest then return "Trovehunter's Bounty" end
    for _, b in ipairs(ns.WORLD_BOSSES or {}) do
        if b.quest == id then return "world boss: " .. b.name end
    end
    for _, w in ipairs(ns.WEEKLIES) do
        for _, q in ipairs(w.ids) do
            if q == id then return "weekly: " .. w.name end
        end
    end
    for skill, sources in pairs(ns.PROFESSIONS or {}) do
        for _, s in ipairs(sources) do
            for _, q in ipairs(s.ids) do
                if q == id then
                    local name = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName
                        and C_TradeSkillUI.GetTradeSkillDisplayName(skill)
                    return ("%s %s"):format(name or ("skill " .. skill), s.kind)
                end
            end
        end
    end
end

local function Found(id)
    local title = QuestTitle(id)
    local known = Known(id)
    local entry = {
        id = id, time = time(), zone = GetZoneText() or "",
        title = title, known = known,
    }
    local list = DeckWeekDB.recorded
    list[#list + 1] = entry
    while #list > KEEP do table.remove(list, 1) end
    print(("DeckUI Week record: quest |cffffd200%d|r %s in %s - %s"):format(id,
        title and ('"' .. title .. '"') or "(hidden)", entry.zone,
        known and ("known: " .. known) or "|cffff8040not in data.lua|r"))
end

local function Check()
    local ids = CompletedIDs()
    if not ids or #ids == count then return end
    count = #ids
    for _, id in ipairs(ids) do
        if not seen[id] then
            seen[id] = true
            Found(id)
        end
    end
end

local function Start()
    if ticker then
        print("DeckUI Week record: already running - /week record stop ends it.")
        return
    end
    seen = {}
    local ids = CompletedIDs() or {}
    for _, id in ipairs(ids) do seen[id] = true end
    count = #ids
    ticker = C_Timer.NewTicker(INTERVAL, Check)
    print(("DeckUI Week record: watching (%d quests completed so far). Loot a treasure, hand in a treatise, finish a hunt - each quest the game flags shows here. /week record stop ends it."):format(count))
end

local function Stop()
    if not ticker then
        print("DeckUI Week record: not running.")
        return
    end
    Check()
    ticker:Cancel()
    ticker, seen = nil, nil
    print("DeckUI Week record: stopped. /week record list shows what was found.")
end

local function List()
    local list = DeckWeekDB.recorded
    if #list == 0 then
        print("DeckUI Week record: nothing recorded yet.")
        return
    end
    print(("DeckUI Week record: %d quests found:"):format(#list))
    for _, e in ipairs(list) do
        print(("  %s  %d  %s  %s  %s"):format(date("%d.%m. %H:%M", e.time), e.id,
            e.title and ('"' .. e.title .. '"') or "(hidden)", e.zone,
            e.known or "not in data.lua"))
    end
end

function ns.Record(arg)
    DeckWeekDB.recorded = DeckWeekDB.recorded or {}
    if arg == "stop" then
        Stop()
    elseif arg == "list" then
        List()
    elseif arg == "clear" then
        wipe(DeckWeekDB.recorded)
        print("DeckUI Week record: list cleared.")
    else
        Start()
    end
end

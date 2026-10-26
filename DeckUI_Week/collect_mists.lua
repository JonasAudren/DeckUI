local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Mists of Pandaria: what a character's week holds (after core.lua)
-------------------------------------------------------------------
-- core.lua keeps the snapshot machinery and asks ns.COLLECTORS for the
-- parts; these are Mists'. Lockouts and currencies are core's own
-- collectors, the rest is new:
--  - Raid Finder wings are not saved instances in Mists: each wing is an
--    LFG dungeon whose killed bosses GetLFGDungeonNumEncounters counts
--    (Blizzard's RaidFinder.lua reads them the same way);
--  - world bosses are the hidden weekly quests of data_mists.lua - the
--    saved world bosses list is left out, they would show twice;
--  - challenge modes: each map's best medal and time, from the season
--    times Blizzard's challenges window shows (Mists/Blizzard_ChallengesUI).
-- Weekly quests in the log are learned like in retail, from the old quest
-- log API (Mists has no C_QuestLog.GetInfo).
-------------------------------------------------------------------
local WEEKLY = Enum.QuestFrequency and Enum.QuestFrequency.Weekly or LE_QUEST_FREQUENCY_WEEKLY

function ns.LearnWeeklies()
    local known = DeckWeekDB.weeklies
    for i = 1, GetNumQuestLogEntries() do
        local title, _, _, isHeader, _, _, frequency, questID = GetQuestLogTitle(i)
        if not isHeader and questID and WEEKLY and frequency == WEEKLY and not ns.KNOWN_QUESTS[questID] then
            known[questID] = title or known[questID] or ("Quest " .. questID)
        end
    end
end

local function Locks()
    local locks = {}
    for _, l in ipairs(ns.Locks()) do
        if not l.worldBoss then locks[#locks + 1] = l end
    end
    -- Raid Finder wings with a boss down this week
    local resetAt = time() + (C_DateAndTime.GetSecondsUntilWeeklyReset() or 0)
    for i = 1, (GetNumRFDungeons and GetNumRFDungeons() or 0) do
        local id, name = GetRFDungeonInfo(i)
        local total, killed = GetLFGDungeonNumEncounters(id)
        if name and killed and killed > 0 then
            locks[#locks + 1] = { name = name, difficulty = RAID_FINDER or "Raid Finder", raid = true,
                killed = killed, total = total or killed, resetAt = resetAt }
        end
    end
    return locks
end

local function WorldBosses()
    local done = {}
    for _, b in ipairs(ns.WORLD_BOSSES) do
        if ns.Done(b.quest) then done[b.quest] = true end
    end
    return done
end

local function Challenges()
    local list = {}
    for _, id in ipairs(C_ChallengeMode.GetMapTable() or {}) do
        local name = C_ChallengeMode.GetMapUIInfo(id)
        local info = C_MythicPlus.GetSeasonTimesForMap and C_MythicPlus.GetSeasonTimesForMap(id)
        list[#list + 1] = {
            name = name or ("map " .. id),
            medal = info and info.medal or 0,
            best = info and info.bestTime and math.ceil(info.bestTime / 1000) or nil,
        }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function Currencies()
    local list = {}
    for _, id in ipairs(ns.MISTS_CURRENCIES) do list[#list + 1] = ns.Currency(id) end
    return list
end

ns.COLLECTORS = {
    locks = Locks, worldBosses = WorldBosses, challenges = Challenges,
    currencies = Currencies, weekliesDone = ns.Weeklies,
}

-- what the game sends on request: the Raid Finder wings' kills
local ev = CreateFrame("Frame")
for _, e in ipairs({ "LFG_LOCK_INFO_RECEIVED", "LFG_UPDATE_RANDOM_INFO" }) do pcall(ev.RegisterEvent, ev, e) end
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if RequestLFDPlayerLockInfo then RequestLFDPlayerLockInfo() end
    elseif DeckWeekDB then
        ns.RequestSnapshot()
    end
end)
-- switched on mid-session: the world is entered already
if IsLoggedIn() and RequestLFDPlayerLockInfo then RequestLFDPlayerLockInfo() end

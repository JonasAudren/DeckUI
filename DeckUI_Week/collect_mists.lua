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
local DAILY = Enum.QuestFrequency and Enum.QuestFrequency.Daily or LE_QUEST_FREQUENCY_DAILY

-- Weeklies as in retail, and dailies too (owner's wish, 2026-10-27: MoP
-- lives on its dailies). A daily is remembered account-wide with its title
-- and the quest log header it sat under (the zone), so the window can say
-- where the day's quests were done. Which dailies the game offers changes
-- every day, so there is no "of how many" - only what was done today.
function ns.LearnWeeklies()
    local known = DeckWeekDB.weeklies
    local dailies = DeckWeekDB.dailies
    local header
    for i = 1, GetNumQuestLogEntries() do
        local title, _, _, isHeader, _, _, frequency, questID = GetQuestLogTitle(i)
        if isHeader then
            header = title
        elseif questID and not ns.KNOWN_QUESTS[questID] then
            if WEEKLY and frequency == WEEKLY then
                known[questID] = title or known[questID] or ("Quest " .. questID)
            elseif DAILY and frequency == DAILY then
                dailies[questID] = { title = title or ("Quest " .. questID), group = header or "" }
            end
        end
    end
end

-- the learned dailies this character has done today, counted by group
local function Dailies()
    local done, total = {}, 0
    for questID, q in pairs(DeckWeekDB.dailies) do
        if ns.Done(questID) then
            done[q.group] = (done[q.group] or 0) + 1
            total = total + 1
        end
    end
    return { total = total, groups = done,
             resetAt = time() + (C_DateAndTime.GetSecondsUntilDailyReset() or 0) }
end

-- Pandaria's factions this character has standing with (a neutral one at
-- zero has never been met), read the way the reputation pane shows them
local function Reputations()
    local list = {}
    local neutral = FACTION_STANDING_LABEL4
    for _, id in ipairs(ns.MISTS_FACTIONS) do
        local s = D.FactionStatus and D.FactionStatus(id)
        if s and not (s.standing == neutral and s.cur == 0) then
            list[#list + 1] = s
        end
    end
    return list
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
    dailies = Dailies, reputations = Reputations,
}

-- what the game sends on request: the Raid Finder wings' kills
local ev = CreateFrame("Frame")
for _, e in ipairs({ "LFG_LOCK_INFO_RECEIVED", "LFG_UPDATE_RANDOM_INFO", "UPDATE_FACTION" }) do pcall(ev.RegisterEvent, ev, e) end
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

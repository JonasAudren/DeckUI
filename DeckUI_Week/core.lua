local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- DeckUI Week: the week at a glance, for every character
-------------------------------------------------------------------
-- Asked for by the owner (2026-10-01): one window with the Great Vault,
-- locked instances, the keystone, weekly quests, renown and the capped
-- currencies - for all characters. Reworked 2026-10-02 into one table of
-- all characters, with delves, prey hunts and profession knowledge added.
--  - what counts this week (crests, delve and prey quests, profession
--    knowledge, the important weekly quests) is kept by ID in data.lua;
--  - other weekly quests are LEARNED on top: every quest with the weekly
--    frequency that shows up in a quest log is remembered account-wide,
--    and each character asks the game whether it is done this week
--    (IsQuestFlaggedCompleted). A right click in the window hides one.
--
-- Each character writes a snapshot of its week (DeckWeekDB.chars) while
-- logged in; the others show what they had when last seen. A snapshot
-- remembers when the weekly reset comes, so a character not seen since
-- then is shown as reset rather than with last week's numbers.
-------------------------------------------------------------------
local function Plain(...)
    if not issecretvalue then return true end
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return false end
    end
    return true
end
ns.Plain = Plain

local function CharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end
ns.CharKey = CharKey

-------------------------------------------------------------------
-- Collectors: each fills one part of the snapshot
-------------------------------------------------------------------
local VAULT_TYPES -- type -> "raid" | "mplus" | "world", from the game's enum
local function VaultTypes()
    if VAULT_TYPES then return VAULT_TYPES end
    VAULT_TYPES = {}
    local E = Enum.WeeklyRewardChestThresholdType or {}
    if E.Raid then VAULT_TYPES[E.Raid] = "raid" end
    if E.Activities then VAULT_TYPES[E.Activities] = "mplus" end
    if E.World then VAULT_TYPES[E.World] = "world" end
    return VAULT_TYPES
end

local function Vault()
    local vault = { raid = {}, mplus = {}, world = {} }
    for _, a in ipairs(C_WeeklyRewards.GetActivities() or {}) do
        local kind = VaultTypes()[a.type]
        if kind and Plain(a.progress, a.threshold, a.level) then
            local slot = { progress = a.progress, threshold = a.threshold, level = a.level }
            -- the item level an unlocked slot offers, as AlterEgo reads it
            if a.progress >= a.threshold and a.id and C_WeeklyRewards.GetExampleRewardItemHyperlinks then
                local link = C_WeeklyRewards.GetExampleRewardItemHyperlinks(a.id)
                local ilvl = link and C_Item.GetDetailedItemLevelInfo(link)
                if ilvl and Plain(ilvl) then slot.ilvl = ilvl end
            end
            vault[kind][a.index] = slot
        end
    end
    vault.rewardsWaiting = C_WeeklyRewards.HasAvailableRewards and C_WeeklyRewards.HasAvailableRewards() or false
    return vault
end

local function Locks()
    local locks, now = {}, time()
    for i = 1, GetNumSavedInstances() do
        local name, _, reset, _, locked, extended, _, isRaid, _, difficultyName, numEncounters, encounterProgress =
            GetSavedInstanceInfo(i)
        if name and (locked or extended) then
            locks[#locks + 1] = {
                name = name, difficulty = difficultyName, raid = isRaid,
                killed = encounterProgress or 0, total = numEncounters or 0,
                resetAt = now + (reset or 0),
            }
        end
    end
    for i = 1, (GetNumSavedWorldBosses and GetNumSavedWorldBosses() or 0) do
        local name, _, reset = GetSavedWorldBossInfo(i)
        if name then
            locks[#locks + 1] = { name = name, difficulty = "World boss", worldBoss = true,
                killed = 1, total = 1, resetAt = now + (reset or 0) }
        end
    end
    table.sort(locks, function(a, b)
        if (a.raid and 1 or 0) ~= (b.raid and 1 or 0) then return a.raid end
        return a.name < b.name
    end)
    return locks
end

local function Keystone()
    local key = {}
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    if mapID and level and level > 0 then
        key.level = level
        key.map = C_ChallengeMode.GetMapUIInfo(mapID) or ("map " .. mapID)
    end
    local runs, best = 0, 0
    for _, run in ipairs(C_MythicPlus.GetRunHistory(false, true) or {}) do
        if run.thisWeek then
            runs = runs + 1
            if run.completed and run.level and run.level > best then best = run.level end
        end
    end
    key.runs, key.best = runs, best
    return key
end

local function Renown()
    local list = {}
    local expansion = LE_EXPANSION_LEVEL_CURRENT or (GetExpansionLevel and GetExpansionLevel())
    for _, id in ipairs(C_MajorFactions.GetMajorFactionIDs(expansion) or {}) do
        local data = C_MajorFactions.GetMajorFactionData(id)
        if data and data.isUnlocked and Plain(data.renownLevel) then
            list[#list + 1] = {
                name = data.name, level = data.renownLevel, max = data.maxLevel,
                earned = data.renownReputationEarned, threshold = data.renownLevelThreshold,
            }
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- One currency as the window needs it. Whether a cap is weekly or for the
-- season is the currency's own answer, not ours.
local function Currency(id)
    local c = id and C_CurrencyInfo.GetCurrencyInfo(id)
    if not c or not c.name or c.name == "" or not Plain(c.quantity, c.totalEarned) then return nil end
    local weekly = (c.maxWeeklyQuantity or 0) > 0
    local seasonal = c.useTotalEarnedForMaxQty and (c.maxQuantity or 0) > 0
    return {
        id = id, name = c.name, icon = c.iconFileID, quantity = c.quantity or 0,
        weekEarned = weekly and c.quantityEarnedThisWeek or nil,
        weekMax = weekly and c.maxWeeklyQuantity or nil,
        seasonEarned = seasonal and c.totalEarned or nil,
        seasonMax = seasonal and c.maxQuantity or nil,
        max = (not seasonal) and (c.maxQuantity or 0) > 0 and c.maxQuantity or nil,
    }
end

local function Season()
    local id = C_MythicPlus.GetCurrentSeason and C_MythicPlus.GetCurrentSeason()
    return ns.SEASONS[id] or ns.SEASONS[ns.DEFAULT_SEASON]
end

local function Crests()
    local list = {}
    for _, id in ipairs(Season().crests) do list[#list + 1] = Currency(id) end
    return list
end

local function Currencies()
    local season, C = Season(), ns.CURRENCIES
    local list = {}
    for _, id in ipairs({ season.catalyst, season.spark, C.keys, C.shards, C.voidcore, C.manaCrystals, C.marl }) do
        list[#list + 1] = Currency(id)
    end
    return list
end

local Done = C_QuestLog.IsQuestFlaggedCompleted

local function Delves()
    local data = ns.DELVES
    local bounty = 0
    for _, item in ipairs(data.bountyItems) do bounty = bounty + (C_Item.GetItemCount(item, true) or 0) end
    local keys = C_CurrencyInfo.GetCurrencyInfo(ns.CURRENCIES.keys)
    return {
        weekly = Done(data.weeklyQuest),
        bounty = bounty, bountyUsed = Done(data.bountyQuest),
        keys = keys and Plain(keys.quantity) and keys.quantity or 0,
    }
end

local function Prey()
    local done = { normal = 0, hard = 0, nightmare = 0 }
    for questID, difficulty in pairs(ns.PREY) do
        if Done(questID) then done[difficulty] = done[difficulty] + 1 end
    end
    local active = C_QuestLog.GetActivePreyQuest and C_QuestLog.GetActivePreyQuest()
    return { done = done, active = active and active > 0 and (C_QuestLog.GetTitleForQuestID(active) or true) or nil }
end

-- The week's knowledge per profession: points taken out of points on offer,
-- split by source. A pool is one quest a week, so it offers its points once.
local KINDS = { "treatise", "quest", "treasure" }
local function Professions()
    local list = {}
    local p1, p2 = GetProfessions()
    for _, index in ipairs({ p1 or 0, p2 or 0 }) do
        local name, icon, skillLine
        if index > 0 then name, icon, _, _, _, _, skillLine = GetProfessionInfo(index) end
        local sources = skillLine and ns.PROFESSIONS[skillLine]
        if sources then
            local prof = { name = name, icon = icon, points = 0, max = 0, parts = {} }
            for _, kind in ipairs(KINDS) do prof.parts[kind] = { points = 0, max = 0 } end
            for _, s in ipairs(sources) do
                local part, done = prof.parts[s.kind], 0
                for _, id in ipairs(s.ids) do if Done(id) then done = done + 1 end end
                local offered = s.pool and 1 or #s.ids
                local taken = math.min(done, offered)
                part.points, part.max = part.points + taken * s.kp, part.max + offered * s.kp
                prof.points, prof.max = prof.points + taken * s.kp, prof.max + offered * s.kp
            end
            list[#list + 1] = prof
        end
    end
    return list
end

-- Weekly quests: learn what is in the log, then ask about all of them.
-- The ones data.lua knows are listed there already and never learned.
local function LearnWeeklies()
    local known = DeckWeekDB.weeklies
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and info.frequency == Enum.QuestFrequency.Weekly
            and not ns.KNOWN_QUESTS[info.questID] then
            known[info.questID] = info.title or known[info.questID] or ("Quest " .. info.questID)
        end
    end
end

-- done this week, keyed like the window lists them: a fixed entry by its
-- first ID (any quest of a pool counts), a learned one by its own
local function Weeklies()
    local done = {}
    for _, w in ipairs(ns.WEEKLIES) do
        for _, id in ipairs(w.ids) do
            if Done(id) then done[w.ids[1]] = true break end
        end
    end
    for questID in pairs(DeckWeekDB.weeklies) do
        if Done(questID) then done[questID] = true end
    end
    return done
end

local function TravelersLog()
    local info = C_PerksActivities and C_PerksActivities.GetPerksActivitiesInfo and C_PerksActivities.GetPerksActivitiesInfo()
    if not info then return nil end
    local points, max = 0, 0
    for _, a in ipairs(info.activities or {}) do
        if a.completed then points = points + (a.thresholdContributionAmount or 0) end
    end
    for _, t in ipairs(info.thresholds or {}) do
        if (t.requiredContributionAmount or 0) > max then max = t.requiredContributionAmount end
    end
    return { month = info.displayMonthName, points = points, max = max }
end

-------------------------------------------------------------------
-- The snapshot of this character
-------------------------------------------------------------------
local function Snapshot()
    if not DeckWeekDB then return end
    LearnWeeklies()
    local _, class = UnitClass("player")
    local _, ilvl = GetAverageItemLevel()
    local snap = {
        name = UnitName("player"), realm = GetRealmName(), class = class,
        level = UnitLevel("player"), ilvl = ilvl and math.floor(ilvl + 0.5) or 0,
        updated = time(),
        resetAt = time() + (C_DateAndTime.GetSecondsUntilWeeklyReset() or 0),
    }
    -- each part on its own: one that fails leaves the others standing
    for key, collect in pairs({
        vault = Vault, locks = Locks, keystone = Keystone, renown = Renown, travelers = TravelersLog,
        crests = Crests, currencies = Currencies, delves = Delves, prey = Prey, profs = Professions,
        weekliesDone = Weeklies,
    }) do
        local ok, result = pcall(collect)
        snap[key] = ok and result or nil
    end
    DeckWeekDB.chars[CharKey()] = snap
    if ns.Refresh then ns.Refresh() end
end
ns.Snapshot = Snapshot

-- a snapshot from before the weekly reset is last week's
function ns.IsStale(snap)
    return snap and snap.resetAt and time() >= snap.resetAt
end

-- many events, one snapshot at most every two seconds
local pending = false
local function RequestSnapshot()
    if pending then return end
    pending = true
    C_Timer.After(2, function()
        pending = false
        Snapshot()
    end)
end
ns.RequestSnapshot = RequestSnapshot

-------------------------------------------------------------------
-- Startup and events
-------------------------------------------------------------------
local function Init()
    DeckWeekDB = DeckWeekDB or {}
    DeckWeekDB.chars = DeckWeekDB.chars or {}
    DeckWeekDB.weeklies = DeckWeekDB.weeklies or {}
    DeckWeekDB.hidden = DeckWeekDB.hidden or {}
    -- learned before data.lua knew them
    for questID in pairs(DeckWeekDB.weeklies) do
        if ns.KNOWN_QUESTS[questID] then DeckWeekDB.weeklies[questID] = nil end
    end
    -- the data the game sends on request
    RequestRaidInfo()
    if C_MythicPlus.RequestMapInfo then C_MythicPlus.RequestMapInfo() end
    if C_MythicPlus.RequestRewards then C_MythicPlus.RequestRewards() end
    RequestSnapshot()
    if ns.InitWindow then ns.InitWindow() end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({
    "UPDATE_INSTANCE_INFO", "WEEKLY_REWARDS_UPDATE", "CHALLENGE_MODE_MAPS_UPDATE",
    "CHALLENGE_MODE_COMPLETED", "QUEST_TURNED_IN", "QUEST_ACCEPTED", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
    "CURRENCY_DISPLAY_UPDATE", "PLAYER_ENTERING_WORLD", "BOSS_KILL", "SKILL_LINES_CHANGED",
}) do pcall(ev.RegisterEvent, ev, e) end
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, event)
    if not DeckWeekDB then return end
    if event == "PLAYER_LOGOUT" then
        -- no timers any more: the last word, now
        pcall(Snapshot)
    elseif event == "BOSS_KILL" then
        RequestRaidInfo()
    else
        RequestSnapshot()
    end
end)

if IsLoggedIn() then
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, name)
        if name == ADDON then
            self:UnregisterEvent("ADDON_LOADED")
            Init()
        end
    end)
else
    local login = CreateFrame("Frame")
    login:RegisterEvent("PLAYER_LOGIN")
    login:SetScript("OnEvent", Init)
end

-- the hub's key binding and minimap button call this
D.weekToggle = function() if ns.Toggle then ns.Toggle() end end

-- /week opens the window; /week config the tab; /week forget <questID>
SLASH_DECKWEEK1 = "/week"
SlashCmdList.DECKWEEK = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "config" then
        D.ToggleConfig("Week")
    elseif msg:match("^forget %d+$") then
        local id = tonumber(msg:match("%d+"))
        DeckWeekDB.weeklies[id] = nil
        print(("DeckUI Week: quest %d forgotten."):format(id))
        RequestSnapshot()
    else
        ns.Toggle()
    end
end

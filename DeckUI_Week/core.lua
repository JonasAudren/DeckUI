local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- DeckUI Week: the week at a glance, for every character
-------------------------------------------------------------------
-- Asked for by the owner (2026-10-01): one window with the Great Vault,
-- locked instances, the keystone, weekly quests, renown and the capped
-- currencies - for all characters. Everything comes from the game's own
-- APIs (12.1.0 docs), no hand-kept lists:
--  - weekly quests have no list in the game, so they are LEARNED: every
--    quest with the weekly frequency that shows up in a quest log is
--    remembered account-wide, and each character asks the game whether
--    it is done this week (IsQuestFlaggedCompleted);
--  - capped currencies are found by walking the currency list for a
--    weekly or seasonal cap.
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
            vault[kind][a.index] = { progress = a.progress, threshold = a.threshold, level = a.level }
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

-- Every currency with a weekly or a seasonal cap, plus the ones the player
-- shows in the backpack. Collapsed headers hide their children, so they
-- are opened for the walk and closed again afterwards.
local function Currencies()
    local list, reopened = {}, {}
    local i = 1
    while i <= C_CurrencyInfo.GetCurrencyListSize() do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and info.isHeader and not info.isHeaderExpanded then
            C_CurrencyInfo.ExpandCurrencyList(i, true)
            reopened[#reopened + 1] = info.name
        end
        i = i + 1
    end
    for index = 1, C_CurrencyInfo.GetCurrencyListSize() do
        local c = C_CurrencyInfo.GetCurrencyListInfo(index)
        if c and not c.isHeader and c.currencyID and Plain(c.quantity) then
            local weekly = (c.maxWeeklyQuantity or 0) > 0
            local seasonal = c.useTotalEarnedForMaxQty and (c.maxQuantity or 0) > 0
            if weekly or seasonal or c.isShowInBackpack then
                list[#list + 1] = {
                    id = c.currencyID, name = c.name, icon = c.iconFileID, quantity = c.quantity,
                    weekEarned = weekly and c.quantityEarnedThisWeek or nil,
                    weekMax = weekly and c.maxWeeklyQuantity or nil,
                    seasonEarned = seasonal and c.totalEarned or nil,
                    seasonMax = seasonal and c.maxQuantity or nil,
                    max = (not seasonal) and (c.maxQuantity or 0) > 0 and c.maxQuantity or nil,
                }
            end
        end
    end
    -- close what was closed, from the bottom so the indices stay valid
    for index = C_CurrencyInfo.GetCurrencyListSize(), 1, -1 do
        local info = C_CurrencyInfo.GetCurrencyListInfo(index)
        if info and info.isHeader and info.isHeaderExpanded then
            for _, name in ipairs(reopened) do
                if name == info.name then C_CurrencyInfo.ExpandCurrencyList(index, false) break end
            end
        end
    end
    return list
end

-- Weekly quests: learn what is in the log, then ask about all of them
local function LearnWeeklies()
    local known = DeckWeekDB.weeklies
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID and info.frequency == Enum.QuestFrequency.Weekly then
            known[info.questID] = info.title or known[info.questID] or ("Quest " .. info.questID)
        end
    end
end

local function Weeklies()
    local done = {}
    for questID in pairs(DeckWeekDB.weeklies) do
        if C_QuestLog.IsQuestFlaggedCompleted(questID) then done[questID] = true end
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
local lastSnap = 0

local function Snapshot()
    if not DeckWeekDB then return end
    lastSnap = GetTime()
    LearnWeeklies()
    local _, class = UnitClass("player")
    local _, ilvl = GetAverageItemLevel()
    local snap = {
        name = UnitName("player"), realm = GetRealmName(), class = class,
        level = UnitLevel("player"), ilvl = ilvl and math.floor(ilvl + 0.5) or 0,
        updated = time(),
        resetAt = time() + (C_DateAndTime.GetSecondsUntilWeeklyReset() or 0),
    }
    local ok
    ok, snap.vault = pcall(Vault)
    if not ok then snap.vault = nil end
    ok, snap.locks = pcall(Locks)
    if not ok then snap.locks = nil end
    ok, snap.keystone = pcall(Keystone)
    if not ok then snap.keystone = nil end
    ok, snap.renown = pcall(Renown)
    if not ok then snap.renown = nil end
    ok, snap.currencies = pcall(Currencies)
    if not ok then snap.currencies = nil end
    snap.weekliesDone = Weeklies()
    ok, snap.travelers = pcall(TravelersLog)
    if not ok then snap.travelers = nil end
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
    "CURRENCY_DISPLAY_UPDATE", "PLAYER_ENTERING_WORLD", "BOSS_KILL",
}) do pcall(ev.RegisterEvent, ev, e) end
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, event)
    if not DeckWeekDB then return end
    if event == "PLAYER_LOGOUT" then
        -- no timers any more: the last word, now
        pcall(Snapshot)
    elseif event == "CURRENCY_DISPLAY_UPDATE" and GetTime() - lastSnap < 3 then
        -- opening and closing currency headers during a snapshot fires
        -- this too; it must not ask for the next snapshot
        return
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

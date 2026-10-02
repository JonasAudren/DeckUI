local ADDON, ns = ...

-------------------------------------------------------------------
-- Midnight's weekly content, by ID
-------------------------------------------------------------------
-- The game has no list of "what counts this week", so these are kept by
-- hand. The IDs are the ones AlterEgo, Plumber and Myu's Knowledge Points
-- Tracker use (read 2026-10-02 from the installed copies) - when one of
-- them changes a number at a patch, this is the place to follow.
-- Names are fallbacks only: a quest's title comes from the game when it
-- has it (C_QuestLog.GetTitleForQuestID), in the client's language.
-------------------------------------------------------------------

-- Upgrade crests and the other season currencies, per M+ season
-- (C_MythicPlus.GetCurrentSeason: 17 = Midnight Season 1, 18 = Season 2).
-- Caps are not kept here: the currency info says whether one is weekly
-- (maxWeeklyQuantity) or for the season (useTotalEarnedForMaxQty).
ns.SEASONS = {
    [17] = {
        crests = { 3383, 3341, 3343, 3345, 3347 },  -- Adventurer .. Myth Dawncrest
        catalyst = 3378, spark = 3212,
    },
    [18] = {
        crests = { 3442, 3443, 3444, 3445, 3446 },  -- Adventurer .. Myth Mistcrest
        catalyst = 3465, spark = 3509,
    },
}
-- on 12.1.0 with no season reported (between seasons): the newest one
ns.DEFAULT_SEASON = 18

-- the same in every season
ns.CURRENCIES = {
    keys = 3028,         -- Restored Coffer Key
    shards = 3310,       -- Coffer Key Shards (weekly cap)
    voidcore = 3418,     -- Nebulous Voidcore (bonus rolls)
    manaCrystals = 3356, -- Untainted Mana-Crystals
    marl = 3316,         -- Voidlight Marl
}

-- Delves: the account's weekly delve quest, and the Trovehunter's Bounty
-- (item per season, one use a week flagged by one quest)
ns.DELVES = {
    weeklyQuest = 93784, weeklyName = "A Gnawing Void of Curiosity",
    bountyItems = { 252415, 265714, 274374 },
    bountyQuest = 86371,
}

-- Prey hunts: each finished hunt flags one quest for the week; four per
-- difficulty count (Plumber's "n/4").
ns.PREY_CAP = 4
ns.PREY = {}
do
    local function add(first, last, difficulty, step)
        for id = first, last, step or 1 do ns.PREY[id] = difficulty end
    end
    add(91095, 91124, "normal")
    add(91210, 91240, "hard", 2)       -- the even ones of 91210-91241
    add(91211, 91241, "nightmare", 2)  -- the odd ones
    add(91242, 91255, "hard")
    add(91256, 91269, "nightmare")
    add(95021, 95024, "nightmare")     -- added in Season 2
end

-- Weekly quests worth a line, in the order shown. `ids` with more than one
-- entry is a pool: one of them is offered each week, any one done counts.
ns.WEEKLIES = {
    { ids = { 89289 }, name = "Favor of the Court" },
    { ids = { 90573, 90574, 90575, 90576 }, name = "Silvermoon runestones" },
    { ids = { 89507 }, name = "Abundant Offerings" },
    { ids = { 89268 }, name = "Lost Legends" },
    { ids = { 88993, 88994, 88995, 88996, 88997 }, name = "Harandar relics" },
    { ids = { 90962 }, name = "Stormarion Assault" },
    { ids = { 94581 }, name = "Stand Your Ground" },
    { ids = { 94790 }, name = "Research Console: Exploring the Void" },
    { ids = { 91700 }, name = "Darkness Unmade" },
    { ids = { 96995 }, name = "Turn Back the Surge" },
    { ids = { 95520 }, name = "Purging the Vaults" },
    { ids = { 89354 }, name = "Preparing for Battle" },
}

-- Weekly profession knowledge, keyed by the profession's base skill line
-- (7th return of GetProfessionInfo). Each source: quest IDs, points per
-- quest, and whether the IDs are a pool (one a week) or all count.
--   treatise  - the Inscription-made treatise, once a week
--   quest     - the trainer's / services weekly, one of a pool
--   treasure  - weekly treasures and gathering drops, each counts
ns.PROFESSIONS = {
    [171] = { -- Alchemy
        { kind = "treatise", ids = { 95127 }, kp = 1 },
        { kind = "quest",    ids = { 93690 }, kp = 1, pool = true },
        { kind = "treasure", ids = { 93528, 93529 }, kp = 1 },
    },
    [164] = { -- Blacksmithing
        { kind = "treatise", ids = { 95128 }, kp = 1 },
        { kind = "quest",    ids = { 93691 }, kp = 2, pool = true },
        { kind = "treasure", ids = { 93530, 93531 }, kp = 2 },
    },
    [333] = { -- Enchanting
        { kind = "treatise", ids = { 95129 }, kp = 1 },
        { kind = "quest",    ids = { 93697, 93698, 93699 }, kp = 3, pool = true },
        { kind = "treasure", ids = { 95048, 95049, 95050, 95051, 95052 }, kp = 1 },
        { kind = "treasure", ids = { 95053 }, kp = 4 },
        { kind = "treasure", ids = { 93532, 93533 }, kp = 2 },
    },
    [202] = { -- Engineering
        { kind = "treatise", ids = { 95138 }, kp = 1 },
        { kind = "quest",    ids = { 93692 }, kp = 1, pool = true },
        { kind = "treasure", ids = { 93534, 93535 }, kp = 1 },
    },
    [182] = { -- Herbalism
        { kind = "treatise", ids = { 95130 }, kp = 1 },
        { kind = "quest",    ids = { 93700, 93701, 93702, 93703, 93704 }, kp = 3, pool = true },
        { kind = "treasure", ids = { 81425, 81426, 81427, 81428, 81429 }, kp = 1 },
        { kind = "treasure", ids = { 81430 }, kp = 4 },
    },
    [773] = { -- Inscription
        { kind = "treatise", ids = { 95131 }, kp = 1 },
        { kind = "quest",    ids = { 93693 }, kp = 4, pool = true },
        { kind = "treasure", ids = { 93536, 93537 }, kp = 2 },
    },
    [755] = { -- Jewelcrafting
        { kind = "treatise", ids = { 95133 }, kp = 1 },
        { kind = "quest",    ids = { 93694 }, kp = 3, pool = true },
        { kind = "treasure", ids = { 93538, 93539 }, kp = 2 },
    },
    [165] = { -- Leatherworking
        { kind = "treatise", ids = { 95134 }, kp = 1 },
        { kind = "quest",    ids = { 93695 }, kp = 2, pool = true },
        { kind = "treasure", ids = { 93540, 93541 }, kp = 2 },
    },
    [186] = { -- Mining
        { kind = "treatise", ids = { 95135 }, kp = 1 },
        { kind = "quest",    ids = { 93705, 93706, 93707, 93708, 93709 }, kp = 3, pool = true },
        { kind = "treasure", ids = { 88673, 88674, 88675, 88676, 88677 }, kp = 1 },
        { kind = "treasure", ids = { 88678 }, kp = 3 },
    },
    [393] = { -- Skinning
        { kind = "treatise", ids = { 95136 }, kp = 1 },
        { kind = "quest",    ids = { 93710, 93711, 93712, 93713, 93714 }, kp = 3, pool = true },
        { kind = "treasure", ids = { 88534, 88549, 88536, 88537, 88530 }, kp = 1 },
        { kind = "treasure", ids = { 88529 }, kp = 3 },
    },
    [197] = { -- Tailoring
        { kind = "treatise", ids = { 95137 }, kp = 1 },
        { kind = "quest",    ids = { 93696 }, kp = 2, pool = true },
        { kind = "treasure", ids = { 93542, 93543 }, kp = 2 },
    },
}

-- Every quest ID above, so the learned list does not show them twice
ns.KNOWN_QUESTS = {}
do
    local known = ns.KNOWN_QUESTS
    for id in pairs(ns.PREY) do known[id] = true end
    known[ns.DELVES.weeklyQuest], known[ns.DELVES.bountyQuest] = true, true
    for _, w in ipairs(ns.WEEKLIES) do for _, id in ipairs(w.ids) do known[id] = true end end
    for _, sources in pairs(ns.PROFESSIONS) do
        for _, s in ipairs(sources) do for _, id in ipairs(s.ids) do known[id] = true end end
    end
end

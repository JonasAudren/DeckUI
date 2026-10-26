local ADDON, ns = ...

-------------------------------------------------------------------
-- Mists of Pandaria's week, by ID (in place of data.lua)
-------------------------------------------------------------------
-- MoP's week is raids, valor and conquest, the world bosses, the charm
-- or seal weekly and the challenge-mode medals - no vault, keystone,
-- delves, hunts or knowledge. Checked against Blizzard's client data for
-- wow_classic 5.5.4 on wago.tools (2026-10-26): every currency below is in
-- CurrencyTypes under this name, every quest ID in QuestV2 (the quests
-- whose completion the client tracks). QuestV2 carries no titles in
-- Classic, so the world bosses' names are ours - /week record confirms
-- an ID in game: the kill flags its quest and the chat names it.
-- Raids and challenge modes need no IDs: lockouts, Raid Finder wings and
-- the challenge-mode maps come from the game's own lists.
-------------------------------------------------------------------

-- Weekly caps are not kept here: the currency info says whether one is
-- weekly (maxWeeklyQuantity) - valor and conquest have one.
ns.MISTS_CURRENCIES = {
    396,   -- Valor Points
    390,   -- Conquest Points
    395,   -- Justice Points
    1901,  -- Honor Points
    738,   -- Lesser Charm of Good Fortune
    697,   -- Elder Charm of Good Fortune (5.0, bonus rolls)
    752,   -- Mogu Rune of Fate (5.2)
    776,   -- Warforged Seal (5.4)
    777,   -- Timeless Coin
    789,   -- Bloody Coin
}
ns.VALOR, ns.CONQUEST = 396, 390

-- The world bosses: one kill a week counts for loot, flagged by a hidden
-- quest. In the order they came.
ns.WORLD_BOSSES = {
    { quest = 32099, name = "Sha of Anger" },
    { quest = 32098, name = "Galleon" },
    { quest = 32518, name = "Nalak" },
    { quest = 32519, name = "Oondasta" },
    { quest = 33117, name = "The Celestials" },
    { quest = 33118, name = "Ordos" },
}

-- Week's shared code asks these; Mists has none of them
ns.WEEKLIES = {}

-- Every quest ID above, so the learned list does not show them twice
ns.KNOWN_QUESTS = {}
for _, b in ipairs(ns.WORLD_BOSSES) do ns.KNOWN_QUESTS[b.quest] = true end

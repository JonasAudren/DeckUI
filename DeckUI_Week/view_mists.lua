local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Mists of Pandaria: the table's columns and details (before window.lua)
-------------------------------------------------------------------
-- window.lua keeps the frame, the rows, the lockouts and the weekly
-- quests; Mists brings what sits between them. Columns: raid bosses down
-- this week, valor and conquest of their weekly caps, world bosses, gold
-- medals in challenge modes. The helpers (colours, Count, Icon) come from
-- window.lua as ns.Fmt, read when a row is filled - window.lua loads after.
-------------------------------------------------------------------
ns.COLS = {
    { key = "name",     title = "Character",   w = 150 },
    { key = "ilvl",     title = "ilvl",        w = 38, tip = "Average item level (equipped)." },
    { key = "raid",     title = "Raids",       w = 60, tip = "Raid bosses down this week, all raids and difficulties, Raid Finder included." },
    { key = "valor",    title = "Valor",       w = 84, tip = "Valor Points earned this week, of the weekly cap." },
    { key = "conquest", title = "Conquest",    w = 84, tip = "Conquest Points earned this week, of the weekly cap." },
    { key = "bosses",   title = "World bosses", w = 80, tip = "World bosses killed this week (one loot kill each)." },
    { key = "medals",   title = "Challenge",   w = 66, tip = "Challenge modes with a gold medal, of all of them." },
    { key = "dailies",  title = "Dailies",     w = 50, tip = "Daily quests done today." },
    { key = "quests",   title = "Weeklies",    w = 58, tip = "Weekly quests done, of the ones listed (hidden ones not counted)." },
}

local GOLD_MEDAL = CHALLENGE_MEDAL_GOLD or 3
local MEDALS = { "Bronze", "Silver", "Gold", "Platinum" }

local function Find(list, id)
    for _, c in ipairs(list or {}) do
        if c.id == id then return c end
    end
end

-- "earned/cap" of a currency's week; the amount when it has no weekly cap
local function Week(snap, stale, id)
    local F, c = ns.Fmt, Find(snap.currencies, id)
    if not c then return F.GREY .. "-|r" end
    if not c.weekMax then return BreakUpLargeNumbers(c.quantity or 0) end
    return F.Count(stale and 0 or (c.weekEarned or 0), c.weekMax)
end

local function LiveLocks(snap)
    local list = {}
    for _, l in ipairs(snap.locks or {}) do
        if not l.resetAt or l.resetAt > time() then list[#list + 1] = l end
    end
    return list
end

local function BossesDone(snap, stale)
    local n = 0
    if not stale then
        for _, b in ipairs(ns.WORLD_BOSSES) do
            if snap.worldBosses and snap.worldBosses[b.quest] then n = n + 1 end
        end
    end
    return n
end

-- today's dailies; a snapshot from before the daily reset counts none
local function DailiesToday(snap)
    local d = snap.dailies
    if not d or (d.resetAt and time() >= d.resetAt) then return 0, {} end
    return d.total or 0, d.groups or {}
end

local function GoldMedals(snap)
    local n = 0
    for _, m in ipairs(snap.challenges or {}) do
        if (m.medal or 0) >= GOLD_MEDAL then n = n + 1 end
    end
    return n, #(snap.challenges or {})
end

function ns.FillCells(c, snap, stale)
    local F = ns.Fmt
    local killed = 0
    for _, l in ipairs(LiveLocks(snap)) do
        if l.raid then killed = killed + (l.killed or 0) end
    end
    c.raid:SetText(killed > 0 and killed or (F.GREY .. "0|r"))
    c.valor:SetText(Week(snap, stale, ns.VALOR))
    c.conquest:SetText(Week(snap, stale, ns.CONQUEST))
    c.bosses:SetText(F.Count(BossesDone(snap, stale), #ns.WORLD_BOSSES))
    local gold, total = GoldMedals(snap)
    c.medals:SetText(total > 0 and F.Count(gold, total) or (F.GREY .. "-|r"))
    local today = DailiesToday(snap)
    c.dailies:SetText(today > 0 and (F.GREEN .. today .. "|r") or (F.GREY .. "0|r"))
end

-- left, above the lockouts: the two weekly caps
function ns.DetailsTop(L, snap, stale)
    L:Heading("Weekly caps")
    L:Line("Valor Points", Week(snap, stale, ns.VALOR))
    L:Line("Conquest Points", Week(snap, stale, ns.CONQUEST))
end

local function Medal(medal)
    local texture = CHALLENGE_MEDAL_TEXTURES_SMALL and CHALLENGE_MEDAL_TEXTURES_SMALL[medal]
    local name = MEDALS[medal]
    if not name then return ns.Fmt.GREY .. "no medal|r" end
    return (texture and ("|T%s:14:14|t "):format(texture) or "") .. name
end

-- right: today's dailies, reputation, world bosses, challenge modes, currencies
function ns.DetailsRight(R, snap, stale)
    local F = ns.Fmt
    local today, groups = DailiesToday(snap)
    R:Heading("Today")
    R:Line("Daily quests done", today > 0 and (F.GREEN .. today .. "|r") or (F.GREY .. "none yet|r"))
    local names = {}
    for group in pairs(groups) do names[#names + 1] = group end
    table.sort(names)
    for _, group in ipairs(names) do
        R:Line(F.GREY .. "    " .. (group ~= "" and group or "Other") .. "|r", groups[group])
    end

    if snap.reputations and #snap.reputations > 0 then
        R:Heading("Reputation")
        for _, f in ipairs(snap.reputations) do
            local color = ("|cff%02x%02x%02x"):format(f.r * 255, f.g * 255, f.b * 255)
            local progress = f.cur >= f.max and "" or ("  %s%s/%s|r"):format(F.GREY,
                BreakUpLargeNumbers(f.cur), BreakUpLargeNumbers(f.max))
            R:Line(f.name, color .. (f.standing or "") .. "|r" .. progress)
        end
    end

    R:Heading("World bosses")
    for _, b in ipairs(ns.WORLD_BOSSES) do
        local done = not stale and snap.worldBosses and snap.worldBosses[b.quest]
        R:Line(b.name, done and (F.GREEN .. "done|r") or "open")
    end

    if snap.challenges and #snap.challenges > 0 then
        R:Heading("Challenge modes")
        for _, m in ipairs(snap.challenges) do
            local best = m.best and (F.GREY .. ("%d:%02d"):format(math.floor(m.best / 60), m.best % 60) .. "|r  ") or ""
            R:Line(m.name, best .. Medal(m.medal))
        end
    end

    R:Currencies("Currencies", snap.currencies, stale)
end

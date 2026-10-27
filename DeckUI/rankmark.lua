local D = DeckUI

-------------------------------------------------------------------
-- Rank marks: elite, rare and boss before an enemy's name
-------------------------------------------------------------------
-- Owner's wish 2026-10-27: FFXIV puts an emblem before the name of the
-- enemies that matter (hunt marks, FATE bosses); here a diamond badge
-- before the names DeckUI draws - the FFXIV nameplates, the enemy list
-- and the FF/XIV target and focus bars (DeckUI_Orbs). DeckUIDB.rankMarks.
--
--   elite        gold diamond
--   rare         silver diamond with a star
--   rare elite   gold diamond with a star
--   boss         red diamond with a gold crown, a little larger
--
-- The rank comes from UnitClassification and, in retail, UnitIsBossMob;
-- a level of -1 on an elite is a boss too (dungeon bosses in Mists).
-- Any of these may be secret for some units: a secret answer means no
-- mark, never a guess. Textures from make-status-masks.py.
-------------------------------------------------------------------
local TEX = "Interface\\AddOns\\DeckUI\\textures\\rank_"

local LOOK = {
    elite     = { fill = { 1, 0.78, 0.25 } },
    rare      = { fill = { 0.78, 0.84, 0.95 }, glyph = "star", glyphColor = { 0.1, 0.12, 0.18 } },
    rareelite = { fill = { 1, 0.78, 0.25 }, glyph = "star", glyphColor = { 0.25, 0.1, 0.02 } },
    boss      = { fill = { 0.8, 0.12, 0.1 }, glyph = "crown", glyphColor = { 1, 0.85, 0.35 }, grow = 1.25 },
}

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- "boss", "rareelite", "rare", "elite" or nil
function D.UnitRank(unit)
    if DeckUIDB and DeckUIDB.rankMarks == false then return nil end
    if not unit or not UnitExists(unit) or Plain(UnitIsPlayer(unit)) then return nil end
    local class = Plain(UnitClassification(unit))
    if UnitIsBossMob and Plain(UnitIsBossMob(unit)) then return "boss" end
    if class == "worldboss" then return "boss" end
    if class == "elite" or class == "rareelite" then
        local level = Plain(UnitLevel(unit))
        if level == -1 and class == "elite" then return "boss" end
        return class
    end
    if class == "rare" then return class end
    return nil
end

-- a badge of `size` pixels; mark:SetRank(rank) shows it (and returns true)
-- or hides it for nil
local function SetRank(mark, rank)
    local look = rank and LOOK[rank]
    if not look then
        mark:Hide()
        return false
    end
    local s = mark.size * (look.grow or 1)
    mark:SetSize(s, s)
    mark.fill:SetVertexColor(look.fill[1], look.fill[2], look.fill[3])
    if look.glyph then
        mark.glyph:SetTexture(TEX .. look.glyph)
        mark.glyph:SetSize(s * 0.62, s * 0.62)
        local c = look.glyphColor
        mark.glyph:SetVertexColor(c[1], c[2], c[3])
        mark.glyph:Show()
    else
        mark.glyph:Hide()
    end
    mark:Show()
    return true
end

function D.RankMark(parent, size)
    local mark = CreateFrame("Frame", nil, parent)
    mark.size = size
    mark:SetSize(size, size)
    local edge = mark:CreateTexture(nil, "ARTWORK", nil, 0)
    edge:SetTexture(TEX .. "diamond")
    edge:SetVertexColor(0, 0, 0, 0.9)
    edge:SetPoint("TOPLEFT", -2, 2)
    edge:SetPoint("BOTTOMRIGHT", 2, -2)
    mark.fill = mark:CreateTexture(nil, "ARTWORK", nil, 1)
    mark.fill:SetTexture(TEX .. "diamond")
    mark.fill:SetAllPoints()
    -- a lighter top half, the gloss FFXIV's emblems have
    local shine = mark:CreateTexture(nil, "ARTWORK", nil, 2)
    shine:SetTexture(TEX .. "diamond")
    shine:SetTexCoord(0, 1, 0, 0.5)
    shine:SetPoint("TOPLEFT")
    shine:SetPoint("RIGHT")
    shine:SetPoint("BOTTOM", mark, "CENTER")
    shine:SetVertexColor(1, 1, 1, 0.25)
    mark.glyph = mark:CreateTexture(nil, "ARTWORK", nil, 3)
    mark.glyph:SetPoint("CENTER")
    mark.SetRank = SetRank
    mark:Hide()
    return mark
end

-- whoever draws marks registers a refresh here; the checkbox calls them
local listeners = {}
function D.OnRankMarks(fn) listeners[#listeners + 1] = fn end
function D.ApplyRankMarks()
    for _, fn in ipairs(listeners) do pcall(fn) end
end

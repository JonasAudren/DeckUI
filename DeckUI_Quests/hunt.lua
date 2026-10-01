local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- The hunt table: which targets an achievement still needs
-------------------------------------------------------------------
-- Asked for by the owner (2026-10-01) in place of Plumber's HuntTable.
-- Plumber keeps a hand-made table of 94 hunt quests (questID ->
-- difficulty, criterion) and writes its icons into Blizzard's map pins.
-- Neither is done here:
--  - no table: the open criteria of the hunt achievements are read live
--    and matched against the offer's title - the way Plumber built its
--    table in the first place (SharedData.lua). Both come in the client's
--    language. Only the achievement IDs are fixed;
--  - no field written on a pin: a mark of our own is a child frame of
--    the pin, kept in our table keyed by pin, so it moves, scales and
--    hides with it. Blizzard's pin is only read (questID, title).
--
-- A target can be on more than one list (normal, hard, nightmare), and
-- an offer does not say its difficulty, so the mark names the lists that
-- still miss the target instead of guessing which one this offer serves.
--
-- The hunt table is the adventure map in CovenantMissionFrame.MapTab
-- (Blizzard_GarrisonUI); its quest-offer provider is post-hooked
-- (hooksecurefunc, which keeps Blizzard's call untainted) on
-- RefreshAllData, the call that lays out the offers.
-------------------------------------------------------------------
local LISTS = {
    { id = 42701, label = "N" },    -- normal targets
    { id = 42702, label = "H" },    -- hard
    { id = 42703, label = "NM" },   -- nightmare
    { id = 63451, label = "NM" },   -- targets added in 12.1 (Plumber files them as nightmare)
    { id = 63452, label = "NM" },
}

local function Plain(v) return not (issecretvalue and issecretvalue(v)) end

-- quest titles and criteria disagree on apostrophes (Jan'alai / Janalai)
-- (two plain replacements: the typographic one is three bytes, which a
-- character class would take apart)
local function Norm(s) return (s:gsub("\226\128\153", ""):gsub("'", ""):lower()) end

-- name -> { "N", "NM", ... } for every target some list still misses
local function OpenTargets()
    local open = {}
    for _, list in ipairs(LISTS) do
        local ok, num = pcall(GetAchievementNumCriteria, list.id)
        for i = 1, (ok and num) or 0 do
            local name, _, completed = GetAchievementCriteriaInfo(list.id, i)
            if name and name ~= "" and not completed and Plain(name) then
                local key = Norm(name)
                open[key] = open[key] or {}
                local labels = open[key]
                if labels[#labels] ~= list.label then labels[#labels + 1] = list.label end
            end
        end
    end
    return open
end

local function Missing(title, open)
    if not title or not Plain(title) then return nil end
    title = Norm(title)
    for name, labels in pairs(open) do
        if title:find(name, 1, true) then return labels end
    end
end

-------------------------------------------------------------------
-- The marks
-------------------------------------------------------------------
local marks = {}   -- pin -> our frame

local function Mark(pin)
    local m = marks[pin]
    if m then return m end
    m = CreateFrame("Frame", nil, pin)
    m:SetSize(18, 18)
    m:SetPoint("BOTTOMLEFT", pin, "TOPRIGHT", -8, -10)
    m:SetFrameLevel(pin:GetFrameLevel() + 5)
    m.star = m:CreateTexture(nil, "OVERLAY")
    m.star:SetAllPoints()
    if C_Texture.GetAtlasInfo("auctionhouse-icon-favorite") then
        m.star:SetAtlas("auctionhouse-icon-favorite")
    else
        m.star:SetTexture("Interface\\Common\\ReputationStar")
        m.star:SetTexCoord(0, 0.5, 0, 0.5)
    end
    m.text = m:CreateFontString(nil, "OVERLAY")
    m.text:SetFont(D.FONT, 11, "OUTLINE")
    m.text:SetPoint("TOP", m, "BOTTOM", 0, 1)
    m.text:SetTextColor(1, 0.82, 0)
    marks[pin] = m
    return m
end

local lastCount, lastMarked = 0, 0

local function MarkAll(map)
    for _, m in pairs(marks) do m:Hide() end
    if not (DeckQuestsDB and DeckQuestsDB.huntMarks) then return end
    local open = OpenTargets()
    lastCount, lastMarked = 0, 0
    for pin in map:EnumeratePinsByTemplate("AdventureMap_QuestOfferPinTemplate") do
        lastCount = lastCount + 1
        local labels = Missing(pin.title, open)
        if labels then
            local m = Mark(pin)
            m.text:SetText(table.concat(labels, " "))
            m:Show()
            lastMarked = lastMarked + 1
        end
    end
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_GarrisonUI", function()
    local map = CovenantMissionFrame and CovenantMissionFrame.MapTab
    if not (map and map.dataProviders) then return end
    for provider in pairs(map.dataProviders) do
        if provider.AddQuest and provider.RefreshAllData then
            hooksecurefunc(provider, "RefreshAllData", function(self, fromOnShow)
                -- the call from OnShow only clears; the offers follow
                if not fromOnShow then MarkAll(self:GetMap()) end
            end)
            ns.huntHooked = true
        end
    end
end)

-- /quests hunts: what the marks are built from
function ns.PrintHunts()
    local open, n = OpenTargets(), 0
    for name, labels in pairs(open) do
        n = n + 1
        if n <= 12 then print(("  %s: %s"):format(name, table.concat(labels, " "))) end
    end
    print(("DeckUI Quests: %d hunt targets still open, hunt table hooked=%s, last refresh %d offers / %d marked"):format(
        n, tostring(ns.huntHooked or false), lastCount, lastMarked))
end

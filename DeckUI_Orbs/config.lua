local ADDON, ns = ...
local D = DeckUI

local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
local min = function(v) return math.floor(v / 60 + 0.5) .. " min" end
local db  = function() return DeckOrbsDB end

D.RegisterModule("Orbs", {
    title = "Orbs",
    build = function(c)
        D.Slider(c, "Size (this device)", -6, 0.6, 1.6, 0.05, pct, ns.DeviceDB, "scale", ns.SetScale)
        D.Slider(c, "Opacity",     -70,  0.3, 1.0, 0.05, pct, db, "alpha", ns.SetAlpha)
        D.Slider(c, "Brightness",  -134, 0.0, 0.5, 0.05, pct, db, "glow",  ns.SetGlow)
        D.Slider(c, "Buffs up to duration (needs /reload)", -198, 60, 900, 60, min,
            db, "buffMaxDuration", function(v)
                ns.SetBuffMaxDuration(v)
                print("DeckUI Orbs: buff duration saved - takes effect after /reload.")
            end)

        local hpBtn = D.Button(c, "Health text", -262, function() end)
        local function HpLabel() return "Health text: " .. ns.HP_TEXT_NAMES[DeckOrbsDB.hpText or "percent"] end
        hpBtn:SetScript("OnClick", function(b) ns.CycleHpText(); b:SetText(HpLabel()) end)
        function hpBtn:Refresh() self:SetText(HpLabel()) end
        c.widgets = c.widgets or {}
        table.insert(c.widgets, hpBtn)

        -- two buttons in one row: health text on the left, the style of
        -- player and target (orbs or Final Fantasy's bars) on the right
        local STYLE_NAMES = { orbs = "Orbs", ff = "Final Fantasy" }
        hpBtn:SetWidth(148)
        hpBtn:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
        hpBtn:ClearAllPoints()
        hpBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -262)
        local styleBtn = D.Button(c, "Style", -262, function() end)
        styleBtn:SetWidth(148)
        styleBtn:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
        styleBtn:ClearAllPoints()
        styleBtn:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -262)
        local function StyleLabel() return "Style: " .. STYLE_NAMES[DeckOrbsDB.style or "orbs"] end
        styleBtn:SetScript("OnClick", function(b)
            DeckOrbsDB.style = (DeckOrbsDB.style == "ff") and "orbs" or "ff"
            b:SetText(StyleLabel())
            print("DeckUI Orbs: player and target as " .. STYLE_NAMES[DeckOrbsDB.style] .. " after /reload.")
        end)
        function styleBtn:Refresh() self:SetText(StyleLabel()) end
        table.insert(c.widgets, styleBtn)

        D.Checkbox(c, "Show cast in orb",       -306, db, "showCast",       ns.SetCastShown)
        D.Checkbox(c, "Show buffs and debuffs", -334, db, "showAuras",      ns.SetAurasShown)
        D.Checkbox(c, "Only own debuffs on target", -362, db, "ownDebuffsOnly", ns.SetOwnDebuffsOnly)
        D.Checkbox(c, "Show focus frame",       -390, db, "showFocus",      ns.SetFocusShown)
        D.Checkbox(c, "Show boss frames (hides Blizzard's)", -418, db, "showBoss", ns.SetBossShown)
        D.Checkbox(c, "Class resource dots on player orb", -446, db, "showClassPower", ns.SetClassPowerShown)
        D.Checkbox(c, "Announce target (big name)",   -474, db, "announceTarget", ns.SetAnnounceTarget)
    end,
})

-- The party list has a tab of its own: the Orbs tab is full, and the
-- window cannot grow on the Deck's 800-pixel screen. The raid frames got
-- theirs when they gained their settings (2026-10-02).
D.RegisterModule("Group", {
    title = "Group",
    build = function(c)
        D.Label(c, "Party list (Final Fantasy style)", -6, 15)
        -- test mode beside the heading: five rows of yourself, session only
        local partyTest = D.Button(c, "Test", -2, function()
            ns.SetPartyTest(not ns.partyTest)
        end)
        partyTest:SetWidth(70)
        partyTest:ClearAllPoints()
        partyTest:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -2)
        D.Checkbox(c, "Show the party list (hides Blizzard's; /reload)", -28, db, "showParty", function(v)
            print("DeckUI Orbs: the party list " .. (v and "appears" or "goes") .. " after /reload.")
        end)
        D.Checkbox(c, "Side by side instead of stacked (this device)", -56, ns.DeviceDB, "partyAcross", function()
            ns.ApplyPartyLayout()
        end)
        D.Slider(c, "Party list size (this device)", -84, 0.6, 1.6, 0.05, pct, ns.DeviceDB, "partyScale", function(v)
            ns.DeviceDB().partyScale = v
            ns.ApplyPartyScale()
        end)
    end,
})

-- A button that steps through a list of values, half the panel wide;
-- side "left" or "right". get/set read and write the value.
local function Cycle(c, y, side, label, order, names, get, set)
    local b = D.Button(c, label, y, function() end)
    b:SetWidth(148)
    b:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
    b:ClearAllPoints()
    if side == "left" then
        b:SetPoint("TOPLEFT", c, "TOPLEFT", 8, y)
    else
        b:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, y)
    end
    local function Text() return label .. ": " .. (names[get()] or tostring(get())) end
    b:SetScript("OnClick", function(self)
        local cur, nextValue = get(), order[1]
        for i, v in ipairs(order) do
            if v == cur then nextValue = order[i % #order + 1] end
        end
        set(nextValue)
        self:SetText(Text())
    end)
    function b:Refresh() self:SetText(Text()) end
    c.widgets = c.widgets or {}
    table.insert(c.widgets, b)
    return b
end

-- a shared raid setting through a Cycle button
local function RaidCycle(c, y, side, label, key, order, names, apply)
    return Cycle(c, y, side, label, order, names,
        function() return DeckOrbsDB[key] end,
        function(v) DeckOrbsDB[key] = v; apply() end)
end

local function Reload(what)
    return function() print("DeckUI Orbs: " .. what .. " - takes effect after /reload.") end
end

local look = function() ns.ApplyRaidLook() end
local layout = function() if ns.ApplyRaidLayout then ns.ApplyRaidLayout() end end
local function Counts()
    local t = {}
    for i = 0, 6 do t[i] = tostring(i) end
    return { 0, 1, 2, 3, 4, 5, 6 }, t
end
local function Percents(list)
    local names = {}
    for _, v in ipairs(list) do names[v] = math.floor(v * 100 + 0.5) .. "%" end
    return list, names
end

D.RegisterModule("Raid", {
    title = "Raid",
    build = function(c)
        D.Label(c, "Raid frames", -6, 15)
        -- a full raid of yourself, session only
        local raidTest = D.Button(c, "Test", -2, function()
            ns.SetRaidTest(not ns.raidTest)
        end)
        raidTest:SetWidth(70)
        raidTest:ClearAllPoints()
        raidTest:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -2)
        D.Checkbox(c, "Show the raid frames (hides Blizzard's; /reload)", -28, db, "showRaid", function(v)
            print("DeckUI Orbs: the raid frames " .. (v and "appear" or "go") .. " after /reload.")
        end)

        D.Slider(c, "Size (this device)", -60, 0.5, 1.4, 0.05, pct, ns.DeviceDB, "raidScale", function(v)
            ns.DeviceDB().raidScale = v
            ns.ApplyRaidScale()
        end)
        local px = function(v) return math.floor(v + 0.5) .. " px" end
        D.Slider(c, "Width (this device)", -124, 60, 140, 2, px, ns.DeviceDB, "raidW", function(v)
            ns.DeviceDB().raidW = v
            layout()
        end)
        D.Slider(c, "Height (this device)", -188, 30, 60, 2, px, ns.DeviceDB, "raidH", function(v)
            ns.DeviceDB().raidH = v
            layout()
        end)

        Cycle(c, -252, "left", "Groups", { false, true }, { [false] = "Columns", [true] = "Rows" },
            function() return ns.DeviceDB().raidRows and true or false end,
            function(v) ns.DeviceDB().raidRows = v; layout() end)
        RaidCycle(c, -252, "right", "Sort", "raidSort", { "group", "role", "class" },
            { group = "Group", role = "Role", class = "Class" }, layout)
        RaidCycle(c, -292, "left", "Bar", "raidColor", { "ff", "class" },
            { ff = "FF green", class = "Class" }, look)
        RaidCycle(c, -292, "right", "Health", "raidHpText", { "none", "percent", "short" },
            { none = "None", percent = "Percent", short = "1.2M" }, look)
        local counts, countNames = Counts()
        RaidCycle(c, -332, "left", "Debuffs", "raidDebuffs", counts, countNames, Reload("debuff count saved"))
        RaidCycle(c, -332, "right", "Own buffs", "raidBuffs", counts, countNames, Reload("buff count saved"))
        local bgs, bgNames = Percents({ 0.5, 0.6, 0.7, 0.8, 0.9, 1 })
        RaidCycle(c, -372, "left", "Background", "raidBgAlpha", bgs, bgNames, look)
        local ranges, rangeNames = Percents({ 0.2, 0.3, 0.4, 0.5, 0.6, 0.8 })
        RaidCycle(c, -372, "right", "Out of range", "raidRangeAlpha", ranges, rangeNames, look)

        D.Checkbox(c, "Frame the tile in the dispel colour", -412, db, "raidDispelGlow", look)
        D.Checkbox(c, "Red edge while a member has aggro", -440, db, "raidAggro", look)
        D.Checkbox(c, "Mana bar for healers", -468, db, "raidMana", look)
        D.Checkbox(c, "Role icons for tanks and healers", -496, db, "raidRoles", look)
        D.Checkbox(c, "Only debuffs you can dispel (/reload)", -524, db, "raidDispelOnly",
            Reload("debuff filter saved"))
        D.Hint(c, "Each tile is a small parameter bar like the Final Fantasy player frame: name in class colour, a thin health bar, debuffs top right, your buffs bottom right. The dispel frame shows only what you can dispel. Blizzard's raid tools on the left stay.", -556)
    end,
})

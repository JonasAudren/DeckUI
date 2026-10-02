local ADDON, ns = ...
local D = DeckUI

local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
local min = function(v) return math.floor(v / 60 + 0.5) .. " min" end
local db  = function() return DeckOrbsDB end

-- Moved to D.Flow 2026-10-02: explanations as tooltips, the two settings
-- that need a reload report to the panel's reload bar, and the boss frames
-- got their test button here (it was only /orbs boss).
local loaded = {}   -- settings that need a reload, as this session loaded them

local function Refreshing(button, label)
    function button:Refresh() self:SetText(label()) end
    return button
end

D.RegisterModule("Orbs", {
    title = "Orbs",
    build = function(c)
        loaded.style = loaded.style or DeckOrbsDB.style or "orbs"
        loaded.buff = loaded.buff or DeckOrbsDB.buffMaxDuration
        local f = D.Flow(c)
        c.widgets = c.widgets or {}

        f:Label("Size and look")
        f:Slider("Size (this device)", 0.6, 1.6, 0.05, pct, ns.DeviceDB, "scale", ns.SetScale)
        f:Slider("Opacity", 0.3, 1.0, 0.05, pct, db, "alpha", ns.SetAlpha)
        f:Slider("Brightness", 0.0, 0.5, 0.05, pct, db, "glow", ns.SetGlow,
            "How much the orbs glow from inside.")

        local STYLE_NAMES = { orbs = "Orbs", ff = "Final Fantasy" }
        local function HpLabel() return "Health: " .. ns.HP_TEXT_NAMES[DeckOrbsDB.hpText or "percent"] end
        local function StyleLabel() return "Style: " .. STYLE_NAMES[DeckOrbsDB.style or "orbs"] end
        local hpBtn, styleBtn = f:Pair(
            { text = "Health", title = "Health text", tip = "Percent, the full number, short (1.2M) or short with percent.",
              onClick = function(b) ns.CycleHpText(); b:SetText(HpLabel()) end },
            { text = "Style", title = "Style of player and target",
              tip = "Round orbs, or Final Fantasy's parameter bar for you and its wide bar for your target. Needs a reload.",
              onClick = function(b)
                  DeckOrbsDB.style = (DeckOrbsDB.style == "ff") and "orbs" or "ff"
                  b:SetText(StyleLabel())
                  D.NeedReload("orbs:style", DeckOrbsDB.style ~= loaded.style)
              end })
        table.insert(c.widgets, Refreshing(hpBtn, HpLabel))
        table.insert(c.widgets, Refreshing(styleBtn, StyleLabel))

        f:Gap(4)
        f:Label("On the frames")
        f:Checkbox("Cast in the orb", db, "showCast", ns.SetCastShown)
        f:Checkbox("Buffs and debuffs", db, "showAuras", ns.SetAurasShown)
        f:Checkbox("Only your own debuffs on the target", db, "ownDebuffsOnly", ns.SetOwnDebuffsOnly)
        f:Checkbox("Class resource dots on the player", db, "showClassPower", ns.SetClassPowerShown,
            "Combo points, holy power, runes and the like as dots on your orb or bar.")
        f:Checkbox("Announce a new target (big name)", db, "announceTarget", ns.SetAnnounceTarget)
        f:Slider("Buffs up to this duration", 60, 900, 60, min, db, "buffMaxDuration", function(v)
            ns.SetBuffMaxDuration(v)
            D.NeedReload("orbs:buffDuration", v ~= loaded.buff)
        end, "Longer buffs (food, flasks, raid buffs) stay off your frame. Needs a reload.")

        f:Label("Focus and bosses")
        f:Checkbox("Focus frame", db, "showFocus", ns.SetFocusShown)
        f:Checkbox("Boss frames (hide Blizzard's)", db, "showBoss", ns.SetBossShown)
        local bossBtn = f:Button("Test boss frames", function(b)
            ns.SetBossTest(not ns.bossTestOn)
            C_Timer.After(0, function() b:Refresh() end)
        end, "Five boss frames showing your target, to see size and place without a boss. Switches out of combat; also /orbs boss.")
        table.insert(c.widgets, Refreshing(bossBtn, function()
            return ns.bossTestOn and "End boss test" or "Test boss frames"
        end))
    end,
})

-- The party list has a tab of its own: the Orbs tab is full, and the
-- window cannot grow on the Deck's 800-pixel screen. The raid frames got
-- theirs when they gained their settings (2026-10-02).
-- A test button that says whether its test runs: label(on) gives the text
local function TestButton(f, c, label, isOn, toggle, tip)
    local b = f:Button(label(false), function(self)
        toggle()
        C_Timer.After(0, function() self:Refresh() end)
    end, tip)
    function b:Refresh() self:SetText(label(isOn())) end
    table.insert(c.widgets, b)
    return b
end

D.RegisterModule("Group", {
    title = "Group",
    build = function(c)
        if loaded.showParty == nil then loaded.showParty = DeckOrbsDB.showParty end
        local f = D.Flow(c)
        c.widgets = c.widgets or {}

        f:Label("Party list")
        f:Checkbox("Show the party list (hides Blizzard's)", db, "showParty", function(v)
            D.NeedReload("orbs:showParty", v ~= loaded.showParty)
        end, "Final Fantasy style rows: tanks, healers, damage, each with class icon, health and auras. Party only - in a raid the raid frames take over. Needs a reload.")
        TestButton(f, c, function(on) return on and "End party test" or "Test: five rows of you" end,
            function() return ns.partyTest end, function() ns.SetPartyTest(not ns.partyTest) end,
            "Shows the list with five copies of you, to see size and place. Switches out of combat; also /orbs test.")

        f:Gap(4)
        f:Label("Layout (this device)")
        f:Checkbox("Side by side instead of stacked", ns.DeviceDB, "partyAcross", function()
            ns.ApplyPartyLayout()
        end)
        f:Slider("Size", 0.6, 1.6, 0.05, pct, ns.DeviceDB, "partyScale", function(v)
            ns.DeviceDB().partyScale = v
            ns.ApplyPartyScale()
        end)
    end,
})

local look = function() ns.ApplyRaidLook() end
local layout = function() if ns.ApplyRaidLayout then ns.ApplyRaidLayout() end end

-- a shared raid setting for Flow:Cycles
local function RaidSetting(label, key, values, names, apply, tip)
    return { label = label, values = values, names = names, tip = tip,
             get = function() return DeckOrbsDB[key] end,
             set = function(v) DeckOrbsDB[key] = v; apply(v) end }
end

-- a raid setting that only takes effect after a reload
local function ReloadAfter(key)
    return function(v) D.NeedReload("orbs:" .. key, v ~= loaded[key]) end
end

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
        for _, key in ipairs({ "showRaid", "raidDebuffs", "raidBuffs", "raidDispelOnly" }) do
            if loaded[key] == nil then loaded[key] = DeckOrbsDB[key] end
        end
        local f = D.Flow(c)
        c.widgets = c.widgets or {}
        local px = function(v) return math.floor(v + 0.5) .. " px" end

        f:Label("Raid frames")
        f:Checkbox("Show the raid frames (hides Blizzard's)", db, "showRaid", ReloadAfter("showRaid"),
            "Each member a small parameter bar like the Final Fantasy player frame. Blizzard's raid tools on the left stay. Needs a reload.")
        TestButton(f, c, function(on) return on and "End raid test" or "Test: a raid of you" end,
            function() return ns.raidTest end, function() ns.SetRaidTest(not ns.raidTest) end,
            "Forty tiles of you, to see size and place. Switches out of combat; also /orbs raid.")

        f:Gap(4)
        f:Label("Size and arrangement (this device)")
        f:Slider("Size", 0.5, 1.4, 0.05, pct, ns.DeviceDB, "raidScale", function(v)
            ns.DeviceDB().raidScale = v
            ns.ApplyRaidScale()
        end)
        f:Slider("Width", 60, 140, 2, px, ns.DeviceDB, "raidW", function(v)
            ns.DeviceDB().raidW = v
            layout()
        end)
        f:Slider("Height", 30, 60, 2, px, ns.DeviceDB, "raidH", function(v)
            ns.DeviceDB().raidH = v
            layout()
        end)
        f:Cycles(
            { label = "Groups", values = { false, true }, names = { [false] = "Columns", [true] = "Rows" },
              tip = "One column per raid group, or one row per group.",
              get = function() return ns.DeviceDB().raidRows and true or false end,
              set = function(v) ns.DeviceDB().raidRows = v; layout() end },
            RaidSetting("Sort", "raidSort", { "group", "role", "class" },
                { group = "Group", role = "Role", class = "Class" }, layout,
                "By group keeps the groups the raid leader set; by role or class fills the grid from the whole raid."))

        f:Gap(4)
        f:Label("Look")
        f:Cycles(
            RaidSetting("Bar", "raidColor", { "ff", "class" }, { ff = "FF green", class = "Class" }, look),
            RaidSetting("Health", "raidHpText", { "none", "percent", "short" },
                { none = "None", percent = "Percent", short = "1.2M" }, look))
        local bgs, bgNames = Percents({ 0.5, 0.6, 0.7, 0.8, 0.9, 1 })
        local ranges, rangeNames = Percents({ 0.2, 0.3, 0.4, 0.5, 0.6, 0.8 })
        f:Cycles(
            RaidSetting("Background", "raidBgAlpha", bgs, bgNames, look),
            RaidSetting("Out of range", "raidRangeAlpha", ranges, rangeNames, look,
                "How see-through a member out of your range is."))
        f:Checkbox("Frame the tile in the dispel colour", db, "raidDispelGlow", look,
            "Shown only for debuffs you can dispel, in the colour of their type.")
        f:Checkbox("Red edge while a member has aggro", db, "raidAggro", look)
        f:Checkbox("Mana bar for healers", db, "raidMana", look)
        f:Checkbox("Role icons for tanks and healers", db, "raidRoles", look)

        f:Gap(4)
        f:Label("Auras (need a reload)")
        local counts, countNames = Counts()
        f:Cycles(
            RaidSetting("Debuffs", "raidDebuffs", counts, countNames, ReloadAfter("raidDebuffs"),
                "Top right on the tile."),
            RaidSetting("Own buffs", "raidBuffs", counts, countNames, ReloadAfter("raidBuffs"),
                "Bottom right: your heals over time and shields, up to two minutes long."))
        f:Checkbox("Only debuffs you can dispel", db, "raidDispelOnly", ReloadAfter("raidDispelOnly"))
    end,
})

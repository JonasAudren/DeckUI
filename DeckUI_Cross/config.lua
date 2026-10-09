local ADDON, ns = ...
local D = DeckUI

local db = function() return DeckCrossDB end
local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end

-- Moved to D.Flow 2026-10-02: explanations as tooltips, the two set-up
-- buttons side by side, the stance bar, the assistant indicator and the
-- Deck-only switch together under "Extras".
D.RegisterModule("Cross", {
    title = "Cross",
    build = function(c)
        local f = D.Flow(c)
        c.widgets = c.widgets or {}

        f:Hint("The crosses show Action Bar 1 (with stance and vehicle paging) and Action Bar 2. On the PC your own keys for those bars drive them.")

        f:Label("Controller (Steam Deck)")
        f:Pair(
            { text = "Set up gamepad", onClick = ns.SetupGamepad,
              tip = "Turns the gamepad on and makes LT Shift and RT Ctrl - the two halves of the crosses. With \"Keep the gamepad set up by itself\" below this happens on its own." },
            { text = "Default bindings", onClick = ns.ApplyDefaultBindings,
              tip = "Writes the defaults into your saved key bindings (asks first). Usually not needed any more: \"Default keys on empty buttons\" below gives them every session without saving." })
        f:Checkbox("Keep the gamepad set up by itself", db, "autoGamepad", function(v)
            if v then ns.EnsureGamepad() end
        end, "The game shares the gamepad settings between devices, so after the PC the Deck lost LT = Shift and RT = Ctrl. DeckUI checks them at login and whenever they change, and puts them back. Steam Deck only.")
        f:Checkbox("Default keys on empty buttons", db, "padDefaults", function() ns.ApplyBindings() end,
            "A jump, X interact, B game menu, Y character, D-pad targets - on every controller button you have not bound yourself, for this session only. Nothing is written into your key bindings, so the PC cannot take them away.")
        f:Checkbox("Quick menu: hold RB", db, "quickMenu", ns.SetQuickMenu,
            "While RB is held, the D-pad and A/B/X/Y open the windows chosen below. Steam Deck only.")
        -- what each of the eight buttons opens: one stepping button per slot
        local values, names = {}, {}
        for _, command in ipairs(ns.QUICK_COMMANDS) do
            if command == "NONE" or ns.QuickCommandKnown(command) then
                values[#values + 1] = command
                names[command] = ns.QUICK_COMMAND_INFO[command].label
            end
        end
        local function Slot(i)
            return { label = ns.QUICK_SLOT_NAMES[i], values = values, names = names,
                     tip = "Click to step to the next window for this button.",
                     get = function() return DeckCrossDB.quickEntries[i] end,
                     set = function(v) DeckCrossDB.quickEntries[i] = v; ns.ApplyQuickEntries() end }
        end
        DeckCrossDB.quickEntries = DeckCrossDB.quickEntries or CopyTable(ns.QUICK_DEFAULTS)
        for row = 0, 3 do f:Cycles(Slot(row * 2 + 1), Slot(row * 2 + 2)) end
        f:Checkbox("Ability menu on B: Action Bar 4", db, "abilityMenu", ns.SetAbilityMenu,
            "Tap B: the first seven slots of Action Bar 4 show, the D-pad and Y, A, X use one - mounts, toys, items, anything you put on that bar. B again closes it. On the Deck Action Bar 4 is hidden then and B no longer opens the game menu (Start does); the PC keeps Action Bar 4 as a bar. Steam Deck only.")
        f:Checkbox("LB + D-pad up/down zooms the camera", db, "lbZoom", ns.SetLBZoom,
            "LB becomes Alt - the only way the game combines LB with another button - so it is no longer a button of its own. Hold for a smooth zoom, tap for one step.")

        f:Gap(4)
        f:Label("Look")
        f:Slider("Size (this device)", 0.6, 1.6, 0.05, pct, ns.DeviceDB, "scale", ns.SetScale)
        -- The opacity slider only means anything while dimming is on, so it
        -- follows the checkbox above it rather than sitting there looking
        -- live. Refresh is extended instead of replaced, so the value still
        -- loads the way every other widget loads.
        local oocSlider
        f:Checkbox("Dim the crosses when idle", db, "dimWhenIdle", function(v)
            ns.SetDimWhenIdle(v)
            if oocSlider then
                if v then oocSlider:Enable() else oocSlider:Disable() end
            end
        end, "Out of combat and untouched for a few seconds, the crosses fade to the opacity below.")
        oocSlider = f:Slider("Out-of-combat opacity", 0.1, 1.0, 0.05, pct, db, "oocAlpha", ns.SetOocAlpha)
        local loadValue = oocSlider.Refresh
        function oocSlider:Refresh()
            loadValue(self)
            if DeckCrossDB.dimWhenIdle then self:Enable() else self:Disable() end
        end
        f:Checkbox("Show button labels", db, "showLabels", function(v) ns.SetLabelsShown(v) end,
            "Controller glyphs on the Steam Deck, your key names on the PC.")
        f:Checkbox("Hide the Blizzard bars the crosses mirror", db, "hideBlizzardBars",
            function(v) ns.SetBlizzardBarsHidden(v) end, "So nothing shows twice. Your keys keep working.")

        f:Gap(4)
        f:Label("Extras")
        f:Checkbox("Stance bar at the crosses", db, "stanceBar", function(v) ns.SetStanceBar(v) end,
            "Forms, stances and auras as round buttons between the middle crosses, in place of Blizzard's bar. On the Steam Deck LB + X/Y/B/A picks one, LB + D-pad left/right steps through them (LB becomes Alt).")
        f:Checkbox("Show what the assistant will cast next", db, "showAssist",
            function(v) ns.SetAssistShown(v) end,
            "Green: castable now. Grey with a swirl: waiting is right. Needs the assistant on one of your action bars; move it with /deck unlock.")
        -- a hub setting, so the module's stand-in page has it too while the module is off
        f:Checkbox("Cross hotbar only on Steam Deck", function() return DeckUIDB end, "crossDeckOnly",
            function(v) D.SetCrossDeckOnly(v) end, "Keeps the crosses off on the PC.")
    end,
})

-- Action bars 3-8 in FFXIV's look (bars.lua): a page of their own
D.RegisterModule("Bars", {
    title = "Bars",
    build = function(c)
        local f = D.Flow(c)
        c.widgets = c.widgets or {}
        f:Hint("Each bar you tick here replaces Blizzard's: square slots in Final Fantasy's look, your keys in the corner. Fill them as always by dragging.")

        local apply = function() ns.ApplyBars() end
        f:Slider("Size (this device)", 0.6, 1.6, 0.05, pct, ns.DeviceDB, "barScale", function(v)
            ns.DeviceDB().barScale = v
            apply()
        end)

        local names = {}
        for _, per in ipairs(ns.BAR_LAYOUTS) do
            names[per] = per == 12 and "one row" or per == 1 and "one column" or (per .. " per row")
        end
        for n = 3, 8 do
            local bar = function() return ns.BarSettings(n) end
            f:Checkbox("Action Bar " .. n, bar, "shown", apply,
                n == 4 and "On the Steam Deck with the ability menu on, this bar lives in the menu on B instead." or nil)
            f:Cycles({ label = "Layout", values = ns.BAR_LAYOUTS, names = names,
                       get = function() return ns.BarSettings(n).perRow end,
                       set = function(v) ns.BarSettings(n).perRow = v; apply() end })
        end
    end,
})

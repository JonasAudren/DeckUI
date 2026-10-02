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
              tip = "Turns the gamepad on and makes LT Shift and RT Ctrl - the two halves of the crosses. Once per device." },
            { text = "Default bindings", onClick = ns.ApplyDefaultBindings,
              tip = "A jump, X interact, B game menu, Y character, D-pad cycles targets. Asks first and lists what it would replace." })
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

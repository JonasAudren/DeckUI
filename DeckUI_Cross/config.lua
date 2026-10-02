local ADDON, ns = ...
local D = DeckUI

local db = function() return DeckCrossDB end

D.RegisterModule("Cross", {
    title = "Cross",
    build = function(c)
        D.Label(c, "Controller (Steam Deck)", -6, 15)
        D.Button(c, "Set up gamepad (LT/RT)", -28, ns.SetupGamepad)
        D.Button(c, "Apply default bindings",    -68, ns.ApplyDefaultBindings)

        D.Checkbox(c, "LB + D-pad up/down zooms the camera", -104, db, "lbZoom", ns.SetLBZoom)
        D.Hint(c, "Run both buttons once per device. Stance bar: LB + X/Y/B/A picks a stance, LB + D-pad left/right steps.", -138)

        D.Label(c, "Keyboard (PC)", -178, 15)
        D.Hint(c, "The crosses mirror Action Bar 1 (with stance and vehicle paging) and Action Bar 2. On the PC your own key bindings for those bars drive them.", -200)

        D.Label(c, "Look", -262, 15)
        D.Slider(c, "Size (this device)", -284, 0.6, 1.6, 0.05,
            function(v) return math.floor(v * 100 + 0.5) .. "%" end, ns.DeviceDB, "scale", ns.SetScale)
        -- The opacity slider only means anything while dimming is on, so it
        -- follows the checkbox above it rather than sitting there looking
        -- live. Refresh is extended instead of replaced, so the value still
        -- loads the way every other widget loads.
        local oocSlider
        D.Checkbox(c, "Dim the crosses when idle", -348, db, "dimWhenIdle", function(v)
            ns.SetDimWhenIdle(v)
            if oocSlider then
                if v then oocSlider:Enable() else oocSlider:Disable() end
            end
        end)
        oocSlider = D.Slider(c, "Out-of-combat opacity", -380, 0.1, 1.0, 0.05,
            function(v) return math.floor(v * 100 + 0.5) .. "%" end, db, "oocAlpha", ns.SetOocAlpha)
        local loadValue = oocSlider.Refresh
        function oocSlider:Refresh()
            loadValue(self)
            if DeckCrossDB.dimWhenIdle then self:Enable() else self:Disable() end
        end

        D.Checkbox(c, "Show button labels", -444, db, "showLabels",
            function(v) ns.SetLabelsShown(v) end)
        D.Checkbox(c, "Hide the Blizzard bars the crosses mirror", -472, db, "hideBlizzardBars",
            function(v) ns.SetBlizzardBarsHidden(v) end)

        D.Checkbox(c, "Stance bar at the crosses", -500, db, "stanceBar",
            function(v) ns.SetStanceBar(v) end)

        D.Label(c, "Assistant indicator", -540, 15)
        D.Checkbox(c, "Show what the assistant will cast next", -562, db, "showAssist",
            function(v) ns.SetAssistShown(v) end)
        D.Hint(c, "Green: castable now. Grey with a swirl: waiting is right. Needs the assistant on one of your action bars; move it with /deck unlock.", -594)

        -- moved here from the Devices page (2026-10-02); a hub setting, so
        -- the module's stand-in page has it too while the module is off
        D.Label(c, "Devices", -650, 15)
        D.Checkbox(c, "Cross hotbar only on Steam Deck", -672, function() return DeckUIDB end, "crossDeckOnly",
            function(v) D.SetCrossDeckOnly(v) end)
    end,
})

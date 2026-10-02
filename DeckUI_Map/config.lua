local ADDON, ns = ...
local D = DeckUI

local db = function() return DeckMapDB end
local device = function() return ns.DeviceDB() end
local cvars = function() return ns.cvars end

-- D.Slider leaves storing the value to its apply function
local function Store(key, apply)
    return function(v)
        ns.DeviceDB()[key] = v
        apply()
    end
end

-- Moved to D.Flow 2026-10-02: explanations as tooltips.
D.RegisterModule("Map", {
    title = "Map",
    build = function(c)
        local px  = function(v) return tostring(v) end
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
        local f = D.Flow(c)

        f:Hint("Drag the minimap by its frame and the world map by the strip along its top edge; /deckmap reset brings both back.")

        f:Label("Minimap (this device)")
        f:Slider("Size", 120, 280, 5, px, device, "minimapSize", Store("minimapSize", ns.ApplyMinimapSize))
        f:Checkbox("Zone name on top", db, "zoneText", ns.ApplyTexts)
        f:Checkbox("Clock", db, "clock", ns.ApplyTexts, "Click it for the alarm and the stopwatch.")
        f:Checkbox("Your coordinates", db, "coordinates", ns.ApplyTexts,
            "Blank in places where the game gives no position.")
        f:Checkbox("Buttons only under the mouse", db, "buttonsOnHover", ns.ApplyHover,
            "Tracking, calendar, the addon list and the zoom buttons appear while the mouse is over the minimap.")

        f:Label("World map")
        f:Slider("Size (this device)", 0.5, 1.4, 0.05, pct, device, "worldMapScale",
            Store("worldMapScale", ns.ApplyWorldMapScale))
        f:Checkbox("Open without the quest log", db, "questLogClosed", function() end)
        f:Checkbox("Controls only under the mouse", db, "mapControlsOnHover", ns.ApplyMapHover,
            "Breadcrumbs, filter, floor and close buttons appear while the mouse is over the map.")
        f:Checkbox("Fade the map while moving", cvars, "mapFade", function() end,
            "The game's own setting - it has no checkbox in the game's options, so it lives here.")
        f:Checkbox("Show your coordinates", cvars, "worldMapShowPlayerCoords", function() end)
        f:Checkbox("Show the cursor's coordinates", cvars, "worldMapShowCursorCoords", function() end)
    end,
})

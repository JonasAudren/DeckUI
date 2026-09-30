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

D.RegisterModule("Map", {
    title = "Map",
    build = function(c)
        local px  = function(v) return tostring(v) end
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end

        D.Label(c, "Minimap (per device)", -6, 15)
        D.Slider(c, "Size", -28, 120, 280, 5, px, device, "minimapSize",
            Store("minimapSize", ns.ApplyMinimapSize))
        D.Checkbox(c, "Zone name on top", -92, db, "zoneText", ns.ApplyTexts)
        D.Checkbox(c, "Clock (click: alarm and stopwatch)", -120, db, "clock", ns.ApplyTexts)
        D.Checkbox(c, "Your coordinates", -148, db, "coordinates", ns.ApplyTexts)
        D.Checkbox(c, "Buttons only while the mouse is over the map", -176, db, "buttonsOnHover", ns.ApplyHover)

        D.Label(c, "World map", -220, 15)
        D.Slider(c, "Size (per device)", -242, 0.5, 1.4, 0.05, pct, device, "worldMapScale",
            Store("worldMapScale", ns.ApplyWorldMapScale))
        D.Checkbox(c, "Open without the quest log", -306, db, "questLogClosed", function() end)
        D.Checkbox(c, "Controls only while the mouse is over the map", -334, db, "mapControlsOnHover", ns.ApplyMapHover)
        D.Checkbox(c, "Fade the map while moving", -362, cvars, "mapFade", function() end)
        D.Checkbox(c, "Show your coordinates", -390, cvars, "worldMapShowPlayerCoords", function() end)
        D.Checkbox(c, "Show the cursor's coordinates", -418, cvars, "worldMapShowCursorCoords", function() end)

        D.Hint(c, "The world map always opens as a window; drag it by the strip along its top edge. Fading while moving has no checkbox in the game's options, so it lives here. Drag the minimap by its frame; /deckmap reset brings both back.", -458)
    end,
})

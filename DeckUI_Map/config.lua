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

local px  = function(v) return tostring(v) end
local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end

-- Moved to D.Flow 2026-10-02: explanations as tooltips. Since 2026-10-28 the
-- minimap and the world map have sub-pages of their own (the hub lists them
-- under Map); this page stays, the module's switch sits on it.
D.RegisterModule("Map", {
    title = "Map",
    build = function(c)
        local f = D.Flow(c)
        f:Hint("The minimap and the world map have pages of their own below.")
    end,
})

-- The keys each sub-page writes, per-device ones included (Defaults matches
-- them against the device tables too). The CVars on the world map page live
-- in the game's config, not in DeckMapDB.
local MINIMAP_KEYS = { minimapSize = true, round = true, zoneText = true, clock = true, coordinates = true,
                       buttonsOnHover = true }
local WORLD_KEYS = { worldMapScale = true, questLogClosed = true, mapControlsOnHover = true }
D.PAGE_FRAMES.Map = {}
D.PAGE_RESET.Map = { db = "DeckMapDB", match = function(k) return not (MINIMAP_KEYS[k] or WORLD_KEYS[k]) end }

D.RegisterModule("MapMinimap", {
    title = "Minimap",
    build = function(c)
        local f = D.Flow(c)

        f:Hint("Drag the minimap by its frame; /deckmap reset brings it back.")

        f:Label("Minimap (this device)")
        f:Slider("Size", 120, 280, 5, px, device, "minimapSize", Store("minimapSize", ns.ApplyMinimapSize))
        f:Checkbox("Round, like Final Fantasy XIV", db, "round", ns.ApplyShape,
            "A round map in a gold ring with N, E, S and W on it - they turn with you when the game's Rotate Minimap is on. The zone sits above, clock and coordinates below.")
        f:Checkbox("Zone name on top", db, "zoneText", ns.ApplyTexts)
        f:Checkbox("Clock", db, "clock", ns.ApplyTexts, "Click it for the alarm and the stopwatch.")
        f:Checkbox("Your coordinates", db, "coordinates", ns.ApplyTexts,
            "Blank in places where the game gives no position.")
        f:Checkbox("Buttons only under the mouse", db, "buttonsOnHover", ns.ApplyHover,
            "Tracking, calendar, the addon list and the zoom buttons appear while the mouse is over the minimap.")
    end,
})
D.PAGE_FRAMES.MapMinimap = { "Minimap" }
D.PAGE_RESET.MapMinimap = { db = "DeckMapDB", match = function(k) return MINIMAP_KEYS[k] == true end }

D.RegisterModule("MapWorld", {
    title = "World map",
    build = function(c)
        local f = D.Flow(c)

        f:Hint("Drag the world map by the strip along its top edge; /deckmap reset brings it back.")

        f:Label("World map")
        -- Mists' map cannot be scaled (worldmap.lua, ApplyWorldMapScale)
        if not D.IsMists then
            f:Slider("Size (this device)", 0.5, 1.4, 0.05, pct, device, "worldMapScale",
                Store("worldMapScale", ns.ApplyWorldMapScale))
        end
        f:Checkbox("Open without the quest log", db, "questLogClosed", function() end)
        -- part of the restyle, which Mists' map does not get (worldmap.lua)
        if not D.IsMists then
            f:Checkbox("Controls only under the mouse", db, "mapControlsOnHover", ns.ApplyMapHover,
                "Breadcrumbs, filter, floor and close buttons appear while the mouse is over the map.")
        end
        f:Checkbox("Fade the map while moving", cvars, "mapFade", function() end,
            "The game's own setting - it has no checkbox in the game's options, so it lives here.")
        -- Mists has neither CVar (probe, 2026-10-25)
        if not D.IsMists then
            f:Checkbox("Show your coordinates", cvars, "worldMapShowPlayerCoords", function() end)
            f:Checkbox("Show the cursor's coordinates", cvars, "worldMapShowCursorCoords", function() end)
        end
    end,
})
D.PAGE_FRAMES.MapWorld = { "World map" }
D.PAGE_RESET.MapWorld = { db = "DeckMapDB", match = function(k) return WORLD_KEYS[k] == true end }

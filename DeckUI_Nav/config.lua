local ADDON, ns = ...
local D = DeckUI

local db = function() return DeckNavDB end
local device = function() return ns.DeviceDB() end
local nothing = function() end

-- Moved to D.Flow 2026-10-02: explanations as tooltips; the /way line stays.
D.RegisterModule("Nav", {
    title = "Nav",
    build = function(c)
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
        local f = D.Flow(c)

        -- Mists has no navigation of Blizzard's: there the target is our waypoint
        -- or the quest focused in the tracker (nav_mists.lua)
        f:Hint(D.IsMists and "The target is your active waypoint, or the quest you focused in the tracker."
            or "The target is always the one Blizzard's navigation follows, so the diamond in the world, the map and the compass agree.")

        f:Label("Compass and target")
        f:Checkbox("Compass bar at the top", db, "compass", nothing,
            "Hides in instances, where the game gives no position. Move it with /deck unlock.")
        f:Checkbox("Party members on the compass", db, "party", nothing)
        if C_VignetteInfo then   -- Mists has none
            f:Checkbox("Rares and treasures on the compass", db, "vignettes", nothing)
        end
        f:Checkbox("Target with arrow, distance and arrival time", db, "panel", nothing,
            "Move it with /deck unlock.")
        if ns.ApplyBeacon then   -- beacon.lua needs C_Navigation; not in Mists
            f:Checkbox("Beacon in the world", db, "beacon", function() ns.ApplyBeacon() end,
                "Name, distance and arrival time around the target's marker in the world, in place of Blizzard's diamond.")
        end
        f:Slider("Size (this device)", 0.6, 1.4, 0.05, pct, device, "scale", function(v)
            ns.DeviceDB().scale = v
            ns.ApplyScale()
        end)

        f:Label("Switching and waypoints")
        f:Hint("Key bindings (Keybindings > AddOns > DeckUI) step through your tracked quests, nearest first - also /decknav next and prev.")
        f:Button("Waypoint list", function() ns.ToggleWaypoints() end,
            "All your waypoints: click one to head there, right click to remove it, double click to rename it. With Route on they are walked in order. Add points with Ctrl-click on the world map or /way 45.2 67.8 name - also /way list.")
        f:Checkbox("Route: walk the waypoints in order", db, "routeMode", function() end,
            "On: after arriving the next point in the list follows, and after the last the first again. Off: a reached point is removed and the nearest one left follows.")
        f:Hint("/way 45.2 67.8 name adds a waypoint, /way #mapID x y one on another map, /way clear removes them all. With TomTom installed, use /dway.")
    end,
})

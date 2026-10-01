local ADDON, ns = ...
local D = DeckUI

local db = function() return DeckNavDB end
local device = function() return ns.DeviceDB() end
local nothing = function() end

D.RegisterModule("Nav", {
    title = "Nav",
    build = function(c)
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end

        D.Label(c, "Compass and target", -6, 15)
        D.Checkbox(c, "Compass bar at the top", -28, db, "compass", nothing)
        D.Checkbox(c, "Party members on the compass", -56, db, "party", nothing)
        D.Checkbox(c, "Rares and treasures on the compass", -84, db, "vignettes", nothing)
        D.Checkbox(c, "Target with arrow, distance and arrival time", -112, db, "panel", nothing)
        D.Checkbox(c, "Beacon in the world: name, distance, arrival time", -140, db, "beacon",
            function() ns.ApplyBeacon() end)
        D.Slider(c, "Size (this device)", -174, 0.6, 1.4, 0.05, pct, device, "scale", function(v)
            ns.DeviceDB().scale = v
            ns.ApplyScale()
        end)

        D.Label(c, "Switching and waypoints", -246, 15)
        D.Hint(c, "The target is always the one Blizzard's navigation follows, so the diamond in the world, the map and the compass agree. Key bindings (Options > Keybindings > AddOns > DeckUI) step through your tracked quests, nearest first - also /decknav next and /decknav prev.", -270)
        D.Hint(c, "/way 45.2 67.8 sets a waypoint on this map, /way #mapID x y on another, /way clear removes it. With TomTom installed, use /dway. The compass hides in instances, where the game gives no position.", -346)
        D.Hint(c, "Move compass and target with /deck unlock.", -414)
    end,
})

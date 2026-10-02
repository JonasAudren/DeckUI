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

        f:Hint("The target is always the one Blizzard's navigation follows, so the diamond in the world, the map and the compass agree.")

        f:Label("Compass and target")
        f:Checkbox("Compass bar at the top", db, "compass", nothing,
            "Hides in instances, where the game gives no position. Move it with /deck unlock.")
        f:Checkbox("Party members on the compass", db, "party", nothing)
        f:Checkbox("Rares and treasures on the compass", db, "vignettes", nothing)
        f:Checkbox("Target with arrow, distance and arrival time", db, "panel", nothing,
            "Move it with /deck unlock.")
        f:Checkbox("Beacon in the world", db, "beacon", function() ns.ApplyBeacon() end,
            "Name, distance and arrival time around the target's marker in the world, in place of Blizzard's diamond.")
        f:Slider("Size (this device)", 0.6, 1.4, 0.05, pct, device, "scale", function(v)
            ns.DeviceDB().scale = v
            ns.ApplyScale()
        end)

        f:Label("Switching and waypoints")
        f:Hint("Key bindings (Keybindings > AddOns > DeckUI) step through your tracked quests, nearest first - also /decknav next and prev.")
        f:Hint("/way 45.2 67.8 sets a waypoint on this map, /way #mapID x y on another, /way clear removes it. With TomTom installed, use /dway.")
    end,
})

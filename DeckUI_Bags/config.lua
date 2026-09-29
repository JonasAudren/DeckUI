local ADDON, ns = ...
local D = DeckUI

local db = function() return DeckBagsDB end
local device = function() return ns.DeviceDB() end

-- D.Slider leaves storing the value to its apply function
local function Relayout(key)
    return function(v)
        ns.DeviceDB()[key] = v
        ns.RequestLayout()
        ns.FlushBags()
    end
end

local function Refresh()
    ns.RequestRefresh()
    ns.FlushBags()
end

D.RegisterModule("Bags", {
    title = "Bags",
    build = function(c)
        D.Label(c, "Bag window (per device)", -6, 15)
        D.Slider(c, "Columns", -28, 6, 24, 1, function(v) return tostring(v) end,
            device, "columns", Relayout("columns"))
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
        D.Slider(c, "Size", -92, 0.6, 1.4, 0.05, pct, device, "scale", Relayout("scale"))

        D.Label(c, "Items", -164, 15)
        D.Checkbox(c, "Show item level on gear", -186, db, "itemLevel", Refresh)
        D.Checkbox(c, "Mark junk (grey items) with a coin", -214, db, "markJunk", Refresh)

        D.Hint(c, "B, the bag bar and /bags open the window, as they would Blizzard's bags. Search, sort and gold sit in the window itself. Drag the window by its frame to move it.", -254)
    end,
})

local ADDON, ns = ...
local D = DeckUI

local db = function() return DeckBagsDB end
local device = function() return ns.DeviceDB() end

-- D.Slider leaves storing the value to its apply function
local function Relayout(key)
    return function(v)
        ns.DeviceDB()[key] = v
        ns.RequestLayout()
        ns.FlushAll()
    end
end

local function Refresh()
    ns.RequestRefresh()
    ns.FlushAll()
end

D.RegisterModule("Bags", {
    title = "Bags",
    build = function(c)
        local count = function(v) return tostring(v) end
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end

        D.Label(c, "Windows (per device)", -6, 15)
        D.Slider(c, "Bag columns", -28, 6, 24, 1, count, device, "columns", Relayout("columns"))
        D.Slider(c, "Bank columns", -92, 7, 24, 1, count, device, "bankColumns", Relayout("bankColumns"))
        D.Slider(c, "Size", -156, 0.6, 1.4, 0.05, pct, device, "scale", Relayout("scale"))
        D.Hint(c, "Window too tall for the screen? More columns make it wider and shorter.", -216)

        D.Label(c, "Items", -262, 15)
        D.Checkbox(c, "Sort the bags into categories", -284, db, "categories", ns.SetCategoryView)
        D.Checkbox(c, "Show item level on gear", -312, db, "itemLevel", Refresh)
        D.Checkbox(c, "Mark junk (grey items) with a coin", -340, db, "markJunk", Refresh)

        D.Hint(c, "Categories: new, equipment, consumables, trade goods, quest, other, junk, and one empty slot counting the free ones. The button next to sort switches too. The bank keeps its tabs.", -378)
        D.Hint(c, "B, the bag bar and /bags open the bags, a banker opens the bank, as they would Blizzard's windows. Drag a window by its frame to move it.", -438)
    end,
})

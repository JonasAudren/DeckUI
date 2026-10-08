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

-- Moved to D.Flow 2026-10-02: explanations as tooltips; the one line
-- people need before they look for it - how to open things - stays.
D.RegisterModule("Bags", {
    title = "Bags",
    build = function(c)
        local count = function(v) return tostring(v) end
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
        local f = D.Flow(c)

        f:Hint("B, the bag bar and /bags open the bags, a banker opens the bank - as they would Blizzard's windows. Drag a window by its frame to move it.")

        f:Label("Windows (this device)")
        local tall = "Window too tall for the screen? More columns make it wider and shorter."
        f:Slider("Bag columns", 6, 24, 1, count, device, "columns", Relayout("columns"), tall)
        f:Slider("Bank columns", 7, 24, 1, count, device, "bankColumns", Relayout("bankColumns"), tall)
        f:Slider("Size", 0.6, 1.4, 0.05, pct, device, "scale", Relayout("scale"))

        f:Label("Items")
        f:Checkbox("Sort the bags into categories", db, "categories", ns.SetCategoryView,
            "New, equipment, consumables, trade goods, quest, other, junk, and one empty slot counting the free ones. The button next to sort switches too. The bank keeps its tabs.")
        f:Checkbox("Item level on gear", db, "itemLevel", Refresh)
        f:Checkbox("Mark junk (grey items) with a coin", db, "markJunk", Refresh)

        f:Label("Auction prices")
        local gold = function(v) return v .. "g" end
        f:Checkbox("Auction value of the window in its footer", db, "ahValue", Refresh,
            "What everything in the window would fetch at the auction house, by the cheapest buyouts of your last scan. The scan runs when you open the auction house.")
        f:Checkbox("Mark valuable items with a gold coin", db, "markValuable", Refresh)
        f:Slider("Valuable from", 10, 1000, 10, gold, db, "valuableGold", function(v)
            DeckBagsDB.valuableGold = v
            Refresh()
        end, "A slot counts as valuable when its whole stack is worth at least this much.")
        f:Gap(4)
        f:Hint("Tracked items: drop an item on the row above the gold to count it there like a currency; right-click one to stop.")
    end,
})

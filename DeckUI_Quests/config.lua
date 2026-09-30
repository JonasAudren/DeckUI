local ADDON, ns = ...
local D = DeckUI

local device = function() return ns.DeviceDB() end

-- D.Slider leaves storing the value to its apply function
local function Store(key)
    return function(v)
        ns.DeviceDB()[key] = v
        ns.RequestRedraw()
    end
end

D.RegisterModule("Quests", {
    title = "Quests",
    build = function(c)
        local px  = function(v) return tostring(v) end
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end

        D.Label(c, "Tracker (per device)", -6, 15)
        D.Slider(c, "Width", -28, 180, 400, 10, px, device, "width", Store("width"))
        D.Slider(c, "Size", -92, 0.6, 1.4, 0.05, pct, device, "scale", Store("scale"))
        D.Slider(c, "Text size", -156, 9, 16, 1, px, device, "textSize", Store("textSize"))
        D.Slider(c, "Height limit", -220, 150, 900, 10, px, device, "maxHeight", Store("maxHeight"))

        D.Hint(c, "Drag the tracker by its frame to move it. Click a section heading to fold it, the - in the corner folds everything. Taller than the limit, it scrolls with the mouse wheel.", -290)
    end,
})

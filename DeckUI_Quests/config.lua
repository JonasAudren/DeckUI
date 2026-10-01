local ADDON, ns = ...
local D = DeckUI

local device = function() return ns.DeviceDB() end
local db = function() return DeckQuestsDB end
local nothing = function() end

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

        D.Label(c, "Delves", -348, 15)
        D.Checkbox(c, "Take a single power automatically", -370, db, "autoDelvePower", nothing)
        D.Checkbox(c, "Show Delver's Journey progress", -398, db, "journeyBar", nothing)
        D.Checkbox(c, "Star hunt targets an achievement still needs", -426, db, "huntMarks", nothing)
        D.Hint(c, "A treasure or rare offering just one power needs no choice; it is taken and named in the chat. The journey bar appears when the season renown grows - /quests journey shows it to place it with /deck unlock. On the hunt table a star marks targets still open, with the lists that miss them (N, H, NM). The Nemesis count and the active hunt show in the tracker.", -460)
    end,
})

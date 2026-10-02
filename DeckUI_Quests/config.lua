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

-- Moved to D.Flow 2026-10-02: explanations as tooltips, and the journey
-- bar got a show button here (it was only /quests journey).
D.RegisterModule("Quests", {
    title = "Quests",
    build = function(c)
        local px  = function(v) return tostring(v) end
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
        local f = D.Flow(c)

        f:Hint("Drag the tracker by its frame to move it. Click a section heading to fold it, the - in the corner folds everything.")

        f:Label("Tracker (this device)")
        f:Slider("Width", 180, 400, 10, px, device, "width", Store("width"))
        f:Slider("Size", 0.6, 1.4, 0.05, pct, device, "scale", Store("scale"))
        f:Slider("Text size", 9, 16, 1, px, device, "textSize", Store("textSize"))
        f:Slider("Height limit", 150, 900, 10, px, device, "maxHeight", Store("maxHeight"),
            "Taller than this, the tracker scrolls with the mouse wheel.")

        f:Label("Delves and the hunt")
        f:Checkbox("Take a single power automatically", db, "autoDelvePower", nothing,
            "A treasure or rare that offers just one power needs no choice: it is taken and named in the chat.")
        f:Checkbox("Show Delver's Journey progress", db, "journeyBar", nothing,
            "A bar appears for a few seconds whenever the season renown grows. Move it with /deck unlock.")
        f:Button("Show the journey bar now", function() ns.ShowJourney() end,
            "Shows it with your current progress, to see it and place it. Also /quests journey.")
        f:Checkbox("Star hunt targets an achievement still needs", db, "huntMarks", nothing,
            "On the hunt table a star marks targets still open, with the lists that miss them (N, H, NM).")
        f:Gap(4)
        f:Hint("The Nemesis count and the active hunt show in the tracker by themselves.")
    end,
})

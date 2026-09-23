local ADDON, ns = ...
local D = DeckUI

local db = function() return DeckSpecDB end

D.RegisterModule("Spec", {
    title = "Spec",
    build = function(c)
        D.Label(c, "Specialization switcher", -6, 15)
        D.Checkbox(c, "Show spec bar", -28, db, "showBar", ns.SetBarShown)

        D.Hint(c, "Click a spec icon to switch (not in combat). The active spec has a gold ring. /spec toggles the bar, /deck unlock moves it.", -66)
    end,
})

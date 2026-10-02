local ADDON, ns = ...
local D = DeckUI

local db = function() return DeckSpecDB end

-- Moved to D.Flow 2026-10-02: the hint became the checkbox's tooltip.
D.RegisterModule("Spec", {
    title = "Spec",
    build = function(c)
        local f = D.Flow(c)
        f:Label("Specialization switcher")
        f:Checkbox("Show the spec bar", db, "showBar", ns.SetBarShown,
            "One round icon per specialization; click one to switch (not in combat). The active one has a gold ring. /spec toggles the bar, /deck unlock moves it.")
    end,
})

local ADDON, ns = ...
local D = DeckUI

local db = function() return DeckSpecDB end

D.RegisterModule("Spec", {
    title = "Spec",
    build = function(c)
        D.Label(c, "Specialization switcher", -6, 15)
        D.Checkbox(c, "Show spec bar", -28, db, "showBar", ns.SetBarShown)

        local hint = c:CreateFontString(nil, "OVERLAY")
        hint:SetFont(D.FONT, 11, "OUTLINE")
        hint:SetPoint("TOP", 0, -66)
        hint:SetWidth(300)
        hint:SetTextColor(0.7, 0.7, 0.7)
        hint:SetText("Click a spec icon to switch (not in combat).\nThe active spec has a gold ring.\n/spec toggles the bar, /deck unlock moves it.")
    end,
})

local ADDON, ns = ...
local D = DeckUI

local db = function() return DeckCrossDB end

D.RegisterModule("Cross", {
    title = "Cross",
    build = function(c)
        D.Label(c, "Controller (Steam Deck)", -6, 15)
        D.Button(c, "Set up gamepad (LT/RT)", -28, ns.SetupGamepad)
        D.Button(c, "Apply default bindings",    -68, ns.ApplyDefaultBindings)

        local hint = c:CreateFontString(nil, "OVERLAY")
        hint:SetFont(D.FONT, 11, "OUTLINE")
        hint:SetPoint("TOP", 0, -108)
        hint:SetTextColor(0.7, 0.7, 0.7)
        hint:SetText("Run both once per device.")

        D.Label(c, "Keyboard (PC)", -140, 15)
        local hint2 = c:CreateFontString(nil, "OVERLAY")
        hint2:SetFont(D.FONT, 11, "OUTLINE")
        hint2:SetPoint("TOP", 0, -162)
        hint2:SetWidth(300)
        hint2:SetTextColor(0.7, 0.7, 0.7)
        hint2:SetText("The crosses mirror Action Bar 1 (left cross + upper half\nof the right cross, incl. stance/vehicle paging) and Action\nBar 2 (rest) on both devices. On the PC your normal WoW\nkey bindings for those bars drive the buttons.")

        D.Label(c, "Look", -240, 15)
        D.Slider(c, "Size (this device)", -262, 0.6, 1.6, 0.05,
            function(v) return math.floor(v * 100 + 0.5) .. "%" end, ns.DeviceDB, "scale", ns.SetScale)
        D.Slider(c, "Out-of-combat opacity", -326, 0.1, 1.0, 0.05,
            function(v) return math.floor(v * 100 + 0.5) .. "%" end, db, "oocAlpha", ns.SetOocAlpha)
        D.Checkbox(c, "Show button labels", -390, db, "showLabels",
            function(v) ns.SetLabelsShown(v) end)
        D.Checkbox(c, "Hide the Blizzard bars the crosses mirror", -418, db, "hideBlizzardBars",
            function(v) ns.SetBlizzardBarsHidden(v) end)

        local hint3 = c:CreateFontString(nil, "OVERLAY")
        hint3:SetFont(D.FONT, 11, "OUTLINE")
        hint3:SetPoint("TOP", 0, -456)
        hint3:SetTextColor(0.7, 0.7, 0.7)
        hint3:SetText("Device is detected by the hub (General tab).")
    end,
})

local ADDON, ns = ...
local D = DeckUI

-- Moved to D.Flow 2026-10-02: the three paragraphs became tooltips and one line.
D.RegisterModule("Week", {
    title = "Week",
    build = function(c)
        local f = D.Flow(c)

        f:Hint("Every character in one table: Great Vault, keystone, prey hunts, delves, profession knowledge and weekly quests. Click a character for the details.")

        f:Label("This week")
        f:Button("Open the week overview", function() ns.Toggle() end,
            "Also /week, a key binding (Keybindings > AddOns > DeckUI) or Shift-click on the minimap button.")
        f:Checkbox("Button on screen", function() return DeckWeekDB end, "showButton",
            function() ns.UpdateButton() end,
            "A small round button that opens the overview; its number counts the Great Vault slots unlocked this week. Drag it to move it.")
        f:Gap(4)
        f:Hint("Each character saves its week while you play it; the others show what they had when last seen. Right click a weekly quest to hide it, a character to forget it.")
    end,
})

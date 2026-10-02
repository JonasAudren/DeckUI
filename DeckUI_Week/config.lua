local ADDON, ns = ...
local D = DeckUI

D.RegisterModule("Week", {
    title = "Week",
    build = function(c)
        D.Label(c, "This week", -6, 15)
        D.Button(c, "Open the week overview", -30, function() ns.Toggle() end)
        D.Checkbox(c, "Button on screen (drag it to move it)", -72, function() return DeckWeekDB end,
            "showButton", function() ns.UpdateButton() end)
        D.Hint(c, "Every character in one table: Great Vault, keystone, prey hunts, delves, profession knowledge and weekly quests. Click a character for the details - lockouts, crests, currencies, renown. Each character saves its week while you play it; the others show what they had when last seen, marked once the weekly reset has passed.", -106)
        D.Hint(c, "Weekly quests: the important ones of Midnight are listed by DeckUI, and every other weekly quest that appears in a quest log is learned for all characters. Right click a quest in the details to hide it, right click a character to forget it.", -196)
        D.Hint(c, "Open it with the button, /week, a key binding (Keybindings > AddOns > DeckUI) or Shift-click on the minimap button. The number on the button counts the Great Vault slots unlocked this week.", -268)
    end,
})

local ADDON, ns = ...
local D = DeckUI

D.RegisterModule("Week", {
    title = "Week",
    build = function(c)
        D.Label(c, "This week", -6, 15)
        D.Button(c, "Open the week overview", -30, function() ns.Toggle() end)
        D.Hint(c, "Great Vault, locked instances, keystone, weekly quests, renown and capped currencies - for every character. Each character saves its week while you play it; the others show what they had when last seen, marked once the weekly reset has passed.", -78)
        D.Hint(c, "Weekly quests have no list in the game, so DeckUI learns them: every weekly quest that appears in a quest log is remembered for all characters. /week forget <questID> removes one.", -150)
        D.Hint(c, "Open it with /week, a key binding (Keybindings > AddOns > DeckUI) or Shift-click on the minimap button.", -222)
    end,
})

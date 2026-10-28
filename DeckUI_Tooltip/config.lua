local ADDON, ns = ...
local D = DeckUI

local db = function() return DeckTooltipDB end
local device = function() return ns.DeviceDB() end
local nothing = function() end

-- Moved to D.Flow 2026-10-02: explanations as tooltips.
D.RegisterModule("Tooltip", {
    title = "Tooltip",
    build = function(c)
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
        local f = D.Flow(c)

        f:Label("Place and size (this device)")
        f:Checkbox("At its own place", db, "fixedAnchor", nothing,
            "Tooltips that belong to a button or frame stay beside it; the others appear at the Tooltip frame, which /deck unlock moves.")
        f:Slider("Size", 0.6, 1.4, 0.05, pct, device, "scale", function(v)
            ns.DeviceDB().scale = v
            ns.ApplyScale()
        end)

        f:Label("Content")
        f:Checkbox("Players in their class colour", db, "classColors", nothing,
            "Name and edge in the class colour. Items colour the edge by their quality either way.")
        f:Checkbox("Spec and item level of players", db, "playerInfo", nothing,
            "Needs a short look at their gear, so it shows a moment later - and never in combat.")
        f:Checkbox("Whom the unit is targeting", db, "targetLine", nothing)
        f:Checkbox("IDs while Shift is held", db, "ids", nothing, "Item, spell and NPC IDs.")
    end,
})

-- The extra lines moved to a sub-page of their own on 2026-10-28 (the hub
-- lists it under Tooltip); the Tooltip frame stays with the parent.
local EXTRAS_KEYS = { questItems = true, knowledge = true, chestKeys = true, reputation = true, ensembles = true,
                      ahPrice = true }
D.PAGE_RESET.Tooltip = { db = "DeckTooltipDB", match = function(k) return not EXTRAS_KEYS[k] end }

D.RegisterModule("TooltipExtras", {
    title = "Extras",
    build = function(c)
        local f = D.Flow(c)

        f:Hint("Lines of our own at the end of a tooltip.")

        f:Label("Extras")
        f:Checkbox("Items that start a quest: the quest", db, "questItems", nothing)
        -- profession knowledge, delves and ensembles came long after Mists
        if not D.IsMists then
            f:Checkbox("Profession spells: unspent knowledge", db, "knowledge", nothing)
            f:Checkbox("Rare chest in a delve: your keys", db, "chestKeys", nothing)
        end
        f:Checkbox("Reputation items: your standing", db, "reputation", nothing,
            "Items and currencies that give reputation show the faction and how far you are with it.")
        if not D.IsMists then
            f:Checkbox("Transmog ensembles: what you have", db, "ensembles", nothing,
                "How many of the set's appearances you have collected already.")
        end
        f:Checkbox("Items: auction price", db, "ahPrice", nothing,
            "The cheapest buyout per piece from your last auction house scan (scanned when you open the auction house), and for a stack in your bags its whole value. Gear shares one price across its item levels.")
    end,
})
D.PAGE_RESET.TooltipExtras = { db = "DeckTooltipDB", match = function(k) return EXTRAS_KEYS[k] == true end }

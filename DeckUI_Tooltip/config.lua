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

        f:Label("Extras")
        f:Checkbox("Items that start a quest: the quest", db, "questItems", nothing)
        f:Checkbox("Profession spells: unspent knowledge", db, "knowledge", nothing)
        f:Checkbox("Rare chest in a delve: your keys", db, "chestKeys", nothing)
    end,
})

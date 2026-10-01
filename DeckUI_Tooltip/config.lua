local ADDON, ns = ...
local D = DeckUI

local db = function() return DeckTooltipDB end
local device = function() return ns.DeviceDB() end
local nothing = function() end

D.RegisterModule("Tooltip", {
    title = "Tooltip",
    build = function(c)
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end

        D.Label(c, "Place and size (per device)", -6, 15)
        D.Checkbox(c, "At its own place (move it with /deck unlock)", -28, db, "fixedAnchor", nothing)
        D.Slider(c, "Size", -62, 0.6, 1.4, 0.05, pct, device, "scale", function(v)
            ns.DeviceDB().scale = v
            ns.ApplyScale()
        end)

        D.Label(c, "Content", -134, 15)
        D.Checkbox(c, "Players in their class colour (name and edge)", -156, db, "classColors", nothing)
        D.Checkbox(c, "Spec and item level of players", -184, db, "playerInfo", nothing)
        D.Checkbox(c, "Whom the unit is targeting", -212, db, "targetLine", nothing)
        D.Checkbox(c, "Item, spell and NPC IDs while Shift is held", -240, db, "ids", nothing)

        D.Hint(c, "Tooltips that belong to a button or frame stay beside it; the others appear at the Tooltip frame. Item level of other players needs a short look at their gear, so it shows a moment later and never in combat. The edge takes the item quality or the class colour.", -280)

        D.Label(c, "Extras", -350, 15)
        D.Checkbox(c, "Items that start a quest: the quest", -372, db, "questItems", nothing)
        D.Checkbox(c, "Profession spells: unspent knowledge", -400, db, "knowledge", nothing)
        D.Checkbox(c, "Rare chest in a delve: your keys", -428, db, "chestKeys", nothing)
    end,
})

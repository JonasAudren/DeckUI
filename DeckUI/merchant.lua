local D = DeckUI

-------------------------------------------------------------------
-- At the merchant: sell the junk, repair the gear
-------------------------------------------------------------------
-- Asked for by the owner (2026-10-01), as the first of the small comforts
-- every player wants. In the hub, so it works without the Bags module.
-- Both off by default: selling and paying on their own is nothing an
-- update should start doing unasked.
--
-- Only C APIs and Blizzard's legacy globals, called from our own event
-- handler - nothing of the MerchantFrame is touched or shown. Blizzard's
-- own "sell all junk" button asks first through a StaticPopup; we skip
-- the question (the player switched this on) and so never touch the
-- shared dialog frames (see D.Dialog in widgets.lua).
--
-- Repair comes first, while the gold is all there; guild funds first when
-- allowed and the player wants it. Then the junk goes - what Blizzard
-- counts as junk (C_MerchantFrame.GetNumJunkItems), so its rules decide,
-- and the buyback tab still holds the last twelve items.
-------------------------------------------------------------------
-- true when the gold was short, so a second try after the junk sale may work
local function Repair(quiet)
    if not (DeckUIDB.autoRepair and CanMerchantRepair()) then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end

    if DeckUIDB.repairGuild and IsInGuild() and CanGuildBankRepair() then
        local allowance = GetGuildBankWithdrawMoney()
        local guildMoney = GetGuildBankMoney()
        -- -1 is "no limit" (the guild master)
        if (allowance == -1 or allowance >= cost) and guildMoney >= cost then
            RepairAllItems(true)
            print("DeckUI: repaired for " .. GetMoneyString(cost, true) .. " from the guild bank.")
            return
        end
    end
    if GetMoney() >= cost then
        RepairAllItems(false)
        print("DeckUI: repaired for " .. GetMoneyString(cost, true) .. ".")
    else
        if not quiet then
            print("DeckUI: not enough gold to repair (" .. GetMoneyString(cost, true) .. ").")
        end
        return true
    end
end

local function SellJunk()
    if not DeckUIDB.autoSellJunk then return end
    if not C_MerchantFrame.IsSellAllJunkEnabled() then return end
    local count = C_MerchantFrame.GetNumJunkItems()
    if count <= 0 then return end
    C_MerchantFrame.SellAllJunkItems()
    print(("DeckUI: sold %d junk item%s."):format(count, count == 1 and "" or "s"))
    return true
end

local atMerchant = false

local ev = CreateFrame("Frame")
ev:RegisterEvent("MERCHANT_SHOW")
ev:RegisterEvent("MERCHANT_CLOSED")
ev:SetScript("OnEvent", function(_, event)
    atMerchant = event == "MERCHANT_SHOW"
    if not atMerchant or not DeckUIDB then return end
    local short = Repair(true)
    if SellJunk() and short then
        -- the sale's gold arrives a moment later
        C_Timer.After(1, function()
            if atMerchant then Repair() end
        end)
    elseif short then
        Repair()
    end
end)

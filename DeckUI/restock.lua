local D = DeckUI

-------------------------------------------------------------------
-- Restock at the merchant: reagents, flasks, food up to a wanted count
-------------------------------------------------------------------
-- Owner's wish (2026-10-27), for Mists of Pandaria Classic (players use
-- "Restocker" for it). DeckUIDB.restock, off by default, "Loot and
-- merchant" page; only Mists' .toc lists this file.
--
-- A list per character (DeckUIDB.restockItems["Name-Realm"][itemID] =
-- wanted count). A small window of ours beside Blizzard's merchant shows it:
-- drop an item from the bags on it to add it (the way the bag window's
-- tracked items take one: GetCursorInfo, then ClearCursor puts it back),
-- - and + change the count (Shift: by 1, else by 5), x removes it.
-- On MERCHANT_SHOW - and on "Restock now" - whatever this merchant sells
-- for gold is bought up to the count: BuyMerchantItem, the call Blizzard's
-- own buy click makes, in pieces no larger than the merchant's stack, and
-- never more than the gold allows. Items that cost anything but gold are
-- left alone. One chat line says what was bought.
-------------------------------------------------------------------
local STEP, ROW, W = 5, 22, 210

local function Enabled() return DeckUIDB and DeckUIDB.restock end

local function List()
    DeckUIDB.restockItems = DeckUIDB.restockItems or {}
    local key = UnitName("player") .. "-" .. GetRealmName()
    DeckUIDB.restockItems[key] = DeckUIDB.restockItems[key] or {}
    return DeckUIDB.restockItems[key]
end

local function Money(copper)
    return GetCoinTextureString and GetCoinTextureString(copper) or (copper .. "c")
end

-------------------------------------------------------------------
-- Buying
-------------------------------------------------------------------
local function Restock()
    if not Enabled() or not MerchantFrame or not MerchantFrame:IsShown() then return end
    local wanted = List()
    if not next(wanted) then return end
    local bought, spent = {}, 0
    for index = 1, GetMerchantNumItems() do
        local itemID = GetMerchantItemID(index)
        local want = itemID and wanted[itemID]
        if want then
            local _, _, price, stackCount, numAvailable, isPurchasable, _, extendedCost = GetMerchantItemInfo(index)
            local have = C_Item.GetItemCount(itemID) or 0
            local need = want - have
            stackCount = math.max(1, stackCount or 1)
            if need > 0 and isPurchasable and not extendedCost and price and price > 0 then
                -- bundles come whole: round up to the merchant's bundle size
                need = math.ceil(need / stackCount) * stackCount
                if numAvailable and numAvailable >= 0 then need = math.min(need, numAvailable * stackCount) end
                local each = price / stackCount
                need = math.min(need, math.floor(GetMoney() / each / stackCount) * stackCount)
                local maxStack = math.max(stackCount, GetMerchantItemMaxStack(index) or stackCount)
                local left = need
                while left > 0 do
                    local n = math.min(left, maxStack)
                    BuyMerchantItem(index, n)
                    left = left - n
                end
                if need > 0 then
                    bought[#bought + 1] = (GetMerchantItemLink(index) or ("item " .. itemID)) .. " x" .. need
                    spent = spent + need * each
                end
            end
        end
    end
    if #bought > 0 then
        print(("DeckUI Restock: bought %s for %s."):format(table.concat(bought, ", "), Money(math.floor(spent + 0.5))))
    end
end

-------------------------------------------------------------------
-- The window beside the merchant
-------------------------------------------------------------------
local win, rows, drop, title = nil, {}, nil, nil
local Refresh

local function AddFromCursor()
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or not itemID then return end
    ClearCursor()
    local list = List()
    if not list[itemID] then
        local stack = select(8, C_Item.GetItemInfo(itemID))
        list[itemID] = math.min(stack or 20, 20)
    end
    Refresh()
end

local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, win)
    r:SetSize(W - 16, ROW)
    r:SetPoint("TOPLEFT", 8, -28 - (i - 1) * ROW)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(18, 18)
    r.icon:SetPoint("LEFT")
    r.name = r:CreateFontString(nil, "OVERLAY")
    r.name:SetFont(D.FONT, 11, "OUTLINE")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
    r.name:SetWidth(96)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    local function Small(text, x, onClick)
        local b = CreateFrame("Button", nil, r)
        b:SetSize(18, 18)
        b:SetPoint("RIGHT", x, 0)
        D.FlatBox(b, 1, 0.35)
        local fs = b:CreateFontString(nil, "OVERLAY")
        fs:SetFont(D.FONT, 12, "OUTLINE")
        fs:SetPoint("CENTER")
        fs:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end
    r.count = r:CreateFontString(nil, "OVERLAY")
    r.count:SetFont(D.FONT, 11, "OUTLINE")
    r.count:SetPoint("RIGHT", -62, 0)
    local function Change(delta)
        local list = List()
        local step = IsShiftKeyDown() and 1 or STEP
        list[r.itemID] = math.max(1, (list[r.itemID] or 0) + delta * step)
        Refresh()
    end
    Small("-", -40, function() Change(-1) end)
    Small("+", -20, function() Change(1) end)
    Small("x", 0, function()
        List()[r.itemID] = nil
        Refresh()
    end)
    rows[i] = r
    return r
end

Refresh = function()
    if not win then return end
    local list = List()
    local ids = {}
    for itemID in pairs(list) do ids[#ids + 1] = itemID end
    table.sort(ids)
    for i, itemID in ipairs(ids) do
        local r = Row(i)
        r.itemID = itemID
        local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
        r.icon:SetTexture(icon or (C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)))
        r.name:SetText(name or ("item " .. itemID))
        r.count:SetText(("%d / %d"):format(C_Item.GetItemCount(itemID) or 0, list[itemID]))
        r:Show()
    end
    for i = #ids + 1, #rows do rows[i]:Hide() end
    local n = #ids
    drop:ClearAllPoints()
    drop:SetPoint("TOPLEFT", 8, -28 - n * ROW - 4)
    win:SetHeight(28 + n * ROW + 4 + 30 + 34)
end

local function MakeWindow()
    if win or not MerchantFrame then return end
    win = CreateFrame("Frame", "DeckRestockFrame", MerchantFrame)
    win:SetWidth(W)
    win:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 4, 0)
    win:EnableMouse(true)
    D.FlatBox(win, 0.92)
    title = win:CreateFontString(nil, "OVERLAY")
    title:SetFont(D.FONT, 13, "OUTLINE")
    title:SetPoint("TOPLEFT", 8, -8)
    title:SetTextColor(1, 0.82, 0)
    title:SetText("Restock")

    drop = CreateFrame("Button", nil, win)
    drop:SetSize(W - 16, 26)
    D.FlatBox(drop, 0.5, 0.25)
    local hint = drop:CreateFontString(nil, "OVERLAY")
    hint:SetFont(D.FONT, 10, "OUTLINE")
    hint:SetPoint("CENTER")
    hint:SetTextColor(0.7, 0.7, 0.7)
    hint:SetText("Drop an item from your bags here")
    drop:SetScript("OnReceiveDrag", AddFromCursor)
    drop:SetScript("OnClick", AddFromCursor)

    local now = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    now:SetSize(W - 16, 24)
    now:SetPoint("BOTTOMLEFT", 8, 8)
    now:SetText("Restock now")
    D.FlattenButton(now)
    now:SetScript("OnClick", Restock)
end

function D.ApplyRestock()
    if not Enabled() then
        if win then win:Hide() end
        return
    end
    MakeWindow()
    if win then
        win:Show()
        Refresh()
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("MERCHANT_SHOW")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        D.ApplyRestock()
    elseif not Enabled() then
        return
    elseif event == "MERCHANT_SHOW" then
        D.ApplyRestock()
        -- after the merchant's list has arrived and junk was sold
        C_Timer.After(0.6, Restock)
    elseif win and win:IsShown() then
        Refresh()
    end
end)

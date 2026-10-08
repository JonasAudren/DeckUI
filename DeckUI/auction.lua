local D = DeckUI

-------------------------------------------------------------------
-- Auction house prices: a full scan, kept for when you are away
-------------------------------------------------------------------
-- Owner's wish (2026-10-08): know on the road what things sell for. The
-- game hands out auction data only at the auction house; its full scan is
-- C_AuctionHouse.ReplicateItems ("in place of an 'allItem' query",
-- Blizzard's API documentation), allowed once every 15 minutes. So:
--  - opening the auction house shows a line below it with "Scan now" when
--    the last scan is at least 15 minutes old (DeckUIDB.ahScan, on). The
--    scan needs a click: started by itself when the window opened, it was
--    never answered (owner's test, 2026-10-08). Opening is AuctionHouseFrame's
--    OnShow: AUCTION_HOUSE_SHOW, which the first version waited for, no
--    longer exists - Midnight opens the window through the player
--    interaction manager (Blizzard_AuctionHouseUI_Bootstrap.lua), and no
--    scan ever started (owner's report, 2026-10-08). Should the game refuse
--    a scan that no click started, the status line offers "Scan now";
--  - REPLICATE_ITEM_LIST_UPDATE says the list is there; it is read in
--    slices of a few thousand entries a frame, so the game does not freeze;
--  - per item ID the lowest buyout per piece is kept, per realm, with the
--    time of the scan (DeckUIDB.ahPrices[realm] = { time, prices }).
-- Every item level of a piece of gear shares its item ID, so for gear the
-- price is the cheapest of them - "from".
-- D.AuctionPrice(itemID) -> copper per piece, seconds since the scan.
-- D.OnAuctionPrices(fn) is called after a scan (the bags refresh then).
-------------------------------------------------------------------
local INTERVAL = 15 * 60
local SLICE = 4000

local callbacks = {}
function D.OnAuctionPrices(fn) callbacks[#callbacks + 1] = fn end

local function RealmKey()
    return GetNormalizedRealmName() or GetRealmName() or "?"
end

function D.AuctionPrice(itemID)
    local store = DeckUIDB and DeckUIDB.ahPrices and DeckUIDB.ahPrices[RealmKey()]
    local price = store and itemID and store.prices[itemID]
    if not price then return nil end
    return price, time() - (store.time or 0)
end

-------------------------------------------------------------------
-- A small status line at the top of the auction house window
-------------------------------------------------------------------
local status = CreateFrame("Frame", "DeckAuctionScanStatus", UIParent)
status:SetFrameStrata("HIGH")
status:Hide()
D.FlatBox(status, 0.85)
status:SetSize(340, 24)
local statusText = status:CreateFontString(nil, "OVERLAY")
statusText:SetFont(D.FONT, 12, "OUTLINE")
statusText:SetPoint("LEFT", 8, 0)
statusText:SetPoint("RIGHT", -84, 0)
statusText:SetJustifyH("LEFT")
statusText:SetWordWrap(false)

local scanButton = CreateFrame("Button", nil, status, "UIPanelButtonTemplate")
scanButton:SetSize(74, 18)
scanButton:SetPoint("RIGHT", -3, 0)
scanButton:SetText("Scan now")
scanButton:GetFontString():SetFont(D.FONT, 11, "OUTLINE")
D.FlattenButton(scanButton)

local function Say(text, seconds)
    local ah = _G.AuctionHouseFrame
    if not (ah and ah:IsShown()) then return end
    status:ClearAllPoints()
    -- below the window and its tabs: above it, a window near the top of the
    -- screen pushed the line off it and nobody saw it (2026-10-08)
    status:SetPoint("TOP", ah, "BOTTOM", 0, -34)
    statusText:SetText(text)
    status:Show()
    if seconds then
        C_Timer.After(seconds, function()
            if statusText:GetText() == text then status:Hide() end
        end)
    end
end

-------------------------------------------------------------------
-- The scan
-------------------------------------------------------------------
local requested = false
local reader = CreateFrame("Frame")
local prices, total, index

local function Finish()
    reader:SetScript("OnUpdate", nil)
    local count = 0
    for _ in pairs(prices) do count = count + 1 end
    DeckUIDB.ahPrices = DeckUIDB.ahPrices or {}
    DeckUIDB.ahPrices[RealmKey()] = { time = time(), prices = prices }
    prices = nil
    Say(("Auction prices saved: %s items"):format(BreakUpLargeNumbers(count)), 6)
    for _, fn in ipairs(callbacks) do xpcall(fn, geterrorhandler()) end
end

local function ReadSlice()
    local last = math.min(index + SLICE, total) - 1
    for i = index, last do
        -- 0-based; count is the 3rd, buyoutPrice the 10th, itemID the 17th return
        local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(i)
        if itemID and buyout and buyout > 0 and count and count > 0 then
            local each = math.floor(buyout / count)
            local known = prices[itemID]
            if not known or each < known then prices[itemID] = each end
        end
    end
    index = last + 1
    if index >= total then
        Finish()
    else
        Say(("Reading the auction house ... %d%%"):format(math.floor(index / total * 100)))
    end
end

local function Since() return time() - (DeckUIDB.ahLastScan or 0) end

local answered = 0   -- REPLICATE_ITEM_LIST_UPDATE seen this session (/deck ah)

-- ahLastScan is written when the list arrives, not when it is asked for:
-- an unanswered request must not lock the button for 15 minutes
local function StartScan()
    requested = true
    scanButton:Hide()
    Say("Asking the auction house for all listings ...")
    C_AuctionHouse.ReplicateItems()
    -- nothing after ten seconds: let the button be pressed again
    C_Timer.After(10, function()
        if requested then
            requested = false
            Say("No answer from the auction house - try again.")
            scanButton:Show()
        end
    end)
end

scanButton:SetScript("OnClick", function()
    if Since() < INTERVAL and not requested then
        Say(("The game allows one scan every 15 minutes - %d min to go."):format(math.ceil((INTERVAL - Since()) / 60)), 5)
        return
    end
    StartScan()
end)

local function OnOpen()
    if not (DeckUIDB and DeckUIDB.ahScan) then return end
    scanButton:Hide()
    if Since() < INTERVAL then
        local store = DeckUIDB.ahPrices and DeckUIDB.ahPrices[RealmKey()]
        if store then
            Say(("Prices from %d min ago - next scan in %d min"):format(
                math.floor((time() - store.time) / 60), math.ceil((INTERVAL - Since()) / 60)), 6)
        end
        return
    end
    -- the scan needs a click: started from the window opening, the game
    -- never answered (owner's test, 2026-10-08) - so the button it is
    Say("Auction prices: scan the auction house")
    scanButton:Show()
end

local function OnClose()
    -- the list is gone with the window; a half-read scan is dropped
    if prices then
        reader:SetScript("OnUpdate", nil)
        prices = nil
    end
    requested = false
    status:Hide()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
ev:SetScript("OnEvent", function()
    answered = answered + 1
    if not (DeckUIDB and requested) then return end   -- someone else's scan
    requested = false
    DeckUIDB.ahLastScan = time()
    total = C_AuctionHouse.GetNumReplicateItems() or 0
    if total == 0 then
        Say("The auction house sent no listings.", 5)
        return
    end
    prices, index = {}, 0
    reader:SetScript("OnUpdate", ReadSlice)
end)

-- the window arrives with Blizzard's load-on-demand addon; its OnShow is
-- the moment the auction house is open (a hook, nothing of the frame changed)
EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI", function()
    AuctionHouseFrame:HookScript("OnShow", function()
        -- a frame later: the window has its place by then
        C_Timer.After(0.1, OnOpen)
    end)
    AuctionHouseFrame:HookScript("OnHide", OnClose)
end)

-- /deck ah: what is stored and when the next scan may run
function D.PrintAuction()
    local store = DeckUIDB.ahPrices and DeckUIDB.ahPrices[RealmKey()]
    local count = 0
    if store then for _ in pairs(store.prices) do count = count + 1 end end
    print(("DeckUI auction: scan=%s realm=%s items=%d scanned=%s ago, next scan allowed in %ds"):format(
        tostring(DeckUIDB.ahScan), RealmKey(), count,
        store and SecondsToTime(time() - store.time) or "never",
        math.max(0, INTERVAL - (time() - (DeckUIDB.ahLastScan or 0)))))
    print(("  waiting for an answer=%s, answers this session=%d, reading=%s, style=%s (applied=%s)"):format(
        tostring(requested), answered, tostring(prices ~= nil), tostring(DeckUIDB.ahStyle), tostring(D.ahStyled or false)))
end

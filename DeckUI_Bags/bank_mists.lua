local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- The bank window in Mists of Pandaria Classic (MISTS_PLAN.md, phase 5)
-------------------------------------------------------------------
-- Only in DeckUI_Bags_Mists.toc, in place of retail's bank.lua: Mists has
-- the old bank - 28 slots in container -1 (BANK_CONTAINER), up to seven
-- bank bags in containers 5..11 (NUM_BAG_SLOTS + i), bag slots bought one
-- by one - and none of C_Bank, bank types, tabs or the warband bank. Read
-- in its 5.5.4 source (TBC/BankFrame.lua, Mists/BankFrame.xml), 2026-10-26.
--
-- As in retail, Blizzard's BankFrame is parked, not replaced: it opens on
-- BANKFRAME_OPENED with ShowUIPanel and closes the conversation at once if
-- it did not show, and a right click on a bag item asks BankFrame:IsShown().
-- So it is shown under a hidden parent and stays a UI panel (see bank.lua
-- for why no UIPanelLayout attribute is touched). Its OnShow/OnHide never
-- run there, so the two things they do - open and close the bags - are
-- done here.
--
-- Item buttons are the shared ContainerFrameItemButtonTemplate on the
-- holder of container -1 / 5..11: its click picks up, uses and moves the
-- item between bank and bags itself. The bag slots are Blizzard's own
-- BankItemButtonBagTemplate, which works out its inventory slot from its
-- ID (1..7) and equips or takes off a bag on a click; filled by Blizzard's
-- BankFrameItemButton_Update. Buying a slot asks through D.Dialog, never
-- the CONFIRM_BUY_BANK_SLOT popup (see D.Dialog in widgets.lua).
-------------------------------------------------------------------
local BANK = BANK_CONTAINER or -1
local NUM_BANK_BAGS = NUM_BANKBAGSLOTS or 7
local BAG_SIZE = 37   -- the template's own size; its art does not scale

local atBank = false

local window = ns.NewWindow("DeckBankWindow", _G.BANK or "Bank", {
    extraHeader = BAG_SIZE + 8,
    extraFooter = 30,
    minWidth    = 470,   -- the bag slot row and the purchase button
})
window.defaultPoint = { "TOPLEFT", UIParent, "TOPLEFT", 40, -120 }
window:SetPoint(unpack(window.defaultPoint))
tinsert(UISpecialFrames, "DeckBankWindow")
ns.bank = window

-- the bank bag containers 5..11
local function BankBags()
    local bags = {}
    for i = 1, NUM_BANK_BAGS do bags[#bags + 1] = (NUM_BAG_SLOTS or 4) + i end
    return bags
end

function window.Layout()
    local d = ns.DeviceDB()
    return {
        { bags = { BANK } },
        { title = "Bank bags", bags = BankBags() },
    }, d.bankColumns, d.scale
end

-------------------------------------------------------------------
-- Bag slot row
-------------------------------------------------------------------
local bagButtons = {}
for i = 1, NUM_BANK_BAGS do
    local b = CreateFrame("Button", "DeckBankBagSlot" .. i, window, "BankItemButtonBagTemplate")
    b:SetID(i)
    b:SetSize(BAG_SIZE, BAG_SIZE)
    b:SetPoint("TOPLEFT", 16 + (i - 1) * (BAG_SIZE + 6), -62)
    bagButtons[i] = b
end

-- Buying the next slot: Blizzard's own question and call, in our dialog
local purchase = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
purchase:SetSize(120, 22)
purchase:SetText(BANKSLOTPURCHASE or "Purchase")
purchase:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
    if D.DialogShown("BANK_BUY_SLOT") then
        D.HideDialog("BANK_BUY_SLOT")
        return
    end
    local cost = GetBankSlotCost(GetNumBankSlots())
    D.Dialog({
        key = "BANK_BUY_SLOT",
        text = ("%s\n%s"):format(CONFIRM_BUY_BANK_SLOT or "Buy a bank slot?", GetMoneyString(cost, true)),
        accept = BANKSLOTPURCHASE or "Purchase",
        onAccept = function() PurchaseSlot() end,
    })
end)
purchase:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(BANKSLOTPURCHASE_LABEL or "Purchase a bag slot")
    GameTooltip:AddLine(GetMoneyString(GetBankSlotCost(GetNumBankSlots()), true), 1, 1, 1)
    GameTooltip:Show()
end)
purchase:SetScript("OnLeave", GameTooltip_Hide)

function ns.RefreshBankChrome()
    local owned, full = GetNumBankSlots()
    for i, b in ipairs(bagButtons) do
        BankFrameItemButton_Update(b)
        -- a slot not bought yet in red, as Blizzard's UpdateBagSlotStatus does
        if i <= owned then
            SetItemButtonTextureVertexColor(b, 1, 1, 1)
            b.tooltipText = BANK_BAG
        else
            SetItemButtonTextureVertexColor(b, 1, 0.1, 0.1)
            b.tooltipText = BANK_BAG_PURCHASE
        end
    end
    purchase:ClearAllPoints()
    purchase:SetPoint("LEFT", window, "TOPLEFT", 16 + NUM_BANK_BAGS * (BAG_SIZE + 6) + 4, -62 - BAG_SIZE / 2)
    purchase:SetShown(not full)
    purchase:SetEnabled(GetMoney() >= GetBankSlotCost(owned))
end

window.OnRefresh = ns.RefreshBankChrome

function ns.HideBankDialogs()
    D.HideDialog("BANK_BUY_SLOT")
end

-------------------------------------------------------------------
-- Opening and closing with the banker
-------------------------------------------------------------------
local hider = CreateFrame("Frame", "DeckBankBlizzardHider", UIParent)
hider:SetAllPoints()
hider:Hide()

-- parked with a place, for the same reason as in retail (bank.lua)
local function ParkBankFrame()
    if BankFrame:GetParent() == hider then return end
    BankFrame:SetParent(hider)
    BankFrame:ClearAllPoints()
    BankFrame:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", 0, 0)
end

local function OpenBank()
    atBank = true
    window.needLayout = true
    window:Show()
    ns.Flush(window)
    OpenAllBags(BankFrame)
end

local function CloseBank()
    atBank = false
    window:Hide()
    CloseAllBags(BankFrame)
end

-- Closing our window (X, Escape) ends the conversation with the banker;
-- the game answers with BANKFRAME_CLOSED, which cleans up.
window:SetScript("OnHide", function(self)
    self.search:ClearFocus()
    ns.HideBankDialogs()
    if atBank then CloseBankFrame() end
end)

local ev = CreateFrame("Frame")
ev:RegisterEvent("BANKFRAME_OPENED")
ev:RegisterEvent("BANKFRAME_CLOSED")
ev:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
ev:SetScript("OnEvent", function(_, event)
    if event == "BANKFRAME_OPENED" then
        OpenBank()
    elseif event == "BANKFRAME_CLOSED" then
        CloseBank()
    else
        -- a bag slot bought or a bank bag put in or taken out
        ns.RequestLayout()
    end
end)

function ns.InitBank()
    ParkBankFrame()
    D.MakeMovable(window, "Bank", DeckBagsDB)
    D.MakeDraggable(window)
end

-- /bags bank: what the bank window is built from
function ns.PrintBank()
    local owned, full = GetNumBankSlots()
    print(("DeckUI Bags bank (Mists): at bank=%s, BankFrame parked=%s shown=%s, bag slots %d of %d%s"):format(
        tostring(atBank), tostring(BankFrame:GetParent() == hider), tostring(BankFrame:IsShown()),
        owned or 0, NUM_BANK_BAGS, full and " (all bought)" or ""))
    print(("  bank: %d slots, %d free"):format(C_Container.GetContainerNumSlots(BANK),
        C_Container.GetContainerNumFreeSlots(BANK) or 0))
    for _, bag in ipairs(BankBags()) do
        print(("  bag %d: %d slots, %d free"):format(bag, C_Container.GetContainerNumSlots(bag),
            C_Container.GetContainerNumFreeSlots(bag) or 0))
    end
end

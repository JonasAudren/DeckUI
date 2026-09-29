local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Shared pieces for the bag window now and the bank windows later:
-- a window with search, sort, money and a grid of item buttons.
-------------------------------------------------------------------
-- The item buttons are Blizzard's own ContainerFrameItemButtonTemplate.
-- Its click handler is Blizzard code that knows every case - using a
-- potion in combat, selling at a merchant, posting at the auction house,
-- depositing at the bank, splitting stacks - and it only stays untainted
-- because it learns its bag through an attribute (SetBagID) rather than
-- a field we write. So we never set a click script of our own on them;
-- we only fill in what they show.
-------------------------------------------------------------------
local BUTTON = 37    -- the template's own size; scaling happens on the grid
local GAP    = 4
local PAD    = 10
local HEADER = 58    -- title row + search row
local FOOTER = 26

ns.BUTTON = BUTTON

-------------------------------------------------------------------
-- Item buttons, pooled per bag
-------------------------------------------------------------------
-- One holder frame per bag carries the bag ID as its frame ID, which is
-- where the template falls back to when no attribute is set. The buttons
-- get the attribute as well; the holder is belt and braces.
local holders = {}   -- [grid][bag] -> frame
local count = 0

local function Holder(grid, bag)
    holders[grid] = holders[grid] or {}
    local h = holders[grid][bag]
    if not h then
        h = CreateFrame("Frame", nil, grid)
        h:SetID(bag)
        h:SetAllPoints()
        holders[grid][bag] = h
    end
    return h
end

local function NewButton(grid, bag)
    count = count + 1
    -- Named, because the template names some of its textures after the
    -- button ($parentIconQuestTexture) and an unnamed parent would make
    -- them all share one global name.
    local b = CreateFrame("ItemButton", "DeckBagsItem" .. count, Holder(grid, bag),
        "ContainerFrameItemButtonTemplate")
    -- Blizzard adds this background only inside its combined bag window;
    -- without it an empty slot is a hole in the grid.
    b.ItemSlotBackground = b:CreateTexture(nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate", -6)
    b.ItemSlotBackground:SetAllPoints(b)

    b.DeckLevel = b:CreateFontString(nil, "OVERLAY")
    b.DeckLevel:SetFont(D.FONT, 12, "OUTLINE")
    b.DeckLevel:SetPoint("TOPLEFT", 2, -2)
    return b
end

-- grid.buttons[bag][slot] -> button, created on first use and kept
function ns.Button(grid, bag, slot)
    grid.buttons[bag] = grid.buttons[bag] or {}
    local b = grid.buttons[bag][slot]
    if not b then
        b = NewButton(grid, bag)
        b:SetBagID(bag)
        b:SetID(slot)
        grid.buttons[bag][slot] = b
    end
    return b
end

-------------------------------------------------------------------
-- What a button shows (the same steps as Blizzard's UpdateItems)
-------------------------------------------------------------------
local ARMOR  = Enum.ItemClass and Enum.ItemClass.Armor or 4
local WEAPON = Enum.ItemClass and Enum.ItemClass.Weapon or 2
local POOR   = Enum.ItemQuality and Enum.ItemQuality.Poor or 0

local function ItemLevel(bag, slot, itemID)
    if not itemID then return nil end
    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(itemID)
    if classID ~= ARMOR and classID ~= WEAPON then return nil end
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP_IGNORE" then return nil end
    local ok, level = pcall(C_Item.GetCurrentItemLevel, ItemLocation:CreateFromBagAndSlot(bag, slot))
    if ok and type(level) == "number" and level > 1 then return level end
    return nil
end

function ns.UpdateButton(b)
    local bag, slot = b:GetBagID(), b:GetID()
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local texture = info and info.iconFileID
    local quality = info and info.quality

    ClearItemButtonOverlay(b)
    b:SetHasItem(texture)
    b:SetItemButtonTexture(texture)
    SetItemButtonQuality(b, quality, info and info.hyperlink, false, info and info.isBound)
    SetItemButtonCount(b, info and info.stackCount)
    SetItemButtonDesaturated(b, info and info.isLocked)

    b:UpdateExtended()
    local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
    b:UpdateQuestItem(quest.isQuestItem, quest.questID, quest.isActive)
    b:UpdateNewItem(quality)
    b:UpdateItemContextMatching()
    b:UpdateCooldown(texture)
    b:SetReadable(info and info.isReadable)
    b:SetMatchesSearch(not (info and info.isFiltered))

    -- Blizzard marks junk only while a merchant is open. We mark it always:
    -- knowing what to sell before walking to the vendor is the point.
    b.JunkIcon:SetShown(DeckBagsDB.markJunk and info ~= nil and quality == POOR and not info.hasNoValue)

    local level = DeckBagsDB.itemLevel and info and ItemLevel(bag, slot, info.itemID)
    b.DeckLevel:SetText(level or "")
end

-------------------------------------------------------------------
-- Window
-------------------------------------------------------------------
-- sections: { { title = string|nil, bags = { bagID, ... } }, ... }
-- Laid out top to bottom, each section a grid of `columns` buttons.
-- Phase two (categories) only changes what goes into the sections.
function ns.NewWindow(name, titleText)
    local w = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    w:SetFrameStrata("MEDIUM")
    w:SetToplevel(true)
    w:EnableMouse(true)
    w:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    w:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    w:Hide()

    local title = w:CreateFontString(nil, "OVERLAY")
    title:SetFont(D.FONT, 16, "OUTLINE")
    title:SetPoint("TOPLEFT", PAD + 2, -12)
    title:SetText(titleText)
    w.title = title

    local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    w.close = close

    -- BagSearchBoxTemplate feeds C_Container.SetItemSearch, and the game
    -- answers with isFiltered on every item plus INVENTORY_SEARCH_UPDATE.
    local search = CreateFrame("EditBox", name .. "Search", w, "BagSearchBoxTemplate")
    search:SetHeight(20)
    search:SetPoint("TOPLEFT", PAD + 6, -34)
    search:SetPoint("RIGHT", w, "RIGHT", -PAD - 30, 0)
    w.search = search

    local sort = CreateFrame("Button", nil, w)
    sort:SetSize(24, 24)
    sort:SetPoint("LEFT", search, "RIGHT", 4, 0)
    sort:SetNormalAtlas("bags-button-autosort-up")
    sort:SetPushedAtlas("bags-button-autosort-down")
    sort:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    sort:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(BAG_CLEANUP_BAGS or "Clean up bags")
        GameTooltip:Show()
    end)
    sort:SetScript("OnLeave", GameTooltip_Hide)
    w.sort = sort

    -- The grid scales as a whole: the template's textures are laid out for
    -- 37 pixels, so resizing single buttons would tear their overlays apart.
    local grid = CreateFrame("Frame", nil, w)
    grid:SetPoint("TOPLEFT", PAD, -HEADER)
    grid:SetSize(1, 1)
    grid.buttons = {}
    grid.headings = {}
    w.grid = grid

    local money = w:CreateFontString(nil, "OVERLAY")
    money:SetFont(D.FONT, 13, "OUTLINE")
    money:SetPoint("BOTTOMRIGHT", -PAD - 2, 10)
    w.money = money

    local free = w:CreateFontString(nil, "OVERLAY")
    free:SetFont(D.FONT, 12, "OUTLINE")
    free:SetPoint("BOTTOMLEFT", PAD + 2, 10)
    free:SetTextColor(0.7, 0.7, 0.7)
    w.free = free

    -- tracked currencies sit left of the gold
    w.currencies = {}
    return w
end

local function Heading(grid, i)
    local fs = grid.headings[i]
    if not fs then
        fs = grid:CreateFontString(nil, "OVERLAY")
        fs:SetFont(D.FONT, 13, "OUTLINE")
        fs:SetTextColor(0.9, 0.75, 0.2)
        grid.headings[i] = fs
    end
    return fs
end

-- Places every slot of every section and sizes the window around them.
-- Only needed when slots appear or vanish (a bag equipped, a setting
-- changed); everything else is ns.RefreshWindow.
function ns.LayoutWindow(w, sections, columns, scale)
    local grid = w.grid
    grid:SetScale(scale)

    for _, bagButtons in pairs(grid.buttons) do
        for _, b in pairs(bagButtons) do b:Hide() end
    end
    for _, fs in ipairs(grid.headings) do fs:Hide() end

    local y, widest, headingIndex = 0, 0, 0
    local free, total = 0, 0
    for _, section in ipairs(sections) do
        local slots = {}
        for _, bag in ipairs(section.bags) do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                slots[#slots + 1] = ns.Button(grid, bag, slot)
            end
            free  = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
        end
        total = total + #slots

        if #slots > 0 then
            if section.title then
                headingIndex = headingIndex + 1
                local fs = Heading(grid, headingIndex)
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", grid, "TOPLEFT", 2, -y - 2)
                fs:SetText(section.title)
                fs:Show()
                y = y + 18
            end
            for i, b in ipairs(slots) do
                local col = (i - 1) % columns
                local row = math.floor((i - 1) / columns)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (BUTTON + GAP), -(y + row * (BUTTON + GAP)))
                b:Show()
            end
            local rows = math.ceil(#slots / columns)
            local cols = math.min(#slots, columns)
            widest = math.max(widest, cols * (BUTTON + GAP) - GAP)
            y = y + rows * (BUTTON + GAP) + 6
        end
    end

    local gridW = math.max(widest, 1)
    local gridH = math.max(y - 6, 1)
    grid:SetSize(gridW, gridH)
    -- the window is not scaled, so the grid's size is converted back
    w:SetSize(math.max(gridW * scale + 2 * PAD, 260), gridH * scale + HEADER + FOOTER + 8)
    w.freeSlots, w.totalSlots = free, total
end

function ns.RefreshWindow(w)
    local free = 0
    for bag, bagButtons in pairs(w.grid.buttons) do
        for _, b in pairs(bagButtons) do
            if b:IsShown() then ns.UpdateButton(b) end
        end
        free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
    end
    w.free:SetText(("%d / %d free"):format(free, w.totalSlots or 0))
    w.money:SetText(GetMoneyString(GetMoney(), true))
    ns.UpdateCurrencies(w)
end

-------------------------------------------------------------------
-- Tracked currencies (the ones the player picked for the backpack)
-------------------------------------------------------------------
local MAX_CURRENCIES = 3

function ns.UpdateCurrencies(w)
    local anchor = w.money
    for i = 1, MAX_CURRENCIES do
        local c = w.currencies[i]
        if not c then
            c = CreateFrame("Frame", nil, w)
            c:SetSize(60, 16)
            c.icon = c:CreateTexture(nil, "ARTWORK")
            c.icon:SetSize(14, 14)
            c.icon:SetPoint("RIGHT")
            c.text = c:CreateFontString(nil, "OVERLAY")
            c.text:SetFont(D.FONT, 12, "OUTLINE")
            c.text:SetPoint("RIGHT", c.icon, "LEFT", -3, 0)
            c:EnableMouse(true)
            c:SetScript("OnEnter", function(self)
                if not self.currencyID then return end
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetCurrencyByID(self.currencyID)
                GameTooltip:Show()
            end)
            c:SetScript("OnLeave", GameTooltip_Hide)
            w.currencies[i] = c
        end
        local info = C_CurrencyInfo.GetBackpackCurrencyInfo(i)
        if info then
            c.icon:SetTexture(info.iconFileID)
            c.text:SetText(BreakUpLargeNumbers(info.quantity))
            c.currencyID = info.currencyTypesID
            c:SetWidth(c.text:GetStringWidth() + 20)
            c:ClearAllPoints()
            c:SetPoint("RIGHT", anchor, "LEFT", -10, 0)
            c:Show()
            anchor = c
        else
            c:Hide()
        end
    end
end

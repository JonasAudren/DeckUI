local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Shared pieces for the bag window and the bank window: a window with
-- search, sort, money and a grid of item buttons, and one update loop.
-------------------------------------------------------------------
-- The item buttons are Blizzard's own ContainerFrameItemButtonTemplate.
-- Its click handler is Blizzard code that knows every case - using a
-- potion in combat, selling at a merchant, posting at the auction house,
-- depositing at the bank, splitting stacks - and it only stays untainted
-- because it learns its bag through an attribute (SetBagID) rather than
-- a field we write. So we never set a click script of our own on them;
-- we only fill in what they show. Bank tabs are ordinary bag IDs, so the
-- same template serves the bank.
-------------------------------------------------------------------
local BUTTON = 37    -- the template's own size; scaling happens on the grid
local GAP    = 4
local PAD    = 10
local HEADER = 58    -- title row + search row; a window can ask for more
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

    -- the category view shows one empty slot standing in for all of them
    b.DeckFree = b:CreateFontString(nil, "OVERLAY")
    b.DeckFree:SetFont(D.FONT, 15, "OUTLINE")
    b.DeckFree:SetPoint("CENTER")
    b.DeckFree:SetTextColor(0.8, 0.8, 0.8)
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
    b.DeckFree:SetText((not info and b.freeCount) or "")
end

-------------------------------------------------------------------
-- Window
-------------------------------------------------------------------
-- sections: { { title = string|nil, bags = { bagID, ... } }, ... }
-- or, for the category view, { title = ..., slots = { { bag, slot }, ... } }.
-- Laid out top to bottom, each section a grid of `columns` buttons.
--
-- opts.extraHeader / opts.extraFooter make room for rows of the window's
-- own (the bank's tab icons and its deposit buttons), opts.minWidth keeps
-- those rows from being squeezed, opts.money says whose gold to show and
-- opts.currencies turns on the tracked currencies.
local windows = {}   -- every window made here, for search sync and updates

function ns.NewWindow(name, titleText, opts)
    opts = opts or {}
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
    w.headerHeight = HEADER + (opts.extraHeader or 0)
    w.footerHeight = FOOTER + (opts.extraFooter or 0)
    w.minWidth     = opts.minWidth or 260

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
    -- The search is global, so the other windows' boxes follow the text.
    local search = CreateFrame("EditBox", name .. "Search", w, "BagSearchBoxTemplate")
    search:SetHeight(20)
    search:SetPoint("TOPLEFT", PAD + 6, -34)
    search:SetPoint("RIGHT", w, "RIGHT", -PAD - 30, 0)
    search:HookScript("OnTextChanged", function(self)
        local text = self:GetText()
        for _, other in ipairs(windows) do
            if other.search ~= self and other.search:GetText() ~= text then
                other.search:SetText(text)
            end
        end
    end)
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
    grid:SetPoint("TOPLEFT", PAD, -w.headerHeight)
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

    w.currencies = {}
    w.showCurrencies = opts.currencies
    w.Money = opts.money or GetMoney

    w.needLayout, w.needRefresh = true, true
    windows[#windows + 1] = w
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
-- Only needed when slots appear or vanish (a bag equipped, a bank tab
-- bought or switched, a setting changed) - or, in the category view, when
-- items move; everything else is RefreshWindow.
-- countBags: the bags the "free" line counts, when the sections do not
-- simply list them (the category view hides most empty slots).
function ns.LayoutWindow(w, sections, columns, scale, countBags)
    local grid = w.grid
    grid:SetScale(scale)

    for _, bagButtons in pairs(grid.buttons) do
        for _, b in pairs(bagButtons) do b:Hide() end
    end
    for _, fs in ipairs(grid.headings) do fs:Hide() end

    local y, widest, headingIndex = 0, 0, 0
    local bags, total = {}, 0
    for _, section in ipairs(sections) do
        local slots = {}
        if section.slots then
            for _, s in ipairs(section.slots) do
                slots[#slots + 1] = ns.Button(grid, s[1], s[2])
            end
        else
            for _, bag in ipairs(section.bags) do
                for slot = 1, C_Container.GetContainerNumSlots(bag) do
                    slots[#slots + 1] = ns.Button(grid, bag, slot)
                end
                bags[#bags + 1] = bag
            end
            total = total + #slots
        end

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
    w:SetSize(math.max(gridW * scale + 2 * PAD, w.minWidth),
        gridH * scale + w.headerHeight + w.footerHeight + 8)
    if countBags then
        bags, total = countBags, 0
        for _, bag in ipairs(countBags) do total = total + C_Container.GetContainerNumSlots(bag) end
    end
    w.layoutBags, w.totalSlots = bags, total
end

function ns.RefreshWindow(w)
    for _, bagButtons in pairs(w.grid.buttons) do
        for _, b in pairs(bagButtons) do
            if b:IsShown() then ns.UpdateButton(b) end
        end
    end
    local free = 0
    for _, bag in ipairs(w.layoutBags or {}) do
        free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
    end
    w.free:SetText(("%d / %d free"):format(free, w.totalSlots or 0))
    w.money:SetText(GetMoneyString(w.Money() or 0, true))
    if w.showCurrencies then ns.UpdateCurrencies(w) end
    if w.OnRefresh then w:OnRefresh() end
end

-------------------------------------------------------------------
-- Updates for every window
-------------------------------------------------------------------
-- Each window supplies w.Layout() -> sections, columns, scale. Events come
-- in bursts (a loot pickup fires several), so they only mark the windows
-- and one pass runs on the next frame, for the windows that are shown.
function ns.RequestLayout()
    for _, w in ipairs(windows) do w.needLayout = true end
end

function ns.RequestRefresh()
    for _, w in ipairs(windows) do w.needRefresh = true end
end

function ns.Flush(w)
    if not w:IsShown() or not w.Layout then return end
    if w.needLayout then
        ns.LayoutWindow(w, w.Layout())
        w.needLayout, w.needRefresh = false, true
    end
    if w.needRefresh then
        ns.RefreshWindow(w)
        w.needRefresh = false
    end
end

function ns.FlushAll()
    for _, w in ipairs(windows) do ns.Flush(w) end
end

local updater = CreateFrame("Frame")
updater:SetScript("OnUpdate", function()
    for _, w in ipairs(windows) do
        if w.needLayout or w.needRefresh then ns.Flush(w) end
    end
end)

-- slot counts change: a bag put on, a bank tab bought or renamed
local LAYOUT_EVENTS = {
    BAG_CONTAINER_UPDATE = true, BANK_TABS_CHANGED = true,
    BANK_TAB_SETTINGS_UPDATED = true,
}

local ev = CreateFrame("Frame")
for _, e in ipairs({
    "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN",
    "INVENTORY_SEARCH_UPDATE", "BAG_NEW_ITEMS_UPDATED", "QUEST_ACCEPTED",
    "UNIT_QUEST_LOG_CHANGED", "PLAYER_MONEY", "ACCOUNT_MONEY", "CURRENCY_DISPLAY_UPDATE",
    "PLAYER_EQUIPMENT_CHANGED", "PLAYERBANKSLOTS_CHANGED", "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED",
    "BAG_CONTAINER_UPDATE", "BANK_TABS_CHANGED", "BANK_TAB_SETTINGS_UPDATED",
}) do ev:RegisterEvent(e) end

-- items actually moved; a window that sorts by content (the category view,
-- w.relayoutOnMove) has to place them again. Not ITEM_LOCK_CHANGED: that
-- fires on pickup, and reshuffling the grid under the cursor is maddening.
local MOVE_EVENTS = { BAG_UPDATE_DELAYED = true, BAG_NEW_ITEMS_UPDATED = true }

ev:SetScript("OnEvent", function(_, event)
    if LAYOUT_EVENTS[event] then ns.RequestLayout() else ns.RequestRefresh() end
    if MOVE_EVENTS[event] then
        for _, w in ipairs(windows) do
            if w.relayoutOnMove then w.needLayout = true end
        end
    end
end)

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

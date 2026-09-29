local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- The bag window
-------------------------------------------------------------------
-- How it takes over from Blizzard's bags: it doesn't. Blizzard's bag
-- frames keep running, parked under a hidden frame, and every piece of
-- Blizzard code that opens or closes bags - the B key, the bag bar, the
-- bank, the mailbox, the merchant, Escape - goes on doing exactly that.
-- Our window simply shows whenever Blizzard thinks a bag is open.
--
-- The alternative, replacing ToggleAllBags and friends, would run our
-- code in the middle of Blizzard's: the bank's OnShow calls OpenAllBags,
-- and everything after that call would carry our taint into the bank
-- frame, whose bank type the bag buttons read on every right click.
-------------------------------------------------------------------
local BACKPACK = Enum.BagIndex.Backpack
local REAGENT  = Enum.BagIndex.ReagentBag
local NUM_BAGS = Constants.InventoryConstants.NumBagSlots   -- 4

local window = ns.NewWindow("DeckBagsWindow", "Bags", { currencies = true })
window.defaultPoint = { "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -20, 110 }
window:SetPoint(unpack(window.defaultPoint))
ns.bags = window

local HELD = {}
for bag = BACKPACK, NUM_BAGS do HELD[#HELD + 1] = bag end
local ALL = { unpack(HELD) }
ALL[#ALL + 1] = REAGENT

-- The grid view: every slot where it actually is.
local function GridSections()
    return {
        { bags = HELD },
        { title = "Reagents", bags = { REAGENT } },
    }
end

-------------------------------------------------------------------
-- The category view
-------------------------------------------------------------------
-- Each item goes into the first group that claims it, in this order, and
-- the groups are shown in the same order. The item class comes from
-- C_Item.GetItemInfoInstant, which answers from the client's own data -
-- no server round trip, so nothing lands in "Other" just for being new.
local C = Enum.ItemClass
local POOR = Enum.ItemQuality.Poor

local CATEGORIES = {
    { key = "new",        title = "New" },
    { key = "equipment",  title = "Equipment" },
    { key = "consumable", title = "Consumables" },
    { key = "trade",      title = "Trade Goods" },
    { key = "quest",      title = "Quest" },
    { key = "other",      title = "Other" },
    { key = "junk",       title = "Junk" },
}

local CLASS_CATEGORY = {
    [C.Weapon]          = "equipment",
    [C.Armor]           = "equipment",
    [C.Consumable]      = "consumable",
    [C.ItemEnhancement] = "consumable",
    [C.Tradegoods]      = "trade",
    [C.Reagent]         = "trade",
    [C.Gem]             = "trade",
    [C.Recipe]          = "trade",
    [C.Profession]      = "trade",
    [C.Questitem]       = "quest",
}

local function Categorize(bag, slot, info)
    -- junk before "new": a grey drop is junk the moment it arrives
    if info.quality == POOR and not info.hasNoValue then return "junk" end
    if C_NewItems.IsNewItem(bag, slot) then return "new" end
    local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
    if quest.isQuestItem or quest.questID then return "quest" end
    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(info.itemID)
    local key = classID and CLASS_CATEGORY[classID]
    -- armor class also holds cosmetic odds and ends that cannot be worn
    if key == "equipment" and (not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP_IGNORE") then
        key = nil
    end
    return key or "other"
end

-- Inside a group: best quality first, then by name, bigger stacks first.
local function ItemOrder(a, b)
    if a.quality ~= b.quality then return a.quality > b.quality end
    if a.name ~= b.name then return a.name < b.name end
    if a.count ~= b.count then return a.count > b.count end
    if a[1] ~= b[1] then return a[1] < b[1] end
    return a[2] < b[2]
end

-- The empty slots collapse into one per kind of bag - the reagent bag only
-- takes reagents - showing how many there are. Dropping an item on it puts
-- the item into that very slot, which is as good as any free one.
local function EmptySection()
    local slots = {}
    for _, group in ipairs({ HELD, { REAGENT } }) do
        local first, free = nil, 0
        for _, bag in ipairs(group) do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                if not C_Container.GetContainerItemInfo(bag, slot) then
                    free = free + 1
                    first = first or { bag, slot }
                end
            end
        end
        if first then
            first.free = free
            slots[#slots + 1] = first
        end
    end
    return { title = "Empty", slots = slots }
end

local function CategorySections()
    local groups = {}
    for _, cat in ipairs(CATEGORIES) do groups[cat.key] = {} end

    for _, bag in ipairs(ALL) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                local entry = { bag, slot, quality = info.quality or 0,
                    name = info.itemName or "", count = info.stackCount or 1 }
                table.insert(groups[Categorize(bag, slot, info)], entry)
            end
        end
    end

    local sections = {}
    for _, cat in ipairs(CATEGORIES) do
        local list = groups[cat.key]
        if #list > 0 then
            table.sort(list, ItemOrder)
            sections[#sections + 1] = { title = cat.title, slots = list }
        end
    end
    sections[#sections + 1] = EmptySection()
    return sections
end

-- Only the stand-in empty slots carry a number; every other button forgets
-- the one it may have had from an earlier layout.
local function MarkFreeCounts(sections)
    for _, bagButtons in pairs(window.grid.buttons) do
        for _, b in pairs(bagButtons) do b.freeCount = nil end
    end
    local empty = sections[#sections]
    for _, s in ipairs(empty.slots or {}) do
        ns.Button(window.grid, s[1], s[2]).freeCount = s.free
    end
end

local function IsCategoryView()
    return DeckBagsDB.categories
end

-------------------------------------------------------------------
-- Settings that shape the grid (per device, like the Orbs and Cross sizes)
-------------------------------------------------------------------
-- A bank tab holds 98 slots, which Blizzard shows as 14 x 7.
local DEVICE_DEFAULTS = {
    deck = { columns = 10, scale = 0.9, bankColumns = 14 },
    pc   = { columns = 12, scale = 1.0, bankColumns = 14 },
}

function ns.DeviceDB()
    local d = D.DeviceDB(DeckBagsDB)
    local defaults = DEVICE_DEFAULTS[D.DeviceKey()]
    for k, v in pairs(defaults) do
        if d[k] == nil then d[k] = v end
    end
    return d
end

function window.Layout()
    local d = ns.DeviceDB()
    window.relayoutOnMove = IsCategoryView()
    if not IsCategoryView() then
        for _, bagButtons in pairs(window.grid.buttons) do
            for _, b in pairs(bagButtons) do b.freeCount = nil end
        end
        return GridSections(), d.columns, d.scale
    end
    local sections = CategorySections()
    MarkFreeCounts(sections)
    return sections, d.columns, d.scale, ALL
end

-------------------------------------------------------------------
-- Switching views: a button in the window, a checkbox in the settings
-------------------------------------------------------------------
function ns.SetCategoryView(state)
    DeckBagsDB.categories = state
    window.needLayout = true
    ns.Flush(window)
end

-- the view button joins the row right of the search box
local viewButton = CreateFrame("Button", nil, window)
viewButton:SetSize(24, 24)
viewButton:SetPoint("RIGHT", window.old, "LEFT", -4, 0)
window.search:SetPoint("RIGHT", viewButton, "LEFT", -6, 0)
viewButton:SetNormalAtlas("bags-icon-multiple")
viewButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
viewButton:SetScript("OnClick", function()
    ns.SetCategoryView(not IsCategoryView())
    if D.panel and D.panel:IsShown() and D.panel.contents.Bags then
        D.RefreshWidgets(D.panel.contents.Bags)
    end
end)
viewButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(IsCategoryView() and "Show one grid" or "Show categories")
    GameTooltip:Show()
end)
viewButton:SetScript("OnLeave", GameTooltip_Hide)

-------------------------------------------------------------------
-- Following Blizzard's open/closed state
-------------------------------------------------------------------
local hider = CreateFrame("Frame", "DeckBagsBlizzardHider", UIParent)
hider:SetAllPoints()
hider:Hide()

local function BlizzardFrames()
    local list = { ContainerFrameCombinedBags }
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        list[#list + 1] = _G["ContainerFrame" .. i]
    end
    return list
end

-- Under a hidden parent Blizzard's frames keep their own shown flag, which
-- is all IsBagOpen asks, but are never drawn and take no clicks.
local function ParkBlizzardFrames()
    for _, f in ipairs(BlizzardFrames()) do
        if f and f:GetParent() ~= hider then f:SetParent(hider) end
    end
end

local function Sync()
    local open = IsAnyBagOpen()
    if open and not window:IsShown() then
        window.needLayout = true
        window:Show()
        ns.Flush(window)
    elseif not open and window:IsShown() then
        window:Hide()
    end
end
ns.SyncBags = Sync

for _, fn in ipairs({ "OpenAllBags", "CloseAllBags", "ToggleAllBags",
                      "OpenBackpack", "CloseBackpack", "ToggleBackpack",
                      "OpenBag", "CloseBag", "ToggleBag" }) do
    if _G[fn] then hooksecurefunc(fn, Sync) end
end

-- The hooks cover every path we know; the poll covers the ones we do not
-- (a frame hidden directly, a new opener in a patch).
local poll = CreateFrame("Frame")
local elapsed = 0
poll:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.2 then return end
    elapsed = 0
    Sync()
end)

-- Closing our window closes Blizzard's bags, so both agree again.
window.close:SetScript("OnClick", function() CloseAllBags() end)

window.sort:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
    C_Container.SortBags()
end)

window:SetScript("OnHide", function(self)
    -- a focused search box would keep swallowing the keyboard
    self.search:ClearFocus()
end)

-------------------------------------------------------------------
-- Startup
-------------------------------------------------------------------
function ns.InitBags()
    ParkBlizzardFrames()
    D.MakeMovable(window, "Bags", DeckBagsDB)
    D.MakeDraggable(window)
    Sync()
end

-- /bags debug: what the window is built from
function ns.PrintBags()
    print(("DeckUI Bags: Blizzard says open=%s, our window shown=%s"):format(
        tostring(IsAnyBagOpen()), tostring(window:IsShown())))
    for bag = BACKPACK, REAGENT do
        print(("  bag %d: %d slots, %d free"):format(bag,
            C_Container.GetContainerNumSlots(bag), C_Container.GetContainerNumFreeSlots(bag) or 0))
    end
    local parked = 0
    for _, f in ipairs(BlizzardFrames()) do
        if f and f:GetParent() == hider then parked = parked + 1 end
    end
    print(("  Blizzard bag frames parked: %d of %d"):format(parked, #BlizzardFrames()))

    -- what the old-expansions filter sees: items per expansion, "?" = not cached yet
    local perExpansion = {}
    for _, bag in ipairs(ALL) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                local e = ns.ItemExpansion(info.itemID)
                e = e == nil and "?" or tostring(e)
                perExpansion[e] = (perExpansion[e] or 0) + 1
            end
        end
    end
    local parts = {}
    for e, n in pairs(perExpansion) do parts[#parts + 1] = e .. ":" .. n end
    table.sort(parts)
    print(("  current expansion %s; items per expansion %s"):format(
        tostring(ns.CurrentExpansion()), table.concat(parts, "  ")))
end

-------------------------------------------------------------------
-- Module startup (normal login AND load on demand via the menu)
-------------------------------------------------------------------
local function Init()
    DeckBagsDB = DeckBagsDB or {}
    if DeckBagsDB.itemLevel == nil then DeckBagsDB.itemLevel = true end
    if DeckBagsDB.markJunk  == nil then DeckBagsDB.markJunk  = true end
    if DeckBagsDB.categories == nil then DeckBagsDB.categories = true end
    ns.InitBags()
    if ns.InitBank then ns.InitBank() end
end

if IsLoggedIn() then
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, name)
        if name == ADDON then
            self:UnregisterEvent("ADDON_LOADED")
            Init()
        end
    end)
else
    local login = CreateFrame("Frame")
    login:RegisterEvent("PLAYER_LOGIN")
    login:SetScript("OnEvent", Init)
end

-- /bags opens and closes the bags the way B does; /bags config opens the
-- tab, /bags debug and /bags bank print what the windows are built from.
SLASH_DECKBAGS1 = "/bags"
SlashCmdList.DECKBAGS = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "config" then
        D.ToggleConfig("Bags")
    elseif msg == "debug" then
        ns.PrintBags()
    elseif msg == "bank" then
        ns.PrintBank()
    else
        ToggleAllBags()
    end
end

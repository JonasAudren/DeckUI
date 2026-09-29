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

local function Sections()
    local held = {}
    for bag = BACKPACK, NUM_BAGS do held[#held + 1] = bag end
    return {
        { bags = held },
        { title = "Reagents", bags = { REAGENT } },
    }
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
    return Sections(), d.columns, d.scale
end

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
end

-------------------------------------------------------------------
-- Module startup (normal login AND load on demand via the menu)
-------------------------------------------------------------------
local function Init()
    DeckBagsDB = DeckBagsDB or {}
    if DeckBagsDB.itemLevel == nil then DeckBagsDB.itemLevel = true end
    if DeckBagsDB.markJunk  == nil then DeckBagsDB.markJunk  = true end
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

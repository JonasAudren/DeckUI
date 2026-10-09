local D = DeckUI

-------------------------------------------------------------------
-- Server info, gold and the bag overview, as FFXIV shows them
-------------------------------------------------------------------
-- The owner's wish (2026-10-09, his annotated FFXIV screenshots): three
-- small pieces of FFXIV's screen, each its own checkbox on the Overview
-- page, all off by default and undone by unticking - hidden at once, their
-- events and timers stopped, nothing of Blizzard's touched.
--   Server info (DeckUIDB.infoServer): realm, a letter when mail waits,
--     latency and the time, on a dark band ("Server-Info").
--   Gold (DeckUIDB.infoGold): the gold you carry with a coin ("Gil").
--   Bag overview (DeckUIDB.infoBags): one block of dots per bag, bright
--     for a used slot, dark for a free one ("Inventarschema"). A click
--     opens the bags.
--
-- The bag overview's click is Blizzard's own backpack button, clicked by a
-- secure action button (type "click"): our Lua never calls ToggleAllBags,
-- which would run the bank's opening tainted (see the Bags notes in
-- CLAUDE.md). Being secure, that button only shows and hides out of
-- combat; a change in combat waits for the fight to end.
-------------------------------------------------------------------
local function Text(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(D.FONT, size, "OUTLINE")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function Band(frame)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)
end

local function Tooltip(frame, fill)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        fill(GameTooltip)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)
end

-------------------------------------------------------------------
-- Server info
-------------------------------------------------------------------
local server = CreateFrame("Frame", "DeckInfoServer", UIParent)
server:SetSize(220, 20)
server.defaultPoint = { "TOPRIGHT", UIParent, "TOPRIGHT", -8, -4 }
server:SetPoint(unpack(server.defaultPoint))
server:Hide()
Band(server)

local serverText = Text(server, 12, "RIGHT")
serverText:SetPoint("RIGHT", -6, 0)
local mail = server:CreateTexture(nil, "OVERLAY")
mail:SetSize(14, 14)
mail:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")

local GREEN, YELLOW, RED = "|cff66ff66", "|cffffd24d", "|cffff5555"

local function LatencyColour(ms)
    if ms < 100 then return GREEN elseif ms < 250 then return YELLOW end
    return RED
end

local function FpsColour(fps)
    if fps >= 50 then return GREEN elseif fps >= 30 then return YELLOW end
    return RED
end

-- Frame rate, CPU and memory (owner's wish 2026-10-09). The game has no
-- answer for the machine's CPU; what it measures is the time addons take
-- each frame (C_AddOnProfiler, 11.1+), shown as a share of the whole
-- frame. Memory is the UI's Lua memory, collectgarbage("count") - cheap,
-- unlike UpdateAddOnMemoryUsage, which only runs for the tooltip.
local RECENT = Enum.AddOnProfilerMetric and Enum.AddOnProfilerMetric.RecentAverageTime

local function AddonShare()
    if not (C_AddOnProfiler and RECENT) then return nil end
    local ok, addons, app = pcall(function()
        return C_AddOnProfiler.GetOverallMetric(RECENT), C_AddOnProfiler.GetApplicationMetric(RECENT)
    end)
    if not ok or type(addons) ~= "number" then return nil end
    if type(app) == "number" and app > 0 then return addons / app * 100, addons end
    return nil, addons
end

-- Which values the line shows, each on its own switch (DeckUIDB.infoParts,
-- owner's wish 2026-10-09: the line had grown long). In this order.
D.INFO_PARTS = { "realm", "fps", "cpu", "mem", "latency", "clock" }
D.INFO_PART_NAMES = { realm = "Realm", fps = "FPS", cpu = "CPU", mem = "Memory",
                      latency = "Latency", clock = "Clock" }

local function Parts()
    DeckUIDB.infoParts = DeckUIDB.infoParts or {}
    for _, key in ipairs(D.INFO_PARTS) do
        if DeckUIDB.infoParts[key] == nil then DeckUIDB.infoParts[key] = true end
    end
    return DeckUIDB.infoParts
end
D.InfoParts = Parts

local PART_TEXT = {
    realm = function() return GetRealmName() or "" end,
    fps = function()
        local fps = GetFramerate() or 0
        return ("%s%d fps|r"):format(FpsColour(fps), fps)
    end,
    cpu = function()
        local share, addonMs = AddonShare()
        return share and ("CPU %.0f%%"):format(share) or addonMs and ("CPU %.1f ms"):format(addonMs) or "CPU -"
    end,
    mem = function() return ("MEM %.0f MB"):format(collectgarbage("count") / 1024) end,
    latency = function()
        local _, _, home, world = GetNetStats()
        local ms = math.max(home or 0, world or 0)
        return ("%s%d ms|r"):format(LatencyColour(ms), ms)
    end,
    clock = function() return date("%H:%M") end,
}

local pieces = {}
local function UpdateServer()
    local parts = Parts()
    wipe(pieces)
    for _, key in ipairs(D.INFO_PARTS) do
        if parts[key] then pieces[#pieces + 1] = PART_TEXT[key]() end
    end
    local hasMail = HasNewMail()
    serverText:SetText(table.concat(pieces, "    "))
    mail:ClearAllPoints()
    mail:SetPoint("RIGHT", serverText, "LEFT", -6, 0)
    mail:SetShown(hasMail and true or false)
    local width = serverText:GetStringWidth() + (hasMail and 26 or 0) + 14
    server:SetWidth(math.max(120, math.ceil(width)))
end

local serverTicker
server:SetScript("OnShow", function()
    UpdateServer()
    serverTicker = C_Timer.NewTicker(1, UpdateServer)
end)
server:SetScript("OnHide", function()
    if serverTicker then serverTicker:Cancel() end
    serverTicker = nil
end)
server:EnableMouse(true)

-- the five addons that take the most, by a value per addon name
local function Top(value)
    local all = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        if C_AddOns.IsAddOnLoaded(i) then
            local name = C_AddOns.GetAddOnInfo(i)
            local v = value(i, name)
            if type(v) == "number" and v > 0 then all[#all + 1] = { name = name, v = v } end
        end
    end
    table.sort(all, function(a, b) return a.v > b.v end)
    return all
end

Tooltip(server, function(tip)
    local _, _, home, world = GetNetStats()
    tip:AddLine(GetRealmName() or "")
    tip:AddDoubleLine("Latency home / world", ("%d / %d ms"):format(home or 0, world or 0), 1, 1, 1, 1, 1, 1)
    local h, m = GetGameTime()
    tip:AddDoubleLine("Realm time", ("%02d:%02d"):format(h, m), 1, 1, 1, 1, 1, 1)
    if HasNewMail() then tip:AddLine("Mail is waiting.", 1, 0.82, 0) end

    local share, addonMs = AddonShare()
    if addonMs then
        tip:AddLine(" ")
        tip:AddDoubleLine("Addons per frame", ("%.2f ms%s"):format(addonMs,
            share and (" (%.0f%% of the frame)"):format(share) or ""), 1, 0.82, 0, 1, 1, 1)
        local cpu = Top(function(_, name)
            local ok, v = pcall(C_AddOnProfiler.GetAddOnMetric, name, RECENT)
            return ok and v or nil
        end)
        for i = 1, math.min(5, #cpu) do
            tip:AddDoubleLine("  " .. cpu[i].name, ("%.2f ms"):format(cpu[i].v), 1, 1, 1, 1, 1, 1)
        end
    else
        tip:AddLine(" ")
        tip:AddLine("CPU: this client does not measure addon time.", 0.6, 0.6, 0.6)
    end

    UpdateAddOnMemoryUsage()
    local memory = Top(function(i) return GetAddOnMemoryUsage(i) end)
    tip:AddLine(" ")
    tip:AddDoubleLine("UI memory", ("%.1f MB"):format(collectgarbage("count") / 1024), 1, 0.82, 0, 1, 1, 1)
    for i = 1, math.min(5, #memory) do
        tip:AddDoubleLine("  " .. memory[i].name, ("%.1f MB"):format(memory[i].v / 1024), 1, 1, 1, 1, 1, 1)
    end
end)

-------------------------------------------------------------------
-- Gold
-------------------------------------------------------------------
local gold = CreateFrame("Frame", "DeckInfoGold", UIParent)
gold:SetSize(110, 22)
gold.defaultPoint = { "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -8, 6 }
gold:SetPoint(unpack(gold.defaultPoint))
gold:Hide()
Band(gold)

local coin = gold:CreateTexture(nil, "OVERLAY")
coin:SetSize(14, 14)
coin:SetPoint("RIGHT", -6, 0)
coin:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
local goldText = Text(gold, 13, "RIGHT")
goldText:SetPoint("RIGHT", coin, "LEFT", -4, 0)

local function UpdateGold()
    goldText:SetText(BreakUpLargeNumbers(math.floor(GetMoney() / 10000)))
    gold:SetWidth(math.max(70, math.ceil(goldText:GetStringWidth() + 34)))
end

gold:SetScript("OnEvent", UpdateGold)
gold:SetScript("OnShow", function(self)
    self:RegisterEvent("PLAYER_MONEY")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    UpdateGold()
end)
gold:SetScript("OnHide", function(self) self:UnregisterAllEvents() end)
gold:EnableMouse(true)
Tooltip(gold, function(tip)
    tip:AddLine("Gold")
    tip:AddLine(GetMoneyString(GetMoney(), true), 1, 1, 1)
end)

-------------------------------------------------------------------
-- Bag overview
-------------------------------------------------------------------
local DOT, GAP, COLS, PAD, BLOCK_GAP = 3, 1, 6, 5, 5
local BAGS = { 0, 1, 2, 3, 4, 5 }   -- backpack, four bags, the reagent bag
local USED = { 0.95, 0.85, 0.55, 1 }
local USED_REAGENT = { 0.55, 0.85, 0.95, 1 }
local FREE = { 0.22, 0.22, 0.22, 1 }

local bags = CreateFrame("Button", "DeckInfoBags", UIParent, "SecureActionButtonTemplate")
bags:SetSize(60, 30)
bags.defaultPoint = { "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -8, 34 }
bags:SetPoint(unpack(bags.defaultPoint))
-- down and up: the secure template acts on the one ActionButtonUseKeyDown
-- names, and with only "AnyUp" a click did nothing (owner's test 2026-10-09)
bags:RegisterForClicks("AnyUp", "AnyDown")
bags:Hide()
Band(bags)

local freeText = Text(bags, 11, "RIGHT")
freeText:SetPoint("BOTTOMRIGHT", bags, "TOPRIGHT", -2, 2)

local dots = {}   -- bag -> list of textures, made as slots appear

local function Dot(bag, i)
    dots[bag] = dots[bag] or {}
    local t = dots[bag][i]
    if not t then
        t = bags:CreateTexture(nil, "ARTWORK")
        t:SetSize(DOT, DOT)
        t:SetTexture("Interface\\Buttons\\WHITE8x8")
        dots[bag][i] = t
    end
    return t
end

local function UpdateBags()
    local x, height, freeTotal = PAD, 0, 0
    for _, bag in ipairs(BAGS) do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        local list = dots[bag] or {}
        for i = slots + 1, #list do list[i]:Hide() end
        if slots > 0 then
            local used = bag == 5 and USED_REAGENT or USED
            for i = 1, slots do
                local t = Dot(bag, i)
                local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", bags, "TOPLEFT", x + col * (DOT + GAP), -PAD - row * (DOT + GAP))
                local c = C_Container.GetContainerItemID(bag, i) and used or FREE
                t:SetVertexColor(c[1], c[2], c[3], c[4])
                t:Show()
            end
            freeTotal = freeTotal + (C_Container.GetContainerNumFreeSlots(bag) or 0)
            x = x + COLS * (DOT + GAP) - GAP + BLOCK_GAP
            height = math.max(height, math.ceil(slots / COLS) * (DOT + GAP) - GAP)
        end
    end
    freeText:SetText(freeTotal)
    if not InCombatLockdown() then
        bags:SetSize(x - BLOCK_GAP + PAD, height + 2 * PAD)
    end
end

bags:SetScript("OnEvent", UpdateBags)
bags:SetScript("OnShow", function(self)
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    UpdateBags()
end)
bags:SetScript("OnHide", function(self) self:UnregisterAllEvents() end)
Tooltip(bags, function(tip)
    tip:AddLine("Bags")
    for _, bag in ipairs(BAGS) do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        if slots > 0 then
            local free = C_Container.GetContainerNumFreeSlots(bag) or 0
            local name = bag == 0 and "Backpack" or bag == 5 and "Reagent bag" or ("Bag " .. bag)
            tip:AddDoubleLine(name, ("%d of %d free"):format(free, slots), 1, 1, 1, 1, 1, 1)
        end
    end
    tip:AddLine("Click: open the bags", 0.6, 0.6, 0.6)
end)

-------------------------------------------------------------------
-- Switching
-------------------------------------------------------------------
local pendingBags = false

-- Blizzard's bag buttons at the bottom right (DeckUIDB.hideBagBar, off by
-- default; owner's wish 2026-10-09, with the overview they were twice
-- there). BagsBar is an Edit Mode system: Edit Mode re-applies its points,
-- never its parent, so it is parked under a hidden parent like the buff
-- frames and given back its own parent when unticked. The overview's
-- click still reaches the backpack button there - Click() does not ask
-- whether a button is visible.
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
local bagBarParent

local function SetBagBarHidden(hide)
    local bar = _G.BagsBar
    if not bar then return end
    if hide and bar:GetParent() ~= hiddenParent then
        bagBarParent = bar:GetParent()
        bar:SetParent(hiddenParent)
    elseif not hide and bar:GetParent() == hiddenParent then
        bar:SetParent(bagBarParent or UIParent)
    end
end

function D.ApplyInfoBars()
    server:SetShown(DeckUIDB.infoServer and true or false)
    if server:IsShown() then UpdateServer() end
    gold:SetShown(DeckUIDB.infoGold and true or false)
    if InCombatLockdown() then
        pendingBags = true
        return
    end
    pendingBags = false
    local backpack = _G.MainMenuBarBackpackButton
    if backpack then
        bags:SetAttribute("type", "click")
        bags:SetAttribute("clickbutton", backpack)
    elseif DeckUIDB.infoBags then
        print("DeckUI: Blizzard's backpack button was not found - the bag overview cannot open the bags.")
    end
    bags:SetShown(DeckUIDB.infoBags and true or false)
    SetBagBarHidden(DeckUIDB.hideBagBar and true or false)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        D.MakeMovable(server, "Server info", DeckUIDB)
        D.MakeMovable(gold, "Gold", DeckUIDB)
        D.MakeMovable(bags, "Bag overview", DeckUIDB)
        D.ApplyInfoBars()
    elseif pendingBags then
        D.ApplyInfoBars()
    end
end)

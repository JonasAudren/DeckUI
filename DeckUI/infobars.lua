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

local function LatencyColour(ms)
    if ms < 100 then return "|cff66ff66" elseif ms < 250 then return "|cffffd24d" end
    return "|cffff5555"
end

local function UpdateServer()
    local _, _, home, world = GetNetStats()
    local ms = math.max(home or 0, world or 0)
    local hasMail = HasNewMail()
    serverText:SetText(("%s    %s%d ms|r    %s"):format(GetRealmName() or "",
        LatencyColour(ms), ms, date("%H:%M")))
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
Tooltip(server, function(tip)
    local _, _, home, world = GetNetStats()
    tip:AddLine(GetRealmName() or "")
    tip:AddDoubleLine("Latency home / world", ("%d / %d ms"):format(home or 0, world or 0), 1, 1, 1, 1, 1, 1)
    local h, m = GetGameTime()
    tip:AddDoubleLine("Realm time", ("%02d:%02d"):format(h, m), 1, 1, 1, 1, 1, 1)
    if HasNewMail() then tip:AddLine("Mail is waiting.", 1, 0.82, 0) end
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

function D.ApplyInfoBars()
    server:SetShown(DeckUIDB.infoServer and true or false)
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

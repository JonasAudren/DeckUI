local D = DeckUI

-------------------------------------------------------------------
-- Loot: fast auto loot and a loot window of our own
-------------------------------------------------------------------
-- Part of replacing Plumber (owner's decision, 2026-10-01). Read from
-- Plumber 1.9.4 (LootUI_Display.lua) and Blizzard's 12.1.0 LootFrame.lua,
-- rebuilt small on DeckUI's rules. In the hub, so it works without any
-- module; both switches in the General tab, off by default.
--
-- Fast auto loot: on LOOT_READY - the earliest moment - every slot is
-- taken with LootSlot. "Auto" is worked out here (the autoLootDefault
-- CVar, flipped while the auto-loot modifier is held) instead of trusting
-- the event's flag, which is Plumber's fix for auto loot that sometimes
-- arrives as manual.
--
-- The window: Blizzard's LootFrame only stops listening to LOOT_OPENED
-- and LOOT_CLOSED (UnregisterEvent - a method, no Lua state written), so
-- it never opens; ours does instead. Everything on it is a C call:
-- LootSlot, CloseLoot, GetLootSlotInfo. Shown for manual loot, and after
-- auto loot only when something stayed behind (full bags, a roll still
-- running). Confirming bind-on-pickup stays Blizzard's: its LOOT_BIND
-- dialog comes from UIParent's own handler, untouched. Group rolls are
-- not touched either.
-------------------------------------------------------------------
local W, ROW, ICON, PAD = 250, 34, 28, 6
local WHITE = "Interface\\Buttons\\WHITE8x8"

local function Plain(v) return not (issecretvalue and issecretvalue(v)) end

local function AutoLoot()
    return GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE")
end

local function TakeAll()
    for slot = GetNumLootItems(), 1, -1 do LootSlot(slot) end
end

-------------------------------------------------------------------
-- The window
-------------------------------------------------------------------
local win = CreateFrame("Frame", "DeckUILootWindow", UIParent)
win:SetSize(W, 80)
win:SetFrameStrata("DIALOG")
win:SetToplevel(true)
win:EnableMouse(true)
win:SetClampedToScreen(true)
win.defaultPoint = { "LEFT", UIParent, "LEFT", 320, 120 }
win:SetPoint(unpack(win.defaultPoint))
win:Hide()
tinsert(UISpecialFrames, "DeckUILootWindow")

do  -- a fill and four one-pixel lines, anchored only
    local bg = win:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.92)
    for _, p in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                         { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = win:CreateTexture(nil, "BORDER")
        t:SetColorTexture(0.3, 0.3, 0.3, 1)
        t:SetPoint(p[1])
        t:SetPoint(p[2])
        if p[3] then t:SetHeight(1) else t:SetWidth(1) end
    end
end

local title = win:CreateFontString(nil, "OVERLAY")
title:SetFont(D.FONT, 13, "OUTLINE")
title:SetPoint("TOPLEFT", PAD + 2, -8)
title:SetText(LOOT or "Loot")

local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)
close:SetScript("OnClick", function() CloseLoot() end)

local takeAll = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
takeAll:SetSize(110, 22)
takeAll:SetPoint("BOTTOM", 0, 8)
takeAll:SetText("Take all")
takeAll:SetScript("OnClick", TakeAll)

local rows = {}

local function RowOnEnter(self)
    local slot = self.slot
    if not slot then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local kind = GetLootSlotType(slot)
    if kind == Enum.LootSlotType.Item then
        GameTooltip:SetLootItem(slot)
    elseif kind == Enum.LootSlotType.Currency then
        GameTooltip:SetLootCurrency(slot)
    else
        GameTooltip:SetText(self.name:GetText() or "")
    end
    GameTooltip:Show()
end

local function RowOnClick(self)
    if not self.slot then return end
    if IsModifiedClick() then
        HandleModifiedItemClick(GetLootSlotLink(self.slot))
    else
        LootSlot(self.slot)
    end
end

local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, win)
    r:SetSize(W - 2 * PAD, ROW)
    r:SetPoint("TOPLEFT", PAD, -28 - (i - 1) * (ROW + 2))
    r:RegisterForClicks("LeftButtonUp")
    r:SetHighlightTexture(WHITE)
    r:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ICON, ICON)
    r.icon:SetPoint("LEFT", 2, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.count = r:CreateFontString(nil, "OVERLAY")
    r.count:SetFont(D.FONT, 11, "OUTLINE")
    r.count:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 1, -1)
    r.name = r:CreateFontString(nil, "OVERLAY")
    r.name:SetFont(D.FONT, 12, "OUTLINE")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -2)
    r.name:SetPoint("RIGHT", -4, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.note = r:CreateFontString(nil, "OVERLAY")
    r.note:SetFont(D.FONT, 10, "OUTLINE")
    r.note:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 2)
    r:SetScript("OnClick", RowOnClick)
    r:SetScript("OnEnter", RowOnEnter)
    r:SetScript("OnLeave", GameTooltip_Hide)
    rows[i] = r
    return r
end

-- an appearance the player has not collected yet
local function NewLook(link)
    if not (link and C_Item.IsDressableItemByID and C_Item.IsDressableItemByID(link)) then return false end
    local has = C_TransmogCollection.PlayerHasTransmogByItemInfo
        and C_TransmogCollection.PlayerHasTransmogByItemInfo(link)
    return has == false
end

local function Fill()
    local shown = 0
    for slot = 1, GetNumLootItems() do
        local texture, name, quantity, currencyID, quality, locked, isQuestItem, _, _, isCoin = GetLootSlotInfo(slot)
        if currencyID and CurrencyContainerUtil then
            name, texture, quantity, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(currencyID, quantity, name, texture, quality)
        end
        if texture then
            shown = shown + 1
            local r = Row(shown)
            r.slot = slot
            r.icon:SetTexture(texture)
            r.icon:SetDesaturated(locked and true or false)
            r.count:SetText((not isCoin and quantity and Plain(quantity) and quantity > 1) and quantity or "")
            r.name:SetText(name or "")
            local color = quality and Plain(quality) and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
            if isCoin then
                r.name:SetTextColor(1, 0.82, 0)
            elseif color then
                r.name:SetTextColor(color.r, color.g, color.b)
            else
                r.name:SetTextColor(1, 1, 1)
            end
            local note = ""
            if isQuestItem then
                note = "|cffffd100" .. (ITEM_BIND_QUEST or "Quest Item") .. "|r"
            elseif GetLootSlotType(slot) == Enum.LootSlotType.Item and NewLook(GetLootSlotLink(slot)) then
                note = "|cff66ccffNew appearance|r"
            elseif locked then
                note = "|cff999999" .. (LOCKED or "Locked") .. "|r"
            end
            r.note:SetText(note)
            r:Show()
        end
    end
    for i = shown + 1, #rows do
        rows[i].slot = nil
        rows[i]:Hide()
    end
    win:SetHeight(28 + shown * (ROW + 2) + 38)
    return shown
end

-- an empty window has nothing to say: ending the loot closes it
local function Refresh()
    if Fill() == 0 then CloseLoot() end
end

win:SetScript("OnHide", function()
    GameTooltip_Hide()
    CloseLoot()
end)

-------------------------------------------------------------------
-- Blizzard's window on or off
-------------------------------------------------------------------
local function ApplyWindow()
    if not LootFrame then return end
    if DeckUIDB.lootWindow then
        LootFrame:UnregisterEvent("LOOT_OPENED")
        LootFrame:UnregisterEvent("LOOT_CLOSED")
    else
        LootFrame:RegisterEvent("LOOT_OPENED")
        LootFrame:RegisterEvent("LOOT_CLOSED")
        win:Hide()
    end
end
D.ApplyLootWindow = ApplyWindow

-- key binding (Bindings.xml): take everything while the window is open
function D.LootAll()
    if win:IsShown() then TakeAll() end
end

-------------------------------------------------------------------
-- Events
-------------------------------------------------------------------
local lootOpen = false
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("LOOT_READY")
ev:RegisterEvent("LOOT_OPENED")
ev:RegisterEvent("LOOT_CLOSED")
ev:RegisterEvent("LOOT_SLOT_CLEARED")
ev:RegisterEvent("LOOT_SLOT_CHANGED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        D.MakeMovable(win, "Loot", DeckUIDB)
        -- a window like the bags: dragged by its frame, the place kept per device
        D.MakeDraggable(win)
        ApplyWindow()
        return
    end
    if not DeckUIDB then return end

    if event == "LOOT_READY" then
        if DeckUIDB.fastLoot and AutoLoot() then TakeAll() end
    elseif event == "LOOT_OPENED" then
        lootOpen = true
        if not DeckUIDB.lootWindow then return end
        if AutoLoot() then
            -- the slots are being taken; show only what stays behind
            TakeAll()
            C_Timer.After(0.3, function()
                if lootOpen and Fill() > 0 then win:Show() end
            end)
        elseif Fill() > 0 then
            win:Show()
        else
            CloseLoot()
        end
    elseif event == "LOOT_CLOSED" then
        lootOpen = false
        win:Hide()
    elseif win:IsShown() then
        -- LOOT_SLOT_CLEARED / LOOT_SLOT_CHANGED
        Refresh()
    end
end)

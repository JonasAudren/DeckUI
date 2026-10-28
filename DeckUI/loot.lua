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

-- Whether a loot is open right now: LOOT_READY/LOOT_OPENED to LOOT_CLOSED.
-- Every slot call goes through this. Mists crashed the client
-- (ACCESS_VIOLATION, seven times on 27/28.10) with our window still up after
-- the loot had closed (owner saw it, 2026-10-28) - a click, a tooltip or a
-- refill then asks about slots of a loot that is gone.
local lootOpen = false

-- A slot is only read while it holds something: Blizzard's LootFrame asks
-- LootSlotHasItem before GetLootSlotInfo (Mists' LootFrame.lua, read
-- 2026-10-28), and a slot taken a moment ago - a bind-on-pickup item from a
-- satchel - stayed in our window and was read again; the client crashed.
local function HasItem(slot)
    return lootOpen and slot and slot <= GetNumLootItems() and LootSlotHasItem(slot) and true or false
end

local function TakeAll()
    if not lootOpen then return end
    for slot = GetNumLootItems(), 1, -1 do
        if HasItem(slot) then LootSlot(slot) end
    end
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
    if not HasItem(slot) then return end
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
    if not HasItem(self.slot) then return end
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
    for slot = 1, lootOpen and GetNumLootItems() or 0 do
        local texture, name, quantity, currencyID, quality, locked, isQuestItem, isCoin, _
        if HasItem(slot) then
            texture, name, quantity, currencyID, quality, locked, isQuestItem, _, _, isCoin = GetLootSlotInfo(slot)
        end
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
    if Fill() == 0 and lootOpen then CloseLoot() end
end

-- closed by the player (X, Escape): that ends the loot. Hidden because the
-- loot closed: nothing to end - CloseLoot inside LOOT_CLOSED is not asked for
win:SetScript("OnHide", function()
    GameTooltip_Hide()
    if lootOpen then CloseLoot() end
end)

-- the window never outlives its loot: twice a second it checks the loot is
-- still open (unlocked, it stays as a sample to drag)
local sinceCheck = 0
win:SetScript("OnUpdate", function(self, dt)
    sinceCheck = sinceCheck + dt
    if sinceCheck < 0.5 then return end
    sinceCheck = 0
    if not lootOpen and not D.IsUnlocked("Loot") then self:Hide() end
end)

-------------------------------------------------------------------
-- Blizzard's window on or off
-------------------------------------------------------------------
local function ApplyWindow()
    if not LootFrame then return end
    if DeckUIDB.lootWindow then
        LootFrame:UnregisterEvent("LOOT_OPENED")
        -- Mists' LOOT_CLOSED also hides the bind-on-pickup question
        -- (LootFrame_Close: StaticPopup_Hide("LOOT_BIND")), which must not
        -- outlive its loot; the frame itself was never shown
        if not D.IsMists then LootFrame:UnregisterEvent("LOOT_CLOSED") end
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
-- The feed: what auto loot just took
-------------------------------------------------------------------
-- With auto loot the window has nothing to offer - everything is taken at
-- once - and the owner saw only the chat (2026-10-01). So what the slots
-- held is read the moment the loot is ready, before it is taken, and
-- listed at the window's place for a few seconds, newest on top: loot
-- from several corpses in a row adds up. Read from the slots, not from
-- the chat lines, which can be secret in Midnight's instances.
local FEED_MAX, FEED_TIME, FEED_FADE = 8, 5, 1
local feed = CreateFrame("Frame", "DeckUILootFeed", UIParent)
feed:SetSize(W, 40)
feed:SetFrameStrata("MEDIUM")
-- a place of its own, moved like the window: by its frame, or with
-- /deck unlock, which shows both with a sample to grab
feed:EnableMouse(true)
feed:SetClampedToScreen(true)
feed.defaultPoint = { "LEFT", UIParent, "LEFT", 320, 260 }
feed:SetPoint(unpack(feed.defaultPoint))
local preview = false
feed:Hide()
do
    local bg = feed:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.8)
end

local entries = {}     -- { texture, name, count, color, time }
local feedRows = {}

local function FeedRow(i)
    local r = feedRows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, feed)
    r:SetSize(W - 2 * PAD, 22)
    r:SetPoint("TOPLEFT", PAD, -PAD - (i - 1) * 24)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT")
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = r:CreateFontString(nil, "OVERLAY")
    r.name:SetFont(D.FONT, 12, "OUTLINE")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.name:SetPoint("RIGHT", -4, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    feedRows[i] = r
    return r
end

local function DrawFeed()
    for i, e in ipairs(entries) do
        local r = FeedRow(i)
        r.icon:SetTexture(e.texture)
        r.name:SetText(e.count and e.count > 1 and ("%s |cffffffffx%d|r"):format(e.name, e.count) or e.name)
        r.name:SetTextColor(e.color[1], e.color[2], e.color[3])
        r:Show()
    end
    for i = #entries + 1, #feedRows do feedRows[i]:Hide() end
    feed:SetHeight(2 * PAD + #entries * 24)
    feed:SetShown(#entries > 0)
end

feed:SetScript("OnUpdate", function(self)
    if preview then self:SetAlpha(1) return end
    local now, changed = GetTime(), false
    for i = #entries, 1, -1 do
        if now - entries[i].time > FEED_TIME + FEED_FADE then
            table.remove(entries, i)
            changed = true
        end
    end
    if changed then DrawFeed() end
    -- the whole list fades with its newest entry
    local newest = entries[1]
    if newest then
        local left = FEED_TIME + FEED_FADE - (now - newest.time)
        self:SetAlpha(math.min(1, left / FEED_FADE))
    end
end)

-- what the slots hold right now, before anything is taken
local function CaptureSlots()
    local now = GetTime()
    for slot = 1, lootOpen and GetNumLootItems() or 0 do
        local texture, name, quantity, currencyID, quality, isCoin, _
        if HasItem(slot) then
            texture, name, quantity, currencyID, quality, _, _, _, _, isCoin = GetLootSlotInfo(slot)
        end
        if currencyID and CurrencyContainerUtil then
            name, texture, quantity, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(currencyID, quantity, name, texture, quality)
        end
        if texture and name and Plain(name) then
            local color = { 1, 1, 1 }
            local q = quality and Plain(quality) and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
            if isCoin then
                color = { 1, 0.82, 0 }
            elseif q then
                color = { q.r, q.g, q.b }
            end
            local count = not isCoin and quantity and Plain(quantity) and quantity or nil
            table.insert(entries, 1, { texture = texture, name = name, count = count, color = color, time = now })
        end
    end
    while #entries > FEED_MAX do table.remove(entries) end
    feed:SetAlpha(1)
    DrawFeed()
end

-------------------------------------------------------------------
-- Events
-------------------------------------------------------------------
local captured = false   -- this loot already went into the feed
local taken = false      -- this loot's slots were already asked for once
local closed = false     -- LOOT_CLOSED came after this loot's LOOT_READY
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
        D.MakeMovable(feed, "Loot list", DeckUIDB)
        D.MakeDraggable(feed)
        -- unlocked, both show with a sample so there is something to drag
        D.OnUnlock(function(state, only)
            -- unlocked for another page's frames: nothing to show here
            if only and not (only["Loot"] or only["Loot list"]) then state = false end
            preview = state and true or false
            if state then
                wipe(entries)
                entries[1] = { texture = 133784, name = "Loot list", count = 3, color = { 1, 0.82, 0 }, time = GetTime() }
                entries[2] = { texture = 134400, name = "Drag me", color = { 0.6, 0.6, 0.6 }, time = GetTime() }
                DrawFeed()
                if not lootOpen then Fill() win:Show() end
            else
                wipe(entries)
                DrawFeed()
                if not lootOpen then win:Hide() end
            end
        end)
        ApplyWindow()
        return
    end
    if not DeckUIDB then return end

    if event == "LOOT_READY" then
        -- fires again while a loot is open; a new loot starts after a close
        if not lootOpen then lootOpen, closed, captured, taken = true, false, false, false end
        local auto = AutoLoot()
        if auto and DeckUIDB.lootWindow and not captured then
            captured = true
            CaptureSlots()
        end
        if DeckUIDB.fastLoot and auto and not taken then
            taken = true
            TakeAll()
        end
    elseif event == "LOOT_OPENED" then
        -- fast loot can empty a corpse before LOOT_OPENED arrives: a loot
        -- that closed already is not opened again
        if closed then return end
        lootOpen = true
        if not DeckUIDB.lootWindow then return end
        if AutoLoot() then
            if not captured then
                captured = true
                CaptureSlots()
            end
            -- the slots are being taken (once - asking twice for a slot that
            -- cannot be taken, a full quest item, only repeats the refusal);
            -- the window only for what stays behind
            if not taken then
                taken = true
                TakeAll()
            end
            C_Timer.After(0.3, function()
                if lootOpen and Fill() > 0 then win:Show() end
            end)
        elseif Fill() > 0 then
            win:Show()
        else
            CloseLoot()
        end
    elseif event == "LOOT_CLOSED" then
        lootOpen, closed, captured, taken = false, true, false, false
        win:Hide()
    elseif win:IsShown() then
        -- LOOT_SLOT_CLEARED / LOOT_SLOT_CHANGED
        Refresh()
    end
end)

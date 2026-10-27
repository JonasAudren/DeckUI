local D = DeckUI

-------------------------------------------------------------------
-- The character panel: item level per slot, missing enchants and gems
-------------------------------------------------------------------
-- Owner's wish (2026-10-27), for Mists of Pandaria Classic, where every
-- enchant and gem counts for raids and challenge modes (players use
-- BetterCharacterPanel for it). DeckUIDB.charPanel, off by default, on the
-- Overview page; only Mists' .toc lists this file - which slots take an
-- enchant differs per game, and Mists' is the one checked here.
--
-- On each of Blizzard's slot buttons (CharacterHeadSlot ...) sits a frame
-- of ours, a child kept in our own table: the item level bottom right in
-- the item's quality colour, and top left a red "E" when an enchant is
-- missing and a purple "G" when a socket is empty. Nothing is written
-- onto Blizzard's buttons, the overlay takes no mouse. Under the window a
-- line sums it up: average item level, missing enchants, empty sockets.
--
-- Reading an item: its link is "item:ID:enchant:gem1:gem2:gem3:gem4:...",
-- so the enchant is the second field and a filled socket a non-zero gem
-- field. The sockets come from C_Item.GetItemNumSockets on the link.
-- The belt's extra socket (Living Steel Belt Buckle) is not on the base
-- item: a belt with no more gems than its base item has sockets is
-- missing the buckle - or the gem in it.
-------------------------------------------------------------------
local SLOTS = {
    { 1, "Head" }, { 2, "Neck" }, { 3, "Shoulder" }, { 15, "Back" }, { 5, "Chest" },
    { 9, "Wrist" }, { 10, "Hands" }, { 6, "Waist" }, { 7, "Legs" }, { 8, "Feet" },
    { 11, "Finger0" }, { 12, "Finger1" }, { 13, "Trinket0" }, { 14, "Trinket1" },
    { 16, "MainHand" }, { 17, "SecondaryHand" },
}
-- Mists of Pandaria's enchantable slots (5.x): shoulders (Inscription's
-- secrets), back, chest, wrists, hands, legs, feet, both weapon slots.
-- Rings only for enchanters, who enchant their own.
local ENCHANT = { [3] = true, [15] = true, [5] = true, [9] = true, [10] = true,
    [7] = true, [8] = true, [16] = true, [17] = true }
local RINGS = { [11] = true, [12] = true }
local WAIST = 6
local ENCHANTING = 333   -- base skill line, 7th return of GetProfessionInfo

local overlays = {}   -- slot -> our frame on Blizzard's button
local summary

local function Enabled() return DeckUIDB and DeckUIDB.charPanel end

local function IsEnchanter()
    local p1, p2 = GetProfessions()
    for _, index in ipairs({ p1 or 0, p2 or 0 }) do
        if index > 0 and select(7, GetProfessionInfo(index)) == ENCHANTING then return true end
    end
    return false
end

-- enchant ID and filled gem count, read from the link's fields
local function ReadLink(link)
    local fields = link:match("item:([%-%d:]+)")
    if not fields then return 0, 0 end
    local parts = { strsplit(":", fields) }
    local enchant = tonumber(parts[2]) or 0
    local gems = 0
    for i = 3, 6 do
        if (tonumber(parts[i]) or 0) > 0 then gems = gems + 1 end
    end
    return enchant, gems
end

local function Overlay(slot, name)
    local f = overlays[slot]
    if f then return f end
    local button = _G["Character" .. name .. "Slot"]
    if not button then return nil end
    f = CreateFrame("Frame", nil, button)
    f:SetAllPoints()
    f:SetFrameLevel(button:GetFrameLevel() + 3)
    f:EnableMouse(false)
    f.ilvl = f:CreateFontString(nil, "OVERLAY")
    f.ilvl:SetFont(D.FONT, 11, "OUTLINE")
    f.ilvl:SetPoint("BOTTOMRIGHT", -1, 2)
    f.flags = f:CreateFontString(nil, "OVERLAY")
    f.flags:SetFont(D.FONT, 11, "OUTLINE")
    f.flags:SetPoint("TOPLEFT", 2, -2)
    overlays[slot] = f
    return f
end

local function Update()
    if not Enabled() then
        for _, f in pairs(overlays) do f:Hide() end
        if summary then summary:Hide() end
        return
    end
    local enchanter = IsEnchanter()
    local missingEnchants, emptySockets = 0, 0
    for _, s in ipairs(SLOTS) do
        local slot, name = s[1], s[2]
        local f = Overlay(slot, name)
        if f then
            local link = GetInventoryItemLink("player", slot)
            local ilvlText, flags = "", ""
            if link then
                local ilvl = C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)
                local quality = GetInventoryItemQuality("player", slot)
                local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
                ilvlText = ilvl and ((c and c.hex or "") .. ilvl .. "|r") or ""

                local enchant, gems = ReadLink(link)
                if (ENCHANT[slot] or (enchanter and RINGS[slot])) and enchant == 0 then
                    flags = flags .. "|cffff3030E|r"
                    missingEnchants = missingEnchants + 1
                end
                local sockets = C_Item.GetItemNumSockets and C_Item.GetItemNumSockets(link) or 0
                local empty = math.max(0, sockets - gems)
                if slot == WAIST then
                    -- the buckle's socket is not on the base item
                    local itemID = GetInventoryItemID("player", slot)
                    local base = itemID and C_Item.GetItemNumSockets and C_Item.GetItemNumSockets(itemID) or sockets
                    if gems <= base then empty = math.max(empty, base + 1 - gems) end
                end
                if empty > 0 then
                    flags = flags .. "|cffc060ffG|r"
                    emptySockets = emptySockets + empty
                end
            end
            f.ilvl:SetText(ilvlText)
            f.flags:SetText(flags)
            f:Show()
        end
    end

    if not summary and CharacterFrame then
        summary = CharacterFrame:CreateFontString(nil, "OVERLAY")
        summary:SetFont(D.FONT, 12, "OUTLINE")
        -- below the tabs that hang under the window - right under it, the
        -- line ran into them (owner's screenshot, 2026-10-27)
        summary:SetPoint("TOP", CharacterFrame, "BOTTOM", 0, -34)
    end
    if summary then
        local _, equipped = GetAverageItemLevel()
        local parts = { ("Item level %.1f"):format(equipped or 0) }
        parts[#parts + 1] = missingEnchants > 0 and ("|cffff3030%d missing enchant%s|r"):format(
            missingEnchants, missingEnchants == 1 and "" or "s") or "|cff33ff33all enchanted|r"
        parts[#parts + 1] = emptySockets > 0 and ("|cffc060ff%d empty socket%s|r"):format(
            emptySockets, emptySockets == 1 and "" or "s") or "|cff33ff33all gems in|r"
        summary:SetText(table.concat(parts, "   "))
        summary:Show()
    end
end

-- many events, one pass a frame later (item data may still be arriving)
local pending = false
local function Request()
    if pending then return end
    pending = true
    C_Timer.After(0.1, function()
        pending = false
        if CharacterFrame and CharacterFrame:IsShown() then Update() end
    end)
end

local hooked = false
function D.ApplyCharPanel()
    if not hooked and PaperDollFrame then
        hooked = true
        PaperDollFrame:HookScript("OnShow", Request)
    end
    if Enabled() then Request() else Update() end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "SOCKET_INFO_UPDATE", "GET_ITEM_INFO_RECEIVED",
    "SKILL_LINES_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        D.ApplyCharPanel()
    elseif Enabled() then
        Request()
    end
end)

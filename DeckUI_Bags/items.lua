local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Tracked items: counts of chosen items, shown like currencies
-------------------------------------------------------------------
-- The owner's choice (2026-10-01) over making Plumber's Backpack Item
-- Tracker fit: that one hangs off Blizzard's bag frames, which this module
-- parks out of sight, and it has no way for another bag addon to host it.
--
-- A row of its own above the footer of the bag window: drop an item on it
-- to track it, right-click an entry to stop. Dropping goes through the
-- cursor (GetCursorInfo, then ClearCursor puts the item back where it
-- came from), so the item buttons keep Blizzard's click handling untouched.
-- The list is account-wide (DeckBagsDB.trackedItems); the counts are the
-- character's own. Shown: what is in the bags; the tooltip adds bank and
-- warband bank.
-------------------------------------------------------------------
local MAX = 6
local ICON = 16
local window = ns.bags

local function List()
    DeckBagsDB.trackedItems = DeckBagsDB.trackedItems or {}
    return DeckBagsDB.trackedItems
end

local row = CreateFrame("Frame", nil, window)
row:SetPoint("BOTTOMLEFT", ns.PAD, ns.FOOTER)
row:SetPoint("BOTTOMRIGHT", -ns.PAD, ns.FOOTER)
row:SetHeight(20)
row:EnableMouse(true)

local hint = row:CreateFontString(nil, "OVERLAY")
hint:SetFont(D.FONT, 11, "OUTLINE")
hint:SetPoint("LEFT", 2, 0)
hint:SetTextColor(0.5, 0.5, 0.5)
hint:SetText("Drop an item here to track its count")

local entries = {}

local function AddFromCursor()
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or not itemID then return end
    ClearCursor()
    local list = List()
    for _, id in ipairs(list) do
        if id == itemID then return end
    end
    if #list >= MAX then
        print(("DeckUI Bags: up to %d tracked items - right-click one to make room."):format(MAX))
        return
    end
    list[#list + 1] = itemID
    ns.UpdateTrackedItems()
end

local function Remove(itemID)
    local list = List()
    for i, id in ipairs(list) do
        if id == itemID then table.remove(list, i) end
    end
    GameTooltip_Hide()
    ns.UpdateTrackedItems()
end

row:SetScript("OnReceiveDrag", AddFromCursor)
row:SetScript("OnMouseUp", AddFromCursor)

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetItemByID(self.itemID)
    local bags = C_Item.GetItemCount(self.itemID)
    local total = C_Item.GetItemCount(self.itemID, true, false, true, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("In your bags", BreakUpLargeNumbers(bags), 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("With bank and warband bank", BreakUpLargeNumbers(total), 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddLine("Right-click: stop tracking", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function Entry(i)
    local e = entries[i]
    if e then return e end
    e = CreateFrame("Button", nil, row)
    e:SetHeight(ICON + 2)
    e:RegisterForClicks("RightButtonUp")
    e.icon = e:CreateTexture(nil, "ARTWORK")
    e.icon:SetSize(ICON, ICON)
    e.icon:SetPoint("LEFT")
    e.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    e.text = e:CreateFontString(nil, "OVERLAY")
    e.text:SetFont(D.FONT, 12, "OUTLINE")
    e.text:SetPoint("LEFT", e.icon, "RIGHT", 3, 0)
    e:SetScript("OnClick", function(self) Remove(self.itemID) end)
    e:SetScript("OnEnter", OnEnter)
    e:SetScript("OnLeave", GameTooltip_Hide)
    -- an item dropped on an entry counts as dropped on the row
    e:SetScript("OnReceiveDrag", AddFromCursor)
    entries[i] = e
    return e
end

function ns.UpdateTrackedItems()
    local list = List()
    local anchor
    for i = 1, MAX do
        local itemID = list[i]
        local e = itemID and Entry(i) or entries[i]
        if itemID then
            e.itemID = itemID
            e.icon:SetTexture(C_Item.GetItemIconByID(itemID))
            local count = C_Item.GetItemCount(itemID)
            e.text:SetText(BreakUpLargeNumbers(count))
            -- none in the bags: grey, the way an empty currency looks
            if count > 0 then e.text:SetTextColor(1, 1, 1) else e.text:SetTextColor(0.5, 0.5, 0.5) end
            e.icon:SetDesaturated(count == 0)
            e:SetWidth(ICON + 6 + e.text:GetStringWidth())
            e:ClearAllPoints()
            if anchor then
                e:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
            else
                e:SetPoint("LEFT", row, "LEFT", 2, 0)
            end
            e:Show()
            anchor = e
        elseif e then
            e:Hide()
        end
    end
    hint:SetShown(#list == 0)
end

-- the footer refresh runs after every bag change (core.lua)
window.OnRefresh = ns.UpdateTrackedItems

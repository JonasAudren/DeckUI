local D = DeckUI

-------------------------------------------------------------------
-- The mailbox: your characters in the "To" field, and what "Open All" took
-------------------------------------------------------------------
-- Owner's wish (2026-10-27), for Mists of Pandaria Classic. Mists already
-- has Blizzard's "Open All" button (OpenAllMail, Classic/MailFrame.lua),
-- so DeckUI adds what it lacks. DeckUIDB.mailHelper, off by default,
-- "Loot and merchant" page; only Mists' .toc lists this file.
--  - Beside the recipient box a small button opens a menu of your own
--    characters on this realm (kept in DeckUIDB.alts by every character
--    that logs in with DeckUI) and the last ten people you sent mail to
--    (DeckUIDB.mailRecent, from a post-hook on SendMail). A pick only
--    writes the name into the box, as typing would.
--  - After Blizzard's "Open All" has run, one chat line says what it took:
--    the gold and the items, counted from post-hooks on TakeInboxMoney /
--    TakeInboxItem while it runs - read from the mail before the server
--    takes it. The button and its code stay Blizzard's.
-------------------------------------------------------------------
local RECENT = 10

local function Enabled() return DeckUIDB and DeckUIDB.mailHelper end

local function Realm() return GetRealmName() end
local function Me() return UnitName("player") end

-- every character remembers itself, so the others can mail it
local function RememberMe()
    DeckUIDB.alts = DeckUIDB.alts or {}
    local realm = Realm()
    DeckUIDB.alts[realm] = DeckUIDB.alts[realm] or {}
    local _, class = UnitClass("player")
    DeckUIDB.alts[realm][Me()] = { class = class, level = UnitLevel("player") }
end

local function RememberRecipient(name)
    if not name or name == "" then return end
    DeckUIDB.mailRecent = DeckUIDB.mailRecent or {}
    local list = DeckUIDB.mailRecent
    for i = #list, 1, -1 do
        if list[i]:lower() == name:lower() then table.remove(list, i) end
    end
    table.insert(list, 1, name)
    while #list > RECENT do table.remove(list) end
end

-------------------------------------------------------------------
-- The recipient menu
-------------------------------------------------------------------
local function Pick(name)
    SendMailNameEditBox:SetText(name)
    SendMailNameEditBox:ClearFocus()
end

local function ClassColored(name, class)
    local c = class and RAID_CLASS_COLORS[class]
    return c and ("|c%s%s|r"):format(c.colorStr, name) or name
end

local function OpenMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        local alts = DeckUIDB.alts and DeckUIDB.alts[Realm()] or {}
        local names = {}
        for name in pairs(alts) do
            if name ~= Me() then names[#names + 1] = name end
        end
        table.sort(names)
        root:CreateTitle("Your characters")
        if #names == 0 then
            root:CreateTitle("|cff888888none yet - log them in once|r")
        end
        for _, name in ipairs(names) do
            local a = alts[name]
            root:CreateButton(ClassColored(name, a.class) .. ("  |cff888888%d|r"):format(a.level or 0),
                function() Pick(name) end)
        end
        local recent = DeckUIDB.mailRecent or {}
        if #recent > 0 then
            root:CreateDivider()
            root:CreateTitle("Recently sent to")
            for _, name in ipairs(recent) do
                root:CreateButton(name, function() Pick(name) end)
            end
        end
    end)
end

local picker
local function MakePicker()
    if picker or not SendMailNameEditBox then return end
    picker = CreateFrame("Button", nil, SendMailFrame)
    picker:SetSize(20, 20)
    picker:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", 2, 0)
    D.FlatBox(picker, 1, 0.4)
    local arrow = picker:CreateTexture(nil, "OVERLAY")
    arrow:SetPoint("CENTER")
    arrow:SetSize(12, 12)
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetRotation(math.rad(-90))
    picker:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    picker:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12)
    picker:SetScript("OnClick", OpenMenu)
    picker:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Send to")
        GameTooltip:AddLine("Your characters on this realm and the last people you mailed.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    picker:SetScript("OnLeave", GameTooltip_Hide)
end

-------------------------------------------------------------------
-- What "Open All" took
-------------------------------------------------------------------
local running = false
local tookMoney, tookItems, itemOrder = 0, {}, {}

local function Money(copper)
    return GetCoinTextureString and GetCoinTextureString(copper) or (copper .. "c")
end

local function Summary()
    if not running then return end
    running = false
    if tookMoney == 0 and #itemOrder == 0 then return end
    local parts = {}
    for _, link in ipairs(itemOrder) do
        local n = tookItems[link]
        parts[#parts + 1] = n > 1 and (link .. " x" .. n) or link
    end
    local items = #parts > 0 and table.concat(parts, ", ") or "no items"
    print(("DeckUI Mail: took %s and %s."):format(tookMoney > 0 and Money(tookMoney) or "no gold", items))
end

local hooked = false
local function Hook()
    if hooked then return end
    hooked = true
    hooksecurefunc("SendMail", function(name)
        if Enabled() then RememberRecipient(name) end
    end)
    hooksecurefunc("TakeInboxMoney", function(index)
        if not running then return end
        local money = select(5, GetInboxHeaderInfo(index))
        tookMoney = tookMoney + (money or 0)
    end)
    hooksecurefunc("TakeInboxItem", function(index, attachment)
        if not running then return end
        local link = GetInboxItemLink(index, attachment)
        local count = select(4, GetInboxItem(index, attachment)) or 1
        if link then
            if not tookItems[link] then itemOrder[#itemOrder + 1] = link end
            tookItems[link] = (tookItems[link] or 0) + count
        end
    end)
    if OpenAllMail and OpenAllMail.StopOpening then
        -- before the click: StartOpening takes the first mail at once,
        -- so a post-hook on it would miss that one
        OpenAllMail:HookScript("PreClick", function()
            if not Enabled() then return end
            running, tookMoney = true, 0
            wipe(tookItems)
            wipe(itemOrder)
        end)
        hooksecurefunc(OpenAllMail, "StopOpening", Summary)
    end
end

function D.ApplyMail()
    if not Enabled() then
        if picker then picker:Hide() end
        return
    end
    Hook()
    MakePicker()
    if picker then picker:Show() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:SetScript("OnEvent", function(_, event)
    RememberMe()
    if event == "PLAYER_LOGIN" then D.ApplyMail() end
end)

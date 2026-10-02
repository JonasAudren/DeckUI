local D = DeckUI

-------------------------------------------------------------------
-- The settings window: a sidebar of pages, the page scrolls
-------------------------------------------------------------------
-- Rebuilt 2026-10-02 (owner's choice from the menu review): thirteen tabs
-- in two rows of 42-pixel buttons had become unreadable, and every page
-- was hand-placed to the pixel inside a window that could neither grow
-- (the Deck's 800-pixel screen) nor scroll - each new option meant moving
-- everything below it. Now:
--  - a sidebar on the left, pages grouped by theme (D.PAGE_GROUPS); a page
--    a module registers lands in its group, an unknown one under "More";
--  - the page on the right scrolls, so its length no longer matters;
--  - a bar at the bottom collects changes that need a /reload
--    (D.NeedReload), with a button that does it.
-- Pages keep their old build(content) functions for now - they are moved
-- to D.Flow (widgets.lua) one by one.
-------------------------------------------------------------------
local W, H = 600, 540
local SIDE_W = 160
local GOLD = { 1, 0.82, 0 }

local panel = CreateFrame("Frame", "DeckUIPanel", UIParent)
panel:SetSize(W, H)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetToplevel(true)
panel:SetMovable(true)
panel:SetClampedToScreen(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
D.FlatBox(panel, 0.95)
panel:Hide()
tinsert(UISpecialFrames, "DeckUIPanel")
D.panel = panel

local title = panel:CreateFontString(nil, "OVERLAY")
title:SetFont(D.FONT, 18, "OUTLINE")
title:SetPoint("TOPLEFT", 14, -12)
title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
title:SetText("DeckUI")

local pageTitle = panel:CreateFontString(nil, "OVERLAY")
pageTitle:SetFont(D.FONT, 16, "OUTLINE")
pageTitle:SetPoint("TOPLEFT", SIDE_W + 22, -14)

local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

-------------------------------------------------------------------
-- Groups and names of the pages
-------------------------------------------------------------------
D.PAGE_GROUPS = {
    { title = "General",   pages = { "General", "Devices" } },
    { title = "Units",     pages = { "Orbs", "Group", "Raid" } },
    { title = "Actions",   pages = { "Cross", "Spec" } },
    { title = "World",     pages = { "Quests", "Map", "Nav" } },
    { title = "Inventory", pages = { "Bags" } },
    { title = "Info",      pages = { "Tooltip", "Week" } },
}
-- the sidebar's name where the module's title is too short to say it
D.PAGE_NAMES = {
    Orbs = "Player and target", Cross = "Cross hotbar", Spec = "Specialization",
    Nav = "Navigation", Map = "Maps", Week = "Week overview",
}

-------------------------------------------------------------------
-- Sidebar
-------------------------------------------------------------------
local side = CreateFrame("Frame", nil, panel)
side:SetPoint("TOPLEFT", 8, -40)
side:SetPoint("BOTTOMLEFT", 8, 8)
side:SetWidth(SIDE_W)
D.FlatBox(side, 0.6, 0.2)

panel.tabs     = {}   -- key -> sidebar entry (the old name, kept for callers)
panel.contents = {}
panel.tabOrder = {}

local headings, usedHeadings = {}, 0

local function Heading(text, y)
    usedHeadings = usedHeadings + 1
    local fs = headings[usedHeadings]
    if not fs then
        fs = side:CreateFontString(nil, "OVERLAY")
        fs:SetFont(D.FONT, 11, "OUTLINE")
        fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        headings[usedHeadings] = fs
    end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", 10, y)
    fs:SetText(text:upper())
    fs:Show()
end

local function NewEntry(key)
    local b = CreateFrame("Button", nil, side)
    b:SetSize(SIDE_W - 8, 20)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(D.FONT, 13, "OUTLINE")
    b.text:SetPoint("LEFT", 14, 0)
    b.text:SetJustifyH("LEFT")
    b.bar = b:CreateTexture(nil, "ARTWORK")
    b.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    b.bar:SetPoint("TOPLEFT", 4, -3)
    b.bar:SetPoint("BOTTOMLEFT", 4, 3)
    b.bar:SetWidth(2)
    b.fill = b:CreateTexture(nil, "BACKGROUND")
    b.fill:SetAllPoints()
    b.fill:SetColorTexture(1, 1, 1, 0.07)
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.05)
    b:SetScript("OnClick", function() panel:ShowTab(key) end)
    return b
end

local function PageName(key)
    local content = panel.contents[key]
    return D.PAGE_NAMES[key] or (content and content.def.title) or key
end

local function LayoutSidebar()
    for i = 1, usedHeadings do headings[i]:Hide() end
    usedHeadings = 0
    for _, b in pairs(panel.tabs) do b:Hide() end

    local y, placed = -8, {}
    local function Group(name, keys)
        local any = false
        for _, key in ipairs(keys) do
            if panel.tabs[key] and not placed[key] then
                if not any then
                    Heading(name, y)
                    y = y - 16
                    any = true
                end
                local b = panel.tabs[key]
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 4, y)
                b.text:SetText(PageName(key))
                b:Show()
                placed[key] = true
                y = y - 21
            end
        end
        if any then y = y - 8 end
    end
    for _, group in ipairs(D.PAGE_GROUPS) do Group(group.title, group.pages) end
    Group("More", panel.tabOrder)   -- whatever no group names
end

-------------------------------------------------------------------
-- The page: a scroll frame on the right, plus the reload bar below it
-------------------------------------------------------------------
local scroll = CreateFrame("ScrollFrame", "DeckUIPanelScroll", panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", SIDE_W + 16, -42)
scroll:SetPoint("BOTTOMRIGHT", -30, 40)
local PAGE_W = W - SIDE_W - 16 - 30

-- Old pages place their widgets at fixed points and say nothing about
-- their height, so it is measured: the lowest widget's bottom edge.
local function Measure(content)
    local top = content:GetTop()
    if not top then return end
    local low = top - 20
    local function Visit(...)
        for i = 1, select("#", ...) do
            local r = select(i, ...)
            if r:IsShown() then
                local bottom = r:GetBottom()
                if bottom and bottom < low then low = bottom end
            end
        end
    end
    Visit(content:GetChildren())
    Visit(content:GetRegions())
    content:SetHeight(math.max(10, top - low + 16))
end

-- changes that wait for a /reload, by key, with a button that does it
local reloadBar = CreateFrame("Frame", nil, panel)
reloadBar:SetPoint("BOTTOMLEFT", SIDE_W + 16, 8)
reloadBar:SetPoint("BOTTOMRIGHT", -8, 8)
reloadBar:SetHeight(26)
reloadBar:Hide()
local reloadText = reloadBar:CreateFontString(nil, "OVERLAY")
reloadText:SetFont(D.FONT, 12, "OUTLINE")
reloadText:SetPoint("LEFT", 4, 0)
reloadText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
local reloadBtn = CreateFrame("Button", nil, reloadBar, "UIPanelButtonTemplate")
reloadBtn:SetSize(90, 22)
reloadBtn:SetPoint("RIGHT")
reloadBtn:SetText("Reload")
reloadBtn:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
reloadBtn:SetScript("OnClick", function() C_UI.Reload() end)
D.FlattenButton(reloadBtn)

local pendingReload = {}

-- key: anything that names the change, so switching back and forth
-- counts once; pass false as `on` when the change was undone
function D.NeedReload(key, on)
    pendingReload[key] = (on ~= false) or nil
    local n = 0
    for _ in pairs(pendingReload) do n = n + 1 end
    reloadText:SetText(n == 1 and "1 change takes effect after a reload."
        or ("%d changes take effect after a reload."):format(n))
    reloadBar:SetShown(n > 0)
end

-------------------------------------------------------------------
-- Pages
-------------------------------------------------------------------
function panel:AddTab(key, def)
    if self.tabs[key] then return end
    self.tabs[key] = NewEntry(key)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(PAGE_W, 10)
    content:Hide()
    content.def = def
    content:SetScript("OnShow", function(c)
        if not c.built then
            c.built = true
            if c.def.build then c.def.build(c) end
        end
        D.RefreshWidgets(c)
        -- the widgets have their places only after this frame is drawn
        C_Timer.After(0, function() Measure(c) end)
    end)
    self.contents[key] = content

    table.insert(self.tabOrder, key)
    LayoutSidebar()
end

function panel:ShowTab(key)
    if not self.contents[key] then key = "General" end
    for k, content in pairs(self.contents) do
        local on = k == key
        if on then scroll:SetScrollChild(content) end
        content:SetShown(on)
        local b = self.tabs[k]
        b.bar:SetShown(on)
        b.fill:SetShown(on)
        b.text:SetTextColor(on and GOLD[1] or 1, on and GOLD[2] or 1, on and GOLD[3] or 1)
    end
    scroll:SetVerticalScroll(0)
    pageTitle:SetText(PageName(key))
    self.current = key
end

panel:SetScript("OnShow", function(self)
    self:ShowTab(self.current or "General")
end)

function D.ToggleConfig(tabKey)
    if tabKey and panel.contents[tabKey] then panel.current = tabKey end
    if panel:IsShown() and not tabKey then
        panel:Hide()
    else
        panel:Show()
        if tabKey then panel:ShowTab(tabKey) end
    end
end

-------------------------------------------------------------------
-- "General" tab
-------------------------------------------------------------------
panel:AddTab("General", {
    title = "General",
    build = function(c)
        local db = function() return DeckUIDB end

        D.Label(c, "Modules", -6, 15)
        local modules = function() return DeckUIDB.modules end
        for i, key in ipairs(D.MODULE_ORDER) do
            D.Checkbox(c, D.MODULE_TITLES[key], -28 * i, modules, key,
                function(v)
                    D.SetModuleEnabled(key, v)
                    -- a module once loaded stays until the reload
                    D.NeedReload("module:" .. key, not v and C_AddOns.IsAddOnLoaded("DeckUI_" .. key))
                end)
        end

        -- below the last module, however many there are
        local y = -28 * #D.MODULE_ORDER - 32
        D.Hint(c, "Enabling takes effect immediately, disabling after /reload.", y)

        D.Label(c, "Other", y - 32, 15)
        D.Checkbox(c, "Show minimap button", y - 54, db, "showMinimap",
            function(v) D.SetMinimapShown(v) end)
        D.Checkbox(c, "Damage meter in DeckUI's look", y - 82, db, "styleDamageMeter",
            D.SetDamageMeterStyled)

        D.Checkbox(c, "Sell junk at the merchant", y - 110, db, "autoSellJunk", function() end)
        D.Checkbox(c, "Repair at the merchant", y - 138, db, "autoRepair", function() end)
        D.Checkbox(c, "Repair with guild funds first", y - 166, db, "repairGuild", function() end)
        D.Checkbox(c, "Fast auto loot", y - 194, db, "fastLoot", function() end)
        D.Checkbox(c, "DeckUI's loot window", y - 222, db, "lootWindow",
            function() D.ApplyLootWindow() end)

        -- the error collector (errors.lua), with how many it holds
        local errBtn = D.Button(c, "Lua errors", y - 260, function() D.ShowErrors() end)
        function errBtn:Refresh() self:SetText(("Lua errors (%d)"):format(D.ErrorCount())) end
        c.widgets = c.widgets or {}
        table.insert(c.widgets, errBtn)
    end,
})

-------------------------------------------------------------------
-- "Devices" tab: everything that differs between the Deck and the PC
-------------------------------------------------------------------
-- Its own tab since the "keep on this device" options joined: the General
-- tab had grown to 832 pixels, too tall for the Deck's screen at 100% UI
-- scale.
panel:AddTab("Devices", {
    title = "Devices",
    build = function(c)
        local db = function() return DeckUIDB end

        D.Label(c, "Device", -6, 15)
        local devBtn = D.Button(c, "Device", -28, function() end)
        devBtn:SetWidth(300)
        devBtn:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
        devBtn:SetScript("OnClick", function(b)
            D.CycleDevice()
            b:SetText(D.DeviceText())
        end)
        function devBtn:Refresh() self:SetText(D.DeviceText()) end
        c.widgets = c.widgets or {}
        table.insert(c.widgets, devBtn)

        D.Checkbox(c, "Cross hotbar only on Steam Deck", -66, db, "crossDeckOnly",
            function(v)
                if not v and DeckUIDB.modules.Cross then
                    D.SetModuleEnabled("Cross", true)
                else
                    print("DeckUI: takes effect after /reload.")
                    D.NeedReload("crossDeckOnly")
                end
            end)

        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
        D.Checkbox(c, "Set Blizzard UI scale per device at login", -94, db, "applyUiScale",
            function(v) if v then D.ApplyUiScale() else print("DeckUI: UI scale is no longer touched (current value stays until you change it in Options).") end end)
        D.Slider(c, "UI scale on Steam Deck", -128, 0.5, 1.0, 0.01, pct, db, "uiScaleDeck",
            function(v) if D.IsDeck() then D.ApplyUiScale() end end)
        D.Slider(c, "UI scale on PC", -192, 0.5, 1.0, 0.01, pct, db, "uiScalePC",
            function(v) if not D.IsDeck() then D.ApplyUiScale() end end)

        D.Label(c, "Positions (per device)", -256, 15)
        local unlockBtn = D.Button(c, "Unlock frames", -278, function() end)
        unlockBtn:SetScript("OnClick", function(b)
            D.SetUnlocked(not D.unlocked)
            b:SetText(D.unlocked and "Lock frames" or "Unlock frames")
        end)
        function unlockBtn:Refresh()
            self:SetText(D.unlocked and "Lock frames" or "Unlock frames")
        end
        table.insert(c.widgets, unlockBtn)

        D.Button(c, "Reset all positions", -318, D.ResetPositions)

        D.Label(c, "Keep on this device", -370, 15)
        D.Checkbox(c, "Key bindings", -392,
            function() return D.bindingsCVar end, "localOnly", D.SetLocalBindings)
        D.Checkbox(c, "Action bar layouts", -420, db, "keepBars", D.SetKeepBars)
        D.Checkbox(c, "Edit Mode layout", -448, db, "keepLayouts", D.SetKeepLayouts)
        D.Hint(c, "Blizzard keeps all three on its server, so every device loads the same. Tick them on each device: what is set up there when you tick a box becomes that device's, and later changes are remembered.", -484)
    end,
})

-------------------------------------------------------------------
-- Slash command
-------------------------------------------------------------------
SLASH_DECKUI1 = "/deck"
SlashCmdList.DECKUI = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "unlock" then
        D.SetUnlocked(true)
    elseif msg == "lock" then
        D.SetUnlocked(false)
    elseif msg == "reset" then
        D.ResetPositions()
    elseif msg == "device" then
        D.PrintDevice()
    elseif msg == "build" then
        D.PrintBuild()
    elseif msg == "bars" then
        D.PrintBars()
    elseif msg == "layout" then
        D.PrintLayout()
    elseif msg == "errors" then
        D.ShowErrors()
    elseif msg == "deck" or msg == "pc" or msg == "auto" then
        D.SetDevice(msg)
    else
        D.ToggleConfig()
    end
end

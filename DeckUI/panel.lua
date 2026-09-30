local D = DeckUI

-------------------------------------------------------------------
-- Window
-------------------------------------------------------------------
local panel = CreateFrame("Frame", "DeckUIPanel", UIParent, "BackdropTemplate")
panel:SetSize(340, 730)   -- height follows the tab rows, see LayoutTabs
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
panel:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
panel:Hide()
tinsert(UISpecialFrames, "DeckUIPanel")
D.panel = panel

local title = panel:CreateFontString(nil, "OVERLAY")
title:SetFont(D.FONT, 18, "OUTLINE")
title:SetPoint("TOP", 0, -12)
title:SetText("DeckUI")

local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)

-------------------------------------------------------------------
-- Tabs
-------------------------------------------------------------------
panel.tabs     = {}
panel.contents = {}
panel.tabOrder = {}

-- Up to six tabs share one row; beyond that they go into two rows and
-- the window grows by one row's height, content moving down with it.
-- Seven in one row would leave 42 pixels each - too narrow for "General"
-- in any readable size.
local BASE_HEIGHT = 730   -- the tallest tab, Cross, ends with a three-line hint at -574
local ROW = 30

local function LayoutTabs()
    local n = #panel.tabOrder
    local rows = n > 6 and 2 or 1
    local perRow = math.ceil(n / rows)
    local w = math.min(100, (320 - (perRow - 1) * 4) / perRow)
    -- six tabs leave 50 pixels each, where "General" in 13 would be cut off
    local size = w < 60 and 11 or 13
    for i, key in ipairs(panel.tabOrder) do
        local tab = panel.tabs[key]
        local row, col = math.floor((i - 1) / perRow), (i - 1) % perRow
        tab:SetSize(w, 26)
        tab:GetFontString():SetFont(D.FONT, size, "OUTLINE")
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", 10 + col * (w + 4), -40 - row * ROW)
    end
    local top = -76 - (rows - 1) * ROW
    for _, content in pairs(panel.contents) do
        content:SetPoint("TOPLEFT", 10, top)
    end
    panel:SetHeight(BASE_HEIGHT + (rows - 1) * ROW)
end

function panel:AddTab(key, def)
    if self.tabs[key] then return end

    local tab = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    tab:SetText(def.title or key)
    tab:GetFontString():SetFont(D.FONT, 13, "OUTLINE")
    tab:SetScript("OnClick", function() self:ShowTab(key) end)
    self.tabs[key] = tab

    local content = CreateFrame("Frame", nil, self)
    content:SetPoint("TOPLEFT", 10, -76)
    content:SetPoint("BOTTOMRIGHT", -10, 10)
    content:Hide()
    content.def = def
    content:SetScript("OnShow", function(c)
        if not c.built then
            c.built = true
            if c.def.build then c.def.build(c) end
        end
        D.RefreshWidgets(c)
    end)
    self.contents[key] = content

    table.insert(self.tabOrder, key)
    LayoutTabs()
end

function panel:ShowTab(key)
    for k, content in pairs(self.contents) do
        content:SetShown(k == key)
        self.tabs[k]:SetEnabled(k ~= key)
    end
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
                function(v) D.SetModuleEnabled(key, v) end)
        end

        -- below the last module, however many there are
        local y = -28 * #D.MODULE_ORDER - 32
        D.Hint(c, "Enabling takes effect immediately, disabling after /reload.", y)

        D.Label(c, "Other", y - 32, 15)
        D.Checkbox(c, "Show minimap button", y - 54, db, "showMinimap",
            function(v) D.SetMinimapShown(v) end)
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
    elseif msg == "deck" or msg == "pc" or msg == "auto" then
        D.SetDevice(msg)
    else
        D.ToggleConfig()
    end
end

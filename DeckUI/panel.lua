local D = DeckUI

-------------------------------------------------------------------
-- Window
-------------------------------------------------------------------
local panel = CreateFrame("Frame", "DeckUIPanel", UIParent, "BackdropTemplate")
panel:SetSize(340, 660)
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

local function LayoutTabs()
    local n = #panel.tabOrder
    local w = math.min(100, (320 - (n - 1) * 4) / n)
    for i, key in ipairs(panel.tabOrder) do
        local tab = panel.tabs[key]
        tab:SetSize(w, 26)
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", 10 + (i - 1) * (w + 4), -40)
    end
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
        D.Checkbox(c, "Orbs (unit frames)",  -28, function() return DeckUIDB.modules end, "Orbs",
            function(v) D.SetModuleEnabled("Orbs", v) end)
        D.Checkbox(c, "Cross (action bar)", -56, function() return DeckUIDB.modules end, "Cross",
            function(v) D.SetModuleEnabled("Cross", v) end)
        D.Checkbox(c, "Spec (spec switcher)", -84, function() return DeckUIDB.modules end, "Spec",
            function(v) D.SetModuleEnabled("Spec", v) end)

        local hint = c:CreateFontString(nil, "OVERLAY")
        hint:SetFont(D.FONT, 11, "OUTLINE")
        hint:SetPoint("TOPLEFT", 24, -116)
        hint:SetTextColor(0.7, 0.7, 0.7)
        hint:SetText("Enabling takes effect immediately, disabling after /reload.")

        D.Label(c, "Device", -148, 15)
        local devBtn = D.Button(c, "Device", -170, function() end)
        devBtn:SetWidth(300)
        devBtn:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
        devBtn:SetScript("OnClick", function(b)
            D.CycleDevice()
            b:SetText(D.DeviceText())
        end)
        function devBtn:Refresh() self:SetText(D.DeviceText()) end
        c.widgets = c.widgets or {}
        table.insert(c.widgets, devBtn)

        D.Checkbox(c, "Cross hotbar only on Steam Deck", -208, db, "crossDeckOnly",
            function(v)
                if not v and DeckUIDB.modules.Cross then
                    D.SetModuleEnabled("Cross", true)
                else
                    print("DeckUI: takes effect after /reload.")
                end
            end)

        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
        D.Checkbox(c, "Set Blizzard UI scale per device at login", -236, db, "applyUiScale",
            function(v) if v then D.ApplyUiScale() else print("DeckUI: UI scale is no longer touched (current value stays until you change it in Options).") end end)
        D.Slider(c, "UI scale on Steam Deck", -270, 0.5, 1.0, 0.01, pct, db, "uiScaleDeck",
            function(v) if D.IsDeck() then D.ApplyUiScale() end end)
        D.Slider(c, "UI scale on PC", -334, 0.5, 1.0, 0.01, pct, db, "uiScalePC",
            function(v) if not D.IsDeck() then D.ApplyUiScale() end end)

        D.Label(c, "Positions (per device)", -398, 15)
        local unlockBtn = D.Button(c, "Unlock frames", -420, function() end)
        unlockBtn:SetScript("OnClick", function(b)
            D.SetUnlocked(not D.unlocked)
            b:SetText(D.unlocked and "Lock frames" or "Unlock frames")
        end)
        function unlockBtn:Refresh()
            self:SetText(D.unlocked and "Lock frames" or "Unlock frames")
        end
        c.widgets = c.widgets or {}
        table.insert(c.widgets, unlockBtn)

        D.Button(c, "Reset all positions", -460, D.ResetPositions)

        D.Label(c, "Other", -512, 15)
        D.Checkbox(c, "Show minimap button", -534, db, "showMinimap",
            function(v) D.SetMinimapShown(v) end)
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
    elseif msg == "deck" or msg == "pc" or msg == "auto" then
        D.SetDevice(msg)
    else
        D.ToggleConfig()
    end
end

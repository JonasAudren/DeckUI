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
    { title = "Inventory", pages = { "Bags", "Loot" } },
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

-------------------------------------------------------------------
-- The footer: "Move" and "Defaults" for the page, the reload notice
-------------------------------------------------------------------
-- Added 2026-10-02 with the last points of the menu review: a page's own
-- frames can be unlocked alone (D.SetUnlocked with a set of keys), and a
-- page can put its settings back to the defaults.

-- the frames each page moves, by the key D.MakeMovable got
D.PAGE_FRAMES = {
    Orbs    = { "Player", "Target", "Focus", "Boss frames", "Player (FF)", "Target (FF)", "Boss frames (FF)" },
    Group   = { "Party" },
    Raid    = { "Raid" },
    Cross   = { "Cross Hotbar", "Leave vehicle", "Assist indicator" },
    Spec    = { "Spec bar" },
    Bags    = { "Bags", "Bank" },
    Quests  = { "Quest tracker", "Delver's Journey" },
    Map     = { "Minimap", "World map" },
    Tooltip = { "Tooltip" },
    Nav     = { "Compass", "Navigation target" },
    Week    = { "Week", "Week button" },
    Loot    = { "Loot", "Loot list" },
}

-- What "Defaults" clears on each page: the SavedVariables table by name,
-- `match` for the keys that belong to this page when several pages share
-- one table (Orbs, Group and Raid; the hub's Loot settings), and `keep` for
-- what is data, not settings. Positions are never touched - "Reset all
-- positions" on the Devices page does that. The game reloads right after,
-- and each module fills what is missing with its defaults as it loads.
local LOOT_KEYS = { autoSellJunk = true, autoRepair = true, repairGuild = true, fastLoot = true, lootWindow = true }
local function GroupKey(k) return k == "showParty" or k:find("^party") ~= nil end
local function RaidKey(k) return k == "showRaid" or k:find("^raid") ~= nil end
D.PAGE_RESET = {
    Orbs    = { db = "DeckOrbsDB", match = function(k) return not GroupKey(k) and not RaidKey(k) end },
    Group   = { db = "DeckOrbsDB", match = GroupKey },
    Raid    = { db = "DeckOrbsDB", match = RaidKey },
    Cross   = { db = "DeckCrossDB" },
    Spec    = { db = "DeckSpecDB" },
    Bags    = { db = "DeckBagsDB", keep = { trackedItems = true } },
    Quests  = { db = "DeckQuestsDB" },
    Map     = { db = "DeckMapDB" },
    Tooltip = { db = "DeckTooltipDB" },
    Nav     = { db = "DeckNavDB" },
    Week    = { db = "DeckWeekDB", keep = { chars = true, weeklies = true, hidden = true } },
    Loot    = { db = "DeckUIDB", match = function(k) return LOOT_KEYS[k] end },
}

local function ResetPage(key)
    local rule = D.PAGE_RESET[key]
    local db = rule and _G[rule.db]
    if not db then return end
    local function Clears(k)
        if k == "perDevice" or (rule.keep and rule.keep[k]) then return false end
        return not rule.match or rule.match(k)
    end
    for k in pairs(db) do
        if type(k) == "string" and Clears(k) then db[k] = nil end
    end
    for _, dev in pairs(db.perDevice or {}) do
        for k in pairs(dev) do
            if type(k) == "string" and k ~= "positions" and Clears(k) then dev[k] = nil end
        end
    end
end

local footer = CreateFrame("Frame", nil, panel)
footer:SetPoint("BOTTOMLEFT", SIDE_W + 16, 8)
footer:SetPoint("BOTTOMRIGHT", -8, 8)
footer:SetHeight(26)

local function FooterButton(text, x)
    local b = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    b:SetSize(76, 22)
    b:SetPoint("LEFT", x, 0)
    b:SetText(text)
    b:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
    D.FlattenButton(b)
    return b
end

-- this page's frames as a set, or nil when none of them exists
local function PageFrames(key)
    local keys = D.PAGE_FRAMES[key]
    if not keys then return nil end
    local set, any = {}, false
    for _, k in ipairs(keys) do set[k] = true end
    for _, entry in ipairs(D.movables) do
        if set[entry.key] then any = true end
    end
    return any and set or nil
end

local moveBtn = FooterButton("Move", 0)
local defaultsBtn = FooterButton("Defaults", 80)

function D.UpdateFooter()
    local key = panel.current
    local frames = key and PageFrames(key)
    local stub = key and panel.contents[key] and panel.contents[key].def.stub
    moveBtn:SetShown(frames ~= nil and not stub)
    moveBtn:SetText(D.unlocked and "Lock" or "Move")
    defaultsBtn:SetShown(key and D.PAGE_RESET[key] ~= nil and not stub and _G[D.PAGE_RESET[key].db] ~= nil)
end

moveBtn:SetScript("OnClick", function()
    if D.unlocked then
        D.SetUnlocked(false)
    else
        D.SetUnlocked(true, PageFrames(panel.current))
    end
    D.UpdateFooter()
end)
D.Tip(moveBtn, "Move", "Unlocks only this page's frames, to drag them to a new place. Click again to lock. All frames at once: the Devices page or /deck unlock.")

defaultsBtn:SetScript("OnClick", function()
    local key = panel.current
    D.Dialog({
        text = ("Put the settings of \"%s\" back to their defaults? Places on screen stay. The game reloads to apply it."):format(PageName(key)),
        accept = "Defaults",
        onAccept = function()
            ResetPage(key)
            C_UI.Reload()
        end,
    })
end)
D.Tip(defaultsBtn, "Defaults", "Puts this page's settings back as they were at installation, then reloads. Places on screen stay.")

-- changes that wait for a /reload, by key, with a button that does it
local reloadBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
reloadBtn:SetSize(70, 22)
reloadBtn:SetPoint("RIGHT")
reloadBtn:SetText("Reload")
reloadBtn:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
reloadBtn:SetScript("OnClick", function() C_UI.Reload() end)
D.FlattenButton(reloadBtn)
reloadBtn:Hide()
local reloadText = footer:CreateFontString(nil, "OVERLAY")
reloadText:SetFont(D.FONT, 12, "OUTLINE")
reloadText:SetPoint("RIGHT", reloadBtn, "LEFT", -6, 0)
reloadText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

local pendingReload = {}

-- key: anything that names the change, so switching back and forth
-- counts once; pass false as `on` when the change was undone
function D.NeedReload(key, on)
    pendingReload[key] = (on ~= false) or nil
    local n = 0
    for _ in pairs(pendingReload) do n = n + 1 end
    reloadText:SetText(n == 1 and "1 change needs a reload" or ("%d changes need a reload"):format(n))
    reloadText:SetShown(n > 0)
    reloadBtn:SetShown(n > 0)
end

-------------------------------------------------------------------
-- Pages
-------------------------------------------------------------------
-- A module's real page replaces its stand-in (a page with def.stub, see
-- "Modules" below) when the module loads.
function panel:AddTab(key, def)
    if self.tabs[key] then
        local old = self.contents[key]
        if not (old and old.def.stub) then return end
        old:Hide()
    else
        self.tabs[key] = NewEntry(key)
        table.insert(self.tabOrder, key)
    end

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

    LayoutSidebar()
    if self.current == key and self:IsShown() then self:ShowTab(key) end
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
        -- gold: the page on show; grey: a module that is off
        local grey = content.def.stub and 0.5 or 1
        b.text:SetTextColor(on and GOLD[1] or grey, on and GOLD[2] or grey, on and GOLD[3] or grey)
    end
    scroll:SetVerticalScroll(0)
    pageTitle:SetText(PageName(key))
    self.current = key
    if D.UpdateModuleSwitch then D.UpdateModuleSwitch() end
    D.UpdateFooter()
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
-- Modules: a switch on their own page, a stand-in page while off
-------------------------------------------------------------------
-- Owner's choice (2026-10-02): a module is switched on and off at the top
-- of its own page, not in a list on another one. A module that is off has
-- not loaded, so it has no page of its own yet - a stand-in takes its
-- place in the sidebar (greyed) and says what the module does. Switched
-- on, the module loads and registers its page, which replaces the stand-in.
D.MODULE_DESCRIPTIONS = {
    Orbs    = "Round unit frames for you, your target, focus, pet and bosses - or Final Fantasy's bars - plus the party list and raid frames.",
    Cross   = "The cross hotbar: Action Bar 1 and 2 as two crosses per side. LT/RT with the D-pad and face buttons on the Steam Deck, your own keys on the PC.",
    Spec    = "A small bar of your specializations; click one to switch.",
    Bags    = "One window for all bags, sorted into categories, and the bank and warband bank in the same look.",
    Quests  = "Its own objective tracker in place of Blizzard's: quests, scenarios, delves, achievements, world quests.",
    Map     = "A square minimap in a DeckUI frame and a smaller, cleaner world map.",
    Tooltip = "The mouse-over tooltip in DeckUI's look, with spec and item level of players and a few extra lines.",
    Nav     = "A compass bar, the navigation target with distance and arrival time, and /way waypoints.",
    Week    = "The week at a glance for all your characters: Great Vault, keystone, hunts, delves, profession knowledge, weekly quests.",
}

local function ModuleLoaded(key)
    return C_AddOns.IsAddOnLoaded(D.MODULE_ADDONS[key])
end

-- what the switch and the overview say about a module
local function ModuleState(key)
    local on, loaded = DeckUIDB.modules[key], ModuleLoaded(key)
    if on and loaded then return "On", true end
    if not on and loaded then return "Off after reload", true end
    if on then
        local allowed = D.ModuleAllowed(key)
        return allowed and "On after reload" or "Not on this device", false
    end
    return "Off", false
end
D.ModuleState = ModuleState

local switch = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
switch:SetSize(150, 22)
switch:SetPoint("TOPRIGHT", -34, -10)
switch:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
D.FlattenButton(switch)
switch:Hide()

function D.UpdateModuleSwitch()
    local key = panel.current
    if not (key and D.MODULE_ADDONS[key]) then
        switch:Hide()
        return
    end
    local state, live = ModuleState(key)
    local color = DeckUIDB.modules[key] and "|cff33ff33" or "|cff888888"
    switch:SetText("Module: " .. color .. state .. "|r")
    switch:Show()
end

switch:SetScript("OnClick", function()
    local key = panel.current
    local on = not DeckUIDB.modules[key]
    D.SetModuleEnabled(key, on)
    -- a module once loaded stays until the reload
    D.NeedReload("module:" .. key, not on and ModuleLoaded(key))
    panel:ShowTab(key)
end)

local function StubPage(key)
    return {
        title = key, stub = true,
        build = function(c)
            local f = D.Flow(c)
            f:Hint(D.MODULE_DESCRIPTIONS[key] or "")
            if key == "Cross" then
                f:Gap(6)
                f:Checkbox("Cross hotbar only on Steam Deck", function() return DeckUIDB end, "crossDeckOnly",
                    function(v) D.SetCrossDeckOnly(v) end)
            end
            f:Gap(6)
            c.stateText = f:Hint("")   -- last: its text changes length
            c.widgets = c.widgets or {}
            table.insert(c.widgets, { Refresh = function()
                local state = ModuleState(key)
                c.stateText:SetText(state == "Not on this device"
                    and "Switched on, but set to the Steam Deck only."
                    or "Switch it on with the button at the top right - it loads at once.")
            end })
        end,
    }
end

-------------------------------------------------------------------
-- "General": the modules at a glance, and what belongs to no module
-------------------------------------------------------------------
D.PAGE_NAMES.General = "Overview"

local function ModuleRow(c, y, key)
    local row = CreateFrame("Button", nil, c)
    row:SetSize(300, 22)
    row:SetPoint("TOP", 0, y)
    D.FlatBox(row, 0.5, 0.2)
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
    local name = row:CreateFontString(nil, "OVERLAY")
    name:SetFont(D.FONT, 13, "OUTLINE")
    name:SetPoint("LEFT", 8, 0)
    name:SetText(D.PAGE_NAMES[key] or key)
    local state = row:CreateFontString(nil, "OVERLAY")
    state:SetFont(D.FONT, 12, "OUTLINE")
    state:SetPoint("RIGHT", -8, 0)
    row:SetScript("OnClick", function() panel:ShowTab(key) end)
    D.Tip(row, D.PAGE_NAMES[key] or key, D.MODULE_DESCRIPTIONS[key])
    function row:Refresh()
        local text = ModuleState(key)
        state:SetText((DeckUIDB.modules[key] and "|cff33ff33" or "|cff888888") .. text .. "|r")
    end
    return row
end

panel:AddTab("General", {
    title = "General",
    build = function(c)
        local db = function() return DeckUIDB end
        local f = D.Flow(c)
        c.widgets = c.widgets or {}

        f:Label("Modules")
        for _, key in ipairs(D.MODULE_ORDER) do
            table.insert(c.widgets, f:Add(24, function(parent, y) return ModuleRow(parent, y, key) end))
        end
        f:Gap(4)
        f:Hint("Click a module for its page; switch it on or off at the top right there.")

        f:Gap(8)
        f:Label("Interface")
        f:Checkbox("Show minimap button", db, "showMinimap", function(v) D.SetMinimapShown(v) end,
            "Left click opens these settings, Shift-click the week overview.")
        f:Checkbox("Damage meter in DeckUI's look", db, "styleDamageMeter", D.SetDamageMeterStyled,
            "Blizzard's damage meter with flat bars and DeckUI's font. Its numbers stay Blizzard's.")

        f:Gap(8)
        -- the error collector (errors.lua), with how many it holds
        local errBtn = f:Button("Lua errors", function() D.ShowErrors() end,
            "Every Lua error since login, from any addon, ready to copy. Also /deck errors.")
        function errBtn:Refresh() self:SetText(("Lua errors (%d)"):format(D.ErrorCount())) end
        table.insert(c.widgets, errBtn)
    end,
})

-------------------------------------------------------------------
-- "Loot and merchant": what used to sit under "Other" in General
-------------------------------------------------------------------
D.PAGE_NAMES.Loot = "Loot and merchant"

panel:AddTab("Loot", {
    title = "Loot and merchant",
    build = function(c)
        local db = function() return DeckUIDB end
        local nothing = function() end
        local f = D.Flow(c)

        f:Label("At the merchant")
        f:Checkbox("Sell junk", db, "autoSellJunk", nothing,
            "Grey items are sold as soon as a merchant opens.")
        f:Checkbox("Repair", db, "autoRepair", nothing,
            "Repairs everything when a merchant who can repair opens.")
        f:Checkbox("Repair with guild funds first", db, "repairGuild", nothing,
            "Uses the guild bank where you are allowed to; your own gold covers the rest.")

        f:Gap(8)
        f:Label("Loot")
        f:Checkbox("Fast auto loot", db, "fastLoot", nothing,
            "Takes everything the moment a corpse opens, without the loot window flickering up.")
        f:Checkbox("DeckUI's loot window", db, "lootWindow", function() D.ApplyLootWindow() end,
            "Replaces Blizzard's loot window. With auto loot a short list shows what you took. Move both with /deck unlock.")
    end,
})

-------------------------------------------------------------------
-- "Devices": everything that differs between the Deck and the PC
-------------------------------------------------------------------
-- Moved to D.Flow 2026-10-02. "Cross hotbar only on Steam Deck" went to
-- the Cross page (and its stand-in) - D.SetCrossDeckOnly below.
function D.SetCrossDeckOnly(v)
    if not v and DeckUIDB.modules.Cross then
        D.SetModuleEnabled("Cross", true)
    else
        D.NeedReload("crossDeckOnly")
    end
end

panel:AddTab("Devices", {
    title = "Devices",
    build = function(c)
        local db = function() return DeckUIDB end
        local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
        local f = D.Flow(c)
        c.widgets = c.widgets or {}

        f:Label("This device")
        local devBtn = f:Button("Device", function(b)
            D.CycleDevice()
            b:SetText(D.DeviceText())
        end, "Auto: Steam Deck when the screen is 1280x800 or a gamepad is active, otherwise PC. Decided once at login. Per-device settings - positions, sizes, the options below - follow this.")
        devBtn:SetWidth(300)
        devBtn:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
        function devBtn:Refresh() self:SetText(D.DeviceText()) end
        table.insert(c.widgets, devBtn)

        f:Gap(4)
        f:Label("UI scale")
        f:Checkbox("Set Blizzard's UI scale per device at login", db, "applyUiScale", function(v)
            if v then D.ApplyUiScale() end
        end, "One scale for the Deck's small screen, one for the PC. Switched off, the current scale simply stays.")
        f:Slider("On the Steam Deck", 0.5, 1.0, 0.01, pct, db, "uiScaleDeck",
            function() if D.IsDeck() then D.ApplyUiScale() end end)
        f:Slider("On the PC", 0.5, 1.0, 0.01, pct, db, "uiScalePC",
            function() if not D.IsDeck() then D.ApplyUiScale() end end)

        f:Label("Positions")
        local unlockBtn = f:Button("Unlock frames", function(b)
            D.SetUnlocked(not D.unlocked)
            b:SetText(D.unlocked and "Lock frames" or "Unlock frames")
        end, "Shows a labelled overlay on every DeckUI frame; drag them where you want them. Each device keeps its own places. Also /deck unlock.")
        function unlockBtn:Refresh()
            self:SetText(D.unlocked and "Lock frames" or "Unlock frames")
        end
        table.insert(c.widgets, unlockBtn)
        f:Button("Reset all positions", function()
            D.Dialog({
                text = "Put every DeckUI frame back to its default place on this device?",
                accept = "Reset",
                onAccept = D.ResetPositions,
            })
        end, "Only this device's places; the other device keeps its own.")

        f:Gap(4)
        f:Label("Keep on this device")
        local keepTip = "Blizzard keeps this on its server, so every device loads the same. Tick it on each device: what is set up there when you tick the box becomes that device's, and later changes are remembered."
        f:Checkbox("Key bindings", function() return D.bindingsCVar end, "localOnly", D.SetLocalBindings, keepTip)
        f:Checkbox("Action bar layouts", db, "keepBars", D.SetKeepBars, keepTip)
        f:Checkbox("Edit Mode layout", db, "keepLayouts", D.SetKeepLayouts, keepTip)
    end,
})

-- the stand-ins for every module not loaded yet; a module that loads
-- later (at login, or switched on) replaces its own
for _, key in ipairs(D.MODULE_ORDER) do
    if not panel.contents[key] then panel:AddTab(key, StubPage(key)) end
end

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
    elseif msg == "" then
        D.ToggleConfig()
    else
        -- /deck raid, /deck bags, ...: open that page
        local page = D.FindPage(msg)
        if page then
            D.ToggleConfig(page)
        else
            print("DeckUI: no page \"" .. msg .. "\". Pages: " .. D.PageList())
            D.ToggleConfig()
        end
    end
end

-- a page by its key or its sidebar name, any case: "raid", "overview",
-- "loot", "player and target"
function D.FindPage(text)
    text = text:lower()
    for key in pairs(panel.contents) do
        if key:lower() == text or PageName(key):lower() == text then return key end
    end
    for key in pairs(panel.contents) do
        if PageName(key):lower():find(text, 1, true) then return key end
    end
end

function D.PageList()
    local keys = {}
    for _, key in ipairs(panel.tabOrder) do keys[#keys + 1] = key:lower() end
    return table.concat(keys, ", ")
end

local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- The tracker frame: sections of entries, each entry a title line and
-- its objectives, drawn from pooled font strings and bars.
-------------------------------------------------------------------
-- The content comes from sections that register themselves (quests.lua,
-- world.lua, scenario.lua). A section only answers "what is there now":
--   ns.RegisterSection(key, { title = ..., order = n, Collect = function() ... end })
-- Collect returns a list of entries:
--   { key = unique, title = text, color = {r,g,b} | nil,
--     lines = { { text = ..., done = bool, bar = 0..1 | nil }, ... },
--     OnClick = function(button, mouseButton) | nil,
--     OnEnter = function(row) | nil,
--     secure = { type = "item" | "spell", value = link | spellID, icon, logIndex } | nil,
--     widget = a widget container from ns.NewWidgetContainer (drawn instead of text) }
-- A line may carry color = {r,g,b} to override the done/normal colours.
-- Nothing here knows about quests; that keeps the drawing in one place.
-------------------------------------------------------------------
local PAD        = 8
local LINE_GAP   = 2
local ENTRY_GAP  = 6
local BAR_HEIGHT = 10

ns.sections = {}
local ordered = {}

function ns.RegisterSection(key, def)
    def.key = key
    ns.sections[key] = def
    ordered[#ordered + 1] = def
    table.sort(ordered, function(a, b) return (a.order or 99) < (b.order or 99) end)
end

-------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------
local tracker = CreateFrame("Frame", "DeckQuestsTracker", UIParent, "BackdropTemplate")
tracker:SetFrameStrata("LOW")
tracker:SetClampedToScreen(true)
tracker:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 },
})
tracker:SetBackdropColor(0.05, 0.05, 0.05, 0.6)
tracker:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
tracker.defaultPoint = { "TOPRIGHT", UIParent, "TOPRIGHT", -80, -260 }
tracker:SetPoint(unpack(tracker.defaultPoint))
tracker:SetSize(260, 40)
ns.tracker = tracker

local title = tracker:CreateFontString(nil, "OVERLAY")
title:SetFont(D.FONT, 14, "OUTLINE")
title:SetPoint("TOPLEFT", PAD, -PAD)
title:SetText("Objectives")
title:SetTextColor(0.9, 0.75, 0.2)

-- Collapsing everything leaves just the title row, for a fight or a
-- cutscene where the list is in the way.
local collapse = CreateFrame("Button", nil, tracker)
collapse:SetSize(18, 18)
collapse:SetPoint("TOPRIGHT", -4, -4)
collapse.text = collapse:CreateFontString(nil, "OVERLAY")
collapse.text:SetFont(D.FONT, 16, "OUTLINE")
collapse.text:SetPoint("CENTER")
collapse:SetScript("OnClick", function()
    DeckQuestsDB.collapsed = not DeckQuestsDB.collapsed
    ns.RequestUpdate()
end)

-- Content scrolls when it is taller than the height limit; the Deck's
-- 800 pixels do not leave room for a long quest log.
local scroll = CreateFrame("ScrollFrame", nil, tracker)
scroll:SetPoint("TOPLEFT", 0, -(PAD + 20))
scroll:SetPoint("BOTTOMRIGHT", 0, PAD)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(1, 1)
scroll:SetScrollChild(content)
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(self, delta)
    local max = math.max(0, content:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 30)))
    -- the secure item and spell buttons sit on UIParent at screen
    -- coordinates copied from the rows; a redraw moves them along
    ns.RequestUpdate()
end)
ns.content = content

-------------------------------------------------------------------
-- Pools
-------------------------------------------------------------------
local texts, bars, rows, heads = {}, {}, {}, {}
local usedTexts, usedBars, usedRows, usedHeads = 0, 0, 0, 0

local function Text()
    usedTexts = usedTexts + 1
    local fs = texts[usedTexts]
    if not fs then
        fs = content:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        texts[usedTexts] = fs
    end
    fs:Show()
    return fs
end

local function Bar()
    usedBars = usedBars + 1
    local b = bars[usedBars]
    if not b then
        b = CreateFrame("StatusBar", nil, content)
        b:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        b:SetStatusBarColor(0.3, 0.6, 1)
        b:SetMinMaxValues(0, 1)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetColorTexture(0, 0, 0, 0.5)
        b.text = b:CreateFontString(nil, "OVERLAY")
        b.text:SetFont(D.FONT, 9, "OUTLINE")
        b.text:SetPoint("CENTER")
        bars[usedBars] = b
    end
    b:Show()
    return b
end

-- An invisible button over an entry's title, for clicks and tooltips.
local function Row()
    usedRows = usedRows + 1
    local r = rows[usedRows]
    if not r then
        r = CreateFrame("Button", nil, content)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
        r:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
        r:SetScript("OnClick", function(self, button)
            if self.entry and self.entry.OnClick then self.entry.OnClick(self, button) end
        end)
        r:SetScript("OnEnter", function(self)
            if self.entry and self.entry.OnEnter then self.entry.OnEnter(self) end
        end)
        r:SetScript("OnLeave", GameTooltip_Hide)
        rows[usedRows] = r
    end
    r:Show()
    return r
end

-- Section headings are buttons too: a click folds the section.
local function Head()
    usedHeads = usedHeads + 1
    local h = heads[usedHeads]
    if not h then
        h = CreateFrame("Button", nil, content)
        h.text = h:CreateFontString(nil, "OVERLAY")
        h.text:SetFont(D.FONT, 13, "OUTLINE")
        h.text:SetPoint("LEFT")
        h.text:SetTextColor(0.9, 0.75, 0.2)
        h:SetScript("OnClick", function(self)
            local folded = DeckQuestsDB.folded
            folded[self.key] = not folded[self.key] or nil
            ns.RequestUpdate()
        end)
        heads[usedHeads] = h
    end
    h:Show()
    return h
end

local function ReleaseAll()
    for i = 1, usedTexts do texts[i]:Hide() end
    for i = 1, usedBars do bars[i]:Hide() end
    for i = 1, usedRows do rows[i]:Hide(); rows[i].entry = nil end
    for i = 1, usedHeads do heads[i]:Hide() end
    usedTexts, usedBars, usedRows, usedHeads = 0, 0, 0, 0
end

-------------------------------------------------------------------
-- Drawing
-------------------------------------------------------------------
local WHITE = { 1, 1, 1 }
local DONE  = { 0.4, 0.9, 0.4 }
local LINE  = { 0.8, 0.8, 0.8 }

-- ns.drawn: every entry drawn this pass with the row frame it got, so a
-- section can place something beside it (the quest item buttons).
ns.drawn = {}

-- Widget containers not drawn this pass are parked off to the side rather
-- than hidden: a hidden container gets no OnUpdate, and Blizzard's widget
-- layout runs in OnUpdate - it would never lay out again.
local widgets = {}

local function DrawWidget(entry, y)
    local c = entry.widget
    c.drawn = true
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -y)
    c:SetAlpha(1)
    return y + c:GetHeight() + ENTRY_GAP
end

local function DrawEntry(entry, y, width, textSize)
    if entry.widget then return DrawWidget(entry, y) end
    local indent = entry.indent or 0
    local row = Row()
    row.entry = entry
    ns.drawn[#ns.drawn + 1] = { entry = entry, row = row }

    local head = Text()
    head:SetFont(D.FONT, textSize + 1, "OUTLINE")
    head:SetWidth(width - indent)
    head:ClearAllPoints()
    head:SetPoint("TOPLEFT", content, "TOPLEFT", PAD + indent, -y)
    head:SetText(entry.title or "")
    head:SetTextColor(unpack(entry.color or WHITE))
    local top = y
    y = y + head:GetStringHeight() + LINE_GAP

    for _, line in ipairs(entry.lines or {}) do
        if line.text and line.text ~= "" then
            local fs = Text()
            fs:SetFont(D.FONT, textSize, "OUTLINE")
            fs:SetWidth(width - indent - 8)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", content, "TOPLEFT", PAD + indent + 8, -y)
            fs:SetText(line.text)
            fs:SetTextColor(unpack(line.color or (line.done and DONE) or LINE))
            y = y + fs:GetStringHeight() + LINE_GAP
        end
        if line.bar then
            local b = Bar()
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", content, "TOPLEFT", PAD + indent + 8, -y)
            b:SetSize(math.min(160, width - indent - 16), BAR_HEIGHT)
            b:SetValue(line.bar)
            b.text:SetText(math.floor(line.bar * 100 + 0.5) .. "%")
            y = y + BAR_HEIGHT + LINE_GAP
        end
    end

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -top)
    row:SetSize(width, math.max(y - top, 14))
    return y + ENTRY_GAP
end

local function Draw()
    ReleaseAll()
    wipe(ns.drawn)
    for _, c in ipairs(widgets) do c.drawn = false end
    local d = ns.DeviceDB()
    local width, textSize = d.width, d.textSize
    tracker:SetScale(d.scale)
    tracker:SetWidth(width + 2 * PAD)
    content:SetWidth(width + 2 * PAD)

    collapse.text:SetText(DeckQuestsDB.collapsed and "+" or "-")

    local y = 0
    local anything = false
    if not DeckQuestsDB.collapsed then
        for _, section in ipairs(ordered) do
            local ok, entries = pcall(section.Collect)
            if not ok then
                -- one broken section must not take the others with it
                entries = { { key = section.key .. "-error", title = section.title .. ": error",
                    color = { 1, 0.3, 0.3 }, lines = { { text = tostring(entries) } } } }
            end
            if entries and #entries > 0 then
                anything = true
                local h = Head()
                h.key = section.key
                local folded = DeckQuestsDB.folded[section.key]
                h.text:SetText((folded and "+ " or "- ") .. section.title .. "  (" .. #entries .. ")")
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -y)
                h:SetSize(width, 16)
                y = y + 18
                if not folded then
                    for _, entry in ipairs(entries) do
                        y = DrawEntry(entry, y, width, textSize)
                    end
                end
                y = y + 4
            end
        end
    end

    content:SetHeight(math.max(y, 1))
    local chrome = PAD + 20 + PAD
    local height = DeckQuestsDB.collapsed and chrome or math.min(y + chrome, d.maxHeight)
    -- The tracker must grow and shrink from its top edge. Whatever put it
    -- elsewhere - a drag, /deck unlock, a position saved before this fix -
    -- is turned into a top-left anchor before the height changes.
    if tracker:GetPoint() ~= "TOPLEFT" then D.PinTopLeft(tracker) end
    tracker:SetHeight(height)
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), math.max(0, y - (height - chrome))))
    tracker:SetShown(anything or DeckQuestsDB.collapsed or D.unlocked)
    for _, c in ipairs(widgets) do
        if not c.drawn then
            c:ClearAllPoints()
            c:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", -2000, 0)
            c:SetAlpha(0)
        end
    end
    ns.PlaceSecureButtons()
end

-------------------------------------------------------------------
-- Widget containers (zone widgets, the delve header, scenario widgets)
-------------------------------------------------------------------
-- Blizzard's UIWidgetContainerTemplate hosts a widget set in any frame;
-- containers are tracked one by one, so ours can hold the same set as
-- Blizzard's. It sizes itself (ResizeLayoutFrame) after each layout, and
-- our layout callback asks the tracker to redraw around the new height.
local function WidgetLayout(container, sortedWidgets)
    DefaultWidgetLayout(container, sortedWidgets)
    ns.RequestUpdate()
end

function ns.NewWidgetContainer()
    local c = CreateFrame("Frame", nil, content, "UIWidgetContainerTemplate")
    c:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", -2000, 0)
    c:SetAlpha(0)
    widgets[#widgets + 1] = c
    return c
end

-- Registering the same set again is a no-op, another ID replaces it and
-- nil unregisters - so this can simply be called on every Collect.
function ns.SetWidgetSet(container, setID)
    if container.setID == setID then return end
    container.setID = setID
    container:RegisterForWidgetSet(setID, setID and WidgetLayout or nil)
end

function ns.HasWidgets(container)
    return container.setID ~= nil and container:IsShown() and (container:GetNumWidgetsShowing() or 0) > 0
end

-------------------------------------------------------------------
-- Secure buttons beside entries: quest items and scenario spells
-------------------------------------------------------------------
-- Blizzard's own buttons call UseQuestLogSpecialItem / CastSpellByID from
-- untainted code; ours cannot, so they are SecureActionButtons with type
-- "item" or "spell" - the path a macro takes. Secure buttons cannot be
-- created, moved, shown or hidden in combat, and nothing anchored to them
-- may move either. So they hang off UIParent at screen coordinates copied
-- from the rows out of combat, beside the tracker's left edge, and in
-- combat they stay where they are until PLAYER_REGEN_ENABLED re-places
-- them. A quest finished mid-fight keeps its button until then.
local BUTTON_SIZE = 26
local secureButtons = {}
local pendingPlace = false

local function SecureButton(i)
    local b = secureButtons[i]
    if b then return b end
    b = CreateFrame("Button", "DeckQuestsButton" .. i, UIParent, "SecureActionButtonTemplate")
    b:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    b:SetFrameStrata("LOW")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = b:CreateFontString(nil, "OVERLAY")
    b.count:SetFont(D.FONT, 11, "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", -1, 1)
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints()
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    b:SetScript("OnEnter", function(self)
        local s = self.secure
        if not s then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if s.type == "item" then GameTooltip:SetHyperlink(s.value) else GameTooltip:SetSpellByID(s.value) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:Hide()
    secureButtons[i] = b
    return b
end

-- Cooldown and charges are plain textures and text, fine in combat too.
-- Spell cooldown numbers may be secret values: only the isActive boolean
-- is read, the numbers go straight into Blizzard's Cooldown frame.
local function UpdateSecureState(b)
    local s = b.secure
    if not s then return end
    if s.type == "item" and s.logIndex then
        local start, duration, enable = GetQuestLogSpecialItemCooldown(s.logIndex)
        if start then CooldownFrame_Set(b.cooldown, start, duration, enable) end
        local _, _, charges = GetQuestLogSpecialItemInfo(s.logIndex)
        b.count:SetText(charges and charges > 1 and charges or "")
    elseif s.type == "spell" then
        b.count:SetText("")
        local ok, info = pcall(C_Spell.GetSpellCooldown, s.value)
        if ok and type(info) == "table" and info.isActive then
            pcall(b.cooldown.SetCooldown, b.cooldown, info.startTime, info.duration, info.modRate)
        else
            b.cooldown:Clear()
        end
    end
end

function ns.UpdateSecureStates()
    for _, b in ipairs(secureButtons) do if b:IsShown() then UpdateSecureState(b) end end
end

function ns.PlaceSecureButtons()
    if InCombatLockdown() then
        pendingPlace = true
        ns.UpdateSecureStates()
        return
    end
    pendingPlace = false

    local uiScale = UIParent:GetEffectiveScale()
    local top, bottom = scroll:GetTop(), scroll:GetBottom()
    local s_b = tracker:GetScale()
    local used = 0
    for _, drawn in ipairs(ns.drawn) do
        local s, row = drawn.entry.secure, drawn.row
        local rowTop = row:GetTop()
        -- only rows actually visible inside the scrolled area get a button
        local visible = s and tracker:IsShown() and rowTop and top and rowTop <= top + 1 and rowTop - 10 >= bottom
        if visible then
            used = used + 1
            local b = SecureButton(used)
            b.secure = s
            b:SetAttribute("type", s.type)
            b:SetAttribute("item", s.type == "item" and s.value or nil)
            b:SetAttribute("spell", s.type == "spell" and s.value or nil)
            b.icon:SetTexture(s.icon)
            b:SetScale(s_b)
            b:ClearAllPoints()
            -- the row's top, left of the tracker's edge, in UIParent space
            b:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT",
                (tracker:GetLeft() * tracker:GetEffectiveScale() / uiScale - 4) / s_b,
                rowTop * row:GetEffectiveScale() / uiScale / s_b)
            UpdateSecureState(b)
            b:Show()
        end
    end
    for i = used + 1, #secureButtons do
        secureButtons[i]:Hide()
        secureButtons[i].secure = nil
    end
end

-- A quest's usable item, as Blizzard decides it (QuestUtil.QuestShowsItemByIndex)
function ns.QuestItem(logIndex, complete)
    if not logIndex then return nil end
    local link, icon, _, showWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
    if link and (not complete or showWhenComplete) then
        return { type = "item", value = link, icon = icon, logIndex = logIndex }
    end
    return nil
end

local secureEvents = CreateFrame("Frame")
secureEvents:RegisterEvent("BAG_UPDATE_COOLDOWN")
secureEvents:RegisterEvent("SPELL_UPDATE_COOLDOWN")
secureEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
secureEvents:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingPlace then ns.RequestUpdate() end
    else
        ns.UpdateSecureStates()
    end
end)

-------------------------------------------------------------------
-- Updating
-------------------------------------------------------------------
-- Quest events come in floods (QUEST_LOG_UPDATE fires several times a
-- second while questing), so they only mark the tracker dirty and one
-- redraw runs on the next frame. Sections with a clock ask for a redraw
-- through ns.ticking: true every second (the Mythic+ timer), "minute"
-- once a minute (world quest countdowns, which count minutes).
local dirty = true
ns.ticking = {}

function ns.RequestUpdate() dirty = true end

local updater = CreateFrame("Frame")
local sinceTick, seconds = 0, 0
updater:SetScript("OnUpdate", function(_, dt)
    sinceTick = sinceTick + dt
    if sinceTick >= 1 then
        sinceTick = 0
        seconds = (seconds + 1) % 60
        for _, rate in pairs(ns.ticking) do
            if rate == true or seconds == 0 then
                dirty = true
                break
            end
        end
    end
    if dirty and DeckQuestsDB and DeckQuestsDB.folded then   -- after Init
        dirty = false
        Draw()
    end
end)

-------------------------------------------------------------------
-- Turning Blizzard's tracker off
-------------------------------------------------------------------
-- Everything it showed is drawn here now, so it goes entirely, the way
-- Blizzard's own kiosk mode does it: SetCanAddModules(false) before
-- ObjectiveTrackerManager:Init - which waits for PLAYER_ENTERING_WORLD,
-- after this module's PLAYER_LOGIN - means no module is ever added, and a
-- module never added never registers a single event. Switched on in a
-- running session, the modules already exist; RemoveAllModules leaves
-- them frozen but alive, so the frame is hidden as well. Nothing in
-- Blizzard's code shows it again once it has no modules.
--
-- The frame itself keeps its own events: QUEST_ACCEPTED is where
-- Blizzard auto-watches new quests (CVar autoQuestWatch), and ZONE_CHANGED
-- re-sorts the watch list - both still wanted.
--
-- This replaced taking single modules out (2026-09-29): that wrote into
-- the container's module list and tainted every later layout of the
-- modules left behind, which only worked while none of them had buttons.
local function DisableBlizzardTracker()
    if ObjectiveTrackerManager then
        ObjectiveTrackerManager:SetCanAddModules(false)
        ObjectiveTrackerManager:RemoveAllModules()
    end
    if ObjectiveTrackerFrame then
        ObjectiveTrackerFrame:Hide()
        -- belt and braces, should a patch find a new way to show it
        hooksecurefunc(ObjectiveTrackerFrame, "Show", function(self) self:Hide() end)
    end
end

-- /quests debug: is Blizzard's tracker really gone
function ns.PrintBlizzardModules()
    local f = ObjectiveTrackerFrame
    local count = f and f.modules and #f.modules or 0
    print(("DeckUI Quests: Blizzard's tracker shown=%s, modules=%d"):format(
        tostring(f and f:IsShown()), count))
    local n = 0
    for _, c in ipairs(widgets) do
        if ns.HasWidgets(c) then n = n + 1 end
    end
    print(("  widget containers with widgets: %d of %d"):format(n, #widgets))
    local shown = 0
    for _, b in ipairs(secureButtons) do if b:IsShown() then shown = shown + 1 end end
    print(("  secure buttons: %d shown, %d made, waiting for combat end=%s"):format(
        shown, #secureButtons, tostring(pendingPlace)))
end

-------------------------------------------------------------------
-- Settings shared by all sections (per device, like the other modules)
-------------------------------------------------------------------
local DEVICE_DEFAULTS = {
    deck = { width = 230, scale = 0.9, textSize = 11, maxHeight = 420 },
    pc   = { width = 260, scale = 1.0, textSize = 12, maxHeight = 600 },
}

function ns.DeviceDB()
    return D.DeviceDB(DeckQuestsDB, DEVICE_DEFAULTS)
end

-------------------------------------------------------------------
-- Module startup (normal login AND load on demand via the menu)
-------------------------------------------------------------------
local function Init()
    DeckQuestsDB = DeckQuestsDB or {}
    DeckQuestsDB.folded = DeckQuestsDB.folded or {}
    if DeckQuestsDB.collapsed == nil then DeckQuestsDB.collapsed = false end

    D.MakeMovable(tracker, "Quest tracker", DeckQuestsDB)
    D.MakeDraggable(tracker)
    -- the secure buttons hang beside the rows and have to follow a move
    tracker:HookScript("OnDragStop", function()
        D.PinTopLeft(tracker)
        ns.RequestUpdate()
    end)

    DisableBlizzardTracker()
    for _, section in ipairs(ordered) do
        if section.Init then section.Init() end
    end
    ns.RequestUpdate()
end

if IsLoggedIn() then
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, name)
        if name == ADDON then
            self:UnregisterEvent("ADDON_LOADED")
            Init()
        end
    end)
else
    local login = CreateFrame("Frame")
    login:RegisterEvent("PLAYER_LOGIN")
    login:SetScript("OnEvent", Init)
end

-- /quests folds and unfolds the tracker; /quests config opens the tab,
-- /quests debug says whether Blizzard's tracker is gone, /quests reset
-- brings the tracker back to its default place.
SLASH_DECKQUESTS1 = "/quests"
SlashCmdList.DECKQUESTS = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "config" then
        D.ToggleConfig("Quests")
    elseif msg == "reset" then
        D.ResetPosition(tracker)
        ns.RequestUpdate()
        print("DeckUI Quests: tracker back at its default place (top right).")
    elseif msg == "debug" then
        local point, rel, relPoint, x, y = tracker:GetPoint()
        print(("DeckUI Quests: tracker shown=%s visible=%s collapsed=%s alpha=%.2f scale=%.2f size=%.0fx%.0f"):format(
            tostring(tracker:IsShown()), tostring(tracker:IsVisible()), tostring(DeckQuestsDB.collapsed),
            tracker:GetAlpha(), tracker:GetScale(), tracker:GetWidth(), tracker:GetHeight()))
        print(("  point %s %s %s %.0f %.0f, top=%s bottom=%s, screen %.0fx%.0f"):format(
            tostring(point), rel and (rel:GetName() or "?") or "nil", tostring(relPoint), x or 0, y or 0,
            tostring(tracker:GetTop() and math.floor(tracker:GetTop())), tostring(tracker:GetBottom() and math.floor(tracker:GetBottom())),
            UIParent:GetWidth(), UIParent:GetHeight()))
        ns.PrintBlizzardModules()
    else
        DeckQuestsDB.collapsed = not DeckQuestsDB.collapsed
        ns.RequestUpdate()
    end
end

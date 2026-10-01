local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- The window: one character at a time, six tabs
-------------------------------------------------------------------
-- Overview (the week in a few lines), Characters (all of them side by
-- side - a click picks one), Instances, Quests, Renown, Currencies.
-- Text rows in a scroll frame, DeckUI's look: dark fill, thin edge, gold
-- headings. Dragged by its frame like the bag window.
-------------------------------------------------------------------
local W, H = 520, 460
local ROW = 18
local GOLD = { 1, 0.82, 0 }
local GREEN, GREY, RED = "|cff33ff33", "|cff888888", "|cffff5555"
local SQUARE = "|TInterface\\Buttons\\WHITE8x8:9:9:0:0:8:8:0:8:0:8:%d:%d:%d|t"

local TABS = {
    { key = "overview",   title = "Overview" },
    { key = "chars",      title = "Characters" },
    { key = "instances",  title = "Instances" },
    { key = "quests",     title = "Quests" },
    { key = "renown",     title = "Renown" },
    { key = "currencies", title = "Currencies" },
}

local win = CreateFrame("Frame", "DeckWeekWindow", UIParent)
win:SetSize(W, H)
win:SetFrameStrata("HIGH")
win:SetToplevel(true)
win:EnableMouse(true)
win:SetClampedToScreen(true)
win.defaultPoint = { "CENTER", UIParent, "CENTER", 0, 40 }
win:SetPoint(unpack(win.defaultPoint))
win:Hide()
tinsert(UISpecialFrames, "DeckWeekWindow")

do  -- a fill and four one-pixel lines, anchored only
    local bg = win:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
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
title:SetFont(D.FONT, 15, "OUTLINE")
title:SetPoint("TOPLEFT", 14, -12)
title:SetText("This week")

local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

local resetText = win:CreateFontString(nil, "OVERLAY")
resetText:SetFont(D.FONT, 12, "OUTLINE")
resetText:SetPoint("TOPRIGHT", -34, -14)
resetText:SetTextColor(0.7, 0.7, 0.7)

-- the character switcher: < name >
local selected     -- the key of the character on show
local prevBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
prevBtn:SetSize(24, 22)
prevBtn:SetPoint("TOPLEFT", 14, -36)
prevBtn:SetText("<")
local charText = win:CreateFontString(nil, "OVERLAY")
charText:SetFont(D.FONT, 13, "OUTLINE")
charText:SetPoint("LEFT", prevBtn, "RIGHT", 8, 0)
charText:SetWidth(200)
charText:SetJustifyH("LEFT")
local nextBtn = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
nextBtn:SetSize(24, 22)
nextBtn:SetPoint("LEFT", charText, "RIGHT", 8, 0)
nextBtn:SetText(">")
local seenText = win:CreateFontString(nil, "OVERLAY")
seenText:SetFont(D.FONT, 11, "OUTLINE")
seenText:SetPoint("LEFT", nextBtn, "RIGHT", 10, 0)
seenText:SetTextColor(0.6, 0.6, 0.6)

-- tabs
local current = "overview"
local tabButtons = {}
for i, tab in ipairs(TABS) do
    local b = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    b:SetSize((W - 28 - 5 * 4) / #TABS, 22)
    b:SetPoint("TOPLEFT", 14 + (i - 1) * ((W - 28 - 5 * 4) / #TABS + 4), -66)
    b:SetText(tab.title)
    b:GetFontString():SetFont(D.FONT, 11, "OUTLINE")
    b.key = tab.key
    tabButtons[i] = b
end

-- the scrolling content
local scroll = CreateFrame("ScrollFrame", "DeckWeekScroll", win, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 12, -96)
scroll:SetPoint("BOTTOMRIGHT", -32, 12)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(W - 50, 10)
scroll:SetScrollChild(content)

-------------------------------------------------------------------
-- Rows
-------------------------------------------------------------------
local rows, used = {}, 0

local function NewRow()
    used = used + 1
    local r = rows[used]
    if not r then
        r = CreateFrame("Button", nil, content)
        r:SetHeight(ROW)
        r.left = r:CreateFontString(nil, "OVERLAY")
        r.left:SetFont(D.FONT, 12, "OUTLINE")
        r.left:SetPoint("LEFT", 4, 0)
        r.left:SetJustifyH("LEFT")
        r.left:SetWordWrap(false)
        r.right = r:CreateFontString(nil, "OVERLAY")
        r.right:SetFont(D.FONT, 12, "OUTLINE")
        r.right:SetPoint("RIGHT", -4, 0)
        r.right:SetJustifyH("RIGHT")
        r.right:SetWordWrap(false)
        r.left:SetPoint("RIGHT", r.right, "LEFT", -8, 0)
        r:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
        r:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
        rows[used] = r
    end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(used - 1) * ROW)
    r:SetPoint("RIGHT", content, "RIGHT")
    r.left:SetTextColor(1, 1, 1)
    r.right:SetTextColor(1, 1, 1)
    r:SetScript("OnClick", nil)
    r:EnableMouse(false)
    r:Show()
    return r
end

local function Line(left, right)
    local r = NewRow()
    r.left:SetText(left or "")
    r.right:SetText(right or "")
    return r
end

local function Heading(text)
    if used > 0 then Line() end
    local r = Line(text)
    r.left:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    return r
end

local function Begin()
    for i = 1, #rows do rows[i]:Hide() end
    used = 0
end

local function Finish()
    content:SetHeight(math.max(used * ROW, 10))
end

-------------------------------------------------------------------
-- Formatting
-------------------------------------------------------------------
local function Duration(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local d, h, m = math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600), math.floor(seconds % 3600 / 60)
    if d > 0 then return ("%dd %dh"):format(d, h) end
    if h > 0 then return ("%dh %dm"):format(h, m) end
    return ("%dm"):format(m)
end

local function Square(done)
    if done then return SQUARE:format(60, 220, 60) end
    return SQUARE:format(70, 70, 70)
end

local function ClassName(snap)
    local c = snap.class and RAID_CLASS_COLORS[snap.class]
    local name = snap.name or "?"
    return c and ("|c%s%s|r"):format(c.colorStr, name) or name
end

-- three slots of one vault row: squares and progress towards the last
local function VaultRow(slots)
    local text, progress, top = "", 0, 0
    for i = 1, 3 do
        local s = slots and slots[i]
        text = text .. Square(s and s.progress >= s.threshold) .. " "
        if s then
            progress = math.max(progress, s.progress)
            top = math.max(top, s.threshold)
        end
    end
    return text, progress, top
end

local VAULT_NAMES = { raid = "Raid", mplus = "Dungeons", world = "World / Delves" }

-------------------------------------------------------------------
-- Tabs
-------------------------------------------------------------------
local function Snap()
    return DeckWeekDB and DeckWeekDB.chars[selected]
end

local Render = {}

function Render.overview(snap, stale)
    Heading("Great Vault")
    for _, kind in ipairs({ "raid", "mplus", "world" }) do
        local slots = not stale and snap.vault and snap.vault[kind] or nil
        local squares, progress, top = VaultRow(slots)
        Line(VAULT_NAMES[kind], ("%s  %d/%d"):format(squares, progress, top))
    end
    if snap.vault and snap.vault.rewardsWaiting then
        Line(GREEN .. "Rewards are waiting in the vault|r")
    end

    Heading("Mythic+")
    local key = snap.keystone or {}
    Line("Keystone", key.level and ("+%d %s"):format(key.level, key.map or "") or (GREY .. "none|r"))
    if not stale then
        Line("Runs this week", ("%d%s"):format(key.runs or 0,
            (key.best or 0) > 0 and ("  (best +%d)"):format(key.best) or ""))
    end

    Heading("This week")
    local raids, dungeons = 0, 0
    for _, l in ipairs(snap.locks or {}) do
        if not l.resetAt or l.resetAt > time() then
            if l.raid then raids = raids + 1 else dungeons = dungeons + 1 end
        end
    end
    Line("Locked raids / dungeons", ("%d / %d"):format(raids, dungeons))
    local open, total = 0, 0
    for questID in pairs(DeckWeekDB.weeklies) do
        total = total + 1
        if stale or not (snap.weekliesDone and snap.weekliesDone[questID]) then open = open + 1 end
    end
    Line("Weekly quests open", ("%d of %d known"):format(open, total))
    local log = snap.travelers
    if log and log.max > 0 then
        Line(("Traveler's Log (%s)"):format(log.month or ""), ("%d / %d"):format(log.points, log.max))
    end
end

function Render.chars()
    local list = {}
    for key, snap in pairs(DeckWeekDB.chars) do list[#list + 1] = { key = key, snap = snap } end
    table.sort(list, function(a, b)
        if (a.snap.ilvl or 0) ~= (b.snap.ilvl or 0) then return (a.snap.ilvl or 0) > (b.snap.ilvl or 0) end
        return a.key < b.key
    end)
    Heading("Characters - click one to show it")
    for _, entry in ipairs(list) do
        local snap = entry.snap
        local stale = ns.IsStale(snap)
        local parts = {}
        for _, kind in ipairs({ "raid", "mplus", "world" }) do
            local n = 0
            for i = 1, 3 do
                local s = not stale and snap.vault and snap.vault[kind] and snap.vault[kind][i]
                if s and s.progress >= s.threshold then n = n + 1 end
            end
            parts[#parts + 1] = ("%s %d/3"):format(kind == "raid" and "R" or kind == "mplus" and "M" or "W", n)
        end
        local key = snap.keystone and snap.keystone.level and (" +%d"):format(snap.keystone.level) or ""
        local r = Line(("%s  %s%d · %d|r"):format(ClassName(snap), GREY, snap.level or 0, snap.ilvl or 0),
            table.concat(parts, "  ") .. key .. (stale and (GREY .. "  (reset)|r") or ""))
        r:EnableMouse(true)
        r:SetScript("OnClick", function()
            selected = entry.key
            current = "overview"
            ns.Refresh()
        end)
    end
end

function Render.instances(snap)
    local any = false
    for _, kind in ipairs({ true, false }) do
        local first = true
        for _, l in ipairs(snap.locks or {}) do
            if (l.raid and true or false) == kind and (not l.resetAt or l.resetAt > time()) then
                if first then Heading(kind and "Raids" or "Dungeons and world bosses") first = false end
                local color = l.killed >= l.total and GREEN or ""
                Line(("%s  %s%s|r"):format(l.name, GREY, l.difficulty or ""),
                    ("%s%d/%d|r  %sresets in %s|r"):format(color, l.killed, l.total, GREY, Duration(l.resetAt - time())))
                any = true
            end
        end
    end
    if not any then Line(GREY .. "No locked instances this week.|r") end
end

function Render.quests(snap, stale)
    local list = {}
    for questID, name in pairs(DeckWeekDB.weeklies) do list[#list + 1] = { id = questID, name = name } end
    table.sort(list, function(a, b) return a.name < b.name end)
    Heading("Weekly quests - learned whenever one is in a quest log")
    if #list == 0 then
        Line(GREY .. "None known yet: take a weekly quest and it is listed from then on.|r")
    end
    for _, q in ipairs(list) do
        local done = not stale and snap.weekliesDone and snap.weekliesDone[q.id]
        Line(q.name, done and (GREEN .. "done|r") or "open")
    end
end

function Render.renown(snap)
    Heading("Renown")
    if not snap.renown or #snap.renown == 0 then Line(GREY .. "No renown factions unlocked.|r") end
    for _, f in ipairs(snap.renown or {}) do
        local maxed = f.max and f.level >= f.max
        Line(f.name, maxed and (GREEN .. ("%d (max)|r"):format(f.level))
            or ("%d / %d  %s(%d/%d)|r"):format(f.level, f.max or 0, GREY, f.earned or 0, f.threshold or 0))
    end
end

function Render.currencies(snap, stale)
    Heading("Currencies - weekly and seasonal caps, and the ones in your backpack")
    for _, c in ipairs(snap.currencies or {}) do
        local right = BreakUpLargeNumbers(c.quantity or 0)
        if c.weekMax then
            local earned = stale and 0 or (c.weekEarned or 0)
            right = right .. ("  %sweek %d/%d|r"):format(earned >= c.weekMax and GREEN or GREY, earned, c.weekMax)
        elseif c.seasonMax then
            right = right .. ("  %sseason %d/%d|r"):format(GREY, c.seasonEarned or 0, c.seasonMax)
        elseif c.max then
            right = right .. ("  %s/ %d|r"):format(GREY, c.max)
        end
        Line(("|T%d:14:14|t %s"):format(c.icon or 0, c.name or "?"), right)
    end
end

-------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------
local function CharKeys()
    local keys = {}
    for key in pairs(DeckWeekDB.chars) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

local function Step(dir)
    local keys = CharKeys()
    if #keys == 0 then return end
    local index = 1
    for i, k in ipairs(keys) do if k == selected then index = i end end
    selected = keys[(index - 1 + dir) % #keys + 1]
    ns.Refresh()
end
prevBtn:SetScript("OnClick", function() Step(-1) end)
nextBtn:SetScript("OnClick", function() Step(1) end)

function ns.Refresh()
    if not win:IsShown() then return end
    selected = selected or ns.CharKey()
    local snap = Snap()
    resetText:SetText("Reset in " .. Duration(C_DateAndTime.GetSecondsUntilWeeklyReset()))
    for _, b in ipairs(tabButtons) do b:SetEnabled(b.key ~= current) end

    Begin()
    if not snap then
        charText:SetText(selected)
        Line(GREY .. "Nothing saved for this character yet.|r")
    else
        local stale = ns.IsStale(snap)
        charText:SetText(ClassName(snap) .. GREY .. " - " .. (snap.realm or "") .. "|r")
        if selected == ns.CharKey() then
            seenText:SetText("live")
        else
            seenText:SetText(("seen %s ago%s"):format(Duration(time() - (snap.updated or 0)),
                stale and ", before the reset" or ""))
        end
        Render[current](snap, stale)
    end
    Finish()
end

for _, b in ipairs(tabButtons) do
    b:SetScript("OnClick", function(self)
        current = self.key
        scroll:SetVerticalScroll(0)
        ns.Refresh()
    end)
end

win:SetScript("OnShow", function()
    selected = ns.CharKey()
    ns.Snapshot()
    ns.Refresh()
end)

function ns.Toggle()
    win:SetShown(not win:IsShown())
end

function ns.InitWindow()
    D.MakeMovable(win, "Week", DeckWeekDB)
    D.MakeDraggable(win)
end

local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- The window: every character in one table
-------------------------------------------------------------------
-- Reworked 2026-10-02 (the owner: one character at a time behind six tabs
-- was too much clicking, and plain text lines read like a list): one row
-- per character with the week in columns - vault, keystone, hunts, delves,
-- knowledge, weekly quests. A click on a row unfolds that character's
-- details in two columns below it; the character being played starts
-- unfolded. A right click on another character forgets it, a right click
-- on a weekly quest hides it. DeckUI's look: dark fill, thin edge, gold
-- headings. Dragged by its frame like the bag window.
-------------------------------------------------------------------
local W, H = 720, 480
local ROW, CHAR_ROW = 17, 22
local GOLD = { 1, 0.82, 0 }
local GREEN, GREY, ORANGE, RED = "|cff33ff33", "|cff888888", "|cffff9933", "|cffff5555"
local SQUARE = "|TInterface\\Buttons\\WHITE8x8:9:9:0:0:8:8:0:8:0:8:%d:%d:%d|t"
local PAD = 6

-- the table's columns: key, heading, width, explanation on mouse-over
local COLS = {
    { key = "name",   title = "Character", w = 150 },
    { key = "ilvl",   title = "ilvl",      w = 38, tip = "Average item level (equipped)." },
    { key = "raid",   title = "Raid",      w = 54, tip = "Great Vault: raid row." },
    { key = "mplus",  title = "Dungeons",  w = 58, tip = "Great Vault: dungeon row (Mythic+ and Heroic)." },
    { key = "world",  title = "World",     w = 54, tip = "Great Vault: world row (delves and world activities)." },
    { key = "key",    title = "Key",       w = 40, tip = "The keystone in the bags." },
    { key = "prey",   title = "Prey",      w = 62, tip = "Hunts this week: Normal, Hard, Nightmare - four of each count." },
    { key = "delve",  title = "Delves",    w = 56, tip = "Square: the weekly delve quest. Number: Restored Coffer Keys." },
    { key = "prof",   title = "Knowledge", w = 66, tip = "Profession knowledge taken this week, of what the week offers." },
    { key = "quests", title = "Weeklies",  w = 58, tip = "Weekly quests done, of the ones listed (hidden ones not counted)." },
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

-- the column headings, each with its explanation
local header = CreateFrame("Frame", nil, win)
header:SetPoint("TOPLEFT", 12, -40)
header:SetSize(W - 44, 18)
do
    local x = PAD
    for _, col in ipairs(COLS) do
        local cell = CreateFrame("Frame", nil, header)
        cell:SetPoint("LEFT", x, 0)
        cell:SetSize(col.w, 18)
        local text = cell:CreateFontString(nil, "OVERLAY")
        text:SetFont(D.FONT, 11, "OUTLINE")
        text:SetAllPoints()
        text:SetJustifyH(col.key == "name" and "LEFT" or "CENTER")
        text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        text:SetText(col.title)
        if col.tip then
            cell:EnableMouse(true)
            cell:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(col.title)
                GameTooltip:AddLine(col.tip, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            cell:SetScript("OnLeave", GameTooltip_Hide)
        end
        col.x = x
        x = x + col.w
    end
    local line = header:CreateTexture(nil, "BORDER")
    line:SetColorTexture(0.3, 0.3, 0.3, 1)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)
end

-- the scrolling content
local scroll = CreateFrame("ScrollFrame", "DeckWeekScroll", win, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 12, -62)
scroll:SetPoint("BOTTOMRIGHT", -32, 12)
local content = CreateFrame("Frame", nil, scroll)
local CW = W - 44
content:SetSize(CW, 10)
scroll:SetScrollChild(content)

-------------------------------------------------------------------
-- Pools: character rows, detail lines, detail backgrounds
-------------------------------------------------------------------
local charRows, lines, panels = {}, {}, {}
local usedChars, usedLines, usedPanels = 0, 0, 0

local function NewCharRow()
    usedChars = usedChars + 1
    local r = charRows[usedChars]
    if not r then
        r = CreateFrame("Button", nil, content)
        r:SetSize(CW, CHAR_ROW)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.cells = {}
        for i, col in ipairs(COLS) do
            local fs = r:CreateFontString(nil, "OVERLAY")
            fs:SetFont(D.FONT, 12, "OUTLINE")
            fs:SetPoint("LEFT", col.x, 0)
            fs:SetWidth(col.w)
            fs:SetJustifyH(col.key == "name" and "LEFT" or "CENTER")
            fs:SetWordWrap(false)
            r.cells[col.key] = fs
        end
        r:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
        r:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
        charRows[usedChars] = r
    end
    r:Show()
    return r
end

local function NewLine()
    usedLines = usedLines + 1
    local r = lines[usedLines]
    if not r then
        r = CreateFrame("Button", nil, content)
        r:SetHeight(ROW)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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
        lines[usedLines] = r
    end
    r.left:SetTextColor(1, 1, 1)
    r.right:SetTextColor(1, 1, 1)
    r:SetScript("OnClick", nil)
    r:SetScript("OnEnter", nil)
    r:SetScript("OnLeave", nil)
    r:EnableMouse(false)
    r:Show()
    return r
end

local function NewPanel()
    usedPanels = usedPanels + 1
    local t = panels[usedPanels]
    if not t then
        t = content:CreateTexture(nil, "BACKGROUND", nil, -7)
        t:SetColorTexture(1, 1, 1, 0.035)
        panels[usedPanels] = t
    end
    t:Show()
    return t
end

local function Begin()
    for _, pool in ipairs({ charRows, lines, panels }) do
        for i = 1, #pool do pool[i]:Hide() end
    end
    usedChars, usedLines, usedPanels = 0, 0, 0
end

-------------------------------------------------------------------
-- A detail column: lines stacked from a top edge
-------------------------------------------------------------------
local Column = {}
Column.__index = Column

local function NewColumn(x, w, y)
    return setmetatable({ x = x, w = w, y = y }, Column)
end

function Column:Line(left, right)
    local r = NewLine()
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", content, "TOPLEFT", self.x, self.y)
    r:SetWidth(self.w)
    r.left:SetText(left or "")
    r.right:SetText(right or "")
    self.y = self.y - ROW
    return r
end

function Column:Heading(text)
    if self.started then self.y = self.y - 6 end
    self.started = true
    local r = self:Line(text)
    r.left:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    return r
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

local function Icon(fileID)
    return fileID and ("|T%d:14:14:0:0:64:64:5:59:5:59|t "):format(fileID) or ""
end

local function Count(n, max)
    if max == 0 then return GREY .. "-|r" end
    local color = n >= max and GREEN or (n > 0 and "" or GREY)
    return ("%s%d/%d|r"):format(color, n, max)
end

-- three slots of one vault row: squares, and the slots' state
local function VaultSlots(snap, stale, kind)
    local slots = not stale and snap.vault and snap.vault[kind] or nil
    local squares, progress, top, ilvls = "", 0, 0, {}
    for i = 1, 3 do
        local s = slots and slots[i]
        local done = s and s.progress >= s.threshold
        squares = squares .. Square(done)
        if s then
            progress = math.max(progress, s.progress)
            top = math.max(top, s.threshold)
            if done and s.ilvl then ilvls[#ilvls + 1] = s.ilvl end
        end
    end
    return squares, progress, top, ilvls
end

local VAULT_NAMES = { raid = "Raid", mplus = "Dungeons", world = "World / Delves" }
local PREY_NAMES = { { "normal", "Normal" }, { "hard", "Hard" }, { "nightmare", "Nightmare" } }
local KIND_NAMES = { treatise = "Treatise", quest = "Weekly quest", treasure = "Treasures and gathering" }

-- the weekly quests to list: the fixed ones, then the learned ones
local function QuestList()
    local list = {}
    for _, w in ipairs(ns.WEEKLIES) do
        local name = #w.ids == 1 and C_QuestLog.GetTitleForQuestID(w.ids[1]) or w.name
        list[#list + 1] = { key = w.ids[1], name = name }
    end
    local learned = {}
    for questID, name in pairs(DeckWeekDB.weeklies) do learned[#learned + 1] = { key = questID, name = name } end
    table.sort(learned, function(a, b) return a.name < b.name end)
    for _, q in ipairs(learned) do list[#list + 1] = q end
    return list
end

-------------------------------------------------------------------
-- The table row of one character
-------------------------------------------------------------------
local expanded = {}       -- character key -> unfolded
local showHidden = false  -- hidden weekly quests listed (greyed) this session

local function FillRow(r, key, snap, stale, live)
    local c = r.cells
    c.name:SetText(ClassName(snap) .. (live and (GREEN .. " •|r") or ""))
    c.ilvl:SetText(snap.ilvl or "")
    for _, kind in ipairs({ "raid", "mplus", "world" }) do
        c[kind]:SetText((VaultSlots(snap, stale, kind)))
    end
    local keystone = snap.keystone
    c.key:SetText(keystone and keystone.level and ("+" .. keystone.level) or (GREY .. "-|r"))

    local prey = not stale and snap.prey and snap.prey.done
    if prey then
        c.prey:SetText(("%d  %s%d|r  %s%d|r"):format(prey.normal, ORANGE, prey.hard, RED, prey.nightmare))
    else
        c.prey:SetText(GREY .. "0  0  0|r")
    end

    local delves = snap.delves
    c.delve:SetText(delves and (Square(not stale and delves.weekly) .. " " .. delves.keys) or (GREY .. "-|r"))

    local points, max = 0, 0
    for _, p in ipairs(snap.profs or {}) do
        points, max = points + (stale and 0 or p.points), max + p.max
    end
    c.prof:SetText(max > 0 and Count(points, max) or (GREY .. "-|r"))

    local done, total = 0, 0
    for _, q in ipairs(QuestList()) do
        if not DeckWeekDB.hidden[q.key] then
            total = total + 1
            if not stale and snap.weekliesDone and snap.weekliesDone[q.key] then done = done + 1 end
        end
    end
    c.quests:SetText(Count(done, total))

    r.bg:SetColorTexture(1, 1, 1, expanded[key] and 0.08 or 0.02)
    r:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            if live then return end
            D.Dialog({
                text = ("Forget %s? The character comes back the next time you log it in."):format(snap.name or key),
                accept = "Forget",
                onAccept = function()
                    DeckWeekDB.chars[key] = nil
                    ns.Refresh()
                end,
            })
            return
        end
        expanded[key] = not expanded[key]
        ns.Refresh()
    end)
end

-------------------------------------------------------------------
-- The details of one character, in two columns
-------------------------------------------------------------------
local function Details(snap, stale, live, y)
    local half = math.floor((CW - 3 * PAD) / 2)
    local L = NewColumn(PAD, half, y)
    local R = NewColumn(2 * PAD + half, half, y)

    -- left: vault, mythic+, lockouts, weekly quests
    L:Heading("Great Vault")
    for _, kind in ipairs({ "raid", "mplus", "world" }) do
        local squares, progress, top, ilvls = VaultSlots(snap, stale, kind)
        -- the squares last, so they line up at the right edge
        local offer = #ilvls > 0 and (GREY .. "ilvl " .. table.concat(ilvls, " / ") .. "|r  ") or ""
        L:Line(VAULT_NAMES[kind], ("%s%d/%d  %s"):format(offer, progress, top, squares))
    end
    if snap.vault and snap.vault.rewardsWaiting then
        L:Line(GREEN .. "Rewards are waiting in the vault|r")
    end

    L:Heading("Mythic+")
    local key = snap.keystone or {}
    L:Line("Keystone", key.level and ("+%d %s"):format(key.level, key.map or "") or (GREY .. "none|r"))
    L:Line("Runs this week", stale and (GREY .. "0|r")
        or ("%d%s"):format(key.runs or 0, (key.best or 0) > 0 and ("  (best +%d)"):format(key.best) or ""))

    local locks = {}
    for _, l in ipairs(snap.locks or {}) do
        if not l.resetAt or l.resetAt > time() then locks[#locks + 1] = l end
    end
    if #locks > 0 then
        L:Heading("Lockouts")
        for _, l in ipairs(locks) do
            L:Line(("%s  %s%s|r"):format(l.name, GREY, l.difficulty or ""), Count(l.killed, l.total))
        end
    end

    L:Heading("Weekly quests")
    local hidden = 0
    for _, q in ipairs(QuestList()) do
        local isHidden = DeckWeekDB.hidden[q.key]
        if isHidden then hidden = hidden + 1 end
        if not isHidden or showHidden then
            local done = not stale and snap.weekliesDone and snap.weekliesDone[q.key]
            local r = L:Line(isHidden and (GREY .. q.name .. "|r") or q.name,
                isHidden and (GREY .. "hidden|r") or done and (GREEN .. "done|r") or "open")
            r:EnableMouse(true)
            r:SetScript("OnClick", function(_, button)
                if button ~= "RightButton" then return end
                DeckWeekDB.hidden[q.key] = not isHidden or nil
                ns.Refresh()
            end)
            r:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(q.name)
                GameTooltip:AddLine(("Quest %d"):format(q.key), 0.7, 0.7, 0.7)
                GameTooltip:AddLine(isHidden and "Right click: show it again" or "Right click: hide it for all characters",
                    0.7, 0.7, 0.7)
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", GameTooltip_Hide)
        end
    end
    if hidden > 0 then
        local r = L:Line(GREY .. (showHidden and "Hide the hidden ones again" or ("%d hidden - click to list them"):format(hidden)) .. "|r")
        r:EnableMouse(true)
        r:SetScript("OnClick", function()
            showHidden = not showHidden
            ns.Refresh()
        end)
    end

    -- right: delves, prey, knowledge, crests, currencies, renown
    R:Heading("Delves")
    local delves = snap.delves
    if delves then
        local name = C_QuestLog.GetTitleForQuestID(ns.DELVES.weeklyQuest) or ns.DELVES.weeklyName
        R:Line(name, (not stale and delves.weekly) and (GREEN .. "done|r") or "open")
        R:Line("Trovehunter's Bounty", (not stale and delves.bountyUsed) and (GREEN .. "used|r")
            or delves.bounty > 0 and ("%d in the bags"):format(delves.bounty) or (GREY .. "none|r"))
        R:Line("Restored Coffer Keys", delves.keys)
    else
        R:Line(GREY .. "Not seen since the update - log this character in.|r")
    end

    R:Heading("Prey")
    local prey = snap.prey
    for _, d in ipairs(PREY_NAMES) do
        R:Line(d[2], Count(not stale and prey and prey.done[d[1]] or 0, ns.PREY_CAP))
    end
    if live and prey and prey.active then
        R:Line("Active hunt", type(prey.active) == "string" and prey.active or "yes")
    end

    if snap.profs and #snap.profs > 0 then
        R:Heading("Profession knowledge")
        for _, p in ipairs(snap.profs) do
            R:Line(Icon(p.icon) .. (p.name or "?"), Count(stale and 0 or p.points, p.max))
            for _, kind in ipairs({ "treatise", "quest", "treasure" }) do
                local part = p.parts and p.parts[kind]
                if part and part.max > 0 then
                    R:Line(GREY .. "    " .. KIND_NAMES[kind] .. "|r", Count(stale and 0 or part.points, part.max))
                end
            end
        end
    end

    local function Currencies(heading, list)
        if not list or #list == 0 then return end
        R:Heading(heading)
        for _, c in ipairs(list) do
            local right = BreakUpLargeNumbers(c.quantity or 0)
            if c.weekMax then
                local earned = stale and 0 or (c.weekEarned or 0)
                right = right .. ("  %sweek %d/%d|r"):format(earned >= c.weekMax and GREEN or GREY, earned, c.weekMax)
            elseif c.seasonMax then
                local color = (c.seasonEarned or 0) >= c.seasonMax and GREEN or GREY
                right = right .. ("  %sseason %d/%d|r"):format(color, c.seasonEarned or 0, c.seasonMax)
            elseif c.max then
                right = right .. ("  %s/ %d|r"):format(GREY, c.max)
            end
            R:Line(Icon(c.icon) .. (c.name or "?"), right)
        end
    end
    Currencies("Crests", snap.crests)
    Currencies("Currencies", snap.currencies)

    if snap.renown and #snap.renown > 0 then
        R:Heading("Renown")
        for _, f in ipairs(snap.renown) do
            local maxed = f.max and f.level >= f.max
            R:Line(f.name, maxed and (GREEN .. ("%d|r"):format(f.level))
                or ("%d / %d"):format(f.level, f.max or 0))
        end
    end

    local log = snap.travelers
    if log and log.max > 0 then
        R:Heading("Traveler's Log")
        R:Line(log.month or "", Count(log.points, log.max))
    end

    return math.min(L.y, R.y)
end

-------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------
local function SortedChars()
    local list, me = {}, ns.CharKey()
    for key, snap in pairs(DeckWeekDB.chars) do list[#list + 1] = { key = key, snap = snap } end
    table.sort(list, function(a, b)
        if (a.key == me) ~= (b.key == me) then return a.key == me end
        if (a.snap.ilvl or 0) ~= (b.snap.ilvl or 0) then return (a.snap.ilvl or 0) > (b.snap.ilvl or 0) end
        return a.key < b.key
    end)
    return list
end

function ns.Refresh()
    if ns.UpdateButton then ns.UpdateButton() end
    if not win:IsShown() or not DeckWeekDB then return end
    resetText:SetText("Reset in " .. Duration(C_DateAndTime.GetSecondsUntilWeeklyReset()))

    Begin()
    local y, me = 0, ns.CharKey()
    for _, entry in ipairs(SortedChars()) do
        local key, snap = entry.key, entry.snap
        local stale, live = ns.IsStale(snap), key == me
        local r = NewCharRow()
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        FillRow(r, key, snap, stale, live)
        y = y - CHAR_ROW

        if expanded[key] then
            local top = y
            local info = NewColumn(PAD, CW - 2 * PAD, y - 4)
            info:Line(GREY .. ("Level %d · %s · %s|r"):format(snap.level or 0, snap.realm or "",
                live and "playing now" or ("seen %s ago%s"):format(Duration(time() - (snap.updated or 0)),
                    stale and ", before the reset - this week starts empty" or "")))
            y = Details(snap, stale, live, info.y) - 8
            local panel = NewPanel()
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
            panel:SetSize(CW, top - y)
            y = y - 4
        end
    end
    if usedChars == 0 then
        local info = NewColumn(PAD, CW - 2 * PAD, 0)
        info:Line(GREY .. "Nothing saved yet.|r")
        y = info.y
    end
    content:SetHeight(math.max(-y, 10))
end

win:SetScript("OnShow", function()
    expanded[ns.CharKey()] = true
    ns.Snapshot()
    ns.Refresh()
end)

function ns.Toggle()
    win:SetShown(not win:IsShown())
end

-------------------------------------------------------------------
-- The button on screen: a small orb that opens the window
-------------------------------------------------------------------
-- DeckUI's round look (gold ring, dark disc, D.RoundMask), a calendar
-- inside and, in its corner, how many Great Vault slots are unlocked this
-- week. Dragged anywhere directly (owner's wish, 2026-10-02) - a drag
-- does not count as a click - and with /deck unlock like everything; its
-- place is kept per device. Shown unless switched off in the Week tab.
local BTN = 36
local button = CreateFrame("Button", "DeckWeekButton", UIParent)
button:SetSize(BTN, BTN)
button:SetFrameStrata("MEDIUM")
button.defaultPoint = { "TOPRIGHT", UIParent, "TOPRIGHT", -230, -30 }
button:SetPoint(unpack(button.defaultPoint))
button:RegisterForClicks("LeftButtonUp")
button:Hide()

local ring = button:CreateTexture(nil, "BACKGROUND")
ring:SetAllPoints()
ring:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
ring:AddMaskTexture(D.RoundMask(button))

local inner = CreateFrame("Frame", nil, button)
inner:SetPoint("CENTER")
inner:SetSize(BTN - 6, BTN - 6)
local innerMask = D.RoundMask(inner)
local disc = inner:CreateTexture(nil, "BACKGROUND")
disc:SetAllPoints()
disc:SetColorTexture(0.05, 0.05, 0.05, 0.95)
disc:AddMaskTexture(innerMask)
local icon = inner:CreateTexture(nil, "ARTWORK")
icon:SetPoint("CENTER")
icon:SetSize(BTN - 14, BTN - 14)
icon:SetTexture("Interface\\Icons\\INV_Misc_Note_02")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
icon:AddMaskTexture(innerMask)

local hl = button:CreateTexture(nil, "HIGHLIGHT")
hl:SetAllPoints()
hl:SetColorTexture(1, 1, 1, 0.15)
hl:AddMaskTexture(D.RoundMask(button))

local badge = button:CreateFontString(nil, "OVERLAY")
badge:SetFont(D.FONT, 12, "OUTLINE")
badge:SetPoint("BOTTOMRIGHT", 2, -2)
badge:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

-- unlocked vault slots of the character on show in the game, this week
local function UnlockedSlots()
    local snap = DeckWeekDB and DeckWeekDB.chars[ns.CharKey()]
    if not snap or not snap.vault or ns.IsStale(snap) then return 0 end
    local n = 0
    for _, kind in ipairs({ "raid", "mplus", "world" }) do
        for i = 1, 3 do
            local s = snap.vault[kind] and snap.vault[kind][i]
            if s and s.progress >= s.threshold then n = n + 1 end
        end
    end
    return n
end

function ns.UpdateButton()
    if not DeckWeekDB then return end
    button:SetShown(DeckWeekDB.showButton)
    local n = UnlockedSlots()
    badge:SetText(n > 0 and n or "")
end

-- a press that turned into a drag is not a click
button:SetScript("OnMouseDown", function(self) self.dragged = false end)
button:SetScript("OnClick", function(self)
    if self.dragged then return end
    ns.Toggle()
end)
button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("This week")
    GameTooltip:AddLine(("Great Vault: %d of 9 slots unlocked"):format(UnlockedSlots()), 1, 1, 1)
    GameTooltip:AddLine("Reset in " .. Duration(C_DateAndTime.GetSecondsUntilWeeklyReset()), 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Click: open the week overview", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Drag: move it", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
button:SetScript("OnLeave", GameTooltip_Hide)

function ns.InitWindow()
    if DeckWeekDB.showButton == nil then DeckWeekDB.showButton = true end
    D.MakeMovable(win, "Week", DeckWeekDB)
    D.MakeDraggable(win)
    D.MakeMovable(button, "Week button", DeckWeekDB)
    D.MakeDraggable(button)
    button:HookScript("OnDragStart", function(self)
        self.dragged = true
        GameTooltip:Hide()
    end)
    ns.UpdateButton()
end

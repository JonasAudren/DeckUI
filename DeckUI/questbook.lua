local D = DeckUI

-------------------------------------------------------------------
-- The quest book: every quest your characters know, searchable
-------------------------------------------------------------------
-- Owner's wish (2026-10-27): a lexicon of quests, sorted by kind, marked
-- done or not. The game has no list of all quests (nor do Blizzard's data
-- files for Mists, which carry quest IDs only), and a quest addon's
-- database is not ours to take - so the book grows with what your
-- characters meet. DeckUIDB.questBook, off by default, Overview page;
-- /questbook opens it. Retail and Mists alike.
--
-- What it learns (account-wide, DeckUIDB.questBookData):
--  - every quest in a quest log: title, the zone header it sits under,
--    level, kind (the quest's tag - dungeon, raid, group, PvP, elite ... -
--    or daily / weekly from its frequency);
--  - every quest each character has completed (the game's full list, at
--    login, and each turn-in), per character;
--  - the names of completed quests it has never seen in a log, loaded in
--    the background, five a second and out of combat: retail asks the
--    game (C_QuestLog.RequestLoadQuestByID); Mists has no such call, so a
--    hidden tooltip of our own is shown the quest's link, which makes the
--    client fetch it, and the name is read a second later. A quest that
--    gives no name after three tries is left as its number.
-------------------------------------------------------------------
local RATE, TRIES = 0.2, 3
local ROWS, ROW, W, H = 17, 18, 560, 470

local function Enabled() return DeckUIDB and DeckUIDB.questBook end
local function CharKey() return UnitName("player") .. "-" .. GetRealmName() end

local function Data()
    DeckUIDB.questBookData = DeckUIDB.questBookData or { quests = {}, done = {}, tries = {} }
    return DeckUIDB.questBookData
end

-------------------------------------------------------------------
-- Learning
-------------------------------------------------------------------
local WEEKLY = Enum.QuestFrequency and Enum.QuestFrequency.Weekly or LE_QUEST_FREQUENCY_WEEKLY
local DAILY = Enum.QuestFrequency and Enum.QuestFrequency.Daily or LE_QUEST_FREQUENCY_DAILY

local function TagName(questID)
    local info = C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(questID)
    if type(info) == "table" then return info.tagName end
    if GetQuestTagInfo then return select(2, GetQuestTagInfo(questID)) end
end

local function Kind(questID, frequency)
    if frequency and frequency == DAILY then return "Daily" end
    if frequency and frequency == WEEKLY then return "Weekly" end
    local tag = TagName(questID)
    if tag and tag ~= "" then return tag end
    return "Normal"
end

local function Remember(questID, title, zone, level, frequency)
    if not questID or questID == 0 then return end
    local q = Data().quests[questID] or {}
    q.t = title or q.t
    q.z = zone or q.z
    q.l = level or q.l
    q.k = Kind(questID, frequency)
    Data().quests[questID] = q
end

local function LearnLog()
    if C_QuestLog.GetInfo then
        local zone
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info then
                if info.isHeader then
                    zone = info.title
                elseif not info.isHidden then
                    Remember(info.questID, info.title, zone, info.level, info.frequency)
                end
            end
        end
    else
        local zone
        for i = 1, GetNumQuestLogEntries() do
            local title, level, _, isHeader, _, _, frequency, questID = GetQuestLogTitle(i)
            if isHeader then
                zone = title
            else
                Remember(questID, title, zone, level, frequency)
            end
        end
    end
end

local function LearnDone()
    local mine = {}
    if C_QuestLog.GetAllCompletedQuestIDs then
        for _, id in ipairs(C_QuestLog.GetAllCompletedQuestIDs() or {}) do mine[id] = true end
    elseif GetQuestsCompleted then
        for id in pairs(GetQuestsCompleted() or {}) do mine[id] = true end
    end
    Data().done[CharKey()] = mine
end

-------------------------------------------------------------------
-- Loading the names of quests never seen in a log
-------------------------------------------------------------------
local queue, queued = {}, {}
local scanner

local function KnownTitle(id)
    if C_QuestLog.GetTitleForQuestID then
        local t = C_QuestLog.GetTitleForQuestID(id)
        if t and t ~= "" then return t end
    end
    if C_QuestLog.GetQuestInfo then
        local t = C_QuestLog.GetQuestInfo(id)
        if t and t ~= "" then return t end
    end
end

local function Fill()
    local data = Data()
    for _, set in pairs(data.done) do
        for id in pairs(set) do
            local q = data.quests[id]
            if (not q or not q.t) and (data.tries[id] or 0) < TRIES and not queued[id] then
                queued[id] = true
                queue[#queue + 1] = id
            end
        end
    end
end

local pendingID   -- Mists: the quest the scanner was shown, read on the next step
local function Step()
    if not Enabled() or InCombatLockdown() then return end
    local data = Data()
    if pendingID then
        local id = pendingID
        pendingID = nil
        local t = KnownTitle(id)
        if not t and scanner then
            local line = _G["DeckQuestBookScanTextLeft1"]
            t = line and line:GetText()
            if t == "" then t = nil end
        end
        if t then
            Remember(id, t)
        else
            data.tries[id] = (data.tries[id] or 0) + 1
        end
        return
    end
    -- Mists: the tooltip scanner is off unless asked for (Windows page,
    -- DeckUIDB.questBookScan). A quest link the client cannot resolve makes
    -- it fetch the quest from the server, five times a second, for
    -- hundreds of quests - and the client crashed (ACCESS_VIOLATION) nine
    -- times on 27/28.10 while this ran, mostly at loot, which fetches item
    -- data the same way. Not proven, but the loot window was ruled out
    -- first; names of quests never seen in a log stay numbers meanwhile.
    if not C_QuestLog.RequestLoadQuestByID and not DeckUIDB.questBookScan then
        wipe(queue)
        wipe(queued)
        return
    end
    local id = table.remove(queue)
    if not id then return end
    queued[id] = nil
    local t = KnownTitle(id)
    if t then
        Remember(id, t)
        return
    end
    if C_QuestLog.RequestLoadQuestByID then
        -- retail: the answer arrives as QUEST_DATA_LOAD_RESULT
        C_QuestLog.RequestLoadQuestByID(id)
        data.tries[id] = (data.tries[id] or 0) + 1
    else
        if not scanner then
            scanner = CreateFrame("GameTooltip", "DeckQuestBookScan", UIParent, "GameTooltipTemplate")
            scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
        end
        scanner:ClearLines()
        scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
        pcall(scanner.SetHyperlink, scanner, ("quest:%d"):format(id))
        pendingID = id
    end
end

-------------------------------------------------------------------
-- The window
-------------------------------------------------------------------
local win, rows, search, kindButton, statusButton, countText
local filterKind = "All"
local list, offset = {}, 0
local Refresh

-- Filters and sorting (owner's wish, 2026-10-27), kept for the session.
-- Status asks this character's list; "Done by others" is what another of
-- your characters did and this one has not.
local STATUSES = { "All", "Not done", "Done", "Done by others" }
local filterStatus = "All"
-- the columns, by what they sort on; a click on a heading sorts by it,
-- a second click turns the order round
local COLUMNS = {
    { key = "t", title = "Name",  x = 2,   w = 210 },
    { key = "l", title = "Level", x = 216, w = 32 },
    { key = "z", title = "Zone",  x = 252, w = 130 },
    { key = "k", title = "Kind",  x = 388, w = 90 },
    { key = "d", title = "Done",  x = 482, w = 54 },
}
local sortKey, sortDesc = "k", false

local function DoneElsewhere(id)
    for key, set in pairs(Data().done) do
        if key ~= CharKey() and set[id] then return true end
    end
    return false
end

local function Matches(q, id, text, me)
    if filterKind ~= "All" and q.k ~= filterKind then return false end
    if filterStatus == "Not done" and me[id] then return false end
    if filterStatus == "Done" and not me[id] then return false end
    if filterStatus == "Done by others" and (me[id] or not DoneElsewhere(id)) then return false end
    if text == "" then return true end
    local hay = ((q.t or "") .. " " .. (q.z or "") .. " " .. id):lower()
    return hay:find(text, 1, true) ~= nil
end

local function Kinds()
    local seen, kinds = {}, { "All" }
    for _, q in pairs(Data().quests) do
        if q.k and not seen[q.k] then seen[q.k] = true; kinds[#kinds + 1] = q.k end
    end
    table.sort(kinds, function(a, b)
        if a == "All" then return true elseif b == "All" then return false end
        return a < b
    end)
    return kinds
end

local function Build()
    local data = Data()
    local text = (search and search:GetText() or ""):lower()
    wipe(list)
    -- every quest learned, plus completed ones not learned yet (as numbers)
    local ids = {}
    for id in pairs(data.quests) do ids[id] = true end
    for _, set in pairs(data.done) do for id in pairs(set) do ids[id] = true end end
    local me = data.done[CharKey()] or {}
    for id in pairs(ids) do
        local q = data.quests[id] or { k = "Normal" }
        if Matches(q, id, text, me) then list[#list + 1] = id end
    end
    -- the value a quest sorts by; unknown ones last whatever the order
    local function Value(id)
        local q = data.quests[id] or {}
        if sortKey == "l" then return q.l or -1 end
        if sortKey == "d" then return me[id] and 2 or (DoneElsewhere(id) and 1 or 0) end
        if sortKey == "t" then return (q.t or "~" .. id):lower() end
        return (q[sortKey] or "~"):lower()
    end
    local values = {}
    for _, id in ipairs(list) do values[id] = Value(id) end
    table.sort(list, function(a, b)
        local va, vb = values[a], values[b]
        if va == vb then
            local qa, qb = data.quests[a] or {}, data.quests[b] or {}
            return (qa.t or "~" .. a) < (qb.t or "~" .. b)
        end
        if sortDesc then return va > vb end
        return va < vb
    end)
end

local function DoneBy(id)
    local names = {}
    for key, set in pairs(Data().done) do
        if set[id] then names[#names + 1] = key:match("^[^-]+") end
    end
    table.sort(names)
    return names
end

Refresh = function()
    if not win or not win:IsShown() then return end
    Build()
    local data, me = Data(), Data().done[CharKey()] or {}
    offset = math.max(0, math.min(offset, #list - ROWS))
    for i = 1, ROWS do
        local r, id = rows[i], list[offset + i]
        if id then
            local q = data.quests[id] or {}
            r.id = id
            r.title:SetText(q.t or ("|cff888888Quest " .. id .. "|r"))
            r.level:SetText(q.l and q.l > 0 and q.l or "")
            r.zone:SetText(q.z or "")
            r.kind:SetText(q.k or "")
            local others = #DoneBy(id)
            r.done:SetText(me[id] and "|cff33ff33done|r"
                or (others > 0 and ("|cff888888%d other%s|r"):format(others, others == 1 and "" or "s") or ""))
            r:Show()
        else
            r:Hide()
        end
    end
    local named = 0
    for _ in pairs(data.quests) do named = named + 1 end
    countText:SetText(("%d shown   %d known   %d names still loading"):format(#list, named, #queue))
    kindButton:SetText("Kind: " .. filterKind)
    statusButton:SetText("Show: " .. filterStatus)
    for _, col in ipairs(COLUMNS) do
        col.label:SetText(col.title .. (col.key == sortKey and (sortDesc and " v" or " ^") or ""))
    end
end

local function Text(parent, size, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(D.FONT, size, "OUTLINE")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    if width then fs:SetWidth(width) end
    return fs
end

local function MakeWindow()
    if win then return end
    win = CreateFrame("Frame", "DeckQuestBook", UIParent)
    win:SetSize(W, H)
    win.defaultPoint = { "CENTER", UIParent, "CENTER", 0, 40 }
    win:SetPoint(unpack(win.defaultPoint))
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:Hide()
    tinsert(UISpecialFrames, "DeckQuestBook")
    D.FlatBox(win, 0.95)
    D.MakeMovable(win, "Quest book", DeckUIDB)
    D.MakeDraggable(win)

    local title = Text(win, 15)
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetTextColor(1, 0.82, 0)
    title:SetText("Quest book")
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    search = CreateFrame("EditBox", "DeckQuestBookSearch", win, "InputBoxTemplate")
    search:SetSize(190, 20)
    search:SetPoint("TOPLEFT", 18, -36)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function() offset = 0; Refresh() end)
    search:SetScript("OnEscapePressed", search.ClearFocus)

    kindButton = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    kindButton:SetSize(150, 22)
    kindButton:SetPoint("LEFT", search, "RIGHT", 12, 0)
    D.FlattenButton(kindButton)
    kindButton:SetScript("OnClick", function()
        local kinds = Kinds()
        local nextKind = kinds[1]
        for i, k in ipairs(kinds) do
            if k == filterKind then nextKind = kinds[i % #kinds + 1] end
        end
        filterKind = nextKind
        offset = 0
        Refresh()
    end)

    statusButton = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    statusButton:SetSize(160, 22)
    statusButton:SetPoint("LEFT", kindButton, "RIGHT", 8, 0)
    D.FlattenButton(statusButton)
    statusButton:SetScript("OnClick", function()
        for i, st in ipairs(STATUSES) do
            if st == filterStatus then filterStatus = STATUSES[i % #STATUSES + 1] break end
        end
        offset = 0
        Refresh()
    end)

    -- the headings, each sorting by its column
    for _, col in ipairs(COLUMNS) do
        local h = CreateFrame("Button", nil, win)
        h:SetSize(col.w, 16)
        h:SetPoint("TOPLEFT", 12 + col.x, -62)
        col.label = Text(h, 11, col.w)
        col.label:SetPoint("LEFT")
        col.label:SetTextColor(1, 0.82, 0)
        if col.key == "d" then col.label:SetJustifyH("RIGHT") end
        h:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
        h:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
        h:SetScript("OnClick", function()
            if sortKey == col.key then sortDesc = not sortDesc else sortKey, sortDesc = col.key, false end
            offset = 0
            Refresh()
        end)
    end

    countText = Text(win, 10, W - 24)
    countText:SetPoint("BOTTOMLEFT", 12, 8)
    countText:SetTextColor(0.6, 0.6, 0.6)

    rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, win)
        r:SetSize(W - 24, ROW)
        r:SetPoint("TOPLEFT", 12, -82 - (i - 1) * ROW)
        r:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
        r:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
        r.title = Text(r, 12, COLUMNS[1].w)
        r.title:SetPoint("LEFT", COLUMNS[1].x, 0)
        r.level = Text(r, 11, COLUMNS[2].w)
        r.level:SetPoint("LEFT", COLUMNS[2].x, 0)
        r.level:SetTextColor(0.8, 0.8, 0.8)
        r.zone = Text(r, 11, COLUMNS[3].w)
        r.zone:SetPoint("LEFT", COLUMNS[3].x, 0)
        r.zone:SetTextColor(0.7, 0.7, 0.7)
        r.kind = Text(r, 11, COLUMNS[4].w)
        r.kind:SetPoint("LEFT", COLUMNS[4].x, 0)
        r.kind:SetTextColor(0.8, 0.75, 0.55)
        r.done = Text(r, 11, 60)
        r.done:SetPoint("RIGHT", -2, 0)
        r.done:SetJustifyH("RIGHT")
        r:SetScript("OnEnter", function(self)
            local q = Data().quests[self.id] or {}
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(q.t or ("Quest " .. self.id))
            GameTooltip:AddLine(("Quest %d%s"):format(self.id, q.l and ("   level %d"):format(q.l) or ""), 0.7, 0.7, 0.7)
            if q.z then GameTooltip:AddLine(q.z, 0.7, 0.7, 0.7) end
            local names = DoneBy(self.id)
            GameTooltip:AddLine(#names > 0 and ("Done by: " .. table.concat(names, ", ")) or "Done by none of your characters",
                1, 1, 1, true)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", GameTooltip_Hide)
        rows[i] = r
    end
    win:EnableMouseWheel(true)
    win:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - delta * 3
        Refresh()
    end)
    win:SetScript("OnShow", function()
        LearnLog()
        Refresh()
    end)
end

function D.ToggleQuestBook()
    if not Enabled() then
        print("DeckUI: switch on the quest book on the Overview page first.")
        return
    end
    MakeWindow()
    win:SetShown(not win:IsShown())
end

function D.ApplyQuestBook()
    if not Enabled() then
        if win then win:Hide() end
        return
    end
    LearnLog()
    LearnDone()
    Fill()
end

-------------------------------------------------------------------
-- Events and the loader
-------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE",
    "QUEST_DATA_LOAD_RESULT" }) do pcall(ev.RegisterEvent, ev, e) end
local logPending = false
ev:SetScript("OnEvent", function(_, event, a)
    if event == "PLAYER_LOGIN" then
        -- a little later: the completed list is not ready at the very start
        C_Timer.After(5, D.ApplyQuestBook)
        C_Timer.NewTicker(RATE, Step)
        return
    end
    if not Enabled() then return end
    if event == "QUEST_TURNED_IN" then
        local mine = Data().done[CharKey()] or {}
        mine[a] = true
        Data().done[CharKey()] = mine
    elseif event == "QUEST_DATA_LOAD_RESULT" then
        local t = KnownTitle(a)
        if t then Remember(a, t) end
        return
    end
    -- the log changes often: learn it once a moment later
    if not logPending then
        logPending = true
        C_Timer.After(1, function()
            logPending = false
            LearnLog()
            if win and win:IsShown() then Refresh() end
        end)
    end
end)

SLASH_DECKQUESTBOOK1 = "/questbook"
SlashCmdList.DECKQUESTBOOK = function() D.ToggleQuestBook() end

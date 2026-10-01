local ADDON = ...
local D = DeckUI

-------------------------------------------------------------------
-- Error collector: /deck errors
-------------------------------------------------------------------
-- Asked for by the owner (2026-10-01) after a flood of more than thirty
-- Lua errors: one window with every error of this and the last session,
-- each once with its count, stack and locals, as text that can be copied
-- in one go (Ctrl+A, Ctrl+C) and pasted into a report.
--
-- It sits in front of the game's own error handler and hands every error
-- on to it, so Blizzard's error window (scriptErrors) works as before.
-- ADDON_ACTION_BLOCKED / FORBIDDEN are collected too: they are the taint
-- reports, the ones that name the addon.
--
-- Kept in DeckUIDB.errors so they survive a /reload, at most MAX, newest
-- first. Nothing here may raise an error itself - an error inside the
-- error handler would loop - so the collecting runs under pcall.
-------------------------------------------------------------------
local MAX = 50
local MAX_LOCALS = 1500
local pending = {}    -- errors from before DeckUIDB exists
local announced = false

local function Store()
    return DeckUIDB and DeckUIDB.errors or pending
end

local function Add(message, stack, locals)
    local list = Store()
    for i, e in ipairs(list) do
        if e.message == message then
            e.count = e.count + 1
            e.time = date("%H:%M:%S")
            e.session = D.errorSession
            table.remove(list, i)
            table.insert(list, 1, e)
            return
        end
    end
    table.insert(list, 1, {
        message = message,
        stack = stack,
        locals = locals,
        count = 1,
        time = date("%H:%M:%S"),
        session = D.errorSession,
    })
    while #list > MAX do table.remove(list) end

    if not announced then
        announced = true
        C_Timer.After(0, function()
            print("|cffff5555DeckUI: a Lua error was caught - /deck errors shows all of them to copy.|r")
        end)
    end
    if D.errorWindow and D.errorWindow:IsShown() then D.errorWindow.Refresh() end
end

local previous = geterrorhandler()
seterrorhandler(function(message, ...)
    pcall(function()
        local locals = debuglocals and debuglocals(4) or ""
        if #locals > MAX_LOCALS then locals = locals:sub(1, MAX_LOCALS) .. "\n  ..." end
        Add(tostring(message), debugstack(4) or "", locals)
    end)
    if previous then return previous(message, ...) end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("ADDON_ACTION_BLOCKED")
events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
events:SetScript("OnEvent", function(self, event, addon, func)
    if event == "ADDON_LOADED" then
        if addon ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        DeckUIDB = DeckUIDB or {}
        DeckUIDB.errors = DeckUIDB.errors or {}
        DeckUIDB.errorSession = (DeckUIDB.errorSession or 0) + 1
        D.errorSession = DeckUIDB.errorSession
        -- only this session and the one before
        for i = #DeckUIDB.errors, 1, -1 do
            if (DeckUIDB.errors[i].session or 0) < D.errorSession - 1 then
                table.remove(DeckUIDB.errors, i)
            end
        end
        for i = #pending, 1, -1 do
            pending[i].session = D.errorSession
            local e = pending[i]
            Add(e.message, e.stack, e.locals)
        end
        wipe(pending)
        return
    end
    pcall(Add, ("%s: %s tried to call %s"):format(event, tostring(addon), tostring(func)),
        debugstack(2) or "", "")
end)

-------------------------------------------------------------------
-- The window
-------------------------------------------------------------------
local function BuildText()
    local list = Store()
    if #list == 0 then return "No errors caught." end
    local version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
    local build, _, _, interface = GetBuildInfo()
    local lines = {
        ("DeckUI %s, client %s (%s), %s, %d error(s)"):format(version, build, interface,
            D.IsDeck and (D.IsDeck() and "deck" or "pc") or "?", #list),
        "",
    }
    for i, e in ipairs(list) do
        local when = e.session == D.errorSession and "this session" or "last session"
        lines[#lines + 1] = ("#%d  %dx, last at %s (%s)"):format(i, e.count, e.time or "?", when)
        lines[#lines + 1] = e.message
        if e.stack and e.stack ~= "" then lines[#lines + 1] = "Stack:\n" .. e.stack end
        if e.locals and e.locals ~= "" then lines[#lines + 1] = "Locals:\n" .. e.locals end
        lines[#lines + 1] = "----------------------------------------"
    end
    return table.concat(lines, "\n")
end

local function CreateWindow()
    local w = CreateFrame("Frame", "DeckUIErrorWindow", UIParent, "BackdropTemplate")
    w:SetSize(640, 460)
    w:SetPoint("CENTER")
    w:SetFrameStrata("DIALOG")
    w:SetToplevel(true)
    w:EnableMouse(true)
    w:SetMovable(true)
    w:SetClampedToScreen(true)
    w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", w.StartMoving)
    w:SetScript("OnDragStop", w.StopMovingOrSizing)
    w:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    w:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    tinsert(UISpecialFrames, "DeckUIErrorWindow")

    local title = w:CreateFontString(nil, "OVERLAY")
    title:SetFont(D.FONT, 15, "OUTLINE")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("DeckUI errors")

    local hint = w:CreateFontString(nil, "OVERLAY")
    hint:SetFont(D.FONT, 11, "OUTLINE")
    hint:SetPoint("LEFT", title, "RIGHT", 12, 0)
    hint:SetTextColor(0.7, 0.7, 0.7)
    hint:SetText("click the text, Ctrl+A, Ctrl+C")

    local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local scroll = CreateFrame("ScrollFrame", "DeckUIErrorScroll", w, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -38)
    scroll:SetPoint("BOTTOMRIGHT", -32, 44)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFont(D.FONT, 11, "")
    edit:SetWidth(590)
    edit:SetScript("OnEscapePressed", function() w:Hide() end)
    -- read only: whatever is typed, the text comes back
    edit:SetScript("OnTextChanged", function(self, user)
        if user then self:SetText(w.text or "") end
    end)
    scroll:SetScrollChild(edit)

    local clear = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
    clear:SetSize(100, 24)
    clear:SetPoint("BOTTOMLEFT", 12, 12)
    clear:SetText("Clear")
    clear:SetScript("OnClick", function()
        wipe(Store())
        announced = false
        w.Refresh()
    end)

    local selectAll = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
    selectAll:SetSize(100, 24)
    selectAll:SetPoint("LEFT", clear, "RIGHT", 8, 0)
    selectAll:SetText("Select all")
    selectAll:SetScript("OnClick", function()
        edit:SetFocus()
        edit:HighlightText()
    end)

    function w.Refresh()
        w.text = BuildText()
        edit:SetText(w.text)
        edit:SetCursorPosition(0)
        scroll:SetVerticalScroll(0)
    end

    w:SetScript("OnShow", w.Refresh)
    w:Hide()
    return w
end

function D.ErrorCount()
    return #Store()
end

function D.ShowErrors()
    D.errorWindow = D.errorWindow or CreateWindow()
    if D.errorWindow:IsShown() then
        D.errorWindow:Hide()
    else
        D.errorWindow:Show()
    end
end

local D = DeckUI

-- Each container keeps a list of its widgets so they can be refreshed when shown
local function Register(parent, widget)
    parent.widgets = parent.widgets or {}
    table.insert(parent.widgets, widget)
end

function D.RefreshWidgets(parent)
    if not parent.widgets then return end
    for _, w in ipairs(parent.widgets) do
        if w.Refresh then w:Refresh() end
    end
end

-------------------------------------------------------------------
-- Heading
-------------------------------------------------------------------
function D.Label(parent, text, y, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(D.FONT, size or 14, "OUTLINE")
    fs:SetPoint("TOP", 0, y)
    fs:SetText(text)
    return fs
end

-------------------------------------------------------------------
-- Hint: the small grey line under a control
-------------------------------------------------------------------
-- Width-limited on purpose. Without it a long line runs straight out of the
-- panel and loses its last characters - "disabling after /reload" was cut
-- off mid-word. Let the font string wrap; never hand-place newlines, they
-- fight the wrapping and leave single words stranded on their own line.
function D.Hint(parent, text, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(D.FONT, 11, "OUTLINE")
    fs:SetPoint("TOP", 0, y)
    fs:SetWidth(width or 290)
    fs:SetJustifyH("CENTER")
    fs:SetTextColor(0.7, 0.7, 0.7)
    fs:SetText(text)
    return fs
end

-------------------------------------------------------------------
-- DeckUI's flat look: a dark fill and four one-pixel lines, anchored only
-------------------------------------------------------------------
-- The same box the week window, the raid tiles and the bags wear. Never
-- BackdropTemplate on anything a tooltip could size (see the Tooltip
-- notes); plain textures are safe everywhere.
function D.FlatBox(frame, alpha, edge)
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, alpha or 0.95)
    local c = edge or 0.3
    local lines = {}
    for _, p in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                         { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(c, c, c, 1)
        t:SetPoint(p[1])
        t:SetPoint(p[2])
        if p[3] then t:SetHeight(1) else t:SetWidth(1) end
        lines[#lines + 1] = t
    end
    return bg, lines
end

-- A Blizzard panel button in the flat look: its three-piece red art at
-- alpha 0 (textures only, the template's scripts stay), our box instead,
-- a lighter fill under the mouse.
function D.FlattenButton(b)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        if b[key] then b[key]:SetAlpha(0) end
    end
    for _, tex in ipairs({ b:GetNormalTexture(), b:GetPushedTexture(), b:GetDisabledTexture() }) do
        tex:SetAlpha(0)
    end
    local hl = b:GetHighlightTexture()
    if hl then
        hl:SetTexture("Interface\\Buttons\\WHITE8x8")
        hl:SetVertexColor(1, 1, 1, 0.08)
        hl:ClearAllPoints()
        hl:SetPoint("TOPLEFT", 1, -1)
        hl:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    local bg = D.FlatBox(b, 1, 0.35)
    bg:SetColorTexture(0.12, 0.12, 0.12, 1)
    return b
end

-------------------------------------------------------------------
-- Button
-------------------------------------------------------------------
function D.Button(parent, text, y, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(260, 34)
    b:SetPoint("TOP", 0, y)
    b:SetText(text)
    b:GetFontString():SetFont(D.FONT, 15, "OUTLINE")
    b:SetScript("OnClick", onClick)
    D.FlattenButton(b)
    return b
end

-------------------------------------------------------------------
-- Slider: text, y, min, max, step, format function,
--         db = function returning the table, key = field in it, apply = function(value)
-------------------------------------------------------------------
local sliderCount = 0
function D.Slider(parent, text, y, minV, maxV, step, fmt, db, key, apply)
    sliderCount = sliderCount + 1
    local name = "DeckUISlider" .. sliderCount

    D.Label(parent, text, y, 14)

    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetPoint("TOP", 0, y - 22)
    s:SetWidth(240)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    _G[name .. "Low"]:SetText(fmt(minV))
    _G[name .. "High"]:SetText(fmt(maxV))
    -- OptionsSliderTemplate parks its value text right above the slider,
    -- which is exactly where our heading sits - the two printed on top of
    -- each other. It moves below the bar instead, into the gap between the
    -- min and max labels, which is empty. Appending it to the heading was
    -- the other option and was dropped: headings have no width limit, so
    -- "Buffs up to duration (needs /reload)   5 min" would have traded this
    -- bug for the one next door.
    s.valueText = _G[name .. "Text"]
    s.valueText:ClearAllPoints()
    s.valueText:SetPoint("TOP", s, "BOTTOM", 0, 3)

    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        self.valueText:SetText(fmt(v))
        if not self.loading then apply(v) end
    end)

    function s:Refresh()
        self.loading = true
        local v = db()[key] or minV
        self:SetValue(v)
        -- SetValue stays quiet when the value did not actually change, so
        -- the text is written here rather than left blank.
        self.valueText:SetText(fmt(v))
        self.loading = false
    end

    Register(parent, s)
    return s
end

-------------------------------------------------------------------
-- Checkbox: text, y, db = function returning the table, key, apply
-------------------------------------------------------------------
function D.Checkbox(parent, text, y, db, key, apply)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(28, 28)
    cb:SetPoint("TOPLEFT", 20, y)

    local t = cb:CreateFontString(nil, "OVERLAY")
    t:SetFont(D.FONT, 14, "OUTLINE")
    t:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    -- The box starts 20 in from a 320-wide content area and is 28 across, so
    -- this is what is left. Without the limit a long label ran off the right
    -- edge instead of wrapping onto a second line.
    t:SetWidth(258)
    t:SetJustifyH("LEFT")
    t:SetText(text)

    cb:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        db()[key] = v
        apply(v)
    end)

    function cb:Refresh()
        self:SetChecked(db()[key])
    end

    Register(parent, cb)
    return cb
end

-------------------------------------------------------------------
-- Dialog: a question with two buttons, optionally a money input
-------------------------------------------------------------------
-- Never StaticPopup_Show from addon code: StaticPopup1..4 are shared by the
-- whole game, a dialog shown from our code keeps fields written while
-- tainted, and the next Blizzard dialog on the same frame - some of which
-- call protected functions on accept - runs tainted too. One window of our
-- own instead, one question at a time; a new question replaces the old.
--
-- opts: text, onAccept(copper), accept / cancel (button texts), width,
--       money = true for a gold/silver/copper input (Blizzard's
--       MoneyInputFrameTemplate - an instance of our own, so it is ours),
--       key = anything, so a caller can tell whether its question is up.
local dialog

local function BuildDialog()
    local f = CreateFrame("Frame", "DeckUIDialog", UIParent, "BackdropTemplate")
    f:SetPoint("TOP", 0, -160)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    f:Hide()
    tinsert(UISpecialFrames, "DeckUIDialog")

    f.text = D.Hint(f, "", -14)
    f.text:SetTextColor(1, 1, 1)

    f.money = CreateFrame("Frame", "DeckUIDialogMoney", f, "MoneyInputFrameTemplate")
    f.money:Hide()

    f.accept = D.Button(f, ACCEPT or "Accept", 0, function()
        local opts = f.opts
        local copper = opts.money and MoneyInputFrame_GetCopper(f.money) or nil
        f:Hide()
        if opts.onAccept then opts.onAccept(copper) end
    end)
    f.cancel = D.Button(f, CANCEL or "Cancel", 0, function() f:Hide() end)
    for _, b in ipairs({ f.accept, f.cancel }) do
        b:SetSize(130, 26)
        b:GetFontString():SetFont(D.FONT, 13, "OUTLINE")
        b:ClearAllPoints()
    end
    f.accept:SetPoint("BOTTOMLEFT", 16, 14)
    f.cancel:SetPoint("BOTTOMRIGHT", -16, 14)

    f:SetScript("OnHide", function(self)
        MoneyInputFrame_ResetMoney(self.money)
        MoneyInputFrame_ClearFocus(self.money)
        self.opts = nil
    end)
    return f
end

function D.Dialog(opts)
    dialog = dialog or BuildDialog()
    dialog:Hide()
    dialog.opts = opts
    local width = opts.width or 320
    dialog:SetWidth(width)
    dialog.text:SetWidth(width - 30)
    dialog.text:SetText(opts.text or "")
    dialog.accept:SetText(opts.accept or ACCEPT or "Accept")
    dialog.cancel:SetText(opts.cancel or CANCEL or "Cancel")

    local height = 14 + dialog.text:GetStringHeight() + 12
    dialog.money:SetShown(opts.money and true or false)
    if opts.money then
        dialog.money:ClearAllPoints()
        dialog.money:SetPoint("TOP", dialog.text, "BOTTOM", 10, -12)
        height = height + 34
    end
    dialog:SetHeight(height + 54)
    dialog:Show()
    if opts.money then dialog.money.gold:SetFocus() end
end

-- the question with this key, if it is the one on screen
function D.DialogShown(key)
    return dialog and dialog:IsShown() and dialog.opts and dialog.opts.key == key
end

function D.HideDialog(key)
    if dialog and (key == nil or D.DialogShown(key)) then dialog:Hide() end
end

-------------------------------------------------------------------
-- Flow: the widgets above, stacked without pixel numbers
-------------------------------------------------------------------
-- A settings page used to place every widget at a hand-counted y, and every
-- new option moved everything below it. D.Flow keeps the cursor instead:
--   local f = D.Flow(content)
--   f:Label("Raid frames"); f:Checkbox("Show", db, "showRaid", apply)
--   f:Slider("Size", 0.5, 1.4, 0.05, pct, db, "scale", apply); f:Hint("...")
-- Each call returns the widget, like the plain functions. The page scrolls
-- (panel.lua), so a long page is no longer a problem.
local Flow = {}
Flow.__index = Flow

-- the explanation a page used to print under a widget, on mouse-over instead
function D.Tip(frame, title, text)
    if not text then return end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.82, 0)
        GameTooltip:AddLine(text, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", GameTooltip_Hide)
end

function D.Flow(parent, y)
    return setmetatable({ parent = parent, y = y or -6 }, Flow)
end

function Flow:Gap(n) self.y = self.y - (n or 10) end

function Flow:Label(text, size)
    local fs = D.Label(self.parent, text, self.y, size or 15)
    self.y = self.y - 24
    return fs
end

-- tip: optional mouse-over explanation (D.Tip)
function Flow:Checkbox(text, db, key, apply, tip)
    local cb = D.Checkbox(self.parent, text, self.y, db, key, apply or function() end)
    D.Tip(cb, text, tip)
    self.y = self.y - 28
    return cb
end

function Flow:Slider(text, minV, maxV, step, fmt, db, key, apply, tip)
    local s = D.Slider(self.parent, text, self.y, minV, maxV, step, fmt, db, key, apply)
    D.Tip(s, text, tip)
    self.y = self.y - 64
    return s
end

function Flow:Button(text, onClick, tip)
    local b = D.Button(self.parent, text, self.y, onClick)
    D.Tip(b, text, tip)
    self.y = self.y - 40
    return b
end

-- two buttons side by side, each half the page wide; left and right are
-- { text = , onClick = , tip = }. Returns both buttons.
function Flow:Pair(left, right)
    local width = math.floor((self.parent:GetWidth() - 24) / 2)
    local function Make(def, point, x)
        local b = D.Button(self.parent, def.text, self.y, def.onClick)
        b:SetSize(width, 28)
        b:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
        b:ClearAllPoints()
        b:SetPoint(point, self.parent, point, x, self.y)
        D.Tip(b, def.title or def.text, def.tip)
        return b
    end
    local a = Make(left, "TOPLEFT", 8)
    local b = right and Make(right, "TOPRIGHT", -8)
    self.y = self.y - 34
    return a, b
end

-- anything else: build(parent, y) places it, height is what it takes
function Flow:Add(height, build)
    local result = build(self.parent, self.y)
    self.y = self.y - height
    return result
end

function Flow:Hint(text)
    local fs = D.Hint(self.parent, text, self.y)
    self.y = self.y - fs:GetStringHeight() - 10
    return fs
end

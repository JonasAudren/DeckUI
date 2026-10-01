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
-- Button
-------------------------------------------------------------------
function D.Button(parent, text, y, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(260, 34)
    b:SetPoint("TOP", 0, y)
    b:SetText(text)
    b:GetFontString():SetFont(D.FONT, 15, "OUTLINE")
    b:SetScript("OnClick", onClick)
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

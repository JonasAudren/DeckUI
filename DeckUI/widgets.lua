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

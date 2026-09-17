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
    s.valueText = _G[name .. "Text"]

    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        self.valueText:SetText(fmt(v))
        if not self.loading then apply(v) end
    end)

    function s:Refresh()
        self.loading = true
        self:SetValue(db()[key] or minV)
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

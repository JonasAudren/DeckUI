local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Spec bar: one round button per specialization, active spec has a
-- gold ring. Originally the stand-alone "QuickSpec" addon.
-------------------------------------------------------------------
local SIZE, GAP = 36, 6

local bar = CreateFrame("Frame", "DeckSpecBar", UIParent)
bar:SetSize(SIZE, SIZE)
bar.defaultPoint = { "CENTER", UIParent, "CENTER", 0, -200 }
bar:SetPoint(unpack(bar.defaultPoint))
ns.bar = bar

ns.buttons = {}

local function MakeButton(i, name, icon)
    local b = CreateFrame("Button", "DeckSpecButton" .. i, bar)
    b:SetSize(SIZE, SIZE)
    b:SetPoint("LEFT", (i - 1) * (SIZE + GAP), 0)

    local mask = b:CreateMaskTexture()
    mask:SetTexture(D.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(b)

    local ring = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    ring:SetSize(SIZE + 6, SIZE + 6)
    ring:SetPoint("CENTER")
    ring:SetTexture(D.DISC)
    ring:SetVertexColor(0.25, 0.25, 0.25, 1)
    b.ring = ring

    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(icon)
    tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    tex:AddMaskTexture(mask)
    b.icon = tex

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\WHITE8x8")
    hl:SetVertexColor(1, 1, 1, 0.2)
    hl:SetBlendMode("ADD")
    hl:AddMaskTexture(mask)

    b.specIndex = i
    b.specName  = name

    b:SetScript("OnClick", function(self)
        if InCombatLockdown() then
            print("DeckUI Spec: not possible in combat.")
            return
        end
        if GetSpecialization() ~= self.specIndex then
            C_SpecializationInfo.SetSpecialization(self.specIndex)
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.specName)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

function ns.UpdateActive()
    local active = GetSpecialization()
    for i, b in ipairs(ns.buttons) do
        if i == active then
            b.ring:SetVertexColor(0.9, 0.75, 0.2, 1)
            b.icon:SetDesaturated(false)
        else
            b.ring:SetVertexColor(0.25, 0.25, 0.25, 1)
            b.icon:SetDesaturated(true)
        end
    end
end

local function Build()
    local n = GetNumSpecializations()
    bar:SetSize(n * SIZE + (n - 1) * GAP, SIZE)
    for i = 1, n do
        if not ns.buttons[i] then
            local _, name, _, icon = GetSpecializationInfo(i)
            ns.buttons[i] = MakeButton(i, name, icon)
        end
    end
    ns.UpdateActive()
end

function ns.SetBarShown(state)
    DeckSpecDB.showBar = state
    bar:SetShown(state)
end

-------------------------------------------------------------------
-- Startup (normal login AND load on demand via the menu)
-------------------------------------------------------------------
local function Init()
    DeckSpecDB = DeckSpecDB or {}
    if DeckSpecDB.showBar == nil then DeckSpecDB.showBar = true end
    Build()
    D.MakeMovable(bar, "Spec bar", DeckSpecDB)
    bar:SetShown(DeckSpecDB.showBar)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
ev:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        Init()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if unit == nil or unit == "player" then ns.UpdateActive() end
    else
        ns.UpdateActive()
    end
end)

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
    ev:RegisterEvent("PLAYER_LOGIN")
end

-- /spec toggles the bar (like the old /qs did); /spec config opens the tab
SLASH_DECKSPEC1 = "/spec"
SLASH_DECKSPEC2 = "/qs"
SlashCmdList.DECKSPEC = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "config" then
        D.ToggleConfig("Spec")
    else
        ns.SetBarShown(not bar:IsShown())
    end
end

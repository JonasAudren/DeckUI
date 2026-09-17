local ADDON, ns = ...
local D = DeckUI

ns.MASK = D.MASK
ns.DISC = D.DISC
ns.FONT = D.FONT

ns.GLOW  = 0
ns.glows = {}

local function AddGlow(bar, mask)
    local glow = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    glow:SetAllPoints(bar:GetStatusBarTexture())
    glow:SetColorTexture(1, 1, 1, ns.GLOW)
    glow:SetBlendMode("ADD")
    glow:AddMaskTexture(mask)
    table.insert(ns.glows, glow)
    return glow
end

function ns.SetGlow(value)
    ns.GLOW = value
    for _, glow in ipairs(ns.glows) do
        glow:SetColorTexture(1, 1, 1, value)
    end
end

function ns.CreateOrb(parent, size)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(size, size)
    bar:SetPoint("CENTER")
    bar:SetFrameLevel(parent:GetFrameLevel() + 2)
    bar:SetOrientation("VERTICAL")
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")

    local mask = bar:CreateMaskTexture()
    mask:SetTexture(ns.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(bar)
    bar:GetStatusBarTexture():AddMaskTexture(mask)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.08, 1)
    bg:AddMaskTexture(mask)

    AddGlow(bar, mask)
    return bar
end

function ns.CreateRing(parent, size)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(size, size)
    bar:SetPoint("CENTER")
    bar:SetFrameLevel(parent:GetFrameLevel() + 1)
    bar:SetOrientation("VERTICAL")
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")

    local mask = bar:CreateMaskTexture()
    mask:SetTexture(ns.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(bar)
    bar:GetStatusBarTexture():AddMaskTexture(mask)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    bg:AddMaskTexture(mask)

    AddGlow(bar, mask)
    return bar
end

function ns.CreateCastOverlay(orb, size)
    local bar = CreateFrame("StatusBar", nil, orb)
    bar:SetSize(size, size)
    bar:SetPoint("CENTER", orb, "CENTER")
    bar:SetFrameLevel(orb:GetFrameLevel() + 1)
    bar:SetOrientation("HORIZONTAL")
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(1, 0.85, 0.3, 0.55)

    local mask = bar:CreateMaskTexture()
    mask:SetTexture(ns.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(bar)
    bar:GetStatusBarTexture():AddMaskTexture(mask)

    return bar
end

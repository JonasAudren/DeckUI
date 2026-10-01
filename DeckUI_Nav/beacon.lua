local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- The beacon in the world: name, distance, arrival time
-------------------------------------------------------------------
-- The owner's choice (2026-10-01): our own instead of Blizzard's diamond.
-- Built from Blizzard's 12.1.0 SuperTrackedFrame.lua. The engine keeps a
-- point projected onto the target in the 3D world (C_Navigation.GetFrame);
-- Blizzard's frame - and now ours - is anchored to it. When the target is
-- off screen the engine reports it clamped, and the beacon then sits on
-- an ellipse around the screen centre with an arrow pointing out, as
-- Blizzard's does (same radii, same arithmetic on frame centres - those
-- are plain numbers).
--
-- Blizzard's frame is parked under a hidden frame (SetParent only, no
-- field written), so its OnUpdate stops and it draws nothing - but its
-- events still arrive, so it keeps clearing a waypoint on arrival the way
-- it always did. Switched off, it goes back to UIParent.
-------------------------------------------------------------------
local MAJOR, MINOR = 500, 200          -- Blizzard's ellipse radii
local ICON = 28

local ICONS = {
    [Enum.SuperTrackingType.Quest]        = "Navigation-Tracked-Icon",
    [Enum.SuperTrackingType.UserWaypoint] = "Waypoint-MapPin-Tracked",
    [Enum.SuperTrackingType.Content]      = "Waypoint-MapPin-Tracked",
    [Enum.SuperTrackingType.Corpse]       = "Navigation-Tombstone-Icon",
}

-- how visible, by what the engine says about the target (Blizzard's table)
local STATE_ALPHA = {
    [Enum.NavigationState.Invalid]  = 0,
    [Enum.NavigationState.Occluded] = 0.6,
    [Enum.NavigationState.InRange]  = 1,
    [Enum.NavigationState.Disabled] = 0,
}

local beacon = CreateFrame("Frame", "DeckNavBeacon", UIParent)
beacon:SetSize(ICON, ICON)
beacon:SetFrameStrata("BACKGROUND")
beacon:SetAlpha(0)
beacon:Hide()

-- The marker in DeckUI's look: a small orb - a gold ring around a dark
-- disc, both cut round with D.RoundMask like the orbs and cross buttons -
-- and the target type's symbol inside, flattened to gold.
local GOLD = { 1, 0.82, 0 }
local RING = 3

local icon = CreateFrame("Frame", nil, beacon)
icon:SetPoint("CENTER")
icon:SetSize(ICON, ICON)

local ring = icon:CreateTexture(nil, "BACKGROUND")
ring:SetAllPoints()
ring:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
ring:AddMaskTexture(D.RoundMask(icon))

local inner = CreateFrame("Frame", nil, icon)
inner:SetPoint("CENTER")
inner:SetSize(ICON - 2 * RING, ICON - 2 * RING)
local disc = inner:CreateTexture(nil, "BACKGROUND")
disc:SetAllPoints()
disc:SetColorTexture(0.05, 0.05, 0.05, 0.9)
disc:AddMaskTexture(D.RoundMask(inner))

local glyph = inner:CreateTexture(nil, "ARTWORK")
glyph:SetPoint("CENTER")

local arrow = beacon:CreateTexture(nil, "ARTWORK")
arrow:SetAtlas("Navigation-Tracked-Arrow", true)
arrow:SetDesaturated(true)
arrow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
arrow:Hide()

local nameText = beacon:CreateFontString(nil, "OVERLAY")
nameText:SetFont(D.FONT, 13, "OUTLINE")
nameText:SetPoint("BOTTOM", icon, "TOP", 0, 4)
nameText:SetTextColor(1, 0.82, 0)
nameText:SetWordWrap(false)

local infoText = beacon:CreateFontString(nil, "OVERLAY")
infoText:SetFont(D.FONT, 12, "OUTLINE")
infoText:SetPoint("TOP", icon, "BOTTOM", 0, -4)
infoText:SetTextColor(1, 1, 1)

-------------------------------------------------------------------
-- Following the engine's point
-------------------------------------------------------------------
local navFrame, wasClamped

local function ScreenCenter()
    local x, y = WorldFrame:GetCenter()
    local scale = UIParent:GetEffectiveScale() or 1
    return x / scale, y / scale
end

local function Place(clamped)
    beacon:ClearAllPoints()
    if not clamped then
        beacon:SetPoint("CENTER", navFrame, "CENTER")
        arrow:Hide()
        return
    end
    local cx, cy = ScreenCenter()
    local nx, ny = navFrame:GetCenter()
    if not (nx and ny) then return end
    local px, py = nx - cx, ny - cy
    local denominator = math.sqrt(MAJOR * MAJOR * py * py + MINOR * MINOR * px * px)
    if denominator == 0 then return end
    local ratio = MAJOR * MINOR / denominator
    local ix, iy = px * ratio, py * ratio
    beacon:SetPoint("CENTER", WorldFrame, "CENTER", ix, iy)
    -- the arrow points from the screen centre outwards, just past the icon
    local len = math.sqrt(ix * ix + iy * iy)
    if len > 0 then
        local ux, uy = ix / len, iy / len
        arrow:ClearAllPoints()
        arrow:SetPoint("CENTER", icon, "CENTER", ux * (ICON * 0.9), uy * (ICON * 0.9))
        arrow:SetRotation(math.atan2(uy, ux) - math.pi / 2)
        arrow:Show()
    end
end

local function TargetAlpha(clamped)
    if not C_Navigation.HasValidScreenPosition() then return 0 end
    local a = STATE_ALPHA[C_Navigation.GetTargetState()] or 0
    if a > 0 and clamped then return 1 end
    return a
end

local function UpdateTexts()
    local state = ns.navState
    nameText:SetText(ns.TargetName() or "")
    local parts = {}
    if state and state.distance then
        parts[#parts + 1] = ns.DistanceString(state.distance)
        if state.eta then parts[#parts + 1] = state.eta end
    end
    infoText:SetText(table.concat(parts, "  \194\183  "))
end

local function UpdateIcon()
    local kind = C_SuperTrack.GetHighestPrioritySuperTrackingType()
    glyph:SetAtlas(kind and ICONS[kind] or "Navigation-Tracked-Icon")
    glyph:SetSize(ICON * 0.55, ICON * 0.55)
    glyph:SetDesaturated(true)
    glyph:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
end

local acc = 0
beacon:SetScript("OnUpdate", function(self, elapsed)
    navFrame = navFrame or C_Navigation.GetFrame()
    if not navFrame then
        self:SetAlpha(0)
        return
    end
    local clamped = C_Navigation.WasClampedToScreen()
    if clamped ~= wasClamped or clamped then Place(clamped) end
    wasClamped = clamped
    -- ease towards the target alpha, like Blizzard's FrameDeltaLerp
    local target = TargetAlpha(clamped)
    local a = self:GetAlpha()
    self:SetAlpha(a + (target - a) * math.min(1, elapsed * 10))
    acc = acc + elapsed
    if acc >= 0.1 then
        acc = 0
        UpdateTexts()
    end
end)

-------------------------------------------------------------------
-- Blizzard's diamond: parked while ours is on
-------------------------------------------------------------------
local parked = CreateFrame("Frame")
parked:Hide()

function ns.ApplyBeacon()
    local on = DeckNavDB.beacon
    if SuperTrackedFrame then
        SuperTrackedFrame:SetParent(on and parked or UIParent)
    end
    beacon:SetShown(on and C_SuperTrack.IsSuperTrackingAnything())
    if on then UpdateIcon() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("NAVIGATION_FRAME_CREATED")
ev:RegisterEvent("NAVIGATION_FRAME_DESTROYED")
ev:RegisterEvent("SUPER_TRACKING_CHANGED")
ev:SetScript("OnEvent", function(_, event)
    if not DeckNavDB then return end
    if event == "NAVIGATION_FRAME_CREATED" then
        navFrame, wasClamped = C_Navigation.GetFrame(), nil
    elseif event == "NAVIGATION_FRAME_DESTROYED" then
        navFrame = nil
        beacon:ClearAllPoints()
    else
        -- a new target: start invisible and fade in at its place
        beacon:SetAlpha(0)
        wasClamped = nil
    end
    ns.ApplyBeacon()
end)

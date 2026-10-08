local D = DeckUI

-------------------------------------------------------------------
-- The soft target's name: what the interact key will use
-------------------------------------------------------------------
-- Replaces Plumber's "Nameplate: Soft Target" (owner's wish, 2026-10-08 -
-- one of the three Plumber modules he had switched on himself). With the
-- interact key, the game shows an icon over the object it would use (a
-- chest, an ore vein, a herb); this adds the object's name below that
-- icon, gold when it is in reach and grey when not, and optionally a ring
-- that fills while you cast on it (DeckUIDB.softTargetName / softTargetCast).
--
-- Blizzard's nameplate is only read and anchored to. Plumber parents its
-- frame into the nameplate and resizes the nameplate's SoftTargetFrame;
-- ours is a frame of our own on UIParent with its points on the icon, and
-- nothing of the nameplate is changed (shared frames, secret values - see
-- the Tooltip notes in CLAUDE.md). The name goes into SetText as it is:
-- the engine draws a secret string, we never compare one.
--
-- Needs two game settings: the interact key (Options > Gameplay > Controls,
-- CVar SoftTargetInteract 2 or 3) and CVar SoftTargetIconGameObject 1 for
-- the icon on objects. Switching this on sets the second; /deck softtarget
-- prints both.
-------------------------------------------------------------------
local UNIT = "softinteract"
local GOLD, GREY = { 1, 0.82, 0 }, { 0.6, 0.6, 0.6 }

local frame = CreateFrame("Frame", "DeckSoftTargetName", UIParent)
frame:SetSize(10, 10)
frame:SetFrameStrata("LOW")
frame:Hide()

local name = frame:CreateFontString(nil, "OVERLAY")
name:SetFont(D.FONT, 14, "OUTLINE")
name:SetPoint("TOP", frame, "TOP", 0, 0)

-- a soft dark band behind the name, so it reads on a bright ground
local band = frame:CreateTexture(nil, "BACKGROUND")
band:SetColorTexture(0, 0, 0, 0.35)
band:SetPoint("TOPLEFT", name, "TOPLEFT", -8, 3)
band:SetPoint("BOTTOMRIGHT", name, "BOTTOMRIGHT", 8, -3)

-- reads the cursor icon the game would show, to tell "in reach" from not
local probe = frame:CreateTexture(nil, "ARTWORK")
probe:SetSize(1, 1)
probe:SetAlpha(0)

-- the cast ring around the icon
local ring = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
ring:SetSize(30, 30)
ring:SetSwipeTexture(D.DISC)
ring:SetUseCircularEdge(true)
ring:SetDrawEdge(false)
ring:SetSwipeColor(1, 0.82, 0, 0.55)
ring:SetReverse(true)
ring:SetHideCountdownNumbers(true)
ring:Hide()

local plate          -- the nameplate we hang on, while we do
local pending = false

local function Hide()
    frame:Hide()
    ring:Hide()
    plate = nil
end

local function Update()
    pending = false
    if not DeckUIDB.softTargetName then return Hide() end
    local nameplate = C_NamePlate.GetNamePlateForUnit(UNIT)
    local soft = nameplate and nameplate.UnitFrame and nameplate.UnitFrame.SoftTargetFrame
    -- game objects only: a creature has a name of its own on the plate
    if not (soft and soft:IsShown() and UnitIsGameObject(UNIT)) then return Hide() end
    local icon = soft.Icon or soft

    plate = nameplate
    frame:ClearAllPoints()
    frame:SetPoint("TOP", icon, "BOTTOM", 0, -4)
    ring:ClearAllPoints()
    ring:SetPoint("CENTER", icon, "CENTER")

    name:SetText(UnitName(UNIT))
    -- the game's cursor art for the object says "unable" when out of reach
    local hasIcon = SetUnitCursorTexture(probe, UNIT)
    local art = hasIcon and (probe:GetAtlas() or probe:GetTexture())
    local unable = not art or (type(art) == "string" and art:lower():find("unable") ~= nil)
    local c = unable and GREY or GOLD
    name:SetTextColor(c[1], c[2], c[3])
    frame:Show()
end

local function RequestUpdate()
    if pending then return end
    pending = true
    C_Timer.After(0.03, Update)   -- the nameplate settles a moment after the event
end

local function UpdateCast()
    if not (DeckUIDB.softTargetCast and frame:IsShown()) then
        ring:Hide()
        return
    end
    local duration = UnitCastingDuration and (UnitCastingDuration("player") or UnitChannelDuration("player"))
    if duration then
        -- a duration object: the engine fills the ring, nothing computed here
        ring:SetCooldownFromDurationObject(duration)
        ring:Show()
    else
        ring:Hide()
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
ev:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
ev:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
ev:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
ev:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
ev:SetScript("OnEvent", function(_, event, unit)
    if not DeckUIDB then return end
    if event == "PLAYER_SOFT_INTERACT_CHANGED" then
        RequestUpdate()
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- a recycled plate would carry our name to another unit
        if plate and C_NamePlate.GetNamePlateForUnit(unit) == plate then Hide() end
    else
        UpdateCast()
    end
end)

function D.SetSoftTargetName(on)
    DeckUIDB.softTargetName = on
    if on and not C_CVar.GetCVarBool("SoftTargetIconGameObject") then
        C_CVar.SetCVar("SoftTargetIconGameObject", "1")
        print("DeckUI: the game now shows the interact icon on objects (SoftTargetIconGameObject 1).")
    end
    Update()
end

-- /deck softtarget: the two game settings and what we see
function D.PrintSoftTarget()
    print(("DeckUI soft target: option=%s cast=%s, SoftTargetInteract=%s (needs 2 or 3), SoftTargetIconGameObject=%s"):format(
        tostring(DeckUIDB.softTargetName), tostring(DeckUIDB.softTargetCast),
        tostring(C_CVar.GetCVar("SoftTargetInteract")), tostring(C_CVar.GetCVar("SoftTargetIconGameObject"))))
    print(("  unit exists=%s, plate=%s, shown=%s"):format(tostring(UnitExists(UNIT)),
        tostring(C_NamePlate.GetNamePlateForUnit(UNIT) ~= nil), tostring(frame:IsShown())))
end

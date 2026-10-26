local D = DeckUI

-------------------------------------------------------------------
-- FFXIV's target arrow over the target's nameplate
-------------------------------------------------------------------
-- The owner's wish (2026-10-09, his FFXIV screenshot): an arrowhead
-- floating over the current target, bobbing gently - red for an enemy,
-- green for a friend. DeckUIDB.targetArrow, off by default, undone by
-- unticking.
--
-- Built like the interact target's name (softtarget.lua): a frame of ours
-- on UIParent, only anchored to Blizzard's nameplate for "target" - nothing
-- on the plate is changed. No plate, no arrow: the target is out of range,
-- nameplates are off for that kind of unit, or the game keeps the plate to
-- itself (C_NamePlate.GetNamePlateForUnit then answers nil). Whether the
-- target can be attacked may be a secret value; then the arrow stays gold.
-------------------------------------------------------------------
local TEXTURE = "Interface\\AddOns\\DeckUI\\textures\\target_arrow"
local SIZE = 26
local ENEMY = { 1, 0.3, 0.25 }
local FRIEND = { 0.35, 0.9, 0.45 }
local NEUTRAL = { 1, 0.82, 0.3 }

local arrow = CreateFrame("Frame", "DeckTargetArrow", UIParent)
arrow:SetSize(SIZE, SIZE)
arrow:SetFrameStrata("LOW")
arrow:Hide()

local outline = arrow:CreateTexture(nil, "ARTWORK", nil, 1)
outline:SetPoint("CENTER")
outline:SetSize(SIZE + 6, SIZE + 6)
outline:SetTexture(TEXTURE)
outline:SetVertexColor(0, 0, 0, 0.9)
local fill = arrow:CreateTexture(nil, "ARTWORK", nil, 2)
fill:SetPoint("CENTER")
fill:SetSize(SIZE, SIZE)
fill:SetTexture(TEXTURE)
-- a lighter top half, like the shine on FFXIV's marker
local shine = arrow:CreateTexture(nil, "ARTWORK", nil, 3)
shine:SetPoint("CENTER")
shine:SetSize(SIZE, SIZE)
shine:SetTexture(TEXTURE)
shine:SetBlendMode("ADD")
shine:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.35))

-- the gentle bob: the arrow's content moves, the anchor stays
local bob = arrow:CreateAnimationGroup()
bob:SetLooping("BOUNCE")
local move = bob:CreateAnimation("Translation")
move:SetOffset(0, 6)
move:SetDuration(0.6)
move:SetSmoothing("IN_OUT")

local function Secret(v) return issecretvalue and issecretvalue(v) end

local function Colour()
    local attackable = UnitCanAttack("player", "target")
    if Secret(attackable) then return NEUTRAL end
    -- a neutral creature can be attacked too, and is yellow as in the game
    -- (owner's report, 2026-10-26)
    local reaction = UnitReaction("target", "player")
    if attackable and not Secret(reaction) and reaction == 4 then return NEUTRAL end
    if attackable then return ENEMY end
    local friend = UnitIsFriend("player", "target")
    if not Secret(friend) and friend then return FRIEND end
    return NEUTRAL
end

local function Update()
    if not DeckUIDB.targetArrow or not UnitExists("target") then
        arrow:Hide()
        return
    end
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    if not plate then
        arrow:Hide()
        return
    end
    arrow:ClearAllPoints()
    arrow:SetPoint("BOTTOM", plate, "TOP", 0, 2)
    local c = Colour()
    fill:SetVertexColor(c[1], c[2], c[3])
    arrow:Show()
    if not bob:IsPlaying() then bob:Play() end
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function()
    -- plates settle a moment after they appear, as in softtarget.lua
    C_Timer.After(0.03, Update)
end)

function D.ApplyTargetArrow()
    if DeckUIDB.targetArrow then
        for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
                             "UNIT_FACTION", "PLAYER_ENTERING_WORLD" }) do
            ev:RegisterEvent(e)
        end
    else
        ev:UnregisterAllEvents()
        bob:Stop()
    end
    Update()
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function() D.ApplyTargetArrow() end)

function D.TargetArrowDebug()
    local plate = UnitExists("target") and C_NamePlate.GetNamePlateForUnit("target")
    print(("DeckUI target arrow: %s, target %s, nameplate %s, shown %s"):format(
        DeckUIDB.targetArrow and "on" or "off", tostring(UnitExists("target")),
        tostring(plate ~= nil and plate ~= false), tostring(arrow:IsShown())))
end

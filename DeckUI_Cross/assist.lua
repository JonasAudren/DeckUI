local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Assistant indicator
-------------------------------------------------------------------
-- Tanking with the single-button assistant leaves one question open that
-- the buttons cannot answer: is there nothing to press right now, or am I
-- missing something? The assistant recommends a spell either way, and a
-- button that simply sits there looks the same in both cases.
--
-- So this shows the recommended spell on its own, with the one thing that
-- settles the question: whether it can actually be cast at this moment.
-- Ready means press; not ready means waiting really is correct. The
-- cooldown swirl says how much longer.
--
-- Deliberately a separate frame rather than a badge on a cross button: the
-- assistant may live on a key binding with no button of its own, and then
-- there is nothing to decorate.
-------------------------------------------------------------------
local SIZE = 46
local RING_READY = { 0.3, 0.9, 0.35 }    -- the recommended spell can be cast
local RING_WAIT  = { 0.25, 0.25, 0.25 }  -- same grey as an idle cross ring

-- Spell 61304 is the global cooldown itself, and it is the only way to tell
-- "on cooldown" from "merely inside the GCD" here.
--
-- The numbers cannot do that job: C_Spell.GetSpellCooldown returns startTime,
-- duration and modRate as SECRET VALUES for real spells - comparing them
-- throws "attempt to compare a secret number value" and taints us. Measured
-- 2026-09-23 on Shield of the Righteous. Only the booleans in that table are
-- readable (isActive, isEnabled, and isOnGCD on the GCD entry), and the raw
-- numbers may still be handed straight back to Blizzard's own Cooldown frame,
-- which knows what to do with them.
--
-- So the state is only judged while the GCD is NOT running. In that moment
-- the answer is unambiguous - an active cooldown is the spell's own - and it
-- is also the moment the question is actually asked: what can I press next.
local GCD_SPELL = 61304

local frame = CreateFrame("Frame", "DeckCrossAssist", UIParent)
frame:SetSize(SIZE, SIZE)
frame.defaultPoint = { "CENTER", UIParent, "CENTER", 0, -160 }
frame:SetPoint(unpack(frame.defaultPoint))
frame:Hide()
ns.assist = frame

local mask = frame:CreateMaskTexture()
mask:SetTexture(D.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
mask:SetAllPoints(frame)

local ring = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
ring:SetSize(SIZE + 6, SIZE + 6)
ring:SetPoint("CENTER")
ring:SetTexture(D.DISC)
ring:SetVertexColor(unpack(RING_WAIT))

local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
bg:SetAllPoints()
bg:SetTexture(D.DISC)
bg:SetVertexColor(0.08, 0.08, 0.08, 1)

local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints()
icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
icon:AddMaskTexture(mask)

local cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
cd:SetAllPoints()
cd:SetSwipeTexture(D.DISC)
cd:SetUseCircularEdge(true)
cd:SetDrawEdge(false)
cd:SetSwipeColor(0, 0, 0, 0.75)
cd:SetHideCountdownNumbers(false)

-------------------------------------------------------------------
-- State
-------------------------------------------------------------------
local function Cooldown(id)
    if not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
    local ok, info = pcall(C_Spell.GetSpellCooldown, id)
    if ok and type(info) == "table" then return info end
    return nil
end

local function OnGCD()
    local gcd = Cooldown(GCD_SPELL)
    return (gcd and gcd.isOnGCD) and true or false
end

-- Castable right now. Only booleans are consulted; see the note above.
local function Ready(id, own)
    if not id then return false end
    if C_Spell and C_Spell.IsSpellUsable then
        local ok, usable = pcall(C_Spell.IsSpellUsable, id)
        -- Covers missing resources, which is most of a tank's waiting.
        if ok and not usable then return false end
    end
    return not (own and own.isActive)
end

local shownSpell

local function Apply(id)
    if id ~= shownSpell then
        shownSpell = id
        if id then
            local tex = C_Spell.GetSpellTexture(id)
            if tex then icon:SetTexture(tex) end
        end
    end
    if not id then
        icon:SetAlpha(0.25)
        ring:SetVertexColor(unpack(RING_WAIT))
        cd:Clear()
        return
    end

    -- Inside the GCD nothing can be said that is not about the GCD, so the
    -- display simply stands still rather than flickering once per cast.
    if OnGCD() then return end

    local own   = Cooldown(id)
    local ready = Ready(id, own)
    icon:SetAlpha(ready and 1 or 0.4)
    ring:SetVertexColor(unpack(ready and RING_READY or RING_WAIT))

    -- The swirl answers "how much longer". The numbers are secret, but they
    -- may be passed back to Blizzard's own frame untouched - it is only our
    -- arithmetic on them that is forbidden.
    if own and own.isActive then
        pcall(cd.SetCooldown, cd, own.startTime, own.duration, own.modRate)
    else
        cd:Clear()
    end
end

local poll = CreateFrame("Frame")
local elapsed = 0
poll:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.1 then return end
    elapsed = 0
    if not frame:IsShown() then return end
    if not (C_AssistedCombat and C_AssistedCombat.GetNextCastSpell) then
        Apply(nil)
        return
    end
    local ok, spell = pcall(C_AssistedCombat.GetNextCastSpell, true)
    Apply(ok and spell or nil)
end)

-------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------
function ns.SetAssistShown(state)
    DeckCrossDB.showAssist = state
    frame:SetShown(state)
end

function ns.InitAssist()
    if DeckCrossDB.showAssist == nil then DeckCrossDB.showAssist = false end
    D.MakeMovable(frame, "Assist indicator", DeckCrossDB)
    frame:SetShown(DeckCrossDB.showAssist)
end

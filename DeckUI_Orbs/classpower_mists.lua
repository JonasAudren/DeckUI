local _, ns = ...

-------------------------------------------------------------------
-- Class resources in Mists of Pandaria Classic (MISTS_PLAN.md, phase 3)
-------------------------------------------------------------------
-- Only in DeckUI_Orbs_Mists.toc, loaded before oUF: oUF's ClassPower
-- element (libs/oUF/elements/classpower.lua, "DeckUI: Mists") asks
-- ns.MistsClassPower for its rules instead of retail's when it is set.
--
-- Mists has resources retail lost: shadow orbs, burning embers, demonic
-- fury and eclipse, chi for every monk, and combo points kept on the
-- target. The rules follow Blizzard's own bars in the 5.5.4 client
-- (Blizzard_UnitFrame: Mists/ShardBar, PriestBar, MonkHarmonyBar,
-- PaladinPowerBar, Cata/EclipseBarFrame, Classic/ComboFrame, read
-- 2026-10-26). Spell IDs from the game's own data (wago.tools SpellName,
-- branch wow_classic, 2026-10-26): 36032 Arcane Charge, 53817 Maelstrom
-- Weapon, 5221 Shred; the warlock's are Blizzard's globals.
--
-- A resource with many points or a scale (fury 0-1000, eclipse -100..100)
-- fills a single bar: oUF makes one bar per point.
-------------------------------------------------------------------
local PT = Enum.PowerType

local SPELL_ARCANE_CHARGE   = 36032
local SPELL_MAELSTROM       = 53817
local SPELL_SHRED           = 5221

-- Blizzard_FrameXMLBase/Classic/Constants.lua and the class bars, with
-- their values as fallbacks
local SPEC_DRUID_BALANCE       = _G.SPEC_DRUID_BALANCE or 1
local SPEC_MAGE_ARCANE         = _G.SPEC_MAGE_ARCANE or 1
local SPEC_PRIEST_SHADOW       = _G.SPEC_PRIEST_SHADOW or 3
local SPEC_SHAMAN_ENHANCEMENT  = 2
local SPEC_WARLOCK_AFFLICTION  = _G.SPEC_WARLOCK_AFFLICTION or 1
local SPEC_WARLOCK_DEMONOLOGY  = _G.SPEC_WARLOCK_DEMONOLOGY or 2
local SPEC_WARLOCK_DESTRUCTION = _G.SPEC_WARLOCK_DESTRUCTION or 3
local PALADIN_LEVEL            = _G.PALADINPOWERBAR_SHOW_LEVEL or 9
local SHADOW_ORBS_LEVEL        = _G.SHADOW_ORBS_SHOW_LEVEL or 10
local POWER_PER_EMBER          = _G.MAX_POWER_PER_EMBER or 10

-- Mists' PowerBarColor has none of these
local COLORS = {
    SHADOW_ORBS    = CreateColor(0.62, 0.42, 0.95),
    BURNING_EMBERS = CreateColor(1.00, 0.45, 0.10),
    DEMONIC_FURY   = CreateColor(0.60, 0.25, 0.90),
    ECLIPSE_LUNAR  = CreateColor(0.30, 0.52, 0.90),
    ECLIPSE_SOLAR  = CreateColor(0.95, 0.73, 0.15),
    ARCANE_CHARGES = CreateColor(0.40, 0.55, 1.00),
    MAELSTROM      = CreateColor(0.00, 0.50, 1.00),
}

local function Spec()
    return C_SpecializationInfo.GetSpecialization()
end

local function Known(spellID)
    return spellID and C_SpellBook.IsSpellKnown(spellID)
end

-- combo points belong to the target in Mists (Classic/ComboFrame.lua)
function ns.MistsComboPoints(unit)
    return GetComboPoints(unit == "vehicle" and "vehicle" or "player", "target") or 0
end

function ns.MistsComboPointsMax(unit)
    local max = UnitPowerMax(unit, PT.ComboPoints)
    return (max and max > 0) and max or 5
end

-- the rune colours by type: blood, unholy, frost, death (runes.lua)
local RUNE_COLORS = {
    [1] = CreateColor(1.00, 0.25, 0.25),   -- blood
    [2] = CreateColor(0.30, 0.85, 0.30),   -- unholy
    [3] = CreateColor(0.25, 0.65, 1.00),   -- frost
    [4] = CreateColor(0.75, 0.40, 0.95),   -- death
}
function ns.MistsRuneColor(runeID)
    return RUNE_COLORS[GetRuneType(runeID) or 0]
end

local function AuraStacks(spellID)
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
    return aura and aura.applications or 0
end

local function AuraStacksMax(spellID)
    local max = C_Spell.GetSpellMaxCumulativeAuraApplications(spellID)
    return (max and max > 0) and max or 1
end

-- generic: the number oUF's own getters hand back; the rest by class
function ns.MistsClassPower(class, GetGeneric, GetGenericMax, GetGenericColor, GetCombo, GetComboMax)
    local function Color(element, powerType)
        return element.__owner.colors.power[powerType] or COLORS[powerType]
    end
    local function Generic()
        return GetGeneric, GetGenericMax, Color
    end

    if class == "DRUID" then
        local function Eclipse(unit)
            local max = UnitPowerMax(unit, PT.Balance)
            if not max or max == 0 then return 0 end
            return (UnitPower(unit, PT.Balance) + max) / (2 * max)   -- 0 lunar .. 1 solar
        end
        local function EclipseColor()
            return UnitPower("player", PT.Balance) < 0 and COLORS.ECLIPSE_LUNAR or COLORS.ECLIPSE_SOLAR
        end
        local function One() return 1 end
        local function IsCat()
            return UnitPowerType("player") == PT.Energy and Known(SPELL_SHRED)
        end
        return function()
            if IsCat() then return GetCombo, GetComboMax, Color end
            return Eclipse, One, EclipseColor
        end, function()
            if IsCat() then return "COMBO_POINTS", PT.ComboPoints end
            -- Blizzard's eclipse bar: balance, in moonkin form or none
            local form = GetShapeshiftFormID()
            if Spec() == SPEC_DRUID_BALANCE and (not form or form == MOONKIN_FORM) then
                return "ECLIPSE", PT.Balance
            end
        end
    elseif class == "MONK" then
        -- every monk spec builds chi in Mists
        return Generic, function() return "CHI", PT.Chi end
    elseif class == "PALADIN" then
        return Generic, function()
            if UnitLevel("player") >= PALADIN_LEVEL then return "HOLY_POWER", PT.HolyPower end
        end
    elseif class == "PRIEST" then
        return Generic, function()
            if Spec() == SPEC_PRIEST_SHADOW and UnitLevel("player") >= SHADOW_ORBS_LEVEL then
                return "SHADOW_ORBS", PT.ShadowOrbs
            end
        end
    elseif class == "ROGUE" then
        return function() return GetCombo, GetComboMax, Color end,
            function() return "COMBO_POINTS", PT.ComboPoints end
    elseif class == "WARLOCK" then
        -- embers in tenths: 2.3 is two full and a third of the next
        local function Embers(unit)
            return UnitPower(unit, PT.BurningEmbers, true) / POWER_PER_EMBER
        end
        local function EmbersMax(unit)
            return math.floor(UnitPowerMax(unit, PT.BurningEmbers, true) / POWER_PER_EMBER)
        end
        local function Fury(unit)
            local max = UnitPowerMax(unit, PT.DemonicFury)
            return (max and max > 0) and UnitPower(unit, PT.DemonicFury) / max or 0
        end
        local function One() return 1 end
        return function()
            local spec = Spec()
            if spec == SPEC_WARLOCK_DESTRUCTION then return Embers, EmbersMax, Color end
            if spec == SPEC_WARLOCK_DEMONOLOGY then return Fury, One, Color end
            return GetGeneric, GetGenericMax, Color
        end, function()
            local spec = Spec()
            if spec == SPEC_WARLOCK_AFFLICTION and Known(_G.WARLOCK_SOULBURN) then
                return "SOUL_SHARDS", PT.SoulShards
            elseif spec == SPEC_WARLOCK_DESTRUCTION and Known(_G.WARLOCK_BURNING_EMBERS) then
                return "BURNING_EMBERS", PT.BurningEmbers
            elseif spec == SPEC_WARLOCK_DEMONOLOGY then
                return "DEMONIC_FURY", PT.DemonicFury
            end
        end
    elseif class == "MAGE" then
        -- arcane charges are a stacking aura in Mists, not a power
        return function()
            return function() return AuraStacks(SPELL_ARCANE_CHARGE) end,
                function() return AuraStacksMax(SPELL_ARCANE_CHARGE) end, Color
        end, nil, function()
            if Spec() == SPEC_MAGE_ARCANE then return "ARCANE_CHARGES" end
        end
    elseif class == "SHAMAN" then
        return function()
            return function() return AuraStacks(SPELL_MAELSTROM) end,
                function() return AuraStacksMax(SPELL_MAELSTROM) end, Color
        end, nil, function()
            if Spec() == SPEC_SHAMAN_ENHANCEMENT then return "MAELSTROM" end
        end
    end
    -- death knights (runes), hunters and warriors: nothing here
    return function() return GetGeneric, GetGenericMax, Color end
end

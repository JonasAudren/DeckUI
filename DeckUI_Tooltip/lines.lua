local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Extra lines: class colours, spec and item level, target, IDs
-------------------------------------------------------------------
-- Everything goes through TooltipDataProcessor.AddTooltipPostCall
-- (TooltipDataHandler.lua, 12.1.0): Blizzard runs these after its own
-- lines and before its own Show, wraps an addon's callback so the taint
-- does not flow back into its processing, and runs them again when the
-- tooltip rebuilds (TOOLTIP_DATA_UPDATE) - so lines added here survive a
-- refresh. We only add lines and recolour; see core.lua for the rules.
local Plain = ns.Plain
local GREY = { 0.6, 0.6, 0.6 }

local function Styled(tooltip)
    return tooltip == GameTooltip or tooltip == ItemRefTooltip
        or tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2
end

-- Shift at the moment the tooltip is built; moving the mouse off and on
-- again shows the IDs once Shift is held
local function WantIDs()
    return DeckTooltipDB.ids and IsShiftKeyDown()
end

local function IDLine(tooltip, label, id)
    if Plain(id) and id then
        tooltip:AddDoubleLine(label, tostring(id), GREY[1], GREY[2], GREY[3], GREY[1], GREY[2], GREY[3])
    end
end

-------------------------------------------------------------------
-- Spec and item level of players
-------------------------------------------------------------------
-- Others need an inspect (NotifyInspect -> INSPECT_READY). The server
-- drops inspect data when flooded (a comment in Blizzard_InspectUI), so
-- one request at a time, not more than one every INSPECT_GAP seconds,
-- never in combat and never while Blizzard's own inspect window is open.
-- Results are kept by GUID for CACHE_TIME seconds. When one arrives while
-- its player is still under the mouse, the tooltip is rebuilt through
-- Blizzard's own SetUnit, which runs the post-call again with the answer.
local INSPECT_GAP = 1.5
local INSPECT_TIMEOUT = 5   -- no answer (out of range, logged off): ask anew
local CACHE_TIME = 300

local inspected = {}     -- guid -> { specID, ilvl, time }
local pendingGUID, lastRequest = nil, 0

local function InspectWindowOpen()
    return InspectFrame and InspectFrame:IsShown()
end

local function RequestInspect(unit, guid)
    if InCombatLockdown() or InspectWindowOpen() then return end
    if pendingGUID and GetTime() - lastRequest > INSPECT_TIMEOUT then pendingGUID = nil end
    if pendingGUID or GetTime() - lastRequest < INSPECT_GAP then return end
    if not CanInspect(unit) then return end
    pendingGUID, lastRequest = guid, GetTime()
    NotifyInspect(unit)
end

local function SpecText(specID)
    if not Plain(specID) or not specID or specID == 0 then return nil end
    local _, name = GetSpecializationInfoByID(specID)
    return name
end

-- spec name and item level for a player unit, or nil while unknown
local function PlayerInfo(unit)
    if UnitIsUnit(unit, "player") then
        local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
        local getInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
        local index = getSpec and getSpec()
        local specID = index and getInfo and getInfo(index)
        local _, equipped = GetAverageItemLevel()
        return SpecText(specID), equipped
    end
    local guid = UnitGUID(unit)
    if not Plain(guid) or not guid then return nil end
    local known = inspected[guid]
    if known and GetTime() - known.time < CACHE_TIME then
        return SpecText(known.specID), known.ilvl
    end
    RequestInspect(unit, guid)
    return nil
end

local inspectEvents = CreateFrame("Frame")
inspectEvents:RegisterEvent("INSPECT_READY")
inspectEvents:SetScript("OnEvent", function(_, _, guid)
    if not Plain(guid) or not guid or guid ~= pendingGUID then return end
    pendingGUID = nil
    -- the mouse may be over an NPC by now, whose GUID is secret
    local over = UnitGUID("mouseover")
    local overIt = Plain(over) and over == guid
    local unit = overIt and "mouseover" or UnitTokenFromGUID(guid)
    if unit then
        local specID = GetInspectSpecialization(unit)
        local ilvl = C_PaperDollInfo.GetInspectItemLevel(unit)
        inspected[guid] = {
            specID = Plain(specID) and specID or nil,
            ilvl = Plain(ilvl) and ilvl or nil,
            time = GetTime(),
        }
    end
    -- leave Blizzard's inspect window its data if it opened meanwhile
    if not InspectWindowOpen() then ClearInspectPlayer() end
    if overIt and GameTooltip:IsShown() then
        GameTooltip:SetUnit("mouseover")
    end
end)

-------------------------------------------------------------------
-- Units
-------------------------------------------------------------------
local function ClassColor(unit)
    if not UnitIsPlayer(unit) then return nil end
    local _, class = UnitClass(unit)
    if not Plain(class) or not class then return nil end
    return RAID_CLASS_COLORS[class]
end

local function TargetLine(tooltip, unit)
    local target = unit .. "target"
    if not UnitExists(target) then return end
    local isMe = UnitIsUnit(target, "player")
    if Plain(isMe) and isMe then
        tooltip:AddDoubleLine("Target", ">> You <<", GREY[1], GREY[2], GREY[3], 1, 0.3, 0.3)
        return
    end
    -- UnitExists said there is one; the name itself may be secret, so it is
    -- not even tested
    local name = UnitName(target)
    local c = ClassColor(target) or HIGHLIGHT_FONT_COLOR
    -- the name may be secret: handed to the tooltip as it is, never joined
    tooltip:AddDoubleLine("Target", name, GREY[1], GREY[2], GREY[3], c.r, c.g, c.b)
end

local function OnUnit(tooltip, data)
    if not Styled(tooltip) then return end
    local _, unit = tooltip:GetUnit()
    if not Plain(unit) or not unit then return end

    local c = DeckTooltipDB.classColors and ClassColor(unit)
    if c then
        -- the first line is the name (GameTooltip.xml's own font string)
        local first = _G[tooltip:GetName() .. "TextLeft1"]
        if first then first:SetTextColor(c.r, c.g, c.b) end
        ns.SetBorderColor(tooltip, c.r, c.g, c.b)
    end

    if DeckTooltipDB.playerInfo and UnitIsPlayer(unit) then
        local spec, ilvl = PlayerInfo(unit)
        if spec or ilvl then
            tooltip:AddDoubleLine(spec or " ", ilvl and ("Item level %d"):format(math.floor(ilvl + 0.5)) or " ",
                1, 1, 1, 1, 0.82, 0)
        end
    end

    if DeckTooltipDB.targetLine then TargetLine(tooltip, unit) end

    if WantIDs() and not UnitIsPlayer(unit) then
        -- Creature-0-server-instance-zone-npcID-spawn; secret for most NPCs
        local guid = data and data.guid
        if Plain(guid) and guid then
            local kind, _, _, _, _, npcID = strsplit("-", guid)
            if kind == "Creature" or kind == "Vehicle" then IDLine(tooltip, "NPC ID", npcID) end
        end
    end
end

-------------------------------------------------------------------
-- Items and spells
-------------------------------------------------------------------
local function OnItem(tooltip, data)
    if not Styled(tooltip) or not data then return end
    local id = data.id
    if Plain(id) and id then
        local quality = C_Item.GetItemQualityByID(id)
        -- grey and white items keep the grey edge
        local color = Plain(quality) and quality and quality >= 2 and ITEM_QUALITY_COLORS[quality]
        if color then ns.SetBorderColor(tooltip, color.r, color.g, color.b) end
    end
    if WantIDs() then IDLine(tooltip, "Item ID", id) end
end

local function OnSpell(tooltip, data)
    if not Styled(tooltip) or not data then return end
    if WantIDs() then IDLine(tooltip, "Spell ID", data.id) end
end

function ns.InitLines()
    local T = Enum.TooltipDataType
    TooltipDataProcessor.AddTooltipPostCall(T.Unit, OnUnit)
    TooltipDataProcessor.AddTooltipPostCall(T.Item, OnItem)
    TooltipDataProcessor.AddTooltipPostCall(T.Spell, OnSpell)
end

function ns.PrintLines()
    local n = 0
    for _ in pairs(inspected) do n = n + 1 end
    print(("  inspected players cached: %d, waiting for: %s, last request %.0fs ago"):format(
        n, tostring(pendingGUID), GetTime() - lastRequest))
end

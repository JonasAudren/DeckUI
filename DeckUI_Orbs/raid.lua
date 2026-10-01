local ADDON, ns = ...
local D = DeckUI
local oUF = ns.oUF

-------------------------------------------------------------------
-- Raid frames: a compact grid, one column per raid group
-------------------------------------------------------------------
-- The owner's choice (2026-10-01): Blizzard's grid in DeckUI's look -
-- tiles in class colour with the name, a role icon for tanks and healers,
-- up to three debuffs (dispellable ones with a coloured border), the
-- buffs you cast (heals over time, shields) and a thin mana bar for
-- healers. Groups 1-8 as columns, in the order the raid leader set them.
-- The party list (party.lua) stays separate and hides itself in a raid.
--
-- Eight oUF group headers, one per group (groupFilter "1".."8"): a single
-- header sorted by group fills its columns five at a time, so a group of
-- three would pull two of the next group into its column. Every header is
-- Blizzard's SecureGroupHeaderTemplate, which adds, removes and moves
-- members in combat by itself.
--
-- Secret values: health reaches the bar only through oUF; range and "is
-- this my target" go to the engine as booleans (SetAlphaFromBoolean, see
-- party.lua); raid members are player-controlled, so class and role are
-- readable - the role is still checked with issecretvalue by oUF.
-------------------------------------------------------------------
local W, H, GAP = 86, 46, 3
local GROUPS = NUM_RAID_GROUPS or 8
local PER_GROUP = MEMBERS_PER_RAID_GROUP or 5
local WHITE = "Interface\\Buttons\\WHITE8x8"
local GOLD = { 0.9, 0.75, 0.2 }
local VISIBILITY = "custom [group:raid] show; hide"

-------------------------------------------------------------------
-- Status text: Dead / Ghost / Offline, nothing while alive
-------------------------------------------------------------------
-- No health number: a tile has no room for one, and the bar says it.
oUF.Tags.Methods["deck:raidstatus"] = function(unit)
    if not UnitIsConnected(unit) then return PLAYER_OFFLINE or "Offline" end
    if UnitIsGhost(unit) then return "Ghost" end
    if UnitIsDead(unit) then return DEAD or "Dead" end
end
oUF.Tags.Events["deck:raidstatus"] = "UNIT_HEALTH UNIT_CONNECTION UNIT_FLAGS"

-------------------------------------------------------------------
-- One tile
-------------------------------------------------------------------
-- Only tanks and healers get an icon - in a raid nearly everyone is
-- damage, and the icon would only cost the name its room. The role also
-- decides the mana bar, so a new role takes the bar along.
local function RolePostUpdate(element, role)
    if role == Enum.LFGRole.Damage then element:Hide() end
    local power = element.__owner.Power
    if power then power:SetShown(role == Enum.LFGRole.Healer) end
end

local function BuildTile(self, unit)
    self:SetSize(W, H)
    self:RegisterForClicks("AnyUp")
    self:SetScript("OnEnter", ns.GroupOnEnter)
    self:SetScript("OnLeave", GameTooltip_Hide)

    local bg = self:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.9)
    ns.Edges(self, 0.3, 0.3, 0.3)

    local health = CreateFrame("StatusBar", nil, self)
    health:SetStatusBarTexture(WHITE)
    health:SetPoint("TOPLEFT", 1, -1)
    health:SetPoint("BOTTOMRIGHT", -1, 1)
    local hbg = health:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetColorTexture(0.12, 0.12, 0.12, 1)
    health.colorClass = true
    health.colorDisconnected = true
    self.Health = health
    local level = health:GetFrameLevel()

    -- the member you target: a gold edge, as on the party list
    local edge = CreateFrame("Frame", nil, self)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetFrameLevel(level + 5)
    ns.Edges(edge, GOLD[1], GOLD[2], GOLD[3])
    edge:SetAlpha(0)
    self.DeckTargetEdge = edge

    -- texts and the role icon ride on the health bar, above its fill
    local role = health:CreateTexture(nil, "OVERLAY")
    role:SetSize(11, 11)
    role:SetPoint("TOPLEFT", 2, -2)
    role.PostUpdate = RolePostUpdate
    self.GroupRoleIndicator = role

    local name = health:CreateFontString(nil, "OVERLAY")
    name:SetFont(ns.FONT, 10, "OUTLINE")
    name:SetPoint("TOPLEFT", 14, -3)
    name:SetPoint("TOPRIGHT", -2, -3)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    self:Tag(name, "[name]")

    local status = health:CreateFontString(nil, "OVERLAY")
    status:SetFont(ns.FONT, 10, "OUTLINE")
    status:SetPoint("CENTER", 0, -1)
    status:SetTextColor(0.75, 0.75, 0.75)
    self:Tag(status, "[deck:raidstatus]")

    local power = CreateFrame("StatusBar", nil, self)
    power:SetStatusBarTexture(WHITE)
    power:SetPoint("BOTTOMLEFT", 1, 1)
    power:SetPoint("BOTTOMRIGHT", -1, 1)
    power:SetHeight(3)
    power:SetFrameLevel(level + 1)
    power.colorPower = true
    power:Hide()
    self.Power = power

    self.Range = { insideAlpha = 1, outsideAlpha = 0.4 }

    if self.CreateAuras then
        -- debuffs bottom left, your own buffs bottom right, above the mana
        local function Container(anchor, growthX, size, x)
            local auras = self:CreateAuras({
                layout        = AnchorUtil.FlowLayoutAxis.Horizontal,
                layoutLimit   = 3 * (size + 1),
                initialAnchor = anchor,
                growthX       = growthX,
                growthY       = "UP",
            })
            auras:SetSize(3 * (size + 1), size)
            auras:SetPoint(anchor, x, 5)
            auras:SetFrameLevel(level + 2)
            auras.size = size
            auras.elementSpacing = 1
            auras.showCount = true
            auras.PostCreateButton = ns.StyleGroupAura
            table.insert(ns.auraContainers, auras)
            return auras
        end
        Container("BOTTOMLEFT", "RIGHT", 14, 2)
            :AddGroup("HARMFUL", { maxFrameCount = 3, showDebuffBorder = true })
        Container("BOTTOMRIGHT", "LEFT", 11, -2)
            :AddGroup("HELPFUL|PLAYER", { maxFrameCount = 3 })
    end
end

oUF:RegisterStyle("DeckOrbsRaid", BuildTile)

-------------------------------------------------------------------
-- Blizzard's raid frames
-------------------------------------------------------------------
-- Only the frames go: CompactRaidFrameManager - the pull-out on the left
-- with raid markers, ready check and the like - stays. The container is
-- parked under a hidden frame and stops listening, the way oUF parks
-- Blizzard's party frames (blizzard.lua): methods only, no field of ours
-- written onto Blizzard's frames. Its unit frames are secure, so the move
-- waits for the end of combat.
local hidden = CreateFrame("Frame")
hidden:Hide()

local function Silence(frame)
    frame:UnregisterAllEvents()
    for _, child in ipairs({ frame:GetChildren() }) do Silence(child) end
end

local function HideBlizzardRaid()
    local container = (CompactRaidFrameManager and CompactRaidFrameManager.container)
        or CompactRaidFrameContainer
    if not container or container:GetParent() == hidden then return end
    Silence(container)
    container:SetParent(hidden)
end

function ns.BlizzardRaidHidden()
    local container = (CompactRaidFrameManager and CompactRaidFrameManager.container)
        or CompactRaidFrameContainer
    return container and container:GetParent() == hidden
end

-------------------------------------------------------------------
-- Test mode: a full raid of yourself, to see size and place alone
-------------------------------------------------------------------
-- Session only, like the party list's: oUF frames for "player" in the
-- raid style, secure like the real tiles, so they come and go only out of
-- combat. While they show, the real headers are hidden.
local testFrames = {}

local function TilePoint(f, group, slot)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", ns.raidHolder, "TOPLEFT", (group - 1) * (W + GAP), -(slot - 1) * (H + GAP))
end

function ns.SetRaidTest(on)
    if not ns.raidHeaders then
        print("DeckUI Orbs: switch the raid frames on and /reload first.")
        return
    end
    if InCombatLockdown() then print("DeckUI Orbs: raid test mode switches after combat.") end
    ns.OutOfCombat("raidTest", function()
        ns.raidTest = on
        if on and #testFrames == 0 then
            oUF:SetActiveStyle("DeckOrbsRaid")
            for i = 1, GROUPS * PER_GROUP do
                local f = oUF:Spawn("player", "DeckOrbsRaidTest" .. i)
                TilePoint(f, math.floor((i - 1) / PER_GROUP) + 1, (i - 1) % PER_GROUP + 1)
                testFrames[i] = f
            end
        end
        local scale = ns.DeviceDB().raidScale or 1
        for _, f in ipairs(testFrames) do
            f:SetScale(scale)
            if on then
                RegisterUnitWatch(f)
            else
                UnregisterUnitWatch(f)
                f:Hide()
            end
        end
        for _, header in ipairs(ns.raidHeaders) do
            header:SetVisibility(on and "hide" or VISIBILITY)
        end
        print("DeckUI Orbs: raid test mode " .. (on and "on - a raid of you." or "off."))
    end)
end

function ns.ApplyRaidScale()
    if not ns.raidHeaders then return end
    local scale = ns.DeviceDB().raidScale or 1
    ns.raidHolder:SetScale(scale)
    ns.OutOfCombat("raidScale", function()
        for _, header in ipairs(ns.raidHeaders) do header:SetScale(scale) end
        for _, f in ipairs(testFrames) do f:SetScale(scale) end
    end)
end

oUF:Factory(function(self)
    if not DeckOrbsDB.showRaid then return end
    self:SetActiveStyle("DeckOrbsRaid")

    local holder = CreateFrame("Frame", "DeckOrbsRaidHolder", UIParent)
    holder:SetSize(GROUPS * (W + GAP) - GAP, PER_GROUP * (H + GAP) - GAP)
    holder.defaultPoint = { "LEFT", UIParent, "LEFT", 24, 60 }
    holder:SetPoint(unpack(holder.defaultPoint))
    D.MakeMovable(holder, "Raid", DeckOrbsDB)
    ns.raidHolder = holder

    ns.raidHeaders = {}
    for group = 1, GROUPS do
        local header = self:SpawnHeader("DeckOrbsRaidGroup" .. group, nil,
            "showRaid", true,
            "groupFilter", tostring(group),
            "point", "TOP",
            "yOffset", -GAP,
            "oUF-initialConfigFunction", ("self:SetWidth(%d); self:SetHeight(%d)"):format(W, H))
        header:SetVisibility(VISIBILITY)
        header:SetPoint("TOPLEFT", holder, "TOPLEFT", (group - 1) * (W + GAP), 0)
        ns.raidHeaders[group] = header
    end
    ns.ApplyRaidScale()

    EventUtil.ContinueOnAddOnLoaded("Blizzard_CompactRaidFrames", function()
        ns.OutOfCombat("blizzardRaid", HideBlizzardRaid)
    end)
end)

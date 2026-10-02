local ADDON, ns = ...
local D = DeckUI
local oUF = ns.oUF

-------------------------------------------------------------------
-- Raid frames: a compact grid, one column (or row) per raid group
-------------------------------------------------------------------
-- The owner's choice (2026-10-01): Blizzard's grid in DeckUI's look -
-- name, a role icon for tanks and healers, up to three debuffs, the buffs
-- you cast and a thin mana bar for healers. Reworked 2026-10-02 (owner:
-- the tiles were too bulky, wanted the dispel and aggro state at a glance
-- and more to set up): tiles shaped like the FF style's parameter bar,
-- the whole tile framed in the dispel colour, a red edge on aggro,
-- and a Raid tab of its own (config.lua) - width, height, columns or rows,
-- sorting, colours, health text, what a tile shows.
-- The party list (party.lua) stays separate and hides itself in a raid.
--
-- Eight oUF group headers (Blizzard's SecureGroupHeaderTemplate), one per
-- group: a single header sorted by group fills its columns five at a time,
-- so a group of three would pull two of the next group into its column.
-- Sorted by role or class there are no groups to keep apart: header 1
-- then takes the whole raid (groupBy, eight columns of five) and the
-- other seven are hidden. Headers are secure, so every change of their
-- attributes, size or place waits for the end of combat (ns.OutOfCombat).
--
-- Secret values: health reaches the bar only through oUF; range and "is
-- this my target" go to the engine as booleans (SetAlphaFromBoolean, see
-- party.lua). The dispel frame is an aura button of the engine's own
-- (filtered to what you can dispel), whose border the engine colours by
-- dispel type - no dispel type passes through our code. Threat is shown
-- only while UnitThreatSituation answers with a plain number.
-------------------------------------------------------------------
local GROUPS = NUM_RAID_GROUPS or 8
local PER_GROUP = MEMBERS_PER_RAID_GROUP or 5
local GAP = 2
local WHITE = "Interface\\Buttons\\WHITE8x8"
local GOLD = { 0.9, 0.75, 0.2 }
local VISIBILITY = "custom [group:raid] show; hide"


local CLASS_ORDER = "WARRIOR,DEATHKNIGHT,PALADIN,MONK,PRIEST,SHAMAN,DRUID,ROGUE,MAGE,WARLOCK,HUNTER,DEMONHUNTER,EVOKER"
local HP_TAGS = { percent = "[perhp]%", short = "[deck:hpshort]" }

-- debuffs only you can dispel: Blizzard's own filter name where it has one
local DISPEL_FILTER = "HARMFUL|" .. (AuraUtil and AuraUtil.AuraFilters
    and AuraUtil.AuraFilters.RaidPlayerDispellable or "RAID")

ns.raidTiles = {}

local function Size()
    local dev = ns.DeviceDB()
    return dev.raidW or 80, dev.raidH or 32
end

-------------------------------------------------------------------
-- Status text: Dead / Ghost / Offline, nothing while alive
-------------------------------------------------------------------
oUF.Tags.Methods["deck:raidstatus"] = function(unit)
    if not UnitIsConnected(unit) then return PLAYER_OFFLINE or "Offline" end
    if UnitIsGhost(unit) then return "Ghost" end
    if UnitIsDead(unit) then return DEAD or "Dead" end
end
oUF.Tags.Events["deck:raidstatus"] = "UNIT_HEALTH UNIT_CONNECTION UNIT_FLAGS"

-------------------------------------------------------------------
-- Threat: a red edge while the member has aggro
-------------------------------------------------------------------
local function UpdateThreat(self, _, unit)
    local own = self.__unit or self.unit
    if unit and unit ~= own then return end
    local edge = self.DeckThreat
    local status = DeckOrbsDB.raidAggro and own and UnitExists(own) and UnitThreatSituation(own)
    if not status or (issecretvalue and issecretvalue(status)) then
        edge:SetAlpha(0)
        return
    end
    edge:SetAlpha(status >= 2 and 1 or 0)
end

oUF:AddElement("DeckThreat", UpdateThreat, function(self)
    if not self.DeckThreat then return end
    self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", UpdateThreat)
    self:RegisterEvent("UNIT_THREAT_LIST_UPDATE", UpdateThreat)
    return true
end, function(self)
    if not self.DeckThreat then return end
    self:UnregisterEvent("UNIT_THREAT_SITUATION_UPDATE", UpdateThreat)
    self:UnregisterEvent("UNIT_THREAT_LIST_UPDATE", UpdateThreat)
    self.DeckThreat:SetAlpha(0)
end)

-------------------------------------------------------------------
-- One tile: a small parameter bar, like the player's in the FF style
-------------------------------------------------------------------
-- Owner, 2026-10-02: "like the player frames" - ffstyle.lua's parameter
-- bar: a dark panel with a thin grey edge, the text on top and a thin bar
-- below it instead of a bar filling the tile.
--   top:    role icon, name in class colour   | up to N debuffs
--   middle: the health bar (FF green or class colour), mana for healers
--   bottom: health text                       | your own buffs
local INSET = 4

-- Only tanks and healers get an icon - in a raid nearly everyone is
-- damage, and the icon would only cost the name its room. The role also
-- decides the mana bar, so a new role takes the bar along.
local function RolePostUpdate(element, role)
    local owner = element.__owner
    local shown = DeckOrbsDB.raidRoles and role ~= Enum.LFGRole.Damage and element:IsShown()
    element:SetShown(shown and true or false)
    owner.DeckName:SetPoint("TOPLEFT", shown and (INSET + 11) or INSET, -3)
    if owner.Power then owner.Power:SetShown(DeckOrbsDB.raidMana and role == Enum.LFGRole.Healer) end
end

-- the small auras: no countdown numbers - on a 9-pixel icon "20m" took
-- more room than the icon itself (owner's screenshot, 2026-10-02); the
-- swirl still shows the time, the stack count stays, smaller
local function StyleRaidAura(element, button)
    ns.StyleGroupAura(element, button)
    if button.Cooldown then
        button.Cooldown:SetHideCountdownNumbers(true)
        button.Cooldown:SetDrawEdge(false)
    end
    if button.Count then button.Count:SetFont(ns.FONT, 8, "OUTLINE") end
end

-- the dispel frame: an aura button the size of the tile, icon invisible,
-- its border coloured by the engine
local function StyleDispelButton(element, button)
    if button.Icon then button.Icon:SetAlpha(0) end
    local owner = element.__owner
    owner.DeckDispelButtons[#owner.DeckDispelButtons + 1] = button
end

-- colours, texts and toggles: anything that can change without a reload
local function LookTile(self)
    self.DeckBg:SetColorTexture(0.05, 0.05, 0.05, DeckOrbsDB.raidBgAlpha or 0.8)
    -- FF green (oUF's health colour) unless the bar takes the class colour
    self.Health.colorClass = DeckOrbsDB.raidColor == "class"

    self:Untag(self.DeckHp)
    local tag = HP_TAGS[DeckOrbsDB.raidHpText]
    if tag then
        self:Tag(self.DeckHp, tag)
        self.DeckHp:UpdateTag()
    else
        self.DeckHp:SetText("")
    end

    self.Range.outsideAlpha = DeckOrbsDB.raidRangeAlpha or 0.4
    if self.DeckDispel then self.DeckDispel:SetAlpha(DeckOrbsDB.raidDispelGlow and 1 or 0) end
    if self.unit then
        for _, key in ipairs({ "Health", "GroupRoleIndicator" }) do
            local element = self[key]
            if element and element.ForceUpdate then element:ForceUpdate() end
        end
        UpdateThreat(self)
    end
end

-- width and height (secure frame: out of combat only); the bars follow
-- the width by their anchors
local function SizeTile(self)
    local w, h = Size()
    self:SetSize(w, h)
    for _, b in ipairs(self.DeckDispelButtons) do b:SetSize(w - 2, h - 2) end
    if self.DeckDispel then self.DeckDispel:SetSize(w - 2, h - 2) end
end

local function Edge(self, level, r, g, b)
    local edge = CreateFrame("Frame", nil, self)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetFrameLevel(level)
    ns.Edges(edge, r, g, b)
    edge:SetAlpha(0)
    return edge
end

local function Bar(self, height, y, level)
    local bar = CreateFrame("StatusBar", nil, self)
    bar:SetStatusBarTexture(WHITE)
    bar:SetPoint("TOPLEFT", INSET, y)
    bar:SetPoint("TOPRIGHT", -INSET, y)
    bar:SetHeight(height)
    bar:SetFrameLevel(level)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.12, 0.12, 0.12, 1)
    return bar
end

local function BuildTile(self, unit)
    local w, h = Size()
    self:SetSize(w, h)
    self:RegisterForClicks("AnyUp")
    self:SetScript("OnEnter", ns.GroupOnEnter)
    self:SetScript("OnLeave", GameTooltip_Hide)
    self.DeckDispelButtons = {}
    local level = self:GetFrameLevel()

    local bg = self:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    self.DeckBg = bg
    ns.Edges(self, 0.3, 0.3, 0.3)

    -- texts on a layer of their own, above the bars
    local texts = CreateFrame("Frame", nil, self)
    texts:SetAllPoints()
    texts:SetFrameLevel(level + 3)

    local health = Bar(self, 6, -17, level + 1)
    health.colorHealth = true
    health.colorDisconnected = true
    self.Health = health

    local power = Bar(self, 2, -25, level + 1)
    power.colorPower = true
    power:Hide()
    self.Power = power

    -- aggro and your target edge the tile; the dispel colour frames it inside
    self.DeckThreat = Edge(self, level + 5, 0.9, 0.12, 0.1)
    self.DeckTargetEdge = Edge(self, level + 6, GOLD[1], GOLD[2], GOLD[3])

    local role = texts:CreateTexture(nil, "OVERLAY")
    role:SetSize(10, 10)
    role:SetPoint("TOPLEFT", INSET, -3)
    role.PostUpdate = RolePostUpdate
    self.GroupRoleIndicator = role

    local name = texts:CreateFontString(nil, "OVERLAY")
    name:SetFont(ns.FONT, 10, "OUTLINE")
    name:SetPoint("TOPLEFT", INSET + 11, -3)
    name:SetPoint("RIGHT", -INSET, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    self:Tag(name, "[raidcolor][name]")
    self.DeckName = name

    local hp = texts:CreateFontString(nil, "OVERLAY")
    hp:SetFont(ns.FONT, 9, "OUTLINE")
    hp:SetPoint("BOTTOMLEFT", INSET, 2)
    hp:SetJustifyH("LEFT")
    hp:SetTextColor(0.85, 0.85, 0.85)
    self.DeckHp = hp

    local status = texts:CreateFontString(nil, "OVERLAY")
    status:SetFont(ns.FONT, 9, "OUTLINE")
    status:SetPoint("BOTTOMLEFT", INSET, 2)
    status:SetTextColor(0.75, 0.75, 0.75)
    self:Tag(status, "[deck:raidstatus]")

    self.Range = { insideAlpha = 1, outsideAlpha = DeckOrbsDB.raidRangeAlpha or 0.4 }

    if self.CreateAuras then
        -- debuffs top right, over the end of the name; your own buffs bottom right
        local function Container(anchor, size, y, count)
            local auras = self:CreateAuras({
                layout        = AnchorUtil.FlowLayoutAxis.Horizontal,
                layoutLimit   = count * (size + 1),
                initialAnchor = anchor,
                growthX       = "LEFT",
                growthY       = anchor:find("TOP") and "DOWN" or "UP",
            })
            auras:SetSize(count * (size + 1), size)
            auras:SetPoint(anchor, -INSET + 1, y)
            auras:SetFrameLevel(level + 4)
            auras.size = size
            auras.elementSpacing = 1
            auras.showCount = true
            auras.PostCreateButton = StyleRaidAura
            table.insert(ns.auraContainers, auras)
            return auras
        end
        local debuffs, buffs = DeckOrbsDB.raidDebuffs or 3, DeckOrbsDB.raidBuffs or 3
        if debuffs > 0 then
            Container("TOPRIGHT", 12, -2, debuffs)
                :AddGroup(DeckOrbsDB.raidDispelOnly and DISPEL_FILTER or "HARMFUL",
                    { maxFrameCount = debuffs, showDebuffBorder = true })
        end
        if buffs > 0 then
            Container("BOTTOMRIGHT", 9, 1, buffs)
                -- heals over time and shields, not your long blessings and the like
                :AddGroup("HELPFUL|PLAYER", { maxFrameCount = buffs, candidateFilters = { maxDuration = 120 } })
        end

        -- the dispel frame over the whole tile
        local dispel = self:CreateAuras({
            layout        = AnchorUtil.FlowLayoutAxis.Horizontal,
            layoutLimit   = w,
            initialAnchor = "TOPLEFT",
            growthX       = "RIGHT",
            growthY       = "DOWN",
        })
        dispel:SetPoint("TOPLEFT", 1, -1)
        dispel:SetSize(w - 2, h - 2)
        dispel:SetFrameLevel(level + 2)
        dispel.width, dispel.height = w - 2, h - 2
        dispel.disableMouse = true
        dispel.disableCooldown = true
        dispel.PostCreateButton = StyleDispelButton
        dispel:AddGroup(DISPEL_FILTER, { maxFrameCount = 1, showDebuffBorder = true })
        self.DeckDispel = dispel
    end

    ns.raidTiles[#ns.raidTiles + 1] = self
    LookTile(self)
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
-- Arrangement: columns or rows, by group, role or class
-------------------------------------------------------------------
local testFrames = {}

-- the place of member `slot` of group `group`, columns or rows
local function Offset(group, slot)
    local w, h = Size()
    if ns.DeviceDB().raidRows then
        return (slot - 1) * (w + GAP), -(group - 1) * (h + GAP)
    end
    return (group - 1) * (w + GAP), -(slot - 1) * (h + GAP)
end

local function LayoutTest()
    for i, f in ipairs(testFrames) do
        local x, y = Offset(math.floor((i - 1) / PER_GROUP) + 1, (i - 1) % PER_GROUP + 1)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", ns.raidHolder, "TOPLEFT", x, y)
    end
end

-- the header's attributes for the current settings; group = its number
local function Configure(header, group)
    local w, h = Size()
    local rows = ns.DeviceDB().raidRows
    local sort = DeckOrbsDB.raidSort
    local whole = sort ~= "group"   -- one header for the whole raid
    header:SetAttribute("_ignore", true)
    header:SetAttribute("point", rows and "LEFT" or "TOP")
    header:SetAttribute("xOffset", rows and GAP or 0)
    header:SetAttribute("yOffset", rows and 0 or -GAP)
    header:SetAttribute("columnAnchorPoint", rows and "TOP" or "LEFT")
    header:SetAttribute("columnSpacing", GAP)
    header:SetAttribute("maxColumns", whole and GROUPS or 1)
    header:SetAttribute("groupFilter", whole and "1,2,3,4,5,6,7,8" or tostring(group))
    header:SetAttribute("groupBy", sort == "role" and "ASSIGNEDROLE" or sort == "class" and "CLASS" or nil)
    header:SetAttribute("groupingOrder", sort == "role" and "TANK,HEALER,DAMAGER,NONE"
        or sort == "class" and CLASS_ORDER or nil)
    header:SetAttribute("oUF-initialConfigFunction", ("self:SetWidth(%d); self:SetHeight(%d)"):format(w, h))
    header:ClearAllPoints()
    local x, y = Offset(whole and 1 or group, 1)
    header:SetPoint("TOPLEFT", ns.raidHolder, "TOPLEFT", x, y)
    header:SetAttribute("_ignore", nil)
    -- the last change, made after _ignore is cleared, runs one re-layout
    header:SetAttribute("unitsPerColumn", PER_GROUP)
    header:SetVisibility((ns.raidTest or (whole and group > 1)) and "hide" or VISIBILITY)
end

function ns.ApplyRaidLayout()
    if not ns.raidHeaders then return end
    local w, h = Size()
    local rows = ns.DeviceDB().raidRows
    local across, down = GROUPS * (w + GAP) - GAP, PER_GROUP * (h + GAP) - GAP
    if rows then
        across, down = PER_GROUP * (w + GAP) - GAP, GROUPS * (h + GAP) - GAP
    end
    ns.raidHolder:SetSize(across, down)
    ns.OutOfCombat("raidLayout", function()
        for _, tile in ipairs(ns.raidTiles) do SizeTile(tile) end
        for group, header in ipairs(ns.raidHeaders) do Configure(header, group) end
        LayoutTest()
    end)
end

function ns.ApplyRaidLook()
    for _, tile in ipairs(ns.raidTiles) do LookTile(tile) end
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

-------------------------------------------------------------------
-- Test mode: a full raid of yourself, to see size and place alone
-------------------------------------------------------------------
-- Session only, like the party list's: oUF frames for "player" in the
-- raid style, secure like the real tiles, so they come and go only out of
-- combat. While they show, the real headers are hidden.
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
                testFrames[i] = oUF:Spawn("player", "DeckOrbsRaidTest" .. i)
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
        LayoutTest()
        for group, header in ipairs(ns.raidHeaders) do Configure(header, group) end
        print("DeckUI Orbs: raid test mode " .. (on and "on - a raid of you." or "off."))
    end)
end

oUF:Factory(function(self)
    if not DeckOrbsDB.showRaid then return end
    self:SetActiveStyle("DeckOrbsRaid")

    local holder = CreateFrame("Frame", "DeckOrbsRaidHolder", UIParent)
    holder:SetSize(10, 10)
    holder.defaultPoint = { "LEFT", UIParent, "LEFT", 24, 60 }
    holder:SetPoint(unpack(holder.defaultPoint))
    D.MakeMovable(holder, "Raid", DeckOrbsDB)
    ns.raidHolder = holder

    local w, h = Size()
    ns.raidHeaders = {}
    for group = 1, GROUPS do
        local header = self:SpawnHeader("DeckOrbsRaidGroup" .. group, nil,
            "showRaid", true,
            "groupFilter", tostring(group),
            "point", "TOP",
            "yOffset", -GAP,
            "oUF-initialConfigFunction", ("self:SetWidth(%d); self:SetHeight(%d)"):format(w, h))
        header:SetVisibility(VISIBILITY)
        ns.raidHeaders[group] = header
    end
    ns.ApplyRaidScale()
    ns.ApplyRaidLayout()

    EventUtil.ContinueOnAddOnLoaded("Blizzard_CompactRaidFrames", function()
        ns.OutOfCombat("blizzardRaid", HideBlizzardRaid)
    end)
end)

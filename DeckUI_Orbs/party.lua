local ADDON, ns = ...
local D = DeckUI
local oUF = ns.oUF

-------------------------------------------------------------------
-- Party frames in the style of Final Fantasy XIV's party list
-------------------------------------------------------------------
-- The owner's choice (2026-09-30): party only (the raid keeps Blizzard's
-- frames for now), rows like FFXIV - class icon, name, a wide health bar
-- with its number, a thin resource bar, auras to the right - in DeckUI's
-- colours; role icon, your own buffs and every debuff (dispellable ones
-- with a coloured border), a gold edge on the member you target, faded
-- out of range. Left click targets, right click opens the menu.
--
-- Built on oUF like the orbs. oUF's group header is Blizzard's
-- SecureGroupHeaderTemplate: it adds, removes and sorts members in combat
-- by itself, sets the click attributes (target / togglemenu) and, with
-- showParty, hides Blizzard's party frames (oUF:DisableBlizzard). That is
-- also why the switch needs a /reload: Blizzard's frames stay hidden for
-- the session once the header exists.
--
-- Secret values: health reaches the bar and the text only through oUF
-- and Blizzard's helpers (see CLAUDE.md), range and "is this my target"
-- are shown with SetAlphaFromBoolean, which takes a secret boolean as it
-- is. Party members are player-controlled, so their class is readable.
-------------------------------------------------------------------
local W, H, GAP = 230, 38, 6
local ICON = 34
local WHITE = "Interface\\Buttons\\WHITE8x8"
local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"
local GOLD = { 0.9, 0.75, 0.2 }
local partyAuras = {}   -- every row's aura container, re-anchored by the layout

-- A fill and four one-pixel lines, anchored only (no BackdropTemplate)
local function Edges(frame, r, g, b, a)
    local lines = {}
    local function Line(p1, p2, horizontal)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(r, g, b, a or 1)
        t:SetPoint(p1)
        t:SetPoint(p2)
        if horizontal then t:SetHeight(1) else t:SetWidth(1) end
        lines[#lines + 1] = t
    end
    Line("TOPLEFT", "TOPRIGHT", true)
    Line("BOTTOMLEFT", "BOTTOMRIGHT", true)
    Line("TOPLEFT", "BOTTOMLEFT", false)
    Line("TOPRIGHT", "BOTTOMRIGHT", false)
    return lines
end
ns.Edges = Edges   -- the raid tiles (raid.lua) wear the same edges

-------------------------------------------------------------------
-- Health text: the number, or Dead / Offline
-------------------------------------------------------------------
oUF.Tags.Methods["deck:partyhp"] = function(unit)
    if not UnitIsConnected(unit) then return PLAYER_OFFLINE or "Offline" end
    if UnitIsDeadOrGhost(unit) then return DEAD or "Dead" end
    local hp = UnitHealth(unit)
    local ok, text = pcall(AbbreviateNumbers, hp)
    if ok and text then return text end
    return hp
end
oUF.Tags.Events["deck:partyhp"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION UNIT_FLAGS"

-------------------------------------------------------------------
-- Two small elements of our own: the class icon and the target edge
-------------------------------------------------------------------
-- The icon stays hidden until the class is known: shown untouched, the
-- circles texture is a sheet of every class at once (owner's report,
-- 2026-09-30, when this element alone did not run for the rows). Blizzard's
-- own class atlas (GetClassAtlas, SharedConstants.lua) needs no texture
-- coordinates; the sheet with CLASS_ICON_TCOORDS is the fallback.
local function UpdateClassIcon(self)
    local icon = self.DeckClassIcon
    -- __unit is what oUF's own elements read (vehicle swaps included)
    local unit = self.__unit or self.unit
    if not icon or not unit then return end
    local _, class = UnitClass(unit)
    if (issecretvalue and issecretvalue(class)) or not class then
        icon:Hide()
        return
    end
    local atlas = GetClassAtlas and GetClassAtlas(class:lower())
    if atlas and C_Texture.GetAtlasInfo(atlas) then
        icon:SetAtlas(atlas)
        icon:Show()
        return
    end
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if coords then
        icon:SetTexture(CLASS_ICONS)
        icon:SetTexCoord(unpack(coords))
        icon:Show()
    else
        icon:Hide()
    end
end

oUF:AddElement("DeckClassIcon", UpdateClassIcon, function(self)
    if not self.DeckClassIcon then return end
    self:RegisterEvent("UNIT_NAME_UPDATE", UpdateClassIcon)
    return true
end, function(self)
    if not self.DeckClassIcon then return end
    self:UnregisterEvent("UNIT_NAME_UPDATE", UpdateClassIcon)
    self.DeckClassIcon:Hide()
end)

local function UpdateTargetEdge(self)
    local unit = self.__unit or self.unit
    if not unit then return end
    -- a secret boolean goes straight to the engine
    self.DeckTargetEdge:SetAlphaFromBoolean(UnitIsUnit(unit, "target"), 1, 0)
end

oUF:AddElement("DeckTargetEdge", UpdateTargetEdge, function(self)
    if not self.DeckTargetEdge then return end
    self:RegisterEvent("PLAYER_TARGET_CHANGED", UpdateTargetEdge, true)
    return true
end, function(self)
    if not self.DeckTargetEdge then return end
    self:UnregisterEvent("PLAYER_TARGET_CHANGED", UpdateTargetEdge)
    self.DeckTargetEdge:SetAlpha(0)
end)

-------------------------------------------------------------------
-- Auras: square, like FFXIV's status icons
-------------------------------------------------------------------
local function StyleAura(element, button)
    if button.Icon then button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    if button.Count then
        button.Count:SetFont(ns.FONT, 10, "OUTLINE")
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", 2, -2)
    end
end
ns.StyleGroupAura = StyleAura

-------------------------------------------------------------------
-- One row
-------------------------------------------------------------------
local function OnEnter(self)
    local unit = self.unit or self:GetAttribute("unit")
    if not unit or not UnitExists(unit) then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    GameTooltip:SetUnit(unit)
    GameTooltip:Show()
end
ns.GroupOnEnter = OnEnter

local function BuildRow(self, unit)
    self:SetSize(W, H)
    self:RegisterForClicks("AnyUp")
    self:SetScript("OnEnter", OnEnter)
    self:SetScript("OnLeave", GameTooltip_Hide)

    local bg = self:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.8)
    Edges(self, 0.3, 0.3, 0.3)

    -- the member you target: a gold edge above the grey one
    local edge = CreateFrame("Frame", nil, self)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetFrameLevel(self:GetFrameLevel() + 5)
    Edges(edge, GOLD[1], GOLD[2], GOLD[3])
    edge:SetAlpha(0)
    self.DeckTargetEdge = edge

    local icon = self:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON, ICON)
    icon:SetPoint("LEFT", 2, 0)
    -- round, like the circles sheet: a mask over the icon alone
    local mask = self:CreateMaskTexture()
    mask:SetTexture(D.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
    icon:Hide()
    self.DeckClassIcon = icon

    local left = ICON + 8
    local barWidth = W - left - 6

    local role = self:CreateTexture(nil, "OVERLAY")
    role:SetSize(13, 13)
    role:SetPoint("TOPLEFT", left, -3)
    self.GroupRoleIndicator = role

    local name = self:CreateFontString(nil, "OVERLAY")
    name:SetFont(ns.FONT, 12, "OUTLINE")
    name:SetPoint("TOPLEFT", left + 16, -3)
    name:SetWidth(barWidth - 16 - 56)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    self:Tag(name, "[raidcolor][name]")

    local hp = self:CreateFontString(nil, "OVERLAY")
    hp:SetFont(ns.FONT, 12, "OUTLINE")
    hp:SetPoint("TOPRIGHT", -6, -3)
    hp:SetJustifyH("RIGHT")
    self:Tag(hp, "[deck:partyhp]")

    local health = CreateFrame("StatusBar", nil, self)
    health:SetStatusBarTexture(WHITE)
    health:SetPoint("TOPLEFT", left, -19)
    health:SetSize(barWidth, 9)
    local hbg = health:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetColorTexture(0.12, 0.12, 0.12, 1)
    -- oUF's health colour is a plain green, like FFXIV's bars
    health.colorHealth = true
    health.colorDisconnected = true
    -- the health bar updates for every member, whatever else does: the
    -- class icon rides along
    health.PostUpdate = function(bar) UpdateClassIcon(bar.__owner) end
    self.Health = health

    local power = CreateFrame("StatusBar", nil, self)
    power:SetStatusBarTexture(WHITE)
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -2)
    power:SetSize(barWidth, 3)
    local pbg = power:CreateTexture(nil, "BACKGROUND")
    pbg:SetAllPoints()
    pbg:SetColorTexture(0.12, 0.12, 0.12, 1)
    power.colorPower = true
    self.Power = power

    self.Range = { insideAlpha = 1, outsideAlpha = 0.4 }

    if self.CreateAuras then
        local size, count = 20, 8
        local auras = self:CreateAuras({
            layout        = AnchorUtil.FlowLayoutAxis.Horizontal,
            layoutLimit   = count * (size + 2),
            initialAnchor = "LEFT",
            growthX       = "RIGHT",
            growthY       = "DOWN",
        })
        auras:SetSize(count * (size + 2), size)
        auras.deckRow = self
        partyAuras[#partyAuras + 1] = auras
        auras.size = size
        auras.elementSpacing = 2
        auras.lineSpacing = 2
        auras.showCount = true
        auras.PostCreateButton = StyleAura
        -- every debuff first, dispellable ones with a coloured border;
        -- then the buffs you cast (heals over time, shields)
        auras:AddGroup("HARMFUL", { maxFrameCount = 4, showDebuffBorder = true })
        auras:AddGroup("HELPFUL|PLAYER", { maxFrameCount = 4 })
        table.insert(ns.auraContainers, auras)
    end
end

oUF:RegisterStyle("DeckOrbsParty", BuildRow)

-------------------------------------------------------------------
-- The list
-------------------------------------------------------------------
-- Tanks, healers, then damage, like FFXIV's list. The header hangs off a
-- plain holder that /deck unlock drags (per device); the header itself is
-- secure and never moved by us in combat.
--
-- Stacked (FFXIV's column, auras to the right of each row) or side by
-- side (one row across, auras below each member) - per device. The
-- header's own attributes decide: every change runs Blizzard's
-- SecureGroupHeader_Update, which clears and sets the members' points
-- itself. Attributes of a secure header cannot change in combat, so a
-- switch there waits for the end of it.
local function AuraPoint(auras, across)
    auras:ClearAllPoints()
    if across then
        auras:SetPoint("TOPLEFT", auras.deckRow, "BOTTOMLEFT", 0, -3)
    else
        auras:SetPoint("LEFT", auras.deckRow, "RIGHT", 4, 0)
    end
end

-------------------------------------------------------------------
-- Test mode: five rows of yourself, to see size, layout and place alone
-------------------------------------------------------------------
-- Session only. The rows are ordinary oUF frames for "player" in the
-- party style - secure unit buttons like the real ones, so they appear and
-- go only out of combat. While they show, the real list is hidden, so the
-- two never lie on top of each other in a group.
local VISIBILITY = "custom [group:raid] hide; [group:party] show; hide"
local testFrames = {}

local function LayoutTest(across)
    for i, f in ipairs(testFrames) do
        f:ClearAllPoints()
        if across then
            f:SetPoint("TOPLEFT", ns.partyHolder, "TOPLEFT", (i - 1) * (W + GAP * 2), 0)
        else
            f:SetPoint("TOPLEFT", ns.partyHolder, "TOPLEFT", 0, -(i - 1) * (H + GAP))
        end
    end
end

function ns.SetPartyTest(on)
    if not ns.partyHeader then
        print("DeckUI Orbs: switch the party list on and /reload first.")
        return
    end
    if InCombatLockdown() then print("DeckUI Orbs: party test mode switches after combat.") end
    ns.OutOfCombat("partyTest", function()
        ns.partyTest = on
        if on and #testFrames == 0 then
            oUF:SetActiveStyle("DeckOrbsParty")
            for i = 1, 5 do
                testFrames[i] = oUF:Spawn("player", "DeckOrbsPartyTest" .. i)
            end
        end
        local scale = ns.DeviceDB().partyScale or 1
        for _, f in ipairs(testFrames) do
            f:SetScale(scale)
            if on then
                RegisterUnitWatch(f)
            else
                UnregisterUnitWatch(f)
                f:Hide()
            end
        end
        local across = ns.DeviceDB().partyAcross
        LayoutTest(across)
        -- the new rows' auras too
        for _, auras in ipairs(partyAuras) do AuraPoint(auras, across) end
        ns.partyHeader:SetVisibility(on and "hide" or VISIBILITY)
        print("DeckUI Orbs: party test mode " .. (on and "on - five rows of you." or "off."))
    end)
end

function ns.ApplyPartyLayout()
    local header = ns.partyHeader
    if not header then return end
    local across = ns.DeviceDB().partyAcross
    LayoutTest(across)
    if across then
        ns.partyHolder:SetSize(5 * W + 4 * GAP * 2, H + 24)
    else
        ns.partyHolder:SetSize(W, 5 * H + 4 * GAP)
    end
    for _, auras in ipairs(partyAuras) do AuraPoint(auras, across) end
    ns.OutOfCombat("partyLayout", function()
        -- one re-layout, not three: the last change, made after _ignore is
        -- cleared, is the one that runs it
        header:SetAttribute("_ignore", true)
        header:SetAttribute("point", across and "LEFT" or "TOP")
        header:SetAttribute("xOffset", across and GAP * 2 or 0)
        header:SetAttribute("_ignore", nil)
        header:SetAttribute("yOffset", across and 0 or -GAP)
    end)
end

function ns.ApplyPartyScale()
    if not ns.partyHeader then return end
    local scale = ns.DeviceDB().partyScale or 1
    ns.partyHolder:SetScale(scale)
    ns.OutOfCombat("partyScale", function()
        ns.partyHeader:SetScale(scale)
        for _, f in ipairs(testFrames) do f:SetScale(scale) end
    end)
end

oUF:Factory(function(self)
    if not DeckOrbsDB.showParty then return end
    self:SetActiveStyle("DeckOrbsParty")

    local holder = CreateFrame("Frame", "DeckOrbsPartyHolder", UIParent)
    holder:SetSize(W, 5 * H + 4 * GAP)
    holder.defaultPoint = { "LEFT", UIParent, "LEFT", 24, 80 }
    holder:SetPoint(unpack(holder.defaultPoint))
    D.MakeMovable(holder, "Party", DeckOrbsDB)
    ns.partyHolder = holder

    local header = self:SpawnHeader("DeckOrbsParty", nil,
        "showParty", true,
        "showPlayer", true,
        "showSolo", false,
        "point", "TOP",
        "yOffset", -GAP,
        "groupBy", "ASSIGNEDROLE",
        "groupingOrder", "TANK,HEALER,DAMAGER,NONE",
        "oUF-initialConfigFunction", ("self:SetWidth(%d); self:SetHeight(%d)"):format(W, H))
    -- in a raid Blizzard's raid frames take over
    header:SetVisibility(VISIBILITY)
    header:SetPoint("TOPLEFT", holder, "TOPLEFT")
    ns.partyHeader = header
    ns.ApplyPartyScale()
    ns.ApplyPartyLayout()
end)

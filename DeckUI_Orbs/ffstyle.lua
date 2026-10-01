local ADDON, ns = ...
local D = DeckUI
local oUF = ns.oUF

-------------------------------------------------------------------
-- Player and target in the style of Final Fantasy XIV
-------------------------------------------------------------------
-- The owner's wish (2026-09-30): an alternative to the orbs. FFXIV shows
-- the player as a "parameter bar" - HP and MP as long thin bars with
-- their numbers, no portrait - and the target as one wide bar at the top
-- of the screen: name on the left, health percent on the right, the cast
-- underneath, status icons below that, and its own target beside it.
-- Here in DeckUI's colours: a dark fill with a thin grey edge.
--
-- Chosen with the "Style" button in the Orbs tab (DeckOrbsDB.style,
-- "orbs" or "ff"); it needs a /reload, since oUF styles a frame once when
-- it is spawned. Every Orbs setting that makes sense still applies: size,
-- opacity, health text, cast, auras, own debuffs only, class resources,
-- the target announce. The positions are saved apart from the orbs'
-- ("Player (FF)", "Target (FF)"), so switching back finds them unchanged.
-------------------------------------------------------------------
local WHITE = "Interface\\Buttons\\WHITE8x8"

local PLAYER_W = 260
local TARGET_W = 380
local TOT_W = 140

-- a fill and four one-pixel lines, anchored only (never BackdropTemplate)
local function Panel(frame, alpha)
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, alpha or 0.75)
    local function Line(p1, p2, horizontal)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(0.3, 0.3, 0.3, 1)
        t:SetPoint(p1)
        t:SetPoint(p2)
        if horizontal then t:SetHeight(1) else t:SetWidth(1) end
    end
    Line("TOPLEFT", "TOPRIGHT", true)
    Line("BOTTOMLEFT", "BOTTOMRIGHT", true)
    Line("TOPLEFT", "BOTTOMLEFT", false)
    Line("TOPRIGHT", "BOTTOMRIGHT", false)
end

local function Bar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(WHITE)
    bar:SetSize(width, height)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.12, 0.12, 0.12, 1)
    return bar
end

local function Text(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.FONT, size, "OUTLINE")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function OnEnter(self)
    local unit = self.__unit or self.unit or self:GetAttribute("unit")
    if not unit or not UnitExists(unit) then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    GameTooltip:SetUnit(unit)
    GameTooltip:Show()
end

local function Clicks(self)
    self:RegisterForClicks("AnyUp")
    self:SetScript("OnEnter", OnEnter)
    self:SetScript("OnLeave", GameTooltip_Hide)
end

-- square status icons in one row, like FFXIV's
local function StyleAura(element, button)
    if button.Icon then button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    if button.Count then
        button.Count:SetFont(ns.FONT, 11, "OUTLINE")
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", 2, -2)
    end
end

local function AuraRow(self, width, size, point, relPoint, y)
    local count = math.floor(width / (size + 3))
    local auras = self:CreateAuras({
        layout        = AnchorUtil.FlowLayoutAxis.Horizontal,
        layoutLimit   = count * (size + 3),
        initialAnchor = "LEFT",
        growthX       = "RIGHT",
        growthY       = "DOWN",
    })
    auras:SetSize(count * (size + 3), size)
    auras:SetPoint(point, self, relPoint, 0, y)
    auras.size = size
    auras.elementSpacing = 3
    auras.lineSpacing = 3
    auras.showCount = true
    auras.PostCreateButton = StyleAura
    table.insert(ns.auraContainers, auras)
    return auras, count
end

-------------------------------------------------------------------
-- Class resources: small squares under the MP bar
-------------------------------------------------------------------
local MAX_POINTS = 10

local function PointBars(self, count, width)
    local points = {}
    for i = 1, count do
        local p = Bar(self, 10, 6)
        p:SetMinMaxValues(0, 1)
        p:SetValue(0)
        points[i] = p
    end
    return points
end

-- spread the points that exist over the bar's width
local function LayoutPoints(points, max, width, anchor)
    if not max or max < 1 then return end
    local gap = 3
    local w = (width - (max - 1) * gap) / max
    for i, p in ipairs(points) do
        p:ClearAllPoints()
        if i <= max then
            p:SetWidth(w)
            p:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", (i - 1) * (w + gap), -4)
        end
    end
end

-------------------------------------------------------------------
-- Player: the parameter bar
-------------------------------------------------------------------
-- Two rows like FFXIV's: "HP" with its number over the health bar, "MP"
-- with its number over the resource bar - each number on its own line,
-- never in the gap between the bars (owner's screenshot, 2026-09-30).
oUF.Tags.Methods["deck:ppshort"] = function(unit)
    local pp = UnitPower(unit)
    local ok, text = pcall(AbbreviateNumbers, pp)
    if ok and text then return text end
    return pp
end
oUF.Tags.Events["deck:ppshort"] = "UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER"

-- Blizzard's mana blue (0, 0, 1) is hard to read on a dark panel
local MANA = Enum.PowerType and Enum.PowerType.Mana or 0
local function BrighterMana(element, unit)
    if UnitPowerType(unit) == MANA then element:SetStatusBarColor(0.3, 0.6, 1) end
end

local function Label(self, text, y)
    local fs = Text(self, 11)
    fs:SetPoint("TOPLEFT", 8, y)
    fs:SetText(text)
    fs:SetTextColor(0.7, 0.7, 0.7)
    return fs
end

local function BuildPlayer(self, unit)
    self:SetSize(PLAYER_W, 64)
    Clicks(self)
    Panel(self)

    local inner = PLAYER_W - 16

    Label(self, "HP", -5)
    local hp = Text(self, 13, "RIGHT")
    hp:SetPoint("TOPRIGHT", -8, -4)
    self:Tag(hp, ns.HP_TAGS[DeckOrbsDB.hpText] or ns.HP_TAGS.percent)
    self.hpText = hp

    local health = Bar(self, inner, 8)
    health:SetPoint("TOPLEFT", 8, -19)
    health.colorHealth = true
    self.Health = health

    local ppLabel = Label(self, "MP", -31)
    local pp = Text(self, 13, "RIGHT")
    pp:SetPoint("TOPRIGHT", -8, -30)
    self:Tag(pp, "[deck:ppshort]")

    local power = Bar(self, inner, 5)
    power:SetPoint("TOPLEFT", 8, -45)
    power.colorPower = true
    power.PostUpdateColor = BrighterMana
    -- the label names the resource: MP, or Rage, Energy, ...
    power.PostUpdate = function(element, unitID)
        local _, token = UnitPowerType(unitID)
        local label = "MP"
        if token and token ~= "MANA" then label = _G[token] or token end
        ppLabel:SetText(label)
    end
    self.Power = power

    local points = PointBars(self, MAX_POINTS, inner)
    points.PostUpdate = function(element, cur, max, hasMaxChanged)
        if hasMaxChanged or not element.laidOut then
            element.laidOut = true
            LayoutPoints(element, max, inner, power)
        end
    end
    self.ClassPower = points

    local runes = PointBars(self, 6, inner)
    runes.colorSpec = true
    LayoutPoints(runes, 6, inner, power)
    self.Runes = runes

    -- your cast: a bar right below, with the spell's name on it
    local cast = Bar(self, PLAYER_W, 10)
    cast:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -6)
    cast:SetStatusBarColor(1, 0.85, 0.3)
    local castText = Text(cast, 11)
    castText:SetPoint("LEFT", 4, 0)
    castText:SetWidth(PLAYER_W - 8)
    cast.Text = castText
    self.Castbar = cast

    if self.CreateAuras then
        -- your buffs above the bar, debuffs above them
        local buffs = AuraRow(self, PLAYER_W, 22, "BOTTOMLEFT", "TOPLEFT", 4)
        buffs:AddGroup("HELPFUL", { candidateFilters = { maxDuration = DeckOrbsDB.buffMaxDuration } })
        local debuffs = AuraRow(self, PLAYER_W, 22, "BOTTOMLEFT", "TOPLEFT", 30)
        debuffs:AddGroup("HARMFUL", { showDebuffBorder = true })
    end
end

-------------------------------------------------------------------
-- Target: the wide bar
-------------------------------------------------------------------
local function BuildTarget(self, unit)
    self:SetSize(TARGET_W, 34)
    Clicks(self)
    Panel(self)

    local name = Text(self, 14)
    name:SetPoint("TOPLEFT", 8, -4)
    name:SetWidth(TARGET_W - 90)
    self:Tag(name, "[difficulty][level]|r [raidcolor][name]")

    local hp = Text(self, 14, "RIGHT")
    hp:SetPoint("TOPRIGHT", -8, -4)
    self:Tag(hp, ns.HP_TAGS[DeckOrbsDB.hpText] or ns.HP_TAGS.percent)
    self.hpText = hp

    local health = Bar(self, TARGET_W - 16, 9)
    health:SetPoint("TOPLEFT", 8, -21)
    health.colorClass = true
    health.colorReaction = true
    health.colorTapped = true
    health.colorDisconnected = true
    self.Health = health

    local cast = Bar(self, TARGET_W - 16, 8)
    cast:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 8, -3)
    cast:SetStatusBarColor(1, 0.55, 0.2)
    local castText = Text(cast, 11)
    castText:SetPoint("TOPLEFT", cast, "BOTTOMLEFT", 0, -1)
    castText:SetWidth(TARGET_W - 16)
    castText:SetTextColor(1, 0.85, 0.3)
    cast.Text = castText
    self.Castbar = cast

    if self.CreateAuras then
        -- status icons under the cast: your debuffs (or all of them), then buffs
        local auras = AuraRow(self, TARGET_W, 22, "TOPLEFT", "BOTTOMLEFT", -28)
        local filter = DeckOrbsDB.ownDebuffsOnly and "HARMFUL|PLAYER" or "HARMFUL"
        local key = auras:AddGroup(filter, { maxFrameCount = 8, showDebuffBorder = true })
        table.insert(ns.targetDebuffs, { container = auras, key = key })
        auras:AddGroup("HELPFUL", { maxFrameCount = 6, showStealableBorder = true })
    end
end

-------------------------------------------------------------------
-- Target of target: a small bar beside the target, name after a chevron
-------------------------------------------------------------------
local function BuildToT(self, unit)
    self:SetSize(TOT_W, 34)
    Clicks(self)
    Panel(self, 0.6)

    local name = Text(self, 12)
    name:SetPoint("TOPLEFT", 6, -5)
    name:SetWidth(TOT_W - 12)
    self:Tag(name, "|cffaaaaaa»|r [raidcolor][name]")

    local health = Bar(self, TOT_W - 12, 6)
    health:SetPoint("TOPLEFT", 6, -22)
    health.colorClass = true
    health.colorReaction = true
    self.Health = health
end

-------------------------------------------------------------------
-- Bosses: FFXIV's enemy list
-------------------------------------------------------------------
-- The owner's choice (2026-10-01): compact rows one under the other, like
-- FFXIV's enemy list - raid marker and name, health percent, a thin
-- health bar, whom the boss is targeting; a red strip on the left while
-- that is you (FFXIV's aggro mark), the cast underneath (grey when it
-- cannot be interrupted), your debuffs to the right. Comes with the
-- "Final Fantasy" style, like player and target.
--
-- Secret values: "is it targeting me" is a boolean for the engine
-- (SetAlphaFromBoolean), the target's name goes straight into SetText,
-- the cast's interruptible flag drives oUF's Shield the same way.
local BOSS_W, BOSS_H = 240, 40
local BOSS_STEP = BOSS_H + 22   -- the cast bar hangs below each row
ns.FF_BOSS_STEP = BOSS_STEP

local function UpdateBossTarget(self)
    local unit = self.__unit or self.unit
    if not unit then return end
    local target = unit .. "target"
    self.DeckBossAggro:SetAlphaFromBoolean(UnitIsUnit(target, "player"), 1, 0)
    if UnitExists(target) then
        self.DeckBossTargetName:SetText(UnitName(target))
        self.DeckBossTargetArrow:Show()
    else
        self.DeckBossTargetName:SetText("")
        self.DeckBossTargetArrow:Hide()
    end
end

oUF:AddElement("DeckBossTarget", UpdateBossTarget, function(self)
    if not self.DeckBossAggro then return end
    self:RegisterEvent("UNIT_TARGET", UpdateBossTarget)
    return true
end, function(self)
    if not self.DeckBossAggro then return end
    self:UnregisterEvent("UNIT_TARGET", UpdateBossTarget)
    self.DeckBossAggro:SetAlpha(0)
end)

local function BuildBoss(self, unit)
    self:SetSize(BOSS_W, BOSS_H)
    Clicks(self)
    Panel(self)

    local marker = self:CreateTexture(nil, "OVERLAY")
    marker:SetSize(14, 14)
    marker:SetPoint("TOPLEFT", 8, -4)
    self.RaidTargetIndicator = marker

    local name = Text(self, 13)
    name:SetPoint("TOPLEFT", 26, -4)
    name:SetWidth(BOSS_W - 26 - 60)
    self:Tag(name, "[name]")

    local hp = Text(self, 13, "RIGHT")
    hp:SetPoint("TOPRIGHT", -8, -4)
    self:Tag(hp, ns.HP_TAGS[DeckOrbsDB.hpText] or ns.HP_TAGS.percent)
    self.hpText = hp

    local health = Bar(self, BOSS_W - 16, 6)
    health:SetPoint("TOPLEFT", 8, -21)
    health.colorReaction = true
    health.colorTapped = true
    self.Health = health

    -- whom it is after: "» name" under the bar
    local arrow = Text(self, 10)
    arrow:SetPoint("TOPLEFT", 8, -29)
    arrow:SetText("|cffaaaaaa»|r")
    local targetName = Text(self, 10)
    targetName:SetPoint("LEFT", arrow, "RIGHT", 3, 0)
    targetName:SetWidth(BOSS_W - 30)
    targetName:SetTextColor(0.85, 0.85, 0.85)
    self.DeckBossTargetArrow = arrow
    self.DeckBossTargetName = targetName

    -- FFXIV's aggro mark: a red strip on the left edge while it targets you
    local aggro = self:CreateTexture(nil, "OVERLAY")
    aggro:SetColorTexture(0.9, 0.15, 0.15, 1)
    aggro:SetPoint("TOPLEFT", 1, -1)
    aggro:SetPoint("BOTTOMLEFT", 1, 1)
    aggro:SetWidth(3)
    aggro:SetAlpha(0)
    self.DeckBossAggro = aggro

    local cast = Bar(self, BOSS_W, 12)
    cast:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -3)
    cast:SetStatusBarColor(1, 0.55, 0.2)
    -- cannot be interrupted: a grey veil over the bar (oUF's Shield)
    local shield = cast:CreateTexture(nil, "OVERLAY")
    shield:SetAllPoints()
    shield:SetColorTexture(0.45, 0.45, 0.45, 0.85)
    shield:SetAlpha(0)
    cast.Shield = shield
    local castText = Text(cast, 10)
    castText:SetPoint("LEFT", 4, 0)
    castText:SetWidth(BOSS_W - 8)
    castText:SetDrawLayer("OVERLAY", 7)
    cast.Text = castText
    self.Castbar = cast

    if self.CreateAuras then
        -- your debuffs on it, to the right of the row
        local size = 18
        local auras = self:CreateAuras({
            layout        = AnchorUtil.FlowLayoutAxis.Horizontal,
            layoutLimit   = 4 * (size + 2),
            initialAnchor = "LEFT",
            growthX       = "RIGHT",
            growthY       = "DOWN",
        })
        auras:SetSize(4 * (size + 2), size)
        auras:SetPoint("LEFT", self, "RIGHT", 4, 0)
        auras.size = size
        auras.elementSpacing = 2
        auras.showCount = true
        auras.PostCreateButton = StyleAura
        auras:AddGroup("HARMFUL|PLAYER", { maxFrameCount = 4, showDebuffBorder = true })
        table.insert(ns.auraContainers, auras)
    end
end

oUF:RegisterStyle("DeckFFPlayer", BuildPlayer)
oUF:RegisterStyle("DeckFFTarget", BuildTarget)
oUF:RegisterStyle("DeckFFToT", BuildToT)
oUF:RegisterStyle("DeckFFBoss", BuildBoss)

-- layout.lua's Factory, in the "ff" style: the five boss rows under one
-- movable holder, saved apart from the boss orbs' place.
function ns.SpawnFFBosses(factory)
    factory:SetActiveStyle("DeckFFBoss")
    local holder = CreateFrame("Frame", "DeckFFBossHolder", UIParent)
    holder:SetSize(BOSS_W, 5 * BOSS_STEP)
    holder.defaultPoint = { "RIGHT", UIParent, "RIGHT", -160, 80 }
    holder:SetPoint(unpack(holder.defaultPoint))
    D.MakeMovable(holder, "Boss frames (FF)", DeckOrbsDB)

    local frames = {}
    for i = 1, 5 do
        local boss = factory:Spawn("boss" .. i, "DeckFFBoss" .. i)
        boss:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(i - 1) * BOSS_STEP)
        frames[i] = boss
    end
    return holder, frames
end

-- layout.lua's Factory asks this when the style is "ff": spawn, place,
-- and hand back the frames it keeps for the settings.
function ns.SpawnFF(factory)
    factory:SetActiveStyle("DeckFFPlayer")
    local player = factory:Spawn("player", "DeckFFPlayer")
    player.defaultPoint = { "BOTTOM", UIParent, "BOTTOM", -300, 150 }
    player:SetPoint(unpack(player.defaultPoint))
    D.MakeMovable(player, "Player (FF)", DeckOrbsDB)

    factory:SetActiveStyle("DeckFFTarget")
    local target = factory:Spawn("target", "DeckFFTarget")
    target.defaultPoint = { "TOP", UIParent, "TOP", 0, -90 }
    target:SetPoint(unpack(target.defaultPoint))
    D.MakeMovable(target, "Target (FF)", DeckOrbsDB)

    factory:SetActiveStyle("DeckFFToT")
    local tot = factory:Spawn("targettarget", "DeckFFTargetTarget")
    tot:SetPoint("TOPLEFT", target, "TOPRIGHT", 6, 0)

    return player, target, tot
end

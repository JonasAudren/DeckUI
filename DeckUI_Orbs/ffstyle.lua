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
-- "orbs", "ff" or "ffxiv" - the third further below); it needs a /reload, since oUF styles a frame once when
-- it is spawned. Every Orbs setting that makes sense still applies: size,
-- opacity, health text, cast, auras, own debuffs only, class resources,
-- the target announce. The positions are saved apart from the orbs'
-- ("Player (FF)", "Target (FF)"), so switching back finds them unchanged.
-------------------------------------------------------------------
local WHITE = "Interface\\Buttons\\WHITE8x8"

-- player, target and target of target take their width and bar height
-- from their pages (ns.FrameSizeDB); the pet keeps the old ToT width
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

-- The target's status icons in FFXIV's shapes, like the buff bar's
-- (owner's wish, 2026-10-26): a buff's top rises to a roof, a debuff's
-- bottom falls to a point. One row holds both groups, so the shape is
-- read off the group the button belongs to: debuff groups are the ones
-- with showDebuffBorder (buffs.lua has the masks and the dispel strip).
local function StyleTargetAura(element, button, options)
    StyleAura(element, button)
    local debuff = options and options.showDebuffBorder
    if ns.ShapeStatusIcon then ns.ShapeStatusIcon(button, debuff) end
    if debuff and ns.DispelStrip then ns.DispelStrip(button) end
end

-- fromRight: the row starts at the frame's right edge and grows left (the
-- target's buffs, kept apart from its debuffs - owner 2026-10-28)
local function AuraRow(self, width, size, point, relPoint, y, fromRight, max)
    local count = math.floor(width / (size + 3))
    if max and max < count then count = max end
    local auras = self:CreateAuras({
        layout        = ns.FLOW.Horizontal,
        layoutLimit   = count * (size + 3),
        initialAnchor = fromRight and "RIGHT" or "LEFT",
        growthX       = fromRight and "LEFT" or "RIGHT",
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

-- Status icon lines at a frame, as the Player and Target pages say: each
-- kind below the cast, above the bar or off, from the left edge or (right)
-- from the right edge, where it shares the line of a left-edge kind placed
-- before it - so eight debuffs left and six buffs right never slide into
-- each other (owner 2026-10-28). spec: size, belowY / aboveY (the first
-- line's offset on each side), order (the kinds, nearest the frame first),
-- and per kind { pos, max, right, filter, debuff, stealable, filters,
-- style, register }; register puts the container into ns.targetDebuffs
-- (the own-debuffs switch and debuffs.lua's exclusion). Sets self.DeckBelow /
-- DeckAbove = the outermost line on each side, for whatever else wants to
-- hang there (debuffs.lua).
local function AuraRows(self, width, spec)
    if not self.CreateAuras then return end
    local S = spec.size
    local line, leftOpen, last, lastLine = { below = 0, above = 0 }, {}, {}, { below = -1, above = -1 }
    for _, kind in ipairs(spec.order) do
        local e = spec[kind]
        if e.pos ~= "off" and e.max > 0 then
            local side, right = e.pos, e.right == true
            -- a left-edge kind takes a line of its own; a right-edge kind
            -- shares the open left line, then closes it
            if not right and leftOpen[side] then line[side] = line[side] + 1 end
            local n = line[side]
            local y = side == "below" and (spec.belowY - n * (S + 4)) or (spec.aboveY + n * (S + 4))
            local p, rp = side == "below" and "TOP" or "BOTTOM", side == "below" and "BOTTOM" or "TOP"
            local edge = right and "RIGHT" or "LEFT"
            local c = AuraRow(self, width, S, p .. edge, rp .. edge, y, right, e.max)
            if e.style then c.PostCreateButton = e.style end
            local key = c:AddGroup(e.filter, {
                maxFrameCount = e.max,
                showDebuffBorder = e.debuff,
                showStealableBorder = e.stealable,
                candidateFilters = e.filters,
            })
            if e.register then table.insert(ns.targetDebuffs, { container = c, key = key }) end
            -- the outermost line: a kind sharing a line leaves the left-edge one in charge
            if n > lastLine[side] then last[side], lastLine[side] = c, n end
            if right then
                line[side], leftOpen[side] = n + 1, false
            else
                leftOpen[side] = true
            end
        end
    end
    self.DeckBelow, self.DeckAbove = last.below, last.above
end

-- Your buffs and debuffs at the player bar, as the Player page says
-- (DeckOrbsDB.playerBuffs / playerDebuffs: above the bar, below its cast,
-- or off; the buffs from the right edge; icon size and how many; FFXIV's
-- shapes or plain squares). The buffs come first, nearest the bar, as
-- before the Player page. belowY: where the first line goes under the
-- frame, past whatever cast hangs there. The buff bar (buffs.lua)
-- replaces both.
local function PlayerAuras(self, W, belowY)
    if DeckOrbsDB.buffBar then return end
    local style = DeckOrbsDB.playerAuraShapes and StyleTargetAura or nil
    AuraRows(self, W, {
        size = DeckOrbsDB.playerAuraSize or 22, belowY = belowY, aboveY = 4,
        order = { "buffs", "debuffs" },
        buffs = { pos = DeckOrbsDB.playerBuffs or "above", max = DeckOrbsDB.playerBuffMax or 10,
                  right = DeckOrbsDB.playerBuffsRight == true, filter = "HELPFUL", style = style,
                  filters = { maxDuration = DeckOrbsDB.buffMaxDuration } },
        debuffs = { pos = DeckOrbsDB.playerDebuffs or "above", max = DeckOrbsDB.playerDebuffMax or 8,
                    filter = "HARMFUL", debuff = true, style = style },
    })
end

-- your debuffs under the target of target (DeckOrbsDB.totDebuffs)
local function ToTDebuffs(self, W, y)
    if not (self.CreateAuras and DeckOrbsDB.totDebuffs) then return end
    local auras = AuraRow(self, W, 18, "TOPLEFT", "BOTTOMLEFT", y, false, 6)
    auras.PostCreateButton = StyleTargetAura
    auras:AddGroup("HARMFUL|PLAYER", { maxFrameCount = 6, showDebuffBorder = true })
end

local function BuildPlayer(self, unit)
    local W, hb = ns.FrameSize("player")
    local ph = math.max(3, math.floor(hb * 0.6 + 0.5))   -- the resource bar, thinner
    local powerY = 19 + hb + 18                          -- the MP line sits between the bars
    self:SetSize(W, powerY + ph + 14)
    Clicks(self)
    Panel(self)

    local inner = W - 16

    Label(self, "HP", -5)
    local hp = Text(self, 13, "RIGHT")
    hp:SetPoint("TOPRIGHT", -8, -4)
    self:Tag(hp, ns.HP_TAGS[DeckOrbsDB.hpText] or ns.HP_TAGS.percent)
    self.hpText = hp

    local health = Bar(self, inner, hb)
    health:SetPoint("TOPLEFT", 8, -19)
    health.colorHealth = true
    self.Health = health

    local ppLabel = Label(self, "MP", -(19 + hb + 4))
    local pp = Text(self, 13, "RIGHT")
    pp:SetPoint("TOPRIGHT", -8, -(19 + hb + 3))
    self:Tag(pp, "[deck:ppshort]")

    local power = Bar(self, inner, ph)
    power:SetPoint("TOPLEFT", 8, -powerY)
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
    local cast = Bar(self, W, 10)
    cast:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -6)
    cast:SetStatusBarColor(1, 0.85, 0.3)
    local castText = Text(cast, 11)
    castText:SetPoint("LEFT", 4, 0)
    castText:SetWidth(W - 8)
    cast.Text = castText
    self.Castbar = cast

    PlayerAuras(self, W, -20)   -- below: past the cast bar
end

-- The target's status icons under its cast, in one line: your debuffs (or
-- all of them) from the left edge, its buffs from the right edge - two
-- containers, so each side keeps its place when the other is empty
-- (owner 2026-10-28; before, one row held both and the buffs slid left).
-- Eight debuffs and six buffs fit side by side in either bar's width.
-- Since the Target page (2026-10-28) each has its side (DeckOrbsDB.targetDebuffs /
-- targetBuffs: "below" the cast, "above" the bar, "off"), the buffs from the
-- right edge (targetBuffsRight) or on a line of their own, icon size and
-- counts. self.DeckBelow / DeckAbove name the outermost line on each side,
-- for whatever else wants to hang there (debuffs.lua).
local function TargetAuraRows(self, width)
    AuraRows(self, width, {
        size = DeckOrbsDB.targetAuraSize or 22, belowY = -28, aboveY = 4,   -- under the cast and its text; over the bar
        order = { "debuffs", "buffs" },
        debuffs = { pos = DeckOrbsDB.targetDebuffs or "below", max = DeckOrbsDB.targetDebuffMax or 8,
                    filter = DeckOrbsDB.ownDebuffsOnly and "HARMFUL|PLAYER" or "HARMFUL", debuff = true,
                    style = StyleTargetAura, register = true },
        buffs = { pos = DeckOrbsDB.targetBuffs or "below", max = DeckOrbsDB.targetBuffMax or 6,
                  right = DeckOrbsDB.targetBuffsRight ~= false, filter = "HELPFUL", stealable = true,
                  style = StyleTargetAura },
    })
end

-------------------------------------------------------------------
-- Rank mark: elite, rare or boss before the target's and focus's name
-------------------------------------------------------------------
-- The hub draws the diamond (DeckUI/rankmark.lua); here it sits where the
-- name starts and pushes the name right by its width. self.DeckRank =
-- { mark, name, x, y, width } - width only for names with a fixed width.
local function UpdateRank(self, event, unit)
    local e = self.DeckRank
    local own = self.__unit or self.unit
    if not own or (unit and unit ~= own) then return end
    local shown = e.mark:SetRank(D.UnitRank(own))
    local w = shown and e.mark:GetWidth() + 4 or 0
    e.mark:ClearAllPoints()
    e.mark:SetPoint("CENTER", self, "TOPLEFT", e.x + (w - 4) / 2, e.y - 7)
    e.name:SetPoint("TOPLEFT", self, "TOPLEFT", e.x + w, e.y)
    if e.width then e.name:SetWidth(e.width - w) end
end

oUF:AddElement("DeckRank", UpdateRank, function(self)
    if not self.DeckRank then return end
    if not C_EventUtils or C_EventUtils.IsEventValid("UNIT_CLASSIFICATION_CHANGED") then
        self:RegisterEvent("UNIT_CLASSIFICATION_CHANGED", UpdateRank)
    end
    return true
end, function(self)
    if not self.DeckRank then return end
    if not C_EventUtils or C_EventUtils.IsEventValid("UNIT_CLASSIFICATION_CHANGED") then
        self:UnregisterEvent("UNIT_CLASSIFICATION_CHANGED", UpdateRank)
    end
    self.DeckRank.mark:Hide()
end)

local rankFrames = {}
local function Rank(self, name, x, y, width)
    self.DeckRank = { mark = D.RankMark(self, 13), name = name, x = x, y = y, width = width }
    rankFrames[#rankFrames + 1] = self
end
D.OnRankMarks(function()
    for _, f in ipairs(rankFrames) do UpdateRank(f) end
end)

-------------------------------------------------------------------
-- Target: the wide bar
-------------------------------------------------------------------
local function BuildTarget(self, unit)
    local W, hb = ns.FrameSize("target")
    self:SetSize(W, 21 + hb + 4)
    Clicks(self)
    Panel(self)

    local name = Text(self, 14)
    name:SetPoint("TOPLEFT", 8, -4)
    name:SetWidth(W - 90)
    self:Tag(name, "[difficulty][level]|r [raidcolor][name]")
    Rank(self, name, 8, -4, W - 90)

    local hp = Text(self, 14, "RIGHT")
    hp:SetPoint("TOPRIGHT", -8, -4)
    self:Tag(hp, ns.HP_TAGS[DeckOrbsDB.hpText] or ns.HP_TAGS.percent)
    self.hpText = hp

    local health = Bar(self, W - 16, hb)
    health:SetPoint("TOPLEFT", 8, -21)
    health.colorClass = true
    health.colorReaction = true
    health.colorTapped = true
    health.colorDisconnected = true
    self.Health = health

    local cast = Bar(self, W - 16, 8)
    cast:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 8, -3)
    cast:SetStatusBarColor(1, 0.55, 0.2)
    local castText = Text(cast, 11)
    castText:SetPoint("TOPLEFT", cast, "BOTTOMLEFT", 0, -1)
    castText:SetWidth(W - 16)
    castText:SetTextColor(1, 0.85, 0.3)
    cast.Text = castText
    self.Castbar = cast

    TargetAuraRows(self, W)
end

-------------------------------------------------------------------
-- Target of target: a small bar beside the target, name after a chevron
-------------------------------------------------------------------
local function BuildToT(self, unit)
    local W, hb = ns.FrameSize("tot")
    self:SetSize(W, 22 + hb + 6)
    Clicks(self)
    Panel(self, 0.6)

    local name = Text(self, 12)
    name:SetPoint("TOPLEFT", 6, -5)
    name:SetWidth(W - 12)
    self:Tag(name, "|cffaaaaaa»|r [raidcolor][name]")

    local health = Bar(self, W - 12, hb)
    health:SetPoint("TOPLEFT", 6, -22)
    health.colorClass = true
    health.colorReaction = true
    self.Health = health
    ToTDebuffs(self, W, -4)
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

-------------------------------------------------------------------
-- Pet: a small parameter bar beside yours
-------------------------------------------------------------------
-- It used to stay an orb in this style, and in a vehicle - where oUF puts
-- the vehicle on the player bar and you on the pet frame - a round pink
-- orb sat beside the bars (owner's screenshot, 2026-10-08). Now it is the
-- target-of-target's shape: name, health number, a thin bar in FF green.
local function BuildPet(self, unit)
    self:SetSize(TOT_W, 34)
    Clicks(self)
    Panel(self, 0.6)

    local hp = Text(self, 11, "RIGHT")
    hp:SetPoint("TOPRIGHT", -6, -5)
    self:Tag(hp, "[deck:hpshort]")

    local name = Text(self, 12)
    name:SetPoint("TOPLEFT", 6, -5)
    name:SetPoint("RIGHT", hp, "LEFT", -4, 0)
    self:Tag(name, "[raidcolor][name]")

    local health = Bar(self, TOT_W - 12, 6)
    health:SetPoint("TOPLEFT", 6, -22)
    health.colorHealth = true
    health.colorDisconnected = true
    self.Health = health
end

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
            layout        = ns.FLOW.Horizontal,
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

-------------------------------------------------------------------
-- The third style, "ffxiv": closer to the game itself
-------------------------------------------------------------------
-- The owner's wish (2026-10-09, his screenshot of FFXIV's parameter bar):
-- no box at all - capsule bars with a glossy top and a dark edge, HP and
-- MP side by side, each number large under its bar with a small label,
-- and a line under them with class, level and EXP over a thin EXP bar.
-- The target is one long capsule with name and percent above it.
-- Bosses keep the enemy list above; positions are shared with "ff".
--
-- The round ends are two masks (textures/bar_cap_left|right, made by
-- make-status-masks.py), square at each end of a bar and CLAMPTOWHITE, so
-- a bar of any length keeps round ends instead of a stretched shape.
local CAP_L = "Interface\\AddOns\\DeckUI_Orbs\\textures\\bar_cap_left"
local CAP_R = "Interface\\AddOns\\DeckUI_Orbs\\textures\\bar_cap_right"
local XIV_PLAYER_W = 300
local XIV_TARGET_W = 420
local XIV_TOT_W = 150

-- round both ends of a texture of the bar; grow reaches past the bar (the edge)
local function Caps(bar, height, grow)
    local size = height + 2 * grow
    local l = bar:CreateMaskTexture()
    l:SetTexture(CAP_L, "CLAMPTOWHITE", "CLAMPTOWHITE")
    l:SetSize(size, size)
    l:SetPoint("LEFT", bar, "LEFT", -grow, 0)
    local r = bar:CreateMaskTexture()
    r:SetTexture(CAP_R, "CLAMPTOWHITE", "CLAMPTOWHITE")
    r:SetSize(size, size)
    r:SetPoint("RIGHT", bar, "RIGHT", grow, 0)
    return function(texture)
        texture:AddMaskTexture(l)
        texture:AddMaskTexture(r)
    end
end

local function PillBar(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(WHITE)
    bar:SetSize(width, height)
    local round = Caps(bar, height, 0)
    round(bar:GetStatusBarTexture())

    -- a dark edge one pixel around, the empty track inside it
    local edge = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetTexture(WHITE)
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetVertexColor(0, 0, 0, 0.9)
    Caps(bar, height, 1)(edge)
    local track = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
    track:SetTexture(WHITE)
    track:SetAllPoints()
    track:SetVertexColor(0.1, 0.1, 0.12, 0.85)
    round(track)

    -- the gloss: lighter at the top, darker at the bottom, whatever the colour
    local half = math.max(1, math.floor(height / 2))
    local shine = bar:CreateTexture(nil, "OVERLAY")
    shine:SetTexture(WHITE)
    shine:SetPoint("TOPLEFT")
    shine:SetPoint("TOPRIGHT")
    shine:SetHeight(half)
    shine:SetBlendMode("ADD")
    shine:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.3))
    round(shine)
    local shade = bar:CreateTexture(nil, "OVERLAY")
    shade:SetTexture(WHITE)
    shade:SetPoint("BOTTOMLEFT")
    shade:SetPoint("BOTTOMRIGHT")
    shade:SetHeight(half)
    shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.35), CreateColor(0, 0, 0, 0))
    round(shade)

    bar.edge, bar.track = edge, track
    return bar
end
ns.PillBar = PillBar   -- the enemy list (enemies.lua) wears it too

-- FFXIV's MP is pink; other resources keep their colours
local function PinkMana(element, unit)
    if UnitPowerType(unit) == MANA then element:SetStatusBarColor(0.88, 0.42, 0.68) end
end
ns.PinkMana = PinkMana   -- the party and raid frames in the XIV look too

-- Party and raid in the XIV look (DeckOrbsDB.groupStyle "xiv", owner's wish
-- 2026-10-27: like his player frame): capsule bars without a panel instead
-- of the dark boxes - party.lua and raid.lua ask this
function ns.GroupXIV() return DeckOrbsDB and DeckOrbsDB.groupStyle == "xiv" end

-- "HP" small, the number large beside it, under a bar
local function BarNumber(self, bar, label)
    local small = Text(self, 10)
    small:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 2, -10)
    small:SetTextColor(0.85, 0.85, 0.85)
    small:SetText(label)
    local big = Text(self, 18)
    big:SetPoint("BOTTOMLEFT", small, "BOTTOMRIGHT", 4, -1)
    return small, big
end

-- class, level and EXP on the EXP bar; the player's own, plain numbers.
-- At the level cap the client still hands out a huge UnitXPMax (owner's
-- screenshot: "0/100,000,000" at 90), so the cap is asked for itself.
local function UpdateXP(line, bar, rested, level)
    local class = UnitClass("player") or ""
    level = level or UnitLevel("player")
    local capped = (IsPlayerAtEffectiveMaxLevel and IsPlayerAtEffectiveMaxLevel())
        or (IsXPUserDisabled and IsXPUserDisabled())
        or (GetMaxLevelForPlayerExpansion and level >= GetMaxLevelForPlayerExpansion())
    if capped then
        rested:SetMinMaxValues(0, 1)
        rested:SetValue(0)
        -- at the cap the watched faction takes the bar, as Blizzard's did
        -- (owner's wish 2026-10-09; its reputation bar is parked with it)
        local watched = C_Reputation.GetWatchedFactionData and C_Reputation.GetWatchedFactionData()
        local status = watched and watched.factionID and watched.factionID > 0
            and D.FactionStatus and D.FactionStatus(watched.factionID)
        if status then
            line:SetText(("%s  Lv. %d    %s  %s  %s/%s"):format(class, level, status.name, status.standing,
                BreakUpLargeNumbers(status.cur), BreakUpLargeNumbers(status.max)))
            bar:SetStatusBarColor(status.r, status.g, status.b)
            bar:SetMinMaxValues(0, status.max)
            bar:SetValue(status.cur)
        else
            line:SetText(("%s  Lv. %d    EXP  -/-"):format(class, level))
            bar:SetMinMaxValues(0, 1)
            bar:SetValue(0)
        end
        return
    end
    bar:SetStatusBarColor(0.95, 0.78, 0.3)
    local cur, max = UnitXP("player") or 0, UnitXPMax("player") or 1
    if max <= 0 then max = 1 end
    line:SetText(("%s  Lv. %d    EXP  %s/%s"):format(class, level,
        BreakUpLargeNumbers(cur), BreakUpLargeNumbers(max)))
    bar:SetMinMaxValues(0, max)
    bar:SetValue(cur)
    rested:SetMinMaxValues(0, max)
    rested:SetValue(math.min(max, cur + (GetXPExhaustion() or 0)))
end

-- FFXIV's progress bar (owner's choice 2026-10-09, instead of the bar under
-- the player, DeckOrbsDB.xivCastCenter): in the middle of the screen, the
-- spell's icon on the left, its name over a capsule, the time left large
-- under it. oUF shows and hides the bar; icon and texts are its children,
-- so they go with it. The time is oUF's duration binding - the engine
-- writes it, no number passes through our code.
local CAST_W = 220
local function CenterCast()
    local holder = CreateFrame("Frame", "DeckXIVCastBar", UIParent)
    holder:SetSize(CAST_W + 44, 44)
    holder.defaultPoint = { "CENTER", UIParent, "CENTER", 0, -170 }
    holder:SetPoint(unpack(holder.defaultPoint))
    D.MakeMovable(holder, "Cast bar", DeckOrbsDB)

    local cast = PillBar(holder, CAST_W, 7)
    cast:SetPoint("LEFT", holder, "LEFT", 44, 0)
    cast:SetStatusBarColor(0.92, 0.5, 0.75)

    local edge = cast:CreateTexture(nil, "BACKGROUND")
    edge:SetSize(38, 38)
    edge:SetPoint("RIGHT", cast, "LEFT", -5, 0)
    edge:SetColorTexture(0, 0, 0, 0.9)
    local icon = cast:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", edge, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cast.Icon = icon

    local name = Text(cast, 12)
    name:SetPoint("BOTTOMLEFT", cast, "TOPLEFT", 2, 3)
    name:SetWidth(CAST_W - 4)
    name:SetTextColor(1, 0.9, 0.95)
    cast.Text = name

    local time = Text(cast, 20, "RIGHT")
    time:SetPoint("TOPRIGHT", cast, "BOTTOMRIGHT", -2, -2)
    cast.Time = time
    return cast
end

local function BuildPlayerXIV(self, unit)
    local W, hb = ns.FrameSize("player")
    local half = math.floor((W - 10) / 2)
    self:SetSize(W, 50 + hb)
    Clicks(self)

    local name = Text(self, 12)
    name:SetPoint("TOPLEFT", 2, 0)
    name:SetWidth(W - 4)
    name:SetTextColor(1, 0.82, 0.55)
    self:Tag(name, "[name]")

    local health = PillBar(self, half, hb)
    health:SetPoint("TOPLEFT", 0, -17)
    health.colorHealth = true
    self.Health = health
    local _, hp = BarNumber(self, health, "HP")
    self:Tag(hp, ns.HP_TAGS[DeckOrbsDB.hpText] or ns.HP_TAGS.percent)
    self.hpText = hp

    local power = PillBar(self, half, hb)
    power:SetPoint("TOPRIGHT", 0, -17)
    power.colorPower = true
    power.PostUpdateColor = PinkMana
    local ppLabel, pp = BarNumber(self, power, "MP")
    self:Tag(pp, "[deck:ppshort]")
    -- the label names the resource: MP, or Rage, Energy, ...
    power.PostUpdate = function(element, unitID)
        local _, token = UnitPowerType(unitID)
        local label = "MP"
        if token and token ~= "MANA" then label = _G[token] or token end
        ppLabel:SetText(label)
    end
    self.Power = power

    -- class resources under the numbers
    local anchor = CreateFrame("Frame", nil, self)
    anchor:SetSize(W, 1)
    anchor:SetPoint("TOPLEFT", 0, -(38 + hb))
    local points = PointBars(self, MAX_POINTS, W)
    points.PostUpdate = function(element, cur, max, hasMaxChanged)
        if hasMaxChanged or not element.laidOut then
            element.laidOut = true
            LayoutPoints(element, max, W, anchor)
        end
    end
    self.ClassPower = points
    local runes = PointBars(self, 6, W)
    runes.colorSpec = true
    LayoutPoints(runes, 6, W, anchor)
    self.Runes = runes

    if DeckOrbsDB.xivCastCenter then
        self.Castbar = CenterCast()
    else
        local cast = PillBar(self, W, 6)
        cast:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -6)
        cast:SetStatusBarColor(1, 0.85, 0.3)
        local castText = Text(cast, 11)
        castText:SetPoint("TOPLEFT", cast, "BOTTOMLEFT", 2, -2)
        castText:SetWidth(W - 4)
        cast.Text = castText
        self.Castbar = cast
    end

    -- below: past the cast capsule and its text, or just the gap when the
    -- cast sits in the screen's middle
    PlayerAuras(self, W, DeckOrbsDB.xivCastCenter and -6 or -30)
end

local function BuildTargetXIV(self, unit)
    local W, hb = ns.FrameSize("target")
    self:SetSize(W, 20 + hb)
    Clicks(self)

    local hp = Text(self, 14, "RIGHT")
    hp:SetPoint("TOPRIGHT", -2, 0)
    self:Tag(hp, ns.HP_TAGS[DeckOrbsDB.hpText] or ns.HP_TAGS.percent)
    self.hpText = hp

    local name = Text(self, 14)
    name:SetPoint("TOPLEFT", 2, 0)
    name:SetWidth(W - 90)
    self:Tag(name, "[difficulty]Lv. [level]|r [raidcolor][name]")
    Rank(self, name, 2, 0, W - 90)

    local health = PillBar(self, W, hb)
    health:SetPoint("TOPLEFT", 0, -19)
    health.colorClass = true
    health.colorReaction = true
    health.colorTapped = true
    health.colorDisconnected = true
    self.Health = health

    local cast = PillBar(self, W, 6)
    cast:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -4)
    cast:SetStatusBarColor(1, 0.55, 0.2)
    local castText = Text(cast, 11)
    castText:SetPoint("TOPLEFT", cast, "BOTTOMLEFT", 2, -2)
    castText:SetWidth(W - 4)
    castText:SetTextColor(1, 0.85, 0.3)
    cast.Text = castText
    self.Castbar = cast

    TargetAuraRows(self, W)
end

-- target of target and pet: a name (and the pet's health) over a short
-- capsule; W and hb from the Target of target page for the former
local function BuildSmallXIV(self, withHp, W, hb)
    self:SetSize(W, 21 + hb + 3)
    Clicks(self)
    local name = Text(self, 12)
    name:SetPoint("TOPLEFT", 2, 0)
    if withHp then
        local hp = Text(self, 11, "RIGHT")
        hp:SetPoint("TOPRIGHT", -2, 0)
        self:Tag(hp, "[deck:hpshort]")
        name:SetPoint("RIGHT", hp, "LEFT", -4, 0)
        self:Tag(name, "[raidcolor][name]")
    else
        name:SetWidth(W - 4)
        self:Tag(name, "[raidcolor][name]")
        -- FFXIV's double chevron between the target's bar and this one
        local chevron = Text(self, 20, "CENTER")
        chevron:SetPoint("RIGHT", self, "BOTTOMLEFT", -6, 7)
        chevron:SetText("»")
        chevron:SetTextColor(0.55, 0.8, 1)
    end
    -- level with the target's bar (its centre 24 px down)
    local health = PillBar(self, W, hb)
    health:SetPoint("TOPLEFT", 0, -21)
    return health
end

-- focus: FFXIV's small "FOCUS" box - a label, level and name, a thin
-- capsule, the cast under it
local XIV_FOCUS_W = 220
local function BuildFocusXIV(self, unit)
    local W = XIV_FOCUS_W
    self:SetSize(W, 32)
    Clicks(self)
    local label = Text(self, 9)
    label:SetPoint("TOPLEFT", 2, 0)
    label:SetTextColor(0.75, 0.75, 0.75)
    label:SetText("FOCUS")
    local hp = Text(self, 11, "RIGHT")
    hp:SetPoint("TOPRIGHT", -2, -10)
    self:Tag(hp, "[perhp]%")
    local name = Text(self, 12)
    name:SetPoint("TOPLEFT", 2, -10)
    name:SetPoint("RIGHT", hp, "LEFT", -4, 0)
    self:Tag(name, "[difficulty]Lv. [level]|r [raidcolor][name]")
    Rank(self, name, 2, -10)
    local health = PillBar(self, W, 5)
    health:SetPoint("TOPLEFT", 0, -26)
    health.colorClass = true
    health.colorReaction = true
    health.colorTapped = true
    health.colorDisconnected = true
    self.Health = health
    local cast = PillBar(self, W, 4)
    cast:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -3)
    cast:SetStatusBarColor(1, 0.55, 0.2)
    local castText = Text(cast, 10)
    castText:SetPoint("TOPLEFT", cast, "BOTTOMLEFT", 2, -2)
    castText:SetWidth(W - 4)
    cast.Text = castText
    self.Castbar = cast
end

function ns.SpawnXIVFocus(factory)
    factory:SetActiveStyle("DeckXIVFocus")
    local focus = factory:Spawn("focus", "DeckXIVFocus")
    focus.defaultPoint = { "TOPRIGHT", UIParent, "TOPRIGHT", -260, -140 }
    focus:SetPoint(unpack(focus.defaultPoint))
    D.MakeMovable(focus, "Focus (FF)", DeckOrbsDB)
    return focus
end

local function BuildToTXIV(self, unit)
    local W, hb = ns.FrameSize("tot")
    local health = BuildSmallXIV(self, false, W, hb)
    health.colorClass = true
    health.colorReaction = true
    self.Health = health
    ToTDebuffs(self, W, -4)
end

local function BuildPetXIV(self, unit)
    local health = BuildSmallXIV(self, true, XIV_TOT_W, 6)
    health.colorHealth = true
    health.colorDisconnected = true
    self.Health = health
end

-- FFXIV's EXP bar in place of Blizzard's (owner's wish 2026-10-09: not
-- under the parameter bar but instead of the game's own): class, level and
-- EXP over a thin bar, rested EXP lighter behind it, movable "EXP bar".
-- Blizzard's status tracking bars (EXP, and reputation/honour when watched)
-- are Edit Mode systems, parked under a hidden parent like the buff frames
-- (buffs.lua) - Edit Mode re-applies points, never the parent.
local XIV_EXP_W = 460
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

local function SpawnXIVExpBar()
    local holder = CreateFrame("Frame", "DeckXIVExpBar", UIParent)
    holder:SetSize(XIV_EXP_W, 20)
    holder.defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 0, 6 }
    holder:SetPoint(unpack(holder.defaultPoint))

    local line = Text(holder, 11)
    line:SetPoint("TOPLEFT", 2, 0)
    line:SetWidth(XIV_EXP_W - 4)
    line:SetTextColor(0.85, 0.85, 0.85)
    local rested = PillBar(holder, XIV_EXP_W, 5)
    rested:SetPoint("BOTTOMLEFT", 0, 1)
    rested:SetStatusBarColor(0.35, 0.5, 0.95, 0.6)
    local xp = PillBar(holder, XIV_EXP_W, 5)
    xp:SetPoint("BOTTOMLEFT", 0, 1)
    xp:SetFrameLevel(rested:GetFrameLevel() + 1)
    xp:SetStatusBarColor(0.95, 0.78, 0.3)
    xp.edge:Hide()
    xp.track:Hide()

    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP",
                             "UPDATE_EXHAUSTION", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN",
                             "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" }) do
        pcall(holder.RegisterEvent, holder, event)   -- an event the client lacks is skipped
    end
    holder:SetScript("OnEvent", function(_, event, level)
        -- UnitLevel lags behind the level-up event, which brings the new level
        UpdateXP(line, xp, rested, event == "PLAYER_LEVEL_UP" and level or nil)
    end)
    UpdateXP(line, xp, rested)
    D.MakeMovable(holder, "EXP bar", DeckOrbsDB)

    ns.OutOfCombat("parkStatusBars", function()
        for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
            local frame = _G[name]
            if frame and frame:GetParent() ~= hiddenParent then frame:SetParent(hiddenParent) end
        end
    end)
    return holder
end

oUF:RegisterStyle("DeckFFPlayer", BuildPlayer)
oUF:RegisterStyle("DeckFFTarget", BuildTarget)
-- Bosses in the "ffxiv" look (owner's wish 2026-10-28; "Boss look" on the
-- Orbs page picks it apart from the player's style): the enemy list's
-- rows as capsule bars without a panel, like the XIV player and target.
local function BuildBossXIV(self, unit)
    self:SetSize(BOSS_W, BOSS_H)
    Clicks(self)

    local marker = self:CreateTexture(nil, "OVERLAY")
    marker:SetSize(14, 14)
    marker:SetPoint("TOPLEFT", 4, -2)
    self.RaidTargetIndicator = marker

    local name = Text(self, 13)
    name:SetPoint("TOPLEFT", 22, -2)
    name:SetWidth(BOSS_W - 22 - 60)
    self:Tag(name, "[name]")

    local hp = Text(self, 13, "RIGHT")
    hp:SetPoint("TOPRIGHT", -2, -2)
    self:Tag(hp, ns.HP_TAGS[DeckOrbsDB.hpText] or ns.HP_TAGS.percent)
    self.hpText = hp

    local health = PillBar(self, BOSS_W - 8, 7)
    health:SetPoint("TOPLEFT", 4, -20)
    health.colorReaction = true
    health.colorTapped = true
    self.Health = health

    local arrow = Text(self, 10)
    arrow:SetPoint("TOPLEFT", 4, -29)
    arrow:SetText("|cffaaaaaa»|r")
    local targetName = Text(self, 10)
    targetName:SetPoint("LEFT", arrow, "RIGHT", 3, 0)
    targetName:SetWidth(BOSS_W - 26)
    targetName:SetTextColor(0.85, 0.85, 0.85)
    self.DeckBossTargetArrow = arrow
    self.DeckBossTargetName = targetName

    -- the aggro mark stands just left of the row, there being no panel edge
    local aggro = self:CreateTexture(nil, "OVERLAY")
    aggro:SetColorTexture(0.9, 0.15, 0.15, 1)
    aggro:SetPoint("TOPLEFT", -5, -2)
    aggro:SetPoint("BOTTOMLEFT", -5, 2)
    aggro:SetWidth(3)
    aggro:SetAlpha(0)
    self.DeckBossAggro = aggro

    local cast = PillBar(self, BOSS_W - 8, 6)
    cast:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 4, -2)
    cast:SetStatusBarColor(1, 0.55, 0.2)
    local shield = cast:CreateTexture(nil, "OVERLAY")
    shield:SetAllPoints()
    shield:SetColorTexture(0.45, 0.45, 0.45, 0.85)
    shield:SetAlpha(0)
    cast.Shield = shield
    local castText = Text(cast, 10)
    castText:SetPoint("TOPLEFT", cast, "BOTTOMLEFT", 2, -1)
    castText:SetWidth(BOSS_W - 12)
    castText:SetTextColor(1, 0.85, 0.3)
    cast.Text = castText
    self.Castbar = cast

    if self.CreateAuras then
        local size = 18
        local auras = self:CreateAuras({
            layout        = ns.FLOW.Horizontal,
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
        auras.PostCreateButton = StyleTargetAura
        auras:AddGroup("HARMFUL|PLAYER", { maxFrameCount = 4, showDebuffBorder = true })
        table.insert(ns.auraContainers, auras)
    end
end

oUF:RegisterStyle("DeckXIVBoss", BuildBossXIV)
oUF:RegisterStyle("DeckFFToT", BuildToT)
oUF:RegisterStyle("DeckFFPet", BuildPet)
oUF:RegisterStyle("DeckFFBoss", BuildBoss)
oUF:RegisterStyle("DeckXIVPlayer", BuildPlayerXIV)
oUF:RegisterStyle("DeckXIVTarget", BuildTargetXIV)
oUF:RegisterStyle("DeckXIVToT", BuildToTXIV)
oUF:RegisterStyle("DeckXIVPet", BuildPetXIV)
oUF:RegisterStyle("DeckXIVFocus", BuildFocusXIV)

-- the oUF style for a part ("Player", "Target", "ToT", "Pet") in the style
-- chosen; both Final Fantasy styles count as "ff" for everything else
function ns.IsFFStyle()
    return DeckOrbsDB.style == "ff" or DeckOrbsDB.style == "ffxiv"
end
function ns.FFStyle(part)
    return (DeckOrbsDB.style == "ffxiv" and "DeckXIV" or "DeckFF") .. part
end

-- The bosses' look, a choice of its own (DeckOrbsDB.bossStyle, Orbs page,
-- /reload): "orbs", "ff" (the enemy list on panels) or "xiv" (capsules);
-- "auto" follows the player's style.
function ns.BossLook()
    local s = DeckOrbsDB.bossStyle or "auto"
    if s ~= "auto" then return s end
    if DeckOrbsDB.style == "ffxiv" then return "xiv" end
    if DeckOrbsDB.style == "ff" then return "ff" end
    return "orbs"
end
function ns.BossStyleName()
    return ns.BossLook() == "xiv" and "DeckXIVBoss" or "DeckFFBoss"
end

-- layout.lua's Factory, for the list looks: the five boss rows under one
-- movable holder, saved apart from the boss orbs' place.
function ns.SpawnFFBosses(factory)
    factory:SetActiveStyle(ns.BossStyleName())
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
    factory:SetActiveStyle(ns.FFStyle("Player"))
    local player = factory:Spawn("player", "DeckFFPlayer")
    player.defaultPoint = { "BOTTOM", UIParent, "BOTTOM", -300, 150 }
    player:SetPoint(unpack(player.defaultPoint))
    D.MakeMovable(player, "Player (FF)", DeckOrbsDB)

    factory:SetActiveStyle(ns.FFStyle("Target"))
    local target = factory:Spawn("target", "DeckFFTarget")
    target.defaultPoint = { "TOP", UIParent, "TOP", 0, -90 }
    target:SetPoint(unpack(target.defaultPoint))
    D.MakeMovable(target, "Target (FF)", DeckOrbsDB)

    if DeckOrbsDB.style == "ffxiv" then SpawnXIVExpBar() end

    factory:SetActiveStyle(ns.FFStyle("ToT"))
    local tot = factory:Spawn("targettarget", "DeckFFTargetTarget")
    -- XIV: in the target's line, after the chevrons
    tot:SetPoint("TOPLEFT", target, "TOPRIGHT", DeckOrbsDB.style == "ffxiv" and 30 or 6, 0)

    return player, target, tot
end

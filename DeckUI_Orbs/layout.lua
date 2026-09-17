local ADDON, ns = ...
local D = DeckUI
local oUF = ns.oUF

local function OnEnter(self)
    local unit = self.unit or self:GetAttribute("unit")
    if not unit or not UnitExists(unit) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetUnit(unit)
    GameTooltip:Show()
end

local function OnLeave()
    GameTooltip:Hide()
end

-------------------------------------------------------------------
-- Default settings
-------------------------------------------------------------------
ns.DEFAULTS = {
    alpha           = 1,
    glow            = 0,
    showCast        = true,
    showAuras       = true,
    ownDebuffsOnly  = true,
    showFocus       = true,
    showBoss        = true,
    showClassPower  = true,
    announceTarget  = true,
    buffMaxDuration = 300,
    hpText          = "percent",   -- "percent" | "absolute" | "both"
}

-- Custom tag: abbreviated health (1.2M, 340K). Uses Blizzard's own
-- AbbreviateNumbers, which copes with Midnight's protected values;
-- falls back to the raw number if that ever fails.
oUF.Tags.Methods["deck:hpshort"] = function(unit)
    local hp = UnitHealth(unit)
    local ok, text = pcall(AbbreviateNumbers, hp)
    if ok and text then return text end
    return hp
end
oUF.Tags.Events["deck:hpshort"] = "UNIT_HEALTH UNIT_MAXHEALTH"

-- oUF tag strings for the health text
ns.HP_TAGS = {
    percent  = "[perhp]%",
    absolute = "[curhp]",
    short    = "[deck:hpshort]",
    both     = "[deck:hpshort] ([perhp]%)",
}
ns.HP_TEXT_ORDER = { "percent", "absolute", "short", "both" }
ns.HP_TEXT_NAMES = { percent = "Percent", absolute = "Absolute", short = "Short (1.2M)", both = "Short + %" }

local BUFF_EXCLUDE = {
    -- [1126] = true,
}

-------------------------------------------------------------------
-- Size table
-------------------------------------------------------------------
local SIZES = {
    big = {
        frame = 150, orb = 120, hpFont = 20, nameFont = 16, castFont = 14, castbar = true, dot = 13,
        debuffs = { size = 26, perCol = 3, cols = 2 },
        buffs   = { size = 20, perCol = 3, cols = 2 },
    },
    medium = {
        frame = 100, orb = 80, hpFont = 16, nameFont = 14, castFont = 12, castbar = true,
        debuffs = { size = 22, perCol = 3, cols = 2 },
        buffs   = { size = 18, perCol = 3, cols = 1 },
    },
    small = {
        frame = 64, orb = 56, hpFont = 13, nameFont = 12, castFont = 0, castbar = false,
    },
    boss = {
        frame = 84, orb = 66, hpFont = 14, nameFont = 12, castFont = 11, castbar = true,
    },
}
local BOSS_SPACING = 16   -- gap between boss orbs (the name sits above, the cast text below)

-------------------------------------------------------------------
-- Auras
-------------------------------------------------------------------
ns.auraContainers = {}
ns.targetDebuffs  = {}

local function StyleAuraButton(element, button, options)
    local mask = button:CreateMaskTexture()
    mask:SetTexture(ns.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(button)

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 1)
    bg:AddMaskTexture(mask)

    if button.Icon then
        button.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        button.Icon:AddMaskTexture(mask)
    end
    if button.Cooldown then
        button.Cooldown:SetSwipeTexture(ns.DISC)
        button.Cooldown:SetUseCircularEdge(true)
    end
    if button.Count then
        button.Count:SetFont(ns.FONT, 12, "OUTLINE")
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", 3, -3)
    end
end

local function CreateAuras(self, cfg, left, xOffset, filter, groupOptions)
    local step   = cfg.size + 4
    local height = cfg.perCol * step
    local width  = cfg.cols   * step

    local auras = self:CreateAuras({
        layout        = AnchorUtil.FlowLayoutAxis.Vertical,
        layoutLimit   = height,
        initialAnchor = left and "TOPRIGHT" or "TOPLEFT",
        growthX       = left and "LEFT" or "RIGHT",
        growthY       = "DOWN",
    })
    auras:SetSize(width, height)
    if left then
        auras:SetPoint("TOPRIGHT", self, "TOPLEFT", -xOffset, 0)
    else
        auras:SetPoint("TOPLEFT", self, "TOPRIGHT", xOffset, 0)
    end

    auras.size            = cfg.size
    auras.elementSpacing  = 4
    auras.lineSpacing     = 4
    auras.maxFrameCount   = cfg.perCol * cfg.cols
    auras.showCount       = true
    auras.PostCreateButton = StyleAuraButton

    local key = auras:AddGroup(filter, groupOptions)
    table.insert(ns.auraContainers, auras)
    return auras, key
end

-------------------------------------------------------------------
-- Class resource dots (combo points, holy power, runes, ...) in an
-- arc along the bottom of the player orb
-------------------------------------------------------------------
local MAX_DOTS = 10

local function LayoutDots(dots, max, orbSize)
    local radius = orbSize / 2 + 9
    local a0, a1 = -150, -30           -- degrees, bottom arc
    for i, dot in ipairs(dots) do
        if i <= max then
            local a = (max == 1) and -90 or (a0 + (a1 - a0) * (i - 1) / (max - 1))
            local r = math.rad(a)
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", dot:GetParent(), "CENTER", math.cos(r) * radius, math.sin(r) * radius)
        end
    end
end

local function CreateDots(self, s, count)
    local dots = {}
    for i = 1, count do
        local bar = CreateFrame("StatusBar", nil, self.Health)
        bar:SetSize(s.dot, s.dot)
        bar:SetFrameLevel(self.Health:GetFrameLevel() + 4)
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)

        local mask = bar:CreateMaskTexture()
        mask:SetTexture(ns.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(bar)
        bar:GetStatusBarTexture():AddMaskTexture(mask)

        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(ns.DISC)
        bg:SetVertexColor(0.12, 0.12, 0.12, 0.9)
        bar.bg = bg
        dots[i] = bar
    end
    return dots
end

-------------------------------------------------------------------
-- Frame builder
-------------------------------------------------------------------
local function BuildOrb(self, unit, s)
    self:SetSize(s.frame, s.frame)
    self:RegisterForClicks("AnyUp")
    self:SetScript("OnEnter", OnEnter)
    self:SetScript("OnLeave", OnLeave)

    local Power = ns.CreateRing(self, s.frame)
    Power.colorPower = true
    self.Power = Power

    local Health = ns.CreateOrb(self, s.orb)
    Health.colorClass = true
    Health.colorReaction = true
    self.Health = Health

    local topLevel = Health:GetFrameLevel()
    if s.castbar then
        local Castbar = ns.CreateCastOverlay(Health, s.orb)
        local castText = Castbar:CreateFontString(nil, "OVERLAY")
        castText:SetFont(ns.FONT, s.castFont, "OUTLINE")
        castText:SetPoint("TOP", self, "BOTTOM", 0, -2)
        castText:SetTextColor(1, 0.85, 0.3)
        Castbar.Text = castText
        self.Castbar = Castbar
        topLevel = Castbar:GetFrameLevel()
    end

    local textLayer = CreateFrame("Frame", nil, Health)
    textLayer:SetAllPoints(Health)
    textLayer:SetFrameLevel(topLevel + 1)

    local hp = textLayer:CreateFontString(nil, "OVERLAY")
    hp:SetFont(ns.FONT, s.hpFont, "OUTLINE")
    hp:SetPoint("CENTER")
    hp:SetWidth(s.orb - 4)
    hp:SetWordWrap(false)
    self:Tag(hp, ns.HP_TAGS[DeckOrbsDB.hpText] or ns.HP_TAGS.percent)
    self.hpText = hp

    local name = self:CreateFontString(nil, "OVERLAY")
    name:SetFont(ns.FONT, s.nameFont, "OUTLINE")
    if s.castbar then
        name:SetPoint("BOTTOM", self, "TOP", 0, 4)
    else
        name:SetPoint("TOP", self, "BOTTOM", 0, -2)
    end
    self:Tag(name, "[name]")

    if unit == "player" and s.dot then
        -- generic class power (combo points, holy power, chi, essence, soul shards, arcane charges)
        local cp = CreateDots(self, s, MAX_DOTS)
        cp.PostUpdate = function(element, cur, max, hasMaxChanged)
            if hasMaxChanged or not element.laidOut then
                element.laidOut = true
                LayoutDots(element, max or 0, s.orb)
            end
        end
        self.ClassPower = cp

        -- death knight runes
        local runes = CreateDots(self, s, 6)
        runes.colorSpec = true
        LayoutDots(runes, 6, s.orb)
        self.Runes = runes
    end

    if not self.CreateAuras then
        print("DeckUI Orbs: oUF is too old for auras - please update oUF.")
        return
    end

    local left = (unit == "player")
    local offset = 4

    if s.debuffs then
        local filter = "HARMFUL"
        if unit ~= "player" and DeckOrbsDB.ownDebuffsOnly then
            filter = "HARMFUL|PLAYER"
        end
        local container, key = CreateAuras(self, s.debuffs, left, offset, filter)
        if unit ~= "player" then
            table.insert(ns.targetDebuffs, { container = container, key = key })
        end
        offset = offset + s.debuffs.cols * (s.debuffs.size + 4) + 4
    end

    if s.buffs then
        CreateAuras(self, s.buffs, left, offset, "HELPFUL", {
            candidateFilters = {
                maxDuration     = DeckOrbsDB.buffMaxDuration,
                excludeSpellIDs = BUFF_EXCLUDE,
            },
        })
    end
end

oUF:RegisterStyle("DeckOrbsBig",    function(self, unit) BuildOrb(self, unit, SIZES.big)    end)
oUF:RegisterStyle("DeckOrbsMedium", function(self, unit) BuildOrb(self, unit, SIZES.medium) end)
oUF:RegisterStyle("DeckOrbsSmall",  function(self, unit) BuildOrb(self, unit, SIZES.small)  end)
oUF:RegisterStyle("DeckOrbsBoss",   function(self, unit) BuildOrb(self, unit, SIZES.boss)   end)

-------------------------------------------------------------------
-- Apply settings
-------------------------------------------------------------------
ns.frames = {}
ns.units  = {}

function ns.SetAlpha(value)
    DeckOrbsDB.alpha = value
    for _, frame in ipairs(ns.frames) do frame:SetAlpha(value) end
end

-- scale is a per-device setting (Deck screen vs PC monitor)
function ns.DeviceDB() return D.DeviceDB(DeckOrbsDB) end

function ns.SetScale(value)
    ns.DeviceDB().scale = value
    for _, frame in ipairs(ns.frames) do frame:SetScale(value) end
end

function ns.SetCastShown(state)
    DeckOrbsDB.showCast = state
    for _, frame in ipairs(ns.frames) do
        if frame.Castbar then
            if state then frame:EnableElement("Castbar") else frame:DisableElement("Castbar") end
        end
    end
end

function ns.SetAurasShown(state)
    DeckOrbsDB.showAuras = state
    for _, container in ipairs(ns.auraContainers) do
        container:SetEnabled(state)
    end
end

function ns.SetOwnDebuffsOnly(state)
    DeckOrbsDB.ownDebuffsOnly = state
    local filter = state and "HARMFUL|PLAYER" or "HARMFUL"
    for _, entry in ipairs(ns.targetDebuffs) do
        local ok = pcall(entry.container.SetAuraGroupFilterString, entry.container, entry.key, filter)
        if not ok then
            print("DeckUI Orbs: debuff filter takes effect after /reload.")
            return
        end
    end
end

function ns.SetFocusShown(state)
    DeckOrbsDB.showFocus = state
    local focus = ns.units.focus
    if not focus then return end
    if state then focus:Enable() else focus:Disable() end
end

function ns.SetHpText(mode)
    DeckOrbsDB.hpText = mode
    local tag = ns.HP_TAGS[mode] or ns.HP_TAGS.percent
    for _, frame in ipairs(ns.frames) do
        if frame.hpText then
            frame:Untag(frame.hpText)
            frame:Tag(frame.hpText, tag)
            frame.hpText:UpdateTag()
        end
    end
end

function ns.CycleHpText()
    local cur = DeckOrbsDB.hpText or "percent"
    for i, v in ipairs(ns.HP_TEXT_ORDER) do
        if v == cur then
            ns.SetHpText(ns.HP_TEXT_ORDER[(i % #ns.HP_TEXT_ORDER) + 1])
            return
        end
    end
    ns.SetHpText("percent")
end

function ns.SetBossShown(state)
    DeckOrbsDB.showBoss = state
    for _, frame in ipairs(ns.bossFrames or {}) do
        if state then frame:Enable() else frame:Disable() end
    end
    if ns.bossHider then
        if state then ns.HideBlizzardBoss() else ns.ShowBlizzardBoss() end
    end
end

function ns.SetClassPowerShown(state)
    DeckOrbsDB.showClassPower = state
    local player = ns.units.player
    if not player then return end
    for _, el in ipairs({ "ClassPower", "Runes" }) do
        if player[el] then
            if state then player:EnableElement(el) else player:DisableElement(el) end
            for _, dot in ipairs(player[el]) do dot:SetShown(state and dot:IsShown()) end
        end
    end
    if state then player:UpdateAllElements("DeckUI") end
end

function ns.SetAnnounceTarget(state)
    DeckOrbsDB.announceTarget = state
end

function ns.SetBuffMaxDuration(value)
    DeckOrbsDB.buffMaxDuration = value
end

function ns.ApplyAllSettings()
    ns.SetScale(ns.DeviceDB().scale or 1)
    ns.SetAlpha(DeckOrbsDB.alpha)
    ns.SetGlow(DeckOrbsDB.glow)
    ns.SetCastShown(DeckOrbsDB.showCast)
    ns.SetAurasShown(DeckOrbsDB.showAuras)
    ns.SetFocusShown(DeckOrbsDB.showFocus)
    ns.SetBossShown(DeckOrbsDB.showBoss)
    ns.SetClassPowerShown(DeckOrbsDB.showClassPower)
end

-------------------------------------------------------------------
-- Target announce: big name above the target orb for a moment after
-- every target change (easy to miss on the Deck when cycling targets)
-------------------------------------------------------------------
local announce = CreateFrame("Frame", "DeckOrbsAnnounce", UIParent)
announce:SetSize(320, 40)
announce:SetFrameStrata("HIGH")
announce:Hide()
local announceText = announce:CreateFontString(nil, "OVERLAY")
announceText:SetFont(ns.FONT, 26, "OUTLINE")
announceText:SetPoint("CENTER")
local announceToken = 0

local function AnnounceTarget()
    if not DeckOrbsDB.announceTarget or not UnitExists("target") then
        announce:Hide()
        return
    end
    local name = UnitName("target") or ""
    local r, g, b = 1, 1, 1
    if UnitIsPlayer("target") then
        local _, class = UnitClass("target")
        local c = class and RAID_CLASS_COLORS[class]
        if c then r, g, b = c.r, c.g, c.b end
    else
        local reaction = UnitReaction("target", "player")
        if reaction then
            local c = FACTION_BAR_COLORS[reaction]
            if c then r, g, b = c.r, c.g, c.b end
        end
    end
    announceText:SetText(name)
    announceText:SetTextColor(r, g, b)
    announce:SetAlpha(1)
    announce:Show()
    announceToken = announceToken + 1
    local token = announceToken
    C_Timer.After(1.0, function()
        if token == announceToken and announce:IsShown() then
            UIFrameFadeOut(announce, 0.6, 1, 0)
            C_Timer.After(0.7, function() if token == announceToken then announce:Hide() end end)
        end
    end)
end

local announceEv = CreateFrame("Frame")
announceEv:RegisterEvent("PLAYER_TARGET_CHANGED")
announceEv:SetScript("OnEvent", AnnounceTarget)

-------------------------------------------------------------------
-- Blizzard boss frames: reparented to a hidden frame while ours are on
-------------------------------------------------------------------
ns.bossHider = CreateFrame("Frame", "DeckOrbsBossHider", UIParent)
ns.bossHider:Hide()

local function BlizzardBossFrames()
    local list = {}
    if BossTargetFrameContainer then
        table.insert(list, BossTargetFrameContainer)
    else
        for i = 1, 5 do
            local f = _G["Boss" .. i .. "TargetFrame"]
            if f then table.insert(list, f) end
        end
    end
    return list
end

function ns.HideBlizzardBoss()
    if InCombatLockdown() then return end
    for _, f in ipairs(BlizzardBossFrames()) do
        if not f.DeckOrigParent then f.DeckOrigParent = f:GetParent() end
        f:SetParent(ns.bossHider)
    end
end

function ns.ShowBlizzardBoss()
    if InCombatLockdown() then return end
    for _, f in ipairs(BlizzardBossFrames()) do
        if f.DeckOrigParent then f:SetParent(f.DeckOrigParent) end
    end
end

-------------------------------------------------------------------
-- Create frames
-------------------------------------------------------------------
oUF:Factory(function(self)
    DeckOrbsDB = DeckOrbsDB or {}
    for k, v in pairs(ns.DEFAULTS) do
        if DeckOrbsDB[k] == nil then DeckOrbsDB[k] = v end
    end
    D.MigrateToDevice(DeckOrbsDB, { "scale" })
    ns.GLOW = DeckOrbsDB.glow

    self:SetActiveStyle("DeckOrbsBig")

    local player = self:Spawn("player", "DeckOrbsPlayer")
    player.defaultPoint = { "BOTTOM", UIParent, "BOTTOM", -260, 140 }
    player:SetPoint(unpack(player.defaultPoint))
    D.MakeMovable(player, "Player", DeckOrbsDB)

    local target = self:Spawn("target", "DeckOrbsTarget")
    target.defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 260, 140 }
    target:SetPoint(unpack(target.defaultPoint))
    D.MakeMovable(target, "Target", DeckOrbsDB)

    self:SetActiveStyle("DeckOrbsMedium")

    local focus = self:Spawn("focus", "DeckOrbsFocus")
    focus.defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 0, 320 }
    focus:SetPoint(unpack(focus.defaultPoint))
    D.MakeMovable(focus, "Focus", DeckOrbsDB)

    self:SetActiveStyle("DeckOrbsSmall")

    local tot = self:Spawn("targettarget", "DeckOrbsTargetTarget")
    tot:SetFrameLevel(30)
    tot:SetPoint("CENTER", target, "CENTER", 55, -45)

    local pet = self:Spawn("pet", "DeckOrbsPet")
    pet:SetFrameLevel(30)
    pet:SetPoint("CENTER", player, "CENTER", -55, -45)

    -- boss orbs: a column on the right side, anchored to one movable holder
    self:SetActiveStyle("DeckOrbsBoss")
    local bossHolder = CreateFrame("Frame", "DeckOrbsBossHolder", UIParent)
    local bs = SIZES.boss.frame
    bossHolder:SetSize(bs, 5 * bs + 4 * BOSS_SPACING)
    bossHolder.defaultPoint = { "RIGHT", UIParent, "RIGHT", -120, 60 }
    bossHolder:SetPoint(unpack(bossHolder.defaultPoint))
    D.MakeMovable(bossHolder, "Boss frames", DeckOrbsDB)
    ns.bossHolder = bossHolder

    ns.bossFrames = {}
    for i = 1, 5 do
        local boss = self:Spawn("boss" .. i, "DeckOrbsBoss" .. i)
        boss:SetPoint("TOP", bossHolder, "TOP", 0, -(i - 1) * (bs + BOSS_SPACING))
        ns.bossFrames[i] = boss
    end

    announce:SetPoint("BOTTOM", target, "TOP", 0, 26)

    ns.frames = { player, target, focus, tot, pet, unpack(ns.bossFrames) }
    ns.units  = { player = player, target = target, focus = focus, tot = tot, pet = pet }

    ns.ApplyAllSettings()
end)

-- Shortcut: opens the Orbs tab directly
SLASH_DECKORBS1 = "/orbs"
SlashCmdList.DECKORBS = function()
    D.ToggleConfig("Orbs")
end

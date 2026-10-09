local ADDON, ns = ...
local D = DeckUI
local oUF = ns.oUF

-------------------------------------------------------------------
-- The enemy list, as FFXIV shows it
-------------------------------------------------------------------
-- The owner's wish (2026-10-09, his annotated FFXIV screenshot): the
-- enemies fighting you or your group, one row each - a square that turns
-- red while the enemy targets you, its raid marker, its name and a thin
-- health bar; your current target lit. DeckOrbsDB.enemyList, off by
-- default, switched without a reload; movable "Enemy list".
--
-- A list to read, not to click: targeting a unit from a click needs a
-- secure unit button, and a secure button's unit cannot change in combat -
-- exactly when the rows come and go. The enemies are the nameplate units
-- (nameplate1..40), so the list knows what the game has a nameplate for:
-- enemy nameplates must be on (Options > Interface > Nameplates).
--
-- Secret values: names and health go straight to SetText / the StatusBar;
-- "targets me" and "is my target" are booleans for the engine
-- (SetAlphaFromBoolean). The filter needs plain answers - whatever the game
-- keeps secret counts as "show it" rather than hiding an enemy.
-------------------------------------------------------------------
local W, ROW_H, MAX_ROWS = 210, 26, 8
local POLL = 0.15
local HOSTILE = { 0.9, 0.35, 0.3 }
local TAPPED = { 0.5, 0.5, 0.5 }
local GROUP = { "player", "party1", "party2", "party3", "party4" }

local function Secret(v) return issecretvalue and issecretvalue(v) end
-- a plain answer, or nil when the game keeps it secret
local function Ask(v)
    if Secret(v) then return nil end
    return v
end

-- in the fight with you or your group?
local function Engaged(unit)
    if Ask(UnitCanAttack("player", unit)) == false then return false end
    if Ask(UnitIsDead(unit)) == true then return false end
    if IsInRaid() then
        -- forty threat tables per enemy is too much to ask ten times a second
        return Ask(UnitAffectingCombat(unit)) ~= false
    end
    for _, member in ipairs(GROUP) do
        if UnitExists(member) then
            local threat = UnitThreatSituation(member, unit)
            if Secret(threat) or threat ~= nil then return true end
        end
    end
    return false
end

-------------------------------------------------------------------
-- The rows
-------------------------------------------------------------------
local holder = CreateFrame("Frame", "DeckOrbsEnemyList", UIParent)
holder:SetSize(W, MAX_ROWS * (ROW_H + 2))
holder.defaultPoint = { "LEFT", UIParent, "LEFT", 20, 0 }
holder:SetPoint(unpack(holder.defaultPoint))
holder:Hide()

local function Text(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.FONT, size, "OUTLINE")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local rows = {}
for i = 1, MAX_ROWS do
    local row = CreateFrame("Frame", nil, holder)
    row:SetSize(W, ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * (ROW_H + 2))
    row:Hide()

    local band = row:CreateTexture(nil, "BACKGROUND")
    band:SetAllPoints()
    band:SetColorTexture(0, 0, 0, 0.45)
    -- your target, as FFXIV marks it: a warm band, a gold frame all round
    -- and a pointer on the left (the first version - a faint band and a
    -- thin edge - was too weak to see, owner 2026-10-09). All of it hangs
    -- off one frame whose alpha comes from a possibly secret boolean.
    local lit = CreateFrame("Frame", nil, row)
    lit:SetAllPoints()
    lit:SetFrameLevel(row:GetFrameLevel())
    local glow = lit:CreateTexture(nil, "BACKGROUND", nil, 1)
    glow:SetAllPoints()
    glow:SetColorTexture(1, 0.7, 0.25, 0.35)
    for _, p in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                         { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = lit:CreateTexture(nil, "BORDER")
        t:SetColorTexture(1, 0.82, 0.3, 1)
        t:SetPoint(p[1])
        t:SetPoint(p[2])
        if p[3] then t:SetHeight(1) else t:SetWidth(1) end
    end
    local pointer = lit:CreateFontString(nil, "OVERLAY")
    pointer:SetFont(ns.FONT, 16, "OUTLINE")
    pointer:SetPoint("RIGHT", lit, "LEFT", -2, 0)
    pointer:SetTextColor(1, 0.82, 0.3)
    pointer:SetText(">")
    row.lit = lit

    -- FFXIV's aggro square: grey, red while the enemy targets you
    local square = row:CreateTexture(nil, "ARTWORK")
    square:SetSize(10, 10)
    square:SetPoint("LEFT", 6, 0)
    square:SetColorTexture(0.35, 0.35, 0.35, 1)
    local aggro = row:CreateTexture(nil, "ARTWORK", nil, 1)
    aggro:SetAllPoints(square)
    aggro:SetColorTexture(0.95, 0.2, 0.2, 1)
    row.aggro = aggro

    local marker = row:CreateTexture(nil, "OVERLAY")
    marker:SetSize(13, 13)
    marker:SetPoint("TOPLEFT", 22, -3)
    marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    marker:Hide()
    row.marker = marker

    local name = Text(row, 12)
    name:SetPoint("TOPLEFT", 22, -3)
    name:SetPoint("RIGHT", -6, 0)
    row.name = name

    local bar = ns.PillBar(row, W - 28, 4)
    bar:SetPoint("BOTTOMLEFT", 22, 5)
    row.bar = bar

    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if not self.unit then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetUnit(self.unit)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    rows[i] = row
end

local function Fill(row, unit)
    row.unit = unit
    row.name:SetText(UnitName(unit))
    row.bar:SetMinMaxValues(0, UnitHealthMax(unit))
    row.bar:SetValue(UnitHealth(unit))
    local c = Ask(UnitIsTapDenied(unit)) and TAPPED or HOSTILE
    row.bar:SetStatusBarColor(c[1], c[2], c[3])
    row.aggro:SetAlphaFromBoolean(UnitIsUnit(unit .. "target", "player"), 1, 0)
    row.lit:SetAlphaFromBoolean(UnitIsUnit(unit, "target"), 1, 0)
    local index = Ask(GetRaidTargetIndex(unit))
    if index then
        SetRaidTargetIconTexture(row.marker, index)
        row.marker:Show()
        row.name:SetPoint("TOPLEFT", 38, -3)
    else
        row.marker:Hide()
        row.name:SetPoint("TOPLEFT", 22, -3)
    end
    row:Show()
end

-------------------------------------------------------------------
-- Which enemies, in the order they joined the fight
-------------------------------------------------------------------
local joined = {}     -- nameplate token -> order it entered the list
local counter = 0
local list = {}
local preview = false

local function ByJoin(a, b) return joined[a] < joined[b] end

local function Update()
    if preview then return end
    wipe(list)
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and Engaged(unit) then
            if not joined[unit] then
                counter = counter + 1
                joined[unit] = counter
            end
            list[#list + 1] = unit
        else
            joined[unit] = nil
        end
    end
    table.sort(list, ByJoin)
    for i, row in ipairs(rows) do
        if list[i] then Fill(row, list[i]) else row.unit = nil; row:Hide() end
    end
end

local driver = CreateFrame("Frame")
local elapsed = 0
local function Tick(_, dt)
    elapsed = elapsed + dt
    if elapsed < POLL then return end
    elapsed = 0
    Update()
end
-- a plate given to another unit keeps its token: start that one afresh
-- a new target lights at once, not on the next poll
driver:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        Update()
    elseif unit then
        joined[unit] = nil
    end
end)

local function ShowPreview(on)
    preview = on
    if not on then
        Update()
        return
    end
    for i, row in ipairs(rows) do
        if i <= 3 then
            row.unit = nil
            row.name:SetText("Enemy " .. i)
            row.bar:SetMinMaxValues(0, 100)
            row.bar:SetValue(100 - i * 25)
            row.bar:SetStatusBarColor(HOSTILE[1], HOSTILE[2], HOSTILE[3])
            row.aggro:SetAlpha(i == 1 and 1 or 0)
            row.lit:SetAlpha(i == 2 and 1 or 0)
            row.marker:Hide()
            row.name:SetPoint("TOPLEFT", 22, -3)
            row:Show()
        else
            row:Hide()
        end
    end
end

function ns.SetEnemyList(on)
    DeckOrbsDB.enemyList = on and true or false
    if on then
        driver:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        driver:RegisterEvent("PLAYER_TARGET_CHANGED")
        driver:SetScript("OnUpdate", Tick)
        holder:Show()
        Update()
    else
        driver:UnregisterAllEvents()
        driver:SetScript("OnUpdate", nil)
        wipe(joined)
        holder:Hide()
    end
end

oUF:Factory(function()
    D.MakeMovable(holder, "Enemy list", DeckOrbsDB)
    ns.SetEnemyList(DeckOrbsDB.enemyList)
    -- unlocked, three sample rows show where the list sits
    D.OnUnlock(function(state, only)
        if only and not only["Enemy list"] then state = false end
        ShowPreview(state and DeckOrbsDB.enemyList and true or false)
    end)
end)

-- /orbs enemies: what the filter sees for every nameplate unit - which
-- answers are plain, which secret - for when an enemy is missing or extra
local function Show(v)
    if Secret(v) then return "secret" end
    return tostring(v)
end

function ns.EnemyDebug()
    print(("DeckUI enemy list: %s, %d in the list, raid %s."):format(
        DeckOrbsDB.enemyList and "on" or "off", #list, tostring(IsInRaid())))
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) then
            print(("  %s: attackable %s, dead %s, combat %s, threat %s, listed %s"):format(unit,
                Show(UnitCanAttack("player", unit)), Show(UnitIsDead(unit)),
                Show(UnitAffectingCombat(unit)), Show(UnitThreatSituation("player", unit)),
                tostring(joined[unit] ~= nil)))
        end
    end
end

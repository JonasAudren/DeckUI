local ADDON, ns = ...
local D = DeckUI
local oUF = ns.oUF

-------------------------------------------------------------------
-- Your debuffs, one capsule each, as FFXIV would draw them
-------------------------------------------------------------------
-- The owner's wish (2026-10-28): a class needs its own view of what it
-- keeps up - a warlock's DoTs, a rogue's poisons. A window of its own
-- (movable "Debuffs"): a column for your target and a smaller one for
-- your focus, for DoTs on two enemies. DeckOrbsDB.dotTracker, off by
-- default, switched without a reload; /orbs dots prints what it sees.
--
-- Each row has a fixed place, from a list per specialization (below), so
-- the eye finds "Corruption" where it was. A debuff missing from the
-- target is an empty capsule with a red edge - the point of the window -
-- but only while you are in combat: out of it, only what runs is shown.
-- The last 30% of a debuff's time (where a refresh loses nothing) turns
-- the bar gold; a thin tick marks where that starts. Your other debuffs
-- on the target follow below the list. A rogue also sees his weapon
-- poisons - buffs on himself, red when one is missing.
--
-- Rows show only for what you know (IsPlayerSpell), so talents sort
-- themselves out and a spell the client lacks never shows as missing.
-- Auras are matched by name: the name comes from the client for the list's
-- spell ID, so it is the client's language, and a debuff whose ID differs
-- from the spell that applies it still matches. Spell IDs from Blizzard's
-- Mists data (wago.tools SpellName, branch wow_classic, 2026-10-28).
--
-- Retail: aura data on enemies can be secret in combat. A secret name
-- cannot be matched, so the list then shows its rows grey ("unknown")
-- rather than red - never "missing" on a guess.
-------------------------------------------------------------------
-- one line per debuff, close together (owner, 2026-10-28): icon, name,
-- capsule, and the time after it
local W, FOCUS_W, ROW_H, TITLE, PAD, ICON = 240, 170, 16, 20, 5, 14
local ROW_GAP, TIME_W, BAR_H = 2, 30, 6
local MAX_OTHER = 4
local PANDEMIC = 0.3
local POLL = 0.1
local GOLD = { 1, 0.82, 0.3 }
local RUN = { 0.5, 0.75, 0.3 }
local LATE = { 0.88, 0.7, 0.29 }
local MISSING = { 0.9, 0.3, 0.3 }

local function Secret(v) return issecretvalue and issecretvalue(v) end
local function Ask(v) if Secret(v) then return nil end return v end

-------------------------------------------------------------------
-- What each specialization keeps up
-------------------------------------------------------------------
-- id: the debuff (its name and icon); known: the spell that tells
-- whether you can apply it, when that is not the same one; self: buffs on
-- you instead, any of them will do.
local LETHAL = { 2823, 8679 }                       -- Deadly, Wound Poison
local NONLETHAL = { 3408, 5761, 108211, 108215 }    -- Crippling, Mind-numbing, Leeching, Paralytic
-- what those poisons put on the enemy, to keep off the target's icon row
local POISON_DEBUFFS = { 2818, 8680, 3409, 5760, 112961, 113952 }
local POISONS = { { self = LETHAL, label = "Lethal poison", debuffs = POISON_DEBUFFS },
                  { self = NONLETHAL, label = "Non-lethal poison" } }
local BOMBS = { { id = 44457 }, { id = 114923 }, { id = 112948 } }   -- Living Bomb, Nether Tempest, Frost Bomb
local DISEASES = { { id = 59921, known = 45477 }, { id = 59879, known = 45462 } }  -- Frost Fever, Blood Plague

local function List(...)
    local out = {}
    for _, part in ipairs({ ... }) do
        for _, entry in ipairs(part) do out[#out + 1] = entry end
    end
    return out
end

local LISTS = {
    [265] = { { id = 980 }, { id = 172 }, { id = 30108 }, { id = 48181 } },  -- Affliction: Agony, Corruption, Unstable Affliction, Haunt
    [266] = { { id = 172 }, { id = 603 } },                                   -- Demonology: Corruption, Doom
    [267] = { { id = 348 } },                                                 -- Destruction: Immolate
    [258] = { { id = 589 }, { id = 34914 }, { id = 2944 } },                  -- Shadow: Shadow Word: Pain, Vampiric Touch, Devouring Plague
    [102] = { { id = 8921 }, { id = 93402 } },                                -- Balance: Moonfire, Sunfire
    [103] = { { id = 1822 }, { id = 1079 }, { id = 106830 } },                -- Feral: Rake, Rip, Thrash
    [104] = { { id = 77758 }, { id = 33745 } },                               -- Guardian: Thrash, Lacerate
    [259] = List({ { id = 1943 }, { id = 2823 } }, POISONS),                  -- Assassination: Rupture, Deadly Poison
    [260] = List({ { id = 84617 }, { id = 1943 } }, POISONS),                 -- Combat: Revealing Strike, Rupture
    [261] = List({ { id = 1943 }, { id = 16511 }, { id = 91021, known = 91023 } }, POISONS), -- Subtlety: Rupture, Hemorrhage, Find Weakness
    [253] = { { id = 1978 } },                                                -- Beast Mastery: Serpent Sting
    [254] = { { id = 1978 } },                                                -- Marksmanship
    [255] = { { id = 1978 }, { id = 3674 } },                                 -- Survival: + Black Arrow
    [71]  = { { id = 86346 }, { id = 115767, known = 12294 } },               -- Arms: Colossus Smash, Deep Wounds
    [250] = DISEASES, [251] = DISEASES, [252] = DISEASES,                     -- Death Knight
    [262] = { { id = 8050 } }, [263] = { { id = 8050 } },                     -- Elemental, Enhancement: Flame Shock
    [62]  = BOMBS, [64] = BOMBS,                                              -- Arcane, Frost: the talented bomb
    [63]  = List({ { id = 11366 }, { id = 12654, known = 12846 } }, BOMBS),   -- Fire: Pyroblast, Ignite
    [70]  = { { id = 31803, known = 31801 } },                                -- Retribution: Censure (Seal of Truth)
    [269] = { { id = 130320, known = 107428 } },                              -- Windwalker: Rising Sun Kick
}

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return (GetSpellInfo(id))
end

local function SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    return GetSpellTexture(id)
end

local function Known(id)
    return (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) or false
end

local function SpecID()
    local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
    local getInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
    local index = getSpec and getSpec()
    return index and getInfo and getInfo(index) or 0
end

-- What the window tracks leaves the target frame's own debuff icons
-- (owner 2026-10-28: once a debuff runs as a bar, it is not an icon too):
-- the spec's whole list, known or not, goes into the icon row's
-- excludeSpellIDs - ns.targetDebuffs holds the FF target bars' debuff
-- containers (ffstyle.lua); the orbs' columns are in it too. Off, the
-- filter is cleared again. Needs no reload: candidate filters are live.
-- The "other" debuffs the window lists below the spec's rows go too
-- (owner's screenshot 2026-10-28: their icons stayed): FillColumn keeps
-- their spell IDs in `extra` and re-applies the filter when that set
-- changes - not every poll, a filter change lays the icon row out again.
local NO_EXCLUDE = {}
local extra, extraKey = {}, ""
function ns.ApplyDotExclusion()
    local filters = NO_EXCLUDE
    if DeckOrbsDB.dotTracker then
        local ids = {}
        for _, e in ipairs(LISTS[SpecID()] or {}) do
            if e.id then ids[e.id] = true end
            for _, id in ipairs(e.debuffs or {}) do ids[id] = true end
        end
        for id in pairs(extra) do ids[id] = true end
        filters = { excludeSpellIDs = ids }
    end
    for _, entry in ipairs(ns.targetDebuffs or {}) do
        pcall(entry.container.SetAuraGroupCandidateFilters, entry.container, entry.key, filters)
    end
end

-- the rows of this spec you can use: { name, icon, self = {names} }
local entries = {}
local function Rebuild()
    wipe(entries)
    ns.ApplyDotExclusion()
    for _, e in ipairs(LISTS[SpecID()] or {}) do
        if e.self then
            local names = {}
            for _, id in ipairs(e.self) do
                local n = SpellName(id)
                if n then names[n] = id end
            end
            entries[#entries + 1] = { self = names, label = e.label, icon = SpellIcon(e.self[1]) }
        elseif Known(e.known or e.id) then
            local n = SpellName(e.id)
            if n then entries[#entries + 1] = { name = n, icon = SpellIcon(e.id), id = e.id } end
        end
    end
end

-------------------------------------------------------------------
-- Reading auras: name -> { icon, count, duration, expires }
-------------------------------------------------------------------
local function Scan(unit, filter)
    local found, secret = {}, false
    for i = 1, 40 do
        local name, icon, count, duration, expires, id
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local a = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
            if not a then break end
            name, icon, count, duration, expires, id = a.name, a.icon, a.applications, a.duration, a.expirationTime, a.spellId
        else
            local n, ic, c, _, dur, exp, _, _, _, sid = UnitAura(unit, i, filter)
            if not n then break end
            name, icon, count, duration, expires, id = n, ic, c, dur, exp, sid
        end
        if Secret(name) then
            secret = true
        elseif not found[name] then
            found[name] = { icon = icon, count = count, duration = duration, expires = expires, id = Ask(id) }
        end
    end
    return found, secret
end

-------------------------------------------------------------------
-- The window: two columns of rows
-------------------------------------------------------------------
local function Frame4(parent, r, g, b, a, into)
    for _, p in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                         { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = parent:CreateTexture(nil, "BORDER")
        t:SetColorTexture(r, g, b, a)
        t:SetPoint(p[1])
        t:SetPoint(p[2])
        if p[3] then t:SetHeight(1) else t:SetWidth(1) end
        into[#into + 1] = t
    end
end

local function Text(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.FONT, size, "OUTLINE")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local holder = CreateFrame("Frame", "DeckOrbsDebuffs", UIParent)
holder:SetSize(W, 60)
holder.defaultPoint = { "CENTER", UIParent, "CENTER", 260, -120 }
holder:SetPoint(unpack(holder.defaultPoint))
holder:Hide()

-- the window's frame: background, edge, title band - all of it goes when
-- the rows hang at the target frame (c.chrome)
local function Column(parent, width, tag)
    local c = CreateFrame("Frame", nil, parent)
    c:SetWidth(width)
    c.chrome = {}
    local bg = c:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetGradient("VERTICAL", CreateColor(0.04, 0.04, 0.05, 0.9), CreateColor(0.13, 0.12, 0.11, 0.9))
    c.chrome[#c.chrome + 1] = bg
    Frame4(c, 0.55, 0.5, 0.42, 0.8, c.chrome)
    c.title = Text(c, 12)
    c.chrome[#c.chrome + 1] = c.title
    c.title:SetPoint("TOPLEFT", 8, -4)
    c.title:SetPoint("RIGHT", -50, 0)
    c.title:SetTextColor(0.95, 0.92, 0.85)
    local t = Text(c, 10, "RIGHT")
    t:SetPoint("TOPRIGHT", -8, -5)
    t:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    t:SetText(tag)
    local line = c:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 6, -TITLE)
    line:SetPoint("TOPRIGHT", -6, -TITLE)
    line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.6)
    c.chrome[#c.chrome + 1] = t
    c.chrome[#c.chrome + 1] = line
    c.rows, c.width = {}, width
    return c
end

local target = Column(holder, W, "TARGET")
local focus = Column(holder, FOCUS_W, "FOCUS")

-- Two ways to stand (DeckOrbsDB.dotAttach): a window of its own, or the
-- bare rows at the target frame - the FF bar or the orb, whichever this
-- style spawned - and the focus column at the focus frame, above or below
-- them (DeckOrbsDB.dotAbove). Our frames only anchor to theirs; nothing on
-- the unit frames changes.
--
-- Clear of what already hangs there (owner, 2026-10-28): below an FF bar
-- sit the cast bar, its text and the target's status icons - one row,
-- 22 px, 15 or 16 icons wide, for at most 8 debuffs + 6 buffs - so the
-- rows go under that row. An orb keeps its auras beside it, but its name
-- or cast text sits on the edge we hang at; a FF focus has its cast below.
local attached = false
local top = TITLE   -- where the rows start below a column's top edge
local GAP = 6
local TEXT_CLEAR = 22   -- an orb's name or cast text, an FF focus's cast and its text

local function UnitFrameFor(unit)
    if unit == "target" then return _G.DeckFFTarget or _G.DeckOrbsTarget end
    return _G.DeckXIVFocus or _G.DeckOrbsFocus
end

-- an FF bar or an orb: in the "ff" style the focus is still an orb
local function IsBar(frame)
    local name = frame:GetName() or ""
    return name:find("^DeckFF") or name:find("^DeckXIV")
end

-- An FF target bar names its outermost aura line on each side
-- (frame.DeckBelow / DeckAbove, ffstyle.lua TargetAuraRows): the column
-- hangs past it. Without one, past the orb's name or cast text.
local function Hang(c, frame, above)
    if above then
        -- the column grows upwards from its bottom edge, rows stay in order
        local over = frame.DeckAbove
        if over then
            c:SetPoint("BOTTOMLEFT", over, "TOPLEFT", 0, GAP)
        else
            c:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, IsBar(frame) and GAP or TEXT_CLEAR)
        end
        return
    end
    local under = frame.DeckBelow
    if under then
        c:SetPoint("TOPLEFT", under, "BOTTOMLEFT", 0, -GAP)
    else
        c:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -TEXT_CLEAR)
    end
end

function ns.ApplyDotLayout()
    attached = DeckOrbsDB.dotAttach and true or false
    local above = DeckOrbsDB.dotAbove and true or false
    top = attached and 0 or TITLE
    for _, c in ipairs({ target, focus }) do
        for _, piece in ipairs(c.chrome) do piece:SetShown(not attached) end
        c:ClearAllPoints()
    end
    local tf, ff = UnitFrameFor("target"), UnitFrameFor("focus")
    if attached and tf then
        Hang(target, tf, above)
    else
        target:SetPoint("TOPLEFT", holder, "TOPLEFT")
    end
    if attached and ff then
        Hang(focus, ff, above)
    else
        focus:SetPoint("TOPLEFT", target, "TOPRIGHT", 6, 0)
    end
end

local function Row(c, i)
    local r = c.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, c)
    r:SetSize(c.width - 2 * PAD, ROW_H)
    r.iconEdge = r:CreateTexture(nil, "ARTWORK")
    r.iconEdge:SetSize(ICON + 2, ICON + 2)
    r.iconEdge:SetPoint("LEFT", 0, 0)
    -- without names the icon is the only word: its tooltip names the debuff
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
        if DeckOrbsDB.dotNames ~= false or not self.label then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.label)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", GameTooltip_Hide)
    r.icon = r:CreateTexture(nil, "ARTWORK", nil, 1)
    r.icon:SetSize(ICON, ICON)
    r.icon:SetPoint("CENTER", r.iconEdge)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.count = Text(r, 9, "RIGHT")
    r.count:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 2, -2)
    r.name = Text(r, 10)
    r.name:SetPoint("LEFT", r.iconEdge, "RIGHT", 4, 0)
    r.bar = ns.PillBar(r, 10, BAR_H)
    r.time = Text(r, 10, "LEFT")
    r.time:SetPoint("LEFT", r.bar, "RIGHT", 4, 0)
    r.time:SetWidth(TIME_W)
    -- where the last 30% begin
    r.tick = r.bar:CreateTexture(nil, "OVERLAY", nil, 2)
    r.tick:SetSize(1, BAR_H)
    r.tick:SetColorTexture(1, 1, 1, 0.6)
    c.rows[i] = r
    ns.LayoutDotRow(r, c)
    return r
end

-- the name takes a share of the row and the capsule the rest - or, with
-- the name off (DeckOrbsDB.dotNames, owner 2026-10-28: more compact), the
-- capsule takes it all; the icon says which debuff
function ns.LayoutDotRow(r, c)
    local names = DeckOrbsDB.dotNames ~= false
    local inner = c.width - 2 * PAD - ICON - 2
    local nameW = names and math.floor(inner * 0.4) or 0
    local barW = inner - nameW - TIME_W - (names and 12 or 8)
    r.name:SetShown(names)
    r.name:SetWidth(math.max(1, nameW))
    r.bar:SetWidth(barW)
    r.bar:ClearAllPoints()
    if names then
        r.bar:SetPoint("LEFT", r.name, "RIGHT", 4, 0)
    else
        r.bar:SetPoint("LEFT", r.iconEdge, "RIGHT", 4, 0)
    end
    r.tick:ClearAllPoints()
    r.tick:SetPoint("LEFT", r.bar, "LEFT", math.floor(barW * PANDEMIC), 0)
end

function ns.ApplyDotNames()
    for _, c in ipairs({ target, focus }) do
        for _, r in ipairs(c.rows) do ns.LayoutDotRow(r, c) end
    end
end

-- The columns' width, per device (ns.DeviceDB().dotScale, a percentage of
-- W on the Debuffs page, 175% = the widest target bar - owner 2026-10-28);
-- the focus column keeps its share of it. Rows already made follow at once.
local FOCUS_SHARE = FOCUS_W / W
function ns.ApplyDotWidth()
    local w = math.floor(W * (ns.DeviceDB().dotScale or 100) / 100 + 0.5)
    target.width, focus.width = w, math.floor(w * FOCUS_SHARE)
    for _, c in ipairs({ target, focus }) do
        c:SetWidth(c.width)
        for _, r in ipairs(c.rows) do
            r:SetWidth(c.width - 2 * PAD)
            ns.LayoutDotRow(r, c)
        end
    end
    holder:SetWidth(w)
end

-- state: "run" (left, duration), "missing", "unknown"
local function Paint(r, icon, name, state, left, duration, count)
    r.icon:SetTexture(icon or 134400)
    r.name:SetText(name or "")
    r.label = name
    r.count:SetText(count and Ask(count) and count > 1 and count or "")
    if state == "missing" then
        r.icon:SetDesaturated(true)
        r.icon:SetAlpha(0.6)
        r.iconEdge:SetColorTexture(MISSING[1], MISSING[2], MISSING[3], 1)
        r.name:SetTextColor(0.95, 0.6, 0.6)
        r.time:SetText("--")   -- the red edge says it; "missing" did not fit after the bar
        r.time:SetTextColor(0.95, 0.6, 0.6)
        r.bar:SetMinMaxValues(0, 1)
        r.bar:SetValue(0)
        r.bar.edge:SetVertexColor(MISSING[1], MISSING[2], MISSING[3], 1)
        r.tick:Hide()
        return
    end
    r.icon:SetDesaturated(false)
    r.icon:SetAlpha(1)
    r.iconEdge:SetColorTexture(0.55, 0.5, 0.42, 1)
    r.name:SetTextColor(0.95, 0.92, 0.85)
    r.time:SetTextColor(0.85, 0.82, 0.75)
    r.bar.edge:SetVertexColor(0, 0, 0, 0.9)
    left, duration = Ask(left), Ask(duration)
    if state == "unknown" or not left or not duration or duration <= 0 then
        -- permanent, or kept secret: a full bar, no time
        r.bar:SetMinMaxValues(0, 1)
        r.bar:SetValue(1)
        local grey = state == "unknown"
        r.bar:SetStatusBarColor(grey and 0.45 or RUN[1], grey and 0.45 or RUN[2], grey and 0.45 or RUN[3])
        r.time:SetText("")
        r.tick:Hide()
        return
    end
    left = math.max(0, left)
    r.bar:SetMinMaxValues(0, duration)
    r.bar:SetValue(left)
    local c = left / duration <= PANDEMIC and LATE or RUN
    r.bar:SetStatusBarColor(c[1], c[2], c[3])
    r.time:SetText(left >= 60 and ("%d:%02d"):format(math.floor(left / 60), math.floor(left % 60))
        or ("%ds"):format(math.ceil(left)))
    r.tick:Show()
end

-- lays the shown rows out and sizes the column; false when it has none
local function Finish(c, shown, gapAfter)
    local y = -top - 3
    for i = 1, shown do
        local r = c.rows[i]
        if gapAfter and i == gapAfter + 1 then y = y - 4 end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", PAD, y)
        r:Show()
        y = y - ROW_H - ROW_GAP
    end
    for i = shown + 1, #c.rows do c.rows[i]:Hide() end
    c:SetHeight(-y + PAD - 2)
    c:SetShown(shown > 0)
    return shown > 0
end

local function Attackable(unit)
    if not UnitExists(unit) then return false end
    if Ask(UnitCanAttack("player", unit)) == false then return false end
    return Ask(UnitIsDead(unit)) ~= true
end

local function FillColumn(c, unit, withSelf, withOthers)
    local now = GetTime()
    local live = Attackable(unit)
    -- a secret answer counts as fighting: better a red row too many than none
    local fighting = Ask(UnitAffectingCombat("player")) ~= false
    local onUnit, secret = {}, false
    if live then onUnit, secret = Scan(unit, "HARMFUL|PLAYER") end
    local mine = withSelf and Scan("player", "HELPFUL") or {}
    local shown, used = 0, {}
    for _, e in ipairs(entries) do
        if e.self then
            if withSelf then
                local hit
                for n in pairs(e.self) do
                    if mine[n] then hit = n break end
                end
                -- a poison you have is news only next to an enemy
                if not hit or live then
                    shown = shown + 1
                    local a = hit and mine[hit]
                    if a then
                        Paint(Row(c, shown), a.icon, hit, "run", a.expires and a.expires - now, a.duration, a.count)
                    else
                        Paint(Row(c, shown), e.icon, e.label, "missing")
                    end
                end
            end
        elseif live then
            used[e.name] = true
            local a = onUnit[e.name]
            if a then
                shown = shown + 1
                Paint(Row(c, shown), a.icon or e.icon, e.name, "run", a.expires and a.expires - now, a.duration, a.count)
            elseif fighting then
                -- a debuff is only missing in a fight: out of combat the
                -- window said "Censure --" at every crocolisk (owner, 2026-10-28)
                shown = shown + 1
                Paint(Row(c, shown), e.icon, e.name, secret and "unknown" or "missing")
            end
        end
    end
    local listed = shown
    if withOthers and live then
        -- by name, so the rows do not swap places from one poll to the next
        local others = {}
        for n in pairs(onUnit) do
            if not used[n] then others[#others + 1] = n end
        end
        table.sort(others)
        local ids, key = {}, {}
        for i = 1, math.min(MAX_OTHER, #others) do
            local a = onUnit[others[i]]
            shown = shown + 1
            Paint(Row(c, shown), a.icon, others[i], "run", a.expires and a.expires - now, a.duration, a.count)
            if a.id then ids[a.id] = true key[#key + 1] = a.id end
        end
        table.sort(key)
        local k = table.concat(key, ",")
        if k ~= extraKey then
            extraKey, extra = k, ids
            ns.ApplyDotExclusion()
        end
    elseif withOthers and extraKey ~= "" then
        -- no target: the icons may show again on the next one
        extraKey, extra = "", {}
        ns.ApplyDotExclusion()
    end
    if live then c.title:SetText(UnitName(unit)) else c.title:SetText("Your debuffs") end
    return Finish(c, shown, listed > 0 and shown > listed and listed or nil)
end

local preview = false

local function Update()
    if preview then return end
    local any = FillColumn(target, "target", true, true)
    local focusOn = UnitExists("focus") and Ask(UnitIsUnit("focus", "target")) == false
    if focusOn then
        focusOn = FillColumn(focus, "focus", false, false)
    else
        focus:Hide()
    end
    holder:SetHeight(math.max(target:IsShown() and target:GetHeight() or 0, focus:IsShown() and focus:GetHeight() or 0, 20))
    -- the focus column keeps its place when the target column is empty
    target:SetShown(any)
    holder:SetShown(any or focusOn)
end

-------------------------------------------------------------------
-- Switching, events, preview
-------------------------------------------------------------------
local driver = CreateFrame("Frame")
local elapsed = 0
local function Tick(_, dt)
    elapsed = elapsed + dt
    if elapsed < POLL then return end
    elapsed = 0
    Update()
end

local SPEC_EVENTS = { "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED" }
driver:SetScript("OnEvent", function(_, event)
    if event ~= "PLAYER_TARGET_CHANGED" and event ~= "PLAYER_FOCUS_CHANGED" then Rebuild() end
    Update()
end)

local function ShowPreview(on)
    preview = on
    if not on then
        if DeckOrbsDB.dotTracker then Update() else holder:Hide() end
        return
    end
    target:SetShown(true)
    target.title:SetText("Debuffs")
    Paint(Row(target, 1), 136118, "Drag me", "run", 14, 18)
    Paint(Row(target, 2), 136139, "In the last 30%", "run", 4, 18)
    Paint(Row(target, 3), 136188, "Missing", "missing")
    Finish(target, 3)
    focus.title:SetText("Focus")
    Paint(Row(focus, 1), 136118, "Sample", "run", 10, 18)
    Finish(focus, 1)
    holder:SetHeight(target:GetHeight())
    holder:Show()
end

function ns.SetDotTracker(on)
    DeckOrbsDB.dotTracker = on and true or false
    if on then
        for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", unpack(SPEC_EVENTS) }) do
            if not C_EventUtils or C_EventUtils.IsEventValid(e) then driver:RegisterEvent(e) end
        end
        driver:SetScript("OnUpdate", Tick)
        Rebuild()
        Update()
    else
        driver:UnregisterAllEvents()
        driver:SetScript("OnUpdate", nil)
        if not preview then holder:Hide() end
        ns.ApplyDotExclusion()   -- the icons come back
    end
end

oUF:Factory(function()
    D.MakeMovable(holder, "Debuffs", DeckOrbsDB)
    ns.ApplyDotWidth()
    -- after the unit frames: this factory runs after layout.lua's
    ns.ApplyDotLayout()
    ns.SetDotTracker(DeckOrbsDB.dotTracker)
    D.OnUnlock(function(state, only)
        if only and not only["Debuffs"] then state = false end
        ShowPreview(state and DeckOrbsDB.dotTracker and true or false)
    end)
end)

-- /orbs dots: the spec, its list, what you know, what the target carries
function ns.DotDebug()
    print(("DeckUI debuffs: %s, spec %d, %d rows."):format(
        DeckOrbsDB.dotTracker and "on" or "off", SpecID(), #entries))
    for _, e in ipairs(LISTS[SpecID()] or {}) do
        if e.self then
            print(("  %s (buff on you)"):format(e.label))
        else
            print(("  %d %s: known %s"):format(e.id, tostring(SpellName(e.id)), tostring(Known(e.known or e.id))))
        end
    end
    if UnitExists("target") then
        local found, secret = Scan("target", "HARMFUL|PLAYER")
        local names = {}
        for n in pairs(found) do names[#names + 1] = n end
        print(("  on your target: %s%s"):format(#names > 0 and table.concat(names, ", ") or "nothing of yours",
            secret and " (some kept secret)" or ""))
    end
end

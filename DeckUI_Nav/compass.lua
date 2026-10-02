local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- The compass bar and the target panel
-------------------------------------------------------------------
-- The bar shows 200 degrees around where you look: cardinal points and
-- ticks every 15 degrees, the navigation target (clamped to the edge
-- when it lies outside, faded), party members in class colour, and the
-- rares and treasures the minimap shows. The panel below names the
-- target, points an arrow at it and gives distance and arrival time.
--
-- Two speeds: what lies where (map positions, vignettes, party) is read
-- ten times a second; turning only moves the marks, every frame, with
-- the one call GetPlayerFacing.
-------------------------------------------------------------------
local W, H = 560, 24
local RANGE = math.rad(100)          -- half the bar
local PX = (W / 2 - 2) / RANGE       -- pixels per radian
local WHITE = "Interface\\Buttons\\WHITE8x8"
local GOLD = { 0.9, 0.75, 0.2 }
local MAX_VIGNETTES = 12

-- a fill and four one-pixel lines, anchored only (no BackdropTemplate)
local function FlatBox(frame)
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.75)
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

-------------------------------------------------------------------
-- The bar
-------------------------------------------------------------------
local bar = CreateFrame("Frame", "DeckNavCompass", UIParent)
bar:SetSize(W, H)
bar.defaultPoint = { "TOP", UIParent, "TOP", 0, -8 }
bar:SetPoint(unpack(bar.defaultPoint))
bar:Hide()
FlatBox(bar)

-- everything that slides lives in a clipping frame, so marks leaving
-- the bar are cut at its edge instead of hanging out of it
local clip = CreateFrame("Frame", nil, bar)
clip:SetPoint("TOPLEFT", 1, -1)
clip:SetPoint("BOTTOMRIGHT", -1, 1)
clip:SetClipsChildren(true)

local marks = {}   -- { region, angle } for the fixed directions

-- clockwise degrees from north; angles in the game's sense are negative
local POINTS = { [0] = "N", [45] = "NE", [90] = "E", [135] = "SE",
                 [180] = "S", [225] = "SW", [270] = "W", [315] = "NW" }
for cw = 0, 345, 15 do
    local angle = -math.rad(cw)
    local tick = clip:CreateTexture(nil, "ARTWORK")
    tick:SetColorTexture(0.6, 0.6, 0.6, 0.8)
    tick:SetSize(1, POINTS[cw] and 5 or 3)
    marks[#marks + 1] = { region = tick, angle = angle, point = "BOTTOM", y = 0 }
    if POINTS[cw] then
        local label = clip:CreateFontString(nil, "OVERLAY")
        label:SetFont(D.FONT, #POINTS[cw] == 1 and 13 or 10, "OUTLINE")
        label:SetText(POINTS[cw])
        if cw == 0 then label:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end
        marks[#marks + 1] = { region = label, angle = angle, point = "CENTER", y = 2 }
    end
end

-- where you look: a gold line above everything that slides
local front = CreateFrame("Frame", nil, bar)
front:SetAllPoints()
front:SetFrameLevel(clip:GetFrameLevel() + 5)
local center = front:CreateTexture(nil, "OVERLAY")
center:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
center:SetSize(2, H - 2)
center:SetPoint("CENTER")

local targetMark = clip:CreateTexture(nil, "OVERLAY", nil, 2)
targetMark:SetAtlas("Navigation-Tracked-Icon")
targetMark:SetSize(16, 16)
targetMark:Hide()

local partyMarks = {}
for i = 1, 4 do
    local t = clip:CreateTexture(nil, "OVERLAY", nil, 1)
    t:SetTexture(WHITE)
    t:SetSize(6, 6)
    t:Hide()
    partyMarks[i] = t
end

local vignetteMarks = {}
for i = 1, MAX_VIGNETTES do
    local t = clip:CreateTexture(nil, "OVERLAY")
    t:SetSize(14, 14)
    t:Hide()
    vignetteMarks[i] = t
end

-------------------------------------------------------------------
-- The target panel
-------------------------------------------------------------------
local panel = CreateFrame("Frame", "DeckNavTarget", UIParent)
panel:SetSize(250, 40)
panel.defaultPoint = { "TOP", UIParent, "TOP", 0, -36 }
panel:SetPoint(unpack(panel.defaultPoint))
panel:Hide()
FlatBox(panel)

local arrow = panel:CreateTexture(nil, "ARTWORK")
arrow:SetAtlas("Navigation-Tracked-Arrow")
arrow:SetSize(26, 26)
arrow:SetPoint("LEFT", 8, 0)

local nameText = panel:CreateFontString(nil, "OVERLAY")
nameText:SetFont(D.FONT, 12, "OUTLINE")
nameText:SetPoint("TOPLEFT", 42, -6)
nameText:SetPoint("TOPRIGHT", -36, -6)
nameText:SetJustifyH("LEFT")
nameText:SetWordWrap(false)

local infoText = panel:CreateFontString(nil, "OVERLAY")
infoText:SetFont(D.FONT, 11, "OUTLINE")
infoText:SetPoint("BOTTOMLEFT", 42, 6)
infoText:SetPoint("BOTTOMRIGHT", -6, 6)
infoText:SetJustifyH("LEFT")
infoText:SetWordWrap(false)
infoText:SetTextColor(0.75, 0.75, 0.75)

-- "2/5" after a step through the tracked quests, for two seconds
local flash = panel:CreateFontString(nil, "OVERLAY")
flash:SetFont(D.FONT, 12, "OUTLINE")
flash:SetPoint("TOPRIGHT", -6, -6)
flash:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
local flashToken = 0

-------------------------------------------------------------------
-- What lies where (ten times a second)
-------------------------------------------------------------------
local state = {
    target = nil,        -- angle of the target, if it has a place on this map
    mapDist = nil,       -- its distance by the map, in yards
    desc = nil,          -- Blizzard's text for a route step ("Take the portal")
    party = {},          -- i -> angle or nil
    partyColor = {},     -- i -> { r, g, b }
    vignettes = {},      -- { { angle, atlas }, ... }
}
local samples = {}       -- { t, distance } for the arrival time

local function Collect()
    local mapID, px, py = ns.PlayerPos()
    state.mapID = mapID
    state.target, state.mapDist, state.desc = nil, nil, nil
    wipe(state.vignettes)
    for i = 1, 4 do state.party[i] = nil end
    if not mapID then return end

    local tx, ty, desc = ns.TargetPos(mapID)
    if tx then
        state.target, state.mapDist = ns.Bearing(mapID, px, py, tx, ty)
        state.desc = desc
    end

    if DeckNavDB.party and IsInGroup() and not IsInRaid() then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local x, y = ns.UnitPos(mapID, unit)
                if x then
                    state.party[i] = ns.Bearing(mapID, px, py, x, y)
                    local _, class = UnitClass(unit)
                    local c = class and ns.Plain(class) and RAID_CLASS_COLORS[class]
                    state.partyColor[i] = c and { c.r, c.g, c.b } or { 0.8, 0.8, 0.8 }
                end
            end
        end
    end

    if DeckNavDB.vignettes then
        for _, guid in ipairs(C_VignetteInfo.GetVignettes() or {}) do
            local info = C_VignetteInfo.GetVignetteInfo(guid)
            if info and ns.Plain(info.onMinimap, info.isDead, info.atlasName)
                and info.onMinimap and not info.isDead and info.atlasName then
                local pos = C_VignetteInfo.GetVignettePosition(guid, mapID)
                if pos then
                    local x, y = pos:GetXY()
                    if ns.Plain(x, y) then
                        local angle = ns.Bearing(mapID, px, py, x, y)
                        if angle then
                            state.vignettes[#state.vignettes + 1] = { angle, info.atlasName }
                            if #state.vignettes == MAX_VIGNETTES then break end
                        end
                    end
                end
            end
        end
    end
end

-- Blizzard's distance first (it follows the route through portals);
-- the map's straight line when it has none
local function Distance()
    local d = C_Navigation.GetDistance()
    if d and ns.Plain(d) and d > 0 then return d end
    return state.mapDist
end

local function DistanceString(d)
    d = math.floor(d + 0.5)
    local text = d < 1000 and tostring(d) or AbbreviateNumbers(d)
    return IN_GAME_NAVIGATION_RANGE and IN_GAME_NAVIGATION_RANGE:format(text) or (text .. " yd")
end

-- arrival time from how fast the distance actually shrinks over the last
-- three seconds - not from the run speed, which knows nothing of the
-- direction you run in
local function ArrivalTime(d)
    local now = GetTime()
    local last = samples[#samples]
    if last and math.abs(last.d - d) > 60 then wipe(samples) end   -- a portal, a new target
    samples[#samples + 1] = { t = now, d = d }
    while #samples > 1 and now - samples[1].t > 3 do table.remove(samples, 1) end
    local first = samples[1]
    if now - first.t < 0.5 then return end
    local closing = (first.d - d) / (now - first.t)
    if closing < 1 then return end
    local secs = math.floor(d / closing + 0.5)
    if secs >= 3600 then return end
    -- with its unit: a bare "0:45" read as a stray number (owner, 2026-10-02)
    if secs < 60 then return ("%d s"):format(secs) end
    return ("%d min"):format(math.ceil(secs / 60))
end

-- shared with the beacon (beacon.lua)
ns.navState = state
ns.DistanceString = DistanceString

local function UpdatePanel()
    if not (DeckNavDB.panel and C_SuperTrack.IsSuperTrackingAnything()) then
        panel:Hide()
        return
    end
    panel:Show()
    nameText:SetText(ns.TargetName() or "")
    local parts = {}
    if state.distance then
        parts[#parts + 1] = DistanceString(state.distance)
        if state.eta then parts[#parts + 1] = state.eta end
    end
    if state.desc and state.desc ~= "" then parts[#parts + 1] = state.desc end
    infoText:SetText(table.concat(parts, "  \194\183  "))
end

-------------------------------------------------------------------
-- Turning (every frame)
-------------------------------------------------------------------
local function Place(region, rel, point, y)
    region:ClearAllPoints()
    region:SetPoint(point or "CENTER", clip, point or "CENTER", -rel * PX, y or 0)
end

local function Turn(facing)
    for _, m in ipairs(marks) do
        local rel = ns.Relative(m.angle, facing)
        if math.abs(rel) <= RANGE + 0.2 then
            Place(m.region, rel, m.point, m.y)
            m.region:Show()
        else
            m.region:Hide()
        end
    end

    if state.target then
        local rel = ns.Relative(state.target, facing)
        local edge = RANGE - math.rad(4)
        local clamped = math.abs(rel) > edge
        if clamped then rel = rel > 0 and edge or -edge end
        Place(targetMark, rel)
        targetMark:SetAlpha(clamped and 0.5 or 1)
        targetMark:Show()
    else
        targetMark:Hide()
    end

    for i, t in ipairs(partyMarks) do
        local angle = state.party[i]
        local rel = angle and ns.Relative(angle, facing)
        if rel and math.abs(rel) <= RANGE then
            local c = state.partyColor[i]
            t:SetVertexColor(c[1], c[2], c[3])
            Place(t, rel, "TOP", -2)
            t:Show()
        else
            t:Hide()
        end
    end

    for i, t in ipairs(vignetteMarks) do
        local v = state.vignettes[i]
        local rel = v and ns.Relative(v[1], facing)
        if rel and math.abs(rel) <= RANGE then
            t:SetAtlas(v[2])
            t:SetSize(14, 14)
            Place(t, rel, "CENTER", -1)
            t:Show()
        else
            t:Hide()
        end
    end
end

-------------------------------------------------------------------
-- The driver: a frame of its own, since a hidden bar runs no OnUpdate
-------------------------------------------------------------------
local driver = CreateFrame("Frame")
local acc = 0
local function OnUpdate(_, elapsed)
    acc = acc + elapsed
    if acc >= 0.1 then
        acc = 0
        Collect()
        -- distance and arrival time once, for the panel and the beacon
        state.distance = C_SuperTrack.IsSuperTrackingAnything() and Distance() or nil
        state.eta = state.distance and ArrivalTime(state.distance) or nil
        UpdatePanel()
    end

    local facing = ns.Facing()
    if DeckNavDB.compass and facing and state.mapID then
        bar:Show()
        Turn(facing)
    else
        bar:Hide()
    end
    if panel:IsShown() then
        local rel = state.target and facing and ns.Relative(state.target, facing)
        arrow:SetShown(rel ~= nil)
        if rel then arrow:SetRotation(rel) end
    end
end

function ns.FlashTarget(text)
    flashToken = flashToken + 1
    local token = flashToken
    flash:SetText(text)
    acc = 1   -- the new target's name at once
    C_Timer.After(2, function()
        if token == flashToken then flash:SetText("") end
    end)
end

function ns.ApplyScale()
    local scale = ns.DeviceDB().scale or 1
    bar:SetScale(scale)
    panel:SetScale(scale)
end

function ns.InitCompass()
    D.MakeMovable(bar, "Compass", DeckNavDB)
    D.MakeMovable(panel, "Navigation target", DeckNavDB)
    ns.ApplyScale()
    driver:RegisterEvent("SUPER_TRACKING_CHANGED")
    driver:SetScript("OnEvent", function()
        wipe(samples)
        acc = 1
    end)
    driver:SetScript("OnUpdate", OnUpdate)
end

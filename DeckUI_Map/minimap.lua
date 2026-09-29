local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- The minimap: square, in a DeckUI frame, sized and placed per device
-------------------------------------------------------------------
-- Blizzard's 12.1.0 minimap (read 2026-09-29): MinimapCluster is an Edit
-- Mode system whose SetPoint/SetScale/ClearAllPoints are replaced by Edit
-- Mode overrides and re-applied on every layout update. Edit Mode never
-- touches Minimap itself, though - only the cluster and the container it
-- scales. So the map moves out: Minimap is reparented into our own frame,
-- and the cluster with Blizzard's header is parked under a hidden parent.
-- Nothing in the minimap is protected, so none of this minds combat.
--
-- The pieces worth keeping come along: tracking, calendar, the addon
-- compartment and the zoom buttons appear while the mouse is over the map;
-- the mail and crafting-order indicators and the instance difficulty stay
-- visible, since they say something. Zone text, clock and coordinates are
-- our own, drawn on the map's edges.
-------------------------------------------------------------------
local BORDER = 2
local EDGE_HEIGHT = 16

local holder = CreateFrame("Frame", "DeckMapMinimap", UIParent, "BackdropTemplate")
holder:SetFrameStrata("LOW")
holder:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
holder:SetBackdropColor(0, 0, 0, 1)
holder:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
holder.defaultPoint = { "TOPRIGHT", UIParent, "TOPRIGHT", -12, -12 }
holder:SetPoint(unpack(holder.defaultPoint))
holder:SetSize(190, 190)
ns.minimap = holder

local hider = CreateFrame("Frame", "DeckMapBlizzardHider", UIParent)
hider:SetAllPoints()
hider:Hide()

-- Addon button libraries ask this to place their buttons on the edge.
-- Blizzard does not define it; it is a convention between addons.
function GetMinimapShape() return "SQUARE" end

-------------------------------------------------------------------
-- Our own text: zone on top, clock and coordinates at the bottom
-------------------------------------------------------------------
local function EdgeText(point, x, y, justify)
    local fs = holder:CreateFontString(nil, "OVERLAY")
    fs:SetFont(D.FONT, 12, "OUTLINE")
    fs:SetPoint(point, holder, point, x, y)
    fs:SetJustifyH(justify)
    return fs
end

-- A dark strip behind the text keeps it readable on a bright map.
local function Strip(point)
    local t = holder:CreateTexture(nil, "ARTWORK", nil, 7)
    t:SetColorTexture(0, 0, 0, 0.55)
    t:SetPoint(point .. "LEFT", holder, point .. "LEFT", BORDER, point == "TOP" and -BORDER or BORDER)
    t:SetPoint(point .. "RIGHT", holder, point .. "RIGHT", -BORDER, point == "TOP" and -BORDER or BORDER)
    t:SetHeight(EDGE_HEIGHT)
    return t
end

-- The text sits above the map: Minimap's children are drawn at its own
-- level, so the strips and text live on an overlay frame on top.
local overlay = CreateFrame("Frame", nil, holder)
overlay:SetAllPoints()
overlay:SetFrameLevel(holder:GetFrameLevel() + 20)

local topStrip = Strip("TOP")
local bottomStrip = Strip("BOTTOM")
topStrip:SetParent(overlay)
bottomStrip:SetParent(overlay)

local zone = EdgeText("TOP", 0, -BORDER - 2, "CENTER")
local clock = EdgeText("BOTTOMLEFT", BORDER + 4, BORDER + 2, "LEFT")
local coords = EdgeText("BOTTOMRIGHT", -BORDER - 4, BORDER + 2, "RIGHT")
for _, fs in ipairs({ zone, clock, coords }) do fs:SetParent(overlay) end

-- Blizzard's colours for the zone's PvP status (Minimap_Update)
local ZONE_COLORS = {
    sanctuary = { 0.41, 0.8, 0.94 },
    arena     = { 1, 0.1, 0.1 },
    hostile   = { 1, 0.1, 0.1 },
    friendly  = { 0.1, 1, 0.1 },
    contested = { 1, 0.7, 0 },
}

local function UpdateZone()
    zone:SetText(GetMinimapZoneText() or "")
    local pvpType = C_PvP.GetZonePVPInfo()
    local c = ZONE_COLORS[pvpType]
    if c then zone:SetTextColor(unpack(c)) else zone:SetTextColor(1, 0.82, 0) end
end

-- Clicks on the edges: the clock opens Blizzard's time manager (alarm,
-- stopwatch), like its own clock button did.
local clockButton = CreateFrame("Button", nil, overlay)
clockButton:SetAllPoints(clock)
clockButton:SetScript("OnClick", function()
    if TimeManager_Toggle then TimeManager_Toggle() end
end)

local function Coordinates()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or not pos then return nil end
    local x, y = pos:GetXY()
    if not x or (x == 0 and y == 0) then return nil end
    return ("%.1f, %.1f"):format(x * 100, y * 100)
end

local ticker = 0
holder:SetScript("OnUpdate", function(_, dt)
    ticker = ticker + dt
    if ticker < 0.2 then return end
    ticker = 0
    if DeckMapDB.clock then clock:SetText(GameTime_GetTime(false)) end
    if DeckMapDB.coordinates then
        -- inside most instances there is no position to give
        coords:SetText(Coordinates() or "")
    end
end)

function ns.ApplyTexts()
    zone:SetShown(DeckMapDB.zoneText)
    topStrip:SetShown(DeckMapDB.zoneText)
    clock:SetShown(DeckMapDB.clock)
    coords:SetShown(DeckMapDB.coordinates)
    clockButton:SetShown(DeckMapDB.clock)
    bottomStrip:SetShown(DeckMapDB.clock or DeckMapDB.coordinates)
    UpdateZone()
end

-------------------------------------------------------------------
-- Blizzard's buttons around our map
-------------------------------------------------------------------
-- Each entry: the frame, where it goes, and whether it only shows while
-- the mouse is over the map. Blizzard re-anchors some of them itself
-- (SetHeaderUnderneath on every Edit Mode update, the indicator frame on
-- mail changes), so this is re-applied after those.
local PIECES = {
    { get = function() return MinimapCluster.Tracking end,       point = { "TOPLEFT", 4, -20 },  hover = true },
    { get = function() return GameTimeFrame end,                 point = { "TOPRIGHT", -4, -20 }, hover = true },
    { get = function() return AddonCompartmentFrame end,         point = { "TOPRIGHT", -4, -44 }, hover = true },
    { get = function() return MinimapCluster.IndicatorFrame end, point = { "BOTTOMLEFT", 4, 22 } },
    { get = function() return MinimapCluster.InstanceDifficulty end, point = { "TOPLEFT", 26, -20 } },
}

local placing = false

local function PlacePieces()
    if placing then return end
    placing = true
    for _, piece in ipairs(PIECES) do
        local f = piece.get()
        if f then
            if f:GetParent() ~= overlay then f:SetParent(overlay) end
            f:ClearAllPoints()
            local p = piece.point
            f:SetPoint(p[1], holder, p[1], p[2], p[3])
        end
    end
    placing = false
end

-- Hover: the buttons fade in with the mouse over the map, like the zoom
-- buttons Blizzard already shows only on mouse-over.
local function HoverFrames()
    local list = {}
    for _, piece in ipairs(PIECES) do
        local f = piece.hover and piece.get()
        if f then list[#list + 1] = f end
    end
    -- addon minimap buttons (LibDBIcon and friends) are children of Minimap
    for _, child in ipairs({ Minimap:GetChildren() }) do
        local name = child:GetName()
        if name and (name:find("^LibDBIcon") or name == "DeckUIMinimapButton") then list[#list + 1] = child end
    end
    if ExpansionLandingPageMinimapButton then list[#list + 1] = ExpansionLandingPageMinimapButton end
    return list
end

local hovering
local function SetHover(state)
    if hovering == state then return end
    hovering = state
    local alpha = (state or not DeckMapDB.buttonsOnHover) and 1 or 0
    for _, f in ipairs(HoverFrames()) do f:SetAlpha(alpha) end
end

local hoverCheck = CreateFrame("Frame")
local sinceHover = 0
hoverCheck:SetScript("OnUpdate", function(_, dt)
    sinceHover = sinceHover + dt
    if sinceHover < 0.1 then return end
    sinceHover = 0
    SetHover(holder:IsMouseOver(8, -8, -8, 8))
end)

function ns.ApplyHover()
    hovering = nil
    SetHover(holder:IsMouseOver())
end

-------------------------------------------------------------------
-- Size and shape
-------------------------------------------------------------------
function ns.ApplyMinimapSize()
    local size = ns.DeviceDB().minimapSize
    holder:SetSize(size, size)
    Minimap:SetSize(size - 2 * BORDER, size - 2 * BORDER)
    -- the engine only re-renders the map on a zoom change; nudging the
    -- zoom makes it pick up the new size right away
    local z = Minimap:GetZoom()
    Minimap:SetZoom(z > 0 and z - 1 or z + 1)
    Minimap:SetZoom(z)
    -- DeckUI's own minimap button follows the map's edge
    if D.UpdateMinimapButton then D.UpdateMinimapButton() end
end

local function TakeOver()
    Minimap:SetParent(holder)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", holder, "CENTER")
    Minimap:SetFrameLevel(holder:GetFrameLevel() + 1)
    Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8x8")
    -- the round ring drawn around Blizzard's map
    if MinimapCompassTexture then MinimapCompassTexture:SetAlpha(0) end
    MinimapCluster:SetParent(hider)
    PlacePieces()
    ns.ApplyMinimapSize()
end

ns.OnInit(function()
    TakeOver()
    D.MakeMovable(holder, "Minimap", DeckMapDB)
    D.MakeDraggable(holder)
    -- the map grows and shrinks from its top edge, where the zone text is
    holder:HookScript("OnDragStop", function() D.PinTopLeft(holder) end)
    ns.ApplyTexts()
    ns.ApplyHover()

    if MinimapCluster.SetHeaderUnderneath then
        hooksecurefunc(MinimapCluster, "SetHeaderUnderneath", PlacePieces)
    end
    if MiniMapIndicatorFrame_UpdatePosition then
        hooksecurefunc("MiniMapIndicatorFrame_UpdatePosition", PlacePieces)
    end
end)

local ev = CreateFrame("Frame")
for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
                     "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED" }) do
    ev:RegisterEvent(e)
end
ev:SetScript("OnEvent", function(_, event)
    if not DeckMapDB then return end
    if event == "EDIT_MODE_LAYOUTS_UPDATED" or event == "PLAYER_ENTERING_WORLD" then PlacePieces() end
    UpdateZone()
end)

function ns.ResetPositions()
    D.ResetPosition(holder)
    if WorldMapFrame and WorldMapFrame.deckMovable then D.ResetPosition(WorldMapFrame) end
    print("DeckUI Map: minimap and world map back at their default places.")
end

ns.OnDebug(function()
    print(("DeckUI Map: Minimap parent=%s size=%.0f zoom=%d shape=%s, cluster parked=%s"):format(
        Minimap:GetParent() and (Minimap:GetParent():GetName() or "?") or "nil",
        Minimap:GetWidth(), Minimap:GetZoom(), GetMinimapShape(),
        tostring(MinimapCluster:GetParent() == hider)))
    local mapID = C_Map.GetBestMapForUnit("player")
    print(("  map %s, coordinates %s"):format(tostring(mapID), tostring(Coordinates())))
    local restricted = C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
        and Enum.AddOnRestrictionType and Enum.AddOnRestrictionType.Map
        and C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Map)
    print("  map restriction active: " .. tostring(restricted))
end)

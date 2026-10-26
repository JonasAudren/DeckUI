local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Waypoints: many of them, on both maps, as a list or a route
-------------------------------------------------------------------
-- The owner's wish (2026-10-09): more than Blizzard's one map pin - any
-- number of points, set by clicking the map, kept in a list that can be
-- renamed and sorted out, and a route mode that walks them in order.
-- DeckNavDB.waypoints (kept across sessions), DeckNavDB.routeMode.
--
-- One of them at a time is the active one, and that one is pushed into
-- Blizzard's own user waypoint and super-tracked - so the compass, the
-- target panel, the beacon in the world and Blizzard's diamond all follow
-- it without knowing about the list. Arriving (within ARRIVE yards, or
-- Blizzard clearing its pin on arrival) moves on: in route mode to the
-- next point in order, otherwise the point is done and the nearest one
-- left takes over.
--
-- Setting points never needs our own click on the map: a Ctrl-click on
-- the world map is Blizzard's way to set its map pin, and every pin set
-- that way (or by /way) lands in our list. Our own pins on the maps are
-- frames of ours - on the world map children of its canvas, placed by map
-- coordinates; on the minimap children of Minimap, placed by yards - and
-- never a data provider: providers run inside the map's refresh, and code
-- of ours in there would run the map's own pins tainted (see the Map notes
-- in CLAUDE.md on widget pins and secret values).
-------------------------------------------------------------------
local ARRIVE = 10                -- yards
local MAX = 50

local list                       -- DeckNavDB.waypoints
local pushed                     -- { mapID, x, y } we last handed Blizzard

-------------------------------------------------------------------
-- Positions across maps
-------------------------------------------------------------------
-- a waypoint's place on another map, through world coordinates
local function PosOn(wp, mapID)
    if wp.mapID == mapID then return wp.x, wp.y end
    local continent, world = C_Map.GetWorldPosFromMapPos(wp.mapID, CreateVector2D(wp.x, wp.y))
    if not continent or not world then return end
    local _, pos = C_Map.GetMapPosFromWorldPos(continent, world, mapID)
    if not pos then return end
    local x, y = pos:GetXY()
    if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
end

local function ZoneName(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or ("map " .. mapID)
end

-- yards from the player, when both are on one map
local function DistanceTo(wp)
    local mapID, px, py = ns.PlayerPos()
    if not mapID then return end
    local x, y = PosOn(wp, mapID)
    if not x then return end
    local _, d = ns.Bearing(mapID, px, py, x, y)
    return d
end

-------------------------------------------------------------------
-- The list
-------------------------------------------------------------------
local Refresh   -- redraws pins and the window; set further down

local function Active()
    for i, wp in ipairs(list) do
        if wp.active then return wp, i end
    end
end

-- hand a point to Blizzard: its waypoint, super-tracked
local function Push(wp)
    for _, other in ipairs(list) do other.active = nil end
    if not wp then
        pushed = nil
        Refresh()
        return
    end
    wp.active = true
    -- already Blizzard's pin (a Ctrl-click just set it): setting it again
    -- would only fire USER_WAYPOINT_UPDATED once more inside Blizzard's click
    local current = ns.UW.GetUserWaypoint()
    if current and current.uiMapID == wp.mapID and current.position
        and math.abs(current.position.x - wp.x) < 0.0005 and math.abs(current.position.y - wp.y) < 0.0005 then
        pushed = { mapID = wp.mapID, x = wp.x, y = wp.y }
        ns.ST.SetSuperTrackedUserWaypoint(true)
        Refresh()
        return
    end
    if ns.UW.CanSetUserWaypointOnMap(wp.mapID) then
        pushed = { mapID = wp.mapID, x = wp.x, y = wp.y }
        ns.UW.SetUserWaypoint(ns.MapPoint(wp.mapID, wp.x, wp.y))
        ns.ST.SetSuperTrackedUserWaypoint(true)
    end
    Refresh()
end
ns.ActivateWaypoint = Push

local function Nearest(except)
    local best, bestD
    for _, wp in ipairs(list) do
        if wp ~= except then
            local d = DistanceTo(wp) or math.huge
            if not best or d < bestD then best, bestD = wp, d end
        end
    end
    return best
end

function ns.AddWaypoint(mapID, x, y, name)
    if #list >= MAX then
        print(("DeckUI Nav: %d waypoints is the limit - remove some in /way list."):format(MAX))
        return
    end
    local wp = { mapID = mapID, x = x, y = y,
                 name = (name and name ~= "") and name or ("%s %.1f %.1f"):format(ZoneName(mapID), x * 100, y * 100) }
    list[#list + 1] = wp
    -- in a route the new point waits its turn; otherwise it is the target
    if DeckNavDB.routeMode and Active() then Refresh() else Push(wp) end
    return wp
end
-- for the compass (compass.lua): the points and their place on a map
ns.WaypointList = function() return list or {} end
ns.WaypointPosOn = PosOn
-- for the other modules (the scenario guide's click)
D.AddWaypoint = function(...) return ns.AddWaypoint(...) end

local function Remove(wp)
    for i, other in ipairs(list) do
        if other == wp then table.remove(list, i) break end
    end
    if wp.active then
        local nextWp = Nearest()
        if nextWp then Push(nextWp) else
            pushed = nil
            ns.UW.ClearUserWaypoint()
            Refresh()
        end
    else
        Refresh()
    end
end
ns.RemoveWaypoint = Remove

function ns.ClearWaypoints()
    wipe(list)
    pushed = nil
    ns.UW.ClearUserWaypoint()
    Refresh()
end

local function Arrived(wp)
    local _, index = Active()
    print(("DeckUI Nav: arrived at %s."):format(wp.name))
    if DeckNavDB.routeMode and index then
        -- the route goes on in order and starts over at the end; the
        -- points stay, so it can be walked again
        if #list < 2 then
            Remove(wp)
            return
        end
        Push(list[index % #list + 1])
    else
        Remove(wp)
    end
end

-------------------------------------------------------------------
-- Blizzard's pin: ours when we set it, the player's when not
-------------------------------------------------------------------
local function Same(a, b)
    return a and b and a.mapID == b.mapID and math.abs(a.x - b.x) < 0.0005 and math.abs(a.y - b.y) < 0.0005
end

local function OnUserWaypoint()
    local point = ns.UW.GetUserWaypoint()
    local current = point and point.position and { mapID = point.uiMapID, x = point.position.x, y = point.position.y }
    if current then
        if Same(current, pushed) then return end
        -- a pin set on the map (Ctrl-click) or by another addon: into the list
        for _, wp in ipairs(list) do
            if Same(wp, current) then Push(wp) return end
        end
        pushed = current   -- it is Blizzard's already
        local wp = ns.AddWaypoint(current.mapID, current.x, current.y)
        -- in a route the new point only joins the list: Blizzard's pin goes
        -- back to the point the route is heading for
        local active = Active()
        if wp and active and active ~= wp then Push(active) end
    else
        -- our pin went away: Blizzard clears it on arrival, the player by
        -- right-clicking it on the map - either way that point is done
        local wp = Active()
        if pushed and wp then
            pushed = nil
            Arrived(wp)
        end
    end
end

-------------------------------------------------------------------
-- Pins on the world map
-------------------------------------------------------------------
local mapPins = {}
local canvas

local function Pin(parent, size)
    local p = CreateFrame("Button", nil, parent)
    p:SetSize(size, size)
    p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local ring = p:CreateTexture(nil, "ARTWORK", nil, 1)
    ring:SetAllPoints()
    ring:SetTexture(D.DISC)
    ring:SetVertexColor(0, 0, 0, 0.9)
    local dot = p:CreateTexture(nil, "ARTWORK", nil, 2)
    dot:SetPoint("TOPLEFT", 2, -2)
    dot:SetPoint("BOTTOMRIGHT", -2, 2)
    dot:SetTexture(D.DISC)
    p.dot = dot
    local num = p:CreateFontString(nil, "OVERLAY")
    num:SetFont(D.FONT, 10, "OUTLINE")
    num:SetPoint("CENTER", 0, 0)
    p.num = num
    p:SetScript("OnClick", function(self, button)
        if not self.wp then return end
        if button == "RightButton" then Remove(self.wp) else Push(self.wp) end
    end)
    p:SetScript("OnEnter", function(self)
        if not self.wp then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.wp.name, 1, 0.82, 0)
        local d = DistanceTo(self.wp)
        if d then GameTooltip:AddLine(ns.DistanceString(d), 1, 1, 1) end
        GameTooltip:AddLine("Left click: go there   Right click: remove", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    p:SetScript("OnLeave", GameTooltip_Hide)
    return p
end

local function Paint(p, wp, index)
    p.wp = wp
    p.num:SetText(index)
    if wp.active then
        p.dot:SetVertexColor(1, 0.8, 0.25)
    else
        p.dot:SetVertexColor(0.55, 0.75, 1)
    end
end

local function UpdateMapPins()
    if not (canvas and WorldMapFrame:IsShown()) then return end
    local mapID = WorldMapFrame:GetMapID()
    local scale = canvas:GetScale()
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    local used = 0
    for i, wp in ipairs(list) do
        -- not "mapID and PosOn(...)": and keeps only the first return value,
        -- y came out nil (605 errors on the first test, 2026-10-09)
        local x, y
        if mapID then x, y = PosOn(wp, mapID) end
        if x and y then
            used = used + 1
            local p = mapPins[used] or Pin(canvas, 20)
            mapPins[used] = p
            Paint(p, wp, i)
            -- constant size on screen whatever the zoom: the pin cancels the
            -- canvas's scale, so its offsets are canvas units times that scale
            p:SetScale(1 / scale)
            p:ClearAllPoints()
            p:SetPoint("CENTER", canvas, "TOPLEFT", x * w * scale, -y * h * scale)
            p:SetFrameLevel(canvas:GetFrameLevel() + 2000)
            p:Show()
        end
    end
    for i = used + 1, #mapPins do mapPins[i]:Hide() end
end

-------------------------------------------------------------------
-- Pins on the minimap
-------------------------------------------------------------------
-- How many yards the minimap shows across, per zoom level, outdoors and
-- indoors - the game's fixed table, as the HereBeDragons library keeps it.
local MINIMAP_YARDS = {
    outdoor = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 },
    indoor  = { [0] = 300, 240, 180, 120, 80, 50 },
}
local miniPins = {}

local function UpdateMiniPins()
    local mapID, px, py = ns.PlayerPos()
    local used = 0
    if mapID and Minimap:IsVisible() then
        local zoom = Minimap:GetZoom()
        local across = (IsIndoors() and MINIMAP_YARDS.indoor or MINIMAP_YARDS.outdoor)[zoom] or 466
        local half = Minimap:GetWidth() / 2
        local perYard = half / (across / 2)
        local rotate = C_CVar.GetCVarBool("rotateMinimap")
        local facing = rotate and ns.Facing() or 0
        local round = not (GetMinimapShape and GetMinimapShape() == "SQUARE")
        for i, wp in ipairs(list) do
            local x, y = PosOn(wp, mapID)
            local angle, dist
            if x and y then angle, dist = ns.Bearing(mapID, px, py, x, y) end
            if angle and dist then
                used = used + 1
                local p = miniPins[used] or Pin(Minimap, 14)
                miniPins[used] = p
                Paint(p, wp, i)
                p.num:SetText("")
                -- the bearing counts counterclockwise from north; on screen
                -- that is east = -sin, north = cos, turned with the map
                local a = angle - facing
                local dx, dy = -math.sin(a) * dist * perYard, math.cos(a) * dist * perYard
                -- beyond the edge: on the edge, pointing the way
                local edge = half - 6
                if round then
                    local r = math.sqrt(dx * dx + dy * dy)
                    if r > edge then dx, dy = dx * edge / r, dy * edge / r end
                else
                    local m = math.max(math.abs(dx), math.abs(dy))
                    if m > edge then dx, dy = dx * edge / m, dy * edge / m end
                end
                p:ClearAllPoints()
                p:SetPoint("CENTER", Minimap, "CENTER", dx, dy)
                p:SetFrameLevel(Minimap:GetFrameLevel() + 10)
                p:Show()
            end
        end
    end
    for i = used + 1, #miniPins do miniPins[i]:Hide() end
end

-------------------------------------------------------------------
-- The list window
-------------------------------------------------------------------
local ROWS, ROW_H, WIN_W = 10, 22, 330
local win = CreateFrame("Frame", "DeckNavWaypoints", UIParent)
win:SetSize(WIN_W, 70 + ROWS * ROW_H)
win.defaultPoint = { "CENTER", UIParent, "CENTER", 0, 60 }
win:SetPoint(unpack(win.defaultPoint))
win:SetFrameStrata("DIALOG")
win:EnableMouse(true)
win:Hide()
D.FlatBox(win, 0.92)

local winTitle = win:CreateFontString(nil, "OVERLAY")
winTitle:SetFont(D.FONT, 14, "OUTLINE")
winTitle:SetPoint("TOPLEFT", 10, -10)
winTitle:SetTextColor(1, 0.82, 0)
winTitle:SetText("Waypoints")
local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)
local hint = win:CreateFontString(nil, "OVERLAY")
hint:SetFont(D.FONT, 10, "OUTLINE")
hint:SetPoint("TOPLEFT", 10, -28)
hint:SetTextColor(0.65, 0.65, 0.65)
hint:SetText("Ctrl-click the world map or /way x y to add a point.")

local offset = 0
local rows = {}
for i = 1, ROWS do
    local r = CreateFrame("Button", nil, win)
    r:SetSize(WIN_W - 20, ROW_H)
    r:SetPoint("TOPLEFT", 10, -44 - (i - 1) * ROW_H)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)
    r.num = r:CreateFontString(nil, "OVERLAY")
    r.num:SetFont(D.FONT, 11, "OUTLINE")
    r.num:SetPoint("LEFT", 2, 0)
    r.num:SetWidth(20)
    r.name = r:CreateFontString(nil, "OVERLAY")
    r.name:SetFont(D.FONT, 12, "OUTLINE")
    r.name:SetPoint("LEFT", 24, 0)
    r.name:SetWidth(WIN_W - 150)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.dist = r:CreateFontString(nil, "OVERLAY")
    r.dist:SetFont(D.FONT, 11, "OUTLINE")
    r.dist:SetPoint("RIGHT", -24, 0)
    r.dist:SetTextColor(0.8, 0.8, 0.8)
    -- the X at the end removes the point
    local x = CreateFrame("Button", nil, r)
    x:SetSize(18, 18)
    x:SetPoint("RIGHT", 0, 0)
    x.text = x:CreateFontString(nil, "OVERLAY")
    x.text:SetFont(D.FONT, 13, "OUTLINE")
    x.text:SetPoint("CENTER")
    x.text:SetText("x")
    x.text:SetTextColor(0.9, 0.4, 0.4)
    x:SetScript("OnClick", function() if r.wp then Remove(r.wp) end end)
    -- renaming happens in place: a double click opens an edit box
    local edit = CreateFrame("EditBox", nil, r, "InputBoxTemplate")
    edit:SetSize(WIN_W - 160, 18)
    edit:SetPoint("LEFT", 26, 0)
    edit:SetAutoFocus(true)
    edit:Hide()
    edit:SetScript("OnEnterPressed", function(self)
        if r.wp and self:GetText() ~= "" then r.wp.name = self:GetText() end
        self:Hide()
        Refresh()
    end)
    edit:SetScript("OnEscapePressed", function(self) self:Hide() end)
    r.edit = edit
    r:SetScript("OnClick", function(self, button)
        if not self.wp then return end
        if button == "RightButton" then Remove(self.wp) else Push(self.wp) end
    end)
    r:SetScript("OnDoubleClick", function(self)
        if not self.wp then return end
        self.edit:SetText(self.wp.name)
        self.edit:Show()
        self.edit:HighlightText()
    end)
    rows[i] = r
end
win:EnableMouseWheel(true)
win:SetScript("OnMouseWheel", function(_, delta)
    offset = math.max(0, math.min(math.max(0, #list - ROWS), offset - delta))
    Refresh()
end)

local route = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
route:SetSize(22, 22)
route:SetPoint("BOTTOMLEFT", 8, 6)
route.text = route:CreateFontString(nil, "OVERLAY")
route.text:SetFont(D.FONT, 12, "OUTLINE")
route.text:SetPoint("LEFT", route, "RIGHT", 2, 0)
route.text:SetText("Route: walk them in order")
route:SetScript("OnClick", function(self)
    DeckNavDB.routeMode = self:GetChecked() and true or false
    if not DeckNavDB.routeMode then Push(Nearest()) end
end)

local clear = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
clear:SetSize(80, 22)
clear:SetPoint("BOTTOMRIGHT", -10, 6)
clear:SetText("Clear all")
D.FlattenButton(clear)
clear:SetScript("OnClick", function()
    D.Dialog({ text = "Remove all waypoints?", accept = "Remove", cancel = "Keep",
        onAccept = ns.ClearWaypoints })
end)

local function UpdateWindow()
    if not win:IsShown() then return end
    route:SetChecked(DeckNavDB.routeMode)
    offset = math.max(0, math.min(offset, math.max(0, #list - ROWS)))
    for i, r in ipairs(rows) do
        local wp = list[i + offset]
        r.wp = wp
        if wp then
            r.num:SetText(i + offset)
            r.name:SetText(wp.name)
            if wp.active then r.name:SetTextColor(1, 0.8, 0.25) else r.name:SetTextColor(1, 1, 1) end
            local d = DistanceTo(wp)
            r.dist:SetText(d and ns.DistanceString(d) or ZoneName(wp.mapID))
            r:Show()
        else
            r:Hide()
        end
    end
end

function ns.ToggleWaypoints()
    win:SetShown(not win:IsShown())
    Refresh()
end

-------------------------------------------------------------------
-- Driving it
-------------------------------------------------------------------
Refresh = function()
    UpdateMapPins()
    UpdateMiniPins()
    UpdateWindow()
end

local driver = CreateFrame("Frame")
local since = 0
driver:SetScript("OnUpdate", function(_, dt)
    since = since + dt
    -- the map's pins follow its zoom and pan every frame; the rest 5x a second
    if canvas and WorldMapFrame:IsShown() then UpdateMapPins() end
    if since < 0.2 then return end
    since = 0
    UpdateMiniPins()
    UpdateWindow()
    local wp = Active()
    if wp then
        local d = DistanceTo(wp)
        if d and d < ARRIVE then Arrived(wp) end
    end
end)

local ev = CreateFrame("Frame")
ns.NavEvent(ev, "USER_WAYPOINT_UPDATED")
ev:SetScript("OnEvent", OnUserWaypoint)

function ns.InitWaypoints()
    DeckNavDB.waypoints = DeckNavDB.waypoints or {}
    list = DeckNavDB.waypoints
    if DeckNavDB.routeMode == nil then DeckNavDB.routeMode = false end
    D.MakeMovable(win, "Waypoint list", DeckNavDB)
    -- dragged by its title and edges while open, no Move needed (rows keep their clicks)
    D.MakeDraggable(win)
    EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", function()
        canvas = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
        -- Mists sets no pin of its own on a Ctrl-click (it has no user
        -- waypoint), so the click is heard here, touching nothing of its map.
        -- Map and point are taken on the press: Blizzard's own handler runs
        -- first on the release and may step into a sub-zone's map by then.
        -- A press that became a drag (panning) adds nothing.
        if D.IsMists and WorldMapFrame.ScrollContainer then
            local pressed
            WorldMapFrame.ScrollContainer:HookScript("OnMouseDown", function(self, button)
                pressed = nil
                if button ~= "LeftButton" or not IsControlKeyDown() then return end
                local x, y = self:GetNormalizedCursorPosition()
                pressed = { mapID = WorldMapFrame:GetMapID(), x = x, y = y, cursor = { GetCursorPosition() } }
            end)
            WorldMapFrame.ScrollContainer:HookScript("OnMouseUp", function(_, button)
                local p = pressed
                pressed = nil
                if not p or button ~= "LeftButton" then return end
                local cx, cy = GetCursorPosition()
                if math.abs(cx - p.cursor[1]) > 6 or math.abs(cy - p.cursor[2]) > 6 then return end
                if p.mapID and p.x and p.y and p.x >= 0 and p.x <= 1 and p.y >= 0 and p.y <= 1
                    and ns.UW.CanSetUserWaypointOnMap(p.mapID) then
                    ns.AddWaypoint(p.mapID, p.x, p.y)
                end
            end)
        end
    end)
    -- the active point was Blizzard's waypoint when we left; hand it again
    local wp = Active()
    if wp then Push(wp) else Refresh() end
end

local ADDON, ns = ...

-------------------------------------------------------------------
-- A stand-in for Blizzard's navigation in Mists of Pandaria Classic
-------------------------------------------------------------------
-- Only in DeckUI_Nav_Mists.toc, loaded first (MISTS_PLAN.md, phase 8).
-- Retail's Nav follows what C_SuperTrack holds and hands its waypoints to
-- Blizzard's user waypoint (C_Map.SetUserWaypoint) - Mists has neither,
-- nor C_Navigation or C_Map.GetMapWorldSize. The rest of the module asks
-- ns.ST, ns.UW and ns.NAV (core.lua), which are Blizzard's tables in
-- retail and these here in Mists - exactly the functions Nav calls:
--  ns.ST: what is followed - our waypoint, or the quest Mists itself
--    super-tracks (SetSuperTrackedQuestID, its map arrow); a quest chosen
--    anywhere else (the tracker, the map) takes over from the waypoint.
--  ns.UW: one waypoint of ours in place of Blizzard's pin, the map size
--    in yards from two world positions (HereBeDragons' way).
--  ns.NAV: no route steps and no route distance - the compass then uses
--    the straight line, as retail does without one.
-- Events retail gets from the game (SUPER_TRACKING_CHANGED,
-- USER_WAYPOINT_UPDATED) are sent here to the frames that ask for them
-- through ns.NavEvent, with the frame's own OnEvent.
-------------------------------------------------------------------
local waypoint            -- { uiMapID, position } like Blizzard's UiMapPoint
local followWaypoint = false
local listeners = {}      -- event -> { frame, ... }

local function Fire(event)
    for _, frame in ipairs(listeners[event] or {}) do
        local handler = frame:GetScript("OnEvent")
        if handler then handler(frame, event) end
    end
end

function ns.MistsNavEvent(frame, event)
    listeners[event] = listeners[event] or {}
    table.insert(listeners[event], frame)
end

local function QuestID()
    local id = GetSuperTrackedQuestID()
    return id and id > 0 and id or 0
end

ns.MistsSuperTrack = {
    IsSuperTrackingAnything = function()
        return (followWaypoint and waypoint ~= nil) or QuestID() > 0
    end,
    IsSuperTrackingUserWaypoint = function()
        return followWaypoint and waypoint ~= nil
    end,
    SetSuperTrackedUserWaypoint = function(on)
        followWaypoint = on and true or false
        Fire("SUPER_TRACKING_CHANGED")
    end,
    GetSuperTrackedQuestID = function()
        if followWaypoint and waypoint then return 0 end
        return QuestID()
    end,
    SetSuperTrackedQuestID = function(questID)
        followWaypoint = false
        SetSuperTrackedQuestID(questID or 0)
        Fire("SUPER_TRACKING_CHANGED")
    end,
    IsSuperTrackingCorpse = function() return false end,
    GetSuperTrackedVignette = function() return nil end,
    GetSuperTrackedItemName = function() return nil end,
    GetHighestPrioritySuperTrackingType = function() return nil end,
}

-- a quest focused anywhere (our tracker, Blizzard's map) wins over the waypoint
local watch = CreateFrame("Frame")
watch:RegisterEvent("SUPER_TRACKED_QUEST_CHANGED")
watch:SetScript("OnEvent", function()
    if QuestID() > 0 then followWaypoint = false end
    Fire("SUPER_TRACKING_CHANGED")
end)

-- yards per map width and height: two world positions, the top-left corner
-- and the middle doubled - the world's x runs north, its y west
local function MapWorldSize(mapID)
    local _, topLeft = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
    local _, middle = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0.5, 0.5))
    if not (topLeft and middle) then return 0, 0 end
    local top, left = topLeft:GetXY()
    local midTop, midLeft = middle:GetXY()
    return math.abs(left - midLeft) * 2, math.abs(top - midTop) * 2
end

ns.MistsUserWaypoint = {
    GetUserWaypoint = function() return waypoint end,
    SetUserWaypoint = function(point)
        waypoint = point
        Fire("USER_WAYPOINT_UPDATED")
    end,
    ClearUserWaypoint = function()
        waypoint = nil
        followWaypoint = false
        Fire("USER_WAYPOINT_UPDATED")
    end,
    CanSetUserWaypointOnMap = function(mapID)
        local w, h = MapWorldSize(mapID)
        return w > 0 and h > 0
    end,
    -- the waypoint on another map: through the world position
    GetUserWaypointPositionForMap = function(mapID)
        if not waypoint then return end
        if waypoint.uiMapID == mapID then return waypoint.position end
        local continent, world = C_Map.GetWorldPosFromMapPos(waypoint.uiMapID, waypoint.position)
        if not world then return end
        local _, pos = C_Map.GetMapPosFromWorldPos(continent, world, mapID)
        return pos
    end,
    GetMapWorldSize = MapWorldSize,
}

ns.MistsNavigation = {
    GetDistance = function() return nil end,
    GetNextWaypointForMap = function() return nil end,
}

-- a point the way Blizzard's UiMapPoint.CreateFromCoordinates makes one
function ns.MistsMapPoint(mapID, x, y)
    return { uiMapID = mapID, position = CreateVector2D(x, y) }
end

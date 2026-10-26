local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- DeckUI Nav: finding the way in the world
-------------------------------------------------------------------
-- The owner's choice (2026-10-01): "a healthy mix of everything" - a
-- compass bar at the top, the navigation target with an arrow, distance
-- and arrival time below it, a key binding that steps through the tracked
-- quests, and /way for coordinates. Built from Blizzard's 12.1.0 source
-- (Gethe/wow-ui-source, read 2026-10-01).
--
-- Nothing here replaces Blizzard's navigation: the target is always the
-- one C_SuperTrack holds, so the diamond in the world, the map pin, the
-- quest tracker and our compass all agree. We only ask the game and set
-- the super-tracked quest or user waypoint through its own API.
--
-- Positions are map coordinates (0..1) on the player's best map, turned
-- into yards with C_Map.GetMapWorldSize. In instances the game hands out
-- neither facing nor position, so the compass simply hides there.
-------------------------------------------------------------------
local DEVICE_DEFAULTS = {
    deck = { scale = 0.9 },
    pc   = { scale = 1.0 },
}

local DEFAULTS = {
    compass   = true,   -- the bar at the top
    party     = true,   -- party members on the bar
    vignettes = true,   -- rares and treasures from the minimap on the bar
    panel     = true,   -- target name, arrow, distance, arrival time
    beacon    = true,   -- our beacon in the world instead of Blizzard's diamond (beacon.lua)
}

function ns.DeviceDB()
    return D.DeviceDB(DeckNavDB, DEVICE_DEFAULTS)
end

-- a value we may compare or do arithmetic with
function ns.Plain(...)
    if not issecretvalue then return true end
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return false end
    end
    return true
end

-- Blizzard's navigation - or Mists' stand-in for it (nav_mists.lua, loaded
-- before this file there). Everything in Nav asks these, never the
-- Blizzard tables by name: ns.ST is C_SuperTrack, ns.UW the user waypoint
-- and map size functions of C_Map, ns.NAV C_Navigation.
ns.ST  = ns.MistsSuperTrack or C_SuperTrack
ns.UW  = ns.MistsUserWaypoint or C_Map
ns.NAV = ns.MistsNavigation or C_Navigation
ns.NavEvent = ns.MistsNavEvent or function(frame, event) frame:RegisterEvent(event) end
ns.MapPoint = ns.MistsMapPoint or function(mapID, x, y) return UiMapPoint.CreateFromCoordinates(mapID, x, y) end

-------------------------------------------------------------------
-- Geometry
-------------------------------------------------------------------
-- Angles follow GetPlayerFacing: 0 is north, growing counterclockwise
-- (west is pi/2). Map x grows east, map y grows south.
local TWO_PI = 2 * math.pi

function ns.PlayerPos()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    if not ns.Plain(x, y) or (x == 0 and y == 0) then return end
    return mapID, x, y
end

function ns.UnitPos(mapID, unit)
    local pos = C_Map.GetPlayerMapPosition(mapID, unit)
    if not pos then return end
    local x, y = pos:GetXY()
    if not ns.Plain(x, y) or (x == 0 and y == 0) then return end
    return x, y
end

function ns.Facing()
    local facing = GetPlayerFacing()
    if facing and ns.Plain(facing) then return facing end
end

-- yards per map width and height; 0 for maps without a world size
local sizes = {}
local function MapSize(mapID)
    local s = sizes[mapID]
    if not s then
        local w, h = ns.UW.GetMapWorldSize(mapID)
        s = { (ns.Plain(w, h) and w) or 0, (ns.Plain(w, h) and h) or 0 }
        sizes[mapID] = s
    end
    if s[1] > 0 and s[2] > 0 then return s[1], s[2] end
end

-- angle and distance (yards) from one map point to another
function ns.Bearing(mapID, px, py, tx, ty)
    local w, h = MapSize(mapID)
    if not w then return end
    local east, north = (tx - px) * w, (py - ty) * h
    return math.atan2(-east, north), math.sqrt(east * east + north * north)
end

-- how far an angle lies left (positive) or right (negative) of the facing
function ns.Relative(angle, facing)
    local r = (angle - facing) % TWO_PI
    if r > math.pi then r = r - TWO_PI end
    return r
end

-------------------------------------------------------------------
-- The navigation target
-------------------------------------------------------------------
-- Where the super-tracked thing lies on the given map. Blizzard's own
-- answer comes first: GetNextWaypointForMap is the next step of the
-- route (a portal or flight master when the target is in another zone).
-- The rest are the per-type answers for when it has none.
local function Valid(x, y)
    return x and y and ns.Plain(x, y) and (x ~= 0 or y ~= 0)
end

local function FromVector(v)
    if v then return v:GetXY() end
end

function ns.TargetPos(mapID)
    if not ns.ST.IsSuperTrackingAnything() then return end

    local x, y, desc = ns.NAV.GetNextWaypointForMap(mapID)
    if Valid(x, y) then return x, y, desc end

    if ns.ST.IsSuperTrackingUserWaypoint() then
        x, y = FromVector(ns.UW.GetUserWaypointPositionForMap(mapID))
        if Valid(x, y) then return x, y end
    end

    local questID = ns.ST.GetSuperTrackedQuestID()
    if questID and questID > 0 then
        if C_QuestLog.GetNextWaypointForMap then   -- Mists: none, its quest marks below
            x, y = C_QuestLog.GetNextWaypointForMap(questID, mapID)
            if Valid(x, y) then return x, y end
        end
        if C_TaskQuest and C_TaskQuest.GetQuestLocation then
            x, y = C_TaskQuest.GetQuestLocation(questID, mapID)
            if Valid(x, y) then return x, y end
        end
        for _, q in ipairs(C_QuestLog.GetQuestsOnMap(mapID) or {}) do
            if q.questID == questID and Valid(q.x, q.y) then return q.x, q.y end
        end
    end

    local vignette = ns.ST.GetSuperTrackedVignette()
    if vignette then
        x, y = FromVector(C_VignetteInfo.GetVignettePosition(vignette, mapID))
        if Valid(x, y) then return x, y end
    end

    if ns.ST.IsSuperTrackingCorpse() and C_DeathInfo then
        x, y = FromVector(C_DeathInfo.GetCorpseMapPosition(mapID))
        if Valid(x, y) then return x, y end
    end
end

function ns.TargetName()
    if not ns.ST.IsSuperTrackingAnything() then return end
    local questID = ns.ST.GetSuperTrackedQuestID()
    if questID and questID > 0 then
        -- Mists names a quest through C_QuestLog.GetQuestInfo
        local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
            or C_QuestLog.GetQuestInfo and C_QuestLog.GetQuestInfo(questID)
        if title and title ~= "" then return title end
    end
    if ns.ST.IsSuperTrackingUserWaypoint() then return "Waypoint" end
    if ns.ST.IsSuperTrackingCorpse() then return CORPSE or "Corpse" end
    local name = ns.ST.GetSuperTrackedItemName()
    if name and ns.Plain(name) and name ~= "" then return name end
    return "Target"
end

-------------------------------------------------------------------
-- Stepping through the tracked quests (key binding, /decknav next|prev)
-------------------------------------------------------------------
-- Nearest first, so "next" from nothing takes the closest quest; quests
-- on another continent come last, in the tracker's order.
local function TrackedQuests()
    local list, seen = {}, {}
    local function Add(id)
        if id and id > 0 and not seen[id] then
            seen[id] = true
            -- Mists has no distance to a quest: the tracker's order then
            local distSq, onContinent
            if C_QuestLog.GetDistanceSqToQuest then distSq, onContinent = C_QuestLog.GetDistanceSqToQuest(id) end
            if not (onContinent and ns.Plain(distSq)) then distSq = math.huge end
            list[#list + 1] = { id = id, dist = distSq, order = #list }
        end
    end
    if C_QuestLog.GetQuestIDForQuestWatchIndex then
        for i = 1, C_QuestLog.GetNumQuestWatches() do Add(C_QuestLog.GetQuestIDForQuestWatchIndex(i)) end
        for i = 1, C_QuestLog.GetNumWorldQuestWatches() do Add(C_QuestLog.GetQuestIDForWorldQuestWatchIndex(i)) end
    else
        -- Mists: the old watch list, as its WatchFrame reads it
        for i = 1, GetNumQuestWatches() do
            local logIndex = GetQuestIndexForWatch(i)
            Add(logIndex and select(8, GetQuestLogTitle(logIndex)))
        end
    end
    table.sort(list, function(a, b)
        if a.dist ~= b.dist then return a.dist < b.dist end
        return a.order < b.order
    end)
    return list
end

function ns.Step(dir)
    local list = TrackedQuests()
    if #list == 0 then
        print("DeckUI Nav: no tracked quests to switch between.")
        return
    end
    local current = ns.ST.GetSuperTrackedQuestID()
    local index
    for i, q in ipairs(list) do
        if q.id == current then index = i end
    end
    if index then
        index = (index - 1 + dir) % #list + 1
    else
        index = dir > 0 and 1 or #list
    end
    local id = list[index].id
    ns.ST.SetSuperTrackedQuestID(id)
    if ns.FlashTarget then ns.FlashTarget(("%d/%d"):format(index, #list)) end
end

-- the hub's key bindings (DeckUI/Bindings.xml) call this
D.navStep = function(dir) ns.Step(dir) end

-------------------------------------------------------------------
-- /way x y [name] - a point for the waypoint list (waypoints.lua)
-------------------------------------------------------------------
-- "/way 45.2 67.8", "/way 45,2 67,8" (decimal commas), "/way #2339 45 67"
-- (another map), anything after the numbers is the point's name.
-- "/way list" opens the list, "/way clear" removes every point.
local function SetWaypoint(msg)
    msg = (msg or ""):trim()
    if msg == "" then
        print("DeckUI Nav: /way 45.2 67.8 [name] adds a waypoint on this map, /way #mapID x y on another, /way list shows them, /way clear removes them all.")
        return
    end
    if msg:lower() == "clear" then
        ns.ClearWaypoints()
        print("DeckUI Nav: all waypoints removed.")
        return
    end
    if msg:lower() == "list" then
        ns.ToggleWaypoints()
        return
    end

    local mapID
    local numbers = {}
    local rest = ""
    for token in msg:gmatch("%S+") do
        local id = token:match("^#(%d+)$")
        if #numbers == 2 then
            rest = rest == "" and token or (rest .. " " .. token)
        elseif id and not mapID and #numbers == 0 then
            mapID = tonumber(id)
        else
            local n = tonumber((token:gsub(",$", ""):gsub(",", ".")))
            if not n then break end
            numbers[#numbers + 1] = n
        end
    end
    local x, y = numbers[1], numbers[2]
    if not (x and y) or x < 0 or x > 100 or y < 0 or y > 100 then
        print("DeckUI Nav: could not read coordinates - try /way 45.2 67.8")
        return
    end

    mapID = mapID or C_Map.GetBestMapForUnit("player")
    if not mapID or not ns.UW.CanSetUserWaypointOnMap(mapID) then
        print("DeckUI Nav: this map takes no waypoints.")
        return
    end
    local wp = ns.AddWaypoint(mapID, x / 100, y / 100, rest)
    if wp then print(("DeckUI Nav: waypoint %s added."):format(wp.name)) end
end

-------------------------------------------------------------------
-- Startup
-------------------------------------------------------------------
local function Init()
    DeckNavDB = DeckNavDB or {}
    for k, v in pairs(DEFAULTS) do
        if DeckNavDB[k] == nil then DeckNavDB[k] = v end
    end
    if ns.InitCompass then ns.InitCompass() end
    if ns.ApplyBeacon then ns.ApplyBeacon() end
    if ns.InitWaypoints then ns.InitWaypoints() end
end

if IsLoggedIn() then
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, name)
        if name == ADDON then
            self:UnregisterEvent("ADDON_LOADED")
            Init()
        end
    end)
else
    local login = CreateFrame("Frame")
    login:RegisterEvent("PLAYER_LOGIN")
    login:SetScript("OnEvent", Init)
end

-- /dway always; /way too, unless another addon (TomTom) already has it
SLASH_DECKNAVWAY1 = "/dway"
if not (C_AddOns.IsAddOnLoaded("TomTom") or (hash_SlashCmdList and hash_SlashCmdList["/WAY"])) then
    SLASH_DECKNAVWAY2 = "/way"
end
SlashCmdList.DECKNAVWAY = SetWaypoint

-- /decknav opens the Nav tab; next/prev step the target; debug prints
-- what the compass works with.
SLASH_DECKNAV1 = "/decknav"
SlashCmdList.DECKNAV = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "next" then
        ns.Step(1)
    elseif msg == "prev" then
        ns.Step(-1)
    elseif msg == "waypoints" then
        ns.ToggleWaypoints()
    elseif msg == "debug" then
        local mapID, px, py = ns.PlayerPos()
        local facing = ns.Facing()
        print(("DeckUI Nav: map %s, player %s, facing %s"):format(tostring(mapID),
            px and ("%.3f %.3f"):format(px, py) or "none",
            facing and ("%.0f deg"):format(math.deg(facing)) or "none (instance?)"))
        local w, h
        if mapID then w, h = ns.UW.GetMapWorldSize(mapID) end
        print(("  map size %s x %s yd, super-tracking %s (type %s), name %s"):format(
            tostring(w), tostring(h),
            tostring(ns.ST.IsSuperTrackingAnything()),
            tostring(ns.ST.GetHighestPrioritySuperTrackingType()), tostring(ns.TargetName())))
        if mapID then
            local tx, ty, desc = ns.TargetPos(mapID)
            if tx then
                local angle, dist = ns.Bearing(mapID, px, py, tx, ty)
                print(("  target %.3f %.3f%s, %s yd on the map, %s yd by Blizzard, %s deg off"):format(tx, ty,
                    desc and desc ~= "" and (" (" .. desc .. ")") or "",
                    dist and ("%.0f"):format(dist) or "?", ("%.0f"):format(ns.NAV.GetDistance() or -1),
                    (angle and facing) and ("%.0f"):format(math.deg(ns.Relative(angle, facing))) or "?"))
            else
                print("  target: no position on this map")
            end
        end
        print(("  tracked quests: %d, /way is %s"):format(#TrackedQuests(),
            SLASH_DECKNAVWAY2 and "ours" or "another addon's (use /dway)"))
    else
        D.ToggleConfig("Nav")
    end
end

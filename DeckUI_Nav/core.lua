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
        local w, h = C_Map.GetMapWorldSize(mapID)
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
    if not C_SuperTrack.IsSuperTrackingAnything() then return end

    local x, y, desc = C_Navigation.GetNextWaypointForMap(mapID)
    if Valid(x, y) then return x, y, desc end

    if C_SuperTrack.IsSuperTrackingUserWaypoint() then
        x, y = FromVector(C_Map.GetUserWaypointPositionForMap(mapID))
        if Valid(x, y) then return x, y end
    end

    local questID = C_SuperTrack.GetSuperTrackedQuestID()
    if questID and questID > 0 then
        x, y = C_QuestLog.GetNextWaypointForMap(questID, mapID)
        if Valid(x, y) then return x, y end
        if C_TaskQuest and C_TaskQuest.GetQuestLocation then
            x, y = C_TaskQuest.GetQuestLocation(questID, mapID)
            if Valid(x, y) then return x, y end
        end
        for _, q in ipairs(C_QuestLog.GetQuestsOnMap(mapID) or {}) do
            if q.questID == questID and Valid(q.x, q.y) then return q.x, q.y end
        end
    end

    local vignette = C_SuperTrack.GetSuperTrackedVignette()
    if vignette then
        x, y = FromVector(C_VignetteInfo.GetVignettePosition(vignette, mapID))
        if Valid(x, y) then return x, y end
    end

    if C_SuperTrack.IsSuperTrackingCorpse() and C_DeathInfo then
        x, y = FromVector(C_DeathInfo.GetCorpseMapPosition(mapID))
        if Valid(x, y) then return x, y end
    end
end

function ns.TargetName()
    if not C_SuperTrack.IsSuperTrackingAnything() then return end
    local questID = C_SuperTrack.GetSuperTrackedQuestID()
    if questID and questID > 0 then
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if title and title ~= "" then return title end
    end
    if C_SuperTrack.IsSuperTrackingUserWaypoint() then return "Waypoint" end
    if C_SuperTrack.IsSuperTrackingCorpse() then return CORPSE or "Corpse" end
    local name = C_SuperTrack.GetSuperTrackedItemName()
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
            local distSq, onContinent = C_QuestLog.GetDistanceSqToQuest(id)
            if not (onContinent and ns.Plain(distSq)) then distSq = math.huge end
            list[#list + 1] = { id = id, dist = distSq, order = #list }
        end
    end
    for i = 1, C_QuestLog.GetNumQuestWatches() do Add(C_QuestLog.GetQuestIDForQuestWatchIndex(i)) end
    for i = 1, C_QuestLog.GetNumWorldQuestWatches() do Add(C_QuestLog.GetQuestIDForWorldQuestWatchIndex(i)) end
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
    local current = C_SuperTrack.GetSuperTrackedQuestID()
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
    C_SuperTrack.SetSuperTrackedQuestID(id)
    if ns.FlashTarget then ns.FlashTarget(("%d/%d"):format(index, #list)) end
end

-- the hub's key bindings (DeckUI/Bindings.xml) call this
D.navStep = function(dir) ns.Step(dir) end

-------------------------------------------------------------------
-- /way x y - Blizzard's own user waypoint, super-tracked
-------------------------------------------------------------------
-- "/way 45.2 67.8", "/way 45,2 67,8" (decimal commas), "/way #2339 45 67"
-- (another map), "/way clear". Anything after the numbers is ignored:
-- Blizzard's waypoint has no text of its own.
local function SetWaypoint(msg)
    msg = (msg or ""):trim()
    if msg == "" then
        print("DeckUI Nav: /way 45.2 67.8 sets a waypoint on this map, /way #mapID x y on another, /way clear removes it.")
        return
    end
    if msg:lower() == "clear" then
        C_Map.ClearUserWaypoint()
        print("DeckUI Nav: waypoint cleared.")
        return
    end

    local mapID
    local numbers = {}
    for token in msg:gmatch("%S+") do
        local id = token:match("^#(%d+)$")
        if id and not mapID and #numbers == 0 then
            mapID = tonumber(id)
        else
            local n = tonumber((token:gsub(",$", ""):gsub(",", ".")))
            if not n then break end
            numbers[#numbers + 1] = n
            if #numbers == 2 then break end
        end
    end
    local x, y = numbers[1], numbers[2]
    if not (x and y) or x < 0 or x > 100 or y < 0 or y > 100 then
        print("DeckUI Nav: could not read coordinates - try /way 45.2 67.8")
        return
    end

    mapID = mapID or C_Map.GetBestMapForUnit("player")
    if not mapID or not C_Map.CanSetUserWaypointOnMap(mapID) then
        print("DeckUI Nav: this map takes no waypoints.")
        return
    end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100))
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    local info = C_Map.GetMapInfo(mapID)
    print(("DeckUI Nav: waypoint at %.1f %.1f in %s."):format(x, y, info and info.name or ("map " .. mapID)))
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
    elseif msg == "debug" then
        local mapID, px, py = ns.PlayerPos()
        local facing = ns.Facing()
        print(("DeckUI Nav: map %s, player %s, facing %s"):format(tostring(mapID),
            px and ("%.3f %.3f"):format(px, py) or "none",
            facing and ("%.0f deg"):format(math.deg(facing)) or "none (instance?)"))
        local w, h
        if mapID then w, h = C_Map.GetMapWorldSize(mapID) end
        print(("  map size %s x %s yd, super-tracking %s (type %s), name %s"):format(
            tostring(w), tostring(h),
            tostring(C_SuperTrack.IsSuperTrackingAnything()),
            tostring(C_SuperTrack.GetHighestPrioritySuperTrackingType()), tostring(ns.TargetName())))
        if mapID then
            local tx, ty, desc = ns.TargetPos(mapID)
            if tx then
                local angle, dist = ns.Bearing(mapID, px, py, tx, ty)
                print(("  target %.3f %.3f%s, %s yd on the map, %s yd by Blizzard, %s deg off"):format(tx, ty,
                    desc and desc ~= "" and (" (" .. desc .. ")") or "",
                    dist and ("%.0f"):format(dist) or "?", ("%.0f"):format(C_Navigation.GetDistance() or -1),
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

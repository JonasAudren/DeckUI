local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- DeckUI Map: a square minimap in DeckUI's style and a smaller world map.
-------------------------------------------------------------------
-- minimap.lua and worldmap.lua each register an Init; this file holds
-- what they share: the saved settings (per device, like the other
-- modules), startup and the /map-like slash command.
-------------------------------------------------------------------
ns.inits = {}

function ns.OnInit(fn) ns.inits[#ns.inits + 1] = fn end

-- The Deck's 800 pixels want a smaller minimap and world map than a PC
-- monitor; both are sliders in the Map tab.
local DEVICE_DEFAULTS = {
    deck = { minimapSize = 150, worldMapScale = 0.75 },
    pc   = { minimapSize = 190, worldMapScale = 0.85 },
}

function ns.DeviceDB()
    local d = D.DeviceDB(DeckMapDB)
    for k, v in pairs(DEVICE_DEFAULTS[D.DeviceKey()]) do
        if d[k] == nil then d[k] = v end
    end
    return d
end

-- Shared, not per device
local DEFAULTS = {
    coordinates  = true,    -- player coordinates under the minimap
    clock        = true,
    zoneText     = true,
    buttonsOnHover = true,  -- addon and Blizzard buttons only while the mouse is over the map
    questLogClosed = true,  -- the world map opens without the quest log beside it
    mapControlsOnHover = true, -- the world map's breadcrumbs and buttons only under the mouse
}

local function Init()
    DeckMapDB = DeckMapDB or {}
    for k, v in pairs(DEFAULTS) do
        if DeckMapDB[k] == nil then DeckMapDB[k] = v end
    end
    for _, fn in ipairs(ns.inits) do fn() end
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

-- /deckmap opens the Map tab; /deckmap debug prints what the module sees.
-- Not /map: that name is too likely to be taken by something else.
SLASH_DECKMAP1 = "/deckmap"
SlashCmdList.DECKMAP = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "debug" then
        for _, fn in ipairs(ns.debug or {}) do fn() end
    elseif msg == "reset" then
        if ns.ResetPositions then ns.ResetPositions() end
    else
        D.ToggleConfig("Map")
    end
end

ns.debug = {}
function ns.OnDebug(fn) ns.debug[#ns.debug + 1] = fn end

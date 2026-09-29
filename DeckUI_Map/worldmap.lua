local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- The world map: smaller, and Blizzard's own extras switched on
-------------------------------------------------------------------
-- Blizzard's 12.1.0 world map (read 2026-09-29) already has what a small
-- screen wants, it is just not all reachable:
--  - coordinates for the player and the cursor (CVars
--    worldMapShowPlayerCoords / worldMapShowCursorCoords, in the options),
--  - fading while you move (CVar mapFade) - read by the map, but with no
--    checkbox anywhere in the options,
--  - mouse-wheel zoom and a windowed mode (CVar miniWorldMap, the
--    maximize/minimize button).
-- So those are checkboxes in the Map tab, writing Blizzard's own CVars.
-- The map itself is scaled and restyled (below), nothing else.
--
-- Scale, not position: the map is a UI panel, and the panel manager
-- re-anchors it on every panel update - but divides by the frame's scale
-- when it does, so a scale survives where a SetPoint would not. Maximized,
-- the map sizes itself to the screen in its own coordinates, so a scale
-- below 1 gives a map that leaves the edges of the screen free.
-- SetScale touches no Lua state, so it taints nothing; the map is not a
-- protected frame either.
-------------------------------------------------------------------
function ns.ApplyWorldMapScale()
    if not WorldMapFrame then return end
    WorldMapFrame:SetScale(ns.DeviceDB().worldMapScale)
    -- An open map is re-placed the next time it opens. Calling the panel
    -- manager's UpdateUIPanelPositions from here would run it tainted - the
    -- classic way to get panels blocked in combat later.
end

-- Blizzard's CVars, readable and writable like a settings table, so the
-- ordinary D.Checkbox can drive them.
ns.cvars = setmetatable({}, {
    __index = function(_, name) return GetCVarBool(name) end,
    __newindex = function(_, name, value) SetCVar(name, value and "1" or "0") end,
})

-------------------------------------------------------------------
-- DeckUI look: a plain window, controls only under the mouse
-------------------------------------------------------------------
-- The owner's choice (2026-09-29): a minimal map that always stays a
-- window, never full screen.
--
-- The map's frame is WorldMapFrame.BorderFrame, a PortraitFrameTemplate:
-- stone background, tiled streaks, a nine-slice edge and the round
-- portrait. Those are only art, so they go to alpha 0 - not Hide(), which
-- Blizzard's portrait code could undo - and a thin DeckUI frame sits on
-- top instead.
--
-- What stays: Blizzard reserves a fixed 67-pixel band above the map for
-- the title and the zone breadcrumbs (TITLE_CANVAS_SPACER_FRAME_HEIGHT).
-- Giving it back to the map would mean rewriting the size Blizzard's
-- Minimize() hands to the panel manager - run tainted, that is how
-- panels end up blocked in combat. So the band stays, dark, and holds the
-- breadcrumbs while the mouse is over the map.
--
-- Always a window: Blizzard's own CVar miniWorldMap, read on every open,
-- with the maximize button made invisible and unclickable. The quest log
-- starts closed through its own CVar questLogOpen; the side panel toggle
-- on the map still opens it.
local TITLE_BAND = 67

local function Fade(region)
    if region then region:SetAlpha(0) end
end

-- invisible and deaf to the mouse, for buttons that must not be used
local function Remove(frame)
    if not frame then return end
    frame:SetAlpha(0)
    frame:EnableMouse(false)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.EnableMouse then child:EnableMouse(false) end
    end
end

-- the controls that appear with the mouse; readouts (coordinates, zone
-- timer, threat, bounty board) stay visible
local function HoverControls()
    local list = {}
    local border = WorldMapFrame.BorderFrame
    if border and border.CloseButton then list[#list + 1] = border.CloseButton end
    if WorldMapFrame.NavBar then list[#list + 1] = WorldMapFrame.NavBar end
    if WorldMapFrame.SidePanelToggle then list[#list + 1] = WorldMapFrame.SidePanelToggle end
    for _, f in ipairs(WorldMapFrame.overlayFrames or {}) do
        -- the floor dropdown and the map filter are dropdown buttons
        if f.GetObjectType and f:GetObjectType() == "DropdownButton" then list[#list + 1] = f end
    end
    return list
end

local styled = false
local hovering

local function SetControlsShown(state)
    if hovering == state then return end
    hovering = state
    local alpha = (state or not DeckMapDB.mapControlsOnHover) and 1 or 0
    for _, f in ipairs(HoverControls()) do f:SetAlpha(alpha) end
end

function ns.ApplyMapHover()
    hovering = nil
    SetControlsShown(WorldMapFrame and WorldMapFrame:IsMouseOver())
end

local function StyleWorldMap()
    if styled or not WorldMapFrame then return end
    styled = true
    local border = WorldMapFrame.BorderFrame
    if border then
        Fade(border.NineSlice)
        Fade(border.PortraitContainer)
        Fade(border.Bg)
        Fade(border.TopTileStreaks)
        Fade(border.InsetBorderTop)
        Fade(border.TitleContainer)
        Remove(border.Tutorial)
        Remove(border.MaximizeMinimizeFrame)
    end

    -- the frame: a dark band behind the breadcrumbs, and a one-pixel edge
    -- around the whole window
    local frame = CreateFrame("Frame", nil, border or WorldMapFrame, "BackdropTemplate")
    frame:SetAllPoints(WorldMapFrame)
    frame:SetFrameLevel(math.max(0, (border or WorldMapFrame):GetFrameLevel() - 1))
    frame:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    local band = frame:CreateTexture(nil, "BACKGROUND")
    band:SetColorTexture(0.05, 0.05, 0.05, 0.95)
    band:SetPoint("TOPLEFT", 1, -1)
    band:SetPoint("TOPRIGHT", -1, -1)
    band:SetHeight(TITLE_BAND - 1)

    -- the hover check runs only while the map is open (frame hides with it)
    local since = 0
    frame:SetScript("OnUpdate", function(_, dt)
        since = since + dt
        if since < 0.1 then return end
        since = 0
        SetControlsShown(WorldMapFrame:IsMouseOver())
    end)
    ns.ApplyMapHover()
end

-- Blizzard reads both CVars each time the map opens; the player's own
-- toggles in a session still work, the next login starts clean again.
local function ApplyMapCVars()
    SetCVar("miniWorldMap", "1")
    if DeckMapDB.questLogClosed then SetCVar("questLogOpen", "0") end
end

-------------------------------------------------------------------
-- Movable: the map leaves the panel manager
-------------------------------------------------------------------
-- As a UI panel (area "left") the map is re-anchored by the panel
-- manager on every panel update, so a position of ours would not last.
-- With "UIPanelLayout-defined" set and no area, ShowUIPanel/HideUIPanel
-- simply Show/Hide it and leave its points alone - the same thing done to
-- the bank frame in DeckUI Bags, and what the usual map addons do.
-- Escape closes it through UISpecialFrames instead of the panel manager.
-- The price: other left-side panels (character, spellbook) no longer
-- make room for it, they open on top.
--
-- Dragged by the strip above the breadcrumbs, not the map itself: a drag
-- on the map pans it when zoomed in. The strip sits below Blizzard's
-- close button (that frame is HIGH strata), so the button still works.
local DRAG_STRIP = 24

local function MakeWorldMapMovable()
    WorldMapFrame:SetAttribute("UIPanelLayout-defined", true)
    WorldMapFrame:SetAttribute("UIPanelLayout-area", nil)
    tinsert(UISpecialFrames, "WorldMapFrame")

    WorldMapFrame.defaultPoint = { "TOPLEFT", UIParent, "TOPLEFT", 16, -116 }
    WorldMapFrame:ClearAllPoints()
    WorldMapFrame:SetPoint(unpack(WorldMapFrame.defaultPoint))
    D.MakeMovable(WorldMapFrame, "World map", DeckMapDB)

    local handle = CreateFrame("Frame", nil, WorldMapFrame)
    handle:SetPoint("TOPLEFT", 1, -1)
    handle:SetPoint("TOPRIGHT", -1, -1)
    handle:SetHeight(DRAG_STRIP)
    handle:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 1)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function() WorldMapFrame:StartMoving() end)
    handle:SetScript("OnDragStop", function()
        WorldMapFrame:StopMovingOrSizing()
        -- top-left, so the quest log opening widens it to the right
        D.PinTopLeft(WorldMapFrame)
    end)
end

-------------------------------------------------------------------
-- The quest log beside the map, in the same style
-------------------------------------------------------------------
-- QuestMapFrame (Blizzard_UIPanels_Game, 12.1.0): parchment backgrounds
-- (atlas QuestLog-main-background), a filigree frame (QuestLogBorder-
-- FrameTemplate: questlog-frame + questlog-frame-filigree) on the quest
-- list, the quest details and the events list, and three side tabs
-- (LargeSideTabButtonTemplate: common-sidetab art). All of it is art, so
-- it goes to alpha 0 and one dark panel with a thin edge sits behind the
-- lot; the tabs get flat dark squares. Quest lines, headers, buttons and
-- the rewards stay Blizzard's.
local function FadePath(root, ...)
    local f = root
    for i = 1, select("#", ...) do
        f = f and f[select(i, ...)]
    end
    if f and f.SetAlpha then f:SetAlpha(0) end
end

local function StyleTab(tab)
    if not tab or tab.deckStyled then return end
    tab.deckStyled = true
    Fade(tab.Background)
    local bg = tab:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
    bg:SetPoint("TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", -2, 2)
    local edge = CreateFrame("Frame", nil, tab, "BackdropTemplate")
    edge:SetPoint("TOPLEFT", 2, -2)
    edge:SetPoint("BOTTOMRIGHT", -2, 2)
    edge:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    edge:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    -- the selected tab and the hover: flat colour instead of the glow art
    if tab.SelectedTexture then
        tab.SelectedTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        tab.SelectedTexture:SetVertexColor(0.9, 0.75, 0.2, 0.25)
        tab.SelectedTexture:ClearAllPoints()
        tab.SelectedTexture:SetPoint("TOPLEFT", 3, -3)
        tab.SelectedTexture:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    Fade(tab.TabGlow)
    if tab.HighlightTexture then
        tab.HighlightTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
        tab.HighlightTexture:SetVertexColor(1, 1, 1, 0.08)
        tab.HighlightTexture:ClearAllPoints()
        tab.HighlightTexture:SetPoint("TOPLEFT", 3, -3)
        tab.HighlightTexture:SetPoint("BOTTOMRIGHT", -3, 3)
    end
end

local function StyleQuestLog()
    local q = QuestMapFrame
    if not q or q.deckStyled then return end
    q.deckStyled = true

    FadePath(q, "QuestsFrame", "ScrollFrame", "Background")
    FadePath(q, "QuestsFrame", "BorderFrame")
    FadePath(q, "QuestsFrame", "DetailsFrame", "Bg")
    FadePath(q, "QuestsFrame", "DetailsFrame", "SealMaterialBG")
    FadePath(q, "QuestsFrame", "DetailsFrame", "BorderFrame")
    FadePath(q, "EventsFrame", "BorderFrame")
    FadePath(q, "EventsFrame", "ScrollBox", "Background")
    -- the map legend and whatever else shares the content area
    for _, content in ipairs(q.ContentFrames or {}) do
        FadePath(content, "BorderFrame")
        FadePath(content, "Background")
    end

    local panel = CreateFrame("Frame", nil, q, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", q.QuestsFrame or q, "TOPLEFT", -2, 2)
    panel:SetPoint("BOTTOMRIGHT", q.QuestsFrame or q, "BOTTOMRIGHT", 2, -2)
    panel:SetFrameLevel(math.max(0, q:GetFrameLevel()))
    panel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    panel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    for _, tab in ipairs(q.TabButtons or {}) do StyleTab(tab) end
    StyleTab(q.QuestsTab)
    StyleTab(q.EventsTab)
    StyleTab(q.MapLegendTab)
end

ns.OnInit(function()
    ns.ApplyWorldMapScale()
    ApplyMapCVars()
    StyleWorldMap()
    StyleQuestLog()
    MakeWorldMapMovable()
end)

ns.OnDebug(function()
    if not WorldMapFrame then
        print("DeckUI Map: WorldMapFrame not found")
        return
    end
    print(("DeckUI Map: world map scale=%.2f maximized=%s, fade=%s, player coords=%s, cursor coords=%s"):format(
        WorldMapFrame:GetScale(), tostring(WorldMapFrame:IsMaximized()),
        tostring(GetCVarBool("mapFade")), tostring(GetCVarBool("worldMapShowPlayerCoords")),
        tostring(GetCVarBool("worldMapShowCursorCoords"))))
end)

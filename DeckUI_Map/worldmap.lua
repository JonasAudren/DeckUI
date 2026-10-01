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

-------------------------------------------------------------------
-- The map's buttons in DeckUI's look
-------------------------------------------------------------------
-- Blizzard's buttons are all art (12.1.0, NavigationBar.xml and
-- Blizzard_WorldMapTemplates.xml): stone breadcrumbs with chevrons
-- between them, the red close button, round minimap-style borders on the
-- filter and map-pin buttons. The art goes to alpha 0 and each button
-- gets what the quest log tabs have: a dark square with a thin edge, a
-- faint white highlight, gold for the current or active state. Text,
-- icons and the dropdown arrows stay Blizzard's, and so do all the
-- scripts - only textures change, so nothing is tainted.
local WHITE = "Interface\\Buttons\\WHITE8x8"

-- every texture of a frame to alpha 0, except the ones in keep
local function FadeTextures(frame, keep)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") and not (keep and keep[region]) then
            region:SetAlpha(0)
        end
    end
end

-- a dark square with a one-pixel edge, between two corners of anchor
local function Square(owner, anchor, left, top, right, bottom)
    local bg = owner:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
    bg:SetPoint("TOPLEFT", anchor, "TOPLEFT", left, top)
    bg:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", right, bottom)
    local edge = CreateFrame("Frame", nil, owner, "BackdropTemplate")
    edge:SetAllPoints(bg)
    edge:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
    edge:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    return bg
end

-- One of Blizzard's textures turned into a flat colour over the square.
-- The alpha goes into the colour itself: SetTexture(WHITE) plus a vertex
-- colour came out fully opaque on these textures - a solid white and a
-- solid gold crumb (owner's screenshot, 2026-09-30).
local function Flat(tex, square, r, g, b, a)
    if not tex then return end
    tex:SetColorTexture(r, g, b, a)
    tex:SetVertexColor(1, 1, 1, 1)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", square, "TOPLEFT", 1, -1)
    tex:SetPoint("BOTTOMRIGHT", square, "BOTTOMRIGHT", -1, 1)
    tex:SetAlpha(1)
end

-- A breadcrumb. The next one is anchored xoffset pixels into it (home -15,
-- overflow -18, the rest 0), so the square stops short of that and two
-- pixels of band stay between neighbours.
local function StyleNavButton(b)
    if not b or b.deckStyled then return end
    b.deckStyled = true
    FadeTextures(b)
    local square = Square(b, b, 1, -2, (b.xoffset or 0) - 1, 2)
    Flat(b:GetHighlightTexture(), square, 1, 1, 1, 0.08)
    -- the last crumb, the map on screen
    Flat(b.selected, square, 0.9, 0.75, 0.2, 0.25)
    local arrow = b.MenuArrowButton
    if arrow then
        -- Blizzard shows a square button behind the arrow on mouse-over
        arrow:HookScript("OnEnter", function(self)
            self.NormalTexture:SetAlpha(0)
            self.PushedTexture:SetAlpha(0)
        end)
        local hl = arrow:GetHighlightTexture()
        if hl then hl:SetAlpha(0) end
    end
    -- the overflow button's only content was its art: a double arrow
    if b == WorldMapFrame.NavBar.overflow then
        local glyph = b:CreateFontString(nil, "OVERLAY")
        glyph:SetFont(D.FONT, 14, "OUTLINE")
        glyph:SetTextColor(1, 0.82, 0)
        glyph:SetPoint("CENTER", square)
        glyph:SetText("\194\171")   -- a left guillemet
    end
end

-- The breadcrumbs come and go with the map shown, so every pass of
-- Blizzard's NavBar_CheckLength (after each add and reset) styles the new
-- ones. The bar itself loses its stone background, bevel and gloss.
local function StyleNavBar(bar)
    if not bar.deckStyled then
        bar.deckStyled = true
        FadeTextures(bar)
        if bar.overlay then bar.overlay:SetAlpha(0) end
    end
    StyleNavButton(bar.home)
    StyleNavButton(bar.overflow)
    for _, b in ipairs(bar.navList or {}) do StyleNavButton(b) end
    for _, b in ipairs(bar.freeButtons or {}) do StyleNavButton(b) end
end

-- the filter button (with its counter) and the map-pin button: round
-- minimap-style art around an icon, which stays
local function StyleRoundButton(b)
    if b.deckStyled then return end
    b.deckStyled = true
    FadeTextures(b, { [b.Icon] = true, [b.IconOverlay or b.Icon] = true })
    local square = Square(b, b.Icon, -4, 4, 4, -4)
    Flat(b:GetHighlightTexture(), square, 1, 1, 1, 0.08)
    -- the pin button's "tracking" glow
    Flat(b.ActiveTexture, square, 0.9, 0.75, 0.2, 0.25)
end

local function StyleCloseButton(b)
    if not b or b.deckStyled then return end
    b.deckStyled = true
    FadeTextures(b)
    local square = Square(b, b, 3, -3, -3, 3)
    Flat(b:GetHighlightTexture(), square, 1, 1, 1, 0.08)
    local x = b:CreateFontString(nil, "OVERLAY")
    x:SetFont(D.FONT, 13, "OUTLINE")
    x:SetTextColor(0.85, 0.85, 0.85)
    x:SetPoint("CENTER", square, "CENTER", 1, 0)
    x:SetText("X")
end

local function StyleMapButtons()
    local border = WorldMapFrame.BorderFrame
    StyleCloseButton(border and border.CloseButton)
    if WorldMapFrame.NavBar then
        StyleNavBar(WorldMapFrame.NavBar)
        hooksecurefunc("NavBar_CheckLength", function(bar)
            if bar == WorldMapFrame.NavBar then StyleNavBar(bar) end
        end)
    end
    for _, f in ipairs(WorldMapFrame.overlayFrames or {}) do
        if f.Icon and (f.FilterCounter or f.ActiveTexture) then StyleRoundButton(f) end
    end
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
    -- around the whole window. Two frames, because the BorderFrame is HIGH
    -- strata: the edge may sit up there, the band may not - as a child of
    -- the BorderFrame it drew over the breadcrumbs and all but hid them
    -- (owner's screenshot, 2026-09-30). The band hangs off the map itself,
    -- at its own frame level, below every child of the map.
    local frame = CreateFrame("Frame", nil, border or WorldMapFrame, "BackdropTemplate")
    frame:SetAllPoints(WorldMapFrame)
    frame:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    local bandFrame = CreateFrame("Frame", nil, WorldMapFrame)
    bandFrame:SetAllPoints(WorldMapFrame)
    bandFrame:SetFrameLevel(WorldMapFrame:GetFrameLevel())
    local band = bandFrame:CreateTexture(nil, "BACKGROUND")
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
    StyleMapButtons()
    ns.ApplyMapHover()
end

-- Blizzard reads both CVars each time the map opens; the player's own
-- toggles in a session still work, the next login starts clean again.
local function ApplyMapCVars()
    SetCVar("miniWorldMap", "1")
    if DeckMapDB.questLogClosed then SetCVar("questLogOpen", "0") end
end

-------------------------------------------------------------------
-- Movable: our place after every panel update
-------------------------------------------------------------------
-- As a UI panel (area "left") the map is re-anchored by the panel
-- manager on every panel update, so a position of ours would not last on
-- its own. A post-hook on UpdateUIPanelPositions puts it back each time:
-- SetPoint leaves no Lua state behind, so the panel manager stays clean.
--
-- NOT the attribute trick ("UIPanelLayout-defined" written by us, the
-- first version): ShowUIPanel reads that attribute every time the map
-- opens, and an attribute set by addon code is tainted - the whole
-- opening then ran tainted, every map pin was set up tainted, and the
-- first widget tooltip from a tainted pin created GameTooltip's shared
-- widget container tainted. From then on any tooltip with a widget failed
-- on a secret width: "Secret values are only allowed during untainted
-- execution" in Blizzard_UIWidgetTemplateTextWithState.lua, hovering a
-- rare's vignette on the map (owner's report, 2026-10-01).
-- The price of the hook: other left-side panels still make room for the
-- map's slot, as if it had not moved.
--
-- Dragged by the strip above the breadcrumbs, not the map itself: a drag
-- on the map pans it when zoomed in. The strip sits below Blizzard's
-- close button (that frame is HIGH strata), so the button still works.
local DRAG_STRIP = 24

local function MakeWorldMapMovable()
    WorldMapFrame.defaultPoint = { "TOPLEFT", UIParent, "TOPLEFT", 16, -116 }
    WorldMapFrame:ClearAllPoints()
    WorldMapFrame:SetPoint(unpack(WorldMapFrame.defaultPoint))
    D.MakeMovable(WorldMapFrame, "World map", DeckMapDB)
    hooksecurefunc("UpdateUIPanelPositions", function()
        if WorldMapFrame:IsShown() then D.ApplyPosition(WorldMapFrame) end
    end)

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
    Fade(tab.TabGlow)
    local square = Square(tab, tab, 2, -2, -2, 2)
    -- the selected tab and the hover: flat colour instead of the glow art
    Flat(tab.SelectedTexture, square, 0.9, 0.75, 0.2, 0.25)
    Flat(tab.HighlightTexture, square, 1, 1, 1, 0.08)
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
    -- every part below needs the map; without it the init chain would stop
    if not WorldMapFrame then return end
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
    -- which breadcrumb is which, if one of them looks wrong
    local bar = WorldMapFrame.NavBar
    if bar then
        local function Describe(label, b)
            if not b then return end
            print(("  %s: %s shown=%s width=%.0f xoffset=%s styled=%s"):format(label,
                tostring(b:GetText()), tostring(b:IsShown()), b:GetWidth(),
                tostring(b.xoffset), tostring(b.deckStyled)))
        end
        Describe("home", bar.home)
        Describe("overflow", bar.overflow)
        for i, b in ipairs(bar.navList or {}) do Describe("crumb " .. i, b) end
    end
end)

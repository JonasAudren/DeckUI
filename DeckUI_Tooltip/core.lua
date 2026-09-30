local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- DeckUI Tooltip: the mouse-over tooltip in DeckUI's style
-------------------------------------------------------------------
-- Built from Blizzard's 12.1.0 source (Gethe/wow-ui-source, read
-- 2026-09-30). GameTooltip is ONE frame the whole game shares, like the
-- widget frames the Quests module once tainted (see CLAUDE.md), so the
-- rules here are strict:
--  - never write a field onto a tooltip, its NineSlice or its status bar:
--    Blizzard reads its own fields later, and a field written by us would
--    make that code run tainted - fatal once a secret value is involved;
--    what we need to remember lives in tables of our own, keyed by frame;
--  - only call methods that change what is drawn (alpha, colour, points,
--    textures) - they leave no Lua state behind;
--  - never call tooltip:Show(), SetWatch or RefreshData ourselves: Show
--    runs Blizzard's OnShow padding arithmetic on widths that can be
--    secret. Lines are added from TooltipDataProcessor post-calls, which
--    Blizzard runs before its own Show (lines.lua);
--  - check a unit's name, class or GUID with issecretvalue before using
--    it: they are secret for units that are not player-controlled.
-------------------------------------------------------------------
local WHITE = "Interface\\Buttons\\WHITE8x8"
local GRAY = { 0.3, 0.3, 0.3 }

local DEVICE_DEFAULTS = {
    deck = { scale = 1.0 },
    pc   = { scale = 1.0 },
}

local DEFAULTS = {
    fixedAnchor = true,    -- at the "Tooltip" frame instead of Blizzard's corner
    classColors = true,    -- players: name and border in their class colour
    playerInfo  = true,    -- players: spec and item level
    targetLine  = true,    -- what the unit is targeting
    ids         = true,    -- item, spell and NPC IDs while Shift is held
}

function ns.DeviceDB()
    return D.DeviceDB(DeckTooltipDB, DEVICE_DEFAULTS)
end

-- a value we may compare, concatenate or do arithmetic with
function ns.Plain(...)
    if not issecretvalue then return true end
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return false end
    end
    return true
end

-------------------------------------------------------------------
-- Look: a dark square with a thin edge instead of Blizzard's frame
-------------------------------------------------------------------
-- SharedTooltip_SetBackdropStyle (SharedTooltipTemplates.lua) re-applies
-- Blizzard's NineSlice on every hide and for special items. After it,
-- the NineSlice goes to alpha 0 - Blizzard only ever Shows and Hides it,
-- so the alpha lasts - and a frame of ours sits one level below the
-- tooltip, under its text. The border takes the item quality or class
-- colour for one showing (lines.lua) and falls back to grey on the next.
local STYLED = {
    "GameTooltip", "ItemRefTooltip",
    "ShoppingTooltip1", "ShoppingTooltip2",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2",
}
local styled = {}        -- tooltip -> true
local backdrops = {}     -- tooltip -> our frame
local borderColor = {}   -- tooltip -> { r, g, b } for the current showing

local function Backdrop(tooltip)
    local f = backdrops[tooltip]
    if not f then
        f = CreateFrame("Frame", nil, tooltip, "BackdropTemplate")
        f:SetAllPoints(tooltip)
        f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        backdrops[tooltip] = f
    end
    f:SetFrameLevel(math.max(0, tooltip:GetFrameLevel() - 1))
    return f
end

local function ApplyStyle(tooltip)
    if not styled[tooltip] then return end
    if tooltip.NineSlice then tooltip.NineSlice:SetAlpha(0) end
    local f = Backdrop(tooltip)
    local c = borderColor[tooltip] or GRAY
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    f:SetBackdropBorderColor(c[1], c[2], c[3], 1)
end

-- for lines.lua: this showing's border colour
function ns.SetBorderColor(tooltip, r, g, b)
    if not styled[tooltip] then return end
    borderColor[tooltip] = { r, g, b }
    ApplyStyle(tooltip)
end

-------------------------------------------------------------------
-- The health bar: Blizzard's, restyled
-------------------------------------------------------------------
-- GameTooltipStatusBar watches the unit itself (a secure mixin that feeds
-- it UnitPercentHealthFromGUID, a secret value). Its logic stays
-- untouched; it only gets a flat texture, a dark background and a thin
-- edge, and sits closer under the tooltip.
local function StyleHealthBar()
    local bar = GameTooltipStatusBar
    if not bar then return end
    bar:SetStatusBarTexture(WHITE)
    bar:SetHeight(4)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 1, -2)
    bar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -1, -2)
    local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
    local edge = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
    edge:SetBackdropBorderColor(GRAY[1], GRAY[2], GRAY[3], 1)
end

-------------------------------------------------------------------
-- Position: a fixed place per device
-------------------------------------------------------------------
-- Blizzard puts tooltips without an owner of their own through
-- GameTooltip_SetDefaultAnchor (the HUD tooltip corner of Edit Mode). A
-- post-hook moves just those to our anchor, which /deck unlock drags and
-- which remembers a place per device. Tooltips anchored to a button or a
-- frame keep their place. The tooltip grows upwards from the anchor, with
-- room below for the health bar.
local anchor = CreateFrame("Frame", "DeckTooltipAnchor", UIParent)
anchor:SetSize(200, 60)
anchor.defaultPoint = { "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 140 }
anchor:SetPoint(unpack(anchor.defaultPoint))

hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip)
    if tooltip ~= GameTooltip or not (DeckTooltipDB and DeckTooltipDB.fixedAnchor) then return end
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 8)
end)

-- the comparison tooltips hang beside GameTooltip, so they scale with it
function ns.ApplyScale()
    local scale = ns.DeviceDB().scale
    for _, name in ipairs({ "GameTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
        if _G[name] then _G[name]:SetScale(scale) end
    end
end

-------------------------------------------------------------------
-- Startup
-------------------------------------------------------------------
local function Init()
    DeckTooltipDB = DeckTooltipDB or {}
    for k, v in pairs(DEFAULTS) do
        if DeckTooltipDB[k] == nil then DeckTooltipDB[k] = v end
    end
    D.MakeMovable(anchor, "Tooltip", DeckTooltipDB)

    for _, name in ipairs(STYLED) do
        local tooltip = _G[name]
        if tooltip then
            styled[tooltip] = true
            ApplyStyle(tooltip)
        end
    end
    hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tooltip, _, embedded)
        if embedded then return end
        borderColor[tooltip] = nil   -- a new showing starts grey
        ApplyStyle(tooltip)
    end)
    StyleHealthBar()
    ns.ApplyScale()
    if ns.InitLines then ns.InitLines() end
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

-- /decktip opens the Tooltip tab; /decktip debug prints what it sees.
SLASH_DECKTOOLTIP1 = "/decktip"
SlashCmdList.DECKTOOLTIP = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "debug" then
        local n = 0
        for _ in pairs(styled) do n = n + 1 end
        print(("DeckUI Tooltip: %d tooltips styled, fixed anchor=%s, scale=%.2f, NineSlice alpha=%.2f"):format(
            n, tostring(DeckTooltipDB.fixedAnchor), ns.DeviceDB().scale,
            GameTooltip.NineSlice and GameTooltip.NineSlice:GetAlpha() or -1))
        if ns.PrintLines then ns.PrintLines() end
    else
        D.ToggleConfig("Tooltip")
    end
end

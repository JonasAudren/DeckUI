local ADDON, ns = ...
local D = DeckUI
local LAB = LibStub("LibActionButton-1.0")

ns.FONT = D.FONT

-------------------------------------------------------------------
-- Dimensions
-------------------------------------------------------------------
ns.SIZE     = 40
ns.GAP      = 2     -- gap between the four buttons of one cross
ns.SIZE_MID = 26
ns.GAP_MID  = 2

local function ClusterWidth(size, gap) return 2 * (size + gap) + size end

local CLUSTER_W       = ClusterWidth(ns.SIZE, ns.GAP)
local CLUSTER_W_MID   = ClusterWidth(ns.SIZE_MID, ns.GAP_MID)
local CLUSTER_GAP     = 18    -- gap between the two crosses of one half
local HALF_W          = 2 * CLUSTER_W + CLUSTER_GAP
local HALF_GAP        = 70    -- gap between left and right half
local RING            = 3     -- ring sticks out this far around a button

-- The small LT+RT cross of each half sits in the gap between that half's
-- two crosses, raised so its bottom button clears the side buttons of the
-- big crosses and its own side buttons slip between their top buttons.
local HALF_X       = HALF_W / 2 + HALF_GAP / 2
local MID_OFFSET_Y = (ns.SIZE / 2 + RING)                     -- top of the big side buttons
                   + (ns.SIZE_MID + ns.GAP_MID)                -- small cross: centre to bottom button centre
                   + (ns.SIZE_MID / 2 + RING) + 2              -- bottom button radius + air

-------------------------------------------------------------------
-- Anchor
-------------------------------------------------------------------
local anchor = CreateFrame("Frame", "DeckCrossAnchor", UIParent)
anchor:SetSize(2 * HALF_W + HALF_GAP, CLUSTER_W)   -- (middle crosses hang above this box)
anchor.defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 0, 90 }
anchor:SetPoint(unpack(anchor.defaultPoint))
ns.anchor = anchor

function ns.DeviceDB() return D.DeviceDB(DeckCrossDB) end

function ns.SetScale(value)
    ns.DeviceDB().scale = value
    anchor:SetScale(value)
end

-------------------------------------------------------------------
-- Secure header
-------------------------------------------------------------------
local header = CreateFrame("Frame", "DeckCrossHeader", anchor, "SecureHandlerStateTemplate")
header:SetAttribute("_onstate-page", [[
    self:SetAttribute("state", newstate)
    control:ChildUpdate("state", newstate)
]])
ns.header = header

-- page macro like Blizzard's main bar
local function PageMacro()
    local m = ""
    m = m .. "[overridebar]" .. GetOverrideBarIndex() .. ";"
    m = m .. "[shapeshift]"  .. GetTempShapeshiftBarIndex() .. ";"
    m = m .. "[vehicleui]"   .. GetVehicleBarIndex() .. ";"
    m = m .. "[possessbar]"  .. GetVehicleBarIndex() .. ";"
    m = m .. "[bonusbar:5]"  .. GetBonusBarIndex() .. ";"
    m = m .. "[bar:2]2;[bar:3]3;[bar:4]4;[bar:5]5;[bar:6]6;"
    m = m .. "[bonusbar:1]7;[bonusbar:2]8;[bonusbar:3]9;[bonusbar:4]10;1"
    return m
end
-- Every index PageMacro() can return needs a registered state, or the
-- buttons fall back to type "empty" and show nothing on that page.
-- GetOverrideBarIndex() is 18 on retail, far above the 14 pages we used
-- to register - that is why mounts and vehicles that take over the bar
-- came up blank. Derive the count from the same API the macro uses so a
-- changed constant cannot silently break it again.
local NUM_PAGES = math.max(
    NUM_ACTIONBAR_PAGES or 6,
    GetOverrideBarIndex(),
    GetVehicleBarIndex(),
    GetTempShapeshiftBarIndex(),
    GetBonusBarIndex()
)

-------------------------------------------------------------------
-- Key labels: our own glyphs from DeckUI_Cross\textures (TGA files)
-------------------------------------------------------------------
local TEX_PATH = "Interface\\AddOns\\DeckUI_Cross\\textures\\"

-- cluster 1 = D-pad (up, right, down, left)
-- cluster 2 = face buttons in Steam Deck / Xbox layout (Y, B, A, X)
local LABEL_TEX = {
    { "dpad_up", "dpad_right", "dpad_down", "dpad_left" },
    { "face_y",  "face_b",     "face_a",    "face_x"    },
}
-- The label sits INSIDE the button on its outward edge (top button ->
-- top edge etc.), so it can never collide with a neighbouring button.
local LABEL_EDGE = { "TOP", "RIGHT", "BOTTOM", "LEFT" }

ns.labels = {}

local function MakeLabel(b, cluster, pos, size)
    local edge = LABEL_EDGE[pos]
    local labelSize = math.floor(size * 0.4)
    local holder = CreateFrame("Frame", nil, b)
    holder:SetSize(labelSize, labelSize)
    holder:SetPoint(edge, b, edge, 0, 0)
    holder:SetFrameLevel(b:GetFrameLevel() + 5)
    holder.cluster, holder.pos, holder.button = cluster, pos, b

    -- controller glyph
    local glyph = holder:CreateTexture(nil, "OVERLAY")
    glyph:SetAllPoints()
    glyph:SetTexture(TEX_PATH .. LABEL_TEX[cluster][pos])
    holder.glyph = glyph

    -- keyboard key (PC): dark disc + short key name
    local disc = holder:CreateTexture(nil, "BACKGROUND")
    disc:SetAllPoints()
    disc:SetTexture(D.DISC)
    disc:SetVertexColor(0.1, 0.1, 0.1, 0.9)
    holder.disc = disc
    local text = holder:CreateFontString(nil, "OVERLAY")
    text:SetFont(D.FONT, math.max(8, labelSize - 6), "OUTLINE")
    text:SetPoint("CENTER")
    holder.text = text

    table.insert(ns.labels, holder)
    return holder
end

-- mode "pad" shows the controller glyphs, "keys" the PC key names;
-- textFor(button) returns the key text for a button in "keys" mode
function ns.SetLabelMode(mode, textFor)
    for _, l in ipairs(ns.labels) do
        local pad = (mode == "pad")
        l.glyph:SetShown(pad)
        if pad then
            l.disc:Hide(); l.text:Hide()
        else
            local t = textFor and textFor(l.button) or ""
            l.text:SetText(t)
            l.disc:SetShown(t ~= "")
            l.text:SetShown(t ~= "")
        end
    end
end

function ns.SetLabelsShown(state)
    for _, l in ipairs(ns.labels) do l:SetShown(state) end
end

-------------------------------------------------------------------
-- Round look (matches DeckUI Orbs)
-------------------------------------------------------------------
local function Nop() end

local function MakeRound(b, size)
    local mask = b:CreateMaskTexture()
    mask:SetTexture(D.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(b)

    -- NOTE: Blizzard's template draws the icon in the BACKGROUND layer,
    -- so everything of ours that must sit behind it goes to the lowest
    -- sublevels (-8, -7).
    -- outer ring
    local ring = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    ring:SetSize(size + 6, size + 6)
    ring:SetPoint("CENTER")
    ring:SetTexture(D.DISC)
    ring:SetVertexColor(0.25, 0.25, 0.25, 1)
    b.DeckRing = ring

    -- dark disc behind the icon (also marks empty slots)
    local bg = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetAllPoints()
    bg:SetTexture(D.DISC)
    bg:SetVertexColor(0.08, 0.08, 0.08, 1)
    b.DeckBg = bg

    -- icon: zoom in a bit and cut it round
    if b.icon then
        b.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        b.icon:AddMaskTexture(mask)
    end

    -- kill the square Blizzard frame texture for good
    if b.NormalTexture then
        b.NormalTexture:SetTexture(nil)
        b.NormalTexture:SetAlpha(0)
        b.NormalTexture.SetTexture = Nop
        b.NormalTexture.SetAlpha   = Nop
    end

    -- Blizzard's own hover/pushed/checked textures are switched off and
    -- kept off (LibActionButton re-applies them on art updates), we draw
    -- our own round glows instead. Bright white disc + mask, additive.
    local function KillTexture(setter, getter)
        local tex = getter(b)
        if tex then
            tex:SetTexture(nil)
            tex:SetAlpha(0)
            tex.SetTexture = Nop
            tex.SetAtlas   = Nop
            tex.SetAlpha   = Nop
        end
        b[setter] = Nop
    end
    KillTexture("SetHighlightTexture", b.GetHighlightTexture)
    KillTexture("SetPushedTexture",    b.GetPushedTexture)
    KillTexture("SetCheckedTexture",   b.GetCheckedTexture)

    local fx = CreateFrame("Frame", nil, b)
    fx:SetAllPoints()
    fx:SetFrameLevel(b:GetFrameLevel() + 3)

    local function Glow(r, g, bl, a)
        local t = fx:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints()
        t:SetTexture("Interface\\Buttons\\WHITE8x8")
        t:SetVertexColor(r, g, bl, a)
        t:SetBlendMode("ADD")
        t:AddMaskTexture(mask)
        t:Hide()
        return t
    end
    b.DeckHover   = Glow(1, 1, 1, 0.18)
    b.DeckPushed  = Glow(1, 0.85, 0.3, 0.45)
    b.DeckChecked = Glow(0.3, 0.7, 1, 0.35)

    b:HookScript("OnEnter",     function(self) self.DeckHover:Show() end)
    b:HookScript("OnLeave",     function(self) self.DeckHover:Hide(); self.DeckPushed:Hide() end)
    b:HookScript("OnMouseDown", function(self) self.DeckPushed:Show() end)
    b:HookScript("OnMouseUp",   function(self) self.DeckPushed:Hide() end)
    -- key press via binding: LAB calls SetButtonState, mirror that
    hooksecurefunc(b, "SetButtonState", function(self, state)
        self.DeckPushed:SetShown(state == "PUSHED")
    end)
    hooksecurefunc(b, "SetChecked", function(self, state)
        self.DeckChecked:SetShown(state and true or false)
    end)

    -- cooldown: circular swipe like the orbs, bigger numbers
    if b.cooldown then
        b.cooldown:SetSwipeTexture(D.DISC)
        b.cooldown:SetUseCircularEdge(true)
        b.cooldown:SetDrawEdge(false)
        b.cooldown:SetSwipeColor(0, 0, 0, 0.75)
        if b.cooldown.SetCountdownFont then
            b.cooldown:SetCountdownFont(size >= 36 and "GameFontHighlightLarge" or "GameFontHighlight")
        end
    end

    -- stack count: our font, bottom right
    if b.Count then
        b.Count:SetFont(D.FONT, size >= 36 and 14 or 11, "OUTLINE")
        b.Count:ClearAllPoints()
        b.Count:SetPoint("BOTTOMRIGHT", 2, 0)
    end

    -- border for equipped items etc.
    if b.Border then
        b.Border:SetTexture(D.DISC)
        b.Border:SetBlendMode("ADD")
        b.Border:ClearAllPoints()
        b.Border:SetPoint("CENTER")
        b.Border:SetSize(size + 6, size + 6)
    end
    if b.Flash then
        b.Flash:SetTexture(D.DISC)
        b.Flash:SetVertexColor(1, 0.2, 0.2, 0.6)
        b.Flash:SetBlendMode("ADD")
        b.Flash:ClearAllPoints()
        b.Flash:SetAllPoints(b)
    end
end

-------------------------------------------------------------------
-- Buttons
-------------------------------------------------------------------
local OFFSETS = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }

local config = {
    showGrid    = true,
    clickOnDown = true,
    hideElements = { macro = true, hotkey = true, equipped = false },
}

ns.buttons = {}
ns.groups  = { {}, {}, {} }

local function MakeCross(group, cluster, clusterX, clusterY, size, gap, firstIdx)
    local d = size + gap
    for pos = 1, 4 do
        local idx = firstIdx + pos - 1
        local b = LAB:CreateButton(idx, "DeckCrossButton" .. idx, header, config)
        b:SetSize(size, size)
        b:SetPoint("CENTER", anchor, "CENTER",
            clusterX + OFFSETS[pos][1] * d,
            clusterY + OFFSETS[pos][2] * d)
        if idx <= 12 then
            -- Action Bar 1 with all its pages
            for page = 1, NUM_PAGES do
                b:SetState(page, "action", (page - 1) * 12 + idx)
            end
            b.DeckCommand = "ACTIONBUTTON" .. idx
        else
            -- Action Bar 2 (MultiBarBottomLeft), same on every page
            for page = 1, NUM_PAGES do
                b:SetState(page, "action", 60 + (idx - 12))
            end
            b.DeckCommand = "MULTIACTIONBAR1BUTTON" .. (idx - 12)
        end
        MakeRound(b, size)
        MakeLabel(b, cluster, pos, size)
        ns.buttons[idx] = b
        table.insert(ns.groups[group], b)
    end
end

local idx = 1
for half = 1, 2 do
    local halfX = (half == 1 and -1 or 1) * (HALF_W / 2 + HALF_GAP / 2)
    for cluster = 1, 2 do
        local clusterX = halfX + (cluster == 1 and -1 or 1) * (CLUSTER_W / 2 + CLUSTER_GAP / 2)
        MakeCross(half, cluster, clusterX, 0, ns.SIZE, ns.GAP, idx)
        idx = idx + 4
    end
end

for cluster = 1, 2 do
    local clusterX = (cluster == 1 and -1 or 1) * HALF_X
    MakeCross(3, cluster, clusterX, MID_OFFSET_Y, ns.SIZE_MID, ns.GAP_MID, idx)
    idx = idx + 4
end

-------------------------------------------------------------------
-- Hide Blizzard's Assisted Combat rotation highlight (purple ring)
-- on the cross buttons. The frame is created lazily by LibActionButton,
-- so we check after every button update and disable it for good.
-------------------------------------------------------------------
local ASSISTED_KEYS = { "AssistedCombatRotationFrame", "AssistedCombatHighlightFrame" }

local function HideAssisted(b)
    for _, key in ipairs(ASSISTED_KEYS) do
        local f = b[key]
        if f and not f.DeckHidden then
            f.DeckHidden = true
            f:Hide()
            f.Show     = Nop
            f.SetShown = Nop
        end
    end
end

-------------------------------------------------------------------
-- Midnight's ActionButtonTemplate puts a "TextOverlayContainer" at
-- frame level 500 on top of the button. It carries textures that dim
-- the button while a modifier (LT/RT) is held. We keep the container
-- (the stack count lives in it) but strip every texture inside.
-------------------------------------------------------------------
local function StripTextures(frame)
    if not frame then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") and not region.DeckHidden then
            region.DeckHidden = true
            region:SetTexture(nil)
            region:SetAlpha(0)
            region:Hide()
            region.SetTexture     = Nop
            region.SetAtlas       = Nop
            region.SetColorTexture = Nop
            region.SetAlpha       = Nop
            region.Show           = Nop
            region.SetShown       = Nop
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        StripTextures(child)
    end
end

local function CleanOverlay(b)
    local c = b.TextOverlayContainer
    if not c then return end
    StripTextures(c)
    if not c.DeckHooked then
        c.DeckHooked = true
        c:HookScript("OnShow", function(self) StripTextures(self) end)
    end
end
ns.CleanOverlay = CleanOverlay

-------------------------------------------------------------------
-- Single-button assistant icon: Blizzard swaps the icon to the next
-- recommended spell, but only on its own buttons. We poll the next
-- spell and paint it onto every cross button holding the assistant.
-------------------------------------------------------------------
local assistedButtons = {}   -- button -> true while it holds the assistant action
local lastAssistSpell

local function IsAssistedSlot(slot)
    if not slot or not (C_AssistedCombat and C_AssistedCombat.IsAssistedCombatAction) then return false end
    local ok, v = pcall(C_AssistedCombat.IsAssistedCombatAction, slot)
    return ok and v or false
end

local function PaintAssistIcon(b)
    if lastAssistSpell and b.icon then
        local tex = C_Spell.GetSpellTexture(lastAssistSpell)
        if tex then b.icon:SetTexture(tex) end
    end
end

local function RefreshAssistedButtons()
    wipe(assistedButtons)
    for _, b in pairs(ns.buttons) do
        if IsAssistedSlot(b._state_action or b:GetAttribute("action")) then
            assistedButtons[b] = true
            PaintAssistIcon(b)
        end
    end
end

local poll = CreateFrame("Frame")
local elapsed = 0
poll:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.1 then return end
    elapsed = 0
    if not next(assistedButtons) then return end
    if not (C_AssistedCombat and C_AssistedCombat.GetNextCastSpell) then return end
    local ok, spell = pcall(C_AssistedCombat.GetNextCastSpell, true)
    if not ok or not spell or spell == lastAssistSpell then return end
    lastAssistSpell = spell
    for b in pairs(assistedButtons) do PaintAssistIcon(b) end
end)

local callbacks = {}
LAB.RegisterCallback(callbacks, "OnButtonUpdate", function(_, button)
    if button.DeckRing then
        HideAssisted(button)
        CleanOverlay(button)
        -- LAB just (re)painted the icon; re-evaluate and repaint if needed
        local slot = button._state_action or button:GetAttribute("action")
        if IsAssistedSlot(slot) then
            assistedButtons[button] = true
            PaintAssistIcon(button)
        else
            assistedButtons[button] = nil
        end
    end
end)
C_Timer.After(1, RefreshAssistedButtons)
for _, b in pairs(ns.buttons) do
    HideAssisted(b)
    CleanOverlay(b)
end

-------------------------------------------------------------------
-- Debug: /dc bare  -> toggles all DeckUI decorations off/on
-------------------------------------------------------------------
ns.bare = false
function ns.ToggleBare()
    ns.bare = not ns.bare
    local shown = not ns.bare
    for _, b in pairs(ns.buttons) do
        b.DeckRing:SetShown(shown)
        b.DeckBg:SetShown(shown)
        if ns.bare then
            b.DeckHover:Hide(); b.DeckPushed:Hide(); b.DeckChecked:Hide()
        end
    end
    ns.SetLabelsShown(shown and DeckCrossDB.showLabels)
    print("DeckUI Cross: decorations " .. (shown and "ON" or "OFF (bare)"))
end

-------------------------------------------------------------------
-- Debug: /dc overlay  -> lists what is visible on button 1
-------------------------------------------------------------------
local function NameOf(b, obj)
    for k, v in pairs(b) do
        if v == obj and type(k) == "string" then return k end
    end
    return "?"
end

local function Describe(b, obj, depth)
    local pad  = string.rep("  ", depth)
    local kind = obj:GetObjectType()
    local info = pad .. kind .. " [" .. NameOf(b, obj) .. "]"
    if kind == "Texture" or kind == "MaskTexture" then
        local r, g, bl, a = obj:GetVertexColor()
        info = info .. string.format(" tex=%s atlas=%s blend=%s col=%.2f/%.2f/%.2f/%.2f",
            tostring(obj:GetTexture()), tostring(obj:GetAtlas()), tostring(obj:GetBlendMode()),
            r or 0, g or 0, bl or 0, a or 0)
    elseif kind == "FontString" then
        info = info .. " text=" .. tostring(obj:GetText())
    end
    if obj.IsShown then info = info .. " shown=" .. tostring(obj:IsShown()) end
    if obj.GetAlpha then info = info .. string.format(" alpha=%.2f", obj:GetAlpha()) end
    print(info)
end

function ns.DumpOverlay(idx)
    local b = ns.buttons[idx or 1]
    if not b then return end
    local function Walk(frame, depth)
        Describe(b, frame, depth)
        for _, r in ipairs({ frame:GetRegions() }) do
            if r:IsShown() then Describe(b, r, depth + 1) end
        end
        for _, ch in ipairs({ frame:GetChildren() }) do
            if ch:IsShown() then Walk(ch, depth + 1) end
        end
    end
    print("DeckUI Cross: visible parts of button " .. (idx or 1))
    Walk(b, 0)
    if b.cooldown then
        local start, dur = b.cooldown:GetCooldownTimes()
        print(string.format("cooldown shown=%s start=%s dur=%s",
            tostring(b.cooldown:IsShown()), tostring(start), tostring(dur)))
    end
end

-------------------------------------------------------------------
-- /dc page: which page the crosses are on and why. The mount, vehicle
-- and override bars were the hard part here, so keep this around.
-------------------------------------------------------------------
function ns.PrintPage()
    print("DeckUI Cross: pages 1-" .. NUM_PAGES .. " registered")
    print(string.format("  indices: bars=%d bonus5=%d vehicle=%d tempshapeshift=%d override=%d",
        NUM_ACTIONBAR_PAGES or 6, GetBonusBarIndex(), GetVehicleBarIndex(),
        GetTempShapeshiftBarIndex(), GetOverrideBarIndex()))
    print(string.format("  state=%s  GetActionBarPage=%d  GetBonusBarOffset=%d",
        tostring(header:GetAttribute("state")), GetActionBarPage(), GetBonusBarOffset()))
    print(string.format("  override=%s vehicle=%s possess=%s",
        tostring(HasOverrideActionBar and HasOverrideActionBar()),
        tostring(HasVehicleActionBar and HasVehicleActionBar()),
        tostring(IsPossessBarVisible and IsPossessBarVisible())))
    for _, idx in ipairs({ 1, 13 }) do
        local b = ns.buttons[idx]
        if b then
            local kind, action = b:GetAction()
            print(string.format("  button %d -> %s %s", idx, tostring(kind), tostring(action)))
        end
    end
end

-------------------------------------------------------------------
-- Key presses reach Blizzard's native buttons (see input.lua), so we
-- mirror their pushed state onto ours for the visual feedback.
-------------------------------------------------------------------
for idx, b in pairs(ns.buttons) do
    local native = idx <= 12 and _G["ActionButton" .. idx] or _G["MultiBarBottomLeftButton" .. (idx - 12)]
    if native then
        hooksecurefunc(native, "SetButtonState", function(_, state)
            b.DeckPushed:SetShown(state == "PUSHED")
            if state == "PUSHED" and ns.TouchActivity then ns.TouchActivity() end
        end)
    end
end

-------------------------------------------------------------------
-- Group highlight: alpha plus ring colour on the active group
-------------------------------------------------------------------
local RING_IDLE   = { 0.25, 0.25, 0.25 }
local RING_ACTIVE = { 0.9, 0.75, 0.2 }   -- same gold as the orb cast overlay

local function SetGroup(list, alpha, active)
    local c = active and RING_ACTIVE or RING_IDLE
    for _, b in ipairs(list) do
        b:SetAlpha(alpha)
        b.DeckRing:SetVertexColor(c[1], c[2], c[3], 1)
    end
end

-- drive the page state now that all buttons exist
RegisterStateDriver(header, "page", PageMacro())

function ns.SetGroupAlpha(left, right, mid)
    SetGroup(ns.groups[1], left,  left  == 1)
    SetGroup(ns.groups[2], right, right == 1)
    SetGroup(ns.groups[3], mid,   mid   == 1)
end

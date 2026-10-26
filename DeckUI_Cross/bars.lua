local ADDON, ns = ...
local D = DeckUI
local LAB = LibStub("LibActionButton-1.0")

-------------------------------------------------------------------
-- Action bars 3-8 of our own, in Final Fantasy XIV's look
-------------------------------------------------------------------
-- Owner's wish (2026-10-09, his FFXIV hotbar screenshot): the bars the
-- crosses do not mirror were still Blizzard's. Each of them can now be a
-- DeckUI bar instead: square slots with rounded corners and a dark edge,
-- the key small in the top left, the count bottom right, empty slots as
-- dark squares - and Blizzard's bar is hidden while ours shows
-- (DeckCrossDB.bars[n].shown, all off by default).
--
-- The buttons are LibActionButton's, like the crosses', one per slot of
-- the bar (state 0 = that action, no paging). Keys stay Blizzard's: the
-- player's bindings for MULTIACTIONBAR2BUTTON1 and friends keep driving
-- Blizzard's own (hidden) buttons, which run the native path; ours show
-- the key from the same command (LAB's keyBoundTarget) and mirror the
-- pushed state from Blizzard's button. A mouse click on ours uses the
-- action through LAB's secure button.
-- Action Bar 4 is the Deck's ability menu (abilitymenu.lua) when that is
-- on, so on the Deck it does not show here.
-------------------------------------------------------------------
local SIZE, GAP = 36, 3
local MASK = "Interface\\AddOns\\DeckUI_Cross\\textures\\slot_rounded"

-- bar number -> first action slot, binding command prefix, Blizzard's buttons
ns.EXTRA_BARS = {
    [3] = { first = 49,  command = "MULTIACTIONBAR2BUTTON", native = "MultiBarBottomRightButton" },
    [4] = { first = 25,  command = "MULTIACTIONBAR3BUTTON", native = "MultiBarRightButton" },
    [5] = { first = 37,  command = "MULTIACTIONBAR4BUTTON", native = "MultiBarLeftButton" },
    [6] = { first = 145, command = "MULTIACTIONBAR5BUTTON", native = "MultiBar5Button" },
    [7] = { first = 157, command = "MULTIACTIONBAR6BUTTON", native = "MultiBar6Button" },
    [8] = { first = 169, command = "MULTIACTIONBAR7BUTTON", native = "MultiBar7Button" },
}
ns.BAR_LAYOUTS = { 12, 6, 4, 3, 2, 1 }   -- buttons per row
local DEFAULT_ROW = { [3] = 12, [4] = 1, [5] = 1, [6] = 12, [7] = 12, [8] = 12 }
local DEFAULT_POINT = {
    [3] = { "BOTTOM", UIParent, "BOTTOM", 0, 300 },
    [4] = { "RIGHT", UIParent, "RIGHT", -8, 40 },
    [5] = { "RIGHT", UIParent, "RIGHT", -50, 40 },
    [6] = { "BOTTOM", UIParent, "BOTTOM", 0, 345 },
    [7] = { "BOTTOM", UIParent, "BOTTOM", 0, 390 },
    [8] = { "BOTTOM", UIParent, "BOTTOM", 0, 435 },
}

local config = {
    showGrid = true,
    clickOnDown = true,
    hideElements = { macro = true, hotkey = false, equipped = false },
    text = {
        hotkey = {
            font = { font = D.FONT, size = 10, flags = "OUTLINE" },
            color = { 1, 1, 1 },
            position = { anchor = "TOPLEFT", relAnchor = "TOPLEFT", offsetX = 3, offsetY = -3 },
            justifyH = "LEFT",
        },
        count = {
            font = { font = D.FONT, size = 12, flags = "OUTLINE" },
            color = { 1, 1, 1 },
            position = { anchor = "BOTTOMRIGHT", relAnchor = "BOTTOMRIGHT", offsetX = -2, offsetY = 2 },
            justifyH = "RIGHT",
        },
    },
}

-------------------------------------------------------------------
-- The FFXIV slot look
-------------------------------------------------------------------
local function Nop() end
local PUSH_MIN = 0.18

local function Style(b)
    local mask = b:CreateMaskTexture()
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(b)

    -- the dark rounded edge and the empty slot (Blizzard's icon is in
    -- BACKGROUND, ours go below it at -8/-7)
    local edge = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetPoint("TOPLEFT", -2, 2)
    edge:SetPoint("BOTTOMRIGHT", 2, -2)
    edge:SetTexture(MASK)
    edge:SetVertexColor(0.02, 0.02, 0.02, 0.95)
    local slot = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    slot:SetAllPoints()
    slot:SetTexture(MASK)
    slot:SetVertexColor(0.1, 0.1, 0.12, 0.9)

    if b.icon then
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.icon:AddMaskTexture(mask)
    end
    if b.NormalTexture then
        b.NormalTexture:SetTexture(nil)
        b.NormalTexture:SetAlpha(0)
        b.NormalTexture.SetTexture = Nop
        b.NormalTexture.SetAlpha = Nop
    end
    -- Mists' UI-Quickslot square on empty slots (see core.lua)
    if D.IsMists and b.SlotBackground then b.SlotBackground:SetAlpha(0) end
    -- LibActionButton puts these back on art updates; ours stay instead
    for _, getter in ipairs({ "GetHighlightTexture", "GetPushedTexture", "GetCheckedTexture" }) do
        local tex = b[getter] and b[getter](b)
        if tex then
            tex:SetTexture(nil)
            tex:SetAlpha(0)
            tex.SetTexture, tex.SetAtlas, tex.SetAlpha = Nop, Nop, Nop
        end
    end
    b.SetHighlightTexture, b.SetPushedTexture, b.SetCheckedTexture = Nop, Nop, Nop

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
    b.DeckHover = Glow(1, 1, 1, 0.15)
    b.DeckPushed = Glow(1, 0.85, 0.3, 0.4)
    b.DeckChecked = Glow(0.3, 0.7, 1, 0.3)
    b:HookScript("OnEnter", function(self) self.DeckHover:Show() end)
    b:HookScript("OnLeave", function(self) self.DeckHover:Hide() end)
    b:HookScript("OnMouseDown", function(self) self.DeckPushed:Show() end)
    b:HookScript("OnMouseUp", function(self) self.DeckPushed:Hide() end)
    hooksecurefunc(b, "SetChecked", function(self, on) self.DeckChecked:SetShown(on and true or false) end)

    if b.cooldown then
        b.cooldown:SetSwipeTexture(MASK)
        b.cooldown:SetSwipeColor(0, 0, 0, 0.7)
        b.cooldown:SetDrawEdge(false)
    end
    if b.Border then b.Border:SetAlpha(0) end
end

-- Blizzard's PUSHED state is gone before the eye sees it; hold ours a moment
local function ShowPushed(b, on)
    if on then
        b.DeckPushedAt = GetTime()
        b.DeckPushed:Show()
        return
    end
    local left = PUSH_MIN - (GetTime() - (b.DeckPushedAt or 0))
    if left <= 0 then b.DeckPushed:Hide() else C_Timer.After(left, function() b.DeckPushed:Hide() end) end
end

-------------------------------------------------------------------
-- The bars
-------------------------------------------------------------------
local bars = {}   -- n -> { holder, header, buttons }

local function Settings(n)
    DeckCrossDB.bars = DeckCrossDB.bars or {}
    DeckCrossDB.bars[n] = DeckCrossDB.bars[n] or { shown = false, perRow = DEFAULT_ROW[n] }
    return DeckCrossDB.bars[n]
end
ns.BarSettings = Settings

local function Build(n)
    local info = ns.EXTRA_BARS[n]
    local holder = CreateFrame("Frame", "DeckCrossBar" .. n, UIParent)
    holder:SetSize(SIZE, SIZE)
    holder.defaultPoint = DEFAULT_POINT[n]
    holder:SetPoint(unpack(holder.defaultPoint))
    holder:Hide()

    local header = CreateFrame("Frame", nil, holder, "SecureHandlerStateTemplate")
    header:SetAllPoints()

    local buttons = {}
    for i = 1, 12 do
        local c = CopyTable(config)
        c.keyBoundTarget = info.command .. i
        local b = LAB:CreateButton(1000 + n * 12 + i, "DeckCrossBar" .. n .. "Button" .. i, header, c)
        b:SetSize(SIZE, SIZE)
        b:SetState(0, "action", info.first + i - 1)
        Style(b)
        local native = _G[info.native .. i]
        if native then
            hooksecurefunc(native, "SetButtonState", function(_, state) ShowPushed(b, state == "PUSHED") end)
        end
        buttons[i] = b
    end
    D.MakeMovable(holder, "Bar " .. n, DeckCrossDB)
    bars[n] = { holder = holder, header = header, buttons = buttons }
    return bars[n]
end

-- places the twelve buttons in rows of perRow (secure buttons: out of combat)
local function Layout(n)
    local bar = bars[n]
    local per = Settings(n).perRow or 12
    local rows = math.ceil(12 / per)
    bar.holder:SetSize(per * (SIZE + GAP) - GAP, rows * (SIZE + GAP) - GAP)
    for i, b in ipairs(bar.buttons) do
        local col, row = (i - 1) % per, math.floor((i - 1) / per)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", bar.holder, "TOPLEFT", col * (SIZE + GAP), -row * (SIZE + GAP))
    end
end

local pending = false

-- How see-through the bars are (owner's wish, 2026-10-26; FFXIV's hotbars
-- have the same setting), DeckCrossDB.barAlpha, shared by both devices.
-- On the holder, so LibActionButton setting a button back to alpha 1 on
-- every update does not undo it; alpha may change in combat too.
function ns.ApplyBarAlpha()
    local alpha = DeckCrossDB and DeckCrossDB.barAlpha or 1
    for _, bar in pairs(bars) do bar.holder:SetAlpha(alpha) end
end

-- shows our bars and hides Blizzard's (or gives them back), out of combat
function ns.ApplyBars()
    if not DeckCrossDB then return end
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local scale = ns.DeviceDB().barScale or 1
    for n, info in pairs(ns.EXTRA_BARS) do
        local s = Settings(n)
        -- on the Deck, Action Bar 4 is the ability menu when that is on
        local menuTakesIt = n == 4 and DeckCrossDB.abilityMenu and D.IsDeck()
        local show = s.shown and not menuTakesIt
        if show and not bars[n] then Build(n) end
        if bars[n] then
            Layout(n)
            bars[n].holder:SetScale(scale)
            bars[n].holder:SetShown(show)
        end
        -- Blizzard's bar: hidden while ours shows or the ability menu has
        -- it. Asked every time - hiding twice and showing a bar we never
        -- hid are both no-ops (input.lua's HideBar/ShowBar).
        ns.SetBlizzardBarHidden(info.native .. "1", (s.shown or menuTakesIt) and true or false)
    end
    ns.ApplyBarAlpha()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function()
    if pending then ns.ApplyBars() end
end)

function ns.InitBars()
    if DeckCrossDB.barAlpha == nil then DeckCrossDB.barAlpha = 1 end
    ns.ApplyBars()
end

-- the movable keys of the bars, for the settings page's Move
ns.BAR_FRAME_KEYS = { "Bar 3", "Bar 4", "Bar 5", "Bar 6", "Bar 7", "Bar 8" }

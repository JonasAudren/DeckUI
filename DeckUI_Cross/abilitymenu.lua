local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Ability menu: tap B, pick one of Action Bar 4's first seven slots
-------------------------------------------------------------------
-- Owner's wish (2026-10-09): mounts and other rarely used things without a
-- mouse. On the Steam Deck, B (the game menu there, which Start opens too)
-- opens a menu of Action Bar 4's first seven slots; the D-pad and Y, A, X
-- use one and close it, B again closes it unused. A tap rather than a hold:
-- the thumb on B cannot also reach Y, A and X. Action Bar 4 itself is
-- hidden on the Deck - its slots live in the menu now - and stays an
-- ordinary bar on the PC (DeckCrossDB.abilityMenu, off by default).
--
-- The slots are secure action buttons of our own, type "action" on slots
-- 25-31 (Action Bar 4 = MultiBarRight, slots 25-36): whatever the player
-- drags onto the bar - a mount, a toy, an item, a macro - is used the way
-- the bar would use it, in combat too. Opening binds the seven keys to
-- those buttons from restricted code (SecureHandlerWrapScript), using one
-- clears them again, so the D-pad and face buttons are only taken while
-- the menu is open. The picture is drawn by plain hooks.
-------------------------------------------------------------------
local OPEN_KEY = "PAD2"           -- B
local FIRST_SLOT = 25             -- Action Bar 4's first slot
local KEYS = { "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT", "PAD4", "PAD1", "PAD3" }   -- Y, A, X
local GLYPHS = { "dpad_up", "dpad_right", "dpad_down", "dpad_left", "face_y", "face_a", "face_x" }
local COUNT = #KEYS

-------------------------------------------------------------------
-- The picture
-------------------------------------------------------------------
local SIZE, STEP = 46, 58
local menu = CreateFrame("Frame", "DeckCrossAbilityMenu", UIParent)
menu:SetSize(2 * 3 * STEP + 60, 3 * STEP + 40)
menu:SetPoint("CENTER", 0, 40)
menu:SetFrameStrata("DIALOG")
menu:Hide()
D.FlatBox(menu, 0.85)

local title = menu:CreateFontString(nil, "OVERLAY")
title:SetFont(D.FONT, 12, "OUTLINE")
title:SetPoint("BOTTOM", 0, 6)
title:SetTextColor(0.7, 0.7, 0.7)
title:SetText("Action Bar 4  -  B closes")

local OFFSETS = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }
-- D-pad cross on the left; Y, A, X on the right where they sit on the pad
local FACE_OFFSETS = { { 0, 1 }, { 0, -1 }, { -1, 0 } }

local tiles = {}
for i = 1, COUNT do
    local t = CreateFrame("Frame", nil, menu)
    t:SetSize(SIZE, SIZE)
    local mask = D.RoundMask(t)
    local ring = t:CreateTexture(nil, "BACKGROUND", nil, -8)
    ring:SetSize(SIZE + 6, SIZE + 6)
    ring:SetPoint("CENTER")
    ring:SetTexture(D.DISC)
    ring:SetVertexColor(0.9, 0.75, 0.2, 1)
    local disc = t:CreateTexture(nil, "BACKGROUND", nil, -7)
    disc:SetAllPoints()
    disc:SetTexture(D.DISC)
    disc:SetVertexColor(0.08, 0.08, 0.08, 1)
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetAllPoints()
    t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    t.icon:AddMaskTexture(mask)
    t.count = t:CreateFontString(nil, "OVERLAY")
    t.count:SetFont(D.FONT, 12, "OUTLINE")
    t.count:SetPoint("BOTTOMRIGHT", 2, 0)
    local g = t:CreateTexture(nil, "OVERLAY")
    g:SetSize(18, 18)
    g:SetPoint("CENTER", t, "TOPLEFT", 4, -4)
    g:SetTexture(ns.TEX_PATH .. GLYPHS[i])
    local cx, cy
    if i <= 4 then
        cx, cy = -(STEP * 1.5 + 6) + OFFSETS[i][1] * STEP, OFFSETS[i][2] * STEP
    else
        local o = FACE_OFFSETS[i - 4]
        cx, cy = (STEP * 1.5 + 6) + o[1] * STEP, o[2] * STEP
    end
    t:SetPoint("CENTER", menu, "CENTER", cx, cy + 10)
    tiles[i] = t
end

local function Paint()
    for i, t in ipairs(tiles) do
        local slot = FIRST_SLOT + i - 1
        local texture = HasAction(slot) and GetActionTexture(slot)
        t.icon:SetTexture(texture)
        t.icon:SetShown(texture ~= nil)
        local count = HasAction(slot) and GetActionCount(slot)
        t.count:SetText((count and count > 1) and count or "")
    end
end
menu:SetScript("OnShow", Paint)

-------------------------------------------------------------------
-- The secure part
-------------------------------------------------------------------
local header = CreateFrame("Frame", "DeckCrossAbilityHeader", UIParent, "SecureHandlerBaseTemplate")
for i, key in ipairs(KEYS) do header:SetAttribute("key" .. i, key) end
header:SetAttribute("count", COUNT)

local toggle = CreateFrame("Button", "DeckCrossAbilityToggle", UIParent, "SecureActionButtonTemplate")
toggle:RegisterForClicks("AnyDown")
toggle:Hide()

SecureHandlerWrapScript(toggle, "OnClick", header, [[
    if owner:GetAttribute("open") then
        owner:ClearBindings()
        owner:SetAttribute("open", nil)
    else
        for i = 1, owner:GetAttribute("count") do
            owner:SetBindingClick(true, owner:GetAttribute("key" .. i), "DeckCrossAbilitySlot" .. i)
        end
        owner:SetAttribute("open", true)
    end
]])

local slots = {}
for i = 1, COUNT do
    local b = CreateFrame("Button", "DeckCrossAbilitySlot" .. i, UIParent, "SecureActionButtonTemplate")
    -- down and up, like LibActionButton: Blizzard's handler acts on the one
    -- ActionButtonUseKeyDown names
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetAttribute("type", "action")
    b:SetAttribute("action", FIRST_SLOT + i - 1)
    b:Hide()
    -- the release closes the menu; the use itself happened on the press or
    -- happens on this release, after this snippet
    SecureHandlerWrapScript(b, "OnClick", header, [[
        if not down then
            owner:ClearBindings()
            owner:SetAttribute("open", nil)
        end
    ]])
    slots[i] = b
end

local function Follow()
    menu:SetShown(header:GetAttribute("open") and true or false)
end
toggle:HookScript("OnClick", Follow)
for _, b in ipairs(slots) do b:HookScript("OnClick", Follow) end

-------------------------------------------------------------------
-- B itself, and Action Bar 4 on the Deck
-------------------------------------------------------------------
local keyOwner = CreateFrame("Frame")
local pending = false

local function Apply()
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local on = DeckCrossDB.abilityMenu and D.IsDeck() and true or false
    ClearOverrideBindings(keyOwner)
    if on then
        SetOverrideBindingClick(keyOwner, true, OPEN_KEY, "DeckCrossAbilityToggle", "LeftButton")
    else
        SecureHandlerExecute(header, [[ self:ClearBindings(); self:SetAttribute("open", nil) ]])
        menu:Hide()
    end
    -- Action Bar 4 lives in the menu on the Deck, the PC keeps the bar:
    -- bars.lua decides for Blizzard's bar and ours alike
    if ns.ApplyBars then ns.ApplyBars() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then Apply() end
    elseif menu:IsShown() then
        Paint()
    end
end)

function ns.SetAbilityMenu(on)
    DeckCrossDB.abilityMenu = on
    if not D.IsDeck() then
        print("DeckUI Cross: saved - the ability menu works on the Steam Deck; Action Bar 4 stays a bar here.")
    elseif InCombatLockdown() then
        print("DeckUI Cross: takes effect after combat.")
    end
    Apply()
end

function ns.InitAbilityMenu()
    if DeckCrossDB.abilityMenu == nil then DeckCrossDB.abilityMenu = false end
    Apply()
end

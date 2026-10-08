local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Quick menu: hold RB, press a D-pad direction or face button
-------------------------------------------------------------------
-- Owner's wish (2026-10-08), Steam Deck only: Blizzard's windows without a
-- mouse. While RB is held, a cross of eight entries shows in the middle of
-- the screen, and the D-pad and face buttons open them (DeckCrossDB.quickMenu,
-- off by default).
--
-- The keys go to Blizzard's own binding commands (TOGGLEWORLDMAP,
-- OPENALLBAGS, ...) - the same path a normal key binding takes, the way the
-- crosses bind ACTIONBUTTONn. Opening a window from our Lua instead would
-- run its whole opening tainted (the world map learned that the hard way,
-- see the Quests notes in CLAUDE.md).
-- RB clicks a secure button on key down and again on key up. A secure
-- wrapper on that click binds the eight keys while RB is down and clears
-- them on release - in restricted code, so it works in combat too, where
-- insecure code cannot bind. The visible menu is shown from a plain hook.
-------------------------------------------------------------------
local HOLD = "PADRSHOULDER"   -- RB

-- position -> key, the same order as the crosses: up, right, down, left
local DPAD = { "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT" }
local FACE = { "PAD4", "PAD2", "PAD1", "PAD3" }   -- Y, B, A, X
local FACE_GLYPH = { "face_y", "face_b", "face_a", "face_x" }

-- the eight entries: binding command, label, icon (texture path or "portrait")
local ENTRIES = {
    { key = DPAD[1], command = "TOGGLEWORLDMAP",    label = "Map",          icon = "Interface\\Icons\\INV_Misc_Map_01" },
    { key = DPAD[2], command = "OPENALLBAGS",       label = "Bags",         icon = "Interface\\Icons\\INV_Misc_Bag_08" },
    { key = DPAD[3], command = "TOGGLEQUESTLOG",    label = "Quest log",    icon = "Interface\\Icons\\INV_Misc_Book_08" },
    { key = DPAD[4], command = "TOGGLECHARACTER0",  label = "Character",    icon = "portrait" },
    { key = FACE[1], command = "TOGGLETALENTS",     label = "Talents",      icon = "Interface\\Icons\\INV_Misc_Book_09", glyph = FACE_GLYPH[1] },
    { key = FACE[2], command = "TOGGLEGROUPFINDER", label = "Group finder", icon = "Interface\\Icons\\INV_Misc_GroupNeedMore", glyph = FACE_GLYPH[2] },
    { key = FACE[3], command = "TOGGLECOLLECTIONS", label = "Collections",  icon = "Interface\\Icons\\Ability_Mount_RidingHorse", glyph = FACE_GLYPH[3] },
    { key = FACE[4], command = "TOGGLEGAMEMENU",    label = "Game menu",    icon = "Interface\\Icons\\INV_Misc_Gear_01", glyph = FACE_GLYPH[4] },
}
local DPAD_GLYPH = { "dpad_up", "dpad_right", "dpad_down", "dpad_left" }

-- a command the client does not know binds to nothing; it is left out and
-- shown greyed, and /dc quick names it
local function Known(command)
    return _G["BINDING_NAME_" .. command] ~= nil
end

-------------------------------------------------------------------
-- The visible menu
-------------------------------------------------------------------
local SIZE, STEP = 46, 58
local menu = CreateFrame("Frame", "DeckCrossQuickMenu", UIParent)
menu:SetSize(2 * 3 * STEP + 60, 3 * STEP + 30)
menu:SetPoint("CENTER", 0, 40)
menu:SetFrameStrata("DIALOG")
menu:Hide()
D.FlatBox(menu, 0.85)

local OFFSETS = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }

local function Entry(entry, cx, glyph)
    local b = CreateFrame("Frame", nil, menu)
    b:SetSize(SIZE, SIZE)
    local mask = D.RoundMask(b)
    local ring = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    ring:SetSize(SIZE + 6, SIZE + 6)
    ring:SetPoint("CENTER")
    ring:SetTexture(D.DISC)
    ring:SetVertexColor(0.9, 0.75, 0.2, 1)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    if entry.icon == "portrait" then
        b.portrait = icon
    else
        icon:SetTexture(entry.icon)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    icon:AddMaskTexture(mask)
    icon:SetDesaturated(not Known(entry.command))
    local g = b:CreateTexture(nil, "OVERLAY")
    g:SetSize(18, 18)
    g:SetPoint("CENTER", b, "TOPLEFT", 4, -4)
    g:SetTexture(ns.TEX_PATH .. glyph)
    local text = b:CreateFontString(nil, "OVERLAY")
    text:SetFont(D.FONT, 11, "OUTLINE")
    text:SetPoint("TOP", b, "BOTTOM", 0, -2)
    text:SetText(entry.label)
    if not Known(entry.command) then text:SetTextColor(0.5, 0.5, 0.5) end
    return b
end

local entryFrames = {}
for i, entry in ipairs(ENTRIES) do
    local cluster = i <= 4 and 1 or 2
    local pos = (i - 1) % 4 + 1
    local cx = (cluster == 1 and -1 or 1) * (STEP * 1.5 + 6)
    local f = Entry(entry, cx, cluster == 1 and DPAD_GLYPH[pos] or entry.glyph)
    f:SetPoint("CENTER", menu, "CENTER", cx + OFFSETS[pos][1] * STEP, OFFSETS[pos][2] * STEP + 8)
    entryFrames[i] = f
end

menu:SetScript("OnShow", function()
    for _, f in ipairs(entryFrames) do
        if f.portrait then SetPortraitTexture(f.portrait, "player") end
    end
end)

-------------------------------------------------------------------
-- The secure part: RB binds the eight keys while it is held
-------------------------------------------------------------------
local header = CreateFrame("Frame", "DeckCrossQuickHeader", UIParent, "SecureHandlerBaseTemplate")
local holdBtn = CreateFrame("Button", "DeckCrossQuickHold", UIParent, "SecureActionButtonTemplate")
holdBtn:RegisterForClicks("AnyDown", "AnyUp")
holdBtn:Hide()   -- a binding click reaches it while hidden too

local n = 0
for _, entry in ipairs(ENTRIES) do
    if Known(entry.command) then
        n = n + 1
        header:SetAttribute("key" .. n, entry.key)
        header:SetAttribute("command" .. n, entry.command)
    end
end
header:SetAttribute("count", n)

-- runs in restricted code before the click; `down` says press or release.
-- The button has no type, so the click itself does nothing after it.
SecureHandlerWrapScript(holdBtn, "OnClick", header, [[
    if down then
        for i = 1, owner:GetAttribute("count") do
            owner:SetBinding(true, owner:GetAttribute("key" .. i), owner:GetAttribute("command" .. i))
        end
    else
        owner:ClearBindings()
    end
]])

-- the picture: a plain hook, nothing protected about a texture
holdBtn:HookScript("OnClick", function(_, _, down)
    menu:SetShown(down and true or false)
end)

-- RB itself, out of combat
local keyOwner = CreateFrame("Frame")

local pending = false
local function Apply()
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    ClearOverrideBindings(keyOwner)
    local on = DeckCrossDB.quickMenu and D.IsDeck()
    if on then SetOverrideBindingClick(keyOwner, true, HOLD, "DeckCrossQuickHold", "LeftButton") end
    if not on then
        menu:Hide()
        SecureHandlerExecute(header, "self:ClearBindings()")
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function()
    if pending then Apply() end
end)

function ns.SetQuickMenu(on)
    DeckCrossDB.quickMenu = on
    if not D.IsDeck() then
        print("DeckUI Cross: saved - the quick menu works on the Steam Deck.")
    elseif InCombatLockdown() then
        print("DeckUI Cross: takes effect after combat.")
    end
    Apply()
end

function ns.InitQuickMenu()
    if DeckCrossDB.quickMenu == nil then DeckCrossDB.quickMenu = false end
    Apply()
end

-- /dc quick: the option, RB's binding and every entry's command
function ns.PrintQuickMenu()
    print(("DeckUI Cross quick menu: option=%s deck=%s RB=%s"):format(
        tostring(DeckCrossDB.quickMenu), tostring(D.IsDeck()), tostring(GetBindingAction(HOLD, true))))
    for _, entry in ipairs(ENTRIES) do
        print(("  %s -> %s (%s)"):format(entry.key, entry.command, Known(entry.command) and "ok" or "UNKNOWN"))
    end
end

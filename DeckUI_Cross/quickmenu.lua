local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Quick menu: hold RB, press a D-pad direction or face button
-------------------------------------------------------------------
-- Owner's wish (2026-10-08), Steam Deck only: Blizzard's windows without a
-- mouse. While RB is held, a cross of eight entries shows in the middle of
-- the screen, and the D-pad and face buttons open them (DeckCrossDB.quickMenu,
-- off by default). Which entry sits on which button is the player's choice
-- since 2026-10-09 (DeckCrossDB.quickEntries, the Cross page).
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
local KEYS = { DPAD[1], DPAD[2], DPAD[3], DPAD[4], FACE[1], FACE[2], FACE[3], FACE[4] }
local GLYPHS = { "dpad_up", "dpad_right", "dpad_down", "dpad_left", "face_y", "face_b", "face_a", "face_x" }
ns.QUICK_SLOT_NAMES = { "Up", "Right", "Down", "Left", "Y", "B", "A", "X" }

-- What a slot can open: binding command -> label and icon (a texture path,
-- or "portrait"). The owner asked to choose them himself (2026-10-09); the
-- Cross page steps each slot through this list (DeckCrossDB.quickEntries).
-- A command this client does not know is skipped in the list and greyed in
-- the menu. DECKUI_WEEK is DeckUI's own binding (DeckUI/Bindings.xml).
ns.QUICK_COMMANDS = {
    "TOGGLEWORLDMAP", "OPENALLBAGS", "TOGGLEQUESTLOG", "TOGGLECHARACTER0", "TOGGLETALENTS",
    "TOGGLESPELLBOOK", "TOGGLEPROFESSIONBOOK", "TOGGLEGROUPFINDER", "TOGGLEENCOUNTERJOURNAL",
    "TOGGLECOLLECTIONS", "TOGGLECOLLECTIONSMOUNTJOURNAL", "TOGGLEACHIEVEMENT", "TOGGLEGUILDTAB",
    "TOGGLESOCIAL", "TOGGLECALENDAR", "DECKUI_WEEK", "TOGGLEGAMEMENU", "NONE",
}
local COMMANDS = {
    TOGGLEWORLDMAP          = { label = "Map",          icon = "Interface\\Icons\\INV_Misc_Map_01" },
    OPENALLBAGS             = { label = "Bags",         icon = "Interface\\Icons\\INV_Misc_Bag_08" },
    TOGGLEQUESTLOG          = { label = "Quest log",    icon = "Interface\\Icons\\INV_Misc_Book_08" },
    TOGGLECHARACTER0        = { label = "Character",    icon = "portrait" },
    TOGGLETALENTS           = { label = "Talents",      icon = "Interface\\Icons\\INV_Misc_Book_09" },
    TOGGLESPELLBOOK         = { label = "Spellbook",    icon = "Interface\\Icons\\INV_Misc_Book_07" },
    TOGGLEPROFESSIONBOOK    = { label = "Professions",  icon = "Interface\\Icons\\INV_Misc_Note_01" },
    TOGGLEGROUPFINDER       = { label = "Group finder", icon = "Interface\\Icons\\INV_Misc_GroupNeedMore" },
    TOGGLEENCOUNTERJOURNAL  = { label = "Adventure guide", icon = "Interface\\Icons\\INV_Misc_Book_17" },
    TOGGLECOLLECTIONS       = { label = "Collections",  icon = "Interface\\Icons\\Ability_Mount_RidingHorse" },
    TOGGLECOLLECTIONSMOUNTJOURNAL = { label = "Mounts", icon = "Interface\\Icons\\Ability_Mount_RidingHorse" },
    TOGGLEACHIEVEMENT       = { label = "Achievements", icon = "Interface\\Icons\\Achievement_Quests_Completed_08" },
    TOGGLEGUILDTAB          = { label = "Guild",        icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01" },
    TOGGLESOCIAL            = { label = "Friends",      icon = "Interface\\Icons\\INV_Letter_15" },
    TOGGLECALENDAR          = { label = "Calendar",     icon = "Interface\\Icons\\INV_Misc_Note_02" },
    DECKUI_WEEK             = { label = "Week",         icon = "Interface\\Icons\\INV_Misc_Note_02" },
    TOGGLEGAMEMENU          = { label = "Game menu",    icon = "Interface\\Icons\\INV_Misc_Gear_01" },
    NONE                    = { label = "Nothing",      icon = nil },
}
ns.QUICK_COMMAND_INFO = COMMANDS
ns.QUICK_DEFAULTS = {
    "TOGGLEWORLDMAP", "OPENALLBAGS", "TOGGLEQUESTLOG", "TOGGLECHARACTER0",
    "TOGGLETALENTS", "TOGGLEGROUPFINDER", "TOGGLECOLLECTIONS", "TOGGLEGAMEMENU",
}

-- a command the client does not know binds to nothing; it is left out and
-- shown greyed, and /dc quick names it
local function Known(command)
    return command ~= "NONE" and _G["BINDING_NAME_" .. command] ~= nil
end
ns.QuickCommandKnown = Known

local function Command(i)
    local list = DeckCrossDB and DeckCrossDB.quickEntries
    return list and list[i] or ns.QUICK_DEFAULTS[i]
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

local function Slot(i)
    local b = CreateFrame("Frame", nil, menu)
    b:SetSize(SIZE, SIZE)
    local mask = D.RoundMask(b)
    local ring = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    ring:SetSize(SIZE + 6, SIZE + 6)
    ring:SetPoint("CENTER")
    ring:SetTexture(D.DISC)
    ring:SetVertexColor(0.9, 0.75, 0.2, 1)
    local disc = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    disc:SetAllPoints()
    disc:SetTexture(D.DISC)
    disc:SetVertexColor(0.08, 0.08, 0.08, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon:AddMaskTexture(mask)
    local g = b:CreateTexture(nil, "OVERLAY")
    g:SetSize(18, 18)
    g:SetPoint("CENTER", b, "TOPLEFT", 4, -4)
    g:SetTexture(ns.TEX_PATH .. GLYPHS[i])
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(D.FONT, 11, "OUTLINE")
    b.text:SetPoint("TOP", b, "BOTTOM", 0, -2)
    return b
end

local slots = {}
for i = 1, 8 do
    local cluster = i <= 4 and 1 or 2
    local pos = (i - 1) % 4 + 1
    local cx = (cluster == 1 and -1 or 1) * (STEP * 1.5 + 6)
    local f = Slot(i)
    f:SetPoint("CENTER", menu, "CENTER", cx + OFFSETS[pos][1] * STEP, OFFSETS[pos][2] * STEP + 8)
    slots[i] = f
end

-- icons and labels from the chosen commands
local function Paint()
    for i, f in ipairs(slots) do
        local command = Command(i)
        local info = COMMANDS[command] or { label = command }
        local known = Known(command)
        if info.icon == "portrait" then
            SetPortraitTexture(f.icon, "player")
        else
            f.icon:SetTexture(info.icon)
        end
        f.icon:SetDesaturated(not known)
        f.icon:SetShown(info.icon ~= nil)
        f.text:SetText(info.label)
        if known then f.text:SetTextColor(1, 1, 1) else f.text:SetTextColor(0.5, 0.5, 0.5) end
    end
end

menu:SetScript("OnShow", Paint)

-------------------------------------------------------------------
-- The secure part: RB binds the eight keys while it is held
-------------------------------------------------------------------
local header = CreateFrame("Frame", "DeckCrossQuickHeader", UIParent, "SecureHandlerBaseTemplate")
local holdBtn = CreateFrame("Button", "DeckCrossQuickHold", UIParent, "SecureActionButtonTemplate")
holdBtn:RegisterForClicks("AnyDown", "AnyUp")
holdBtn:Hide()   -- a binding click reaches it while hidden too

-- the key/command pairs the snippet binds; secure attributes, so they are
-- written out of combat only
local function SetEntries()
    local n = 0
    for i = 1, 8 do
        local command = Command(i)
        if Known(command) then
            n = n + 1
            header:SetAttribute("key" .. n, KEYS[i])
            header:SetAttribute("command" .. n, command)
        end
    end
    header:SetAttribute("count", n)
end

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
    SetEntries()
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
    DeckCrossDB.quickEntries = DeckCrossDB.quickEntries or CopyTable(ns.QUICK_DEFAULTS)
    Apply()
end

-- the Cross page changed a slot: new attributes (after combat) and pictures
function ns.ApplyQuickEntries()
    if InCombatLockdown() then print("DeckUI Cross: takes effect after combat.") end
    Apply()
    if menu:IsShown() then Paint() end
end

-- /dc quick: the option, RB's binding and every entry's command
function ns.PrintQuickMenu()
    print(("DeckUI Cross quick menu: option=%s deck=%s RB=%s"):format(
        tostring(DeckCrossDB.quickMenu), tostring(D.IsDeck()), tostring(GetBindingAction(HOLD, true))))
    for i = 1, 8 do
        local command = Command(i)
        print(("  %s -> %s (%s)"):format(KEYS[i], command, Known(command) and "ok" or "UNKNOWN"))
    end
end

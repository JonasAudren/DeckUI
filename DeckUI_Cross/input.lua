local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Controller keys: D-pad (cluster 1) and face buttons (cluster 2),
-- LT = Shift = left half, RT = Ctrl = right half, both = middle.
-------------------------------------------------------------------
local PAD_KEYS = {
    { "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT" },
    { "PAD4",   "PAD2",      "PAD1",     "PAD3"     },
}
local MODS = { "SHIFT", "CTRL", "SHIFT-CTRL" }

local DEFAULT_BINDINGS = {
    PAD1      = "JUMP",
    PAD3      = "INTERACTTARGET",
    PAD2      = "TOGGLEGAMEMENU",
    PAD4      = "TOGGLECHARACTER0",
    PADDUP    = "TARGETNEARESTENEMY",
    PADDDOWN  = "TARGETPREVIOUSENEMY",
    PADDLEFT  = "TARGETPREVIOUSFRIEND",
    PADDRIGHT = "TARGETNEARESTFRIEND",
}

-------------------------------------------------------------------
-- PC input: buttons 1-12 follow the keys of Action Bar 1 (ACTIONBUTTON
-- 1-12, i.e. your normal 1-0, -, = or whatever you bound), buttons
-- 13-24 the keys of Action Bar 2 (MULTIACTIONBAR1BUTTON1-12).
-- core.lua stores the binding command on each button as DeckCommand.
-------------------------------------------------------------------
function ns.KeysForButton(b)
    if not b.DeckCommand then return end
    return GetBindingKey(b.DeckCommand)
end

-------------------------------------------------------------------
-- Bindings
-------------------------------------------------------------------
local bindingsPending = false

-- Keys are bound to Blizzard's NATIVE commands (ACTIONBUTTONn /
-- MULTIACTIONBAR1BUTTONn), not to our buttons: only the native path
-- runs the engine's press-and-hold repeat (single-button assistant,
-- hold-to-cast). Our buttons just mirror the result visually.
local function BindPad()
    local idx = 0
    for group = 1, 3 do
        for cluster = 1, 2 do
            for pos = 1, 4 do
                idx = idx + 1
                local b = ns.buttons[idx]
                if b and b.DeckCommand then
                    SetOverrideBinding(ns.header, true,
                        MODS[group] .. "-" .. PAD_KEYS[cluster][pos], b.DeckCommand)
                end
            end
        end
    end
end

function ns.ApplyBindings()
    if InCombatLockdown() then
        bindingsPending = true
        return
    end
    ClearOverrideBindings(ns.header)
    -- PC: nothing to bind, the player's own key bindings already drive
    -- the native commands the crosses mirror.
    if D.IsDeck() then BindPad() end
    bindingsPending = false
end

function ns.ApplyLabels()
    if D.IsDeck() then
        ns.SetLabelMode("pad")
    else
        ns.SetLabelMode("keys", function(b)
            local key = ns.KeysForButton(b)
            return key and GetBindingText(key, true) or ""
        end)
    end
    ns.SetLabelsShown(DeckCrossDB.showLabels)
end

function ns.SetupGamepad()
    SetCVar("GamePadEnable", "1")
    SetCVar("GamePadEmulateShift", "PADLTRIGGER")
    SetCVar("GamePadEmulateCtrl",  "PADRTRIGGER")
    SetCVar("GamePadEmulateAlt",   "none")
    print("DeckUI Cross: gamepad enabled, LT = left, RT = right, LT+RT = middle.")
end

function ns.ApplyDefaultBindings()
    if InCombatLockdown() then
        print("DeckUI Cross: not possible in combat.")
        return
    end
    for key, command in pairs(DEFAULT_BINDINGS) do
        SetBinding(key, command)
    end
    SaveBindings(GetCurrentBindingSet())
    print("DeckUI Cross: default controller bindings applied.")
end

-------------------------------------------------------------------
-- Hide Blizzard's own bars that the crosses mirror, so nothing shows
-- twice. Done by reparenting to a hidden frame (the safe, reload-free
-- way); the key bindings keep working because they click our buttons.
-------------------------------------------------------------------
local hider = CreateFrame("Frame", "DeckCrossBarHider", UIParent)
hider:Hide()

-- Frame names changed over the versions (MainMenuBar was renamed in
-- Midnight), so bars are resolved through one of their buttons: the
-- parent of ActionButton1 IS Action Bar 1, whatever it is called.
local BARS = { "ActionButton1", "MultiBarBottomLeftButton1" }   -- Action Bar 1 + 2 (both devices)

-- Midnight wraps every button in its own container, so we climb up
-- from the button until we reach the frame that hangs directly under
-- UIParent (or under our hider, if we already moved it) - that is the bar.
local function ResolveBar(buttonName)
    local button = _G[buttonName]
    if not button then return nil, buttonName .. " not found" end
    local frame = button
    for _ = 1, 10 do
        local parent = frame:GetParent()
        if not parent then return nil, buttonName .. " has no bar frame" end
        if parent == UIParent or parent == hider then return frame end
        frame = parent
    end
    return nil, buttonName .. ": bar frame too deep"
end

local hidePending = false

local function HideBar(bar)
    if not bar.DeckOrigParent then
        bar.DeckOrigParent = bar:GetParent()
        -- if Blizzard (Edit Mode etc.) reparents the bar, pull it back
        hooksecurefunc(bar, "SetParent", function(self, parent)
            if self.DeckHidden and parent ~= hider and not InCombatLockdown() then
                self:SetParent(hider)
            end
        end)
    end
    bar.DeckHidden = true
    bar:SetParent(hider)
    -- belt and braces: a secure visibility driver keeps it hidden even
    -- if something calls Show() on it
    RegisterStateDriver(bar, "visibility", "hide")
end

local function ShowBar(bar)
    if not bar.DeckOrigParent then return end
    bar.DeckHidden = false
    UnregisterStateDriver(bar, "visibility")
    bar:SetParent(bar.DeckOrigParent)
    bar:Show()
end

function ns.SetBlizzardBarsHidden(state)
    DeckCrossDB.hideBlizzardBars = state
    if InCombatLockdown() then
        hidePending = true
        return
    end
    hidePending = false
    local bars = BARS
    for _, name in ipairs(bars) do
        local bar, why = ResolveBar(name)
        if bar then
            if state then HideBar(bar) else ShowBar(bar) end
        else
            print("DeckUI Cross: " .. why)
        end
    end
end

function ns.PrintBars()
    local bars = BARS
    print("DeckUI Cross: hideBlizzardBars=" .. tostring(DeckCrossDB.hideBlizzardBars))
    for _, name in ipairs(bars) do
        local bar, why = ResolveBar(name)
        if bar then
            local parent = bar:GetParent()
            print(string.format("  %s -> bar %s parent=%s shown=%s visible=%s alpha=%.2f",
                name, bar:GetName() or "(unnamed)",
                parent and (parent:GetName() or "?") or "nil",
                tostring(bar:IsShown()), tostring(bar:IsVisible()), bar:GetAlpha()))
        else
            print("  " .. why)
        end
    end
end

-------------------------------------------------------------------
-- Highlight (controller only - on the PC all crosses stay lit)
-------------------------------------------------------------------
local DIM, IDLE, ACTIVE, MID_IDLE = 0.35, 0.8, 1, 0.25
local inCombat     = false
local lastActivity = 0
local dimmed       = nil     -- last applied state, to avoid needless updates

-- Out of combat the hotbar is dimmed (DeckCrossDB.oocAlpha). Any activity
-- (LT/RT, casting, pressing a button) brings it back to full; DIM_DELAY
-- seconds after the last activity it dims again. A ticker re-checks, so
-- a missed event can't leave it stuck bright.
local DIM_DELAY = 3

local function Touch()
    lastActivity = GetTime()
end

local function UpdateHighlight()
    local lt, rt = IsShiftKeyDown(), IsControlKeyDown()
    local modHeld = lt or rt
    if modHeld then Touch() end
    local idle = (not inCombat) and (not modHeld) and (GetTime() - lastActivity > DIM_DELAY)
    local ooc = idle and (DeckCrossDB and DeckCrossDB.oocAlpha or 1) or 1

    if not D.IsDeck() then
        ns.SetGroupAlpha(IDLE * ooc, IDLE * ooc, IDLE * ooc)
        return
    end
    if lt and rt then
        ns.SetGroupAlpha(DIM, DIM, ACTIVE)
    elseif lt then
        ns.SetGroupAlpha(ACTIVE, DIM, MID_IDLE)
    elseif rt then
        ns.SetGroupAlpha(DIM, ACTIVE, MID_IDLE)
    else
        ns.SetGroupAlpha(IDLE * ooc, IDLE * ooc, MID_IDLE * ooc)
    end
end
ns.UpdateHighlight = UpdateHighlight
ns.TouchActivity   = Touch

-- ticker: cheap re-check a few times per second
local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, dt)
    acc = acc + dt
    if acc < 0.25 then return end
    acc = 0
    if DeckCrossDB then UpdateHighlight() end
end)

function ns.SetOocAlpha(value)
    DeckCrossDB.oocAlpha = value
    UpdateHighlight()
end

-------------------------------------------------------------------
-- Startup (works on normal login AND when loaded on demand via the menu)
-------------------------------------------------------------------
local function Init()
    DeckCrossDB = DeckCrossDB or {}
    if DeckCrossDB.showLabels == nil then DeckCrossDB.showLabels = true end
    if DeckCrossDB.oocAlpha == nil then DeckCrossDB.oocAlpha = 0.35 end
    inCombat = InCombatLockdown()
    D.MigrateToDevice(DeckCrossDB, { "scale" })
    ns.SetScale(ns.DeviceDB().scale or 1)
    DeckCrossDB.testMode = nil
    DeckCrossDB.pcKeys   = nil
    if DeckCrossDB.hideBlizzardBars == nil then DeckCrossDB.hideBlizzardBars = true end
    D.MakeMovable(ns.anchor, "Cross Hotbar", DeckCrossDB)
    ns.ApplyBindings()
    ns.ApplyLabels()
    ns.SetBlizzardBarsHidden(DeckCrossDB.hideBlizzardBars)
    UpdateHighlight()
    print("DeckUI Cross: " .. (D.IsDeck() and "controller mode (LT/RT)" or "keyboard mode (mirrors Action Bar 1 + 2, Blizzard bindings)"))
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("MODIFIER_STATE_CHANGED")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
ev:SetScript("OnEvent", function(self, event)
    if event == "UNIT_SPELLCAST_SENT" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        Touch()
        UpdateHighlight()
        return
    end
    if event == "PLAYER_LOGIN" then
        Init()
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        UpdateHighlight()
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        UpdateHighlight()
        if bindingsPending then ns.ApplyBindings() end
        if hidePending then ns.SetBlizzardBarsHidden(DeckCrossDB.hideBlizzardBars) end
    elseif event == "MODIFIER_STATE_CHANGED" then
        UpdateHighlight()
    elseif event == "UPDATE_BINDINGS" then
        -- player changed keys in Blizzard's menu: follow them
        if DeckCrossDB and not D.IsDeck() then
            ns.ApplyBindings()
            ns.ApplyLabels()
        end
    end
end)

if IsLoggedIn() then
    -- Module was loaded via the menu; SavedVariables arrive with ADDON_LOADED
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, _, name)
        if name == ADDON then
            self:UnregisterEvent("ADDON_LOADED")
            Init()
        end
    end)
else
    ev:RegisterEvent("PLAYER_LOGIN")
end

-- Shortcut: opens the Cross tab directly
SLASH_DECKCROSS1 = "/dc"
SlashCmdList.DECKCROSS = function(msg)
    msg = (msg or ""):lower():trim()
    local idx = msg:match("^overlay%s*(%d*)$")
    if idx then
        ns.DumpOverlay(tonumber(idx) or 1)
        return
    elseif msg == "bare" then
        ns.ToggleBare()
        return
    elseif msg == "bars" then
        ns.PrintBars()
        return
    end
    D.ToggleConfig("Cross")
end

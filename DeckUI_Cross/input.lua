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

-- /dc trace: print what the engine does while a key is held, with
-- timestamps. The press-and-hold repeat runs on the engine's native
-- binding, and it stops the moment the combination stops matching. On a
-- Deck LT/RT are ANALOG triggers driving the emulated Shift/Ctrl, so a
-- finger easing off below the threshold releases the modifier while the
-- direction key stays down - and when the trigger comes back there is no
-- fresh key-down for the combination, so the repeat does not resume. The
-- trace tells that apart from a cast that simply failed, and it also says
-- when something re-applies our bindings mid-fight.
local trace, traceStart = false, 0

local function TraceSay(fmt, ...)
    print(format("|cff88ccffDC %6.2f|r " .. fmt, GetTime() - traceStart, ...))
end

-- Keys are bound to Blizzard's NATIVE commands (ACTIONBUTTONn /
-- MULTIACTIONBAR1BUTTONn), not to our buttons: only the native path
-- runs the engine's press-and-hold repeat (single-button assistant,
-- hold-to-cast). Our buttons just mirror the result visually.
-- Camera zoom on LB + D-pad up/down (owner's wish, 2026-09-30). The
-- binding UI cannot take LB + D-pad as one key: only Shift, Ctrl and Alt
-- combine with another key, and on a gamepad a button becomes one of
-- those only through GamePadEmulate*. Shift and Ctrl are LT/RT already, so
-- LB becomes Alt - and stops being a button of its own.
-- CAMERAZOOMIN/OUT (Bindings_Standard.xml) zoom smoothly while held and
-- one step on a tap, like the mouse wheel.
local LB = "PADLSHOULDER"

-- LB is Alt while either of its uses is on: zoom, or the stance row's
-- keys (LB + face buttons / D-pad left-right, stance.lua)
local function LBIsAlt()
    return DeckCrossDB.lbZoom or DeckCrossDB.stanceBar
end
ns.LBIsAlt = LBIsAlt

local function ApplyZoomModifier()
    if LBIsAlt() then
        SetCVar("GamePadEmulateAlt", LB)
    elseif GetCVar("GamePadEmulateAlt") == LB then
        -- ours to undo; an Alt the player set up differently stays
        SetCVar("GamePadEmulateAlt", "none")
    end
end

ns.ApplyLBModifier = ApplyZoomModifier

local function BindZoom()
    if not DeckCrossDB.lbZoom then return end
    SetOverrideBinding(ns.header, true, "ALT-PADDUP", "CAMERAZOOMIN")
    SetOverrideBinding(ns.header, true, "ALT-PADDDOWN", "CAMERAZOOMOUT")
end

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
        if trace then TraceSay("bindings deferred (in combat)") end
        return
    end
    if trace then TraceSay("BINDINGS RE-APPLIED - this kills a running repeat") end
    ClearOverrideBindings(ns.header)
    -- PC: nothing to bind, the player's own key bindings already drive
    -- the native commands the crosses mirror.
    if D.IsDeck() then
        BindPad()
        ApplyZoomModifier()
        BindZoom()
    end
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
    SetCVar("GamePadEmulateAlt",   LBIsAlt() and LB or "none")
    print("DeckUI Cross: gamepad enabled, LT = left, RT = right, LT+RT = middle.")
end

function ns.SetLBZoom(on)
    DeckCrossDB.lbZoom = on
    if not D.IsDeck() then
        print("DeckUI Cross: saved - LB zoom applies on the Steam Deck.")
        return
    end
    if InCombatLockdown() then
        print("DeckUI Cross: takes effect after combat.")
    end
    -- ApplyBindings sets the CVar and the bindings, or waits for combat end;
    -- switched off, it only drops the zoom bindings, so undo Alt here
    -- (ApplyZoomModifier keeps it while the stance keys still need it)
    if not on then ApplyZoomModifier() end
    ns.ApplyBindings()
    print(on and "DeckUI Cross: LB + D-pad up/down zooms the camera (hold for a smooth zoom). LB now works as Alt."
        or LBIsAlt() and "DeckUI Cross: LB zoom off. LB stays Alt for the stance keys."
        or "DeckUI Cross: LB zoom off, LB is a button of its own again.")
end

-- SetBinding writes straight into the player's key bindings and there is
-- no undo, so ask first and say exactly which of their bindings would be
-- replaced. The question goes through DeckUI's own dialog (widgets.lua):
-- a StaticPopup shown from addon code leaves the shared dialog frame
-- tainted for whatever Blizzard shows on it next.

local function KeyLabel(key)
    return GetBindingText(key, true) or key
end

local function ActionLabel(command)
    return _G["BINDING_NAME_" .. command] or command
end

function ns.ApplyDefaultBindingsNow()
    if InCombatLockdown() then
        print("DeckUI Cross: not possible in combat.")
        return
    end
    local n = 0
    for key, command in pairs(DEFAULT_BINDINGS) do
        SetBinding(key, command)
        n = n + 1
    end
    SaveBindings(GetCurrentBindingSet())
    print("DeckUI Cross: default controller bindings applied (" .. n .. " keys).")
end

function ns.ApplyDefaultBindings()
    if InCombatLockdown() then
        print("DeckUI Cross: not possible in combat.")
        return
    end

    -- keys that already do something else: those are what the player loses
    local taken = {}
    for key, command in pairs(DEFAULT_BINDINGS) do
        local current = GetBindingAction(key)
        if current and current ~= "" and current ~= command then
            -- both sides, or a row reads like an assignment instead of a loss
            table.insert(taken, KeyLabel(key) .. "   |cffff8080" .. ActionLabel(current)
                .. "|r  ->  " .. ActionLabel(command))
        end
    end
    table.sort(taken)

    local msg = "Bind the controller defaults?\n\n"
             .. "A jump, X interact, B game menu, Y character.\n"
             .. "D-pad up/down cycles enemies, left/right cycles friends."
    if #taken > 0 then
        msg = msg .. "\n\n|cffff8080This replaces " .. #taken
           .. (#taken == 1 and " binding you already use|r" or " bindings you already use|r")
           .. " (yours -> DeckUI):\n"
           .. table.concat(taken, "\n")
    else
        msg = msg .. "\n\nNone of these keys is bound to anything else."
    end
    msg = msg .. "\n\nThere is no undo."

    D.Dialog({
        text = msg,
        width = 380,
        accept = YES,
        cancel = NO,
        onAccept = ns.ApplyDefaultBindingsNow,
    })
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

-- the same for any other bar, found through one of its buttons (stance.lua)
function ns.SetBlizzardBarHidden(buttonName, state)
    if InCombatLockdown() then return false end
    local bar, why = ResolveBar(buttonName)
    if not bar then
        print("DeckUI Cross: " .. why)
        return true
    end
    -- a bar that is one of the mirrored ones stays with their setting
    for _, name in ipairs(BARS) do
        if ResolveBar(name) == bar then return true end
    end
    if state then HideBar(bar) else ShowBar(bar) end
    return true
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

-------------------------------------------------------------------
-- Leave vehicle / taxi
-------------------------------------------------------------------
-- Blizzard's leave button went missing along with the bars we hide, which
-- strands the player in a vehicle with no way out on the Deck. So we carry
-- our own, and show it exactly when leaving is possible and none of
-- Blizzard's leave buttons can actually be seen - that way it never shows
-- twice, whichever frame the button hangs under on this client.
-- VehicleExit and TaxiRequestEarlyLanding are not protected (Blizzard's own
-- button calls them from plain Lua), so a normal button does, in combat too.
local LEAVE_SIZE = 40

local leave = CreateFrame("Button", "DeckCrossLeaveVehicle", UIParent)
leave:SetSize(LEAVE_SIZE, LEAVE_SIZE)
leave.defaultPoint = { "BOTTOM", UIParent, "BOTTOM", 0, 220 }
leave:SetPoint(unpack(leave.defaultPoint))
leave:Hide()

leave:SetNormalTexture("Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up")
leave:SetPushedTexture("Interface\\Vehicles\\UI-Vehicles-Button-Exit-Down")
leave:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
for _, tex in ipairs({ leave:GetNormalTexture(), leave:GetPushedTexture() }) do
    tex:SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
end

leave:SetScript("OnClick", function()
    if UnitOnTaxi("player") then
        TaxiRequestEarlyLanding()
    else
        VehicleExit()
    end
end)
leave:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(UnitOnTaxi("player") and (TAXI_CANCEL or "Request stop") or (LEAVE_VEHICLE or "Leave vehicle"))
    GameTooltip:Show()
end)
leave:SetScript("OnLeave", GameTooltip_Hide)

local function BlizzardLeaveVisible()
    local main = _G["MainMenuBarVehicleLeaveButton"]
    if main and main:IsVisible() then return true end
    local override = _G["OverrideActionBar"]
    if override and override.LeaveButton and override.LeaveButton:IsVisible() then return true end
    return false
end

local function CanLeave()
    return CanExitVehicle() or UnitOnTaxi("player")
end

-- Polled rather than event-driven: taxis have no clean start event, and
-- Blizzard updates its own button on the same events we would listen to,
-- so asking "is theirs visible" right then would race it.
local leaveElapsed = 0
local leavePoll = CreateFrame("Frame")
leavePoll:SetScript("OnUpdate", function(_, dt)
    leaveElapsed = leaveElapsed + dt
    if leaveElapsed < 0.2 then return end
    leaveElapsed = 0
    -- While frames are unlocked it stays visible, or it could never be
    -- dragged anywhere outside a vehicle.
    leave:SetShown(D.IsUnlocked("Leave vehicle") or (CanLeave() and not BlizzardLeaveVisible()))
end)

local function PrintLeave()
    local b = _G["MainMenuBarVehicleLeaveButton"]
    if not b then
        print("  MainMenuBarVehicleLeaveButton not found")
    else
        local chain, frame = {}, b:GetParent()
        while frame and #chain < 10 do
            table.insert(chain, frame:GetName() or "(unnamed)")
            if frame == UIParent then break end
            frame = frame:GetParent()
        end
        print(string.format("  leave button: shown=%s visible=%s parents=%s",
            tostring(b:IsShown()), tostring(b:IsVisible()), table.concat(chain, " > ")))
    end
    print(string.format("  can leave=%s  ours shown=%s", tostring(CanLeave()), tostring(leave:IsShown())))
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
    PrintLeave()
    if ns.PrintStance then ns.PrintStance() end
end

-------------------------------------------------------------------
-- Highlight (controller only - on the PC all crosses stay lit)
-------------------------------------------------------------------
local DIM, IDLE, ACTIVE, MID_IDLE = 0.35, 0.8, 1, 0.25
local inCombat     = false
local lastActivity = 0

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
    -- Idle dimming is optional. Switched off, IDLE goes with it: that is the
    -- quiet-but-not-idle level, and leaving it in would mean "no dimming"
    -- still sat at 80%. The LT/RT highlight below is untouched either way -
    -- it says which half a trigger has armed, which is orientation, not
    -- dimming.
    local dimming = DeckCrossDB and DeckCrossDB.dimWhenIdle
    local base = dimming and IDLE or 1
    local idle = dimming and (not inCombat) and (not modHeld) and (GetTime() - lastActivity > DIM_DELAY)
    local ooc = idle and (DeckCrossDB and DeckCrossDB.oocAlpha or 1) or 1

    if not D.IsDeck() then
        ns.SetGroupAlpha(base * ooc, base * ooc, base * ooc)
        return
    end
    if lt and rt then
        ns.SetGroupAlpha(DIM, DIM, ACTIVE)
    elseif lt then
        ns.SetGroupAlpha(ACTIVE, DIM, MID_IDLE)
    elseif rt then
        ns.SetGroupAlpha(DIM, ACTIVE, MID_IDLE)
    else
        ns.SetGroupAlpha(base * ooc, base * ooc, MID_IDLE * ooc)
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

function ns.SetDimWhenIdle(value)
    DeckCrossDB.dimWhenIdle = value
    UpdateHighlight()
end

-------------------------------------------------------------------
-- Startup (works on normal login AND when loaded on demand via the menu)
-------------------------------------------------------------------
-- ConsolePort ships its own cluster bar on the very same LT/RT + D-pad and
-- face button combinations we use, and its ConsolePort_Bar module calls
-- UnregisterAllEvents on ActionButton1-12, which is exactly what our
-- mirrored pushed state hangs off. It also hooks all SetOverrideBinding
-- functions and re-asserts its own override, so our bindings lose. The two
-- cannot share the keys - say so rather than let the user wonder why the
-- cross looks right but does the wrong thing.
local function WarnConsolePortBar()
    if not C_AddOns.IsAddOnLoaded("ConsolePort_Bar") then return end
    print("DeckUI Cross: ConsolePort's action bar is enabled and claims the same LT/RT combinations - the two fight over them.")
    print("DeckUI Cross: uncheck \"Console Port Action Bar\" in the addon list and keep \"Console Port\" itself; its cursor, targeting and rings work fine next to DeckUI.")
end

local function Init()
    DeckCrossDB = DeckCrossDB or {}
    if DeckCrossDB.showLabels == nil then DeckCrossDB.showLabels = true end
    if DeckCrossDB.oocAlpha == nil then DeckCrossDB.oocAlpha = 0.35 end
    -- Off by default: a hotbar that fades while you look at it is a taste,
    -- and the owner's is that it should stay put. The option brings it back.
    if DeckCrossDB.dimWhenIdle == nil then DeckCrossDB.dimWhenIdle = false end
    inCombat = InCombatLockdown()
    D.MigrateToDevice(DeckCrossDB, { "scale" })
    ns.SetScale(ns.DeviceDB().scale or 1)
    DeckCrossDB.testMode = nil
    DeckCrossDB.pcKeys   = nil
    if DeckCrossDB.hideBlizzardBars == nil then DeckCrossDB.hideBlizzardBars = true end
    -- the stance row (stance.lua): off until ticked; on the Deck its LB keys come with it
    if DeckCrossDB.stanceBar == nil then DeckCrossDB.stanceBar = false end
    D.MakeMovable(ns.anchor, "Cross Hotbar", DeckCrossDB)
    D.MakeMovable(leave, "Leave vehicle", DeckCrossDB)
    ns.ApplyBindings()
    ns.ApplyLabels()
    ns.SetBlizzardBarsHidden(DeckCrossDB.hideBlizzardBars)
    if ns.InitAssist then ns.InitAssist() end
    if ns.InitStance then ns.InitStance() end
    UpdateHighlight()
    print("DeckUI Cross: " .. (D.IsDeck() and "controller mode (LT/RT)" or "keyboard mode (mirrors Action Bar 1 + 2, Blizzard bindings)"))
    WarnConsolePortBar()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("MODIFIER_STATE_CHANGED")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
-- Not just for the trace any more: a rejected cast is what the red flash on
-- the button is made of.
ev:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
-- Cast events carry the spell id in different places, and a name lookup
-- can fail on an unknown id - neither is worth an error in a debug aid.
local function SpellLabel(id)
    if not id then return "?" end
    local ok, info = pcall(C_Spell.GetSpellInfo, id)
    if ok and type(info) == "table" and info.name then return info.name end
    return tostring(id)
end

-- A failed cast says nothing about why. The target's state and the red
-- error line the game shows do, and together they separate "no valid
-- target" from "out of range" from "not enough resources".
local function TargetNote()
    if not UnitExists("target") then return "  (no target)" end
    if UnitIsDead("target") then return "  (target dead)" end
    if not UnitCanAttack("player", "target") then return "  (target not attackable)" end
    return ""
end

local function TraceEvent(event, a1, a2, a3)
    if event == "MODIFIER_STATE_CHANGED" then
        -- The interesting line: a modifier going UP while you are still
        -- holding the direction key is the repeat dying.
        TraceSay("%s %s", a1, (a2 == 1) and "down" or "UP  <-- modifier released")
    elseif event == "UNIT_SPELLCAST_SENT" then
        TraceSay("cast sent")
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        TraceSay("cast ok     %s", SpellLabel(a3))
    elseif event == "UNIT_SPELLCAST_FAILED" then
        TraceSay("cast FAILED %s%s", SpellLabel(a3), TargetNote())
    elseif event == "UI_ERROR_MESSAGE" then
        TraceSay("   reason: %s", tostring(a2))
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        TraceSay("%s", event)
    end
end

function ns.ToggleTrace()
    trace = not trace
    if trace then
        traceStart = GetTime()
        ev:RegisterEvent("UI_ERROR_MESSAGE")
        print("DeckUI Cross: trace ON. Hold the key until the repeat stops, then /dc trace again.")
        -- The repeat is driven by Blizzard's own button, and a hidden frame
        -- gets no OnUpdate. Say up front where that button stands, so the
        -- log can be read without guessing at the state it ran in.
        local b = _G["ActionButton1"]
        if b then
            local parent = b:GetParent()
            TraceSay("ActionButton1 shown=%s visible=%s parent=%s",
                tostring(b:IsShown()), tostring(b:IsVisible()),
                parent and (parent:GetName() or "(unnamed)") or "nil")
        end
        TraceSay("hideBlizzardBars=%s device=%s", tostring(DeckCrossDB.hideBlizzardBars), D.IsDeck() and "deck" or "pc")
        if ns.AssistedStatus then
            local n, hasTarget = ns.AssistedStatus()
            TraceSay("assistant buttons=%d  live target=%s%s", n, tostring(hasTarget),
                (n == 0) and "   <-- no button holds the assistant, so no veil can show" or "")
        end
    else
        ev:UnregisterEvent("UI_ERROR_MESSAGE")
        print("DeckUI Cross: trace off.")
    end
end

ev:SetScript("OnEvent", function(self, event, a1, a2, a3)
    if trace then TraceEvent(event, a1, a2, a3) end
    if event == "UNIT_SPELLCAST_SENT" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        Touch()
        UpdateHighlight()
        return
    end
    if event == "UNIT_SPELLCAST_FAILED" then
        if ns.FlashFailed then ns.FlashFailed() end
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
    elseif msg == "page" then
        ns.PrintPage()
        return
    elseif msg == "trace" then
        ns.ToggleTrace()
        return
    elseif msg == "assist" then
        ns.PrintAssist()
        return
    end
    D.ToggleConfig("Cross")
end

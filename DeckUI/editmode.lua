local D = DeckUI

-------------------------------------------------------------------
-- Edit Mode layout per device
-------------------------------------------------------------------
-- Blizzard's Edit Mode layouts live on the server, and so does the choice
-- of the active one - per character and spec (EditModeManager.lua 12.1.0
-- re-reads it on PLAYER_SPECIALIZATION_CHANGED). The owner arranged
-- Blizzard's frames for the Deck, and the PC loaded that arrangement too.
-- DeckUI's own frames are not affected: their positions are per device
-- already.
--
-- The answer is Blizzard's own: one layout per device, made in Edit Mode.
-- DeckUI only remembers which layout this device uses, per character and
-- spec, by *name* (the indices shift when layouts are added or deleted),
-- and learns it by watching: whatever layout is active here is this
-- device's. At login, /reload and after a spec change it switches back if
-- the other device's layout is active.
--
-- Switching is C_EditMode.SetActiveLayout, the call behind Blizzard's own
-- dropdown. From an addon it leaves Edit Mode's manager running tainted
-- for the rest of the session - the way action bars end up blocked in
-- combat. The switch itself is saved on the server, though, and after a
-- reload Blizzard reads it untainted. So every switch asks for a reload
-- right away, and nothing else of Blizzard's is touched.
-------------------------------------------------------------------
local LOGIN_DELAY = 3   -- Edit Mode reads its layouts after PLAYER_ENTERING_WORLD
local MAX_TRIES = 30    -- one a second while Edit Mode is not initialised

local ready = false     -- learning only once this device's layout is in place
local pending = false   -- a switch waits for the end of combat
local lastResult        -- for /deck layout

local function Store(create)
    local device, char, spec = D.CharSpecKey()
    DeckUIDB.editLayouts = DeckUIDB.editLayouts or {}
    local t = DeckUIDB.editLayouts
    if create then
        t[device] = t[device] or {}
        t[device][char] = t[device][char] or {}
    end
    return t[device] and t[device][char], spec
end

-- Blizzard's own merged list: preset layouts first, then the saved ones;
-- activeLayout indexes into that. Only read, never written.
local function LayoutInfo()
    local m = EditModeManagerFrame
    return m and m.layoutInfo
end

local function ActiveName()
    local info = LayoutInfo()
    local layout = info and info.layouts and info.layouts[info.activeLayout]
    return layout and layout.layoutName
end

local function IndexOf(name)
    local info = LayoutInfo()
    for i, layout in ipairs(info and info.layouts or {}) do
        if layout.layoutName == name then return i end
    end
end

local function Remember()
    local name = ActiveName()
    if not name then return end
    local t, spec = Store(true)
    t[spec] = name
end

-------------------------------------------------------------------
-- The reload prompt: a small window of our own rather than a StaticPopup,
-- whose shared dialogs other code relies on staying untainted
-------------------------------------------------------------------
local prompt
local function ShowReloadPrompt(name)
    if not prompt then
        prompt = CreateFrame("Frame", "DeckUIReloadPrompt", UIParent, "BackdropTemplate")
        prompt:SetSize(320, 120)
        prompt:SetPoint("TOP", 0, -160)
        prompt:SetFrameStrata("DIALOG")
        prompt:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        prompt:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        prompt:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        prompt.text = D.Hint(prompt, "", -14)
        prompt.text:SetTextColor(1, 1, 1)
        local reload = D.Button(prompt, "Reload now", -74, ReloadUI)
        reload:SetWidth(130)
        reload:ClearAllPoints()
        reload:SetPoint("BOTTOMLEFT", 16, 14)
        local later = D.Button(prompt, "Later", -74, function() prompt:Hide() end)
        later:SetWidth(130)
        later:ClearAllPoints()
        later:SetPoint("BOTTOMRIGHT", -16, 14)
        tinsert(UISpecialFrames, "DeckUIReloadPrompt")
    end
    prompt.text:SetText(("Edit Mode layout switched to \"%s\" for this device. Reload now so Blizzard's frames pick it up cleanly."):format(name))
    prompt:Show()
end

-------------------------------------------------------------------
-- When
-------------------------------------------------------------------
-- A spec change fires two events, and each starts a delayed sync; the
-- generation lets only the newest chain act, so a layout is never
-- switched (and the reload asked for) twice.
local generation = 0
local switchedTo        -- asked for this session, waiting for the reload

local function Sync(gen, tries)
    gen, tries = gen or generation, tries or 0
    if gen ~= generation or not DeckUIDB.keepLayouts then return end
    if not LayoutInfo() then
        if tries >= MAX_TRIES then
            lastResult = "Edit Mode never initialised, gave up"
            return
        end
        C_Timer.After(1, function() Sync(gen, tries + 1) end)
        return
    end
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local t, spec = Store(false)
    local want = t and t[spec]
    local have = ActiveName()
    if not want then
        Remember()
        lastResult = ("first time here - \"%s\" became this device's layout"):format(tostring(have))
    elseif want == have then
        lastResult = ("\"%s\" already active"):format(want)
    elseif switchedTo == want then
        -- asked already; Blizzard's manager catches up with the reload
        return
    else
        local index = IndexOf(want)
        if index then
            switchedTo = want
            C_EditMode.SetActiveLayout(index)
            lastResult = ("switched from \"%s\" to \"%s\", reload pending"):format(tostring(have), want)
            print(("DeckUI: Edit Mode layout switched to \"%s\" for this device."):format(want))
            ShowReloadPrompt(want)
            -- no learning until the reload: should Blizzard's manager not
            -- have caught up, it would still name the old layout, and
            -- learning that would undo the switch
            return
        else
            -- renamed or deleted: what is active now takes its place
            print(("DeckUI: Edit Mode layout \"%s\" no longer exists; \"%s\" is this device's layout now."):format(want, tostring(have)))
            Remember()
            lastResult = ("\"%s\" missing, kept \"%s\""):format(want, tostring(have))
        end
    end
    ready = true
end

local function Resync()
    ready = false
    generation = generation + 1
    local gen = generation
    C_Timer.After(LOGIN_DELAY, function() Sync(gen) end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
-- Blizzard re-reads the active layout on PLAYER_SPECIALIZATION_CHANGED;
-- learning stops on either spec event, so the new spec's server-side
-- choice is never taken for this device's
ev:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
ev:SetScript("OnEvent", function(self, event, isLogin, isReload)
    if event == "PLAYER_ENTERING_WORLD" then
        if isLogin or isReload then Resync() end
    elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
        -- the player picked a layout (or changed one): that is this
        -- device's now. A frame later, so Blizzard's own handler has
        -- updated the active layout whatever the handler order.
        C_Timer.After(0, function()
            if ready and DeckUIDB.keepLayouts then Remember() end
        end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then Sync() end
    elseif event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        Resync()
    end
end)

-- The checkbox: switched on, the active layout becomes this device's.
function D.SetKeepLayouts(on)
    if on then
        if LayoutInfo() then
            Remember()
            ready = true
            lastResult = ("switched on - \"%s\" became this device's layout"):format(tostring(ActiveName()))
        else
            Resync()
        end
        print(("DeckUI: Edit Mode layouts are now kept per device. \"%s\" belongs to the %s."):format(
            tostring(ActiveName()), D.DEVICE_NAMES[D.DeviceKey()]))
    else
        ready = false
        print("DeckUI: Edit Mode layouts are no longer kept per device (the saved choices stay).")
    end
end

-- /deck layout
function D.PrintLayout()
    local device, char, spec = D.CharSpecKey()
    local t = Store(false)
    print(("DeckUI: Edit Mode layout per device %s; %s, %s, spec %s"):format(
        DeckUIDB.keepLayouts and "on" or "off", device, char, tostring(spec)))
    print(("DeckUI: active \"%s\", saved for this device \"%s\", learning %s, switch waiting for combat end %s"):format(
        tostring(ActiveName()), tostring(t and t[spec]), ready and "yes" or "no", pending and "yes" or "no"))
    print("DeckUI: last sync: " .. (lastResult or "none yet"))
end

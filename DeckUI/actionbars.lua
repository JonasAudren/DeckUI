local D = DeckUI

-------------------------------------------------------------------
-- Action bars per device
-------------------------------------------------------------------
-- What sits on the action bars is stored on the server, per character and
-- spec, and there is no CVar to keep it local the way synchronizeBindings
-- does for the keys. The owner lays out his bars differently on the Deck
-- (its buttons want it), and the PC then loaded that layout too.
--
-- So DeckUI keeps a copy per device, character and spec, and at login (and
-- after a spec change) puts this device's copy back onto the bars. While
-- playing, every change to the bars is copied again, a second after the
-- last one. The first time a character and spec is seen on a device, the
-- bars as they are become that device's copy - nothing is placed.
--
-- Only the player's own slots take part (Blizzard's page numbers,
-- MultiActionBars.lua 12.1.0): pages 1-6 (action bar 1 with its second
-- page, bars 2-5), 7-10 (the stance and form bars of druids, rogues and
-- the like) and 13-15 (bars 6-8). Page 11 is the skyriding bar, 12 and
-- 16-18 belong to vehicles, possession and override bars - the game fills
-- those itself.
--
-- Placing is Blizzard's cursor path: pick the thing up (spell, macro,
-- item, mount ...), PlaceAction, ClearCursor. That is protected in combat,
-- so a restore waits for the end of combat. Whatever cannot be picked up -
-- a spell not learned in this talent setup, an item no longer in the bags -
-- leaves its slot alone and is counted.
-------------------------------------------------------------------
local SLOTS = {}
for page = 1, 15 do
    if page <= 10 or page >= 13 then
        for i = 1, 12 do SLOTS[#SLOTS + 1] = (page - 1) * 12 + i end
    end
end

local RANDOM_MOUNT = 0x0FFFFFFF   -- "summon random favorite mount"
local SETTLE = 1.0                -- seconds of quiet before a copy is taken
local LOGIN_DELAY = 3             -- the bars arrive from the server after login
local MAX_TRIES = 10              -- LOGIN_DELAY apart while the bars read empty

local ready = false               -- copies are only taken once the bars are ours
local pending = false             -- a restore waits for the end of combat
local lastResult                  -- for /deck bars

local function Secret(v)
    return issecretvalue and issecretvalue(v)
end

local function SpecID()
    local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
    local getInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
    local index = getSpec and getSpec()
    return index and getInfo and getInfo(index) or 0
end

local function Key()
    return D.DeviceKey(), UnitName("player") .. "-" .. GetRealmName(), SpecID()
end
-- device, "name-realm", specID - editmode.lua keys its layouts the same way
D.CharSpecKey = Key

-- the stored copy for this device, character and spec (create makes it)
local function Layout(create)
    local device, char, spec = Key()
    DeckUIDB.barLayouts = DeckUIDB.barLayouts or {}
    local t = DeckUIDB.barLayouts
    if not create and not (t[device] and t[device][char]) then return nil end
    t[device] = t[device] or {}
    t[device][char] = t[device][char] or {}
    if create then t[device][char][spec] = t[device][char][spec] or {} end
    return t[device][char][spec]
end

-------------------------------------------------------------------
-- Reading a slot
-------------------------------------------------------------------
-- An entry says what to pick up again: false for an empty slot, otherwise
-- { t = kind, id = ... }. Kinds we cannot place again are kept as
-- { t = "other" } and their slots are never touched.
-- The assistant's slot cannot be recognised by its contents - GetActionInfo
-- names whatever it recommends right now - so it is asked by slot.
local function Read(slot)
    if C_ActionBar.IsAssistedCombatAction(slot) then return { t = "assist" } end
    local kind, id = GetActionInfo(slot)
    if Secret(kind) or Secret(id) then return nil end
    if not kind then return false end
    if kind == "spell" or kind == "item" or kind == "flyout" then
        return { t = kind, id = id }
    elseif kind == "macro" then
        -- the index shifts when macros are added; the name is what stays
        return { t = "macro", id = GetActionText(slot) }
    elseif kind == "summonmount" then
        return { t = "mount", id = id }
    elseif kind == "summonpet" then
        return { t = "pet", id = id }
    elseif kind == "equipmentset" then
        return { t = "set", id = id }   -- the set's name
    end
    return { t = "other", kind = kind }
end

local function Same(a, b)
    if not a or not b then return a == b end
    return a.t == b.t and a.id == b.id
end

-- Copy the bars into this device's layout. Returns false when a slot
-- could not be read (a secret value), or when every slot reads empty -
-- that is bars not loaded yet rather than a layout, and storing it would
-- wipe the bars at the next login. Either way nothing is written.
local function Snapshot()
    local copy, filled = {}, 0
    for _, slot in ipairs(SLOTS) do
        local entry = Read(slot)
        if entry == nil then return false end
        copy[slot] = entry
        if entry then filled = filled + 1 end
    end
    if filled == 0 then return false end
    local layout = Layout(true)
    wipe(layout)
    for slot, entry in pairs(copy) do layout[slot] = entry end
    return true
end

-------------------------------------------------------------------
-- Placing a slot
-------------------------------------------------------------------
local PickupSpell = C_Spell and C_Spell.PickupSpell or PickupSpell
local PickupItem = C_Item and C_Item.PickupItem or PickupItem

local function PickupMount(id)
    if id == RANDOM_MOUNT then
        C_MountJournal.Pickup(0)
        return
    end
    for i = 1, C_MountJournal.GetNumDisplayedMounts() do
        if C_MountJournal.GetDisplayedMountID(i) == id then
            C_MountJournal.Pickup(i)
            return
        end
    end
    -- hidden by the journal's filters: the mount's spell places it too
    local _, spellID = C_MountJournal.GetMountInfoByID(id)
    if spellID then PickupSpell(spellID) end
end

local function PickupFlyout(id)
    local bank = Enum.SpellBookSpellBank.Player
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
            local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
            if item and item.itemType == Enum.SpellBookItemType.Flyout and item.actionID == id then
                C_SpellBook.PickupSpellBookItem(i, bank)
                return
            end
        end
    end
end

local PICKUP = {
    spell = function(id)
        PickupSpell(id)
        -- a talent may have replaced the spell with a variant
        if not GetCursorInfo() and FindBaseSpellByID then
            local base = FindBaseSpellByID(id)
            if base and base ~= id then PickupSpell(base) end
        end
    end,
    assist = function()
        local id = C_AssistedCombat.GetActionSpell()
        if id then PickupSpell(id) end
    end,
    item = function(id)
        if PlayerHasToy and PlayerHasToy(id) then
            C_ToyBox.PickupToyBoxItem(id)
        else
            PickupItem(id)
        end
    end,
    macro = function(name)
        local index = name and GetMacroIndexByName(name) or 0
        if index > 0 then PickupMacro(index) end
    end,
    flyout = PickupFlyout,
    mount = PickupMount,
    pet = function(guid) C_PetJournal.PickupPet(guid) end,
    set = function(name)
        local id = C_EquipmentSet.GetEquipmentSetID(name)
        if id then C_EquipmentSet.PickupEquipmentSet(id) end
    end,
}

-- Put the stored layout on the bars. Slots that already match are left
-- alone, so on the device that made the layout this places nothing.
local function Restore(layout)
    local placed, cleared, failed = 0, 0, 0
    ClearCursor()
    for _, slot in ipairs(SLOTS) do
        local want = layout[slot]
        local have = Read(slot)
        if want ~= nil and have ~= nil and not Same(want, have)
            and not (want and want.t == "other") and not (have and have.t == "other") then
            if want == false then
                PickupAction(slot)
                ClearCursor()
                cleared = cleared + 1
            else
                local ok = pcall(PICKUP[want.t], want.id)
                if ok and GetCursorInfo() then
                    PlaceAction(slot)
                    placed = placed + 1
                else
                    failed = failed + 1
                end
                ClearCursor()
            end
        end
    end
    return placed, cleared, failed
end

-------------------------------------------------------------------
-- When
-------------------------------------------------------------------
-- Login and a spec change can each start a delayed sync; the generation
-- lets only the newest chain act, so a layout is never placed twice.
local generation = 0

local function Sync(gen, tries)
    gen, tries = gen or generation, tries or 0
    if gen ~= generation or not DeckUIDB.keepBars then return end
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local layout = Layout(false)
    if layout and next(layout) then
        local placed, cleared, failed = Restore(layout)
        lastResult = ("placed %d, cleared %d, could not place %d"):format(placed, cleared, failed)
        if placed + cleared > 0 then
            print(("DeckUI: action bars set to this device's layout (%s)."):format(lastResult))
        end
    elseif Snapshot() then
        lastResult = "first time here - the bars as they are became this device's layout"
    else
        -- bars still empty: try again later rather than store nothing
        if tries >= MAX_TRIES then
            lastResult = "bars never became readable, gave up until the next login"
            return
        end
        lastResult = "bars not readable yet, trying again"
        C_Timer.After(LOGIN_DELAY, function() Sync(gen, tries + 1) end)
        return
    end
    -- the placed actions come back as slot events; their copy settles then
    ready = true
end

local copyTimer
local function TakeCopy()
    copyTimer = nil
    if not ready or InCombatLockdown() then return end
    Snapshot()
end

-- In combat nothing is scheduled: the bars cannot change there anyway,
-- and PLAYER_REGEN_ENABLED schedules a copy afterwards.
local function ScheduleCopy()
    if not ready or not DeckUIDB.keepBars or InCombatLockdown() then return end
    if copyTimer then copyTimer:Cancel() end
    copyTimer = C_Timer.NewTimer(SETTLE, TakeCopy)
end

-- a spec change swaps every bar; no copies until this spec's are back
local function Resync()
    ready = false
    if copyTimer then copyTimer:Cancel(); copyTimer = nil end
    generation = generation + 1
    local gen = generation
    C_Timer.After(LOGIN_DELAY, function() Sync(gen) end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
-- the spec itself, not every talent change (PLAYER_SPECIALIZATION_CHANGED
-- fires for those too)
ev:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
ev:SetScript("OnEvent", function(self, event, isLogin, isReload)
    if event == "PLAYER_ENTERING_WORLD" then
        -- login and /reload, not every loading screen
        if isLogin or isReload then Resync() end
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        ScheduleCopy()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then Sync() else ScheduleCopy() end
    elseif event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
        Resync()
    end
end)

-- The checkbox: switched on, the bars as they are become this device's
-- layout; switched off, the copies stay but nothing is placed.
function D.SetKeepBars(on)
    if on then
        if InCombatLockdown() or not Snapshot() then
            -- the next sync takes the copy
            Resync()
        else
            ready = true
            lastResult = "switched on - the bars as they are became this device's layout"
        end
        print("DeckUI: action bars are now kept per device. This layout belongs to the " .. D.DEVICE_NAMES[D.DeviceKey()] .. ".")
    else
        ready = false
        print("DeckUI: action bars are no longer kept per device (the saved layouts stay).")
    end
end

-- /deck bars
function D.PrintBars()
    local device, char, spec = Key()
    local layout = Layout(false)
    local n = 0
    for _, entry in pairs(layout or {}) do if entry then n = n + 1 end end
    print(("DeckUI: action bars per device %s; %s, %s, spec %s"):format(
        DeckUIDB.keepBars and "on" or "off", device, char, tostring(spec)))
    print(("DeckUI: saved layout %s (%d filled slots), copying %s, restore waiting for combat end %s"):format(
        layout and "yes" or "no", n, ready and "yes" or "no", pending and "yes" or "no"))
    print("DeckUI: last sync: " .. (lastResult or "none yet"))
end

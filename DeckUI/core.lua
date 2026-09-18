DeckUI = {}
local D = DeckUI

-------------------------------------------------------------------
-- Shared constants
-------------------------------------------------------------------
-- STANDARD_TEXT_FONT is the client's own UI font, so Cyrillic, Chinese
-- and Korean clients get a font that actually has their glyphs.
D.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
D.MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
D.DISC = "Interface\\Minimap\\UI-Minimap-Background"

D.MODULE_ADDONS = {
    Orbs  = "DeckUI_Orbs",
    Cross = "DeckUI_Cross",
    Spec  = "DeckUI_Spec",
}
D.MODULE_ORDER = { "Orbs", "Cross", "Spec" }

D.modules = {}   -- key -> { title = ..., build = function(content) end }

-------------------------------------------------------------------
-- Module registration (called by the modules when they load)
-------------------------------------------------------------------
function D.RegisterModule(key, def)
    D.modules[key] = def
    if D.panel then D.panel:AddTab(key, def) end
end

-------------------------------------------------------------------
-- Device detection (Steam Deck vs PC)
-- Lua cannot ask the OS, so we use two clues: the Deck's 1280x800
-- screen and an active gamepad. DeckUIDB.device = "auto"|"deck"|"pc"
-- lets the user override the result.
-------------------------------------------------------------------
D.DEVICE_ORDER = { "auto", "deck", "pc" }
D.DEVICE_NAMES = { auto = "Auto", deck = "Steam Deck", pc = "PC" }

local function HasGamepad()
    if not (C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()) then return false end
    local ok, ids = pcall(C_GamePad.GetAllDeviceIDs)
    return ok and type(ids) == "table" and #ids > 0
end

function D.DetectDevice()
    local w, h = GetPhysicalScreenSize()
    w, h = math.floor(w + 0.5), math.floor(h + 0.5)
    if w == 1280 and h == 800 then return "deck", "screen 1280x800" end
    if HasGamepad() then return "deck", "gamepad active" end
    return "pc", "no gamepad, screen " .. w .. "x" .. h
end

-- effective device after override
function D.GetDevice()
    local o = DeckUIDB and DeckUIDB.device or "auto"
    if o == "deck" or o == "pc" then return o, "manual" end
    return D.DetectDevice()
end

function D.IsDeck()
    return D.GetDevice() == "deck"
end

-- set the override directly: /deck deck|pc|auto, handy for testing the
-- Deck behaviour while sitting at the PC
function D.SetDevice(key)
    if not D.DEVICE_NAMES[key] then return end
    DeckUIDB.device = key
    D.PrintDevice()
    print("DeckUI: changes to the loaded modules take effect after /reload.")
    -- the Device button caption would go stale while the panel is open
    if D.panel and D.panel:IsShown() then
        local c = D.panel.contents[D.panel.current]
        if c then D.RefreshWidgets(c) end
    end
end

function D.CycleDevice()
    local cur = DeckUIDB.device or "auto"
    for i, v in ipairs(D.DEVICE_ORDER) do
        if v == cur then
            D.SetDevice(D.DEVICE_ORDER[(i % #D.DEVICE_ORDER) + 1])
            return
        end
    end
    D.SetDevice("auto")   -- stored value was not one of ours
end

function D.DeviceText()
    local o = DeckUIDB.device or "auto"
    if o == "auto" then
        local d, why = D.DetectDevice()
        return "Device: Auto (" .. D.DEVICE_NAMES[d] .. ", " .. why .. ")"
    end
    return "Device: " .. D.DEVICE_NAMES[o] .. " (manual)"
end

function D.PrintDevice()
    print("DeckUI: " .. D.DeviceText())
end

-- /deck build - the numbers a release depends on. The interface number in
-- our .toc files decides two things at once: whether WoW calls the addon
-- out of date, and which game version the CurseForge upload is filed under,
-- because the release script derives the version name from it. Reading it
-- off the running client beats reading it off a website, and the comparison
-- is the whole point: a mismatch is the thing to catch before tagging.
function D.PrintBuild()
    local version, build, _, toc = GetBuildInfo()
    local ours = C_AddOns.GetAddOnMetadata("DeckUI", "Interface")
    print(("DeckUI: client %s (build %s), interface %s"):format(
        tostring(version), tostring(build), tostring(toc)))
    if not ours then
        print("DeckUI: cannot read our own ## Interface")
        return
    end
    if tostring(ours) == tostring(toc) then
        print(("DeckUI: our .toc says %s - matches, nothing to do"):format(tostring(ours)))
    else
        print(("DeckUI: our .toc says %s - MISMATCH, the .toc files want %s"):format(
            tostring(ours), tostring(toc)))
        print("DeckUI: fix before releasing with  bump-version.ps1 <version> -Interface " .. tostring(toc))
    end
end

-- Per-device settings: positions and sizes differ between the Deck's
-- 1280x800 and a PC monitor, so modules keep them in db.perDevice[<device>].
-- D.DeviceDB(db) returns that table for the current device.
function D.DeviceKey()
    return D.IsDeck() and "deck" or "pc"
end

function D.DeviceDB(db)
    db.perDevice = db.perDevice or {}
    local key = D.DeviceKey()
    db.perDevice[key] = db.perDevice[key] or {}
    return db.perDevice[key]
end

-- one-time migration of old flat fields into the per-device table of
-- BOTH devices (so nothing looks different on either until changed)
function D.MigrateToDevice(db, fields)
    db.perDevice = db.perDevice or {}
    for _, dev in ipairs({ "deck", "pc" }) do
        db.perDevice[dev] = db.perDevice[dev] or {}
    end
    for _, f in ipairs(fields) do
        if db[f] ~= nil then
            for _, dev in ipairs({ "deck", "pc" }) do
                if db.perDevice[dev][f] == nil then db.perDevice[dev][f] = db[f] end
            end
            db[f] = nil
        end
    end
end

-- may this module be loaded on the current device?
function D.ModuleAllowed(key)
    if key == "Cross" and DeckUIDB.crossDeckOnly and not D.IsDeck() then
        return false, "Cross hotbar is set to Steam Deck only"
    end
    return true
end

-------------------------------------------------------------------
-- Load / enable a module
-------------------------------------------------------------------
local function LoadModule(key)
    local addon = D.MODULE_ADDONS[key]
    if C_AddOns.IsAddOnLoaded(addon) then return true end
    C_AddOns.EnableAddOn(addon)
    local loaded, reason = C_AddOns.LoadAddOn(addon)
    if not loaded then
        print("DeckUI: module " .. key .. " could not be loaded (" .. tostring(reason) .. ")")
    end
    return loaded
end

function D.SetModuleEnabled(key, state)
    DeckUIDB.modules[key] = state
    if state then
        local allowed, why = D.ModuleAllowed(key)
        if not allowed then
            print("DeckUI: module " .. key .. " stays off on this device (" .. why .. ").")
        elseif InCombatLockdown() then
            print("DeckUI: module " .. key .. " will be loaded after combat (/reload).")
        else
            LoadModule(key)
        end
    else
        if C_AddOns.IsAddOnLoaded(D.MODULE_ADDONS[key]) then
            print("DeckUI: module " .. key .. " will be disabled on the next /reload.")
        end
    end
end

-------------------------------------------------------------------
-- Movable frames (shared by all modules)
-------------------------------------------------------------------
D.movables = {}
D.unlocked = false

-- positions live in the per-device table: db.perDevice[<device>].positions
local function Positions(entry)
    local d = D.DeviceDB(entry.db)
    -- migrate old device-independent positions once, to both devices
    if entry.db.positions then
        for _, dev in ipairs({ "deck", "pc" }) do
            entry.db.perDevice[dev] = entry.db.perDevice[dev] or {}
            entry.db.perDevice[dev].positions = entry.db.perDevice[dev].positions or {}
            for k, v in pairs(entry.db.positions) do
                if entry.db.perDevice[dev].positions[k] == nil then
                    entry.db.perDevice[dev].positions[k] = v
                end
            end
        end
        entry.db.positions = nil
    end
    d.positions = d.positions or {}
    return d.positions
end

local function ApplyPosition(entry)
    local pos = Positions(entry)[entry.key]
    if pos then
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    end
end

local function SavePosition(entry)
    local point, _, relPoint, x, y = entry.frame:GetPoint()
    Positions(entry)[entry.key] = { point = point, relPoint = relPoint, x = x, y = y }
end

-- frame: the frame, key: name used for saving/label, db: the module's SavedVariables table
function D.MakeMovable(frame, key, db)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameStrata("HIGH")
    overlay:EnableMouse(true)
    overlay:RegisterForDrag("LeftButton")
    overlay:Hide()

    local bg = overlay:CreateTexture(nil, "OVERLAY")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0.8, 0, 0.35)

    local label = overlay:CreateFontString(nil, "OVERLAY")
    label:SetFont(D.FONT, 16, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetText(key)

    local entry = { frame = frame, key = key, db = db, overlay = overlay }

    overlay:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        frame:StartMoving()
    end)
    overlay:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition(entry)
    end)

    table.insert(D.movables, entry)
    ApplyPosition(entry)
    overlay:SetShown(D.unlocked)
end

function D.SetUnlocked(state)
    if state and InCombatLockdown() then
        print("DeckUI: not possible in combat.")
        return
    end
    D.unlocked = state
    for _, entry in ipairs(D.movables) do
        entry.overlay:SetShown(state)
    end
    print("DeckUI: frames " .. (state and "unlocked" or "locked"))
end

function D.ResetPositions()
    if InCombatLockdown() then return end
    for _, entry in ipairs(D.movables) do
        Positions(entry)[entry.key] = nil
        if entry.frame.defaultPoint then
            entry.frame:ClearAllPoints()
            entry.frame:SetPoint(unpack(entry.frame.defaultPoint))
        end
    end
    print("DeckUI: positions reset for this device (" .. D.DEVICE_NAMES[D.DeviceKey()] .. ").")
end

-------------------------------------------------------------------
-- Startup: load settings, load enabled modules
-------------------------------------------------------------------
local DEFAULTS = {
    modules       = { Orbs = true, Cross = true, Spec = true },
    showMinimap   = true,
    minimapAngle  = 220,
    device        = "auto",
    crossDeckOnly = false,   -- Cross runs on both: controller on the Deck, keyboard on the PC
    applyUiScale  = false,
    uiScaleDeck   = 0.8,
    uiScalePC     = 0.71,
}

-- Blizzard's whole-UI scale, set per device at login when enabled
function D.ApplyUiScale()
    if not DeckUIDB.applyUiScale or InCombatLockdown() then return end
    local value = D.IsDeck() and DeckUIDB.uiScaleDeck or DeckUIDB.uiScalePC
    value = math.max(0.5, math.min(1.0, value or 1))
    SetCVar("useUiScale", "1")
    SetCVar("uiScale", tostring(value))
    UIParent:SetScale(value)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, name)
    if name ~= "DeckUI" then return end
    self:UnregisterEvent("ADDON_LOADED")

    DeckUIDB = DeckUIDB or {}
    for k, v in pairs(DEFAULTS) do
        if DeckUIDB[k] == nil then DeckUIDB[k] = v end
    end
    for _, key in ipairs(D.MODULE_ORDER) do
        if DeckUIDB.modules[key] == nil then DeckUIDB.modules[key] = true end
    end
    -- one-time migration: Cross used to be Deck-only by default
    if not DeckUIDB.migratedCrossPC then
        DeckUIDB.migratedCrossPC = true
        DeckUIDB.crossDeckOnly = false
    end

    for _, key in ipairs(D.MODULE_ORDER) do
        if DeckUIDB.modules[key] and D.ModuleAllowed(key) then LoadModule(key) end
    end
end)

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
    D.ApplyUiScale()
end)

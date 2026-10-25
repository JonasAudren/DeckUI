local ADDON, ns = ...

-------------------------------------------------------------------
-- DeckUI_Probe: what does this client know of the names DeckUI uses?
-------------------------------------------------------------------
-- Prepared for porting DeckUI to Mists of Pandaria Classic (2026-10-25).
-- It changes nothing in the game: it only asks. Results land in the
-- SavedVariables DeckUIProbeDB when the game saves them (/reload or
-- logging out). Run with /deckprobe, or it runs by itself 5 s after login.
-------------------------------------------------------------------
local function Lookup(path)
    local t = _G
    for part in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        local ok, v = pcall(function() return t[part] end)
        if not ok then return nil end
        t = v
    end
    return t
end

local function Kind(v)
    local tv = type(v)
    if tv == "table" and v.GetObjectType then
        local ok, ot = pcall(v.GetObjectType, v)
        return ok and ("frame:" .. tostring(ot)) or "frame"
    end
    return tv
end

local function Run()
    local db = { meta = {}, api = {}, globals = {}, events = {}, enums = {}, cvars = {}, atlases = {},
                 templates = {}, methods = {}, bindings = {}, cnamespaces = {}, values = {} }
    local version, build, date, toc = GetBuildInfo()
    db.meta = { version = version, build = build, date = date, interface = toc,
                project = WOW_PROJECT_ID, mists = WOW_PROJECT_MISTS_CLASSIC, time = time(),
                class = select(2, UnitClass("player")), level = UnitLevel("player"),
                locale = GetLocale(), realm = GetRealmName() }

    db.errors = {}
    -- each part on its own, so one failure cannot lose the rest
    local function part(name, fn)
        local ok, err = pcall(fn)
        if not ok then db.errors[name] = tostring(err) end
    end
    part("api", function() for _, n in ipairs(ns.API) do db.api[n] = Kind(Lookup(n)) end end)
    part("globals", function() for _, n in ipairs(ns.GLOBALS) do db.globals[n] = Kind(Lookup(n)) end end)
    part("rest", function()

    local f = CreateFrame("Frame")
    for _, e in ipairs(ns.EVENTS) do
        local ok = pcall(f.RegisterEvent, f, e)
        db.events[e] = ok and "ok" or "unknown"
        if ok then f:UnregisterEvent(e) end
    end
    for _, n in ipairs(ns.ENUMS) do
        local v = Lookup("Enum." .. n)
        db.enums[n] = v == nil and "nil" or tostring(v)
    end
    for _, n in ipairs(ns.CVARS) do
        local info = C_CVar and C_CVar.GetCVarInfo and C_CVar.GetCVarInfo(n)
        db.cvars[n] = info ~= nil and tostring(C_CVar.GetCVar(n)) or "nil"
    end
    for _, n in ipairs(ns.ATLASES) do
        db.atlases[n] = (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(n)) and "ok" or "nil"
    end
    for _, n in ipairs(ns.TEMPLATES) do
        local info = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo(n)
        db.templates[n] = info and tostring(info.type or "ok") or "nil"
    end

    -- methods: present on any of the widget kinds DeckUI makes
    local probes = {
        Frame = CreateFrame("Frame"), Button = CreateFrame("Button"), CheckButton = CreateFrame("CheckButton"),
        StatusBar = CreateFrame("StatusBar"), Cooldown = CreateFrame("Cooldown"), EditBox = CreateFrame("EditBox"),
        ScrollFrame = CreateFrame("ScrollFrame"), GameTooltip = GameTooltip,
    }
    probes.Texture = probes.Frame:CreateTexture()
    probes.FontString = probes.Frame:CreateFontString()
    probes.MaskTexture = probes.Frame:CreateMaskTexture()
    probes.AnimationGroup = probes.Frame:CreateAnimationGroup()
    probes.Animation = probes.AnimationGroup:CreateAnimation("Translation")
    for _, m in ipairs(ns.METHODS) do
        local where = {}
        for kind, obj in pairs(probes) do
            if obj and type(obj[m]) == "function" then where[#where + 1] = kind end
        end
        table.sort(where)
        db.methods[m] = #where > 0 and table.concat(where, ",") or "nil"
    end
    probes.EditBox:Hide()

    -- binding commands the client knows
    part("bindings", function()
    local known = {}
    for i = 1, GetNumBindings() do
        local cmd = GetBinding(i)
        if cmd then known[cmd] = true end
    end
    for _, c in ipairs(ns.BINDINGS) do db.bindings[c] = known[c] and "ok" or "nil" end
    end)

    -- every C_ namespace and its functions: the real API of this client
    for k, v in pairs(_G) do
        if type(k) == "string" and k:match("^C_") and type(v) == "table" then
            local fns = {}
            for fk, fv in pairs(v) do
                if type(fv) == "function" then fns[#fns + 1] = fk end
            end
            table.sort(fns)
            db.cnamespaces[k] = table.concat(fns, " ")
        end
    end

    -- values that decide how the port has to work
    local function try(name, fn)
        local ok, a, b, c, d2 = pcall(fn)
        db.values[name] = ok and table.concat({ tostring(a), tostring(b), tostring(c), tostring(d2) }, " | ") or ("error: " .. tostring(a))
    end
    try("ActionBarPages", function() return GetOverrideBarIndex(), GetVehicleBarIndex(), GetTempShapeshiftBarIndex(), GetBonusBarIndex() end)
    try("NUM_ACTIONBAR_PAGES", function() return NUM_ACTIONBAR_PAGES, NUM_ACTIONBAR_BUTTONS end)
    try("Spec", function() return GetSpecialization and GetSpecialization(), GetNumSpecGroups and GetNumSpecGroups(), GetActiveSpecGroup and GetActiveSpecGroup() end)
    try("SpecInfo", function() return GetSpecializationInfo(GetSpecialization() or 1) end)
    try("PowerType", function() return UnitPowerType("player") end)
    try("ShapeshiftForms", function() return GetNumShapeshiftForms(), GetShapeshiftForm() end)
    try("Facing+Pos", function() return GetPlayerFacing and GetPlayerFacing(), UnitPosition and UnitPosition("player") end)
    try("Map", function() local m = C_Map.GetBestMapForUnit("player"); local p = m and C_Map.GetPlayerMapPosition(m, "player"); return m, p and p.x, p and p.y, C_Map.GetMapWorldSize and C_Map.GetMapWorldSize(m) end)
    try("Secret", function() return issecretvalue and issecretvalue(UnitHealth("player")), issecretvalue and UnitExists("target") and issecretvalue(UnitHealth("target")) end)
    try("Assisted", function() return C_AssistedCombat and C_AssistedCombat.IsAvailable and C_AssistedCombat.IsAvailable(), C_AssistedCombat and C_AssistedCombat.GetNextCastSpell and C_AssistedCombat.GetNextCastSpell() end)
    try("AuctionLegacy", function() return IsUsingLegacyAuctionClient and IsUsingLegacyAuctionClient(), C_AuctionHouse and C_AuctionHouse.ReplicateItems ~= nil end)
    try("Expansion", function() return GetExpansionLevel(), GetServerExpansionLevel and GetServerExpansionLevel(), GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() end)
    try("EditModeLayouts", function() local l = C_EditMode and C_EditMode.GetLayouts and C_EditMode.GetLayouts(); return l and #l.layouts, l and l.activeLayout end)
    try("Bank", function() return BANK_CONTAINER, NUM_BANKGENERIC_SLOTS, NUM_BANKBAGSLOTS, GetNumBankSlots and GetNumBankSlots() end)
    try("Bags", function() return NUM_BAG_SLOTS, NUM_TOTAL_EQUIPPED_BAG_SLOTS, Enum.BagIndex and Enum.BagIndex.ReagentBag end)
    try("QuestLog", function() return GetNumQuestLogEntries and GetNumQuestLogEntries(), C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries() end)
    try("Weekly", function() return C_DateAndTime.GetSecondsUntilWeeklyReset(), GetNumSavedInstances and GetNumSavedInstances() end)
    try("GamePad", function() return C_GamePad.IsEnabled(), C_GamePad.GetActiveDeviceID() end)
    try("Micro", function() local t = {}; for _, b in ipairs({ MicroMenu and MicroMenu:GetChildren() }) do t[#t + 1] = b:GetName() or "?" end; return table.concat(t, ",") end)
    try("TooltipBar", function() return GameTooltipStatusBar and GameTooltipStatusBar:GetObjectType(), GameTooltip.StatusBar and "field" end)
    try("NamePlate", function() local p = C_NamePlate.GetNamePlateForUnit("target"); return p and (p.UnitFrame and "UnitFrame" or "noUnitFrame") end)

    end)
    DeckUIProbeDB = db
    local n = 0
    for _ in pairs(db.cnamespaces) do n = n + 1 end
    print(("DeckUI Probe: done - %s (interface %s), %d C_ namespaces. /reload or log out to save, then tell Claude."):format(version, tostring(toc), n))
end

SLASH_DECKPROBE1 = "/deckprobe"
SlashCmdList.DECKPROBE = Run

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() C_Timer.After(5, Run) end)

"""Dry-run DeckUI_Probe in a mocked WoW environment (lupa), to catch Lua errors before the
owner runs it. Some API pieces are deliberately missing, as they may be in MoP."""
import os, sys
from lupa import LuaRuntime
SCR = sys.argv[1]
probe = os.path.join(SCR, "DeckUI_Probe")
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
local known_events = { PLAYER_LOGIN = true, UNIT_AURA = true, QUEST_LOG_UPDATE = true }
local function widget(kind)
  local w = { kind = kind }
  local mt = {}
  mt.__index = {
    GetObjectType = function(self) return self.kind end,
    RegisterEvent = function(self, e) if not known_events[e] then error("Attempt to register unknown event \"" .. e .. "\"") end end,
    UnregisterEvent = function() end,
    SetScript = function() end, Hide = function() end, Show = function() end,
    CreateTexture = function() return widget("Texture") end,
    CreateFontString = function() return widget("FontString") end,
    CreateMaskTexture = function() return widget("MaskTexture") end,
    CreateAnimationGroup = function() return widget("AnimationGroup") end,
    CreateAnimation = function() return widget("Animation") end,
    SetAlpha = function() end, SetPoint = function() end, GetChildren = function() return widget("Button") end,
    GetName = function() return "CharacterMicroButton" end,
  }
  return setmetatable(w, mt)
end
CreateFrame = function(kind) return widget(kind) end
GameTooltip = widget("GameTooltip")
MicroMenu = widget("Frame")
GetBuildInfo = function() return "5.5.4", "70579", "Oct 21 2026", 50504 end
WOW_PROJECT_ID, WOW_PROJECT_MISTS_CLASSIC = 19, 19
UnitClass = function() return "Druid", "DRUID" end
UnitLevel = function() return 90 end
GetLocale = function() return "deDE" end
GetRealmName = function() return "Test" end
C_CVar = { GetCVarInfo = function(n) if n == "GamePadEnable" then return "1" end end, GetCVar = function() return "1" end }
C_Texture = { GetAtlasInfo = function(n) return nil end }
C_XMLUtil = { GetTemplateInfo = function(n) if n == "SecureActionButtonTemplate" then return { type = "Button" } end end }
GetNumBindings = function() return 2 end
GetBinding = function(i) return ({ "ACTIONBUTTON1", "JUMP" })[i] end
C_Map = { GetBestMapForUnit = function() return 390 end, GetPlayerMapPosition = function() return { x = 0.5, y = 0.5 } end }
C_ActionBar = { GetBonusBarIndex = function() return 7 end }
GetOverrideBarIndex = function() return 18 end
GetVehicleBarIndex = function() return 16 end
GetTempShapeshiftBarIndex = function() return 17 end
GetBonusBarIndex = function() return 7 end
UnitHealth = function() return 100 end
UnitExists = function() return false end
C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return 1000 end }
C_GamePad = { IsEnabled = function() return true end, GetActiveDeviceID = function() return 1 end }
C_NamePlate = { GetNamePlateForUnit = function() return nil end }
C_Timer = { After = function(t, f) end }
SlashCmdList = {}
time = os.time
GetExpansionLevel = function() return 4 end
''')
ns = lua.eval("{}")
for f in ("names.lua", "probe.lua"):
    src = open(os.path.join(probe, f), encoding="utf-8").read()
    fn = lua.execute("return function(src, ns) local chunk = assert(load(src)); return chunk('DeckUI_Probe', ns) end")
    fn(src, ns)
lua.execute("SlashCmdList.DECKPROBE()")
db = lua.eval("DeckUIProbeDB")
def count(t):
    return sum(1 for _ in t.items()) if t is not None else 0
print("meta interface:", db.meta.interface, "errors:", dict(db.errors.items()) if db.errors else {})
for k in ("api", "globals", "events", "enums", "cvars", "atlases", "templates", "methods", "bindings", "values", "cnamespaces"):
    print(f"  {k:12} {count(db[k])}")
print("  events sample:", list(db.events.items())[:3])
print("  values:", dict(db["values"].items()))

# write the result the way WoW writes SavedVariables, for testing readprobe.py
def ser(v, depth):
    if lua.eval("type")(v) == "table":
        inner = "".join("\t" * (depth + 1) + '["%s"] = %s,\n' % (k, ser(x, depth + 1)) for k, x in sorted(v.items(), key=lambda kv: str(kv[0])))
        return "{\n" + inner + "\t" * depth + "}"
    if isinstance(v, (int, float)) and not isinstance(v, bool):
        return str(v)
    if isinstance(v, bool):
        return "true" if v else "false"
    return '"%s"' % str(v).replace('"', '\\"')
out = os.path.join(SCR, "fakewtf", "Account", "TEST", "SavedVariables")
os.makedirs(out, exist_ok=True)
open(os.path.join(out, "DeckUI_Probe.lua"), "w", encoding="utf-8").write("\nDeckUIProbeDB = " + ser(db, 0) + "\n")
print("fake SavedVariables written")

local ADDON, ns = ...
local D = DeckUI

local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
local min = function(v) return math.floor(v / 60 + 0.5) .. " min" end
local db  = function() return DeckOrbsDB end

D.RegisterModule("Orbs", {
    title = "Orbs",
    build = function(c)
        D.Slider(c, "Size (this device)", -6, 0.6, 1.6, 0.05, pct, ns.DeviceDB, "scale", ns.SetScale)
        D.Slider(c, "Opacity",     -70,  0.3, 1.0, 0.05, pct, db, "alpha", ns.SetAlpha)
        D.Slider(c, "Brightness",  -134, 0.0, 0.5, 0.05, pct, db, "glow",  ns.SetGlow)
        D.Slider(c, "Buffs up to duration (needs /reload)", -198, 60, 900, 60, min,
            db, "buffMaxDuration", function(v)
                ns.SetBuffMaxDuration(v)
                print("DeckUI Orbs: buff duration saved - takes effect after /reload.")
            end)

        local hpBtn = D.Button(c, "Health text", -262, function() end)
        local function HpLabel() return "Health text: " .. ns.HP_TEXT_NAMES[DeckOrbsDB.hpText or "percent"] end
        hpBtn:SetScript("OnClick", function(b) ns.CycleHpText(); b:SetText(HpLabel()) end)
        function hpBtn:Refresh() self:SetText(HpLabel()) end
        c.widgets = c.widgets or {}
        table.insert(c.widgets, hpBtn)

        D.Checkbox(c, "Show cast in orb",       -306, db, "showCast",       ns.SetCastShown)
        D.Checkbox(c, "Show buffs and debuffs", -334, db, "showAuras",      ns.SetAurasShown)
        D.Checkbox(c, "Only own debuffs on target", -362, db, "ownDebuffsOnly", ns.SetOwnDebuffsOnly)
        D.Checkbox(c, "Show focus frame",       -390, db, "showFocus",      ns.SetFocusShown)
        D.Checkbox(c, "Show boss frames (hides Blizzard's)", -418, db, "showBoss", ns.SetBossShown)
        D.Checkbox(c, "Class resource dots on player orb", -446, db, "showClassPower", ns.SetClassPowerShown)
        D.Checkbox(c, "Announce target (big name)",   -474, db, "announceTarget", ns.SetAnnounceTarget)
    end,
})

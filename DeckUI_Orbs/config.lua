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

        -- two buttons in one row: health text on the left, the style of
        -- player and target (orbs or Final Fantasy's bars) on the right
        local STYLE_NAMES = { orbs = "Orbs", ff = "Final Fantasy" }
        hpBtn:SetWidth(148)
        hpBtn:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
        hpBtn:ClearAllPoints()
        hpBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -262)
        local styleBtn = D.Button(c, "Style", -262, function() end)
        styleBtn:SetWidth(148)
        styleBtn:GetFontString():SetFont(D.FONT, 12, "OUTLINE")
        styleBtn:ClearAllPoints()
        styleBtn:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -262)
        local function StyleLabel() return "Style: " .. STYLE_NAMES[DeckOrbsDB.style or "orbs"] end
        styleBtn:SetScript("OnClick", function(b)
            DeckOrbsDB.style = (DeckOrbsDB.style == "ff") and "orbs" or "ff"
            b:SetText(StyleLabel())
            print("DeckUI Orbs: player and target as " .. STYLE_NAMES[DeckOrbsDB.style] .. " after /reload.")
        end)
        function styleBtn:Refresh() self:SetText(StyleLabel()) end
        table.insert(c.widgets, styleBtn)

        D.Checkbox(c, "Show cast in orb",       -306, db, "showCast",       ns.SetCastShown)
        D.Checkbox(c, "Show buffs and debuffs", -334, db, "showAuras",      ns.SetAurasShown)
        D.Checkbox(c, "Only own debuffs on target", -362, db, "ownDebuffsOnly", ns.SetOwnDebuffsOnly)
        D.Checkbox(c, "Show focus frame",       -390, db, "showFocus",      ns.SetFocusShown)
        D.Checkbox(c, "Show boss frames (hides Blizzard's)", -418, db, "showBoss", ns.SetBossShown)
        D.Checkbox(c, "Class resource dots on player orb", -446, db, "showClassPower", ns.SetClassPowerShown)
        D.Checkbox(c, "Announce target (big name)",   -474, db, "announceTarget", ns.SetAnnounceTarget)

        D.Label(c, "Party list (Final Fantasy style)", -506, 15)
        -- test mode beside the heading: five rows of yourself, session only
        local testBtn = D.Button(c, "Test", -502, function()
            ns.SetPartyTest(not ns.partyTest)
        end)
        testBtn:SetWidth(70)
        testBtn:ClearAllPoints()
        testBtn:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -502)
        D.Checkbox(c, "Show the party list (hides Blizzard's; /reload)", -528, db, "showParty", function(v)
            print("DeckUI Orbs: the party list " .. (v and "appears" or "goes") .. " after /reload.")
        end)
        D.Checkbox(c, "Side by side instead of stacked (this device)", -556, ns.DeviceDB, "partyAcross", function()
            ns.ApplyPartyLayout()
        end)
        D.Slider(c, "Party list size (this device)", -584, 0.6, 1.6, 0.05, pct, ns.DeviceDB, "partyScale", function(v)
            ns.DeviceDB().partyScale = v
            ns.ApplyPartyScale()
        end)
    end,
})

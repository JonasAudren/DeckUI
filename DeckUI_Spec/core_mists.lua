local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Spec bar for Mists of Pandaria Classic (MISTS_PLAN.md, phase 4)
-------------------------------------------------------------------
-- Only in DeckUI_Spec_Mists.toc; retail's core.lua switches between
-- specializations, which Mists does not do: a character there has up to
-- two talent groups (dual spec, from level 30 and the trainer), each with
-- its own specialization. So one round button per group, showing that
-- group's spec; a click activates the group - Blizzard's own talent frame
-- does exactly that with C_SpecializationInfo.SetActiveSpecGroup from
-- plain Lua (Blizzard_TalentUI_Shared.lua, 5.5.4), a cast of a few seconds,
-- not in combat. The spec inside a group is chosen in the talent frame.
-- Mists has only the C_SpecializationInfo forms of these functions (probe,
-- 2026-10-25); GetNumSpecGroups is global.
-------------------------------------------------------------------
local SIZE, GAP = 36, 6
local UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark"

local bar = CreateFrame("Frame", "DeckSpecBar", UIParent)
bar:SetSize(SIZE, SIZE)
bar.defaultPoint = { "CENTER", UIParent, "CENTER", 0, -200 }
bar:SetPoint(unpack(bar.defaultPoint))
ns.bar = bar

ns.buttons = {}

-- the spec of a talent group: name, icon (nil when none is chosen yet)
local function GroupSpec(group)
    local index = C_SpecializationInfo.GetSpecialization(false, false, group)
    if not index or index == 0 then return end
    local _, name, _, icon = C_SpecializationInfo.GetSpecializationInfo(index, false, false, nil, nil, group)
    return name, icon
end

local function MakeButton(group)
    local b = CreateFrame("Button", "DeckSpecButton" .. group, bar)
    b:SetSize(SIZE, SIZE)
    b:SetPoint("LEFT", (group - 1) * (SIZE + GAP), 0)

    local mask = D.RoundMask(b)

    local ring = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    ring:SetSize(SIZE + 6, SIZE + 6)
    ring:SetPoint("CENTER")
    ring:SetTexture(D.DISC)
    ring:SetVertexColor(0.25, 0.25, 0.25, 1)
    b.ring = ring

    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    tex:AddMaskTexture(mask)
    b.icon = tex

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\WHITE8x8")
    hl:SetVertexColor(1, 1, 1, 0.2)
    hl:SetBlendMode("ADD")
    hl:AddMaskTexture(mask)

    b.group = group

    b:SetScript("OnClick", function(self)
        if InCombatLockdown() then
            print("DeckUI Spec: not possible in combat.")
            return
        end
        if C_SpecializationInfo.GetActiveSpecGroup(false, false) ~= self.group then
            C_SpecializationInfo.SetActiveSpecGroup(self.group)
        end
    end)
    b:SetScript("OnEnter", function(self)
        local name = GroupSpec(self.group)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.group == 1 and "Primary talents" or "Secondary talents")
        GameTooltip:AddLine(name or "No specialization chosen yet - the talent frame (N) sets it.", 1, 1, 1, true)
        if C_SpecializationInfo.GetActiveSpecGroup(false, false) ~= self.group then
            GameTooltip:AddLine("Click to switch (a short cast, not in combat).", 0.6, 0.6, 0.6, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

function ns.UpdateActive()
    local active = C_SpecializationInfo.GetActiveSpecGroup(false, false)
    for group, b in ipairs(ns.buttons) do
        local _, icon = GroupSpec(group)
        b.icon:SetTexture(icon or UNKNOWN)
        local on = group == active
        b.ring:SetVertexColor(on and 0.9 or 0.25, on and 0.75 or 0.25, on and 0.2 or 0.25, 1)
        b.icon:SetDesaturated(not on)
    end
end

-- dual spec is learned at a trainer, mid-session: the second button
-- comes when the count changes
local function Build()
    local n = math.max(1, GetNumSpecGroups(false) or 1)
    bar:SetSize(n * SIZE + (n - 1) * GAP, SIZE)
    for group = 1, n do
        if not ns.buttons[group] then ns.buttons[group] = MakeButton(group) end
        ns.buttons[group]:Show()
    end
    for group = n + 1, #ns.buttons do ns.buttons[group]:Hide() end
    ns.UpdateActive()
end

function ns.SetBarShown(state)
    DeckSpecDB.showBar = state
    bar:SetShown(state)
end

ns.HINT = "One round icon per talent group (dual spec), showing its specialization; click one to switch (not in combat). The active one has a gold ring. The specialization itself is chosen in the talent frame. /spec toggles the bar, /deck unlock moves it."

-------------------------------------------------------------------
-- Startup (normal login AND load on demand via the menu)
-------------------------------------------------------------------
local ready = false

local function Init()
    DeckSpecDB = DeckSpecDB or {}
    if DeckSpecDB.showBar == nil then DeckSpecDB.showBar = true end
    Build()
    D.MakeMovable(bar, "Spec bar", DeckSpecDB)
    bar:SetShown(DeckSpecDB.showBar)
    ready = true
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
ev:RegisterEvent("PLAYER_TALENT_UPDATE")
ev:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        Init()
    elseif not ready then
        return
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
        return
    else
        Build()
    end
end)

if IsLoggedIn() then
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

SLASH_DECKSPEC1 = "/spec"
SLASH_DECKSPEC2 = "/qs"
SlashCmdList.DECKSPEC = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "config" then
        D.ToggleConfig("Spec")
    else
        ns.SetBarShown(not bar:IsShown())
    end
end

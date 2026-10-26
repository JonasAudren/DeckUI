local D = DeckUI

-------------------------------------------------------------------
-- The main menu as FFXIV's round buttons
-------------------------------------------------------------------
-- The owner's wish (2026-10-09, his FFXIV screenshot, "Hauptmenü"): the
-- micro menu at the bottom right as a row of round buttons - a dark disc,
-- a gold ring, the icon inside. DeckUIDB.mainMenu, off by default, undone
-- by unticking; movable "Main menu".
--
-- Our buttons are secure action buttons of type "click" on Blizzard's own
-- micro buttons (the way the bag overview opens the bags): what a click
-- opens - talents, the group finder, the game menu - runs from Blizzard's
-- code, never from ours. The icons are Blizzard's micro menu atlases
-- ("UI-HUD-MicroMenu-<name>-Up", the name the button keeps in textureName),
-- the character button shows the player's portrait as Blizzard's does.
--
-- Blizzard's MicroMenu is faded, not parked: Blizzard moves it into the
-- vehicle bar and to full-screen frames and back (MicroMenuBar_SetFull-
-- ScreenFrame), so a parent of ours would not hold. Alpha 0 held by a
-- SetAlpha post-hook and the mouse off down its tree - the way the Cross
-- module fades the override bar. Nothing is written onto Blizzard's frames.
-------------------------------------------------------------------
local SIZE, GAP = 24, 1   -- tighter and smaller after the first look (owner, 2026-10-09)
local BUTTONS = {
    "CharacterMicroButton", "ProfessionMicroButton", "PlayerSpellsMicroButton",
    "AchievementMicroButton", "QuestLogMicroButton", "HousingMicroButton",
    "GuildMicroButton", "LFDMicroButton", "CollectionsMicroButton",
    "EJMicroButton", "StoreMicroButton", "MainMenuMicroButton",
}
-- Mists' row, in the order of its own micro menu (Blizzard_MicroMenu,
-- Classic/MainMenuBarMicroButtons.xml, 5.5.4)
if D.IsMists then
    BUTTONS = {
        "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton",
        "AchievementMicroButton", "QuestLogMicroButton", "SocialsMicroButton",
        "GuildMicroButton", "PVPMicroButton", "LFGMicroButton",
        "CollectionsMicroButton", "EJMicroButton", "StoreMicroButton",
        "MainMenuMicroButton", "HelpMicroButton",
    }
end
local GOLD = { 0.85, 0.68, 0.3 }
local ALERT = { 1, 0.9, 0.45 }

local bar = CreateFrame("Frame", "DeckMainMenu", UIParent)
bar:SetSize(SIZE, SIZE)
bar.defaultPoint = { "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -8, 76 }
bar:SetPoint(unpack(bar.defaultPoint))
bar:Hide()

local buttons = {}

local function Build(name)
    local blizzard = _G[name]
    local b = CreateFrame("Button", nil, bar, "SecureActionButtonTemplate")
    b:SetSize(SIZE, SIZE)
    -- down and up: the template acts on the one ActionButtonUseKeyDown names
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type", "click")
    b:SetAttribute("clickbutton", blizzard)
    b.blizzard = blizzard

    local mask = D.RoundMask(b)
    local ring = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    ring:SetSize(SIZE + 4, SIZE + 4)
    ring:SetPoint("CENTER")
    ring:SetTexture(D.DISC)
    ring:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    local disc = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    disc:SetAllPoints()
    disc:SetTexture(D.DISC)
    disc:SetVertexColor(0.06, 0.05, 0.04)
    b.ring = ring

    -- the atlas is 32x40 with the icon in the middle: as tall as it needs,
    -- the round mask keeps the middle
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", 0, -1)
    icon:AddMaskTexture(mask)
    b.icon = icon

    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetTexture(D.DISC)
    hover:SetVertexColor(1, 1, 1, 0.15)
    hover:SetBlendMode("ADD")

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local tip = self.blizzard.tooltipText or self.blizzard.newbieText
        GameTooltip:SetText(tip or name, 1, 1, 1)
        if not self.blizzard:IsEnabled() and self.blizzard.disabledTooltip then
            GameTooltip:AddLine(self.blizzard.disabledTooltip, 1, 0.3, 0.3, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

-- icon, enabled state and Blizzard's alert flash, read off its button
local function Paint(b)
    local blizzard = b.blizzard
    local enabled = blizzard:IsEnabled()
    if blizzard == CharacterMicroButton then
        if not b.portrait then
            b.icon:SetSize(SIZE - 4, SIZE - 4)
            b.portrait = true
        end
        SetPortraitTexture(b.icon, "player")
    elseif blizzard.textureName then
        local atlas = "UI-HUD-MicroMenu-" .. blizzard.textureName .. (enabled and "-Up" or "-Disabled")
        if b.atlas ~= atlas then
            b.atlas = atlas
            b.icon:SetAtlas(atlas)
            b.icon:SetSize(SIZE + 4, (SIZE + 4) * 40 / 32)
        end
    else
        -- Mists: the old micro buttons, a 32x64 file each
        -- (Interface\Buttons\UI-MicroButton-<name>-Up) shown from 0.36 down;
        -- the icon is the middle of that, cut round by our mask
        local art = enabled and blizzard:GetNormalTexture() or blizzard:GetDisabledTexture()
        local file = art and art:GetTexture()
        if file and b.file ~= file then
            b.file = file
            b.icon:SetTexture(file)
            b.icon:SetTexCoord(0.1, 0.9, 0.47, 0.9)
            b.icon:SetSize(SIZE, SIZE)
        end
    end
    b.icon:SetDesaturated(not enabled)
    local flash = blizzard.FlashBorder and blizzard.FlashBorder:IsShown()
    local c = flash and ALERT or GOLD
    b.ring:SetVertexColor(c[1], c[2], c[3])
end

local function Layout()
    local x = 0
    for _, b in ipairs(buttons) do
        b:ClearAllPoints()
        if b.blizzard:IsShown() then
            b:SetPoint("LEFT", bar, "LEFT", x, 0)
            b:Show()
            x = x + SIZE + GAP
        else
            b:Hide()
        end
    end
    bar:SetWidth(math.max(SIZE, x - GAP))
end

-------------------------------------------------------------------
-- Blizzard's menu out of sight
-------------------------------------------------------------------
local faded, hooked = false, false

-- Off down the tree, and back to what each frame had: switching on every
-- child gave the game menu button's notification overlay (a plain frame
-- above the button, frame level 100) the mouse, and it swallowed hover and
-- clicks on the button (owner's /fstack, 2026-10-26). Kept in our table.
local mouseBefore = {}
local function NoMouse(frame, on)
    if frame.EnableMouse and frame.IsMouseEnabled then
        if not on then
            if mouseBefore[frame] == nil then mouseBefore[frame] = frame:IsMouseEnabled() end
            frame:EnableMouse(false)
        elseif mouseBefore[frame] ~= nil then
            frame:EnableMouse(mouseBefore[frame])
            mouseBefore[frame] = nil
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do NoMouse(child, on) end
end

local function SetBlizzardFaded(state)
    local menu = _G.MicroMenu
    if not menu then return end
    if not hooked then
        hooked = true
        hooksecurefunc(menu, "SetAlpha", function(self, alpha)
            if faded and alpha ~= 0 then self:SetAlpha(0) end
        end)
    end
    faded = state
    menu:SetAlpha(state and 0 or 1)
    NoMouse(menu, not state)
end

-------------------------------------------------------------------
-- Switching
-------------------------------------------------------------------
local pending = false
local ticker

function D.ApplyMainMenu()
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local on = DeckUIDB.mainMenu and true or false
    if on and #buttons == 0 then
        for _, name in ipairs(BUTTONS) do
            if _G[name] then buttons[#buttons + 1] = Build(name) end
        end
    end
    if on then
        for _, b in ipairs(buttons) do Paint(b) end
        Layout()
        bar:Show()
        -- state, alerts and buttons coming and going: read twice a second
        if not ticker then
            ticker = C_Timer.NewTicker(0.5, function()
                for _, b in ipairs(buttons) do Paint(b) end
                if not InCombatLockdown() then Layout() end
            end)
        end
    else
        bar:Hide()
        if ticker then ticker:Cancel(); ticker = nil end
    end
    -- only touch Blizzard's menu when this setting is what changed it
    if on or faded then SetBlizzardFaded(on) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        D.MakeMovable(bar, "Main menu", DeckUIDB)
        D.ApplyMainMenu()
    elseif pending then
        D.ApplyMainMenu()
    end
end)

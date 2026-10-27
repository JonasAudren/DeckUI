local D = DeckUI

-------------------------------------------------------------------
-- Loot rolls: Need / Greed / Pass in DeckUI's look
-------------------------------------------------------------------
-- Owner's wish 2026-10-27. Built from Blizzard's 12.1.5 GroupLootFrame.lua
-- (Mainline) and 5.5.4 LootFrame.lua (Classic), read the same day. Both
-- games still roll: START_LOOT_ROLL (rollID, time in ms) opens a roll,
-- CANCEL_LOOT_ROLL / CANCEL_ALL_LOOT_ROLLS end it, and a click is
-- RollOnLoot(rollID, type) - 0 pass, 1 need, 2 greed, 4 transmog (retail,
-- instead of greed when the item offers it). Blizzard's frames show no
-- disenchant roll in either game, so neither do we.
--
-- Blizzard's GroupLootFrame1-4 keep running untouched: the event reaches
-- them through UIParent (Mists) or the event router (retail), they open,
-- time out and close themselves. We only fade them (alpha 0 held by a
-- SetAlpha post-hook, mouse off down the tree) - hiding one would make
-- Blizzard's container hand the same frame to the next roll. Confirming a
-- bind-on-pickup roll stays Blizzard's dialog (CONFIRM_LOOT_ROLL, its own
-- handler). Our window lists every roll that is open, not just four.
--
-- The layout is FFXIV's loot window (owner's wish, the same day): a title
-- band, the items as a list, the one you picked marked like the enemy
-- list's target (warm band, gold frame, a pointer), and Need / Greed / Pass
-- once, along the bottom, for the picked item. The first item is picked by
-- itself, so a single roll is still one click.
-------------------------------------------------------------------
local W, TITLE, ROW, ICON, PAD, FOOT = 340, 24, 38, 30, 6, 30
local WHITE = "Interface\\Buttons\\WHITE8x8"
local NUM_BLIZZARD = 4
local GOLD = { 1, 0.82, 0.3 }

local function Plain(v) return not (issecretvalue and issecretvalue(v)) end

-- roll type -> label and art: retail's atlas when the client has it,
-- else the old file every client still carries
local KINDS = {
    [1] = { label = NEED or "Need",   atlas = "lootroll-toast-icon-need",     file = "Interface\\Buttons\\UI-GroupLoot-Dice" },
    [2] = { label = GREED or "Greed", atlas = "lootroll-toast-icon-greed",    file = "Interface\\Buttons\\UI-GroupLoot-Coin" },
    [4] = { label = TRANSMOGRIFICATION or "Transmog", atlas = "lootroll-toast-icon-transmog" },
    [0] = { label = PASS or "Pass",   atlas = "lootroll-toast-icon-pass",     file = "Interface\\Buttons\\UI-GroupLoot-Pass" },
}

local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local function SetKindArt(tex, kind)
    local k = KINDS[kind]
    if HasAtlas(k.atlas .. "-up") then
        tex:SetAtlas(k.atlas .. "-up")
    else
        tex:SetTexture(k.file and (k.file .. "-Up") or nil)
    end
end

local function Frame4(parent, r, g, b, a, layer)
    for _, p in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                         { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = parent:CreateTexture(nil, layer or "BORDER")
        t:SetColorTexture(r, g, b, a)
        t:SetPoint(p[1])
        t:SetPoint(p[2])
        if p[3] then t:SetHeight(1) else t:SetWidth(1) end
    end
end

local function TimeText(ms)
    local s = math.max(0, math.ceil(ms / 1000))
    return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

-------------------------------------------------------------------
-- The window
-------------------------------------------------------------------
local win = CreateFrame("Frame", "DeckUILootRolls", UIParent)
win:SetSize(W, 100)
win:SetFrameStrata("DIALOG")
win:EnableMouse(true)
win:SetClampedToScreen(true)
win.defaultPoint = { "TOP", UIParent, "TOP", 0, -220 }
win:SetPoint(unpack(win.defaultPoint))
win:Hide()

do  -- FFXIV's window: dark, a little lighter at the top, a soft light edge
    local bg = win:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetTexture(WHITE)
    if bg.SetGradient and CreateColor then
        bg:SetGradient("VERTICAL", CreateColor(0.04, 0.04, 0.05, 0.93), CreateColor(0.13, 0.12, 0.11, 0.93))
    else
        bg:SetColorTexture(0.07, 0.07, 0.07, 0.93)
    end
    Frame4(win, 0.55, 0.5, 0.42, 0.8)

    local title = win:CreateFontString(nil, "OVERLAY")
    title:SetFont(D.FONT, 13, "OUTLINE")
    title:SetPoint("TOPLEFT", 10, -6)
    title:SetText(LOOT or "Loot")
    title:SetTextColor(0.95, 0.92, 0.85)
    win.count = win:CreateFontString(nil, "OVERLAY")
    win.count:SetFont(D.FONT, 11, "OUTLINE")
    win.count:SetPoint("TOPRIGHT", -10, -7)
    win.count:SetTextColor(0.7, 0.68, 0.62)
    -- the gold line under the title, fading out to both sides
    local line = win:CreateTexture(nil, "ARTWORK")
    line:SetTexture(WHITE)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 6, -TITLE)
    line:SetPoint("TOPRIGHT", -6, -TITLE)
    line:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.6)
end

local rolls = {}       -- { id, time (ms) } in the order they came
local seen = { start = 0, cancel = 0 }   -- events heard, for /deck rolls
local rows = {}
local preview = false
local selected         -- the picked roll's ID
local Draw

local function IconOnEnter(self)
    local r = self:GetParent()
    if not r.rollID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetLootRollItem(r.rollID)
    GameTooltip:Show()
end

local function RowOnClick(self)
    if self.rollID and IsModifiedClick() then
        HandleModifiedItemClick(GetLootRollItemLink(self.rollID))
        return
    end
    if self.rollID then
        selected = self.rollID
        Draw()
    end
end

local function Row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, win)
    r:SetSize(W - 2 * PAD, ROW)
    r:SetPoint("TOPLEFT", PAD, -TITLE - 4 - (i - 1) * (ROW + 2))
    r:RegisterForClicks("LeftButtonUp")
    r:SetScript("OnClick", RowOnClick)

    r.band = r:CreateTexture(nil, "BACKGROUND")
    r.band:SetAllPoints()
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)

    -- the picked item, as the enemy list marks your target
    r.lit = CreateFrame("Frame", nil, r)
    r.lit:SetAllPoints()
    r.lit:SetFrameLevel(r:GetFrameLevel())
    local glow = r.lit:CreateTexture(nil, "BACKGROUND", nil, 1)
    glow:SetAllPoints()
    glow:SetColorTexture(1, 0.7, 0.25, 0.25)
    Frame4(r.lit, GOLD[1], GOLD[2], GOLD[3], 1)
    local pointer = r.lit:CreateFontString(nil, "OVERLAY")
    pointer:SetFont(D.FONT, 16, "OUTLINE")
    pointer:SetPoint("RIGHT", r.lit, "LEFT", 1, 0)
    pointer:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    pointer:SetText(">")

    r.iconButton = CreateFrame("Button", nil, r)
    r.iconButton:SetSize(ICON, ICON)
    r.iconButton:SetPoint("LEFT", 6, 0)
    r.iconButton:SetScript("OnEnter", IconOnEnter)
    r.iconButton:SetScript("OnLeave", GameTooltip_Hide)
    r.iconButton:SetScript("OnClick", function(self) RowOnClick(self:GetParent()) end)
    r.edge = r.iconButton:CreateTexture(nil, "BACKGROUND")
    r.edge:SetPoint("TOPLEFT", -1, 1)
    r.edge:SetPoint("BOTTOMRIGHT", 1, -1)
    r.icon = r.iconButton:CreateTexture(nil, "ARTWORK")
    r.icon:SetAllPoints()
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.count = r.iconButton:CreateFontString(nil, "OVERLAY")
    r.count:SetFont(D.FONT, 11, "OUTLINE")
    r.count:SetPoint("BOTTOMRIGHT", 1, -1)

    r.time = r:CreateFontString(nil, "OVERLAY")
    r.time:SetFont(D.FONT, 11, "OUTLINE")
    r.time:SetPoint("TOPRIGHT", -6, -5)
    r.time:SetTextColor(0.85, 0.82, 0.75)

    r.name = r:CreateFontString(nil, "OVERLAY")
    r.name:SetFont(D.FONT, 12, "OUTLINE")
    r.name:SetPoint("TOPLEFT", r.iconButton, "TOPRIGHT", 8, -2)
    r.name:SetPoint("RIGHT", r.time, "LEFT", -6, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)

    -- the time left: a thin bar under the name
    r.timer = CreateFrame("StatusBar", nil, r)
    r.timer:SetStatusBarTexture(WHITE)
    r.timer:SetHeight(3)
    r.timer:SetPoint("BOTTOMLEFT", r.iconButton, "BOTTOMRIGHT", 8, 3)
    r.timer:SetPoint("RIGHT", -6, 0)
    local track = r.timer:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0, 0, 0, 0.6)
    r.timer:SetScript("OnUpdate", function(bar)
        if not r.rollID then return end
        local left = GetLootRollTimeLeft(r.rollID)
        if left and Plain(left) then
            local _, max = bar:GetMinMaxValues()
            bar:SetValue(math.max(0, math.min(left, max)))
            local f = max > 0 and left / max or 0
            bar:SetStatusBarColor(f > 0.25 and 1 or 0.9, f > 0.25 and 0.82 or 0.3, 0.2)
            r.time:SetText(TimeText(left))
        end
    end)

    rows[i] = r
    return r
end

-------------------------------------------------------------------
-- Need / Greed (or Transmog) / Pass along the bottom
-------------------------------------------------------------------
local buttons = {}

local function ChoiceOnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(KINDS[self.kind].label)
    if not self:IsEnabled() and self.reason then
        GameTooltip:AddLine(self.reason, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true)
    end
    GameTooltip:Show()
end

local function ChoiceOnClick(self)
    if not selected then return end
    RollOnLoot(selected, self.kind)
    -- the roll is ours to end only once the game says so (CANCEL_LOOT_ROLL);
    -- a bind-on-pickup roll first asks through Blizzard's dialog
end

local BW = (W - 2 * PAD - 2 * 6) / 3
for i, kind in ipairs({ 1, 2, 0 }) do
    local b = CreateFrame("Button", nil, win)
    b:SetSize(BW, FOOT - 6)
    b:SetPoint("BOTTOMLEFT", PAD + (i - 1) * (BW + 6), PAD)
    local bg = D.FlatBox(b, 1, 0.45)
    bg:SetColorTexture(0.16, 0.15, 0.13, 1)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", -1, 1)
    hl:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.18)
    b.art = b:CreateTexture(nil, "ARTWORK")
    b.art:SetSize(18, 18)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(D.FONT, 12, "OUTLINE")
    b.text:SetPoint("CENTER", 10, 0)
    b.art:SetPoint("RIGHT", b.text, "LEFT", -4, 0)
    b:SetMotionScriptsWhileDisabled(true)
    b:SetScript("OnClick", ChoiceOnClick)
    b:SetScript("OnEnter", ChoiceOnEnter)
    b:SetScript("OnLeave", GameTooltip_Hide)
    buttons[i] = b
end

local function SetChoice(b, kind, on, reason)
    b.kind = kind
    SetKindArt(b.art, kind)
    b.text:SetText(KINDS[kind].label)
    b:SetEnabled(on)
    b.text:SetTextColor(on and 0.95 or 0.45, on and 0.92 or 0.45, on and 0.85 or 0.45)
    b.art:SetDesaturated(not on)
    b.art:SetAlpha(on and 1 or 0.4)
    b.reason = (not on and reason) and _G["LOOT_ROLL_INELIGIBLE_REASON" .. reason] or nil
end

-- the buttons follow the picked row; nil = nothing to roll on (preview)
local function SetChoices(info)
    if not info then
        SetChoice(buttons[1], 1, false)
        SetChoice(buttons[2], 2, false)
        SetChoice(buttons[3], 0, false)
        return
    end
    SetChoice(buttons[1], 1, info.canNeed, info.reasonNeed)
    if info.canTransmog then
        SetChoice(buttons[2], 4, true)
    else
        SetChoice(buttons[2], 2, info.canGreed, info.reasonGreed)
    end
    SetChoice(buttons[3], 0, true)
end

-------------------------------------------------------------------
-- Filling
-------------------------------------------------------------------
local function FillRow(r, roll, i)
    r.rollID = roll.id
    r.band:SetColorTexture(i % 2 == 1 and 0 or 1, i % 2 == 1 and 0 or 1, i % 2 == 1 and 0 or 1, i % 2 == 1 and 0.3 or 0.03)
    r.timer:SetMinMaxValues(0, roll.time or 60000)
    local texture, name, count, quality, _, canNeed, canGreed, _, reasonNeed, reasonGreed, _, _, canTransmog =
        GetLootRollItemInfo(roll.id)
    if not name then
        -- the item is not in the cache yet (a new dungeon's loot): the roll
        -- stays, shown as loading, and Draw asks again shortly
        r.icon:SetTexture(134400)
        r.count:SetText("")
        r.name:SetText("Loading item...")
        r.name:SetTextColor(0.6, 0.6, 0.6)
        r.edge:SetColorTexture(0.3, 0.3, 0.3, 1)
        r.info = { loading = true }
        r:Show()
        return true
    end
    r.icon:SetTexture(texture)
    r.count:SetText(count and Plain(count) and count > 1 and count or "")
    r.name:SetText(name)
    local color = quality and Plain(quality) and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        r.name:SetTextColor(color.r, color.g, color.b)
        r.edge:SetColorTexture(color.r, color.g, color.b, 1)
    else
        r.name:SetTextColor(1, 1, 1)
        r.edge:SetColorTexture(0.3, 0.3, 0.3, 1)
    end
    r.info = {
        canNeed = canNeed and true or false, reasonNeed = reasonNeed,
        canGreed = canGreed and true or false, reasonGreed = reasonGreed,
        canTransmog = canTransmog and true or false,
    }
    r:Show()
    return false
end

-- sample rows while unlocked, so there is something to drag
local function FillSample(r, i)
    r.rollID = nil
    r.band:SetColorTexture(0, 0, 0, i == 1 and 0.3 or 0)
    r.icon:SetTexture(i == 1 and 133784 or 134400)
    r.count:SetText("")
    r.name:SetText(i == 1 and "Loot rolls" or "Drag me")
    r.name:SetTextColor(0.64, 0.21, 0.93)
    r.edge:SetColorTexture(0.64, 0.21, 0.93, 1)
    r.timer:SetMinMaxValues(0, 1)
    r.timer:SetValue(i == 1 and 0.7 or 0.3)
    r.timer:SetStatusBarColor(1, 0.82, 0.2)
    r.time:SetText(i == 1 and "0:42" or "0:18")
    r.lit:SetShown(i == 1)
    r:Show()
end

local retry = false
function Draw()
    local shown, loading = 0, false
    local info
    if preview and #rolls == 0 then
        for i = 1, 2 do FillSample(Row(i), i) end
        shown = 2
    else
        for i = #rolls, 1, -1 do
            -- a roll whose time ran out has ended without telling us. Not the
            -- item info: it is missing while the item loads, and dropping the
            -- roll then left nothing on screen (owner, 2026-10-27, second
            -- dungeon - Blizzard's frames are faded)
            local left = GetLootRollTimeLeft(rolls[i].id)
            if left and Plain(left) and left <= 0 then table.remove(rolls, i) end
        end
        -- the pick stays while its roll is open, else the first one
        local still = false
        for _, roll in ipairs(rolls) do
            if roll.id == selected then still = true end
        end
        if not still then selected = rolls[1] and rolls[1].id or nil end
        for _, roll in ipairs(rolls) do
            shown = shown + 1
            local r = Row(shown)
            if FillRow(r, roll, shown) then loading = true end
            r.lit:SetShown(roll.id == selected)
            if roll.id == selected then info = r.info end
        end
    end
    for i = shown + 1, #rows do
        rows[i].rollID = nil
        rows[i]:Hide()
    end
    SetChoices(info and not info.loading and info or nil)
    if info and info.loading then SetChoice(buttons[3], 0, true) end
    win.count:SetText(shown > 1 and (shown .. " items") or "")
    win:SetHeight(TITLE + 4 + shown * (ROW + 2) + FOOT + PAD)
    win:SetShown(shown > 0)
    if (loading or shown > 0) and not retry then
        -- loading rows fill in, and timed-out rolls leave, without an event
        retry = true
        C_Timer.After(loading and 0.3 or 1, function()
            retry = false
            if #rolls > 0 then Draw() end
        end)
    end
end

local function Remove(rollID)
    for i = #rolls, 1, -1 do
        if rolls[i].id == rollID then table.remove(rolls, i) end
    end
    Draw()
end

local function Add(rollID, time)
    for _, roll in ipairs(rolls) do
        if roll.id == rollID then return end
    end
    rolls[#rolls + 1] = { id = rollID, time = time }
    Draw()
end

-------------------------------------------------------------------
-- Blizzard's roll frames out of sight
-------------------------------------------------------------------
local faded = false
local hooked = {}
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
    faded = state
    for i = 1, NUM_BLIZZARD do
        local f = _G["GroupLootFrame" .. i]
        if f then
            if not hooked[f] then
                hooked[f] = true
                hooksecurefunc(f, "SetAlpha", function(self, alpha)
                    if faded and alpha ~= 0 then self:SetAlpha(0) end
                end)
            end
            f:SetAlpha(state and 0 or 1)
            NoMouse(f, not state)
        end
    end
end

-------------------------------------------------------------------
-- Switching and events
-------------------------------------------------------------------
local ev = CreateFrame("Frame")

function D.ApplyLootRolls()
    local on = DeckUIDB.lootRolls and true or false
    SetBlizzardFaded(on)
    if on then
        ev:RegisterEvent("START_LOOT_ROLL")
        ev:RegisterEvent("CANCEL_LOOT_ROLL")
        ev:RegisterEvent("CANCEL_ALL_LOOT_ROLLS")
        -- rolls already open (switched on mid-roll, or a /reload)
        wipe(rolls)
        if GetActiveLootRollIDs then
            for _, id in ipairs(GetActiveLootRollIDs()) do
                local left = GetLootRollTimeLeft(id)
                local total = C_Loot and C_Loot.GetLootRollDuration and C_Loot.GetLootRollDuration(id)
                rolls[#rolls + 1] = { id = id, time = (total and Plain(total) and total) or (left and Plain(left) and left) or 60000 }
            end
        end
    else
        ev:UnregisterEvent("START_LOOT_ROLL")
        ev:UnregisterEvent("CANCEL_LOOT_ROLL")
        ev:UnregisterEvent("CANCEL_ALL_LOOT_ROLLS")
        wipe(rolls)
    end
    Draw()
end

ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        D.MakeMovable(win, "Loot rolls", DeckUIDB)
        D.OnUnlock(function(state, only)
            if only and not only["Loot rolls"] then state = false end
            preview = state and true or false
            Draw()
        end)
        D.ApplyLootRolls()
    elseif event == "START_LOOT_ROLL" then
        local rollID, time = ...
        seen.start = seen.start + 1
        Add(rollID, time)
    elseif event == "CANCEL_LOOT_ROLL" then
        seen.cancel = seen.cancel + 1
        Remove((...))
    elseif event == "CANCEL_ALL_LOOT_ROLLS" then
        wipe(rolls)
        Draw()
    end
end)

-- /deck rolls: what we hold and what Blizzard's frames do
function D.PrintLootRolls()
    print(("DeckUI rolls: option %s, %d open, window %s; heard %d starts, %d ends this session"):format(
        DeckUIDB.lootRolls and "on" or "off", #rolls, win:IsShown() and "shown" or "hidden", seen.start, seen.cancel))
    if GetActiveLootRollIDs then
        print("  game's open rolls: " .. table.concat(GetActiveLootRollIDs(), ", "))
    end
    for _, roll in ipairs(rolls) do
        local _, name = GetLootRollItemInfo(roll.id)
        print(("  roll %s: %s, %s ms left"):format(tostring(roll.id), tostring(name), tostring(GetLootRollTimeLeft(roll.id))))
    end
    for i = 1, NUM_BLIZZARD do
        local f = _G["GroupLootFrame" .. i]
        if f then
            print(("  GroupLootFrame%d: %s, alpha %.2f, roll %s"):format(i, f:IsShown() and "shown" or "hidden",
                f:GetAlpha(), tostring(f.rollID)))
        end
    end
end

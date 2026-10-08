local D = DeckUI

-------------------------------------------------------------------
-- The talking head as a subtitle
-------------------------------------------------------------------
-- Replaces Plumber's "Talking Head" module (owner's wish, 2026-10-08 - one
-- of the three Plumber modules he had switched on himself): Blizzard's box
-- with its frame and animated portrait takes a lot of the Deck's screen.
-- Ours is a subtitle in DeckUI's look - the speaker in gold, the line in
-- white on a dark band, all of it at once - movable ("Talking head", per
-- device) and below the world map's strata, so an open map covers it.
-- DeckUIDB.talkingHead (off by default), talkingHeadInstances (on: show
-- text in instances too; off keeps only the voice there).
--
-- Blizzard's TalkingHeadFrame only loses TALKINGHEAD_REQUESTED
-- (UnregisterEvent, re-registered when switched off - the way loot.lua
-- treats LootFrame); nothing is written onto it. The voice line is played
-- here, on the game's "Talking Head" sound channel, as Blizzard's frame
-- would have. Name and text may be secret values in Midnight: they go to
-- SetText whole and are never compared or joined unless plain.
-------------------------------------------------------------------
local WIDTH = 560
local FADE = 0.4      -- seconds to fade in and out
local AFTER = 0.6     -- seconds the line stays after its voice ends

local frame = CreateFrame("Frame", "DeckTalkingHead", UIParent)
frame:SetSize(WIDTH, 60)
frame:SetFrameStrata("MEDIUM")   -- the world map is HIGH and covers it
frame.defaultPoint = { "TOP", UIParent, "TOP", 0, -140 }
frame:SetPoint(unpack(frame.defaultPoint))
frame:Hide()

local band = frame:CreateTexture(nil, "BACKGROUND")
band:SetAllPoints()
band:SetColorTexture(0, 0, 0, 0.55)

local speaker = frame:CreateFontString(nil, "OVERLAY")
speaker:SetFont(D.FONT, 15, "OUTLINE")
speaker:SetPoint("TOP", 0, -8)
speaker:SetTextColor(1, 0.82, 0)

local line = frame:CreateFontString(nil, "OVERLAY")
line:SetFont(D.FONT, 14, "OUTLINE")
line:SetPoint("TOP", speaker, "BOTTOM", 0, -4)
line:SetWidth(WIDTH - 32)
line:SetJustifyH("CENTER")
line:SetWordWrap(true)

local voice          -- sound handle of the line playing
local hideAt = 0     -- GetTime() when the current line goes
local inInstance = false
local preview = false

local function Plain(v)
    return not (issecretvalue and issecretvalue(v))
end

local function Layout()
    -- the band grows with the text; heights are plain numbers of our own strings
    local h = 8 + speaker:GetStringHeight() + 4 + line:GetStringHeight() + 10
    if Plain(h) then frame:SetHeight(math.max(40, h)) end
end

local function StopVoice()
    if voice then
        StopSound(voice)
        voice = nil
    end
end

local function FadeOut()
    if frame:IsShown() and not preview then UIFrameFadeOut(frame, FADE, frame:GetAlpha(), 0) end
    C_Timer.After(FADE, function()
        if GetTime() >= hideAt and not preview then frame:Hide() end
    end)
end

local function OnRequested()
    StopVoice()
    local displayInfo, _, vo, duration, _, _, name, text = C_TalkingHead.GetCurrentLineInfo()
    if not (displayInfo and displayInfo ~= 0 and duration) then return end

    if vo then
        local ok, handle = PlaySound(vo, "Talking Head", true, true)
        if ok then voice = handle end
    end
    -- in an instance the voice alone, unless the text is wanted there too
    if inInstance and not DeckUIDB.talkingHeadInstances then return end

    speaker:SetText(name or "")
    line:SetText(text or "")
    Layout()
    frame:SetAlpha(0)
    frame:Show()
    UIFrameFadeIn(frame, FADE, 0, 1)
    local seconds = (Plain(duration) and duration or 5) + AFTER
    hideAt = GetTime() + seconds
    C_Timer.After(seconds, function()
        if GetTime() >= hideAt then FadeOut() end
    end)
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if event == "TALKINGHEAD_REQUESTED" then
        OnRequested()
    elseif event == "TALKINGHEAD_CLOSE" then
        hideAt = 0
        FadeOut()
    elseif event == "LOADING_SCREEN_ENABLED" then
        StopVoice()
        hideAt = 0
        frame:Hide()
    elseif event == "PLAYER_ENTERING_WORLD" then
        inInstance = IsInInstance() and true or false
    end
end)

local active = false

function D.ApplyTalkingHead()
    local on = DeckUIDB.talkingHead and true or false
    if on == active then return end
    active = on
    local blizzard = _G.TalkingHeadFrame
    if on then
        if blizzard then blizzard:UnregisterEvent("TALKINGHEAD_REQUESTED") end
        for _, e in ipairs({ "TALKINGHEAD_REQUESTED", "TALKINGHEAD_CLOSE", "LOADING_SCREEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
            ev:RegisterEvent(e)
        end
        inInstance = IsInInstance() and true or false
    else
        ev:UnregisterAllEvents()
        StopVoice()
        frame:Hide()
        if blizzard then blizzard:RegisterEvent("TALKINGHEAD_REQUESTED") end
    end
end

-- Blizzard's frame comes with its own load-on-demand addon
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    D.MakeMovable(frame, "Talking head", DeckUIDB)
    EventUtil.ContinueOnAddOnLoaded("Blizzard_TalkingHeadUI", function()
        if active then
            active = false   -- apply again now that the frame exists
        end
        D.ApplyTalkingHead()
    end)
    D.ApplyTalkingHead()
    -- unlocked, a sample line shows so there is something to drag
    D.OnUnlock(function(state, only)
        if only and not only["Talking head"] then state = false end
        preview = state and true or false
        if state then
            speaker:SetText("Talking head")
            line:SetText("A line of what is being said shows here, as a subtitle.")
            Layout()
            frame:SetAlpha(1)
            frame:Show()
        elseif GetTime() >= hideAt then
            frame:Hide()
        end
    end)
end)

local D = DeckUI

-------------------------------------------------------------------
-- Blizzard's damage meter in DeckUI's look
-------------------------------------------------------------------
-- The owner's wish (2026-09-30). Built from Blizzard_DamageMeter, 12.1.0
-- (read 2026-09-30). The meter's numbers are secret values in combat -
-- that is the point of a built-in meter - so nothing here reads them:
-- only textures and fonts change, through methods, after Blizzard has
-- set them up. No field is ever written onto Blizzard's frames; what we
-- need to remember lives in our own tables.
--
-- Where Blizzard sets the look:
--  - every bar: DamageMeterEntryMixin:UpdateStyle (on creation, on a
--    style change) sets the background atlas; a post-hook turns the bar
--    flat, the background dark, hides the shadow edge and swaps the font.
--    Its opacity stays Blizzard's (the "background opacity" setting sets
--    the alpha of the very textures we recolour);
--  - every window: DamageMeterSessionWindowMixin:SetStyle (on creation
--    and on a style change): the header bar, the window background and
--    the breakdown window's background become flat colour, and the window
--    gets a thin grey edge of its own.
-- Mixin functions are copied into a frame when it is made, so the hooks
-- go onto the mixin tables before the meter makes its frames, and frames
-- that exist already are styled once directly.
--
-- Switched on in the General tab (DeckUIDB.styleDamageMeter, off by
-- default); switched off it needs a /reload to get Blizzard's art back.
-------------------------------------------------------------------
local WHITE = "Interface\\Buttons\\WHITE8x8"
local edged = {}   -- window -> true once it has our edge

local function Enabled() return DeckUIDB and DeckUIDB.styleDamageMeter end

-- four one-pixel lines, only anchored (a window can be resized)
local function Edge(frame)
    local function Line(p1, p2, horizontal)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(0.3, 0.3, 0.3, 1)
        t:SetPoint(p1)
        t:SetPoint(p2)
        if horizontal then t:SetHeight(1) else t:SetWidth(1) end
    end
    Line("TOPLEFT", "TOPRIGHT", true)
    Line("BOTTOMLEFT", "BOTTOMRIGHT", true)
    Line("TOPLEFT", "BOTTOMLEFT", false)
    Line("TOPRIGHT", "BOTTOMRIGHT", false)
end

-- keep the size Blizzard chose (the text scale setting), change the face
local function Font(fs)
    if not fs then return end
    local _, size = fs:GetFont()
    if size then fs:SetFont(D.FONT, size, "OUTLINE") end
    fs:SetShadowOffset(0, 0)
end

local function StyleEntry(entry)
    if not Enabled() then return end
    local bar = entry.StatusBar
    if not bar then return end
    bar:SetStatusBarTexture(WHITE)
    if bar.Background then bar.Background:SetColorTexture(0.12, 0.12, 0.12, 0.9) end
    if bar.BackgroundEdge then bar.BackgroundEdge:SetAlpha(0) end
    Font(bar.Name)
    Font(bar.Value)
end

local function StyleWindow(window)
    if not Enabled() then return end
    if window.Header then window.Header:SetColorTexture(0.05, 0.05, 0.05, 0.95) end
    local container = window.MinimizeContainer
    if container and container.Background then
        container.Background:SetColorTexture(0.05, 0.05, 0.05, 0.85)
    end
    local source = container and container.SourceWindow
    if source and source.Background then
        source.Background:SetColorTexture(0.05, 0.05, 0.05, 0.95)
    end
    Font(window.SessionTimer)
    if not edged[window] then
        edged[window] = true
        Edge(window)
    end
end

local function StyleExisting()
    if not (DamageMeter and DamageMeter.ForEachSessionWindow) then return end
    DamageMeter:ForEachSessionWindow(function(window)
        StyleWindow(window)
        if window.ForEachEntryFrame then window:ForEachEntryFrame(StyleEntry) end
        local container = window.MinimizeContainer
        if container and container.LocalPlayerEntry then StyleEntry(container.LocalPlayerEntry) end
        local source = container and container.SourceWindow
        if source and source.ScrollBox and source.ScrollBox.ForEachFrame then
            source.ScrollBox:ForEachFrame(StyleEntry)
        end
    end)
end

local hooked = false
local function Hook()
    if hooked then return end
    hooked = true
    if DamageMeterEntryMixin and DamageMeterEntryMixin.UpdateStyle then
        hooksecurefunc(DamageMeterEntryMixin, "UpdateStyle", StyleEntry)
    end
    if DamageMeterSessionWindowMixin and DamageMeterSessionWindowMixin.SetStyle then
        hooksecurefunc(DamageMeterSessionWindowMixin, "SetStyle", StyleWindow)
    end
end

-- the General tab's checkbox
function D.SetDamageMeterStyled(on)
    if on then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_DamageMeter", function()
            Hook()
            StyleExisting()
        end)
    else
        print("DeckUI: the damage meter gets Blizzard's look back after /reload.")
    end
end

-- As early as the setting can be read: our saved variables arrive with
-- our own ADDON_LOADED, usually before the meter has made any bars.
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, _, name)
    if name ~= "DeckUI" then return end
    self:UnregisterEvent("ADDON_LOADED")
    if Enabled() then D.SetDamageMeterStyled(true) end
end)

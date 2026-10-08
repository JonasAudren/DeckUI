local D = DeckUI

-------------------------------------------------------------------
-- The auction house window in DeckUI's look
-------------------------------------------------------------------
-- Owner's wish (2026-10-08). Textures only, the way the world map and the
-- quest log are restyled (DeckUI_Map): Blizzard's frame art, portrait,
-- parchment backgrounds and the red panel buttons go to alpha 0, our flat
-- box (dark fill, thin edge) goes behind, buttons and the bottom tabs get
-- the flat look. No script of Blizzard's is replaced and no field written
-- onto its frames - the buy and post buttons call protected functions, and
-- a tainted path there would block them. DeckUIDB.ahStyle, off by default;
-- switching it off needs a reload (the art comes back with it).
-------------------------------------------------------------------
local function Fade(region)
    if region and region.SetAlpha then region:SetAlpha(0) end
end

-- a tab of PanelTabButtonTemplate: three pieces, each in a normal, an
-- active and a highlight version
local TAB_PIECES = { "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
                     "LeftHighlight", "MiddleHighlight", "RightHighlight" }

local function StyleTab(tab)
    for _, key in ipairs(TAB_PIECES) do Fade(tab[key]) end
    local box = CreateFrame("Frame", nil, tab)
    box:SetPoint("TOPLEFT", 6, -4)
    box:SetPoint("BOTTOMRIGHT", -6, 6)
    box:SetFrameLevel(math.max(0, tab:GetFrameLevel() - 1))
    D.FlatBox(box, 0.9, 0.35)
end

-- walks the window: insets lose their art and get a faint edge, panel
-- buttons become flat; tabs are done on their own
local function Walk(frame, depth)
    if depth > 7 then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.LeftActive then
            -- a tab, styled by StyleTab
        elseif child:IsObjectType("Button") and child.Left and child.Middle and child.Right then
            D.FlattenButton(child)
        else
            if child.NineSlice then
                Fade(child.NineSlice)
                D.FlatBox(child, 0.35, 0.22)
            end
            if child.Bg then Fade(child.Bg) end
            for _, region in ipairs({ child:GetRegions() }) do
                local atlas = region.GetAtlas and region:GetAtlas()
                -- the parchment and marble backgrounds of the lists
                if atlas and (atlas:find("auctionhouse%-background") or atlas:find("parchment")) then
                    Fade(region)
                end
            end
            Walk(child, depth + 1)
        end
    end
end

local function Style()
    local f = AuctionHouseFrame
    Fade(f.NineSlice)
    Fade(f.Bg)
    Fade(f.PortraitContainer)
    Fade(f.TopTileStreaks)
    D.FlatBox(f, 0.95)

    -- the gold bar under the money
    if f.MoneyFrameBorder then
        for _, region in ipairs({ f.MoneyFrameBorder:GetRegions() }) do Fade(region) end
    end
    if f.MoneyFrameInset then
        Fade(f.MoneyFrameInset.NineSlice)
        Fade(f.MoneyFrameInset.Bg)
    end

    for _, tab in ipairs({ f.BuyTab, f.SellTab, f.AuctionsTab }) do StyleTab(tab) end
    for _, tab in ipairs(f.Tabs or {}) do
        if tab ~= f.BuyTab and tab ~= f.SellTab and tab ~= f.AuctionsTab then StyleTab(tab) end
    end

    Walk(f, 1)
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI", function()
    if DeckUIDB and DeckUIDB.ahStyle then
        local ok, err = pcall(Style)
        if ok then D.ahStyled = true else geterrorhandler()(err) end
    end
end)

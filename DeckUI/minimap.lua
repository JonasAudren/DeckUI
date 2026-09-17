local D = DeckUI
local RADIUS = 100

local mmb = CreateFrame("Button", "DeckUIMinimapButton", Minimap)
mmb:SetSize(32, 32)
mmb:SetFrameStrata("MEDIUM")
mmb:SetFrameLevel(8)
mmb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mmb:RegisterForDrag("LeftButton")
mmb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local bg = mmb:CreateTexture(nil, "BACKGROUND")
bg:SetSize(24, 24)
bg:SetPoint("CENTER")
bg:SetTexture(D.DISC)
bg:SetVertexColor(0.1, 0.1, 0.1)

local ring = mmb:CreateTexture(nil, "ARTWORK")
ring:SetSize(20, 20)
ring:SetPoint("CENTER")
ring:SetTexture(D.DISC)
ring:SetVertexColor(0.2, 0.5, 1)

local orb = mmb:CreateTexture(nil, "ARTWORK", nil, 1)
orb:SetSize(14, 14)
orb:SetPoint("CENTER")
orb:SetTexture(D.DISC)
orb:SetVertexColor(0.9, 0.75, 0.2)

local border = mmb:CreateTexture(nil, "OVERLAY")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function UpdatePosition()
    local angle = math.rad(DeckUIDB.minimapAngle or 220)
    mmb:ClearAllPoints()
    mmb:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    DeckUIDB.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    UpdatePosition()
end

mmb:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
mmb:SetScript("OnDragStop",  function(self) self:SetScript("OnUpdate", nil) end)

mmb:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        D.SetUnlocked(not D.unlocked)
    else
        D.ToggleConfig()
    end
end)

mmb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("DeckUI")
    GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
    GameTooltip:AddLine("Right-click: unlock/lock frames", 1, 1, 1)
    GameTooltip:AddLine("Drag: move button", 1, 1, 1)
    GameTooltip:Show()
end)
mmb:SetScript("OnLeave", GameTooltip_Hide)

function D.SetMinimapShown(state)
    DeckUIDB.showMinimap = state
    mmb:SetShown(state)
    if not state then print("DeckUI: minimap button hidden - /deck opens the settings.") end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    UpdatePosition()
    if DeckUIDB.showMinimap == false then mmb:Hide() end
end)

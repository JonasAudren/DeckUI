local D = DeckUI

-------------------------------------------------------------------
-- The dungeon queue as a small window
-------------------------------------------------------------------
-- Owner's wish (2026-10-27): not only Blizzard's eye at the minimap, but a
-- small window that says while you wait who has been found, how long the
-- estimate is and how long you have been waiting - what the eye only shows
-- on mouse-over. DeckUIDB.lfgWindow, off by default, Overview page; movable
-- "Dungeon queue". Blizzard's eye stays.
--
-- One block per queue (Dungeon Finder, Raid Finder, scenarios), read the
-- way Blizzard's QueueStatusFrame reads it (5.5.4 and 12.1.5 alike):
-- GetLFGMode(category, id) for the state, GetLFGQueueStats(category, id)
-- for the numbers - per role how many are still needed of how many, your
-- estimated wait, and when you queued. The game tells roles, not classes:
-- a found healer is a healer, whoever it is. Scenarios have no roles, so
-- there only the times show. The window ticks once a second while it
-- shows and is hidden when no queue is open.
-------------------------------------------------------------------
local W, PAD = 230, 8

local CATEGORIES = {
    { id = LE_LFG_CATEGORY_LFD, name = LOOKING_FOR_DUNGEON or "Dungeon Finder" },
    { id = LE_LFG_CATEGORY_RF, name = RAID_FINDER or "Raid Finder" },
    { id = LE_LFG_CATEGORY_SCENARIO, name = SCENARIOS or "Scenarios", noRoles = true },
}
local ROLES = { { "TANK", "tank" }, { "HEALER", "healer" }, { "DAMAGER", "dps" } }
local ROLE_FILE = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"

local function Enabled() return DeckUIDB and DeckUIDB.lfgWindow end

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    if seconds >= 3600 then
        return ("%d:%02d:%02d"):format(math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60)
    end
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function RoleIcon(role)
    if not GetTexCoordsForRoleSmallCircle then return role:sub(1, 1) end
    local l, r, t, b = GetTexCoordsForRoleSmallCircle(role)
    return ("|T%s:14:14:0:0:64:64:%d:%d:%d:%d|t"):format(ROLE_FILE, l * 64, r * 64, t * 64, b * 64)
end

-- the active queue of a category: its ID and mode, nil when not queued
local function ActiveQueue(category)
    local activeID = select(18, GetLFGQueueStats(category))
    local list = GetLFGQueuedList and GetLFGQueuedList(category) or {}
    for queueID in pairs(list) do
        local mode = GetLFGMode(category, queueID)
        if mode and (not activeID or (mode ~= "queued" and mode ~= "listed" and mode ~= "suspended")) then
            activeID = queueID
        end
    end
    if not activeID then return nil end
    local mode = GetLFGMode(category, activeID)
    if not mode then return nil end
    return activeID, mode
end

-------------------------------------------------------------------
-- The window
-------------------------------------------------------------------
local win = CreateFrame("Frame", "DeckLFGQueue", UIParent)
win:SetSize(W, 60)
win.defaultPoint = { "TOPRIGHT", UIParent, "TOPRIGHT", -230, -220 }
win:SetPoint(unpack(win.defaultPoint))
win:SetFrameStrata("MEDIUM")
win:Hide()
D.FlatBox(win, 0.9)

local blocks = {}

local function Text(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(D.FONT, size, "OUTLINE")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetWidth(W - 2 * PAD)
    return fs
end

local function Block(i)
    local b = blocks[i]
    if b then return b end
    b = CreateFrame("Frame", nil, win)
    b:SetSize(W - 2 * PAD, 58)
    b.title = Text(b, 12)
    b.title:SetPoint("TOPLEFT", 0, 0)
    b.title:SetTextColor(1, 0.82, 0)
    b.roles = Text(b, 12)
    b.roles:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -4)
    b.times = Text(b, 11)
    b.times:SetPoint("TOPLEFT", b.roles, "BOTTOMLEFT", 0, -4)
    blocks[i] = b
    return b
end

local STATES = {
    proposal = "|cff33ff33Group found!|r",
    rolecheck = "Role check ...",
    suspended = "|cffff9933Paused|r",
    lfgparty = "In the group",
    abandonedInDungeon = "In the group",
}

local function Update()
    if not Enabled() then win:Hide() return end
    local used, y = 0, -PAD
    for _, cat in ipairs(CATEGORIES) do
        local id, mode
        if cat.id then id, mode = ActiveQueue(cat.id) end
        if id and mode ~= "lfgparty" and mode ~= "abandonedInDungeon" then
            used = used + 1
            local b = Block(used)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", PAD, y)
            local _, tankNeeds, healerNeeds, dpsNeeds, totalTanks, totalHealers, totalDPS, _, _, instanceName,
                _, _, _, _, myWait, queuedTime = select(2, GetLFGQueueStats(cat.id, id))
            local name = instanceName and instanceName ~= "" and instanceName
                or (GetLFGDungeonInfo and GetLFGDungeonInfo(id)) or cat.name
            b.title:SetText(name)
            if mode == "queued" then
                if cat.noRoles or not totalTanks then
                    b.roles:SetText("")
                else
                    local parts = {}
                    local found = { totalTanks - (tankNeeds or 0), totalHealers - (healerNeeds or 0), totalDPS - (dpsNeeds or 0) }
                    local total = { totalTanks, totalHealers, totalDPS }
                    for i, r in ipairs(ROLES) do
                        local full = found[i] >= total[i]
                        parts[#parts + 1] = ("%s %s%d/%d|r"):format(RoleIcon(r[1]), full and "|cff33ff33" or "|cffffffff",
                            found[i], total[i])
                    end
                    b.roles:SetText(table.concat(parts, "   "))
                end
                local waited = queuedTime and (GetTime() - queuedTime) or 0
                local estimate = (myWait and myWait > 0) and Clock(myWait) or "unknown"
                b.times:SetText(("Waiting |cffffffff%s|r   Estimate |cffffffff%s|r"):format(Clock(waited), estimate))
            else
                b.roles:SetText(STATES[mode] or mode)
                b.times:SetText("")
            end
            b:Show()
            y = y - (b.times:GetText() ~= "" and 58 or 40)
        end
    end
    for i = used + 1, #blocks do blocks[i]:Hide() end
    if used == 0 and not D.IsUnlocked("Dungeon queue") then
        win:Hide()
        return
    end
    win:SetHeight(math.max(40, -y + PAD - 4))
    win:Show()
end

-- ticking only while a queue shows
local ticker
local function Tick()
    Update()
    if win:IsShown() and not ticker then
        ticker = C_Timer.NewTicker(1, function()
            Update()
            if not win:IsShown() and ticker then ticker:Cancel(); ticker = nil end
        end)
    end
end

function D.ApplyLFGWindow()
    Tick()
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "LFG_UPDATE", "LFG_QUEUE_STATUS_UPDATE", "LFG_PROPOSAL_SHOW", "LFG_PROPOSAL_FAILED",
    "LFG_PROPOSAL_SUCCEEDED", "LFG_ROLE_CHECK_SHOW", "LFG_ROLE_CHECK_UPDATE", "GROUP_ROSTER_UPDATE",
    "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        D.MakeMovable(win, "Dungeon queue", DeckUIDB)
        -- dragged directly while it shows, no Move needed (owner, 2026-10-27)
        D.MakeDraggable(win)
    end
    if Enabled() then Tick() end
end)

-- shown while unlocked, so it can be placed without a queue
if D.OnUnlock then
    D.OnUnlock(function() if Enabled() then Update() end end)
end

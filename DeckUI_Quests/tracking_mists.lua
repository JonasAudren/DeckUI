local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Zone widgets and tracked achievements in Mists of Pandaria Classic
-------------------------------------------------------------------
-- Only in DeckUI_Quests_Mists.toc, in place of retail's tracking.lua
-- (MISTS_PLAN.md, phase 7). Of what retail's file draws, Mists has the
-- zone widgets and achievements - no collections, Traveler's Log,
-- endeavors or tracked recipes. Achievements are tracked the old way:
-- GetTrackedAchievements / RemoveTrackedAchievement, as Mists' WatchFrame
-- reads them (Wrath/WatchFrame.lua, 5.5.4), not through C_ContentTracking.
-- The lines are retail's (AchievementLines there), the criteria API is the
-- same in Mists.
-------------------------------------------------------------------
local FAILED = { 1, 0.3, 0.3 }

local function Menu(row, title, buttons)
    MenuUtil.CreateContextMenu(row, function(_, root)
        if title then root:CreateTitle(title) end
        for _, b in ipairs(buttons) do root:CreateButton(b[1], b[2]) end
    end)
end

local function Tooltip(title, hint)
    return function(row)
        GameTooltip:SetOwner(row, "ANCHOR_LEFT")
        GameTooltip:SetText(title or "")
        GameTooltip:AddLine(hint, 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end
end

-------------------------------------------------------------------
-- Zone widgets (capture bars, zone objectives), drawn from their data
-------------------------------------------------------------------
ns.RegisterSection("zone", {
    title = "Zone",
    order = 15,
    Collect = function()
        ns.ticking.zone = nil   -- a widget with a timer sets it again
        local lines = ns.WidgetLines("zone", C_UIWidgetManager.GetObjectiveTrackerWidgetSetID())
        if #lines == 0 then return {} end
        return { { key = "zone-widgets", title = GetRealZoneText(), lines = lines } }
    end,
})

-------------------------------------------------------------------
-- Achievements
-------------------------------------------------------------------
local PROGRESS_BAR_FLAG = EVALUATION_TREE_FLAG_PROGRESS_BAR or 0x1
local CRITERIA_TYPE_ACHIEVEMENT = CRITERIA_TYPE_ACHIEVEMENT or 8
local MAX_CRITERIA = 5   -- Blizzard's MAX_CRITERIA_PER_ACHIEVEMENT

local function AchievementClick(id, name)
    return function(row, button)
        if button == "RightButton" then
            Menu(row, name, {
                { OBJECTIVES_STOP_TRACKING or "Stop tracking", function() RemoveTrackedAchievement(id) end },
            })
        elseif IsModifiedClick("QUESTWATCHTOGGLE") then
            RemoveTrackedAchievement(id)
        end
    end
end

local function AchievementLines(id, description)
    local lines = {}
    local num = GetAchievementNumCriteria(id)
    if num == 0 then
        lines[1] = { text = description }
        return lines
    end
    local shown = 0
    for i = 1, num do
        local criteriaString, criteriaType, completed, quantity, totalQuantity, _, flags, assetID,
            quantityString, _, eligible, duration, elapsed = GetAchievementCriteriaInfo(id, i)
        if not completed then
            if shown >= MAX_CRITERIA then
                lines[#lines + 1] = { text = "..." }
                break
            end
            shown = shown + 1
            local line = { text = criteriaString, color = eligible == false and FAILED or nil }
            if criteriaType == CRITERIA_TYPE_ACHIEVEMENT and assetID then
                line.text = select(2, GetAchievementInfo(assetID)) or line.text
            end
            if flags and bit.band(flags, PROGRESS_BAR_FLAG) ~= 0 and totalQuantity and totalQuantity > 0 then
                line.text = (quantityString and quantityString:gsub(" / ", "/") .. " " or "") .. (criteriaString or "")
                line.bar = math.min(1, (quantity or 0) / totalQuantity)
            end
            if duration and elapsed and elapsed < duration then
                line.text = line.text .. ("  (%d:%02d)"):format(math.floor((duration - elapsed) / 60), (duration - elapsed) % 60)
                ns.ticking.achievements = true
            end
            lines[#lines + 1] = line
        end
    end
    return lines
end

ns.RegisterSection("achievements", {
    title = "Achievements",
    order = 40,
    Collect = function()
        ns.ticking.achievements = nil
        local entries = {}
        for _, id in ipairs({ GetTrackedAchievements() }) do
            local _, name, _, _, _, _, _, description, _, _, _, _, wasEarnedByMe = GetAchievementInfo(id)
            if name and not wasEarnedByMe then
                entries[#entries + 1] = {
                    key = "achievement" .. id,
                    title = name,
                    lines = AchievementLines(id, description),
                    OnClick = AchievementClick(id, name),
                    OnEnter = Tooltip(name, "Shift-click: stop tracking, Right-click: menu"),
                }
            end
        end
        return entries
    end,
})

-------------------------------------------------------------------
-- Events
-------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({
    "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD",
    "TRACKED_ACHIEVEMENT_UPDATE", "TRACKED_ACHIEVEMENT_LIST_CHANGED", "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE",
}) do ev:RegisterEvent(e) end
ev:SetScript("OnEvent", function(_, event)
    if event == "CRITERIA_UPDATE" or event:find("ACHIEVEMENT") then
        ns.RequestUpdate("achievements")
    else
        ns.RequestUpdate()
    end
end)

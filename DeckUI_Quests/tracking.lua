local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Everything else Blizzard's tracker showed: zone widgets, collections,
-- achievements, the Traveler's Log, neighbourhood endeavors and recipes.
-------------------------------------------------------------------
-- Each follows its Blizzard module (12.1.0, read 2026-09-29) - same data,
-- same clicks: left opens where it lives, shift-left stops tracking,
-- right opens a small menu. Section order is Blizzard's order.
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

-- Blizzard's requirement lines read "3 / 10 Things"; it tightens them.
local function Requirement(text)
    return (text or ""):gsub(" / ", "/")
end

-------------------------------------------------------------------
-- Zone widgets (capture bars, zone objectives)
-------------------------------------------------------------------
local zoneWidgets

ns.RegisterSection("zone", {
    title = "Zone",
    order = 15,
    Init = function()
        zoneWidgets = ns.NewWidgetContainer()
        ns.SetWidgetSet(zoneWidgets, C_UIWidgetManager.GetObjectiveTrackerWidgetSetID())
    end,
    Collect = function()
        if not ns.HasWidgets(zoneWidgets) then return {} end
        return { { key = "zone-widgets", widget = zoneWidgets } }
    end,
})

-------------------------------------------------------------------
-- Collections: tracked appearances, mounts and decor
-------------------------------------------------------------------
local CT = Enum.ContentTrackingType
local TARGET = Enum.ContentTrackingTargetType
local STOP_MANUAL = Enum.ContentTrackingStopType.Manual

local function AdventureClick(trackType, id, targetType, targetID, title)
    local function Stop() C_ContentTracking.StopTracking(trackType, id, STOP_MANUAL) end
    return function(row, button)
        if button == "RightButton" then
            Menu(row, title, {
                { SUPER_TRACK_QUEST or "Super track", function() C_SuperTrack.SetSuperTrackedContent(trackType, id) end },
                { OBJECTIVES_STOP_TRACKING or "Stop tracking", Stop },
            })
        elseif IsShiftKeyDown() then
            Stop()
        elseif targetType == TARGET.Achievement then
            ShowAchievementFrameForAchievement(targetID)
        elseif targetType == TARGET.Profession then
            ProfessionsUtil.OpenProfessionFrameToRecipe(targetID)
        else
            ContentTrackingUtil.OpenMapToTrackable(trackType, id)
        end
    end
end

ns.RegisterSection("adventure", {
    title = "Collections",
    order = 35,
    Collect = function()
        local entries = {}
        if ContentTrackingUtil and not ContentTrackingUtil.IsContentTrackingEnabled() then return entries end
        local superType, superID = C_SuperTrack.GetSuperTrackedContent()
        for _, trackType in ipairs(C_ContentTracking.GetCollectableSourceTypes() or {}) do
            for _, id in ipairs(C_ContentTracking.GetTrackedIDs(trackType) or {}) do
                local targetType, targetID = C_ContentTracking.GetCurrentTrackingTarget(trackType, id)
                if targetType then
                    local title = C_ContentTracking.GetTitle(trackType, id)
                    local lines = { { text = C_ContentTracking.GetObjectiveText(targetType, targetID, false)
                        or CONTENT_TRACKING_RETRIEVING_INFO or "Retrieving info..." } }
                    local isSuper = superType == trackType and superID == id
                    if isSuper then
                        local waypoint = C_ContentTracking.GetWaypointText(trackType, id)
                        if waypoint then lines[#lines + 1] = { text = waypoint } end
                    end
                    entries[#entries + 1] = {
                        key = "adventure" .. trackType .. "-" .. id,
                        title = title,
                        color = isSuper and { 1, 0.82, 0 } or nil,
                        lines = lines,
                        OnClick = AdventureClick(trackType, id, targetType, targetID, title),
                        OnEnter = Tooltip(title, "Left-click: show where, Shift-click: stop tracking, Right-click: menu"),
                    }
                end
            end
        end
        return entries
    end,
})

-------------------------------------------------------------------
-- Achievements
-------------------------------------------------------------------
local PROGRESS_BAR_FLAG = EVALUATION_TREE_FLAG_PROGRESS_BAR or 0x1
local CRITERIA_TYPE_ACHIEVEMENT = CRITERIA_TYPE_ACHIEVEMENT or 8
local MAX_CRITERIA = 5   -- Blizzard's MAX_CRITERIA_PER_ACHIEVEMENT

local function StopAchievement(id)
    C_ContentTracking.StopTracking(CT.Achievement, id, STOP_MANUAL)
end

local function AchievementClick(id, name)
    return function(row, button)
        if button == "RightButton" then
            Menu(row, name, {
                { OBJECTIVES_VIEW_ACHIEVEMENT or "View achievement", function() ShowAchievementFrameForAchievement(id) end },
                { OBJECTIVES_STOP_TRACKING or "Stop tracking", function() StopAchievement(id) end },
            })
        elseif IsModifiedClick("QUESTWATCHTOGGLE") then
            StopAchievement(id)
        else
            ShowAchievementFrameForAchievement(id)
        end
    end
end

local function AchievementLines(id, description)
    local lines = {}
    local num = GetAchievementNumCriteria(id)
    if num == 0 then
        lines[1] = { text = description, color = not IsAchievementEligible(id) and FAILED or nil }
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
            local line = { text = criteriaString, color = not eligible and FAILED or nil }
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
        for _, id in ipairs(C_ContentTracking.GetTrackedIDs(CT.Achievement) or {}) do
            local _, name, _, _, _, _, _, description, _, _, _, _, wasEarnedByMe = GetAchievementInfo(id)
            if name and not wasEarnedByMe then
                entries[#entries + 1] = {
                    key = "achievement" .. id,
                    title = name,
                    lines = AchievementLines(id, description),
                    OnClick = AchievementClick(id, name),
                    OnEnter = Tooltip(name, "Left-click: open, Shift-click: stop tracking, Right-click: menu"),
                }
            end
        end
        return entries
    end,
})

-------------------------------------------------------------------
-- Traveler's Log (monthly activities)
-------------------------------------------------------------------
local function OpenActivity(id)
    if not EncounterJournal then EncounterJournal_LoadUI() end
    MonthlyActivitiesFrame_OpenFrameToActivity(id)
end

ns.RegisterSection("monthly", {
    title = "Traveler's Log",
    order = 45,
    Collect = function()
        local entries = {}
        local tracked = C_PerksActivities.GetTrackedPerksActivities()
        for _, id in ipairs(tracked and tracked.trackedIDs or {}) do
            local info = C_PerksActivities.GetPerksActivityInfo(id)
            if info and not info.completed then
                local lines = {}
                for _, req in ipairs(info.requirementsList or {}) do
                    if not req.completed then lines[#lines + 1] = { text = Requirement(req.requirementText) } end
                end
                local function Stop() C_PerksActivities.RemoveTrackedPerksActivity(id) end
                entries[#entries + 1] = {
                    key = "monthly" .. id,
                    title = info.activityName,
                    lines = lines,
                    OnClick = function(row, button)
                        if button == "RightButton" then
                            Menu(row, info.activityName, {
                                { "View in Traveler's Log", function() OpenActivity(id) end },
                                { OBJECTIVES_STOP_TRACKING or "Stop tracking", Stop },
                            })
                        elseif IsModifiedClick("QUESTWATCHTOGGLE") then
                            Stop()
                        else
                            OpenActivity(id)
                        end
                    end,
                    OnEnter = Tooltip(info.activityName, "Left-click: Traveler's Log, Shift-click: stop tracking"),
                }
            end
        end
        return entries
    end,
})

-------------------------------------------------------------------
-- Neighbourhood endeavors (housing initiatives)
-------------------------------------------------------------------
-- Blizzard asks the server for the initiative data itself, and only when
-- something is tracked; without that request the info may never arrive.
local NI = C_NeighborhoodInitiative

local function RequestInitiatives()
    if not NI then return end
    local tracked = NI.GetTrackedInitiativeTasks()
    if tracked and tracked.trackedIDs and #tracked.trackedIDs > 0 then
        NI.RequestNeighborhoodInitiativeInfo()
    end
end

ns.RegisterSection("initiatives", {
    title = "Endeavors",
    order = 50,
    Init = RequestInitiatives,
    Collect = function()
        local entries = {}
        if not NI then return entries end
        local tracked = NI.GetTrackedInitiativeTasks()
        for _, id in ipairs(tracked and tracked.trackedIDs or {}) do
            local info = NI.GetInitiativeTaskInfo(id)
            if info and not info.completed then
                local lines = {}
                for _, req in ipairs(info.requirementsList or {}) do
                    if not req.completed then lines[#lines + 1] = { text = Requirement(req.requirementText) } end
                end
                local function Stop() NI.RemoveTrackedInitiativeTask(id) end
                local function Open() HousingFramesUtil.OpenFrameToTaskID(id) end
                entries[#entries + 1] = {
                    key = "initiative" .. id,
                    title = info.taskName,
                    lines = lines,
                    OnClick = function(row, button)
                        if button == "RightButton" then
                            Menu(row, info.taskName, {
                                { "View in Endeavors", Open },
                                { OBJECTIVES_STOP_TRACKING or "Stop tracking", Stop },
                            })
                        elseif IsModifiedClick("QUESTWATCHTOGGLE") then
                            Stop()
                        else
                            Open()
                        end
                    end,
                    OnEnter = Tooltip(info.taskName, "Left-click: Endeavors, Shift-click: stop tracking"),
                }
            end
        end
        return entries
    end,
})

-------------------------------------------------------------------
-- Profession recipes: reagents owned / needed
-------------------------------------------------------------------
-- Owned counts everything Blizzard counts: bags, bank and warband bank
-- (ItemUtil.GetCraftingReagentCount), summed over all quality tiers.
local MODIFYING = Enum.CraftingReagentType.Modifying

local function Owned(reagents)
    local total = 0
    for _, r in ipairs(reagents or {}) do
        if r.itemID then
            total = total + (C_Item.GetItemCount(r.itemID, true, false, true, true) or 0)
        elseif r.currencyID then
            local info = C_CurrencyInfo.GetCurrencyInfo(r.currencyID)
            total = total + (info and info.quantity or 0)
        end
    end
    return total
end

local function ReagentName(slot)
    if slot.reagentType == MODIFYING then
        return slot.slotInfo and slot.slotInfo.slotText or "?"
    end
    local r = slot.reagents and slot.reagents[1]
    if not r then return "?" end
    if r.itemID then
        local name = C_Item.GetItemNameByID(r.itemID)
        if not name then C_Item.RequestLoadItemDataByID(r.itemID) end
        return name or "..."
    end
    local info = r.currencyID and C_CurrencyInfo.GetCurrencyInfo(r.currencyID)
    return info and info.name or "?"
end

local function RecipeEntry(recipeID, isRecraft)
    local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, isRecraft)
    if not schematic then return nil end
    local slots = {}
    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        if slot.required then slots[#slots + 1] = slot end
    end
    -- required modifying slots first, as Blizzard lists them
    table.sort(slots, function(a, b)
        local am, bm = a.reagentType == MODIFYING, b.reagentType == MODIFYING
        if am ~= bm then return am end
        return (a.slotIndex or 0) < (b.slotIndex or 0)
    end)
    local lines = {}
    for _, slot in ipairs(slots) do
        local have, need = Owned(slot.reagents), slot.quantityRequired or 0
        lines[#lines + 1] = { text = ("%d/%d %s"):format(have, need, ReagentName(slot)), done = have >= need }
    end
    local title = isRecraft and ("Recraft: " .. (schematic.name or "")) or schematic.name
    local function Stop() C_TradeSkillUI.SetRecipeTracked(recipeID, false, isRecraft) end
    local function Open()
        ProfessionsFrame_LoadUI()
        if isRecraft then return end
        if C_TradeSkillUI.IsRecipeProfessionLearned(recipeID) then
            C_TradeSkillUI.OpenRecipe(recipeID)
        else
            Professions.InspectRecipe(recipeID)
        end
    end
    return {
        key = (isRecraft and "recraft" or "recipe") .. recipeID,
        title = title,
        lines = lines,
        OnClick = function(row, button)
            if button == "RightButton" then
                Menu(row, title, {
                    { "View recipe", Open },
                    { OBJECTIVES_STOP_TRACKING or "Stop tracking", Stop },
                })
            elseif IsModifiedClick("RECIPEWATCHTOGGLE") or IsShiftKeyDown() then
                Stop()
            else
                Open()
            end
        end,
        OnEnter = Tooltip(title, "Left-click: open the recipe, Shift-click: stop tracking"),
    }
end

ns.RegisterSection("recipes", {
    title = "Recipes",
    order = 55,
    Collect = function()
        local entries = {}
        for _, isRecraft in ipairs({ false, true }) do
            for _, recipeID in ipairs(C_TradeSkillUI.GetRecipesTracked(isRecraft) or {}) do
                local e = RecipeEntry(recipeID, isRecraft)
                if e then entries[#entries + 1] = e end
            end
        end
        return entries
    end,
})

-------------------------------------------------------------------
-- Events for all of the above
-------------------------------------------------------------------
-- Blizzard's collections module untracks a collected appearance while it
-- lays out; with it switched off, that happens here.
local ev = CreateFrame("Frame")
for _, e in ipairs({
    "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD",
    "CONTENT_TRACKING_UPDATE", "CONTENT_TRACKING_LIST_UPDATE", "CONTENT_TRACKING_IS_ENABLED_UPDATE",
    "TRACKING_TARGET_INFO_UPDATE", "TRACKABLE_INFO_UPDATE", "SUPER_TRACKING_CHANGED",
    "TRANSMOG_COLLECTION_SOURCE_ADDED", "HOUSE_DECOR_ADDED_TO_CHEST",
    "TRACKED_ACHIEVEMENT_UPDATE", "TRACKED_ACHIEVEMENT_LIST_CHANGED", "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE",
    "PERKS_ACTIVITY_COMPLETED", "PERKS_ACTIVITIES_TRACKED_UPDATED", "PERKS_ACTIVITIES_TRACKED_LIST_CHANGED",
    "INITIATIVE_TASKS_TRACKED_UPDATED", "INITIATIVE_TASKS_TRACKED_LIST_CHANGED", "NEIGHBORHOOD_INITIATIVE_UPDATED",
    "TRACKED_RECIPE_UPDATE", "BAG_UPDATE_DELAYED", "CURRENCY_DISPLAY_UPDATE",
}) do pcall(ev.RegisterEvent, ev, e) end

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "TRANSMOG_COLLECTION_SOURCE_ADDED" and arg1
        and C_ContentTracking.IsTracking(CT.Appearance, arg1) then
        C_ContentTracking.StopTracking(CT.Appearance, arg1, Enum.ContentTrackingStopType.Collected)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        RequestInitiatives()
    end
    ns.RequestUpdate()
end)

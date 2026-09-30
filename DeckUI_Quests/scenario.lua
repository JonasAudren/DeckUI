local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Scenarios, delves, dungeons and Mythic+
-------------------------------------------------------------------
-- The same sources as Blizzard's ScenarioObjectiveTracker (12.1.0,
-- read 2026-09-29): the stage through the undocumented C_Scenario.GetInfo
-- and GetStepInfo, the criteria through C_ScenarioInfo.GetCriteriaInfo.
-- A criterion flagged isWeightedProgress carries its progress in
-- `quantity` as a 0-100 percentage (enemy forces work like that); a
-- whole weighted step reports it in GetStepInfo's weightedProgress.
--
-- GetStepInfo returns, in order: name, description, numCriteria,
-- stepFailed, isBonusStep, isForCurrentStepOnly, shouldShowBonusObjective,
-- numSpells, allSpellInfo, weightedProgress, rewardQuestID, widgetSetID.
--
-- The docs mark none of this secret. A Mythic+ key is one of the AddOn
-- restriction types, though, so if a number does turn out secret in a
-- key, the section errors - and core.lua shows the error on one line
-- instead of losing the tracker.
-------------------------------------------------------------------
local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- Blizzard hides criteria and spells while this is false (some scenarios
-- reveal their objectives only later); it arrives with an event.
local showCriteria = true

local function CriterionLine(c)
    local text = c.description
    if not c.isWeightedProgress and not c.isFormatted and c.totalQuantity and c.totalQuantity > 0 then
        text = ("%d/%d %s"):format(c.quantity, c.totalQuantity, c.description)
    end
    local line = { text = text, done = c.completed }
    if c.failed then line.color = { 1, 0.3, 0.3 } end
    if c.isWeightedProgress and not c.completed then
        line.bar = (c.quantity or 0) / 100
    end
    if c.duration and c.duration > 0 and c.elapsed and c.elapsed <= c.duration then
        line.text = line.text .. "  (" .. Clock(c.duration - c.elapsed) .. ")"
        ns.ticking.scenario = true
    end
    return line
end

local function CriteriaLines()
    local lines = {}
    local _, stageDescription, numCriteria, _, _, _, _, _, _, weightedProgress = C_Scenario.GetStepInfo()
    if weightedProgress then
        -- the whole step is one bar (Blizzard shows the description and the bar)
        lines[#lines + 1] = { text = stageDescription, bar = weightedProgress / 100 }
        return lines
    end
    for i = 1, numCriteria or 0 do
        local c = C_ScenarioInfo.GetCriteriaInfo(i)
        if c then lines[#lines + 1] = CriterionLine(c) end
    end
    return lines
end

-------------------------------------------------------------------
-- The delve header: tier, lives and the delve's effects, as text
-------------------------------------------------------------------
-- Blizzard shows it as a widget (ScenarioHeaderDelves) in the stage's
-- widget set. Hosting that widget tainted the game's shared widget frames
-- (see core.lua), so the same data is read here and drawn as an entry -
-- the fields Blizzard's own template uses (UIWidgetTemplateScenarioHeader
-- Delves.lua, 12.1.0): headerText, tierText, the currencies (the lives),
-- the spells (the delve's effects) and the tooltips.
-- 514 and 252: the fixed sets Blizzard's scenario module shows above and
-- below its blocks (its XML, 12.1.0)
local SCENARIO_TOP_SET, SCENARIO_BOTTOM_SET = 514, 252

local function Shown(info)
    return info and info.shownState ~= Enum.WidgetShownState.Hidden
end

-- the treasure in the header's corner
local REWARD = Enum.UIWidgetRewardShownState or {}

local function DelveEntry(widgetSetID)
    if not widgetSetID or widgetSetID == 0 then return nil end
    ns.WatchWidgetSet("scenario", widgetSetID)
    local header
    for _, w in ipairs(C_UIWidgetManager.GetAllWidgetsBySetID(widgetSetID) or {}) do
        if w.widgetType == Enum.UIWidgetVisualizationType.ScenarioHeaderDelves then
            local info = C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo(w.widgetID)
            if Shown(info) then header = info break end
        end
    end
    if not header then return nil end

    local title = header.headerText
    if header.tierText and header.tierText ~= "" then
        title = ("%s - Tier %s"):format(title, header.tierText)
    end
    local lines = ns.CurrencyLines(header.currencies, {})
    local reward = header.rewardInfo
    if reward and reward.shownState == REWARD.ShownEarned then
        lines[#lines + 1] = { text = "Treasure earned", done = true }
    elseif reward and reward.shownState == REWARD.ShownUnearned then
        lines[#lines + 1] = { text = "Treasure not earned yet" }
    end
    for _, sp in ipairs(header.spells or {}) do
        if Shown(sp) then
            local name = C_Spell.GetSpellName(sp.spellID)
            local icon = C_Spell.GetSpellTexture(sp.spellID)
            if name then
                lines[#lines + 1] = { text = (icon and ("|T%d:0|t "):format(icon) or "") .. name }
            end
        end
    end
    return {
        key = "delve",
        title = title,
        color = { 1, 0.82, 0 },
        lines = lines,
        OnEnter = function(row)
            GameTooltip:SetOwner(row, "ANCHOR_LEFT")
            GameTooltip:AddLine(header.headerText, 1, 1, 1)
            if header.tooltip and header.tooltip ~= "" then
                GameTooltip:AddLine(header.tooltip, nil, nil, nil, true)
            end
            for _, sp in ipairs(header.spells or {}) do
                if Shown(sp) and sp.tooltip and sp.tooltip ~= "" then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(sp.tooltip, nil, nil, nil, true)
                end
            end
            -- Blizzard's own words for the treasure, earned or not
            local rewardText = reward and (reward.shownState == REWARD.ShownEarned
                and reward.earnedTooltip or reward.unearnedTooltip)
            if reward and reward.shownState ~= REWARD.Hidden and rewardText and rewardText ~= "" then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(rewardText, nil, nil, nil, true)
            end
            GameTooltip:Show()
        end,
    }
end

-------------------------------------------------------------------
-- Scenario spells: secure spell buttons, one entry per spell
-------------------------------------------------------------------
local function SpellEntries(allSpellInfo)
    local entries, seen = {}, {}
    local function Add(spellID, name, icon)
        if not spellID or seen[spellID] then return end
        seen[spellID] = true
        if not (name and icon) then
            local info = C_Spell.GetSpellInfo(spellID)
            name = name or (info and info.name)
            icon = icon or (info and info.iconID)
        end
        entries[#entries + 1] = {
            key = "spell" .. spellID,
            title = name or ("Spell " .. spellID),
            color = { 0.6, 0.8, 1 },
            secure = { type = "spell", value = spellID, icon = icon },
            OnEnter = function(row)
                GameTooltip:SetOwner(row, "ANCHOR_LEFT")
                GameTooltip:SetSpellByID(spellID)
                GameTooltip:Show()
            end,
        }
    end
    for _, s in ipairs(allSpellInfo or {}) do
        Add(s.spellID, s.spellName or s.name, s.spellIcon or s.icon)
    end
    -- delves: the tiered entrance's active spells
    if C_ScenarioInfo.IsTieredEntranceScenario and C_ScenarioInfo.IsTieredEntranceScenario() then
        for _, spellID in ipairs(C_ScenarioInfo.GetTieredEntranceActiveSpells() or {}) do
            Add(spellID)
        end
    end
    return entries
end

-------------------------------------------------------------------
-- Bonus steps (Blizzard showed these in its bonus objective module)
-------------------------------------------------------------------
local function StepComplete(step)
    local _, _, numCriteria = C_Scenario.GetStepInfo(step)
    for i = 1, numCriteria or 0 do
        local c = C_ScenarioInfo.GetCriteriaInfoByStep(step, i)
        if c and not c.completed then return false end
    end
    return true
end

local function BonusEntries()
    local entries = {}
    -- a step that supersedes another stays hidden until that one is done
    local waitsFor = {}
    for _, pair in ipairs(C_Scenario.GetSupersededObjectives() or {}) do
        local step, superseded = pair[1] or pair.scenarioBonusStepID, pair[2] or pair.supersededBonusStepID
        if step and superseded then waitsFor[step] = superseded end
    end
    for _, step in ipairs(C_Scenario.GetBonusSteps() or {}) do
        local name, description, numCriteria, failed, _, _, shouldShow = C_Scenario.GetStepInfo(step)
        if shouldShow and not (waitsFor[step] and not StepComplete(waitsFor[step])) then
            local lines = {}
            for i = 1, numCriteria or 0 do
                local c = C_ScenarioInfo.GetCriteriaInfoByStep(step, i)
                if c then lines[#lines + 1] = CriterionLine(c) end
            end
            if #lines == 0 and description and description ~= "" then
                lines[1] = { text = description }
            end
            entries[#entries + 1] = {
                key = "bonusstep" .. step,
                title = name,
                color = failed and { 1, 0.3, 0.3 } or { 0.9, 0.75, 0.2 },
                lines = lines,
            }
        end
    end
    return entries
end

-------------------------------------------------------------------
-- Mythic+
-------------------------------------------------------------------
-- The clock: GetWorldElapsedTimers lists the running world timers, and the
-- one of type ChallengeMode is the key's; its limit is the third return of
-- GetMapUIInfo. A key is timed within 100% of the limit, +2 within 80% and
-- +3 within 60% - Blizzard's tracker does not show these, the thresholds
-- are the game's rule for keystone upgrades.
local CHALLENGE_TIMER = Enum.WorldElapsedTimerTypes and Enum.WorldElapsedTimerTypes.ChallengeMode or 1

local function ChallengeElapsed()
    for _, timerID in ipairs({ GetWorldElapsedTimers() }) do
        local _, elapsed, timerType = GetWorldElapsedTime(timerID)
        if timerType == CHALLENGE_TIMER then return elapsed end
    end
    return nil
end

local function KeystoneEntry()
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    if not mapID then return nil end
    local name, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
    local level, affixes = C_ChallengeMode.GetActiveKeystoneInfo()
    local elapsed = ChallengeElapsed() or 0
    ns.ticking.scenario = true

    local lines = {}
    if timeLimit and timeLimit > 0 then
        local left = timeLimit - elapsed
        lines[#lines + 1] = {
            text = ("%s / %s%s"):format(Clock(elapsed), Clock(timeLimit), left < 0 and "  (over time)" or ""),
            color = left < 0 and { 1, 0.3, 0.3 } or nil,
            bar = math.min(1, elapsed / timeLimit),
        }
        local plus3, plus2 = timeLimit * 0.6 - elapsed, timeLimit * 0.8 - elapsed
        if plus3 > 0 then lines[#lines + 1] = { text = "+3 within " .. Clock(plus3) } end
        if plus2 > 0 then lines[#lines + 1] = { text = "+2 within " .. Clock(plus2) } end
    end
    local deaths, timeLost = C_ChallengeMode.GetDeathCount()
    if deaths and deaths > 0 then
        lines[#lines + 1] = { text = ("%d deaths, -%s"):format(deaths, Clock(timeLost or 0)) }
    end
    local names = {}
    for _, affixID in ipairs(affixes or {}) do
        local affixName = C_ChallengeMode.GetAffixInfo(affixID)
        if affixName then names[#names + 1] = affixName end
    end
    if #names > 0 then lines[#lines + 1] = { text = table.concat(names, ", ") } end

    return {
        key = "keystone",
        title = ("+%d %s"):format(level or 0, name or ""),
        color = { 1, 0.82, 0 },
        lines = lines,
    }
end

-------------------------------------------------------------------
-- The section
-------------------------------------------------------------------
-- the eye on the stage, when Blizzard's tracker would show one
local function FindScenarioGroup(scenarioID)
    if scenarioID and C_LFGList.CanCreateScenarioGroup and C_LFGList.CanCreateScenarioGroup(scenarioID) then
        return { kind = "scenario", id = scenarioID }
    end
    return nil
end

local function Collect()
    ns.ticking.scenario = nil
    local entries = {}
    local function Add(e) if e then entries[#entries + 1] = e end end

    -- the 13th return is the scenario's ID (Blizzard's tracker reads it so)
    local name, currentStage, numStages, _, _, _, _, _, _, _, _, _, scenarioID = C_Scenario.GetInfo()
    if not name or not numStages or numStages == 0 then
        return entries
    end

    Add(KeystoneEntry())

    if currentStage and currentStage <= numStages then
        local stageName, _, _, _, _, _, _, _, allSpellInfo, _, _, widgetSetID = C_Scenario.GetStepInfo()
        Add(DelveEntry(widgetSetID))

        local title = name
        if numStages > 1 then
            title = ("%s - %d/%d %s"):format(name, currentStage, numStages, stageName or "")
        elseif stageName and stageName ~= "" and stageName ~= name then
            title = name .. " - " .. stageName
        end
        -- the scenario's fixed widget sets frame the stage's own lines
        -- (the stage's own set holds the delve header, drawn above, and
        -- may hold more widgets - bars, texts - which go here too)
        local lines = ns.WidgetLines("scenario", SCENARIO_TOP_SET)
        ns.WidgetLines("scenario", widgetSetID, lines)
        for _, l in ipairs(showCriteria and CriteriaLines() or {}) do lines[#lines + 1] = l end
        ns.WidgetLines("scenario", SCENARIO_BOTTOM_SET, lines)
        Add({ key = "stage", title = title, lines = lines, findGroup = FindScenarioGroup(scenarioID) })
        if showCriteria then
            for _, e in ipairs(SpellEntries(allSpellInfo)) do Add(e) end
        end
    else
        Add({ key = "stage", title = name, lines = { { text = COMPLETE or "Complete", done = true } } })
    end

    for _, e in ipairs(BonusEntries()) do Add(e) end
    return entries
end

ns.RegisterSection("scenario", {
    title = "Scenario",
    order = 10,
    Collect = Collect,
    Init = function()
        if C_Scenario.ShouldShowCriteria then showCriteria = C_Scenario.ShouldShowCriteria() end
    end,
})

local ev = CreateFrame("Frame")
for _, e in ipairs({
    "SCENARIO_UPDATE", "SCENARIO_CRITERIA_UPDATE", "SCENARIO_COMPLETED", "SCENARIO_SPELL_UPDATE",
    "SCENARIO_BONUS_VISIBILITY_UPDATE", "SCENARIO_CRITERIA_SHOW_STATE_UPDATE", "CRITERIA_COMPLETE",
    "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET",
    "CHALLENGE_MODE_DEATH_COUNT_UPDATED", "WORLD_STATE_TIMER_START", "WORLD_STATE_TIMER_STOP",
    "ACTIVE_DELVE_DATA_UPDATE",
}) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, event, arg)
    if event == "SCENARIO_CRITERIA_SHOW_STATE_UPDATE" then showCriteria = arg and true or false end
    ns.RequestUpdate()
end)

local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Extras: what Plumber's tooltip modules added, the parts still alive
-------------------------------------------------------------------
-- Part of replacing Plumber (owner's decision, 2026-10-01). Read from
-- Plumber 1.9.4 (GameTooltip_ItemQuest.lua, ProfessionsBook.lua,
-- GameTooltip_Key.lua) and rebuilt on this module's rules: lines are only
-- ADDED from TooltipDataProcessor post-calls - Plumber also calls Show(),
-- rebuilds tooltips and rewrites Blizzard's lines, none of which is done
-- here (see core.lua).
--
-- Left out on purpose: Plumber's delve cache lines (its item and quest
-- lists are The War Within's and stale in Midnight), reputation items and
-- transmog ensembles (big hand-kept tables, planned separately), the
-- Ctrl-click "show in quest log" (opening the quest log from our code
-- taints it, see DeckUI_Quests/quests.lua).
-------------------------------------------------------------------
local Plain = ns.Plain
local GOLD = { 1, 0.82, 0 }
local GREEN = { 0.1, 1, 0.1 }

-------------------------------------------------------------------
-- Items that start a quest: which quest, and how far it is
-------------------------------------------------------------------
-- Only bag items know their quest (C_Container.GetContainerItemQuestInfo
-- wants bag and slot), so this reads which bag slot the tooltip is
-- built for from Blizzard's processingInfo - read, never written.
local QUEST_ITEM_CLASS = Enum.ItemClass and Enum.ItemClass.Questitem or 12

-- the quest's description: the line Blizzard's quest link tooltip shows
-- under the title (the fourth once the quest is taken, else the third)
local function QuestDescription(questID)
    local data = C_TooltipInfo.GetHyperlink(("quest:%d"):format(questID))
    local line = data and data.lines and data.lines[C_QuestLog.IsOnQuest(questID) and 4 or 3]
    local text = line and line.leftText
    if text and Plain(text) and text ~= "" then return text end
end

local function QuestItemLines(tooltip, itemID)
    local classID = select(6, C_Item.GetItemInfoInstant(itemID))
    if classID ~= QUEST_ITEM_CLASS then return end
    local info = tooltip.processingInfo
    local args = info and info.getterName == "GetBagItem" and info.getterArgs
    if not (args and args[1] and args[2]) then return end
    local quest = C_Container.GetContainerItemQuestInfo(args[1], args[2])
    local questID = quest and quest.questID
    if not questID then return end

    local title = C_QuestLog.GetTitleForQuestID(questID)
    if not title then return end
    tooltip:AddLine(" ")
    tooltip:AddLine(title, GOLD[1], GOLD[2], GOLD[3], true)
    if C_QuestLog.IsOnQuest(questID) then
        if C_QuestLog.ReadyForTurnIn(questID) then
            tooltip:AddLine(QUEST_WATCH_QUEST_READY or "Ready for turn-in", GREEN[1], GREEN[2], GREEN[3], true)
        else
            tooltip:AddLine(QUEST_TOOLTIP_ACTIVE or "You are on this quest", GREEN[1], GREEN[2], GREEN[3], true)
        end
    elseif C_QuestLog.IsQuestFlaggedCompleted(questID) then
        tooltip:AddLine(QUEST_COMPLETE or "Completed", 0.5, 0.5, 0.5, true)
    end
    local desc = QuestDescription(questID)
    if desc then tooltip:AddLine(desc, 1, 1, 1, true) end
    if IsShiftKeyDown() then
        tooltip:AddDoubleLine("Quest ID", tostring(questID), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
    end
end

-------------------------------------------------------------------
-- Profession spells: knowledge points not spent yet
-------------------------------------------------------------------
-- Unspent knowledge is the trait currency of each specialization tree of
-- the profession, counted once per currency (the trees share them). The
-- spell is told apart by its name, which is the profession's name.
local knowledge = {}   -- profession name -> unspent points, until something changes

local function SkillLineFor(profIndex)
    local name = profIndex and select(11, GetProfessionInfo(profIndex))
    if not name or name == "" then return end
    for _, skillLine in ipairs(C_TradeSkillUI.GetAllProfessionTradeSkillLines() or {}) do
        local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLine)
        if info and info.professionName == name then return skillLine end
    end
end

local function Unspent(profIndex)
    local skillLine = SkillLineFor(profIndex)
    if not skillLine then return 0 end
    local configID = C_ProfSpecs.GetConfigIDForSkillLine(skillLine)
    if not configID or configID == 0 then return 0 end
    local total, seen = 0, {}
    for _, treeID in ipairs(C_ProfSpecs.GetSpecTabIDsForSkillLine(skillLine) or {}) do
        local tab = C_ProfSpecs.GetTabInfo(treeID)
        local currency = tab and C_ProfSpecs.GetSpendCurrencyForPath(tab.rootNodeID)
        if currency and not seen[currency] then
            seen[currency] = true
            for _, c in ipairs(C_Traits.GetTreeCurrencyInfo(configID, treeID, false) or {}) do
                if c.traitCurrencyID == currency and Plain(c.quantity) then
                    total = total + (c.quantity or 0)
                end
            end
        end
    end
    return total
end

local function KnowledgeLine(tooltip, spellID)
    local spellName = C_Spell.GetSpellName(spellID)
    if not spellName then return end
    local prof1, prof2 = GetProfessions()
    for _, index in ipairs({ prof1, prof2 }) do
        local name = GetProfessionInfo(index)
        if name == spellName then
            if knowledge[name] == nil then knowledge[name] = Unspent(index) end
            local n = knowledge[name]
            if n > 0 then
                tooltip:AddLine(" ")
                tooltip:AddLine(("%d unspent knowledge"):format(n), GOLD[1], GOLD[2], GOLD[3], true)
            end
            return
        end
    end
end

-------------------------------------------------------------------
-- The rare chest in a delve: the key it wants
-------------------------------------------------------------------
-- The world object carries the name of item 228942; it takes one
-- Restored Coffer Key (currency 3028). Both are The War Within's numbers
-- that Plumber still uses on 12.1 - if Midnight's delves changed them,
-- the line simply never shows.
local CHEST_ITEM, KEY_CURRENCY = 228942, 3028

local function InDelve()
    return C_PartyInfo.IsPartyWalkIn and C_PartyInfo.IsPartyWalkIn()
end

local function ChestKeyLine(tooltip, data)
    if not InDelve() then return end
    local name = data.lines and data.lines[1] and data.lines[1].leftText
    if not (name and Plain(name)) then return end
    local chest = C_Item.GetItemNameByID(CHEST_ITEM)
    if not chest or name ~= chest then return end
    local key = C_CurrencyInfo.GetCurrencyInfo(KEY_CURRENCY)
    if not (key and Plain(key.quantity)) then return end
    local have = key.quantity or 0
    local r, g, b = 1, 1, 1
    if have < 1 then r, g, b = 1, 0.13, 0.13 end
    tooltip:AddDoubleLine(key.name or "Key", ("%d / 1 |T%d:14:14|t"):format(have, key.iconFileID or 0), r, g, b, r, g, b)
end

-------------------------------------------------------------------
-- Wiring
-------------------------------------------------------------------
local function Styled(tooltip)
    return tooltip == GameTooltip or tooltip == ItemRefTooltip
end

function ns.InitExtras()
    local T = Enum.TooltipDataType
    C_Item.GetItemNameByID(CHEST_ITEM)   -- ask for the name early, it is cached after

    TooltipDataProcessor.AddTooltipPostCall(T.Item, function(tooltip, data)
        if not (Styled(tooltip) and data and DeckTooltipDB.questItems) then return end
        if Plain(data.id) and data.id then QuestItemLines(tooltip, data.id) end
    end)
    TooltipDataProcessor.AddTooltipPostCall(T.Spell, function(tooltip, data)
        if not (Styled(tooltip) and data and DeckTooltipDB.knowledge) then return end
        if Plain(data.id) and data.id then KnowledgeLine(tooltip, data.id) end
    end)
    if T.Object then
        TooltipDataProcessor.AddTooltipPostCall(T.Object, function(tooltip, data)
            if not (Styled(tooltip) and data and DeckTooltipDB.chestKeys) then return end
            ChestKeyLine(tooltip, data)
        end)
    end

    -- knowledge counts are kept until something could have changed them
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "SKILL_LINES_CHANGED", "TRAIT_CONFIG_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED" }) do
        ev:RegisterEvent(e)
    end
    ev:SetScript("OnEvent", function() wipe(knowledge) end)
end

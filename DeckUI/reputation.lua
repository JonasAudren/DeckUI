local D = DeckUI

-------------------------------------------------------------------
-- A faction's standing, the way the game's reputation pane shows it
-------------------------------------------------------------------
-- Shared by the FFXIV EXP bar (DeckUI_Orbs, the watched faction at the
-- level cap) and the tooltip (DeckUI_Tooltip, items and currencies that
-- grant reputation) - added 2026-10-09. One faction can be any of four
-- kinds, asked in this order: paragon (past the top of renown or exalted),
-- renown (the expansion's major factions), friendship (a named ladder of
-- its own), and the classic hated..exalted. The player's own data: plain
-- numbers.
--
-- D.FactionStatus(factionID) -> { name, standing, cur, max, r, g, b }
-- or nil when the game does not know the faction for this character.
-------------------------------------------------------------------
local PARAGON = { 0.4, 0.75, 1 }
local RENOWN = { 0, 0.75, 1 }
local FRIEND = { 0.3, 0.85, 0.4 }

local function Result(name, standing, cur, max, colour)
    if not max or max <= 0 then cur, max = 1, 1 end
    return { name = name, standing = standing, cur = math.max(0, math.min(cur or 0, max)), max = max,
             r = colour[1], g = colour[2], b = colour[3] }
end

function D.FactionStatus(factionID)
    if not factionID or not C_Reputation.GetFactionDataByID then return nil end
    local data = C_Reputation.GetFactionDataByID(factionID)
    if not data or not data.name or data.name == "" then return nil end
    local name = data.name

    if C_Reputation.IsFactionParagon and C_Reputation.IsFactionParagon(factionID) then
        local value, threshold, _, hasReward = C_Reputation.GetFactionParagonInfo(factionID)
        if value and threshold and threshold > 0 then
            return Result(name, hasReward and "Paragon (reward waiting)" or "Paragon",
                value % threshold, threshold, PARAGON)
        end
    end

    if C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(factionID) then
        local major = C_MajorFactions.GetMajorFactionData(factionID)
        if major then
            local cur, max = major.renownReputationEarned or 0, major.renownLevelThreshold or 1
            if C_MajorFactions.HasMaximumRenown and C_MajorFactions.HasMaximumRenown(factionID) then cur = max end
            return Result(name, ("Renown %d"):format(major.renownLevel or 0), cur, max, RENOWN)
        end
    end

    local friend = C_GossipInfo.GetFriendshipReputation and C_GossipInfo.GetFriendshipReputation(factionID)
    if friend and friend.friendshipFactionID and friend.friendshipFactionID > 0 then
        local low = friend.reactionThreshold or 0
        local high = friend.nextThreshold or friend.standing or low
        return Result(name, friend.reaction or "", (friend.standing or 0) - low, high - low, FRIEND)
    end

    local reaction = data.reaction or 4
    local colour = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    colour = colour and { colour.r, colour.g, colour.b } or FRIEND
    local low = data.currentReactionThreshold or 0
    return Result(name, _G["FACTION_STANDING_LABEL" .. reaction] or "",
        (data.currentStanding or 0) - low, (data.nextReactionThreshold or low) - low, colour)
end

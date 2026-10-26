local _, ns = ...
local oUF = ns.oUF

-- sourced from Blizzard_UnitFrame/Mainline/TargetFrame.lua
local MAX_BOSS_FRAMES = _G.MAX_BOSS_FRAMES or 5

-- sourced from Blizzard_FrameXMLBase/Shared/Constants.lua
local MEMBERS_PER_RAID_GROUP = _G.MEMBERS_PER_RAID_GROUP or 5

local isArenaHooked = false
local isBossHooked = false
local isPartyHooked = false

-- DeckUI: Mists. Mists of Pandaria Classic has no SetRolesets, so its frames
-- are hidden the way oUF 13 did: hidden, parked under a hidden parent and
-- kept there (taken from oUF 13.4.5's blizzard.lua).
local hiddenParent, hookedFrames, looseFrames = nil, {}, {}
local function park(frame, doNotReparent)
	frame:Hide()
	if(doNotReparent) then return end

	if(not hiddenParent) then
		hiddenParent = CreateFrame('Frame', nil, UIParent)
		hiddenParent:SetAllPoints()
		hiddenParent:Hide()

		local watcher = CreateFrame('Frame')
		watcher:RegisterEvent('PLAYER_REGEN_ENABLED')
		watcher:SetScript('OnEvent', function()
			for loose in next, looseFrames do
				loose:SetParent(hiddenParent)
			end
			table.wipe(looseFrames)
		end)
	end

	frame:SetParent(hiddenParent)
	if(not hookedFrames[frame]) then
		hookedFrames[frame] = true
		hooksecurefunc(frame, 'SetParent', function(self, parent)
			if(parent ~= hiddenParent) then
				if(InCombatLockdown() and self:IsProtected()) then
					looseFrames[self] = true
				else
					self:SetParent(hiddenParent)
				end
			end
		end)
	end
end

local function handleFrame(baseName, doNotReparent)
	local frame
	if(type(baseName) == 'string') then
		frame = _G[baseName]
	else
		frame = baseName
	end

	if(frame) then
		frame:UnregisterAllEvents()
		if(frame.SetRolesets) then
			frame:SetRolesets('alwaysBlocked')
		else
			park(frame, doNotReparent) -- DeckUI: Mists
		end

		local health = frame.healthBar or frame.healthbar or frame.HealthBar or (frame.HealthBarsContainer and frame.HealthBarsContainer.healthBar)
		if(health) then
			health:UnregisterAllEvents()
		end

		local power = frame.manabar or frame.ManaBar
		if(power) then
			power:UnregisterAllEvents()
		end

		local castbar = frame.castBar or frame.spellbar or frame.CastingBarFrame
		if(castbar) then
			castbar:UnregisterAllEvents()
		end

		local altpowerbar = frame.powerBarAlt or frame.PowerBarAlt
		if(altpowerbar) then
			altpowerbar:UnregisterAllEvents()
		end

		local buffFrame = frame.BuffFrame or frame.AurasFrame
		if(buffFrame) then
			buffFrame:UnregisterAllEvents()
		end

		local petFrame = frame.petFrame or frame.PetFrame
		if(petFrame) then
			petFrame:UnregisterAllEvents()
		end

		local totFrame = frame.totFrame
		if(totFrame) then
			totFrame:UnregisterAllEvents()
		end

		local ccRemoverFrame = frame.CcRemoverFrame
		if(ccRemoverFrame) then
			ccRemoverFrame:UnregisterAllEvents()
		end

		local debuffFrame = frame.DebuffFrame
		if(debuffFrame) then
			debuffFrame:UnregisterAllEvents()
		end
	end
end

function oUF:DisableBlizzard(unit)
	if(not unit) then return end

	if(unit == 'player') then
		handleFrame(PlayerFrame)
	elseif(unit == 'pet') then
		handleFrame(PetFrame)
	elseif(unit == 'target') then
		handleFrame(TargetFrame)
	elseif(unit == 'focus') then
		handleFrame(FocusFrame)
	elseif(unit:match('boss%d?$')) then
		if(not isBossHooked) then
			isBossHooked = true

			-- it's needed because the layout manager can bring frames that are
			-- controlled by containers back from the dead when a user chooses
			-- to revert all changes
			-- for now I'll just reparent it, but more might be needed in the
			-- future, watch it
			handleFrame(BossTargetFrameContainer)

			for i = 1, MAX_BOSS_FRAMES do
				-- DeckUI: Mists - not reparented, as in oUF 13: their container's
				-- layout breaks on a frame without a size
				handleFrame('Boss' .. i .. 'TargetFrame', true)
			end
		end
	elseif(unit:match('party%d?$')) then
		if(not isPartyHooked) then
			isPartyHooked = true

			handleFrame(PartyFrame)

			-- DeckUI: Mists - its PartyFrame may come without the pool
			if(PartyFrame and PartyFrame.PartyMemberFramePool) then
				for frame in PartyFrame.PartyMemberFramePool:EnumerateActive() do
					handleFrame(frame, true)
				end
			end

			for i = 1, MEMBERS_PER_RAID_GROUP do
				handleFrame('CompactPartyFrameMember' .. i)
			end
		end
	elseif(unit:match('arena%d?$')) then
		if(not isArenaHooked) then
			isArenaHooked = true

			-- DeckUI: Mists - neither container exists there
			if(CompactArenaFrame) then
				handleFrame(CompactArenaFrame)

				for _, frame in next, CompactArenaFrame.memberUnitFrames do
					handleFrame(frame)
				end
			end

			-- old arena frames, they're still used for flag carriers etc in battlegrounds
			if(ArenaEnemyMatchFramesContainer) then
				handleFrame(ArenaEnemyMatchFramesContainer)

				for _, frame in next, ArenaEnemyMatchFramesContainer.UnitFrames do
					handleFrame(frame)
				end
			end
		end
	elseif(unit:match('nameplate%d?%d?%d?$')) then
		local frame = C_NamePlate.GetNamePlateForUnit(unit)
		handleFrame(frame.UnitFrame, true) -- DeckUI: Mists - plates are never reparented
	end
end

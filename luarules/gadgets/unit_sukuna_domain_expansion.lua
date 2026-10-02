local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Sukuna Domain Expansion",
		desc = "Malevolent Shrine: a timed domain that slashes every enemy inside it",
		author = "Beyond All Reason Modded",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local DomainExpansion = VFS.Include("common/modded/domain_expansion.lua")

if gadgetHandler:IsSyncedCode() then
	local CMD_DOMAIN_EXPANSION = GameCMD.DOMAIN_EXPANSION

	local spAddUnitDamage = Spring.AddUnitDamage
	local spGetGaiaTeamID = Spring.GetGaiaTeamID
	local spGetGameFrame = Spring.GetGameFrame
	local spGetGroundHeight = Spring.GetGroundHeight
	local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
	local spGetUnitIsDead = Spring.GetUnitIsDead
	local spGetUnitPosition = Spring.GetUnitPosition
	local spGetUnitTeam = Spring.GetUnitTeam
	local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
	local spSendMessageToTeam = Spring.SendMessageToTeam
	local spSetUnitRulesParam = Spring.SetUnitRulesParam
	local spSpawnCEG = Spring.SpawnCEG
	local spUseUnitResource = Spring.UseUnitResource

	local mathCos = math.cos
	local mathRandom = math.random
	local mathSin = math.sin

	local gameSpeed = Game.gameSpeed
	local TICK_FRAMES = 6
	local CAST_FRAMES = gameSpeed
	local FLOOR_FRAMES = 15
	local BOUNDARY_POINTS = 28
	local MAX_HIT_CEGS_PER_TICK = 8

	local domainDefs = DomainExpansion.ParseDomainDefs(UnitDefs, WeaponDefNames, gameSpeed, TICK_FRAMES)
	if not next(domainDefs) then
		return false
	end

	local gaiaTeamID = spGetGaiaTeamID()

	local domainCmdDesc = {
		id = CMD_DOMAIN_EXPANSION,
		type = CMDTYPE.ICON,
		name = "Domain Expansion",
		action = "domainexpansion",
		tooltip = "Domain Expansion: Malevolent Shrine. Slashes every enemy inside the domain.",
	}

	local readyFrame = {} -- unitID -> frame the domain can be cast again
	local pendingCasts = {} -- domains waiting for the hand sign to finish
	local activeDomains = {}

	local function addCommand(unitID)
		if not Spring.FindUnitCmdDesc(unitID, CMD_DOMAIN_EXPANSION) then
			Spring.InsertUnitCmdDesc(unitID, domainCmdDesc)
		end
	end

	local function tryCast(unitID, unitDefID, teamID)
		local def = domainDefs[unitDefID]
		if spGetUnitIsBeingBuilt(unitID) then
			return
		end
		local frame = spGetGameFrame()
		local canCast, waitFrames = DomainExpansion.CanCast(readyFrame[unitID], frame)
		if not canCast then
			spSendMessageToTeam(teamID, "Domain Expansion recharging: " .. math.ceil(waitFrames / gameSpeed) .. "s")
			return
		end
		if not spUseUnitResource(unitID, "energy", def.energy) then
			spSendMessageToTeam(teamID, "Domain Expansion needs " .. def.energy .. " energy")
			return
		end

		readyFrame[unitID] = frame + def.cooldownFrames
		spSetUnitRulesParam(unitID, "domain_ready_frame", readyFrame[unitID])

		local env = Spring.UnitScript.GetScriptEnv(unitID)
		if env and env.DomainCast then
			Spring.UnitScript.CallAsUnit(unitID, env.DomainCast, CAST_FRAMES * 1000 / gameSpeed)
		end

		local x, y, z = spGetUnitPosition(unitID)
		pendingCasts[#pendingCasts + 1] = {
			ownerID = unitID,
			def = def,
			openFrame = frame + CAST_FRAMES,
			x = x,
			y = y,
			z = z,
			allyTeam = spGetUnitAllyTeam(unitID),
		}
	end

	local function openDomain(cast, frame)
		if spGetUnitIsDead(cast.ownerID) ~= false then
			return
		end
		local def = cast.def
		local domain = {
			ownerID = cast.ownerID,
			def = def,
			x = cast.x,
			y = spGetGroundHeight(cast.x, cast.z),
			z = cast.z,
			allyTeam = cast.allyTeam,
			endFrame = frame + def.durationFrames,
		}
		activeDomains[#activeDomains + 1] = domain
		spSpawnCEG(def.openCeg, domain.x, domain.y, domain.z, 0, 1, 0)
		SendToUnsynced("sukunaDomainOpened", domain.x, domain.y, domain.z)
	end

	local function drawBoundary(domain)
		local radius = domain.def.radius
		for i = 1, BOUNDARY_POINTS do
			local angle = (i / BOUNDARY_POINTS) * 2 * math.pi
			local px = domain.x + radius * mathCos(angle)
			local pz = domain.z + radius * mathSin(angle)
			spSpawnCEG("custom:domain-boundary", px, spGetGroundHeight(px, pz), pz, 0, 1, 0)
		end
		spSpawnCEG(domain.def.floorCeg, domain.x, domain.y, domain.z, 0, 1, 0)
	end

	local function slashDomain(domain)
		local def = domain.def
		local attackerID = spGetUnitIsDead(domain.ownerID) == false and domain.ownerID or -1
		local units = spGetUnitsInCylinder(domain.x, domain.z, def.radius)
		local cegs = 0
		for i = 1, #units do
			local targetID = units[i]
			if
				spGetUnitAllyTeam(targetID) ~= domain.allyTeam
				and spGetUnitTeam(targetID) ~= gaiaTeamID
				and spGetUnitIsDead(targetID) == false
			then
				if cegs < MAX_HIT_CEGS_PER_TICK then
					local tx, ty, tz = spGetUnitPosition(targetID)
					spSpawnCEG("custom:sukuna-slash-large", tx, ty + 8, tz, 0, 1, 0)
					cegs = cegs + 1
				end
				spAddUnitDamage(targetID, def.damagePerTick, 0, attackerID, def.weaponDefID)
			end
		end
		-- slashes carving the empty ground as well
		for _ = 1, 3 do
			local angle = mathRandom() * 2 * math.pi
			local dist = mathRandom() * def.radius
			local px = domain.x + dist * mathCos(angle)
			local pz = domain.z + dist * mathSin(angle)
			spSpawnCEG("custom:sukuna-slash-large", px, spGetGroundHeight(px, pz) + 6, pz, 0, 1, 0)
		end
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID)
		if domainDefs[unitDefID] then
			tryCast(unitID, unitDefID, teamID)
		end
		return false
	end

	function gadget:GameFrame(frame)
		for i = #pendingCasts, 1, -1 do
			local cast = pendingCasts[i]
			if frame >= cast.openFrame then
				table.remove(pendingCasts, i)
				openDomain(cast, frame)
			end
		end

		for i = #activeDomains, 1, -1 do
			local domain = activeDomains[i]
			if frame >= domain.endFrame or spGetUnitIsDead(domain.ownerID) ~= false then
				table.remove(activeDomains, i)
			else
				if frame % FLOOR_FRAMES == 0 then
					drawBoundary(domain)
				end
				if frame % TICK_FRAMES == 0 then
					slashDomain(domain)
				end
			end
		end
	end

	function gadget:UnitCreated(unitID, unitDefID)
		if domainDefs[unitDefID] then
			addCommand(unitID)
		end
	end

	function gadget:UnitDestroyed(unitID)
		readyFrame[unitID] = nil
	end

	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_DOMAIN_EXPANSION)
		gadgetHandler:RegisterAllowCommand(CMD_DOMAIN_EXPANSION)
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			if domainDefs[Spring.GetUnitDefID(unitID)] then
				addCommand(unitID)
			end
		end
	end
else
	local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
	local spGetSpectatingState = Spring.GetSpectatingState
	local spIsPosInLos = Spring.IsPosInLos
	local spPlaySoundFile = Spring.PlaySoundFile

	local function domainOpened(_, x, y, z)
		local _, fullView = spGetSpectatingState()
		if fullView or spIsPosInLos(x, y, z, spGetMyAllyTeamID()) then
			spPlaySoundFile("sounds/raptors/bigraptorroar.wav", 1.5, x, y, z, "sfx")
			spPlaySoundFile("sounds/weapons/junofir2.wav", 1.2, x, y, z, "sfx")
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("sukunaDomainOpened", domainOpened)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("sukunaDomainOpened")
	end
end

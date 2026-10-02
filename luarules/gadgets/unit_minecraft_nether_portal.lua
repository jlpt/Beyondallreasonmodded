local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Minecraft Nether Portals",
		desc = "Allied ground units that walk into a nether portal come out of the next portal of their ally team",
		author = "Beyond All Reason Modded",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local NetherPortal = VFS.Include("common/modded/nether_portal.lua")

if gadgetHandler:IsSyncedCode() then
	local spGetGroundHeight = Spring.GetGroundHeight
	local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spGetUnitBuildFacing = Spring.GetUnitBuildFacing
	local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
	local spGetUnitIsDead = Spring.GetUnitIsDead
	local spGetUnitPosition = Spring.GetUnitPosition
	local spGetUnitTransporter = Spring.GetUnitTransporter
	local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
	local spGiveOrderToUnit = Spring.GiveOrderToUnit
	local spSetUnitPosition = Spring.SetUnitPosition
	local spSetUnitVelocity = Spring.SetUnitVelocity
	local spSpawnCEG = Spring.SpawnCEG
	local spTestMoveOrder = Spring.TestMoveOrder

	local CMD_GUARD = CMD.GUARD
	local CMD_REMOVE = CMD.REMOVE
	local MOVE_COMMANDS = {
		[CMD.MOVE] = true,
		[CMD.FIGHT] = true,
		[CMD.PATROL] = true,
		[GameCMD.RAW_MOVE] = true,
	}

	local gameSpeed = Game.gameSpeed
	local CHECK_FRAMES = 5
	local TRAVEL_COOLDOWN_FRAMES = 3 * gameSpeed
	local EXIT_DISTANCE = 44
	local EXIT_LATERALS = { 0, 18, -18, 36, -36 }

	local portalDefs = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.customParams.nether_portal then
			portalDefs[unitDefID] = tonumber(unitDef.customParams.portal_radius) or 30
		end
	end
	if not next(portalDefs) then
		return false
	end

	-- units that can walk through a portal
	local travellerDefs = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if not unitDef.canFly and not unitDef.isImmobile and (unitDef.speed or 0) > 0 and not portalDefs[unitDefID] then
			travellerDefs[unitDefID] = true
		end
	end

	local networks = {} -- allyTeam -> portal unitIDs in the order they were finished
	local portals = {} -- unitID -> { allyTeam, x, y, z, facing, radius, linked }
	local travelCooldown = {} -- unitID -> frame it may use a portal again
	local exitCounter = 0

	local function setLinked(portalID, linked)
		local portal = portals[portalID]
		if portal.linked == linked then
			return
		end
		portal.linked = linked
		local env = Spring.UnitScript.GetScriptEnv(portalID)
		if env and env.SetLinked then
			Spring.UnitScript.CallAsUnit(portalID, env.SetLinked, linked)
		end
	end

	local function refreshLinks(allyTeam)
		local network = networks[allyTeam]
		if not network then
			return
		end
		local linked = #network >= 2
		for i = 1, #network do
			setLinked(network[i], linked)
		end
	end

	local function addPortal(unitID, unitDefID)
		local allyTeam = spGetUnitAllyTeam(unitID)
		local x, y, z = spGetUnitPosition(unitID)
		portals[unitID] = {
			allyTeam = allyTeam,
			x = x,
			y = y,
			z = z,
			facing = spGetUnitBuildFacing(unitID) or 0,
			radius = portalDefs[unitDefID],
			linked = false,
		}
		networks[allyTeam] = networks[allyTeam] or {}
		table.insert(networks[allyTeam], unitID)
		refreshLinks(allyTeam)
	end

	local function removePortal(unitID)
		local portal = portals[unitID]
		if not portal then
			return
		end
		portals[unitID] = nil
		local network = networks[portal.allyTeam]
		for i = #network, 1, -1 do
			if network[i] == unitID then
				table.remove(network, i)
			end
		end
		refreshLinks(portal.allyTeam)
	end

	local function findExit(unitDefID, exit)
		exitCounter = exitCounter + 1
		for side = 1, -1, -2 do
			for i = 1, #EXIT_LATERALS do
				local lateral = EXIT_LATERALS[(i + exitCounter) % #EXIT_LATERALS + 1]
				local x, z = NetherPortal.ExitPosition(exit.x, exit.z, exit.facing, side * EXIT_DISTANCE, lateral)
				local y = spGetGroundHeight(x, z)
				if spTestMoveOrder(unitDefID, x, y, z) then
					return x, y, z
				end
			end
		end
		return nil
	end

	local function teleport(unitID, unitDefID, entry, exitID, frame, cmdTag)
		local x, y, z = findExit(unitDefID, portals[exitID])
		if not x then
			return
		end
		local ux, uy, uz = spGetUnitPosition(unitID)
		spSpawnCEG("custom:nether-teleport", ux, uy, uz, 0, 1, 0)
		spSetUnitPosition(unitID, x, z)
		spSetUnitVelocity(unitID, 0, 0, 0)
		spSpawnCEG("custom:nether-teleport", x, y, z, 0, 1, 0)
		if cmdTag then
			spGiveOrderToUnit(unitID, CMD_REMOVE, { cmdTag }, 0)
		end
		travelCooldown[unitID] = frame + TRAVEL_COOLDOWN_FRAMES
		SendToUnsynced("minecraftPortalTravel", entry.x, entry.y, entry.z, x, y, z)
	end

	local function checkPortal(portalID, portal, frame)
		local exitID = NetherPortal.NextPortal(networks[portal.allyTeam], portalID)
		if not exitID then
			return
		end
		local units = spGetUnitsInCylinder(portal.x, portal.z, portal.radius)
		for i = 1, #units do
			local unitID = units[i]
			local unitDefID = spGetUnitDefID(unitID)
			if
				travellerDefs[unitDefID]
				and spGetUnitAllyTeam(unitID) == portal.allyTeam
				and (travelCooldown[unitID] or 0) <= frame
				and not spGetUnitIsBeingBuilt(unitID)
				and not spGetUnitTransporter(unitID)
			then
				local cmdID, _, cmdTag, p1, p2, p3 = spGetUnitCurrentCommand(unitID)
				local command = cmdID and { id = cmdID, params = { p1, p2, p3 } } or nil
				if
					NetherPortal.WantsToEnter(
						command,
						portalID,
						portal.x,
						portal.z,
						portal.radius * 2,
						CMD_GUARD,
						MOVE_COMMANDS
					)
				then
					teleport(unitID, unitDefID, portal, exitID, frame, cmdTag)
				end
			end
		end
	end

	function gadget:GameFrame(frame)
		if frame % CHECK_FRAMES ~= 0 then
			return
		end
		for portalID, portal in pairs(portals) do
			if portal.linked and spGetUnitIsDead(portalID) == false then
				checkPortal(portalID, portal, frame)
			end
		end
	end

	function gadget:UnitFinished(unitID, unitDefID)
		if portalDefs[unitDefID] then
			addPortal(unitID, unitDefID)
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID)
		travelCooldown[unitID] = nil
		if portalDefs[unitDefID] then
			removePortal(unitID)
		end
	end

	function gadget:UnitGiven(unitID, unitDefID)
		if portals[unitID] then
			removePortal(unitID)
			addPortal(unitID, unitDefID)
		end
	end

	function gadget:Initialize()
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			local unitDefID = spGetUnitDefID(unitID)
			if portalDefs[unitDefID] and not spGetUnitIsBeingBuilt(unitID) then
				addPortal(unitID, unitDefID)
			end
		end
	end
else
	local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
	local spGetSpectatingState = Spring.GetSpectatingState
	local spIsPosInLos = Spring.IsPosInLos
	local spPlaySoundFile = Spring.PlaySoundFile

	local function canHear(x, y, z)
		local _, fullView = spGetSpectatingState()
		return fullView or spIsPosInLos(x, y, z, spGetMyAllyTeamID())
	end

	local function portalTravel(_, x1, y1, z1, x2, y2, z2)
		if canHear(x1, y1, z1) then
			spPlaySoundFile("sounds/weapons/junohit2.wav", 0.6, x1, y1, z1, "sfx")
		end
		if canHear(x2, y2, z2) then
			spPlaySoundFile("sounds/weapons/junohit2.wav", 0.6, x2, y2, z2, "sfx")
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("minecraftPortalTravel", portalTravel)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("minecraftPortalTravel")
	end
end

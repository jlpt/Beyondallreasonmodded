local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Minecraft TNT",
		desc = "TNT placed by Steve lights its fuse when enemies come close or when it is hit, and spares allies",
		author = "Beyond All Reason Modded",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	local spAreTeamsAllied = Spring.AreTeamsAllied
	local spDestroyUnit = Spring.DestroyUnit
	local spGetGaiaTeamID = Spring.GetGaiaTeamID
	local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
	local spGetUnitIsDead = Spring.GetUnitIsDead
	local spGetUnitPosition = Spring.GetUnitPosition
	local spGetUnitTeam = Spring.GetUnitTeam
	local spGetUnitsInCylinder = Spring.GetUnitsInCylinder

	local gameSpeed = Game.gameSpeed
	local CHECK_FRAMES = 10
	local CHAIN_FUSE_FRAMES = math.floor(gameSpeed * 0.5)

	local tntDefs = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		local cp = unitDef.customParams
		if cp.tnt_fuse then
			tntDefs[unitDefID] = {
				fuseFrames = math.floor(tonumber(cp.tnt_fuse) * gameSpeed),
				triggerRadius = tonumber(cp.tnt_trigger_radius) or 150,
			}
		end
	end
	local blastDef = WeaponDefNames.mc_tnt_blast
	if not next(tntDefs) or not blastDef then
		return false
	end
	local blastWeaponDefID = blastDef.id

	local gaiaTeamID = spGetGaiaTeamID()

	local armed = {} -- unitID -> tnt def, finished and waiting for an enemy
	local fuses = {} -- unitID -> detonation frame
	local lastBlastTeam -- team of the TNT exploding right now, for blasts reported without an attacker

	local function prime(unitID, fuseFrames, frame)
		if fuses[unitID] then
			return
		end
		armed[unitID] = nil
		fuses[unitID] = frame + fuseFrames
		local env = Spring.UnitScript.GetScriptEnv(unitID)
		if env and env.Prime then
			Spring.UnitScript.CallAsUnit(unitID, env.Prime)
		end
		local x, y, z = spGetUnitPosition(unitID)
		SendToUnsynced("minecraftTntPrimed", x, y, z)
	end

	local function enemyNear(unitID, radius)
		local x, _, z = spGetUnitPosition(unitID)
		local allyTeam = spGetUnitAllyTeam(unitID)
		local units = spGetUnitsInCylinder(x, z, radius)
		for i = 1, #units do
			local otherID = units[i]
			if
				spGetUnitAllyTeam(otherID) ~= allyTeam
				and spGetUnitTeam(otherID) ~= gaiaTeamID
				and not tntDefs[Spring.GetUnitDefID(otherID)]
			then
				return true
			end
		end
		return false
	end

	function gadget:UnitFinished(unitID, unitDefID)
		if tntDefs[unitDefID] then
			armed[unitID] = tntDefs[unitDefID]
		end
	end

	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage)
		local def = tntDefs[unitDefID]
		if def and damage > 0 and not spGetUnitIsBeingBuilt(unitID) then
			prime(unitID, math.min(CHAIN_FUSE_FRAMES, def.fuseFrames), Spring.GetGameFrame())
		end
	end

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, _, _, _, attackerTeam)
		if weaponDefID ~= blastWeaponDefID or tntDefs[unitDefID] then
			return damage, 1
		end
		local blastTeam = attackerTeam or lastBlastTeam
		if blastTeam and spAreTeamsAllied(unitTeam, blastTeam) then
			return 0, 0
		end
		return damage, 1
	end

	function gadget:GameFrame(frame)
		-- blasts prime neighbouring TNT, which adds fuses, so collect before detonating
		local due
		for unitID, detonateFrame in pairs(fuses) do
			if frame >= detonateFrame then
				due = due or {}
				due[#due + 1] = unitID
			end
		end
		if due then
			for i = 1, #due do
				local unitID = due[i]
				fuses[unitID] = nil
				if spGetUnitIsDead(unitID) == false then
					lastBlastTeam = spGetUnitTeam(unitID)
					spDestroyUnit(unitID, true)
					lastBlastTeam = nil
				end
			end
		end

		if frame % CHECK_FRAMES == 0 then
			for unitID, def in pairs(armed) do
				if enemyNear(unitID, def.triggerRadius) then
					prime(unitID, def.fuseFrames, frame)
				end
			end
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
		if tntDefs[unitDefID] then
			armed[unitID] = nil
			fuses[unitID] = nil
		end
	end

	function gadget:Initialize()
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			local def = tntDefs[Spring.GetUnitDefID(unitID)]
			if def and not spGetUnitIsBeingBuilt(unitID) then
				armed[unitID] = def
			end
		end
	end
else
	local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
	local spGetSpectatingState = Spring.GetSpectatingState
	local spIsPosInLos = Spring.IsPosInLos
	local spPlaySoundFile = Spring.PlaySoundFile

	local function tntPrimed(_, x, y, z)
		local _, fullView = spGetSpectatingState()
		if fullView or spIsPosInLos(x, y, z, spGetMyAllyTeamID()) then
			spPlaySoundFile("sounds/weapons/fireburnshort.wav", 1.2, x, y, z, "sfx")
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("minecraftTntPrimed", tntPrimed)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("minecraftTntPrimed")
	end
end

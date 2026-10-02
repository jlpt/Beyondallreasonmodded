local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Fahh On Death",
		desc = "Plays the fahh sound effect whenever a unit dies",
		author = "Beyond All Reason Modded",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local SOUND_FILE = "sounds/modded/fahh.wav"

local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spPlaySoundFile = Spring.PlaySoundFile

local config = {
	volume = 1.0,
	-- seconds between two fahhs, so a big fight does not stack hundreds of them; commanders always get theirs
	minInterval = 0.6,
	onlyCommanders = false,
}

local commanderDefs = {}
local ignoredDefs = {} -- walls, mines, blocks and TNT break or go off, they do not die
for unitDefID, unitDef in pairs(UnitDefs) do
	local cp = unitDef.customParams
	if cp.iscommander then
		commanderDefs[unitDefID] = true
	end
	if cp.objectify or cp.mine or cp.tnt_fuse or unitDef.modCategories.object then
		ignoredDefs[unitDefID] = true
	end
end

local lastPlayed

function widget:UnitDestroyed(unitID, unitDefID)
	if ignoredDefs[unitDefID] or spGetUnitIsBeingBuilt(unitID) then
		return
	end
	-- an evolving unit is replaced, not killed
	if spGetUnitRulesParam(unitID, "unit_evolved") then
		return
	end
	local isCommander = commanderDefs[unitDefID]
	if config.onlyCommanders and not isCommander then
		return
	end
	local now = spGetTimer()
	if not isCommander and lastPlayed and spDiffTimers(now, lastPlayed) < config.minInterval then
		return
	end
	lastPlayed = now
	spPlaySoundFile(SOUND_FILE, config.volume, "ui")
end

function widget:GetConfigData()
	return config
end

function widget:SetConfigData(data)
	for key, value in pairs(data) do
		if config[key] ~= nil and type(value) == type(config[key]) then
			config[key] = value
		end
	end
end

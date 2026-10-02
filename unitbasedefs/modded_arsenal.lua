-- Build options for the modded units: Sukuna and Steve in every bot lab tier, and (with the raptorscavarsenal
-- modoption) the raptor and scavenger rosters for the three player factions.

local scavUnitsForPlayers = require("unitbasedefs/scavenger_units_for_players").Tweaks

local factions = { "arm", "cor", "leg" }

local botLabs = {
	armlab = 1,
	corlab = 1,
	leglab = 1,
	armalab = 2,
	coralab = 2,
	legalab = 2,
	armshltx = 3,
	corgant = 3,
	leggant = 3,
}

local t1Constructors = {
	armcom = true,
	corcom = true,
	legcom = true,
	armck = true,
	corck = true,
	legck = true,
	armcv = true,
	corcv = true,
	legcv = true,
	armca = true,
	corca = true,
	legca = true,
}

local t2Constructors = {
	armack = true,
	corack = true,
	legack = true,
	armacv = true,
	coracv = true,
	legacv = true,
	armaca = true,
	coraca = true,
	legaca = true,
}

local raptorT1Structures = {
	"brood_nest",
	"brood_roost",
	"raptor_turret_basic_t2_v1",
	"raptor_turret_acid_t2_v1",
	"raptor_turret_emp_t2_v1",
	"raptor_turret_antiair_t2_v1",
	"raptor_turret_brood_t2_v1",
	"raptor_turret_burrow_t2_v1",
}

local raptorT2Structures = {
	"brood_lair",
	"brood_throne",
	"raptor_turret_basic_t3_v1",
	"raptor_turret_acid_t3_v1",
	"raptor_turret_emp_t3_v1",
	"raptor_turret_antiair_t3_v1",
	"raptor_turret_brood_t3_v1",
	"raptor_turret_antinuke_t2_v1",
	"raptor_turret_antinuke_t3_v1",
	"raptor_worm_green",
	"raptor_antinuke",
	"raptor_turret_basic_t4_v1",
	"raptor_turret_basic_t4_v2",
	"raptor_turret_acid_t4_v1",
	"raptor_turret_acid_t4_v2",
	"raptor_turret_emp_t4_v1",
	"raptor_turret_emp_t4_v2",
	"raptor_turret_antiair_t4_v1",
	"raptor_turret_brood_t4_v1",
	"raptor_turret_brood_t4_v2",
	"raptor_turret_meteor_t4_v1",
}

-- Scavenger-only content, handed to the faction it was derived from.
local scavenger = {
	arm = {
		botLab = {},
		vehiclePlant = { "armzapper" },
		airPlant = { "armfify" },
		gantry = {
			"armpwt4",
			"armsptkt4",
			"armassimilator",
			"armlunchbox",
			"armmeatball",
			"armrattet4",
			"armvadert4",
			"armdronecarryland",
		},
		airGantry = { "armthundt4", "armfepocht4", "armlichet4" },
		shipyard = { "armptt2", "armdecadet3", "armpshipt3", "armserpt3", "armdronecarry", "armtrident" },
		constructor = {
			"armapt3",
			"armminivulc",
			"armbotrail",
			"armannit3",
			"armlwall",
			"armafust3",
			"armmmkrt3",
			"armwint2",
			"armgatet3",
		},
	},
	cor = {
		botLab = { "corkark" },
		vehiclePlant = { "corforge", "cortorch", "corftiger", "corgatreap" },
		airPlant = { "cords", "corcrw", "cordronecarryair" },
		gantry = {
			"corakt4",
			"corkarganetht4",
			"cormandot4",
			"corthermite",
			"cordeadeye",
			"corgolt4",
			"corves",
		},
		airGantry = { "corcrwt4", "corfblackhyt4" },
		shipyard = { "coresuppt3", "corslrpc", "cordronecarry", "corsentinel" },
		constructor = {
			"corapt3",
			"corobligator",
			"corhllllt",
			"cordoomt3",
			"corminibuzz",
			"cormwall",
			"corscavdrag",
			"corscavfort",
			"corscavdtf",
			"corscavdtl",
			"corscavdtm",
			"corafust3",
			"cormmkrt3",
			"corwint2",
			"corgatet3",
		},
	},
	leg = {
		botLab = {},
		vehiclePlant = {},
		airPlant = {},
		gantry = { "leggobt3", "legpede", "legsrailt4", "legapollyon", "legeheatraymech_old" },
		airGantry = { "legfortt4", "legmost3" },
		shipyard = {},
		constructor = {
			"legapt3",
			"legministarfall",
			"legrwall",
			"legdtf",
			"legdtl",
			"legdtm",
			"legafust3",
			"legadveconvt3",
			"legmext15",
			"legwint2",
		},
	},
}

local scavengerBuilders = {
	botLab = { arm = "armlab", cor = "corlab", leg = "leglab" },
	vehiclePlant = { arm = "armavp", cor = "coravp", leg = "legavp" },
	airPlant = { arm = "armaap", cor = "coraap", leg = "legaap" },
	gantry = { arm = "armshltx", cor = "corgant", leg = "leggant" },
	airGantry = { arm = "armapt3", cor = "corapt3", leg = "legapt3" },
	shipyard = { arm = "armasy", cor = "corasy", leg = "legadvshipyard" },
}

local scavengerOptionsByBuilder = {}
for _, faction in ipairs(factions) do
	for group, builders in pairs(scavengerBuilders) do
		scavengerOptionsByBuilder[builders[faction]] = scavenger[faction][group]
	end
end

-- Costs derived from health in raptor_unitdefs_post are out of reach for the biggest raptors; these are buildable.
local raptorCostOverrides = {
	raptor_queen_veryeasy = { metalcost = 60000, energycost = 1500000, buildtime = 1200000 },
}

-- Raptor defs that only ever met the raptor AI: the engine truncates fractional footprints, and a commandfire weapon
-- needs the manual fire command before a player can launch it (the PvE nuke controller fires them with attack orders).
local function playableRaptor(name, unitDef)
	for _, key in ipairs({ "footprintx", "footprintz" }) do
		local footprint = unitDef[key]
		if type(footprint) == "number" and footprint % 1 ~= 0 then
			unitDef[key] = math.max(1, math.floor(footprint))
		end
	end
	for _, weapon in pairs(unitDef.weapondefs or {}) do
		if weapon.commandfire and not weapon.stockpile then
			unitDef.canmanualfire = true
		end
	end
	-- files raptor defences under Combat in the build menu instead of Utility
	local customparams = unitDef.customparams
	if (unitDef.speed or 0) == 0 and unitDef.weapondefs and next(unitDef.weapondefs) and not customparams.unitgroup then
		local unitgroup = "weapon"
		for _, weapon in pairs(unitDef.weapondefs) do
			if weapon.interceptor == 1 then
				unitgroup = "antinuke"
			end
		end
		if unitgroup == "weapon" and string.find(name, "antiair", 1, true) then
			unitgroup = "aa"
		end
		customparams.unitgroup = unitgroup
	end
end

local function addBuildOptions(buildoptions, options)
	local present = {}
	for _, option in ipairs(buildoptions) do
		present[option] = true
	end
	for _, option in ipairs(options) do
		if not present[option] then
			buildoptions[#buildoptions + 1] = option
			present[option] = true
		end
	end
end

local function moddedArsenal(name, unitDef, modOptions)
	local buildoptions = unitDef.buildoptions

	local labTier = botLabs[name]
	if labTier then
		addBuildOptions(buildoptions, { "sukuna_t" .. labTier, "steve_t" .. labTier })
	end

	if not modOptions.raptorscavarsenal then
		return
	end

	-- runs first: it appends without checking for duplicates, addBuildOptions does
	if not modOptions.scavunitsforplayers then
		scavUnitsForPlayers(name, unitDef)
	end

	if t1Constructors[name] then
		addBuildOptions(buildoptions, raptorT1Structures)
	end

	if t2Constructors[name] then
		addBuildOptions(buildoptions, raptorT2Structures)
		addBuildOptions(buildoptions, scavenger[name:sub(1, 3)].constructor)
	end

	local scavengerOptions = scavengerOptionsByBuilder[name]
	if scavengerOptions then
		addBuildOptions(buildoptions, scavengerOptions)
	end

	if string.find(name, "raptor", 1, true) then
		playableRaptor(name, unitDef)
	end

	local costs = raptorCostOverrides[name]
	if costs then
		for key, value in pairs(costs) do
			unitDef[key] = value
		end
	end
end

return {
	Tweaks = moddedArsenal,
}

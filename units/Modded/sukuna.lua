-- Ryomen Sukuna, buildable from bot labs at three tech levels. Each tier keeps the abilities of the tiers below it:
-- T1 Dismantle slashes, T2 adds Domain Expansion (luarules/gadgets/unit_sukuna_domain_expansion.lua),
-- T3 adds Fuga, the flame arrow.

local tiers = {
	{
		buildtime = 4200,
		energycost = 2400,
		metalcost = 190,
		health = 1500,
		speed = 66,
		sightdistance = 480,
		footprint = 2,
		movementclass = "BOT2",
		collision = "16 34 16",
		icontype = "armwar",
		explodeas = "smallexplosiongeneric",
		selfdestructas = "smallExplosionGenericSelfd",
		slash = { damage = 150, range = 110, reload = 0.7, aoe = 40, thickness = 2.2, ceg = "custom:sukuna-slash" },
	},
	{
		buildtime = 17000,
		energycost = 14000,
		metalcost = 850,
		health = 4600,
		speed = 72,
		sightdistance = 560,
		footprint = 3,
		movementclass = "BOT3",
		collision = "22 46 22",
		icontype = "corcan",
		explodeas = "mediumExplosionGeneric",
		selfdestructas = "mediumExplosionGenericSelfd",
		slash = { damage = 330, range = 130, reload = 0.6, aoe = 56, thickness = 3, ceg = "custom:sukuna-slash-large" },
		domain = { radius = 380, duration = 8, dps = 320, cooldown = 45, energy = 1500 },
	},
	{
		buildtime = 90000,
		energycost = 72000,
		metalcost = 4600,
		health = 24000,
		speed = 66,
		sightdistance = 700,
		footprint = 4,
		movementclass = "HBOT4",
		collision = "30 64 30",
		icontype = "corkarg",
		explodeas = "largeExplosionGeneric",
		selfdestructas = "largeExplosionGenericSelfd",
		slash = { damage = 700, range = 150, reload = 0.5, aoe = 72, thickness = 4, ceg = "custom:sukuna-slash-large" },
		domain = { radius = 520, duration = 10, dps = 650, cooldown = 40, energy = 3000 },
		fuga = { damage = 4200, range = 950, reload = 16, aoe = 300 },
	},
}

local function sukuna(tier)
	local t = tiers[tier]
	local unitDef = {
		buildpic = "modded/sukuna_t" .. tier .. ".dds",
		buildtime = t.buildtime,
		canmove = true,
		collisionvolumeoffsets = "0 0 0",
		collisionvolumescales = t.collision,
		collisionvolumetype = "CylY",
		energycost = t.energycost,
		explodeas = t.explodeas,
		footprintx = t.footprint,
		footprintz = t.footprint,
		health = t.health,
		icontype = t.icontype,
		maxacc = 0.35,
		maxdec = 0.9,
		maxslope = 17,
		maxwaterdepth = 22,
		metalcost = t.metalcost,
		movementclass = t.movementclass,
		nochasecategory = "VTOL",
		objectname = "Modded/sukuna_t" .. tier .. ".s3o",
		script = "Units/modded/sukuna_lus.lua",
		seismicsignature = 0,
		selfdestructas = t.selfdestructas,
		sightdistance = t.sightdistance,
		speed = t.speed,
		turninplace = true,
		turninplaceanglelimit = 90,
		turninplacespeedlimit = 1.6,
		turnrate = 1300,
		upright = true,
		customparams = {
			model_author = "KAKASHI (Sketchfab, CC-BY-4.0)",
			normaltex = "unittextures/blank_normal.dds",
			subfolder = "Modded",
			techlevel = tier,
			unitgroup = "weapon",
		},
		sounds = {
			canceldestruct = "cancel2",
			underattack = "warning1",
			cant = {
				[1] = "cantdo4",
			},
			count = {
				[1] = "count6",
				[2] = "count5",
				[3] = "count4",
				[4] = "count3",
				[5] = "count2",
				[6] = "count1",
			},
			ok = {
				[1] = "servmed1",
			},
			select = {
				[1] = "servmed1",
			},
		},
		weapondefs = {
			dismantle = {
				areaofeffect = t.slash.aoe,
				avoidfeature = false,
				beamtime = 0.1,
				beamttl = 3,
				corethickness = 0.6,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.75,
				energypershot = 0,
				explosiongenerator = t.slash.ceg,
				impulsefactor = 0.3,
				laserflaresize = 3,
				name = "Dismantle: cursed slashes",
				noselfdamage = true,
				range = t.slash.range,
				reloadtime = t.slash.reload,
				rgbcolor = "1 0.12 0.08",
				rgbcolor2 = "1 1 1",
				soundhitdry = "",
				soundhitwet = "sizzle",
				soundstart = "talonattack",
				soundtrigger = 1,
				thickness = t.slash.thickness,
				tolerance = 10000,
				turret = true,
				weapontype = "BeamLaser",
				weaponvelocity = 1500,
				damage = {
					default = t.slash.damage,
					vtol = math.floor(t.slash.damage * 0.15),
				},
			},
		},
		weapons = {
			[1] = {
				badtargetcategory = "VTOL",
				def = "DISMANTLE",
				fastquerypointupdate = true,
				onlytargetcategory = "NOTSUB",
			},
		},
	}

	if t.domain then
		local cp = unitDef.customparams
		cp.domain_radius = t.domain.radius
		cp.domain_duration = t.domain.duration
		cp.domain_dps = t.domain.dps
		cp.domain_cooldown = t.domain.cooldown
		cp.domain_energy = t.domain.energy
		-- never fired by the engine: the domain gadget deals its damage through this weapon so kills are credited
		unitDef.weapondefs.malevolent_shrine = {
			areaofeffect = 0,
			craterareaofeffect = 0,
			craterboost = 0,
			cratermult = 0,
			edgeeffectiveness = 1,
			explosiongenerator = "custom:sukuna-slash-large",
			impulsefactor = 0,
			name = "Domain Expansion: Malevolent Shrine",
			range = t.domain.radius,
			reloadtime = t.domain.cooldown,
			soundhitdry = "",
			soundstart = "",
			weapontype = "Cannon",
			weaponvelocity = 1000,
			damage = {
				default = t.domain.dps,
			},
		}
	end

	if t.fuga then
		unitDef.weapondefs.fuga = {
			areaofeffect = t.fuga.aoe,
			avoidfeature = false,
			cegtag = "missiletraillarge-red",
			craterareaofeffect = t.fuga.aoe,
			craterboost = 0,
			cratermult = 0,
			edgeeffectiveness = 0.55,
			explosiongenerator = "custom:fire-explosion-large",
			firestarter = 100,
			flighttime = 3,
			impulsefactor = 0.6,
			model = "Modded/sukuna_fuga.s3o",
			name = "Fuga: Open (flame arrow)",
			noselfdamage = true,
			range = t.fuga.range,
			reloadtime = t.fuga.reload,
			smoketrail = false,
			soundhit = "xplonuk2xs",
			soundhitwet = "splslrg",
			soundstart = "flamhvy1",
			startvelocity = 700,
			texture1 = "null",
			tracks = false,
			turret = true,
			weaponacceleration = 0,
			weapontimer = 3,
			weapontype = "MissileLauncher",
			weaponvelocity = 700,
			customparams = {
				area_onhit_ceg = "fire-area-150-repeat",
				area_onhit_damage = 140,
				area_onhit_damageCeg = "burnflamexl-gen",
				area_onhit_range = 150,
				area_onhit_resistance = "fire",
				area_onhit_time = 8,
			},
			damage = {
				default = t.fuga.damage,
				vtol = math.floor(t.fuga.damage * 0.25),
			},
		}
		unitDef.weapons[2] = {
			badtargetcategory = "VTOL",
			def = "FUGA",
			onlytargetcategory = "NOTSUB",
		}
	end

	return unitDef
end

return {
	sukuna_t1 = sukuna(1),
	sukuna_t2 = sukuna(2),
	sukuna_t3 = sukuna(3),
}

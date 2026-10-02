-- Death explosions of the Minecraft structures (units/Modded/minecraft_blocks.lua).
-- luarules/gadgets/unit_minecraft_tnt.lua keeps mc_tnt_blast from hurting the TNT owner's allies.

return {
	mc_tnt_blast = {
		areaofeffect = 300,
		cameraShake = 300,
		craterareaofeffect = 220,
		craterboost = 0.3,
		cratermult = 0.6,
		edgeeffectiveness = 0.45,
		explosiongenerator = "custom:genericshellexplosion-huge",
		impulsefactor = 1.2,
		name = "TNT",
		soundhit = "xplolrg3",
		soundstart = "largegun",
		damage = {
			default = 2600,
			vtol = 400,
		},
		customparams = {
			unitexplosion = 1,
		},
	},
	mc_block_break = {
		areaofeffect = 24,
		cameraShake = 0,
		explosiongenerator = "custom:dirt",
		impulsefactor = 0,
		name = "Block break",
		soundhit = "xplosml3",
		damage = {
			default = 0,
		},
		customparams = {
			unitexplosion = 1,
		},
	},
}

local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")

describe("Modded units", function()
	local defs

	setup(function()
		defs = SpringSyncedBuilder.new():WithRealUnitDefs():Build():GetUnitDefs()
	end)

	local function canBuild(builder, option)
		for _, buildOption in ipairs(defs[builder].buildoptions or {}) do
			if buildOption == option then
				return true
			end
		end
		return false
	end

	local function weaponNames(name)
		local names = {}
		for _, weapon in ipairs(defs[name].weapons or {}) do
			names[#names + 1] = weapon.def:lower()
		end
		table.sort(names)
		return names
	end

	it("builds Sukuna and Steve in the bot lab of the matching tier for every faction", function()
		local labs = {
			{ "armlab", "corlab", "leglab" },
			{ "armalab", "coralab", "legalab" },
			{ "armshltx", "corgant", "leggant" },
		}
		for tier, tierLabs in ipairs(labs) do
			for _, lab in ipairs(tierLabs) do
				assert.is_true(canBuild(lab, "sukuna_t" .. tier), lab .. " builds sukuna_t" .. tier)
				assert.is_true(canBuild(lab, "steve_t" .. tier), lab .. " builds steve_t" .. tier)
			end
		end
	end)

	it("adds Sukuna's abilities tier by tier", function()
		assert.same({ "dismantle" }, weaponNames("sukuna_t1"))
		assert.is_nil(defs.sukuna_t1.customparams.domain_radius)

		assert.same({ "dismantle" }, weaponNames("sukuna_t2"))
		assert.is_not_nil(defs.sukuna_t2.customparams.domain_radius)

		assert.same({ "dismantle", "fuga" }, weaponNames("sukuna_t3"))
		assert.is_not_nil(defs.sukuna_t3.customparams.domain_radius)
	end)

	it("adds Steve's structures tier by tier", function()
		assert.same({ "mc_dirt", "mc_cobble" }, defs.steve_t1.buildoptions)
		assert.same({ "mc_dirt", "mc_cobble", "mc_nether_portal" }, defs.steve_t2.buildoptions)
		assert.same({ "mc_dirt", "mc_cobble", "mc_nether_portal", "mc_tnt" }, defs.steve_t3.buildoptions)
		for tier = 1, 3 do
			assert.same({ "bow" }, weaponNames("steve_t" .. tier))
		end
	end)

	it("lets constructors of every faction build the raptor factories", function()
		for _, faction in ipairs({ "arm", "cor", "leg" }) do
			assert.is_true(canBuild(faction .. "ck", "brood_nest"))
			assert.is_true(canBuild(faction .. "ck", "brood_roost"))
			assert.is_true(canBuild(faction .. "ack", "brood_lair"))
			assert.is_true(canBuild(faction .. "ack", "brood_throne"))
		end
		assert.is_true(canBuild("brood_throne", "raptor_queen_veryeasy"))
	end)

	it("hands scavenger-only units to the faction they came from", function()
		assert.is_true(canBuild("armshltx", "armpwt4"))
		assert.is_true(canBuild("corgant", "corkarganetht4"))
		assert.is_true(canBuild("leggant", "legpede"))
		assert.is_false(canBuild("armshltx", "corkarganetht4"))
		assert.is_true(canBuild("armack", "armannit3"))
		assert.is_true(canBuild("corack", "cordoomt3"))
	end)
end)

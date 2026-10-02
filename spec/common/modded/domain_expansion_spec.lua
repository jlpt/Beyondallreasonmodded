local DomainExpansion = require("common/modded/domain_expansion")

describe("DomainExpansion", function()
	describe("ParseDomainDefs", function()
		local unitDefs = {
			[1] = {
				name = "sukuna_t2",
				customParams = {
					domain_radius = "380",
					domain_duration = "8",
					domain_dps = "320",
					domain_cooldown = "45",
					domain_energy = "1500",
				},
			},
			[2] = {
				name = "sukuna_t3",
				customParams = {
					domain_radius = "520",
					domain_duration = "10",
					domain_dps = "650",
					domain_cooldown = "40",
				},
			},
			[3] = { name = "sukuna_t1", customParams = {} },
		}
		local weaponDefNames = { sukuna_t2_malevolent_shrine = { id = 77 } }

		local defs = DomainExpansion.ParseDomainDefs(unitDefs, weaponDefNames, 30, 6)

		it("only lists units with a domain radius", function()
			assert.is_table(defs[1])
			assert.is_table(defs[2])
			assert.is_nil(defs[3])
		end)

		it("converts seconds to frames and damage per second to damage per tick", function()
			assert.equal(380, defs[1].radius)
			assert.equal(240, defs[1].durationFrames)
			assert.equal(1350, defs[1].cooldownFrames)
			assert.equal(64, defs[1].damagePerTick)
			assert.equal(1500, defs[1].energy)
		end)

		it("credits damage to the unit's shrine weapon, or to no weapon when it has none", function()
			assert.equal(77, defs[1].weaponDefID)
			assert.equal(-1, defs[2].weaponDefID)
		end)

		it("treats a missing energy cost as free", function()
			assert.equal(0, defs[2].energy)
		end)

		it("uses the large effects for large domains", function()
			assert.equal("custom:malevolent-shrine-open", defs[1].openCeg)
			assert.equal("custom:malevolent-shrine-floor", defs[1].floorCeg)
			assert.equal("custom:malevolent-shrine-open-xl", defs[2].openCeg)
			assert.equal("custom:malevolent-shrine-floor-xl", defs[2].floorCeg)
		end)
	end)

	describe("CanCast", function()
		it("allows a unit that never cast", function()
			local canCast, waitFrames = DomainExpansion.CanCast(nil, 100)
			assert.is_true(canCast)
			assert.equal(0, waitFrames)
		end)

		it("refuses while recharging and reports the frames left", function()
			local canCast, waitFrames = DomainExpansion.CanCast(500, 380)
			assert.is_false(canCast)
			assert.equal(120, waitFrames)
		end)

		it("allows casting again on the frame the cooldown ends", function()
			assert.is_true((DomainExpansion.CanCast(500, 500)))
		end)
	end)
end)

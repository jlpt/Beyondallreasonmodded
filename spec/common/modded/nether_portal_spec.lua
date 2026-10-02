local NetherPortal = require("common/modded/nether_portal")

local CMD_GUARD = 25
local CMD_MOVE = 10
local CMD_REPAIR = 40
local MOVE_COMMANDS = { [CMD_MOVE] = true }

describe("NetherPortal", function()
	describe("NextPortal", function()
		it("has no exit while a portal has no partner", function()
			assert.is_nil(NetherPortal.NextPortal({}, 5))
			assert.is_nil(NetherPortal.NextPortal({ 5 }, 5))
		end)

		it("links two portals both ways", function()
			assert.equal(9, NetherPortal.NextPortal({ 5, 9 }, 5))
			assert.equal(5, NetherPortal.NextPortal({ 5, 9 }, 9))
		end)

		it("sends travellers around the ring in build order", function()
			local network = { 5, 9, 3 }
			assert.equal(9, NetherPortal.NextPortal(network, 5))
			assert.equal(3, NetherPortal.NextPortal(network, 9))
			assert.equal(5, NetherPortal.NextPortal(network, 3))
		end)

		it("has no exit for a portal outside the network", function()
			assert.is_nil(NetherPortal.NextPortal({ 5, 9 }, 7))
		end)
	end)

	describe("ExitPosition", function()
		it("places travellers in front of the portal for each facing", function()
			assert.same({ 100, 140 }, { NetherPortal.ExitPosition(100, 100, 0, 40, 0) })
			assert.same({ 140, 100 }, { NetherPortal.ExitPosition(100, 100, 1, 40, 0) })
			assert.same({ 100, 60 }, { NetherPortal.ExitPosition(100, 100, 2, 40, 0) })
			assert.same({ 60, 100 }, { NetherPortal.ExitPosition(100, 100, 3, 40, 0) })
		end)

		it("shifts travellers sideways along the portal", function()
			assert.same({ 90, 140 }, { NetherPortal.ExitPosition(100, 100, 0, 40, 10) })
			assert.same({ 140, 110 }, { NetherPortal.ExitPosition(100, 100, 1, 40, 10) })
		end)

		it("puts travellers behind the portal for a negative distance", function()
			assert.same({ 100, 60 }, { NetherPortal.ExitPosition(100, 100, 0, -40, 0) })
		end)
	end)

	describe("WantsToEnter", function()
		local function wants(command)
			return NetherPortal.WantsToEnter(command, 7, 100, 100, 60, CMD_GUARD, MOVE_COMMANDS)
		end

		it("takes idle units standing in the portal", function()
			assert.is_true(wants(nil))
		end)

		it("takes units guarding this portal only", function()
			assert.is_true(wants({ id = CMD_GUARD, params = { 7 } }))
			assert.is_false(wants({ id = CMD_GUARD, params = { 8 } }))
		end)

		it("takes units whose move order ends at the portal", function()
			assert.is_true(wants({ id = CMD_MOVE, params = { 130, 0, 140 } }))
		end)

		it("leaves units walking past the portal to somewhere else", function()
			assert.is_false(wants({ id = CMD_MOVE, params = { 400, 0, 100 } }))
		end)

		it("leaves builders working next to the portal", function()
			assert.is_false(wants({ id = -12, params = { 110, 0, 110, 0 } }))
			assert.is_false(wants({ id = CMD_REPAIR, params = { 7 } }))
		end)
	end)
end)

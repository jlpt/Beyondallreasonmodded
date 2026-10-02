-- Rules for Steve's nether portals, shared by luarules/gadgets/unit_minecraft_nether_portal.lua and its spec.
-- The portals of one ally team form a ring in the order they were finished: each one leads to the next.

local NetherPortal = {}

-- Build facing to the direction the portal opening points at: 0 south, 1 east, 2 north, 3 west.
local FACING_DIRECTIONS = {
	[0] = { 0, 1 },
	[1] = { 1, 0 },
	[2] = { 0, -1 },
	[3] = { -1, 0 },
}

--- The portal a traveller entering `unitID` comes out of, or nil while the portal has no partner.
---@param network integer[] portal unitIDs of one ally team, in the order they were finished
---@param unitID integer
---@return integer?
function NetherPortal.NextPortal(network, unitID)
	local count = #network
	if count < 2 then
		return nil
	end
	for i = 1, count do
		if network[i] == unitID then
			return network[i % count + 1]
		end
	end
	return nil
end

--- Where a traveller is placed in front of the exit portal.
---@param x number exit portal position
---@param z number
---@param facing integer build facing of the exit portal
---@param distance number how far in front of the portal
---@param lateral number sideways offset, so groups do not land on one spot
---@return number x
---@return number z
function NetherPortal.ExitPosition(x, z, facing, distance, lateral)
	local dir = FACING_DIRECTIONS[facing] or FACING_DIRECTIONS[0]
	local dx, dz = dir[1], dir[2]
	-- the sideways axis is the facing direction turned by a quarter
	return x + dx * distance - dz * lateral, z + dz * distance + dx * lateral
end

--- Whether a unit standing at the portal means to go through it: it is idle in the portal, guards the portal, or
--- its current move order ends at the portal. Builders working next to a portal are left alone.
---@param command table? first queued command as returned by Spring.GetUnitCommands
---@param portalID integer
---@param portalX number
---@param portalZ number
---@param reach number how close a move goal must be to the portal
---@param guardCmdID integer CMD.GUARD
---@param moveCmdIDs table<integer, boolean> commands whose first three params are a goal position
---@return boolean
function NetherPortal.WantsToEnter(command, portalID, portalX, portalZ, reach, guardCmdID, moveCmdIDs)
	if command == nil then
		return true
	end
	local params = command.params
	if command.id == guardCmdID then
		return params[1] == portalID
	end
	if moveCmdIDs[command.id] and #params >= 3 then
		local dx, dz = params[1] - portalX, params[3] - portalZ
		return dx * dx + dz * dz <= reach * reach
	end
	return false
end

return NetherPortal

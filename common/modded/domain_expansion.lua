-- Rules for Sukuna's Domain Expansion, shared by luarules/gadgets/unit_sukuna_domain_expansion.lua and its spec.

local XL_RADIUS = 450

local DomainExpansion = {}

--- Reads the domain_* customparams of every unit that can expand a domain.
---@param unitDefs table UnitDefs
---@param weaponDefNames table WeaponDefNames
---@param gameSpeed number frames per second
---@param tickFrames number frames between two damage ticks
---@return table<integer, table> domainDefs keyed by unitDefID
function DomainExpansion.ParseDomainDefs(unitDefs, weaponDefNames, gameSpeed, tickFrames)
	local domainDefs = {}
	for unitDefID, unitDef in pairs(unitDefs) do
		local cp = unitDef.customParams
		local radius = cp and tonumber(cp.domain_radius)
		if radius then
			local weaponDef = weaponDefNames[unitDef.name .. "_malevolent_shrine"]
			local suffix = radius >= XL_RADIUS and "-xl" or ""
			domainDefs[unitDefID] = {
				radius = radius,
				durationFrames = math.floor(tonumber(cp.domain_duration) * gameSpeed),
				damagePerTick = tonumber(cp.domain_dps) * tickFrames / gameSpeed,
				cooldownFrames = math.floor(tonumber(cp.domain_cooldown) * gameSpeed),
				energy = tonumber(cp.domain_energy) or 0,
				weaponDefID = weaponDef and weaponDef.id or -1,
				openCeg = "custom:malevolent-shrine-open" .. suffix,
				floorCeg = "custom:malevolent-shrine-floor" .. suffix,
			}
		end
	end
	return domainDefs
end

--- Whether a domain can be cast this frame.
---@param readyFrame integer? frame the domain recharges, nil if never cast
---@param frame integer current game frame
---@return boolean canCast
---@return integer waitFrames frames left on the cooldown, 0 when ready
function DomainExpansion.CanCast(readyFrame, frame)
	if readyFrame == nil or frame >= readyFrame then
		return true, 0
	end
	return false, readyFrame - frame
end

return DomainExpansion

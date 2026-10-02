-- Dirt and cobblestone blocks (units/Modded/minecraft_blocks.lua).

local block = piece("block")

function script.Create() end

function script.Killed(recentDamage, maxHealth)
	Explode(block, SFX.SHATTER + SFX.NO_HEATCLOUD)
	return 3
end

-- TNT block (units/Modded/minecraft_blocks.lua). Prime is called by luarules/gadgets/unit_minecraft_tnt.lua,
-- which also sets the block off when the fuse runs out.

local block, flash = piece("block", "flash")

local SIG_FUSE = 1

function script.Create()
	Hide(flash)
end

local function fuse()
	Signal(SIG_FUSE)
	SetSignalMask(SIG_FUSE)
	local blinkMs = 300
	while true do
		Show(flash)
		EmitSfx(block, 1024)
		Sleep(blinkMs)
		Hide(flash)
		Sleep(blinkMs)
		blinkMs = math.max(80, blinkMs - 30)
	end
end

function Prime()
	StartThread(fuse)
end

function script.Killed(recentDamage, maxHealth)
	return 3
end

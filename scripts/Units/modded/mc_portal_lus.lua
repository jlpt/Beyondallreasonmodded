-- Nether portal (units/Modded/minecraft_blocks.lua). SetLinked is called by
-- luarules/gadgets/unit_minecraft_nether_portal.lua: the portal sheet only glows while another portal is linked.

local frame, sheet, ambient = piece("frame", "sheet", "ambient")

local SIG_AMBIENT = 1

local function shimmer()
	Signal(SIG_AMBIENT)
	SetSignalMask(SIG_AMBIENT)
	while true do
		EmitSfx(ambient, 1024)
		Sleep(250)
	end
end

function script.Create()
	Hide(sheet)
end

function SetLinked(linked)
	if linked then
		Show(sheet)
		StartThread(shimmer)
	else
		Signal(SIG_AMBIENT)
		Hide(sheet)
	end
end

function script.Killed(recentDamage, maxHealth)
	Explode(frame, SFX.SHATTER + SFX.NO_HEATCLOUD)
	return 3
end

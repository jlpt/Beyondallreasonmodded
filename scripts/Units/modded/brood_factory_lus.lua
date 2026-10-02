-- Factory script for the raptor hive based brood factories (units/Modded/brood_factories.lua).

local base, pad, topflare = piece("base", "pad", "topflare")
local arms = { piece("arm1", "arm2", "arm3", "arm4", "arm5") }

local SIG_ACTIVATE = 2
local SIG_OPENCLOSE = 4
local SIG_PULSE = 8

include("include/util.lua")

local rad = math.rad

local function open()
	Signal(SIG_OPENCLOSE)
	SetSignalMask(SIG_OPENCLOSE)
	open_yard()
	SetUnitValue(COB.INBUILDSTANCE, 1)
end

local function close()
	Signal(SIG_OPENCLOSE)
	SetSignalMask(SIG_OPENCLOSE)
	SetUnitValue(COB.INBUILDSTANCE, 0)
	close_yard()
end

local function pulse()
	Signal(SIG_PULSE)
	SetSignalMask(SIG_PULSE)
	while true do
		for i = 1, #arms do
			Turn(arms[i], x_axis, rad(-12), rad(30))
		end
		Sleep(500)
		for i = 1, #arms do
			Turn(arms[i], x_axis, rad(6), rad(30))
		end
		Sleep(500)
	end
end

function script.Create()
	StartThread(smoke_unit, base)
end

function script.Activate()
	Signal(SIG_ACTIVATE)
	StartThread(open)
end

local function deactivate()
	Signal(SIG_ACTIVATE)
	SetSignalMask(SIG_ACTIVATE)
	Sleep(5000)
	StartThread(close)
end

function script.Deactivate()
	StartThread(deactivate)
end

function script.StartBuilding()
	StartThread(pulse)
end

function script.StopBuilding()
	Signal(SIG_PULSE)
	for i = 1, #arms do
		Turn(arms[i], x_axis, 0, rad(30))
	end
end

function script.QueryNanoPiece()
	return topflare
end

function script.QueryBuildInfo()
	return pad
end

function script.Killed(recentDamage, maxHealth)
	EmitSfx(base, 1024)
	return 3
end

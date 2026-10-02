-- Steve (units/Modded/steve.lua): walks, draws his bow and places blocks with his right hand.

local torso, head, larm, rarm, nano, flare, lleg, rleg =
	piece("torso", "head", "larm", "rarm", "nano", "flare", "lleg", "rleg")

local SIG_WALK = 1
local SIG_AIM = 2
local SIG_BUILD = 4
local SIG_RESTORE = 8

local rad = math.rad

local isAiming = false
local isBuilding = false

local function armsFree()
	return not isAiming and not isBuilding
end

local function walk()
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)
	while true do
		Turn(lleg, x_axis, rad(-35), rad(180))
		Turn(rleg, x_axis, rad(35), rad(180))
		if armsFree() then
			Turn(larm, x_axis, rad(35), rad(180))
			Turn(rarm, x_axis, rad(-35), rad(180))
		end
		WaitForTurn(lleg, x_axis)
		Turn(lleg, x_axis, rad(35), rad(180))
		Turn(rleg, x_axis, rad(-35), rad(180))
		if armsFree() then
			Turn(larm, x_axis, rad(-35), rad(180))
			Turn(rarm, x_axis, rad(35), rad(180))
		end
		WaitForTurn(lleg, x_axis)
	end
end

local function restoreArms(speed)
	Turn(torso, y_axis, 0, rad(speed))
	Turn(head, x_axis, 0, rad(speed))
	Turn(larm, x_axis, 0, rad(speed))
	Turn(larm, y_axis, 0, rad(speed))
	Turn(rarm, x_axis, 0, rad(speed))
	Turn(rarm, y_axis, 0, rad(speed))
end

local function restoreAfterDelay()
	Signal(SIG_RESTORE)
	SetSignalMask(SIG_RESTORE)
	Sleep(2000)
	isAiming = false
	if not isBuilding then
		restoreArms(150)
	end
end

function script.Create() end

function script.StartMoving()
	StartThread(walk)
end

function script.StopMoving()
	Signal(SIG_WALK)
	Turn(lleg, x_axis, 0, rad(250))
	Turn(rleg, x_axis, 0, rad(250))
	if armsFree() then
		Turn(larm, x_axis, 0, rad(250))
		Turn(rarm, x_axis, 0, rad(250))
	end
end

function script.AimFromWeapon()
	return torso
end

function script.QueryWeapon()
	return flare
end

function script.AimWeapon(weaponNum, heading, pitch)
	Signal(SIG_AIM)
	SetSignalMask(SIG_AIM)
	isAiming = true
	Turn(torso, y_axis, heading, rad(360))
	Turn(head, x_axis, -pitch, rad(360))
	Turn(larm, x_axis, rad(-90) - pitch, rad(420))
	Turn(rarm, x_axis, rad(-90) - pitch, rad(420))
	Turn(rarm, y_axis, rad(-25), rad(420))
	WaitForTurn(torso, y_axis)
	WaitForTurn(larm, x_axis)
	StartThread(restoreAfterDelay)
	return true
end

function script.FireWeapon()
	Turn(rarm, y_axis, rad(-5), rad(900))
	Sleep(120)
	Turn(rarm, y_axis, rad(-25), rad(200))
end

local function placeBlocks()
	Signal(SIG_BUILD)
	SetSignalMask(SIG_BUILD)
	while true do
		Turn(rarm, x_axis, rad(-95), rad(360))
		WaitForTurn(rarm, x_axis)
		Turn(rarm, x_axis, rad(-45), rad(360))
		WaitForTurn(rarm, x_axis)
	end
end

function script.StartBuilding(heading, pitch)
	isBuilding = true
	Turn(torso, y_axis, heading, rad(360))
	Turn(head, x_axis, -pitch, rad(360))
	WaitForTurn(torso, y_axis)
	SetUnitValue(COB.INBUILDSTANCE, 1)
	StartThread(placeBlocks)
	return true
end

function script.StopBuilding()
	isBuilding = false
	Signal(SIG_BUILD)
	SetUnitValue(COB.INBUILDSTANCE, 0)
	if not isAiming then
		restoreArms(200)
	end
	return true
end

function script.QueryNanoPiece()
	return nano
end

function script.Killed(recentDamage, maxHealth)
	Explode(head, SFX.FALL + SFX.NO_HEATCLOUD)
	Explode(larm, SFX.FALL + SFX.NO_HEATCLOUD)
	Explode(rarm, SFX.FALL + SFX.NO_HEATCLOUD)
	return 3
end

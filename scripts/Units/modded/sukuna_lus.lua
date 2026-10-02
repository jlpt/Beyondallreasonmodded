-- Ryomen Sukuna (units/Modded/sukuna.lua). Weapon 1 is Dismantle (melee slashes), weapon 2 (T3 only) is Fuga.
-- DomainCast is called by luarules/gadgets/unit_sukuna_domain_expansion.lua.

local pelvis, torso, head, larm, rarm, rhand, aimpoint, fuga, lleg, rleg =
	piece("pelvis", "torso", "head", "larm", "rarm", "rhand", "aimpoint", "fuga", "lleg", "rleg")

local SIG_WALK = 1
local SIG_AIM = 2
local SIG_AIM_FUGA = 4
local SIG_RESTORE = 8

local rad = math.rad

local isAiming = false
local isCasting = false

local function restorePose(speed)
	Turn(torso, y_axis, 0, rad(speed))
	Turn(larm, x_axis, 0, rad(speed))
	Turn(larm, y_axis, 0, rad(speed))
	Turn(larm, z_axis, 0, rad(speed))
	Turn(rarm, x_axis, 0, rad(speed))
	Turn(rarm, y_axis, 0, rad(speed))
	Turn(rarm, z_axis, 0, rad(speed))
	Turn(head, x_axis, 0, rad(speed))
end

local function walk()
	Signal(SIG_WALK)
	SetSignalMask(SIG_WALK)
	while true do
		Turn(lleg, x_axis, rad(-28), rad(140))
		Turn(rleg, x_axis, rad(28), rad(140))
		if not isAiming and not isCasting then
			Turn(larm, x_axis, rad(22), rad(110))
			Turn(rarm, x_axis, rad(-22), rad(110))
		end
		Move(pelvis, y_axis, 0.8, 6)
		WaitForTurn(lleg, x_axis)
		Move(pelvis, y_axis, 0, 6)
		Turn(lleg, x_axis, rad(28), rad(140))
		Turn(rleg, x_axis, rad(-28), rad(140))
		if not isAiming and not isCasting then
			Turn(larm, x_axis, rad(-22), rad(110))
			Turn(rarm, x_axis, rad(22), rad(110))
		end
		Move(pelvis, y_axis, 0.8, 6)
		WaitForTurn(lleg, x_axis)
		Move(pelvis, y_axis, 0, 6)
	end
end

local function stopWalking()
	Signal(SIG_WALK)
	Turn(lleg, x_axis, 0, rad(200))
	Turn(rleg, x_axis, 0, rad(200))
	Move(pelvis, y_axis, 0, 10)
	if not isAiming and not isCasting then
		Turn(larm, x_axis, 0, rad(200))
		Turn(rarm, x_axis, 0, rad(200))
	end
end

local function restoreAfterDelay()
	Signal(SIG_RESTORE)
	SetSignalMask(SIG_RESTORE)
	Sleep(2500)
	isAiming = false
	Hide(fuga)
	restorePose(120)
end

function script.Create()
	Hide(fuga)
end

function script.StartMoving()
	StartThread(walk)
end

function script.StopMoving()
	stopWalking()
end

function script.AimFromWeapon(weaponNum)
	return aimpoint
end

function script.QueryWeapon(weaponNum)
	if weaponNum == 2 then
		return fuga
	end
	return rhand
end

function script.AimWeapon(weaponNum, heading, pitch)
	if isCasting then
		return false
	end
	isAiming = true
	if weaponNum == 2 then
		Signal(SIG_AIM_FUGA)
		SetSignalMask(SIG_AIM_FUGA)
		Show(fuga)
		Turn(torso, y_axis, heading, rad(240))
		Turn(larm, x_axis, rad(-85) - pitch, rad(300))
		Turn(larm, z_axis, rad(-25), rad(300))
		Turn(rarm, x_axis, rad(-70) - pitch, rad(300))
		Turn(rarm, y_axis, rad(-35), rad(300))
		WaitForTurn(torso, y_axis)
		WaitForTurn(larm, x_axis)
	else
		Signal(SIG_AIM)
		SetSignalMask(SIG_AIM)
		Turn(torso, y_axis, heading, rad(500))
		WaitForTurn(torso, y_axis)
	end
	StartThread(restoreAfterDelay)
	return true
end

local function slash()
	Turn(rarm, x_axis, rad(-120), rad(1400))
	Turn(rarm, z_axis, rad(30), rad(900))
	WaitForTurn(rarm, x_axis)
	Turn(rarm, x_axis, rad(-20), rad(1200))
	Turn(rarm, z_axis, rad(-20), rad(900))
	Turn(larm, x_axis, rad(-60), rad(700))
	WaitForTurn(rarm, x_axis)
	Turn(larm, x_axis, 0, rad(300))
end

function script.FireWeapon(weaponNum)
	if weaponNum == 2 then
		Hide(fuga)
		Turn(rarm, x_axis, rad(-40), rad(900))
	else
		StartThread(slash)
	end
end

local function domainCast(durationMs)
	isCasting = true
	Signal(SIG_RESTORE)
	Turn(torso, y_axis, 0, rad(300))
	Turn(larm, x_axis, rad(-80), rad(260))
	Turn(larm, z_axis, rad(-35), rad(260))
	Turn(rarm, x_axis, rad(-80), rad(260))
	Turn(rarm, z_axis, rad(35), rad(260))
	Turn(head, x_axis, rad(-10), rad(60))
	Sleep(durationMs)
	isCasting = false
	restorePose(150)
end

-- Hand sign for Domain Expansion; durationMs is the cast time.
function DomainCast(durationMs)
	StartThread(domainCast, durationMs)
end

function script.Killed(recentDamage, maxHealth)
	Explode(head, SFX.FALL + SFX.NO_HEATCLOUD)
	Explode(larm, SFX.FALL + SFX.NO_HEATCLOUD)
	Explode(rarm, SFX.FALL + SFX.NO_HEATCLOUD)
	return 3
end

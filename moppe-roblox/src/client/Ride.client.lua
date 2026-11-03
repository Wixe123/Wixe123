-- Riding on the client: keys -> RideSim (the physics), RideSim -> the moped's constraints.
-- The client owns the moped's physics and drives it with LinearVelocity (speed in the ground plane) and
-- AlignOrientation (heading, lean, wheelie). Rewards are calculated and checked by the server.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local RideSim = require(Shared.RideSim)
local CS = require(Shared.ClientState)
local remotes = RS:WaitForChild("Remotes")
local Report, Api = remotes:WaitForChild("Report"), remotes:WaitForChild("Api")
local plr = Players.LocalPlayer
local S = 1 / Config.STUD

local R = RideSim.new(function(kind, ...)
	if kind == "say" then CS.toast:Fire((...))
	else Report:FireServer(kind, ...) end
end)
R.whValue = RideSim.whValue
CS.ride = R
CS.changed.Event:Connect(function() if CS.profile then RideSim.setProfile(R, CS.profile) end end)

local function myMoped()
	for _, m in ipairs(workspace:GetChildren()) do
		local o = m:FindFirstChild("Owner")
		if o and o.Value == plr and m:FindFirstChild("Seat") then return m end
	end
end
local function seatedOn(m)
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and m ~= nil and hum.SeatPart == m.Seat
end

local K = {}
local function key(k) return K[k] == true end
UIS.InputBegan:Connect(function(io, gp)
	if gp or io.UserInputType ~= Enum.UserInputType.Keyboard then return end
	local k = io.KeyCode.Name
	K[k] = true
	if not R.mop then return end
	if k == "K" then RideSim.kick(R, 1)
	elseif k == "X" then RideSim.stop(R)
	elseif k == "E" and not R.mop.cvt then R.gear = math.min(4, R.gear + 1)
	elseif k == "Q" and not R.mop.cvt then R.gear = math.max(1, R.gear - 1)
	elseif k == "R" then
		R.v, R.crash, R.wh, R.pitch, R.pw, R.lean = 0, nil, nil, 0, 0, 0
		Report:FireServer("dirty")
		task.spawn(function() Api:InvokeServer("spawn") end)
	end
end)
UIS.InputEnded:Connect(function(io) K[io.KeyCode.Name] = false end)
UIS.WindowFocusReleased:Connect(function() K = {} end)

local wasSeated = false
RunService.Heartbeat:Connect(function(dtReal)
	if not R.P then return end
	local m = myMoped()
	local seated = seatedOn(m)
	if seated and not wasSeated and not R.on then RideSim.kick(R, 3) end -- "Åk ut" starts the engine
	wasSeated = seated
	local input = {
		thr = (key("W") or key("Up")) and 1 or 0,
		brk = (key("S") or key("Down")) and 1 or 0,
		st = ((key("D") or key("Right")) and 1 or 0) - ((key("A") or key("Left")) and 1 or 0),
		back = key("LeftShift") or key("RightShift"),
	}
	-- physics in sub-steps of at most 1/60 s based on real time
	local real = math.min(0.25, dtReal)
	local n = math.max(1, math.ceil(real * 60))
	for _ = 1, n do RideSim.step(R, real / n, seated, input) end
	R.seated = seated
	if not m then return end
	local root = m.PrimaryPart
	local lv, ao = root and root:FindFirstChild("Drive"), root and root:FindFirstChild("Tilt")
	if not (lv and ao) then return end
	if seated then
		if not R.drive then R.drive = true; local _, y = root.CFrame:ToOrientation(); R.h = y end
		local vs = R.v * S
		lv.MaxForce = 4e5
		lv.PlaneVelocity = Vector2.new(-math.sin(R.h) * vs, -math.cos(R.h) * vs)
		ao.MaxTorque = 4e5
		local roll = R.crash and R.crash.side * math.min(1.45, R.crash.t * 2.4) or -R.lean
		ao.CFrame = CFrame.Angles(0, R.h, 0) * CFrame.Angles(R.pitch, 0, roll)
	else
		R.drive = false
		lv.MaxForce, ao.MaxTorque = 0, 0
	end
end)

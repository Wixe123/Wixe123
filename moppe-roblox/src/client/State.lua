-- Client state shared by all LocalScripts: the profile from the server, API calls, the current work mode,
-- toasts, camera and movement locking.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = RS:WaitForChild("Shared")
local Profile = require(Shared.Profile)
local Config = require(Shared.Config)
local remotes = RS:WaitForChild("Remotes")
local Api = remotes:WaitForChild("Api")
local plr = Players.LocalPlayer

local S = {}
S.profile = nil
S.meta = { now = 0, plot = nil, stock = {} }
S.mode = nil
S.changed = Instance.new("BindableEvent")
S.toastEv = Instance.new("BindableEvent")
S.modeEv = Instance.new("BindableEvent")
S.open = Instance.new("BindableEvent") -- open a window or work mode by name ("shop", "engine", "moped", ...)
S.tipEv = Instance.new("BindableEvent")
S.settings = { tips = true, minimap = true }
local clockOffset = 0

remotes:WaitForChild("State").OnClientEvent:Connect(function(p, meta)
	S.profile = p
	S.meta = meta or S.meta
	clockOffset = (meta and meta.now or 0) - os.clock()
	S.changed:Fire()
end)
remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text, kind) S.toastEv:Fire(text, kind) end)

function S.now() return os.clock() + clockOffset end
function S.tip(text) S.tipEv:Fire(text) end
-- walk to a point in my garage (garage-local Vector3), then call cb (also if already there)
function S.walkTo(localPos, cb, dist)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and root) then return end
	local target = S.origin() * localPos
	if (root.Position - target).Magnitude <= (dist or 8) then cb(); return end
	hum:MoveTo(target)
	local done = false
	local conn
	conn = hum.MoveToFinished:Connect(function()
		if done then return end
		done = true
		conn:Disconnect()
		cb()
	end)
	task.delay(8, function()
		if not done then done = true; conn:Disconnect(); cb() end
	end)
end
function S.toast(text, kind) S.toastEv:Fire(text, kind or "info") end
-- call the server; shows the error as a toast; returns ok, result
function S.api(action, ...)
	local ok, a, b, c = pcall(function(...) return Api:InvokeServer(action, ...) end, ...)
	if not ok then
		S.toast("Ingen kontakt med servern", "error")
		return false
	end
	if not a and b then S.toast(b, "error") end
	return a, b, c
end

-- my garage
function S.plot()
	local i = S.meta.plot or plr:GetAttribute("Plot")
	local g = workspace:FindFirstChild("Garage")
	return i and g and g:FindFirstChild("Plot" .. i), i
end
function S.origin()
	local _, i = S.plot()
	return CFrame.new(Config.plotOrigin(i or 1), 0, 0)
end
function S.moped() local p = S.profile; return p and p.mopeds[p.cur] end
function S.item(id) return S.profile and S.profile.items[id] end
function S.perf(m)
	local p = S.profile
	if not p then return nil end
	return Profile.perf(p, m)
end

-- work modes: only one at a time; modes lock walking and may take over the camera
-- hide my own character and the E-prompts while working (the camera is close)
local function workView(on)
	pcall(function() game:GetService("ProximityPromptService").Enabled = not on end)
	local char = plr.Character
	if char then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then d.LocalTransparencyModifier = on and 1 or 0 end
		end
	end
end
function S.setMode(name)
	if S.mode == name then return true end
	if S.mode then return false end
	S.mode = name
	S.tip(nil)
	workView(true)
	S.lockMove(true)
	S.modeEv:Fire(name)
	return true
end
function S.endMode(name)
	if name and S.mode ~= name then return end
	S.mode = nil
	workView(false)
	S.lockMove(false)
	S.camRelease()
	S.modeEv:Fire(nil)
end
local saved
function S.lockMove(on)
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if on then
		saved = saved or { hum.WalkSpeed, hum.JumpPower }
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	elseif saved then
		hum.WalkSpeed, hum.JumpPower = saved[1], saved[2]
		saved = nil
	end
end
function S.camTo(cf, fov, t)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	if t and t > 0 then
		TweenService:Create(cam, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = cf, FieldOfView = fov or 60 }):Play()
	else
		cam.CFrame = cf
		cam.FieldOfView = fov or 60
	end
end
function S.camRelease()
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if hum then cam.CameraSubject = hum end
end
-- is a world object part of my own plot?
function S.isMine(inst)
	local plot = S.plot()
	return plot ~= nil and inst:IsDescendantOf(plot)
end

return S

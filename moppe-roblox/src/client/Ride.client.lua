-- Riding: the client drives its own moped (network owner). Speed comes from Performance (the same model as the
-- numbers in Moped Info), the moped follows the ground with raycasts, stops at walls, leans in curves and the
-- suspension bobs. Engine temperature rises with throttle; too hot wears the piston and can seize it.
-- HUD: speedometer with rpm and temperature, minimap with roads and the delivery target.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Shared = RS:WaitForChild("Shared")
local Performance = require(Shared.Performance)
local MopedDef = require(Shared.MopedDef)
local Config = require(Shared.Config)
local Map = require(Shared.Map)
local plr = Players.LocalPlayer
local S = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UIKit"))
local RideEv = RS:WaitForChild("Remotes"):WaitForChild("Ride")

local STUD = Config.STUD
local R = { v = 0, yaw = 0, lean = 0, pitch = 0, bob = 0, bobV = 0, temp = 40, rpm = 0, thr = 0, over = 0, cfg = nil, model = nil }

---------------------------------------------------------------- HUD
local gui = UI.screen("Körning", 4, plr)
gui.Enabled = false
local speedo = UI.panel(gui, UDim2.fromOffset(230, 150), UDim2.new(1, -16, 1, -16), { anchor = Vector2.new(1, 1), name = "Hastighet" })
local kmh = UI.text(speedo, "0", UDim2.fromOffset(150, 70), UDim2.fromOffset(16, 8), { font = UI.BLACK, ts = 60, name = "Kmh" })
UI.text(speedo, "KM/H", UDim2.fromOffset(60, 20), UDim2.fromOffset(160, 50), { ts = 14, color = UI.C.dim, font = UI.BOLD })
UI.text(speedo, "Varv", UDim2.fromOffset(60, 18), UDim2.fromOffset(16, 86), { ts = 12, color = UI.C.dim })
local rpmBg, rpmFill = UI.bar(speedo, UDim2.fromOffset(150, 10), UDim2.fromOffset(64, 90), 0, UI.C.accent2)
local rpmText = UI.text(speedo, "", UDim2.fromOffset(60, 18), UDim2.fromOffset(160, 86), { ts = 12, xa = Enum.TextXAlignment.Right })
UI.text(speedo, "Temp", UDim2.fromOffset(60, 18), UDim2.fromOffset(16, 112), { ts = 12, color = UI.C.dim })
local tempBg, tempFill = UI.bar(speedo, UDim2.fromOffset(150, 10), UDim2.fromOffset(64, 116), 0, UI.C.green)
local tempText = UI.text(speedo, "", UDim2.fromOffset(60, 18), UDim2.fromOffset(160, 112), { ts = 12, xa = Enum.TextXAlignment.Right })
local warn = UI.panel(gui, UDim2.fromOffset(420, 40), UDim2.new(0.5, 0, 0, 60), { anchor = Vector2.new(0.5, 0), name = "Varning", color = UI.C.red, transp = 0.1, visible = false })
local warnText = UI.text(warn, "", UDim2.fromScale(1, 1), nil, { ts = 15, font = UI.BOLD, xa = Enum.TextXAlignment.Center })
local help = UI.text(gui, "W gas · S broms · A/D styr · Mellanslag kliv av · R tillbaka till garaget", UDim2.fromOffset(560, 20), UDim2.new(0.5, 0, 1, -14), { anchor = Vector2.new(0.5, 1), ts = 13, color = UI.C.text, xa = Enum.TextXAlignment.Center })
local deliver = UI.button(gui, "Lämna paketet", UDim2.fromOffset(220, 46), UDim2.new(0.5, 0, 1, -60), { kind = "green", anchor = Vector2.new(0.5, 1), name = "Lämna", ts = 18 })
deliver.Visible = false

-- minimap: roads as rotated frames inside a clipped square, the moped in the middle pointing up
local mapFrame = UI.panel(gui, UDim2.fromOffset(200, 200), UDim2.fromOffset(16, 16), { name = "Minikarta", clip = true, color = Color3.fromRGB(70, 100, 60), transp = 0.1 })
local mapInner = UI.new("Frame", { Size = UDim2.fromOffset(0, 0), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Name = "Vägar" }, mapFrame)
local MAP_SCALE = 0.32 -- pixels per stud
for i, r in ipairs(Map.ROADS) do
	local ax, az, bx, bz = r.a[1], r.a[2], r.b[1], r.b[2]
	local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
	local f = UI.new("Frame", {
		Size = UDim2.fromOffset(len * MAP_SCALE + r.w * MAP_SCALE, math.max(3, r.w * MAP_SCALE)), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((ax + bx) / 2 * MAP_SCALE, (az + bz) / 2 * MAP_SCALE), Rotation = math.deg(math.atan2(bz - az, bx - ax)),
		BackgroundColor3 = r.track and Color3.fromRGB(200, 120, 60) or Color3.fromRGB(70, 70, 76), BorderSizePixel = 0, Name = "Väg" .. i,
	}, mapInner)
end
local home = UI.new("Frame", { Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = UI.C.accent2, BorderSizePixel = 0, Name = "Hem" }, mapInner)
UI.corner(home, 4)
local pin = UI.new("Frame", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = UI.C.yellow, BorderSizePixel = 0, Name = "Mål", Visible = false }, mapInner)
UI.corner(pin, 6)
local me = UI.new("TextLabel", { Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Text = "▲", TextColor3 = Color3.new(1, 1, 1), TextSize = 16, Font = UI.BOLD, Name = "Jag", ZIndex = 3 }, mapFrame)

-- the destination beacon in the world (local only)
local beacon = Instance.new("Part")
beacon.Name = "Leveransmål"
beacon.Anchored = true
beacon.CanCollide = false
beacon.CanQuery = false
beacon.Shape = Enum.PartType.Cylinder
beacon.Size = Vector3.new(60, 10, 10)
beacon.Material = Enum.Material.Neon
beacon.Color = Color3.fromRGB(241, 196, 15)
beacon.Transparency = 0.55

local function activeDelivery()
	local p = S.profile
	if not p then return nil end
	for _, j in ipairs(p.jobs) do if j.type == "leverans" then return j, Map.PLACES[j.dest] end end
end

---------------------------------------------------------------- riding state
local function myRide()
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local model = seat and seat.Parent
	if model and model:GetAttribute("OwnerId") == plr.UserId and model.PrimaryPart then return model, hum end
end
local function loadCfg()
	local p, m = S.profile, S.moped()
	if p and m and m.engine then R.cfg = Performance.config(p.items, m.engine, m.slots, m.jet or 0) end
end
S.changed.Event:Connect(loadCfg)

local keys = {}
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	keys[input.KeyCode] = true
	if input.KeyCode == Enum.KeyCode.R and not S.mode and myRide() then S.api("home") end
end)
UIS.InputEnded:Connect(function(input) keys[input.KeyCode] = false end)
UIS.WindowFocusReleased:Connect(function() keys = {} end)
local function key(...) for _, k in ipairs({ ... }) do if keys[k] then return true end end return false end

deliver.Activated:Connect(function()
	local j = activeDelivery()
	if j then S.api("completeJob", j.id) end
end)

local overAcc = 0
RunService.Heartbeat:Connect(function(dt)
	local model, hum = myRide()
	if not model then
		if R.model then
			R.model, R.v = nil, 0
			gui.Enabled = false
			beacon.Parent = nil
		end
		-- the delivery pin also helps when walking
		return
	end
	if R.model ~= model then
		R.model = model
		R.v, R.lean, R.pitch, R.bob, R.bobV = 0, 0, 0, 0, 0
		local _, y = model.PrimaryPart.CFrame:ToOrientation()
		R.yaw = y
		loadCfg()
		gui.Enabled = true
		local light = model:FindFirstChild("Strålkastare", true)
		local spot = light and light:FindFirstChildOfClass("SpotLight")
		if spot then spot.Enabled = true end
	end
	local c = R.cfg
	if not c then return end
	dt = math.min(dt, 0.1)
	local root = model.PrimaryPart
	local def = MopedDef.MODELS[model:GetAttribute("Model") or "citi"]
	-- input
	local thr = key(Enum.KeyCode.W, Enum.KeyCode.Up) and 1 or 0
	local brk = key(Enum.KeyCode.S, Enum.KeyCode.Down) and 1 or 0
	local steer = (key(Enum.KeyCode.D, Enum.KeyCode.Right) and 1 or 0) - (key(Enum.KeyCode.A, Enum.KeyCode.Left) and 1 or 0)
	if R.seized then thr = 0 end
	R.thr = R.thr + (thr - R.thr) * math.min(1, dt * 6)
	-- longitudinal (metres per second)
	local force, rpm = Performance.force(c, math.max(0, R.v), R.thr)
	R.rpm = R.thr > 0.05 and rpm or math.max(c.idle, R.rpm - dt * 6000)
	local a = (force - Performance.resist(math.abs(R.v)) * (R.v >= 0 and 1 or -1)) / Performance.MASS
	if brk > 0 then
		if R.v > 0.3 then a = a - 7.5 * c.brake else a = -1.2 end -- slow backing when stopped
	end
	R.v = R.v + a * dt
	if R.v < -1.6 then R.v = -1.6 end
	if thr == 0 and brk == 0 and math.abs(R.v) < 0.15 then R.v = 0 end
	-- steering: tighter at low speed, limited by tyre grip
	local vs = math.abs(R.v)
	local turn = steer * 1.7 * c.handling / (1 + vs * 0.12)
	local maxTurn = (7 * c.grip) / math.max(vs, 1)
	turn = math.clamp(turn, -maxTurn, maxTurn)
	R.yaw = R.yaw - turn * dt * (R.v >= 0 and 1 or -1)
	local targetLean = -steer * math.min(1, vs / 10) * 0.42
	R.lean = R.lean + (targetLean - R.lean) * math.min(1, dt * 5)
	-- move, follow the ground, stop at walls
	local fwd = Vector3.new(-math.sin(R.yaw), 0, -math.cos(R.yaw))
	local step = fwd * (R.v / STUD) * dt
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, plr.Character }
	local pos = root.Position
	local groundOffset = def.r
	if step.Magnitude > 1e-4 then
		local wall = workspace:Raycast(pos + Vector3.new(0, 0.6, 0), step + step.Unit * (def.wb / 2 + 0.8), params)
		if wall and wall.Instance.CanCollide and wall.Normal.Y < 0.6 then
			R.v = 0
			step = Vector3.new()
		end
	end
	local newPos = pos + step
	local function groundAt(p)
		local hit = workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
		return hit and hit.Position.Y
	end
	local gy = groundAt(newPos)
	local y = gy and (gy + groundOffset) or newPos.Y
	-- pitch from the ground under the wheels
	local gf, gb = groundAt(newPos + fwd * def.wb / 2), groundAt(newPos - fwd * def.wb / 2)
	if gf and gb then R.pitch = R.pitch + (math.atan2(gf - gb, def.wb) - R.pitch) * math.min(1, dt * 8) end
	-- suspension: a spring on the body height
	local target = y
	R.bobV = R.bobV + ((target - (pos.Y + R.bob)) * 80 - R.bobV * 12) * dt
	R.bob = math.clamp(R.bob + R.bobV * dt, -0.3, 0.3)
	local finalY = target + R.bob * 0.4
	local cf = CFrame.new(newPos.X, finalY, newPos.Z) * CFrame.Angles(0, R.yaw, 0) * CFrame.Angles(R.pitch, 0, R.lean)
	root.CFrame = cf
	root.AssemblyLinearVelocity = fwd * (R.v / STUD)
	root.AssemblyAngularVelocity = Vector3.new()
	-- temperature: rises towards the full-throttle value with throttle, cools with speed
	local kmhNow = vs * 3.6
	local hot = Performance.temp(c, kmhNow)
	local targetT = 45 + (hot - 45) * R.thr
	R.temp = R.temp + (targetT - R.temp) * math.min(1, dt / (targetT > R.temp and 14 or 8))
	if R.temp > Performance.TEMP_WARN then
		overAcc = overAcc + dt
		warn.Visible = true
		warnText.Text = R.temp > Performance.TEMP_SEIZE - 8 and "Motorn är på väg att skära! Släpp gasen!" or "Motorn går varm – släpp gasen en stund"
		if overAcc >= 1 then RideEv:FireServer("overheat", overAcc); overAcc = 0 end
	else
		warn.Visible = R.seized == true
		overAcc = 0
	end
	-- seized engine (from the server's wear)
	local p, m = S.profile, S.moped()
	local k = p and m and m.engine and p.items[m.engine.kolv]
	R.seized = k ~= nil and (k.wear or 0) >= 1
	if R.seized then warn.Visible = true; warnText.Text = "Kolvskär! Tryck R för att åka hem och byta kolv." end
	-- smoke
	local smoke = root:FindFirstChild("Rök", true)
	if smoke then smoke.Rate = R.seized and 0 or (4 + 30 * R.thr) end
	-- HUD
	kmh.Text = tostring(math.floor(kmhNow + 0.5))
	rpmFill.Size = UDim2.fromScale(math.clamp(R.rpm / math.max(c.limit, 1), 0, 1), 1)
	rpmFill.BackgroundColor3 = R.rpm >= c.limit - 150 and UI.C.red or UI.C.accent2
	rpmText.Text = tostring(math.floor(R.rpm / 100) * 100)
	tempFill.Size = UDim2.fromScale(math.clamp((R.temp - 20) / (Performance.TEMP_SEIZE - 20), 0, 1), 1)
	tempFill.BackgroundColor3 = R.temp > Performance.TEMP_WARN and UI.C.red or (R.temp > 120 and UI.C.yellow or UI.C.green)
	tempText.Text = string.format("%d °C", math.floor(R.temp))
	-- minimap
	mapFrame.Visible = S.settings.minimap
	-- north-up map centred on the moped; the arrow turns with the heading
	mapInner.Position = UDim2.new(0.5, -newPos.X * MAP_SCALE, 0.5, -newPos.Z * MAP_SCALE)
	me.Rotation = -math.deg(R.yaw)
	local o = S.origin()
	home.Position = UDim2.fromOffset(o.X * MAP_SCALE, o.Z * MAP_SCALE)
	-- delivery job
	local j, pl = activeDelivery()
	if pl then
		pin.Visible = true
		pin.Position = UDim2.fromOffset(pl.x * MAP_SCALE, pl.z * MAP_SCALE)
		beacon.CFrame = CFrame.new(pl.x, 30, pl.z) * CFrame.Angles(0, 0, math.rad(90))
		beacon.Parent = workspace
		local d = (Vector3.new(pl.x, 0, pl.z) - Vector3.new(newPos.X, 0, newPos.Z)).Magnitude
		deliver.Visible = d < Map.DELIVER_RADIUS
	else
		pin.Visible = false
		beacon.Parent = nil
		deliver.Visible = false
	end
end)

-- Paint booth: the panel hangs on the stand (shown enlarged). Pick a colour (library, RGB sliders or HEX),
-- a finish and the gloss, then hold the left button and spray with the gun in your hand. Coverage builds up
-- where you spray; too much in one place makes runs. Mouse wheel moves the gun closer or further away.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Shared = RS:WaitForChild("Shared")
local Parts = require(Shared.Parts)
local Paint = require(Shared.Paint)
local Models = require(Shared.Models)
local GarageBuilder = require(Shared.GarageBuilder)
local plr = Players.LocalPlayer
local S = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UIKit"))

local gui = UI.screen("Lackering", 10, plr)
gui.Enabled = false
local L = { color = { 200, 22, 30 }, finish = "blank", gloss = 0.7, dist = 1.0, spraying = false, state = nil, t = 0, even = 0 }

---------------------------------------------------------------- UI
local info = UI.panel(gui, UDim2.fromOffset(480, 40), UDim2.fromOffset(12, 8), { name = "Info", transp = 0.15 })
UI.text(info, "Håll vänster musknapp och spraya jämnt över kåpan", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(12, 0), { ts = 15, font = UI.BOLD })
local side = UI.panel(gui, UDim2.fromOffset(290, 600), UDim2.new(1, -12, 0, 8), { anchor = Vector2.new(1, 0), name = "Färgpanel" })
UI.pad(side, 12)
UI.text(side, "Färg:", UDim2.new(1, 0, 0, 20), nil, { font = UI.BOLD, ts = 15 })
local swatches = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 70), Position = UDim2.fromOffset(0, 24), BackgroundTransparency = 1, Name = "Bibliotek" }, side)
UI.grid(swatches, UDim2.fromOffset(28, 28), UDim2.fromOffset(5, 5))
local preview = UI.new("Frame", { Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(0, 104), BackgroundColor3 = Color3.new(1, 0, 0), BorderSizePixel = 0, Name = "Förhandsvisning" }, side)
UI.corner(preview, 8)
local colorName = UI.text(side, "", UDim2.fromOffset(190, 22), UDim2.fromOffset(70, 104), { ts = 14, font = UI.BOLD, name = "Färgnamn" })
local hex = UI.new("TextBox", { Size = UDim2.fromOffset(110, 30), Position = UDim2.fromOffset(70, 130), BackgroundColor3 = UI.C.panel2, TextColor3 = UI.C.text, Font = UI.FONT, TextSize = 15, ClearTextOnFocus = false, Text = "", Name = "HEX" }, side)
UI.corner(hex, 6)
UI.text(side, "HEX", UDim2.fromOffset(40, 30), UDim2.fromOffset(186, 130), { ts = 13, color = UI.C.dim })
local sliders = {}
local function slider(y, label, color, get, set)
	UI.text(side, label, UDim2.fromOffset(20, 22), UDim2.fromOffset(0, y), { ts = 14, font = UI.BOLD })
	local bar = UI.new("Frame", { Size = UDim2.fromOffset(190, 10), Position = UDim2.fromOffset(26, y + 6), BackgroundColor3 = color, BorderSizePixel = 0, Name = label .. "Reglage" }, side)
	UI.corner(bar, 5)
	local knob = UI.new("Frame", { Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Name = "Knopp" }, bar)
	UI.corner(knob, 8)
	local val = UI.text(side, "", UDim2.fromOffset(46, 22), UDim2.fromOffset(222, y), { ts = 13, xa = Enum.TextXAlignment.Right })
	local s = { bar = bar, knob = knob, val = val, get = get, set = set }
	bar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then s.drag = true end end)
	sliders[#sliders + 1] = s
	return s
end
local function hexOf(c) return Paint.hex(c) end
slider(172, "R", Color3.fromRGB(200, 50, 50), function() return L.color[1] / 255 end, function(v) L.color[1] = math.floor(v * 255 + 0.5) end)
slider(198, "G", Color3.fromRGB(50, 170, 70), function() return L.color[2] / 255 end, function(v) L.color[2] = math.floor(v * 255 + 0.5) end)
slider(224, "B", Color3.fromRGB(50, 90, 210), function() return L.color[3] / 255 end, function(v) L.color[3] = math.floor(v * 255 + 0.5) end)
UI.text(side, "Lacktyp:", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 256), { font = UI.BOLD, ts = 15 })
local finishes = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 70), Position = UDim2.fromOffset(0, 280), BackgroundTransparency = 1, Name = "Lacktyper" }, side)
UI.grid(finishes, UDim2.fromOffset(84, 30), UDim2.fromOffset(4, 4))
UI.text(side, "Glans:", UDim2.fromOffset(60, 22), UDim2.fromOffset(0, 352), { font = UI.BOLD, ts = 15 })
local glossSlider = slider(376, "", Color3.fromRGB(120, 130, 150), function() return L.gloss end, function(v) L.gloss = v end)
local statText = UI.text(side, "", UDim2.new(1, 0, 0, 90), UDim2.fromOffset(0, 404), { ts = 14, wrap = true, rich = true, ya = Enum.TextYAlignment.Top, name = "Resultat" })
local distText = UI.text(side, "", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 494), { ts = 13, color = UI.C.dim, name = "Avstånd" })
local buttons = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 530), BackgroundTransparency = 1, Name = "Knappar" }, side)
UI.list(buttons, 6, true)
local picker = UI.panel(gui, UDim2.fromOffset(420, 320), UDim2.fromScale(0.5, 0.5), { anchor = Vector2.new(0.5, 0.5), name = "Välj", visible = false })

local function refreshColor()
	local c = Color3.fromRGB(L.color[1], L.color[2], L.color[3])
	preview.BackgroundColor3 = c
	local name = "Egen färg"
	for _, e in ipairs(Paint.LIBRARY) do if e.c[1] == L.color[1] and e.c[2] == L.color[2] and e.c[3] == L.color[3] then name = e.n end end
	colorName.Text = name
	if not hex:IsFocused() then hex.Text = hexOf(L.color) end
	for _, s in ipairs(sliders) do
		local v = s.get()
		s.knob.Position = UDim2.fromScale(v, 0.5)
		s.val.Text = s == glossSlider and string.format("%d %%", math.floor(v * 100)) or tostring(math.floor(v * 255 + 0.5))
	end
	UI.clear(finishes)
	for i, f in ipairs(Paint.FINISH) do
		UI.button(finishes, f.n, UDim2.fromOffset(84, 30), nil, { kind = L.finish == f.id and "primary" or "secondary", ts = 13, order = i, name = f.id }, function() L.finish = f.id; refreshColor() end)
	end
	if L.cells then for _, p in pairs(L.cells) do p.Color = c end end
end
for i, e in ipairs(Paint.LIBRARY) do
	local b = UI.new("TextButton", { Size = UDim2.fromOffset(28, 28), BackgroundColor3 = Color3.fromRGB(e.c[1], e.c[2], e.c[3]), Text = "", LayoutOrder = i, Name = e.n, AutoButtonColor = true }, swatches)
	UI.corner(b, 6)
	UI.stroke(b, UI.C.line, 1, 0.3)
	b.Activated:Connect(function() L.color = { e.c[1], e.c[2], e.c[3] }; refreshColor() end)
end
hex.FocusLost:Connect(function()
	local c = Paint.validHex(hex.Text)
	if c then L.color = c else S.toast("Skriv HEX som #RRGGBB", "error") end
	refreshColor()
end)

---------------------------------------------------------------- scene: enlarged panel, coverage cells, gun and hand
local scene = Instance.new("Model")
scene.Name = "LackLokal"
local function boothCF() return S.origin() * GarageBuilder.BOOTH * CFrame.new(0, 1.6, 0) end
local frame -- face frame: LookVector points from the panel towards the camera
local function buildScene(id)
	scene:ClearAllChildren()
	local it = S.item(id)
	local model = Models.item(it.sku, nil) -- unpainted (primer)
	model:ScaleTo(2.2)
	model:PivotTo(boothCF())
	for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then d.Color = Color3.fromRGB(160, 162, 166); d.Material = Enum.Material.SmoothPlastic end end
	model.Parent = scene
	L.panelModel = model
	local cf, size = model:GetBoundingBox()
	-- look at the widest side: thinnest horizontal axis is the normal
	local normal = size.X < size.Z and Vector3.new(-1, 0, 0) or Vector3.new(0, 0, -1)
	local w = normal.X ~= 0 and size.Z or size.X
	local h = size.Y
	local depth = normal.X ~= 0 and size.X or size.Z
	local origin = boothCF()
	local worldNormal = origin:VectorToWorldSpace(normal)
	frame = CFrame.lookAt(cf.Position + worldNormal * (depth / 2 + 0.06), cf.Position + worldNormal * 5)
	L.w, L.h = math.max(w, 1), math.max(h, 1)
	-- coverage cells only where the panel is behind them
	L.cells = {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local mk = Models.maker(scene)
	for row = 1, Paint.ROWS do
		for col = 1, Paint.COLS do
			local x = -L.w / 2 + (col - 0.5) * L.w / Paint.COLS
			local y = L.h / 2 - (row - 0.5) * L.h / Paint.ROWS
			local p0 = frame * Vector3.new(x, y, 0)
			local hit = workspace:Raycast(p0 + frame.LookVector * 1, -frame.LookVector * (depth + 2), params)
			if hit then
				local p = mk.box("Lack", Vector3.new(L.w / Paint.COLS * 1.02, L.h / Paint.ROWS * 1.02, 0.03), CFrame.new(hit.Position + hit.Normal * 0.03) * frame.Rotation, Color3.fromRGB(L.color[1], L.color[2], L.color[3]), Enum.Material.SmoothPlastic)
				p.Transparency = 1
				p.CanQuery = false
				L.cells[(row - 1) * Paint.COLS + col] = p
			end
		end
	end
	-- cells with no panel behind them count as painted so they do not lower the coverage
	L.state = Paint.new()
	for i = 1, Paint.COLS * Paint.ROWS do if not L.cells[i] then L.state.cells[i] = 1 end end
	-- gun and hand rig
	local hand = Models.hand(scene, CFrame.new(), true)
	L.handRig = {}
	for _, d in ipairs(hand:GetDescendants()) do if d:IsA("BasePart") then d.CanQuery = false; L.handRig[#L.handRig + 1] = { d, d.CFrame } end end
	local gun = Instance.new("Model")
	gun.Name = "Sprutpistol"
	gun.Parent = scene
	Models.tool(gun, "spruta", CFrame.new(), L.even > 0.5)
	L.gunRig = {}
	for _, d in ipairs(gun:GetDescendants()) do if d:IsA("BasePart") then d.CanQuery = false; L.gunRig[#L.gunRig + 1] = { d, d.CFrame } end end
	local nozzle = mk.box("Munstycke", Vector3.new(0.05, 0.05, 0.05), CFrame.new(), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	nozzle.Transparency = 1
	local att = Instance.new("Attachment")
	att.Parent = nozzle
	L.mist = Instance.new("ParticleEmitter")
	L.mist.Rate = 0
	L.mist.Lifetime = NumberRange.new(0.3, 0.6)
	L.mist.Speed = NumberRange.new(8, 10)
	L.mist.SpreadAngle = Vector2.new(12, 12)
	L.mist.Size = NumberSequence.new(0.15, 0.9)
	L.mist.Transparency = NumberSequence.new(0.4, 1)
	L.mist.Parent = att
	L.nozzle = nozzle
	scene.Parent = workspace
	S.camTo(frame * CFrame.new(0, 0.3, 7.5) * CFrame.Angles(math.rad(-3), 0, 0), 45, 0.4)
end
local function paintCells()
	for i, p in pairs(L.cells) do
		local x = L.state.cells[i]
		p.Transparency = 1 - math.clamp(x, 0, 1) * 0.92
		p.Color = Color3.fromRGB(L.color[1], L.color[2], L.color[3])
		if x > 1.8 then p.Color = p.Color:Lerp(Color3.new(0, 0, 0), 0.35) end
		local fin = Paint.FIN[L.finish]
		p.Material = Enum.Material[fin.mat]
		p.Reflectance = fin.refl[1] + (fin.refl[2] - fin.refl[1]) * L.gloss
	end
end
local function refreshStats()
	local r = Paint.result(L.state)
	local col = r.q >= 0.75 and "#2ECC71" or (r.q >= 0.5 and "#F1C40F" or "#E74C3C")
	statText.Text = string.format('Täckning: <b>%d %%</b>\nJämnhet: <b>%d %%</b>\nRinningar: <b>%d</b>\nKvalitet: <font color="%s"><b>%s</b></font>', math.floor(r.cover * 100), math.floor(r.even * 100), math.floor(r.runs * Paint.COLS * Paint.ROWS + 0.5), col, r.label)
	distText.Text = string.format("Avstånd: %s (rullhjul)", L.dist < 0.85 and "nära" or (L.dist > 1.2 and "långt" or "lagom"))
end
local function buildButtons()
	UI.clear(buttons)
	UI.button(buttons, "Klar", UDim2.fromOffset(84, 36), nil, { kind = "green", order = 1 }, function()
		if L.t < 3 then S.toast("Spraya kåpan först", "error"); return end
		local ok, r = S.api("paintDone", L.color, L.finish, L.gloss, L.state)
		if ok then
			S.toast(string.format("Lackerat: %s (%d %%). Lacken torkar i 20 sekunder.", r.label, math.floor(r.q * 100)), "ok")
			S.endMode("paint")
		end
	end)
	UI.button(buttons, "Börja om", UDim2.fromOffset(90, 36), nil, { kind = "secondary", order = 2 }, function()
		local s2 = Paint.new()
		for i = 1, Paint.COLS * Paint.ROWS do if not L.cells[i] then s2.cells[i] = 1 end end
		L.state = s2
		paintCells()
		refreshStats()
	end)
	UI.button(buttons, "Avbryt", UDim2.fromOffset(84, 36), nil, { kind = "danger", order = 3 }, function() S.endMode("paint") end)
end

---------------------------------------------------------------- open / close
local function begin()
	local ok, inf = S.api("paintStart")
	if not ok then return false end
	L.even = inf.even or 0
	L.t = 0
	buildScene(inf.item)
	side.Visible, info.Visible = true, true
	refreshColor()
	buildButtons()
	paintCells()
	refreshStats()
	return true
end
local function showPicker()
	UI.clear(picker)
	UI.pad(picker, 12)
	UI.list(picker, 6)
	UI.text(picker, "Häng en kåpa i lackboxen", UDim2.new(1, 0, 0, 26), nil, { font = UI.BOLD, ts = 16, order = 0 })
	local n = 0
	for id, it in pairs(S.profile.items) do
		local part = Parts.get(it.sku)
		if part.kind == "kapa" and (it.loc == "hylla" or it.loc == "bank" or it.loc == "golv" or it.loc == "hand" or it.loc:sub(1, 4) == "box:") then
			n = n + 1
			UI.button(picker, part.name, UDim2.new(1, 0, 0, 34), nil, { kind = "secondary", order = n, ts = 14 }, function()
				if S.api("moveTo", id, "lack") then picker.Visible = false; begin() end
			end)
		end
	end
	if n == 0 then UI.text(picker, "Du har ingen lös kåpa. Gå till mopeden, klicka på en kåpa och välj Lackera, eller beställ en kåpa.", UDim2.new(1, 0, 0, 60), nil, { ts = 14, wrap = true, color = UI.C.dim, order = 1 }) end
	UI.button(picker, "Avbryt", UDim2.new(1, 0, 0, 36), nil, { kind = "danger", order = 99 }, function() S.endMode("paint") end)
	picker.Visible = true
end
local function open()
	if not S.setMode("paint") then return end
	gui.Enabled = true
	side.Visible, info.Visible = false, false
	S.camTo(S.origin() * GarageBuilder.BOOTH * CFrame.new(0, 2, -9) * CFrame.Angles(math.rad(-8), math.pi, 0), 50, 0.4)
	local hung
	for _, it in pairs(S.profile.items) do if it.loc == "lack" then hung = true end end
	if not (hung and begin()) then showPicker() end
end
local function close()
	gui.Enabled = false
	picker.Visible = false
	L.spraying = false
	L.cells = nil
	scene:ClearAllChildren()
	scene.Parent = nil
end
S.open.Event:Connect(function(what, atStation) if what == "paint" and atStation then open() end end)
S.modeEv.Event:Connect(function(mode) if mode ~= "paint" and gui.Enabled then close() end end)

---------------------------------------------------------------- input and spraying
UIS.InputBegan:Connect(function(input, gp)
	if S.mode ~= "paint" or not L.state then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not gp then L.spraying = true end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		L.spraying = false
		for _, s in ipairs(sliders) do s.drag = false end
	end
end)
UIS.InputChanged:Connect(function(input)
	if S.mode ~= "paint" then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		L.dist = math.clamp(L.dist - input.Position.Z * 0.1, 0.6, 1.6)
		refreshStats()
	elseif input.UserInputType == Enum.UserInputType.MouseMovement then
		for _, s in ipairs(sliders) do
			if s.drag then
				local m = UIS:GetMouseLocation()
				s.set(math.clamp((m.X - s.bar.AbsolutePosition.X) / s.bar.AbsoluteSize.X, 0, 1))
				refreshColor()
				paintCells()
			end
		end
	end
end)
local acc = 0
RunService.RenderStepped:Connect(function(dt)
	if S.mode ~= "paint" or not L.state or not frame or not L.handRig then return end
	local cam = workspace.CurrentCamera
	local m = UIS:GetMouseLocation()
	local ray = cam:ViewportPointToRay(m.X, m.Y)
	local n = frame.LookVector
	local denom = ray.Direction:Dot(n)
	if math.abs(denom) < 1e-4 then return end
	local hit = ray.Origin + ray.Direction * ((frame.Position - ray.Origin):Dot(n) / denom)
	-- the gun hovers in front of the panel at the chosen distance, nozzle aimed at the point
	local gunPos = hit + n * (1.2 + 1.6 * L.dist) + frame.UpVector * 0.25
	local gunCF = CFrame.lookAt(gunPos, hit)
	for _, r in ipairs(L.gunRig) do r[1].CFrame = gunCF * r[2] end
	local handCF = gunCF * CFrame.new(0.05, -0.45, 0.25) * CFrame.Angles(math.rad(-70), 0, 0)
	for _, r in ipairs(L.handRig) do r[1].CFrame = handCF * r[2] end
	L.nozzle.CFrame = gunCF * CFrame.new(0, 0.03, -0.32)
	L.mist.Color = ColorSequence.new(Color3.fromRGB(L.color[1], L.color[2], L.color[3]))
	L.mist.Rate = L.spraying and 90 or 0
	if L.spraying then
		local l = frame:PointToObjectSpace(hit)
		local u, v = (l.X + L.w / 2) / L.w, (L.h / 2 - l.Y) / L.h
		if u > -0.15 and u < 1.15 and v > -0.15 and v < 1.15 then Paint.spray(L.state, u, v, dt, L.dist, L.even) else L.state.t = L.state.t + dt end
		L.t = L.t + dt
		acc = acc + dt
		if acc > 0.08 then acc = 0; paintCells(); refreshStats() end
	end
end)

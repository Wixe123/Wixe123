-- Cylinder porting in first person: the cylinder sits in the vise (shown enlarged), the four port windows glow
-- where material should come off, and your hand holds the die grinder at the mouse. Hold the left button to
-- grind. Cells fade from glowing blue to polished metal when done, and turn red if you go too deep.
-- A shaky hand (cheap grinder) makes it harder; training mode lets you practise without a cylinder.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = RS:WaitForChild("Shared")
local Parts = require(Shared.Parts)
local Porting = require(Shared.Porting)
local Models = require(Shared.Models)
local GarageBuilder = require(Shared.GarageBuilder)
local plr = Players.LocalPlayer
local S = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UIKit"))

local gui = UI.screen("Portning", 10, plr)
gui.Enabled = false
local P = { state = nil, zone = 1, training = false, steady = 0, speed = 1, grinding = false, t = 0 }
local SIZE = 3.2 -- the enlarged cylinder block
local FACES = { front = 0, right = 90, back = 180, left = 270 } -- rotation so the face looks at the camera

---------------------------------------------------------------- UI
local topInfo = UI.panel(gui, UDim2.fromOffset(470, 40), UDim2.fromOffset(12, 8), { name = "Info", transp = 0.15 })
UI.text(topInfo, "Porta de markerade områdena för bästa prestanda!", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(12, 0), { ts = 15, font = UI.BOLD })
local zones = UI.panel(gui, UDim2.fromOffset(250, 250), UDim2.new(1, -12, 0, 8), { anchor = Vector2.new(1, 0), name = "Zoner" })
UI.pad(zones, 10)
UI.list(zones, 4)
local stats = UI.panel(gui, UDim2.fromOffset(250, 190), UDim2.new(1, -12, 0, 266), { anchor = Vector2.new(1, 0), name = "Resultat" })
UI.pad(stats, 12)
UI.text(stats, "Framsteg", UDim2.new(1, 0, 0, 22), nil, { font = UI.BOLD, ts = 17, xa = Enum.TextXAlignment.Center })
local progText = UI.text(stats, "0 %", UDim2.new(1, 0, 0, 26), UDim2.fromOffset(0, 22), { font = UI.BLACK, ts = 24, xa = Enum.TextXAlignment.Center, name = "Procent" })
local _, progFill = UI.bar(stats, UDim2.new(1, 0, 0, 10), UDim2.fromOffset(0, 52), 0, UI.C.accent2)
local evenRow = UI.text(stats, "", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 72), { ts = 15, name = "Jämnhet" })
local precRow = UI.text(stats, "", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 96), { ts = 15, name = "Precision" })
local overRow = UI.text(stats, "", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 120), { ts = 15, name = "Överportat" })
local qualRow = UI.text(stats, "", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 144), { ts = 16, font = UI.BOLD, name = "Kvalitet", rich = true })
local buttons = UI.new("Frame", { Size = UDim2.fromOffset(700, 44), Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Name = "Knappar" }, gui)
UI.list(buttons, 8, true, Enum.HorizontalAlignment.Center)
local hint = UI.panel(gui, UDim2.fromOffset(380, 56), UDim2.new(1, -12, 1, -64), { anchor = Vector2.new(1, 1), name = "Tips", transp = 0.2 })
UI.text(hint, "Håll vänster musknapp och för slipen över den gröna ytan. Den slocknar när porten är klar. A/D byter port.", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(12, 0), { ts = 13, wrap = true })
local picker = UI.panel(gui, UDim2.fromOffset(420, 300), UDim2.fromScale(0.5, 0.5), { anchor = Vector2.new(0.5, 0.5), name = "Välj", visible = false })

---------------------------------------------------------------- the enlarged cylinder, cells, hand and grinder
local scene = Instance.new("Model")
scene.Name = "PortningLokal"
local cells = {} -- zoneId -> { part per cell }
local block, hand, tool, sparks
local function baseCF() return S.origin() * GarageBuilder.PORT * CFrame.new(0, 1.9, 0) end
local PORT_OUT = SIZE / 2 + 0.42 -- the port flanges stand out past the cooling fins
-- the cylinder turns in the vise so the port you work on faces you (P.ang); the camera stays put
P.ang, P.targetAng = 0, 0
local rig = {} -- cylinder parts and their position relative to the unturned cylinder
local function turnedCF() return baseCF() * CFrame.Angles(0, P.ang, 0) end
local function faceCF(face)
	-- outward face frame on the port flange: LookVector points out of the cylinder
	return turnedCF() * CFrame.Angles(0, math.rad(FACES[face]), 0) * CFrame.new(0, -0.15, -PORT_OUT)
end
local outlines = {} -- zoneId -> neon bars around the port
local function buildScene(sku)
	scene:ClearAllChildren()
	cells = {}
	outlines = {}
	P.ang, P.targetAng = 0, 0
	local mk = Models.maker(scene)
	local part = Parts.get(sku or "cylinder_origo50")
	local lvl = part and part.stats.lvl or 0
	local col = (lvl == 0 and Color3.fromRGB(128, 131, 137)) or (lvl == 1 and Color3.fromRGB(70, 72, 78)) or Color3.fromRGB(176, 180, 186)
	local M = Enum.Material
	local b = baseCF()
	-- the cylinder: core, square cooling fins, top deck with the bore and stud holes, base flange
	block = mk.box("Cylinderkropp", Vector3.new(SIZE * 0.86, SIZE * 0.95, SIZE * 0.86), b, col, M.Metal)
	for i = 0, 7 do
		mk.box("Kylfläns", Vector3.new(SIZE + 0.55, 0.09, SIZE + 0.55), b * CFrame.new(0, -1.2 + i * 0.3, 0), col, M.Metal)
	end
	local topY = SIZE * 0.475
	mk.box("Däck", Vector3.new(SIZE + 0.25, 0.26, SIZE + 0.25), b * CFrame.new(0, topY, 0), col, M.Metal)
	mk.cyl("Lopp", 0.05, 0.9, b * CFrame.new(0, topY + 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(20, 20, 22), M.SmoothPlastic)
	mk.cyl("Loppkant", 0.04, 0.98, b * CFrame.new(0, topY + 0.11, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(205, 210, 216), M.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			mk.cyl("Pinnbultshål", 0.06, 0.13, b * CFrame.new(sx * 1.25, topY + 0.12, sz * 1.25) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(18, 18, 20), M.SmoothPlastic)
		end
	end
	mk.box("Fot", Vector3.new(SIZE + 0.1, 0.2, SIZE + 0.1), b * CFrame.new(0, -SIZE * 0.475, 0), col, M.Metal)
	-- the ports: a flange through the fins, a dark port opening, the surface you grind and a glowing outline
	for _, z in ipairs(Porting.ZONES) do
		local f = faceCF(z.face)
		local w, h = z.w * SIZE * 1.3, z.h * SIZE * 1.3
		mk.box("Portfläns", Vector3.new(w + 0.55, h + 0.55, 0.62), f * CFrame.new(0, 0, 0.31), col, M.Metal)
		mk.box("Portöppning", Vector3.new(w + 0.06, h + 0.06, 0.05), f * CFrame.new(0, 0, -0.005), Color3.fromRGB(16, 16, 18), M.SmoothPlastic)
		cells[z.id] = {}
		for row = 1, Porting.ROWS do
			for c = 1, Porting.COLS do
				local cw, ch = w / Porting.COLS, h / Porting.ROWS
				local p = mk.box("Yta", Vector3.new(cw, ch, 0.03), f * CFrame.new(-w / 2 + (c - 0.5) * cw, h / 2 - (row - 0.5) * ch, -0.02), Color3.fromRGB(72, 74, 78), M.Concrete)
				p.CastShadow = false
				p:SetAttribute("Depth", 0)
				cells[z.id][(row - 1) * Porting.COLS + c] = p
			end
		end
		local t = 0.07
		local bars = {
			mk.box("Markering", Vector3.new(w + 0.2, t, 0.04), f * CFrame.new(0, h / 2 + 0.07, -0.04), Color3.fromRGB(60, 255, 120), M.Neon),
			mk.box("Markering", Vector3.new(w + 0.2, t, 0.04), f * CFrame.new(0, -h / 2 - 0.07, -0.04), Color3.fromRGB(60, 255, 120), M.Neon),
			mk.box("Markering", Vector3.new(t, h + 0.2, 0.04), f * CFrame.new(-w / 2 - 0.07, 0, -0.04), Color3.fromRGB(60, 255, 120), M.Neon),
			mk.box("Markering", Vector3.new(t, h + 0.2, 0.04), f * CFrame.new(w / 2 + 0.07, 0, -0.04), Color3.fromRGB(60, 255, 120), M.Neon),
		}
		for _, bar in ipairs(bars) do bar.CastShadow = false end
		-- glowing green layer over the port: it fades away as you grind the port to size
		local glow = mk.box("Glöd", Vector3.new(w, h, 0.02), f * CFrame.new(0, 0, -0.045), Color3.fromRGB(70, 255, 130), M.Neon)
		glow.Transparency = 0.45
		glow.CastShadow = false
		bars[#bars + 1] = glow
		outlines[z.id] = bars
	end
	-- strong work light on the cylinder
	local lamp = mk.box("Arbetslampa", Vector3.new(0.2, 0.2, 0.2), b * CFrame.new(0.5, 4.5, -4.5), Color3.new(1, 1, 1), M.SmoothPlastic)
	lamp.Transparency = 1
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 70
	spot.Range = 18
	spot.Brightness = 4
	spot.Shadows = true
	spot.Parent = lamp
	local fill = Instance.new("PointLight")
	fill.Range = 10
	fill.Brightness = 1.5
	fill.Parent = lamp
	rig = {}
	local b0 = baseCF()
	for _, d in ipairs(scene:GetChildren()) do
		if d:IsA("BasePart") then rig[#rig + 1] = { d, b0:ToObjectSpace(d.CFrame) } end
	end
	-- hand and die grinder: anchored parts moved every frame from stored offsets (no welds, no physics)
	hand = Models.hand(scene, CFrame.new(), false)
	P.handRig = {}
	for _, d in ipairs(hand:GetDescendants()) do if d:IsA("BasePart") then d.CanQuery = false; d.CastShadow = false; P.handRig[#P.handRig + 1] = { d, d.CFrame } end end
	tool = Instance.new("Model")
	tool.Name = "Slipmaskin"
	tool.Parent = scene
	Models.tool(tool, "slip", CFrame.new(), P.speed > 1.1)
	P.toolRig = {}
	for _, d in ipairs(tool:GetDescendants()) do if d:IsA("BasePart") then d.CanQuery = false; P.toolRig[#P.toolRig + 1] = { d, d.CFrame } end end
	local tipPart = mk.ball("Spets", 0.16, CFrame.new(), Color3.fromRGB(255, 170, 60), Enum.Material.Neon)
	tipPart.Transparency = 1
	tipPart.CanQuery = false
	P.tip = tipPart
	local att = Instance.new("Attachment")
	att.Parent = tipPart
	sparks = Instance.new("ParticleEmitter")
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.15, 0.4)
	sparks.Speed = NumberRange.new(6, 12)
	sparks.SpreadAngle = Vector2.new(40, 40)
	sparks.Size = NumberSequence.new(0.06, 0.01)
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 120, 40))
	sparks.Parent = att
	scene.Parent = workspace
end
-- rough cast metal -> brighter as material comes off -> polished when done -> reddish if too deep
local function cellLook(d)
	if d > Porting.OVER then return Color3.fromRGB(196, 92, 70), Enum.Material.Metal end
	if d >= Porting.TARGET then return Color3.fromRGB(222, 226, 232), Enum.Material.Metal end
	return Color3.fromRGB(72, 74, 78):Lerp(Color3.fromRGB(176, 180, 186), d), d > 0.4 and Enum.Material.Metal or Enum.Material.Concrete
end
local function paintCells()
	for zid, list in pairs(cells) do
		local depths = P.state.cells[zid]
		for i, p in ipairs(list) do
			local c, m = cellLook(depths[i])
			p.Color = c
			p.Material = m
			p:SetAttribute("Depth", depths[i])
		end
	end
	-- outlines: bright green on the port you work on, faint on the others, off when a port is done
	for i, z in ipairs(Porting.ZONES) do
		local prog = Porting.zoneProgress(P.state, z.id)
		local done = prog >= 0.97
		for _, bar in ipairs(outlines[z.id] or {}) do
			if bar.Name == "Glöd" then
				-- the green fades out where the port has been ground
				bar.Transparency = done and 1 or (0.45 + 0.5 * prog) + (i == P.zone and 0 or 0.25)
			else
				bar.Transparency = done and 1 or (i == P.zone and 0 or 0.65)
			end
		end
	end
end

---------------------------------------------------------------- UI updates
local function zoneDone(z) return Porting.zoneProgress(P.state, z.id) >= 0.97 end
local function refreshUI()
	UI.clear(zones)
	UI.text(zones, P.training and "Träningsläge" or "Arbetsmoment", UDim2.new(1, 0, 0, 24), nil, { font = UI.BOLD, ts = 16, order = 0 })
	for i, z in ipairs(Porting.ZONES) do
		local row = UI.check(zones, z.n, zoneDone(z), i, i == P.zone)
		local b = UI.new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Name = "Välj" }, row)
		b.Activated:Connect(function() P.setZone(i) end)
	end
	local res = Porting.result(P.state)
	UI.check(zones, "Jämn finish", res.even > 0.75 and res.cover > 0.9, 10, false)
end
-- the buttons are built once per session (rebuilding them would swallow clicks)
local function buildButtons()
	UI.clear(buttons)
	UI.button(buttons, "Klar", UDim2.fromOffset(140, 40), nil, { kind = "green", order = 1 }, function() P.finish() end)
	UI.button(buttons, P.training and "Avsluta träning" or "Träningsläge", UDim2.fromOffset(170, 40), nil, { kind = "secondary", order = 2 }, function() P.toggleTraining() end)
	UI.button(buttons, "Avbryt", UDim2.fromOffset(120, 40), nil, { kind = "danger", order = 3 }, function() S.endMode("port") end)
end
local function refreshStats()
	local res = Porting.result(P.state)
	local prog = Porting.progress(P.state)
	progText.Text = string.format("%d %%", math.floor(prog * 100))
	progFill.Size = UDim2.fromScale(prog, 1)
	local function mark(ok) return ok and "  ✓" or "" end
	evenRow.Text = string.format("Jämnhet: %d %%%s", math.floor(res.even * 100), mark(res.even > 0.75))
	precRow.Text = string.format("Precision: %d %%%s", math.floor(res.precision * 100), mark(res.precision > 0.85))
	overRow.Text = string.format("Överportat: %d %%", math.floor(res.over * 100))
	overRow.TextColor3 = res.over > 0 and UI.C.red or UI.C.text
	local col = res.q >= 0.75 and "#2ECC71" or (res.q >= 0.5 and "#F1C40F" or "#E74C3C")
	qualRow.Text = string.format('Kvalitet: <font color="%s">%s (%d %%)</font>', col, res.label, math.floor(res.q * 100))
end
function P.setZone(i)
	P.zone = ((i - 1) % #Porting.ZONES) + 1
	local z = Porting.ZONES[P.zone]
	local f = faceCF(z.face)
	-- turn the cylinder (shortest way) so this port faces the room; look from slightly above
	local target = -math.rad(FACES[z.face])
	while target - P.ang > math.pi do target = target - 2 * math.pi end
	while target - P.ang < -math.pi do target = target + 2 * math.pi end
	P.targetAng = target
	local front = baseCF() * CFrame.new(0, -0.15, -PORT_OUT)
	S.camTo(CFrame.lookAt(front.Position + Vector3.new(0.5, 1.5, -3.4), front.Position + Vector3.new(0, -0.15, 0)), 50, 0.35)
	if outlines[z.id] then paintCells() end
	refreshUI()
end

---------------------------------------------------------------- start, finish
local function freeCylinders()
	local r = {}
	for id, it in pairs(S.profile.items) do
		if Parts.get(it.sku).kind == "cylinder" and not it.port and (it.loc == "hylla" or it.loc == "bank" or it.loc == "golv" or it.loc == "hand" or it.loc:sub(1, 4) == "box:") then r[#r + 1] = id end
	end
	return r
end
local function showPicker()
	UI.clear(picker)
	UI.pad(picker, 12)
	UI.list(picker, 6)
	UI.text(picker, "Spänn fast en cylinder i skruvstädet", UDim2.new(1, 0, 0, 26), nil, { font = UI.BOLD, ts = 16, order = 0 })
	local list = freeCylinders()
	for i, id in ipairs(list) do
		local it = S.item(id)
		UI.button(picker, Parts.get(it.sku).name, UDim2.new(1, 0, 0, 36), nil, { kind = "secondary", order = i, ts = 14 }, function()
			if S.api("moveTo", id, "port") then picker.Visible = false; P.begin() end
		end)
	end
	if #list == 0 then
		UI.text(picker, "Du har ingen oportad cylinder ledig. Lyft ur motorn och ta loss cylindern, eller beställ en. Du kan också öva i träningsläget.", UDim2.new(1, 0, 0, 70), nil, { ts = 14, wrap = true, color = UI.C.dim, order = 1 })
	end
	UI.button(picker, "Träningsläge", UDim2.new(1, 0, 0, 36), nil, { kind = "primary", order = 50 }, function() picker.Visible = false; P.training = true; P.begin() end)
	UI.button(picker, "Avbryt", UDim2.new(1, 0, 0, 36), nil, { kind = "danger", order = 51 }, function() S.endMode("port") end)
	picker.Visible = true
end
function P.begin()
	local sku
	if not P.training then
		local ok, info = S.api("portStart")
		if not ok then showPicker(); return end
		P.steady, P.speed = info.steady or 0, info.speed or 1
		sku = S.item(info.item) and S.item(info.item).sku
	else
		P.steady, P.speed = 0.5, 1
	end
	P.state = Porting.new()
	P.t = 0
	P.started = os.clock()
	buildScene(sku)
	topInfo.Visible, zones.Visible, stats.Visible, hint.Visible = true, true, true, true
	P.setZone(1)
	buildButtons()
	refreshStats()
end
function P.toggleTraining()
	P.training = not P.training
	P.begin()
end
function P.finish()
	if P.training then
		local res = Porting.result(P.state)
		S.toast(string.format("Träning klar: %s (%d %%). Testa på riktigt när du har en cylinder.", res.label, math.floor(res.q * 100)), "info")
		S.endMode("port")
		return
	end
	if os.clock() - (P.started or 0) < 6 or P.t < 1 then S.toast("Ta det lugnt – portning tar tid. Slipa klart först.", "error"); return end
	local ok, res = S.api("portDone", P.state)
	if ok then
		S.toast(string.format("Portningen klar: %s (%d %%). Effekten syns i Moped Info när cylindern sitter i motorn.", res.label, math.floor(res.q * 100)), res.q >= 0.5 and "ok" or "error")
		S.endMode("port")
	end
end
local function open()
	if not S.setMode("port") then return end
	gui.Enabled = true
	P.training = false
	topInfo.Visible, zones.Visible, stats.Visible, hint.Visible = false, false, false, false
	S.camTo(S.origin() * GarageBuilder.PORT * CFrame.new(0, 3, -7) * CFrame.Angles(math.rad(-20), math.pi, 0), 50, 0.4)
	local onVise
	for _, it in pairs(S.profile.items) do if it.loc == "port" then onVise = true end end
	if onVise then P.begin() else showPicker() end
end
local function close()
	gui.Enabled = false
	picker.Visible = false
	P.grinding = false
	scene:ClearAllChildren()
	scene.Parent = nil
	UIS.MouseIconEnabled = true
end
S.open.Event:Connect(function(what, atStation) if what == "port" and atStation then open() end end)
S.modeEv.Event:Connect(function(mode) if mode ~= "port" and gui.Enabled then close() end end)

---------------------------------------------------------------- input and the grinding loop
UIS.InputBegan:Connect(function(input, gp)
	if S.mode ~= "port" or not P.state then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not gp then P.grinding = true end
	if input.KeyCode == Enum.KeyCode.A then P.setZone(P.zone - 1) elseif input.KeyCode == Enum.KeyCode.D then P.setZone(P.zone + 1) end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then P.grinding = false end
end)
local acc = 0
RunService.RenderStepped:Connect(function(dt)
	if S.mode ~= "port" or not P.state or not hand or not hand.Parent then return end
	-- turn the cylinder towards the chosen port
	if math.abs(P.targetAng - P.ang) > 1e-3 then
		P.ang = P.ang + (P.targetAng - P.ang) * math.min(1, dt * 9)
		if math.abs(P.targetAng - P.ang) < 0.01 then P.ang = P.targetAng end
		local t = turnedCF()
		for _, r in ipairs(rig) do r[1].CFrame = t * r[2] end
	end
	local z = Porting.ZONES[P.zone]
	local f = faceCF(z.face)
	local cam = workspace.CurrentCamera
	local m = UIS:GetMouseLocation()
	local ray = cam:ViewportPointToRay(m.X, m.Y)
	-- intersect the face plane
	local n = f.LookVector
	local denom = ray.Direction:Dot(n)
	if math.abs(denom) < 1e-4 then return end
	local hit = ray.Origin + ray.Direction * ((f.Position - ray.Origin):Dot(n) / denom)
	-- shaky hand: noise that the pro grinder mostly removes
	local shake = (1 - P.steady) * 0.07 * (P.grinding and 1 or 0.4)
	local tnow = os.clock()
	local wob = f.RightVector * math.sin(tnow * 23) * shake + f.UpVector * math.cos(tnow * 17) * shake
	local tipPos = hit + wob + n * 0.02
	-- the grinder points into the face from the camera side (tip at local -0.78 X); the hand holds its body
	local back = (n * 1.3 + f.RightVector * 1.6 + f.UpVector * 0.8).Unit
	local up = f.UpVector - back * f.UpVector:Dot(back)
	up = up.Unit
	local toolCF = CFrame.fromMatrix(tipPos + back * 0.78, back, up)
	for _, r in ipairs(P.toolRig) do r[1].CFrame = toolCF * r[2] end
	local grip = toolCF * Vector3.new(0.18, -0.15, 0)
	local sleeve = (back - up * 0.7 + f.RightVector * 0.3).Unit
	local handCF = CFrame.lookAt(grip, grip - sleeve, up)
	if P.grinding then handCF = handCF * CFrame.new(math.sin(tnow * 60) * 0.01, 0, 0) end
	for _, r in ipairs(P.handRig) do r[1].CFrame = handCF * r[2] end
	P.tip.CFrame = CFrame.new(tipPos)
	sparks.Rate = 0
	P.tip.Transparency = P.grinding and 0.15 or 0.7
	if P.grinding then
		local l = f:PointToObjectSpace(tipPos)
		local w, h = z.w * SIZE * 1.3, z.h * SIZE * 1.3
		local u, v = (l.X + w / 2) / w, (h / 2 - l.Y) / h
		local inside = Porting.grind(P.state, z.id, u, v, dt, P.speed)
		sparks.Rate = inside and 140 or 40
		P.t = P.t + dt
		acc = acc + dt
		if acc > 0.1 then acc = 0; paintCells(); refreshStats() end
	end
end)
-- refresh the checklist only when a zone's done-state changes
task.spawn(function()
	local last = ""
	while true do
		task.wait(0.5)
		if S.mode == "port" and P.state and gui.Enabled and zones.Visible then
			local sig = tostring(P.zone)
			for _, z in ipairs(Porting.ZONES) do sig = sig .. (zoneDone(z) and "1" or "0") end
			local res = Porting.result(P.state)
			sig = sig .. ((res.even > 0.75 and res.cover > 0.9) and "1" or "0")
			if sig ~= last then last = sig; refreshUI() end
		end
	end
end)

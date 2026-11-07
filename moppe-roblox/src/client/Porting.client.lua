-- Cylinder porting in first person: an enlarged work view of the cylinder in the vise, glowing port areas,
-- a hand with a die grinder that follows the mouse. Hold the left button to grind. Quality from Porting.lua.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = RS:WaitForChild("Shared")
local Porting = require(Shared.Porting)
local Builder = require(Shared.Builder)
local GarageBuilder = require(Shared.GarageBuilder)
local CS = require(Shared.ClientState)
local Api = RS:WaitForChild("Remotes"):WaitForChild("Api")
local plr = Players.LocalPlayer
local cam = workspace.CurrentCamera

local function new(class, props, parent) local o = Instance.new(class); for k, v in pairs(props) do o[k] = v end; o.Parent = parent; return o end
local function corner(o) new("UICorner", { CornerRadius = UDim.new(0, 8) }, o); return o end
local function txt(parent, t, size, color)
	return new("TextLabel", { BackgroundTransparency = 1, Text = t, TextSize = size or 14, TextColor3 = color or Color3.new(1, 1, 1), Font = Enum.Font.GothamMedium, RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, parent)
end
local function button(parent, t, color, cb)
	local b = corner(new("TextButton", { Text = t, TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = color, Size = UDim2.new(1, 0, 0, 32) }, parent))
	b.MouseButton1Click:Connect(cb)
	return b
end

local gui = new("ScreenGui", { Name = "Porting", ResetOnSpawn = false, Enabled = false }, plr:WaitForChild("PlayerGui"))
local banner = corner(new("TextLabel", { BackgroundColor3 = Color3.fromRGB(20, 24, 30), BackgroundTransparency = 0.15, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamMedium, TextSize = 16,
	Text = "ⓘ  Porta de markerade områdena för bästa prestanda!", Position = UDim2.new(0, 16, 0, 16), Size = UDim2.new(0, 470, 0, 40) }, gui))
local panel = corner(new("Frame", { BackgroundColor3 = Color3.fromRGB(20, 24, 30), BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.new(0, 250, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, gui))
new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, panel)
new("UIListLayout", { Padding = UDim.new(0, 5) }, panel)
local title = txt(panel, "<b>Framsteg</b>", 18)
local bars = {}
for _, z in ipairs(Porting.ZONES) do
	txt(panel, z.n, 12, Color3.fromRGB(190, 198, 210))
	local bg = corner(new("Frame", { BackgroundColor3 = Color3.fromRGB(50, 56, 66), Size = UDim2.new(1, 0, 0, 8) }, panel))
	bars[z.id] = corner(new("Frame", { BackgroundColor3 = z.color, Size = UDim2.new(0, 0, 1, 0) }, bg))
end
local metrics = txt(panel, "", 14)
local start = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, panel)
new("UIListLayout", { Padding = UDim.new(0, 5) }, start)

local W = { on = false } -- work state
local function cleanup()
	if W.piece then W.piece:Destroy() end
	if W.hand then W.hand:Destroy() end
	if W.con then W.con:Disconnect() end
	W = { on = false }
	gui.Enabled = false
	cam.CameraType = Enum.CameraType.Custom
	UIS.MouseIconEnabled = true
	CS.setMode(nil); CS.modeEnded:Fire()
end

-- the enlarged work view: finned cylinder, bore (the work surface) and the zones as cells
local R = 2.6 -- the bore's radius in studs (the view is enlarged, the real cylinder is 8.5 cm)
local function buildPiece(center)
	local m = new("Model", { Name = "PortingView" }, cam)
	local function p(props) local x = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth }, m); for k, v in pairs(props) do x[k] = v end; return x end
	p({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 7.4, 7.4), CFrame = CFrame.new(center - Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(160, 165, 172), Material = Enum.Material.Metal })
	for i = 0, 5 do p({ Size = Vector3.new(9, 0.18, 9), CFrame = CFrame.new(center - Vector3.new(0, 2.9 - i * 0.5, 0)), Color = Color3.fromRGB(150, 155, 162), Material = Enum.Material.Metal }) end
	p({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, R * 2, R * 2), CFrame = CFrame.new(center + Vector3.new(0, 0.01, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(40, 42, 46), Material = Enum.Material.Metal })
	local cells = {}
	for _, z in ipairs(Porting.ZONES) do
		cells[z.id] = {}
		local cw = (z.u[2] - z.u[1]) / Porting.CU * R * 0.92
		local ch = (z.v[2] - z.v[1]) / Porting.CV * R * 0.92
		for i = 1, Porting.CU * Porting.CV do
			local cu, cv = Porting.cellCenter(z, i)
			cells[z.id][i] = p({ Size = Vector3.new(cw, 0.05, ch), CFrame = CFrame.new(center + Vector3.new(cu * R, 0.06, -cv * R)), Color = z.color, Material = Enum.Material.Neon, Transparency = 0.25 })
		end
	end
	return m, cells
end

local function uvFromMouse(center)
	local mpos = UIS:GetMouseLocation()
	local ray = cam:ViewportPointToRay(mpos.X, mpos.Y)
	if math.abs(ray.Direction.Y) < 1e-3 then return nil end
	local t = (center.Y + 0.06 - ray.Origin.Y) / ray.Direction.Y
	local hit = ray.Origin + ray.Direction * t
	return (hit.X - center.X) / R, -(hit.Z - center.Z) / R, hit
end

local function begin(training)
	local ok, steady = Api:InvokeServer("portStart", training)
	if not ok then CS.toast:Fire(tostring(steady)); return end
	for _, c in ipairs(start:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	local a = GarageBuilder.anchors(GarageBuilder.plotOrigin(CS.profile._plot))
	local center = a.portbench.Position + Vector3.new(0, 3.2, 0)
	W.training = training
	W.s = Porting.new(steady or 0.6, training)
	W.piece, W.cells = buildPiece(center)
	cam.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { CFrame = CFrame.lookAt(center + Vector3.new(0, 9, 5.5), center) }):Play()
	W.hand = Builder.hand("grinder", { steady = steady })
	W.hand.Parent = cam
	local tip = new("Attachment", { Position = Vector3.new(0, 0, -0.13 / 0.28) }, W.hand.PrimaryPart)
	-- the work view is enlarged (bore 8.5 cm -> 5.2 studs), so the hand is enlarged by the same factor
	local SCALE = R / (0.0425 / 0.28)
	pcall(function() W.hand:ScaleTo(SCALE) end)
	W.tipLen = tip.Position.Magnitude
	W.sparks = new("ParticleEmitter", { Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 0, Lifetime = NumberRange.new(0.15, 0.4), Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(60, 60), Size = NumberSequence.new(0.15, 0), Color = ColorSequence.new(Color3.fromRGB(255, 200, 90)), LightEmission = 1 }, tip)
	W.dust = new("ParticleEmitter", { Texture = "rbxasset://textures/particles/smoke_main.dds", Rate = 0, Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(1, 2), Size = NumberSequence.new(0.3, 1.2),
		Transparency = NumberSequence.new(0.6, 1), Color = ColorSequence.new(Color3.fromRGB(170, 170, 170)) }, tip)
	-- the hand slides in from the lower right
	W.handIn = 0
	W.on = true
	UIS.MouseIconEnabled = false
	local acc = 0
	W.con = RunService.RenderStepped:Connect(function(dt)
		local u, v, hit = uvFromMouse(center)
		if not u then return end
		local grinding = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		local jitter = grinding and (1 - W.s.steady) * 0.08 + 0.015 or 0
		local jx, jz = (math.random() - 0.5) * jitter, (math.random() - 0.5) * jitter
		W.handIn = math.min(1, W.handIn + dt * 3)
		local from = cam.CFrame.Position + cam.CFrame.RightVector * 6 - cam.CFrame.UpVector * 4
		local target = hit + Vector3.new(jx, 0.25, jz)
		local pos = from:Lerp(target, W.handIn)
		-- the grinder leans towards the cylinder; the hand rotates slightly with movement
		W.vel = (W.last and (pos - W.last) / math.max(dt, 1e-3)) or Vector3.zero
		W.last = pos
		local tilt = math.clamp(W.vel.X * 0.03, -0.4, 0.4)
		-- place the grip so the bit tip ends up exactly at the mouse pointer (the tool comes in from above at an angle)
		local dir = Vector3.new(-0.25, -0.85, -0.45).Unit
		W.hand:PivotTo(CFrame.lookAt(pos - dir * W.tipLen, pos) * CFrame.Angles(0, 0, tilt))
		local zone = Porting.grind(W.s, u + jx / R, v - jz / R, dt, grinding and W.handIn >= 1)
		W.sparks.Rate = (grinding and zone) and 140 or 0
		W.dust.Rate = (grinding and not zone) and 40 or 0
		acc = acc + dt
		if acc > 0.1 then
			acc = 0
			for _, z in ipairs(Porting.ZONES) do
				for i, cell in ipairs(W.cells[z.id]) do
					local w = W.s.cells[z.id][i]
					if w > 1.4 then cell.Color, cell.Material, cell.Transparency = Color3.fromRGB(120, 30, 20), Enum.Material.Metal, 0
					elseif w >= 1 then cell.Color, cell.Material, cell.Transparency = Color3.fromRGB(225, 230, 236), Enum.Material.Metal, 0
					else cell.Color, cell.Material, cell.Transparency = z.color:Lerp(Color3.fromRGB(225, 230, 236), w), Enum.Material.Neon, 0.25 + 0.5 * w end
				end
				bars[z.id].Size = UDim2.new(Porting.zoneProgress(W.s, z.id), 0, 1, 0)
			end
			local r = Porting.result(W.s)
			local function ck(x) return x > 0.7 and " <font color=\"#5ad26e\">✓</font>" or "" end
			metrics.Text = string.format("Jämnhet %d %%%s<br/>Precision %d %%%s<br/>Kvalitet: <b>%s</b>%s<br/>%s",
				math.floor(r.evenness * 100), ck(r.evenness), math.floor(r.precision * 100), ck(r.precision), r.label, r.over > 0.05 and " <font color=\"#ff6a4a\">(överportad!)</font>" or "",
				W.training and "<font color=\"#ffb020\">Träningsläge: ingen cylinder ändras</font>" or "")
			title.Text = string.format("<b>Framsteg %d %%</b>", math.floor(r.coverage * 100))
		end
	end)
	button(start, W.training and "Avsluta träningen" or "Klar – spara portningen", Color3.fromRGB(40, 160, 80), function()
		local r = Porting.result(W.s)
		-- the hand slides out, then the result goes to the server
		W.handIn = 0
		local ok2, msg = Api:InvokeServer("portDone", r)
		CS.toast:Fire(tostring(msg))
		cleanup()
	end)
	button(start, "Avbryt", Color3.fromRGB(110, 118, 130), function() Api:InvokeServer("portDone", nil); cleanup() end)
end

CS.openPort.Event:Connect(function()
	if CS.mode then return end
	CS.setMode("port")
	gui.Enabled = true
	metrics.Text = "Cylindern spänns fast i skruvstycket. Håll vänster musknapp för att slipa. Jobba jämnt över varje område, stanna innanför markeringarna och slipa inte för länge på samma ställe."
	for _, c in ipairs(start:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	local hasCyl = false
	for _, it in pairs(CS.profile.items) do if it.loc == "portbench" then hasCyl = true end end
	if hasCyl then button(start, "Börja porta", Color3.fromRGB(26, 108, 220), function() begin(false) end) end
	button(start, "Träna (ingen cylinder ändras)", Color3.fromRGB(230, 140, 20), function() begin(true) end)
	button(start, "Stäng", Color3.fromRGB(110, 118, 130), function() cleanup() end)
end)
UIS.InputBegan:Connect(function(io, gp) if not gp and io.KeyCode == Enum.KeyCode.Escape and gui.Enabled then if W.on then Api:InvokeServer("portDone", nil) end; cleanup() end end)

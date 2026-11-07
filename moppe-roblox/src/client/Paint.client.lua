-- The spray booth: choose colour (library, RGB, HEX) and paint type, then spray the panel with the spray gun in
-- first person. The paint is applied in real time on an enlarged view of the panel. Quality from Paint.lua.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = RS:WaitForChild("Shared")
local Paint = require(Shared.Paint)
local Builder = require(Shared.Builder)
local Catalog = require(Shared.Catalog)
local GarageBuilder = require(Shared.GarageBuilder)
local CS = require(Shared.ClientState)
local Api = RS:WaitForChild("Remotes"):WaitForChild("Api")
local plr = Players.LocalPlayer
local cam = workspace.CurrentCamera

local function new(class, props, parent) local o = Instance.new(class); for k, v in pairs(props) do o[k] = v end; o.Parent = parent; return o end
local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o); return o end
local function txt(parent, t, size, color)
	return new("TextLabel", { BackgroundTransparency = 1, Text = t, TextSize = size or 14, TextColor3 = color or Color3.new(1, 1, 1), Font = Enum.Font.GothamMedium, RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, parent)
end
local function button(parent, t, color, cb, w)
	local b = corner(new("TextButton", { Text = t, TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = color, Size = UDim2.new(w or 1, 0, 0, 30) }, parent), 6)
	b.MouseButton1Click:Connect(cb)
	return b
end

local gui = new("ScreenGui", { Name = "PaintBooth", ResetOnSpawn = false, Enabled = false }, plr:WaitForChild("PlayerGui"))
local panel = corner(new("ScrollingFrame", { BackgroundColor3 = Color3.fromRGB(20, 24, 30), BackgroundTransparency = 0.08, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.new(0, 290, 1, -28), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, BorderSizePixel = 0 }, gui))
new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, panel)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
local banner = corner(new("TextLabel", { BackgroundColor3 = Color3.fromRGB(20, 24, 30), BackgroundTransparency = 0.15, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamMedium, TextSize = 15,
	Text = "ⓘ  Välj färg och lacktyp, håll sedan vänster musknapp och spraya jämnt över hela kåpan", Position = UDim2.new(0, 14, 0, 14), Size = UDim2.new(0, 620, 0, 38) }, gui))

local P = { on = false, col = "#c8102e", fin = "gloss" }
local function cleanup()
	if P.view then P.view:Destroy() end
	if P.hand then P.hand:Destroy() end
	if P.con then P.con:Disconnect() end
	P.view, P.hand, P.con, P.on, P.s = nil, nil, nil, false, nil
	gui.Enabled = false
	cam.CameraType = Enum.CameraType.Custom
	UIS.MouseIconEnabled = true
	CS.setMode(nil); CS.modeEnded:Fire()
end
local function color3() return Color3.fromHex(P.col) end

-- colour selection UI
local preview, hexBox, rgb, quality
local buildFinish
local function refreshColour()
	preview.BackgroundColor3 = color3()
	hexBox.Text = P.col
	local c = color3()
	for i, k in ipairs({ "R", "G", "B" }) do rgb[i].fill.Size = UDim2.new(c[k], 0, 1, 0); rgb[i].val.Text = k .. " " .. math.floor(c[k] * 255 + 0.5) end
	if P.cells then for _, cell in ipairs(P.cells) do cell.Color = color3() end end
	if P.s then P.s = Paint.new(P.s.even) end -- a new colour starts over
end
local function buildUI(baseLabel)
	for _, c in ipairs(panel:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	txt(panel, "<b>Lackbox</b>", 18)
	txt(panel, baseLabel, 12, Color3.fromRGB(180, 188, 200))
	txt(panel, "Färgbibliotek", 13, Color3.fromRGB(255, 176, 32))
	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, panel)
	new("UIGridLayout", { CellSize = UDim2.new(0, 60, 0, 44), CellPadding = UDim2.new(0, 6, 0, 6) }, grid)
	for _, lib in ipairs(Paint.LIBRARY) do
		local b = corner(new("TextButton", { Text = "", BackgroundColor3 = Color3.fromHex(lib[2]) }, grid), 6)
		new("TextLabel", { BackgroundTransparency = 1, Text = lib[1], TextSize = 9, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, TextWrapped = true, Size = UDim2.fromScale(1, 1) }, b)
		b.MouseButton1Click:Connect(function() P.col, P.fin = lib[2], lib[3]; refreshColour(); buildFinish() end)
	end
	txt(panel, "RGB", 13, Color3.fromRGB(255, 176, 32))
	rgb = {}
	for i, k in ipairs({ "R", "G", "B" }) do
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22) }, panel)
		local val = new("TextLabel", { BackgroundTransparency = 1, Text = k, TextSize = 12, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0, 46, 1, 0), TextXAlignment = Enum.TextXAlignment.Left }, row)
		local bg = corner(new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(50, 56, 66), Position = UDim2.new(0, 50, 0, 6), Size = UDim2.new(1, -50, 0, 10) }, row), 5)
		local fill = corner(new("Frame", { BackgroundColor3 = ({ Color3.fromRGB(230, 60, 60), Color3.fromRGB(60, 200, 90), Color3.fromRGB(70, 130, 240) })[i], Size = UDim2.new(0, 0, 1, 0) }, bg), 5)
		local function setFrom(x)
			local f = math.clamp((x - bg.AbsolutePosition.X) / bg.AbsoluteSize.X, 0, 1)
			local c = color3()
			local t = { c.R, c.G, c.B }
			t[i] = f
			P.col = string.format("#%02x%02x%02x", math.floor(t[1] * 255 + 0.5), math.floor(t[2] * 255 + 0.5), math.floor(t[3] * 255 + 0.5))
			refreshColour()
		end
		bg.MouseButton1Down:Connect(function(x) setFrom(x) end)
		rgb[i] = { fill = fill, val = val }
	end
	local hexRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30) }, panel)
	new("TextLabel", { BackgroundTransparency = 1, Text = "HEX", TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 176, 32), Size = UDim2.new(0, 46, 1, 0), TextXAlignment = Enum.TextXAlignment.Left }, hexRow)
	hexBox = corner(new("TextBox", { Text = P.col, TextSize = 14, Font = Enum.Font.Code, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(44, 52, 64), Position = UDim2.new(0, 50, 0, 0), Size = UDim2.new(0, 110, 1, 0), ClearTextOnFocus = false }, hexRow), 6)
	preview = corner(new("Frame", { BackgroundColor3 = color3(), Position = UDim2.new(0, 170, 0, 0), Size = UDim2.new(1, -170, 1, 0) }, hexRow), 6)
	hexBox.FocusLost:Connect(function()
		local h = hexBox.Text:gsub("^([^#])", "#%1")
		if Paint.validHex(h) then P.col = h:lower(); refreshColour() else hexBox.Text = P.col; CS.toast:Fire("Ange en HEX-kod som #1a2b3c") end
	end)
	txt(panel, "Lacktyp", 13, Color3.fromRGB(255, 176, 32))
	P.finRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, panel)
	new("UIGridLayout", { CellSize = UDim2.new(0, 84, 0, 28), CellPadding = UDim2.new(0, 6, 0, 6) }, P.finRow)
	buildFinish()
	quality = txt(panel, "", 14)
	button(panel, "Klar – låt lacken torka", Color3.fromRGB(40, 160, 80), function()
		if not P.s then return end
		local r = Paint.result(P.s)
		local ok, msg = Api:InvokeServer("paintDone", P.col, P.fin, r.q)
		CS.toast:Fire(tostring(msg))
		if ok then cleanup() end
	end)
	button(panel, "Avbryt", Color3.fromRGB(110, 118, 130), function() Api:InvokeServer("paintDone", nil); cleanup() end)
	refreshColour()
end
buildFinish = function()
	for _, c in ipairs(P.finRow:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	for _, f in ipairs({ "gloss", "matt", "metal", "pearl", "chrome" }) do
		local b = button(P.finRow, Paint.FINISH[f], P.fin == f and Color3.fromRGB(26, 108, 220) or Color3.fromRGB(60, 68, 80), function() P.fin = f; buildFinish() end)
		b.Size = UDim2.new(0, 84, 0, 28)
	end
end

-- the work view: the panel enlarged on the booth rack, cells that are coloured as you spray
local SW, SH = 7, 4.4
local function buildView(center, look, baseColor)
	local m = new("Model", { Name = "PaintView" }, cam)
	local cf = CFrame.lookAt(center, center + Vector3.new(0, 0, -1)) -- the panel faces the camera (+Z)
	local base = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Size = Vector3.new(SW, SH, 0.2), CFrame = cf, Color = baseColor, Material = Enum.Material.SmoothPlastic }, m)
	local cells = {}
	for i = 1, Paint.GW * Paint.GH do
		local cu, cv = Paint.cellCenter(i)
		cells[i] = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Size = Vector3.new(SW / Paint.GW, SH / Paint.GH, 0.05), Color = color3(), Transparency = 1,
			CFrame = cf * CFrame.new(cu * SW / 2, cv * SH / 2, -0.13), Material = Enum.Material.SmoothPlastic }, m)
	end
	return m, cells, base, cf
end

CS.openPaint.Event:Connect(function()
	if CS.mode then return end
	local ok, even = Api:InvokeServer("paintStart")
	if not ok then CS.toast:Fire(tostring(even)); return end
	CS.setMode("paint")
	local item
	for _, it in pairs(CS.profile.items) do if it.loc == "booth" then item = it end end
	local pr = item and Catalog.BY_SKU[item.s]
	local a = GarageBuilder.anchors(GarageBuilder.plotOrigin(CS.profile._plot))
	local center = a.booth.Position + Vector3.new(0, 1.6, 0)
	local baseC = item and item.paint and Color3.fromHex(item.paint.col) or Color3.fromRGB(190, 190, 190)
	P.s = Paint.new(even or 0.7)
	P.view, P.cells, P.base, P.cf = buildView(center, pr and pr.val.look, baseC)
	gui.Enabled = true
	buildUI((pr and pr.name or "Kåpa") .. (item and item.paint and (" · nu " .. item.paint.col) or ""))
	cam.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(cam, TweenInfo.new(0.6), { CFrame = CFrame.lookAt(center + Vector3.new(-1.2, 0.6, -9), center) }):Play()
	P.hand = Builder.hand("spray", { even = even })
	P.hand.Parent = cam
	pcall(function() P.hand:ScaleTo(9) end)
	local noz = new("Attachment", { Position = Vector3.new(0, 0, -0.085 / 0.28 * 9) }, P.hand.PrimaryPart)
	P.mist = new("ParticleEmitter", { Texture = "rbxasset://textures/particles/smoke_main.dds", Rate = 0, Lifetime = NumberRange.new(0.25, 0.5), Speed = NumberRange.new(8, 12), SpreadAngle = Vector2.new(14, 14),
		Size = NumberSequence.new(0.3, 1.6), Transparency = NumberSequence.new(0.5, 1), EmissionDirection = Enum.NormalId.Front }, noz)
	P.on = true
	UIS.MouseIconEnabled = false
	local acc, handIn = 0, 0
	P.con = RunService.RenderStepped:Connect(function(dt)
		local mpos = UIS:GetMouseLocation()
		local ray = cam:ViewportPointToRay(mpos.X, mpos.Y)
		local n = P.cf.LookVector
		local t = (P.cf.Position - ray.Origin):Dot(n) / ray.Direction:Dot(n)
		local hit = ray.Origin + ray.Direction * t
		local lp = P.cf:PointToObjectSpace(hit)
		local u, v = lp.X / (SW / 2), lp.Y / (SH / 2)
		local spraying = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and P.s ~= nil
		handIn = math.min(1, handIn + dt * 3)
		local aim = P.cf * CFrame.new(math.clamp(lp.X, -SW, SW), math.clamp(lp.Y, -SH, SH), -0.1)
		local gunPos = aim.Position - P.cf.LookVector * 4.5 + Vector3.new(0, -0.3, 0)
		local from = cam.CFrame.Position + cam.CFrame.RightVector * 5 - cam.CFrame.UpVector * 3
		P.hand:PivotTo(CFrame.lookAt(from:Lerp(gunPos, handIn), aim.Position) * CFrame.Angles(0, 0, spraying and math.sin(os.clock() * 30) * 0.02 or 0))
		P.mist.Rate = spraying and 120 or 0
		P.mist.Color = ColorSequence.new(color3())
		if spraying and math.abs(u) < 1.4 and math.abs(v) < 1.4 then Paint.spray(P.s, u, v, dt) end
		acc = acc + dt
		if acc > 0.08 and P.s then
			acc = 0
			for i, cell in ipairs(P.cells) do
				local w = P.s.g[i]
				cell.Transparency = 1 - math.min(1, w)
				cell.Color = w > 1.7 and color3():Lerp(Color3.new(0, 0, 0), 0.35) or color3()
			end
			local r = Paint.result(P.s)
			quality.Text = string.format("Täckning %d %%<br/>Jämnhet %d %%<br/>Rinningar %d %%<br/>Kvalitet: <b>%s</b>", math.floor(r.coverage * 100), math.floor(r.evenness * 100), math.floor(r.runs * 100), r.label)
		end
	end)
end)
UIS.InputBegan:Connect(function(io, gp) if not gp and io.KeyCode == Enum.KeyCode.Escape and gui.Enabled then Api:InvokeServer("paintDone", nil); cleanup() end end)

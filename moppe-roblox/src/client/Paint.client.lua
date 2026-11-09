-- Paint booth, laid out like the reference: colour picker (saturation/brightness square + hue bar + HEX),
-- finish list, decals, "Avsluta", a checklist (Placera kåpan, Välj färg, Spraya jämnt, Låt torka) and a
-- "Lackar..." bar. Hold the left button to spray with the gun in your hand: paint lands where the spray hits,
-- too much in one place makes runs. Mouse wheel moves the gun closer or further away.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local AssetService = game:GetService("AssetService")
local Shared = RS:WaitForChild("Shared")
local Parts = require(Shared.Parts)
local Paint = require(Shared.Paint)
local Models = require(Shared.Models)
local MeshGen = require(Shared.MeshGen)
local GarageBuilder = require(Shared.GarageBuilder)
local Config = require(Shared.Config)
local plr = Players.LocalPlayer
local S = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UIKit"))

local gui = UI.screen("Lackering", 10, plr)
gui.Enabled = false
local L = { h = 0.75, s = 0.8, v = 0.85, color = { 138, 43, 226 }, finish = "metallic", gloss = 0.8, dist = 1.0, decal = nil,
	spraying = false, state = nil, t = 0, even = 0, chosen = false, phase = "spray" }
local PRIMER = Color3.fromRGB(150, 152, 156)
local function col3() return Color3.fromRGB(L.color[1], L.color[2], L.color[3]) end

---------------------------------------------------------------- left panel: colour, finish, decals
local panel = UI.panel(gui, UDim2.fromOffset(300, 596), UDim2.fromOffset(12, 8), { name = "Lackering" })
local function heading(text, y) return UI.text(panel, text, UDim2.fromOffset(270, 20), UDim2.fromOffset(16, y), { ts = 16, font = UI.BOLD }) end
-- title with a spray-gun icon
local ic = UI.new("Frame", { Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(14, 8), BackgroundTransparency = 1, Name = "Ikon" }, panel)
UI.corner(UI.new("Frame", { Size = UDim2.fromOffset(16, 10), Position = UDim2.fromOffset(4, 6), BackgroundColor3 = UI.C.text, BorderSizePixel = 0 }, ic), 3)
UI.corner(UI.new("Frame", { Size = UDim2.fromOffset(6, 14), Position = UDim2.fromOffset(8, 14), BackgroundColor3 = UI.C.text, BorderSizePixel = 0 }, ic), 2)
UI.corner(UI.new("Frame", { Size = UDim2.fromOffset(6, 4), Position = UDim2.fromOffset(20, 9), BackgroundColor3 = UI.C.text, BorderSizePixel = 0 }, ic), 2)
UI.text(panel, "Lackering", UDim2.fromOffset(220, 40), UDim2.fromOffset(52, 4), { ts = 22, font = UI.BOLD })
heading("Färg", 46)
local sv = UI.new("Frame", { Size = UDim2.fromOffset(232, 140), Position = UDim2.fromOffset(16, 68), BackgroundColor3 = Color3.fromHSV(L.h, 1, 1), BorderSizePixel = 0, Name = "Färgruta", Active = true }, panel)
UI.corner(sv, 4)
local white = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Name = "Vitt" }, sv)
UI.new("UIGradient", { Transparency = NumberSequence.new(0, 1) }, white)
UI.corner(white, 4)
local black = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Name = "Svart" }, sv)
UI.new("UIGradient", { Transparency = NumberSequence.new(1, 0), Rotation = 90 }, black)
UI.corner(black, 4)
local svMark = UI.new("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Name = "Markör", ZIndex = 3 }, sv)
UI.corner(svMark, 7)
UI.stroke(svMark, Color3.new(1, 1, 1), 2, 0)
local hue = UI.new("Frame", { Size = UDim2.fromOffset(22, 140), Position = UDim2.fromOffset(258, 68), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Name = "Nyans", Active = true }, panel)
UI.corner(hue, 4)
do
	local kp = {}
	for i = 0, 6 do kp[#kp + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1, 1, 1)) end
	UI.new("UIGradient", { Color = ColorSequence.new(kp), Rotation = 90 }, hue)
end
local hueMark = UI.new("Frame", { Size = UDim2.new(1, 6, 0, 4), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Name = "Markör", ZIndex = 3 }, hue)
UI.stroke(hueMark, Color3.new(0, 0, 0), 1, 0.3)
local hexRow = UI.new("Frame", { Size = UDim2.fromOffset(264, 30), Position = UDim2.fromOffset(16, 214), BackgroundColor3 = UI.C.panel2, BorderSizePixel = 0, Name = "HEXrad" }, panel)
UI.corner(hexRow, 6)
UI.text(hexRow, "HEX:", UDim2.fromOffset(46, 30), UDim2.fromOffset(8, 0), { ts = 15, font = UI.BOLD })
local hex = UI.new("TextBox", { Size = UDim2.new(1, -60, 1, -6), Position = UDim2.fromOffset(54, 3), BackgroundColor3 = UI.C.panel, TextColor3 = UI.C.text, Font = UI.FONT, TextSize = 15, ClearTextOnFocus = false, Text = "", TextXAlignment = Enum.TextXAlignment.Left, Name = "HEX" }, hexRow)
UI.corner(hex, 4)
UI.pad(hex, 8, 4, 0, 0)
heading("Lacktyp", 252)
local finishes = UI.new("Frame", { Size = UDim2.fromOffset(264, 146), Position = UDim2.fromOffset(16, 274), BackgroundTransparency = 1, Name = "Lacktyper" }, panel)
UI.grid(finishes, UDim2.fromOffset(130, 27), UDim2.fromOffset(4, 3))
UI.text(panel, "Glans", UDim2.fromOffset(60, 20), UDim2.fromOffset(16, 424), { ts = 14, font = UI.BOLD })
local glossBar = UI.new("Frame", { Size = UDim2.fromOffset(150, 8), Position = UDim2.fromOffset(78, 430), BackgroundColor3 = UI.C.panel2, BorderSizePixel = 0, Name = "Glans", Active = true }, panel)
UI.corner(glossBar, 4)
local glossFill = UI.new("Frame", { Size = UDim2.fromScale(L.gloss, 1), BackgroundColor3 = UI.C.accent, BorderSizePixel = 0 }, glossBar)
UI.corner(glossFill, 4)
local glossKnob = UI.new("Frame", { Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(L.gloss, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Name = "Knopp" }, glossBar)
UI.corner(glossKnob, 8)
local glossText = UI.text(panel, "", UDim2.fromOffset(46, 20), UDim2.fromOffset(234, 424), { ts = 13, xa = Enum.TextXAlignment.Right })
heading("Dekaler", 446)
local decalBtn = UI.button(panel, "+  Lägg till dekal", UDim2.fromOffset(264, 32), UDim2.fromOffset(16, 470), { kind = "secondary", ts = 15, name = "Dekal" })
UI.stroke(decalBtn, UI.C.line, 1, 0.3)
local decals = UI.new("Frame", { Size = UDim2.fromOffset(264, 60), Position = UDim2.fromOffset(16, 510), BackgroundTransparency = 1, Name = "Dekaler" }, panel)
UI.list(decals, 6, true)
local quit = UI.button(gui, "Avsluta", UDim2.fromOffset(240, 46), UDim2.fromOffset(12, 612), { kind = "danger", ts = 20, name = "Avsluta" })

-- right: checklist, bottom: progress, small tip
local checks = UI.panel(gui, UDim2.fromOffset(220, 150), UDim2.new(1, -12, 0, 60), { anchor = Vector2.new(1, 0), name = "Moment" })
UI.pad(checks, 12, 10, 10, 10)
UI.list(checks, 4)
local prog = UI.panel(gui, UDim2.fromOffset(470, 64), UDim2.new(0.5, 70, 1, -12), { anchor = Vector2.new(0.5, 1), name = "Framsteg" })
local progLabel = UI.text(prog, "Lackar...", UDim2.fromOffset(300, 24), UDim2.fromOffset(16, 6), { ts = 17, font = UI.BOLD, name = "Etikett" })
local progPct = UI.text(prog, "0%", UDim2.fromOffset(80, 24), UDim2.new(1, -96, 0, 34), { ts = 19, font = UI.BOLD, xa = Enum.TextXAlignment.Right, name = "Procent" })
local progBg, progFill = UI.bar(prog, UDim2.new(1, -116, 0, 14), UDim2.fromOffset(16, 40), 0, col3())
local tipBox = UI.text(gui, "Håll vänster musknapp och spraya jämnt  ·  Rullhjul: avstånd", UDim2.fromOffset(420, 20), UDim2.new(0.5, 70, 1, -84), { anchor = Vector2.new(0.5, 1), ts = 13, xa = Enum.TextXAlignment.Center, name = "Tips" })
local picker = UI.panel(gui, UDim2.fromOffset(420, 320), UDim2.fromScale(0.5, 0.5), { anchor = Vector2.new(0.5, 0.5), name = "Välj", visible = false })

---------------------------------------------------------------- UI state
local paintCells, buildChecks
local function setFromRGB(c)
	L.color = { c[1], c[2], c[3] }
	local h, s2, v = Color3.fromRGB(c[1], c[2], c[3]):ToHSV()
	if s2 > 0.01 then L.h = h end
	L.s, L.v = s2, v
end
local function setFromHSV()
	local c = Color3.fromHSV(L.h, L.s, L.v)
	L.color = { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end
local function refreshColor()
	sv.BackgroundColor3 = Color3.fromHSV(L.h, 1, 1)
	svMark.Position = UDim2.fromScale(L.s, 1 - L.v)
	hueMark.Position = UDim2.fromScale(0.5, L.h)
	if not hex:IsFocused() then hex.Text = Paint.hex(L.color) end
	glossFill.Size = UDim2.fromScale(L.gloss, 1)
	glossKnob.Position = UDim2.fromScale(L.gloss, 0.5)
	glossText.Text = string.format("%d%%", math.floor(L.gloss * 100))
	progFill.BackgroundColor3 = col3()
	UI.clear(finishes)
	for i, f in ipairs(Paint.FINISH) do
		local on = L.finish == f.id
		local r = UI.new("TextButton", { Size = UDim2.new(0, 130, 0, 27), BackgroundColor3 = on and UI.C.accent or UI.C.panel2, BackgroundTransparency = on and 0 or 0.3, Text = "", AutoButtonColor = true, LayoutOrder = i, Name = f.n }, finishes)
		UI.corner(r, 6)
		if on then UI.stroke(r, UI.C.accent2, 2, 0) end
		local dot = UI.new("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(10, 6), BackgroundTransparency = on and 1 or 0.6, BackgroundColor3 = UI.C.dim, BorderSizePixel = 0 }, r)
		UI.corner(dot, 7)
		UI.stroke(dot, UI.C.text, 2, on and 0 or 0.5)
		UI.text(r, f.n, UDim2.new(1, -40, 1, 0), UDim2.fromOffset(36, 0), { ts = 15, font = on and UI.BOLD or UI.FONT })
		r.Activated:Connect(function() L.finish = f.id; L.chosen = true; refreshColor(); if paintCells then paintCells() end; if buildChecks then buildChecks() end end)
	end
	UI.clear(decals)
	for i, d in ipairs(Paint.DECALS) do
		local on = L.decal == d.id
		local b = UI.new("TextButton", { Size = UDim2.fromOffset(60, 56), BackgroundColor3 = UI.C.panel2, Text = "", AutoButtonColor = true, LayoutOrder = i, Name = d.id }, decals)
		UI.corner(b, 6)
		UI.stroke(b, on and UI.C.accent2 or UI.C.line, on and 2 or 1, on and 0 or 0.4)
		UI.text(b, d.text, UDim2.new(1, -6, 1, -6), UDim2.fromOffset(3, 3), { ts = 13, font = UI.BLACK, color = Color3.fromRGB(d.c[1], d.c[2], d.c[3]), xa = Enum.TextXAlignment.Center, scaled = true })
		b.Activated:Connect(function() L.decal = d.id; refreshColor(); if paintCells then paintCells() end end)
	end
	decalBtn.Text = L.decal and "Ta bort dekal" or "+  Lägg till dekal"
	if paintCells then paintCells() end
end
decalBtn.Activated:Connect(function()
	if L.decal then L.decal = nil else L.decal = Paint.DECALS[1].id end
	refreshColor()
end)
hex.FocusLost:Connect(function()
	local c = Paint.validHex(hex.Text)
	if c then setFromRGB(c); L.chosen = true else S.toast("Skriv HEX som #RRGGBB", "error") end
	refreshColor()
	if buildChecks then buildChecks() end
end)
local dragging -- "sv" | "hue" | "gloss"
for name, f in pairs({ sv = sv, hue = hue, gloss = glossBar }) do
	f.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = name end end)
end
local function dragTo()
	local m = UIS:GetMouseLocation()
	local inset = GuiService:GetGuiInset()
	local function rel(f)
		local ap, as = f.AbsolutePosition, f.AbsoluteSize
		return math.clamp((m.X - ap.X) / as.X, 0, 1), math.clamp((m.Y - inset.Y - ap.Y) / as.Y, 0, 1)
	end
	if dragging == "sv" then local x, y = rel(sv); L.s, L.v = x, 1 - y; setFromHSV(); L.chosen = true
	elseif dragging == "hue" then local _, y = rel(hue); L.h = math.min(y, 0.999); setFromHSV(); L.chosen = true
	elseif dragging == "gloss" then local x = rel(glossBar); L.gloss = x end
	refreshColor()
	if buildChecks then buildChecks() end
end

---------------------------------------------------------------- scene: the panel on the stand, gun and hand
local scene = Instance.new("Model")
scene.Name = "LackLokal"
local SCALE = 1.5
local function boothCF() return S.origin() * GarageBuilder.BOOTH * CFrame.new(0, 1.2, 0) end
local frame -- face frame: LookVector points from the panel towards the camera
local function faceTowards(part, dir)
	local best, bestDot = Enum.NormalId.Front, -2
	for _, n in ipairs(Enum.NormalId:GetEnumItems()) do
		local d = part.CFrame:VectorToWorldSpace(Vector3.FromNormalId(n)):Dot(dir)
		if d > bestDot then best, bestDot = n, d end
	end
	return best
end
local function buildScene(id)
	scene:ClearAllChildren()
	scene.Parent = workspace -- must be in the world before raycasting against the panel
	local it = S.item(id)
	-- hide the real part on the stand while the work copy is shown
	local plot = S.plot()
	L.hidden = {}
	if plot then
		for _, d in ipairs(plot:GetDescendants()) do
			if d:IsA("Model") and d:GetAttribute("Item") == id then
				for _, q in ipairs(d:GetDescendants()) do if q:IsA("BasePart") then q.LocalTransparencyModifier = 1; L.hidden[#L.hidden + 1] = q end end
			end
		end
	end
	-- what you see: the smooth 3D panel, standing upright with its long side across; grey primer to begin with
	local function extents(cf, size) -- world-axis size of a box
		local r = cf.Rotation
		local x, y, z = r:VectorToWorldSpace(Vector3.new(size.X, 0, 0)), r:VectorToWorldSpace(Vector3.new(0, size.Y, 0)), r:VectorToWorldSpace(Vector3.new(0, 0, size.Z))
		return Vector3.new(math.abs(x.X) + math.abs(y.X) + math.abs(z.X), math.abs(x.Y) + math.abs(y.Y) + math.abs(z.Y), math.abs(x.Z) + math.abs(y.Z) + math.abs(z.Z))
	end
	L.visual = {}
	local part = Parts.get(it.sku)
	local data = part and MeshGen.panel(part.stats.fits, part.stats.panel)
	local okMesh = data and pcall(function()
		local em = AssetService:CreateEditableMesh()
		local ids = {}
		for i, v in ipairs(data.verts) do ids[i] = em:AddVertex(v * SCALE) end
		for _, t in ipairs(data.tris) do em:AddTriangle(ids[t[1]], ids[t[2]], ids[t[3]]) end
		local okP, mp = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(em), { CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition }) end)
		if not okP then mp = AssetService:CreateMeshPartAsync(Content.fromObject(em)) end
		mp.Name = "Kåpa"
		mp.Anchored = true
		mp.CanQuery = true
		mp.Size = data.size * SCALE
		-- moped space: a side panel is long along Z; turn it so the long side runs across the booth
		mp.CFrame = boothCF() * (data.size.X < data.size.Z and CFrame.Angles(0, math.rad(-90), 0) or CFrame.new())
		mp.Parent = scene
		L.visual[1] = mp
	end)
	-- the block version: shown only when the smooth one can't be made
	local model = Models.item(it.sku, nil)
	model:ScaleTo(SCALE)
	local _, size0 = model:GetBoundingBox()
	model:PivotTo(boothCF() * (size0.X < size0.Z and CFrame.Angles(0, math.rad(-90), 0) or CFrame.new()))
	if model.PrimaryPart then model.PrimaryPart:Destroy() end
	for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then d.Transparency = 1; d.CanQuery = true end end
	model.Parent = scene
	if not okMesh then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				local v = d:Clone()
				v.Transparency = 0
				v.CanQuery = false
				v.Parent = scene
				L.visual[#L.visual + 1] = v
			end
		end
	end
	-- the paint grid lies on the face of what you see, towards the room
	local cf, size
	if okMesh then cf, size = L.visual[1].CFrame, extents(L.visual[1].CFrame, L.visual[1].Size)
	else local c, s0 = model:GetBoundingBox(); cf, size = c, extents(c, s0) end
	local w, h, depth = size.X, size.Y, size.Z
	local towardsRoom = Vector3.new(0, 0, 1)
	frame = CFrame.lookAt(cf.Position + towardsRoom * (depth / 2 + 0.06), cf.Position + towardsRoom * 5)
	L.pw, L.ph = math.max(w, 0.5), math.max(h, 0.5)
	L.cells = {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = okMesh and { L.visual[1] } or { model }
	for row = 1, Paint.ROWS do
		for col = 1, Paint.COLS do
			local x = -L.pw / 2 + (col - 0.5) * L.pw / Paint.COLS
			local y = L.ph / 2 - (row - 0.5) * L.ph / Paint.ROWS
			local p0 = frame * Vector3.new(x, y, 0)
			if workspace:Raycast(p0 + frame.LookVector * 1, -frame.LookVector * (depth + 2), params) then L.cells[(row - 1) * Paint.COLS + col] = true end
		end
	end
	L.state = Paint.new()
	for i = 1, Paint.COLS * Paint.ROWS do if not L.cells[i] then L.state.cells[i] = 1 end end
	L.mask = model
	L.smooth = okMesh == true
	L.dots = {}
	-- decal preview on the panel
	local big = L.visual[1]
	for _, v in ipairs(L.visual) do if v.Size.Magnitude > big.Size.Magnitude then big = v end end
	L.decalGui = Instance.new("SurfaceGui")
	L.decalGui.Name = "Dekal"
	L.decalGui.Face = faceTowards(big, towardsRoom)
	L.decalGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	L.decalGui.PixelsPerStud = 60
	L.decalGui.LightInfluence = 1
	L.decalLabel = Instance.new("TextLabel")
	L.decalLabel.Size = UDim2.fromScale(0.6, 0.3)
	L.decalLabel.Position = UDim2.fromScale(0.2, 0.35)
	L.decalLabel.BackgroundTransparency = 1
	L.decalLabel.TextScaled = true
	L.decalLabel.Font = Enum.Font.GothamBlack
	L.decalLabel.Text = ""
	L.decalLabel.Parent = L.decalGui
	L.decalGui.Parent = big
	-- gun with a see-through cup showing the paint, and the hand holding it
	local mk = Models.maker(scene)
	local hand = Models.hand(scene, CFrame.new(), true)
	L.handRig = {}
	for _, d in ipairs(hand:GetDescendants()) do if d:IsA("BasePart") then d.CanQuery = false; L.handRig[#L.handRig + 1] = { d, d.CFrame } end end
	local gun = Instance.new("Model")
	gun.Name = "Sprutpistol"
	gun.Parent = scene
	local gmk = Models.tool(gun, "spruta", CFrame.new(), L.even > 0.5)
	for _, p in ipairs(gmk.parts) do if p.Name == "Kopp" then p.Transparency = 0.6 end end
	L.cupPaint = gmk.cyl("Färg", 0.18, 0.1, CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), col3(), Enum.Material.SmoothPlastic)
	L.gunRig = {}
	for _, d in ipairs(gun:GetDescendants()) do if d:IsA("BasePart") then d.CanQuery = false; L.gunRig[#L.gunRig + 1] = { d, d.CFrame } end end
	local nozzle = mk.box("Munstycke", Vector3.new(0.05, 0.05, 0.05), CFrame.new(), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	nozzle.Transparency = 1
	nozzle.CanQuery = false
	local att = Instance.new("Attachment")
	att.Parent = nozzle
	L.mist = Instance.new("ParticleEmitter")
	L.mist.Rate = 0
	L.mist.Lifetime = NumberRange.new(0.35, 0.7)
	L.mist.Speed = NumberRange.new(9, 12)
	L.mist.SpreadAngle = Vector2.new(14, 14)
	L.mist.Size = NumberSequence.new(0.2, 1.5)
	L.mist.Transparency = NumberSequence.new(0.35, 1)
	L.mist.LightEmission = 0.25
	L.mist.EmissionDirection = Enum.NormalId.Front
	L.mist.Parent = att
	L.nozzle = nozzle
	-- the booth's front wall, curtain and sign stand between the camera and the panel: hide them locally
	if plot then
		for _, d in ipairs(plot:GetDescendants()) do
			if d:IsA("BasePart") and (d.Name == "Lackbox" or d.Name == "Draperi" or d.Name == "Skylt") then
				local off = d.Position - frame.Position
				if off:Dot(frame.LookVector) > depth / 2 + 1 and math.abs(off:Dot(frame.RightVector)) < 9 and d.Size.Y > 0.5 then
					d.LocalTransparencyModifier = 1
					L.hidden[#L.hidden + 1] = d
				end
			end
		end
	end
	-- camera inside the booth, straight in front of the panel; the panel sits right of the colour panel
	-- (frame.RightVector is the camera's left: the frame looks back at the camera)
	local back = math.max(5.5, L.pw * 1.45, L.ph * 1.9)
	local side = frame.RightVector * (back * 0.1)
	S.camTo(CFrame.lookAt(frame.Position + frame.LookVector * back + frame.UpVector * 0.8 + side, frame.Position + side + frame.UpVector * -0.15), 50, 0.4)
end
paintCells = function()
	if not L.state then return end
	local cov = Paint.coverage(L.state)
	local r = Paint.result(L.state)
	local lookC, lookM, lookR = Paint.look({ c = L.color, f = L.finish, g = L.gloss })
	local c = PRIMER:Lerp(lookC, math.clamp(cov * 1.25, 0, 1))
	if r.runs > 0 then c = c:Lerp(Color3.new(0, 0, 0), math.min(0.3, r.runs * 2)) end
	for _, v in ipairs(L.visual or {}) do
		v.Color = c
		v.Material = cov > 0.6 and lookM or Enum.Material.SmoothPlastic
		v.Reflectance = cov > 0.6 and lookR or 0
	end
	if L.cupPaint then L.cupPaint.Color = col3() end
	-- the spots melt into an even coat as coverage grows
	for _, d in ipairs(L.dots or {}) do d.Transparency = math.clamp(0.15 + cov * 0.9, 0.15, 1) end
	if L.decalLabel then
		local d = Paint.DECAL[L.decal or ""]
		L.decalLabel.Text = d and d.text or ""
		if d then L.decalLabel.TextColor3 = Color3.fromRGB(d.c[1], d.c[2], d.c[3]) end
	end
	local pct = math.floor(cov * 100)
	if L.phase == "spray" then
		progLabel.Text = "Lackar..."
		progPct.Text = pct .. "%"
		progFill.Size = UDim2.fromScale(cov, 1)
	end
end
buildChecks = function()
	UI.clear(checks)
	local cov = L.state and Paint.coverage(L.state) or 0
	local rows = {
		{ "Placera kåpan", L.state ~= nil },
		{ "Välj färg", L.chosen },
		{ "Spraya jämnt", cov >= 0.9 },
		{ "Låt torka", L.phase == "dry" and L.dryLeft and L.dryLeft <= 0 },
	}
	for i, r in ipairs(rows) do
		local f = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = i, Name = r[1] }, checks)
		local mark = UI.new("Frame", { Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(0, 4), BackgroundColor3 = r[2] and UI.C.green or UI.C.panel, BackgroundTransparency = r[2] and 0 or 1, BorderSizePixel = 0 }, f)
		UI.corner(mark, 10)
		if r[2] then UI.text(mark, "✓", UDim2.fromScale(1, 1), nil, { ts = 14, font = UI.BOLD, xa = Enum.TextXAlignment.Center })
		else UI.stroke(mark, UI.C.text, 2, 0.2) end
		UI.text(f, r[1], UDim2.new(1, -30, 1, 0), UDim2.fromOffset(30, 0), { ts = 16, font = UI.BOLD })
	end
end

---------------------------------------------------------------- flow: pick a panel, spray, Avsluta saves, then it dries
local function begin()
	local ok, inf = S.api("paintStart")
	if not ok then return false end
	L.even = inf.even or 0
	L.t = 0
	L.phase = "spray"
	L.chosen = false
	buildScene(inf.item)
	panel.Visible, checks.Visible, prog.Visible, quit.Visible, tipBox.Visible = true, true, true, true, true
	refreshColor()
	paintCells()
	buildChecks()
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
quit.Activated:Connect(function()
	if L.phase == "spray" and L.state and L.t >= 3 then
		local ok, r = S.api("paintDone", L.color, L.finish, L.gloss, L.state, L.decal)
		if ok then
			S.toast(string.format("Lackerat: %s (%d %%). Låt lacken torka.", r.label, math.floor(r.q * 100)), "ok")
			L.phase = "dry"
			L.dryLeft = Config.PAINT_DRY
			L.spraying = false
			buildChecks()
		end
		return
	end
	S.endMode("paint")
end)
local function open()
	if not S.setMode("paint") then return end
	gui.Enabled = true
	panel.Visible, checks.Visible, prog.Visible, quit.Visible, tipBox.Visible = false, false, false, false, false
	S.camTo(S.origin() * GarageBuilder.BOOTH * CFrame.new(0, 2, -9) * CFrame.Angles(math.rad(-8), math.pi, 0), 50, 0.4)
	local hung
	for _, it in pairs(S.profile.items) do if it.loc == "lack" then hung = true end end
	if not (hung and begin()) then showPicker() end
end
local function close()
	gui.Enabled = false
	picker.Visible = false
	L.spraying = false
	-- leaving without Avsluta frees the panel on the stand again (you can pick it up)
	task.spawn(function() S.api("workCancel") end)
	L.state, L.cells, L.visual, L.mask, L.dots, L.decalGui, L.decalLabel, L.cupPaint = nil, nil, nil, nil, nil, nil, nil, nil
	for _, q in ipairs(L.hidden or {}) do if q.Parent then q.LocalTransparencyModifier = 0 end end
	L.hidden = nil
	scene:ClearAllChildren()
	scene.Parent = nil
end
S.open.Event:Connect(function(what, atStation) if what == "paint" and atStation then open() end end)
S.modeEv.Event:Connect(function(mode) if mode ~= "paint" and gui.Enabled then close() end end)

---------------------------------------------------------------- input and spraying
UIS.InputBegan:Connect(function(input, gp)
	if S.mode ~= "paint" or not L.state then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and (not gp or not S.mouseOverUi()) and L.phase == "spray" and not dragging then L.spraying = true end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		L.spraying = false
		dragging = nil
	end
end)
UIS.InputChanged:Connect(function(input)
	if S.mode ~= "paint" then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		L.dist = math.clamp(L.dist - input.Position.Z * 0.1, 0.6, 1.6)
	elseif input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
		dragTo()
	end
end)
local acc = 0
RunService.RenderStepped:Connect(function(dt)
	if S.mode ~= "paint" or not L.state or not frame or not L.handRig then return end
	if L.spraying and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then L.spraying = false end
	-- drying countdown after Avsluta
	if L.phase == "dry" then
		L.dryLeft = math.max(0, L.dryLeft - dt)
		progLabel.Text = L.dryLeft > 0 and "Torkar..." or "Torr!"
		progPct.Text = string.format("%d s", math.ceil(L.dryLeft))
		progFill.Size = UDim2.fromScale(1 - L.dryLeft / Config.PAINT_DRY, 1)
		if L.dryLeft <= 0 and not L.dryDone then
			L.dryDone = true
			buildChecks()
			task.delay(1.2, function() if S.mode == "paint" then S.endMode("paint") end; L.dryDone = false end)
		end
	end
	local cam = workspace.CurrentCamera
	local m = UIS:GetMouseLocation()
	local ray = cam:ViewportPointToRay(m.X, m.Y)
	local n = frame.LookVector
	local denom = ray.Direction:Dot(n)
	if math.abs(denom) < 1e-4 then return end
	local hit = ray.Origin + ray.Direction * ((frame.Position - ray.Origin):Dot(n) / denom)
	-- the gun hovers in front of the panel at the chosen distance, nozzle aimed at the point
	-- (frame.RightVector points to the camera's left) so the gun sits low and to the right of the aim point
	local gunPos = hit + n * (0.9 + 1.1 * L.dist) - frame.RightVector * 0.55 - frame.UpVector * 0.3
	-- while it dries the gun is put away (out of sight behind the camera)
	if L.phase == "dry" then gunPos, hit = cam.CFrame.Position - cam.CFrame.LookVector * 20, cam.CFrame.Position - cam.CFrame.LookVector * 25 end
	local gunCF = CFrame.lookAt(gunPos, hit)
	for _, r in ipairs(L.gunRig) do r[1].CFrame = gunCF * r[2] end
	-- hand round the grip, fingers up around it and the arm going down out of the picture
	local handCF = gunCF * CFrame.new(0, -0.34, 0.16) * CFrame.Angles(math.rad(78), 0, 0)
	for _, r in ipairs(L.handRig) do r[1].CFrame = handCF * r[2] end
	L.nozzle.CFrame = gunCF * CFrame.new(0, 0.03, -0.32)
	L.mist.Color = ColorSequence.new(col3())
	L.mist.Rate = L.spraying and 150 or 0
	if L.spraying then
		local l = frame:PointToObjectSpace(hit)
		local u, v = (l.X + L.pw / 2) / L.pw, (L.ph / 2 - l.Y) / L.ph
		if u > -0.15 and u < 1.15 and v > -0.15 and v < 1.15 then Paint.spray(L.state, u, v, dt, L.dist, L.even, L.pw / Paint.COLS, L.ph / Paint.ROWS) else L.state.t = L.state.t + dt end
		-- paint spots where the spray hits the panel
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = L.smooth and L.visual or { L.mask }
		local _, finM, finR = Paint.look({ c = L.color, f = L.finish, g = L.gloss })
		for _ = 1, 3 do
			local aim = hit + frame.RightVector * (math.random() - 0.5) * 0.6 * L.dist + frame.UpVector * (math.random() - 0.5) * 0.6 * L.dist
			local res = workspace:Raycast(gunPos, (aim - gunPos) * 1.5, params)
			if res then
				local dot
				if #L.dots >= 900 then dot = table.remove(L.dots, 1) else
					dot = Instance.new("Part")
					dot.Shape = Enum.PartType.Cylinder
					dot.Anchored, dot.CanCollide, dot.CanQuery, dot.CanTouch, dot.CastShadow = true, false, false, false, false
					dot.Name = "Lackprick"
					dot.Parent = scene
				end
				local d = (0.1 + math.random() * 0.07) * L.dist
				dot.Size = Vector3.new(0.02, d, d)
				dot.CFrame = CFrame.lookAt(res.Position + res.Normal * 0.015, res.Position + res.Normal) * CFrame.Angles(0, math.pi / 2, 0)
				dot.Color = col3()
				dot.Material = finM
				dot.Reflectance = finR
				dot.Transparency = math.clamp(0.15 + Paint.coverage(L.state) * 0.9, 0.15, 1)
				L.dots[#L.dots + 1] = dot
			end
		end
		L.t = L.t + dt
		acc = acc + dt
		if acc > 0.1 then
			acc = 0
			paintCells()
			if Paint.coverage(L.state) >= 0.9 then buildChecks() end
		end
	end
end)

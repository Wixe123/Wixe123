-- The open world (the garages themselves are built by Main via GarageBuilder):
-- terrain with hills and a lake, the industrial street in front of the garages, drag strip and ring track (test track),
-- industrial area, country road with fields and a farm, car park, petrol station, Swedish houses and trees.
local Lighting = game:GetService("Lighting")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local S = 1 / Config.STUD
local function M(x) return x * S end

local world = Instance.new("Folder"); world.Name = "MoppeWorld"; world.Parent = workspace
local function part(name, size, cf, color, material, shape, parent)
	local p = Instance.new("Part"); p.Name = name
	if shape == "cyl" then p.Shape = Enum.PartType.Cylinder elseif shape == "ball" then p.Shape = Enum.PartType.Ball end
	p.Size, p.CFrame, p.Color, p.Material, p.Anchored = size, cf, color, material or Enum.Material.SmoothPlastic, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent or world
	return p
end
local function wedge(name, size, cf, color, material, parent)
	local w = Instance.new("WedgePart"); w.Name, w.Size, w.CFrame, w.Color, w.Material, w.Anchored = name, size, cf, color, material or Enum.Material.SmoothPlastic, true
	w.Parent = parent or world
	return w
end
-- box in metres: centre (x, z), y = bottom
local function blk(name, w, h, d, x, y, z, color, mat, ry)
	return part(name, Vector3.new(M(w), M(h), M(d)), CFrame.new(M(x), M(y + h / 2), -M(z)) * CFrame.Angles(0, math.rad(ry or 0), 0), color, mat)
end

-- ---------- light ----------
Lighting.ClockTime, Lighting.GeographicLatitude, Lighting.Brightness = 15, 59, 2.4
Lighting.EnvironmentDiffuseScale, Lighting.EnvironmentSpecularScale = 1, 1
Lighting.OutdoorAmbient, Lighting.Ambient, Lighting.GlobalShadows = Color3.fromRGB(118, 124, 134), Color3.fromRGB(38, 40, 46), true
local atm = Instance.new("Atmosphere"); atm.Density, atm.Offset, atm.Color, atm.Decay, atm.Glare, atm.Haze = 0.3, 0.12, Color3.fromRGB(199, 214, 230), Color3.fromRGB(106, 126, 148), 0.25, 1.4; atm.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect"); cc.Saturation, cc.Contrast = 0.06, 0.06; cc.Parent = Lighting
local bloom = Instance.new("BloomEffect"); bloom.Intensity, bloom.Size, bloom.Threshold = 0.35, 24, 1.3; bloom.Parent = Lighting
local rays = Instance.new("SunRaysEffect"); rays.Intensity, rays.Spread = 0.04, 0.6; rays.Parent = Lighting

-- ---------- terrain ----------
local base = workspace:FindFirstChild("Baseplate"); if base then base:Destroy() end
local T = workspace.Terrain
T.WaterColor, T.WaterReflectance, T.WaterTransparency, T.WaterWaveSize, T.WaterWaveSpeed = Color3.fromRGB(40, 78, 96), 0.6, 0.4, 0.08, 6
T:FillBlock(CFrame.new(0, -8, M(110)), Vector3.new(M(560), 16, M(480)), Enum.Material.Grass) -- (z in metres -110 = Roblox +Z)
local hr = Random.new(3)
for i = 0, 31 do
	local a = i / 32 * math.pi * 2
	T:FillBall(Vector3.new(math.cos(a) * M(265), -M(4), M(110) + math.sin(a) * M(225)), M(26 + hr:NextNumber() * 18), hr:NextNumber() < 0.25 and Enum.Material.Rock or Enum.Material.Grass)
end
local lake = Vector3.new(-M(100), 0, M(250)) -- metres (x -100, z -250)
T:FillCylinder(CFrame.new(lake + Vector3.new(0, -2, 0)), 4, M(32), Enum.Material.Sand)
T:FillCylinder(CFrame.new(lake + Vector3.new(0, -4, 0)), 8, M(28), Enum.Material.Water)

-- ---------- roads ----------
local asph, lineC, curbC, walk = Color3.fromRGB(56, 59, 64), Color3.fromRGB(232, 232, 226), Color3.fromRGB(165, 165, 160), Color3.fromRGB(150, 150, 146)
local function road(x1, z1, x2, z2, w)
	local A, B = Vector3.new(M(x1), 0.2, -M(z1)), Vector3.new(M(x2), 0.2, -M(z2))
	local len = (B - A).Magnitude
	local cf = CFrame.lookAt((A + B) / 2, B)
	part("Road", Vector3.new(M(w), 0.6, len + M(w) * 0.3), cf, asph, Enum.Material.Asphalt)
	for i = 0, math.floor(len / M(8)) - 1 do part("Dash", Vector3.new(0.35, 0.05, M(3)), cf * CFrame.new(0, 0.32, -len / 2 + M(4) + i * M(8)), lineC) end
	for _, s in ipairs({ -1, 1 }) do part("Edge", Vector3.new(0.35, 0.05, len), cf * CFrame.new(s * (M(w / 2) - 0.6), 0.32, 0), lineC) end
	return cf, len
end
local function streetlight(x, z, face)
	part("Pole", Vector3.new(M(6), M(0.16), M(0.16)), CFrame.new(M(x), M(3), -M(z)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(90, 94, 100), Enum.Material.Metal, "cyl")
	local lamp = part("StreetLamp", Vector3.new(M(0.6), M(0.12), M(0.3)), CFrame.new(M(x + face * 1.4), M(5.9), -M(z)), Color3.fromRGB(255, 236, 200), Enum.Material.Neon)
	part("Arm", Vector3.new(M(1.6), M(0.1), M(0.1)), CFrame.new(M(x + face * 0.8), M(5.95), -M(z)), Color3.fromRGB(90, 94, 100), Enum.Material.Metal)
	local l = Instance.new("SpotLight"); l.Face = Enum.NormalId.Bottom; l.Angle = 110; l.Range = 50; l.Brightness = 1.2; l.Color = Color3.fromRGB(255, 228, 180); l.Parent = lamp
end
-- industrial street in front of the garages (along X) with pavement on the garage side
local sz = Config.STREET_Z
road(-120, sz, 120, sz, 9)
blk("Pavement", 240, 0.15, 2.5, 0, 0, sz + 5.75, walk, Enum.Material.Pavement)
blk("Curb", 240, 0.15, 0.25, 0, 0, sz + 4.6, curbC, Enum.Material.Concrete)
for x = -110, 110, 22 do streetlight(x, sz + 6.2, -1) end
-- driveways from each garage to the street
for _, pl in ipairs(Config.PLOTS) do blk("Driveway", 7, 0.1, 4.5, pl.x, 0, pl.z - 10.5, asph, Enum.Material.Asphalt) end
-- drag strip south from the middle, ring track (test track) at its end
road(0, sz - 4, 0, -200, 10)
blk("StartLine", 10, 0.06, 0.5, 0, 0.5, sz - 12, lineC)
local ring = Vector3.new(M(80), 0, M(120))
local R1, R2, N = M(38), M(50), 72
for i = 0, N - 1 do
	local a = i / N * math.pi * 2
	local r = (R1 + R2) / 2
	part("Ring", Vector3.new(R2 - R1, 0.6, 2 * math.pi * r / N * 1.08), CFrame.new(ring + Vector3.new(math.cos(a) * r, 0.2, math.sin(a) * r)) * CFrame.Angles(0, -a, 0), asph, Enum.Material.Asphalt)
	for _, rr in ipairs({ R1 - M(0.4), R2 + M(0.4) }) do
		part("Kerb", Vector3.new(M(0.8), 0.7, 2 * math.pi * rr / N * 1.02), CFrame.new(ring + Vector3.new(math.cos(a) * rr, 0.2, math.sin(a) * rr)) * CFrame.Angles(0, -a, 0), i % 2 == 0 and Color3.fromRGB(200, 30, 30) or Color3.fromRGB(240, 240, 236))
	end
end
road(0, -120, 80 - 50, -120, 8)
-- country road west with fields and a farm
road(-120, sz, -200, sz, 7)
road(-200, sz, -230, -120, 7)
road(-230, -120, -230, -230, 7)
for i = 0, 5 do
	local fx, fz = -175 + (i % 2) * 40, -50 - math.floor(i / 2) * 55
	blk("Field", 34, 0.12, 48, fx, 0, fz, i % 3 == 0 and Color3.fromRGB(196, 170, 90) or Color3.fromRGB(110, 86, 60), i % 3 == 0 and Enum.Material.LeafyGrass or Enum.Material.Ground)
	for r = 0, 9 do blk("Row", 33, 0.08, 0.4, fx, 0.12, fz - 22 + r * 4.8, Color3.fromRGB(85, 120, 50), Enum.Material.LeafyGrass) end
end
blk("Barn", 18, 7, 10, -265, 0, -150, Color3.fromRGB(138, 43, 31), Enum.Material.WoodPlanks)
wedge("BarnRoofA", Vector3.new(M(19), M(4), M(5.5)), CFrame.new(M(-265), M(9), M(150) + M(2.75)) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(46, 47, 51), Enum.Material.Slate)
wedge("BarnRoofB", Vector3.new(M(19), M(4), M(5.5)), CFrame.new(M(-265), M(9), M(150) - M(2.75)), Color3.fromRGB(46, 47, 51), Enum.Material.Slate)
-- industrial area east: warehouses and containers
for i = 0, 3 do
	local wx, wz = 140 + (i % 2) * 34, -40 - math.floor(i / 2) * 40
	blk("Warehouse", 28, 9, 22, wx, 0, wz, i % 2 == 0 and Color3.fromRGB(150, 156, 160) or Color3.fromRGB(120, 130, 120), Enum.Material.CorrodedMetal)
	blk("WarehouseDoor", 6, 5, 0.3, wx, 0, wz + 11.1, Color3.fromRGB(200, 200, 196), Enum.Material.Metal)
end
local cr = Random.new(9)
for i = 0, 11 do
	local c = ({ Color3.fromRGB(170, 50, 40), Color3.fromRGB(40, 90, 150), Color3.fromRGB(60, 120, 70), Color3.fromRGB(200, 140, 40) })[i % 4 + 1]
	blk("Container", 6, 2.6, 2.4, 135 + (i % 4) * 7, (i >= 8) and 2.6 or 0, -120 - math.floor(i / 4 % 2) * 3, c, Enum.Material.CorrodedMetal, cr:NextNumber() * 6)
end
road(120, sz, 150, sz, 9)
road(150, sz, 150, -140, 8)
-- car park and petrol station (no brand)
blk("ParkingLot", 30, 0.1, 20, 30, 0, -40, asph, Enum.Material.Asphalt)
for i = 0, 7 do blk("Bay", 0.2, 0.05, 5, 17 + i * 3.6, 0.1, -35, lineC) end
blk("StationRoof", 16, 0.6, 10, -45, 5, -40, Color3.fromRGB(235, 235, 230), Enum.Material.SmoothPlastic)
for _, x in ipairs({ -51, -39 }) do blk("StationPillar", 0.5, 5, 0.5, x, 0, -40, Color3.fromRGB(235, 235, 230)) end
for _, x in ipairs({ -48, -42 }) do blk("Pump", 0.8, 1.6, 0.5, x, 0, -40, Color3.fromRGB(40, 140, 80)) end
blk("StationShop", 12, 4, 8, -45, 0, -52, Color3.fromRGB(210, 210, 205), Enum.Material.Concrete)
local ss = blk("StationSign", 6, 1, 0.2, -45, 4.2, -48, Color3.fromRGB(30, 120, 70))
local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.CanvasSize = Vector2.new(300, 50); sg.Parent = ss
local stl = Instance.new("TextLabel"); stl.Size = UDim2.fromScale(1, 1); stl.BackgroundTransparency = 1; stl.Text = "MACKEN"; stl.TextScaled = true; stl.Font = Enum.Font.GothamBlack; stl.TextColor3 = Color3.new(1, 1, 1); stl.Parent = sg
blk("StationApron", 24, 0.1, 22, -45, 0, -44, asph, Enum.Material.Asphalt)

-- ---------- houses and trees ----------
local rnd = Random.new(7)
local white = Color3.fromRGB(242, 240, 234)
local function house(x, z, ry, col)
	local h = Instance.new("Model"); h.Name = "House"; h.Parent = world
	local cf = CFrame.new(M(x), 0, -M(z)) * CFrame.Angles(0, ry, 0)
	local w, d, Hh = 8, 6, 2.8
	local function p(n, sw, sh, sd, ox, oy, oz, c, mat) return part(n, Vector3.new(M(sw), M(sh), M(sd)), cf * CFrame.new(M(ox), M(oy), -M(oz)), c, mat, nil, h) end
	p("Plinth", w + 0.2, 0.5, d + 0.2, 0, 0.25, 0, Color3.fromRGB(85, 88, 92), Enum.Material.Concrete)
	p("Walls", w, Hh, d, 0, 0.5 + Hh / 2, 0, col, Enum.Material.WoodPlanks)
	for _, sx in ipairs({ -1, 1 }) do for _, szz in ipairs({ -1, 1 }) do p("Corner", 0.16, Hh, 0.16, sx * w / 2, 0.5 + Hh / 2, szz * d / 2, white, Enum.Material.WoodPlanks) end end
	for _, s in ipairs({ -1, 1 }) do wedge("Roof", Vector3.new(M(w + 0.5), M(1.8), M(d / 2 + 0.25)), cf * CFrame.new(0, M(0.5 + Hh + 0.9), s * M(d / 4 + 0.12)) * CFrame.Angles(0, s > 0 and math.pi or 0, 0), Color3.fromRGB(46, 47, 51), Enum.Material.Slate, h) end
	p("Chimney", 0.6, 1.6, 0.6, w * 0.25, 0.5 + Hh + 1.3, d * 0.15, Color3.fromRGB(120, 60, 45), Enum.Material.Brick)
	for i = 0, 2 do for _, s in ipairs({ -1, 1 }) do
		p("WinFrame", 1, 1.15, 0.08, -w / 2 + 1.5 + i * 2.6, 0.5 + 1.55, s * (d / 2 + 0.03), white, Enum.Material.WoodPlanks)
		local g = p("Glass", 0.82, 0.95, 0.1, -w / 2 + 1.5 + i * 2.6, 0.5 + 1.55, s * (d / 2 + 0.04), Color3.fromRGB(40, 55, 70), Enum.Material.Glass); g.Reflectance = 0.35
	end end
	p("Door", 1, 2, 0.08, w / 2 - 1.4, 0.5 + 1, d / 2 + 0.04, Color3.fromRGB(59, 42, 30), Enum.Material.Wood)
	for i = -10, 10 do p("Picket", 0.08, 0.9, 0.03, i * 0.5, 0.45, d / 2 + 4, white, Enum.Material.WoodPlanks) end
	p("Mailbox", 0.35, 0.3, 0.45, 6, 1.1, d / 2 + 4.5, Color3.fromRGB(40, 90, 170), Enum.Material.Metal)
	p("MailPost", 0.08, 1, 0.08, 6, 0.5, d / 2 + 4.5, Color3.fromRGB(70, 70, 70), Enum.Material.Metal)
end
local function spruce(x, z, hgt)
	part("Trunk", Vector3.new(M(1.6), M(0.4), M(0.4)), CFrame.new(M(x), M(0.8), -M(z)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(74, 51, 34), Enum.Material.Wood, "cyl")
	local col = Color3.fromRGB(26 + rnd:NextInteger(0, 10), 60 + rnd:NextInteger(0, 16), 34)
	for i = 0, 5 do local f = i / 5; local r = M(4.2 - 3.3 * f); part("Needles", Vector3.new(M(hgt * 0.16), r, r), CFrame.new(M(x), M(1.3 + f * hgt * 0.78), -M(z)) * CFrame.Angles(0, rnd:NextNumber() * 3, math.pi / 2), col, Enum.Material.Grass, "cyl") end
end
local function birch(x, z, hgt)
	part("Trunk", Vector3.new(M(hgt * 0.7), M(0.25), M(0.25)), CFrame.new(M(x), M(hgt * 0.35), -M(z)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(232, 228, 218), Enum.Material.SmoothPlastic, "cyl")
	for i = 0, 4 do local s = M(1.8 + rnd:NextNumber() * 1.2); part("Leaves", Vector3.new(s, s * 0.9, s), CFrame.new(M(x + (rnd:NextNumber() - 0.5) * 1.8), M(hgt * 0.6 + i * 0.55), -M(z + (rnd:NextNumber() - 0.5) * 1.8)), Color3.fromRGB(88 + rnd:NextInteger(0, 20), 140 + rnd:NextInteger(0, 20), 56), Enum.Material.LeafyGrass, "ball") end
end
-- areas kept free: garages + street, roads, ring, fields, industrial area, petrol station, car park, lake
local function blocked(x, z)
	if z > sz - 8 and z < 14 and x > -130 and x < 130 then return true end
	if math.abs(x) < 9 and z < sz and z > -205 then return true end
	local d = math.sqrt((x - 80) ^ 2 + (z + 120) ^ 2); if d > 30 and d < 60 then return true end
	if z > -126 and z < -114 and x > 0 and x < 40 then return true end
	if x < -150 and x > -210 and z < -20 and z > -200 then return true end
	if x > 115 and x < 200 and z < 10 and z > -140 then return true end
	if x > -60 and x < -28 and z > -60 and z < -28 then return true end
	if x > 12 and x < 48 and z > -52 and z < -28 then return true end
	if math.sqrt((x + 100) ^ 2 + (z + 250) ^ 2) < 36 then return true end
	if math.abs(x + 230) < 8 or (z > sz - 6 and z < sz + 6 and x < -100) then return true end
	if math.sqrt(x ^ 2 + (z + 110) ^ 2) > 240 then return true end
	return false
end
local colors = { Color3.fromRGB(138, 43, 31), Color3.fromRGB(214, 176, 74), Color3.fromRGB(234, 229, 216), Color3.fromRGB(138, 43, 31) }
local n = 0
for _ = 1, 800 do
	if n >= 18 then break end
	local x, z = rnd:NextNumber(-220, 220), rnd:NextNumber(-320, 100)
	if not blocked(x, z) and not blocked(x, z - 8) and not blocked(x + 6, z) and not blocked(x - 6, z) then n = n + 1; house(x, z, rnd:NextInteger(0, 3) * math.pi / 2, colors[n % 4 + 1]) end
end
n = 0
for _ = 1, 1600 do
	if n >= 140 then break end
	local x, z = rnd:NextNumber(-240, 240), rnd:NextNumber(-330, 110)
	if not blocked(x, z) then n = n + 1; if rnd:NextNumber() < 0.65 then spruce(x, z, 6 + rnd:NextNumber() * 6) else birch(x, z, 5 + rnd:NextNumber() * 4) end end
end

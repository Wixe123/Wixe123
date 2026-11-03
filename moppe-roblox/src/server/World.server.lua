-- Builds the world when the server starts: garage, road out, drag strip, ring track, Swedish houses, trees, light.
local Lighting = game:GetService("Lighting")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local S = 1 / Config.STUD

local world = Instance.new("Folder")
world.Name = "MoppeWorld"
world.Parent = workspace

local function part(name, size, cf, color, material, parent, shape)
	local p = Instance.new("Part")
	p.Name = name
	if shape == "cyl" then p.Shape = Enum.PartType.Cylinder elseif shape == "ball" then p.Shape = Enum.PartType.Ball end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or world
	return p
end
local function wedge(name, size, cf, color, material, parent)
	local w = Instance.new("WedgePart")
	w.Name, w.Size, w.CFrame, w.Color, w.Material, w.Anchored = name, size, cf, color, material or Enum.Material.SmoothPlastic, true
	w.Parent = parent or world
	return w
end
local M = function(x) return x * S end -- metres -> studs

-- light: Swedish summer afternoon
Lighting.ClockTime = 14.5
Lighting.GeographicLatitude = 59
Lighting.Brightness = 2.6
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.OutdoorAmbient = Color3.fromRGB(120, 125, 135)
Lighting.Ambient = Color3.fromRGB(40, 42, 48)
Lighting.GlobalShadows = true
local atm = Instance.new("Atmosphere")
atm.Density, atm.Offset, atm.Color, atm.Decay, atm.Glare, atm.Haze = 0.28, 0.1, Color3.fromRGB(200, 215, 230), Color3.fromRGB(110, 130, 150), 0.2, 1.2
atm.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect"); cc.Saturation, cc.Contrast = 0.05, 0.05; cc.Parent = Lighting
local bloom = Instance.new("BloomEffect"); bloom.Intensity, bloom.Size, bloom.Threshold = 0.4, 24, 1.2; bloom.Parent = Lighting

-- ground
local base = workspace:FindFirstChild("Baseplate")
if base then base:Destroy() end
part("Ground", Vector3.new(M(420), 4, M(420)), CFrame.new(0, -2, M(-120)), Color3.fromRGB(76, 122, 55), Enum.Material.Grass)

-- garage (inner floor 12 x 12 m, door towards -Z)
local G = Instance.new("Folder"); G.Name = "Garage"; G.Parent = world
local W, H = M(12), M(4)
part("Floor", Vector3.new(W, 0.4, W), CFrame.new(0, 0.2, 0), Color3.fromRGB(120, 122, 124), Enum.Material.Concrete, G)
local wallC, wallMat = Color3.fromRGB(205, 200, 190), Enum.Material.Plaster
part("WallBack", Vector3.new(W, H, 1), CFrame.new(0, H / 2, W / 2), wallC, wallMat, G)
part("WallL", Vector3.new(1, H, W), CFrame.new(-W / 2, H / 2, 0), wallC, wallMat, G)
part("WallR", Vector3.new(1, H, W), CFrame.new(W / 2, H / 2, 0), wallC, wallMat, G)
local door = M(5)
part("WallFrontL", Vector3.new((W - door) / 2, H, 1), CFrame.new(-(W + door) / 4, H / 2, -W / 2), wallC, wallMat, G)
part("WallFrontR", Vector3.new((W - door) / 2, H, 1), CFrame.new((W + door) / 4, H / 2, -W / 2), wallC, wallMat, G)
part("DoorTop", Vector3.new(door, M(1), 1), CFrame.new(0, H - M(0.5), -W / 2), wallC, wallMat, G)
part("Roof", Vector3.new(W + 2, 1, W + 2), CFrame.new(0, H + 0.5, 0), Color3.fromRGB(70, 72, 76), Enum.Material.Slate, G)
for _, x in ipairs({ -M(2.2), M(2.2) }) do part("Line", Vector3.new(0.25, 0.05, M(8)), CFrame.new(x, 0.42, 0), Color3.fromRGB(216, 180, 30), Enum.Material.SmoothPlastic, G) end
for _, z in ipairs({ -M(3), 0, M(3) }) do
	for _, x in ipairs({ -M(2), M(2) }) do
		local tube = part("Tube", Vector3.new(M(2.4), 0.25, 0.4), CFrame.new(x, H - 0.4, z), Color3.fromRGB(255, 255, 245), Enum.Material.Neon, G)
		local l = Instance.new("SurfaceLight"); l.Face = Enum.NormalId.Bottom; l.Brightness = 1.4; l.Range = 20; l.Angle = 120; l.Parent = tube
	end
end
-- workbench, tool wall, tyres, barrel
part("Bench", Vector3.new(M(3.2), 0.4, M(0.8)), CFrame.new(-M(3), M(0.95), W / 2 - M(0.5)), Color3.fromRGB(138, 90, 51), Enum.Material.Wood, G)
for _, x in ipairs({ -M(4.4), -M(1.6) }) do part("BenchLeg", Vector3.new(0.3, M(0.95), M(0.7)), CFrame.new(x, M(0.47), W / 2 - M(0.5)), Color3.fromRGB(93, 99, 107), Enum.Material.Metal, G) end
part("ToolWall", Vector3.new(M(2.6), M(1.3), 0.2), CFrame.new(-M(3), M(1.9), W / 2 - 0.6), Color3.fromRGB(140, 122, 90), Enum.Material.WoodPlanks, G)
part("ToolChest", Vector3.new(M(0.6), M(0.9), M(0.45)), CFrame.new(-M(0.8), M(0.45), W / 2 - M(0.4)), Color3.fromRGB(181, 35, 28), Enum.Material.Metal, G)
for i = 0, 3 do part("Tyre", Vector3.new(M(0.18), M(0.7), M(0.7)), CFrame.new(W / 2 - M(0.6), M(0.1) + i * M(0.18), W / 2 - M(0.7)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(22, 22, 24), Enum.Material.SmoothPlastic, G, "cyl") end
part("Barrel", Vector3.new(M(0.9), M(0.6), M(0.6)), CFrame.new(W / 2 - M(0.6), M(0.45), W / 2 - M(1.8)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(31, 95, 158), Enum.Material.Metal, G, "cyl")
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Name = "Spawn"; spawnPad.Size = Vector3.new(6, 0.4, 6); spawnPad.CFrame = CFrame.new(M(3.5), 0.45, M(2)); spawnPad.Anchored = true
spawnPad.Transparency = 1; spawnPad.CanCollide = false; spawnPad.Neutral = true; spawnPad.Parent = G
local mopedPad = part("MopedSpot", Vector3.new(1, 0.1, 1), CFrame.new(0, 0.45, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, G)
mopedPad.Transparency = 1; mopedPad.CanCollide = false

-- road: out from the garage (-Z), drag strip, ring track
local asph, lineC = Color3.fromRGB(58, 61, 66), Color3.fromRGB(232, 232, 226)
part("Driveway", Vector3.new(M(6), 0.4, M(14)), CFrame.new(0, 0.2, -W / 2 - M(7)), asph, Enum.Material.Asphalt)
part("Strip", Vector3.new(M(10), 0.4, M(170)), CFrame.new(0, 0.2, -W / 2 - M(14) - M(85)), asph, Enum.Material.Asphalt)
for _, x in ipairs({ -M(4.6), M(4.6) }) do part("Edge", Vector3.new(0.4, 0.05, M(170)), CFrame.new(x, 0.42, -W / 2 - M(14) - M(85)), lineC, Enum.Material.SmoothPlastic) end
for i = 0, 20 do part("Dash", Vector3.new(0.35, 0.05, M(3)), CFrame.new(0, 0.42, -W / 2 - M(18) - i * M(8)), lineC, Enum.Material.SmoothPlastic) end
part("StartLine", Vector3.new(M(10), 0.06, 0.6), CFrame.new(0, 0.43, -W / 2 - M(20)), lineC, Enum.Material.SmoothPlastic)
local ringC = Vector3.new(M(80), 0, -W / 2 - M(100))
local R1, R2, N = M(38), M(50), 72
for i = 0, N - 1 do
	local a = i / N * math.pi * 2
	local r = (R1 + R2) / 2
	local seg = 2 * math.pi * r / N
	part("Ring", Vector3.new(R2 - R1, 0.4, seg * 1.08), CFrame.new(ringC + Vector3.new(math.cos(a) * r, 0.2, math.sin(a) * r)) * CFrame.Angles(0, -a, 0), asph, Enum.Material.Asphalt)
end
part("Connector", Vector3.new(M(80) - R2 + M(5), 0.4, M(8)), CFrame.new((M(80) - R2) / 2, 0.21, ringC.Z), asph, Enum.Material.Asphalt)

-- Swedish houses: panel with white corners, windows, gable roof
local rnd = Random.new(7)
local function house(pos, rot, col, w, d)
	local h = Instance.new("Model"); h.Name = "House"; h.Parent = world
	local cf = CFrame.new(pos) * CFrame.Angles(0, rot, 0)
	local Hh = M(2.8)
	local function p(n, size, off, c, mat) return part(n, size, cf * off, c, mat, h) end
	p("Walls", Vector3.new(M(w), Hh, M(d)), CFrame.new(0, Hh / 2, 0), col, Enum.Material.WoodPlanks)
	p("Plinth", Vector3.new(M(w) + 0.4, 1, M(d) + 0.4), CFrame.new(0, 0.5, 0), Color3.fromRGB(85, 88, 92), Enum.Material.Concrete)
	for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do p("Corner", Vector3.new(0.6, Hh, 0.6), CFrame.new(sx * M(w) / 2, Hh / 2, sz * M(d) / 2), Color3.fromRGB(242, 240, 234), Enum.Material.WoodPlanks) end end
	local rh = M(1.7)
	for _, s in ipairs({ -1, 1 }) do
		local wd = wedge("Roof", Vector3.new(M(w) + 1.6, rh, M(d) / 2 + 0.8), cf * CFrame.new(0, Hh + rh / 2, s * (M(d) / 4 + 0.4)) * CFrame.Angles(0, s > 0 and math.pi or 0, 0), Color3.fromRGB(46, 47, 51), Enum.Material.Slate, h)
	end
	for i = 0, math.floor(w / 2.6) - 1 do
		local x = -M(w) / 2 + M(1.5) + i * M(2.6)
		for _, s in ipairs({ -1, 1 }) do
			p("WinFrame", Vector3.new(M(1), M(1.1), 0.3), CFrame.new(x, M(1.55), s * (M(d) / 2 + 0.1)), Color3.fromRGB(242, 240, 234), Enum.Material.WoodPlanks)
			local g = p("Glass", Vector3.new(M(0.82), M(0.92), 0.35), CFrame.new(x, M(1.55), s * (M(d) / 2 + 0.12)), Color3.fromRGB(40, 55, 70), Enum.Material.Glass)
			g.Reflectance = 0.3
		end
	end
	p("Door", Vector3.new(M(1), M(2), 0.3), CFrame.new(M(w) / 2 - M(1.4), M(1), M(d) / 2 + 0.12), Color3.fromRGB(59, 42, 30), Enum.Material.Wood)
end
local function spruce(pos, hgt)
	part("Trunk", Vector3.new(M(1.4), M(0.4), M(0.4)), CFrame.new(pos + Vector3.new(0, M(0.7), 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(74, 51, 34), Enum.Material.Wood, world, "cyl")
	local col = Color3.fromRGB(28 + rnd:NextInteger(0, 10), 66 + rnd:NextInteger(0, 14), 38)
	for i = 0, 3 do
		local r = M(3.6 - i * 0.8)
		part("Needles", Vector3.new(M(hgt * 0.22), r, r), CFrame.new(pos + Vector3.new(0, M(1.4 + i * hgt * 0.2), 0)) * CFrame.Angles(0, 0, math.pi / 2), col, Enum.Material.Grass, world, "cyl")
	end
end
local function birch(pos, hgt)
	part("Trunk", Vector3.new(M(hgt * 0.65), M(0.25), M(0.25)), CFrame.new(pos + Vector3.new(0, M(hgt * 0.32), 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(232, 228, 218), Enum.Material.SmoothPlastic, world, "cyl")
	for i = 0, 2 do
		local s = M(2.2 + rnd:NextNumber() * 1)
		part("Leaves", Vector3.new(s, s, s), CFrame.new(pos + Vector3.new((rnd:NextNumber() - 0.5) * M(1.2), M(hgt * 0.6 + i * 0.7), (rnd:NextNumber() - 0.5) * M(1.2))), Color3.fromRGB(95, 143, 58), Enum.Material.LeafyGrass, world, "ball")
	end
end
local function blocked(p)
	if math.abs(p.X) < M(14) and p.Z > -W / 2 - M(190) and p.Z < W then return true end -- garage + strip
	local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(ringC.X, 0, ringC.Z)).Magnitude
	if d > M(30) and d < M(58) then return true end
	if p.X > 0 and p.X < M(85) and math.abs(p.Z - ringC.Z) < M(10) then return true end
	return false
end
local colors = { Color3.fromRGB(138, 43, 31), Color3.fromRGB(214, 176, 74), Color3.fromRGB(234, 229, 216), Color3.fromRGB(138, 43, 31) }
local n = 0
for _ = 1, 400 do
	if n >= 14 then break end
	local p = Vector3.new(rnd:NextNumber(-M(190), M(190)), 0, rnd:NextNumber(-M(320), M(80)))
	if not blocked(p) then n = n + 1; house(p, rnd:NextInteger(0, 3) * math.pi / 2, colors[n % 4 + 1], 8, 6) end
end
n = 0
for _ = 1, 800 do
	if n >= 90 then break end
	local p = Vector3.new(rnd:NextNumber(-M(200), M(200)), 0, rnd:NextNumber(-M(330), M(90)))
	if not blocked(p) then
		n = n + 1
		if rnd:NextNumber() < 0.7 then spruce(p, 5 + rnd:NextNumber() * 4) else birch(p, 5 + rnd:NextNumber() * 3) end
	end
end
-- lake
part("Lake", Vector3.new(0.2, M(60), M(60)), CFrame.new(-M(110), 0.05, -M(200)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(36, 80, 110), Enum.Material.Glass, world, "cyl").Reflectance = 0.4

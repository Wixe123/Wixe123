-- Builds the world when the server starts: Roblox Terrain (grass, hills, lake), a large garage,
-- road with curbs and streetlights, drag strip, ring track, Swedish houses, trees, light.
local Lighting = game:GetService("Lighting")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local S = 1 / Config.STUD
local function M(x) return x * S end -- metres -> studs

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
local function deco(p) p.CanCollide = false; p.CastShadow = true; return p end

-- ---------- light: Swedish summer afternoon ----------
Lighting.ClockTime = 15
Lighting.GeographicLatitude = 59
Lighting.Brightness = 2.4
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.OutdoorAmbient = Color3.fromRGB(118, 124, 134)
Lighting.Ambient = Color3.fromRGB(38, 40, 46)
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.25
local atm = Instance.new("Atmosphere")
atm.Density, atm.Offset, atm.Color, atm.Decay, atm.Glare, atm.Haze = 0.3, 0.12, Color3.fromRGB(199, 214, 230), Color3.fromRGB(106, 126, 148), 0.25, 1.4
atm.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect"); cc.Saturation, cc.Contrast, cc.TintColor = 0.06, 0.06, Color3.fromRGB(255, 252, 246); cc.Parent = Lighting
local bloom = Instance.new("BloomEffect"); bloom.Intensity, bloom.Size, bloom.Threshold = 0.35, 24, 1.3; bloom.Parent = Lighting
local rays = Instance.new("SunRaysEffect"); rays.Intensity, rays.Spread = 0.04, 0.6; rays.Parent = Lighting
local dof = Instance.new("DepthOfFieldEffect"); dof.FarIntensity, dof.FocusDistance, dof.InFocusRadius, dof.NearIntensity = 0.12, 60, 120, 0; dof.Parent = Lighting

-- ---------- terrain: grass, hills, lake with a sandy shore ----------
local base = workspace:FindFirstChild("Baseplate")
if base then base:Destroy() end
local T = workspace.Terrain
T.WaterColor = Color3.fromRGB(40, 78, 96)
T.WaterReflectance = 0.6
T.WaterTransparency = 0.4
T.WaterWaveSize = 0.08
T.WaterWaveSpeed = 6
T:FillBlock(CFrame.new(0, -8, M(-120)), Vector3.new(M(460), 16, M(460)), Enum.Material.Grass)
local hr = Random.new(3)
for i = 0, 27 do -- hills around the edges so the world does not end in a sharp edge
	local a = i / 28 * math.pi * 2
	local c = Vector3.new(math.cos(a) * M(215), -M(4), M(-120) + math.sin(a) * M(215))
	T:FillBall(c, M(28 + hr:NextNumber() * 18), hr:NextNumber() < 0.25 and Enum.Material.Rock or Enum.Material.Grass)
end
local lakeC = Vector3.new(-M(110), 0, -M(200))
T:FillCylinder(CFrame.new(lakeC + Vector3.new(0, -2, 0)), 4, M(34), Enum.Material.Sand)
T:FillCylinder(CFrame.new(lakeC + Vector3.new(0, -4, 0)), 8, M(30), Enum.Material.Water)

-- ---------- garage: 24 x 16 m, 5 m high, door towards -Z ----------
local G = Instance.new("Folder"); G.Name = "Garage"; G.Parent = world
local GW, GD, GH = M(24), M(16), M(5)
local brick, brickC = Enum.Material.Brick, Color3.fromRGB(139, 66, 50)
local steel = Color3.fromRGB(92, 98, 106)
part("Floor", Vector3.new(GW + 2, 1.2, GD + 2), CFrame.new(0, 0, 0), Color3.fromRGB(128, 131, 134), Enum.Material.Concrete, G)
local floorTop = 0.6
local function gp(name, size, x, y, z, color, mat, shape, rot) return part(name, size, CFrame.new(x, floorTop + y, z) * (rot or CFrame.new()), color, mat, G, shape) end
-- walls: back, sides with windows, front with door opening
gp("WallBack", Vector3.new(GW + 2, GH, 1), 0, GH / 2, GD / 2 + 0.5, brickC, brick)
for _, s in ipairs({ -1, 1 }) do
	local x = s * (GW / 2 + 0.5)
	gp("WallSideLow", Vector3.new(1, M(1.4), GD), x, M(0.7), 0, brickC, brick)
	gp("WallSideHigh", Vector3.new(1, GH - M(3), GD), x, M(3) + (GH - M(3)) / 2, 0, brickC, brick)
	for i = -1, 1 do
		local z = i * M(5)
		gp("WinPost", Vector3.new(1, M(1.6), M(0.3)), x, M(2.2), z - M(1.6), Color3.fromRGB(240, 240, 236), Enum.Material.WoodPlanks)
		gp("WinPost", Vector3.new(1, M(1.6), M(0.3)), x, M(2.2), z + M(1.6), Color3.fromRGB(240, 240, 236), Enum.Material.WoodPlanks)
		local gl = gp("Window", Vector3.new(0.4, M(1.6), M(3)), x, M(2.2), z, Color3.fromRGB(170, 200, 220), Enum.Material.Glass); gl.Transparency = 0.6
	end
	-- brick between the windows (windows at z = -5, 0, 5 m, 3.2 m wide incl. posts)
	for _, seg in ipairs({ { -8, -6.6 }, { -3.4, -1.6 }, { 1.6, 3.4 }, { 6.6, 8 } }) do
		gp("WallBetween", Vector3.new(1, M(1.6), M(seg[2] - seg[1])), x, M(2.2), M((seg[1] + seg[2]) / 2), brickC, brick)
	end
end
local door = M(6)
gp("WallFrontL", Vector3.new((GW + 2 - door) / 2, GH, 1), -(GW + 2 + door) / 4, GH / 2, -GD / 2 - 0.5, brickC, brick)
gp("WallFrontR", Vector3.new((GW + 2 - door) / 2, GH, 1), (GW + 2 + door) / 4, GH / 2, -GD / 2 - 0.5, brickC, brick)
gp("DoorTop", Vector3.new(door, M(1.2), 1), 0, GH - M(0.6), -GD / 2 - 0.5, brickC, brick)
gp("RollerDoor", Vector3.new(door, M(0.6), M(0.6)), 0, GH - M(0.9), -GD / 2 + M(0.2), Color3.fromRGB(190, 195, 200), Enum.Material.Metal, "cyl", CFrame.Angles(0, 0, 0))
-- roof and steel beams
gp("Roof", Vector3.new(GW + 3, 1, GD + 3), 0, GH + 0.5, 0, Color3.fromRGB(64, 66, 70), Enum.Material.CorrodedMetal)
for i = -2, 2 do gp("Beam", Vector3.new(GW, M(0.35), M(0.18)), 0, GH - M(0.2), i * M(3.2), steel, Enum.Material.Metal) end
-- sign above the door
local sign = gp("Sign", Vector3.new(M(5), M(0.8), 0.4), 0, GH + M(0.2), -GD / 2 - 1.2, Color3.fromRGB(25, 27, 30), Enum.Material.SmoothPlastic)
local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.CanvasSize = Vector2.new(500, 80); sg.LightInfluence = 0; sg.Parent = sign
local st = Instance.new("TextLabel"); st.Size = UDim2.fromScale(1, 1); st.BackgroundTransparency = 1; st.Text = "MOPPE GARAGE"; st.TextScaled = true; st.Font = Enum.Font.GothamBlack; st.TextColor3 = Color3.fromRGB(255, 176, 32); st.Parent = sg
-- hanging industrial lamps
for _, x in ipairs({ -M(7), 0, M(7) }) do
	for _, z in ipairs({ -M(3.5), M(3.5) }) do
		deco(gp("LampWire", Vector3.new(M(1), 0.15, 0.15), x, GH - M(0.5), z, Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, "cyl", CFrame.Angles(0, 0, math.pi / 2)))
		deco(gp("LampShade", Vector3.new(M(0.35), M(0.7), M(0.7)), x, GH - M(1.1), z, Color3.fromRGB(46, 70, 60), Enum.Material.Metal, "cyl", CFrame.Angles(0, 0, math.pi / 2)))
		local bulb = deco(gp("LampBulb", Vector3.new(M(0.5), 0.3, M(0.5)), x, GH - M(1.3), z, Color3.fromRGB(255, 244, 220), Enum.Material.Neon))
		local l = Instance.new("SpotLight"); l.Face = Enum.NormalId.Bottom; l.Angle = 120; l.Range = 40; l.Brightness = 1.6; l.Color = Color3.fromRGB(255, 240, 215); l.Shadows = true; l.Parent = bulb
	end
end
-- floor markings
for _, x in ipairs({ -M(2.4), M(2.4) }) do gp("Line", Vector3.new(0.3, 0.05, M(9)), x, 0.03, -M(2), Color3.fromRGB(216, 180, 30), Enum.Material.SmoothPlastic) end
-- workbench with pegboard, vise and tools along the back wall
local wood, red = Color3.fromRGB(138, 96, 58), Color3.fromRGB(176, 32, 28)
local bz = GD / 2 - M(0.5)
gp("Bench", Vector3.new(M(4), M(0.08), M(0.9)), -M(6), M(0.95), bz, wood, Enum.Material.Wood)
for _, x in ipairs({ -M(7.9), -M(4.1) }) do gp("BenchLeg", Vector3.new(M(0.08), M(0.95), M(0.8)), x, M(0.47), bz, steel, Enum.Material.Metal) end
gp("BenchShelf", Vector3.new(M(4), M(0.04), M(0.8)), -M(6), M(0.3), bz, steel, Enum.Material.Metal)
gp("Pegboard", Vector3.new(M(4), M(1.4), 0.3), -M(6), M(1.85), GD / 2 - 0.2, Color3.fromRGB(150, 132, 98), Enum.Material.WoodPlanks)
local tr = Random.new(5)
for i = 0, 11 do
	local t = gp("Tool", Vector3.new(M(0.05), M(0.22 + tr:NextNumber() * 0.25), 0.3), -M(7.7) + i * M(0.31), M(1.85) + (tr:NextNumber() - 0.5) * M(0.7), GD / 2 - 0.5, i % 3 == 0 and red or Color3.fromRGB(70, 74, 80), Enum.Material.Metal)
	t.CFrame = t.CFrame * CFrame.Angles(0, 0, (tr:NextNumber() - 0.5) * 0.7)
end
gp("Vise", Vector3.new(M(0.25), M(0.2), M(0.3)), -M(4.5), M(1.09), bz - M(0.2), Color3.fromRGB(40, 70, 130), Enum.Material.Metal)
-- tool chest
gp("ToolChest", Vector3.new(M(1.1), M(1), M(0.55)), -M(2.6), M(0.5), bz, red, Enum.Material.Metal)
for i = 0, 4 do gp("Drawer", Vector3.new(M(1), M(0.015), 0.2), -M(2.6), M(0.15) + i * M(0.18), bz - M(0.28), Color3.fromRGB(200, 200, 200), Enum.Material.Metal) end
-- shelving with boxes
for _, x in ipairs({ M(3.2), M(6.8) }) do for _, z in ipairs({ bz - M(0.25), bz + M(0.25) }) do gp("Upright", Vector3.new(M(0.06), M(2.6), M(0.06)), x, M(1.3), z, Color3.fromRGB(40, 90, 160), Enum.Material.Metal) end end
for j = 0, 3 do
	gp("Shelf", Vector3.new(M(3.7), M(0.04), M(0.6)), M(5), M(0.3) + j * M(0.75), bz, Color3.fromRGB(200, 120, 30), Enum.Material.Metal)
	for k = 0, 3 do
		if tr:NextNumber() < 0.75 then
			local w = M(0.5 + tr:NextNumber() * 0.3)
			gp("Box", Vector3.new(w, M(0.3 + tr:NextNumber() * 0.25), M(0.45)), M(3.6) + k * M(0.9), M(0.32) + j * M(0.75) + M(0.2), bz, Color3.fromRGB(176, 136, 90), Enum.Material.Fabric)
		end
	end
end
-- tyre stacks, compressor, oil drums
for s = 0, 1 do for i = 0, 4 do gp("Tyre", Vector3.new(M(0.2), M(0.65), M(0.65)), GW / 2 - M(0.8) - s * M(0.8), M(0.1) + i * M(0.2), GD / 2 - M(1.8), Color3.fromRGB(24, 24, 26), Enum.Material.SmoothPlastic, "cyl", CFrame.Angles(0, 0, math.pi / 2)) end end
gp("Compressor", Vector3.new(M(1.1), M(0.45), M(0.45)), GW / 2 - M(1), M(0.35), GD / 2 - M(3.6), red, Enum.Material.Metal, "cyl")
gp("CompMotor", Vector3.new(M(0.4), M(0.3), M(0.3)), GW / 2 - M(1), M(0.75), GD / 2 - M(3.6), Color3.fromRGB(40, 42, 46), Enum.Material.Metal)
for i, c in ipairs({ Color3.fromRGB(31, 95, 158), Color3.fromRGB(150, 30, 30) }) do gp("Drum", Vector3.new(M(0.9), M(0.6), M(0.6)), GW / 2 - M(0.6), M(0.45), -GD / 2 + M(1) + i * M(0.75), c, Enum.Material.Metal, "cyl", CFrame.Angles(0, 0, math.pi / 2)) end
-- moped lift (to the right of the moped spot)
gp("LiftTop", Vector3.new(M(0.9), M(0.12), M(2.4)), M(5), M(0.55), -M(2), Color3.fromRGB(150, 155, 160), Enum.Material.DiamondPlate)
gp("LiftBase", Vector3.new(M(0.5), M(0.5), M(1.6)), M(5), M(0.25), -M(2), Color3.fromRGB(200, 40, 30), Enum.Material.Metal)
local ramp = wedge("LiftRamp", Vector3.new(M(0.9), M(0.6), M(0.9)), CFrame.new(M(5), floorTop + M(0.3), -M(2) - M(1.65)) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(150, 155, 160), Enum.Material.DiamondPlate, G)
-- office corner: desk, screen, chair, sofa, posters, clock, fire extinguisher
local ox, oz = -GW / 2 + M(2.2), -GD / 2 + M(2.5)
gp("Desk", Vector3.new(M(1.6), M(0.06), M(0.8)), ox, M(0.75), oz, wood, Enum.Material.Wood)
for _, dx in ipairs({ -M(0.75), M(0.75) }) do gp("DeskLeg", Vector3.new(M(0.05), M(0.75), M(0.7)), ox + dx, M(0.37), oz, steel, Enum.Material.Metal) end
local screen = gp("Screen", Vector3.new(M(0.6), M(0.4), M(0.04)), ox, M(1.05), oz + M(0.2), Color3.fromRGB(60, 120, 170), Enum.Material.Neon); screen.Transparency = 0.2
gp("Chair", Vector3.new(M(0.5), M(0.08), M(0.5)), ox, M(0.48), oz - M(0.55), Color3.fromRGB(30, 30, 32), Enum.Material.Fabric)
gp("ChairBack", Vector3.new(M(0.5), M(0.5), M(0.06)), ox, M(0.75), oz - M(0.8), Color3.fromRGB(30, 30, 32), Enum.Material.Fabric)
gp("Sofa", Vector3.new(M(0.8), M(0.45), M(2)), -GW / 2 + M(0.6), M(0.22), oz + M(2.5), Color3.fromRGB(90, 60, 40), Enum.Material.Fabric)
gp("SofaBack", Vector3.new(M(0.25), M(0.5), M(2)), -GW / 2 + M(0.2), M(0.65), oz + M(2.5), Color3.fromRGB(90, 60, 40), Enum.Material.Fabric)
for i, c in ipairs({ Color3.fromRGB(200, 60, 40), Color3.fromRGB(40, 110, 180), Color3.fromRGB(230, 180, 40) }) do
	gp("Poster", Vector3.new(0.2, M(0.9), M(0.65)), -GW / 2 + 0.2, M(2.1), -GD / 2 + M(4) + i * M(1.1), c, Enum.Material.SmoothPlastic)
end
gp("Clock", Vector3.new(0.2, M(0.4), M(0.4)), 0, GH - M(1.6), GD / 2 + 0.05, Color3.fromRGB(240, 240, 236), Enum.Material.SmoothPlastic, "cyl", CFrame.Angles(0, math.pi / 2, 0))
gp("Extinguisher", Vector3.new(M(0.5), M(0.16), M(0.16)), -GW / 2 + M(0.3), M(0.6), -GD / 2 + M(0.8), Color3.fromRGB(200, 20, 20), Enum.Material.Metal, "cyl", CFrame.Angles(0, 0, math.pi / 2))
-- spawn points
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Name = "Spawn"; spawnPad.Size = Vector3.new(6, 0.4, 6); spawnPad.CFrame = CFrame.new(-M(3), floorTop + 0.25, M(1)); spawnPad.Anchored = true
spawnPad.Transparency = 1; spawnPad.CanCollide = false; spawnPad.Neutral = true; spawnPad.Parent = G
local mopedPad = part("MopedSpot", Vector3.new(1, 0.1, 1), CFrame.new(0, floorTop + 0.1, -M(2)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, G)
mopedPad.Transparency = 1; mopedPad.CanCollide = false

-- ---------- roads: driveway, drag strip with curbs, pavement and streetlights, ring track ----------
local asph, lineC, curbC = Color3.fromRGB(56, 59, 64), Color3.fromRGB(232, 232, 226), Color3.fromRGB(165, 165, 160)
local function road(name, size, cf) return part(name, size, cf, asph, Enum.Material.Asphalt) end
local yRoad = 0.2
road("Driveway", Vector3.new(M(7), 0.6, M(14)), CFrame.new(0, yRoad, -GD / 2 - M(7)))
local stripZ0, stripL = -GD / 2 - M(14), M(170)
local stripC = stripZ0 - stripL / 2
road("Strip", Vector3.new(M(10), 0.6, stripL), CFrame.new(0, yRoad, stripC))
for _, s in ipairs({ -1, 1 }) do
	part("EdgeLine", Vector3.new(0.4, 0.05, stripL), CFrame.new(s * M(4.6), yRoad + 0.32, stripC), lineC, Enum.Material.SmoothPlastic)
	part("Curb", Vector3.new(M(0.25), M(0.15), stripL), CFrame.new(s * M(5.1), yRoad + M(0.05), stripC), curbC, Enum.Material.Concrete)
end
part("Pavement", Vector3.new(M(2.5), 0.8, stripL), CFrame.new(M(6.5), yRoad + 0.1, stripC), Color3.fromRGB(150, 150, 146), Enum.Material.Pavement)
for i = 0, 20 do part("Dash", Vector3.new(0.35, 0.05, M(3)), CFrame.new(0, yRoad + 0.32, stripZ0 - M(4) - i * M(8)), lineC, Enum.Material.SmoothPlastic) end
part("StartLine", Vector3.new(M(10), 0.06, 0.6), CFrame.new(0, yRoad + 0.33, stripZ0 - M(6)), lineC, Enum.Material.SmoothPlastic)
-- streetlights along the pavement
for i = 0, 6 do
	local z = stripZ0 - M(10) - i * M(25)
	local px = M(7.4)
	part("Pole", Vector3.new(M(6), M(0.16), M(0.16)), CFrame.new(px, M(3), z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(90, 94, 100), Enum.Material.Metal, world, "cyl")
	part("Arm", Vector3.new(M(1.6), M(0.1), M(0.1)), CFrame.new(px - M(0.8), M(5.95), z), Color3.fromRGB(90, 94, 100), Enum.Material.Metal)
	local lamp = part("StreetLamp", Vector3.new(M(0.6), M(0.12), M(0.3)), CFrame.new(px - M(1.5), M(5.88), z), Color3.fromRGB(255, 236, 200), Enum.Material.Neon)
	local l = Instance.new("SpotLight"); l.Face = Enum.NormalId.Bottom; l.Angle = 110; l.Range = 50; l.Brightness = 1.2; l.Color = Color3.fromRGB(255, 228, 180); l.Parent = lamp
end
-- ring track with red and white kerbs
local ringC = Vector3.new(M(80), 0, stripC)
local R1, R2, N = M(38), M(50), 72
for i = 0, N - 1 do
	local a = i / N * math.pi * 2
	local r = (R1 + R2) / 2
	local seg = 2 * math.pi * r / N
	road("Ring", Vector3.new(R2 - R1, 0.6, seg * 1.08), CFrame.new(ringC + Vector3.new(math.cos(a) * r, yRoad, math.sin(a) * r)) * CFrame.Angles(0, -a, 0))
	for _, rr in ipairs({ R1 - M(0.4), R2 + M(0.4) }) do
		part("Kerb", Vector3.new(M(0.8), 0.7, 2 * math.pi * rr / N * 1.02), CFrame.new(ringC + Vector3.new(math.cos(a) * rr, yRoad, math.sin(a) * rr)) * CFrame.Angles(0, -a, 0),
			i % 2 == 0 and Color3.fromRGB(200, 30, 30) or Color3.fromRGB(240, 240, 236), Enum.Material.SmoothPlastic)
	end
end
road("Connector", Vector3.new(M(80) - R2 + M(5), 0.6, M(8)), CFrame.new((M(80) - R2) / 2 + M(2), yRoad + 0.01, ringC.Z))

-- ---------- Swedish houses: panel with white corners, windows, gable roof, chimney, fence, mailbox ----------
local rnd = Random.new(7)
local white = Color3.fromRGB(242, 240, 234)
local function house(pos, rot, col, w, d)
	local h = Instance.new("Model"); h.Name = "House"; h.Parent = world
	local cf = CFrame.new(pos) * CFrame.Angles(0, rot, 0)
	local Hh = M(2.8)
	local function p(n, size, off, c, mat, shape) return part(n, size, cf * off, c, mat, h, shape) end
	p("Plinth", Vector3.new(M(w) + 0.4, 2, M(d) + 0.4), CFrame.new(0, 0.6, 0), Color3.fromRGB(85, 88, 92), Enum.Material.Concrete)
	p("Walls", Vector3.new(M(w), Hh, M(d)), CFrame.new(0, 1.6 + Hh / 2, 0), col, Enum.Material.WoodPlanks)
	for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do p("Corner", Vector3.new(0.6, Hh, 0.6), CFrame.new(sx * M(w) / 2, 1.6 + Hh / 2, sz * M(d) / 2), white, Enum.Material.WoodPlanks) end end
	local rh = M(1.8)
	for _, s in ipairs({ -1, 1 }) do
		wedge("Roof", Vector3.new(M(w) + 1.6, rh, M(d) / 2 + 0.8), cf * CFrame.new(0, 1.6 + Hh + rh / 2, s * (M(d) / 4 + 0.4)) * CFrame.Angles(0, s > 0 and math.pi or 0, 0), Color3.fromRGB(46, 47, 51), Enum.Material.Slate, h)
	end
	p("Chimney", Vector3.new(M(0.6), M(1.6), M(0.6)), CFrame.new(M(w) * 0.25, 1.6 + Hh + M(1.3), M(d) * 0.15), Color3.fromRGB(120, 60, 45), Enum.Material.Brick)
	for i = 0, math.floor(w / 2.6) - 1 do
		local x = -M(w) / 2 + M(1.5) + i * M(2.6)
		for _, s in ipairs({ -1, 1 }) do
			p("WinFrame", Vector3.new(M(1), M(1.15), 0.3), CFrame.new(x, 1.6 + M(1.55), s * (M(d) / 2 + 0.1)), white, Enum.Material.WoodPlanks)
			local g = p("Glass", Vector3.new(M(0.82), M(0.95), 0.35), CFrame.new(x, 1.6 + M(1.55), s * (M(d) / 2 + 0.12)), Color3.fromRGB(40, 55, 70), Enum.Material.Glass)
			g.Reflectance = 0.35
			p("Mullion", Vector3.new(M(0.06), M(0.95), 0.4), CFrame.new(x, 1.6 + M(1.55), s * (M(d) / 2 + 0.14)), white, Enum.Material.WoodPlanks)
		end
	end
	p("Door", Vector3.new(M(1), M(2), 0.3), CFrame.new(M(w) / 2 - M(1.4), 1.6 + M(1), M(d) / 2 + 0.12), Color3.fromRGB(59, 42, 30), Enum.Material.Wood)
	p("Steps", Vector3.new(M(1.4), 1.6, M(0.8)), CFrame.new(M(w) / 2 - M(1.4), 0.8, M(d) / 2 + M(0.45)), Color3.fromRGB(120, 122, 124), Enum.Material.Concrete)
	-- picket fence in front and a mailbox
	local fz = M(d) / 2 + M(4)
	for i = -10, 10 do p("Picket", Vector3.new(M(0.08), M(0.9), M(0.03)), CFrame.new(i * M(0.5), M(0.45), fz), white, Enum.Material.WoodPlanks) end
	p("Rail", Vector3.new(M(10.5), M(0.07), M(0.03)), CFrame.new(0, M(0.65), fz - M(0.03)), white, Enum.Material.WoodPlanks)
	p("MailPost", Vector3.new(M(0.08), M(1), M(0.08)), CFrame.new(M(6), M(0.5), fz + M(0.5)), Color3.fromRGB(70, 70, 70), Enum.Material.Metal)
	p("Mailbox", Vector3.new(M(0.35), M(0.3), M(0.45)), CFrame.new(M(6), M(1.1), fz + M(0.5)), Color3.fromRGB(40, 90, 170), Enum.Material.Metal)
end
local function spruce(pos, hgt)
	part("Trunk", Vector3.new(M(1.6), M(0.4), M(0.4)), CFrame.new(pos + Vector3.new(0, M(0.8), 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(74, 51, 34), Enum.Material.Wood, world, "cyl")
	local col = Color3.fromRGB(26 + rnd:NextInteger(0, 10), 60 + rnd:NextInteger(0, 16), 34)
	local tiers = 6
	for i = 0, tiers - 1 do
		local f = i / (tiers - 1)
		local r = M(4.2 - 3.3 * f)
		part("Needles", Vector3.new(M(hgt * 0.16), r, r), CFrame.new(pos + Vector3.new(0, M(1.3 + f * hgt * 0.78), 0)) * CFrame.Angles(0, rnd:NextNumber() * 3, math.pi / 2), col, Enum.Material.Grass, world, "cyl")
	end
	part("Top", Vector3.new(M(0.5), M(0.5), M(0.5)), CFrame.new(pos + Vector3.new(0, M(1.3 + hgt * 0.92), 0)), col, Enum.Material.Grass, world, "ball")
end
local function birch(pos, hgt)
	part("Trunk", Vector3.new(M(hgt * 0.7), M(0.25), M(0.25)), CFrame.new(pos + Vector3.new(0, M(hgt * 0.35), 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(232, 228, 218), Enum.Material.SmoothPlastic, world, "cyl")
	for i = 0, 4 do
		local s = M(1.8 + rnd:NextNumber() * 1.2)
		part("Leaves", Vector3.new(s, s * 0.9, s), CFrame.new(pos + Vector3.new((rnd:NextNumber() - 0.5) * M(1.8), M(hgt * 0.6 + i * 0.55), (rnd:NextNumber() - 0.5) * M(1.8))), Color3.fromRGB(88 + rnd:NextInteger(0, 20), 140 + rnd:NextInteger(0, 20), 56), Enum.Material.LeafyGrass, world, "ball")
	end
end
local function blocked(p)
	if math.abs(p.X) < M(18) and p.Z > stripZ0 - stripL - M(10) and p.Z < GD then return true end -- garage + strip
	local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(ringC.X, 0, ringC.Z)).Magnitude
	if d > M(30) and d < M(60) then return true end
	if p.X > 0 and p.X < M(85) and math.abs(p.Z - ringC.Z) < M(10) then return true end
	if (Vector3.new(p.X, 0, p.Z) - lakeC).Magnitude < M(40) then return true end
	if (Vector3.new(p.X, 0, p.Z) - Vector3.new(0, 0, M(-120))).Magnitude > M(195) then return true end -- not in the hills
	return false
end
local colors = { Color3.fromRGB(138, 43, 31), Color3.fromRGB(214, 176, 74), Color3.fromRGB(234, 229, 216), Color3.fromRGB(138, 43, 31) }
local n = 0
for _ = 1, 600 do
	if n >= 16 then break end
	local p = Vector3.new(rnd:NextNumber(-M(190), M(190)), 0, rnd:NextNumber(-M(320), M(80)))
	if not blocked(p) and not blocked(p + Vector3.new(0, 0, M(8))) then n = n + 1; house(p, rnd:NextInteger(0, 3) * math.pi / 2, colors[n % 4 + 1], 8, 6) end
end
n = 0
for _ = 1, 1200 do
	if n >= 120 then break end
	local p = Vector3.new(rnd:NextNumber(-M(200), M(200)), 0, rnd:NextNumber(-M(330), M(90)))
	if not blocked(p) then
		n = n + 1
		if rnd:NextNumber() < 0.65 then spruce(p, 6 + rnd:NextNumber() * 6) else birch(p, 5 + rnd:NextNumber() * 4) end
	end
end

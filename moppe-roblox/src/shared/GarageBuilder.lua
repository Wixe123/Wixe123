-- A garage (template). Built once per player plot. Returns references to all work stations.
-- Garage space in metres: x -12..12, z -8..8, door at z = -8 (forward = -Z in Roblox).
local Config = require(script.Parent.Config)
local S = 1 / Config.STUD
local GarageBuilder = {}

-- the work stations' points (used by both the server and the client so they always agree)
function GarageBuilder.anchors(origin)
	local function at(x, y, z) return origin * CFrame.new(x * S, y * S, -z * S) end
	return {
		origin = origin,
		moped = at(0, 0, -2),
		stand = at(-2.2, 1.15, 4.6) * CFrame.Angles(0, math.rad(90), 0),
		booth = at(8.8, 1.25, 5),
		portbench = at(2.2, 1.2, 7.15),
		delivery = at(4.5, 0.3, -10),
		computer = at(-10.2, 1.08, -5.3),
		spawn = at(-3, 1, 0),
	}
end
function GarageBuilder.plotOrigin(i) local pl = Config.PLOTS[i]; return CFrame.new(pl.x * S, 0, -pl.z * S) end

function GarageBuilder.build(parent, origin, plotIdx)
	local G = Instance.new("Model"); G.Name = "Garage" .. plotIdx; G.Parent = parent
	local function M(x) return x * S end
	local function at(x, y, z) return origin * CFrame.new(M(x), M(y), -M(z)) end
	local function part(name, size, cf, color, material, shape)
		local p = Instance.new("Part"); p.Name = name
		if shape == "cyl" then p.Shape = Enum.PartType.Cylinder elseif shape == "ball" then p.Shape = Enum.PartType.Ball end
		p.Size, p.CFrame, p.Color, p.Material, p.Anchored = size, cf, color, material or Enum.Material.SmoothPlastic, true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = G
		return p
	end
	local function box(name, w, h, d, x, y, z, color, mat) return part(name, Vector3.new(M(w), M(h), M(d)), at(x, y, z), color, mat) end
	local function interact(p, kind, hint) p:SetAttribute("Interact", kind); p:SetAttribute("Plot", plotIdx); if hint then p:SetAttribute("Hint", hint) end; return p end
	local brick, brickC, steel = Enum.Material.Brick, Color3.fromRGB(139, 66, 50), Color3.fromRGB(92, 98, 106)
	local white, wood, red = Color3.fromRGB(240, 240, 236), Color3.fromRGB(138, 96, 58), Color3.fromRGB(176, 32, 28)
	local W, D, H = 24, 16, 5
	-- floor, walls, roof
	local floor = box("Floor", W + 0.6, 0.3, D + 0.6, 0, -0.15, 0, Color3.fromRGB(128, 131, 134), Enum.Material.Concrete)
	interact(floor, "floor", "Lägg på golvet")
	box("WallBack", W + 0.6, H, 0.3, 0, H / 2, D / 2 + 0.15, brickC, brick)
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * (W / 2 + 0.15)
		box("WallLow", 0.3, 1.4, D, x, 0.7, 0, brickC, brick)
		box("WallHigh", 0.3, 2, D, x, 4, 0, brickC, brick)
		for _, seg in ipairs({ { -8, -6.6 }, { -3.4, -1.6 }, { 1.6, 3.4 }, { 6.6, 8 } }) do box("WallMid", 0.3, 1.6, seg[2] - seg[1], x, 2.2, (seg[1] + seg[2]) / 2, brickC, brick) end
		for _, z in ipairs({ -5, 0, 5 }) do
			local g = box("Window", 0.12, 1.6, 3.2, x, 2.2, z, Color3.fromRGB(170, 200, 220), Enum.Material.Glass); g.Transparency = 0.6
		end
	end
	box("WallFrontL", (W + 0.6 - 6) / 2, H, 0.3, -(W + 6.6) / 4, H / 2, -D / 2 - 0.15, brickC, brick)
	box("WallFrontR", (W + 0.6 - 6) / 2, H, 0.3, (W + 6.6) / 4, H / 2, -D / 2 - 0.15, brickC, brick)
	box("DoorTop", 6, 1.2, 0.3, 0, H - 0.6, -D / 2 - 0.15, brickC, brick)
	part("RollerDoor", Vector3.new(M(6), M(0.6), M(0.6)), at(0, H - 0.9, -D / 2 + 0.3), Color3.fromRGB(190, 195, 200), Enum.Material.Metal, "cyl")
	box("Roof", W + 1, 0.3, D + 1, 0, H + 0.15, 0, Color3.fromRGB(64, 66, 70), Enum.Material.CorrodedMetal)
	for i = -2, 2 do box("Beam", W, 0.35, 0.18, 0, H - 0.2, i * 3.2, steel, Enum.Material.Metal) end
	-- sign with the owner's name
	local sign = box("Sign", 6, 0.8, 0.15, 0, H + 0.2, -D / 2 - 0.4, Color3.fromRGB(25, 27, 30))
	local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.CanvasSize = Vector2.new(600, 80); sg.LightInfluence = 0; sg.Parent = sign
	local st = Instance.new("TextLabel"); st.Name = "Owner"; st.Size = UDim2.fromScale(1, 1); st.BackgroundTransparency = 1; st.Text = "LEDIGT GARAGE"; st.TextScaled = true
	st.Font = Enum.Font.GothamBlack; st.TextColor3 = Color3.fromRGB(255, 176, 32); st.Parent = sg
	-- lamps
	for _, x in ipairs({ -7, 0, 7 }) do
		for _, z in ipairs({ -3.5, 3.5 }) do
			local shade = part("LampShade", Vector3.new(M(0.3), M(0.7), M(0.7)), at(x, H - 1.1, z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(46, 70, 60), Enum.Material.Metal, "cyl")
			shade.CanCollide = false
			local bulb = box("LampBulb", 0.5, 0.05, 0.5, x, H - 1.28, z, Color3.fromRGB(255, 244, 220), Enum.Material.Neon); bulb.CanCollide = false
			local l = Instance.new("SpotLight"); l.Face = Enum.NormalId.Bottom; l.Angle = 120; l.Range = 40; l.Brightness = 1.5; l.Color = Color3.fromRGB(255, 240, 215); l.Shadows = true; l.Parent = bulb
		end
	end
	-- dirt and wear: oil stains on the floor
	local rnd = Random.new(plotIdx * 13)
	for _ = 1, 7 do
		local s = 0.4 + rnd:NextNumber() * 0.9
		local o = part("OilStain", Vector3.new(M(0.02), M(s), M(s)), at(rnd:NextNumber() * 18 - 9, 0.012, rnd:NextNumber() * 12 - 7) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(40, 38, 36), Enum.Material.SmoothPlastic, "cyl")
		o.Transparency = 0.45; o.CanCollide = false; o.CanQuery = false
	end
	box("MopedMat", 1.4, 0.01, 2.8, 0, 0.005, -2, Color3.fromRGB(30, 30, 32), Enum.Material.Fabric).CanQuery = false
	local refs = GarageBuilder.anchors(origin)
	refs.model, refs.sign = G, st
	-- moped spot (the current moped) and parking spots for the others
	refs.parking = { at(-8.5, 0, -4) * CFrame.Angles(0, math.rad(90), 0), at(-8.5, 0, 0.5) * CFrame.Angles(0, math.rad(90), 0) }
	-- workbench along the back wall with pegboard and tools
	local bench = box("Bench", 5.6, 0.08, 0.9, -6, 0.95, 7.3, wood, Enum.Material.Wood)
	interact(bench, "bench", "Lägg på arbetsbänken")
	for _, x in ipairs({ -8.7, -3.3 }) do box("BenchLeg", 0.08, 0.95, 0.8, x, 0.47, 7.3, steel, Enum.Material.Metal) end
	box("BenchShelf", 5.6, 0.04, 0.8, -6, 0.3, 7.3, steel, Enum.Material.Metal)
	box("Pegboard", 5.6, 1.4, 0.05, -6, 1.85, 7.95, Color3.fromRGB(150, 132, 98), Enum.Material.WoodPlanks)
	for i = 0, 15 do
		local t = box("WallTool", 0.05, 0.22 + rnd:NextNumber() * 0.25, 0.03, -8.5 + i * 0.33, 1.85 + (rnd:NextNumber() - 0.5) * 0.7, 7.9, i % 3 == 0 and red or Color3.fromRGB(70, 74, 80), Enum.Material.Metal)
		t.CFrame = t.CFrame * CFrame.Angles(0, 0, (rnd:NextNumber() - 0.5) * 0.7)
	end
	refs.benchSlots = {}
	for i = 0, 7 do table.insert(refs.benchSlots, at(-8.4 + i * 0.68, 1.05, 7.2)) end
	-- engine stand (red) with a mount plate
	box("StandBase", 0.7, 0.06, 0.7, -2.2, 0.03, 4.6, red, Enum.Material.Metal)
	part("StandPost", Vector3.new(M(0.8), M(0.08), M(0.08)), at(-2.2, 0.45, 4.6) * CFrame.Angles(0, 0, math.pi / 2), red, Enum.Material.Metal, "cyl")
	local standPlate = box("StandPlate", 0.06, 0.2, 0.2, -2.2, 0.85, 4.6, Color3.fromRGB(80, 80, 85), Enum.Material.Metal)
	interact(standPlate, "stand", "Motorstativ: bygg motorn")
	local standZone = box("StandZone", 1.2, 1.2, 1.2, -2.2, 1.2, 4.6, Color3.new(1, 1, 1)); standZone.Transparency = 1; standZone.CanCollide = false
	interact(standZone, "stand", "Motorstativ: bygg motorn")
	refs.standTray = {}
	for i = 0, 7 do table.insert(refs.standTray, at(-3.4 + (i % 4) * 0.28, 0.82, 3.5 + math.floor(i / 4) * 0.3)) end
	box("TrayTable", 1.3, 0.05, 0.75, -2.98, 0.75, 3.65, steel, Enum.Material.Metal)
	-- porting bench with vise and lamp
	local pb = box("PortBench", 1.4, 0.08, 0.7, 2.2, 0.95, 7.3, Color3.fromRGB(70, 74, 80), Enum.Material.DiamondPlate)
	interact(pb, "portbench", "Portningsbänk: porta cylindern")
	box("PortLeg", 1.3, 0.9, 0.6, 2.2, 0.45, 7.3, steel, Enum.Material.Metal)
	box("Vise", 0.25, 0.18, 0.3, 2.2, 1.08, 7.15, Color3.fromRGB(40, 70, 130), Enum.Material.Metal)
	local pl = box("PortLamp", 0.3, 0.05, 0.3, 2.2, 1.9, 7.1, Color3.fromRGB(255, 250, 235), Enum.Material.Neon)
	local plL = Instance.new("SpotLight"); plL.Face = Enum.NormalId.Bottom; plL.Angle = 60; plL.Range = 8; plL.Brightness = 2.5; plL.Parent = pl
	-- paint booth: glass walls, extractor fan, panel stand
	local bx, bz = 8.8, 5
	for _, side in ipairs({ { 3.4, 0.05, bx, bz - 1.7 }, { 0.05, 3.4, bx - 1.7, bz }, { 0.05, 3.4, bx + 1.7, bz } }) do
		local g = box("BoothGlass", side[1], 2.6, side[2], side[3], 1.3, side[4], Color3.fromRGB(200, 220, 230), Enum.Material.Glass); g.Transparency = 0.7
	end
	box("BoothFloor", 3.4, 0.03, 3.4, bx, 0.015, bz, Color3.fromRGB(70, 90, 80), Enum.Material.Fabric)
	box("BoothFan", 1.2, 1.2, 0.2, bx, 2.2, bz + 1.7, Color3.fromRGB(60, 60, 64), Enum.Material.DiamondPlate)
	box("BoothLight", 3, 0.05, 0.3, bx, 2.65, bz, Color3.fromRGB(255, 252, 240), Enum.Material.Neon)
	part("BoothStand", Vector3.new(M(1), M(0.06), M(0.06)), at(bx, 0.5, bz) * CFrame.Angles(0, 0, math.pi / 2), steel, Enum.Material.Metal, "cyl")
	local bs = box("BoothRack", 0.8, 0.05, 0.05, bx, 1.0, bz, steel, Enum.Material.Metal)
	interact(bs, "booth", "Lackbox: lackera kåpan")
	local bzn = box("BoothZone", 2.8, 2.2, 2.8, bx, 1.2, bz, Color3.new(1, 1, 1)); bzn.Transparency = 1; bzn.CanCollide = false
	interact(bzn, "booth", "Lackbox: lackera kåpan")
	-- shelving along the right wall
	refs.shelfSlots = {}
	for j = 0, 3 do
		local s = box("Shelf", 0.6, 0.04, 4.2, W / 2 - 0.5, 0.3 + j * 0.62, -2, Color3.fromRGB(200, 120, 30), Enum.Material.Metal)
		interact(s, "shelf", "Lägg på hyllan")
		if j < 3 then for k = 0, 5 do table.insert(refs.shelfSlots, at(W / 2 - 0.5, 0.42 + j * 0.62, -3.75 + k * 0.7)) end end
	end
	for _, z in ipairs({ -4.1, 0.1 }) do for _, x in ipairs({ W / 2 - 0.78, W / 2 - 0.22 }) do box("Upright", 0.05, 2.2, 0.05, x, 1.1, z, Color3.fromRGB(40, 90, 160), Enum.Material.Metal) end end
	-- computer desk (left front)
	box("Desk", 1.6, 0.06, 0.8, -10.2, 0.75, -5.5, wood, Enum.Material.Wood)
	for _, dx in ipairs({ -0.75, 0.75 }) do box("DeskLeg", 0.05, 0.75, 0.7, -10.2 + dx, 0.37, -5.5, steel, Enum.Material.Metal) end
	local screen = box("Screen", 0.62, 0.42, 0.04, -10.2, 1.08, -5.3, Color3.fromRGB(70, 140, 200), Enum.Material.Neon)
	interact(screen, "computer", "Dator: Moppelagret.se")
	box("Keyboard", 0.45, 0.02, 0.15, -10.2, 0.79, -5.65, Color3.fromRGB(30, 30, 32))
	box("Chair", 0.5, 0.08, 0.5, -10.2, 0.48, -6.1, Color3.fromRGB(30, 30, 32), Enum.Material.Fabric)
	-- moped lift (decor), tyres, compressor, drums, extinguisher
	box("LiftTop", 0.9, 0.12, 2.4, 5, 0.55, -3, Color3.fromRGB(150, 155, 160), Enum.Material.DiamondPlate)
	box("LiftBase", 0.5, 0.5, 1.6, 5, 0.25, -3, red, Enum.Material.Metal)
	for sidx = 0, 1 do for i = 0, 4 do part("Tyre", Vector3.new(M(0.2), M(0.65), M(0.65)), at(W / 2 - 0.8 - sidx * 0.8, 0.1 + i * 0.2, -6.3) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(24, 24, 26), Enum.Material.SmoothPlastic, "cyl") end end
	part("Compressor", Vector3.new(M(1.1), M(0.45), M(0.45)), at(-W / 2 + 1, 0.35, 6.4), red, Enum.Material.Metal, "cyl")
	for i, c in ipairs({ Color3.fromRGB(31, 95, 158), Color3.fromRGB(150, 30, 30) }) do part("Drum", Vector3.new(M(0.9), M(0.6), M(0.6)), at(-W / 2 + 0.6, 0.45, 2 + i * 0.75) * CFrame.Angles(0, 0, math.pi / 2), c, Enum.Material.Metal, "cyl") end
	part("Extinguisher", Vector3.new(M(0.5), M(0.16), M(0.16)), at(-W / 2 + 0.3, 0.6, -6.8) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(200, 20, 20), Enum.Material.Metal, "cyl")
	-- delivery: outside the door, with floor spots around for unpacked parts
	refs.floorSlots = {}
	for i = 0, 11 do table.insert(refs.floorSlots, at(2.6 + (i % 4) * 0.6, 0.12, -11 - math.floor(i / 4) * 0.6)) end
	-- spawn point inside
	return refs
end

return GarageBuilder

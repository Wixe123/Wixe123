-- Builds the world around the garages: ground, roads from Map (with markings and street lights), the town on
-- Storgatan, the petrol station, the supermarket, the industrial area, the harbour, the country road to the farm,
-- the test track and the drag strip. Everything is anchored parts; terrain is only used for water.
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Map = require(Shared.Map)
local Models = require(Shared.Models)
local GarageBuilder = require(Shared.GarageBuilder)

local V3, CF, C3 = Vector3.new, CFrame.new, Color3.fromRGB
local M = Enum.Material
local rad = math.rad

local world = Instance.new("Folder")
world.Name = "Världen"
world.Parent = workspace
local mk = Models.maker(world)
local function box(name, size, cf, color, mat, collide)
	local p = mk.box(name, size, cf, color, mat)
	p.CanCollide = collide ~= false
	return p
end
local function cyl(name, len, r, cf, color, mat, collide)
	local p = mk.cyl(name, len, r, cf, color, mat)
	p.CanCollide = collide ~= false
	return p
end

---------------------------------------------------------------- light and sky
Lighting.ClockTime = 14.5
Lighting.GeographicLatitude = 58
Lighting.Brightness = 2.2
Lighting.Ambient = C3(70, 72, 80)
Lighting.OutdoorAmbient = C3(130, 135, 145)
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.8
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.25
local atm = Instance.new("Atmosphere")
atm.Density = 0.28
atm.Offset = 0.2
atm.Color = C3(200, 214, 230)
atm.Decay = C3(110, 120, 140)
atm.Glare = 0.2
atm.Haze = 1.2
atm.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Contrast = 0.06
cc.Saturation = 0.08
cc.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.35
bloom.Size = 26
bloom.Threshold = 1.4
bloom.Parent = Lighting
local rays = Instance.new("SunRaysEffect")
rays.Intensity = 0.06
rays.Parent = Lighting

---------------------------------------------------------------- ground
-- one flat grass plate; roads, pavements and garage floors are parts on top of it (no terrain grass)
-- (the harbour basin in the west is left open for the water)
box("Mark", V3(1440, 4, 2048), CF(300, -2, 0), C3(86, 128, 62), M.Grass)
box("Mark", V3(600, 4, 1224), CF(-720, -2, 412), C3(86, 128, 62), M.Grass)
box("Mark", V3(600, 4, 564), CF(-720, -2, -742), C3(86, 128, 62), M.Grass)
box("Mark", V3(400, 4, 260), CF(-820, -2, -330), C3(86, 128, 62), M.Grass)

---------------------------------------------------------------- roads
local ASPHALT, LINE, KERB, PAVE = C3(58, 58, 62), C3(235, 235, 230), C3(170, 170, 166), C3(150, 148, 144)
local RY = Map.ROAD_Y
local function roadSegment(r)
	local a, b = V3(r.a[1], 0, r.a[2]), V3(r.b[1], 0, r.b[2])
	local len = (b - a).Magnitude
	if len < 0.1 then return end
	local mid = (a + b) / 2
	local look = CFrame.lookAt(mid, b)
	local col = r.drag and C3(46, 46, 50) or ASPHALT
	box("Väg", V3(r.w, 0.24, len), look * CF(0, RY - 0.12, 0), col, M.Asphalt)
	-- round joint so bends have no gaps
	cyl("Väg", 0.24, r.w / 2, CF(b.X, RY - 0.12 - 0.001, b.Z) * CFrame.Angles(0, 0, rad(90)), col, M.Asphalt)
	-- markings: dashed centre line on normal roads, edge lines on the track
	if r.track then
		for _, s in ipairs({ -1, 1 }) do box("Kantlinje", V3(0.3, 0.02, len), look * CF(s * (r.w / 2 - 0.6), RY + 0.01, 0), LINE, M.SmoothPlastic, false) end
	elseif r.drag then
		box("Mittlinje", V3(0.3, 0.02, len), look * CF(0, RY + 0.01, 0), LINE, M.SmoothPlastic, false)
		for _, s in ipairs({ -1, 1 }) do box("Kantlinje", V3(0.3, 0.02, len), look * CF(s * (r.w / 2 - 0.5), RY + 0.01, 0), LINE, M.SmoothPlastic, false) end
	else
		local n = math.floor(len / 9)
		for i = 0, n - 1 do
			local z = -len / 2 + 4.5 + i * 9
			box("Mittlinje", V3(0.3, 0.02, 4), look * CF(0, RY + 0.01, z), LINE, M.SmoothPlastic, false)
		end
	end
end
for _, r in ipairs(Map.ROADS) do roadSegment(r) end

-- pavement along Garagegatan (town side) and both sides of Storgatan, with kerbs
local function pavement(x0, z0, x1, z1, w)
	local a, b = V3(x0, 0, z0), V3(x1, 0, z1)
	local len = (b - a).Magnitude
	local look = CFrame.lookAt((a + b) / 2, b)
	box("Trottoar", V3(w, 0.4, len), look * CF(0, 0.2, 0), PAVE, M.Pavement)
	return look, len
end
local SZ = Config.STREET_Z
pavement(-322, SZ - 11, -8, SZ - 11, 5)
pavement(8, SZ - 11, 322, SZ - 11, 5)
for _, s in ipairs({ -1, 1 }) do pavement(s * 10.5, SZ - 14, s * 10.5, -282, 5) end
for _, s in ipairs({ -1, 1 }) do pavement(s * 10.5, -298, s * 10.5, -522, 5) end

-- street lights
local function streetLight(x, z, faceX)
	box("Lyktstolpe", V3(0.5, 16, 0.5), CF(x, 8, z), C3(60, 62, 66), M.Metal)
	box("Lyktarm", V3(math.abs(faceX) * 3 + 0.4, 0.35, 0.4), CF(x + faceX * 1.5, 15.8, z), C3(60, 62, 66), M.Metal)
	local lamp = box("Lykta", V3(1.6, 0.4, 0.9), CF(x + faceX * 3, 15.6, z), C3(255, 236, 190), M.Neon, false)
	local l = Instance.new("SpotLight")
	l.Face = Enum.NormalId.Bottom
	l.Range = 34
	l.Angle = 110
	l.Brightness = 1.2
	l.Color = C3(255, 220, 170)
	l.Parent = lamp
end
for x = -300, 300, 50 do if math.abs(x) > 20 then streetLight(x, SZ - 10, 1) end end
for z = -80, -500, -50 do streetLight(-11, z, 1); streetLight(11, z - 25, -1) end
for x = -300, 300, 60 do streetLight(x, -299, 1) end

---------------------------------------------------------------- trees and fences
local LEAF = { C3(58, 110, 46), C3(74, 126, 52), C3(48, 96, 40) }
local treeN = 0
local function tree(x, z, s)
	treeN = treeN + 1
	s = s or 1
	box("Stam", V3(0.9 * s, 7 * s, 0.9 * s), CF(x, 3.5 * s, z), C3(92, 70, 50), M.Wood)
	local leaf = LEAF[treeN % 3 + 1]
	mk.ball("Krona", 7 * s, CF(x, 8.5 * s, z), leaf, M.Grass)
	mk.ball("Krona", 5 * s, CF(x + 1.6 * s, 10.5 * s, z - 0.8 * s), leaf, M.Grass)
	mk.ball("Krona", 4.5 * s, CF(x - 1.4 * s, 11 * s, z + 1 * s), leaf, M.Grass)
end
local function birch(x, z)
	box("Stam", V3(0.6, 12, 0.6), CF(x, 6, z), C3(236, 232, 224), M.SmoothPlastic)
	mk.ball("Krona", 6, CF(x, 12.5, z), C3(110, 160, 60), M.Grass)
	mk.ball("Krona", 4.5, CF(x + 1.2, 14.5, z), C3(110, 160, 60), M.Grass)
end
-- behind the garages and along the roads
for x = -300, 300, 34 do tree(x + 10, 34, 1.1); birch(x + 27, 44) end
for z = -60, -260, -36 do tree(-24, z, 0.9); tree(24, z - 18, 0.9) end
for i = 0, 10 do birch(345 + (i % 2) * 8, 30 + i * 16) end

---------------------------------------------------------------- buildings
local FACADES = { C3(214, 196, 170), C3(186, 92, 70), C3(226, 214, 150), C3(160, 180, 196), C3(226, 226, 222), C3(140, 150, 120) }
local function building(cx, cz, w, d, floors, color, name, signText, signColor)
	local h = floors * 9 + 1
	box(name or "Hus", V3(w, h, d), CF(cx, h / 2, cz), color, M.Plaster)
	box("Tak", V3(w + 1, 0.8, d + 1), CF(cx, h + 0.4, cz), C3(70, 70, 74), M.Concrete)
	-- window bands on all four sides
	for f = 0, floors - 1 do
		local y = 4.5 + f * 9 + (f == 0 and 0 or 1)
		for _, s in ipairs({ -1, 1 }) do
			local g = box("Fönster", V3(w - 4, 3.6, 0.2), CF(cx, y, cz + s * (d / 2 + 0.05)), C3(120, 160, 190), M.Glass, false)
			g.Reflectance = 0.25
			local g2 = box("Fönster", V3(0.2, 3.6, d - 4), CF(cx + s * (w / 2 + 0.05), y, cz), C3(120, 160, 190), M.Glass, false)
			g2.Reflectance = 0.25
			for k = 1, math.floor((w - 4) / 6) do
				box("Spröjs", V3(0.4, 3.6, 0.3), CF(cx - (w - 4) / 2 + k * 6, y, cz + s * (d / 2 + 0.08)), color, M.Plaster, false)
			end
		end
	end
	if signText then
		local sp = box("Skylt", V3(math.min(w - 2, #signText * 2.4 + 4), 3.2, 0.4), CF(cx, math.min(h - 2, 13), cz - d / 2 - 0.3), signColor or C3(20, 22, 28), M.SmoothPlastic, false)
		GarageBuilder.sign(world, sp, Enum.NormalId.Front, signText, C3(255, 255, 255))
	end
end
-- the town along Storgatan (west side faces +X towards the road, east side faces -X)
local n = 0
for z = -75, -470, -58 do
	n = n + 1
	if not (z < -150 and z > -230) then building(-40, z, 36, 40, 3 + n % 3, FACADES[n % 6 + 1]) end
	if not (z < -100 and z > -170) then building(42, z - 10, 34, 38, 2 + (n + 1) % 4, FACADES[(n + 2) % 6 + 1]) end
end
-- supermarket and car park (west)
building(-78, -192, 60, 34, 1, C3(232, 232, 228), "Stormarknad", "STORMARKNAD", C3(200, 30, 30))
box("Parkering", V3(50, 0.2, 40), CF(-34, 0.06, -192), C3(64, 64, 68), M.Asphalt)
for i = 0, 7 do box("P-linje", V3(0.3, 0.02, 9), CF(-54 + i * 6, 0.17, -178), LINE, M.SmoothPlastic, false); box("P-linje", V3(0.3, 0.02, 9), CF(-54 + i * 6, 0.17, -206), LINE, M.SmoothPlastic, false) end
local function car(x, z, color, rotY)
	local c = CF(x, 0, z) * CFrame.Angles(0, rad(rotY or 0), 0)
	box("Bil", V3(5.4, 1.8, 12), c * CF(0, 1.9, 0), color, M.SmoothPlastic)
	box("Bil", V3(5, 1.6, 6), c * CF(0, 3.5, 0.6), color, M.SmoothPlastic)
	box("Ruta", V3(4.6, 1.3, 6.1), c * CF(0, 3.5, 0.6), C3(40, 50, 60), M.Glass, false)
	for _, s in ipairs({ -1, 1 }) do for _, t in ipairs({ -4, 4 }) do cyl("Hjul", 0.9, 1.1, c * CF(s * 2.4, 1.1, t), C3(20, 20, 22), M.Rubber) end end
end
car(-51, -180, C3(30, 60, 140), 0); car(-39, -204, C3(200, 200, 200), 180); car(-27, -180, C3(140, 20, 20), 0); car(-15, -204, C3(30, 30, 30), 180)

-- petrol station "Macken" (east side)
do
	local x, z = 48, -132
	box("Mackplatta", V3(40, 0.2, 34), CF(x, 0.06, z), C3(110, 110, 112), M.Concrete)
	for _, s in ipairs({ -1, 1 }) do for _, t in ipairs({ -1, 1 }) do box("Pelare", V3(1, 12, 1), CF(x - 4 + s * 8, 6, z + t * 6), C3(230, 230, 230), M.Metal) end end
	box("Tak", V3(22, 1.4, 18), CF(x - 4, 12.7, z), C3(240, 240, 240), M.SmoothPlastic)
	box("Takkant", V3(22.2, 0.8, 18.2), CF(x - 4, 12.7, z), C3(20, 120, 200), M.Neon, false)
	for _, t in ipairs({ -1, 1 }) do
		box("Pump", V3(1.4, 4.2, 2.2), CF(x - 4, 2.1, z + t * 6), C3(20, 120, 200), M.SmoothPlastic)
		box("Pump", V3(1.5, 1.2, 2.3), CF(x - 4, 4.2, z + t * 6), C3(240, 240, 240), M.SmoothPlastic)
	end
	building(x + 13, z, 14, 22, 1, C3(236, 236, 236), "Butik")
	local sp = box("Mackskylt", V3(0.6, 7, 4), CF(x - 22, 9, z - 14), C3(20, 120, 200), M.SmoothPlastic)
	GarageBuilder.sign(world, sp, Enum.NormalId.Left, "MACKEN", C3(255, 255, 255))
	box("Mackskylt", V3(0.6, 6, 0.6), CF(x - 22, 3, z - 14), C3(60, 60, 60), M.Metal)
	for i = 1, 3 do local l = box("Taklampa", V3(4, 0.2, 1), CF(x - 4, 11.9, z - 6 + i * 3), C3(255, 255, 250), M.Neon, false); local s = Instance.new("SurfaceLight"); s.Face = Enum.NormalId.Bottom; s.Range = 16; s.Brightness = 1; s.Parent = l end
end

-- Verkstad Norr at the end of Storgatan
building(0, -560, 40, 26, 1, C3(200, 204, 210), "Verkstad", "VERKSTAD NORR", C3(30, 70, 160))

-- industrial area east of Storgatan: warehouses and containers
local function warehouse(cx, cz, w, d, h, color, text)
	box("Lager", V3(w, h, d), CF(cx, h / 2, cz), color, M.Metal)
	box("Tak", V3(w + 1, 1, d + 1), CF(cx, h + 0.5, cz), C3(90, 92, 96), M.Metal)
	box("Port", V3(14, 12, 0.4), CF(cx, 6, cz - d / 2 - 0.2), C3(200, 200, 200), M.Metal, false)
	for i = -3, 3 do box("Ribba", V3(0.3, h, 0.3), CF(cx + i * w / 7, h / 2, cz - d / 2 - 0.15), C3(60, 64, 70), M.Metal, false) end
	if text then
		local sp = box("Skylt", V3(#text * 2.4 + 6, 3.4, 0.4), CF(cx, h - 3, cz - d / 2 - 0.4), C3(240, 196, 30), M.SmoothPlastic, false)
		GarageBuilder.sign(world, sp, Enum.NormalId.Front, text, C3(20, 20, 20))
	end
end
box("Industriplatta", V3(260, 0.2, 110), CF(190, 0.05, -350), C3(100, 100, 98), M.Concrete)
warehouse(110, -350, 60, 40, 22, C3(140, 150, 160))
warehouse(240, -350, 56, 36, 20, C3(170, 100, 60), "INDUSTRIVERKSTADEN")
local CONT = { C3(200, 40, 30), C3(30, 90, 160), C3(40, 140, 70), C3(230, 160, 30) }
for i = 0, 7 do
	local x, z = 160 + (i % 4) * 18, -385 - math.floor(i / 4) * 10
	box("Container", V3(16, 8.5, 8), CF(x, 4.25 + (i == 5 and 8.5 or 0), z), CONT[i % 4 + 1], M.Metal)
end

-- harbour in the west: quay, warehouse and water
box("Kaj", V3(80, 1, 60), CF(-370, 0.5, -330), C3(130, 128, 124), M.Concrete)
warehouse(-370, -345, 50, 26, 18, C3(120, 60, 50), "HAMNENS LAGER")
box("Vatten", V3(200, 0.4, 260), CF(-520, -0.7, -330), C3(40, 80, 110), M.Glass, true).Transparency = 0.15
workspace.Terrain:FillBlock(CF(-520, -2.5, -330), V3(200, 4, 260), Enum.Material.Water)
for i = 0, 6 do cyl("Pollare", 1.2, 0.5, CF(-412, 1.6, -360 + i * 10) * CFrame.Angles(0, 0, rad(90)), C3(30, 30, 30), M.Metal) end

-- country road: fields and the farm
local FIELDS = { C3(150, 120, 80), C3(210, 190, 110), C3(120, 150, 70), C3(160, 130, 90) }
for i = 0, 5 do
	local x, z = 380 + (i % 3) * 70, 80 + math.floor(i / 3) * 90
	if not (x > 400 and x < 470 and z > 150) then box("Åker", V3(60, 0.1, 80), CF(x + 30, 0.04, z), FIELDS[i % 4 + 1], M.Ground, false) end
end
do
	local x, z = 545, 500
	box("Lada", V3(30, 16, 22), CF(x, 8, z), C3(150, 30, 26), M.WoodPlanks)
	box("Takfot", V3(31, 0.6, 23), CF(x, 16.2, z), C3(240, 240, 240), M.Wood)
	mk.wedge("Tak", V3(31, 7, 11.5), CF(x, 19.8, z - 5.75) * CFrame.Angles(0, rad(180), 0), C3(60, 60, 64), M.Slate).CanCollide = true
	mk.wedge("Tak", V3(31, 7, 11.5), CF(x, 19.8, z + 5.75), C3(60, 60, 64), M.Slate).CanCollide = true
	box("Ladport", V3(10, 11, 0.4), CF(x - 6, 5.5, z - 11.2), C3(240, 240, 240), M.WoodPlanks, false)
	local sp = box("Skylt", V3(14, 2.6, 0.3), CF(x - 6, 13, z - 11.3), C3(240, 240, 240), M.Wood, false)
	GarageBuilder.sign(world, sp, Enum.NormalId.Front, "LINDGÅRDEN", C3(150, 30, 26))
	for i = 0, 12 do box("Staket", V3(0.3, 3, 0.3), CF(495, 1.5, 420 + i * 8), C3(240, 240, 240), M.Wood) end
	box("Staket", V3(0.2, 0.3, 96), CF(495, 2.4, 468), C3(240, 240, 240), M.Wood)
end

-- test track: grass inside, kerbs, grandstand, start line
do
	local t = Map.TRACK
	local sp = box("Läktare", V3(40, 8, 10), CF(t.cx, 4, t.cz - t.r - 16), C3(160, 160, 164), M.Concrete)
	for i = 0, 3 do box("Läktare", V3(40, 1, 2.2), CF(t.cx, 1 + i * 2, t.cz - t.r - 12.5 - i * 2.2), C3(30, 90, 170), M.SmoothPlastic) end
	local sign2 = box("Skylt", V3(24, 3.5, 0.4), CF(t.cx, 11, t.cz - t.r - 21), C3(20, 20, 24), M.SmoothPlastic, false)
	GarageBuilder.sign(world, sign2, Enum.NormalId.Back, "TESTBANAN", C3(240, 196, 30))
	for i = 0, 6 do box("Mållinje", V3(2, 0.03, 2), CF(t.cx - 6 + i * 2, RY + 0.02, t.cz - t.r + (i % 2) * 2), i % 2 == 0 and C3(240, 240, 240) or C3(20, 20, 20), M.SmoothPlastic, false) end
end
-- drag strip: start lights ("christmas tree") and a finish line
do
	local z = 330
	box("Startljus", V3(0.6, 10, 0.6), CF(-300, 5, z - 11), C3(40, 40, 44), M.Metal)
	for i, c in ipairs({ C3(255, 200, 40), C3(255, 200, 40), C3(255, 200, 40), C3(40, 255, 80) }) do
		box("Lampa", V3(1, 0.8, 1), CF(-300, 10.6 - i * 1.2, z - 11), c, M.Neon, false)
	end
	for i = 0, 7 do box("Mållinje", V3(2, 0.03, 2), CF(40, RY + 0.02, z - 7 + i * 2), i % 2 == 0 and C3(240, 240, 240) or C3(20, 20, 20), M.SmoothPlastic, false) end
	local sp = box("Skylt", V3(30, 4, 0.4), CF(-140, 9, z + 14), C3(20, 20, 24), M.SmoothPlastic, false)
	GarageBuilder.sign(world, sp, Enum.NormalId.Front, "DRAGSTRIP 400 m", C3(255, 255, 255))
	box("Skylt", V3(0.6, 7, 0.6), CF(-152, 3.5, z + 14), C3(60, 60, 60), M.Metal)
	box("Skylt", V3(0.6, 7, 0.6), CF(-128, 3.5, z + 14), C3(60, 60, 60), M.Metal)
end

-- destination posts for delivery jobs
for key, pl in pairs(Map.PLACES) do
	local post = box("Leveranspunkt", V3(0.6, 6, 0.6), CF(pl.x + 6, 3, pl.z), C3(240, 196, 30), M.SmoothPlastic)
	local board = box("Leveransskylt", V3(8, 2.2, 0.3), CF(pl.x + 6, 6.6, pl.z), C3(20, 20, 24), M.SmoothPlastic, false)
	GarageBuilder.sign(world, board, Enum.NormalId.Front, pl.n, C3(240, 196, 30))
	GarageBuilder.sign(world, board, Enum.NormalId.Back, pl.n, C3(240, 196, 30))
	post:SetAttribute("Place", key)
end

-- a neutral spawn on the street; the server moves everyone into their own garage
local spawn = Instance.new("SpawnLocation")
spawn.Name = "Start"
spawn.Anchored = true
spawn.Size = V3(6, 0.2, 6)
spawn.CFrame = CF(0, RY + 0.1, SZ)
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Neutral = true
spawn.Parent = world

world:SetAttribute("Built", true)

-- One player's garage. Built around origin (floor centre, the roller door faces -Z towards the street).
-- Returns the anchor points the server uses (where the moped, engine, shelves, bench and boxes go).
local Models = require(script.Parent.Models)
local GarageBuilder = {}

local V3, CF, C3 = Vector3.new, CFrame.new, Color3.fromRGB
local M = Enum.Material
local rad = math.rad

GarageBuilder.W, GarageBuilder.D, GarageBuilder.H = 44, 32, 14
GarageBuilder.FLOOR = 0.2 -- floor top height
local FLOOR = GarageBuilder.FLOOR

-- local anchor points (garage space)
GarageBuilder.LIFT = CF(-7, FLOOR + 1.05, 1)
GarageBuilder.STAND = CF(9, FLOOR + 3.6, 2.5) * CFrame.Angles(0, rad(90), 0)
GarageBuilder.PORT = CF(17.5, FLOOR + 3.55, 12.4)
GarageBuilder.BOOTH = CF(17, FLOOR + 3.2, -9.5)
GarageBuilder.COMPUTER = CF(10.5, FLOOR + 4.25, 15.05)
GarageBuilder.SPAWN = CF(0, FLOOR + 3, -9)
GarageBuilder.EXIT = CF(0, 0, -24) -- where the moped is put when riding out (on the driveway)

local function sign(parent, part, face, text, textColor, bg, font)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0.2
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = bg and 0 or 1
	if bg then l.BackgroundColor3 = bg end
	l.Text = text
	l.TextColor3 = textColor
	l.TextScaled = true
	l.Font = font or Enum.Font.GothamBlack
	l.Parent = sg
	sg.Parent = part
	return l
end
GarageBuilder.sign = sign

function GarageBuilder.build(parent, origin, plotIndex)
	local model = Instance.new("Model")
	model.Name = "Garage" .. plotIndex
	local mk = Models.maker(model)
	local function at(x, y, z) return origin * CF(x, y, z) end
	local function box(name, size, cf, color, mat, collide)
		local p = mk.box(name, size, cf, color, mat)
		p.CanCollide = collide ~= false
		return p
	end
	local W, D, H = GarageBuilder.W, GarageBuilder.D, GarageBuilder.H
	local hw, hd = W / 2, D / 2
	local refs = { benchSlots = {}, shelfSlots = {}, floorSlots = {}, toolSlots = {}, deliverySlots = {} }

	---------------------------------------------------------------- shell
	local floor = box("Golv", V3(W, 0.4, D), at(0, FLOOR - 0.2, 0), C3(122, 122, 118), M.Concrete)
	floor:SetAttribute("Interact", "floor")
	-- oil stains and a drain
	for i, s in ipairs({ { -6, 3, 2.2 }, { -9, -2, 1.4 }, { 8, 1, 1.6 }, { 3, 9, 1.0 }, { -2, -8, 1.2 } }) do
		local st = mk.cyl("Fläck", 0.02, s[3], at(s[1], FLOOR + 0.01, s[2]) * CFrame.Angles(0, 0, rad(90)), C3(70, 66, 60), M.SmoothPlastic)
		st.Transparency = 0.55 + i * 0.04
	end
	box("Brunn", V3(1.4, 0.03, 1.4), at(0, FLOOR + 0.01, 6), C3(60, 60, 62), M.DiamondPlate, false)
	-- yellow work-area lines around the lift and stand
	local yellow = C3(240, 196, 30)
	for _, r in ipairs({ { -7, 1, 7, 12.5 }, { 9, 2.5, 7.5, 8 } }) do
		local x, z, w, d = r[1], r[2], r[3], r[4]
		box("Linje", V3(w, 0.02, 0.22), at(x, FLOOR + 0.01, z - d / 2), yellow, M.SmoothPlastic, false)
		box("Linje", V3(w, 0.02, 0.22), at(x, FLOOR + 0.01, z + d / 2), yellow, M.SmoothPlastic, false)
		box("Linje", V3(0.22, 0.02, d), at(x - w / 2, FLOOR + 0.01, z), yellow, M.SmoothPlastic, false)
		box("Linje", V3(0.22, 0.02, d), at(x + w / 2, FLOOR + 0.01, z), yellow, M.SmoothPlastic, false)
	end
	box("Gummimatta", V3(5, 0.04, 4.5), at(9, FLOOR + 0.02, 2.5), C3(30, 30, 32), M.Rubber, false)
	-- walls: brick inside, corrugated metal outside, dark band at the bottom
	local brick, outer, band = C3(214, 208, 198), C3(84, 96, 112), C3(52, 62, 78)
	local function wall(cx, cz, sx, sz, inward)
		box("Vägg", V3(sx, H, sz), at(cx, FLOOR + H / 2, cz), outer, M.Metal)
		local ix, iz = inward[1] * 0.35, inward[2] * 0.35
		local isx, isz = sx == 1 and 0.3 or sx, sz == 1 and 0.3 or sz
		box("Vägg", V3(isx, H - 4, isz), at(cx + ix, FLOOR + 2 + H / 2, cz + iz), brick, M.Brick)
		box("Sockel", V3(isx, 4, isz), at(cx + ix, FLOOR + 2, cz + iz), band, M.Concrete)
	end
	wall(0, hd + 0.5, W + 2, 1, { 0, -1 })
	wall(-hw - 0.5, 0, 1, D, { 1, 0 })
	wall(hw + 0.5, 0, 1, D, { -1, 0 })
	-- front wall with the door opening (x -7..7, height 10) and two windows
	local doorW, doorH = 14, 10
	local sideW = (W - doorW) / 2
	for _, s in ipairs({ -1, 1 }) do
		local cx = s * (doorW / 2 + sideW / 2)
		-- below and above the window, and the pieces beside it
		box("Vägg", V3(sideW, 4.5, 1), at(cx, FLOOR + 2.25, -hd - 0.5), outer, M.Metal)
		box("Vägg", V3(sideW, H - 9, 1), at(cx, FLOOR + 9 + (H - 9) / 2, -hd - 0.5), outer, M.Metal)
		box("Vägg", V3(3, 4.5, 1), at(cx - s * (sideW / 2 - 1.5), FLOOR + 6.75, -hd - 0.5), outer, M.Metal)
		box("Vägg", V3(sideW - 11, 4.5, 1), at(cx + s * (sideW / 2 - (sideW - 11) / 2), FLOOR + 6.75, -hd - 0.5), outer, M.Metal)
		local wx = cx - s * (sideW / 2 - 3 - 4)
		local glass = box("Fönster", V3(8, 4.5, 0.2), at(wx, FLOOR + 6.75, -hd - 0.5), C3(170, 200, 220), M.Glass)
		glass.Transparency = 0.6
		box("Karm", V3(8.3, 0.25, 1.1), at(wx, FLOOR + 9.05, -hd - 0.5), C3(240, 240, 240), M.SmoothPlastic)
		box("Karm", V3(8.3, 0.35, 1.3), at(wx, FLOOR + 4.45, -hd - 0.5), C3(240, 240, 240), M.SmoothPlastic)
		box("Karm", V3(0.2, 4.5, 1.05), at(wx, FLOOR + 6.75, -hd - 0.5), C3(240, 240, 240), M.SmoothPlastic)
		-- inner brick on the front wall
		box("Vägg", V3(sideW, 4.5, 0.3), at(cx, FLOOR + 2.25, -hd + 0.15), band, M.Concrete)
	end
	box("Vägg", V3(doorW, H - doorH, 1), at(0, FLOOR + doorH + (H - doorH) / 2, -hd - 0.5), outer, M.Metal)
	-- roller door rolled up, rails
	mk.cyl("Rulle", doorW + 0.6, 0.75, at(0, FLOOR + doorH + 0.8, -hd + 0.6), C3(170, 175, 180), M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		box("Skena", V3(0.3, doorH, 0.4), at(s * (doorW / 2 + 0.15), FLOOR + doorH / 2, -hd + 0.2), C3(150, 150, 150), M.Metal)
		box("Dörrkarm", V3(0.5, doorH + 0.5, 1.2), at(s * (doorW / 2 + 0.25), FLOOR + (doorH + 0.5) / 2, -hd - 0.5), C3(240, 196, 30), M.SmoothPlastic)
	end
	box("Dörrkarm", V3(doorW + 1, 0.5, 1.2), at(0, FLOOR + doorH + 0.25, -hd - 0.5), C3(240, 196, 30), M.SmoothPlastic)
	-- roof and ceiling
	box("Tak", V3(W + 3, 0.8, D + 3), at(0, FLOOR + H + 0.4, 0), C3(70, 74, 80), M.Metal)
	box("Innertak", V3(W, 0.1, D), at(0, FLOOR + H - 0.05, 0), C3(236, 236, 232), M.SmoothPlastic)
	for i = -2, 2 do box("Balk", V3(W, 0.7, 0.4), at(0, FLOOR + H - 0.45, i * 6.5), C3(110, 116, 124), M.Metal) end
	-- fluorescent lights
	for _, x in ipairs({ -12, 0, 12 }) do
		for _, z in ipairs({ -6, 7 }) do
			box("Armatur", V3(0.9, 0.25, 6.5), at(x, FLOOR + H - 0.95, z), C3(235, 235, 235), M.SmoothPlastic, false)
			local tube = box("Lysrör", V3(0.35, 0.12, 6.1), at(x, FLOOR + H - 1.12, z), C3(255, 252, 240), M.Neon, false)
			local l = Instance.new("SurfaceLight")
			l.Face = Enum.NormalId.Bottom
			l.Range = 26
			l.Angle = 120
			l.Brightness = 1.6
			l.Color = C3(255, 246, 230)
			l.Shadows = true
			l.Parent = tube
		end
	end

	---------------------------------------------------------------- workbench, pegboard and tools (back wall)
	local wood, blue, chrome = C3(150, 112, 72), C3(28, 88, 170), C3(205, 210, 215)
	local benchX0, benchX1, benchZ = -19, 1, hd - 1.4
	local bw = benchX1 - benchX0
	local bcx = (benchX0 + benchX1) / 2
	local top = box("Arbetsbänk", V3(bw, 0.35, 2.6), at(bcx, FLOOR + 3.0, benchZ), wood, M.WoodPlanks)
	top:SetAttribute("Interact", "bench")
	for i = 0, 4 do
		local x = benchX0 + 2 + i * 4
		box("Skåp", V3(3.8, 2.75, 2.3), at(x, FLOOR + 1.45, benchZ + 0.1), blue, M.Metal)
		for j = 0, 2 do
			box("Låda", V3(3.5, 0.75, 0.06), at(x, FLOOR + 0.55 + j * 0.88, benchZ - 1.07), C3(36, 100, 185), M.Metal, false)
			box("Handtag", V3(1.4, 0.1, 0.12), at(x, FLOOR + 0.8 + j * 0.88, benchZ - 1.13), chrome, M.Metal, false)
		end
	end
	for i = 1, 8 do
		local x = benchX0 + 1.5 + (i - 1) * (bw - 3) / 7
		refs.benchSlots[i] = at(x, FLOOR + 3.2, benchZ - 0.2)
	end
	-- pegboard with tools
	box("Verktygstavla", V3(bw, 5.2, 0.15), at(bcx, FLOOR + 6.3, hd - 0.2), C3(196, 172, 128), M.Plaster)
	for i = 0, bw * 2 - 1 do
		for j = 0, 9 do
			if (i + j) % 2 == 0 then box("Hål", V3(0.08, 0.08, 0.02), at(benchX0 + 0.25 + i * 0.5, FLOOR + 3.95 + j * 0.5, hd - 0.28), C3(90, 76, 56), M.SmoothPlastic, false) end
		end
	end
	-- wrenches in a row (sizes), screwdrivers, hammer, pliers
	for i = 0, 9 do
		local len = 1.0 + i * 0.12
		local x = benchX0 + 1 + i * 0.45
		box("Nyckel", V3(0.12, len, 0.05), at(x, FLOOR + 7.2 - len / 2, hd - 0.33), chrome, M.Metal, false)
		box("Nyckel", V3(0.26, 0.2, 0.05), at(x, FLOOR + 7.25, hd - 0.33), chrome, M.Metal, false)
	end
	local cols = { C3(220, 40, 40), C3(240, 196, 30), C3(30, 90, 200), C3(30, 160, 80), C3(220, 40, 40), C3(30, 30, 30) }
	for i = 1, 6 do
		local x = benchX0 + 6 + i * 0.5
		box("Mejsel", V3(0.16, 0.6, 0.16), at(x, FLOOR + 6.8, hd - 0.36), cols[i], M.SmoothPlastic, false)
		box("Mejsel", V3(0.05, 0.9, 0.05), at(x, FLOOR + 6.05, hd - 0.36), chrome, M.Metal, false)
	end
	box("Hammare", V3(0.15, 1.3, 0.12), at(benchX0 + 10.5, FLOOR + 6.3, hd - 0.35), wood, M.Wood, false)
	box("Hammare", V3(0.7, 0.25, 0.2), at(benchX0 + 10.5, FLOOR + 7.0, hd - 0.38), C3(60, 60, 64), M.Metal, false)
	for i = 0, 2 do
		box("Tång", V3(0.12, 1.0, 0.06), at(benchX0 + 12 + i * 0.6 - 0.08, FLOOR + 6.3, hd - 0.34) * CFrame.Angles(0, 0, rad(6)), C3(200, 40, 40), M.SmoothPlastic, false)
		box("Tång", V3(0.12, 1.0, 0.06), at(benchX0 + 12 + i * 0.6 + 0.08, FLOOR + 6.3, hd - 0.34) * CFrame.Angles(0, 0, rad(-6)), C3(200, 40, 40), M.SmoothPlastic, false)
	end
	-- socket set case and a cordless screwdriver on the board (where the player's tools hang)
	for i = 1, 4 do refs.toolSlots[i] = at(benchX0 + 14 + (i - 1) * 1.4, FLOOR + 6.2, hd - 0.6) end
	-- shelf above the pegboard with cans and boxes
	box("Hylla", V3(bw, 0.2, 1.4), at(bcx, FLOOR + 9.3, hd - 0.8), C3(120, 120, 124), M.Metal)
	local canCols = { C3(200, 30, 30), C3(30, 100, 200), C3(240, 196, 30), C3(40, 140, 60), C3(230, 230, 230) }
	for i = 0, 17 do
		local x = benchX0 + 0.8 + i * 1.08
		if i % 4 == 3 then box("Kartong", V3(0.95, 0.8, 1.0), at(x, FLOOR + 9.8, hd - 0.8), C3(176, 138, 92), M.Cardboard, false)
		else mk.cyl("Burk", 0.9, 0.3, at(x, FLOOR + 9.85, hd - 0.8) * CFrame.Angles(0, 0, rad(90)), canCols[i % 5 + 1], M.Metal).CanCollide = false end
	end
	-- banner (made-up brand)
	local banner = box("Banderoll", V3(12, 2.6, 0.08), at(bcx, FLOOR + 11.6, hd - 0.12), C3(22, 52, 150), M.Fabric, false)
	sign(model, banner, Enum.NormalId.Front, "VIPPA  MOPEDER", C3(255, 255, 255))

	---------------------------------------------------------------- red tool chest and computer desk
	local red = C3(196, 30, 30)
	box("Verktygsvagn", V3(4.2, 3.6, 2.2), at(4.6, FLOOR + 2.0, hd - 1.6), red, M.Metal)
	box("Verktygslåda", V3(4.2, 2.0, 1.9), at(4.6, FLOOR + 4.8, hd - 1.5), red, M.Metal)
	for j = 0, 5 do box("Låda", V3(3.9, 0.04, 0.05), at(4.6, FLOOR + 0.8 + j * 0.55, hd - 2.73), C3(30, 30, 30), M.Metal, false) end
	for j = 0, 2 do box("Handtag", V3(3.6, 0.08, 0.1), at(4.6, FLOOR + 4.2 + j * 0.55, hd - 2.5), chrome, M.Metal, false) end
	for _, s in ipairs({ -1, 1 }) do mk.cyl("Hjul", 0.25, 0.22, at(4.6 + s * 1.8, FLOOR + 0.22, hd - 2.4), C3(20, 20, 20), M.Rubber) end
	-- desk
	box("Skrivbord", V3(5.5, 0.25, 2.6), at(10.5, FLOOR + 3.0, hd - 1.5), C3(60, 62, 68), M.Metal)
	for _, s in ipairs({ -1, 1 }) do box("Ben", V3(0.2, 2.9, 2.4), at(10.5 + s * 2.6, FLOOR + 1.45, hd - 1.5), C3(40, 40, 44), M.Metal) end
	box("Dator", V3(0.9, 2.0, 2.0), at(12.4, FLOOR + 1.0, hd - 1.6), C3(26, 26, 30), M.SmoothPlastic)
	box("Skärmfot", V3(0.8, 0.08, 0.6), at(10.5, FLOOR + 3.17, hd - 0.9), C3(30, 30, 34), M.Metal)
	box("Skärmarm", V3(0.15, 0.9, 0.15), at(10.5, FLOOR + 3.6, hd - 0.85), C3(30, 30, 34), M.Metal)
	local monitor = box("Skärm", V3(3.0, 1.75, 0.14), GarageBuilder.COMPUTER and origin * GarageBuilder.COMPUTER, C3(16, 16, 18), M.SmoothPlastic)
	monitor:SetAttribute("Interact", "computer")
	refs.screen = monitor
	box("Tangentbord", V3(1.9, 0.08, 0.65), at(10.3, FLOOR + 3.17, hd - 2.0), C3(30, 30, 34), M.SmoothPlastic, false)
	box("Mus", V3(0.22, 0.08, 0.35), at(11.8, FLOOR + 3.17, hd - 2.0), C3(30, 30, 34), M.SmoothPlastic, false)
	-- office chair
	local chair = C3(26, 26, 28)
	box("Stol", V3(1.6, 0.3, 1.6), at(10.5, FLOOR + 2.0, hd - 3.6), chair, M.Fabric)
	box("Stol", V3(1.6, 1.8, 0.25), at(10.5, FLOOR + 3.0, hd - 2.9), chair, M.Fabric)
	box("Stol", V3(0.2, 1.7, 0.2), at(10.5, FLOOR + 1.0, hd - 3.6), C3(120, 120, 120), M.Metal, false)
	box("Stol", V3(1.8, 0.15, 0.2), at(10.5, FLOOR + 0.2, hd - 3.6), C3(60, 60, 60), M.Metal, false)
	box("Stol", V3(0.2, 0.15, 1.8), at(10.5, FLOOR + 0.2, hd - 3.6), C3(60, 60, 60), M.Metal, false)

	---------------------------------------------------------------- porting bench with vise and lamp
	local px, pz = 17.5, hd - 3.2
	box("Portningsbänk", V3(6, 0.4, 3), at(px, FLOOR + 2.9, pz), C3(80, 84, 90), M.DiamondPlate)
	for _, s in ipairs({ -1, 1 }) do for _, t in ipairs({ -1, 1 }) do box("Ben", V3(0.3, 2.7, 0.3), at(px + s * 2.7, FLOOR + 1.35, pz + t * 1.3), C3(60, 60, 64), M.Metal) end end
	local pb = box("Skruvstäd", V3(1.3, 0.6, 1.0), at(px, FLOOR + 3.4, pz - 0.6), C3(30, 70, 140), M.Metal)
	pb:SetAttribute("Interact", "portbench")
	box("Käft", V3(1.2, 0.5, 0.2), at(px, FLOOR + 3.85, pz - 1.0), C3(70, 74, 80), M.Metal, false)
	box("Käft", V3(1.2, 0.5, 0.2), at(px, FLOOR + 3.85, pz - 0.1), C3(70, 74, 80), M.Metal, false)
	mk.cyl("Skruv", 1.3, 0.07, at(px, FLOOR + 3.4, pz + 0.5) * CFrame.Angles(0, rad(90), 0), C3(180, 180, 180), M.Metal)
	box("Lampfot", V3(0.5, 0.15, 0.5), at(px + 2.2, FLOOR + 3.15, pz + 0.8), C3(30, 30, 30), M.Metal, false)
	mk.tube("Lamparm", at(px + 2.2, FLOOR + 3.2, pz + 0.8).Position, at(px + 1.4, FLOOR + 5.6, pz - 0.2).Position, 0.06, C3(30, 30, 30), M.Metal)
	local shade = mk.cyl("Lampskärm", 0.5, 0.35, at(px + 1.2, FLOOR + 5.5, pz - 0.4) * CFrame.Angles(0, 0, rad(-60)), C3(240, 196, 30), M.Metal)
	local pl = Instance.new("SpotLight")
	pl.Face = Enum.NormalId.Left
	pl.Range = 10
	pl.Angle = 70
	pl.Brightness = 2
	pl.Parent = shade
	refs.portTool = at(px + 1.6, FLOOR + 3.2, pz + 0.6)
	local ps = box("Skylt", V3(4, 0.8, 0.1), at(px, FLOOR + 7.5, hd - 0.3), C3(20, 20, 24), M.SmoothPlastic, false)
	sign(model, ps, Enum.NormalId.Front, "PORTNING", C3(240, 196, 30))

	---------------------------------------------------------------- paint booth (front right corner)
	local bx0, bx1, bz0, bz1 = 12, hw, -hd, -4
	local bcx2, bcz = (bx0 + bx1) / 2, (bz0 + bz1) / 2
	local white = C3(232, 234, 236)
	box("Lackbox", V3(0.3, 11, bz1 - bz0), at(bx0 + 0.15, FLOOR + 5.5, bcz), white, M.SmoothPlastic)
	box("Lackbox", V3(bx1 - bx0, 0.3, bz1 - bz0), at(bcx2, FLOOR + 11, bcz), white, M.SmoothPlastic)
	local curtain = box("Draperi", V3(bx1 - bx0 - 4, 9.5, 0.08), at(bcx2 + 2, FLOOR + 6.2, bz1), C3(160, 200, 230), M.SmoothPlastic, false)
	curtain.Transparency = 0.65
	box("Lackbox", V3(4, 11, 0.3), at(bx0 + 2, FLOOR + 5.5, bz1), white, M.SmoothPlastic)
	box("Galler", V3(bx1 - bx0 - 0.6, 0.06, bz1 - bz0 - 0.6), at(bcx2, FLOOR + 0.04, bcz), C3(50, 52, 56), M.DiamondPlate, false)
	for _, x in ipairs({ bx0 + 2.5, bx1 - 2.5 }) do
		local lp = box("Lackljus", V3(1.2, 0.15, 8), at(x, FLOOR + 10.8, bcz), C3(255, 255, 250), M.Neon, false)
		local sl = Instance.new("SurfaceLight")
		sl.Face = Enum.NormalId.Bottom
		sl.Range = 14
		sl.Brightness = 1.4
		sl.Angle = 120
		sl.Parent = lp
	end
	-- extraction fan on the side wall
	mk.cyl("Fläkthus", 0.6, 1.4, at(bx1 - 0.4, FLOOR + 7, bcz), C3(150, 150, 150), M.Metal)
	mk.ring("Fläkt", at(bx1 - 0.75, FLOOR + 7, bcz), 1.4, 0.06, 6, C3(60, 60, 60), M.Metal)
	-- panel stand
	local stand = box("Lackstativ", V3(0.25, 3.2, 0.25), at(17, FLOOR + 1.6, -9.5), C3(40, 40, 44), M.Metal)
	stand:SetAttribute("Interact", "booth")
	box("Lackstativ", V3(2.4, 0.2, 2.4), at(17, FLOOR + 0.1, -9.5), C3(40, 40, 44), M.Metal)
	box("Lackstativ", V3(2.2, 0.15, 0.15), at(17, FLOOR + 3.0, -9.5), C3(40, 40, 44), M.Metal)
	local bsign = box("Skylt", V3(5, 1, 0.1), at(bcx2 + 2, FLOOR + 10.4, bz1 - 0.1), C3(20, 20, 24), M.SmoothPlastic, false)
	sign(model, bsign, Enum.NormalId.Back, "LACKBOX", C3(255, 255, 255))
	-- compressor next to the booth
	mk.cyl("Kompressor", 3, 0.8, at(10.5, FLOOR + 0.85, -13) , red, M.Metal)
	box("Kompressor", V3(1.2, 0.8, 1), at(10.5, FLOOR + 2, -13), C3(40, 40, 40), M.Metal)

	---------------------------------------------------------------- storage shelves (left wall), 24 slots
	local orange, board = C3(232, 120, 30), C3(150, 152, 156)
	for u, zc in ipairs({ -3.5, 6.5 }) do
		for _, dz in ipairs({ -4, 4 }) do
			for _, dx in ipairs({ -1, 1 }) do
				box("Hyllställ", V3(0.25, 10, 0.25), at(-hw + 1.6 + dx * 1.1, FLOOR + 5, zc + dz), orange, M.Metal)
			end
		end
		for lv = 0, 3 do
			local y = FLOOR + 0.6 + lv * 2.6
			local sh = box("Hyllplan", V3(2.5, 0.15, 8.2), at(-hw + 1.6, y, zc), board, M.Metal)
			sh:SetAttribute("Interact", "shelf")
			for k = 0, 2 do
				refs.shelfSlots[#refs.shelfSlots + 1] = at(-hw + 1.6, y + 0.1, zc - 2.7 + k * 2.7)
			end
		end
		-- static stock on the top
		for k = 0, 3 do box("Kartong", V3(1.6, 1.1, 1.6), at(-hw + 1.6, FLOOR + 10.65, zc - 3 + k * 2), C3(176, 138, 92), M.Cardboard, false) end
	end
	for i = 1, 12 do refs.floorSlots[i] = at(-14 + ((i - 1) % 6) * 2.4, FLOOR, -11 + math.floor((i - 1) / 6) * 2.4) end

	---------------------------------------------------------------- moped lift and engine stand
	local lift = GarageBuilder.LIFT
	box("Lyft", V3(2.8, 0.3, 9), at(lift.X, FLOOR + 0.15, lift.Z), C3(170, 30, 30), M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		box("Saxarm", V3(0.2, 0.2, 5.4), at(lift.X + s * 0.9, FLOOR + 0.6, lift.Z) * CFrame.Angles(rad(8), 0, 0), C3(60, 60, 60), M.Metal, false)
		box("Saxarm", V3(0.2, 0.2, 5.4), at(lift.X + s * 0.9, FLOOR + 0.6, lift.Z) * CFrame.Angles(rad(-8), 0, 0), C3(60, 60, 60), M.Metal, false)
	end
	local lt = box("Lyftbord", V3(2.6, 0.3, 8.6), at(lift.X, FLOOR + 0.9, lift.Z), C3(200, 36, 36), M.Metal)
	lt:SetAttribute("Interact", "lift")
	box("Gummi", V3(1.0, 0.04, 8.4), at(lift.X, FLOOR + 1.06, lift.Z), C3(25, 25, 27), M.Rubber, false)
	box("Hjulfäste", V3(1.0, 0.8, 0.3), at(lift.X, FLOOR + 1.4, lift.Z - 4.0), C3(60, 60, 60), M.Metal)
	local st = GarageBuilder.STAND
	local sx, sz = st.X, st.Z
	box("Stativfot", V3(0.4, 0.3, 4), at(sx - 1.3, FLOOR + 0.15, sz), C3(190, 30, 30), M.Metal)
	box("Stativfot", V3(0.4, 0.3, 4), at(sx + 1.3, FLOOR + 0.15, sz), C3(190, 30, 30), M.Metal)
	box("Stativfot", V3(3, 0.3, 0.4), at(sx, FLOOR + 0.15, sz + 1), C3(190, 30, 30), M.Metal)
	for _, s in ipairs({ -1, 1 }) do for _, t in ipairs({ -1.8, 1.8 }) do mk.cyl("Hjul", 0.2, 0.16, at(sx + s * 1.3, FLOOR + 0.16, sz + t), C3(20, 20, 20), M.Rubber) end end
	local post = box("Motorstativ", V3(0.4, 3.2, 0.4), at(sx, FLOOR + 1.9, sz + 1), C3(190, 30, 30), M.Metal)
	post:SetAttribute("Interact", "stand")
	box("Arm", V3(0.3, 0.3, 1.3), at(sx, FLOOR + 3.4, sz + 0.5), C3(190, 30, 30), M.Metal)
	mk.cyl("Fäste", 0.15, 0.5, at(sx, st.Y, sz - 0.15) * CFrame.Angles(0, rad(90), 0), C3(80, 80, 84), M.Metal)

	---------------------------------------------------------------- decor
	for i = 0, 2 do mk.cyl("Däck", 0.7, 1.2, at(hw - 2, FLOOR + 0.35 + i * 0.72, 5) * CFrame.Angles(0, 0, rad(90)), C3(24, 24, 26), M.Rubber).CanCollide = true end
	mk.cyl("Oljefat", 2.8, 0.9, at(hw - 2, FLOOR + 1.4, 1.5) * CFrame.Angles(0, 0, rad(90)), C3(30, 80, 160), M.Metal).CanCollide = true
	mk.cyl("Brandsläckare", 1.4, 0.3, at(-8, FLOOR + 2.2, -hd + 0.45) * CFrame.Angles(0, 0, rad(90)), red, M.SmoothPlastic)
	mk.cyl("Klocka", 0.1, 0.7, at(0, FLOOR + 11.5, hd - 0.3) * CFrame.Angles(0, rad(90), 0), C3(245, 245, 245), M.SmoothPlastic)
	local poster = box("Affisch", V3(0.05, 3.2, 2.4), at(hw - 0.2, FLOOR + 7, 9), C3(20, 20, 24), M.SmoothPlastic, false)
	sign(model, poster, Enum.NormalId.Left, "FARTEK\nRACING", C3(220, 40, 40))
	local poster2 = box("Affisch", V3(0.05, 3.2, 2.4), at(hw - 0.2, FLOOR + 7, 13), C3(240, 196, 30), M.SmoothPlastic, false)
	sign(model, poster2, Enum.NormalId.Left, "NORDTRIM\nSPORT", C3(20, 20, 24))

	---------------------------------------------------------------- outside: sign, driveway, delivery spot
	local nameBoard = box("Namnskylt", V3(16, 2.4, 0.3), at(0, FLOOR + H - 1.6, -hd - 1.15), C3(20, 22, 28), M.SmoothPlastic, false)
	refs.nameLabel = sign(model, nameBoard, Enum.NormalId.Front, "LEDIGT GARAGE", C3(255, 255, 255))
	local numBoard = box("Nummer", V3(2, 2, 0.3), at(-hw + 2, FLOOR + H - 1.6, -hd - 1.15), C3(240, 196, 30), M.SmoothPlastic, false)
	sign(model, numBoard, Enum.NormalId.Front, tostring(plotIndex), C3(20, 20, 20))
	for _, s in ipairs({ -1, 1 }) do
		local lamp = box("Vägglampa", V3(0.8, 0.5, 0.6), at(s * 9.5, FLOOR + 10.5, -hd - 1.3), C3(255, 240, 200), M.Neon, false)
		local l = Instance.new("SpotLight")
		l.Face = Enum.NormalId.Bottom
		l.Range = 18
		l.Brightness = 1.2
		l.Angle = 100
		l.Parent = lamp
	end
	box("Uppfart", V3(16, 0.2, 10), at(0, -0.04, -hd - 5), C3(70, 70, 72), M.Asphalt)
	box("Leveransplats", V3(5, 0.03, 4), at(12, 0.08, -hd - 4.5), C3(240, 196, 30), M.SmoothPlastic, false).Transparency = 0.3
	for i = 1, 4 do refs.deliverySlots[i] = at(10.8 + ((i - 1) % 2) * 2.4, 0.1, -hd - 3.6 - math.floor((i - 1) / 2) * 2.0) end
	-- invisible wall above the roof edge so nobody climbs onto the roof by accident: not needed (roof is high)
	model.Parent = parent
	refs.model = model
	return refs
end

return GarageBuilder

-- Builds the mopeds and the shop's part previews from Roblox parts.
-- Dimensions are written in metres and converted to studs (Config.STUD). Forward = -Z (Roblox LookVector), up = +Y, right = +X.
local Config = require(script.Parent.Config)
local Builder = {}
local S = 1 / Config.STUD -- studs per metre

local MAT = {
	paint = Enum.Material.SmoothPlastic, metal = Enum.Material.Metal, chrome = Enum.Material.Metal, rubber = Enum.Material.SmoothPlastic,
	plastic = Enum.Material.SmoothPlastic, neon = Enum.Material.Neon, glass = Enum.Material.Glass, alu = Enum.Material.DiamondPlate, fabric = Enum.Material.Fabric,
}
local C = {
	tire = Color3.fromRGB(22, 23, 25), dark = Color3.fromRGB(35, 37, 41), black = Color3.fromRGB(18, 18, 20), chrome = Color3.fromRGB(235, 238, 242),
	alu = Color3.fromRGB(190, 195, 202), eng = Color3.fromRGB(150, 155, 162), white = Color3.fromRGB(240, 240, 236), lamp = Color3.fromRGB(255, 238, 190),
	red = Color3.fromRGB(190, 25, 35), amber = Color3.fromRGB(255, 154, 26), carbon = Color3.fromRGB(30, 32, 36), gold = Color3.fromRGB(212, 168, 58),
}
Builder.C = C

-- small helper that adds parts to a model, welded to a root
local function maker(model, root)
	local K = {}
	function K.part(name, shape, sizeM, cf, color, material, refl)
		local p = Instance.new("Part")
		p.Name = name
		if shape == "cyl" then p.Shape = Enum.PartType.Cylinder elseif shape == "ball" then p.Shape = Enum.PartType.Ball end
		p.Size = Vector3.new(math.max(0.05, sizeM.X * S), math.max(0.05, sizeM.Y * S), math.max(0.05, sizeM.Z * S))
		p.CFrame = cf
		p.Color = color
		p.Material = material or MAT.plastic
		p.Reflectance = refl or 0
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.Anchored = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		if root then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = root, p
			w.Parent = p
		end
		return p
	end
	function K.wedge(name, sizeM, cf, color, material, refl)
		local p = K.part(name, "box", sizeM, cf, color, material, refl)
		local w = Instance.new("WedgePart")
		for _, prop in ipairs({ "Name", "Size", "CFrame", "Color", "Material", "Reflectance", "CanCollide", "CanTouch", "CanQuery", "Massless", "Anchored" }) do w[prop] = p[prop] end
		w.Parent = model
		p:Destroy()
		if root then local wc = Instance.new("WeldConstraint"); wc.Part0, wc.Part1 = root, w; wc.Parent = w end
		return w
	end
	-- metre coordinates (x right, y up, z forward like the web version) -> CFrame in the model's space
	function K.at(x, y, z) return CFrame.new(x * S, y * S, -z * S) end
	-- tube (cylinder) between two points in metres
	function K.tube(name, a, b, r, color, material, refl)
		local A, B = Vector3.new(a[1] * S, a[2] * S, -a[3] * S), Vector3.new(b[1] * S, b[2] * S, -b[3] * S)
		local len = (B - A).Magnitude / S
		if len < 0.001 then return nil end
		local cf = CFrame.lookAt((A + B) / 2, B) * CFrame.Angles(0, math.pi / 2, 0)
		return K.part(name, "cyl", Vector3.new(len, r * 2, r * 2), cf, color, material, refl)
	end
	function K.box(name, w, h, d, x, y, z, color, material, refl, rx)
		return K.part(name, "box", Vector3.new(w, h, d), K.at(x, y, z) * CFrame.Angles(rx or 0, 0, 0), color, material, refl)
	end
	return K
end
Builder.maker = maker

local function rimLook(E, rimColor)
	if E.rims == "pol" then return C.chrome, MAT.chrome, 0.45 end
	if E.rims == "gold" then return C.gold, MAT.metal, 0.25 end
	return rimColor, MAT.metal, 0.1
end

-- wheel: tyre (collides with the ground) + rim + hub. Returns the tyre (collision) and a spinning group part.
local function wheel(K, name, wr, z, width, E, look)
	local tyre = K.part(name, "cyl", Vector3.new(width, wr * 2, wr * 2), K.at(0, wr, z), C.tire, MAT.rubber)
	tyre.CanCollide = true
	tyre.CanQuery = true
	tyre.Massless = false
	tyre.CustomPhysicalProperties = PhysicalProperties.new(1, 0.05, 0, 1, 1) -- slides on the ground, the controller decides speed
	local rc, rm, rr = rimLook(E, look.rim or C.alu)
	K.part(name .. "Rim", "cyl", Vector3.new(width * 1.05, wr * 1.25, wr * 1.25), K.at(0, wr, z), rc, rm, rr)
	K.part(name .. "Hub", "cyl", Vector3.new(width * 1.2, wr * 0.35, wr * 0.35), K.at(0, wr, z), C.alu, MAT.metal, 0.2)
	-- spokes as a separate part the client rotates (visual only)
	local sp = K.part(name .. "Spokes", "box", Vector3.new(width * 1.1, wr * 1.15, 0.03), K.at(0, wr, z), rc, rm, rr)
	K.part(name .. "Spokes2", "box", Vector3.new(width * 1.1, 0.03, wr * 1.15), K.at(0, wr, z), rc, rm, rr)
	return tyre, sp
end

local function paintMat(look)
	local f = look.fin or "gloss"
	if f == "matt" then return MAT.plastic, 0 elseif f == "metal" then return MAT.metal, 0.2 end
	return MAT.paint, 0.12
end

-- E: effective config (Catalog.ecfg), look: { col, seat, rim, fin, num }
function Builder.moped(mop, E, look)
	local model = Instance.new("Model")
	model.Name = "Moped_" .. mop.id
	local wr, wb = mop.wr, mop.wb
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.35 * S, 0.3 * S, wb * 0.8 * S)
	root.CFrame = CFrame.new(0, (wr + 0.15) * S, 0)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CustomPhysicalProperties = PhysicalProperties.new(2, 0.3, 0, 1, 1)
	root.Parent = model
	model.PrimaryPart = root
	local K = maker(model, root)
	local pm, pr = paintMat(look)
	local body, seatC = look.col, look.seat
	local z0 = wb / 2
	local fw, fsp = wheel(K, "FW", wr, z0, mop.id == "dt" and 0.09 or 0.11, E, look)
	local rw, rsp = wheel(K, "RW", wr, -z0, mop.id == "dt" and 0.1 or 0.12, E, look)
	local exh = Config.EXH[E.exh + 1]
	local seatY
	if mop.id == "dt" then
		-- enduro: frame, raked fork, tank, long seat, high fenders, finned cylinder, expansion chamber
		K.tube("Frame1", { 0, 0.98, 0.43 }, { 0, 0.84, -0.25 }, 0.024, C.dark, MAT.metal, 0.1)
		K.tube("Frame2", { 0, 0.82, 0.47 }, { 0, 0.3, 0.1 }, 0.022, C.dark, MAT.metal, 0.1)
		K.tube("Frame3", { 0, 0.3, 0.1 }, { 0, 0.32, -0.15 }, 0.022, C.dark, MAT.metal, 0.1)
		for _, s in ipairs({ -1, 1 }) do
			K.tube("Rail", { s * 0.08, 0.82, -0.25 }, { s * 0.1, 0.74, -0.75 }, 0.014, C.dark, MAT.metal, 0.1)
			K.tube("Strut", { s * 0.07, 0.32, -0.15 }, { s * 0.1, 0.74, -0.6 }, 0.013, C.dark, MAT.metal, 0.1)
			K.tube("ForkUp", { s * 0.075, 1.02, 0.4 }, { s * 0.075, 0.62, 0.56 }, 0.022, C.chrome, MAT.chrome, 0.4)
			K.tube("ForkLo", { s * 0.075, 0.66, 0.545 }, { s * 0.075, wr, z0 }, 0.028, C.black, MAT.plastic)
			K.tube("Swing", { s * 0.08, 0.3, -0.18 }, { s * 0.08, wr, -z0 }, 0.018, C.dark, MAT.metal, 0.1)
			K.tube("Shock", { s * 0.09, 0.3, -0.5 }, { s * 0.1, 0.78, -0.52 }, 0.022, Color3.fromRGB(216, 180, 30), MAT.metal, 0.1)
		end
		if E.tank ~= "none" then
			local tc = E.tank == "carbon" and C.carbon or body
			K.box("Tank", 0.26, 0.16, 0.42, 0, 0.9, 0.13, tc, pm, pr, math.rad(-9))
			K.box("TankTop", 0.2, 0.05, 0.3, 0, 0.98, 0.12, tc, pm, pr, math.rad(-9))
		end
		K.box("Seat", 0.22, 0.08, 0.62, 0, 0.9, -0.36, seatC, MAT.fabric, 0, math.rad(3))
		seatY = 0.95
		for _, s in ipairs({ -1, 1 }) do K.box("SidePanel", 0.01, 0.17, 0.22, s * 0.115, 0.74, -0.3, C.white, MAT.plastic) end
		if E.fender ~= "none" then
			local fc = E.fender == "carbon" and C.carbon or E.fender == "chrome" and C.chrome or C.white
			K.box("FrontFender", 0.11, 0.02, 0.42, 0, wr * 2 + 0.06, z0 + 0.05, fc, MAT.plastic, E.fender == "chrome" and 0.4 or 0, math.rad(-8))
		end
		K.box("RearFender", 0.13, 0.02, 0.5, 0, 0.88, -0.86, C.white, MAT.plastic, 0, math.rad(12))
		K.box("TailLight", 0.12, 0.05, 0.03, 0, 0.92, -1.08, C.red, MAT.neon)
		-- engine
		K.box("Crankcase", 0.2, 0.2, 0.3, 0, 0.3, 0, C.eng, MAT.metal, 0.1)
		for i = 0, 6 do K.box("Fin", 0.19, 0.012, 0.17, 0, 0.42 + i * 0.028, 0.1 + i * 0.01, C.alu, MAT.metal, 0.1, math.rad(20)) end
		-- expansion chamber
		local R = 0.035 + exh.l * 0.035
		K.tube("ExhA", { 0, 0.47, 0.22 }, { 0.02, 0.3, 0.32 }, 0.022, exh.col, MAT.metal, 0.3)
		K.tube("ExhB", { 0.02, 0.3, 0.32 }, { 0.1, 0.2, 0.15 }, R * 0.8, exh.col, MAT.metal, 0.3)
		K.tube("ExhC", { 0.1, 0.2, 0.15 }, { 0.15, 0.4, -0.3 }, R, exh.col, MAT.metal, 0.3)
		K.tube("ExhD", { 0.15, 0.4, -0.3 }, { 0.15, 0.6, -0.55 }, R * 0.6, exh.col, MAT.metal, 0.3)
		K.tube("Silencer", { 0.15, 0.6, -0.55 }, { 0.15, 0.7, -0.8 }, 0.03, C.black, MAT.metal)
		-- handlebar, mirrors, headlight
		local hb = E.bars == "high"
		local by, bw = 1.08 + (hb and 0.07 or 0), hb and 0.74 or 0.64
		K.tube("Bar", { -bw / 2, by, 0.38 }, { bw / 2, by, 0.38 }, 0.011, hb and C.alu or C.black, MAT.metal, 0.1)
		if E.mir ~= "none" then
			for _, s in ipairs({ -1, 1 }) do
				K.tube("MirStalk", { s * bw * 0.38, by, 0.38 }, { s * bw * 0.42, by + 0.24, 0.36 }, 0.006, C.black, MAT.metal)
				K.part("Mirror", "ball", Vector3.new(0.09, 0.07, 0.09), K.at(s * bw * 0.43, by + 0.27, 0.35), E.mir == "round" and C.chrome or C.black, MAT.metal, E.mir == "round" and 0.5 or 0)
			end
		end
		K.box("LampPlate", 0.22, 0.24, 0.04, 0, 0.9, 0.55, C.white, MAT.plastic, 0, math.rad(-25))
		K.part("Headlight", "cyl", Vector3.new(0.05, 0.14, 0.14), K.at(0, 0.9, 0.575) * CFrame.Angles(0, math.pi / 2, 0), E.glass == "tint" and C.dark or C.lamp, E.glass == "tint" and MAT.glass or MAT.neon)
	else
		-- scooters (Jogga: round classic, Aerox: low sporty)
		local sport = mop.id == "rok"
		local s = wb / 1.2
		for _, x in ipairs({ -1, 1 }) do
			K.tube("Fork", { x * 0.07, wr, z0 }, { x * 0.07, 0.75, 0.42 * s }, 0.022, C.dark, MAT.metal, 0.1)
		end
		K.box("Floor", 0.38, 0.06, 0.55 * s, 0, 0.25, 0.08 * s, C.dark, MAT.plastic)
		K.box("LegShield", 0.4, 0.62, 0.12, 0, 0.6, 0.42 * s, body, pm, pr, math.rad(sport and 18 or 10))
		if sport then
			K.wedge("Nose", Vector3.new(0.36, 0.3, 0.45), K.at(0, 0.95, 0.52 * s) * CFrame.Angles(0, math.pi, 0), body, pm, pr)
			for _, x in ipairs({ -1, 1 }) do K.part("Lamp", "ball", Vector3.new(0.08, 0.06, 0.08), K.at(x * 0.08, 0.92, 0.66 * s), E.glass == "tint" and C.dark or C.lamp, E.glass == "tint" and MAT.glass or MAT.neon) end
		else
			K.box("Headset", 0.3, 0.18, 0.22, 0, 1.0, 0.45 * s, body, pm, pr)
			K.part("Lamp", "ball", Vector3.new(0.13, 0.1, 0.06), K.at(0, 0.98, 0.57 * s), E.glass == "tint" and C.dark or C.lamp, E.glass == "tint" and MAT.glass or MAT.neon)
		end
		K.box("RearBody", 0.34, sport and 0.24 or 0.3, 0.6 * s, 0, sport and 0.55 or 0.5, -0.33 * s, body, pm, pr)
		if sport then K.wedge("Tail", Vector3.new(0.3, 0.16, 0.3), K.at(0, 0.62, -0.72 * s), body, pm, pr) end
		K.box("Seat", 0.28, 0.1, 0.6 * s, 0, sport and 0.72 or 0.7, -0.3 * s, seatC, MAT.fabric, 0, math.rad(-3))
		seatY = sport and 0.77 or 0.75
		K.tube("Bar", { -0.33, 1.07, 0.38 * s }, { 0.33, 1.07, 0.38 * s }, 0.013, C.chrome, MAT.chrome, 0.4)
		if E.fender ~= "none" and not sport then
			local fc = E.fender == "carbon" and C.carbon or E.fender == "chrome" and C.chrome or body
			K.box("FrontFender", 0.14, 0.03, 0.34, 0, wr * 2 + 0.04, z0, fc, E.fender == "chrome" and MAT.chrome or pm, E.fender == "chrome" and 0.45 or pr, math.rad(-5))
		end
		if E.mir ~= "none" then
			for _, x in ipairs({ -1, 1 }) do
				K.tube("MirStalk", { x * 0.27, 1.08, 0.38 * s }, { x * 0.3, 1.28, 0.34 * s }, 0.007, E.mir == "round" and C.chrome or C.black, MAT.metal)
				K.part("Mirror", "ball", Vector3.new(0.1, 0.07, 0.05), K.at(x * 0.3, 1.3, 0.33 * s), E.mir == "round" and C.chrome or C.black, MAT.metal, E.mir == "round" and 0.5 or 0)
			end
		end
		K.box("Engine", 0.16, 0.18, 0.55 * s, 0.05, 0.24, -0.34 * s, C.dark, MAT.metal)
		K.part("VarCover", "cyl", Vector3.new(0.08, 0.26, 0.26), K.at(0.17, 0.26, -0.2 * s), C.alu, MAT.metal, 0.15)
		local L = 0.7 + exh.l * 0.5
		K.tube("Exhaust", { 0.19, 0.15, 0.04 }, { 0.2, 0.22, 0.04 - L }, 0.05 + exh.l * 0.02, exh.col, MAT.metal, 0.3)
		K.box("TailLight", 0.14, 0.05, 0.04, 0, sport and 0.6 or 0.5, -0.66 * s, C.red, MAT.neon)
	end
	-- start number decals on both sides
	for _, sx in ipairs({ -1, 1 }) do
		local plate = K.part("NumPlate", "box", Vector3.new(0.005, 0.15, 0.15), K.at(sx * (mop.id == "dt" and 0.135 or 0.175), mop.id == "dt" and 0.74 or 0.45, mop.id == "dt" and -0.3 or -0.36), C.white, MAT.plastic)
		local gui = Instance.new("SurfaceGui")
		gui.Face = sx > 0 and Enum.NormalId.Right or Enum.NormalId.Left
		gui.CanvasSize = Vector2.new(100, 100)
		gui.Parent = plate
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = look.num or ""
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = Color3.new(0.07, 0.07, 0.07)
		t.Parent = gui
	end
	-- seat for the rider
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(0.3 * S, 0.1 * S, 0.4 * S)
	seat.CFrame = CFrame.new(0, seatY * S, -0.3 * (wb / 1.2) * S)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Massless = true
	seat.Parent = model
	local sw = Instance.new("WeldConstraint"); sw.Part0, sw.Part1 = root, seat; sw.Parent = seat
	-- references for the client
	local refs = Instance.new("Folder"); refs.Name = "Refs"; refs.Parent = model
	for name, p in pairs({ FW = fw, RW = rw, FSpokes = fsp, RSpokes = rsp }) do
		local o = Instance.new("ObjectValue"); o.Name = name; o.Value = p; o.Parent = refs
	end
	return model
end

-- 3D preview of a part for the shop (ViewportFrame). Returns a Model centred around origin.
function Builder.preview(slot, val)
	local model = Instance.new("Model")
	local K = maker(model, nil)
	val = val or {}
	if slot == "kit" then
		local t = val.kit or 0
		local col = ({ C.eng, Color3.fromRGB(200, 205, 212), Color3.fromRGB(40, 42, 46) })[t + 1]
		K.part("Body", "cyl", Vector3.new(0.6, 0.4, 0.4), K.at(0, 0, 0) * CFrame.Angles(0, 0, math.pi / 2), col, MAT.metal, 0.1)
		for i = 0, 7 do K.box("Fin", 0.56, 0.02, 0.56, 0, -0.24 + i * 0.07, 0, col, MAT.metal, 0.1) end
		K.part("Head", "cyl", Vector3.new(0.1, 0.46, 0.46), K.at(0, 0.36, 0) * CFrame.Angles(0, 0, math.pi / 2), t == 2 and C.red or col, MAT.metal, 0.1)
	elseif slot == "exh" then
		local e = Config.EXH[(val.exh or 0) + 1]
		if (val.exh or 0) == 0 then
			K.part("Can", "cyl", Vector3.new(0.75, 0.28, 0.28), CFrame.new(), e.col, MAT.metal, 0.2)
		else
			local L = 1.2 + e.l * 0.5
			K.tube("A", { -L / 2, 0, 0 }, { -L / 6, 0, 0 }, 0.05, e.col, MAT.metal, 0.3)
			K.tube("B", { -L / 6, 0, 0 }, { L / 6, 0, 0 }, 0.12 + e.l * 0.05, e.col, MAT.metal, 0.3)
			K.tube("C", { L / 6, 0, 0 }, { L / 2, 0, 0 }, 0.05, e.col, MAT.metal, 0.3)
		end
	elseif slot == "carb" then
		local d = (({ 12, 17.5, 19, 21, 24 })[(val.carb or 0) + 1]) / 17.5
		K.box("Body", 0.32 * d, 0.3 * d, 0.28 * d, 0, 0, 0, C.alu, MAT.metal, 0.1)
		K.part("Mouth", "cyl", Vector3.new(0.24 * d, 0.24 * d, 0.24 * d), K.at(0, 0, 0.26 * d) * CFrame.Angles(0, math.pi / 2, 0), C.alu, MAT.metal, 0.1)
		K.part("Bowl", "cyl", Vector3.new(0.16 * d, 0.26 * d, 0.26 * d), K.at(0, -0.22 * d, 0) * CFrame.Angles(0, 0, math.pi / 2), C.alu, MAT.metal, 0.1)
	elseif slot == "jets" then
		K.box("Tray", 0.95, 0.05, 0.4, 0, -0.05, 0, C.black, MAT.plastic)
		for i = 0, 5 do K.part("Jet", "cyl", Vector3.new(0.12, 0.06, 0.06), K.at(-0.38 + i * 0.152, 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2), C.gold, MAT.metal, 0.3) end
	elseif slot == "man" then
		local r = (val.maxd or 19) > 19 and 0.08 or 0.058
		K.tube("Pipe", { -0.4, 0, 0 }, { 0.35, 0.22, 0 }, r, C.black, MAT.plastic)
		K.box("Flange", 0.05, 0.28, 0.32, -0.42, 0, 0, C.alu, MAT.metal, 0.1)
	elseif slot == "filt" then
		if (val.fcap or 1) > 1 then K.part("Cone", "cyl", Vector3.new(0.36, 0.4, 0.4), CFrame.new(), C.red, MAT.fabric)
		else K.box("Box", 0.5, 0.28, 0.3, 0, 0, 0, C.black, MAT.plastic) end
	elseif slot == "ign" then
		K.box("Cdi", 0.36, 0.12, 0.26, 0, 0, 0, (val.icap or 11000) > 11000 and C.red or C.black, MAT.plastic)
		K.part("Coil", "cyl", Vector3.new(0.22, 0.14, 0.14), K.at(0.38, 0.02, 0) * CFrame.Angles(0, 0, math.pi / 2), C.dark, MAT.plastic)
	elseif slot == "cool" then
		local big = (val.cf or 1) > 1
		K.box("Core", big and 0.72 or 0.56, 0.46, 0.05, 0, 0, 0, C.alu, MAT.alu, 0.1)
		for i = 0, (big and 8 or 5) do K.box("Fin", (big and 0.72 or 0.56), 0.012, 0.08, 0, -0.2 + i * 0.05, 0, C.alu, MAT.metal, 0.1) end
	elseif slot == "var" then
		local col = (val.rmin or 0.85) < 0.75 and C.gold or (val.rmin or 0.85) < 0.8 and Color3.fromRGB(58, 111, 216) or C.alu
		K.part("Disc", "cyl", Vector3.new(0.1, 0.68, 0.68), K.at(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), col, MAT.metal, 0.2)
		K.part("Hub", "cyl", Vector3.new(0.24, 0.1, 0.1), K.at(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), C.chrome, MAT.chrome, 0.4)
	elseif slot == "roll" then
		local col = (val.rlo or 7) < 5 and C.white or (val.rlo or 7) > 10 and C.gold or C.black
		for i = 0, 5 do local a = i * math.pi / 3; K.part("Roller", "cyl", Vector3.new(0.11, 0.17, 0.17), K.at(math.cos(a) * 0.27, 0, math.sin(a) * 0.27), col, MAT.plastic) end
	elseif slot == "clutch" or slot == "contra" then
		local hard = slot == "clutch" and (val.slip or 7500) or (7500 + (val.cdt or 0) * 4)
		local col = hard > 9500 and C.red or hard > 8000 and Color3.fromRGB(240, 196, 25) or (slot == "contra" and C.dark or C.chrome)
		local n, r = slot == "clutch" and 3 or 1, slot == "clutch" and 0.06 or 0.22
		for k = 1, n do for i = 0, 7 do K.part("Coil", "cyl", Vector3.new(0.02, r * 2, r * 2), K.at(-0.22 * (n - 1) / 2 + (k - 1) * 0.22, -0.3 + i * 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2), col, MAT.metal, 0.2) end end
	elseif slot == "belt" then
		for i = 0, 23 do local a = i / 24 * math.pi * 2; K.box("Seg", 0.08, 0.04, 0.06, math.cos(a) * 0.5, math.sin(a) * 0.2, 0, (val.blim or 7) > 7 and Color3.fromRGB(232, 118, 44) or C.black, MAT.rubber) end
	elseif slot == "fender" or slot == "tank" then
		local v = val.fender or val.tank
		local col = v == "carbon" and C.carbon or v == "chrome" and C.chrome or C.red
		if slot == "tank" then K.box("Tank", 0.46, 0.28, 0.72, 0, 0, 0, col, MAT.paint, 0.12)
		else K.wedge("Fender", Vector3.new(0.3, 0.2, 0.7), CFrame.new(), col, v == "chrome" and MAT.chrome or MAT.paint, v == "chrome" and 0.45 or 0.12) end
	elseif slot == "mir" then
		for _, x in ipairs({ -1, 1 }) do
			K.tube("Stalk", { x * 0.2, -0.2, 0 }, { x * 0.32, 0.22, 0 }, 0.012, C.dark, MAT.metal)
			K.part("Head", "ball", Vector3.new(0.22, 0.16, 0.1), K.at(x * 0.34, 0.3, 0), val.mir == "round" and C.chrome or C.dark, MAT.metal, val.mir == "round" and 0.5 or 0)
		end
	elseif slot == "bars" then
		local hi = val.bars == "high"
		K.tube("Bar", { -0.5, hi and 0.2 or 0.05, 0 }, { 0.5, hi and 0.2 or 0.05, 0 }, 0.022, hi and C.alu or C.dark, MAT.metal, 0.2)
		if hi then K.tube("Brace", { -0.2, 0.1, 0 }, { 0.2, 0.1, 0 }, 0.012, C.alu, MAT.metal, 0.2) end
	elseif slot == "rims" then
		local rc, rm, rr = rimLook(val, C.alu)
		K.part("Tyre", "cyl", Vector3.new(0.16, 0.92, 0.92), K.at(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), C.tire, MAT.rubber)
		K.part("Rim", "cyl", Vector3.new(0.17, 0.62, 0.62), K.at(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), rc, rm, rr)
	elseif slot == "glass" then
		K.part("Lens", "ball", Vector3.new(0.5, 0.5, 0.3), CFrame.new(), val.glass == "tint" and C.dark or C.lamp, val.glass == "tint" and MAT.glass or MAT.neon)
	else
		K.box("Box", 0.4, 0.4, 0.4, 0, 0, 0, C.dark, MAT.plastic)
	end
	return model
end

return Builder

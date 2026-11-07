-- 3D models built from Roblox parts: every part (as a loose item), the engine with parts at their mount points,
-- the moped from what is actually mounted, a hand with tools (first person). Sizes in metres -> studs.
-- Coordinates: x right, y up, z forward (z is flipped to Roblox's -Z = forward).
local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.Catalog)
local Panels = require(script.Parent.Panels)
local Assembly = require(script.Parent.Assembly)
local Builder = {}
local S = 1 / Config.STUD
Builder.S = S

local MAT = { paint = Enum.Material.SmoothPlastic, metal = Enum.Material.Metal, plastic = Enum.Material.SmoothPlastic, neon = Enum.Material.Neon,
	glass = Enum.Material.Glass, alu = Enum.Material.DiamondPlate, fabric = Enum.Material.Fabric, rust = Enum.Material.CorrodedMetal }
local C = {
	tire = Color3.fromRGB(22, 23, 25), dark = Color3.fromRGB(35, 37, 41), black = Color3.fromRGB(18, 18, 20), chrome = Color3.fromRGB(235, 238, 242),
	alu = Color3.fromRGB(190, 195, 202), cast = Color3.fromRGB(150, 155, 162), white = Color3.fromRGB(240, 240, 236), lamp = Color3.fromRGB(255, 238, 190),
	red = Color3.fromRGB(190, 25, 35), carbon = Color3.fromRGB(30, 32, 36), gold = Color3.fromRGB(212, 168, 58), brass = Color3.fromRGB(205, 165, 75),
	copper = Color3.fromRGB(184, 115, 51), yellow = Color3.fromRGB(240, 196, 25), skin = Color3.fromRGB(234, 192, 160), glove = Color3.fromRGB(40, 42, 46),
}
Builder.C, Builder.MAT = C, MAT

local function hexColor(h) if type(h) == "string" and h:match("^#%x%x%x%x%x%x$") then return Color3.fromHex(h) end return C.cast end

-- part factory: parts in model, optionally welded to root
local function maker(model, root)
	local K = {}
	function K.part(name, shape, sizeM, cf, color, material, refl)
		local p = Instance.new("Part")
		p.Name = name
		if shape == "cyl" then p.Shape = Enum.PartType.Cylinder elseif shape == "ball" then p.Shape = Enum.PartType.Ball end
		p.Size = Vector3.new(math.max(0.02, sizeM.X * S), math.max(0.02, sizeM.Y * S), math.max(0.02, sizeM.Z * S))
		p.CFrame = cf
		p.Color = color
		p.Material = material or MAT.plastic
		p.Reflectance = refl or 0
		p.CanCollide, p.CanTouch, p.Massless, p.Anchored = false, false, true, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		if root then local w = Instance.new("WeldConstraint"); w.Part0, w.Part1 = root, p; w.Parent = p end
		return p
	end
	function K.wedge(name, sizeM, cf, color, material, refl)
		local w = Instance.new("WedgePart")
		w.Name, w.Size, w.CFrame, w.Color, w.Material, w.Reflectance = name, Vector3.new(sizeM.X * S, sizeM.Y * S, sizeM.Z * S), cf, color, material or MAT.plastic, refl or 0
		w.CanCollide, w.CanTouch, w.Massless, w.Anchored = false, false, true, false
		w.Parent = model
		if root then local wc = Instance.new("WeldConstraint"); wc.Part0, wc.Part1 = root, w; wc.Parent = w end
		return w
	end
	function K.at(x, y, z) return CFrame.new(x * S, y * S, -z * S) end
	function K.tube(name, a, b, r, color, material, refl)
		local A, B = Vector3.new(a[1] * S, a[2] * S, -a[3] * S), Vector3.new(b[1] * S, b[2] * S, -b[3] * S)
		local len = (B - A).Magnitude / S
		if len < 0.001 then return nil end
		return K.part(name, "cyl", Vector3.new(len, r * 2, r * 2), CFrame.lookAt((A + B) / 2, B) * CFrame.Angles(0, math.pi / 2, 0), color, material, refl)
	end
	-- cylinder along an axis: "x" (default), "y" (vertical) or "z"
	function K.cyl(name, len, dia, x, y, z, axis, color, material, refl)
		local rot = axis == "y" and CFrame.Angles(0, 0, math.pi / 2) or axis == "z" and CFrame.Angles(0, math.pi / 2, 0) or CFrame.new()
		return K.part(name, "cyl", Vector3.new(len, dia, dia), K.at(x, y, z) * rot, color, material, refl)
	end
	function K.box(name, w, h, d, x, y, z, color, material, refl, rx, ry, rz)
		return K.part(name, "box", Vector3.new(w, h, d), K.at(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0)), color, material, refl)
	end
	function K.spin(name, sizeM, cf, color, material, refl)
		local p = K.part(name, "box", sizeM, cf, color, material, refl)
		for _, c in ipairs(p:GetChildren()) do if c:IsA("WeldConstraint") then c:Destroy() end end
		local w = Instance.new("Weld"); w.Name = "SpinWeld"; w.Part0, w.Part1 = root, p; w.C0 = root.CFrame:Inverse() * p.CFrame; w.Parent = p
		return w
	end
	function K.attach(name, x, y, z)
		local a = Instance.new("Attachment"); a.Name = name
		a.Position = root.CFrame:PointToObjectSpace(Vector3.new(x * S, y * S, -z * S)); a.Parent = root
		return a
	end
	return K
end
Builder.maker = maker

-- paint on a panel: colour + finish -> Roblox material/reflectance. Poor paint quality = duller surface.
function Builder.paintLook(paint, look)
	local L = Panels.LOOK[look or "std"] or {}
	if L.fixed == "carbon" then return C.carbon, MAT.paint, 0.18, 0 end
	if L.fixed == "chrome" then return C.chrome, MAT.metal, 0.5, 0 end
	if L.fixed == "clear" then return Color3.fromRGB(60, 66, 74), MAT.glass, 0.2, 0.45 end
	paint = paint or { col = "#bdbdbd", fin = "gloss", q = 1 }
	local q = paint.q or 1
	local col, f = hexColor(paint.col), paint.fin
	if f == "matt" then return col, MAT.plastic, 0, 0 end
	if f == "metal" then return col, MAT.metal, 0.12 * q, 0 end
	if f == "pearl" then return col:Lerp(Color3.new(1, 1, 1), 0.08), MAT.paint, 0.22 * q, 0 end
	if f == "chrome" then return col:Lerp(C.chrome, 0.5), MAT.metal, 0.45 * q, 0 end
	return col, MAT.paint, 0.14 * q, 0
end

local function rimLook(rims)
	if rims == "pol" then return C.chrome, MAT.metal, 0.45 end
	if rims == "gold" then return C.gold, MAT.metal, 0.25 end
	return C.alu, MAT.metal, 0.1
end

-- ---------- engine parts (centred around their mount point) ----------
local function enginePart(K, kind, v, x, y, z, item)
	local function c(name, len, dia, dx, dy, dz, axis, col, mat, refl) return K.cyl(name, len, dia, x + dx, y + dy, z + dz, axis, col, mat, refl) end
	local function b(name, w, h, d, dx, dy, dz, col, mat, refl) return K.box(name, w, h, d, x + dx, y + dy, z + dz, col, mat, refl) end
	if kind == "case" then
		b("CaseTop", 0.24, 0.12, 0.3, 0, 0.02, -0.03, C.cast, MAT.metal, 0.05)
		K.part("CaseBottom", "ball", Vector3.new(0.26, 0.16, 0.32), K.at(x, y - 0.05, z - 0.03), C.cast, MAT.metal, 0.05)
		b("CaseBolts", 0.245, 0.01, 0.2, 0, 0.08, -0.03, C.chrome, MAT.metal, 0.3)
	elseif kind == "bearing" then for _, s in ipairs({ -1, 1 }) do c("Bearing", 0.02, 0.06, s * 0.11, 0, 0, "x", C.chrome, MAT.metal, 0.4) end
	elseif kind == "seal" then for _, s in ipairs({ -1, 1 }) do c("Seal", 0.01, 0.045, s * 0.135, 0, 0, "x", C.black, MAT.plastic) end
	elseif kind == "crank" then
		c("Shaft", 0.46, 0.022, 0, 0, 0, "x", C.chrome, MAT.metal, 0.35)
		for _, s in ipairs({ -1, 1 }) do c("Web", 0.025, 0.15, s * 0.035, 0, 0, "x", v.crankf and v.crankf > 1 and C.gold or C.cast, MAT.metal, 0.2) end
		b("Conrod", 0.018, 0.1, 0.025, 0, 0.04, 0, C.chrome, MAT.metal, 0.3)
	elseif kind == "needle" then c("Needle", 0.024, 0.026, 0, 0, 0, "x", C.brass, MAT.metal, 0.3)
	elseif kind == "piston" then
		local d = v.bore and v.bore > 50 and 0.047 or 0.04
		c("Piston", 0.045, d, 0, 0, 0, "y", C.alu, MAT.metal, 0.25)
		c("Crown", 0.004, d * 0.95, 0, 0.024, 0, "y", C.cast, MAT.metal)
	elseif kind == "pin" then c("Pin", 0.046, 0.012, 0, 0, 0, "x", C.chrome, MAT.metal, 0.4)
	elseif kind == "rings" then
		local d = v.bore and v.bore > 50 and 0.048 or 0.041
		c("Ring1", 0.003, d, 0, 0.004, 0, "y", C.dark, MAT.metal); c("Ring2", 0.003, d, 0, -0.004, 0, "y", C.dark, MAT.metal)
	elseif kind == "gasket" then b("Gasket", 0.1, 0.003, 0.1, 0, 0, 0, Color3.fromRGB(120, 90, 60), MAT.fabric)
	elseif kind == "cyl" then
		local t = v.kit or 0
		local col = ({ C.cast, Color3.fromRGB(205, 210, 216), Color3.fromRGB(42, 44, 48) })[t + 1]
		c("Barrel", 0.13, 0.085, 0, 0, 0, "y", col, MAT.metal, 0.08)
		for i = 0, 6 do b("Fin", 0.15, 0.007, 0.15, 0, -0.055 + i * 0.018, 0, col, MAT.metal, 0.08) end
		b("ExPort", 0.04, 0.035, 0.05, 0, -0.02, 0.07, col, MAT.metal, 0.08)
		b("InPort", 0.04, 0.035, 0.04, 0, -0.03, -0.065, col, MAT.metal, 0.08)
		if item and item.port then b("PortGlint", 0.03, 0.025, 0.002, 0, -0.02, 0.097, Color3.fromRGB(230, 235, 240), MAT.metal, 0.6) end
	elseif kind == "head" then
		local big = v.cf and v.cf > 1
		b("Head", 0.14, 0.035, 0.14, 0, 0, 0, C.alu, MAT.metal, 0.12)
		for i = 0, (big and 4 or 2) do b("HeadFin", big and 0.17 or 0.14, 0.005, 0.14, 0, 0.022 + i * 0.012, 0, C.alu, MAT.metal, 0.12) end
	elseif kind == "plug" then c("Insulator", 0.035, 0.016, 0, 0.015, 0, "y", C.white, MAT.plastic); c("PlugNut", 0.015, 0.02, 0, -0.008, 0, "y", C.chrome, MAT.metal, 0.3)
	elseif kind == "reed" then b("Reed", 0.05, 0.05, 0.035, 0, 0, 0, v.reedf and v.reedf > 1 and C.carbon or C.dark, MAT.plastic, 0.05)
	elseif kind == "intake" then c("Intake", 0.07, (v.maxd or 19) > 19 and 0.045 or 0.035, 0, 0, 0, "z", C.black, MAT.plastic)
	elseif kind == "carb" then
		local d = (Config.CARB[(v.carb or 0) + 1] or 17.5) / 17.5
		b("CarbBody", 0.05 * d, 0.05 * d, 0.05 * d, 0, 0, 0, C.alu, MAT.metal, 0.12)
		c("Bell", 0.04, 0.035 * d, 0, 0, -0.04, "z", C.alu, MAT.metal, 0.12)
		c("Bowl", 0.03, 0.035 * d, 0, -0.035, 0, "y", C.alu, MAT.metal, 0.12)
		c("Slide", 0.03, 0.022, 0, 0.035, 0, "y", C.chrome, MAT.metal, 0.3)
	elseif kind == "filter" then
		if (v.fcap or 1) > 1 then c("Cone", 0.1, 0.08, 0, 0, -0.02, "z", C.red, MAT.fabric) else b("Airbox", 0.12, 0.08, 0.1, 0, 0, -0.02, C.black, MAT.plastic) end
	elseif kind == "hose" then K.tube("Hose", { x, y, z }, { x + 0.02, y + 0.1, z - 0.06 }, 0.004, Color3.fromRGB(220, 200, 120), MAT.glass, 0.1)
	elseif kind == "stator" then c("Stator", 0.02, 0.1, 0, 0, 0, "x", C.copper, MAT.metal, 0.2)
	elseif kind == "flywheel" then c("Flywheel", 0.03, 0.125, 0, 0, 0, "x", C.dark, MAT.metal, 0.1)
	elseif kind == "fan" then
		c("FanDisc", 0.012, 0.13, 0, 0, 0, "x", C.black, MAT.plastic)
		for i = 0, 7 do local a = i * math.pi / 4; K.part("Blade", "box", Vector3.new(0.02, 0.05, 0.008), K.at(x - 0.012, y + math.sin(a) * 0.04, z + math.cos(a) * 0.04) * CFrame.Angles(-a, 0, 0), C.black, MAT.plastic) end
	elseif kind == "coil" then b("Coil", 0.03, 0.045, 0.05, 0, 0, 0, C.black, MAT.plastic)
	elseif kind == "cdi" then b("Cdi", 0.06, 0.02, 0.045, 0, 0, 0, (v.icap or 11000) > 11000 and C.red or C.black, MAT.plastic)
	elseif kind == "cable" then K.tube("Cable", { x, y - 0.06, z - 0.06 }, { x, y + 0.06, z + 0.04 }, 0.004, C.black, MAT.plastic); c("Cap", 0.025, 0.018, 0, 0.065, 0.045, "y", C.red, MAT.plastic)
	elseif kind == "weights" then
		local col = (v.roller or 9) <= 7 and C.white or (v.roller or 9) >= 11 and C.brass or C.black
		for i = 0, 5 do local a = i * math.pi / 3; c("Roller", 0.013, 0.016, 0, math.sin(a) * 0.035, math.cos(a) * 0.035, "x", col, MAT.plastic) end
	elseif kind == "var" then
		local col = (v.rmin or 0.85) < 0.75 and C.gold or (v.rmin or 0.85) < 0.8 and Color3.fromRGB(58, 111, 216) or C.alu
		c("Variator", 0.02, 0.115, 0, 0, 0, "x", col, MAT.metal, 0.2); c("VarHub", 0.03, 0.03, 0.01, 0, 0, "x", C.chrome, MAT.metal, 0.4)
	elseif kind == "contra" then
		local col = (v.cdt or 0) >= 800 and C.red or (v.cdt or 0) >= 400 and C.yellow or C.dark
		for i = 0, 6 do c("Coil", 0.004, 0.05, -0.02 + i * 0.007, 0, 0, "x", col, MAT.metal, 0.1) end
	elseif kind == "pulley" then c("Pulley", 0.03, 0.1, 0, 0, 0, "x", C.alu, MAT.metal, 0.15)
	elseif kind == "belt" then
		for i = 0, 19 do local a = i / 20 * math.pi * 2; K.part("BeltSeg", "box", Vector3.new(0.018, 0.012, 0.035), K.at(x, y + math.sin(a) * 0.05, z + math.cos(a) * 0.2) * CFrame.Angles(-a, 0, 0), (v.blim or 7) > 7 and Color3.fromRGB(232, 118, 44) or C.black, MAT.plastic) end
	elseif kind == "clutch" then
		c("ClutchPlate", 0.02, 0.1, 0, 0, 0, "x", C.dark, MAT.metal)
		for i = 0, 2 do local a = i * 2 * math.pi / 3; b("Shoe", 0.02, 0.025, 0.04, 0.005, math.sin(a) * 0.035, math.cos(a) * 0.035, (v.slip or 7500) > 8000 and C.red or Color3.fromRGB(110, 90, 70), MAT.fabric) end
	elseif kind == "bell" then c("Bell", 0.03, 0.115, 0, 0, 0, "x", C.cast, MAT.metal, 0.2)
	elseif kind == "gearbox" then b("Gearbox", 0.12, 0.08, 0.12, 0, 0, 0, C.dark, MAT.metal)
	elseif kind == "plates" then for i = 0, 3 do c("Plate", 0.006, 0.1, i * 0.008, 0, 0, "x", i % 2 == 0 and C.dark or Color3.fromRGB(110, 90, 70), MAT.metal) end
	elseif kind == "sprocket" then c("Sprocket", 0.008, 0.05, 0, 0, 0, "x", C.dark, MAT.metal)
	end
end
Builder.enginePart = enginePart

-- the engine with all mounted parts. map: socket -> {sku, item}. Parts get the attributes Sock/Item (for interaction).
function Builder.engine(parent, originCF, mopId, map, anchored)
	local model = Instance.new("Model"); model.Name = "Engine"
	local root = Instance.new("Part"); root.Name = "EngineRoot"; root.Size = Vector3.new(0.2, 0.2, 0.2); root.Transparency = 1; root.CanCollide = false; root.CanQuery = false
	root.Anchored = anchored ~= false; root.CFrame = originCF; root.Parent = model
	model.PrimaryPart = root
	for _, s in ipairs(Assembly.engineSockets(mopId)) do
		local e = map[s.id]
		if e then
			local pr = Catalog.BY_SKU[e.sku]
			local sub = Instance.new("Model"); sub.Name = "Sock_" .. s.id; sub.Parent = model
			sub:SetAttribute("Sock", s.id); if e.item then sub:SetAttribute("Item", e.item) end
			local K = maker(sub, nil)
			enginePart(K, pr.kind, pr.val, s.pos[1], s.pos[2], s.pos[3], e.data)
			-- place first, weld afterwards (a WeldConstraint locks the offset when it is created)
			for _, p in ipairs(sub:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CFrame = originCF * p.CFrame
					p.CanQuery = true
					p.Anchored = anchored ~= false
					if anchored == false then local w = Instance.new("WeldConstraint"); w.Part0, w.Part1 = root, p; w.Parent = p end
				end
			end
		end
	end
	model.Parent = parent
	return model
end
-- world CFrame for a socket on an engine
function Builder.socketCF(originCF, sock) return originCF * CFrame.new(sock.pos[1] * S, sock.pos[2] * S, -sock.pos[3] * S) end

-- ---------- one loose part (on a shelf, the bench, in the hand, in the shop) ----------
-- returns a Model with a PrimaryPart "Main" (centre) and size info. item: {s, paint, port}
function Builder.item(sku, item)
	local pr = Catalog.BY_SKU[sku]
	local model = Instance.new("Model"); model.Name = pr and pr.name or sku
	local K = maker(model, nil)
	local v, kind = pr and pr.val or {}, pr and pr.kind or "?"
	if Catalog.KIND[kind] and Catalog.KIND[kind][2] ~= "Chassi" and kind ~= "panel" and kind ~= "tool" and kind ~= "exh" and kind ~= "radiator" then
		enginePart(K, kind, v, 0, 0, 0, item)
	elseif kind == "panel" then
		local mopId = pr.fits[1]
		local pd = Panels.find(mopId, v.panel)
		local col, mat, refl, tr = Builder.paintLook(item and item.paint, v.look)
		local L = Panels.LOOK[v.look] or {}
		local sc = L.scale or { 1, 1, 1 }
		local size = Vector3.new(pd.size[1] * sc[1], pd.size[2] * sc[2], pd.size[3] * sc[3])
		local p
		if pd.shape == "wedge" then p = K.wedge("Panel", size, CFrame.new(), col, mat, refl)
		else p = K.part("Panel", pd.shape == "ball" and "ball" or "box", size, CFrame.new(), col, mat, refl) end
		p.Transparency = tr
	elseif kind == "wheel" then
		local rc, rm, rr = rimLook(v.rims)
		K.cyl("Tyre", 0.11, 0.34, 0, 0, 0, "x", C.tire, MAT.plastic); K.cyl("Rim", 0.115, 0.22, 0, 0, 0, "x", rc, rm, rr)
	elseif kind == "brake" then K.cyl("Disc", 0.006, 0.2, 0, 0, 0, "x", C.alu, MAT.metal, 0.3); K.box("Caliper", 0.04, 0.05, 0.06, 0.02, 0.08, 0, C.red, MAT.metal)
	elseif kind == "fork" then for _, s in ipairs({ -1, 1 }) do K.cyl("Leg", 0.55, 0.035, s * 0.07, 0, 0, "y", v.upside and C.gold or C.alu, MAT.metal, 0.3) end; K.box("Yoke", 0.2, 0.03, 0.06, 0, 0.25, 0, C.dark, MAT.metal)
	elseif kind == "shock" then K.cyl("Body", 0.3, 0.03, 0, 0, 0, "y", C.dark, MAT.metal); for i = 0, 6 do K.cyl("Spring", 0.006, 0.05, 0, -0.1 + i * 0.03, 0, "y", pr.color == "red" and C.red or C.yellow, MAT.metal) end
	elseif kind == "bars" then K.tube("Bar", { -0.33, v.bars == "high" and 0.06 or 0, 0 }, { 0.33, v.bars == "high" and 0.06 or 0, 0 }, 0.012, C.dark, MAT.metal); for _, s in ipairs({ -1, 1 }) do K.cyl("Grip", 0.1, 0.034, s * 0.3, v.bars == "high" and 0.06 or 0, 0, "x", C.black, MAT.plastic) end
	elseif kind == "seat" then K.box("Seat", 0.28, 0.1, 0.6, 0, 0, 0, C.black, MAT.fabric)
	elseif kind == "tank" then K.box("Tank", 0.24, 0.15, 0.4, 0, 0, 0, C.cast, MAT.metal)
	elseif kind == "frame" then K.tube("Main", { 0, 0.3, 0.4 }, { 0, -0.1, 0 }, 0.025, C.dark, MAT.metal); K.tube("Back", { 0, -0.1, 0 }, { 0, 0.15, -0.6 }, 0.025, C.dark, MAT.metal)
	elseif kind == "exh" then
		local e = Config.EXH[(v.exh or 0) + 1]
		if (v.exh or 0) == 0 then K.cyl("Can", 0.5, 0.11, 0, 0, 0, "z", e.col, MAT.metal, 0.2) else
			local L = 0.8 + e.l * 0.3
			K.cyl("Header", L * 0.3, 0.04, 0, 0, L * 0.35, "z", e.col, MAT.metal, 0.3); K.cyl("Belly", L * 0.4, 0.09 + e.l * 0.03, 0, 0, 0, "z", e.col, MAT.metal, 0.3)
			K.cyl("Stinger", L * 0.3, 0.035, 0, 0, -L * 0.35, "z", e.col, MAT.metal, 0.3)
		end
	elseif kind == "radiator" then K.box("Core", (v.cf or 1) > 1 and 0.32 or 0.26, 0.2, 0.03, 0, 0, 0, C.alu, MAT.alu, 0.1)
	elseif kind == "tool" then Builder.toolModel(K, v.tool, v)
	else K.box("Box", 0.1, 0.1, 0.1, 0, 0, 0, C.dark, MAT.plastic) end
	local cf, size = model:GetBoundingBox()
	local main = Instance.new("Part"); main.Name = "Main"; main.Size = size + Vector3.new(0.05, 0.05, 0.05); main.CFrame = cf; main.Transparency = 1
	main.CanCollide, main.Massless = false, true; main.Parent = model
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= main then local w = Instance.new("WeldConstraint"); w.Part0, w.Part1 = main, p; w.Parent = p end
	end
	model.PrimaryPart = main
	return model
end

-- tools: grinder, spray gun, wrench set
function Builder.toolModel(K, tool, v)
	if tool == "grinder" then
		K.cyl("Body", 0.16, 0.045, 0, 0, 0, "z", (v and v.steady or 0.6) >= 1 and C.red or Color3.fromRGB(40, 110, 190), MAT.plastic)
		K.cyl("Collet", 0.03, 0.02, 0, 0, 0.095, "z", C.chrome, MAT.metal, 0.4)
		K.cyl("Bit", 0.025, 0.008, 0, 0, 0.12, "z", Color3.fromRGB(150, 150, 150), MAT.metal, 0.2)
		K.cyl("Cord", 0.06, 0.01, 0, 0, -0.11, "z", C.black, MAT.plastic)
	elseif tool == "spray" then
		K.box("GunBody", 0.03, 0.05, 0.12, 0, 0, 0, (v and v.even or 0.7) >= 1 and C.alu or C.cast, MAT.metal, 0.2)
		K.cyl("Cup", 0.08, 0.06, 0, 0.065, -0.02, "y", C.alu, MAT.metal, 0.2)
		K.cyl("Nozzle", 0.03, 0.015, 0, 0.005, 0.07, "z", C.chrome, MAT.metal, 0.4)
		K.box("Handle", 0.025, 0.09, 0.03, 0, -0.06, -0.03, C.black, MAT.plastic, 0, -15, 0, 0)
	else
		K.box("Case", 0.3, 0.06, 0.18, 0, 0, 0, C.red, MAT.plastic)
		for i = 0, 6 do K.cyl("Socket", 0.03, 0.015 + i * 0.002, -0.11 + i * 0.035, 0.035, 0.03, "y", C.chrome, MAT.metal, 0.4) end
	end
end

-- first-person hand (glove) with a tool in its grip. Returns the model; PrimaryPart = Grip (where the tool sits).
function Builder.hand(tool, v)
	local model = Instance.new("Model"); model.Name = "Hand"
	local grip = Instance.new("Part"); grip.Name = "Grip"; grip.Size = Vector3.new(0.1, 0.1, 0.1); grip.Transparency = 1; grip.CanCollide = false; grip.CanQuery = false; grip.Anchored = true
	grip.CFrame = CFrame.new(); grip.Parent = model
	local K = maker(model, grip)
	K.box("Palm", 0.085, 0.03, 0.1, 0, 0, -0.06, C.glove, MAT.fabric)
	for i = 0, 3 do
		local x = -0.03 + i * 0.02
		K.box("Finger" .. i, 0.017, 0.017, 0.05, x, 0.012, -0.005, C.glove, MAT.fabric, 0, 25, 0, 0)
		K.box("Tip" .. i, 0.016, 0.016, 0.03, x, 0.025, 0.02, C.glove, MAT.fabric, 0, 70, 0, 0)
	end
	K.box("Thumb", 0.02, 0.02, 0.05, -0.05, -0.005, -0.03, C.glove, MAT.fabric, 0, 0, 30, -20)
	K.cyl("Wrist", 0.08, 0.06, 0, -0.01, -0.13, "z", C.glove, MAT.fabric)
	K.cyl("Sleeve", 0.2, 0.075, 0, -0.015, -0.27, "z", Color3.fromRGB(30, 60, 110), MAT.fabric)
	if tool then Builder.toolModel(K, tool, v) end
	for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then p.CanQuery = false; p.CastShadow = false end end
	model.PrimaryPart = grip
	return model
end

-- ---------- moped from mounted parts ----------
-- view: { mopId, ch = {slot -> {sku, item, data}}, eng = {socket -> {...}} or nil (engine on the stand), num }
function Builder.moped(view)
	local mop = Config.BY_ID[view.mopId]
	local model = Instance.new("Model"); model.Name = "Moped_" .. mop.id
	local wr, wb, z0 = mop.wr, mop.wb, mop.wb / 2
	local s = wb / 1.2
	local root = Instance.new("Part"); root.Name = "Root"; root.Size = Vector3.new(0.35 * S, 0.3 * S, wb * 0.8 * S); root.CFrame = CFrame.new(0, (wr + 0.15) * S, 0)
	root.Transparency = 1; root.CanCollide = false; root.CanQuery = false
	root.CustomPhysicalProperties = PhysicalProperties.new(10, 0.3, 0, 1, 1); root.Parent = model
	model.PrimaryPart = root
	local K = maker(model, root)
	local ch = view.ch
	local isDt = mop.id == "dt"
	local function tag(inst, sock) inst:SetAttribute("Sock", sock); if ch[sock] and ch[sock].item then inst:SetAttribute("Item", ch[sock].item) end end
	local function group(sock) local g = Instance.new("Model"); g.Name = "Slot_" .. sock; g.Parent = model; tag(g, sock); return g end
	local function into(g, fn) local before = {}; for _, c in ipairs(model:GetChildren()) do before[c] = true end; fn(); for _, c in ipairs(model:GetChildren()) do if not before[c] and c:IsA("BasePart") then c.Parent = g; c.CanQuery = true end end end
	-- frame
	if ch.frame then into(group("frame"), function()
		if isDt then
			K.tube("Frame1", { 0, 0.98, 0.43 }, { 0, 0.84, -0.25 }, 0.024, C.dark, MAT.metal, 0.1); K.tube("Frame2", { 0, 0.82, 0.47 }, { 0, 0.3, 0.1 }, 0.022, C.dark, MAT.metal, 0.1)
			for _, x in ipairs({ -1, 1 }) do K.tube("Rail", { x * 0.08, 0.82, -0.25 }, { x * 0.1, 0.74, -0.75 }, 0.014, C.dark, MAT.metal, 0.1) end
		else
			K.tube("Spine", { 0, 0.85, 0.42 * s }, { 0, 0.24, 0.3 * s }, 0.025, C.dark, MAT.metal); K.tube("Floor", { 0, 0.24, 0.3 * s }, { 0, 0.24, -0.15 * s }, 0.025, C.dark, MAT.metal)
			K.tube("Rear", { 0, 0.24, -0.15 * s }, { 0, 0.55, -0.62 * s }, 0.025, C.dark, MAT.metal)
			K.box("RearBody", 0.26, 0.22, 0.55 * s, 0, 0.48, -0.33 * s, Color3.fromRGB(45, 47, 52), MAT.plastic)
		end
	end) end
	-- fork + front wheel + brake
	if ch.fork then into(group("fork"), function()
		for _, x in ipairs({ -1, 1 }) do
			if isDt then K.tube("ForkUp", { x * 0.075, 1.02, 0.4 }, { x * 0.075, 0.62, 0.56 }, 0.022, C.chrome, MAT.metal, 0.4); K.tube("ForkLo", { x * 0.075, 0.66, 0.545 }, { x * 0.075, wr, z0 }, 0.028, C.black, MAT.plastic)
			else K.tube("Fork", { x * 0.07, wr, z0 }, { x * 0.07, 0.75, 0.42 * s }, 0.022, C.dark, MAT.metal, 0.1) end
		end
	end) end
	local spins = {}
	local function wheel(sock, z, width)
		local w = ch[sock]
		if not w then return nil end
		local g = group(sock)
		local rc, rm, rr = rimLook(Catalog.BY_SKU[w.sku].val.rims)
		local tyre
		into(g, function()
			tyre = K.cyl(sock .. "Tyre", width, wr * 2, 0, wr, z, "x", C.tire, MAT.plastic)
			K.cyl(sock .. "Rim", width * 1.05, wr * 1.25, 0, wr, z, "x", rc, rm, rr)
			K.cyl(sock .. "Hub", width * 1.2, wr * 0.35, 0, wr, z, "x", C.alu, MAT.metal, 0.2)
		end)
		tyre.CanCollide = true; tyre.CanQuery = true; tyre.Massless = false
		tyre.CustomPhysicalProperties = PhysicalProperties.new(3, 0.05, 0, 1, 1)
		for i = 0, 2 do
			local sw = K.spin(sock .. "Spoke", Vector3.new(width * 1.1, wr * 1.2, 0.025), K.at(0, wr, z) * CFrame.Angles(i * math.pi / 3, 0, 0), rc, rm, rr)
			sw.Part1.Parent = g
			table.insert(spins, sw)
		end
		return tyre
	end
	local fw = wheel("wheelF", z0, isDt and 0.09 or 0.11)
	local rw = wheel("wheelR", -z0, isDt and 0.1 or 0.12)
	for _, b in ipairs({ { "brakeF", z0 }, { "brakeR", -z0 } }) do
		if ch[b[1]] then into(group(b[1]), function() K.cyl("Disc", 0.006, 0.19, 0.06, wr, b[2], "x", C.alu, MAT.metal, 0.3); K.box("Caliper", 0.03, 0.05, 0.06, 0.075, wr + 0.08, b[2] - 0.04, C.red, MAT.metal) end) end
	end
	if ch.shock then into(group("shock"), function()
		if isDt then for _, x in ipairs({ -1, 1 }) do K.tube("Shock", { x * 0.09, 0.3, -0.5 }, { x * 0.1, 0.78, -0.52 }, 0.022, ch.shock.sku == "P-shock-gas" and C.red or C.yellow, MAT.metal, 0.1) end
		else K.tube("Shock", { 0.12, 0.55, -0.6 * s }, { 0.12, 0.28, -0.72 * s }, 0.025, ch.shock.sku == "P-shock-gas" and C.red or C.yellow, MAT.metal, 0.1) end
	end) end
	if ch.bars then into(group("bars"), function()
		local hb = Catalog.BY_SKU[ch.bars.sku].val.bars == "high"
		local by = isDt and (1.08 + (hb and 0.07 or 0)) or 1.07
		local bz = isDt and 0.38 or 0.38 * s
		local bw = hb and 0.74 or 0.64
		K.tube("Bar", { -bw / 2, by, bz }, { bw / 2, by, bz }, 0.012, hb and C.alu or C.chrome, MAT.metal, 0.3)
		for _, x in ipairs({ -1, 1 }) do K.cyl("Grip", 0.1, 0.034, x * (bw / 2 - 0.04), by, bz, "x", C.black, MAT.plastic) end
		for _, x in ipairs({ -1, 1 }) do K.tube("Mirror", { x * bw * 0.4, by, bz }, { x * bw * 0.44, by + 0.22, bz - 0.03 }, 0.006, C.black, MAT.metal); K.part("MirrorHead", "ball", Vector3.new(0.1, 0.07, 0.04), K.at(x * bw * 0.45, by + 0.25, bz - 0.04), C.black, MAT.metal) end
	end) end
	if ch.seat then into(group("seat"), function() K.box("Seat", isDt and 0.22 or 0.28, isDt and 0.08 or 0.1, isDt and 0.62 or 0.6 * s, 0, isDt and 0.9 or 0.72, isDt and -0.36 or -0.3 * s, C.black, MAT.fabric, 0, 3) end) end
	if ch.tank then into(group("tank"), function() K.box("Tank", 0.24, 0.13, 0.4, 0, 0.88, 0.13, C.cast, MAT.metal, 0.05, -9) end) end
	if ch.radiator then into(group("radiator"), function() K.box("Radiator", 0.3, 0.22, 0.03, 0, 0.62, 0.36 * s, C.alu, MAT.alu, 0.1, 15) end) end
	if ch.exh then into(group("exh"), function()
		local e = Config.EXH[(Catalog.BY_SKU[ch.exh.sku].val.exh or 0) + 1]
		if isDt then
			local R = 0.035 + e.l * 0.035
			K.tube("ExhA", { 0, 0.47, 0.22 }, { 0.02, 0.3, 0.32 }, 0.022, e.col, MAT.metal, 0.3); K.tube("ExhB", { 0.02, 0.3, 0.32 }, { 0.1, 0.2, 0.15 }, R * 0.8, e.col, MAT.metal, 0.3)
			K.tube("ExhC", { 0.1, 0.2, 0.15 }, { 0.15, 0.4, -0.3 }, R, e.col, MAT.metal, 0.3); K.tube("ExhD", { 0.15, 0.4, -0.3 }, { 0.15, 0.6, -0.55 }, R * 0.6, e.col, MAT.metal, 0.3)
			K.tube("Silencer", { 0.15, 0.6, -0.55 }, { 0.15, 0.7, -0.8 }, 0.03, C.black, MAT.metal)
		else
			local L = 0.7 + e.l * 0.5
			K.tube("Exhaust", { 0.19, 0.15, 0.04 }, { 0.2, 0.22, 0.04 - L }, 0.05 + e.l * 0.02, e.col, MAT.metal, 0.3)
		end
	end) end
	-- engine (when it sits in the moped)
	if view.eng then
		local eo = isDt and K.at(0, 0.32, 0.02) or K.at(0.04, 0.26, -0.38 * s)
		local eng = Builder.engine(model, root.CFrame * eo, mop.id, view.eng, false)
		local er = eng.PrimaryPart
		er.Anchored, er.Massless = false, true
		local ew = Instance.new("WeldConstraint"); ew.Part0, ew.Part1 = root, er; ew.Parent = er
		eng:SetAttribute("Sock", "engine")
	end
	-- body panels: each its own part with its own colour
	for _, pd in ipairs(Panels[mop.id]) do
		local e = ch["pan:" .. pd.id]
		if e then
			local pr = Catalog.BY_SKU[e.sku]
			local L = Panels.LOOK[pr.val.look] or {}
			local sc = L.scale or { 1, 1, 1 }
			local col, mat, refl, tr = Builder.paintLook(e.data and e.data.paint, pr.val.look)
			local rot = pd.rot or { 0, 0, 0 }
			local cf = K.at(pd.pos[1], pd.pos[2], pd.pos[3]) * CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
			local size = Vector3.new(pd.size[1] * sc[1], pd.size[2] * sc[2], pd.size[3] * sc[3])
			local p = pd.shape == "wedge" and K.wedge("Panel_" .. pd.id, size, cf, col, mat, refl) or K.part("Panel_" .. pd.id, pd.shape == "ball" and "ball" or "box", size, cf, col, mat, refl)
			p.Transparency = tr; p.CanQuery = true
			tag(p, "pan:" .. pd.id)
		else
			-- visible fixing points where the panel is missing
			for _, dx in ipairs({ -0.3, 0.3 }) do
				K.cyl("Bolt", 0.012, 0.012, pd.pos[1] + (pd.size[1] > 0.1 and dx * pd.size[1] or 0), pd.pos[2], pd.pos[3] + (pd.size[1] <= 0.1 and dx * pd.size[3] or 0), "x", C.chrome, MAT.metal, 0.4)
			end
		end
	end
	-- lights, smoke and references for the client (only when the frame is there)
	if ch.frame then
		local hl = K.attach("HeadlightAtt", 0, isDt and 0.9 or 0.98, isDt and 0.6 or 0.7 * s)
		local spot = Instance.new("SpotLight"); spot.Name = "Headlight"; spot.Face = Enum.NormalId.Front; spot.Angle = 55; spot.Range = 45; spot.Brightness = 2.4; spot.Color = Color3.fromRGB(255, 240, 210); spot.Shadows = true; spot.Parent = hl
		K.part("Lamp", "ball", Vector3.new(0.1, 0.08, 0.05), K.at(0, isDt and 0.9 or 0.98, isDt and 0.58 or 0.6 * s), C.lamp, MAT.neon)
		local tl = K.attach("TailAtt", 0, isDt and 0.92 or 0.55, isDt and -1.1 or -0.7 * s)
		local pl = Instance.new("PointLight"); pl.Color = Color3.fromRGB(255, 40, 40); pl.Range = 6; pl.Brightness = 1.2; pl.Parent = tl
		K.box("TailLight", 0.12, 0.05, 0.03, 0, isDt and 0.92 or 0.55, isDt and -1.08 or -0.68 * s, C.red, MAT.neon)
	end
	local ex = isDt and K.attach("ExhaustAtt", 0.15, 0.72, -0.85) or K.attach("ExhaustAtt", 0.2, 0.22, -0.9)
	local pe = Instance.new("ParticleEmitter"); pe.Name = "Smoke"; pe.Texture = "rbxasset://textures/particles/smoke_main.dds"; pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.6, 1.4); pe.Speed = NumberRange.new(2, 4); pe.SpreadAngle = Vector2.new(12, 12); pe.EmissionDirection = Enum.NormalId.Back
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 2.2) }); pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	pe.Color = ColorSequence.new(Color3.fromRGB(200, 200, 205)); pe.Parent = ex
	if ch.seat then
		local seat = Instance.new("Seat"); seat.Name = "Seat"; seat.Size = Vector3.new(0.3 * S, 0.1 * S, 0.4 * S)
		seat.CFrame = CFrame.new(0, (isDt and 0.95 or 0.77) * S, (isDt and 0.36 or 0.3 * s) * S); seat.Transparency = 1; seat.CanCollide = false; seat.Massless = true; seat.Parent = model
		local sw = Instance.new("WeldConstraint"); sw.Part0, sw.Part1 = root, seat; sw.Parent = seat
	end
	local refs = Instance.new("Folder"); refs.Name = "Refs"; refs.Parent = model
	for i, w in ipairs(spins) do local o = Instance.new("ObjectValue"); o.Name = "Spin" .. i; o.Value = w; o.Parent = refs end
	if fw then local o = Instance.new("ObjectValue"); o.Name = "FW"; o.Value = fw; o.Parent = refs end
	if rw then local o = Instance.new("ObjectValue"); o.Name = "RW"; o.Value = rw; o.Parent = refs end
	model:SetAttribute("Moped", mop.id)
	return model
end

return Builder

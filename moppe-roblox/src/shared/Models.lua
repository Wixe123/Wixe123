-- 3D models built from Roblox parts: every engine part, every chassis part, panels, the whole moped,
-- tools, the first-person hand and the delivery box. Each part kind has one builder; it is used on the engine,
-- on the moped, on the shelf, in the hand and as the product picture in the shop.
local Parts = require(script.Parent.Parts)
local EngineDef = require(script.Parent.EngineDef)
local MopedDef = require(script.Parent.MopedDef)
local Paint = require(script.Parent.Paint)
local Models = {}

local V3, CF, C3 = Vector3.new, CFrame.new, Color3.fromRGB
local rad = math.rad
local ALU, CAST, STEEL, CHROME = C3(176, 180, 186), C3(128, 131, 137), C3(84, 86, 92), C3(214, 218, 224)
local BLACK, RUBBER, DARK = C3(30, 30, 33), C3(22, 22, 24), C3(48, 50, 54)
local COPPER, BRASS, CERAMIC = C3(184, 112, 50), C3(190, 160, 80), C3(236, 232, 222)
Models.COLORS = { ALU = ALU, CAST = CAST, STEEL = STEEL, CHROME = CHROME, BLACK = BLACK, RUBBER = RUBBER }
local M = Enum.Material

---------------------------------------------------------------- builder
-- mk(parent): helpers that create anchored, non-colliding parts in world space
function Models.maker(parent)
	local mk = { parent = parent, parts = {} }
	local function base(cls, name, size, cf, color, mat)
		local p = Instance.new(cls)
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CastShadow = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = size
		p.CFrame = cf
		p.Color = color or ALU
		p.Material = mat or M.SmoothPlastic
		p.Parent = parent
		mk.parts[#mk.parts + 1] = p
		return p
	end
	function mk.box(name, size, cf, color, mat) return base("Part", name, size, cf, color, mat) end
	function mk.wedge(name, size, cf, color, mat) return base("WedgePart", name, size, cf, color, mat) end
	-- cylinder along the X axis of cf
	function mk.cyl(name, len, radius, cf, color, mat)
		local p = base("Part", name, V3(len, radius * 2, radius * 2), cf, color, mat)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	function mk.ball(name, d, cf, color, mat)
		local p = base("Part", name, V3(d, d, d), cf, color, mat)
		p.Shape = Enum.PartType.Ball
		return p
	end
	-- straight tube between two world points
	function mk.tube(name, a, b, radius, color, mat)
		local len = (b - a).Magnitude
		if len < 1e-3 then return nil end
		local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
		return mk.cyl(name, len, radius, cf, color, mat)
	end
	-- tube through several points (bends get a ball joint)
	function mk.path(name, pts, radius, color, mat)
		for i = 1, #pts - 1 do
			mk.tube(name, pts[i], pts[i + 1], radius, color, mat)
			if i > 1 then mk.ball(name, radius * 2, CF(pts[i]), color, mat) end
		end
	end
	-- a disc facing X with spokes/fins around it
	function mk.ring(name, cf, radius, thick, n, color, mat)
		for i = 1, n do
			local a = (i - 1) / n * math.pi * 2
			mk.box(name, V3(thick, radius * 0.5, radius * 0.08), cf * CFrame.Angles(a, 0, 0) * CF(0, radius * 0.72, 0), color, mat)
		end
	end
	return mk
end
local function brandColor(part)
	local r, g, b = Parts.brandColor(part.brand)
	return C3(r, g, b)
end

---------------------------------------------------------------- engine part builders
-- each builder: (mk, cf, part, item) where cf is the socket frame in world space
local B = {}
local AX_Z = CFrame.Angles(0, math.pi / 2, 0) -- cylinder along Z
local AX_Y = CFrame.Angles(0, 0, math.pi / 2) -- cylinder along Y

B.vevhus = function(mk, cf, part)
	local c = part.brand == "Origo" and CAST or ALU
	mk.cyl("Vevhus", 0.86, 0.44, cf, c, M.Metal)
	mk.box("Vevhus", V3(0.86, 0.72, 0.55), cf * CF(0, -0.02, 0.32), c, M.Metal)
	mk.box("Vevhus", V3(0.74, 0.74, 0.1), cf * CF(0, 0, -0.44), c, M.Metal) -- cylinder base face
	mk.box("Vevhus", V3(0.86, 0.12, 0.7), cf * CF(0, 0.4, 0.1), c, M.Metal)
	-- inner CVT wall and rear axle boss on the left side
	mk.box("Vevhus", V3(0.07, 0.62, 1.9), cf * CF(-0.5, 0, 0.82), c, M.Metal)
	mk.cyl("Vevhus", 0.07, 0.36, cf * CF(-0.5, 0, 1.7), c, M.Metal)
	mk.cyl("Vevhus", 0.07, 0.34, cf * CF(-0.5, 0, -0.05), c, M.Metal)
	mk.cyl("Vevhus", 0.25, 0.14, cf * CF(-0.36, 0, 1.7), c, M.Metal)
	-- bolts along the joint
	for i = 0, 5 do mk.cyl("Bult", 0.9, 0.03, cf * CF(0, 0.34 * math.cos(i), 0.34 * math.sin(i) + 0.12), STEEL, M.Metal) end
	if part.brand ~= "Origo" then mk.box("Dekal", V3(0.02, 0.12, 0.4), cf * CF(0.44, 0.15, 0.32), brandColor(part)) end
end
B.vevlager = function(mk, cf)
	for _, x in ipairs({ -0.33, 0.33 }) do
		mk.cyl("Lager", 0.08, 0.2, cf * CF(x, 0, 0), CHROME, M.Metal)
		mk.cyl("Lager", 0.085, 0.1, cf * CF(x, 0, 0), STEEL, M.Metal)
	end
end
B.vevaxel = function(mk, cf, part)
	mk.cyl("Axel", 1.62, 0.055, cf, STEEL, M.Metal)
	for _, x in ipairs({ -0.12, 0.12 }) do
		mk.cyl("Vevskiva", 0.1, 0.32, cf * CF(x, 0, 0), part.brand == "Origo" and STEEL or CHROME, M.Metal)
	end
	mk.cyl("Vevtapp", 0.24, 0.05, cf * CF(0, 0, -0.2), STEEL, M.Metal)
	mk.box("Vevstake", V3(0.09, 0.08, 0.46), cf * CF(0, 0, -0.42), CHROME, M.Metal)
	mk.cyl("Lilländen", 0.1, 0.07, cf * CF(0, 0, -0.62), CHROME, M.Metal)
	-- splines at the ends
	mk.cyl("Spline", 0.18, 0.065, cf * CF(-0.72, 0, 0), DARK, M.DiamondPlate)
	mk.cyl("Spline", 0.18, 0.065, cf * CF(0.72, 0, 0), DARK, M.DiamondPlate)
end
B.packbox = function(mk, cf)
	for _, x in ipairs({ -0.42, 0.42 }) do mk.cyl("Packbox", 0.05, 0.12, cf * CF(x, 0, 0), RUBBER, M.Rubber) end
end
B.nallager = function(mk, cf, part)
	mk.cyl("Nållager", 0.13, 0.065, cf, part.brand == "Origo" and BRASS or CHROME, M.Metal)
end
local function boreR(part) return (part.stats.bore or 40) / 40 * 0.19 end
B.kolv = function(mk, cf, part)
	local r = boreR(part)
	mk.cyl("Kolv", 0.28, r, cf * AX_Z, ALU, M.Metal)
	mk.cyl("Kolvtopp", 0.02, r * 0.96, cf * CF(0, 0, -0.145) * AX_Z, C3(150, 150, 150), M.Metal)
	mk.cyl("Bulthål", 0.02, 0.05, cf * CF(r + 0.002, 0, 0.04), STEEL, M.Metal)
end
B.kolvbult = function(mk, cf)
	mk.cyl("Kolvbult", 0.34, 0.038, cf, CHROME, M.Metal)
end
B.kolvringar = function(mk, cf, part)
	local r = boreR(part) + 0.006
	mk.cyl("Ring", 0.018, r, cf * AX_Z, DARK, M.Metal)
	mk.cyl("Ring", 0.018, r, cf * CF(0, 0, -0.04) * AX_Z, DARK, M.Metal)
end
B.fotpackning = function(mk, cf, part)
	mk.box("Packning", V3(0.62, 0.62, 0.015), cf, part.brand == "Origo" and C3(196, 170, 120) or C3(120, 120, 128), M.Fabric)
end
B.cylinder = function(mk, cf, part)
	local lvl = part.stats.lvl or 0
	local body = (lvl == 0 and CAST) or (lvl == 1 and DARK) or ALU
	local w = 0.56 + 0.03 * lvl
	mk.box("Cylinder", V3(w, w, 0.6), cf, body, M.Metal)
	for i = 0, 6 do
		mk.box("Fläns", V3(w + 0.22, w + 0.22, 0.035), cf * CF(0, 0, -0.26 + i * 0.085), body, M.Metal)
	end
	mk.cyl("Avgasport", 0.18, 0.1, cf * CF(0, -w / 2 - 0.06, -0.05) * AX_Y, body, M.Metal)
	mk.box("Fot", V3(0.66, 0.66, 0.05), cf * CF(0, 0, 0.29), body, M.Metal)
	if lvl > 0 then
		mk.box("Dekal", V3(0.02, 0.1, 0.42), cf * CF(w / 2 + 0.115, 0, 0), brandColor(part))
		mk.box("Dekal", V3(0.02, 0.1, 0.42), cf * CF(-w / 2 - 0.115, 0, 0), brandColor(part))
	end
end
B.topplock = function(mk, cf, part)
	local c = part.brand == "Origo" and CAST or C3(60, 60, 64)
	mk.box("Topplock", V3(0.6, 0.6, 0.1), cf, c, M.Metal)
	for i = 0, 2 do mk.box("Fläns", V3(0.74, 0.74, 0.025), cf * CF(0, 0, -0.06 - i * 0.045), c, M.Metal) end
	mk.cyl("Tändstiftsfäste", 0.1, 0.07, cf * CF(0, 0.1, -0.13) * AX_Z, c, M.Metal)
	if part.brand ~= "Origo" then mk.box("Dekal", V3(0.3, 0.06, 0.012), cf * CF(0, -0.15, -0.155), brandColor(part)) end
end
B.tandstift = function(mk, cf, part)
	mk.cyl("Gänga", 0.06, 0.03, cf * CF(0, 0, 0.02) * AX_Z, CHROME, M.Metal)
	mk.cyl("Sexkant", 0.05, 0.05, cf * CF(0, 0, -0.03) * AX_Z, CHROME, M.Metal)
	mk.cyl("Isolator", 0.12, 0.032, cf * CF(0, 0, -0.11) * AX_Z, CERAMIC, M.SmoothPlastic)
	mk.cyl("Topp", 0.03, 0.018, cf * CF(0, 0, -0.18) * AX_Z, STEEL, M.Metal)
	if part.brand ~= "Origo" then mk.cyl("Ring", 0.012, 0.034, cf * CF(0, 0, -0.08) * AX_Z, brandColor(part)) end
end
B.reed = function(mk, cf, part)
	mk.box("Reedhus", V3(0.38, 0.1, 0.32), cf, DARK, M.Metal)
	local c = (part.stats.lvl or 0) > 0 and C3(30, 30, 30) or C3(90, 90, 70)
	mk.wedge("Blad", V3(0.3, 0.1, 0.24), cf * CF(0, 0.09, 0), c, part.brand == "Fartek" and M.Fabric or M.SmoothPlastic)
	if part.brand ~= "Origo" then mk.box("Dekal", V3(0.38, 0.02, 0.06), cf * CF(0, 0.06, -0.14), brandColor(part)) end
end
B.insug = function(mk, cf, part)
	mk.cyl("Insug", 0.22, 0.1 + 0.015 * (part.stats.lvl or 0), cf * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(0, 0, -0.35), part.brand == "Origo" and RUBBER or brandColor(part), M.Rubber)
	mk.box("Fläns", V3(0.3, 0.03, 0.24), cf * CF(0, -0.1, -0.02), DARK, M.Metal)
end
B.forgasare = function(mk, cf, part)
	local s = (part.stats.mm or 12) / 12
	mk.cyl("Förgasare", 0.32, 0.1 * s ^ 0.5, cf * AX_Z, ALU, M.Metal)
	mk.box("Flottörhus", V3(0.18, 0.14, 0.18), cf * CF(0, -0.13, 0), ALU, M.Metal)
	mk.cyl("Spjällhus", 0.18, 0.06, cf * CF(0, 0.12, 0) * AX_Y, ALU, M.Metal)
	mk.cyl("Lock", 0.03, 0.065, cf * CF(0, 0.22, 0) * AX_Y, part.brand == "Origo" and BLACK or brandColor(part), M.SmoothPlastic)
	mk.cyl("Choke", 0.08, 0.02, cf * CF(0.12, 0.03, 0.04), BLACK)
end
B.luftfilter = function(mk, cf, part)
	local lvl = part.stats.lvl or 0
	if lvl == 0 then
		mk.box("Filterlåda", V3(0.46, 0.34, 0.5), cf, BLACK, M.Plastic)
		mk.box("Lock", V3(0.48, 0.06, 0.52), cf * CF(0, 0.19, 0), DARK, M.Plastic)
	else
		mk.cyl("Filter", 0.32, 0.17, cf * AX_Z, brandColor(part), M.Fabric)
		mk.cyl("Topp", 0.03, 0.12, cf * CF(0, 0, 0.17) * AX_Z, lvl == 2 and CHROME or BLACK, M.Metal)
		mk.cyl("Klämma", 0.05, 0.1, cf * CF(0, 0, -0.17) * AX_Z, CHROME, M.Metal)
	end
end
B.slang = function(mk, cf, part)
	local col = part.brand == "Bruksmek" and C3(230, 200, 120) or BLACK
	local a = cf.Position
	local p = mk.tube("Slang", a, a + V3(0.06, 0.2, 0.25), 0.025, col, M.Rubber)
	if p and part.brand == "Bruksmek" then p.Transparency = 0.35 end
end
B.stator = function(mk, cf)
	mk.cyl("Stator", 0.08, 0.27, cf, COPPER, M.Metal)
	mk.cyl("Platta", 0.03, 0.29, cf * CF(-0.04, 0, 0), DARK, M.Metal)
end
B.svanghjul = function(mk, cf, part)
	local c = part.brand == "Origo" and STEEL or ALU
	mk.cyl("Svänghjul", 0.12, 0.36, cf, c, M.Metal)
	mk.ring("Fläkt", cf * CF(0.07, 0, 0), 0.36, 0.04, 8, c, M.Metal)
	mk.cyl("Mutter", 0.05, 0.06, cf * CF(0.09, 0, 0), CHROME, M.Metal)
end
B.cdi = function(mk, cf, part)
	mk.box("CDI", V3(0.24, 0.1, 0.34), cf, BLACK, M.Plastic)
	mk.box("Etikett", V3(0.18, 0.012, 0.2), cf * CF(0, 0.055, 0), part.brand == "Origo" and C3(200, 200, 200) or brandColor(part))
	mk.cyl("Kontakt", 0.06, 0.03, cf * CF(0, 0, -0.19) * AX_Z, DARK)
end
B.spole = function(mk, cf, part)
	mk.box("Spole", V3(0.16, 0.2, 0.16), cf, BLACK, M.Plastic)
	mk.cyl("Lindning", 0.12, 0.07, cf * CF(0, 0.02, 0) * AX_Y, part.brand == "Origo" and DARK or brandColor(part), M.Plastic)
end
B.tandkabel = function(mk, cf, part)
	local a = cf.Position
	-- from the coil to the spark plug, both found relative to this socket
	local coil = a + (cf:VectorToWorldSpace(V3(0.2, 0.1, 0.4)))
	local plug = a + (cf:VectorToWorldSpace(V3(-0.22, -0.04, -0.52)))
	local mid = (coil + plug) / 2 + cf:VectorToWorldSpace(V3(0.12, 0.12, 0))
	mk.path("Tändkabel", { coil, mid, plug }, 0.022, part.brand == "Origo" and BLACK or C3(200, 40, 40), M.Rubber)
	mk.cyl("Tändhatt", 0.1, 0.035, CFrame.lookAt(plug, plug + cf:VectorToWorldSpace(V3(-0.1, 0, -0.2))) * CFrame.Angles(0, math.pi / 2, 0), BLACK, M.Rubber)
end
B.variator = function(mk, cf, part)
	mk.cyl("Variator", 0.1, 0.4, cf, part.brand == "Origo" and STEEL or ALU, M.Metal)
	mk.cyl("Nav", 0.16, 0.12, cf * CF(-0.04, 0, 0), STEEL, M.Metal)
	if part.brand ~= "Origo" then mk.ring("Spår", cf * CF(-0.055, 0, 0), 0.4, 0.01, 6, brandColor(part)) end
end
B.vikter = function(mk, cf, part)
	local c = part.brand == "Origo" and BLACK or brandColor(part)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		mk.cyl("Rulle", 0.08, 0.05, cf * CF(0, math.cos(a) * 0.24, math.sin(a) * 0.24) * CFrame.Angles(a, 0, 0) * AX_Z, c, M.Plastic)
	end
end
B.flakt = function(mk, cf, part)
	mk.cyl("Fläkt", 0.03, 0.4, cf, part.brand == "Origo" and DARK or brandColor(part), M.Plastic)
	mk.ring("Skovel", cf * CF(-0.03, 0, 0), 0.4, 0.05, 10, DARK, M.Plastic)
end
B.remskiva = function(mk, cf)
	mk.cyl("Remskiva", 0.1, 0.32, cf, STEEL, M.Metal)
	mk.cyl("Fjäder", 0.14, 0.12, cf * CF(0.05, 0, 0), C3(200, 170, 40), M.Metal)
end
B.koppling = function(mk, cf, part)
	mk.cyl("Koppling", 0.05, 0.28, cf, STEEL, M.Metal)
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		mk.box("Belägg", V3(0.06, 0.08, 0.26), cf * CFrame.Angles(a, 0, 0) * CF(0, 0.22, 0), part.brand == "Origo" and C3(110, 90, 70) or brandColor(part), M.Fabric)
	end
end
B.rem = function(mk, cf, part)
	local c = part.brand == "Origo" and RUBBER or C3(40, 40, 30)
	mk.box("Rem", V3(0.09, 0.05, 1.72), cf * CF(0, 0.3, 0), c, M.Rubber)
	mk.box("Rem", V3(0.09, 0.05, 1.72), cf * CF(0, -0.27, 0), c, M.Rubber)
end
B.klocka = function(mk, cf, part)
	mk.cyl("Klocka", 0.12, 0.35, cf, part.brand == "Origo" and STEEL or ALU, M.Metal)
	mk.cyl("Nav", 0.06, 0.1, cf * CF(-0.08, 0, 0), STEEL, M.Metal)
	if part.brand ~= "Origo" then mk.ring("Hål", cf * CF(-0.061, 0, 0), 0.35, 0.01, 8, C3(40, 40, 40)) end
end

---------------------------------------------------------------- chassis builders
-- ctx: { cf = moped root CFrame (ground, between axles), def = model def }
local C = {}
local function mp(ctx, x, y, z) return ctx.cf * V3(x, y, z) end
local function frontAxle(ctx) return V3(0, ctx.def.r, -ctx.def.wb / 2) end
local function rearAxle(ctx) return V3(0, ctx.def.r, ctx.def.wb / 2) end
function Models.engineCF(ctx)
	local ra = rearAxle(ctx)
	return ctx.cf * CF(ra.X, ra.Y + 0.22, ra.Z - EngineDef.REAR_AXLE_Z)
end
local function headTop(ctx)
	local h = ctx.def.head
	return V3(h[1], h[2], h[3])
end

C.ram = function(mk, ctx)
	local d = ctx.def
	local col = C3(26, 26, 28)
	local h = headTop(ctx)
	local rake = rad(d.rake)
	local up = V3(0, math.cos(rake), math.sin(rake))
	mk.tube("Styrhuvud", ctx.cf * (h - up * 0.4), ctx.cf * (h + up * 0.35), 0.12, col, M.Metal)
	local floorY = d.floorY - 0.2
	local pts = {
		h - up * 0.3, V3(0, floorY + 0.15, -1.35), V3(0, floorY, -1.0), V3(0, floorY, 0.15), V3(0, d.seat[2] - 0.45, 1.25), V3(0, d.seat[2] - 0.35, d.tailZ - 0.2),
	}
	for _, x in ipairs({ -0.28, 0.28 }) do
		local w = {}
		for i, p in ipairs(pts) do w[i] = ctx.cf * (i == 1 and p or (p + V3(x, 0, 0))) end
		mk.path("Ram", w, 0.07, col, M.Metal)
	end
	for _, z in ipairs({ -1.0, 0.15, 1.25 }) do
		local y = z > 1 and d.seat[2] - 0.45 or floorY
		mk.tube("Tvärbalk", mp(ctx, -0.28, y, z), mp(ctx, 0.28, y, z), 0.05, col, M.Metal)
	end
	-- engine hanger and stand
	mk.tube("Motorfäste", mp(ctx, 0, floorY, 0.15), Models.engineCF(ctx) * V3(0, 0.3, -0.2), 0.06, col, M.Metal)
	mk.box("Fäste", V3(0.7, 0.06, 0.3), ctx.cf * CF(0, d.seat[2] - 0.42, d.tailZ - 0.3), col, M.Metal)
	-- side stand
	mk.tube("Stöd", mp(ctx, -0.3, 0.9, 0.3), mp(ctx, -0.55, 0.05, 0.5), 0.04, col, M.Metal)
end
C.gaffel = function(mk, ctx, part)
	local d = ctx.def
	local h, fa = headTop(ctx), frontAxle(ctx)
	local usd = part.brand ~= "Origo"
	for _, x in ipairs({ -0.27, 0.27 }) do
		local top, bot = V3(x, h.Y - 0.25, h.Z + 0.05), V3(x, fa.Y, fa.Z)
		local mid = top:Lerp(bot, 0.55)
		mk.tube("Gaffelben", ctx.cf * top, ctx.cf * mid, usd and 0.085 or 0.06, usd and C3(200, 160, 40) or CHROME, M.Metal)
		mk.tube("Gaffelben", ctx.cf * mid, ctx.cf * bot, usd and 0.06 or 0.085, usd and CHROME or DARK, M.Metal)
	end
	mk.box("Krona", V3(0.7, 0.1, 0.22), ctx.cf * CF(0, h.Y - 0.2, h.Z + 0.03), DARK, M.Metal)
	mk.tube("Axel", mp(ctx, -0.32, fa.Y, fa.Z), mp(ctx, 0.32, fa.Y, fa.Z), 0.035, STEEL, M.Metal)
end
local function wheel(mk, ctx, part, axle, name)
	local d = ctx.def
	local cf = ctx.cf * CF(axle)
	mk.cyl(name, 0.4, d.r, cf, RUBBER, M.Rubber)
	mk.cyl(name, 0.34, d.r - 0.05, cf, C3(34, 34, 36), M.Rubber)
	local rimC = part.brand == "Origo" and C3(40, 40, 44) or brandColor(part)
	mk.cyl(name .. "Fälg", 0.42, d.r * 0.66, cf, rimC, M.Metal)
	mk.cyl(name .. "Nav", 0.46, 0.14, cf, ALU, M.Metal)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		mk.box(name .. "Eker", V3(0.12, d.r * 0.5, 0.07), cf * CFrame.Angles(a, 0, 0) * CF(0, d.r * 0.38, 0), rimC, M.Metal)
	end
	-- tread blocks so the rotation can be seen
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		mk.box(name .. "Mönster", V3(0.36, 0.03, 0.12), cf * CFrame.Angles(a, 0, 0) * CF(0, d.r + 0.005, 0), RUBBER, M.Rubber)
	end
end
C.framhjul = function(mk, ctx, part) wheel(mk, ctx, part, frontAxle(ctx), "Framhjul") end
C.bakhjul = function(mk, ctx, part) wheel(mk, ctx, part, rearAxle(ctx), "Bakhjul") end
C.frambroms = function(mk, ctx, part)
	local fa = frontAxle(ctx)
	local cf = ctx.cf * CF(fa)
	mk.cyl("Bromsskiva", 0.03, ctx.def.r * 0.55, cf * CF(-0.24, 0, 0), CHROME, M.Metal)
	mk.box("Bromsok", V3(0.12, 0.22, 0.3), cf * CF(-0.27, 0.12, 0.3) * CFrame.Angles(0.5, 0, 0), part.brand == "Origo" and DARK or brandColor(part), M.Metal)
	mk.tube("Bromsslang", ctx.cf * (fa + V3(-0.3, 0.3, 0.3)), ctx.cf * (headTop(ctx) + V3(-0.4, 0.6, 0.15)), 0.025, BLACK, M.Rubber)
end
C.bakbroms = function(mk, ctx, part)
	local ra = rearAxle(ctx)
	local cf = ctx.cf * CF(ra)
	if part.brand == "Origo" then
		mk.cyl("Trumma", 0.12, ctx.def.r * 0.45, cf * CF(0.26, 0, 0), ALU, M.Metal)
		mk.box("Bromsarm", V3(0.05, 0.08, 0.3), cf * CF(0.33, 0.15, -0.1), STEEL, M.Metal)
	else
		mk.cyl("Bromsskiva", 0.03, ctx.def.r * 0.5, cf * CF(0.24, 0, 0), CHROME, M.Metal)
		mk.box("Bromsok", V3(0.12, 0.2, 0.28), cf * CF(0.27, 0.12, -0.28), brandColor(part), M.Metal)
	end
end
C.dampare = function(mk, ctx, part)
	local ra = rearAxle(ctx)
	local d = ctx.def
	local a = ctx.cf * V3(-0.5, ra.Y + 0.15, ra.Z - 0.1)
	local b = ctx.cf * V3(-0.42, d.seat[2] - 0.5, ra.Z - 0.55)
	mk.tube("Dämpare", a, b, 0.06, DARK, M.Metal)
	mk.tube("Fjäder", a:Lerp(b, 0.15), a:Lerp(b, 0.85), 0.1, part.brand == "Origo" and C3(40, 40, 44) or brandColor(part), M.Metal)
	for i = 1, 6 do mk.cyl("Varv", 0.03, 0.105, CFrame.lookAt(a:Lerp(b, 0.15 + i * 0.1), b) * CFrame.Angles(0, math.pi / 2, 0), part.brand == "Origo" and DARK or brandColor(part), M.Metal) end
end
C.styre = function(mk, ctx, part)
	local d = ctx.def
	local h = headTop(ctx)
	local y, z = d.barY, h.Z + 0.22
	mk.tube("Styrstam", ctx.cf * (h + V3(0, 0.2, 0.08)), mp(ctx, 0, y, z), 0.07, DARK, M.Metal)
	local w = part.brand == "Origo" and 0.78 or 0.88
	mk.tube("Styre", mp(ctx, -w, y + 0.05, z + 0.1), mp(ctx, w, y + 0.05, z + 0.1), 0.05, part.brand == "Origo" and DARK or CHROME, M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		mk.cyl("Handtag", 0.36, 0.075, ctx.cf * CF(s * (w - 0.12), y + 0.05, z + 0.1), RUBBER, M.Rubber)
		mk.tube("Handtag", mp(ctx, s * (w - 0.35), y + 0.1, z), mp(ctx, s * (w - 0.05), y + 0.08, z - 0.25), 0.025, ALU, M.Metal)
		mk.tube("Spegelarm", mp(ctx, s * (w - 0.4), y + 0.1, z + 0.05), mp(ctx, s * (w - 0.25), y + 0.48, z - 0.02), 0.02, DARK, M.Metal)
		mk.cyl("Spegel", 0.04, 0.11, ctx.cf * CF(s * (w - 0.24), y + 0.54, z - 0.02) * AX_Z, BLACK)
	end
	mk.box("Mätare", V3(0.42, 0.2, 0.08), ctx.cf * CF(0, y + 0.2, z - 0.05) * CFrame.Angles(rad(30), 0, 0), BLACK)
end
C.tank = function(mk, ctx)
	local t = ctx.def.tank
	mk.box("Tank", V3(0.66, 0.42, 1.15), ctx.cf * CF(t[1], t[2], t[3]), C3(36, 36, 38), M.Plastic)
	mk.cyl("Tanklock", 0.06, 0.12, ctx.cf * CF(t[1], t[2] + 0.23, t[3] - 0.4) * AX_Y, CHROME, M.Metal)
end
C.sadel = function(mk, ctx, part)
	local s, len = ctx.def.seat, ctx.def.seatLen
	local c = C3(24, 24, 26)
	mk.box("Sadel", V3(0.74, 0.22, len - 0.4), ctx.cf * CF(s[1], s[2], s[3] + 0.15), c, M.Leather)
	mk.wedge("Sadel", V3(0.74, 0.22, 0.4), ctx.cf * CF(s[1], s[2], s[3] - len / 2 + 0.15) * CFrame.Angles(0, math.pi, 0), c, M.Leather)
	mk.box("Sadelbotten", V3(0.7, 0.08, len - 0.1), ctx.cf * CF(s[1], s[2] - 0.14, s[3]), DARK, M.Plastic)
	if part.brand ~= "Origo" then
		mk.box("Söm", V3(0.02, 0.23, len - 0.45), ctx.cf * CF(-0.2, s[2] + 0.005, s[3] + 0.15), brandColor(part), M.Fabric)
		mk.box("Söm", V3(0.02, 0.23, len - 0.45), ctx.cf * CF(0.2, s[2] + 0.005, s[3] + 0.15), brandColor(part), M.Fabric)
	end
	mk.box("Handtag", V3(0.6, 0.06, 0.12), ctx.cf * CF(0, s[2] - 0.05, s[3] + len / 2 + 0.05), DARK, M.Metal)
end
C.avgas = function(mk, ctx, part)
	local e = Models.engineCF(ctx)
	local lvl = part.stats.lvl or 0
	local col = part.brand == "Origo" and C3(50, 50, 52) or (lvl >= 2 and CHROME or C3(70, 70, 74))
	local r = 0.1 + 0.05 * lvl
	local port = e * V3(0, -0.4, -0.85)
	local p1 = e * V3(0.1, -0.62, -0.75)
	local belly0 = e * V3(0.38, -0.62, -0.35)
	local belly1 = e * V3(0.5, -0.5, 0.75)
	local cone = e * V3(0.55, -0.25, 1.15)
	local sil0 = e * V3(0.58, -0.1, 1.25)
	local sil1 = e * V3(0.6, 0.2, 2.2)
	mk.path("Krök", { port, p1, belly0 }, 0.07, col, M.Metal)
	mk.tube("Kammare", belly0, belly1, r + 0.04, col, M.Metal)
	mk.tube("Kon", belly1, cone, r, col, M.Metal)
	mk.tube("Ljuddämpare", sil0, sil1, part.brand == "Origo" and 0.15 or 0.13, part.brand == "Origo" and C3(40, 40, 42) or (lvl >= 2 and C3(30, 30, 32) or ALU), lvl >= 2 and M.Fabric or M.Metal)
	mk.cyl("Ändrör", 0.15, 0.05, CFrame.lookAt(sil1, sil1 + (sil1 - sil0)) * CFrame.Angles(0, math.pi / 2, 0) * CF(0.05, 0, 0), CHROME, M.Metal)
	if part.brand ~= "Origo" then
		mk.box("Dekal", V3(0.02, 0.1, 0.4), CFrame.lookAt(sil0:Lerp(sil1, 0.5), sil1) * CF(0.14, 0, 0), brandColor(part))
	end
end
-- panel from MopedDef prims, painted
function Models.paintPart(p, paint)
	if not paint then
		p.Color = C3(232, 232, 228)
		p.Material = M.SmoothPlastic
		p.Reflectance = 0.02
		return
	end
	-- finish, settings and (poor quality looks blotchy) all in Paint.look
	Paint.apply(p, paint)
end
C.kapa = function(mk, ctx, part, item)
	local def = MopedDef.MODELS[part.stats.fits]
	local pdef = def and def.panelById[part.stats.panel]
	if not pdef then return end
	local big
	for _, pr in ipairs(pdef.prims) do
		local shape, size, pos, rot = pr[1], pr[2], pr[3], pr[4] or { 0, 0, 0 }
		local cf = ctx.cf * CF(pos[1], pos[2], pos[3]) * CFrame.fromOrientation(rad(rot[1]), rad(rot[2]), rad(rot[3]))
		local p
		if shape == "wedge" then p = mk.wedge(pdef.n, V3(size[1], size[2], size[3]), cf)
		elseif shape == "ball" then p = mk.ball(pdef.n, size[1], cf)
		elseif shape == "cyl" then p = mk.cyl(pdef.n, size[1], size[2] / 2, cf)
		elseif shape == "ell" then
			p = mk.box(pdef.n, V3(size[1], size[2], size[3]), cf)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		else p = mk.box(pdef.n, V3(size[1], size[2], size[3]), cf) end
		Models.paintPart(p, item and item.paint)
		p:SetAttribute("Panel", pdef.id)
		if shape ~= "ball" and shape ~= "cyl" and (not big or size[1] * size[2] * size[3] > big[2]) then big = { p, size[1] * size[2] * size[3], pos } end
	end
	-- decal: brand text on the outward side of the biggest piece
	local dk = item and item.paint and item.paint.dk and Paint.DECAL[item.paint.dk]
	if dk and big then
		local p, pos = big[1], big[3]
		local face = Enum.NormalId.Top
		if math.abs(pos[1]) > 0.25 then face = pos[1] < 0 and Enum.NormalId.Left or Enum.NormalId.Right end
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Dekal"
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.LightInfluence = 1
		sg.Parent = p
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(0.9, 0.5)
		t.Position = UDim2.fromScale(0.05, 0.25)
		t.BackgroundTransparency = 1
		t.Text = dk.text
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = C3(dk.c[1], dk.c[2], dk.c[3])
		t.TextStrokeTransparency = 0.4
		t.Parent = sg
	end
end

---------------------------------------------------------------- tools
function Models.tool(parent, kind, cf, pro)
	local mk = Models.maker(parent)
	if kind == "slip" then
		local body = pro and C3(200, 40, 40) or C3(60, 110, 200)
		mk.cyl("Kropp", 0.9, 0.11, cf, body, M.SmoothPlastic)
		mk.cyl("Grepp", 0.35, 0.115, cf * CF(0.15, 0, 0), RUBBER, M.Rubber)
		mk.cyl("Hals", 0.18, 0.06, cf * CF(-0.52, 0, 0), ALU, M.Metal)
		mk.cyl("Spindel", 0.16, 0.012, cf * CF(-0.69, 0, 0), CHROME, M.Metal)
		mk.ball("Fräs", 0.06, cf * CF(-0.78, 0, 0), C3(160, 160, 160), M.Metal)
		mk.cyl("Sladd", 0.4, 0.025, cf * CF(0.65, 0, 0), BLACK)
	elseif kind == "spruta" then
		local body = pro and C3(230, 230, 230) or C3(90, 90, 96)
		mk.box("Kropp", V3(0.14, 0.2, 0.36), cf, body, M.Metal)
		mk.cyl("Munstycke", 0.12, 0.04, cf * CF(0, 0.03, -0.24) * AX_Z, CHROME, M.Metal)
		mk.box("Handtag", V3(0.1, 0.42, 0.12), cf * CF(0, -0.26, 0.08) * CFrame.Angles(rad(-15), 0, 0), RUBBER, M.Rubber)
		mk.cyl("Kopp", 0.3, 0.12, cf * CF(0, 0.26, 0) * AX_Y, C3(220, 220, 220), M.SmoothPlastic).Transparency = 0.3
		mk.box("Avtryckare", V3(0.04, 0.14, 0.04), cf * CF(0, -0.1, -0.08), STEEL, M.Metal)
	else -- skiftnyckel / skruvdragare
		mk.box("Skaft", V3(0.08, 0.04, 0.7), cf, CHROME, M.Metal)
		mk.box("Huvud", V3(0.16, 0.05, 0.14), cf * CF(0, 0, -0.38), CHROME, M.Metal)
	end
	return mk
end
-- first-person hand holding something (built around cf = palm); returns the model
function Models.hand(parent, cf, glove)
	local model = Instance.new("Model")
	model.Name = "Hand"
	local mk = Models.maker(model)
	local skin = glove and C3(30, 30, 34) or C3(234, 190, 155)
	local sleeve = C3(28, 30, 36)
	local palm = mk.box("Handflata", V3(0.32, 0.12, 0.36), cf, skin, glove and M.Fabric or M.SmoothPlastic)
	mk.cyl("Handled", 0.3, 0.13, cf * CF(0, -0.02, 0.32) * AX_Z, skin, M.SmoothPlastic)
	mk.cyl("Ärm", 1.4, 0.19, cf * CF(0, -0.05, 1.12) * AX_Z, sleeve, M.Fabric)
	mk.cyl("Mudd", 0.12, 0.2, cf * CF(0, -0.05, 0.44) * AX_Z, C3(20, 20, 22), M.Fabric)
	for i = 0, 3 do
		local x = -0.12 + i * 0.08
		mk.box("Finger", V3(0.065, 0.075, 0.18), cf * CF(x, 0.02, -0.25) * CFrame.Angles(rad(-35), 0, 0), skin, M.SmoothPlastic)
		mk.box("Finger", V3(0.06, 0.07, 0.14), cf * CF(x, -0.06, -0.36) * CFrame.Angles(rad(-75), 0, 0), skin, M.SmoothPlastic)
	end
	mk.box("Tumme", V3(0.07, 0.08, 0.2), cf * CF(0.19, -0.03, -0.08) * CFrame.Angles(rad(-20), rad(35), 0), skin, M.SmoothPlastic)
	model.PrimaryPart = palm
	model.Parent = parent
	return model
end
function Models.box(parent, cf, size, open)
	local model = Instance.new("Model")
	model.Name = "Paket"
	local mk = Models.maker(model)
	local cardboard = C3(176, 138, 92)
	size = size or V3(2.2, 1.4, 1.6)
	local base = mk.box("Låda", V3(size.X, 0.08, size.Z), cf * CF(0, -size.Y / 2 + 0.04, 0), cardboard, M.Cardboard)
	for _, s in ipairs({ -1, 1 }) do
		mk.box("Låda", V3(0.06, size.Y, size.Z), cf * CF(s * (size.X / 2 - 0.03), 0, 0), cardboard, M.Cardboard)
		mk.box("Låda", V3(size.X, size.Y, 0.06), cf * CF(0, 0, s * (size.Z / 2 - 0.03)), cardboard, M.Cardboard)
	end
	if open then
		mk.box("Flik", V3(size.X / 2, 0.04, size.Z), cf * CF(-size.X * 0.75, size.Y / 2 - 0.1, 0) * CFrame.Angles(0, 0, rad(-25)), cardboard, M.Cardboard)
		mk.box("Flik", V3(size.X / 2, 0.04, size.Z), cf * CF(size.X * 0.75, size.Y / 2 - 0.1, 0) * CFrame.Angles(0, 0, rad(25)), cardboard, M.Cardboard)
	else
		mk.box("Lock", V3(size.X, 0.05, size.Z), cf * CF(0, size.Y / 2, 0), cardboard, M.Cardboard)
		mk.box("Tejp", V3(0.3, 0.06, size.Z + 0.02), cf * CF(0, size.Y / 2 + 0.005, 0), C3(200, 180, 120), M.SmoothPlastic)
		mk.box("Etikett", V3(0.7, 0.02, 0.5), cf * CF(size.X * 0.2, size.Y / 2 + 0.03, size.Z * 0.15), C3(245, 245, 245), M.SmoothPlastic)
	end
	model.PrimaryPart = base
	model.Parent = parent
	return model
end

---------------------------------------------------------------- assembling
-- build one part (by sku) into model parent at the place it has on an engine (engineCF) or a moped (ctx)
local DEFAULT_CTX
local function defaultCtx(fits)
	local def = MopedDef.MODELS[fits or "citi"]
	return { cf = CFrame.new(), def = def }
end
function Models.buildInto(parent, sku, item, engineCF, ctx)
	local part = Parts.get(sku)
	if not part then return nil end
	local mk = Models.maker(parent)
	if B[part.kind] then
		local sock = EngineDef.BY_ID[EngineDef.socketForKind(part.kind)]
		local pos = sock.pos
		B[part.kind](mk, (engineCF or CFrame.new()) * CF(pos[1], pos[2], pos[3]), part, item)
	elseif C[part.kind] then
		C[part.kind](mk, ctx or defaultCtx(part.stats.fits), part, item)
	elseif part.kind == "verktyg" then
		Models.tool(parent, part.stats.tool, CFrame.new(), part.price > 1000)
	end
	return mk
end
-- a loose part as its own Model, pivot at the centre of its bounding box, PrimaryPart "Main" (invisible handle)
function Models.item(sku, item)
	local model = Instance.new("Model")
	model.Name = sku
	Models.buildInto(model, sku, item)
	local cf, size = model:GetBoundingBox()
	local main = Instance.new("Part")
	main.Name = "Main"
	main.Anchored = true
	main.CanCollide = false
	main.CanTouch = false
	main.Transparency = 1
	main.Size = Vector3.new(math.max(size.X, 0.2), math.max(size.Y, 0.2), math.max(size.Z, 0.2))
	main.CFrame = CFrame.new(cf.Position)
	main.Parent = model
	model.PrimaryPart = main
	model:SetAttribute("Sku", sku)
	return model, main.Size
end
-- the engine: one sub-model per socket (Name = socket id, attribute Sock)
function Models.engine(parent, engineCF, map, items)
	local model = Instance.new("Model")
	model.Name = "Motor"
	for _, s in ipairs(EngineDef.SOCKETS) do
		local id = map[s.id]
		local it = id and items[id]
		if it then
			local sub = Instance.new("Model")
			sub.Name = s.id
			sub:SetAttribute("Sock", s.id)
			sub:SetAttribute("Item", id)
			Models.buildInto(sub, it.sku, it, engineCF)
			sub.Parent = model
		end
	end
	model.Parent = parent
	return model
end
-- the whole moped: Root (invisible, PrimaryPart), Seat, chassis slots, panels, engine
-- paint from the studio on chassis parts (rims, calipers, bars, mirrors, details): by part name in the zone's slots
function Models.applyZonePaint(model, m)
	for zid, spec in pairs(m.paint or {}) do
		local z = Paint.ZONE[zid]
		if z and z.slots and spec then
			for _, slot in ipairs(z.slots) do
				local sub = model:FindFirstChild(slot)
				if sub then
					for _, d in ipairs(sub:GetDescendants()) do
						if d:IsA("BasePart") and z.nameSet[d.Name] then Paint.apply(d, spec); d:SetAttribute("PaintZone", zid) end
					end
				end
			end
		end
	end
end
function Models.moped(parent, m, items, rootCF)
	local def = MopedDef.MODELS[m.model]
	local model = Instance.new("Model")
	model.Name = "Moped"
	model:SetAttribute("Model", m.model)
	local ctx = { cf = rootCF, def = def }
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1.1, 0.5, def.wb + 1.2)
	root.CFrame = rootCF * CF(0, def.r, 0)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.Parent = model
	model.PrimaryPart = root
	for slot, id in pairs(m.slots) do
		local it = items[id]
		if it then
			local sub = Instance.new("Model")
			sub.Name = slot
			sub:SetAttribute("Slot", slot)
			sub:SetAttribute("Item", id)
			Models.buildInto(sub, it.sku, it, nil, ctx)
			sub.Parent = model
		end
	end
	Models.applyZonePaint(model, m)
	if m.engine then
		local eng = Models.engine(model, Models.engineCF(ctx), m.engine, items)
		eng.Name = "motor"
		eng:SetAttribute("Slot", "motor")
	end
	-- bolts and brackets where a panel is missing, so it is clear something is off
	for _, p in ipairs(def.panels) do
		if not m.slots["pan:" .. p.id] then
			local pr = p.prims[1]
			local mk = Models.maker(model)
			local pos = ctx.cf * V3(pr[3][1], pr[3][2], pr[3][3])
			for i = -1, 1, 2 do mk.cyl("Skruv", 0.08, 0.04, CFrame.new(pos + ctx.cf:VectorToWorldSpace(V3(0, 0.15 * i, 0))) * ctx.cf.Rotation, CHROME, M.Metal) end
		end
	end
	-- lights (only if the front panel / tail are on)
	local mk = Models.maker(model)
	for _, l in ipairs(def.lights) do
		local lamp = mk.box("Strålkastare", V3(0.32, 0.18, 0.06), ctx.cf * CF(l[1], l[2], l[3] - 0.05), C3(255, 250, 230), M.Neon)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Range = 40
		spot.Angle = 50
		spot.Brightness = 3
		spot.Enabled = false
		spot.Parent = lamp
	end
	mk.box("Baklykta", V3(0.4, 0.12, 0.05), ctx.cf * CF(0, def.seat[2] - 0.25, def.tailZ + 0.12), C3(200, 20, 20), M.Neon)
	-- seat used for riding (invisible, on top of the saddle)
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(0.9, 0.2, 1.2)
	seat.CFrame = rootCF * CF(0, def.seat[2] + 0.12, def.seat[3] - 0.1)
	seat.Transparency = 1
	seat.Anchored = true
	seat.CanCollide = false
	seat.CanTouch = false
	seat.Disabled = true
	seat.Parent = model
	-- exhaust smoke
	local att = Instance.new("Attachment")
	att.Name = "Avgasrök"
	att.Position = root.CFrame:PointToObjectSpace(Models.engineCF(ctx) * V3(0.6, 0.2, 2.25))
	att.Parent = root
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Rök"
	smoke.Rate = 0
	smoke.Lifetime = NumberRange.new(0.6, 1.2)
	smoke.Speed = NumberRange.new(1, 2)
	smoke.Size = NumberSequence.new(0.2, 1.1)
	smoke.Transparency = NumberSequence.new(0.6, 1)
	smoke.Color = ColorSequence.new(C3(220, 220, 225))
	smoke.Parent = att
	model.Parent = parent
	return model
end

return Models

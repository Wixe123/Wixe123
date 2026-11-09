-- Paint booth: colour library, finishes and spray coverage. Quality from coverage, evenness and runs.
local Paint = {}

Paint.LIBRARY = {
	{ n = "Gloss Black", c = { 18, 18, 20 } }, { n = "Midnight Blue", c = { 22, 34, 84 } }, { n = "Racing Red", c = { 200, 22, 30 } },
	{ n = "Pearl White", c = { 238, 236, 228 } }, { n = "Nardo Grey", c = { 128, 130, 128 } }, { n = "Candy Purple", c = { 120, 30, 170 } },
	{ n = "Neon Green", c = { 70, 230, 60 } }, { n = "Chrome Silver", c = { 196, 200, 206 } }, { n = "Metallic Gold", c = { 205, 160, 60 } },
	{ n = "Sky Blue", c = { 70, 150, 230 } }, { n = "Sunset Orange", c = { 245, 120, 30 } }, { n = "Mint", c = { 140, 215, 190 } },
	{ n = "Bubblegum", c = { 240, 120, 180 } }, { n = "Olive", c = { 100, 110, 50 } }, { n = "Sand", c = { 214, 196, 150 } }, { n = "Yellow", c = { 245, 205, 30 } },
}
-- finishes. Each one changes the real look of the part: Roblox material, reflectance and colour treatment
-- (Paint.look). Only built-in materials are used, so no extra material or texture instances are created.
-- price = base price per paint job (kr) before the size of the part and extra effects.
Paint.FINISH = {
	{ id = "solid", n = "Solid", price = 150 },
	{ id = "metallic", n = "Metallic", price = 350 },
	{ id = "pearl", n = "Pärlemor", price = 500 },
	{ id = "matt", n = "Matt", price = 250 },
	{ id = "glossy", n = "Blank", price = 200 },
	{ id = "chrome", n = "Krom", price = 900 },
	{ id = "carbon", n = "Kolfiber-look", price = 750 },
	{ id = "candy", n = "Candy", price = 650 },
}
Paint.FIN = {}
for _, f in ipairs(Paint.FINISH) do Paint.FIN[f.id] = f end
-- names used by older saves
Paint.FIN.blank, Paint.FIN.parlemor, Paint.FIN.krom = Paint.FIN.glossy, Paint.FIN.pearl, Paint.FIN.chrome

-- settings 0..1 and their defaults: gloss, metallic intensity, reflection, clear coat, colour depth
Paint.SETTINGS = {
	{ id = "g", n = "Glans", def = 0.7 }, { id = "mi", n = "Metallic-intensitet", def = 0.6 }, { id = "rf", n = "Reflektion", def = 0.4 },
	{ id = "cc", n = "Klarlack", def = 0.5 }, { id = "dp", n = "Färgdjup", def = 0.3 },
}

-- parts of a moped that can be painted on their own. panels = panel ids (painted items); names = part names in
-- the chassis models built by Models (slot = the slot those parts belong to). size = how big the job is.
Paint.ZONES = {
	{ id = "frontkapor", n = "Främre kåpor", panels = { "flankV", "flankH", "ben", "styrkapa" }, size = 1.4 },
	{ id = "sidokapor", n = "Sidokåpor", panels = { "sidaV", "sidaH" }, size = 1.6 },
	{ id = "bakkapor", n = "Bakre kåpor", panels = { "bak", "tunnel", "fot" }, size = 1.3 },
	{ id = "front", n = "Front", panels = { "front" }, size = 1.2 },
	{ id = "skarm", n = "Stänkskärm", panels = { "skarm" }, size = 0.8 },
	{ id = "falgar", n = "Fälgar", slots = { "framhjul", "bakhjul" }, names = { "FramhjulFälg", "FramhjulEker", "BakhjulFälg", "BakhjulEker" }, size = 1.0 },
	{ id = "bromsok", n = "Bromsok", slots = { "frambroms", "bakbroms" }, names = { "Bromsok" }, size = 0.5 },
	{ id = "styre", n = "Styre", slots = { "styre" }, names = { "Styre", "Styrstam" }, size = 0.6 },
	{ id = "speglar", n = "Speglar", slots = { "styre" }, names = { "Spegel", "Spegelarm" }, size = 0.4 },
	{ id = "detaljer", n = "Detaljer", slots = { "gaffel" }, names = { "Krona", "Gaffelben" }, size = 0.7 },
}
Paint.ZONE = {}
for _, z in ipairs(Paint.ZONES) do
	Paint.ZONE[z.id] = z
	z.nameSet = {}
	for _, n in ipairs(z.names or {}) do z.nameSet[n] = true end
end
-- which zone a panel id belongs to
Paint.PANEL_ZONE = {}
for _, z in ipairs(Paint.ZONES) do for _, pid in ipairs(z.panels or {}) do Paint.PANEL_ZONE[pid] = z.id end end

local function num01(x, def)
	x = tonumber(x)
	if not x or x ~= x then return def end
	return math.max(0, math.min(1, x))
end
-- a clean paint spec from anything (client data is never trusted)
function Paint.validSpec(t)
	if type(t) ~= "table" then return nil end
	local c = Paint.validColor(t.c)
	local f = type(t.f) == "string" and Paint.FIN[t.f]
	if not c or not f then return nil end
	local s = { c = c, f = f.id }
	for _, st in ipairs(Paint.SETTINGS) do s[st.id] = num01(t[st.id], st.def) end
	return s
end
-- price of painting a zone with a spec: { total, base, effects, size }
function Paint.cost(zoneId, spec)
	local z = Paint.ZONE[zoneId]
	local f = spec and Paint.FIN[spec.f]
	if not z or not f then return nil end
	local effects = 0
	if (spec.cc or 0) > 0.6 then effects = effects + 120 end -- extra clear coat
	if (spec.dp or 0) > 0.6 then effects = effects + 80 end -- deep colour (more layers)
	if f.id == "candy" or f.id == "pearl" then effects = effects + 100 end -- special effect coat
	local sub = f.price + effects
	local total = math.floor(sub * z.size / 10 + 0.5) * 10
	return { total = total, base = f.price, effects = effects, size = z.size, extra = total - sub }
end

-- the look of a paint spec: Color3, Material, Reflectance (needs Roblox types; the server only stores specs)
function Paint.look(spec)
	local f = Paint.FIN[spec.f] or Paint.FIN.glossy
	local c = spec.c or { 200, 200, 200 }
	local g, mi, rf = num01(spec.g, 0.7), num01(spec.mi, 0.6), num01(spec.rf, 0.4)
	local cc, dp = num01(spec.cc, 0.5), num01(spec.dp, 0.3)
	local base = Color3.fromRGB(c[1], c[2], c[3])
	local deep = Color3.new(base.R * 0.55, base.G * 0.55, base.B * 0.55)
	local col = base:Lerp(deep, dp * 0.5)
	local M = Enum.Material
	local mat, refl
	local shine = 0.4 + 0.6 * g -- gloss scales all reflections
	if f.id == "solid" then
		mat = g < 0.3 and M.Plastic or M.SmoothPlastic
		refl = (0.02 + 0.08 * rf + 0.05 * cc) * shine
	elseif f.id == "matt" then
		mat = M.Plastic
		refl = 0
		col = col:Lerp(Color3.new(col.R * 0.9, col.G * 0.9, col.B * 0.9), 0.5)
	elseif f.id == "glossy" then
		mat = M.SmoothPlastic
		refl = (0.08 + 0.2 * rf + 0.1 * cc) * shine
	elseif f.id == "metallic" then
		mat = mi >= 0.35 and M.Metal or M.SmoothPlastic
		refl = (0.05 + 0.2 * rf * (0.5 + mi) + 0.08 * cc) * shine
		col = col:Lerp(Color3.new(1, 1, 1), 0.12 * mi)
	elseif f.id == "pearl" then
		mat = M.SmoothPlastic
		refl = (0.16 + 0.18 * rf + 0.08 * cc) * shine
		col = col:Lerp(Color3.fromRGB(245, 240, 255), 0.18)
	elseif f.id == "chrome" then
		mat = M.Foil
		refl = 0.45 + 0.4 * rf * shine
		col = col:Lerp(Color3.fromRGB(205, 210, 216), 0.55 * (1 - dp))
	elseif f.id == "carbon" then
		mat = M.Fabric -- woven surface: the closest built-in material to carbon fibre
		refl = (0.03 + 0.15 * cc) * shine
		col = col:Lerp(Color3.fromRGB(22, 22, 24), 0.82)
	else -- candy: deep, saturated colour under a thick shiny coat (opaque: Glass would show what is behind)
		mat = M.SmoothPlastic
		refl = (0.22 + 0.25 * cc + 0.1 * rf) * shine
		col = col:Lerp(deep, 0.25 + dp * 0.4)
	end
	if (spec.q or 1) < 0.5 then mat = M.Plastic; col = col:Lerp(Color3.fromRGB(90, 90, 90), 0.15); refl = refl * 0.4 end
	return col, mat, math.max(0, math.min(1, refl))
end
function Paint.apply(part, spec)
	local col, mat, refl = Paint.look(spec)
	part.Color, part.Material, part.Reflectance = col, mat, refl
end

-- decals (fictional brands only)
Paint.DECALS = {
	{ id = "vippa", text = "VIPPA", c = { 240, 240, 240 } }, { id = "fartek", text = "FARTEK", c = { 205, 38, 38 } },
	{ id = "nordtrim", text = "NORDTRIM", c = { 240, 196, 25 } }, { id = "snabbo", text = "SNABBO", c = { 245, 120, 20 } },
}
Paint.DECAL = {}
for _, d in ipairs(Paint.DECALS) do Paint.DECAL[d.id] = d end

Paint.COLS, Paint.ROWS = 10, 6

function Paint.validHex(s)
	if type(s) ~= "string" then return nil end
	s = s:gsub("^#", "")
	if not s:match("^%x%x%x%x%x%x$") then return nil end
	return { tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16) }
end
function Paint.hex(c) return string.format("#%02X%02X%02X", c[1], c[2], c[3]) end
function Paint.validColor(c)
	if type(c) ~= "table" then return nil end
	local r = {}
	for i = 1, 3 do
		local v = tonumber(c[i])
		if not v then return nil end
		r[i] = math.floor(math.max(0, math.min(255, v)) + 0.5)
	end
	return r
end

function Paint.new()
	local s = { cells = {}, t = 0 }
	for i = 1, Paint.COLS * Paint.ROWS do s.cells[i] = 0 end
	return s
end
-- spray at (u,v) 0..1 over the panel for dt seconds; dist = gun distance factor (1 = ideal); even from the gun.
-- cw, ch: cell size in studs (the spray is round on the panel whatever its shape); without them, in cells.
function Paint.spray(s, u, v, dt, dist, even, cw, ch)
	even = even or 0
	dist = dist or 1
	local studs = cw and ch and cw > 0 and ch > 0
	local radius = studs and 0.6 * dist or 1.6 * dist
	local rate = 3.2 / (dist * dist) * dt
	local cx, cy = u * Paint.COLS + 0.5, v * Paint.ROWS + 0.5
	for row = 1, Paint.ROWS do
		for col = 1, Paint.COLS do
			local dx, dy = col - cx, row - cy
			if studs then dx, dy = dx * cw, dy * ch end
			local d = math.sqrt(dx * dx + dy * dy)
			if d < radius then
				local i = (row - 1) * Paint.COLS + col
				local f = 1 - d / radius
				f = f * (1 - 0.4 * even) + 0.4 * even * (d < radius * 0.8 and 0.7 or 0.2)
				s.cells[i] = s.cells[i] + rate * f
			end
		end
	end
	s.t = s.t + dt
end
function Paint.coverage(s)
	local c = 0
	for _, x in ipairs(s.cells) do if x >= 0.8 then c = c + 1 end end
	return c / #s.cells
end
function Paint.result(s)
	if type(s) ~= "table" or type(s.cells) ~= "table" then return nil end
	local n = Paint.COLS * Paint.ROWS
	local cover, runs, sum = 0, 0, 0
	local vals = {}
	for i = 1, n do
		local x = math.max(0, math.min(4, tonumber(s.cells[i]) or 0))
		vals[i] = x
		sum = sum + math.min(x, 1.6)
		if x >= 0.8 then cover = cover + 1 end
		if x > 2.4 then runs = runs + 1 end
	end
	local mean = sum / n
	local var = 0
	for i = 1, n do var = var + (math.min(vals[i], 1.6) - mean) ^ 2 end
	local even = math.max(0, 1 - math.sqrt(var / n) * 1.5)
	cover, runs = cover / n, runs / n
	local q = math.max(0, math.min(1, cover * 0.55 + even * 0.45 - runs * 1.2))
	local label = q >= 0.9 and "Perfekt" or (q >= 0.75 and "Bra" or (q >= 0.5 and "OK" or "Fläckig"))
	return { cover = cover, even = even, runs = runs, q = q, label = label }
end

return Paint

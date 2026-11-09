-- Paint booth: colour library, finishes and spray coverage. Quality from coverage, evenness and runs.
local Paint = {}

Paint.LIBRARY = {
	{ n = "Gloss Black", c = { 18, 18, 20 } }, { n = "Midnight Blue", c = { 22, 34, 84 } }, { n = "Racing Red", c = { 200, 22, 30 } },
	{ n = "Pearl White", c = { 238, 236, 228 } }, { n = "Nardo Grey", c = { 128, 130, 128 } }, { n = "Candy Purple", c = { 120, 30, 170 } },
	{ n = "Neon Green", c = { 70, 230, 60 } }, { n = "Chrome Silver", c = { 196, 200, 206 } }, { n = "Metallic Gold", c = { 205, 160, 60 } },
	{ n = "Sky Blue", c = { 70, 150, 230 } }, { n = "Sunset Orange", c = { 245, 120, 30 } }, { n = "Mint", c = { 140, 215, 190 } },
	{ n = "Bubblegum", c = { 240, 120, 180 } }, { n = "Olive", c = { 100, 110, 50 } }, { n = "Sand", c = { 214, 196, 150 } }, { n = "Yellow", c = { 245, 205, 30 } },
}
-- finishes: Roblox material + reflectance range (gloss slider picks within it)
Paint.FINISH = {
	{ id = "blank", n = "Blank", mat = "SmoothPlastic", refl = { 0.02, 0.18 } },
	{ id = "matt", n = "Matt", mat = "Plastic", refl = { 0, 0.02 } },
	{ id = "metallic", n = "Metallic", mat = "Metal", refl = { 0.05, 0.3 } },
	{ id = "parlemor", n = "Pärlemor", mat = "SmoothPlastic", refl = { 0.15, 0.35 } },
	{ id = "krom", n = "Krom", mat = "Foil", refl = { 0.35, 0.6 } },
}
Paint.FIN = {}
for _, f in ipairs(Paint.FINISH) do Paint.FIN[f.id] = f end

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

-- Cylinder porting: four port windows, each a grid of cells that are ground down to the marked depth.
-- The client sends the cell depths when done; the server computes the quality from them with result().
local Porting = {}

Porting.COLS, Porting.ROWS = 6, 3
Porting.ZONES = {
	{ id = "avgas", n = "Avgasport", face = "front", w = 0.62, h = 0.36 },
	{ id = "overV", n = "Sidport vänster", face = "left", w = 0.4, h = 0.26 },
	{ id = "overH", n = "Sidport höger", face = "right", w = 0.4, h = 0.26 },
	{ id = "insug", n = "Insugsport", face = "back", w = 0.5, h = 0.3 },
}
Porting.BY_ID = {}
for _, z in ipairs(Porting.ZONES) do Porting.BY_ID[z.id] = z end
Porting.TARGET = 1.0 -- depth that counts as done
Porting.OVER = 1.5 -- deeper than this is over-ported (bad)

function Porting.new()
	local s = { cells = {}, inside = 0, outside = 0 }
	for _, z in ipairs(Porting.ZONES) do
		local c = {}
		for i = 1, Porting.COLS * Porting.ROWS do c[i] = 0 end
		s.cells[z.id] = c
	end
	return s
end

-- grind at (u,v) in 0..1 zone coordinates for dt seconds; speed from the tool; returns true if inside the zone
function Porting.grind(s, zoneId, u, v, dt, speed)
	local cells = s.cells[zoneId]
	if not cells then return false end
	speed = speed or 1
	if u < -0.02 or u > 1.02 or v < -0.02 or v > 1.02 then
		s.outside = s.outside + dt
		return false
	end
	s.inside = s.inside + dt
	local cx, cy = u * Porting.COLS + 0.5, v * Porting.ROWS + 0.5
	for row = 1, Porting.ROWS do
		for col = 1, Porting.COLS do
			local d = math.sqrt((col - cx) ^ 2 + (row - cy) ^ 2)
			if d < 1.5 then
				local i = (row - 1) * Porting.COLS + col
				cells[i] = cells[i] + dt * 1.8 * speed * (1 - d / 1.5)
			end
		end
	end
	return true
end

function Porting.zoneProgress(s, zoneId)
	local cells = s.cells[zoneId]
	local sum = 0
	for _, d in ipairs(cells) do sum = sum + math.min(d, Porting.TARGET) end
	return sum / (#cells * Porting.TARGET)
end
function Porting.progress(s)
	local t = 0
	for _, z in ipairs(Porting.ZONES) do t = t + Porting.zoneProgress(s, z.id) end
	return t / #Porting.ZONES
end

-- quality metrics 0..1 and an overall q; label in Swedish
function Porting.result(s)
	local all = {}
	for _, z in ipairs(Porting.ZONES) do
		local cells = s.cells and s.cells[z.id]
		if type(cells) ~= "table" then return nil end
		for i = 1, Porting.COLS * Porting.ROWS do
			local d = tonumber(cells[i]) or 0
			all[#all + 1] = math.max(0, math.min(3, d))
		end
	end
	local n = #all
	local cover, mean, over = 0, 0, 0
	for _, d in ipairs(all) do
		cover = cover + math.min(d, Porting.TARGET) / Porting.TARGET
		mean = mean + d
		if d > Porting.OVER then over = over + 1 end
	end
	cover, mean = cover / n, mean / n
	local var = 0
	for _, d in ipairs(all) do var = var + (math.min(d, 1.6) - math.min(mean, 1.6)) ^ 2 end
	local even = math.max(0, 1 - math.sqrt(var / n) * 1.6)
	local inside, outside = tonumber(s.inside) or 0, tonumber(s.outside) or 0
	local precision = (inside + outside) > 0 and inside / (inside + outside) or 0
	local overF = over / n
	local q = cover * 0.45 + even * 0.3 + precision * 0.25 - overF * 0.8
	q = math.max(0, math.min(1, q))
	if cover < 0.5 then q = math.min(q, 0.3) end
	local label = q >= 0.9 and "Perfekt" or (q >= 0.75 and "Bra" or (q >= 0.5 and "OK" or "Dålig"))
	return { cover = cover, even = even, precision = precision, over = overF, q = q, label = label }
end

return Porting

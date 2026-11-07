-- Cylinder porting: the marked areas (ports) are split into cells. The tool tip removes material in the cells it
-- touches while the player holds the button. Quality comes from evenness, precision (time outside the areas)
-- and over-porting. Coordinates u, v in [-1, 1] on the cylinder's work view (seen from above, exhaust towards +v).
local Porting = {}

Porting.ZONES = {
	{ id = "exhaust", n = "Avgasport", u = { -0.18, 0.18 }, v = { 0.52, 0.86 }, color = Color3.fromRGB(255, 120, 40) },
	{ id = "transfer_l", n = "Överströmning vänster", u = { -0.86, -0.6 }, v = { -0.22, 0.3 }, color = Color3.fromRGB(60, 170, 255) },
	{ id = "transfer_r", n = "Överströmning höger", u = { 0.6, 0.86 }, v = { -0.22, 0.3 }, color = Color3.fromRGB(60, 170, 255) },
	{ id = "boost", n = "Boostport", u = { -0.14, 0.14 }, v = { -0.86, -0.6 }, color = Color3.fromRGB(120, 255, 140) },
}
Porting.CU, Porting.CV = 4, 3 -- cells per zone
Porting.RADIUS = 0.07 -- the tool tip's reach
Porting.RATE = 0.55 -- work per second at full contact (1 = finished cell)

function Porting.new(steady, training)
	local s = { cells = {}, on = 0, off = 0, t = 0, steady = steady or 0.6, training = training == true }
	for _, z in ipairs(Porting.ZONES) do
		s.cells[z.id] = {}
		for i = 1, Porting.CU * Porting.CV do s.cells[z.id][i] = 0 end
	end
	return s
end

local function cellCenter(z, i)
	local cu, cv = (i - 1) % Porting.CU, math.floor((i - 1) / Porting.CU)
	return z.u[1] + (cu + 0.5) / Porting.CU * (z.u[2] - z.u[1]), z.v[1] + (cv + 0.5) / Porting.CV * (z.v[2] - z.v[1])
end
Porting.cellCenter = cellCenter

-- one time step: the tool is at (u, v), grinding = button held. Returns the zone the tool is in (or nil).
function Porting.grind(s, u, v, dt, grinding)
	if not grinding then return nil end
	s.t = s.t + dt
	local hit = nil
	for _, z in ipairs(Porting.ZONES) do
		if u >= z.u[1] - Porting.RADIUS and u <= z.u[2] + Porting.RADIUS and v >= z.v[1] - Porting.RADIUS and v <= z.v[2] + Porting.RADIUS then
			hit = z
			for i = 1, Porting.CU * Porting.CV do
				local cu, cv = cellCenter(z, i)
				local d = math.sqrt((cu - u) ^ 2 + (cv - v) ^ 2)
				local cellR = math.max((z.u[2] - z.u[1]) / Porting.CU, (z.v[2] - z.v[1]) / Porting.CV) * 0.6
				if d < Porting.RADIUS + cellR then
					local w = 1 - d / (Porting.RADIUS + cellR)
					s.cells[z.id][i] = s.cells[z.id][i] + Porting.RATE * w * dt
				end
			end
		end
	end
	if hit then s.on = s.on + dt else s.off = s.off + dt end
	return hit
end

function Porting.zoneProgress(s, zid)
	local t = 0
	for _, w in ipairs(s.cells[zid]) do t = t + math.min(1, w) end
	return t / (Porting.CU * Porting.CV)
end

-- result: coverage (0..1), evenness, precision, over (share of cells over 1.4), q (0..1), deg (raised timing)
function Porting.result(s)
	local all, sum, over = {}, 0, 0
	for _, z in ipairs(Porting.ZONES) do for _, w in ipairs(s.cells[z.id]) do table.insert(all, w); sum = sum + math.min(1, w); if w > 1.4 then over = over + 1 end end end
	local nCells = #all
	local coverage = sum / nCells
	local mean = 0
	for _, w in ipairs(all) do mean = mean + math.min(1.6, w) end
	mean = mean / nCells
	local var = 0
	for _, w in ipairs(all) do var = var + (math.min(1.6, w) - mean) ^ 2 end
	local sd = math.sqrt(var / nCells)
	local evenness = math.max(0, 1 - sd / 0.5)
	local precision = (s.on + s.off) > 0 and s.on / (s.on + s.off) or 0
	local overShare = over / nCells
	local q = math.max(0, math.min(1, (0.4 * evenness + 0.4 * precision + 0.2 * (1 - overShare)) * coverage * (0.85 + 0.15 * s.steady)))
	local deg = 4 * coverage * (1 - 0.5 * overShare)
	local label = q > 0.8 and "Utmärkt" or q > 0.6 and "Bra" or q > 0.35 and "Okej" or "Dålig"
	return { coverage = coverage, evenness = evenness, precision = precision, over = overShare, q = q, deg = deg, label = label }
end

return Porting

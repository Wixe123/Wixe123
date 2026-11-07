-- Paint: colour library, paint types and spray quality. The panel's sprayed side is split into a grid; the spray
-- gun adds paint with a soft edge. Quality comes from coverage, evenness and runs (too much paint in one place).
local Paint = {}

Paint.LIBRARY = {
	{ "Gloss Black", "#0e0e10", "gloss" }, { "Midnight Blue", "#16234a", "metal" }, { "Racing Red", "#c8102e", "gloss" }, { "Pearl White", "#f4f1ea", "pearl" },
	{ "Nardo Grey", "#7c7f80", "gloss" }, { "Candy Purple", "#5a1a7a", "pearl" }, { "Neon Green", "#39ff14", "gloss" }, { "Chrome Silver", "#d9dde2", "chrome" },
	{ "Metallic Gold", "#c9a227", "metal" }, { "Sky Blue", "#4aa3ff", "gloss" }, { "Orange", "#ff7f11", "gloss" }, { "Matt Black", "#1a1a1a", "matt" },
}
Paint.FINISH = { gloss = "Blank", matt = "Matt", metal = "Metallic", pearl = "Pärlemor", chrome = "Krom" }
Paint.GW, Paint.GH = 8, 5
Paint.RADIUS = 0.32 -- spray width in u/v units (the panel is -1..1 in both directions)
Paint.RATE = 0.9

function Paint.new(even)
	local s = { g = {}, t = 0, even = even or 0.7 }
	for i = 1, Paint.GW * Paint.GH do s.g[i] = 0 end
	return s
end
function Paint.cellCenter(i)
	local x, y = (i - 1) % Paint.GW, math.floor((i - 1) / Paint.GW)
	return -1 + (x + 0.5) * 2 / Paint.GW, -1 + (y + 0.5) * 2 / Paint.GH
end
-- spray at (u, v) for dt seconds; a better gun (even) gives a softer, wider spray pattern
function Paint.spray(s, u, v, dt)
	s.t = s.t + dt
	local r = Paint.RADIUS * (0.85 + 0.3 * s.even)
	for i = 1, Paint.GW * Paint.GH do
		local cu, cv = Paint.cellCenter(i)
		local d = math.sqrt((cu - u) ^ 2 + (cv - v) ^ 2)
		if d < r then
			local w = 1 - (d / r) ^ (1 + s.even)
			s.g[i] = s.g[i] + Paint.RATE * w * dt
		end
	end
end
function Paint.result(s)
	local n, cov, runs, sum = Paint.GW * Paint.GH, 0, 0, 0
	for _, w in ipairs(s.g) do if w >= 0.8 then cov = cov + 1 end; if w > 1.7 then runs = runs + 1 end; sum = sum + math.min(1.8, w) end
	local mean = sum / n
	local var = 0
	for _, w in ipairs(s.g) do var = var + (math.min(1.8, w) - mean) ^ 2 end
	local evenness = math.max(0, 1 - math.sqrt(var / n) / 0.45)
	local coverage, runShare = cov / n, runs / n
	local q = math.max(0, math.min(1, coverage * (0.6 * evenness + 0.4 * (1 - runShare * 2))))
	local label = q > 0.8 and "Utmärkt" or q > 0.6 and "Bra" or q > 0.35 and "Okej" or "Fläckig"
	return { coverage = coverage, evenness = evenness, runs = runShare, q = q, label = label }
end
function Paint.validHex(h) return type(h) == "string" and h:match("^#%x%x%x%x%x%x$") ~= nil end
return Paint

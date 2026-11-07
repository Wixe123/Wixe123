-- The world layout: roads (also drawn on the minimap), places and job destinations. Ground top is y = 0.
local Config = require(script.Parent.Config)
local Map = {}

local SZ = Config.STREET_Z
Map.ROAD_Y = 0.12 -- road surface height
-- straight road segments: a, b = {x, z}; w = width; name for the minimap
Map.ROADS = {
	{ a = { -330, SZ }, b = { 330, SZ }, w = 16, n = "Garagegatan" },
	{ a = { 0, SZ - 8 }, b = { 0, -530 }, w = 16, n = "Storgatan" },
	{ a = { -330, -290 }, b = { 330, -290 }, w = 14, n = "Industrivägen" },
	{ a = { -330, SZ - 8 }, b = { -330, -282 }, w = 12, n = "Västra vägen" },
	{ a = { 330, SZ - 8 }, b = { 330, -282 }, w = 12, n = "Östra vägen" },
	{ a = { 330, SZ + 8 }, b = { 330, 200 }, w = 11, n = "Landsvägen" },
	{ a = { 330, 200 }, b = { 520, 390 }, w = 11, n = "Landsvägen" },
	{ a = { 520, 390 }, b = { 520, 470 }, w = 11, n = "Gårdsvägen" },
	{ a = { -230, SZ + 8 }, b = { -230, 120 }, w = 12, n = "Banvägen" },
	{ a = { -330, 330 }, b = { 60, 330 }, w = 16, n = "Dragstrip", drag = true },
	{ a = { -230, 120 }, b = { -230, 322 }, w = 12, n = "Banvägen" },
}
-- the test track: an oval made of segments
Map.TRACK = { cx = -110, cz = 210, len = 150, r = 55, w = 14 }
do
	local t = Map.TRACK
	local pts = {}
	local n = 14
	for i = 0, n do local a = math.pi / 2 + i / n * math.pi; pts[#pts + 1] = { t.cx - t.len / 2 + math.cos(a) * t.r, t.cz - math.sin(a) * t.r } end
	for i = 0, n do local a = -math.pi / 2 + i / n * math.pi; pts[#pts + 1] = { t.cx + t.len / 2 + math.cos(a) * t.r, t.cz - math.sin(a) * t.r } end
	pts[#pts + 1] = pts[1]
	for i = 1, #pts - 1 do Map.ROADS[#Map.ROADS + 1] = { a = pts[i], b = pts[i + 1], w = t.w, n = "Testbanan", track = true } end
	Map.ROADS[#Map.ROADS + 1] = { a = { -230, 210 }, b = { t.cx - t.len / 2 - t.r, 210 }, w = 12, n = "Testbanan" }
end

-- job destinations (x, z) and other named places
Map.PLACES = {
	norr = { x = 0, z = -545, n = "Verkstad Norr" },
	hamn = { x = -360, z = -330, n = "Hamnens lager" },
	macken = { x = 42, z = -130, n = "Macken" },
	gard = { x = 520, z = 485, n = "Lindgårdens gård" },
	ind = { x = 240, z = -318, n = "Industriverkstaden" },
}
Map.DELIVER_RADIUS = 14

-- distance from a point to the nearest road centreline, and that road
function Map.nearestRoad(x, z)
	local best, bestR = math.huge, nil
	for _, r in ipairs(Map.ROADS) do
		local ax, az, bx, bz = r.a[1], r.a[2], r.b[1], r.b[2]
		local dx, dz = bx - ax, bz - az
		local l2 = dx * dx + dz * dz
		local t = l2 > 0 and math.max(0, math.min(1, ((x - ax) * dx + (z - az) * dz) / l2)) or 0
		local px, pz = ax + dx * t, az + dz * t
		local d = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		if d < best then best, bestR = d, r end
	end
	return best, bestR
end
function Map.onRoad(x, z) local d, r = Map.nearestRoad(x, z); return d <= r.w / 2 + 0.5 end

return Map

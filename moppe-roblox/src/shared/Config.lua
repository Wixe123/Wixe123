-- Moppe Garage (Roblox): all data in one place. Same values as the web version (moppe/index.html).
-- Numbers are game tuning values, not measured data.
local Config = {}

Config.KITS = {
	{ n = "Original 50 cc", cc = 50, ex = 178, q = 1 },
	{ n = "Sport 70 cc", cc = 70, ex = 184, q = 1.05 },
	{ n = "Race 70 cc", cc = 70, ex = 192, q = 1.08 },
}
Config.EXH = {
	{ n = "Original", t = 7000, w = 3600, g = 0.85, col = Color3.fromRGB(119, 119, 119), l = 0.5 },
	{ n = "Touring", t = 8000, w = 4000, g = 0.92, col = Color3.fromRGB(153, 153, 153), l = 0.6 },
	{ n = "Sport", t = 9500, w = 3300, g = 1, col = Color3.fromRGB(204, 204, 204), l = 0.7 },
	{ n = "Mellankammare", t = 10500, w = 2800, g = 1.04, col = Color3.fromRGB(216, 216, 224), l = 0.85 },
	{ n = "Race-kammare", t = 12000, w = 2100, g = 1.1, col = Color3.fromRGB(176, 160, 144), l = 1 },
}
Config.CARB = { 12, 17.5, 19, 21, 24 }
Config.GEARS = { 3.0, 1.95, 1.45, 1.12 }

-- wb = wheelbase (m), wr = wheel radius (m), fd = final drive. Roblox: 1 stud = 0.28 m (STUD below)
Config.MOPEDS = {
	{ id = "jog", n = "Jogga 50", cvt = true, cool = "air", fan = true, fam = "V-AC", m = 85, wb = 1.2, wr = 0.17, fd = 9.4, price = 6000,
		d = { jet = 58, port = 0, roller = 10, col = Color3.fromRGB(230, 57, 70), seat = Color3.fromRGB(34, 34, 34), num = "7" } },
	{ id = "rok", n = "Aerox 50", cvt = true, cool = "liquid", fan = false, fam = "H-LC", m = 98, wb = 1.3, wr = 0.26, fd = 13, price = 9000,
		d = { jet = 85, port = 0, roller = 9, col = Color3.fromRGB(29, 111, 224), seat = Color3.fromRGB(34, 34, 34), num = "27" } },
	{ id = "dt", n = "Enduro DT 50", cvt = false, cool = "air", fan = false, fam = "G-AC", m = 80, wb = 1.3, wr = 0.22, fd = 12.8, price = 8000,
		d = { jet = 85, port = 0, roller = 9, col = Color3.fromRGB(244, 194, 13), seat = Color3.fromRGB(34, 34, 34), num = "3" } },
}
Config.BY_ID = {}
for _, m in ipairs(Config.MOPEDS) do Config.BY_ID[m.id] = m end

Config.FAM = { ["V-AC"] = "Vertikal luftkyld skotermotor", ["H-LC"] = "Horisontell vätskekyld skotermotor", ["G-AC"] = "Växlad luftkyld motor" }

-- player garages (metres): 6 plots in a row along an industrial street, doors towards -Z
Config.PLOTS = {}
for i = 1, 6 do Config.PLOTS[i] = { x = (i - 3.5) * 32, z = 0 } end
Config.STREET_Z = -16 -- the street in front of the garages
Config.PAINT_DRY = 20 -- seconds before freshly painted parts can be fitted
Config.STUD = 0.28 -- meter per stud (Roblox character ≈ 5 studs ≈ 1.4–1.8 m)
Config.AMB = 15 -- outside temperature, °C (assumed)

-- economy (in-game kronor, not real prices)
Config.ECON = {
	start = 4000,
	distKr = 5, distM = 100, -- 5 kr per 100 m with the engine running
	cleanKr = 40, cleanM = 2000, -- 40 kr per 2 km without crash/overheating
	crashKr = 50,
	mopSell = 0.6,
	maxSpeed = 40, -- m/s, faster movement than this is not paid (anti-cheat)
}
-- wheelie: rewards with diminishing returns, cap per minute
Config.WHEELIE = { h = { jog = 0.55, rok = 0.55, dt = 0.65 }, fr = 0.45, back = 0.2, pull = 400, pullT = 0.3, damp = 2.5, over = 0.14,
	minV = 8 / 3.6, minT = 0.5, max = 200, tau = 5, rate = 400 }

return Config

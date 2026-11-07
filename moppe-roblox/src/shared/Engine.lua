-- Engine model, ported line by line from the web version (calc/torque/target/therm in moppe/index.html).
local Config = require(script.Parent.Config)
local Engine = {}

local function clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end

-- c: effective config (tuning values + values from installed parts, see Catalog.ecfg)
function Engine.calc(c)
	local k, e = Config.KITS[c.kit + 1], Config.EXH[c.exh + 1]
	local D, dia = k.cc / 50, Config.CARB[c.carb + 1]
	local fdia, fc = math.min(dia, c.maxd or 99), c.fcap or 1 -- the intake throttles flow, a sport filter adds air
	local ex = k.ex + c.port
	local portPk = 7000 + (ex - 175) * 233
	local pk = 0.4 * portPk + 0.6 * e.t
	local match = math.exp(-((portPk - e.t) / 2800) ^ 2)
	local opt = dia * 5 * math.sqrt(D) * (0.85 + pk / 60000)
	local m = c.jet / opt / math.sqrt(fc)
	local fuelF
	if m < 1 then fuelF = 1 - 3 * (1 - m) ^ 2 else fuelF = 1 - 0.8 * (m - 1) ^ 2 end
	fuelF = math.max(0.45, fuelF)
	local cap, need = (fdia / 17.5) ^ 2 * fc, D * pk / 12000
	local restr = math.min(1, math.sqrt(cap / need))
	return {
		ex = ex, portPk = portPk, pk = pk, w = e.w, match = match, m = m, fuelF = fuelF,
		resp = fuelF * (0.55 + 0.45 * match) * (0.7 + 0.3 * restr), restr = restr, over = math.max(0, cap / need - 1.6),
		tmax = 4.2 * D * k.q * e.g * (0.75 + 0.25 * match) * (c.tmf or 1), -- tmf: crankshaft, reed valve and porting quality
		heat = 1 + math.max(0, 1 - m) * 2.2 + math.max(0, ex - 185) * 0.03 + (1 - match) * 0.3 + math.max(0, m - 1.25) * 0.3,
		lim = math.min(c.icap or 1e9, math.max(9500, pk * 1.2 + 500)), -- ignition rev limit
		cond = 1,
	}
end

function Engine.torque(P, rpm)
	local g = math.exp(-((rpm - P.pk) / P.w) ^ 2)
	local t = P.tmax * (0.3 + 0.7 * g) * P.fuelF
	t = t * (1 - (1 - P.restr) * math.min(1, rpm / P.pk))
	t = t * (1 - math.min(0.35, P.over * 0.3) * math.max(0, 1 - rpm / (P.pk * 0.9)))
	if rpm > P.lim then return 0 end
	return t * (P.cond or 1)
end

-- peak power in hp from the curve (same sampling as the web dyno)
function Engine.peakHp(P)
	local hb, at = 0, 0
	for r = 2000, 15000, 250 do
		local h = Engine.torque(P, r) * r / 9549 * 1.341
		if h > hb then hb, at = h, r end
	end
	return hb, at
end

function Engine.target(c) return 5200 + 780 * (14 - c.roller) + (c.cdt or 0) end

-- ---------- heat model ----------
-- Air-cooled: one lump (cylinder+head), the sensor is a CHT under the spark plug.
-- Liquid-cooled: cylinder and coolant as two lumps, the sensor is in the coolant.
Engine.TH = {
	jog = { C = 2500, a0 = 4, af = 5.3, av = 0.6 },
	dt = { C = 2500, a0 = 6, af = 0, av = 4.7 },
	rok = { C = 1500, G = 100, a0 = 2, Cw = 4200, r0 = 10, rv = 9.3 },
}
Engine.BAND = {
	air = { lab = "Topptemp (CHT)", b = { { 50, "kall, varmkör", Color3.fromRGB(74, 163, 255) }, { 200, "normal", Color3.fromRGB(107, 211, 107) }, { 230, "varm", Color3.fromRGB(255, 176, 32) }, { 1e9, "ÖVERHETTAD", Color3.fromRGB(255, 106, 74) } } },
	liquid = { lab = "Kylvätska", b = { { 50, "kall, varmkör", Color3.fromRGB(74, 163, 255) }, { 95, "normal", Color3.fromRGB(107, 211, 107) }, { 110, "varm", Color3.fromRGB(255, 176, 32) }, { 1e9, "KOKAR", Color3.fromRGB(255, 106, 74) } } },
}
Engine.T_LOSS, Engine.T_DMG, Engine.T_BOIL = 225, 240, 120

function Engine.newThermal() return { tc = Config.AMB, tw = Config.AMB, boil = false, dmg = 0 } end

-- s: thermal state, Q: heat input (W), rpm, v (m/s), cf: cooling factor from parts
function Engine.therm(mop, s, dt, Q, rpm, v, cf)
	local t, AMB = Engine.TH[mop.id], Config.AMB
	cf = cf or 1
	if mop.cool == "liquid" then
		local hr = (t.r0 + t.rv * cf * v ^ 0.8) * (s.boil and 0.35 or 1)
		local q = t.G * (s.boil and 0.4 or 1) * (s.tc - s.tw)
		s.tc = s.tc + (Q - q - t.a0 * (s.tc - AMB)) / t.C * dt
		s.tw = math.min(Engine.T_BOIL, s.tw + (q - hr * (s.tw - AMB)) / t.Cw * dt)
		if s.tw >= Engine.T_BOIL - 0.5 then s.boil = true elseif s.tw < 100 then s.boil = false end
	else
		local hA = t.a0 + cf * (t.af * (rpm / 1000) ^ 0.8 + t.av * v ^ 0.8)
		s.tc = s.tc + (Q - hA * (s.tc - AMB)) / t.C * dt
	end
	if s.tc > Engine.T_DMG then s.dmg = math.min(1, s.dmg + dt * (s.tc - Engine.T_DMG) / 900) end
end

function Engine.heatF(s) return 1 - math.min(0.45, math.max(0, (s.tc - Engine.T_LOSS) / 100)) end

function Engine.heatIn(P, torqueNm, rpm) return P.heat * (1.4 * torqueNm * rpm * math.pi / 30 + 300 * rpm / 1000) end

function Engine.tinfo(mop, s)
	local B = Engine.BAND[mop.cool]
	local v = mop.cool == "liquid" and s.tw or s.tc
	for _, b in ipairs(B.b) do
		if v < b[1] then return { lab = B.lab, v = v, band = b[2], col = b[3], tc = s.tc, dmg = s.dmg } end
	end
end

Engine.clamp = clamp
return Engine

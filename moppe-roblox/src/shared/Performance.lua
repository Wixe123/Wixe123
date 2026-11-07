-- Engine and moped performance from the mounted parts. A simplified, game-balanced model:
-- the cylinder gives the base power and rev range; carburettor, intake, exhaust, ignition and porting scale it,
-- parts that are too small for the cylinder hold it back, and the CVT (variator, rollers, clutch) decides
-- where the engine runs at each speed. The same functions drive the riding simulation.
local Parts = require(script.Parent.Parts)
local Performance = {}

local KMH = 3.6
Performance.MASS = 152 -- moped + rider, kg
Performance.CDA = 0.62 -- drag area m^2
Performance.CRR = 0.016
Performance.WHEEL_R = 0.27 -- m
Performance.GEARBOX = 12.4 -- fixed reduction after the CVT
Performance.CVT_LOW = 2.55

local function st(items, map, sock, key, default)
	local uid = map and map[sock]
	local it = uid and items[uid]
	local p = it and Parts.get(it.sku)
	local v = p and p.stats[key]
	if v == nil then return default end
	return v
end
local function item(items, map, sock)
	local uid = map and map[sock]
	return uid and items[uid]
end

-- level mismatch: a part below the cylinder's level holds power back
local function match(partLvl, cylLvl)
	local d = (partLvl or 0) - (cylLvl or 0)
	if d >= 0 then return 1 + 0.025 * math.min(d, 2) end
	return 1 + 0.11 * d
end

-- cfg from an engine socket map; chassis map optional
function Performance.config(items, engine, chassis, jet)
	local c = {}
	jet = jet or 0 -- -2 (rich) .. +2 (lean)
	local cyl = item(items, engine, "cylinder")
	local lvl = st(items, engine, "cylinder", "lvl", 0)
	local hp = st(items, engine, "cylinder", "hp", 3.0)
	local rpm = st(items, engine, "cylinder", "rpm", 6500)
	local cc = st(items, engine, "cylinder", "cc", 49.3)
	local stroke = st(items, engine, "vevaxel", "stroke", 39.2)
	cc = cc * stroke / 39.2
	hp = hp * (stroke / 39.2) ^ 0.8
	-- porting result stored on the cylinder item
	local portQ = cyl and cyl.port and cyl.port.q
	if portQ then
		hp = hp * (0.92 + 0.17 * portQ)
	end
	-- multipliers from parts
	for _, s in ipairs({ "vevhus", "vevaxel", "fotpackning", "cdi", "spole" }) do hp = hp * st(items, engine, s, "hp", 1) end
	hp = hp * st(items, engine, "topplock", "comp", 1)
	local exhMult = st(items, chassis, "avgas", "mult", 1.0)
	local exhLvl = st(items, chassis, "avgas", "lvl", 0)
	hp = hp * exhMult * match(exhLvl, lvl)
	hp = hp * match(st(items, engine, "reed", "lvl", 0), lvl)
	hp = hp * match(st(items, engine, "insug", "lvl", 0), lvl)
	hp = hp * match(st(items, engine, "luftfilter", "lvl", 0), lvl)
	-- jetting: lean gives a little power and much more heat
	hp = hp * (1 + 0.03 * jet - 0.012 * jet * jet)
	-- carburettor flow: soft cap
	local cap = st(items, engine, "forgasare", "cap", 4.6)
	if hp > cap then hp = cap + (hp - cap) * 0.25 end
	-- wear on piston and rings
	local wear = 0
	for _, s in ipairs({ "kolv", "kolvringar", "cylinder" }) do
		local it = item(items, engine, s)
		if it and it.wear then wear = math.max(wear, it.wear) end
	end
	hp = hp * (1 - 0.45 * wear)
	rpm = rpm + st(items, chassis, "avgas", "rpm", 0) + st(items, engine, "vevaxel", "rpm", 0)
	c.hp = hp
	c.peak = rpm
	c.cc = cc
	c.lvl = lvl
	c.wear = wear
	-- rev limit: the CDI, and bearings/pin decide how far over peak it can rev
	local mech = rpm + 1800 + st(items, engine, "vevlager", "rpm", 0) + st(items, engine, "nallager", "rpm", 0) + st(items, engine, "kolvbult", "rpm", 0)
	c.limit = math.min(st(items, engine, "cdi", "limit", 7000), mech)
	c.idle = 1800
	-- torque at peak (Nm): P[kW] = T * rpm / 9549, hp = kW * 1.341
	c.tq = hp / 1.341 * 9549 / rpm
	c.width = 0.42 + 0.06 * (3 - lvl) -- racing engines have a narrow powerband
	-- CVT
	c.high = st(items, engine, "variator", "high", 1.25)
	local gram = st(items, engine, "vikter", "gram", 6.0)
	c.shift = math.min(c.limit - 200, rpm - 900 + (6.0 - gram) * 650) -- rpm the variator holds
	c.engage = st(items, engine, "koppling", "engage", 3400)
	c.acc = st(items, engine, "variator", "acc", 1) * st(items, engine, "koppling", "acc", 1) * st(items, engine, "klocka", "acc", 1) * st(items, engine, "remskiva", "acc", 1) * st(items, engine, "svanghjul", "acc", 1)
	c.eff = 0.86 * st(items, engine, "rem", "eff", 1)
	-- heat: bigger tune runs hotter, a lean jet much hotter; cold plug, fan and head help
	local heat = st(items, engine, "cylinder", "heat", 1.0) * st(items, engine, "topplock", "heat", 1.0)
	heat = heat * (1 + 0.09 * jet) / st(items, engine, "flakt", "cool", 1.0)
	local range = st(items, engine, "tandstift", "range", 7)
	heat = heat * (1 - 0.02 * (range - 7))
	c.heat = heat
	-- chassis
	c.grip = (st(items, chassis, "framhjul", "grip", 1) + st(items, chassis, "bakhjul", "grip", 1)) / 2
	c.brake = (st(items, chassis, "frambroms", "brake", 1) * 0.65 + st(items, chassis, "bakbroms", "brake", 1) * 0.35)
	c.handling = st(items, chassis, "gaffel", "handling", 1) * st(items, chassis, "dampare", "handling", 1) * st(items, chassis, "styre", "handling", 1)
	c.loud = st(items, chassis, "avgas", "loud", 1)
	return c
end

-- engine torque (Nm) at rpm, full throttle
function Performance.torque(c, rpm)
	if rpm < 900 then return 0 end
	if rpm > c.limit then return 0 end
	local x = (rpm - c.peak) / (c.peak * c.width)
	local t = c.tq * math.max(0.12, 1 - 0.55 * x * x)
	if rpm > c.peak then t = c.tq * math.max(0.05, 1 - 0.9 * x * x) end
	return t
end
function Performance.powerHp(c, rpm) return Performance.torque(c, rpm) * rpm / 9549 * 1.341 end

-- CVT: engine rpm and total ratio for a road speed (m/s); also whether the clutch slips
function Performance.drive(c, v)
	local wheelRpm = math.abs(v) / (2 * math.pi * Performance.WHEEL_R) * 60
	local low, high = Performance.CVT_LOW * Performance.GEARBOX, c.high * Performance.GEARBOX
	local rpmLow = wheelRpm * low
	if rpmLow < c.engage then
		return math.max(c.engage, rpmLow), low, true
	end
	if rpmLow < c.shift then return rpmLow, low, false end
	local rpmHigh = wheelRpm * high
	if rpmHigh < c.shift then return c.shift, c.shift / math.max(wheelRpm, 1e-3), false end
	return rpmHigh, high, false
end

-- forward force (N) at speed v with throttle 0..1
function Performance.force(c, v, thr)
	local rpm, ratio, slip = Performance.drive(c, v)
	local t = Performance.torque(c, rpm) * thr
	if slip then t = t * 0.92 end
	return t * ratio * c.eff * c.acc / Performance.WHEEL_R, rpm
end
function Performance.resist(v)
	local drag = 0.5 * 1.2 * Performance.CDA * v * v
	local roll = Performance.MASS * 9.81 * Performance.CRR
	return drag + (v > 0.05 and roll or 0)
end

-- simulate full throttle from standstill: top speed (km/h) and 0-45 / 0-60 times
function Performance.simulate(c)
	local v, t, dt = 0, 0, 0.02
	local t45, t60
	local last = 0
	for i = 1, 4000 do
		local f = Performance.force(c, v, 1)
		local a = (f - Performance.resist(v)) / Performance.MASS
		v = math.max(0, v + a * dt)
		t = t + dt
		if not t45 and v * KMH >= 45 then t45 = t end
		if not t60 and v * KMH >= 60 then t60 = t end
		if i % 100 == 0 then
			if math.abs(v - last) < 0.005 then break end
			last = v
		end
	end
	return v * KMH, t45, t60
end

-- equilibrium temperature at full throttle on a straight (°C), from heat and power
function Performance.temp(c, kmh)
	local cool = 0.35 + 0.65 * math.min(1, (kmh or 40) / 60)
	return 70 + c.hp * 4.0 * c.heat / cool
end
Performance.TEMP_WARN = 150
Performance.TEMP_SEIZE = 175

-- everything the UI shows
function Performance.summary(items, engine, chassis, jet)
	local c = Performance.config(items, engine, chassis, jet)
	local top, t45, t60 = Performance.simulate(c)
	local peakHp, peakRpm = 0, 0
	for r = 2000, math.floor(c.limit), 100 do
		local h = Performance.powerHp(c, r)
		if h > peakHp then peakHp, peakRpm = h, r end
	end
	local temp = Performance.temp(c, top)
	local status = "OK"
	if c.wear > 0.6 then status = "Sliten" elseif temp > Performance.TEMP_WARN then status = "Går varm" end
	return { hp = peakHp, rpm = peakRpm, limit = c.limit, top = top, t45 = t45, t60 = t60, temp = temp, status = status, cc = c.cc, cfg = c }
end

return Performance

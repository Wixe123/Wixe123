-- Riding physics without Roblox services (testable): engine, CVT/gears, temperature, wheelie and crash.
-- Ported from the web version's step(). Events (engine/crash/wheelie/dmg/dirty/say) go out via sim.emit.
local Config = require(script.Parent.Config)
local Engine = require(script.Parent.Engine)
local Economy = require(script.Parent.Economy)
local W = Config.WHEELIE
local RideSim = {}

function RideSim.new(emit)
	local R = { v = 0, rpm = 0, thr = 0, gear = 1, ratio = 2.9, h = 0, lean = 0, pitch = 0, pw = 0, on = false, crash = nil, wh = nil,
		t0 = nil, t60 = nil, clk = 0, pullT = 0, pull0 = false, acc = 0, thermal = {}, emit = emit or function() end, lastDmg = 0, lastDirty = -99 }
	for _, m in ipairs(Config.MOPEDS) do R.thermal[m.id] = Engine.newThermal() end
	return R
end

-- load the engine for the current moped from a profile
function RideSim.setProfile(R, p)
	R.mop = Config.BY_ID[p.cur]
	R.E = Economy.ecfg(p, p.cur)
	R.P = Economy.engine(p, p.cur)
	-- the client calculates damage; only a repair on the server (p.rep counter) may lower it
	local th = R.thermal[p.cur]
	if R.rep ~= (p.rep or 0) then R.rep = p.rep or 0; th.dmg = p.dmg[p.cur] or 0; R.lastDmg = th.dmg
	else th.dmg = math.max(th.dmg, p.dmg[p.cur] or 0) end
end

function RideSim.kick(R, tries, rand)
	rand = rand or math.random
	local P = R.P
	if R.on or R.v > 3 or R.crash or not P then return false end
	if R.thermal[R.mop.id].dmg >= 1 then R.emit("say", "Motorn har skurit. Reparera den i garaget."); return false end
	local p = math.max(0.08, 0.18 + 0.62 * P.fuelF - (P.m > 1.3 and 0.15 or 0))
	for _ = 1, tries or 1 do
		if rand() < p then R.on = true; R.rpm = 2600; R.emit("engine", true); R.emit("say", "Motorn startade!"); return true end
	end
	R.emit("say", "Kick... den startade inte" .. (P.m < 0.9 and " (för mager?)" or P.m > 1.15 and " (för fet?)" or ""))
	return false
end
function RideSim.stop(R) if R.on then R.on = false; R.emit("engine", false); R.emit("say", "Motorn stängdes av") end end

local function crash(R, why)
	if R.crash then return end
	R.crash = { t = 0, why = why, side = R.lean < 0 and -1 or 1 }
	R.on, R.wh = false, nil
	R.emit("engine", false)
	R.emit("crash", why)
	R.emit("say", "VURPA: " .. why)
end

-- estimate for the HUD during the wheelie (assumes a soft landing; the server calculates the real reward)
function RideSim.whValue(w)
	if w.t < W.minT or w.n == 0 then return 0, 0 end
	return Economy.wheelieValue(w.t, w.vs / w.t, math.sqrt(math.max(0, w.s2 / w.n - (w.s1 / w.n) ^ 2)), 0)
end

local function land(R, imp)
	local w = R.wh
	R.wh = nil
	if imp > 4.5 then crash(R, "för hård landning"); return end
	if w.t < W.minT then R.emit("say", string.format("Kort lyft (%.1f s), räknas inte", w.t)); return end
	R.emit("wheelie", w.t, w.vs / w.t, math.sqrt(math.max(0, w.s2 / w.n - (w.s1 / w.n) ^ 2)), imp)
end

-- moment balance about the rear axle
local function wheelie(R, dt, a, thr, brk, back)
	local mop = R.mop
	local h = W.h[mop.id]
	back = back and R.on and brk == 0
	local b = mop.wb * W.fr - (back and W.back or 0)
	local mass = mop.m + 75
	local I = mass * (h * h + b * b)
	if back and not R.pull0 then R.pull0 = true; R.pullT = thr > 0.5 and W.pullT or 0 end
	if not back then R.pull0 = false end
	local Mr = R.pullT > 0 and W.pull or 0
	R.pullT = math.max(0, R.pullT - dt)
	local n = 4
	local d = dt / n
	for _ = 1, n do
		local th = R.pitch
		local M = mass * a * (h * math.cos(th) + b * math.sin(th)) - mass * 9.81 * (b * math.cos(th) - h * math.sin(th)) + Mr - W.damp * I * R.pw
		if th <= 0 and M <= 0 then R.pitch, R.pw = 0, 0
		else
			R.pw = R.pw + M / I * d
			R.pitch = R.pitch + R.pw * d
			if R.pitch <= 0 then local imp = -R.pw; R.pitch, R.pw = 0, 0; if R.wh then land(R, imp) end end
		end
	end
	if R.pitch > math.atan2(b, h) + W.over then crash(R, "tippade bakåt i en stegring"); return end
	if R.pitch > 0.035 and not R.crash then
		if not R.wh then R.wh = { t = 0, all = 0, vs = 0, s1 = 0, s2 = 0, n = 0 } end
		local w = R.wh
		w.all = w.all + dt
		if R.v >= W.minV and R.on then w.t = w.t + dt; w.vs = w.vs + R.v * dt; w.s1 = w.s1 + R.pitch; w.s2 = w.s2 + R.pitch * R.pitch; w.n = w.n + 1 end
	end
end

local function heat(R, dt, Tq, v)
	for _, m in ipairs(Config.MOPEDS) do
		local active = m.id == R.mop.id
		local on = active and R.on
		local rpm = on and R.rpm or 0
		Engine.therm(m, R.thermal[m.id], dt, on and Engine.heatIn(R.P, Tq, rpm) or 0, rpm, active and v or 0, active and R.E.cf or 1)
	end
	local s = R.thermal[R.mop.id]
	if R.on and s.dmg >= 1 then R.on = false; R.emit("engine", false); R.emit("say", "Kolvskär! Motorn skar av överhettning. Reparera den i garaget.") end
	if math.abs(s.dmg - R.lastDmg) >= 0.01 then R.lastDmg = s.dmg; R.emit("dmg", s.dmg) end
	local band = Engine.tinfo(R.mop, s).band
	if (band == "varm" or band == "ÖVERHETTAD" or band == "KOKAR") and R.clk - R.lastDirty > 5 then R.lastDirty = R.clk; R.emit("dirty") end
end

-- input: { thr = 0/1, brk = 0/1, st = -1..1, back = bool }
function RideSim.step(R, dt, seated, input)
	local P, E, mop = R.P, R.E, R.mop
	R.thr = R.thr + (input.thr - R.thr) * math.min(1, dt * (2 + 8 * P.resp))
	local thr = R.thr
	R.clk = R.clk + dt
	if not seated then
		local goal = (not R.on) and 0 or (thr > 0.02 and 1800 + thr * (P.pk * 1.05 - 1800) or 1800)
		R.rpm = R.rpm + (goal - R.rpm) * math.min(1, dt * (R.on and 3 + 9 * P.resp or 4))
		heat(R, dt, R.on and Engine.torque(P, R.rpm) * (0.15 + 0.85 * thr) * Engine.heatF(R.thermal[mop.id]) * 0.25 or 0, 0)
		R.v, R.pitch, R.pw = 0, 0, 0
		return
	end
	if R.crash then
		local c = R.crash
		c.t = c.t + dt
		R.v = math.max(0, R.v - 7 * dt)
		R.pitch = math.max(0, R.pitch - 3 * dt)
		R.rpm = math.max(0, R.rpm - 4000 * dt)
		heat(R, dt, 0, R.v)
		if c.t > 2.5 then R.crash, R.lean, R.pitch, R.pw = nil, 0, 0, 0; R.emit("say", "Mopeden är uppe igen. K = starta") end
		return
	end
	local wheelRpm = R.v / (2 * math.pi * mop.wr) * 60
	local tot, des
	local tg = Engine.target(E) * (0.55 + 0.45 * math.max(thr, 0.2))
	if mop.cvt then
		R.ratio = math.min(2.9, math.max(E.rmin, tg / math.max(wheelRpm * mop.fd, 1)))
		tot = R.ratio * mop.fd
		des = math.max(wheelRpm * tot, thr > 0.05 and math.min(tg, E.slip * (0.55 + 0.45 * thr)) or 1800)
	else
		tot = Config.GEARS[R.gear] * mop.fd
		des = math.max(wheelRpm * tot, thr > 0.05 and 2200 + thr * (P.pk - 2200) or 1800)
	end
	if not R.on then des = 0 end
	R.rpm = R.rpm + (des - R.rpm) * math.min(1, dt * (R.on and 3 + 9 * P.resp or 3))
	R.rpm = math.min(R.rpm, P.lim * 1.03)
	local Tq = Engine.torque(P, R.rpm) * (0.15 + 0.85 * thr)
	if thr < 0.02 and not mop.cvt then Tq = -0.5 end
	Tq = Tq * Engine.heatF(R.thermal[mop.id])
	if not R.on then Tq = 0 end
	local mass = mop.m + 75
	local eff = mop.cvt and 0.85 * (1 - math.min(0.15, math.max(0, (P.hp - E.blim) * 0.03))) or 0.85 -- a weak belt slips
	local F = Tq * tot * eff / mop.wr
	local drag = 0.33 * R.v * R.v + 0.015 * mass * 9.8
	R.acc = (F - (R.v > 0 and drag or 0)) / mass
	local a = R.acc - input.brk * 6.5
	if R.v <= 0 and a < 0 then a = 0 end
	R.v = math.max(0, R.v + a * dt)
	heat(R, dt, math.max(0, Tq), R.v)
	R.h = R.h - input.st * (1 - R.pitch * 0.6) * 1.6 * math.min(1, R.v / 1.5) / (1 + R.v * 0.12) * dt
	R.lean = R.lean + ((input.st * math.min(R.v, 18) * 0.025) - R.lean) * math.min(1, dt * 5)
	wheelie(R, dt, a, thr, input.brk, input.back)
	if R.v < 0.1 and thr > 0.5 and R.on and R.t0 == nil then R.t0 = R.clk end
	if R.v < 0.1 and thr < 0.1 then R.t0 = nil end
	if R.t0 and R.v >= 16.67 then R.t60 = R.clk - R.t0; R.t0 = nil end
end

return RideSim

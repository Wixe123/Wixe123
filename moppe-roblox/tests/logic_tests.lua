local Config = require(Shared.Config)
local Engine = require(Shared.Engine)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local RideSim = require(Shared.RideSim)
local function r1(x) return math.floor(x * 10 + 0.5) / 10 end

-- 1. engine: same peak power as the web version
local p = Economy.new()
for _, t in ipairs({ { "jog", 3.4 }, { "rok", 3.9 }, { "dt", 3.9 } }) do
	local hp = r1(Economy.engine(p, t[1]).hp)
	ok("motor standard " .. t[1] .. " = " .. t[2] .. " hk (webben)", hp == t[2], hp)
end
local function race(pp, id)
	local function put(slot, sku) local _, _, us = Economy.buy(pp, sku, 1, nil, 0); pp.inst[id][slot] = us[1] end
	pp.money = 1e6
	put("kit", "D-kit-2-" .. id); put("exh", "D-exh-4-" .. id); put("carb", "D-carb-3"); put("man", "D-man-1-" .. id); put("ign", "D-ign-1-" .. id)
	if Config.BY_ID[id].cvt then put("clutch", "D-clutch-2-" .. id); put("belt", "D-belt-1-" .. id); put("roll", "D-roll-0-" .. id); pp.cfgs[id].roller = 5 end
	pp.cfgs[id].jet = 105
end
local pr = Economy.new(); race(pr, "jog")
ok("motor race-Jogga = 9.9 hk (webben)", r1(Economy.engine(pr, "jog").hp) == 9.9, r1(Economy.engine(pr, "jog").hp))

-- 2. riding: acceleration and top speed compared with the web version (60 fps, fixed steps)
local function accel(pp, id, secs)
	pp.cur = id
	local R = RideSim.new()
	RideSim.setProfile(R, pp)
	R.on, R.rpm = true, 1800
	for _, m in ipairs(Config.MOPEDS) do R.thermal[m.id].tc = 150; R.thermal[m.id].tw = 80 end
	local t, mk = 0, {}
	for _ = 1, (secs or 20) * 60 do
		RideSim.step(R, 1 / 60, true, { thr = 1, brk = 0, st = 0, back = false })
		t = t + 1 / 60
		if not R.mop.cvt and R.rpm > R.P.pk * 1.12 and R.gear < 4 then R.gear = R.gear + 1 end
		for _, v in ipairs({ 20, 30, 40 }) do if R.v * 3.6 >= v and not mk[v] then mk[v] = r1(t) end end
	end
	return mk, math.floor(R.v * 3.6 + 0.5), R
end
local web = { jog = { 2.4, 4.0, 6.7, 58 }, rok = { 2.5, 4.1, 6.6, 60 }, dt = { 1.9, 3.5, 6.0, 55 } }
for _, id in ipairs({ "jog", "rok", "dt" }) do
	local mk, top = accel(Economy.new(), id)
	local w = web[id]
	local close = math.abs(mk[20] - w[1]) <= 0.15 and math.abs(mk[30] - w[2]) <= 0.15 and math.abs(mk[40] - w[3]) <= 0.2 and math.abs(top - w[4]) <= 2
	ok("acceleration standard " .. id .. " (0-20/30/40, topp) som webben " .. table.concat(w, "/"), close, mk[20] .. "/" .. mk[30] .. "/" .. mk[40] .. "/" .. top)
end
local mkr, topr = accel(pr, "jog")
ok("acceleration race-Jogga som webben 1.6/2.2/3.0/86", math.abs(mkr[20] - 1.6) <= 0.15 and math.abs(mkr[30] - 2.2) <= 0.15 and math.abs(mkr[40] - 3.0) <= 0.2 and math.abs(topr - 86) <= 2, mkr[20] .. "/" .. mkr[30] .. "/" .. mkr[40] .. "/" .. topr)

-- 3. temperature: cold start, warm-up, full throttle, cooling down
local pt = Economy.new()
local R = RideSim.new(); RideSim.setProfile(R, pt)
ok("kallstart vid utetemp", R.thermal.jog.tc == Config.AMB, R.thermal.jog.tc)
R.on, R.rpm = true, 1800
for _ = 1, 600 * 60 do RideSim.step(R, 1 / 60, true, { thr = 1, brk = 0, st = 0, back = false }) end
local tFull = R.thermal.jog.tc
ok("Jogga fullgas 10 min ≈ 176°C (webben)", math.abs(tFull - 176) <= 4, r1(tFull))
R.on = false
for _ = 1, 600 * 60 do RideSim.step(R, 1 / 60, false, { thr = 0, brk = 0, st = 0, back = false }) end
ok("avstängd 10 min svalnar", R.thermal.jog.tc < tFull - 60, r1(R.thermal.jog.tc))

-- 4. wheelie: no lift on throttle alone, a controlled wheelie gets reported
local _, _, Rs = accel(Economy.new(), "jog", 8)
local maxPitch = 0
do local pp = Economy.new(); pp.cur = "jog"; local R2 = RideSim.new(); RideSim.setProfile(R2, pp); R2.on = true
	for _ = 1, 480 do RideSim.step(R2, 1 / 60, true, { thr = 1, brk = 0, st = 0, back = false }); maxPitch = math.max(maxPitch, R2.pitch) end end
ok("standard Jogga lyfter inte på bara gas", maxPitch == 0, maxPitch)
local events = {}
local pd = Economy.new(); race(pd, "dt"); pd.cur = "dt"
local R3 = RideSim.new(function(k, a, b, c, d) table.insert(events, { k, a, b, c, d }) end)
RideSim.setProfile(R3, pd); R3.on = true
for i = 1, 9 * 60 do
	local t = i / 60
	local e = R3.pitch + 0.25 * R3.pw
	local inp = { thr = (t < 0.3 or e < 0.4) and 1 or 0, brk = e > 0.52 and 1 or 0, st = 0, back = t > 0.3 and t < 6 }
	if t > 6 then inp.thr, inp.brk = 0, 1 end
	RideSim.step(R3, 1 / 60, true, inp)
	if not R3.mop.cvt and R3.rpm > R3.P.pk * 1.12 and R3.gear < 4 then R3.gear = R3.gear + 1 end
end
local wev
for _, e in ipairs(events) do if e[1] == "wheelie" then wev = e end end
ok("kontrollerad stegring (race-DT) rapporteras", wev ~= nil and wev[2] > 3, wev and r1(wev[2]) .. " s")

-- 5. economy
local pe = Economy.new()
ok("startsaldo 2000", pe.money == 2000, pe.money)
local okb, err = Economy.buy(pe, "D-exh-4-jog", 1, nil, 0)
ok("köp över saldot nekas", okb == false and pe.money == 2000, err)
local okb2, _, us, inst = Economy.buy(pe, "D-exh-2-jog", 1, "jog", 0)
ok("köp + direktmontering drar rätt belopp", okb2 and inst and pe.money == 100, pe.money)
ok("monterad del uppdaterar motorn (avgas index 2)", Economy.ecfg(pe, "jog").exh == 2)
local oemExh
for u, it in pairs(pe.items) do if it.s == "D-exh-0-jog" and not Economy.installedOn(pe, u) then oemExh = u end end
ok("utbytt originalavgas ligger i förrådet", oemExh ~= nil)
ok("bara utbytbara delar kan tas bort", (Economy.uninstall(pe, "jog", "kit")) == false and (Economy.uninstall(pe, "jog", "mir")) == true)
local m0 = pe.money
Economy.sell(pe, oemExh, 0)
ok("sälja begagnad del ger 50 %", pe.money - m0 == 450, pe.money - m0)
local inc = Economy.buy(pe, "D-kit-2-rok", 1, nil, 0)
local wrong
for u, it in pairs(pe.items) do if it.s == "D-kit-2-rok" then wrong = u end end
ok("inkompatibel del kan inte monteras", wrong == nil or (Economy.install(pe, wrong, "jog")) == false)
local pd2 = Economy.new()
Economy.addDistance(pd2, 250, 0)
ok("250 m ger 2 hela block = 10 kr", pd2.money == 2010, pd2.money)
for _ = 1, 1000 do Economy.addDistance(pd2, 0, 0) end
ok("upprepade nollsteg betalar inget", pd2.money == 2010, pd2.money)
Economy.addDistance(pd2, 1800, 0)
ok("2 km ren körning ger +40", pd2.money == 2010 + 90 + 40, pd2.money)
pd2.money = 30
Economy.crash(pd2, "test", 0)
ok("vurpa drar inte under 0", pd2.money == 0, pd2.money)
local pw = Economy.new()
local tot = 0
for i = 1, 6 do tot = tot + Economy.wheelie(pw, 10, 12, 0.02, 0.5, 100 + i, 200) end
ok("stegringstaket 400 kr/min håller", tot <= 400, tot)
ok("stegring utan att servern sett rörelse nekas", Economy.wheelie(Economy.new(), 10, 12, 0.02, 0.5, 0, 0) == 0)
local ptn = Economy.new()
Economy.tune(ptn, "jog", "jet", 200)
ok("munstycke klampas till satsens intervall (50–110)", ptn.cfgs.jog.jet == 110, ptn.cfgs.jog.jet)
local prp = Economy.new(); prp.dmg.jog = 0.4
Economy.repair(prp, "jog", false, 0)
ok("reparation kostar 100+900×skada", prp.money == 2000 - 460 and prp.dmg.jog == 0, prp.money)
local ps = Economy.new()
Economy.sellMoped(ps, "dt", 0)
local left = 0
for _, it in pairs(ps.items) do if it.src == "oem" and not Economy.installedOn(ps, _) then left = left + 1 end end
ok("sålja moped: 60 %, originaldelar följer med", ps.money == 2000 + 4800 and not ps.own.dt and left == 0, ps.money)
ok("köpa tillbaka moped", (Economy.buyMoped(ps, "dt", 0)) == false and ps.money == 6800) -- costs 8000, not enough
-- 6. saving: load(public(p)) gives the same profile, garbage gives a valid profile
local function ser(t, d)
	d = d or 0
	if type(t) ~= "table" then return tostring(t) end
	local ks = {}
	for k in pairs(t) do table.insert(ks, tostring(k)) end
	table.sort(ks)
	local o = {}
	for _, k in ipairs(ks) do local v = t[k]; if v == nil then v = t[tonumber(k)] end; table.insert(o, k .. "=" .. ser(v, d + 1)) end
	return "{" .. table.concat(o, ",") .. "}"
end
local before = ser(Economy.public(pe))
local after = ser(Economy.public(Economy.load(Economy.public(pe))))
ok("spara -> ladda ger samma profil", before == after, #before .. " tecken")
local g = Economy.load({ money = "mycket", items = { x = { s = "finns-inte" } }, inst = { jog = { kit = "x" } }, own = "ja", cfgs = { jog = { jet = 1e9, col = "röd" } } })
ok("trasig sparning ger giltig profil", g.money == 2000 and g.cfgs.jog.jet == 160 and Economy.ecfg(g, "jog").kit == 0, g.money)

print(string.format("\n%d godkända, %d underkända", PASS, FAIL))

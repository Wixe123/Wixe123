local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Assembly = require(Shared.Assembly)
local Economy = require(Shared.Economy)
local RideSim = require(Shared.RideSim)
local Porting = require(Shared.Porting)
local Paint = require(Shared.Paint)
local Delivery = require(Shared.Delivery)
local function r1(x) return math.floor(x * 10 + 0.5) / 10 end

-- 1. an original moped is complete and has the same engine as before
local p = Economy.new()
ok("ny profil: Jogga komplett och körbar", Economy.canRide(p, "jog"), table.concat(Economy.mopedMissing(p, "jog"), ","))
ok("Jogga original = 3.4 hk (som tidigare)", r1(Economy.engine(p, "jog").hp) == 3.4, r1(Economy.engine(p, "jog").hp))
p.money = 1e6
Economy.buyMoped(p, "rok", 0); Economy.buyMoped(p, "dt", 0)
ok("Aerox och DT original = 3.9 hk", r1(Economy.engine(p, "rok").hp) == 3.9 and r1(Economy.engine(p, "dt").hp) == 3.9, r1(Economy.engine(p, "rok").hp) .. "/" .. r1(Economy.engine(p, "dt").hp))
local function accel(pp, id)
	pp.cur = id
	local R = RideSim.new(); RideSim.setProfile(R, pp); R.on = true
	for _, m in ipairs(Config.MOPEDS) do R.thermal[m.id].tc = 150; R.thermal[m.id].tw = 80 end
	local t, mk = 0, {}
	for _ = 1, 20 * 60 do RideSim.step(R, 1 / 60, true, { thr = 1, brk = 0, st = 0, back = false }); t = t + 1 / 60
		if not R.mop.cvt and R.rpm > R.P.pk * 1.12 and R.gear < 4 then R.gear = R.gear + 1 end
		for _, v in ipairs({ 20, 30 }) do if R.v * 3.6 >= v and not mk[v] then mk[v] = r1(t) end end end
	return mk[30], math.floor(R.v * 3.6 + 0.5)
end
local t30, top = accel(p, "jog")
ok("Jogga 0–30 4.0 s, topp 58 km/h (som tidigare)", math.abs(t30 - 4.0) <= 0.15 and math.abs(top - 58) <= 2, t30 .. " s / " .. top)

-- 2. the engine out of the moped: exhaust and rear wheel must come off first
local q = Economy.new()
local okA, why = Economy.engineToStand(q, "jog")
ok("motorn kan inte lyftas ur med avgas och bakhjul på", not okA, why)
Economy.unmountMoped(q, "jog", "brakeR"); Economy.unmountMoped(q, "jog", "wheelR"); Economy.unmountMoped(q, "jog", "exh")
ok("motorn i stativet när avgas och bakhjul är av", (Economy.engineToStand(q, "jog")) == true and q.stand == "jog")
ok("mopeden går inte att köra utan motor", not Economy.canRide(q, "jog"))

-- 3. take the engine apart completely: wrong order is refused, right order works
local okB, whyB = Economy.unmountEngine(q, "piston")
ok("kolven kan inte tas bort före cylindern", not okB, whyB)
local list = Assembly.engineSockets("jog")
local removed, rounds = {}, 0
while next(q.mopeds.jog.eng) and rounds < 100 do
	rounds = rounds + 1
	for _, s in ipairs(list) do
		if q.mopeds.jog.eng[s.id] and (Economy.unmountEngine(q, s.id)) then table.insert(removed, s.id) end
	end
end
ok("hela motorn demonterad i rätt ordning (" .. #removed .. " delar)", next(q.mopeds.jog.eng) == nil and #removed == #list, #removed .. "/" .. #list)
local first = removed[#removed]
ok("vevhuset sist ut", first == "case", first)
-- rebuild: mount from the bench in random order until it works
local function freeOf(kind)
	for u, it in pairs(q.items) do if it.loc == "bench" and Catalog.BY_SKU[it.s].kind == kind then return u end end
end
local okC, whyC = Economy.mountEngine(q, freeOf("piston"), "piston")
ok("kolven kan inte monteras före vevhuset", not okC, whyC)
local mounted, guard = 0, 0
while #Economy.engineMissing(q, "jog") > 0 and guard < 200 do
	guard = guard + 1
	for _, s in ipairs(list) do
		local u = not q.mopeds.jog.eng[s.id] and freeOf(s.kind)
		if u and (Economy.mountEngine(q, u, s.id)) then mounted = mounted + 1 end
	end
end
ok("motorn ombyggd från grunden", #Economy.engineMissing(q, "jog") == 0, mounted .. " delar")
-- a piston that does not fit the cylinder
local q2 = Economy.new(); q2.money = 1e5
Economy.unmountMoped(q2, "jog", "brakeR"); Economy.unmountMoped(q2, "jog", "wheelR"); Economy.unmountMoped(q2, "jog", "exh"); Economy.engineToStand(q2, "jog")
for _, s in ipairs({ "cable", "plug", "head", "cyl" }) do Economy.unmountEngine(q2, s) end
local race = Economy.newItem(q2, "P-cyl-race", "bench")
local okD, whyD = Economy.mountEngine(q2, race, "cyl")
ok("70 cc-cylinder på 50 cc-kolv nekas", not okD, whyD)
ok("motorn tillbaka i mopeden", (function() local u = nil; for k, it in pairs(q2.items) do if it.s == "P-cyl-std" and it.loc == "bench" then u = k end end
	Economy.mountEngine(q2, u, "cyl"); Economy.mountEngine(q2, freeOf and (function() for k, it in pairs(q2.items) do if it.s == "P-head-std" and it.loc == "bench" then return k end end end)(), "head")
	for k, it in pairs(q2.items) do if it.s == "P-plug-std" and it.loc == "bench" then Economy.mountEngine(q2, k, "plug") end end
	for k, it in pairs(q2.items) do if it.s == "P-cable-std" and it.loc == "bench" then Economy.mountEngine(q2, k, "cable") end end
	return (Economy.engineToMoped(q2)) == true end)())

-- 4. orders, delivery times and boxes
ok("leveranstid liten (1 del) = 60 s", Delivery.seconds({ { sku = "P-plug-std", q = 1 } }) == 60 + (Catalog.BY_SKU["P-plug-std"].stock == "Beställningsvara" and 120 or 0))
local med = Delivery.seconds({ { sku = "P-plug-std", q = 4 } }) - (Catalog.BY_SKU["P-plug-std"].stock == "Beställningsvara" and 120 or 0)
ok("leveranstid mellan (4 delar) 3–5 min", med >= 180 and med <= 300, med)
ok("leveranstid stor (8 delar) = 10 min", Delivery.seconds({ { sku = "P-gasket-std", q = 8 } }) - (Catalog.BY_SKU["P-gasket-std"].stock == "Beställningsvara" and 120 or 0) == 600)
local o = Economy.new()
local m0 = o.money
local okE, whyE, ord = Economy.order(o, { { sku = "P-carb-21", q = 1 }, { sku = "P-intake-big", q = 1 } }, 1000)
ok("beställning drar rätt belopp", okE and o.money == m0 - 1300 - 450, o.money)
ok("ingenting kommer före leveranstiden", #Economy.tick(o, 1000 + 30) == 0)
local arrived = Economy.tick(o, ord.eta)
local inBox = 0
for _, it in pairs(o.items) do if it.loc == "box:" .. ord.id then inBox = inBox + 1 end end
ok("leverans: låda med 2 delar", #arrived == 1 and inBox == 2, inBox)
ok("tick igen ger ingen ny leverans", #Economy.tick(o, ord.eta + 999) == 0)
Economy.openBox(o, ord.id)
local onFloor = 0
for _, it in pairs(o.items) do if it.loc == "floor" then onFloor = onFloor + 1 end end
ok("öppnad låda: delarna på golvet", onFloor == 2, onFloor)
local okF = Economy.order(o, { { sku = "P-cyl-race", q = 10 } }, 0)
ok("beställning över saldot nekas", not okF)

-- 5. porting: even work in the zones = good, scribbling outside = bad
local function sweep(steady, outside, over)
	local s = Porting.new(steady)
	for _, z in ipairs(Porting.ZONES) do
		for pass = 1, over and 6 or 2 do
			for i = 1, Porting.CU * Porting.CV do local cu, cv = Porting.cellCenter(z, i); for _ = 1, 30 do Porting.grind(s, cu, cv, 1 / 60, true) end end
		end
	end
	if outside then for _ = 1, 600 do Porting.grind(s, 0, 0, 1 / 60, true) end end
	return Porting.result(s)
end
local good, bad, much = sweep(1, false), sweep(0.6, true), sweep(1, false, true)
ok("jämn portning ger hög kvalitet", good.q > 0.75 and good.coverage > 0.95, r1(good.q))
ok("slipning utanför zonerna sänker precisionen", bad.precision < good.precision and bad.q < good.q, r1(bad.precision))
ok("för mycket slipning ger överportning", much.over > 0.5 and much.deg < good.deg, r1(much.over))
local pp = Economy.new()
local cylU = pp.mopeds.jog.eng.cyl
local hp0 = Economy.engine(pp, "jog").hp
pp.items[cylU].loc = "portbench" -- (the test puts it there directly)
local okG = Economy.applyPort(pp, cylU, good)
pp.items[cylU].loc = "eng:jog"
local hp1 = Economy.engine(pp, "jog").hp
ok("portad cylinder ger mer effekt", okG and hp1 > hp0, r1(hp0) .. " -> " .. r1(hp1))
pp.items[cylU].loc = "portbench"
ok("cylindern kan inte portas två gånger", (Economy.applyPort(pp, cylU, good)) == false)

-- 6. paint: even spraying = good, one spot = runs
local ps = Paint.new(1)
for y = -1, 1, 0.1 do for x = -1, 1, 0.05 do Paint.spray(ps, x, y, 1 / 60) end end
for y = -1, 1, 0.1 do for x = -1, 1, 0.05 do Paint.spray(ps, x, y, 1 / 60) end end
local pg = Paint.result(ps)
local pb = Paint.new(0.7)
for _ = 1, 400 do Paint.spray(pb, 0, 0, 1 / 60) end
local pbad = Paint.result(pb)
ok("jämn lackering ger hög kvalitet", pg.q > 0.7 and pg.coverage > 0.9, r1(pg.q))
ok("allt på ett ställe ger rinningar och dålig täckning", pbad.runs > 0 and pbad.q < 0.3, r1(pbad.q))
local pl = Economy.new()
local side = pl.mopeds.jog.ch["pan:side_l"]
Economy.unmountMoped(pl, "jog", "pan:side_l")
ok("demonterad kåpa ligger på bänken", pl.items[side].loc == "bench")
Economy.move(pl, side, "booth")
local mp0 = pl.money
local okH = Economy.applyPaint(pl, side, "#16234a", "metal", pg.q, 100)
ok("lackering i lackboxen kostar och sparas", okH and pl.money == mp0 - 70 and pl.items[side].paint.col == "#16234a", pl.money)
Economy.move(pl, side, "bench")
ok("våt lack kan inte monteras", (Economy.mountMoped(pl, side, "jog", "pan:side_l")) == false)
Economy.dryTick(pl, 100 + Config.PAINT_DRY)
ok("torr kåpa monteras tillbaka", (Economy.mountMoped(pl, side, "jog", "pan:side_l")) == true)
ok("varje kåpa har egen färg", pl.items[pl.mopeds.jog.ch["pan:side_r"]].paint.col ~= pl.items[side].paint.col)
Economy.saveDesign(pl, "jog", "Midnight")
pl.items[side].paint.col = "#ff0000"
Economy.applyDesign(pl, "Midnight")
ok("sparad design kan läggas på igen", pl.items[side].paint.col == "#16234a")
local pr = Economy.new(); pr.money = 1e5; Economy.buyMoped(pr, "rok", 0)
local okI, whyI = Economy.unmountMoped(pr, "rok", "pan:side_l")
ok("sidokåpan kan inte tas bort före bakre sidokåpan", not okI, whyI)

-- 7. economy and saving
local pe = Economy.new()
Economy.addDistance(pe, 250, 0)
ok("körning: 2 hela 100 m-block = 10 kr", pe.money == 4010, pe.money)
for _ = 1, 500 do Economy.addDistance(pe, 0, 0) end
ok("upprepade nollsteg betalar inget", pe.money == 4010)
local tot = 0
for i = 1, 6 do tot = tot + Economy.wheelie(pe, 10, 12, 0.02, 0.5, 100 + i, 200) end
ok("stegringstaket 400 kr/min håller", tot <= 400, tot)
pe.money = 20; Economy.crash(pe, "test", 0)
ok("vurpa drar inte under 0", pe.money == 0)
local function ser(t)
	if type(t) == "number" then return string.format("%.10g", t) end
	if type(t) ~= "table" then return tostring(t) end
	local ks = {}
	for k in pairs(t) do table.insert(ks, tostring(k)) end
	table.sort(ks)
	local out = {}
	for _, k in ipairs(ks) do local v = t[k]; if v == nil then v = t[tonumber(k)] end; table.insert(out, k .. "=" .. ser(v)) end
	return "{" .. table.concat(out, ",") .. "}"
end
for _, prof in ipairs({ q, pl, o, pr }) do
	local a, b = ser(Economy.public(prof)), ser(Economy.public(Economy.load(Economy.public(prof))))
	ok("spara -> ladda ger samma profil (" .. #a .. " tecken)", a == b)
end
local g = Economy.load({ v = 2, money = "x", items = { a = { s = "finns-inte", loc = "bench" } }, mopeds = { jog = { own = true, eng = { case = "a" } } } })
ok("trasig sparning ger giltig profil", g.money == Config.ECON.start and g.mopeds.jog ~= nil and g.items.a == nil)
local old = Economy.load({ money = 999, cfgs = {} })
ok("gammal sparning (v1) ger ny startprofil", old.money == Config.ECON.start and Economy.canRide(old, "jog"))

print(string.format("\n%d godkända, %d underkända", PASS, FAIL))

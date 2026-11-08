-- Game rules without Roblox objects: profile, engine building, shop, porting, paint, jobs, saving, performance.
local G = E.makeGlobals(E.serverCtx)
local Shared = E.services.ReplicatedStorage.Shared
local function req(n) return G.require(Shared[n]) end
local Parts, EngineDef, MopedDef, Profile, Perf, Porting, Paint = req("Parts"), req("EngineDef"), req("MopedDef"), req("Profile"), req("Performance"), req("Porting"), req("Paint")
local check = E.check

-- new profile
local p = Profile.new()
check("start money 4000", p.money == 4000, p.money)
check("starter moped can be ridden", Profile.canRide(p), table.concat(Profile.mopedProblems(p), ","))
check("29 engine sockets", #EngineDef.SOCKETS == 29, #EngineDef.SOCKETS)
local s = Profile.perf(p)
HOST_ECHO(string.format("  OEM: %.1f hp @ %d rpm, limit %d, top %.1f km/h, 0-45 %s s, temp %.0f", s.hp, s.rpm, s.limit, s.top, tostring(s.t45 and math.floor(s.t45 * 10) / 10), s.temp))
check("OEM top speed is about 45 km/h", s.top > 40 and s.top < 50, s.top)
check("OEM about 3-4 hp", s.hp > 2.8 and s.hp < 4.2, s.hp)

-- take the engine out and strip it completely
local m = p.mopeds[1]
-- the engine lifts out directly: rear wheel, brake and exhaust stay on the moped
local ok, e = Profile.engineToStand(p); check("engine lifts out without removing wheel, brake or exhaust", ok, e)
check("rear wheel still on", m.slots.bakhjul ~= nil and m.slots.bakbroms ~= nil and m.slots.avgas ~= nil)
check("moped no longer rideable", not Profile.canRide(p))
-- taking the cylinder off brings the head, plug and HT lead with it
local okc, cid, extra = Profile.unmountEngine(p, "stand", "cylinder")
check("cylinder comes off in one go", okc and #extra == 3, extra and table.concat(extra, ","))
HOST_ECHO("  also came off: " .. table.concat(extra or {}, ", "))
local removed = 0
for i = #EngineDef.SOCKETS, 1, -1 do
	local sock = EngineDef.SOCKETS[i].id
	local ok2 = Profile.unmountEngine(p, "stand", sock)
	if ok2 then removed = removed + 1 end
end
-- some sockets later in the list depend on earlier ones (rem needs koppling) - repeat until empty
for _ = 1, 5 do for i = #EngineDef.SOCKETS, 1, -1 do if Profile.unmountEngine(p, "stand", EngineDef.SOCKETS[i].id) then removed = removed + 1 end end end
check("engine fully stripped", EngineDef.isEmpty(p.stand), removed)

-- build it again in order, using whatever free parts match
local function freePart(kind, bore)
	for id, it in pairs(p.items) do
		local part = Parts.get(it.sku)
		if Profile.isFree(p, it) and part.kind == kind and (not bore or part.stats.bore == bore) then return id end
	end
end
ok, e = Profile.mountEngine(p, "stand", "cylinder", freePart("cylinder")); check("cylinder refused on empty case", not ok, e)
HOST_ECHO("  refused: " .. tostring(e))
local mounted = 0
for _, sdef in ipairs(EngineDef.SOCKETS) do
	local id = freePart(sdef.kind, (sdef.kind == "kolv" or sdef.kind == "kolvringar") and 40 or nil)
	local ok3, e3 = Profile.mountEngine(p, "stand", sdef.id, id)
	if ok3 then mounted = mounted + 1 else HOST_ECHO("  mount " .. sdef.id .. " failed: " .. tostring(e3)) end
end
check("engine rebuilt (29 parts)", mounted == 29 and EngineDef.complete(p.stand), mounted)
ok, e = Profile.engineToMoped(p); check("engine back into moped", ok, e)
check("moped rideable again", Profile.canRide(p), table.concat(Profile.mopedProblems(p), ","))

-- wrong piston for the cylinder
local q = Profile.new()
q.stand = {}
for _, sock in ipairs({ "vevhus", "vevlager", "vevaxel", "packbox", "nallager" }) do
	Profile.mountEngine(q, "stand", sock, Profile.addItem(q, Profile.OEM_ENGINE[sock], "bank"))
end
Profile.mountEngine(q, "stand", "kolv", Profile.addItem(q, "kolv_47", "bank"))
ok, e = Profile.mountEngine(q, "stand", "kolvringar", Profile.addItem(q, "kolvringar_40", "bank"))
check("40 mm rings refused on 47 mm piston", not ok, e)
HOST_ECHO("  refused: " .. tostring(e))

-- shop and delivery
local r = Profile.new()
ok, e = Profile.order(r, { { sku = "cylinder_nordtrim70", qty = 1 } }, 1000)
check("order 1 part", ok, e)
check("1 part takes 60 s", e.ready - e.placed == 60, e.ready - e.placed)
check("freight 99 kr under 2000", e.freight == 99 and r.money == 4000 - 1990 - 99, r.money)
check("nothing arrives early", #Profile.tick(r, 1059) == 0)
check("arrives after 60 s", #Profile.tick(r, 1060) == 1)
local box = Profile.boxItems(r, e.id)
check("box holds the part", #box == 1)
check("box must be opened before taking", not Profile.moveItem(r, box[1], "hand"))
Profile.openBox(r, e.id)
ok, e2 = Profile.moveItem(r, box[1], "hand"); check("take part from box", ok, e2)
check("empty box is thrown away", r.orders[1].state == "tom", r.orders[1].state)
local okb, o2 = Profile.order(r, { { sku = "tandstift_b7", qty = 2 }, { sku = "kolv_47", qty = 1 }, { sku = "kolvringar_47", qty = 1 } }, 2000)
check("4 parts take 3.5 min", okb and o2.ready - o2.placed == 210, okb and (o2.ready - o2.placed))
local okc, o3 = Profile.order(r, { { sku = "slang_origo", qty = 8 } }, 3000, function() return 0 end)
check("8 parts out of stock take 12 min", okc and o3.ready - o3.placed == 720, okc and (o3.ready - o3.placed))
check("cannot overspend", not Profile.order(r, { { sku = "cylinder_snabbo80", qty = 10 } }, 1))

-- porting
local st = Porting.new()
-- a careful player sweeps each window back and forth until the glow is gone
for _, z in ipairs(Porting.ZONES) do
	local pass = 0
	while Porting.zoneProgress(st, z.id) < 0.97 and pass < 200 do
		pass = pass + 1
		for row = 1, Porting.ROWS do for k = 0, 24 do
			local u = (pass + row) % 2 == 0 and k / 24 or 1 - k / 24
			Porting.grind(st, z.id, u, (row - 0.5) / Porting.ROWS, 1 / 60, 1)
		end end
	end
end
local res = Porting.result(st)
HOST_ECHO(string.format("  careful porting: cover %.2f even %.2f precision %.2f over %.2f q %.2f %s", res.cover, res.even, res.precision, res.over, res.q, res.label))
check("careful porting is good", res.q >= 0.75, res.q)
local sloppy = Porting.new()
for _ = 1, 400 do Porting.grind(sloppy, "avgas", 0.5, 0.5, 1 / 30, 1) end
for _ = 1, 200 do Porting.grind(sloppy, "avgas", 1.5, 0.5, 1 / 30, 1) end
local res2 = Porting.result(sloppy)
check("sloppy porting is bad", res2.q < 0.4, res2.q)
-- effect on the engine
local t = Profile.new()
local cylId = t.mopeds[1].engine.cylinder
local before = Profile.perf(t).hp
t.items[cylId].port = { q = 1 }
local after = Profile.perf(t).hp
t.items[cylId].port = { q = 0 }
local bad = Profile.perf(t).hp
HOST_ECHO(string.format("  porting effect: %.2f hp -> perfect %.2f, bad %.2f", before, after, bad))
check("perfect porting adds power", after > before * 1.04)
check("bad porting costs power", bad < before * 0.95)

-- tuned engine
local u = Profile.new()
local mm = u.mopeds[1]
local function swap(map, sock, sku) u.items[map[sock]].sku = sku end
swap(mm.engine, "cylinder", "cylinder_fartek70"); swap(mm.engine, "kolv", "kolv_476"); swap(mm.engine, "kolvringar", "kolvringar_476")
swap(mm.engine, "forgasare", "forgasare_gs21"); swap(mm.engine, "insug", "insug_fartek"); swap(mm.engine, "reed", "reed_snabbo")
swap(mm.engine, "luftfilter", "luftfilter_fartek"); swap(mm.engine, "cdi", "cdi_fartek"); swap(mm.engine, "variator", "variator_fartek")
swap(mm.engine, "vikter", "vikter_5g"); swap(mm.engine, "koppling", "koppling_fartek"); swap(mm.engine, "vevaxel", "vevaxel_fartek")
swap(mm.slots, "avgas", "avgas_fartek")
local s2 = Profile.perf(u)
HOST_ECHO(string.format("  Racing 70: %.1f hp @ %d rpm, limit %d, top %.1f km/h, 0-45 %.1f s, temp %.0f", s2.hp, s2.rpm, s2.limit, s2.top, s2.t45 or -1, s2.temp))
check("racing 70 is around 10-13 hp", s2.hp > 9 and s2.hp < 14, s2.hp)
check("racing 70 does 85-105 km/h", s2.top > 85 and s2.top < 105, s2.top)
check("racing 70 accelerates faster", s2.t45 < s.t45, s2.t45)
-- a big cylinder with the stock carburettor is held back
swap(mm.engine, "forgasare", "forgasare_origo12")
local s3 = Profile.perf(u)
check("small carburettor limits power", s3.hp < s2.hp * 0.7, s3.hp)
swap(mm.engine, "forgasare", "forgasare_gs21")
swap(mm.engine, "cdi", "cdi_origo")
local s4 = Profile.perf(u)
check("stock CDI limits revs and speed", s4.limit == 7000 and s4.top < s2.top - 20, s4.top)

-- paint and designs
local ps = Paint.new()
for row = 1, Paint.ROWS do for col = 1, Paint.COLS do for _ = 1, 6 do Paint.spray(ps, (col - 0.5) / Paint.COLS, (row - 0.5) / Paint.ROWS, 1 / 30, 1, 0) end end end
local pr = Paint.result(ps)
HOST_ECHO(string.format("  paint: cover %.2f even %.2f runs %.2f q %.2f %s", pr.cover, pr.even, pr.runs, pr.q, pr.label))
check("even spraying gives good paint", pr.q >= 0.75, pr.q)
local ps2 = Paint.new()
for _ = 1, 300 do Paint.spray(ps2, 0.5, 0.5, 1 / 30, 1, 0) end
check("spraying one spot gives runs", Paint.result(ps2).runs > 0, Paint.result(ps2).runs)
local v = Profile.new()
ok, e = Profile.saveDesign(v, "Röd"); check("save design", ok, e)
local okd = Profile.applyDesign(v, 1, 0)
check("apply design costs money", okd and v.money < 4000, v.money)

-- jobs
local w = Profile.new()
local offers = Profile.offers(w)
check("three job offers", #offers == 3)
ok, e = Profile.acceptJob(w, offers[2].key); check("accept repair job", ok, e)
check("customer engine on stand", EngineDef.complete(w.stand))
check("repair not done yet", not Profile.completeJob(w, e.id))
check("cylinder off with head, plug and lead", Profile.unmountEngine(w, "stand", "cylinder"))
check("old rings off", Profile.unmountEngine(w, "stand", "kolvringar"))
check("pin off", Profile.unmountEngine(w, "stand", "kolvbult"))
check("old piston off", Profile.unmountEngine(w, "stand", "kolv"))
local newK, newR = Profile.addItem(w, "kolv_40", "bank"), Profile.addItem(w, "kolvringar_40", "bank")
local seq = { { "kolv", newK }, { "kolvringar", newR } }
for _, x in ipairs(seq) do check("mount new " .. x[1], Profile.mountEngine(w, "stand", x[1], x[2])) end
for _, sock in ipairs({ "kolvbult", "cylinder", "topplock", "tandstift", "tandkabel" }) do
	local id
	for iid, it in pairs(w.items) do if Profile.isFree(w, it) and Parts.get(it.sku).kind == sock and it.cust then id = iid end end
	check("remount customer " .. sock, Profile.mountEngine(w, "stand", sock, id))
end
local money0 = w.money
ok, e = Profile.completeJob(w, w.jobs[1].id); check("repair job paid", ok and w.money == money0 + 950, e)
local leftovers = 0
for _, it in pairs(w.items) do if it.cust then leftovers = leftovers + 1 end end
check("customer parts gone", leftovers == 0 and EngineDef.isEmpty(w.stand), leftovers)

-- saving
local data = Profile.save(p)
local okSave, errSave = pcall(E.checkStorable, data, "save")
check("profile can be saved to DataStore", okSave, errSave)
local loaded = Profile.load(E.deepcopy(data))
check("loaded profile keeps money", loaded.money == p.money)
check("loaded moped still rideable", Profile.canRide(loaded))
local broken = Profile.load({ v = 3, items = { i1 = { sku = "nope", loc = "mount" } }, mopeds = { { model = "citi", slots = { ram = "i1" } } } })
check("broken save is repaired", broken and #broken.mopeds >= 1, #broken.mopeds)
local old = Profile.load({ v = 3, money = 100, items = {}, mopeds = {} })
check("old saves get a free Sprint once", old.mopeds[#old.mopeds].model == "sprint" and old.gotSprint)
check("old save versions start fresh", select(2, Profile.load({ v = 2 })) == "ny")

-- A player's saved garage and every rule for changing it. Pure Lua (no Roblox objects), so the server is the only
-- one that changes a profile and the rules can be tested without Roblox. Functions return ok, err (Swedish message).
local Config = require(script.Parent.Config)
local Parts = require(script.Parent.Parts)
local EngineDef = require(script.Parent.EngineDef)
local MopedDef = require(script.Parent.MopedDef)
local Porting = require(script.Parent.Porting)
local Paint = require(script.Parent.Paint)
local Performance = require(script.Parent.Performance)
local Profile = {}

Profile.VERSION = 3
Profile.STORAGE = { hylla = true, bank = true, golv = true }
Profile.SHELF_SLOTS = 24
Profile.BENCH_SLOTS = 8
Profile.MAX_MOPEDS = 4
Profile.MAX_ORDER_LINES = 20

local function err(m) return false, m end

---------------------------------------------------------------- items
function Profile.addItem(p, sku, loc, extra)
	local id = "i" .. p.nextId
	p.nextId = p.nextId + 1
	local it = { sku = sku, loc = loc or "golv" }
	if extra then for k, v in pairs(extra) do it[k] = v end end
	p.items[id] = it
	return id
end
function Profile.count(p, loc)
	local n = 0
	for _, it in pairs(p.items) do if it.loc == loc then n = n + 1 end end
	return n
end
-- first storage place with room: shelf, then bench, then floor
function Profile.freeStorage(p)
	if Profile.count(p, "hylla") < Profile.SHELF_SLOTS then return "hylla" end
	if Profile.count(p, "bank") < Profile.BENCH_SLOTS then return "bank" end
	return "golv"
end
function Profile.inHand(p)
	for id, it in pairs(p.items) do if it.loc == "hand" then return id end end
end
local function boxOrder(p, loc)
	local oid = type(loc) == "string" and loc:match("^box:(%d+)$")
	if not oid then return nil end
	for _, o in ipairs(p.orders) do if o.id == tonumber(oid) then return o end end
end
-- can this item be picked up / used as a free part?
local function free(p, it)
	if not it then return false end
	if Profile.STORAGE[it.loc] or it.loc == "hand" then return true end
	-- a cylinder in the vise or a panel on the paint stand can be used when no session is running
	if it.loc == "port" then return not p.portStart end
	if it.loc == "lack" then return not p.paintStart end
	local o = boxOrder(p, it.loc)
	return o ~= nil and o.state == "oppnad"
end
Profile.isFree = free

function Profile.moveItem(p, id, loc)
	local it = p.items[id]
	if not it then return err("Delen finns inte") end
	if not free(p, it) and it.loc ~= "port" and it.loc ~= "lack" then
		if boxOrder(p, it.loc) then return err("Öppna paketet först") end
		return err("Delen sitter monterad")
	end
	if it.loc == "port" and p.portStart then return err("Portningen pågår") end
	if loc == "hand" then
		local h = Profile.inHand(p)
		if h and h ~= id then return err("Du bär redan något") end
	elseif loc == "hylla" then
		if Profile.count(p, "hylla") >= Profile.SHELF_SLOTS and it.loc ~= "hylla" then return err("Hyllan är full") end
	elseif loc == "bank" then
		if Profile.count(p, "bank") >= Profile.BENCH_SLOTS and it.loc ~= "bank" then return err("Arbetsbänken är full") end
	elseif loc == "port" then
		if Parts.get(it.sku).kind ~= "cylinder" then return err("Bara cylindrar kan portas") end
		if it.port then return err("Cylindern är redan portad") end
		for oid, o in pairs(p.items) do if o.loc == "port" and oid ~= id then return err("Det ligger redan en cylinder i skruvstädet") end end
	elseif loc == "lack" then
		if Parts.get(it.sku).kind ~= "kapa" then return err("Bara kåpor kan lackeras i lackboxen") end
		for oid, o in pairs(p.items) do if o.loc == "lack" and oid ~= id then return err("Det hänger redan en kåpa i lackboxen") end end
	elseif loc ~= "golv" then
		return err("Kan inte lägga delen där")
	end
	it.loc = loc
	Profile.cleanBoxes(p)
	return true
end

---------------------------------------------------------------- engine and moped
local function engineMap(p, target)
	if target == "stand" then return p.stand end
	local m = p.mopeds[p.cur]
	return m and m.engine, m
end
function Profile.mountEngine(p, target, sock, id)
	local map = engineMap(p, target)
	if not map then return err("Ingen motor där") end
	local it = p.items[id]
	if not free(p, it) then return err("Delen är inte ledig") end
	local ok, e = EngineDef.canMount(map, sock, it.sku, p.items)
	if not ok then return err(e) end
	map[sock] = id
	it.loc = "mount"
	Profile.cleanBoxes(p)
	return true
end
function Profile.unmountEngine(p, target, sock)
	local map = engineMap(p, target)
	if not map then return err("Ingen motor där") end
	local ok, e = EngineDef.canRemove(map, sock)
	if not ok then return err(e) end
	local extra = {}
	for _, d in ipairs(EngineDef.dependents(map, sock)) do
		local did = map[d]
		map[d] = nil
		p.items[did].loc = Profile.count(p, "bank") < Profile.BENCH_SLOTS and "bank" or "golv"
		extra[#extra + 1] = EngineDef.BY_ID[d].name:lower()
	end
	local id = map[sock]
	map[sock] = nil
	p.items[id].loc = Profile.count(p, "bank") < Profile.BENCH_SLOTS and "bank" or "golv"
	return true, id, extra
end
function Profile.mountChassis(p, slot, id, now)
	local m = p.mopeds[p.cur]
	if not m then return err("Ingen moped på lyften") end
	local it = p.items[id]
	if not free(p, it) then return err("Delen är inte ledig") end
	if it.dry and now and it.dry > now then return err("Lacken är inte torr än") end
	local ok, e = MopedDef.canMount(m, slot, it.sku)
	if not ok then return err(e) end
	m.slots[slot] = id
	it.loc = "mount"
	Profile.cleanBoxes(p)
	return true
end
function Profile.unmountChassis(p, slot)
	local m = p.mopeds[p.cur]
	if not m then return err("Ingen moped på lyften") end
	if slot == "motor" then return Profile.engineToStand(p) end
	local ok, e = MopedDef.canRemove(m, slot)
	if not ok then return err(e) end
	local extra = {}
	for _, d in ipairs(MopedDef.dependents(m, slot)) do
		local did = m.slots[d]
		m.slots[d] = nil
		p.items[did].loc = Profile.count(p, "bank") < Profile.BENCH_SLOTS and "bank" or "golv"
		extra[#extra + 1] = MopedDef.slotName(m.model, d):lower()
	end
	local id = m.slots[slot]
	m.slots[slot] = nil
	p.items[id].loc = Profile.count(p, "bank") < Profile.BENCH_SLOTS and "bank" or "golv"
	return true, id, extra
end
function Profile.engineToMoped(p)
	local m = p.mopeds[p.cur]
	if not m then return err("Ingen moped på lyften") end
	local ok, e = MopedDef.canMountEngine(m, p.stand)
	if not ok then return err(e) end
	m.engine = p.stand
	p.stand = {}
	return true
end
function Profile.engineToStand(p)
	local m = p.mopeds[p.cur]
	if not m or not m.engine then return err("Mopeden har ingen motor") end
	if not EngineDef.isEmpty(p.stand) then return err("Motorstativet är upptaget") end
	local ok, e = MopedDef.canRemove(m, "motor")
	if not ok then return err(e) end
	p.stand = m.engine
	m.engine = nil
	return true
end

-- problems that stop the current moped from running (missing parts, seized engine)
function Profile.mopedProblems(p, m)
	m = m or p.mopeds[p.cur]
	if not m then return { "Ingen moped" } end
	local r = MopedDef.missing(m)
	if m.engine then
		for _, s in ipairs({ "kolv", "kolvringar" }) do
			local id = m.engine[s]
			if id and p.items[id] and (p.items[id].wear or 0) >= 1 then r[#r + 1] = "Kolvskär: byt " .. EngineDef.BY_ID[s].name:lower() end
		end
	end
	return r
end
function Profile.canRide(p) return #Profile.mopedProblems(p) == 0 end
function Profile.chassisMap(m)
	local c = {}
	for k, v in pairs(m.slots) do c[k] = v end
	return c
end
function Profile.perf(p, m)
	m = m or p.mopeds[p.cur]
	if not m or not m.engine then return nil end
	return Performance.summary(p.items, m.engine, m.slots, m.jet or 0)
end

---------------------------------------------------------------- mopeds
local OEM = {
	ram = nil, gaffel = "gaffel_origo", framhjul = "framhjul_origo", frambroms = "frambroms_origo", styre = "styre_origo", dampare = "dampare_origo",
	bakhjul = "bakhjul_origo", bakbroms = "bakbroms_origo", avgas = "avgas_origo", tank = "tank_origo", sadel = "sadel_origo",
}
Profile.OEM_ENGINE = {
	vevhus = "vevhus_origo", vevlager = "vevlager_origo", vevaxel = "vevaxel_origo", packbox = "packbox_origo", nallager = "nallager_origo",
	kolv = "kolv_40", kolvbult = "kolvbult_origo", kolvringar = "kolvringar_40", fotpackning = "fotpackning_origo", cylinder = "cylinder_origo50",
	topplock = "topplock_origo", tandstift = "tandstift_b7", reed = "reed_origo", insug = "insug_origo", forgasare = "forgasare_origo12",
	luftfilter = "luftfilter_origo", slang = "slang_origo", stator = "stator_origo", svanghjul = "svanghjul_origo", cdi = "cdi_origo",
	spole = "spole_origo", tandkabel = "tandkabel_origo", variator = "variator_origo", vikter = "vikter_6g", flakt = "flakt_origo",
	remskiva = "remskiva_origo", koppling = "koppling_origo", rem = "rem_origo", klocka = "klocka_origo",
}
function Profile.newEngine(p, extra)
	local map = {}
	for sock, sku in pairs(Profile.OEM_ENGINE) do map[sock] = Profile.addItem(p, sku, "mount", extra) end
	return map
end
function Profile.giveMoped(p, model, color)
	local def = MopedDef.MODELS[model]
	local m = { model = model, slots = {}, engine = nil, jet = 0, odo = 0 }
	m.slots.ram = Profile.addItem(p, "ram_" .. model, "mount")
	for slot, sku in pairs(OEM) do m.slots[slot] = Profile.addItem(p, sku, "mount") end
	for _, pan in ipairs(def.panels) do
		m.slots["pan:" .. pan.id] = Profile.addItem(p, "kapa_" .. model .. "_" .. pan.id, "mount", { paint = { c = color or def.color, f = "blank", g = 0.6, q = 1 } })
	end
	m.engine = Profile.newEngine(p)
	p.mopeds[#p.mopeds + 1] = m
	return #p.mopeds
end
function Profile.buyMoped(p, model)
	local def = MopedDef.MODELS[model]
	if not def then return err("Okänd modell") end
	if #p.mopeds >= Profile.MAX_MOPEDS then return err("Garaget rymmer " .. Profile.MAX_MOPEDS .. " mopeder") end
	if p.money < def.price then return err("Du har inte råd") end
	p.money = p.money - def.price
	local idx = Profile.giveMoped(p, model)
	return true, idx
end
local function mopedItems(m)
	local r = {}
	for _, id in pairs(m.slots) do r[#r + 1] = id end
	if m.engine then for _, id in pairs(m.engine) do r[#r + 1] = id end end
	return r
end
function Profile.mopedValue(p, m)
	local v = 0
	for _, id in ipairs(mopedItems(m)) do
		local it = p.items[id]
		local part = it and Parts.get(it.sku)
		if part then v = v + part.price * (1 - 0.5 * (it.wear or 0)) end
	end
	return math.floor(v * 0.6)
end
function Profile.sellMoped(p, idx)
	local m = p.mopeds[idx]
	if not m then return err("Ingen sådan moped") end
	if #p.mopeds <= 1 then return err("Du måste ha minst en moped") end
	local v = Profile.mopedValue(p, m)
	for _, id in ipairs(mopedItems(m)) do p.items[id] = nil end
	table.remove(p.mopeds, idx)
	if p.cur > #p.mopeds then p.cur = #p.mopeds elseif p.cur > idx then p.cur = p.cur - 1 end
	p.money = p.money + v
	return true, v
end
function Profile.selectMoped(p, idx)
	if not p.mopeds[idx] then return err("Ingen sådan moped") end
	p.cur = idx
	return true
end
function Profile.setJet(p, jet)
	local m = p.mopeds[p.cur]
	jet = tonumber(jet)
	if not m or not jet then return err("Fel värde") end
	m.jet = math.max(-2, math.min(2, math.floor(jet + 0.5)))
	return true
end

---------------------------------------------------------------- shop
function Profile.deliverySeconds(lines)
	local n, back = 0, false
	for _, l in ipairs(lines) do
		n = n + l.qty
		if l.back then back = true end
	end
	local s
	if n <= 2 then s = 60 elseif n <= 6 then s = 180 + (n - 3) * 30 else s = 600 end
	if back then s = s + 120 end
	return s
end
-- cart = { {sku=, qty=} }; stock(sku) -> number in stock (server-wide); returns ok, order
function Profile.order(p, cart, now, stock)
	if type(cart) ~= "table" or #cart == 0 then return err("Kundvagnen är tom") end
	if #cart > Profile.MAX_ORDER_LINES then return err("För många rader") end
	local lines, total, seen = {}, 0, {}
	for _, l in ipairs(cart) do
		local part = type(l) == "table" and Parts.get(l.sku)
		local qty = type(l) == "table" and tonumber(l.qty)
		if not part or not qty then return err("Ogiltig vara") end
		qty = math.floor(qty)
		if qty < 1 or qty > 10 then return err("Antal måste vara 1–10") end
		if seen[part.sku] then return err("Dubbel rad") end
		seen[part.sku] = true
		if part.kind == "verktyg" and part.price == 0 then return err(part.name .. " följer redan med garaget") end
		local inStock = stock and stock(part.sku) or part.stock
		lines[#lines + 1] = { sku = part.sku, qty = qty, price = part.price, back = inStock < qty }
		total = total + part.price * qty
	end
	local freight = total >= 2000 and 0 or 99
	total = total + freight
	if p.money < total then return err("Du har inte råd (" .. total .. " kr)") end
	p.money = p.money - total
	local o = { id = p.nextOrder, lines = lines, total = total, freight = freight, placed = now, ready = now + Profile.deliverySeconds(lines), state = "vag" }
	p.nextOrder = p.nextOrder + 1
	table.insert(p.orders, o)
	while #p.orders > 30 do table.remove(p.orders, 1) end
	return true, o
end
-- orders that have arrived get their parts in a box; returns ids of arrived orders
function Profile.tick(p, now)
	local arrived = {}
	for _, o in ipairs(p.orders) do
		if o.state == "vag" and o.ready <= now then
			o.state = "framme"
			for _, l in ipairs(o.lines) do
				for _ = 1, l.qty do Profile.addItem(p, l.sku, "box:" .. o.id) end
			end
			arrived[#arrived + 1] = o.id
		end
	end
	return arrived
end
function Profile.openBox(p, oid)
	for _, o in ipairs(p.orders) do
		if o.id == oid then
			if o.state ~= "framme" then return err("Paketet är redan öppnat") end
			o.state = "oppnad"
			return true
		end
	end
	return err("Inget sådant paket")
end
function Profile.boxItems(p, oid)
	local r = {}
	for id, it in pairs(p.items) do if it.loc == "box:" .. oid then r[#r + 1] = id end end
	table.sort(r)
	return r
end
-- an opened box with nothing left is thrown away
function Profile.cleanBoxes(p)
	for _, o in ipairs(p.orders) do
		if o.state == "oppnad" and #Profile.boxItems(p, o.id) == 0 then o.state = "tom" end
	end
end
function Profile.sellItem(p, id)
	local it = p.items[id]
	if not it or not free(p, it) then return err("Delen kan inte säljas") end
	if it.cust then return err("Delen tillhör en kund") end
	local part = Parts.get(it.sku)
	if part.kind == "verktyg" and part.price == 0 then return err("Den behåller du") end
	local v = math.floor(part.price * Config.SELL_FACTOR * (1 - 0.6 * (it.wear or 0)))
	p.items[id] = nil
	p.money = p.money + v
	Profile.cleanBoxes(p)
	return true, v
end
function Profile.bestTool(p, toolKind)
	local best
	for _, it in pairs(p.items) do
		local part = Parts.get(it.sku)
		if part and part.kind == "verktyg" and part.stats.tool == toolKind then
			if not best or part.price > best.price then best = part end
		end
	end
	return best
end

---------------------------------------------------------------- porting and paint
function Profile.portStart(p, now)
	local id
	for oid, it in pairs(p.items) do if it.loc == "port" then id = oid end end
	if not id then return err("Lägg en cylinder i skruvstädet först") end
	if not Profile.bestTool(p, "slip") then return err("Du behöver en rak slipmaskin") end
	p.portStart = now
	return true, id
end
function Profile.portDone(p, state, now)
	if not p.portStart then return err("Ingen portning pågår") end
	local elapsed = now - p.portStart
	p.portStart = nil
	if elapsed < Config.PORT_MIN_TIME then return err("För snabbt") end
	local id
	for oid, it in pairs(p.items) do if it.loc == "port" then id = oid end end
	if not id then return err("Cylindern är borta") end
	local res = Porting.result(state)
	if not res then return err("Ogiltigt resultat") end
	p.items[id].port = { q = res.q, label = res.label }
	p.stats.ported = p.stats.ported + 1
	return true, res
end
function Profile.paintStart(p, now)
	local id
	for oid, it in pairs(p.items) do if it.loc == "lack" then id = oid end end
	if not id then return err("Häng en kåpa i lackboxen först") end
	if not Profile.bestTool(p, "spruta") then return err("Du behöver en sprutpistol") end
	p.paintStart = now
	return true, id
end
function Profile.paintDone(p, color, finish, gloss, state, now)
	if not p.paintStart then return err("Ingen lackering pågår") end
	local elapsed = now - p.paintStart
	p.paintStart = nil
	if elapsed < Config.PAINT_MIN_TIME then return err("För snabbt") end
	local c = Paint.validColor(color)
	if not c or not Paint.FIN[finish] then return err("Ogiltig färg") end
	local id
	for oid, it in pairs(p.items) do if it.loc == "lack" then id = oid end end
	if not id then return err("Kåpan är borta") end
	local res = Paint.result(state)
	if not res then return err("Ogiltigt resultat") end
	gloss = math.max(0, math.min(1, tonumber(gloss) or 0.6))
	p.items[id].paint = { c = c, f = finish, g = gloss, q = res.q }
	p.items[id].dry = now + Config.PAINT_DRY
	p.stats.painted = p.stats.painted + 1
	return true, res
end
-- designs: the colours of every panel of the current moped
function Profile.saveDesign(p, name)
	local m = p.mopeds[p.cur]
	if type(name) ~= "string" then return err("Ange ett namn") end
	name = name:sub(1, 24):gsub("[%c<>]", "")
	if name == "" then return err("Ange ett namn") end
	local d = { n = name, model = m.model, panels = {} }
	for slot, id in pairs(m.slots) do
		local pid = slot:match("^pan:(.+)$")
		local it = p.items[id]
		if pid and it and it.paint then d.panels[pid] = { c = it.paint.c, f = it.paint.f, g = it.paint.g } end
	end
	if next(d.panels) == nil then return err("Inga lackerade kåpor att spara") end
	for i, old in ipairs(p.designs) do if old.n == name then p.designs[i] = d; return true end end
	if #p.designs >= 12 then return err("Max 12 designer") end
	p.designs[#p.designs + 1] = d
	return true
end
Profile.DESIGN_COST = 120
function Profile.applyDesign(p, idx, now)
	local d = p.designs[idx]
	local m = p.mopeds[p.cur]
	if not d or not m then return err("Ingen sådan design") end
	if d.model ~= m.model then return err("Designen är gjord för " .. MopedDef.MODELS[d.model].n) end
	local targets = {}
	for pid, paint in pairs(d.panels) do
		local id = m.slots["pan:" .. pid]
		if id then targets[#targets + 1] = { id = id, paint = paint } end
	end
	local cost = #targets * Profile.DESIGN_COST
	if #targets == 0 then return err("Inga kåpor monterade") end
	if p.money < cost then return err("Lackeringen kostar " .. cost .. " kr") end
	p.money = p.money - cost
	for _, t in ipairs(targets) do p.items[t.id].paint = { c = t.paint.c, f = t.paint.f, g = t.paint.g, q = 1 } end
	return true, cost
end

---------------------------------------------------------------- riding
Profile.KM_PAY = 12
function Profile.addDistance(p, meters)
	meters = math.max(0, math.min(400, tonumber(meters) or 0)) -- server caps per report
	p.stats.km = p.stats.km + meters / 1000
	local m = p.mopeds[p.cur]
	if m then m.odo = (m.odo or 0) + meters / 1000 end
	p.distAcc = (p.distAcc or 0) + meters
	local pay = math.floor(p.distAcc / 1000 * Profile.KM_PAY)
	if pay > 0 then
		p.distAcc = p.distAcc - pay * 1000 / Profile.KM_PAY
		p.money = p.money + pay
		p.stats.earned = p.stats.earned + pay
	end
	return pay
end
-- overheating wears piston and rings; at 1 the engine seizes
function Profile.addWear(p, amount)
	local m = p.mopeds[p.cur]
	if not m or not m.engine then return end
	amount = math.max(0, math.min(0.25, tonumber(amount) or 0))
	for _, s in ipairs({ "kolv", "kolvringar" }) do
		local it = p.items[m.engine[s]]
		if it then it.wear = math.min(1, (it.wear or 0) + amount) end
	end
end

---------------------------------------------------------------- jobs (uppdrag)
Profile.DESTINATIONS = {
	norr = "Verkstad Norr", hamn = "Hamnens lager", macken = "Macken", gard = "Lindgårdens gård", ind = "Industriverkstaden",
}
local DEST_ORDER = { "norr", "hamn", "macken", "gard", "ind" }
-- the board always offers three jobs; which ones depends on how many jobs you have done
function Profile.offers(p)
	local n = p.stats.jobs
	local r = {}
	local d1 = DEST_ORDER[(n % #DEST_ORDER) + 1]
	local d2 = DEST_ORDER[((n + 2) % #DEST_ORDER) + 1]
	r[1] = { key = "lev:" .. d1, type = "leverans", dest = d1, n = "Leverera reservdelar till " .. Profile.DESTINATIONS[d1], pay = 300 + (n % 3) * 75, about = "Hämta paketet vid garageporten och kör det till markeringen." }
	r[2] = { key = "rep:" .. n, type = "reparation", n = "Kolvskär: byt kolv och ringar på kundmotor", pay = 950, about = "Kundens motor ställs på ditt motorstativ. Byt kolv och kolvringar mot nya (40 mm) och lämna tillbaka motorn." }
	r[3] = { key = "bygg:" .. d2, type = "bygg", n = "Bygg en trimmad motor åt en kund", pay = 600, lvl = 1, about = "Bygg en komplett motor på stativet med minst sportcylinder (70 cc). Du får betalt för delarna plus arbetet." }
	return r
end
function Profile.acceptJob(p, key)
	if #p.jobs >= 2 then return err("Du har redan två uppdrag") end
	local offer
	for _, o in ipairs(Profile.offers(p)) do if o.key == key then offer = o end end
	if not offer then return err("Uppdraget finns inte längre") end
	for _, j in ipairs(p.jobs) do
		if j.type == offer.type then return err("Du har redan ett sådant uppdrag") end
	end
	local job = { key = offer.key, type = offer.type, n = offer.n, pay = offer.pay, dest = offer.dest, lvl = offer.lvl, id = p.nextJob }
	p.nextJob = p.nextJob + 1
	if offer.type == "reparation" then
		if not EngineDef.isEmpty(p.stand) then return err("Töm motorstativet först") end
		p.stand = Profile.newEngine(p, { cust = job.id })
		for _, s in ipairs({ "kolv", "kolvringar" }) do p.items[p.stand[s]].wear = 1 end
	end
	p.jobs[#p.jobs + 1] = job
	return true, job
end
local function jobIndex(p, id) for i, j in ipairs(p.jobs) do if j.id == id then return i, j end end end
-- deliver: the server checks the player is at the destination before calling this
function Profile.completeJob(p, id)
	local i, j = jobIndex(p, id)
	if not j then return err("Inget sådant uppdrag") end
	local pay = j.pay
	if j.type == "reparation" then
		for _, s in ipairs({ "kolv", "kolvringar" }) do
			local it = p.items[p.stand[s] or ""]
			if not it or (it.wear or 0) > 0.05 then return err("Byt " .. EngineDef.BY_ID[s].name:lower() .. " först") end
		end
		if not EngineDef.complete(p.stand) then return err("Motorn måste vara komplett") end
		for _, id2 in pairs(p.stand) do p.items[id2] = nil end
		p.stand = {}
		for id2, it in pairs(p.items) do if it.cust == j.id then p.items[id2] = nil end end -- the old worn parts go to scrap
	elseif j.type == "bygg" then
		if not EngineDef.complete(p.stand) then return err("Bygg en komplett motor på stativet") end
		local cyl = Parts.get(p.items[p.stand.cylinder].sku)
		if (cyl.stats.lvl or 0) < (j.lvl or 1) then return err("Kunden vill ha minst en 70 cc sportcylinder") end
		local value = 0
		for _, id2 in pairs(p.stand) do
			local it = p.items[id2]
			if it.cust then return err("Motorn innehåller en annan kunds delar") end
			value = value + Parts.get(it.sku).price
			p.items[id2] = nil
		end
		p.stand = {}
		pay = pay + math.floor(value * 1.1)
	end
	table.remove(p.jobs, i)
	p.money = p.money + pay
	p.stats.jobs = p.stats.jobs + 1
	p.stats.earned = p.stats.earned + pay
	return true, pay
end
function Profile.cancelJob(p, id)
	local i, j = jobIndex(p, id)
	if not j then return err("Inget sådant uppdrag") end
	if j.type == "reparation" then
		-- the customer takes back their engine as it is; their parts leave the garage
		for s, id2 in pairs(p.stand) do if p.items[id2] and p.items[id2].cust == j.id then p.stand[s] = nil end end
		for id2, it in pairs(p.items) do if it.cust == j.id then p.items[id2] = nil end end
		-- player's own parts left on the stand go back to the bench
		for s, id2 in pairs(p.stand) do p.stand[s] = nil; p.items[id2].loc = "bank" end
	end
	table.remove(p.jobs, i)
	return true
end

---------------------------------------------------------------- create, load, save
function Profile.new()
	local p = {
		v = Profile.VERSION, money = Config.START_MONEY, items = {}, nextId = 1, stand = {}, mopeds = {}, cur = 1,
		orders = {}, nextOrder = 1, designs = {}, jobs = {}, nextJob = 1,
		stats = { km = 0, built = 0, ported = 0, painted = 0, jobs = 0, earned = 0 },
	}
	Profile.giveMoped(p, "citi", { 200, 30, 40 })
	Profile.addItem(p, "verktyg_hylsor", "verktyg")
	Profile.addItem(p, "verktyg_slip", "verktyg")
	Profile.addItem(p, "verktyg_spruta", "verktyg")
	-- a few spare parts on the shelf to start building with
	Profile.addItem(p, "fotpackning_origo", "hylla")
	Profile.addItem(p, "tandstift_b7", "hylla")
	Profile.addItem(p, "cylinder_origo50", "hylla")
	return p
end

local function validMap(p, map, used)
	if type(map) ~= "table" then return {} end
	local r = {}
	for k, id in pairs(map) do
		if type(k) == "string" and type(id) == "string" and p.items[id] and not used[id] then r[k] = id; used[id] = true end
	end
	return r
end
-- validate saved data; anything broken is repaired or dropped. Bad or old data gives a new profile.
function Profile.load(d)
	if type(d) ~= "table" or d.v ~= Profile.VERSION or type(d.items) ~= "table" then return Profile.new(), "ny" end
	local p = Profile.new()
	p.items = {}
	p.mopeds = {}
	p.money = math.max(0, math.floor(tonumber(d.money) or 0))
	p.nextId = math.max(1, math.floor(tonumber(d.nextId) or 1))
	for id, it in pairs(d.items) do
		if type(id) == "string" and type(it) == "table" and Parts.get(it.sku) then
			local num = tonumber(id:match("^i(%d+)$"))
			if num then
				p.items[id] = it
				if num >= p.nextId then p.nextId = num + 1 end
			end
		end
	end
	local used = {}
	p.stand = validMap(p, d.stand, used)
	if type(d.mopeds) == "table" then
		for _, m in ipairs(d.mopeds) do
			if type(m) == "table" and MopedDef.MODELS[m.model] then
				local nm = { model = m.model, slots = validMap(p, m.slots, used), engine = m.engine and validMap(p, m.engine, used) or nil, jet = tonumber(m.jet) or 0, odo = tonumber(m.odo) or 0 }
				p.mopeds[#p.mopeds + 1] = nm
			end
		end
	end
	if #p.mopeds == 0 then Profile.giveMoped(p, "citi", { 200, 30, 40 }) end
	p.cur = math.max(1, math.min(#p.mopeds, math.floor(tonumber(d.cur) or 1)))
	p.orders = {}
	if type(d.orders) == "table" then
		for _, o in ipairs(d.orders) do
			if type(o) == "table" and type(o.id) == "number" and type(o.lines) == "table" and type(o.state) == "string" then p.orders[#p.orders + 1] = o end
		end
	end
	p.nextOrder = math.max(1, math.floor(tonumber(d.nextOrder) or 1))
	for _, o in ipairs(p.orders) do if o.id >= p.nextOrder then p.nextOrder = o.id + 1 end end
	p.designs = type(d.designs) == "table" and d.designs or {}
	p.jobs = type(d.jobs) == "table" and d.jobs or {}
	p.nextJob = math.max(1, math.floor(tonumber(d.nextJob) or 1))
	if type(d.stats) == "table" then for k in pairs(p.stats) do p.stats[k] = tonumber(d.stats[k]) or 0 end end
	-- locations: mounted parts must be referenced; things in hand go to the bench
	for id, it in pairs(p.items) do
		if it.loc == "mount" and not used[id] then it.loc = "golv" end
		if used[id] then it.loc = "mount" end
		if it.loc == "hand" then it.loc = "bank" end
		if type(it.loc) ~= "string" then it.loc = "golv" end
	end
	-- delivery jobs carry nothing physical; a lost leverans job is just kept
	Profile.cleanBoxes(p)
	return p, "laddad"
end
-- the data that is saved (plain tables only)
function Profile.save(p)
	local d = {}
	for k, v in pairs(p) do
		if k ~= "portStart" and k ~= "paintStart" and k ~= "distAcc" then d[k] = v end
	end
	return d
end

return Profile

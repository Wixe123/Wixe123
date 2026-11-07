-- Player profile, parts as physical items and the economy (server authoritative, testable without Roblox).
-- Each item has a location: shelf | bench | floor | box:<order> | eng:<moped> (+ sock) | ch:<moped> (+ sock) | booth | portbench | tool.
-- Money only changes via book(), and can never go below 0.
local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.Catalog)
local Assembly = require(script.Parent.Assembly)
local Engine = require(script.Parent.Engine)
local Panels = require(script.Parent.Panels)
local Delivery = require(script.Parent.Delivery)
local Paint = require(script.Parent.Paint)
local Economy = {}
local E = Config.ECON

local function num(x, d, lo, hi) if type(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge then return d end return math.min(hi, math.max(lo, x)) end
local function hex(c) return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
Economy.hex = hex

local function newItem(p, sku, loc, src)
	p.uid = p.uid + 1
	local u = "i" .. p.uid
	p.items[u] = { s = sku, loc = loc, used = false, src = src or "shop" }
	return u
end
Economy.newItem = newItem

local function defaultPaint(m, pd)
	local col = pd.role == "body" and hex(m.d.col) or pd.role == "white" and "#f2f2ee" or "#1a1a1c"
	return { col = col, fin = pd.role == "dark" and "matt" or "gloss", q = 1 }
end

-- a complete original moped: all engine parts, chassis and panels with factory paint
function Economy.buildOEM(p, id)
	local m = Config.BY_ID[id]
	local mp = { own = true, jet = m.d.jet, dmg = 0, eng = {}, ch = {}, engAt = "moped" }
	p.mopeds[id] = mp
	for _, s in ipairs(Assembly.engineSockets(id)) do
		local sku = Catalog.OEM[id][s.kind]
		if sku then local u = newItem(p, sku, "eng:" .. id, "oem"); p.items[u].sock = s.id; mp.eng[s.id] = u end
	end
	for _, s in ipairs(Assembly.chassisSlots(id)) do
		local sku = s.kind == "panel" and Catalog.OEM_PANEL[id][s.panel] or (s.kind ~= "engine" and Catalog.OEM[id][s.kind])
		if sku then
			local u = newItem(p, sku, "ch:" .. id, "oem")
			p.items[u].sock = s.id
			if s.kind == "panel" then p.items[u].paint = defaultPaint(m, Panels.find(id, s.panel)) end
			mp.ch[s.id] = u
		end
	end
	mp.ch.engine = "engine" -- the engine is a unit, not an item
end

function Economy.new()
	local p = { v = 2, money = E.start, uid = 0, items = {}, mopeds = {}, stand = nil, cur = "jog", orders = {}, oid = 0, designs = {},
		stats = { dist = 0, top = 0, wn = 0, best = 0, crash = 0, earned = 0, built = 0, ported = 0, painted = 0 }, paid = 0, clean = 0, cleanPaid = 0, rep = 0, ledger = {} }
	Economy.buildOEM(p, "jog")
	newItem(p, "P-tool-basic", "tool", "start")
	newItem(p, "P-tool-grinder", "tool", "start")
	newItem(p, "P-tool-spray", "tool", "start")
	return p
end

function Economy.book(p, a, text, now)
	a = math.floor(a + 0.5)
	if a == 0 then return 0 end
	p.money = p.money + a
	if a > 0 then p.stats.earned = p.stats.earned + a end
	table.insert(p.ledger, 1, { a = a, x = text, t = now or 0 })
	while #p.ledger > 40 do table.remove(p.ledger) end
	return a
end
function Economy.spend(p, a, text, now)
	a = math.floor(a + 0.5)
	if a < 0 or a > p.money then return false end
	Economy.book(p, -a, text, now)
	return true
end
function Economy.fine(p, a, text, now) return -Economy.book(p, -math.min(math.floor(a + 0.5), p.money), text, now) end

-- maps socket -> sku for the assembly rules
local function skuMap(p, t)
	local o = {}
	for k, u in pairs(t) do if u == "engine" then o[k] = "engine" elseif p.items[u] then o[k] = p.items[u].s end end
	return o
end
Economy.skuMap = skuMap
function Economy.engineMissing(p, id) local mp = p.mopeds[id]; return Assembly.missing(Assembly.engineSockets(id), skuMap(p, mp.eng)) end
function Economy.mopedMissing(p, id)
	local mp = p.mopeds[id]
	local miss = Assembly.missing(Assembly.chassisSlots(id), skuMap(p, mp.ch))
	if mp.engAt ~= "moped" then local has = false; for _, x in ipairs(miss) do if x == "engine" then has = true end end; if not has then table.insert(miss, "engine") end end
	if #Economy.engineMissing(p, id) > 0 then table.insert(miss, "motordelar") end
	return miss
end
function Economy.canRide(p, id) return p.mopeds[id] and p.mopeds[id].own and #Economy.mopedMissing(p, id) == 0 end

function Economy.ecfg(p, id)
	local mp = p.mopeds[id]
	local cyl = mp.eng.cyl and p.items[mp.eng.cyl]
	return Assembly.ecfg(skuMap(p, mp.eng), skuMap(p, mp.ch), mp.jet, cyl and cyl.port)
end
function Economy.engine(p, id)
	local P = Engine.calc(Economy.ecfg(p, id))
	P.cond = 1 - 0.4 * (p.mopeds[id].dmg or 0)
	P.hp = Engine.peakHp(P)
	return P
end

local function hasTool(p, kind)
	local best = nil
	for _, it in pairs(p.items) do
		local pr = Catalog.BY_SKU[it.s]
		if it.loc == "tool" and pr and pr.val.tool == kind then if not best or (pr.val.steady or pr.val.even or 0) > (best.val.steady or best.val.even or 0) then best = pr end end
	end
	return best
end
Economy.hasTool = hasTool

-- ---------- moving parts in the garage ----------
local FREE = { shelf = true, bench = true, floor = true, booth = true, portbench = true }
function Economy.move(p, u, loc)
	local it = p.items[u]
	if not it then return false, "Okänd del" end
	if not FREE[loc] then return false, "Kan inte läggas där" end
	if not (FREE[it.loc] or it.loc:sub(1, 4) == "box:") then return false, "Delen sitter monterad" end
	local pr = Catalog.BY_SKU[it.s]
	if loc == "booth" then
		if pr.kind ~= "panel" then return false, "Bara kåpor kan lackeras" end
		for _, o in pairs(p.items) do if o.loc == "booth" and o ~= it then return false, "Lackboxen är upptagen" end end
	end
	if loc == "portbench" then
		if not pr.hasPort then return false, "Bara cylindrar kan portas" end
		for _, o in pairs(p.items) do if o.loc == "portbench" and o ~= it then return false, "Portningsbänken är upptagen" end end
	end
	it.loc = loc
	it.sock = nil
	return true
end

-- engine parts: only when the engine is on the engine stand
function Economy.mountEngine(p, u, sock)
	local id = p.stand
	if not id then return false, "Ingen motor i motorstativet" end
	local it = p.items[u]
	if not it or not (FREE[it.loc] or it.loc:sub(1, 4) == "box:") then return false, "Delen är inte ledig" end
	if (it.dry or 0) > 0 then return false, "Lacken torkar" end
	if not hasTool(p, "basic") then return false, "Du behöver verktyg" end
	local list = Assembly.engineSockets(id)
	local why = Assembly.canMount(list, skuMap(p, p.mopeds[id].eng), id, sock, it.s)
	if why then return false, why end
	p.mopeds[id].eng[sock] = u
	it.loc, it.sock, it.used = "eng:" .. id, sock, true
	if #Economy.engineMissing(p, id) == 0 then p.stats.built = p.stats.built + 1 end
	return true
end
function Economy.unmountEngine(p, sock, toLoc)
	local id = p.stand
	if not id then return false, "Ingen motor i motorstativet" end
	local mp = p.mopeds[id]
	local why = Assembly.canRemove(Assembly.engineSockets(id), skuMap(p, mp.eng), id, sock)
	if why then return false, why end
	local u = mp.eng[sock]
	mp.eng[sock] = nil
	p.items[u].loc, p.items[u].sock = toLoc or "bench", nil
	return true, nil, u
end
-- moped parts and panels: when the moped is in the garage
function Economy.mountMoped(p, u, id, sock)
	local mp = p.mopeds[id]
	if not mp or not mp.own then return false, "Du äger inte mopeden" end
	local it = p.items[u]
	if not it or not (FREE[it.loc] or it.loc:sub(1, 4) == "box:") then return false, "Delen är inte ledig" end
	if (it.dry or 0) > 0 then return false, "Lacken torkar fortfarande" end
	local why = Assembly.canMount(Assembly.chassisSlots(id), skuMap(p, mp.ch), id, sock, it.s)
	if why then return false, why end
	mp.ch[sock] = u
	it.loc, it.sock, it.used = "ch:" .. id, sock, true
	return true
end
function Economy.unmountMoped(p, id, sock, toLoc)
	local mp = p.mopeds[id]
	if not mp or not mp.own then return false, "Du äger inte mopeden" end
	if sock == "engine" then return false, "Motorn lyfts ur med \"Lyft ur motorn\"" end
	local why = Assembly.canRemove(Assembly.chassisSlots(id), skuMap(p, mp.ch), id, sock)
	if why then return false, why end
	local u = mp.ch[sock]
	mp.ch[sock] = nil
	p.items[u].loc, p.items[u].sock = toLoc or "bench", nil
	return true, nil, u
end
-- the whole engine between the moped and the engine stand
function Economy.engineToStand(p, id)
	local mp = p.mopeds[id]
	if not mp or not mp.own then return false, "Du äger inte mopeden" end
	if p.stand then return false, "Motorstativet är upptaget" end
	if mp.engAt ~= "moped" then return false, "Motorn sitter inte i mopeden" end
	local why = Assembly.canRemove(Assembly.chassisSlots(id), skuMap(p, mp.ch), id, "engine")
	if why then return false, why end
	mp.ch.engine = nil
	mp.engAt = "stand"
	p.stand = id
	return true
end
function Economy.engineToMoped(p)
	local id = p.stand
	if not id then return false, "Ingen motor i stativet" end
	local mp = p.mopeds[id]
	local miss = Economy.engineMissing(p, id)
	if #miss > 0 then return false, "Motorn är inte färdig: " .. table.concat(Assembly.names(Assembly.engineSockets(id), miss, id), ", ") end
	local list = Assembly.chassisSlots(id)
	for _, r in ipairs(Assembly.find(list, "engine").req) do
		if not mp.ch[r] then return false, "Montera " .. Assembly.names(list, { r }, id)[1] .. " på mopeden först" end
	end
	mp.ch.engine = "engine"
	mp.engAt = "moped"
	p.stand = nil
	return true
end

-- ---------- shop: orders, delivery, boxes ----------
function Economy.order(p, lines, now)
	if type(lines) ~= "table" or #lines == 0 then return false, "Kundvagnen är tom" end
	local clean, tot = {}, 0
	for _, l in ipairs(lines) do
		local pr = type(l) == "table" and Catalog.BY_SKU[l.sku]
		local q = type(l) == "table" and math.floor(num(l.q, 1, 1, 10)) or 0
		if not pr then return false, "En produkt finns inte" end
		if pr.kind == "tool" then for _, it in pairs(p.items) do if it.s == pr.sku then return false, "Du har redan " .. pr.name end end end
		tot = tot + pr.price * q
		table.insert(clean, { sku = pr.sku, q = q })
	end
	if #clean > 12 then return false, "Högst 12 olika produkter per beställning" end
	if tot > p.money then return false, "Du har inte råd (" .. Catalog.fmt(tot) .. " kr, du har " .. Catalog.fmt(p.money) .. " kr). Inga pengar drogs." end
	Economy.spend(p, tot, "Beställning hos Moppelagret.se", now)
	p.oid = p.oid + 1
	local o = { id = p.oid, lines = clean, total = tot, t0 = now, eta = now + Delivery.seconds(clean), state = "transit" }
	table.insert(p.orders, 1, o)
	while #p.orders > 20 do table.remove(p.orders) end
	return true, nil, o
end
-- the server calls this regularly: orders whose time is up become a box outside the garage door
function Economy.tick(p, now)
	local arrived = {}
	for _, o in ipairs(p.orders) do
		if o.state == "transit" and now >= o.eta then
			o.state = "arrived"
			for _, l in ipairs(o.lines) do
				local pr = Catalog.BY_SKU[l.sku]
				for _ = 1, l.q do newItem(p, l.sku, pr.kind == "tool" and "tool" or ("box:" .. o.id), "shop") end
			end
			table.insert(arrived, o)
		end
	end
	return arrived
end
-- open the box: the parts are laid out on the floor next to it
function Economy.openBox(p, oid)
	local o
	for _, x in ipairs(p.orders) do if x.id == oid then o = x end end
	if not o or o.state ~= "arrived" then return false, "Ingen låda att öppna" end
	o.state = "opened"
	for _, it in pairs(p.items) do if it.loc == "box:" .. oid then it.loc = "floor" end end
	return true
end

-- ---------- porting and paint ----------
function Economy.applyPort(p, u, res)
	local it = p.items[u]
	if not it or it.loc ~= "portbench" then return false, "Cylindern ligger inte på portningsbänken" end
	if not hasTool(p, "grinder") then return false, "Du behöver en slipmaskin" end
	if it.port then return false, "Cylindern är redan portad" end
	local q, deg = num(res.q, 0, 0, 1), num(res.deg, 0, 0, 4)
	it.port = { q = q, deg = math.floor(deg * 10 + 0.5) / 10, label = tostring(res.label or "") }
	p.stats.ported = p.stats.ported + 1
	return true
end
function Economy.applyPaint(p, u, col, fin, q, now)
	local it = p.items[u]
	if not it or it.loc ~= "booth" then return false, "Kåpan ligger inte i lackboxen" end
	if not hasTool(p, "spray") then return false, "Du behöver en sprutpistol" end
	local pr = Catalog.BY_SKU[it.s]
	if Panels.LOOK[pr.val.look] and Panels.LOOK[pr.val.look].fixed then return false, "Den här kåpan kan inte lackeras" end
	if not Paint.validHex(col) or not Paint.FINISH[fin] then return false, "Ogiltig färg" end
	local cost = 40 + (fin == "pearl" and 60 or fin == "chrome" and 120 or fin == "metal" and 30 or 0)
	if not Economy.spend(p, cost, "Lack, " .. Paint.FINISH[fin], now) then return false, "Du har inte råd med lacken" end
	it.paint = { col = col, fin = fin, q = num(q, 0, 0, 1) }
	it.dry = (now or 0) + Config.PAINT_DRY
	p.stats.painted = p.stats.painted + 1
	return true
end
function Economy.dryTick(p, now) for _, it in pairs(p.items) do if it.dry and now >= it.dry then it.dry = nil end end end

-- designs: the paint of all fitted panels under a name, can be put back later
function Economy.saveDesign(p, id, name)
	name = tostring(name or ""):sub(1, 30)
	if name == "" then return false, "Ge designen ett namn" end
	local d = { moped = id, panels = {} }
	for sock, u in pairs(p.mopeds[id].ch) do
		local it = p.items[u]
		if it and it.paint then d.panels[sock] = { col = it.paint.col, fin = it.paint.fin } end
	end
	p.designs[name] = d
	local n = 0
	for _ in pairs(p.designs) do n = n + 1 end
	if n > 12 then p.designs[name] = nil; return false, "Högst 12 designer" end
	return true
end
function Economy.applyDesign(p, name)
	local d = p.designs[name]
	if not d or not p.mopeds[d.moped] then return false, "Okänd design" end
	for sock, pt in pairs(d.panels) do
		local u = p.mopeds[d.moped].ch[sock]
		local it = u and p.items[u]
		if it and it.paint then it.paint.col, it.paint.fin = pt.col, pt.fin end
	end
	return true
end

-- ---------- buy/sell ----------
function Economy.sellPrice(p, u)
	local it = p.items[u]
	local pr = it and Catalog.BY_SKU[it.s]
	if not pr or pr.kind == "tool" then return 0 end
	return math.floor(pr.price * (it.used and 0.5 or 0.7) + 0.5)
end
function Economy.sell(p, u, now)
	local it = p.items[u]
	if not it then return false, "Okänd del" end
	if not FREE[it.loc] then return false, "Delen sitter monterad" end
	local v = Economy.sellPrice(p, u)
	if v <= 0 then return false, "Verktyg går inte att sälja" end
	local name = Catalog.BY_SKU[it.s].name
	p.items[u] = nil
	Economy.book(p, v, "Sålde " .. name, now)
	return true
end
function Economy.buyMoped(p, id, now)
	local m = Config.BY_ID[id]
	if not m then return false, "Okänd moped" end
	if p.mopeds[id] and p.mopeds[id].own then return false, "Du äger redan mopeden" end
	if not Economy.spend(p, m.price, "Köpte " .. m.n, now) then return false, "Du har inte råd" end
	Economy.buildOEM(p, id)
	return true
end
function Economy.sellValue(p, id)
	local mp = p.mopeds[id]
	local v = 0
	for _, t in ipairs({ mp.eng, mp.ch }) do for _, u in pairs(t) do local pr = p.items[u] and Catalog.BY_SKU[p.items[u].s]; if pr then v = v + pr.price * 0.45 end end end
	return math.floor(v * (1 - 0.5 * (mp.dmg or 0)) + 0.5)
end
function Economy.sellMoped(p, id, now)
	local mp = p.mopeds[id]
	if not mp or not mp.own then return false, "Du äger inte mopeden" end
	local owned = 0
	for _, m in pairs(p.mopeds) do if m.own then owned = owned + 1 end end
	if owned < 2 then return false, "Du måste ha minst en moped" end
	if p.stand == id then return false, "Montera tillbaka motorn först" end
	local v = Economy.sellValue(p, id)
	for _, t in ipairs({ mp.eng, mp.ch }) do for _, u in pairs(t) do p.items[u] = nil end end
	p.mopeds[id] = nil
	if p.cur == id then for k, m in pairs(p.mopeds) do if m.own then p.cur = k; break end end end
	Economy.book(p, v, "Sålde " .. Config.BY_ID[id].n, now)
	return true
end
function Economy.repairCost(p, id) local d = p.mopeds[id].dmg or 0; if d >= 1 then return 1500 end return math.floor(100 + 900 * d + 0.5) end
function Economy.repair(p, id, emergency, now)
	local mp = p.mopeds[id]
	local d = mp and mp.dmg or 0
	if d <= 0 then return false, "Motorn är hel" end
	if emergency then
		if d <= 0.5 or p.money >= Economy.repairCost(p, id) then return false, "Nödlagning behövs inte" end
		mp.dmg = 0.5
	else
		if not Economy.spend(p, Economy.repairCost(p, id), "Reparation, " .. Config.BY_ID[id].n, now) then return false, "Du har inte råd" end
		mp.dmg = 0
	end
	p.rep = p.rep + 1
	return true
end
function Economy.setJet(p, id, jet) local mp = p.mopeds[id]; if not mp then return false end; mp.jet = math.floor(num(jet, mp.jet, 40, 160) + 0.5); return true end

-- ---------- riding rewards (same rules as before) ----------
function Economy.addDistance(p, meters, now)
	if meters <= 0 then return 0 end
	p.stats.dist = p.stats.dist + meters
	p.clean = p.clean + meters
	local got = 0
	local b = math.floor(p.stats.dist / E.distM)
	if b > p.paid then got = got + Economy.book(p, (b - p.paid) * E.distKr, "Körsträcka", now); p.paid = b end
	local c = math.floor(p.clean / E.cleanM)
	if c > p.cleanPaid then got = got + Economy.book(p, (c - p.cleanPaid) * E.cleanKr, "Ren körning 2 km", now); p.cleanPaid = c end
	return got
end
function Economy.dirty(p) p.clean = 0; p.cleanPaid = 0 end
function Economy.crash(p, why, now) p.stats.crash = p.stats.crash + 1; Economy.dirty(p); return Economy.fine(p, E.crashKr, "Vurpa: " .. tostring(why or ""), now) end
function Economy.wheelieValue(t, vAvg, sd, imp)
	local W = Config.WHEELIE
	if t < W.minT then return 0, 0 end
	local base = W.max * (1 - math.exp(-t / W.tau))
	local mult = math.min(1.5, math.max(0.5, vAvg * 3.6 / 30)) * (1 - math.min(0.5, sd / 0.15))
	local q = imp < 1 and 1 or imp < 2.5 and 0.7 or 0.4
	return math.floor(base * mult * q + 0.5), mult
end
function Economy.wheelie(p, t, vAvg, sd, imp, now, seenDist)
	local W = Config.WHEELIE
	t, vAvg, sd, imp = num(t, 0, 0, 120), num(vAvg, 0, 0, E.maxSpeed), num(sd, 0, 0, 3), num(imp, 0, 0, 50)
	if t < W.minT then return 0, "För kort" end
	if seenDist and seenDist < t * W.minV * 0.5 then return 0, "Servern såg inte att du rörde dig" end
	local r = Economy.wheelieValue(t, vAvg, sd, imp)
	p._wh = p._wh or {}
	local keep, used = {}, 0
	for _, x in ipairs(p._wh) do if now - x[1] < 60 then table.insert(keep, x); used = used + x[2] end end
	p._wh = keep
	r = math.min(r, math.max(0, W.rate - used))
	p.stats.wn = p.stats.wn + 1
	p.stats.best = math.max(p.stats.best, t)
	if r > 0 then table.insert(p._wh, { now, r }); Economy.book(p, r, string.format("Stegring %.1f s", t), now) end
	return r
end

-- ---------- load/save ----------
-- stored data is never trusted: unknown parts are removed, locations and sockets are rebuilt from the mopeds' maps
function Economy.load(raw)
	if type(raw) ~= "table" or raw.v ~= 2 then return Economy.new() end
	local p = Economy.new()
	p.items, p.mopeds, p.uid = {}, {}, math.floor(num(raw.uid, 0, 0, 1e9))
	p.money = math.floor(num(raw.money, E.start, 0, 1e9))
	if type(raw.items) == "table" then
		for u, it in pairs(raw.items) do
			if type(u) == "string" and type(it) == "table" and Catalog.BY_SKU[it.s] and type(it.loc) == "string" then
				local o = { s = it.s, loc = it.loc, used = it.used == true, src = tostring(it.src or "") }
				if type(it.port) == "table" then o.port = { q = num(it.port.q, 0, 0, 1), deg = num(it.port.deg, 0, 0, 4), label = tostring(it.port.label or "") } end
				if type(it.paint) == "table" and Paint.validHex(it.paint.col) and Paint.FINISH[it.paint.fin] then o.paint = { col = it.paint.col, fin = it.paint.fin, q = num(it.paint.q, 1, 0, 1) } end
				if Catalog.BY_SKU[it.s].kind == "panel" and not o.paint then o.paint = { col = "#bdbdbd", fin = "gloss", q = 1 } end
				p.items[u] = o
			end
		end
	end
	local anyOwn = false
	if type(raw.mopeds) == "table" then
		for _, m in ipairs(Config.MOPEDS) do
			local r = raw.mopeds[m.id]
			if type(r) == "table" and r.own == true then
				anyOwn = true
				local mp = { own = true, jet = math.floor(num(r.jet, m.d.jet, 40, 160)), dmg = num(r.dmg, 0, 0, 1), eng = {}, ch = {}, engAt = r.engAt == "stand" and "stand" or "moped" }
				p.mopeds[m.id] = mp
				local function take(src, dst, list, prefix)
					if type(src) ~= "table" then return end
					for _, s in ipairs(list) do
						local u = src[s.id]
						local it = type(u) == "string" and p.items[u]
						if it and Catalog.BY_SKU[it.s].kind == s.kind and (s.kind ~= "panel" or Catalog.BY_SKU[it.s].val.panel == s.panel) and Catalog.fits(Catalog.BY_SKU[it.s], m.id) then
							dst[s.id] = u; it.loc = prefix .. m.id; it.sock = s.id
						end
					end
				end
				take(r.eng, mp.eng, Assembly.engineSockets(m.id), "eng:")
				take(r.ch, mp.ch, Assembly.chassisSlots(m.id), "ch:")
				if mp.engAt == "moped" then mp.ch.engine = "engine" end
			end
		end
	end
	-- parts whose location points to a mount that no longer exists end up on the bench
	for u, it in pairs(p.items) do
		local kind, mid = it.loc:match("^(%a+):(.+)$")
		if kind == "eng" or kind == "ch" then
			local mp = p.mopeds[mid]
			local map = mp and (kind == "eng" and mp.eng or mp.ch)
			if not (map and it.sock and map[it.sock] == u) then it.loc, it.sock = "bench", nil end
		elseif kind ~= "box" and not (FREE[it.loc] or it.loc == "tool") then it.loc, it.sock = "bench", nil end
	end
	if not anyOwn then Economy.buildOEM(p, "jog") end
	if type(raw.stand) == "string" and p.mopeds[raw.stand] and p.mopeds[raw.stand].engAt == "stand" then p.stand = raw.stand end
	for id, mp in pairs(p.mopeds) do if mp.engAt == "stand" and p.stand ~= id then mp.engAt = "moped"; mp.ch.engine = "engine" end end
	if type(raw.cur) == "string" and p.mopeds[raw.cur] then p.cur = raw.cur else for k in pairs(p.mopeds) do p.cur = k; break end end
	if type(raw.orders) == "table" then
		for i = 1, math.min(20, #raw.orders) do
			local o = raw.orders[i]
			if type(o) == "table" and type(o.lines) == "table" and (o.state == "transit" or o.state == "arrived" or o.state == "opened") then
				local lines = {}
				for _, l in ipairs(o.lines) do if type(l) == "table" and Catalog.BY_SKU[l.sku] then table.insert(lines, { sku = l.sku, q = math.floor(num(l.q, 1, 1, 10)) }) end end
				table.insert(p.orders, { id = math.floor(num(o.id, 0, 0, 1e9)), lines = lines, total = num(o.total, 0, 0, 1e9), t0 = num(o.t0, 0, 0, 1e12), eta = num(o.eta, 0, 0, 1e12), state = o.state })
			end
		end
	end
	p.oid = math.floor(num(raw.oid, 0, 0, 1e9))
	if type(raw.designs) == "table" then
		for name, d in pairs(raw.designs) do
			if type(name) == "string" and type(d) == "table" and p.mopeds[d.moped] and type(d.panels) == "table" then
				local pans = {}
				for sock, pt in pairs(d.panels) do if type(pt) == "table" and Paint.validHex(pt.col) and Paint.FINISH[pt.fin] then pans[sock] = { col = pt.col, fin = pt.fin } end end
				p.designs[name:sub(1, 30)] = { moped = d.moped, panels = pans }
			end
		end
	end
	if type(raw.stats) == "table" then for k in pairs(p.stats) do p.stats[k] = num(raw.stats[k], 0, 0, 1e12) end end
	p.paid = math.floor(num(raw.paid, 0, 0, 1e12)); p.clean = num(raw.clean, 0, 0, 1e9); p.cleanPaid = math.floor(num(raw.cleanPaid, 0, 0, 1e9)); p.rep = math.floor(num(raw.rep, 0, 0, 1e9))
	if type(raw.ledger) == "table" then for i = 1, math.min(#raw.ledger, 40) do local l = raw.ledger[i]; if type(l) == "table" and type(l.x) == "string" and type(l.a) == "number" then table.insert(p.ledger, { a = l.a, x = l.x, t = num(l.t, 0, 0, 1e12) }) end end end
	-- the basic tools always exist
	if not hasTool(p, "basic") then newItem(p, "P-tool-basic", "tool", "start") end
	return p
end
function Economy.public(p)
	local o = {}
	for k, v in pairs(p) do if k:sub(1, 1) ~= "_" then o[k] = v end end
	return o
end
return Economy

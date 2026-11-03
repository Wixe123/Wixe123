-- Player profile and economy rules (server authoritative). Pure logic without Roblox services so it can be tested.
-- Every function that changes money goes through book(), and money can never go below 0.
local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.Catalog)
local Engine = require(script.Parent.Engine)
local Economy = {}
local E = Config.ECON

local function hex(c) return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
Economy.hex = hex
local function num(x, d, lo, hi) if type(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge then return d end return math.min(hi, math.max(lo, x)) end

local function defCfg(m)
	return { jet = m.d.jet, port = m.d.port, roller = m.d.roller, col = hex(m.d.col), seat = hex(m.d.seat), num = m.d.num, fin = "gloss" }
end

local function newItem(p, sku, src, paid)
	p.uid = p.uid + 1
	local u = "i" .. p.uid
	p.items[u] = { s = sku, used = false, src = src, paid = paid or 0 }
	return u
end

function Economy.equipOEM(p, id)
	local inst = {}
	for slot in pairs(Catalog.slotsOf(id)) do
		local sku = Catalog.OEM[id][slot]
		if sku then inst[slot] = newItem(p, sku, "oem", 0) end
	end
	p.inst[id] = inst
end

function Economy.new()
	local p = { v = 1, money = E.start, own = {}, cur = "jog", cfgs = {}, items = {}, uid = 0, inst = {}, dmg = {},
		stats = { dist = 0, top = 0, wn = 0, best = 0, crash = 0, earned = 0 }, paid = 0, clean = 0, cleanPaid = 0, rep = 0, ledger = {} }
	for _, m in ipairs(Config.MOPEDS) do
		p.own[m.id] = true
		p.cfgs[m.id] = defCfg(m)
		p.dmg[m.id] = 0
		Economy.equipOEM(p, m.id)
	end
	return p
end

-- sanitize a stored profile (DataStore data is never trusted blindly)
function Economy.load(raw)
	local p = Economy.new()
	if type(raw) ~= "table" then return p end
	p.money = math.floor(num(raw.money, E.start, 0, 1e9))
	if type(raw.items) == "table" then
		p.items, p.uid = {}, math.floor(num(raw.uid, 0, 0, 1e9))
		for u, it in pairs(raw.items) do
			if type(u) == "string" and type(it) == "table" and Catalog.BY_SKU[it.s] then p.items[u] = { s = it.s, used = it.used == true, src = tostring(it.src or ""), paid = num(it.paid, 0, 0, 1e7) } end
		end
	end
	for _, m in ipairs(Config.MOPEDS) do
		local id = m.id
		if type(raw.own) == "table" then p.own[id] = raw.own[id] == true end
		local c = type(raw.cfgs) == "table" and raw.cfgs[id]
		if type(c) == "table" then
			local d = p.cfgs[id]
			d.jet = num(c.jet, d.jet, 40, 160); d.port = num(c.port, d.port, -4, 8); d.roller = num(c.roller, d.roller, 4, 14)
			if type(c.col) == "string" and c.col:match("^#%x%x%x%x%x%x$") then d.col = c.col end
			if type(c.seat) == "string" and c.seat:match("^#%x%x%x%x%x%x$") then d.seat = c.seat end
			if type(c.num) == "string" then d.num = c.num:gsub("%D", ""):sub(1, 2) end
			if c.fin == "gloss" or c.fin == "matt" or c.fin == "metal" then d.fin = c.fin end
		end
		p.dmg[id] = num(type(raw.dmg) == "table" and raw.dmg[id], 0, 0, 1)
		if type(raw.items) == "table" and type(raw.inst) == "table" and type(raw.inst[id]) == "table" then
			local inst, used = {}, {}
			for slot in pairs(Catalog.slotsOf(id)) do
				local u = raw.inst[id][slot]
				local it = type(u) == "string" and p.items[u]
				if it and not used[u] and Catalog.fits(Catalog.BY_SKU[it.s], id) and Catalog.BY_SKU[it.s].slot == slot then inst[slot] = u; used[u] = true
				elseif not Catalog.REMOVABLE[slot] and Catalog.OEM[id][slot] then inst[slot] = newItem(p, Catalog.OEM[id][slot], "oem", 0) end
			end
			p.inst[id] = inst
		elseif type(raw.items) == "table" then
			Economy.equipOEM(p, id) -- the items were replaced by the stored ones, so give this moped fresh original parts
		end
	end
	local anyOwn = false
	for _, m in ipairs(Config.MOPEDS) do if p.own[m.id] then anyOwn = true end end
	if not anyOwn then p.own.jog = true end
	if type(raw.cur) == "string" and Config.BY_ID[raw.cur] then p.cur = raw.cur end
	if type(raw.stats) == "table" then for k in pairs(p.stats) do p.stats[k] = num(raw.stats[k], 0, 0, 1e12) end end
	p.rep = math.floor(num(raw.rep, 0, 0, 1e9))
	p.paid = math.floor(num(raw.paid, 0, 0, 1e12)); p.clean = num(raw.clean, 0, 0, 1e9); p.cleanPaid = math.floor(num(raw.cleanPaid, 0, 0, 1e9))
	if type(raw.ledger) == "table" then for i = 1, math.min(#raw.ledger, 40) do local l = raw.ledger[i]; if type(l) == "table" and type(l.x) == "string" and type(l.a) == "number" then table.insert(p.ledger, { a = l.a, x = l.x, t = num(l.t, 0, 0, 1e12) }) end end end
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

function Economy.installedOn(p, u)
	for id, inst in pairs(p.inst) do for slot, v in pairs(inst) do if v == u then return id, slot end end end
	return nil
end
function Economy.ecfg(p, id)
	local c = p.cfgs[id]
	return Catalog.ecfg(id, { jet = c.jet, port = c.port, roller = c.roller }, p.inst[id], p.items)
end
function Economy.engine(p, id)
	local P = Engine.calc(Economy.ecfg(p, id))
	P.cond = 1 - 0.4 * (p.dmg[id] or 0)
	P.hp = Engine.peakHp(P)
	return P
end

function Economy.canInstall(p, u, id)
	local it = p.items[u]
	local pr = it and Catalog.BY_SKU[it.s]
	if not pr then return "Okänd del" end
	if not p.own[id] then return "Du äger inte mopeden" end
	if not Catalog.fits(pr, id) then return "Passar inte " .. Config.BY_ID[id].n end
	if Economy.installedOn(p, u) then return "Redan monterad" end
	local cur = p.inst[id][pr.slot]
	if cur and p.items[cur] and p.items[cur].s == it.s then return "Samma del sitter redan på mopeden" end
	return nil
end
function Economy.install(p, u, id)
	local why = Economy.canInstall(p, u, id)
	if why then return false, why end
	local slot = Catalog.BY_SKU[p.items[u].s].slot
	local old = p.inst[id][slot]
	p.inst[id][slot] = u
	p.items[u].used = true
	if old and p.items[old] then p.items[old].used = true end
	return true
end
function Economy.uninstall(p, id, slot)
	if not Catalog.REMOVABLE[slot] then return false, "Den här delen byts genom att montera en annan" end
	if not p.inst[id] or not p.inst[id][slot] then return false, "Ingen del monterad" end
	p.inst[id][slot] = nil
	return true
end

-- buy: all or nothing. qty 1..10. installOn = moped id to install on directly (optional)
function Economy.buy(p, sku, qty, installOn, now)
	local pr = Catalog.BY_SKU[sku]
	qty = math.floor(num(qty, 1, 1, 10))
	if not pr then return false, "Produkten finns inte" end
	local tot = pr.price * qty
	if tot > p.money then return false, "Du har inte råd (" .. tot .. " kr, du har " .. p.money .. " kr)" end
	Economy.spend(p, tot, "Köp: " .. qty .. "× " .. pr.name, now)
	local us = {}
	for _ = 1, qty do table.insert(us, newItem(p, sku, "demo", pr.price)) end
	local installed = false
	if installOn and Config.BY_ID[installOn] and Catalog.fits(pr, installOn) then installed = Economy.install(p, us[1], installOn) end
	return true, nil, us, installed
end
function Economy.sellPrice(p, u)
	local it = p.items[u]
	local pr = it and Catalog.BY_SKU[it.s]
	if not pr then return 0 end
	return math.floor(pr.price * (it.used and 0.5 or 0.7) + 0.5)
end
function Economy.sell(p, u, now)
	if not p.items[u] then return false, "Okänd del" end
	if Economy.installedOn(p, u) then return false, "Delen är monterad" end
	local v = Economy.sellPrice(p, u)
	local name = Catalog.BY_SKU[p.items[u].s].name
	p.items[u] = nil
	Economy.book(p, v, "Sålde " .. name, now)
	return true
end

function Economy.tune(p, id, key, value)
	local c = p.cfgs[id]
	if not c or not p.own[id] then return false, "Du äger inte mopeden" end
	if key == "jet" or key == "roller" then
		local e = Economy.ecfg(p, id)
		local lo, hi = key == "jet" and e.jlo or e.rlo, key == "jet" and e.jhi or e.rhi
		c[key] = num(value, c[key], lo, hi)
		if key == "roller" then c[key] = math.floor(c[key] * 2 + 0.5) / 2 else c[key] = math.floor(c[key] + 0.5) end
	elseif key == "port" then c.port = math.floor(num(value, c.port, -4, 8) * 2 + 0.5) / 2
	elseif key == "fin" then if value == "gloss" or value == "matt" or value == "metal" then c.fin = value else return false, "Okänd finish" end
	elseif key == "col" or key == "seat" then if type(value) == "string" and value:match("^#%x%x%x%x%x%x$") then c[key] = value else return false, "Ogiltig färg" end
	elseif key == "num" then c.num = tostring(value):gsub("%D", ""):sub(1, 2)
	else return false, "Okänd inställning" end
	return true
end

function Economy.repairCost(p, id) local d = p.dmg[id] or 0; if d >= 1 then return 1500 end return math.floor(100 + 900 * d + 0.5) end
function Economy.repair(p, id, emergency, now)
	local d = p.dmg[id] or 0
	if d <= 0 then return false, "Motorn är hel" end
	if emergency then
		if d <= 0.5 then return false, "Nödlagning behövs inte" end
		if p.money >= Economy.repairCost(p, id) then return false, "Du har råd med en riktig reparation" end
		p.dmg[id] = 0.5
		p.rep = (p.rep or 0) + 1
		return true
	end
	if not Economy.spend(p, Economy.repairCost(p, id), "Reparation, " .. Config.BY_ID[id].n, now) then return false, "Du har inte råd" end
	p.dmg[id] = 0
	p.rep = (p.rep or 0) + 1
	return true
end

function Economy.sellValue(p, id) return math.floor(Config.BY_ID[id].price * E.mopSell * (1 - 0.5 * (p.dmg[id] or 0)) + 0.5) end
function Economy.sellMoped(p, id, now)
	if not p.own[id] then return false, "Du äger inte mopeden" end
	local owned = 0
	for _, m in ipairs(Config.MOPEDS) do if p.own[m.id] then owned = owned + 1 end end
	if owned < 2 then return false, "Du måste ha minst en moped" end
	local v = Economy.sellValue(p, id)
	for _, u in pairs(p.inst[id] or {}) do if p.items[u] and p.items[u].src == "oem" then p.items[u] = nil end end -- OEM parts go with the moped, aftermarket parts go to storage
	p.inst[id] = {}
	p.own[id] = false
	p.dmg[id] = 0
	p.cfgs[id] = defCfg(Config.BY_ID[id])
	Economy.book(p, v, "Sålde " .. Config.BY_ID[id].n, now)
	if p.cur == id then for _, m in ipairs(Config.MOPEDS) do if p.own[m.id] then p.cur = m.id; break end end end
	return true
end
function Economy.buyMoped(p, id, now)
	local m = Config.BY_ID[id]
	if not m then return false, "Okänd moped" end
	if p.own[id] then return false, "Du äger redan mopeden" end
	if not Economy.spend(p, m.price, "Köpte " .. m.n, now) then return false, "Du har inte råd" end
	p.own[id] = true
	p.cfgs[id] = defCfg(m)
	p.dmg[id] = 0
	Economy.equipOEM(p, id)
	return true
end

-- riding: the server measures the distance itself; money is paid per completed 100 m block, never twice
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
function Economy.crash(p, why, now)
	p.stats.crash = p.stats.crash + 1
	Economy.dirty(p)
	return Economy.fine(p, E.crashKr, "Vurpa: " .. tostring(why or ""), now)
end

-- wheelie: the server calculates the reward itself from the reported values and checks them against what it saw
-- t = valid time (s), vAvg = average speed (m/s), sd = pitch spread (rad), imp = landing speed (rad/s)
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

-- data sent to the client (without transient fields)
function Economy.public(p)
	local o = {}
	for k, v in pairs(p) do if k:sub(1, 1) ~= "_" then o[k] = v end end
	return o
end

return Economy

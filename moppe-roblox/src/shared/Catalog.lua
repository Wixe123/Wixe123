-- Parts catalogue: demo products with made-up manufacturers and prices (game money). Same as the web version.
-- One source of truth: the player's items + installed[moped][slot]; the engine config is derived with ecfg().
local Config = require(script.Parent.Config)
local Catalog = {}

Catalog.SLOTS = {
	kit = { "Cylinder", "Cylindrar" }, exh = { "Avgassystem", "Avgassystem" }, carb = { "Förgasare", "Förgasare" },
	jets = { "Munstyckessats", "Munstycken" }, man = { "Insug", "Insug" }, filt = { "Luftfilter", "Luftfilter" },
	ign = { "Tändning", "Tändning" }, cool = { "Kylning", "Kylning" }, var = { "Variator", "Variatorer" },
	roll = { "Rullsats", "Rullvikter" }, clutch = { "Kopplingsfjädrar", "Kopplingsfjädrar" }, contra = { "Kontrafjäder", "Kontrafjädrar" },
	belt = { "Rem", "Remmar" }, fender = { "Framskärm", "Kåpor" }, tank = { "Tankkåpa", "Kåpor" }, mir = { "Speglar", "Speglar" },
	bars = { "Styre", "Styren" }, rims = { "Fälgar", "Hjul & fälgar" }, glass = { "Lyktglas", "Kosmetik" },
}
Catalog.SLOT_ORDER = { "kit", "exh", "carb", "jets", "man", "filt", "ign", "cool", "var", "roll", "clutch", "contra", "belt", "fender", "tank", "mir", "bars", "rims", "glass" }
Catalog.REMOVABLE = { fender = true, tank = true, mir = true }
Catalog.ENGINE = { kit = true, exh = true, carb = true, jets = true, man = true, filt = true, ign = true, cool = true, var = true, roll = true, clutch = true, contra = true, belt = true }
Catalog.GROUPS = {
	{ "Motor", { "Cylindrar", "Avgassystem", "Förgasare", "Munstycken", "Insug", "Luftfilter", "Tändning", "Kylning" } },
	{ "Kraftöverföring", { "Variatorer", "Rullvikter", "Kopplingsfjädrar", "Kontrafjädrar", "Remmar" } },
	{ "Utseende", { "Kåpor", "Speglar", "Styren", "Hjul & fälgar", "Kosmetik" } },
}
Catalog.BASE = { kit = 0, exh = 0, carb = 1, jlo = 50, jhi = 110, maxd = 19, fcap = 1, icap = 11000, cf = 1, rmin = 0.85, rlo = 7, rhi = 12, slip = 7500, cdt = 0, blim = 7,
	fender = "none", tank = "none", mir = "none", bars = "std", rims = "std", glass = "clear" }

local PR, BY, OEM = {}, {}, { jog = {}, rok = {}, dt = {} }
Catalog.PR, Catalog.BY_SKU, Catalog.OEM = PR, BY, OEM
local ALL, CVT = { "jog", "rok", "dt" }, { "jog", "rok" }

local function has(t, x) for _, v in ipairs(t) do if v == x then return true end end return false end
Catalog.has = has

local function add(slot, v, name, man, price, val, fits, desc, oemFor, split)
	local groups = {}
	if split then for _, f in ipairs(fits) do table.insert(groups, { f }) end else groups = { fits } end
	for _, fs in ipairs(groups) do
		local sku = "D-" .. slot .. "-" .. v .. (split and ("-" .. fs[1]) or "")
		local p = { sku = sku, name = name .. (split and (" – " .. Config.BY_ID[fs[1]].n) or ""), man = man, cat = Catalog.SLOTS[slot][2], slot = slot,
			price = price, val = val, fits = fs, desc = desc }
		table.insert(PR, p)
		BY[sku] = p
		for _, f in ipairs(fs) do if oemFor and has(oemFor, f) then OEM[f][slot] = sku end end
	end
end
local function fmt(n) -- 11000 -> "11 000"
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""))
end

for i, k in ipairs(Config.KITS) do
	add("kit", i - 1, "Cylindersats " .. k.n, ({ "Originaldel", "Fartek", "Nordtrim" })[i], ({ 1200, 1900, 2900 })[i], { kit = i - 1 }, ALL,
		k.cc .. " cc, avgasport " .. k.ex .. "° grundtiming. Större slagvolym och högre effektvarv.", i == 1 and ALL or {}, true)
end
for i, e in ipairs(Config.EXH) do
	add("exh", i - 1, "Avgassystem " .. e.n, ({ "Originaldel", "Bruksmek", "Fartek", "Nordtrim", "Fartek" })[i], ({ 900, 1400, 1900, 2400, 3200 })[i], { exh = i - 1 }, ALL,
		"Inställt för ca " .. e.t .. " varv. Flyttar effekttoppen.", i == 1 and ALL or {}, true)
end
for i, d in ipairs(Config.CARB) do
	add("carb", i - 1, "Förgasare " .. d .. " mm", i > 3 and "Fartek" or "Vippa", ({ 500, 700, 900, 1300, 1700 })[i], { carb = i - 1 }, ALL,
		"Mer luft vid höga varv. Över 19 mm behövs större insug.", ({ { "jog" }, { "rok", "dt" } })[i])
end
for i, j in ipairs({ { 40, 70, "liten" }, { 50, 110, "standard" }, { 90, 160, "stor" } }) do
	add("jets", i - 1, "Munstyckessats " .. j[3] .. " (" .. j[1] .. "–" .. j[2] .. ")", "Vippa", 150, { jlo = j[1], jhi = j[2] }, ALL,
		"Låser upp huvudmunstycken " .. j[1] .. "–" .. j[2] .. ".", i == 2 and ALL or {})
end
add("man", 0, "Insug original (upp till 19 mm)", "Originaldel", 200, { maxd = 19 }, ALL, "Förgasare större än 19 mm stryps.", ALL, true)
add("man", 1, "Insug stort (upp till 24 mm)", "Nordtrim", 450, { maxd = 24 }, ALL, "Förgasare upp till 24 mm får fullt flöde.", {}, true)
add("filt", 0, "Luftfilter original", "Originaldel", 150, { fcap = 1 }, ALL, "Originalfilter.", ALL)
add("filt", 1, "Luftfilter sport", "Vippa", 350, { fcap = 1.12 }, ALL, "12 % mer luft, blandningen blir magrare.", {})
add("ign", 0, "Tändning original (spärr 11 000)", "Originaldel", 600, { icap = 11000 }, ALL, "Motorn kan inte varva över 11 000 rpm.", ALL, true)
add("ign", 1, "Tändning sport (spärr 14 000)", "Fartek", 1300, { icap = 14000 }, ALL, "Motorn kan varva till 14 000 rpm.", {}, true)
add("cool", 0, "Topplock original", "Originaldel", 500, { cf = 1 }, { "jog", "dt" }, "Originaltopplock.", { "jog", "dt" }, true)
add("cool", 1, "Topplock storflänsat", "Kylstad", 900, { cf = 1.25 }, { "jog", "dt" }, "25 % bättre luftkylning.", {}, true)
add("cool", 2, "Kylare original", "Originaldel", 700, { cf = 1 }, { "rok" }, "Originalkylare.", { "rok" })
add("cool", 3, "Kylare stor", "Kylstad", 1300, { cf = 1.25 }, { "rok" }, "25 % bättre kylning av kylvätskan.", {})
for i, r in ipairs({ { 0.85, "original", 600 }, { 0.78, "sport", 1100 }, { 0.72, "race", 1600 } }) do
	add("var", i - 1, "Variator " .. r[2], ({ "Originaldel", "Nordtrim", "Fartek" })[i], r[3], { rmin = r[1] }, CVT, "Högsta utväxling " .. r[1] .. ":1, högre toppfart.", i == 1 and CVT or {}, true)
end
for i, r in ipairs({ { 4, 8, "lätt" }, { 7, 12, "standard" }, { 11, 14, "tung" } }) do
	add("roll", i - 1, "Rullsats " .. r[3] .. " (" .. r[1] .. "–" .. r[2] .. " g)", "Vippa", 120, { rlo = r[1], rhi = r[2] }, CVT, "Låser upp rullvikter " .. r[1] .. "–" .. r[2] .. " g.", i == 2 and CVT or {}, true)
end
for i, r in ipairs({ { 7500, "original", 150 }, { 9000, "sport", 220 }, { 10500, "race", 260 } }) do
	add("clutch", i - 1, "Kopplingsfjädrar " .. r[2], i == 1 and "Originaldel" or "Fartek", r[3], { slip = r[1] }, CVT, "Kopplingen slirar upp till ca " .. fmt(r[1]) .. " rpm från stillastående.", i == 1 and CVT or {}, true)
end
for i, r in ipairs({ { 0, "original", 150 }, { 400, "+15 %", 200 }, { 800, "+30 %", 250 } }) do
	add("contra", i - 1, "Kontrafjäder " .. r[2], i == 1 and "Originaldel" or "Nordtrim", r[3], { cdt = r[1] }, CVT, "Variatorn håller " .. (r[1] > 0 and (r[1] .. " rpm högre") or "originalvarvet") .. ".", i == 1 and CVT or {}, true)
end
add("belt", 0, "Rem original", "Originaldel", 300, { blim = 7 }, CVT, "Slirar över ca 7 hk.", CVT, true)
add("belt", 1, "Rem förstärkt", "Bruksmek", 550, { blim = 15 }, CVT, "Slirar över ca 15 hk.", {}, true)
for i, r in ipairs({ { "paint", "original (lackad)", 400 }, { "carbon", "karbonlook", 650 }, { "chrome", "krom", 750 } }) do
	add("fender", i - 1, "Framskärm " .. r[2], i == 1 and "Originaldel" or "Bruksmek", r[3], { fender = r[1] }, { "jog", "dt" }, "Syns på mopeden.", i == 1 and { "jog", "dt" } or {})
end
for i, r in ipairs({ { "paint", "original (lackad)", 500 }, { "carbon", "karbonlook", 800 } }) do
	add("tank", i - 1, "Tankkåpa " .. r[2], i == 1 and "Originaldel" or "Bruksmek", r[3], { tank = r[1] }, { "dt" }, "Syns på mopeden.", i == 1 and { "dt" } or {})
end
for i, r in ipairs({ { "std", "original", 250 }, { "round", "runda krom", 380 } }) do
	add("mir", i - 1, "Speglar " .. r[2], i == 1 and "Originaldel" or "Vippa", r[3], { mir = r[1] }, { "jog", "dt" }, "Syns på mopeden.", i == 1 and { "jog" } or {})
end
for i, r in ipairs({ { "std", "original", 300 }, { "high", "crossstyre högt", 550 } }) do
	add("bars", i - 1, "Styre " .. r[2], i == 1 and "Originaldel" or "Nordtrim", r[3], { bars = r[1] }, { "dt" }, "Syns på mopeden.", i == 1 and { "dt" } or {})
end
add("rims", 0, "Fälgar original", "Originaldel", 900, { rims = "std" }, ALL, "Originalfälgar.", ALL, true)
add("rims", 1, "Fälgar polerade", "Bruksmek", 1400, { rims = "pol" }, ALL, "Spegelblank metall.", {}, true)
add("rims", 2, "Fälgar guld", "Nordtrim", 1300, { rims = "gold" }, ALL, "Guldfärgade fälgar.", {}, true)
for i, r in ipairs({ { "clear", "klart (original)", 200 }, { "tint", "tonat", 300 } }) do
	add("glass", i - 1, "Lyktglas " .. r[2], i == 1 and "Originaldel" or "Vippa", r[3], { glass = r[1] }, ALL, "Syns på mopeden.", i == 1 and ALL or {})
end

function Catalog.slotsOf(id)
	local o = {}
	for _, p in ipairs(PR) do if has(p.fits, id) then o[p.slot] = true end end
	return o
end
function Catalog.fits(p, id) return p ~= nil and has(p.fits, id) end

-- effective config for a moped: base -> tuning values -> installed parts (or OEM if a required slot is empty)
-- data: { cfg = {jet,port,roller,...}, inst = {slot = itemId}, items = {itemId = {s = sku}} }
function Catalog.ecfg(id, cfg, inst, items)
	local c = {}
	for k, v in pairs(Catalog.BASE) do c[k] = v end
	for k, v in pairs(cfg or {}) do c[k] = v end
	for slot in pairs(Catalog.slotsOf(id)) do
		local u = inst and inst[slot]
		local it = u and items and items[u]
		local p = it and BY[it.s]
		if p then
			for k, v in pairs(p.val) do c[k] = v end
		elseif not Catalog.REMOVABLE[slot] and OEM[id][slot] then
			for k, v in pairs(BY[OEM[id][slot]].val) do c[k] = v end
		end
	end
	c.jet = math.min(c.jhi, math.max(c.jlo, c.jet))
	c.roller = math.min(c.rhi, math.max(c.rlo, c.roller))
	return c
end

Catalog.fmt = fmt
return Catalog

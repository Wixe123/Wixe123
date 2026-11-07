-- Parts catalogue for Moppelagret.se (the in-game web shop). Made-up brands and game prices – no real
-- trademarks or logos. Each product has a kind that decides where it fits (engine socket or moped slot).
local Config = require(script.Parent.Config)
local Catalog = {}

Catalog.CATS = { "Cylindrar", "Vevpartier", "Motordelar", "Förgasare", "Insug", "Luftfilter", "Avgassystem", "Variatorer", "Kopplingar", "Tändsystem", "Chassi", "Kåpor", "Styling", "Verktyg" }
Catalog.BRANDS = { "Fartek", "Nordtrim", "Vippa", "Bruksmek", "Kylstad", "Snabbo", "Origo" } -- Origo = original part

-- kinds: what sort of part it is and in which category it is sold
Catalog.KIND = {
	case = { "Vevhus", "Motordelar" }, crank = { "Vevaxel", "Vevpartier" }, bearing = { "Vevlager", "Motordelar" }, seal = { "Packbox", "Motordelar" },
	needle = { "Nållager", "Motordelar" }, piston = { "Kolv", "Cylindrar" }, rings = { "Kolvringar", "Cylindrar" }, pin = { "Kolvbult", "Cylindrar" },
	gasket = { "Cylinderfotspackning", "Motordelar" }, cyl = { "Cylinder", "Cylindrar" }, head = { "Topplock", "Cylindrar" }, plug = { "Tändstift", "Tändsystem" },
	reed = { "Reedventil", "Insug" }, intake = { "Insug", "Insug" }, carb = { "Förgasare", "Förgasare" }, filter = { "Luftfilter", "Luftfilter" }, hose = { "Bränsleslang", "Insug" },
	stator = { "Stator", "Tändsystem" }, flywheel = { "Svänghjul", "Tändsystem" }, fan = { "Fläkt", "Motordelar" }, coil = { "Tändspole", "Tändsystem" }, cdi = { "CDI", "Tändsystem" }, cable = { "Tändkabel", "Tändsystem" },
	weights = { "Variatorvikter", "Variatorer" }, var = { "Variator", "Variatorer" }, contra = { "Kontrafjäder", "Kopplingar" }, pulley = { "Bakre remskiva", "Kopplingar" },
	belt = { "Rem", "Variatorer" }, clutch = { "Koppling", "Kopplingar" }, bell = { "Kopplingsklocka", "Kopplingar" },
	gearbox = { "Växellåda", "Motordelar" }, plates = { "Kopplingslameller", "Kopplingar" }, sprocket = { "Drev", "Kopplingar" },
	frame = { "Ram", "Chassi" }, fork = { "Framgaffel", "Chassi" }, shock = { "Bakdämpare", "Chassi" }, wheel = { "Hjul", "Chassi" }, brake = { "Broms", "Chassi" },
	bars = { "Styre", "Chassi" }, seat = { "Sadel", "Chassi" }, tank = { "Tank", "Chassi" }, exh = { "Avgassystem", "Avgassystem" }, radiator = { "Kylare", "Chassi" },
	panel = { "Kåpa", "Kåpor" }, tool = { "Verktyg", "Verktyg" },
}

local PR, BY, OEM = {}, {}, { jog = {}, rok = {}, dt = {} }
Catalog.PR, Catalog.BY_SKU = PR, BY
local ALL, CVT = { "jog", "rok", "dt" }, { "jog", "rok" }
local function has(t, x) for _, v in ipairs(t) do if v == x then return true end end return false end
Catalog.has = has
local function fmt(n)
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""))
end
Catalog.fmt = fmt

-- stock is fixed per product (shown in the shop): "I lager", "Få kvar" or "Beställningsvara" (+2 min delivery)
local STOCK = { "I lager", "I lager", "I lager", "Få kvar", "Beställningsvara" }
local n = 0
local function add(kind, v, name, man, price, val, fits, desc, oemFor, extra)
	n = n + 1
	local sku = "P-" .. kind .. "-" .. v
	local p = { sku = sku, kind = kind, name = name, man = man, cat = Catalog.KIND[kind][2], price = price, val = val or {}, fits = fits, desc = desc,
		stock = STOCK[(n * 7) % #STOCK + 1] }
	for k, x in pairs(extra or {}) do p[k] = x end
	table.insert(PR, p)
	BY[sku] = p
	for _, f in ipairs(oemFor or {}) do OEM[f][kind] = OEM[f][kind] or sku end
	return p
end

-- ---------- engine ----------
add("case", "std", "Vevhus original", "Origo", 1400, {}, ALL, "Motorns grund. Allt annat monteras på vevhuset.", ALL)
add("crank", "std", "Vevaxel original", "Origo", 900, { crankf = 1 }, ALL, "Originalvevaxel med vevstake.", ALL)
add("crank", "race", "Vevaxel race (långslag)", "Fartek", 1650, { crankf = 1.05 }, ALL, "Tål högre varv. +5 % vridmoment i spelet.", {})
add("bearing", "std", "Vevlager 6204 (par)", "Origo", 180, {}, ALL, "Två kullager till vevaxeln.", ALL)
add("bearing", "c3", "Vevlager C3 (par)", "Nordtrim", 260, {}, ALL, "Lager med större glapp för varma motorer.", {})
add("seal", "std", "Packboxar (par)", "Origo", 90, {}, ALL, "Tätar vevhuset mot vevaxeln.", ALL)
add("needle", "std", "Nållager vevstake", "Origo", 110, {}, ALL, "Lagret i vevstakens lilla ände.", ALL)
add("gasket", "std", "Cylinderfotspackning", "Origo", 40, {}, ALL, "Tätar mellan cylinder och vevhus.", ALL)
add("plug", "std", "Tändstift standard", "Origo", 60, {}, ALL, "Normalt värmetal.", ALL)
add("plug", "cold", "Tändstift kallt", "Snabbo", 90, {}, ALL, "Kallare stift för trimmade motorer.", {})
-- cylinder kits: cylinder + piston + rings + pin in the same set
for i, k in ipairs(Config.KITS) do
	local v = ({ "std", "sport", "race" })[i]
	local man = ({ "Origo", "Fartek", "Nordtrim" })[i]
	local price = ({ 1200, 1900, 2900 })[i]
	add("cyl", v, "Cylinder " .. k.n, man, price, { kit = i - 1 }, ALL, k.cc .. " cc. Kan portas på portningsbänken.", i == 1 and ALL or {}, { hasPort = true })
	add("piston", v, "Kolv " .. k.cc .. " cc" .. (i > 1 and " (" .. v .. ")" or ""), man, math.floor(price * 0.2), { bore = k.cc }, ALL, "Måste passa cylindern.", i == 1 and ALL or {})
	add("rings", v, "Kolvringar " .. k.cc .. " cc", man, 120, { bore = k.cc }, ALL, "Två ringar till kolven.", i == 1 and ALL or {})
end
add("pin", "std", "Kolvbult 12 mm", "Origo", 60, {}, ALL, "Håller kolven på vevstaken.", ALL)
add("head", "std", "Topplock original", "Origo", 500, { cf = 1 }, ALL, "Originaltopplock.", ALL)
add("head", "fins", "Topplock storflänsat", "Kylstad", 900, { cf = 1.25 }, { "jog", "dt" }, "25 % bättre luftkylning.", {})
-- intake and fuel
add("reed", "std", "Reedventil original", "Origo", 300, { reedf = 1 }, ALL, "Backventil i insuget.", ALL)
add("reed", "carbon", "Reedventil kolfiber", "Snabbo", 650, { reedf = 1.03 }, ALL, "Snabbare blad: +3 % vridmoment i spelet.", {})
add("intake", "std", "Insug original (upp till 19 mm)", "Origo", 200, { maxd = 19 }, ALL, "Förgasare över 19 mm stryps.", ALL)
add("intake", "big", "Insug stort (upp till 24 mm)", "Nordtrim", 450, { maxd = 24 }, ALL, "Fullt flöde upp till 24 mm.", {})
for i, d in ipairs(Config.CARB) do
	add("carb", tostring(d), "Förgasare " .. d .. " mm", i > 3 and "Fartek" or "Vippa", ({ 500, 700, 900, 1300, 1700 })[i], { carb = i - 1 }, ALL, "Mer luft vid höga varv.", ({ { "jog" }, { "rok", "dt" } })[i])
end
add("filter", "std", "Luftfilter original", "Origo", 150, { fcap = 1 }, ALL, "Originalfilter.", ALL)
add("filter", "sport", "Luftfilter sport", "Vippa", 350, { fcap = 1.12 }, ALL, "12 % mer luft, blandningen blir magrare.", {})
add("hose", "std", "Bränsleslang 5 mm", "Origo", 40, {}, ALL, "Från kranen till förgasaren.", ALL)
-- ignition
add("stator", "std", "Stator", "Origo", 450, {}, ALL, "Laddspolar och tändpuls.", ALL)
add("flywheel", "std", "Svänghjul original", "Origo", 600, {}, ALL, "Svänghjul med magneter.", ALL)
add("fan", "std", "Fläkt", "Origo", 120, {}, { "jog", "rok" }, "Kyler motorn (sitter på svänghjulet).", { "jog", "rok" })
add("coil", "std", "Tändspole", "Origo", 300, {}, ALL, "Ger högspänning till stiftet.", ALL)
add("cdi", "std", "CDI original (spärr 11 000)", "Origo", 600, { icap = 11000 }, ALL, "Varvspärr 11 000 rpm.", ALL)
add("cdi", "sport", "CDI sport (spärr 14 000)", "Fartek", 1300, { icap = 14000 }, ALL, "Varvspärr 14 000 rpm.", {})
add("cable", "std", "Tändkabel med hatt", "Origo", 80, {}, ALL, "Från spolen till tändstiftet.", ALL)
-- transmission (CVT)
for i, g in ipairs({ 5, 6, 7, 8, 9, 10, 11, 12 }) do
	add("weights", tostring(g), "Variatorvikter " .. g .. " g (6 st)", "Vippa", 120, { roller = g }, CVT, "Lättare vikter = högre varv.", g == 10 and { "jog" } or g == 9 and { "rok" } or {})
end
add("var", "std", "Variator original", "Origo", 600, { rmin = 0.85 }, CVT, "Högsta utväxling 0,85:1.", CVT)
add("var", "sport", "Variator sport", "Nordtrim", 1100, { rmin = 0.78 }, CVT, "Högsta utväxling 0,78:1, högre toppfart.", {})
add("var", "race", "Variator race", "Fartek", 1600, { rmin = 0.72 }, CVT, "Högsta utväxling 0,72:1.", {})
add("contra", "std", "Kontrafjäder original", "Origo", 150, { cdt = 0 }, CVT, "Originalfjäder.", CVT)
add("contra", "15", "Kontrafjäder +15 %", "Nordtrim", 200, { cdt = 400 }, CVT, "Variatorn håller 400 rpm högre.", {})
add("contra", "30", "Kontrafjäder +30 %", "Nordtrim", 250, { cdt = 800 }, CVT, "Variatorn håller 800 rpm högre.", {})
add("pulley", "std", "Bakre remskiva", "Origo", 500, {}, CVT, "Sekundärsidan av variatorn.", CVT)
add("belt", "std", "Rem original", "Origo", 300, { blim = 7 }, CVT, "Slirar över ca 7 hk.", CVT)
add("belt", "kevlar", "Rem förstärkt", "Bruksmek", 550, { blim = 15 }, CVT, "Slirar över ca 15 hk.", {})
add("clutch", "std", "Koppling original", "Origo", 450, { slip = 7500 }, CVT, "Slirar till ca 7 500 rpm.", CVT)
add("clutch", "sport", "Koppling sport", "Fartek", 750, { slip = 9000 }, CVT, "Slirar till ca 9 000 rpm.", {})
add("clutch", "race", "Koppling race", "Fartek", 950, { slip = 10500 }, CVT, "Slirar till ca 10 500 rpm.", {})
add("bell", "std", "Kopplingsklocka", "Origo", 350, {}, CVT, "Kopplingen griper mot klockan.", CVT)
-- transmission (geared DT)
add("gearbox", "std", "Växellåda 4 växlar", "Origo", 1800, {}, { "dt" }, "Sitter i vevhuset.", { "dt" })
add("plates", "std", "Kopplingslameller", "Origo", 400, { slip = 0 }, { "dt" }, "Våtkoppling.", { "dt" })
add("sprocket", "std", "Drev 12 tänder", "Origo", 150, {}, { "dt" }, "Driver kedjan.", { "dt" })
-- ---------- moped (chassis) ----------
add("frame", "std", "Ram", "Origo", 2500, {}, ALL, "Mopedens stomme.", ALL)
add("fork", "std", "Framgaffel original", "Origo", 1200, {}, ALL, "", ALL)
add("fork", "upside", "Framgaffel upside-down", "Snabbo", 2600, {}, ALL, "Stelare framvagn.", {})
add("shock", "std", "Bakdämpare original", "Origo", 500, {}, ALL, "", ALL)
add("shock", "gas", "Bakdämpare gas, röd fjäder", "Snabbo", 950, {}, ALL, "Syns med röd fjäder.", {}, { color = "red" })
add("wheel", "std", "Hjul original", "Origo", 900, { rims = "std" }, ALL, "Fälg med däck.", ALL)
add("wheel", "pol", "Hjul polerade", "Bruksmek", 1400, { rims = "pol" }, ALL, "Spegelblanka fälgar.", {})
add("wheel", "gold", "Hjul guld", "Nordtrim", 1300, { rims = "gold" }, ALL, "Guldfärgade fälgar.", {})
add("brake", "std", "Skivbroms", "Origo", 400, {}, ALL, "Skiva och ok.", ALL)
add("bars", "std", "Styre original", "Origo", 300, { bars = "std" }, ALL, "", ALL)
add("bars", "high", "Crossstyre högt", "Nordtrim", 550, { bars = "high" }, { "dt" }, "", {})
add("seat", "std", "Sadel original", "Origo", 600, {}, ALL, "", ALL)
add("tank", "std", "Tank", "Origo", 900, {}, { "dt" }, "", { "dt" })
for i, e in ipairs(Config.EXH) do
	add("exh", tostring(i - 1), "Avgassystem " .. e.n, ({ "Origo", "Bruksmek", "Fartek", "Nordtrim", "Fartek" })[i], ({ 900, 1400, 1900, 2400, 3200 })[i], { exh = i - 1 }, ALL,
		"Inställt för ca " .. e.t .. " varv.", i == 1 and ALL or {})
end
add("radiator", "std", "Kylare original", "Origo", 700, { cf = 1 }, { "rok" }, "Kyler kylvätskan.", { "rok" })
add("radiator", "big", "Kylare stor", "Kylstad", 1300, { cf = 1.25 }, { "rok" }, "25 % bättre kylning.", {})
-- ---------- tools ----------
add("tool", "basic", "Hylsnyckelsats och skruvdragare", "Bruksmek", 0, { tool = "basic" }, ALL, "Behövs för att montera. Följer med garaget.", {})
add("tool", "grinder", "Rak slipmaskin", "Bruksmek", 900, { tool = "grinder", steady = 0.6 }, ALL, "Behövs för att porta cylindrar.", {})
add("tool", "grinderpro", "Rak slipmaskin proffs", "Fartek", 2400, { tool = "grinder", steady = 1 }, ALL, "Lugnare verktyg: mer precision vid portning.", {})
add("tool", "spray", "Sprutpistol", "Bruksmek", 700, { tool = "spray", even = 0.7 }, ALL, "Behövs för att lackera.", {})
add("tool", "spraypro", "Sprutpistol HVLP", "Vippa", 1900, { tool = "spray", even = 1 }, ALL, "Jämnare sprutbild: bättre lack.", {})

-- ---------- body panels: one product per panel and variant, per model (see Panels.lua) ----------
local Panels = require(script.Parent.Panels)
for _, m in ipairs(Config.MOPEDS) do
	for _, pd in ipairs(Panels[m.id]) do
		add("panel", m.id .. "-" .. pd.id, pd.n .. " – " .. m.n, "Origo", pd.price, { panel = pd.id, look = "std" }, { m.id }, "Originalkåpa.", { m.id }, { panel = pd.id })
		for _, alt in ipairs(pd.alts or {}) do
			add("panel", m.id .. "-" .. pd.id .. "-" .. alt[1], pd.n .. " " .. alt[2] .. " – " .. m.n, alt[3], alt[4], { panel = pd.id, look = alt[1] }, { m.id }, alt[5], {}, { panel = pd.id })
		end
	end
end
-- OEM panels are keyed by panel id (several panels share kind "panel")
Catalog.OEM_PANEL = {}
for _, m in ipairs(Config.MOPEDS) do
	Catalog.OEM_PANEL[m.id] = {}
	for _, pd in ipairs(Panels[m.id]) do Catalog.OEM_PANEL[m.id][pd.id] = "P-panel-" .. m.id .. "-" .. pd.id end
end
Catalog.OEM = OEM

function Catalog.fits(p, mopId) return p ~= nil and has(p.fits, mopId) end
return Catalog

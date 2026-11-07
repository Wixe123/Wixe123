-- Every part and tool that exists, with shop data and the stats Performance uses.
-- All brands are made up (real brand names and logos could get the game taken down from Roblox).
local Parts = {}

-- kinds: what a part is, where it belongs and which shop category it is sold under
Parts.KINDS = {
	-- motorblock
	vevhus = { n = "Vevhus", grp = "Motorblock", cat = "Vevpartier" },
	vevlager = { n = "Vevlager", grp = "Motorblock", cat = "Motordelar" },
	vevaxel = { n = "Vevaxel", grp = "Motorblock", cat = "Vevpartier" },
	packbox = { n = "Packboxar", grp = "Motorblock", cat = "Motordelar" },
	nallager = { n = "Nållager", grp = "Motorblock", cat = "Motordelar" },
	kolv = { n = "Kolv", grp = "Motorblock", cat = "Cylindrar" },
	kolvbult = { n = "Kolvbult", grp = "Motorblock", cat = "Motordelar" },
	kolvringar = { n = "Kolvringar", grp = "Motorblock", cat = "Cylindrar" },
	fotpackning = { n = "Cylinderfotspackning", grp = "Motorblock", cat = "Motordelar" },
	cylinder = { n = "Cylinder", grp = "Motorblock", cat = "Cylindrar" },
	topplock = { n = "Topplock", grp = "Motorblock", cat = "Cylindrar" },
	tandstift = { n = "Tändstift", grp = "Motorblock", cat = "Tändsystem" },
	-- transmission
	variator = { n = "Variator", grp = "Transmission", cat = "Variatorer" },
	vikter = { n = "Variatorvikter", grp = "Transmission", cat = "Variatorer" },
	flakt = { n = "Fläkt", grp = "Transmission", cat = "Variatorer" },
	rem = { n = "Rem", grp = "Transmission", cat = "Variatorer" },
	koppling = { n = "Koppling", grp = "Transmission", cat = "Kopplingar" },
	klocka = { n = "Kopplingsklocka", grp = "Transmission", cat = "Kopplingar" },
	remskiva = { n = "Bakre remskiva", grp = "Transmission", cat = "Kopplingar" },
	-- bränsle och insug
	reed = { n = "Reedventil", grp = "Insug", cat = "Insug" },
	insug = { n = "Insug", grp = "Insug", cat = "Insug" },
	forgasare = { n = "Förgasare", grp = "Insug", cat = "Förgasare" },
	luftfilter = { n = "Luftfilter", grp = "Insug", cat = "Luftfilter" },
	slang = { n = "Bränsleslang", grp = "Insug", cat = "Förgasare" },
	-- tändning
	cdi = { n = "CDI", grp = "Tändning", cat = "Tändsystem" },
	spole = { n = "Tändspole", grp = "Tändning", cat = "Tändsystem" },
	svanghjul = { n = "Svänghjul", grp = "Tändning", cat = "Tändsystem" },
	stator = { n = "Stator", grp = "Tändning", cat = "Tändsystem" },
	tandkabel = { n = "Tändkabel", grp = "Tändning", cat = "Tändsystem" },
	-- chassi
	ram = { n = "Ram", grp = "Chassi", cat = "Chassi" },
	gaffel = { n = "Framgaffel", grp = "Chassi", cat = "Chassi" },
	framhjul = { n = "Framhjul", grp = "Chassi", cat = "Chassi" },
	bakhjul = { n = "Bakhjul", grp = "Chassi", cat = "Chassi" },
	frambroms = { n = "Frambroms", grp = "Chassi", cat = "Chassi" },
	bakbroms = { n = "Bakbroms", grp = "Chassi", cat = "Chassi" },
	dampare = { n = "Bakdämpare", grp = "Chassi", cat = "Chassi" },
	styre = { n = "Styre", grp = "Chassi", cat = "Chassi" },
	tank = { n = "Tank", grp = "Chassi", cat = "Chassi" },
	sadel = { n = "Sadel", grp = "Chassi", cat = "Chassi" },
	avgas = { n = "Avgassystem", grp = "Chassi", cat = "Avgassystem" },
	kapa = { n = "Kåpa", grp = "Kåpor", cat = "Styling" },
	verktyg = { n = "Verktyg", grp = "Verktyg", cat = "Verktyg" },
}

Parts.CATEGORIES = { "Cylindrar", "Förgasare", "Avgassystem", "Variatorer", "Kopplingar", "Vevpartier", "Tändsystem", "Insug", "Luftfilter", "Motordelar", "Chassi", "Styling", "Verktyg" }

Parts.BRANDS = {
	Origo = { color = { 190, 194, 200 }, about = "Originaldelar" },
	Fartek = { color = { 205, 38, 38 }, about = "Racing" },
	Nordtrim = { color = { 240, 196, 25 }, about = "Sport" },
	Snabbo = { color = { 245, 120, 20 }, about = "Racing" },
	Kylstad = { color = { 40, 110, 210 }, about = "Kyla och tändning" },
	["Gasström"] = { color = { 40, 160, 90 }, about = "Förgasare" },
	Bruksmek = { color = { 110, 115, 125 }, about = "Prisvärt" },
	Vippa = { color = { 30, 90, 200 }, about = "Mopedtillverkare" },
}

Parts.ITEMS = {}
Parts.LIST = {}
Parts.LIST_INDEX = {}
local function add(kind, code, brand, name, price, stock, stats, desc)
	local sku = kind .. "_" .. code
	assert(Parts.KINDS[kind], kind)
	assert(not Parts.ITEMS[sku], sku)
	local it = { sku = sku, kind = kind, brand = brand, name = name, price = price, stock = stock, stats = stats or {}, desc = desc or "" }
	Parts.ITEMS[sku] = it
	Parts.LIST[#Parts.LIST + 1] = it
	Parts.LIST_INDEX[sku] = #Parts.LIST
	return it
end
Parts.add = add

-- motorblock -------------------------------------------------------------
add("vevhus", "origo", "Origo", "Vevhus original", 650, 6, { lvl = 0 }, "Delat vevhus i gjuten aluminium för liggande motor.")
add("vevhus", "fartek", "Fartek", "Vevhus Racing", 1490, 2, { lvl = 2, hp = 1.03 }, "Bearbetade överströmningskanaler som matchar racingcylindrar.")
add("vevlager", "origo", "Origo", "Vevlager 6204", 149, 12, {}, "Två kullager till vevaxeln.")
add("vevlager", "nordtrim", "Nordtrim", "Vevlager C4 högvarv", 249, 6, { rpm = 300 }, "Lager med större glapp som tål högre varv.")
add("vevaxel", "origo", "Origo", "Vevaxel 39,2 mm", 690, 5, { stroke = 39.2 }, "Original vevaxel med vevstake.")
add("vevaxel", "fartek", "Fartek", "Vevaxel Racing 39,2 mm", 1290, 3, { stroke = 39.2, hp = 1.04, rpm = 500, lvl = 2 }, "Balanserad vevaxel för högre varv.")
add("vevaxel", "snabbo", "Snabbo", "Långslagsvevaxel 44 mm", 1590, 0, { stroke = 44, hp = 1.09, rpm = -400, lvl = 2 }, "Längre slag ger mer slagvolym och vridmoment.")
add("packbox", "origo", "Origo", "Packboxar (par)", 79, 20, {}, "Tätar vevhuset mot vevaxeln.")
add("packbox", "fartek", "Fartek", "Packboxar Viton (par)", 129, 8, {}, "Värmetåliga packboxar.")
add("nallager", "origo", "Origo", "Nållager 10x14x13", 69, 15, {}, "Lager för kolvbulten i vevstaken.")
add("nallager", "nordtrim", "Nordtrim", "Nållager Silver", 119, 6, { rpm = 150 }, "Försilvrad bur för högre varv.")
add("kolv", "40", "Origo", "Kolv 40 mm", 349, 8, { bore = 40 }, "Kolv till 50 cc cylinder.")
add("kolv", "47", "Nordtrim", "Kolv 47 mm", 499, 5, { bore = 47 }, "Kolv till Nordtrim 70 cc.")
add("kolv", "476", "Fartek", "Kolv 47,6 mm", 590, 4, { bore = 47.6 }, "Smidd kolv till Fartek 70 cc.")
add("kolv", "50", "Snabbo", "Kolv 50 mm", 690, 2, { bore = 50 }, "Kolv till Snabbo 80 cc.")
add("kolvringar", "40", "Origo", "Kolvringar 40 mm", 129, 10, { bore = 40 }, "Två ringar.")
add("kolvringar", "47", "Nordtrim", "Kolvringar 47 mm", 159, 6, { bore = 47 }, "Två ringar.")
add("kolvringar", "476", "Fartek", "Kolvringar 47,6 mm", 189, 6, { bore = 47.6 }, "Två krom-ringar.")
add("kolvringar", "50", "Snabbo", "Kolvringar 50 mm", 199, 3, { bore = 50 }, "Två ringar.")
add("kolvbult", "origo", "Origo", "Kolvbult 10 mm", 59, 15, {}, "Håller kolven på vevstaken.")
add("kolvbult", "fartek", "Fartek", "Kolvbult lätt 10 mm", 129, 6, { rpm = 200 }, "Urborrad, lättare bult.")
add("fotpackning", "origo", "Origo", "Fotpackning 0,5 mm", 39, 25, {}, "Packning mellan vevhus och cylinder.")
add("fotpackning", "fartek", "Fartek", "Fotpackning 0,3 mm", 59, 10, { hp = 1.02 }, "Tunnare packning ger lite högre kompression.")
add("cylinder", "origo50", "Origo", "Cylinder 50 cc", 1290, 4, { cc = 49.3, bore = 40, hp = 3.6, rpm = 6800, lvl = 0, heat = 1.0 }, "Originalcylinder i gjutjärn. Lugn och tålig.")
add("cylinder", "nordtrim70", "Nordtrim", "Cylinder 70 cc Sport", 1990, 4, { cc = 68, bore = 47, hp = 6.9, rpm = 8600, lvl = 1, heat = 1.15 }, "Gjutjärnscylinder för gatan. Bra första trimning.")
add("cylinder", "fartek70", "Fartek", "Cylinder 70 cc Racing", 3290, 2, { cc = 69.7, bore = 47.6, hp = 9.6, rpm = 10400, lvl = 2, heat = 1.3 }, "Aluminium med nikasilbeläggning och fem överströmningskanaler.")
add("cylinder", "snabbo80", "Snabbo", "Cylinder 80 cc Big Bore", 4490, 0, { cc = 77, bore = 50, hp = 12.2, rpm = 10900, lvl = 3, heat = 1.45 }, "Störst slagvolym. Kräver stor förgasare och racingavgas.")
add("topplock", "origo", "Origo", "Topplock original", 290, 6, { comp = 1.0 }, "Luftkylt topplock.")
add("topplock", "fartek", "Fartek", "Topplock Racing", 790, 3, { comp = 1.05, heat = 1.06 }, "Högre kompression och större kylflänsar.")
add("tandstift", "b7", "Origo", "Tändstift B7", 49, 30, { range = 7 }, "Normalt värmetal.")
add("tandstift", "b9", "Kylstad", "Tändstift B9 Racing", 89, 12, { range = 9 }, "Kallare stift som tål trimmade motorer.")

-- transmission -----------------------------------------------------------
add("variator", "origo", "Origo", "Variator original (strypt)", 490, 5, { high = 1.25 }, "Original med distansbricka som begränsar toppfarten.")
add("variator", "nordtrim", "Nordtrim", "Variator Speed", 990, 4, { high = 0.93 }, "Större utväxling i toppen.")
add("variator", "fartek", "Fartek", "Multivar Racing", 1690, 2, { high = 0.84, acc = 1.03 }, "Racingvariator med optimerad bana för rullarna.")
add("vikter", "6g", "Origo", "Variatorvikter 6,0 g", 99, 15, { gram = 6.0 }, "Sex rullar. Tyngre rullar växlar upp tidigare.")
add("vikter", "5g", "Nordtrim", "Variatorvikter 5,0 g", 129, 10, { gram = 5.0 }, "Lättare rullar håller motorn på högre varv.")
add("vikter", "4g", "Snabbo", "Variatorvikter 4,0 g", 129, 6, { gram = 4.0 }, "Mycket lätta rullar för racingcylindrar.")
add("vikter", "75g", "Bruksmek", "Variatorvikter 7,5 g", 99, 6, { gram = 7.5 }, "Tunga rullar. Lugn körning, lägre varv.")
add("flakt", "origo", "Origo", "Variatorfläkt", 129, 8, { cool = 1.0 }, "Fläkthjulet på variatorn kyler remmen och motorn.")
add("flakt", "fartek", "Fartek", "Variatorfläkt Racing", 249, 4, { cool = 1.08 }, "Större skovlar som flyttar mer luft.")
add("rem", "origo", "Origo", "Drivrem original", 249, 10, { eff = 1.0 }, "Gummirem.")
add("rem", "snabbo", "Snabbo", "Drivrem Kevlar", 449, 5, { eff = 1.03 }, "Kevlarförstärkt rem som slirar mindre.")
add("koppling", "origo", "Origo", "Koppling original", 590, 5, { engage = 3400 }, "Kopplar in tidigt. Mjuk start.")
add("koppling", "nordtrim", "Nordtrim", "Koppling Sport", 890, 4, { engage = 4300 }, "Kopplar in på högre varv för snabbare start.")
add("koppling", "fartek", "Fartek", "Koppling Racing", 1390, 2, { engage = 5200, acc = 1.02 }, "Justerbar racingkoppling.")
add("klocka", "origo", "Origo", "Kopplingsklocka original", 390, 6, {}, "Stålklocka.")
add("klocka", "fartek", "Fartek", "Kopplingsklocka lätt", 790, 3, { acc = 1.03 }, "Lättare klocka varvar upp snabbare.")
add("remskiva", "origo", "Origo", "Bakre remskiva original", 590, 5, {}, "Med momentfjäder.")
add("remskiva", "snabbo", "Snabbo", "Torque driver", 990, 3, { acc = 1.04 }, "Bättre bana och styvare fjäder ger snabbare acceleration.")

-- bränsle och insug ---------------------------------------------------------
add("reed", "origo", "Origo", "Reedventil original", 290, 6, { lvl = 0 }, "Membranventil med glasfiberblad.")
add("reed", "fartek", "Fartek", "Reedventil Kolfiber", 690, 4, { lvl = 1 }, "Kolfiberblad som öppnar snabbare.")
add("reed", "snabbo", "Snabbo", "Reedventil Racing V-Force", 890, 2, { lvl = 2 }, "Fler blad och större genomströmning.")
add("insug", "origo", "Origo", "Insug original", 149, 8, { lvl = 0 }, "Gummiinsug.")
add("insug", "nordtrim", "Nordtrim", "Insug 19 mm", 349, 5, { lvl = 1 }, "Större insug för sportförgasare.")
add("insug", "fartek", "Fartek", "Insug Racing 24 mm", 449, 3, { lvl = 2 }, "Insug för racingförgasare.")
add("forgasare", "origo12", "Origo", "Förgasare 12 mm", 490, 5, { mm = 12, cap = 4.6 }, "Originalförgasare.")
add("forgasare", "gs175", "Gasström", "Förgasare 17,5 mm", 990, 5, { mm = 17.5, cap = 8.8 }, "Bra steg upp från original.")
add("forgasare", "gs19", "Gasström", "Förgasare 19 mm", 1290, 4, { mm = 19, cap = 11.0 }, "Passar 70 cc.")
add("forgasare", "gs21", "Gasström", "Förgasare 21 mm", 1590, 3, { mm = 21, cap = 13.6 }, "För racing-70 och 80 cc.")
add("forgasare", "fartek24", "Fartek", "Förgasare 24 mm Racing", 2190, 0, { mm = 24, cap = 16.5 }, "Störst flöde. Kräver racinginsug.")
add("luftfilter", "origo", "Origo", "Luftfilterlåda original", 199, 6, { lvl = 0 }, "Tyst men stryper flödet.")
add("luftfilter", "nordtrim", "Nordtrim", "Sportfilter", 249, 6, { lvl = 1 }, "Öppet filter.")
add("luftfilter", "fartek", "Fartek", "Racingfilter", 349, 4, { lvl = 2 }, "Konfilter med stor yta.")
add("slang", "origo", "Origo", "Bränsleslang 5 mm", 39, 30, {}, "Från tank till förgasare.")
add("slang", "bruksmek", "Bruksmek", "Bränsleslang genomskinlig", 49, 20, {}, "Man ser bränslet.")

-- tändning ------------------------------------------------------------------
add("cdi", "origo", "Origo", "CDI original (spärrad)", 390, 5, { limit = 7000 }, "Varvspärr för 45 km/h.")
add("cdi", "snabbo", "Snabbo", "CDI Racing ospärrad", 790, 4, { limit = 13000 }, "Ingen varvspärr.")
add("cdi", "fartek", "Fartek", "CDI Racing med tändkurva", 990, 2, { limit = 12500, hp = 1.03 }, "Ospärrad med bättre tändkurva.")
add("spole", "origo", "Origo", "Tändspole original", 290, 6, {}, "")
add("spole", "kylstad", "Kylstad", "Tändspole Racing", 490, 4, { hp = 1.015 }, "Starkare gnista.")
add("svanghjul", "origo", "Origo", "Svänghjul original", 590, 5, {}, "Tungt och stabilt.")
add("svanghjul", "fartek", "Fartek", "Svänghjul lätt", 1190, 2, { acc = 1.04 }, "Lättare svänghjul varvar snabbare.")
add("stator", "origo", "Origo", "Stator original", 490, 5, {}, "Ger ström till tändning och lyse.")
add("stator", "fartek", "Fartek", "Stator Racing", 690, 3, {}, "Lättare stator.")
add("tandkabel", "origo", "Origo", "Tändkabel", 49, 20, {}, "")
add("tandkabel", "kylstad", "Kylstad", "Tändkabel silikon", 99, 10, {}, "Tål värme bättre.")

-- chassi -----------------------------------------------------------------------
add("ram", "citi", "Vippa", "Ram Vippa Citi", 1990, 2, { fits = "citi" }, "Stålram till Citi 50.")
add("ram", "sprint", "Vippa", "Ram Vippa Sprint", 2490, 2, { fits = "sprint" }, "Stålram till Sprint 50.")
add("ram", "klassik", "Vippa", "Ram Vippa Klassik", 2190, 2, { fits = "klassik" }, "Stålram till Klassik 50.")
add("gaffel", "origo", "Origo", "Framgaffel original", 990, 4, { handling = 1.0 }, "Teleskopgaffel.")
add("gaffel", "fartek", "Fartek", "Upside-down-gaffel", 2490, 2, { handling = 1.12 }, "Styvare gaffel ger bättre styrning.")
add("framhjul", "origo", "Origo", "Framhjul 13 tum", 590, 6, { grip = 1.0 }, "Fälg och däck.")
add("framhjul", "snabbo", "Snabbo", "Framhjul Sport 13 tum", 990, 3, { grip = 1.1 }, "Mjukare gummi.")
add("bakhjul", "origo", "Origo", "Bakhjul 13 tum", 590, 6, { grip = 1.0 }, "Fälg och däck.")
add("bakhjul", "snabbo", "Snabbo", "Bakhjul Sport 13 tum", 990, 3, { grip = 1.1 }, "Mjukare gummi.")
add("frambroms", "origo", "Origo", "Skivbroms fram", 390, 6, { brake = 1.0 }, "Skiva och ok.")
add("frambroms", "fartek", "Fartek", "Skivbroms fram 4-kolv", 790, 3, { brake = 1.2 }, "Kraftigare ok.")
add("bakbroms", "origo", "Origo", "Trumbroms bak", 290, 6, { brake = 1.0 }, "")
add("bakbroms", "fartek", "Fartek", "Skivbroms bak", 590, 3, { brake = 1.12 }, "")
add("dampare", "origo", "Origo", "Bakdämpare original", 390, 6, { handling = 1.0 }, "")
add("dampare", "nordtrim", "Nordtrim", "Bakdämpare justerbar", 890, 3, { handling = 1.08 }, "Justerbar fjäderförspänning.")
add("styre", "origo", "Origo", "Styre original", 290, 6, {}, "")
add("styre", "bruksmek", "Bruksmek", "Streetstyre", 490, 4, { handling = 1.03 }, "Bredare styre.")
add("tank", "origo", "Origo", "Bensintank 6 l", 690, 4, {}, "")
add("sadel", "origo", "Origo", "Sadel original", 590, 5, {}, "")
add("sadel", "nordtrim", "Nordtrim", "Sadel Sport", 890, 3, {}, "Sportigare form med sömmar.")
add("avgas", "origo", "Origo", "Avgassystem original", 990, 5, { mult = 1.0, rpm = 0, lvl = 0, loud = 1.0 }, "Tyst originalavgas.")
add("avgas", "kylstad", "Kylstad", "Avgas Tour", 1590, 4, { mult = 1.08, rpm = 200, lvl = 1, loud = 1.1 }, "Lite mer kraft, fortfarande tyst.")
add("avgas", "nordtrim", "Nordtrim", "Avgas Sport", 1890, 4, { mult = 1.13, rpm = 500, lvl = 1, loud = 1.3 }, "Expansionskammare för 50–70 cc.")
add("avgas", "fartek", "Fartek", "Avgas Racing", 2990, 2, { mult = 1.24, rpm = 1100, lvl = 2, loud = 1.6 }, "Racingkammare för höga varv.")
add("avgas", "snabbo", "Snabbo", "Avgas Pipe 80", 3490, 0, { mult = 1.31, rpm = 1500, lvl = 3, loud = 1.8 }, "Störst kammare. Kräver racingcylinder.")

-- verktyg ----------------------------------------------------------------------
add("verktyg", "hylsor", "Bruksmek", "Hylsnyckelsats", 0, 99, { tool = "hylsor" }, "Hylsor och spärrskaft. Följer med garaget.")
add("verktyg", "slip", "Bruksmek", "Rak slipmaskin", 690, 8, { tool = "slip", steady = 0.0, speed = 1.0 }, "Rak slipmaskin för portning.")
add("verktyg", "slippro", "Fartek", "Rak slipmaskin Pro", 1490, 3, { tool = "slip", steady = 1.0, speed = 1.3 }, "Stadigare och snabbare. Lättare att porta jämnt.")
add("verktyg", "spruta", "Bruksmek", "Sprutpistol", 490, 8, { tool = "spruta", even = 0.0 }, "Enkel sprutpistol.")
add("verktyg", "sprutapro", "Fartek", "Sprutpistol HVLP Pro", 1290, 3, { tool = "spruta", even = 1.0 }, "Jämnare stråle, färre rinningar.")

function Parts.get(sku) return Parts.ITEMS[sku] end
function Parts.kindName(kind) local k = Parts.KINDS[kind]; return k and k.n or kind end
function Parts.byKind(kind)
	local r = {}
	for _, it in ipairs(Parts.LIST) do if it.kind == kind then r[#r + 1] = it end end
	return r
end
function Parts.category(sku)
	local it = Parts.ITEMS[sku]
	return it and Parts.KINDS[it.kind].cat
end
function Parts.brandColor(brand)
	local b = Parts.BRANDS[brand]
	local c = b and b.color or { 190, 194, 200 }
	return c[1], c[2], c[3]
end

return Parts

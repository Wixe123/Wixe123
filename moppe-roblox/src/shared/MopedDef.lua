-- Moped models, their chassis slots and their panels (kåpor).
-- Moped space (studs): origin on the ground midway between the axles, -Z = forward, +X = right.
local Parts = require(script.Parent.Parts)
local EngineDef = require(script.Parent.EngineDef)
local MopedDef = {}

-- chassis slots: id, kind, req (slots that must be mounted first). "motor" holds the engine assembly.
MopedDef.SLOTS = {
	{ id = "ram", kind = "ram", n = "Ram", req = {} },
	{ id = "gaffel", kind = "gaffel", n = "Framgaffel", req = { "ram" } },
	{ id = "framhjul", kind = "framhjul", n = "Framhjul", req = { "gaffel" } },
	{ id = "frambroms", kind = "frambroms", n = "Frambroms", req = { "framhjul" } },
	{ id = "styre", kind = "styre", n = "Styre", req = { "gaffel" } },
	{ id = "dampare", kind = "dampare", n = "Bakdämpare", req = { "ram" } },
	{ id = "motor", kind = "motor", n = "Motor", req = { "ram", "dampare" } },
	{ id = "bakhjul", kind = "bakhjul", n = "Bakhjul", req = { "motor" } },
	{ id = "bakbroms", kind = "bakbroms", n = "Bakbroms", req = { "bakhjul" } },
	{ id = "avgas", kind = "avgas", n = "Avgassystem", req = { "motor" } },
	{ id = "tank", kind = "tank", n = "Tank", req = { "ram" } },
	{ id = "sadel", kind = "sadel", n = "Sadel", req = { "tank" } },
}
MopedDef.SLOT = {}
for _, s in ipairs(MopedDef.SLOTS) do MopedDef.SLOT[s.id] = s end

-- shapes: { shape, size {x,y,z}, pos {x,y,z}, rot {x,y,z} degrees }
local function P(id, n, price, req, prims) return { id = id, n = n, price = price, req = req, prims = prims } end
local function mirror(prims)
	local r = {}
	for i, p in ipairs(prims) do
		r[i] = { p[1], p[2], { -p[3][1], p[3][2], p[3][3] }, p[4] and { p[4][1], -p[4][2], -p[4][3] } or nil }
	end
	return r
end

MopedDef.MODELS = {}
MopedDef.ORDER = { "citi", "sprint", "klassik" }

-- Vippa Citi 50: small city scooter, the starter moped
local citiSideL = {
	{ "box", { 0.42, 0.85, 2.3 }, { -0.3, 2.2, 1.25 } },
	{ "wedge", { 0.42, 0.5, 0.7 }, { -0.3, 1.53, 0.25 } },
}
MopedDef.MODELS.citi = {
	id = "citi", n = "Vippa Citi 50", price = 8000, color = { 200, 30, 40 },
	wb = 4.2, r = 0.8, head = { 0, 2.6, -1.7 }, rake = 24, barY = 3.45, seat = { 0, 2.74, 1.0 }, seatLen = 1.9, tank = { 0, 2.15, 1.0 },
	floorY = 1.35, tailZ = 2.6, lights = { { 0, 2.62, -2.2 } },
	panels = {
		P("front", "Frontkåpa", 790, { "gaffel" }, {
			{ "box", { 1.05, 1.75, 0.42 }, { 0, 2.12, -1.98 }, { 14, 0, 0 } },
			{ "box", { 0.95, 0.45, 0.4 }, { 0, 1.3, -1.86 } },
		}),
		P("ben", "Benskydd", 590, { "ram" }, { { "box", { 0.95, 1.45, 0.08 }, { 0, 2.05, -1.72 }, { 14, 0, 0 } } }),
		P("fot", "Fotplatta", 490, { "ram" }, { { "box", { 0.95, 0.18, 1.62 }, { 0, 1.26, -0.86 } } }),
		P("sidaV", "Sidokåpa vänster", 690, { "tank" }, citiSideL),
		P("sidaH", "Sidokåpa höger", 690, { "tank" }, mirror(citiSideL)),
		P("bak", "Bakkåpa", 590, { "tank" }, { { "wedge", { 0.84, 0.42, 0.6 }, { 0, 2.42, 2.66 }, { 0, 180, 0 } } }),
		P("skarm", "Framskärm", 390, { "gaffel" }, {
			{ "box", { 0.42, 0.1, 0.8 }, { 0, 1.7, -2.1 } },
			{ "box", { 0.42, 0.1, 0.45 }, { 0, 1.55, -2.62 }, { -35, 0, 0 } },
		}),
		P("styrkapa", "Styrkåpa", 490, { "styre" }, { { "box", { 1.0, 0.32, 0.55 }, { 0, 3.42, -1.62 }, { 10, 0, 0 } } }),
	},
}

-- Vippa Sprint 50: sporty scooter with a big pointed front and a high tail
local sprintSideL = {
	{ "box", { 0.45, 0.9, 2.45 }, { -0.32, 2.3, 1.35 } },
	{ "wedge", { 0.45, 0.55, 0.8 }, { -0.32, 1.58, 0.25 } },
	{ "wedge", { 0.45, 0.4, 0.95 }, { -0.32, 2.95, 2.4 } },
}
local sprintFlankL = { { "box", { 0.12, 1.25, 0.85 }, { -0.6, 2.25, -1.98 }, { 16, -12, 0 } } }
MopedDef.MODELS.sprint = {
	id = "sprint", n = "Vippa Sprint 50", price = 12500, color = { 25, 70, 200 },
	wb = 4.5, r = 0.85, head = { 0, 2.75, -1.85 }, rake = 25, barY = 3.6, seat = { 0, 2.88, 1.05 }, seatLen = 2.1, tank = { 0, 2.25, 1.05 },
	floorY = 1.4, tailZ = 2.9, lights = { { -0.28, 2.42, -2.46 }, { 0.28, 2.42, -2.46 } },
	panels = {
		P("front", "Frontkåpa", 990, { "gaffel" }, {
			{ "box", { 1.15, 1.55, 0.5 }, { 0, 2.35, -2.15 }, { 18, 0, 0 } },
			{ "wedge", { 0.95, 0.42, 0.65 }, { 0, 1.72, -2.5 }, { 0, 180, 0 } },
			{ "box", { 1.1, 0.12, 0.62 }, { 0, 3.12, -2.0 }, { 28, 0, 0 } },
		}),
		P("flankV", "Frontflank vänster", 590, { "gaffel" }, sprintFlankL),
		P("flankH", "Frontflank höger", 590, { "gaffel" }, mirror(sprintFlankL)),
		P("ben", "Benskydd", 690, { "ram" }, { { "box", { 1.05, 1.4, 0.08 }, { 0, 2.15, -1.84 }, { 16, 0, 0 } } }),
		P("fot", "Fotplatta", 490, { "ram" }, { { "box", { 0.95, 0.18, 1.6 }, { 0, 1.31, -0.92 } } }),
		P("tunnel", "Tunnelkåpa", 490, { "ram" }, { { "box", { 0.45, 0.3, 1.4 }, { 0, 1.5, -0.92 } } }),
		P("sidaV", "Sidokåpa vänster", 790, { "tank" }, sprintSideL),
		P("sidaH", "Sidokåpa höger", 790, { "tank" }, mirror(sprintSideL)),
		P("bak", "Bakkåpa", 690, { "tank" }, { { "box", { 0.82, 0.35, 0.3 }, { 0, 2.78, 2.98 } } }),
		P("skarm", "Framskärm", 390, { "gaffel" }, {
			{ "box", { 0.42, 0.1, 0.9 }, { 0, 1.8, -2.3 } },
			{ "box", { 0.42, 0.1, 0.45 }, { 0, 1.66, -2.86 }, { -30, 0, 0 } },
		}),
		P("styrkapa", "Styrkåpa", 590, { "styre" }, { { "wedge", { 1.0, 0.35, 0.6 }, { 0, 3.55, -1.75 }, { 0, 180, 0 } } }),
		P("under", "Underkåpa", 390, { "ram" }, { { "box", { 0.8, 0.12, 1.3 }, { 0, 1.1, -0.92 } } }),
		P("spoiler", "Bakspoiler", 490, { "tank" }, { { "box", { 0.72, 0.08, 0.45 }, { 0, 3.22, 2.92 }, { -12, 0, 0 } } }),
	},
}

-- Vippa Klassik 50: round retro scooter
local klassikSideL = { { "ell", { 0.72, 1.05, 2.0 }, { -0.3, 2.08, 1.45 } } }
MopedDef.MODELS.klassik = {
	id = "klassik", n = "Vippa Klassik 50", price = 10500, color = { 120, 200, 190 },
	wb = 4.3, r = 0.8, head = { 0, 2.7, -1.8 }, rake = 22, barY = 3.5, seat = { 0, 2.78, 1.1 }, seatLen = 1.8, tank = { 0, 2.2, 1.1 },
	floorY = 1.35, tailZ = 2.55, lights = { { 0, 3.6, -1.98 } },
	panels = {
		P("front", "Frontsköld", 890, { "gaffel" }, {
			{ "box", { 1.2, 1.85, 0.14 }, { 0, 2.15, -1.95 }, { 12, 0, 0 } },
			{ "ell", { 0.42, 0.62, 0.3 }, { 0, 2.55, -2.12 } },
		}),
		P("fot", "Fotplatta", 490, { "ram" }, { { "box", { 1.0, 0.15, 1.6 }, { 0, 1.28, -0.9 } } }),
		P("sidaV", "Sidokåpa vänster", 790, { "tank" }, klassikSideL),
		P("sidaH", "Sidokåpa höger", 790, { "tank" }, mirror(klassikSideL)),
		P("bak", "Bakkåpa", 590, { "tank" }, { { "ell", { 0.75, 0.55, 0.9 }, { 0, 2.45, 2.3 } } }),
		P("skarm", "Framskärm", 490, { "gaffel" }, { { "ell", { 0.55, 0.55, 1.15 }, { 0, 1.62, -2.12 } } }),
		P("styrkapa", "Styrkåpa", 590, { "styre" }, {
			{ "box", { 0.95, 0.3, 0.5 }, { 0, 3.42, -1.68 }, { 8, 0, 0 } },
			{ "ell", { 0.42, 0.42, 0.3 }, { 0, 3.6, -1.86 } },
		}),
	},
}

-- register frames and panels as parts in the catalog
for _, id in ipairs(MopedDef.ORDER) do
	local m = MopedDef.MODELS[id]
	m.panelById = {}
	for _, p in ipairs(m.panels) do
		m.panelById[p.id] = p
		Parts.add("kapa", id .. "_" .. p.id, "Vippa", p.n .. " " .. m.n:gsub("^Vippa ", ""):gsub(" 50$", ""), p.price, 4, { fits = id, panel = p.id }, "Originalkåpa i plast, olackerad.")
	end
end

-- all slot ids for a model: chassis slots + "pan:<id>"
function MopedDef.slotIds(model)
	local r = {}
	for _, s in ipairs(MopedDef.SLOTS) do r[#r + 1] = s.id end
	for _, p in ipairs(MopedDef.MODELS[model].panels) do r[#r + 1] = "pan:" .. p.id end
	return r
end
function MopedDef.slotInfo(model, slot)
	if slot:sub(1, 4) == "pan:" then
		local p = MopedDef.MODELS[model].panelById[slot:sub(5)]
		if p then return { id = slot, kind = "kapa", n = p.n, req = p.req, panel = p } end
		return nil
	end
	return MopedDef.SLOT[slot]
end
function MopedDef.slotName(model, slot) local i = MopedDef.slotInfo(model, slot); return i and i.n or slot end

-- m = { model=, slots = {slot=uid}, engine = {sock=uid} or nil }
function MopedDef.canMount(m, slot, sku)
	local info = MopedDef.slotInfo(m.model, slot)
	if not info then return false, "Okänd plats" end
	if slot == "motor" then return false, "Motorn monteras från motorstativet" end
	local p = Parts.get(sku)
	if not p then return false, "Okänd del" end
	if p.kind ~= info.kind then return false, p.name .. " passar inte där" end
	if p.stats.fits and p.stats.fits ~= m.model then return false, p.name .. " passar inte " .. MopedDef.MODELS[m.model].n end
	if p.stats.panel and "pan:" .. p.stats.panel ~= slot then return false, p.name .. " sitter inte där" end
	if m.slots[slot] then return false, info.n .. " sitter redan på" end
	for _, r in ipairs(info.req) do
		local filled = (r == "motor") and m.engine ~= nil or m.slots[r] ~= nil
		if not filled then return false, "Montera " .. MopedDef.slotName(m.model, r):lower() .. " först" end
	end
	return true
end
local function filled(m, slot) if slot == "motor" then return m.engine ~= nil end return m.slots[slot] ~= nil end
MopedDef.filled = filled
function MopedDef.canRemove(m, slot)
	if not filled(m, slot) then return false, "Inget monterat där" end
	for _, id in ipairs(MopedDef.slotIds(m.model)) do
		if filled(m, id) then
			local info = MopedDef.slotInfo(m.model, id)
			for _, r in ipairs(info.req) do
				if r == slot then return false, "Ta bort " .. info.n:lower() .. " först" end
			end
		end
	end
	return true
end
-- engine assembly from the stand into the moped
function MopedDef.canMountEngine(m, engineMap)
	if m.engine then return false, "Mopeden har redan en motor" end
	if not EngineDef.complete(engineMap) then return false, "Motorn är inte färdigbyggd" end
	for _, r in ipairs(MopedDef.SLOT.motor.req) do
		if not m.slots[r] then return false, "Montera " .. MopedDef.SLOT[r].n:lower() .. " först" end
	end
	return true
end
-- what is missing before the moped can be ridden (panels are optional)
function MopedDef.missing(m)
	local r = {}
	for _, s in ipairs(MopedDef.SLOTS) do
		if not filled(m, s.id) then r[#r + 1] = s.n end
	end
	if m.engine then
		local em = EngineDef.missing(m.engine)
		if #em > 0 then r[#r + 1] = "Motordelar (" .. #em .. ")" end
	end
	return r
end
function MopedDef.canRide(m) return #MopedDef.missing(m) == 0 end
function MopedDef.missingPanels(m)
	local r = {}
	for _, p in ipairs(MopedDef.MODELS[m.model].panels) do if not m.slots["pan:" .. p.id] then r[#r + 1] = p.n end end
	return r
end

return MopedDef

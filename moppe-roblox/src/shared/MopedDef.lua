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
	{ "box", { 0.14, 0.62, 1.7 }, { -0.5, 2.18, 1.05 }, { 0, 0, -6 } },
	{ "wedge", { 0.14, 0.42, 0.8 }, { -0.47, 1.72, 0.45 }, { 0, 0, -6 } },
}
MopedDef.MODELS.citi = {
	id = "citi", n = "Vippa Citi 50", price = 8000, color = { 200, 30, 40 },
	wb = 4.2, r = 0.88, head = { 0, 2.65, -1.72 }, rake = 24, barY = 3.55, seat = { 0, 2.72, 1.0 }, seatLen = 1.9, tank = { 0, 2.1, 1.0 },
	floorY = 1.4, tailZ = 2.55, lights = { { 0, 2.5, -2.1 } },
	panels = {
		P("front", "Frontkåpa", 790, { "gaffel" }, {
			{ "box", { 1.15, 1.25, 0.22 }, { 0, 2.3, -2.0 }, { -18, 0, 0 } },
			{ "wedge", { 1.15, 0.5, 0.35 }, { 0, 1.55, -1.93 }, { 0, 180, 0 } },
		}),
		P("ben", "Benskydd", 590, { "ram" }, { { "box", { 1.1, 1.2, 0.14 }, { 0, 2.0, -1.72 }, { -16, 0, 0 } } }),
		P("fot", "Fotplatta", 490, { "ram" }, { { "box", { 1.0, 0.12, 1.45 }, { 0, 1.42, -0.62 } } }),
		P("sidaV", "Sidokåpa vänster", 690, { "tank" }, citiSideL),
		P("sidaH", "Sidokåpa höger", 690, { "tank" }, mirror(citiSideL)),
		P("bak", "Bakkåpa", 590, { "tank" }, { { "wedge", { 0.95, 0.5, 0.9 }, { 0, 2.4, 2.25 } }, { "box", { 0.95, 0.25, 0.4 }, { 0, 2.08, 2.5 } } }),
		P("skarm", "Framskärm", 390, { "gaffel" }, {
			{ "box", { 0.42, 0.1, 0.8 }, { 0, 1.9, -2.15 }, { 0, 0, 0 } },
			{ "box", { 0.42, 0.1, 0.5 }, { 0, 1.72, -2.68 }, { 35, 0, 0 } },
		}),
		P("styrkapa", "Styrkåpa", 490, { "styre" }, { { "box", { 1.0, 0.3, 0.55 }, { 0, 3.5, -1.62 }, { -10, 0, 0 } } }),
	},
}

-- Vippa Sprint 50: sporty scooter with a big front and a high tail
local sprintSideL = {
	{ "box", { 0.14, 0.7, 1.9 }, { -0.52, 2.2, 1.05 }, { 0, 0, -5 } },
	{ "wedge", { 0.14, 0.55, 0.9 }, { -0.5, 1.68, 0.38 }, { 0, 0, -5 } },
	{ "wedge", { 0.14, 0.45, 0.9 }, { -0.5, 2.68, 1.85 }, { 0, 180, 5 } },
}
local sprintFlankL = { { "box", { 0.12, 0.9, 0.9 }, { -0.62, 2.2, -1.75 }, { -20, -12, 0 } } }
MopedDef.MODELS.sprint = {
	id = "sprint", n = "Vippa Sprint 50", price = 12500, color = { 25, 70, 200 },
	wb = 4.5, r = 0.9, head = { 0, 2.75, -1.85 }, rake = 25, barY = 3.6, seat = { 0, 2.85, 1.05 }, seatLen = 2.1, tank = { 0, 2.15, 1.05 },
	floorY = 1.45, tailZ = 2.7, lights = { { -0.28, 2.45, -2.3 }, { 0.28, 2.45, -2.3 } },
	panels = {
		P("front", "Frontkåpa", 990, { "gaffel" }, {
			{ "wedge", { 1.25, 1.0, 0.75 }, { 0, 2.35, -2.17 }, { 0, 180, 0 } },
			{ "box", { 1.25, 0.6, 0.3 }, { 0, 2.95, -1.95 }, { -30, 0, 0 } },
			{ "wedge", { 1.2, 0.45, 0.5 }, { 0, 1.62, -2.08 }, { 180, 0, 0 } },
		}),
		P("flankV", "Frontflank vänster", 590, { "gaffel" }, sprintFlankL),
		P("flankH", "Frontflank höger", 590, { "gaffel" }, mirror(sprintFlankL)),
		P("ben", "Benskydd", 690, { "ram" }, { { "box", { 1.15, 1.25, 0.14 }, { 0, 2.08, -1.62 }, { -14, 0, 0 } } }),
		P("fot", "Fotplatta", 490, { "ram" }, { { "box", { 1.0, 0.12, 1.5 }, { 0, 1.47, -0.62 } } }),
		P("tunnel", "Tunnelkåpa", 490, { "ram" }, { { "wedge", { 0.55, 0.45, 0.9 }, { 0, 1.75, -0.1 }, { 0, 180, 0 } } }),
		P("sidaV", "Sidokåpa vänster", 790, { "tank" }, sprintSideL),
		P("sidaH", "Sidokåpa höger", 790, { "tank" }, mirror(sprintSideL)),
		P("bak", "Bakkåpa", 690, { "tank" }, { { "wedge", { 0.95, 0.55, 1.0 }, { 0, 2.6, 2.4 } }, { "box", { 0.9, 0.2, 0.35 }, { 0, 2.25, 2.75 } } }),
		P("skarm", "Framskärm", 390, { "gaffel" }, {
			{ "box", { 0.4, 0.1, 0.85 }, { 0, 1.95, -2.32 } },
			{ "box", { 0.4, 0.1, 0.5 }, { 0, 1.78, -2.85 }, { 35, 0, 0 } },
		}),
		P("styrkapa", "Styrkåpa", 590, { "styre" }, { { "wedge", { 1.05, 0.35, 0.6 }, { 0, 3.55, -1.72 }, { 0, 180, 0 } } }),
		P("under", "Underkåpa", 390, { "ram" }, { { "box", { 0.85, 0.12, 1.2 }, { 0, 1.28, -0.7 }, { 0, 0, 0 } } }),
		P("spoiler", "Bakspoiler", 490, { "tank" }, { { "box", { 0.7, 0.08, 0.45 }, { 0, 2.95, 2.75 }, { 12, 0, 0 } } }),
	},
}

-- Vippa Klassik 50: round retro scooter
local klassikSideL = { { "ball", { 1.1, 1.1, 1.1 }, { -0.42, 1.95, 1.35 } } }
MopedDef.MODELS.klassik = {
	id = "klassik", n = "Vippa Klassik 50", price = 10500, color = { 120, 200, 190 },
	wb = 4.3, r = 0.86, head = { 0, 2.7, -1.78 }, rake = 22, barY = 3.55, seat = { 0, 2.78, 1.05 }, seatLen = 1.85, tank = { 0, 2.1, 1.05 },
	floorY = 1.4, tailZ = 2.5, lights = { { 0, 3.62, -1.72 } },
	panels = {
		P("front", "Frontsköld", 890, { "gaffel" }, {
			{ "box", { 1.25, 1.6, 0.16 }, { 0, 2.2, -1.95 }, { -14, 0, 0 } },
			{ "cyl", { 0.16, 1.25, 1.25 }, { 0, 2.95, -1.78 }, { 0, 90, 76 } },
		}),
		P("fot", "Fotplatta", 490, { "ram" }, { { "box", { 1.05, 0.12, 1.45 }, { 0, 1.42, -0.62 } } }),
		P("sidaV", "Sidokåpa vänster", 790, { "tank" }, klassikSideL),
		P("sidaH", "Sidokåpa höger", 790, { "tank" }, mirror(klassikSideL)),
		P("bak", "Bakkåpa", 590, { "tank" }, { { "ball", { 0.9, 0.9, 0.9 }, { 0, 2.15, 2.15 } } }),
		P("skarm", "Framskärm", 490, { "gaffel" }, { { "ball", { 0.7, 0.7, 0.7 }, { 0, 1.75, -2.15 } } }),
		P("styrkapa", "Styrkåpa", 590, { "styre" }, { { "box", { 0.95, 0.32, 0.5 }, { 0, 3.47, -1.68 }, { -8, 0, 0 } } }),
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

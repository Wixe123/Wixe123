-- Assembly rules: engine sockets (on the engine stand) and moped mounting points (chassis + panels).
-- Each socket has a position (metres, engine space: x right, y up, z forward, origin = crankshaft centre),
-- the part kind that fits and which sockets must already be fitted. The same rules apply in reverse for removal.
-- Everything works on maps socket -> sku, so it can be tested without Roblox.
local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.Catalog)
local Panels = require(script.Parent.Panels)
local Assembly = {}

local function S(id, kind, pos, req, only, rot) return { id = id, kind = kind, pos = pos, req = req or {}, only = only, rot = rot } end
-- only = "cvt" | "dt" | "fan" (scooters with a cooling fan)
Assembly.ENGINE = {
	S("case", "case", { 0, 0, 0 }),
	S("bearings", "bearing", { 0, 0, 0 }, { "case" }),
	S("gearbox", "gearbox", { 0, -0.08, -0.1 }, { "case" }, "dt"),
	S("crank", "crank", { 0, 0, 0 }, { "bearings" }),
	S("seals", "seal", { 0, 0, 0 }, { "crank" }),
	S("needle", "needle", { 0, 0.075, 0 }, { "crank" }),
	S("piston", "piston", { 0, 0.15, 0 }, { "needle" }),
	S("pin", "pin", { 0, 0.15, 0 }, { "piston" }),
	S("rings", "rings", { 0, 0.175, 0 }, { "piston" }),
	S("gasket", "gasket", { 0, 0.205, 0 }, { "pin", "rings" }),
	S("cyl", "cyl", { 0, 0.28, 0 }, { "gasket" }),
	S("head", "head", { 0, 0.37, 0 }, { "cyl" }),
	S("plug", "plug", { 0, 0.425, 0 }, { "head" }),
	S("reed", "reed", { 0, 0.06, -0.15 }, { "case" }),
	S("intake", "intake", { 0, 0.07, -0.21 }, { "reed" }),
	S("carb", "carb", { 0, 0.08, -0.29 }, { "intake" }),
	S("filter", "filter", { 0, 0.1, -0.4 }, { "carb" }),
	S("hose", "hose", { 0.07, 0.13, -0.29 }, { "carb" }),
	S("stator", "stator", { -0.16, 0, 0 }, { "seals" }),
	S("flywheel", "flywheel", { -0.2, 0, 0 }, { "stator" }),
	S("fan", "fan", { -0.25, 0, 0 }, { "flywheel" }, "fan"),
	S("coil", "coil", { -0.08, 0.24, -0.1 }, { "case" }),
	S("cdi", "cdi", { -0.12, 0.1, -0.22 }, { "coil" }),
	S("cable", "cable", { -0.04, 0.34, -0.04 }, { "coil", "plug" }),
	S("weights", "weights", { 0.18, 0, 0 }, { "seals" }, "cvt"),
	S("var", "var", { 0.2, 0, 0 }, { "weights" }, "cvt"),
	S("contra", "contra", { 0.2, 0, -0.36 }, { "case" }, "cvt"),
	S("pulley", "pulley", { 0.2, 0, -0.36 }, { "contra" }, "cvt"),
	S("belt", "belt", { 0.22, 0, -0.18 }, { "var", "pulley" }, "cvt"),
	S("clutch", "clutch", { 0.24, 0, -0.36 }, { "pulley" }, "cvt"),
	S("bell", "bell", { 0.27, 0, -0.36 }, { "clutch", "belt" }, "cvt"),
	S("plates", "plates", { 0.18, -0.02, -0.05 }, { "gearbox", "seals" }, "dt"),
	S("sprocket", "sprocket", { -0.12, -0.06, -0.18 }, { "gearbox" }, "dt"),
}
-- DT: the crankshaft goes in after the gearbox (both sit in the case halves)
Assembly.DT_EXTRA_REQ = { crank = { "gearbox" } }

-- chassis: positions in moped space are drawn by Builder; here only order and kind
Assembly.CHASSIS = {
	S("frame", "frame"), S("fork", "fork", nil, { "frame" }), S("wheelF", "wheel", nil, { "fork" }), S("brakeF", "brake", nil, { "wheelF" }),
	S("shock", "shock", nil, { "frame" }), S("engine", "engine", nil, { "frame", "shock" }),
	S("wheelR", "wheel", nil, { "engine" }), S("brakeR", "brake", nil, { "wheelR" }),
	S("bars", "bars", nil, { "fork" }), S("seat", "seat", nil, { "frame" }), S("tank", "tank", nil, { "frame" }, "dt"),
	S("exh", "exh", nil, { "engine" }), S("radiator", "radiator", nil, { "frame" }, "rok"),
}
-- panels needing more than the frame
local PANEL_REQ = { grips = { "bars" }, barcover = { "bars" }, dash = { "bars", "pan:barcover" }, lightcover = { "frame" }, headset = { "bars" },
	rearside_l = { "pan:side_l" }, rearside_r = { "pan:side_r" }, tankcover = { "tank" }, lampmask = { "fork" }, fender_f = { "fork" }, fender_r = { "frame" } }

local function applies(s, mop)
	if not s.only then return true end
	if s.only == "cvt" then return mop.cvt end
	if s.only == "dt" then return not mop.cvt end
	if s.only == "fan" then return mop.id ~= "dt" end
	return s.only == mop.id
end

function Assembly.engineSockets(mopId)
	local mop, out = Config.BY_ID[mopId], {}
	for _, s in ipairs(Assembly.ENGINE) do
		if applies(s, mop) then
			local req = s.req
			if not mop.cvt and Assembly.DT_EXTRA_REQ[s.id] then req = {}; for _, r in ipairs(s.req) do table.insert(req, r) end; for _, r in ipairs(Assembly.DT_EXTRA_REQ[s.id]) do table.insert(req, r) end end
			table.insert(out, { id = s.id, kind = s.kind, pos = s.pos, req = req })
		end
	end
	return out
end
function Assembly.chassisSlots(mopId)
	local mop, out = Config.BY_ID[mopId], {}
	for _, s in ipairs(Assembly.CHASSIS) do if applies(s, mop) then table.insert(out, { id = s.id, kind = s.kind, req = s.req }) end end
	for _, pd in ipairs(Panels[mopId]) do table.insert(out, { id = "pan:" .. pd.id, kind = "panel", panel = pd.id, req = PANEL_REQ[pd.id] or { "frame" }, optional = true }) end
	return out
end
local function find(list, id) for _, s in ipairs(list) do if s.id == id then return s end end end
Assembly.find = find
local function label(list, id)
	if id:sub(1, 4) == "pan:" then local pd = nil; for _, s in ipairs(list) do if s.id == id then pd = s end end; return pd and pd.panel and ("kåpan " .. id:sub(5)) or id end
	if id == "engine" then return "motorn" end
	local s = find(list, id)
	return s and string.lower(Catalog.KIND[s.kind][1]) or id
end
local SLOT_NAME = { wheelF = "framhjulet", wheelR = "bakhjulet", brakeF = "frambromsen", brakeR = "bakbromsen", exh = "avgassystemet", engine = "motorn", bearings = "vevlagren", seals = "packboxarna" }
local function nameOf(list, id, mopId)
	if SLOT_NAME[id] then return SLOT_NAME[id] end
	if id:sub(1, 4) == "pan:" then local pd = Panels.find(mopId, id:sub(5)); return pd and string.lower(pd.n) or id end
	return label(list, id)
end

-- which sockets does a product fit (usually one)?
function Assembly.socketsFor(list, prod)
	local out = {}
	for _, s in ipairs(list) do
		if s.kind == prod.kind and (s.kind ~= "panel" or s.panel == prod.val.panel) then table.insert(out, s.id) end
	end
	return out
end

-- can product sku go in socket id? map = socket -> sku (fitted). Returns nil if OK, otherwise a reason in Swedish.
function Assembly.canMount(list, map, mopId, socketId, sku)
	local s = find(list, socketId)
	local prod = Catalog.BY_SKU[sku]
	if not s or not prod then return "Okänd del eller plats" end
	if prod.kind ~= s.kind or (s.kind == "panel" and prod.val.panel ~= s.panel) then return "Delen hör inte hemma här" end
	if not Catalog.fits(prod, mopId) then return "Delen passar inte " .. Config.BY_ID[mopId].n end
	if map[socketId] then return "Platsen är redan upptagen" end
	for _, r in ipairs(s.req) do
		if not map[r] then return "Montera " .. nameOf(list, r, mopId) .. " först" end
	end
	-- the piston and rings must match the cylinder (and each other)
	if s.kind == "cyl" or s.kind == "rings" then
		local pis = map.piston and Catalog.BY_SKU[map.piston]
		local bore = s.kind == "cyl" and Config.KITS[prod.val.kit + 1].cc or prod.val.bore
		if pis and pis.val.bore ~= bore then return "Kolven (" .. pis.val.bore .. " cc) passar inte " .. (s.kind == "cyl" and "cylindern" or "ringarna") .. " (" .. bore .. " cc)" end
	end
	return nil
end
-- can socket id be removed? (nothing else fitted may depend on it)
function Assembly.canRemove(list, map, mopId, socketId)
	if not map[socketId] then return "Inget monterat här" end
	for _, s in ipairs(list) do
		if map[s.id] then for _, r in ipairs(s.req) do if r == socketId then return "Ta bort " .. nameOf(list, s.id, mopId) .. " först" end end end
	end
	return nil
end
-- required sockets missing (panels are optional)
function Assembly.missing(list, map)
	local out = {}
	for _, s in ipairs(list) do if not s.optional and not map[s.id] then table.insert(out, s.id) end end
	return out
end
function Assembly.names(list, ids, mopId)
	local o = {}
	for _, id in ipairs(ids) do table.insert(o, nameOf(list, id, mopId)) end
	return o
end

-- effective engine configuration from fitted parts (+ porting result and the jet setting)
function Assembly.ecfg(engMap, chMap, jet, port)
	local c = { kit = 0, exh = 0, carb = 1, maxd = 19, fcap = 1, icap = 11000, cf = 1, rmin = 0.85, roller = 9, slip = 7500, cdt = 0, blim = 7, crankf = 1, reedf = 1, port = 0, jet = jet or 85 }
	local function take(sku) local p = sku and Catalog.BY_SKU[sku]; if p then for k, v in pairs(p.val) do c[k] = v end end end
	for _, sku in pairs(engMap or {}) do take(sku) end
	for slot, sku in pairs(chMap or {}) do if slot == "exh" or slot == "radiator" then take(sku) end end
	if port then c.port = port.deg or 0; c.portq = port.q end
	c.tmf = c.crankf * c.reedf * (c.portq and (0.9 + 0.2 * c.portq) or 1) -- careful porting gives up to +10 %, a poor job loses power
	c.jet = math.min(160, math.max(40, c.jet))
	return c
end

return Assembly

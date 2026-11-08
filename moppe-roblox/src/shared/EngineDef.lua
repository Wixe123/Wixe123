-- The two-stroke engine as sockets: where every part sits on the engine and what must be mounted first.
-- Engine space (studs): origin at the crank centre, +X = right side of the moped, +Y = up, -Z = forward.
-- The cylinder lies horizontally and points forward; the CVT runs back along the left side to the rear axle.
local Parts = require(script.Parent.Parts)
local EngineDef = {}

EngineDef.REAR_AXLE_Z = 1.75 -- rear pulley / rear wheel axle behind the crank

-- id, kind, pos {x,y,z}, rot {x,y,z} in degrees, req = sockets that must be mounted first
EngineDef.SOCKETS = {
	{ id = "vevhus", kind = "vevhus", pos = { 0, 0, 0.05 }, req = {} },
	{ id = "vevlager", kind = "vevlager", pos = { 0, 0, 0 }, req = { "vevhus" } },
	{ id = "vevaxel", kind = "vevaxel", pos = { 0, 0, 0 }, req = { "vevlager" } },
	{ id = "packbox", kind = "packbox", pos = { 0, 0, 0 }, req = { "vevaxel" } },
	{ id = "nallager", kind = "nallager", pos = { 0, 0, -0.62 }, req = { "vevaxel" } },
	{ id = "kolv", kind = "kolv", pos = { 0, 0, -0.66 }, req = { "nallager" } },
	{ id = "kolvbult", kind = "kolvbult", pos = { 0, 0, -0.62 }, req = { "kolv" } },
	{ id = "kolvringar", kind = "kolvringar", pos = { 0, 0, -0.76 }, req = { "kolv" } },
	{ id = "fotpackning", kind = "fotpackning", pos = { 0, 0, -0.47 }, req = { "vevaxel" } },
	{ id = "cylinder", kind = "cylinder", pos = { 0, 0, -0.78 }, req = { "kolvbult", "kolvringar", "fotpackning" } },
	{ id = "topplock", kind = "topplock", pos = { 0, 0, -1.17 }, req = { "cylinder" } },
	{ id = "tandstift", kind = "tandstift", pos = { 0, 0.1, -1.31 }, req = { "topplock" } },
	{ id = "reed", kind = "reed", pos = { 0, 0.5, 0.12 }, req = { "vevhus" } },
	{ id = "insug", kind = "insug", pos = { 0, 0.66, 0.2 }, req = { "reed" } },
	{ id = "forgasare", kind = "forgasare", pos = { 0, 0.82, 0.34 }, req = { "insug" } },
	{ id = "luftfilter", kind = "luftfilter", pos = { 0, 0.88, 0.78 }, req = { "forgasare" } },
	{ id = "slang", kind = "slang", pos = { 0.12, 1.0, 0.36 }, req = { "forgasare" } },
	{ id = "stator", kind = "stator", pos = { 0.56, 0, 0 }, req = { "packbox" } },
	{ id = "svanghjul", kind = "svanghjul", pos = { 0.66, 0, 0 }, req = { "stator" } },
	{ id = "cdi", kind = "cdi", pos = { 0.45, 0.5, 0.55 }, req = { "vevhus" } },
	{ id = "spole", kind = "spole", pos = { 0.42, 0.42, -0.55 }, req = { "vevhus" } },
	{ id = "tandkabel", kind = "tandkabel", pos = { 0.22, 0.32, -0.95 }, req = { "spole", "tandstift" } },
	{ id = "variator", kind = "variator", pos = { -0.66, 0, 0 }, req = { "packbox" } },
	{ id = "vikter", kind = "vikter", pos = { -0.6, 0, 0 }, req = { "variator" } },
	{ id = "flakt", kind = "flakt", pos = { -0.78, 0, 0 }, req = { "vikter" } },
	{ id = "remskiva", kind = "remskiva", pos = { -0.66, 0, 1.75 }, req = { "vevhus" } },
	{ id = "koppling", kind = "koppling", pos = { -0.72, 0, 1.75 }, req = { "remskiva" } },
	{ id = "rem", kind = "rem", pos = { -0.68, 0, 0.88 }, req = { "variator", "koppling" } },
	{ id = "klocka", kind = "klocka", pos = { -0.8, 0, 1.75 }, req = { "rem" } },
}
EngineDef.BY_ID = {}
EngineDef.ORDER = {}
for i, s in ipairs(EngineDef.SOCKETS) do
	EngineDef.BY_ID[s.id] = s
	EngineDef.ORDER[s.id] = i
	s.name = Parts.kindName(s.kind)
	s.grp = Parts.KINDS[s.kind].grp
end
EngineDef.GROUPS = { "Motorblock", "Transmission", "Insug", "Tändning" }

local function itemSku(items, uid) local it = items[uid]; return it and it.sku end
local function stat(items, map, sock, key)
	local uid = map[sock]
	local p = uid and Parts.get(itemSku(items, uid))
	return p and p.stats[key]
end

-- can part (sku) go into socket sock on engine map? returns ok, reason
function EngineDef.canMount(map, sock, sku, items)
	local s = EngineDef.BY_ID[sock]
	if not s then return false, "Okänd plats" end
	local p = Parts.get(sku)
	if not p then return false, "Okänd del" end
	if p.kind ~= s.kind then return false, p.name .. " passar inte där" end
	if map[sock] then return false, s.name .. " sitter redan på" end
	for _, r in ipairs(s.req) do
		if not map[r] then return false, "Montera " .. EngineDef.BY_ID[r].name:lower() .. " först" end
	end
	-- piston, rings and cylinder must have the same bore
	local bore = p.stats.bore
	if bore then
		for _, other in ipairs({ "kolv", "kolvringar", "cylinder" }) do
			if other ~= sock and map[other] then
				local ob = stat(items, map, other, "bore")
				if ob and math.abs(ob - bore) > 0.01 then
					return false, string.format("%s är %s mm men %s är %s mm", p.name, tostring(bore), EngineDef.BY_ID[other].name:lower(), tostring(ob))
				end
			end
		end
	end
	return true
end

-- can the part in sock be removed? (nothing mounted may depend on it)
-- mounted sockets that sit on top of sock (directly or further out), outermost first
function EngineDef.dependents(map, sock)
	local out, inSet = {}, { [sock] = true }
	local changed = true
	while changed do
		changed = false
		for _, s in ipairs(EngineDef.SOCKETS) do
			if map[s.id] and not inSet[s.id] then
				for _, r in ipairs(s.req) do
					if inSet[r] then inSet[s.id] = true; out[#out + 1] = s.id; changed = true; break end
				end
			end
		end
	end
	-- outermost (last mounted) first
	table.sort(out, function(a, b) return EngineDef.ORDER[a] > EngineDef.ORDER[b] end)
	return out
end
-- a part can always be taken off; whatever sits on it comes off too (see dependents)
function EngineDef.canRemove(map, sock)
	if not map[sock] then return false, "Inget monterat där" end
	return true
end

-- sockets that are empty, in mounting order
function EngineDef.missing(map)
	local r = {}
	for _, s in ipairs(EngineDef.SOCKETS) do if not map[s.id] then r[#r + 1] = s.id end end
	return r
end
function EngineDef.complete(map) return #EngineDef.missing(map) == 0 end
function EngineDef.isEmpty(map) return next(map) == nil end
-- the next sockets that can be mounted now (all requirements met)
function EngineDef.nextUp(map)
	local r = {}
	for _, s in ipairs(EngineDef.SOCKETS) do
		if not map[s.id] then
			local ok = true
			for _, q in ipairs(s.req) do if not map[q] then ok = false end end
			if ok then r[#r + 1] = s.id end
		end
	end
	return r
end
function EngineDef.socketForKind(kind)
	for _, s in ipairs(EngineDef.SOCKETS) do if s.kind == kind then return s.id end end
end

return EngineDef

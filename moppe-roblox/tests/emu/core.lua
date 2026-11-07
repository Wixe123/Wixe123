-- Emulator core: scheduler (virtual time, coroutines), signals, Enum and the Instance system.
-- Every property read/write and method call is checked against Roblox's API dump (api_data.lua),
-- so a misspelled property, a read-only write, a wrong value type or a non-existent method fails here
-- the same way it would in Roblox.
local T = EMU_REQUIRE("datatypes")
local API = EMU_REQUIRE("api_data")
local E = { T = T, API = API }

E.now = 0 -- virtual seconds
E.frame = 0
E.errors = {} -- game errors {msg, trace}
E.warnings = {}
E.gaps = {} -- features the emulator does not implement (not game errors)
E.log = {}
local function out(kind, msg)
	E.log[#E.log + 1] = kind .. ": " .. msg
	if E.echo then E.echo(kind, msg) end
end
E.out = out
function E.gap(what)
	if not E.gaps[what] then E.gaps[what] = true; out("GAP", what) end
end

---------------------------------------------------------------- scheduler
local threadCtx = setmetatable({}, { __mode = "k" }) -- thread -> context
E.threadCtx = threadCtx
local sleeping = {} -- {co=, at=, args=}
local deferred = {}
E.ctx = nil -- context of the running thread

local function traceOf(co, msg)
	local tb = debug.traceback(co, tostring(msg))
	return tb
end

function E.reportError(msg, trace, ctx)
	local s = tostring(msg)
	E.errors[#E.errors + 1] = { msg = s, trace = trace, ctx = ctx and ctx.name }
	out("ERROR", "[" .. (ctx and ctx.name or "?") .. "] " .. s .. (trace and ("\n" .. trace) or ""))
end

local resume
resume = function(co, ...)
	local prev = E.ctx
	E.ctx = threadCtx[co] or prev
	local res = table.pack(coroutine.resume(co, ...))
	E.ctx = prev
	if not res[1] then
		E.reportError(res[2], traceOf(co, ""), threadCtx[co])
		return
	end
	if coroutine.status(co) == "suspended" then
		local req = res[2]
		if type(req) == "table" and req.__wait then
			sleeping[#sleeping + 1] = { co = co, at = E.now + req.t, t0 = E.now }
		end
		-- other yields (signal :Wait, WaitForChild) are resumed by their owners
	end
end
E.resume = resume

function E.spawn(f, ctx, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	threadCtx[co] = threadCtx[co] or ctx or E.ctx
	resume(co, ...)
	return co
end

function E.defer(f, ctx, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	threadCtx[co] = threadCtx[co] or ctx or E.ctx
	deferred[#deferred + 1] = { co = co, args = table.pack(...) }
	return co
end

function E.delay(t, f, ctx, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	threadCtx[co] = threadCtx[co] or ctx or E.ctx
	local args = table.pack(...)
	sleeping[#sleeping + 1] = { co = co, at = E.now + (t or 0), args = args, t0 = E.now }
	return co
end

function E.wait(t)
	t = math.max(t or 0, 1 / 60)
	local co, main = coroutine.running()
	if main or not coroutine.isyieldable() then error("attempt to yield across a non-yieldable boundary (wait outside a thread)", 2) end
	local t0 = E.now
	coroutine.yield({ __wait = true, t = t })
	return E.now - t0, E.now
end

function E.cancel(co)
	for i = #sleeping, 1, -1 do if sleeping[i].co == co then table.remove(sleeping, i) end end
	for i = #deferred, 1, -1 do if deferred[i].co == co then table.remove(deferred, i) end end
	E.cancelled = E.cancelled or setmetatable({}, { __mode = "k" })
	E.cancelled[co] = true
end

function E.runDeferred()
	local n = 0
	while #deferred > 0 and n < 10000 do
		local d = table.remove(deferred, 1)
		n = n + 1
		if coroutine.status(d.co) == "suspended" then resume(d.co, table.unpack(d.args, 1, d.args.n)) end
	end
end

function E.wakeSleepers()
	local ready = {}
	for i = #sleeping, 1, -1 do
		local s = sleeping[i]
		if s.at <= E.now + 1e-9 then table.remove(sleeping, i); ready[#ready + 1] = s end
	end
	table.sort(ready, function(a, b) return a.at < b.at end)
	for _, s in ipairs(ready) do
		if coroutine.status(s.co) == "suspended" and not (E.cancelled and E.cancelled[s.co]) then
			if s.args then resume(s.co, table.unpack(s.args, 1, s.args.n))
			else resume(s.co, E.now - s.t0, E.now) end
		end
	end
end

---------------------------------------------------------------- signals
local Sig = {}
Sig.__index = Sig
T.TYPE[Sig] = "RBXScriptSignal"
local Conn = {}
T.TYPE[Conn] = "RBXScriptConnection"
Conn.__index = function(c, k)
	if k == "Connected" then return c.on end
	if k == "Disconnect" then return function(self) self.on = false end end
	error(tostring(k) .. " is not a valid member of RBXScriptConnection", 2)
end
function E.signal(name) return setmetatable({ name = name, conns = {}, waiting = {} }, Sig) end
function Sig.Connect(s, f)
	if type(f) ~= "function" then error("Attempt to connect failed: Passed value is not a function", 2) end
	local c = setmetatable({ f = f, on = true, ctx = E.ctx }, Conn)
	s.conns[#s.conns + 1] = c
	return c
end
function Sig.Once(s, f)
	local c
	c = Sig.Connect(s, function(...) c.on = false; f(...) end)
	return c
end
Sig.ConnectParallel = Sig.Connect
function Sig.Wait(s)
	local co, main = coroutine.running()
	if main then error("Wait called outside a thread", 2) end
	s.waiting[#s.waiting + 1] = co
	return coroutine.yield({ __signal = true })
end
-- fire: every connection runs in its own thread; ctxFilter limits delivery to one side (server/client)
function E.fire(s, ...)
	if not s then return end
	local list = s.conns
	local alive = {}
	for _, c in ipairs(list) do if c.on then alive[#alive + 1] = c end end
	s.conns = alive
	for _, c in ipairs(alive) do
		if c.on then
			local co = coroutine.create(c.f)
			threadCtx[co] = c.ctx
			resume(co, ...)
		end
	end
	local w = s.waiting
	s.waiting = {}
	for _, co in ipairs(w) do if coroutine.status(co) == "suspended" then resume(co, ...) end end
end
function E.hasListeners(s) for _, c in ipairs(s.conns) do if c.on then return true end end return #s.waiting > 0 end

---------------------------------------------------------------- Enum
local EnumItemMt, EnumTypeMt = {}, {}
T.TYPE[EnumItemMt] = "EnumItem"
T.TYPE[EnumTypeMt] = "Enum"
local enumTypes = {}
EnumItemMt.__index = function(i, k)
	if k == "Name" then return i.n elseif k == "Value" then return i.v elseif k == "EnumType" then return i.et end
	if k == "IsA" then return function(self, n) return self.et.n == n end end
	error(tostring(k) .. " is not a valid member of EnumItem", 2)
end
EnumItemMt.__newindex = function() error("EnumItem is read-only", 2) end
EnumItemMt.__tostring = function(i) return "Enum." .. i.et.n .. "." .. i.n end
EnumTypeMt.__index = function(et, k)
	if k == "GetEnumItems" then return function(self) local r = {}; for _, it in pairs(self.items) do r[#r + 1] = it end table.sort(r, function(a, b) return a.v < b.v end) return r end end
	if k == "FromName" then return function(self, n) return self.items[n] end end
	if k == "FromValue" then return function(self, v) for _, it in pairs(self.items) do if it.v == v then return it end end end end
	local it = et.items[k]
	if it then return it end
	error(tostring(k) .. " is not a valid EnumItem of Enum." .. et.n, 2)
end
EnumTypeMt.__tostring = function(et) return et.n end
for name, items in pairs(API.E) do
	local et = setmetatable({ n = name, items = {} }, EnumTypeMt)
	for iname, v in pairs(items) do et.items[iname] = setmetatable({ n = iname, v = v, et = et }, EnumItemMt) end
	enumTypes[name] = et
end
local EnumsMt = {}
T.TYPE[EnumsMt] = "Enums"
E.Enum = setmetatable({}, { __index = function(_, k)
	local et = enumTypes[k]
	if not et then error(tostring(k) .. " is not a valid member of \"Enum\"", 2) end
	return et
end, __newindex = function() error("Enum is read-only", 2) end })
function E.isEnumItem(v) return getmetatable(v) == EnumItemMt end
function E.enumItem(typeName, nameOrValue)
	local et = enumTypes[typeName]
	if not et then return nil end
	if type(nameOrValue) == "string" then return et.items[nameOrValue] end
	for _, it in pairs(et.items) do if it.v == nameOrValue then return it end end
end

---------------------------------------------------------------- Instance system
local C = API.C
local Inst = {}
E.InstMt = Inst
T.TYPE[Inst] = "Instance"
E.METHODS = {} -- class -> name -> function(self, ...)
E.GETTERS = {} -- class -> prop -> function(self)
E.SETTERS = {} -- class -> prop -> function(self, v) (after validation; return true to skip storing)
E.DEFAULTS = {} -- class -> prop -> value or function(self)
E.CREATED = {} -- class -> function(self) after creation
local ids = 0

local function isInst(v) return getmetatable(v) == Inst end
E.isInst = isInst

local function classChain(cls)
	local chain = {}
	while cls and C[cls] do chain[#chain + 1] = cls; cls = C[cls].s end
	return chain
end
local chainCache = {}
local function chainOf(cls)
	local ch = chainCache[cls]
	if not ch then ch = classChain(cls); chainCache[cls] = ch end
	return ch
end
E.chainOf = chainOf
function E.isA(cls, base)
	for _, c in ipairs(chainOf(cls)) do if c == base then return true end end
	return false
end

-- member lookup: returns kind ("p","m","e","c"), info
local memberCache = {}
local function member(cls, k)
	local key = cls .. "." .. k
	local hit = memberCache[key]
	if hit ~= nil then return hit[1], hit[2] end
	local kind, info = false, nil
	for _, c in ipairs(chainOf(cls)) do
		local d = C[c]
		if d.p[k] then kind, info = "p", d.p[k]; break end
		for _, m in ipairs(d.m) do if m == k then kind = "m"; break end end
		if kind then break end
		for _, m in ipairs(d.e) do if m == k then kind = "e"; break end end
		if kind then break end
		for _, m in ipairs(d.c) do if m == k then kind = "c"; break end end
		if kind then break end
	end
	memberCache[key] = { kind, info }
	return kind, info
end
E.member = member

local function lookup(tbl, cls, k)
	for _, c in ipairs(chainOf(cls)) do
		local t = tbl[c]
		if t and t[k] ~= nil then return t[k] end
	end
end
E.lookup = lookup

local typeDefault = {
	bool = false, float = 0, double = 0, int = 0, int64 = 0, string = "",
}
local function defaultFor(o, k, info)
	local d = lookup(E.DEFAULTS, o.cls, k)
	if d ~= nil then
		if type(d) == "function" then return d(o) end
		return d
	end
	local cat, tn = info[1], info[2]
	if cat == "Primitive" then return typeDefault[tn] end
	if cat == "Enum" then
		local et = enumTypes[tn]
		if et then
			local best
			for _, it in pairs(et.items) do if not best or it.v < best.v then best = it end end
			return best
		end
		return nil
	end
	if cat == "DataType" then
		if tn == "Vector3" then return T.Vector3.zero
		elseif tn == "Vector2" then return T.Vector2.zero
		elseif tn == "CFrame" then return T.CFrame.identity
		elseif tn == "Color3" then return T.Color3.new(0, 0, 0)
		elseif tn == "UDim2" then return T.UDim2.new()
		elseif tn == "UDim" then return T.UDim.new()
		elseif tn == "Content" or tn == "ContentId" then return ""
		elseif tn == "NumberRange" then return T.NumberRange.new(0, 0)
		elseif tn == "NumberSequence" then return T.NumberSequence.new(0)
		elseif tn == "ColorSequence" then return T.ColorSequence.new(T.Color3.new(1, 1, 1))
		elseif tn == "Rect" then return T.Rect.new(0, 0, 0, 0)
		elseif tn == "Font" then return T.Font.new("rbxasset://fonts/families/LegacyArial.json")
		end
		return nil
	end
	return nil
end

local function valueTypeOk(info, v)
	local cat, tn = info[1], info[2]
	if cat == "Primitive" then
		if tn == "bool" then return type(v) == "boolean"
		elseif tn == "string" then return type(v) == "string" or type(v) == "number"
		else return type(v) == "number" end
	elseif cat == "Enum" then
		if E.isEnumItem(v) then return v.et.n == tn end
		if type(v) == "number" then return E.enumItem(tn, v) ~= nil end
		if type(v) == "string" then return E.enumItem(tn, v) ~= nil end
		return false
	elseif cat == "DataType" then
		local got = T.typeName(v) or type(v)
		if tn == "Content" or tn == "ContentId" then return type(v) == "string" end
		if tn == "BinaryString" or tn == "SharedString" then return type(v) == "string" end
		return got == tn
	elseif cat == "Class" then
		if v == nil then return true end
		return isInst(v) and E.isA(v.cls, tn)
	end
	return true
end

local function fullName(o)
	local parts = {}
	local x = o
	while x and x.cls ~= "DataModel" do
		table.insert(parts, 1, x.props.Name)
		x = x.parent
	end
	return table.concat(parts, ".")
end
E.fullName = fullName

function E.signalOf(o, name)
	local s = o.sig[name]
	if not s then s = E.signal(name); o.sig[name] = s end
	return s
end
local function fireEv(o, name, ...)
	local s = o.sig[name]
	if s then E.fire(s, ...) end
end
E.fireEv = fireEv

local function changed(o, k)
	fireEv(o, "Changed", k)
	local ps = o.psig and o.psig[k]
	if ps then E.fire(ps) end
end
E.changed = changed

-- emulator-internal fields stored on instance tables (lowercase, never Roblox members)
local INTERNAL = {}
for _, k in ipairs({ "parent", "cframe", "locked", "terrain", "ctx", "L", "seat", "occupant", "byName", "destroyed", "owner", "source", "extra", "scale",
	"psig", "asig", "tsig", "playing", "mouseObj", "canvasW", "canvasH", "contentSize", "kicked", "fallWarned", "emitted", "jdirty" }) do INTERNAL[k] = true end
E.INTERNAL = INTERNAL
Inst.__index = function(o, k)
	if type(k) ~= "string" then error("invalid key to Instance index: " .. tostring(k), 2) end
	if INTERNAL[k] then return nil end
	if k == "Name" then return o.props.Name end
	if k == "Parent" then return o.parent end
	if k == "ClassName" then return o.cls end
	local g = lookup(E.GETTERS, o.cls, k)
	if g then return g(o) end
	local kind, info = member(o.cls, k)
	if kind == "p" then
		local v = o.props[k]
		if v == nil and not o.nilProps[k] then
			v = defaultFor(o, k, info)
		end
		return v
	elseif kind == "m" then
		local f = lookup(E.METHODS, o.cls, k)
		if f then return f end
		return function() E.gap("method " .. o.cls .. ":" .. k); error("EMU: " .. o.cls .. ":" .. k .. " is not implemented in the emulator", 2) end
	elseif kind == "e" then
		return E.signalOf(o, k)
	elseif kind == "c" then
		error(k .. " is a callback member of " .. o.cls .. "; you can only set the callback value, get is not available", 2)
	end
	-- extra emulator-only methods with Roblox names that the dump lists under a deprecated/lowercase alias
	local f = lookup(E.METHODS, o.cls, k)
	if f then return f end
	local child = o.byName and o.byName(k)
	if child then return child end
	error(k .. " is not a valid member of " .. o.cls .. " \"" .. fullName(o) .. "\"", 2)
end

local function setParent(o, p)
	if p ~= nil and not isInst(p) then error("Parent must be an Instance or nil", 3) end
	if o.locked then error("The Parent property of " .. o.props.Name .. " is locked, current parent: " .. tostring(o.parent and o.parent.props.Name) .. ", new parent " .. tostring(p and p.props.Name), 3) end
	if p == o then error("Attempt to set " .. fullName(o) .. " as its own parent", 3) end
	local x = p
	while x do
		if x == o then error("Attempt to set parent of " .. fullName(o) .. " to " .. fullName(p) .. " would result in circular reference", 3) end
		x = x.parent
	end
	local old = o.parent
	if old == p then return end
	if old then
		for i, c in ipairs(old.children) do if c == o then table.remove(old.children, i); break end end
		local a = old
		while a do fireEv(a, "DescendantRemoving", o); a = a.parent end
		fireEv(old, "ChildRemoved", o)
	end
	o.parent = p
	if p then
		p.children[#p.children + 1] = o
	end
	if E.onReparent then E.onReparent(o, old, p) end
	fireEv(o, "AncestryChanged", o, p)
	local function anc(d) for _, c in ipairs(d.children) do fireEv(c, "AncestryChanged", o, p); anc(c) end end
	anc(o)
	changed(o, "Parent")
	if p then
		fireEv(p, "ChildAdded", o)
		local function desc(d)
			local a = p
			while a do fireEv(a, "DescendantAdded", d); a = a.parent end
			for _, c in ipairs(d.children) do desc(c) end
		end
		desc(o)
	end
end
E.setParent = setParent

Inst.__newindex = function(o, k, v)
	if INTERNAL[k] then rawset(o, k, v); return end
	if k == "Parent" then return setParent(o, v) end
	if k == "Name" then
		if type(v) ~= "string" and type(v) ~= "number" then error("Unable to assign property Name. string expected, got " .. type(v), 2) end
		o.props.Name = tostring(v)
		changed(o, "Name")
		return
	end
	local kind, info = member(o.cls, k)
	if kind == "c" then
		if v ~= nil and type(v) ~= "function" then error("Unable to assign callback " .. k .. ": function expected", 2) end
		o.callbacks[k] = v
		return
	end
	if kind ~= "p" then
		if kind then error("Unable to assign property " .. k .. ". It is not a property of " .. o.cls, 2) end
		error(k .. " is not a valid member of " .. o.cls .. " \"" .. fullName(o) .. "\"", 2)
	end
	if info[3] == 1 and not E.trusted then
		error("Unable to assign property " .. k .. ". Property is read only", 2)
	end
	if v == nil then
		if info[1] ~= "Class" then error("Unable to assign property " .. k .. ". " .. info[2] .. " expected, got nil", 2) end
	elseif not valueTypeOk(info, v) then
		local got = isInst(v) and v.cls or (T.typeName(v) or type(v))
		error("Unable to assign property " .. k .. ". " .. info[2] .. " expected, got " .. got, 2)
	end
	if info[4] == 1 then E.warnOnce("deprecated property " .. o.cls .. "." .. k) end
	if info[1] == "Enum" and not E.isEnumItem(v) then v = E.enumItem(info[2], v) end
	if info[1] == "Primitive" and info[2] == "string" then v = tostring(v) end
	if info[1] == "Primitive" and (info[2] == "int" or info[2] == "int64") then v = math.floor(v) end
	local s = lookup(E.SETTERS, o.cls, k)
	if s and s(o, v) then changed(o, k); return end
	o.props[k] = v
	if v == nil then o.nilProps[k] = true else o.nilProps[k] = nil end
	changed(o, k)
end
Inst.__tostring = function(o) return o.props.Name end

function E.warnOnce(w)
	E.warned = E.warned or {}
	if not E.warned[w] then E.warned[w] = true; E.warnings[#E.warnings + 1] = w; out("WARN", w) end
end

function E.new(cls, parent, raw)
	local d = C[cls]
	if not d then error("Unable to create an Instance of type \"" .. tostring(cls) .. "\"", 2) end
	if not raw then
		for _, t in ipairs(d.t) do
			if t == "NotCreatable" or t == "Service" then error("Unable to create an Instance of type \"" .. cls .. "\"", 2) end
		end
		for _, t in ipairs(d.t) do if t == "Deprecated" then E.warnOnce("deprecated class " .. cls) end end
	end
	ids = ids + 1
	local o = setmetatable({ cls = cls, props = { Name = cls }, nilProps = {}, children = {}, sig = {}, attrs = {}, callbacks = {}, tags = {}, id = ids }, Inst)
	o.byName = function(n) for _, c in ipairs(o.children) do if c.props.Name == n then return c end end end
	local ch = chainOf(cls)
	for i = #ch, 1, -1 do
		local f = E.CREATED[ch[i]]
		if f then f(o) end
	end
	if parent ~= nil then setParent(o, parent) end
	return o
end

return E

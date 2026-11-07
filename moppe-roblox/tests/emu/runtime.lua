-- Emulator runtime: the DataModel, script environments (Luau globals), players and characters,
-- the frame loop, and input simulation (keys, mouse, GUI clicks, proximity prompts, seats).
local E = EMU_REQUIRE("gui")
local T = E.T
local V3, V2, CF, C3 = T.Vector3, T.Vector2, T.CFrame, T.Color3
local M, G, S, D = E.METHODS, E.GETTERS, E.SETTERS, E.DEFAULTS
local Ins = M.Instance
local function cls(t, c) t[c] = t[c] or {}; return t[c] end

---------------------------------------------------------------- DataModel
local game = E.new("DataModel", nil, true)
game.props.Name = "Game"
game.locked = true
E.game = game
local function addSvc(n)
	local s = E.svc(n)
	s.parent = game
	table.insert(game.children, s)
	return s
end
for _, n in ipairs({ "Workspace", "Players", "Lighting", "ReplicatedStorage", "ReplicatedFirst", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "SoundService", "RunService", "UserInputService", "TweenService", "DataStoreService", "PhysicsService", "CollectionService", "Debris", "HttpService", "TextService", "ContextActionService", "GuiService", "ProximityPromptService", "MarketplaceService", "Teams", "Chat" }) do addSvc(n) end
local ws = E.services.Workspace
local terrain = E.new("Terrain", nil, true)
terrain.props.Name = "Terrain"
terrain.locked = true
terrain.parent = ws
table.insert(ws.children, terrain)
ws.terrain = terrain
local sp = E.services.StarterPlayer
local sps = E.new("StarterPlayerScripts", nil, true); sps.props.Name = "StarterPlayerScripts"; sps.parent = sp; table.insert(sp.children, sps); sps.locked = true
local scs = E.new("StarterCharacterScripts", nil, true); scs.props.Name = "StarterCharacterScripts"; scs.parent = sp; table.insert(sp.children, scs); scs.locked = true

---------------------------------------------------------------- Luau globals
local function typeof(v)
	if E.isInst(v) then return "Instance" end
	local tn = T.typeName(v)
	if tn then return tn end
	return type(v)
end
E.typeof = typeof

local luauString = setmetatable({}, { __index = string })
luauString.split = function(s, sep)
	sep = sep or ","
	local r = {}
	if sep == "" then for c in s:gmatch(".") do r[#r + 1] = c end return r end
	local i = 1
	while true do
		local a, b = s:find(sep, i, true)
		if not a then r[#r + 1] = s:sub(i); break end
		r[#r + 1] = s:sub(i, a - 1)
		i = b + 1
	end
	return r
end
luauString.format = function(fmt, ...)
	local args = table.pack(...)
	local i = 0
	for spec in fmt:gmatch("%%[-+ #0]*%d*%.?%d*[%a%%]") do
		local c = spec:sub(-1)
		if c ~= "%" then
			i = i + 1
			local a = args[i]
			if (c == "d" or c == "i" or c == "x" or c == "X" or c == "c" or c == "o") and type(a) == "number" and math.floor(a) ~= a then
				E.warnOnce("string.format " .. spec .. " got non-integer " .. tostring(a) .. " (Luau truncates it, check the intent)")
				args[i] = a >= 0 and math.floor(a) or math.ceil(a)
			elseif (c == "d" or c == "f" or c == "g" or c == "x") and type(a) ~= "number" then
				if type(a) == "string" and tonumber(a) then args[i] = tonumber(a)
				else error("bad argument #" .. (i + 1) .. " to 'format' (number expected, got " .. typeof(a) .. ")", 2) end
			elseif c == "s" and a == nil and i > args.n then
				error("bad argument #" .. (i + 1) .. " to 'format' (string expected, got no value)", 2)
			end
		end
	end
	return string.format(fmt, table.unpack(args, 1, args.n))
end
local luauTable = setmetatable({}, { __index = table })
luauTable.find = function(t, v, init) for i = init or 1, #t do if t[i] == v then return i end end return nil end
luauTable.clear = function(t) for k in pairs(t) do t[k] = nil end end
luauTable.create = function(n, v) local r = {}; for i = 1, n do r[i] = v end return r end
luauTable.clone = function(t) local r = {}; for k, v in pairs(t) do r[k] = v end return setmetatable(r, getmetatable(t)) end
luauTable.freeze = function(t) return t end
luauTable.isfrozen = function() return false end
luauTable.getn = nil
luauTable.foreach = nil
local luauMath = setmetatable({}, { __index = math })
luauMath.clamp = function(x, a, b)
	if type(x) ~= "number" or type(a) ~= "number" or type(b) ~= "number" then error("invalid argument to math.clamp (number expected)", 2) end
	if a > b then error("max must be greater than or equal to min", 2) end
	return math.max(a, math.min(b, x))
end
luauMath.round = function(x) if x >= 0 then return math.floor(x + 0.5) end return math.ceil(x - 0.5) end
luauMath.sign = function(x) return x > 0 and 1 or (x < 0 and -1 or 0) end
luauMath.atan2 = function(y, x) return math.atan(y, x) end
luauMath.pow = nil
luauMath.ldexp = function(m, e) return m * 2 ^ e end
luauMath.log10 = function(x) return math.log(x, 10) end
luauMath.noise = function(x, y, z)
	local n = math.sin((x or 0) * 12.9898 + (y or 0) * 78.233 + (z or 0) * 37.719) * 43758.5453
	return (n - math.floor(n)) - 0.5
end
luauMath.random = function(a, b)
	if a and math.floor(a) ~= a then error("bad argument #1 to 'random' (number has no integer representation)", 2) end
	if a and b then return math.random(math.floor(a), math.floor(b)) elseif a then return math.random(math.floor(a)) end
	return math.random()
end
local luauOs = { time = os.time, date = os.date, difftime = os.difftime, clock = function() return E.now end }

local function makeTask()
	return {
		spawn = function(f, ...) if type(f) ~= "function" and type(f) ~= "thread" then error("invalid argument #1 to 'spawn' (function or thread expected)", 2) end return E.spawn(f, nil, ...) end,
		defer = function(f, ...) return E.defer(f, nil, ...) end,
		delay = function(t, f, ...) return E.delay(t, f, nil, ...) end,
		wait = function(t) return E.wait(t) end,
		cancel = function(co) E.cancel(co) end,
		synchronize = function() end,
		desynchronize = function() end,
	}
end

local DM_G = cls(G, "DataModel")
function E.makeGlobals(ctx)
	local g = {}
	for _, k in ipairs({ "assert", "error", "getmetatable", "ipairs", "next", "pairs", "pcall", "rawequal", "rawget", "rawset", "rawlen", "select", "setmetatable", "tonumber", "tostring", "type", "xpcall", "coroutine", "utf8" }) do g[k] = _G[k] end
	g.string, g.table, g.math, g.os = luauString, luauTable, luauMath, luauOs
	g.unpack = table.unpack
	g.debug = { traceback = debug.traceback, info = function() return "?" end, profilebegin = function() end, profileend = function() end, setmemorycategory = function() end }
	g.bit32 = nil
	g.game, g.Game = game, game
	g.workspace, g.Workspace = ws, ws
	g.Instance = { new = function(c, parent)
		if type(c) ~= "string" then error("Instance.new: class name string expected", 2) end
		local ok, r = pcall(E.new, c, nil)
		if not ok then error(r, 2) end
		if parent ~= nil then E.warnOnce("Instance.new with parent argument (slow pattern; set Parent last)"); r.Parent = parent end
		return r
	end, fromExisting = function(o) return Ins.Clone(o) end }
	for _, k in ipairs({ "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "NumberRange", "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "Rect", "TweenInfo", "RaycastParams", "OverlapParams", "PhysicalProperties", "Random", "Font", "BrickColor" }) do g[k] = T[k] end
	g.Ray = { new = function(o, d) return setmetatable({ _Origin = o, _Direction = d }, E.RayMt) end }
	g.Enum = E.Enum
	g.typeof = typeof
	g.task = makeTask()
	g.wait = function(t) E.warnOnce("deprecated wait() (use task.wait)"); return E.wait(t) end
	g.delay = function(t, f) E.warnOnce("deprecated delay()"); return E.delay(t, f) end
	g.spawn = function(f) E.warnOnce("deprecated spawn()"); return E.delay(0, f) end
	g.tick = function() return 1.7e9 + E.now end
	g.time = function() return E.now end
	g.elapsedTime = function() return E.now end
	g.print = function(...) local t = table.pack(...); for i = 1, t.n do t[i] = tostring(t[i]) end E.out("PRINT", "[" .. ctx.name .. "] " .. table.concat(t, " ")) end
	g.warn = function(...) local t = table.pack(...); for i = 1, t.n do t[i] = tostring(t[i]) end E.out("WARNING", "[" .. ctx.name .. "] " .. table.concat(t, " ")) end
	g.shared = {}
	g._G = g
	g.newproxy = function() return setmetatable({}, {}) end
	g.gcinfo = function() return 0 end
	g.collectgarbage = function(o) if o == "count" then return 0 end end
	g.settings = function() return setmetatable({}, { __index = function() return setmetatable({}, { __index = function() return 0 end }) end }) end
	g.UserSettings = g.settings
	g.require = function(m)
		if not E.isInst(m) then error("Attempted to call require with invalid argument(s).", 2) end
		if m.cls ~= "ModuleScript" then error("Attempted to call require with a non-ModuleScript", 2) end
		local cache = ctx.cache
		local c = cache[m]
		if c then
			if c.loading then error("Requested module was required recursively: " .. E.fullName(m), 2) end
			return c.value
		end
		c = { loading = true }
		cache[m] = c
		local env = setmetatable({ script = m }, { __index = g })
		local f, err = load(m.source or "", "=" .. E.fullName(m), "t", env)
		if not f then cache[m] = nil; error("Syntax error in " .. E.fullName(m) .. ": " .. tostring(err), 2) end
		local r = table.pack(pcall(f))
		if not r[1] then cache[m] = nil; error("Requested module experienced an error while loading: " .. tostring(r[2]), 2) end
		if r.n ~= 2 then cache[m] = nil; error("Module code did not return exactly one value: " .. E.fullName(m), 2) end
		c.loading = false
		c.value = r[2]
		return r[2]
	end
	return g
end
cls(G, "LuaSourceContainer")
D.BaseScript = { Disabled = false, Enabled = true }
cls(S, "LuaSourceContainer").Source = function(o, v) o.source = v; return true end

function E.runScript(s, ctx)
	ctx.globals = ctx.globals or E.makeGlobals(ctx)
	local env = setmetatable({ script = s }, { __index = ctx.globals })
	local f, err = load(s.source or "", "=" .. E.fullName(s), "t", env)
	if not f then E.reportError("Syntax error: " .. tostring(err), nil, ctx); return end
	E.spawn(f, ctx)
end

---------------------------------------------------------------- loading the project
-- items: { {kind="module"|"server"|"client"|"clientmodule"|"servermodule", name=, source=, folder=} }
function E.loadProject(items)
	local shared = E.new("Folder", nil, true)
	shared.props.Name = "Shared"
	E.setParent(shared, E.services.ReplicatedStorage)
	for _, it in ipairs(items) do
		local cname = (it.kind == "server" and "Script") or (it.kind == "client" and "LocalScript") or "ModuleScript"
		local s = E.new(cname, nil, true)
		s.props.Name = it.name
		s.source = it.source
		local parent
		if it.kind == "module" then parent = shared
		elseif it.kind == "server" or it.kind == "servermodule" then parent = E.services.ServerScriptService
		else parent = sps end
		E.setParent(s, parent)
	end
end
function E.startServer()
	for _, s in ipairs(Ins.GetDescendants(E.services.ServerScriptService)) do
		if s.cls == "Script" and not s.props.Disabled then E.runScript(s, E.serverCtx) end
	end
	for _, s in ipairs(Ins.GetDescendants(ws)) do
		if s.cls == "Script" and not s.props.Disabled then E.runScript(s, E.serverCtx) end
	end
end

---------------------------------------------------------------- players and characters
local function part(name, size, parent, cf)
	local p = E.new("Part", nil, true)
	p.props.Name = name
	p.props.Size = size
	p.cframe = cf or CF.identity
	p.props.Color = C3.fromRGB(234, 184, 146)
	E.setParent(p, parent)
	return p
end
function E.spawnCharacter(plr)
	local old = plr.props.Character
	if old and not old.destroyed then Ins.Destroy(old) end
	local ch = E.new("Model", nil, true)
	ch.props.Name = plr.props.Name
	local spawnCF = CF.new(0, 5, 0)
	for _, d in ipairs(Ins.GetDescendants(ws)) do
		if d.cls == "SpawnLocation" and d.props.Enabled ~= false then spawnCF = d.cframe + V3.new(0, d.props.Size.Y / 2 + 3, 0); break end
	end
	local root = part("HumanoidRootPart", V3.new(2, 2, 1), ch, spawnCF)
	root.props.Transparency = 1
	root.props.CanCollide = false
	local function limb(n, size, off, color)
		local p = part(n, size, ch, spawnCF * CF.new(off))
		if color then p.props.Color = color end
		local w = E.new("Motor6D", nil, true)
		w.props.Name = n .. "Joint"
		w.props.Part0 = root; w.props.Part1 = p; w.props.C0 = CF.new(off)
		E.setParent(w, p)
		return p
	end
	local shirt, pants = C3.fromRGB(30, 30, 34), C3.fromRGB(40, 50, 70)
	limb("LowerTorso", V3.new(2, 0.4, 1), V3.new(0, -0.8, 0), pants)
	limb("UpperTorso", V3.new(2, 1.6, 1), V3.new(0, 0.2, 0), shirt)
	limb("Head", V3.new(1.2, 1.2, 1.2), V3.new(0, 1.6, 0))
	limb("LeftUpperArm", V3.new(1, 1.2, 1), V3.new(-1.5, 0.4, 0), shirt)
	limb("LeftLowerArm", V3.new(1, 1.1, 1), V3.new(-1.5, -0.6, 0), shirt)
	limb("LeftHand", V3.new(1, 0.3, 1), V3.new(-1.5, -1.3, 0))
	limb("RightUpperArm", V3.new(1, 1.2, 1), V3.new(1.5, 0.4, 0), shirt)
	limb("RightLowerArm", V3.new(1, 1.1, 1), V3.new(1.5, -0.6, 0), shirt)
	limb("RightHand", V3.new(1, 0.3, 1), V3.new(1.5, -1.3, 0))
	limb("LeftUpperLeg", V3.new(1, 1.2, 1), V3.new(-0.5, -1.6, 0), pants)
	limb("LeftLowerLeg", V3.new(1, 1.1, 1), V3.new(-0.5, -2.5, 0), pants)
	limb("LeftFoot", V3.new(1, 0.3, 1), V3.new(-0.5, -2.9, 0), C3.fromRGB(20, 20, 20))
	limb("RightUpperLeg", V3.new(1, 1.2, 1), V3.new(0.5, -1.6, 0), pants)
	limb("RightLowerLeg", V3.new(1, 1.1, 1), V3.new(0.5, -2.5, 0), pants)
	limb("RightFoot", V3.new(1, 0.3, 1), V3.new(0.5, -2.9, 0), C3.fromRGB(20, 20, 20))
	E.jointDirty = true
	local hum = E.new("Humanoid", nil, true)
	E.setParent(hum, ch)
	local anim = E.new("Animator", nil, true)
	E.setParent(anim, hum)
	ch.props.PrimaryPart = root
	E.setParent(ch, ws)
	plr.props.Character = ch
	E.changed(plr, "Character")
	-- character scripts
	for _, s in ipairs(scs.children) do
		local c = Ins.Clone(s)
		E.setParent(c, ch)
		if c.cls == "LocalScript" then E.runScript(c, plr.ctx) elseif c.cls == "Script" then E.runScript(c, E.serverCtx) end
	end
	E.fireEv(plr, "CharacterAdded", ch)
	E.fireEv(plr, "CharacterAppearanceLoaded", ch)
	return ch
end
cls(G, "Humanoid").RootPart = function(o) return o.parent and Ins.FindFirstChild(o.parent, "HumanoidRootPart") end
cls(G, "Humanoid").SeatPart = function(o) return o.seat end
cls(G, "Humanoid").Sit = function(o) return o.seat ~= nil end
cls(G, "Humanoid").MoveDirection = function() return V3.zero end
cls(G, "Humanoid").FloorMaterial = function() return E.Enum.Material.Concrete end
cls(G, "Seat").Occupant = function(o) return o.occupant end
cls(G, "VehicleSeat").Occupant = function(o) return o.occupant end
cls(G, "VehicleSeat").Throttle = function() return 0 end
cls(G, "VehicleSeat").Steer = function() return 0 end
function E.unseat(hum)
	local seat = hum.seat
	if not seat then return end
	local w = Ins.FindFirstChild(seat, "SeatWeld")
	if w then Ins.Destroy(w) end
	seat.occupant = nil
	hum.seat = nil
	E.jointDirty = true
	E.changed(seat, "Occupant")
	E.fireEv(hum, "Seated", false, nil)
	E.changed(hum, "SeatPart"); E.changed(hum, "Sit")
	local root = Ins.FindFirstChild(hum.parent, "HumanoidRootPart")
	if root then E.movePart(root, root.cframe + V3.new(0, 3, 0)) end
	E.jumpCooldown = E.now + 1
end
function E.sit(seat, hum)
	if seat.props.Disabled then return false end
	if seat.occupant then return false end
	if hum.seat then E.unseat(hum) end
	local root = Ins.FindFirstChild(hum.parent, "HumanoidRootPart")
	if not root then return false end
	local w = E.new("Weld", nil, true)
	w.props.Name = "SeatWeld"
	w.props.Part0 = seat; w.props.Part1 = root
	w.props.C0 = CF.new(0, seat.props.Size.Y / 2 + 1.5, 0)
	w.props.C1 = CF.identity
	E.setParent(w, seat)
	seat.occupant = hum
	hum.seat = seat
	E.changed(seat, "Occupant")
	E.fireEv(hum, "Seated", true, seat)
	E.changed(hum, "SeatPart"); E.changed(hum, "Sit")
	return true
end
cls(M, "Seat").Sit = function(o, hum)
	if E.ctx and E.ctx.name ~= "server" then error("Seat:Sit can only be called from the server", 2) end
	E.sit(o, hum)
end
cls(M, "VehicleSeat").Sit = cls(M, "Seat").Sit
local HS = cls(S, "Humanoid")
HS.Sit = function(o, v) if not v and o.seat then E.unseat(o) end return true end
HS.Jump = function(o, v) if v and o.seat then E.unseat(o) end return true end
local Hm = cls(M, "Humanoid")
function Hm.MoveTo(o, p) E.walkTo(o.parent, p) end
function Hm.Move() end
function Hm.ChangeState(o, s) if s.Name == "Jumping" and o.seat then E.unseat(o) end end
function Hm.GetState() return E.Enum.HumanoidStateType.Running end
function Hm.SetStateEnabled() end
function Hm.GetStateEnabled() return true end
function Hm.TakeDamage(o, d) o.props.Health = math.max(0, (o.props.Health or 100) - d) end
function Hm.UnequipTools() end
function Hm.EquipTool() end
function Hm.GetPlayingAnimationTracks() return {} end
function Hm.GetAppliedDescription() return nil end
function Hm.ApplyDescription() end
local function animTrack(a)
	local tr = { IsPlaying = false, Looped = false, Speed = 1, Length = 1, TimePosition = 0, Animation = a }
	tr.Play = function(self) self.IsPlaying = true end
	tr.Stop = function(self) self.IsPlaying = false end
	tr.AdjustSpeed = function(self, s) self.Speed = s end
	tr.AdjustWeight = function() end
	tr.Stopped = E.signal("Stopped"); tr.Ended = E.signal("Ended"); tr.KeyframeReached = E.signal("k")
	tr.GetMarkerReachedSignal = function() return E.signal("m") end
	return tr
end
function Hm.LoadAnimation(o, a) E.warnOnce("deprecated Humanoid:LoadAnimation (use Animator)"); return animTrack(a) end
cls(M, "Animator").LoadAnimation = function(o, a) return animTrack(a) end
cls(M, "Animator").GetPlayingAnimationTracks = function() return {} end

function E.addPlayer(name, userId)
	local plr = E.new("Player", nil, true)
	plr.props.Name = name
	plr.props.DisplayName = name
	plr.props.UserId = userId or 1
	plr.ctx = { name = "client", player = plr, cache = {} }
	E.player = E.player or plr
	local pg = E.new("PlayerGui", nil, true); pg.props.Name = "PlayerGui"
	local bp = E.new("Backpack", nil, true); bp.props.Name = "Backpack"
	local ps = E.new("PlayerScripts", nil, true); ps.props.Name = "PlayerScripts"
	E.setParent(pg, plr); E.setParent(bp, plr); E.setParent(ps, plr)
	E.setParent(plr, E.services.Players)
	E.delay(0.05, function()
		for _, c in ipairs(E.services.StarterGui.children) do local cc = Ins.Clone(c); if cc then E.setParent(cc, pg) end end
		for _, c in ipairs(sps.children) do
			local cc = Ins.Clone(c)
			E.setParent(cc, ps)
		end
		for _, c in ipairs(ps.children) do if c.cls == "LocalScript" then E.runScript(c, plr.ctx) end end
	end, plr.ctx)
	if E.services.Players.CharacterAutoLoads then
		E.delay(0.4, function() E.spawnCharacter(plr) end, E.serverCtx)
	end
	return plr
end
function E.removePlayer(plr)
	E.fireEv(E.services.Players, "PlayerRemoving", plr)
	E.run(0.2)
	if plr.props.Character then Ins.Destroy(plr.props.Character) end
	plr.locked = false
	Ins.Destroy(plr)
end

---------------------------------------------------------------- frame loop
local lastErr = {}
function E.step(dt)
	dt = dt or 1 / 60
	E.now = E.now + dt
	E.frame = E.frame + 1
	E.wakeSleepers()
	E.runDeferred()
	local RS = E.services.RunService
	E.fireEv(RS, "Stepped", E.now, dt)
	E.fireEv(RS, "PreSimulation", dt)
	E.physicsStep(dt)
	E.fireEv(RS, "PostSimulation", dt)
	E.fireEv(RS, "Heartbeat", dt)
	local binds = {}
	for n, b in pairs(E.renderBinds) do binds[#binds + 1] = b end
	table.sort(binds, function(a, b) return a.prio < b.prio end)
	E.cameraFollow()
	for _, b in ipairs(binds) do
		local co = coroutine.create(b.f)
		E.threadCtx[co] = b.ctx
		E.resume(co, dt)
	end
	E.fireEv(RS, "PreRender", dt)
	E.fireEv(RS, "RenderStepped", dt)
	E.stepTweens()
	E.runDeferred()
end
function E.run(seconds, dt)
	dt = dt or 1 / 30
	local n = math.max(1, math.floor(seconds / dt + 0.5))
	for _ = 1, n do E.step(dt) end
end

-- minimal physics: unanchored assemblies with nothing anchored fall onto the ground; characters stand on floors
function E.physicsStep(dt)
	for _, plr in ipairs(M.Players.GetPlayers(E.services.Players)) do
		local ch = plr.props.Character
		local root = ch and Ins.FindFirstChild(ch, "HumanoidRootPart")
		local hum = ch and Ins.FindFirstChildOfClass(ch, "Humanoid")
		if root and hum and not hum.seat and not root.props.Anchored then
			local p = T.RaycastParams.new()
			p.FilterDescendantsInstances = { ch }
			p.RespectCanCollide = true
			local hit = E.raycast(root.cframe.Position + V3.new(0, 1, 0), V3.new(0, -60, 0), p)
			if hit then
				local y = hit.Position.Y + 3
				if math.abs(root.cframe.Y - y) > 0.05 then E.movePart(root, root.cframe + V3.new(0, y - root.cframe.Y, 0)) end
			else
				if not plr.fallWarned then plr.fallWarned = true; E.reportError("character of " .. plr.props.Name .. " has no floor below " .. tostring(root.cframe.Position) .. " (would fall)", nil, E.serverCtx) end
			end
			-- touching a seat sits the character (Roblox behaviour)
			if E.now > (E.jumpCooldown or 0) then
				for _, d in ipairs(Ins.GetDescendants(ws)) do
					if (d.cls == "Seat" or d.cls == "VehicleSeat") and not d.props.Disabled and not d.occupant then
						local l = d.cframe:PointToObjectSpace(root.cframe.Position - V3.new(0, 2, 0))
						local s = d.props.Size
						if math.abs(l.X) < s.X / 2 + 0.5 and math.abs(l.Z) < s.Z / 2 + 0.5 and l.Y > -1 and l.Y < 2.5 then
							E.out("INFO", plr.props.Name .. " touched seat " .. E.fullName(d) .. " and sat down")
							E.sit(d, hum)
							break
						end
					end
				end
			end
		end
	end
end

local camState = {}
function E.cameraFollow()
	if not E.player then return end
	local cam = E.currentCamera(E.player.ctx)
	if cam.props.CameraType and cam.props.CameraType.Name ~= "Custom" and cam.props.CameraType.Name ~= "Follow" then return end
	if E.cameraOverride then return end
	local ch = E.player.props.Character
	local root = ch and Ins.FindFirstChild(ch, "HumanoidRootPart")
	if not root then return end
	local yaw = camState.yaw or 0
	local focus = root.cframe.Position + V3.new(0, 1.5, 0)
	local dist = camState.dist or 14
	local pos = focus + V3.new(math.sin(yaw) * dist, dist * 0.45, math.cos(yaw) * dist)
	cam.props.CFrame = CF.lookAt(pos, focus)
	cam.props.Focus = CF.new(focus)
end
function E.setCameraYaw(y, dist) camState.yaw = y; camState.dist = dist end

---------------------------------------------------------------- input simulation
local function io(t) return E.inputObject(t) end
local function gpNow() return E.focusedBox ~= nil end
function E.key(name, down)
	local kc = E.Enum.KeyCode[name]
	E.input.keys[name] = down
	local ino = io({ _KeyCode = kc, _UserInputType = E.Enum.UserInputType.Keyboard, _UserInputState = down and E.Enum.UserInputState.Begin or E.Enum.UserInputState.End, _Position = V3.new(E.input.mouse.X, E.input.mouse.Y, 0), _Delta = V3.zero })
	local uis = E.services.UserInputService
	if down then E.fireEv(uis, "InputBegan", ino, gpNow()) else E.fireEv(uis, "InputEnded", ino, gpNow()) end
	for n, a in pairs(E.actions) do
		for _, inp in ipairs(a.inputs) do
			if inp == kc then
				local co = coroutine.create(a.f)
				E.threadCtx[co] = a.ctx
				E.resume(co, n, down and E.Enum.UserInputState.Begin or E.Enum.UserInputState.End, ino)
			end
		end
	end
	if down and not gpNow() then
		local ch = E.player and E.player.props.Character
		local hum = ch and Ins.FindFirstChildOfClass(ch, "Humanoid")
		if name == "Space" and hum and hum.seat then E.unseat(hum) end
		if name == E.promptKey then E.pressPromptKey(name) end
	end
	E.runDeferred()
end
E.promptKey = "E"
function E.tap(name) E.key(name, true); E.run(0.1); E.key(name, false); E.run(0.1) end

local hovered = {}
function E.mouseMove(x, y)
	local old = E.input.mouse
	E.input.mouse = V2.new(x, y)
	E.input.delta = V2.new(x - old.X, y - old.Y)
	local uis = E.services.UserInputService
	local ino = io({ _UserInputType = E.Enum.UserInputType.MouseMovement, _UserInputState = E.Enum.UserInputState.Change, _Position = V3.new(x, y - E.VIEW.inset, 0), _Delta = V3.new(x - old.X, y - old.Y, 0), _KeyCode = E.Enum.KeyCode.Unknown })
	local hits = E.guiAt(x, y)
	local now = {}
	for _, h in ipairs(hits) do now[h] = true end
	for h in pairs(hovered) do if not now[h] then E.fireEv(h, "MouseLeave", x, y - E.VIEW.inset) end end
	for h in pairs(now) do if not hovered[h] then E.fireEv(h, "MouseEnter", x, y - E.VIEW.inset) end E.fireEv(h, "MouseMoved", x, y - E.VIEW.inset) end
	hovered = now
	E.fireEv(uis, "InputChanged", ino, #hits > 0 and hits[1].Active == true)
	if E.player and E.player.mouseObj and E.player.mouseObj.sig.Move then E.fire(E.player.mouseObj.sig.Move) end
	E.runDeferred()
end
-- returns the GUI object that would receive a click at x,y (screen coords incl. inset)
function E.guiTarget(x, y)
	for _, h in ipairs(E.guiAt(x, y)) do
		if E.isA(h.cls, "GuiButton") or h.Active or h.cls == "TextBox" or h.cls == "ScrollingFrame" then return h end
	end
end
function E.mouseButton(btn, down)
	local x, y = E.input.mouse.X, E.input.mouse.Y
	local bn = btn == 1 and "MouseButton1" or "MouseButton2"
	E.input.buttons[bn] = down
	local target = E.guiTarget(x, y)
	local gp = target ~= nil and (E.isA(target.cls, "GuiButton") or target.Active == true)
	local ino = io({ _UserInputType = E.Enum.UserInputType[bn], _UserInputState = down and E.Enum.UserInputState.Begin or E.Enum.UserInputState.End, _Position = V3.new(x, y - E.VIEW.inset, 0), _Delta = V3.zero, _KeyCode = E.Enum.KeyCode.Unknown })
	local uis = E.services.UserInputService
	if target then
		if down then
			E.pressed = E.pressed or {}
			E.pressed[btn] = target
			E.fireEv(target, "InputBegan", ino)
			if E.isA(target.cls, "GuiButton") then E.fireEv(target, bn .. "Down", x, y - E.VIEW.inset) end
			if target.cls == "TextBox" then M.TextBox.CaptureFocus(target) end
		else
			E.fireEv(target, "InputEnded", ino)
			if E.isA(target.cls, "GuiButton") then
				E.fireEv(target, bn .. "Up", x, y - E.VIEW.inset)
				if E.pressed and E.pressed[btn] == target then
					E.fireEv(target, bn .. "Click")
					if btn == 1 then E.fireEv(target, "Activated", ino, 1) end
				end
			end
		end
	end
	if down then E.fireEv(uis, "InputBegan", ino, gp) else E.fireEv(uis, "InputEnded", ino, gp) end
	local mo = E.player and E.player.mouseObj
	if mo and not gp then
		local s = mo.sig[(btn == 1 and "Button1" or "Button2") .. (down and "Down" or "Up")]
		if s then E.fire(s) end
	end
	-- ClickDetectors
	if not target and down and btn == 1 then
		local mo2 = E.mouse(E.player)
		local t = mo2.Target
		local x2 = t
		while x2 do
			local cd = Ins.FindFirstChildOfClass(x2, "ClickDetector")
			if cd then E.fireEv(cd, "MouseClick", E.player); break end
			x2 = x2.parent
		end
	end
	E.runDeferred()
end
function E.click(x, y, btn)
	if x then E.mouseMove(x, y) end
	E.mouseButton(btn or 1, true)
	E.run(0.05)
	E.mouseButton(btn or 1, false)
	E.run(0.1)
end
-- find a GUI object of the local player by visible text (Lua pattern) or name
function E.findGui(pat, opts)
	opts = opts or {}
	local list = E.guiList(E.player)
	for i = #list, 1, -1 do
		local o = list[i].o
		local txt = o.props.Text
		if (txt and txt:find(pat)) or o.props.Name == pat then
			if not opts.button or E.isA(o.cls, "GuiButton") then return o end
			-- text inside a button: return the button ancestor
			local a = o.parent
			while a and not E.isA(a.cls, "GuiButton") do a = a.parent end
			if a then return a end
		end
	end
end
function E.clickGui(pat, btn)
	local o = E.isInst(pat) and pat or E.findGui(pat, { button = true })
	if not o then E.reportError("scenario: no visible button matching '" .. tostring(pat) .. "'", nil, { name = "scenario" }); return false end
	local L = o.L
	local x, y = L.x + L.w / 2, L.y + L.h / 2
	local t = E.guiTarget(x, y)
	if t ~= o and not (t and Ins.IsDescendantOf(t, o)) then
		E.reportError("scenario: button '" .. tostring(pat) .. "' (" .. E.fullName(o) .. ") is covered by " .. (t and E.fullName(t) or "nothing clickable") .. " at its center", nil, { name = "scenario" })
		return false
	end
	E.click(x, y, btn)
	return true
end
function E.typeText(box, text, enter)
	if not E.isInst(box) then box = E.findGui(box) end
	M.TextBox.CaptureFocus(box)
	box.Text = text
	M.TextBox.ReleaseFocus(box, enter ~= false)
	E.runDeferred()
end

-- proximity prompts
function E.promptsInRange()
	local ch = E.player and E.player.props.Character
	local root = ch and Ins.FindFirstChild(ch, "HumanoidRootPart")
	if not root then return {} end
	local r = {}
	for _, d in ipairs(Ins.GetDescendants(ws)) do
		if d.cls == "ProximityPrompt" and d.Enabled then
			local p = d.parent
			local pos = p and (E.isA(p.cls, "BasePart") and p.cframe.Position or (p.cls == "Attachment" and p.WorldPosition) or (p.cls == "Model" and M.Model.GetPivot(p).Position))
			if pos then
				local dist = (pos - root.cframe.Position).Magnitude
				if dist <= d.MaxActivationDistance then r[#r + 1] = { p = d, d = dist, pos = pos } end
			end
		end
	end
	table.sort(r, function(a, b) return a.d < b.d end)
	return r, root
end
local function trigger(pp)
	local svcP = E.services.ProximityPromptService
	E.fireEv(pp, "PromptButtonHoldBegan", E.player)
	if pp.HoldDuration > 0 then E.run(pp.HoldDuration + 0.05) end
	E.fireEv(pp, "Triggered", E.player)
	E.fireEv(svcP, "PromptTriggered", pp, E.player)
	E.fireEv(pp, "TriggerEnded", E.player)
	E.fireEv(pp, "PromptButtonHoldEnded", E.player)
	E.runDeferred()
end
function E.pressPromptKey(key)
	local list, root = E.promptsInRange()
	for _, it in ipairs(list) do
		if it.p.KeyboardKeyCode.Name == key then
			if it.p.RequiresLineOfSight then
				local params = T.RaycastParams.new()
				params.FilterDescendantsInstances = { E.player.props.Character, it.p.parent }
				local dir = it.pos - root.cframe.Position
				local hit = E.raycast(root.cframe.Position, dir, params)
				if hit and hit.Distance < dir.Magnitude - 0.5 then
					E.out("INFO", "prompt '" .. it.p.ActionText .. "' blocked from view by " .. E.fullName(hit.Instance))
					return
				end
			end
			E.out("INFO", "pressed " .. key .. " -> prompt '" .. it.p.ActionText .. "' on " .. E.fullName(it.p.parent))
			trigger(it.p)
			return it.p
		end
	end
end
-- trigger a prompt by action text: walks the character next to it and presses its key, so overlapping prompts are caught
function E.usePrompt(action)
	local target
	for _, d in ipairs(Ins.GetDescendants(ws)) do
		if d.cls == "ProximityPrompt" and d.Enabled and (d.ActionText:find(action) or d.props.Name == action) then target = d; break end
	end
	if not target then E.reportError("scenario: no enabled prompt '" .. action .. "'", nil, { name = "scenario" }); return end
	local list = E.promptsInRange()
	local nearest
	for _, it in ipairs(list) do if it.p.KeyboardKeyCode == target.KeyboardKeyCode then nearest = it.p; break end end
	if nearest ~= target then
		local pp = target.parent
		local pos = E.isA(pp.cls, "BasePart") and pp.cframe.Position or (pp.cls == "Attachment" and pp.WorldPosition) or M.Model.GetPivot(pp).Position
		E.out("INFO", "walking to prompt '" .. action .. "'")
		E.walkNear(pos)
		list = E.promptsInRange()
		nearest = nil
		for _, it in ipairs(list) do if it.p.KeyboardKeyCode == target.KeyboardKeyCode then nearest = it.p; break end end
	end
	if nearest ~= target then
		E.reportError("scenario: prompt '" .. action .. "' cannot be reached: nearest prompt is '" .. (nearest and nearest.ActionText or "none") .. "'", nil, { name = "scenario" })
		return
	end
	E.pressPromptKey(target.KeyboardKeyCode.Name)
	return target
end
-- teleport the character close to a position (as walking would), checking the straight path is not blocked
function E.walkNear(pos, dist)
	local ch = E.player.props.Character
	local root = Ins.FindFirstChild(ch, "HumanoidRootPart")
	local from = root.cframe.Position
	local flat = V3.new(pos.X - from.X, 0, pos.Z - from.Z)
	local stop = pos - (flat.Magnitude > 0.1 and flat.Unit or V3.new(0, 0, 1)) * (dist or 3)
	local target = V3.new(stop.X, math.max(pos.Y, from.Y), stop.Z)
	local params = T.RaycastParams.new()
	params.FilterDescendantsInstances = { ch }
	params.RespectCanCollide = true
	local waist = from + V3.new(0, 0.5, 0)
	local dir = V3.new(target.X - waist.X, 0, target.Z - waist.Z)
	if dir.Magnitude > 0.1 then
		local hit = E.raycast(waist, dir, params)
		if hit then E.out("INFO", "walk path blocked by " .. E.fullName(hit.Instance) .. " (a player would walk around it)") end
	end
	E.movePart(root, CF.lookAt(target, V3.new(pos.X, target.Y, pos.Z)))
	E.run(0.3)
end
function E.walkTo(ch, pos)
	local root = Ins.FindFirstChild(ch, "HumanoidRootPart")
	if root then E.movePart(root, CF.new(pos + V3.new(0, 3, 0))) end
	local hum = Ins.FindFirstChildOfClass(ch, "Humanoid")
	if hum then E.delay(0.1, function() E.fireEv(hum, "MoveToFinished", true) end) end
end
function E.teleport(pos, lookAt)
	local root = Ins.FindFirstChild(E.player.props.Character, "HumanoidRootPart")
	E.movePart(root, lookAt and CF.lookAt(pos, lookAt) or CF.new(pos))
	E.run(0.1)
end

return E

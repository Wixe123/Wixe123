-- Services for the emulator: Workspace (raycasts, camera, terrain), Players, RunService, UserInputService,
-- TweenService, DataStoreService, remotes and the rest the game touches.
local E = EMU_REQUIRE("classes")
local T = E.T
local V3, V2, CF, C3 = T.Vector3, T.Vector2, T.CFrame, T.Color3
local M, G, S, D = E.METHODS, E.GETTERS, E.SETTERS, E.DEFAULTS
local function cls(t, c) t[c] = t[c] or {}; return t[c] end
local services = E.services

E.VIEW = { w = 1280, h = 720, inset = 58 }
E.serverCtx = { name = "server", cache = {} }

local function svc(name, cname)
	local s = E.new(cname or name, nil, true)
	s.props.Name = name
	services[name] = s
	s.locked = true
	return s
end
E.svc = svc

---------------------------------------------------------------- Workspace and raycasts
local function rayBox(o, d, cf, size)
	-- ray in part space
	local lo = cf:PointToObjectSpace(o)
	local ld = cf:VectorToObjectSpace(d)
	local h = { size.X / 2, size.Y / 2, size.Z / 2 }
	local p = { lo.X, lo.Y, lo.Z }
	local v = { ld.X, ld.Y, ld.Z }
	local tmin, tmax, nAxis, nSign = -math.huge, math.huge, 0, 0
	for a = 1, 3 do
		if math.abs(v[a]) < 1e-12 then
			if p[a] < -h[a] or p[a] > h[a] then return nil end
		else
			local t1, t2 = (-h[a] - p[a]) / v[a], (h[a] - p[a]) / v[a]
			local s = -1
			if t1 > t2 then t1, t2 = t2, t1; s = 1 end
			if t1 > tmin then tmin = t1; nAxis = a; nSign = s end
			if t2 < tmax then tmax = t2 end
			if tmin > tmax then return nil end
		end
	end
	if tmax < 0 then return nil end
	local t = tmin >= 0 and tmin or 0
	local n = { 0, 0, 0 }
	if nAxis > 0 then n[nAxis] = nSign end
	return t, cf:VectorToWorldSpace(V3.new(n[1], n[2], n[3]))
end
local function raySphere(o, d, c, r)
	local oc = o - c
	local a = d:Dot(d)
	local b = 2 * oc:Dot(d)
	local cc = oc:Dot(oc) - r * r
	local disc = b * b - 4 * a * cc
	if disc < 0 then return nil end
	local t = (-b - math.sqrt(disc)) / (2 * a)
	if t < 0 then t = (-b + math.sqrt(disc)) / (2 * a) end
	if t < 0 then return nil end
	return t, ((o + d * t) - c).Unit
end
local function rayCyl(o, d, cf, size)
	-- cylinder along local X, radius min(Y,Z)/2
	local lo, ld = cf:PointToObjectSpace(o), cf:VectorToObjectSpace(d)
	local r, hl = math.min(size.Y, size.Z) / 2, size.X / 2
	local best, bn
	local a = ld.Y * ld.Y + ld.Z * ld.Z
	if a > 1e-12 then
		local b = 2 * (lo.Y * ld.Y + lo.Z * ld.Z)
		local c = lo.Y * lo.Y + lo.Z * lo.Z - r * r
		local disc = b * b - 4 * a * c
		if disc >= 0 then
			for _, t in ipairs({ (-b - math.sqrt(disc)) / (2 * a), (-b + math.sqrt(disc)) / (2 * a) }) do
				if t >= 0 then
					local x = lo.X + ld.X * t
					if math.abs(x) <= hl and (not best or t < best) then best = t; bn = V3.new(0, lo.Y + ld.Y * t, lo.Z + ld.Z * t).Unit end
				end
			end
		end
	end
	if math.abs(ld.X) > 1e-12 then
		for _, sx in ipairs({ -1, 1 }) do
			local t = (sx * hl - lo.X) / ld.X
			if t >= 0 then
				local y, z = lo.Y + ld.Y * t, lo.Z + ld.Z * t
				if y * y + z * z <= r * r and (not best or t < best) then best = t; bn = V3.new(sx, 0, 0) end
			end
		end
	end
	if not best then return nil end
	return best, cf:VectorToWorldSpace(bn)
end
-- ray against a triangle mesh (MeshParts made with EditableMesh), in part space scaled by Size
local function rayMesh(p, o, d)
	local cf, size = p.cframe or CF.identity, p.props.Size
	local lo, ld = cf:PointToObjectSpace(o), cf:VectorToObjectSpace(d)
	local m = p.extra.mesh
	local sx, sy, sz = size.X, size.Y, size.Z
	local ox, oy, oz, dx, dy, dz = lo.X, lo.Y, lo.Z, ld.X, ld.Y, ld.Z
	local best, bn
	local v = m.v
	for _, t in ipairs(m.t) do
		local a, b, c = v[t[1]], v[t[2]], v[t[3]]
		local ax, ay, az = a[1] * sx, a[2] * sy, a[3] * sz
		local e1x, e1y, e1z = b[1] * sx - ax, b[2] * sy - ay, b[3] * sz - az
		local e2x, e2y, e2z = c[1] * sx - ax, c[2] * sy - ay, c[3] * sz - az
		local px, py, pz = dy * e2z - dz * e2y, dz * e2x - dx * e2z, dx * e2y - dy * e2x
		local det = e1x * px + e1y * py + e1z * pz
		if math.abs(det) > 1e-12 then
			local inv = 1 / det
			local tx, ty, tz = ox - ax, oy - ay, oz - az
			local u = (tx * px + ty * py + tz * pz) * inv
			if u >= 0 and u <= 1 then
				local qx, qy, qz = ty * e1z - tz * e1y, tz * e1x - tx * e1z, tx * e1y - ty * e1x
				local w = (dx * qx + dy * qy + dz * qz) * inv
				if w >= 0 and u + w <= 1 then
					local dist = (e2x * qx + e2y * qy + e2z * qz) * inv
					if dist >= 0 and (not best or dist < best) then
						best = dist
						local nx, ny, nz = e1y * e2z - e1z * e2y, e1z * e2x - e1x * e2z, e1x * e2y - e1y * e2x
						if nx * dx + ny * dy + nz * dz > 0 then nx, ny, nz = -nx, -ny, -nz end
						bn = V3.new(nx, ny, nz).Unit
					end
				end
			end
		end
	end
	if not best then return nil end
	return best, cf:VectorToWorldSpace(bn)
end
function E.rayPart(p, o, d)
	if p.cls == "MeshPart" and p.extra and p.extra.mesh and p.props.CollisionFidelity and p.props.CollisionFidelity.Name ~= "Box" then return rayMesh(p, o, d) end
	local cf, size = p.cframe or CF.identity, p.props.Size or V3.new(4, 1.2, 2)
	local shape = p.cls == "Part" and p.props.Shape and p.props.Shape.Name or "Block"
	if shape == "Ball" then return raySphere(o, d, cf.Position, math.min(size.X, size.Y, size.Z) / 2) end
	if shape == "Cylinder" then return rayCyl(o, d, cf, size) end
	return rayBox(o, d, cf, size)
end
local function filtered(p, params)
	if not params then return true end
	local list = params.FilterDescendantsInstances or {}
	local ft = params.FilterType
	local include = (E.isEnumItem(ft) and ft.Name == "Include") or ft == "Include" or (E.isEnumItem(ft) and ft.Name == "Whitelist")
	local inList = false
	for _, f in ipairs(list) do
		if f == p or M.Instance.IsDescendantOf(p, f) then inList = true; break end
	end
	if include then return inList end
	return not inList
end
function E.raycast(origin, dir, params, root)
	if not (T.isV3(origin) and T.isV3(dir)) then error("Raycast: origin and direction must be Vector3", 3) end
	local len = dir.Magnitude
	if len == 0 then return nil end
	if len > 15000 then E.warnOnce("Raycast longer than 15000 studs is clamped in Roblox") end
	local unit = dir / len
	local best, bp, bn
	local respect = params and params.RespectCanCollide
	local group = params and params.CollisionGroup
	local function test(p)
		if p.props.CanQuery == false then return end
		if respect and p.props.CanCollide == false then return end
		if group and group ~= "Default" and E.groupsCollide and not E.groupsCollide(group, p.props.CollisionGroup or "Default") then return end
		if not filtered(p, params) then return end
		local t, n = E.rayPart(p, origin, unit)
		if t and t <= len and (not best or t < best) then best, bp, bn = t, p, n end
	end
	if root then
		local function walk(x)
			for _, c in ipairs(x.children) do
				if E.isA(c.cls, "BasePart") and c.cls ~= "Terrain" then test(c) end
				if #c.children > 0 then walk(c) end
			end
		end
		walk(root)
	else
		-- parts are bucketed in a 32-stud grid (rebuilt when the tree changes); parts moved since then are checked always
		local G = 32
		if E.partsDirty or not E.partGrid then
			local list = {}
			local function walk(x)
				for _, c in ipairs(x.children) do
					if E.isA(c.cls, "BasePart") and c.cls ~= "Terrain" then list[#list + 1] = c end
					if #c.children > 0 then walk(c) end
				end
			end
			walk(services.Workspace)
			local grid = {}
			for _, p in ipairs(list) do
				local c, sz = p.cframe, p.props.Size
				local r = math.sqrt(sz.x * sz.x + sz.y * sz.y + sz.z * sz.z) / 2
				for gx = math.floor((c.px - r) / G), math.floor((c.px + r) / G) do
					for gz = math.floor((c.pz - r) / G), math.floor((c.pz + r) / G) do
						local k = gx * 100003 + gz
						local cell = grid[k]
						if not cell then cell = {}; grid[k] = cell end
						cell[#cell + 1] = p
					end
				end
			end
			E.partList, E.partGrid, E.partsDirty, E.movedSet = list, grid, false, {}
		end
		local ox, oy, oz = origin.X, origin.Y, origin.Z
		local ux, uy, uz = unit.X, unit.Y, unit.Z
		local seen = {}
		local function consider(p)
			if seen[p] or not p.parent then return end
			seen[p] = true
			local c, sz = p.cframe, p.props.Size
			local rx, ry, rz = c.px - ox, c.py - oy, c.pz - oz
			local t = rx * ux + ry * uy + rz * uz
			local rad2 = (sz.x * sz.x + sz.y * sz.y + sz.z * sz.z) / 4
			local tt = math.max(0, math.min(len, t))
			local dx, dy, dz = rx - ux * tt, ry - uy * tt, rz - uz * tt
			if dx * dx + dy * dy + dz * dz <= rad2 then test(p) end
		end
		local ex, ez = ox + ux * len, oz + uz * len
		if len < 400 then
			for gx = math.floor(math.min(ox, ex) / G), math.floor(math.max(ox, ex) / G) do
				for gz = math.floor(math.min(oz, ez) / G), math.floor(math.max(oz, ez) / G) do
					local cell = E.partGrid[gx * 100003 + gz]
					if cell then for _, p in ipairs(cell) do consider(p) end end
				end
			end
		else
			for _, p in ipairs(E.partList) do consider(p) end
		end
		for p in pairs(E.movedSet) do consider(p) end
	end
	-- terrain boxes
	if E.terrainOps then
		for _, op in ipairs(E.terrainOps) do
			if op.kind == "block" and op.mat ~= "Air" and op.mat ~= "Water" then
				local fake = { cframe = op.cf, props = { Size = op.size }, cls = "Part" }
				local t, n = rayBox(origin, unit, op.cf, op.size)
				if t and t <= len and (not best or t < best) then best, bp, bn = t, services.Workspace.Terrain, n end
			end
		end
	end
	if not best then return nil end
	local mat = bp.cls == "Terrain" and E.enumItem("Material", "Grass") or bp.props.Material or E.enumItem("Material", "Plastic")
	return setmetatable({ _Instance = bp, _Position = origin + unit * best, _Normal = bn, _Distance = best, _Material = mat }, E.RaycastResultMt)
end
E.RaycastResultMt = {
	__index = function(t, k) local v = rawget(t, "_" .. k); if v ~= nil then return v end error(tostring(k) .. " is not a valid member of RaycastResult", 2) end,
}
T.TYPE[E.RaycastResultMt] = "RaycastResult"

local Wm = cls(M, "WorldRoot")
function Wm.Raycast(o, origin, dir, params)
	local root = nil
	if o.cls ~= "Workspace" then root = o end
	return E.raycast(origin, dir, params, root)
end
function Wm.Blockcast(o, cf, size, dir, params)
	-- approximation: center ray plus the 4 corners of the box face
	local best
	for _, off in ipairs({ V3.new(0, 0, 0), V3.new(size.X / 2, 0, 0), V3.new(-size.X / 2, 0, 0), V3.new(0, size.Y / 2, 0), V3.new(0, -size.Y / 2, 0) }) do
		local r = E.raycast(cf * off, dir, params)
		if r and (not best or r.Distance < best.Distance) then best = r end
	end
	return best
end
function Wm.Spherecast(o, pos, radius, dir, params) return E.raycast(pos, dir, params) end
function Wm.Shapecast(o, part, dir, params) return E.raycast(part.cframe.Position, dir, params) end
local function partsIn(test, params)
	local r = {}
	local function walk(x)
		for _, c in ipairs(x.children) do
			if E.isA(c.cls, "BasePart") and c.cls ~= "Terrain" and c.props.CanQuery ~= false and filtered(c, params) and test(c) then r[#r + 1] = c end
			walk(c)
		end
	end
	walk(services.Workspace)
	return r
end
function Wm.GetPartBoundsInRadius(o, pos, rad, params)
	return partsIn(function(p) local s = p.props.Size or V3.one; return (p.cframe.Position - pos).Magnitude <= rad + s.Magnitude / 2 end, params)
end
function Wm.GetPartBoundsInBox(o, cf, size, params)
	return partsIn(function(p) local l = cf:PointToObjectSpace(p.cframe.Position); local s = (p.props.Size or V3.one) / 2
		return math.abs(l.X) <= size.X / 2 + s.Magnitude and math.abs(l.Y) <= size.Y / 2 + s.Magnitude and math.abs(l.Z) <= size.Z / 2 + s.Magnitude end, params)
end
function Wm.GetPartsInPart(o, part, params) return Wm.GetPartBoundsInBox(o, part.cframe, part.props.Size, params) end
function Wm.FindPartOnRay(o, ray, ignore)
	E.warnOnce("deprecated FindPartOnRay")
	local p = T.RaycastParams.new()
	if ignore then p.FilterDescendantsInstances = { ignore } end
	local r = E.raycast(ray.Origin, ray.Direction, p)
	if r then return r.Instance, r.Position, r.Normal, r.Material end
	return nil, ray.Origin + ray.Direction, V3.zero, nil
end
function Wm.BulkMoveTo(o, parts, cfs)
	for i, p in ipairs(parts) do p.cframe = cfs[i]; E.changed(p, "CFrame") end
end
cls(G, "Workspace").CurrentCamera = function(o) return E.currentCamera() end
cls(S, "Workspace").CurrentCamera = function(o, v) E.setCamera(v); return true end
cls(G, "Workspace").DistributedGameTime = function() return E.now end
cls(M, "Workspace").GetServerTimeNow = function() return E.now end
cls(G, "Workspace").Terrain = function(o) return o.terrain end

-- Terrain: operations are recorded for the renderer
E.terrainOps = {}
local Tm = cls(M, "Terrain")
local function tmat(m) if not E.isEnumItem(m) or m.et.n ~= "Material" then error("Terrain: Material enum expected", 3) end return m.Name end
function Tm.FillBlock(o, cf, size, mat) table.insert(E.terrainOps, { kind = "block", cf = cf, size = size, mat = tmat(mat) }) end
function Tm.FillBall(o, c, r, mat) table.insert(E.terrainOps, { kind = "ball", cf = CF.new(c), size = V3.new(r * 2, r * 2, r * 2), mat = tmat(mat) }) end
function Tm.FillCylinder(o, cf, h, r, mat) table.insert(E.terrainOps, { kind = "cyl", cf = cf, size = V3.new(r * 2, h, r * 2), mat = tmat(mat) }) end
function Tm.FillWedge(o, cf, size, mat) table.insert(E.terrainOps, { kind = "wedge", cf = cf, size = size, mat = tmat(mat) }) end
function Tm.Clear(o) E.terrainOps = {} end
function Tm.FillRegion() E.gap("Terrain:FillRegion") end

-- Camera
local cameras = {}
function E.currentCamera(ctx)
	ctx = ctx or E.ctx or E.serverCtx
	local key = ctx.player or "server"
	local c = cameras[key]
	if not c or c.destroyed then
		c = E.new("Camera", nil, true)
		c.props.Name = "Camera"
		cameras[key] = c
		c.props.CFrame = CF.new(0, 20, 20)
	end
	return c
end
function E.setCamera(v) local ctx = E.ctx or E.serverCtx; cameras[ctx.player or "server"] = v end
local Cg = cls(G, "Camera")
Cg.ViewportSize = function() return V2.new(E.VIEW.w, E.VIEW.h) end
Cg.CoordinateFrame = function(o) return o.props.CFrame or CF.new(0, 20, 20) end
Cg.Focus = function(o) return o.props.Focus or CF.identity end
local Cm = cls(M, "Camera")
local function camRay(o, x, y, depth)
	local cf = o.props.CFrame or CF.new(0, 20, 20)
	local fov = math.rad(o.props.FieldOfView or 70)
	local w, h = E.VIEW.w, E.VIEW.h
	local th = math.tan(fov / 2)
	local nx, ny = (x / w * 2 - 1) * th * (w / h), (1 - y / h * 2) * th
	local dir = cf:VectorToWorldSpace(V3.new(nx, ny, -1)).Unit
	return setmetatable({ _Origin = cf.Position + dir * (depth or 0), _Direction = dir, _Unit = nil }, E.RayMt)
end
E.RayMt = { __index = function(t, k)
	if k == "Unit" then return t end
	local v = rawget(t, "_" .. k); if v ~= nil then return v end
	if k == "ClosestPoint" then return function(self, p) local d = (p - self._Origin):Dot(self._Direction); return self._Origin + self._Direction * math.max(0, d) end end
	error(tostring(k) .. " is not a valid member of Ray", 2)
end }
T.TYPE[E.RayMt] = "Ray"
function Cm.ViewportPointToRay(o, x, y, depth) return camRay(o, x, y, depth) end
function Cm.ScreenPointToRay(o, x, y, depth) return camRay(o, x, y + E.VIEW.inset, depth) end
function Cm.WorldToViewportPoint(o, p)
	local cf = o.props.CFrame or CF.new(0, 20, 20)
	local l = cf:PointToObjectSpace(p)
	local fov = math.rad(o.props.FieldOfView or 70)
	local th = math.tan(fov / 2)
	local w, h = E.VIEW.w, E.VIEW.h
	local depth = -l.Z
	local sx = (l.X / (depth * th * w / h) + 1) / 2 * w
	local sy = (1 - l.Y / (depth * th)) / 2 * h
	local on = depth > 0 and sx >= 0 and sx <= w and sy >= 0 and sy <= h
	return V3.new(sx, sy, depth), on
end
function Cm.WorldToScreenPoint(o, p) local v, on = Cm.WorldToViewportPoint(o, p); return V3.new(v.X, v.Y - E.VIEW.inset, v.Z), on end
function Cm.GetPartsObscuringTarget() return {} end
function Cm.Interpolate(o, a, b, t) o.props.CFrame = a; o.props.Focus = b end

---------------------------------------------------------------- Players
D.Player = { DisplayName = "", UserId = 0, AccountAge = 30, CameraMaxZoomDistance = 128, CameraMinZoomDistance = 0.5, MembershipType = function() return E.enumItem("MembershipType", "None") end }
local Pm = cls(M, "Player")
function Pm.GetMouse(o) return E.mouse(o) end
function Pm.Kick(o, msg) E.out("KICK", tostring(msg)); o.kicked = msg end
function Pm.LoadCharacter(o) E.spawnCharacter(o) end
function Pm.GetNetworkPing() return 0.05 end
function Pm.IsInGroup() return false end
function Pm.GetRankInGroup() return 0 end
function Pm.HasAppearanceLoaded() return true end
function Pm.ClearCharacterAppearance() end
function Pm.DistanceFromCharacter(o, p) local c = o.props.Character; local r = c and M.Instance.FindFirstChild(c, "HumanoidRootPart"); if not r then return 0 end return (r.cframe.Position - p).Magnitude end
local Psm = cls(M, "Players")
function Psm.GetPlayers(o) local r = {}; for _, c in ipairs(o.children) do if c.cls == "Player" then r[#r + 1] = c end end return r end
function Psm.GetPlayerFromCharacter(o, ch) for _, p in ipairs(Psm.GetPlayers(o)) do if p.props.Character == ch then return p end end end
function Psm.GetPlayerByUserId(o, id) for _, p in ipairs(Psm.GetPlayers(o)) do if p.props.UserId == id then return p end end end
function Psm.GetUserThumbnailAsync() return "rbxasset://textures/ui/GuiImagePlaceholder.png", true end
function Psm.GetNameFromUserIdAsync(o, id) return "Player" .. tostring(id) end
cls(G, "Players").LocalPlayer = function(o)
	local ctx = E.ctx
	if ctx and ctx.player then return ctx.player end
	return nil
end

---------------------------------------------------------------- RunService
local RSm = cls(M, "RunService")
function RSm.IsServer() return E.ctx == nil or E.ctx.name == "server" end
function RSm.IsClient() return E.ctx ~= nil and E.ctx.name ~= "server" end
function RSm.IsStudio() return true end
function RSm.IsRunning() return true end
function RSm.IsRunMode() return false end
function RSm.IsEdit() return false end
E.renderBinds = {}
function RSm.BindToRenderStep(o, name, prio, f)
	if type(f) ~= "function" then error("BindToRenderStep: function expected", 2) end
	E.renderBinds[name] = { prio = prio, f = f, ctx = E.ctx }
end
function RSm.UnbindFromRenderStep(o, name) E.renderBinds[name] = nil end

---------------------------------------------------------------- UserInputService and mouse
E.input = { keys = {}, buttons = {}, mouse = V2.new(640, 400), delta = V2.zero }
local UISm = cls(M, "UserInputService")
function UISm.GetMouseLocation() return E.input.mouse end
function UISm.GetMouseDelta() return E.input.delta end
function UISm.IsKeyDown(o, k) return E.input.keys[k.Name] == true end
function UISm.IsMouseButtonPressed(o, b) return E.input.buttons[b.Name] == true end
function UISm.GetKeysPressed() local r = {}; for k, v in pairs(E.input.keys) do if v then r[#r + 1] = { KeyCode = E.Enum.KeyCode[k] } end end return r end
function UISm.GetFocusedTextBox() return E.focusedBox end
function UISm.GetLastInputType() return E.Enum.UserInputType.Keyboard end
function UISm.GetConnectedGamepads() return {} end
function UISm.GetGamepadConnected() return false end
function UISm.GetStringForKeyCode(o, k) return k.Name end
function UISm.GetMouseButtonsPressed() return {} end
function UISm.GetNavigationGamepads() return {} end
D.UserInputService = { MouseEnabled = true, KeyboardEnabled = true, TouchEnabled = false, GamepadEnabled = false, MouseIconEnabled = true, MouseDeltaSensitivity = 1 }
local IOmt = {}
T.TYPE[IOmt] = "InputObject"
IOmt.__index = function(t, k) local v = rawget(t, "_" .. k); if v ~= nil then return v end
	if k == "IsModifierKeyDown" then return function() return false end end
	error(tostring(k) .. " is not a valid member of InputObject", 2) end
IOmt.__newindex = function(t, k, v) rawset(t, "_" .. k, v) end
function E.inputObject(t) return setmetatable(t, IOmt) end

local MouseMt = {}
T.TYPE[MouseMt] = "Instance"
function E.mouse(plr)
	plr.mouseObj = plr.mouseObj or setmetatable({ plr = plr, sig = {}, props = { Icon = "", TargetFilter = nil } }, MouseMt)
	return plr.mouseObj
end
local function mouseRay()
	local cam = E.currentCamera()
	local m = E.input.mouse
	return Cm.ViewportPointToRay(cam, m.X, m.Y)
end
MouseMt.__index = function(mo, k)
	if k == "X" then return E.input.mouse.X elseif k == "Y" then return E.input.mouse.Y - E.VIEW.inset
	elseif k == "UnitRay" then return mouseRay()
	elseif k == "Origin" then return CF.new(mouseRay().Origin)
	elseif k == "Hit" or k == "Target" or k == "TargetSurface" then
		local r = mouseRay()
		local p = T.RaycastParams.new()
		local f = { mo.props.TargetFilter, mo.plr.props.Character }
		local list = {}
		for _, x in pairs(f) do list[#list + 1] = x end
		p.FilterDescendantsInstances = list
		local hit = E.raycast(r.Origin, r.Direction * 1000, p)
		if k == "Target" then return hit and hit.Instance end
		if k == "TargetSurface" then return E.Enum.NormalId.Top end
		local pos = hit and hit.Position or (r.Origin + r.Direction * 1000)
		return CF.lookAt(r.Origin, pos).Rotation + pos
	elseif k == "Icon" or k == "TargetFilter" then return mo.props[k]
	elseif k == "ViewSizeX" then return E.VIEW.w elseif k == "ViewSizeY" then return E.VIEW.h - E.VIEW.inset
	elseif k == "Button1Down" or k == "Button1Up" or k == "Button2Down" or k == "Button2Up" or k == "Move" or k == "WheelForward" or k == "WheelBackward" or k == "Idle" then
		mo.sig[k] = mo.sig[k] or E.signal(k); return mo.sig[k]
	end
	error(tostring(k) .. " is not a valid member of PlayerMouse", 2)
end
MouseMt.__newindex = function(mo, k, v)
	if k == "Icon" or k == "TargetFilter" then mo.props[k] = v; return end
	error("Unable to assign property " .. tostring(k) .. " of PlayerMouse", 2)
end

---------------------------------------------------------------- TweenService
local EASE = {}
EASE.Linear = function(t) return t end
EASE.Quad = function(t) return t * t end
EASE.Cubic = function(t) return t * t * t end
EASE.Quart = function(t) return t * t * t * t end
EASE.Quint = function(t) return t ^ 5 end
EASE.Sine = function(t) return 1 - math.cos(t * math.pi / 2) end
EASE.Exponential = function(t) return t == 0 and 0 or 2 ^ (10 * (t - 1)) end
EASE.Circular = function(t) return 1 - math.sqrt(1 - t * t) end
EASE.Back = function(t) local s = 1.70158; return t * t * ((s + 1) * t - s) end
EASE.Bounce = function(t) return t end
EASE.Elastic = function(t) return t end
local function ease(style, dir, t)
	local f = EASE[style and style.Name or "Quad"] or EASE.Quad
	local d = dir and dir.Name or "Out"
	if d == "In" then return f(t) elseif d == "Out" then return 1 - f(1 - t)
	else if t < 0.5 then return f(t * 2) / 2 else return 1 - f((1 - t) * 2) / 2 end end
end
local function lerp(a, b, t)
	if type(a) == "number" then return a + (b - a) * t end
	local tn = T.typeName(a)
	if tn == "Vector3" or tn == "Vector2" or tn == "Color3" or tn == "UDim2" or tn == "CFrame" then return a:Lerp(b, t) end
	return t >= 1 and b or a
end
local TweenMt = {}
T.TYPE[TweenMt] = "Instance"
E.tweens = {}
local TWm = cls(M, "TweenService")
function TWm.Create(o, inst, info, goals)
	if not E.isInst(inst) then error("TweenService:Create: Instance expected", 2) end
	if T.typeName(info) ~= "TweenInfo" then error("TweenService:Create: TweenInfo expected", 2) end
	for k, v in pairs(goals) do
		local kind, pinfo = E.member(inst.cls, k)
		if kind ~= "p" then error("TweenService:Create property named '" .. tostring(k) .. "' cannot be tweened due to type mismatch (property is a 'nil', but given type is '" .. (T.typeName(v) or type(v)) .. "')", 2) end
		if pinfo[3] == 1 then error("TweenService:Create: property " .. k .. " is read only", 2) end
		local cur = inst[k]
		local ct, vt = T.typeName(cur) or type(cur), T.typeName(v) or type(v)
		if ct ~= vt then error("TweenService:Create property named '" .. k .. "' cannot be tweened due to type mismatch (property is a '" .. ct .. "', but given type is '" .. vt .. "')", 2) end
	end
	local tw = setmetatable({ inst = inst, info = info, goals = goals, state = "Begin", sig = {} }, TweenMt)
	return tw
end
function TWm.GetValue(o, a, style, dir) return ease(style, dir, a) end
TweenMt.__index = function(tw, k)
	if k == "Play" then return function(self)
		if self.state == "Playing" then return end
		self.state = "Playing"
		self.t0 = E.now
		self.from = {}
		for kk in pairs(self.goals) do self.from[kk] = self.inst[kk] end
		E.tweens[self] = true
	end end
	if k == "Cancel" or k == "Pause" then return function(self) E.tweens[self] = nil; self.state = k == "Cancel" and "Cancelled" or "Paused" end end
	if k == "Destroy" then return function(self) E.tweens[self] = nil end end
	if k == "Completed" then tw.sig.Completed = tw.sig.Completed or E.signal("Completed"); return tw.sig.Completed end
	if k == "PlaybackState" then return E.Enum.PlaybackState[tw.state] end
	if k == "Instance" then return tw.inst end
	if k == "TweenInfo" then return tw.info end
	error(tostring(k) .. " is not a valid member of Tween", 2)
end
function E.stepTweens()
	local list = {}
	for tw in pairs(E.tweens) do list[#list + 1] = tw end
	for _, tw in ipairs(list) do
		if tw.inst.destroyed then E.tweens[tw] = nil
		else
			local info = tw.info
			local dur = math.max(1e-6, info.Time)
			local t = math.max(0, math.min(1, (E.now - tw.t0 - (rawget(info, "_DelayTime") or 0)) / dur))
			local a = ease(rawget(info, "_EasingStyle"), rawget(info, "_EasingDirection"), t)
			E.trusted = false
			for k, v in pairs(tw.goals) do tw.inst[k] = lerp(tw.from[k], v, a) end
			if t >= 1 then
				E.tweens[tw] = nil
				tw.state = "Completed"
				if tw.sig.Completed then E.fire(tw.sig.Completed, E.Enum.PlaybackState.Completed) end
			end
		end
	end
end

---------------------------------------------------------------- DataStoreService
E.datastore = {}
E.datastoreFails = false
local DSmt = {}
T.TYPE[DSmt] = "Instance"
DSmt.__index = function(ds, k)
	local store = E.datastore[ds.name]
	local function check() if E.datastoreFails then error("502: API Services rejected request with error. HTTP 403 (Studio access to APIs is not allowed.)", 3) end E.wait(0.05) end
	if k == "GetAsync" then return function(self, key) check(); local v = store[key]; return v and E.deepcopy(v) or nil end end
	if k == "SetAsync" then return function(self, key, v) check(); E.checkStorable(v, "SetAsync"); store[key] = E.deepcopy(v) end end
	if k == "UpdateAsync" then return function(self, key, f) check(); local nv = f(store[key] and E.deepcopy(store[key]) or nil); if nv ~= nil then E.checkStorable(nv, "UpdateAsync"); store[key] = E.deepcopy(nv) end return nv end end
	if k == "RemoveAsync" then return function(self, key) check(); local v = store[key]; store[key] = nil; return v end end
	if k == "IncrementAsync" then return function(self, key, d) check(); store[key] = (store[key] or 0) + (d or 1); return store[key] end end
	error(tostring(k) .. " is not a valid member of DataStore", 2)
end
local DSSm = cls(M, "DataStoreService")
function DSSm.GetDataStore(o, name)
	E.datastore[name] = E.datastore[name] or {}
	return setmetatable({ name = name }, DSmt)
end
function DSSm.GetRequestBudgetForRequestType() return 100 end
function E.deepcopy(v)
	if type(v) ~= "table" or E.isInst(v) or T.typeName(v) then return v end
	local r = {}
	for k, x in pairs(v) do r[k] = E.deepcopy(x) end
	return r
end
function E.checkStorable(v, where, path)
	path = path or "value"
	local t = type(v)
	if t == "function" or t == "userdata" or t == "thread" then error(where .. ": cannot store " .. t .. " at " .. path, 3) end
	if t == "number" and (v ~= v or v == math.huge or v == -math.huge) then error(where .. ": NaN/inf at " .. path, 3) end
	if t == "table" then
		if E.isInst(v) or T.typeName(v) then error(where .. ": cannot store " .. (T.typeName(v) or "Instance") .. " at " .. path .. " (only plain data can be saved)", 3) end
		local n, strKeys, numKeys = #v, 0, 0
		for k, x in pairs(v) do
			if type(k) == "string" then strKeys = strKeys + 1 elseif type(k) == "number" then numKeys = numKeys + 1 else error(where .. ": key type " .. type(k) .. " at " .. path, 3) end
			E.checkStorable(x, where, path .. "." .. tostring(k))
		end
		if numKeys > 0 and (strKeys > 0 or numKeys ~= n) then error(where .. ": table at " .. path .. " mixes array and dictionary keys or has holes; it cannot be saved as JSON", 3) end
	end
end

---------------------------------------------------------------- remotes
local function remoteCopy(v, path)
	path = path or "arg"
	if type(v) == "function" then E.reportError("remote: function passed at " .. path .. " becomes nil", debug.traceback(), E.ctx); return nil end
	if type(v) ~= "table" or E.isInst(v) or T.typeName(v) then return v end
	local n, strKeys, numKeys = #v, 0, 0
	for k in pairs(v) do if type(k) == "string" then strKeys = strKeys + 1 elseif type(k) == "number" then numKeys = numKeys + 1 end end
	if numKeys > 0 and (strKeys > 0 or numKeys ~= n) then
		E.reportError("remote: table at " .. path .. " mixes array and dictionary keys or has holes; Roblox will drop or convert keys", debug.traceback(), E.ctx)
	end
	local r = {}
	for k, x in pairs(v) do r[k] = remoteCopy(x, path .. "." .. tostring(k)) end
	return r
end
local function copyArgs(...)
	local a = table.pack(...)
	for i = 1, a.n do a[i] = remoteCopy(a[i], "arg" .. i) end
	return a
end
local function deliver(o, ev, filter, args)
	local s = o.sig[ev]
	if not s then return end
	E.defer(function()
		local alive = {}
		for _, c in ipairs(s.conns) do if c.on then alive[#alive + 1] = c end end
		for _, c in ipairs(alive) do
			if filter(c.ctx) then
				local co = coroutine.create(c.f)
				E.threadCtx[co] = c.ctx
				E.resume(co, table.unpack(args, 1, args.n))
			end
		end
	end, E.serverCtx)
end
local REm = cls(M, "RemoteEvent")
function REm.FireServer(o, ...)
	local ctx = E.ctx
	if not ctx or ctx.name == "server" then error("FireServer can only be called from the client", 2) end
	local a = copyArgs(ctx.player, ...)
	deliver(o, "OnServerEvent", function(c) return c and c.name == "server" end, a)
end
function REm.FireClient(o, plr, ...)
	if E.ctx and E.ctx.name ~= "server" then error("FireClient can only be called from the server", 2) end
	if not (E.isInst(plr) and plr.cls == "Player") then error("FireClient: player argument must be a Player object", 2) end
	local a = copyArgs(...)
	deliver(o, "OnClientEvent", function(c) return c and c.player == plr end, a)
end
function REm.FireAllClients(o, ...)
	if E.ctx and E.ctx.name ~= "server" then error("FireAllClients can only be called from the server", 2) end
	local a = copyArgs(...)
	deliver(o, "OnClientEvent", function(c) return c and c.name ~= "server" end, a)
end
cls(M, "UnreliableRemoteEvent").FireServer = REm.FireServer
cls(M, "UnreliableRemoteEvent").FireClient = REm.FireClient
cls(M, "UnreliableRemoteEvent").FireAllClients = REm.FireAllClients
local RFm = cls(M, "RemoteFunction")
function RFm.InvokeServer(o, ...)
	local ctx = E.ctx
	if not ctx or ctx.name == "server" then error("InvokeServer can only be called from the client", 2) end
	local a = copyArgs(ctx.player, ...)
	local caller = coroutine.running()
	local done, res = false, nil
	E.defer(function()
		local f = o.callbacks.OnServerInvoke
		local t0 = E.now
		while not f and E.now - t0 < 10 do E.wait(0.1); f = o.callbacks.OnServerInvoke end
		if not f then E.reportError("InvokeServer: no OnServerInvoke on " .. E.fullName(o), nil, ctx); done = true; res = { n = 0 }; E.resume(caller); return end
		local r = table.pack(pcall(f, table.unpack(a, 1, a.n)))
		if not r[1] then E.reportError("OnServerInvoke error in " .. E.fullName(o) .. ": " .. tostring(r[2]), nil, E.serverCtx); res = { n = 0, err = r[2] }
		else
			res = { n = r.n - 1 }
			for i = 2, r.n do res[i - 1] = remoteCopy(r[i], "ret" .. (i - 1)) end
		end
		done = true
		if coroutine.status(caller) == "suspended" then E.resume(caller) end
	end, E.serverCtx)
	if not done then coroutine.yield({ __invoke = true }) end
	if res.err then error(res.err, 2) end
	return table.unpack(res, 1, res.n)
end
function RFm.InvokeClient(o, plr, ...) E.gap("RemoteFunction:InvokeClient"); return nil end

---------------------------------------------------------------- other services
local PSm = cls(M, "PhysicsService")
E.groups = { Default = {} }
E.groupPairs = {}
function PSm.RegisterCollisionGroup(o, n) E.groups[n] = E.groups[n] or {} end
function PSm.IsCollisionGroupRegistered(o, n) return E.groups[n] ~= nil end
function PSm.CollisionGroupSetCollidable(o, a, b, v)
	if not E.groups[a] then error("Collision group '" .. tostring(a) .. "' is not registered", 2) end
	if not E.groups[b] then error("Collision group '" .. tostring(b) .. "' is not registered", 2) end
	E.groupPairs[a .. "|" .. b] = v; E.groupPairs[b .. "|" .. a] = v
end
function PSm.CollisionGroupsAreCollidable(o, a, b) local v = E.groupPairs[a .. "|" .. b]; return v == nil or v end
function E.groupsCollide(a, b) local v = E.groupPairs[a .. "|" .. b]; return v == nil or v end
function PSm.GetRegisteredCollisionGroups() local r = {}; for n in pairs(E.groups) do r[#r + 1] = { name = n } end return r end
function PSm.CreateCollisionGroup(o, n) E.warnOnce("deprecated PhysicsService:CreateCollisionGroup"); E.groups[n] = {} end
function PSm.SetPartCollisionGroup(o, p, n) E.warnOnce("deprecated PhysicsService:SetPartCollisionGroup"); p.props.CollisionGroup = n end
cls(S, "BasePart").CollisionGroup = function(o, v)
	if not E.groups[v] then E.reportError("CollisionGroup '" .. tostring(v) .. "' set on " .. E.fullName(o) .. " before it was registered", debug.traceback(), E.ctx) end
	o.props.CollisionGroup = v; return true
end

local CSm = cls(M, "CollectionService")
function CSm.AddTag(o, inst, t) inst.tags[t] = true end
function CSm.RemoveTag(o, inst, t) inst.tags[t] = nil end
function CSm.HasTag(o, inst, t) return inst.tags[t] == true end
function CSm.GetTagged(o, t)
	local r = {}
	local function walk(x) for _, c in ipairs(x.children) do if c.tags[t] then r[#r + 1] = c end walk(c) end end
	walk(E.game)
	return r
end
function CSm.GetInstanceAddedSignal(o, t) o.tsig = o.tsig or {}; o.tsig[t] = o.tsig[t] or E.signal("tag"); return o.tsig[t] end
function CSm.GetInstanceRemovedSignal(o, t) return CSm.GetInstanceAddedSignal(o, "-" .. t) end
function CSm.GetTags(o, inst) return M.Instance.GetTags(inst) end

local DBm = cls(M, "Debris")
function DBm.AddItem(o, inst, t) E.delay(t or 10, function() if not inst.destroyed then M.Instance.Destroy(inst) end end, E.serverCtx) end

local HSm = cls(M, "HttpService")
local function jenc(v, path)
	local t = type(v)
	if t == "nil" then return "null" end
	if t == "boolean" then return tostring(v) end
	if t == "number" then if v ~= v or v == math.huge or v == -math.huge then return "null" end return string.format("%.14g", v) end
	if t == "string" then return '"' .. v:gsub('[%c"\\]', function(c) local m = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" }; return m[c] or string.format("\\u%04x", c:byte()) end) .. '"' end
	if t == "table" then
		if #v > 0 or next(v) == nil then local r = {}; for i, x in ipairs(v) do r[i] = jenc(x) end return "[" .. table.concat(r, ",") .. "]" end
		local r = {}
		for k, x in pairs(v) do r[#r + 1] = jenc(tostring(k)) .. ":" .. jenc(x) end
		table.sort(r)
		return "{" .. table.concat(r, ",") .. "}"
	end
	error("Can't convert " .. t .. " to JSON", 3)
end
function HSm.JSONEncode(o, v) return jenc(v) end
function HSm.JSONDecode(o, s)
	local i = 1
	local function ws() i = s:find("[^%s]", i) or #s + 1 end
	local val
	local function str()
		local r = {}
		i = i + 1
		while true do
			local c = s:sub(i, i)
			if c == '"' then i = i + 1; break end
			if c == "\\" then
				local n = s:sub(i + 1, i + 1)
				local m = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" }
				if n == "u" then r[#r + 1] = utf8.char(tonumber(s:sub(i + 2, i + 5), 16)); i = i + 6
				else r[#r + 1] = m[n] or n; i = i + 2 end
			else r[#r + 1] = c; i = i + 1 end
			if i > #s then error("Can't parse JSON", 4) end
		end
		return table.concat(r)
	end
	val = function()
		ws()
		local c = s:sub(i, i)
		if c == "{" then
			local r = {}; i = i + 1; ws()
			if s:sub(i, i) == "}" then i = i + 1; return r end
			while true do ws(); local k = str(); ws(); i = i + 1; r[k] = val(); ws(); local d = s:sub(i, i); i = i + 1; if d == "}" then break end end
			return r
		elseif c == "[" then
			local r = {}; i = i + 1; ws()
			if s:sub(i, i) == "]" then i = i + 1; return r end
			while true do r[#r + 1] = val(); ws(); local d = s:sub(i, i); i = i + 1; if d == "]" then break end end
			return r
		elseif c == '"' then return str()
		elseif s:sub(i, i + 3) == "true" then i = i + 4; return true
		elseif s:sub(i, i + 4) == "false" then i = i + 5; return false
		elseif s:sub(i, i + 3) == "null" then i = i + 4; return nil
		else local n = s:match("^-?[%d%.eE+-]+", i); if not n then error("Can't parse JSON", 4) end i = i + #n; return tonumber(n) end
	end
	return val()
end
function HSm.GenerateGUID(o, braces) E.guid = (E.guid or 0) + 1; local g = string.format("%08X-0000-4000-8000-%012X", E.guid, E.guid); return braces == false and g or "{" .. g .. "}" end
function HSm.UrlEncode(o, s) return (s:gsub("[^%w]", function(c) return string.format("%%%02X", c:byte()) end)) end

local TSm = cls(M, "TextService")
function TSm.GetTextSize(o, text, size, font, frame) local w = 0; for line in (text .. "\n"):gmatch("(.-)\n") do w = math.max(w, utf8.len(line) * size * 0.5) end local lines = select(2, text:gsub("\n", "")) + 1; return V2.new(math.min(w, frame and frame.X or math.huge), lines * size) end

local SGm = cls(M, "StarterGui")
E.coreGui = {}
function SGm.SetCoreGuiEnabled(o, t, v)
	if not (E.isEnumItem(t) and t.et.n == "CoreGuiType") then error("SetCoreGuiEnabled: CoreGuiType expected", 2) end
	if E.ctx and E.ctx.name == "server" then error("SetCoreGuiEnabled can only be called from a LocalScript", 2) end
	E.coreGui[t.Name] = v
end
function SGm.GetCoreGuiEnabled(o, t) return E.coreGui[t.Name] ~= false end
function SGm.SetCore(o, n, v) if E.ctx and E.ctx.name == "server" then error("SetCore can only be called from a LocalScript", 2) end E.core = E.core or {}; E.core[n] = v end
function SGm.GetCore(o, n) return E.core and E.core[n] end

local CASm = cls(M, "ContextActionService")
E.actions = {}
function CASm.BindAction(o, name, f, touch, ...) E.actions[name] = { f = f, inputs = { ... }, ctx = E.ctx } end
function CASm.BindActionAtPriority(o, name, f, touch, prio, ...) E.actions[name] = { f = f, inputs = { ... }, ctx = E.ctx } end
function CASm.UnbindAction(o, name) E.actions[name] = nil end
function CASm.SetTitle() end
function CASm.SetPosition() end
function CASm.GetButton() return nil end

local GSm = cls(M, "GuiService")
function GSm.GetGuiInset() return V2.new(0, E.VIEW.inset), V2.zero end
D.GuiService = { AutoSelectGuiEnabled = true }

local SSm = cls(M, "SoundService")
function SSm.PlayLocalSound(o, s) s.playing = true end

local MPSm = cls(M, "MarketplaceService")
function MPSm.UserOwnsGamePassAsync() return false end

local PPSm = cls(M, "ProximityPromptService")
D.ProximityPromptService = { Enabled = true, MaxPromptsVisible = 16 }

local LSm = cls(M, "LocalizationService")
cls(G, "LocalizationService").RobloxLocaleId = function() return "sv-se" end

function E.makeService(n)
	local known = {
		Workspace = 1, Players = 1, Lighting = 1, ReplicatedStorage = 1, ReplicatedFirst = 1, ServerScriptService = 1, ServerStorage = 1, StarterGui = 1,
		StarterPack = 1, StarterPlayer = 1, SoundService = 1, Chat = 1, Teams = 1, RunService = 1, UserInputService = 1, TweenService = 1, DataStoreService = 1,
		PhysicsService = 1, CollectionService = 1, AssetService = 1, Debris = 1, HttpService = 1, TextService = 1, ContextActionService = 1, GuiService = 1,
		MarketplaceService = 1, ProximityPromptService = 1, LocalizationService = 1, TeleportService = 1, BadgeService = 1, TextChatService = 1,
		VRService = 1, HapticService = 1, AnalyticsService = 1, PathfindingService = 1, ContentProvider = 1, MessagingService = 1, MemoryStoreService = 1,
		PolicyService = 1, AvatarEditorService = 1, SocialService = 1, GroupService = 1, AssetService = 1, KeyframeSequenceProvider = 1, StarterPlayerScripts = 0,
	}
	if not known[n] or known[n] == 0 then return nil end
	if not E.API.C[n] then return nil end
	local s = svc(n)
	if E.game then s.parent = E.game; table.insert(E.game.children, s) end
	return s
end

local CPm = cls(M, "ContentProvider")
function CPm.PreloadAsync() end

---------------------------------------------------------------- AssetService / EditableMesh (meshes made in code)
local ContentMt = {}
T.TYPE[ContentMt] = "Content"
ContentMt.__index = function(c, k) if k == "Object" then return c.obj elseif k == "Uri" then return c.uri end error(tostring(k) .. " is not a valid member of Content", 2) end
E.Content = {
	fromObject = function(o) return setmetatable({ obj = o }, ContentMt) end,
	fromUri = function(u) return setmetatable({ uri = u }, ContentMt) end,
	none = setmetatable({}, ContentMt),
}
local ASm = cls(M, "AssetService")
function ASm.CreateEditableMesh(o, opts)
	if E.noEditableMesh then return nil end -- like Roblox when the game may not use mesh APIs
	local em = E.new("EditableMesh", nil, true)
	em.extra = { verts = {}, tris = {} }
	return em
end
local EMm = cls(M, "EditableMesh")
function EMm.AddVertex(o, p)
	if not T.isV3(p) then error("AddVertex: Vector3 expected", 2) end
	local v = o.extra.verts
	v[#v + 1] = p
	return #v
end
function EMm.AddTriangle(o, a, b, c)
	local n = #o.extra.verts
	for _, x in ipairs({ a, b, c }) do if type(x) ~= "number" or x < 1 or x > n then error("AddTriangle: invalid vertex id " .. tostring(x), 2) end end
	local t = o.extra.tris
	t[#t + 1] = { a, b, c }
	return #t
end
function EMm.GetSize(o)
	local mn, mx
	for _, v in ipairs(o.extra.verts) do mn = mn and mn:Min(v) or v; mx = mx and mx:Max(v) or v end
	return mn and (mx - mn) or V3.zero
end
function EMm.AddNormal() return 1 end
function EMm.Destroy(o) o.destroyed = true end
function ASm.CreateMeshPartAsync(o, content, opts)
	if T.typeName(content) ~= "Content" then error("CreateMeshPartAsync: Content expected (use Content.fromObject)", 2) end
	local em = content.obj
	if not (em and em.cls == "EditableMesh") then error("CreateMeshPartAsync: no EditableMesh in Content", 2) end
	if #em.extra.tris == 0 then error("CreateMeshPartAsync: mesh has no triangles", 2) end
	E.wait(0.05)
	local mp = E.new("MeshPart", nil, true)
	local size = EMm.GetSize(em)
	local mn
	for _, v in ipairs(em.extra.verts) do mn = mn and mn:Min(v) or v end
	local center = mn + size / 2
	-- mesh normalised to -0.5..0.5 so it scales with Size, like Roblox
	local nv = {}
	for i, v in ipairs(em.extra.verts) do local d = v - center; nv[i] = { d.X / math.max(size.X, 1e-6), d.Y / math.max(size.Y, 1e-6), d.Z / math.max(size.Z, 1e-6) } end
	E.meshId = (E.meshId or 0) + 1
	mp.extra = { mesh = { id = E.meshId, v = nv, t = em.extra.tris } }
	mp.props.Size = size
	if type(opts) == "table" and opts.CollisionFidelity then mp.props.CollisionFidelity = opts.CollisionFidelity end
	return mp
end

return E

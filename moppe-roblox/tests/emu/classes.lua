-- Class behaviour for the emulator: defaults, computed properties and methods of the classes the game uses.
local E = EMU_REQUIRE("core")
local T = E.T
local V3, CF, C3, U2 = T.Vector3, T.CFrame, T.Color3, T.UDim2
local M, G, S, D, CR = E.METHODS, E.GETTERS, E.SETTERS, E.DEFAULTS, E.CREATED
local function cls(t, c) t[c] = t[c] or {}; return t[c] end

---------------------------------------------------------------- Instance
local I = cls(M, "Instance")
function I.IsA(o, c) return E.isA(o.cls, c) end
function I.GetChildren(o) local r = {}; for i, c in ipairs(o.children) do r[i] = c end return r end
function I.GetDescendants(o)
	local r = {}
	local function walk(x) for _, c in ipairs(x.children) do r[#r + 1] = c; walk(c) end end
	walk(o)
	return r
end
function I.FindFirstChild(o, n, rec)
	if type(n) ~= "string" then error("Argument 1 missing or nil", 2) end
	for _, c in ipairs(o.children) do if c.props.Name == n then return c end end
	if rec then for _, c in ipairs(o.children) do local f = I.FindFirstChild(c, n, true); if f then return f end end end
end
function I.FindFirstChildOfClass(o, n) for _, c in ipairs(o.children) do if c.cls == n then return c end end end
function I.FindFirstChildWhichIsA(o, n, rec)
	for _, c in ipairs(o.children) do if E.isA(c.cls, n) then return c end end
	if rec then for _, c in ipairs(o.children) do local f = I.FindFirstChildWhichIsA(c, n, true); if f then return f end end end
end
function I.FindFirstAncestor(o, n) local x = o.parent; while x do if x.props.Name == n then return x end x = x.parent end end
function I.FindFirstAncestorOfClass(o, n) local x = o.parent; while x do if x.cls == n then return x end x = x.parent end end
function I.FindFirstAncestorWhichIsA(o, n) local x = o.parent; while x do if E.isA(x.cls, n) then return x end x = x.parent end end
function I.IsDescendantOf(o, a) local x = o.parent; while x do if x == a then return true end x = x.parent end return false end
function I.IsAncestorOf(o, d) return I.IsDescendantOf(d, o) end
function I.GetFullName(o) return E.fullName(o) end
function I.WaitForChild(o, n, timeout)
	local c = I.FindFirstChild(o, n)
	if c then return c end
	local co, main = coroutine.running()
	if main then error("WaitForChild outside a thread", 2) end
	local t0 = E.now
	local warned = false
	while true do
		E.wait(1 / 30)
		c = I.FindFirstChild(o, n)
		if c then return c end
		if timeout and E.now - t0 >= timeout then return nil end
		if not timeout and not warned and E.now - t0 > 5 then
			warned = true
			E.reportError("Infinite yield possible on '" .. E.fullName(o) .. ":WaitForChild(\"" .. n .. "\")'", debug.traceback(), E.ctx)
		end
	end
end
function I.GetAttribute(o, n) return o.attrs[n] end
function I.SetAttribute(o, n, v)
	if type(n) ~= "string" then error("SetAttribute: name must be a string", 2) end
	local t = T.typeName(v) or type(v)
	local okTypes = { ["nil"] = 1, string = 1, boolean = 1, number = 1, UDim = 1, UDim2 = 1, BrickColor = 1, Color3 = 1, Vector2 = 1, Vector3 = 1, CFrame = 1, NumberSequence = 1, ColorSequence = 1, NumberRange = 1, Rect = 1, Font = 1, EnumItem = 1 }
	if not okTypes[t] then error("SetAttribute: " .. t .. " is not a supported attribute type", 2) end
	o.attrs[n] = v
	E.fireEv(o, "AttributeChanged", n)
	if o.asig and o.asig[n] then E.fire(o.asig[n]) end
end
function I.GetAttributes(o) local r = {}; for k, v in pairs(o.attrs) do r[k] = v end return r end
function I.GetAttributeChangedSignal(o, n)
	o.asig = o.asig or {}
	o.asig[n] = o.asig[n] or E.signal("AttributeChanged:" .. n)
	return o.asig[n]
end
function I.GetPropertyChangedSignal(o, p)
	if p ~= "Name" and p ~= "Parent" and E.member(o.cls, p) ~= "p" then error(tostring(p) .. " is not a valid property name.", 2) end
	o.psig = o.psig or {}
	o.psig[p] = o.psig[p] or E.signal("Changed:" .. p)
	return o.psig[p]
end
function I.ClearAllChildren(o) for i = #o.children, 1, -1 do local c = o.children[i]; if not c.locked then I.Destroy(c) end end end
function I.Destroy(o)
	if o.destroyed then return end -- destroying twice is allowed in Roblox
	if o.locked then error("The Parent property of " .. o.props.Name .. " is locked", 2) end
	E.fireEv(o, "Destroying")
	for i = #o.children, 1, -1 do I.Destroy(o.children[i]) end
	if o.parent then E.setParent(o, nil) end
	o.destroyed = true
	o.locked = true
	for _, s in pairs(o.sig) do s.conns = {} end
end
function I.Remove(o) E.warnOnce("deprecated Instance:Remove"); E.setParent(o, nil) end
function I.AddTag(o, t) o.tags[t] = true; if E.tagAdded then E.tagAdded(o, t) end end
function I.RemoveTag(o, t) o.tags[t] = nil end
function I.HasTag(o, t) return o.tags[t] == true end
function I.GetTags(o) local r = {}; for t in pairs(o.tags) do r[#r + 1] = t end return r end
function I.GetActor() return nil end
function I.Clone(o)
	if o.props.Archivable == false then return nil end
	local map = {}
	local function copy(x)
		if x.props.Archivable == false then return nil end
		local n = E.new(x.cls, nil, true)
		map[x] = n
		for k, v in pairs(x.props) do n.props[k] = v end
		for k, v in pairs(x.nilProps) do n.nilProps[k] = v end
		for k, v in pairs(x.attrs) do n.attrs[k] = v end
		for k, v in pairs(x.tags) do n.tags[k] = v end
		if x.cframe then n.cframe = x.cframe end
		if x.source then n.source = x.source end
		if x.extra then n.extra = {}; for k, v in pairs(x.extra) do n.extra[k] = v end end
		for _, c in ipairs(x.children) do
			local cc = copy(c)
			if cc then cc.parent = n; n.children[#n.children + 1] = cc end
		end
		return n
	end
	local root = copy(o)
	-- remap instance references inside the copy (Part0/Part1, PrimaryPart, Value...)
	local function fix(x)
		for k, v in pairs(x.props) do if E.isInst(v) and map[v] then x.props[k] = map[v] end end
		for _, c in ipairs(x.children) do fix(c) end
	end
	fix(root)
	return root
end
D.Instance = { Archivable = true }

---------------------------------------------------------------- service / DataModel
local services = {}
E.services = services
local DM = cls(M, "DataModel")
function DM.GetService(o, n)
	local s = services[n]
	if s then return s end
	if E.makeService then s = E.makeService(n) end
	if not s then error("'" .. tostring(n) .. "' is not a valid Service name", 2) end
	return s
end
DM.FindService = DM.GetService
cls(M, "ServiceProvider").GetService = DM.GetService
cls(M, "ServiceProvider").FindService = DM.GetService
function DM.BindToClose(o, f) E.closeHandlers = E.closeHandlers or {}; table.insert(E.closeHandlers, f) end
function DM.IsLoaded() return true end
cls(G, "DataModel").Workspace = function() return services.Workspace end
cls(G, "DataModel").PlaceId = function() return 0 end
cls(G, "DataModel").JobId = function() return "" end

---------------------------------------------------------------- BasePart, joints, assemblies
D.BasePart = {
	Anchored = false, CanCollide = true, CanQuery = true, CanTouch = true, CastShadow = true, Locked = false, Massless = false,
	Size = V3.new(4, 1.2, 2), Color = C3.fromRGB(163, 162, 165), Transparency = 0, Reflectance = 0,
	CollisionGroup = "Default", Material = function() return E.enumItem("Material", "Plastic") end,
	TopSurface = function() return E.enumItem("SurfaceType", "Smooth") end, BottomSurface = function() return E.enumItem("SurfaceType", "Smooth") end,
}
D.Part = { Shape = function() return E.enumItem("PartType", "Block") end }
D.MeshPart = { Size = V3.new(1, 1, 1) }
D.Seat = { Disabled = false }
D.VehicleSeat = { Disabled = false, MaxSpeed = 25, Torque = 10, TurnSpeed = 1 }
D.SpawnLocation = { Enabled = true, Duration = 10, Neutral = true }
D.Terrain = { Anchored = true }
CR.BasePart = function(o) o.cframe = CF.identity end

local function partCF(o) return o.cframe or CF.identity end
local function joints(p)
	-- all enabled joints touching part p: returns list of {other=, joint=}
	return E.jointIndex and E.jointIndex[p] or {}
end
local function isJoint(j) return j.cls == "WeldConstraint" or j.cls == "Weld" or j.cls == "Motor6D" or j.cls == "ManualWeld" or j.cls == "Snap" end
function E.jointActive(j)
	if j.destroyed then return false end
	local p0, p1 = j.props.Part0, j.props.Part1
	if not (p0 and p1) or p0 == p1 then return false end
	if j.props.Enabled == false then return false end
	if not j.parent then return false end
	return true
end
E.jointIndex = setmetatable({}, { __mode = "k" })
local function reindex()
	-- rebuilt lazily when joints change
	E.jointDirty = true
end
local allJoints = setmetatable({}, { __mode = "k" })
local function rebuildJoints()
	if not E.jointDirty then return end
	E.jointDirty = false
	local idx = setmetatable({}, { __mode = "k" })
	for j in pairs(allJoints) do
		if E.jointActive(j) then
			local p0, p1 = j.props.Part0, j.props.Part1
			idx[p0] = idx[p0] or {}; idx[p1] = idx[p1] or {}
			table.insert(idx[p0], { other = p1, joint = j })
			table.insert(idx[p1], { other = p0, joint = j })
		end
	end
	E.jointIndex = idx
end
function E.assembly(p)
	rebuildJoints()
	local seen, list = { [p] = true }, { p }
	local i = 1
	while i <= #list do
		local x = list[i]
		for _, e in ipairs(E.jointIndex[x] or {}) do
			if not seen[e.other] then seen[e.other] = true; list[#list + 1] = e.other end
		end
		i = i + 1
	end
	return list
end
-- move a whole rigid assembly so that part p gets the new CFrame
function E.movePart(p, newCF)
	local old = partCF(p)
	local delta = newCF * old:Inverse()
	E.movedSet = E.movedSet or {}
	for _, x in ipairs(E.assembly(p)) do
		E.movedSet[x] = true
		if x == p then x.cframe = newCF else x.cframe = delta * partCF(x) end
		E.changed(x, "CFrame"); E.changed(x, "Position")
	end
end
-- a Weld/Motor6D defines Part1 = Part0 * C0 * C1:Inverse() (* Transform)
local function solveWeld(j)
	if not E.jointActive(j) then return end
	if j.cls == "WeldConstraint" then return end
	local p0, p1 = j.props.Part0, j.props.Part1
	local c0, c1 = j.props.C0 or CF.identity, j.props.C1 or CF.identity
	local tr = (j.cls == "Motor6D" and j.props.Transform) or CF.identity
	local target = partCF(p0) * c0 * tr * c1:Inverse()
	-- move p1's side (everything connected to p1 without passing through this joint)
	j.props.Enabled = false; E.jointDirty = true
	local side = E.assembly(p1)
	j.props.Enabled = nil; E.jointDirty = true
	local delta = target * partCF(p1):Inverse()
	for _, x in ipairs(side) do
		if x ~= p0 then x.cframe = delta * partCF(x); E.changed(x, "CFrame") end
	end
end
E.solveWeld = solveWeld
for _, jc in ipairs({ "JointInstance", "WeldConstraint" }) do
	CR[jc] = function(o) allJoints[o] = true; reindex() end
end
for _, jc in ipairs({ "Weld", "Motor6D", "ManualWeld", "Snap" }) do
	local s = cls(S, jc)
	for _, k in ipairs({ "C0", "C1", "Part0", "Part1", "Transform" }) do
		s[k] = function(o, v) o.props[k] = v; reindex(); solveWeld(o); return true end
	end
end
local wc = cls(S, "WeldConstraint")
wc.Part0 = function(o, v) o.props.Part0 = v; reindex(); return true end
wc.Part1 = function(o, v) o.props.Part1 = v; reindex(); return true end
wc.Enabled = function(o, v) o.props.Enabled = v; reindex(); return true end
D.JointInstance = { C0 = CF.identity, C1 = CF.identity, Enabled = true }
D.WeldConstraint = { Enabled = true }
D.Motor6D = { Transform = CF.identity }
cls(G, "WeldConstraint").Active = function(o) return E.jointActive(o) end
cls(G, "JointInstance").Active = function(o) return E.jointActive(o) end
local prevReparent = E.onReparent
E.onReparent = function(o, old, p)
	if allJoints[o] then reindex(); if o.parent then solveWeld(o) end end
	if prevReparent then prevReparent(o, old, p) end
end

local bp = cls(G, "BasePart")
bp.CFrame = function(o) return partCF(o) end
bp.Position = function(o) return partCF(o).Position end
bp.Orientation = function(o)
	local x, y, z = partCF(o):ToOrientation()
	return V3.new(math.deg(x), math.deg(y), math.deg(z))
end
bp.Rotation = function(o) local x, y, z = partCF(o):ToEulerAnglesXYZ(); return V3.new(math.deg(x), math.deg(y), math.deg(z)) end
bp.PivotOffset = function(o) return o.props.PivotOffset or CF.identity end
bp.AssemblyRootPart = function(o) return E.assembly(o)[1] end
bp.AssemblyMass = function(o) local m = 0; for _, x in ipairs(E.assembly(o)) do if not x.props.Massless then local s = x.props.Size or V3.new(4, 1.2, 2); m = m + s.X * s.Y * s.Z * 0.7 end end return m end
bp.Mass = function(o) local s = o.props.Size or V3.new(4, 1.2, 2); return s.X * s.Y * s.Z * 0.7 end
bp.AssemblyLinearVelocity = function(o) return o.props.AssemblyLinearVelocity or V3.zero end
bp.AssemblyAngularVelocity = function(o) return o.props.AssemblyAngularVelocity or V3.zero end
bp.ResizeableFaces = function() return nil end
local bps = cls(S, "BasePart")
bps.CFrame = function(o, v) E.movePart(o, v); return true end
bps.Position = function(o, v) local c = partCF(o); E.movePart(o, c.Rotation + v); return true end
bps.Orientation = function(o, v) local p = partCF(o).Position; E.movePart(o, CF.new(p) * CF.fromOrientation(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))); return true end
bps.Rotation = function(o, v) local p = partCF(o).Position; E.movePart(o, CF.new(p) * CF.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))); return true end
bps.Size = function(o, v)
	if v.X < 0 or v.Y < 0 or v.Z < 0 then E.warnOnce("negative part size") end
	o.props.Size = V3.new(math.max(0.001, v.X), math.max(0.001, v.Y), math.max(0.001, v.Z))
	return true
end
bps.Velocity = function(o, v) o.props.AssemblyLinearVelocity = v; return true end
local BPm = cls(M, "BasePart")
function BPm.GetPivot(o) return partCF(o) * (o.props.PivotOffset or CF.identity) end
function BPm.PivotTo(o, c) E.movePart(o, c * (o.props.PivotOffset or CF.identity):Inverse()) end
function BPm.GetMass(o) return bp.Mass(o) end
function BPm.SetNetworkOwner(o, plr)
	if not o.props.Anchored then
		for _, x in ipairs(E.assembly(o)) do if x.props.Anchored then error("Network Ownership API cannot be called on Anchored parts or parts welded to Anchored parts.", 2) end end
	else
		error("Network Ownership API cannot be called on Anchored parts or parts welded to Anchored parts.", 2)
	end
	if E.ctx and E.ctx.name ~= "server" then error("Network Ownership API can only be called from the server", 2) end
	o.owner = plr
end
function BPm.SetNetworkOwnershipAuto(o) o.owner = nil end
function BPm.GetNetworkOwner(o) return o.owner end
function BPm.CanSetNetworkOwnership(o)
	for _, x in ipairs(E.assembly(o)) do if x.props.Anchored then return false, "anchored" end end
	return true
end
function BPm.GetConnectedParts(o, rec) return E.assembly(o) end
function BPm.GetJoints(o) rebuildJoints(); local r = {}; for _, e in ipairs(E.jointIndex[o] or {}) do r[#r + 1] = e.joint end return r end
function BPm.GetTouchingParts() return {} end
function BPm.ApplyImpulse() end
function BPm.ApplyAngularImpulse() end
function BPm.BreakJoints(o) for _, e in ipairs(BPm.GetJoints(o)) do e:Destroy() end end
function BPm.GetRootPart(o) return E.assembly(o)[1] end
function BPm.GetVelocityAtPosition(o) return V3.zero end

---------------------------------------------------------------- Model / PVInstance
local function modelParts(o)
	local r = {}
	for _, d in ipairs(I.GetDescendants(o)) do if E.isA(d.cls, "BasePart") then r[#r + 1] = d end end
	return r
end
local function boundingBox(parts, frame)
	frame = frame or CF.identity
	local inv = frame:Inverse()
	local mn, mx
	for _, p in ipairs(parts) do
		local c, s = partCF(p), p.props.Size or V3.new(4, 1.2, 2)
		for _, sx in ipairs({ -1, 1 }) do for _, sy in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
			local w = inv * (c * V3.new(sx * s.X / 2, sy * s.Y / 2, sz * s.Z / 2))
			mn = mn and mn:Min(w) or w
			mx = mx and mx:Max(w) or w
		end end end
	end
	if not mn then return frame, V3.zero end
	return frame * CF.new((mn + mx) / 2), mx - mn
end
E.boundingBox = boundingBox
local Mm = cls(M, "Model")
function Mm.GetPivot(o)
	local pp = o.props.PrimaryPart
	if pp and pp.parent and I.IsDescendantOf(pp, o) then return partCF(pp) * (pp.props.PivotOffset or CF.identity) end
	if o.props.WorldPivot then return o.props.WorldPivot end
	local cf = boundingBox(modelParts(o))
	return cf
end
function Mm.PivotTo(o, c)
	local old = Mm.GetPivot(o)
	local delta = c * old:Inverse()
	local moved = {}
	for _, p in ipairs(modelParts(o)) do
		if not moved[p] then
			local asm = E.assembly(p)
			for _, x in ipairs(asm) do
				if not moved[x] then moved[x] = true; x.cframe = delta * partCF(x); E.changed(x, "CFrame") end
			end
		end
	end
	if o.props.WorldPivot then o.props.WorldPivot = c end
end
function Mm.SetPrimaryPartCFrame(o, c)
	E.warnOnce("deprecated Model:SetPrimaryPartCFrame")
	if not o.props.PrimaryPart then error("Model:SetPrimaryPartCFrame() failed because no PrimaryPart has been set, or the PrimaryPart no longer exists. Please set Model.PrimaryPart before using this.", 2) end
	Mm.PivotTo(o, c)
end
function Mm.GetPrimaryPartCFrame(o) return partCF(o.props.PrimaryPart) end
function Mm.GetBoundingBox(o)
	local pv = Mm.GetPivot(o)
	return boundingBox(modelParts(o), pv.Rotation + pv.Position)
end
function Mm.GetExtentsSize(o) local _, s = boundingBox(modelParts(o)); return s end
function Mm.MoveTo(o, p) local pv = Mm.GetPivot(o); Mm.PivotTo(o, pv.Rotation + p) end
function Mm.GetScale(o) return o.scale or 1 end
function Mm.ScaleTo(o, s)
	if s <= 0 then error("ScaleTo: scale must be positive", 2) end
	local f = s / (o.scale or 1)
	o.scale = s
	local pv = Mm.GetPivot(o)
	for _, p in ipairs(modelParts(o)) do
		local rel = pv:ToObjectSpace(partCF(p))
		p.cframe = pv * (rel.Rotation + rel.Position * f)
		p.props.Size = (p.props.Size or V3.new(4, 1.2, 2)) * f
	end
	for _, d in ipairs(I.GetDescendants(o)) do
		if d.cls == "Weld" or d.cls == "Motor6D" then
			d.props.C0 = (d.props.C0 or CF.identity).Rotation + (d.props.C0 or CF.identity).Position * f
			d.props.C1 = (d.props.C1 or CF.identity).Rotation + (d.props.C1 or CF.identity).Position * f
		elseif d.cls == "Attachment" then
			d.props.CFrame = (d.props.CFrame or CF.identity).Rotation + (d.props.CFrame or CF.identity).Position * f
		end
	end
end
cls(M, "PVInstance").GetPivot = function(o) return Mm.GetPivot(o) end
cls(M, "PVInstance").PivotTo = function(o, c) return Mm.PivotTo(o, c) end
cls(G, "Model").WorldPivot = function(o) return Mm.GetPivot(o) end
cls(S, "Model").WorldPivot = function(o, v) o.props.WorldPivot = v; return true end
cls(S, "Model").PrimaryPart = function(o, v)
	if v and not I.IsDescendantOf(v, o) then E.warnOnce("PrimaryPart set to a part outside the model") end
	o.props.PrimaryPart = v; return true
end

---------------------------------------------------------------- Attachment
D.Attachment = { Visible = false, CFrame = CF.identity }
local ag = cls(G, "Attachment")
ag.WorldCFrame = function(o) local p = o.parent; return (p and p.cframe or CF.identity) * (o.props.CFrame or CF.identity) end
ag.WorldPosition = function(o) return ag.WorldCFrame(o).Position end
ag.Position = function(o) return (o.props.CFrame or CF.identity).Position end
ag.Axis = function(o) return (o.props.CFrame or CF.identity).RightVector end
ag.SecondaryAxis = function(o) return (o.props.CFrame or CF.identity).UpVector end
ag.WorldAxis = function(o) return ag.WorldCFrame(o).RightVector end
ag.Orientation = function(o) local x, y, z = (o.props.CFrame or CF.identity):ToOrientation(); return V3.new(math.deg(x), math.deg(y), math.deg(z)) end
local as = cls(S, "Attachment")
as.Position = function(o, v) o.props.CFrame = (o.props.CFrame or CF.identity).Rotation + v; return true end
as.Orientation = function(o, v) o.props.CFrame = CF.new((o.props.CFrame or CF.identity).Position) * CF.fromOrientation(math.rad(v.X), math.rad(v.Y), math.rad(v.Z)); return true end
as.WorldPosition = function(o, v) local p = o.parent; o.props.CFrame = (o.props.CFrame or CF.identity).Rotation + ((p and p.cframe or CF.identity):PointToObjectSpace(v)); return true end
as.WorldCFrame = function(o, v) local p = o.parent; o.props.CFrame = (p and p.cframe or CF.identity):ToObjectSpace(v); return true end

---------------------------------------------------------------- lights, effects, misc defaults
D.Light = { Enabled = true, Brightness = 1, Color = C3.new(1, 1, 1), Shadows = false }
D.PointLight = { Range = 8 }
D.SpotLight = { Range = 16, Angle = 90, Face = function() return E.enumItem("NormalId", "Front") end }
D.SurfaceLight = { Range = 16, Angle = 90, Face = function() return E.enumItem("NormalId", "Front") end }
D.ParticleEmitter = { Enabled = true, Rate = 5, Lifetime = T.NumberRange.new(5, 10), Speed = T.NumberRange.new(5, 5), LightEmission = 0 }
D.Beam = { Enabled = true, Width0 = 1, Width1 = 1 }
D.Trail = { Enabled = true }
D.Fire = { Enabled = true }
D.Smoke = { Enabled = true }
D.Highlight = { Enabled = true, FillTransparency = 0.5, OutlineTransparency = 0, FillColor = C3.fromRGB(255, 0, 0), OutlineColor = C3.new(1, 1, 1) }
D.Decal = { Transparency = 0, Color3 = C3.new(1, 1, 1), Face = function() return E.enumItem("NormalId", "Front") end }
D.Texture = { StudsPerTileU = 2, StudsPerTileV = 2 }
D.SurfaceAppearance = {}
D.SpecialMesh = { Scale = V3.new(1, 1, 1) }
D.Sound = { Volume = 0.5, PlaybackSpeed = 1, RollOffMaxDistance = 10000, RollOffMinDistance = 10 }
D.ValueBase = {}
D.Atmosphere = { Density = 0.395, Offset = 0, Color = C3.fromRGB(199, 199, 199), Decay = C3.fromRGB(106, 112, 125), Glare = 0, Haze = 0 }
D.BloomEffect = { Enabled = true, Intensity = 0.4, Size = 24, Threshold = 0.95 }
D.ColorCorrectionEffect = { Enabled = true, TintColor = C3.new(1, 1, 1) }
D.SunRaysEffect = { Enabled = true, Intensity = 0.25, Spread = 1 }
D.DepthOfFieldEffect = { Enabled = true }
D.BlurEffect = { Enabled = true, Size = 24 }
D.Sky = { CelestialBodiesShown = true, StarCount = 3000 }
D.ProximityPrompt = {
	Enabled = true, MaxActivationDistance = 10, HoldDuration = 0, RequiresLineOfSight = true, ActionText = "Interact", ObjectText = "",
	KeyboardKeyCode = function() return E.enumItem("KeyCode", "E") end, Style = function() return E.enumItem("ProximityPromptStyle", "Default") end, UIOffset = T.Vector2.zero,
}
D.ClickDetector = { MaxActivationDistance = 32 }
D.LinearVelocity = { Enabled = true, MaxForce = 1000 }
D.AlignOrientation = { Enabled = true, MaxTorque = 10000, Responsiveness = 10, MaxAngularVelocity = math.huge }
D.AlignPosition = { Enabled = true, MaxForce = 10000, Responsiveness = 10, MaxVelocity = math.huge }
D.Constraint = { Enabled = true, Visible = false }
D.RemoteEvent = {}
D.Camera = { FieldOfView = 70, CameraType = function() return E.enumItem("CameraType", "Custom") end, CFrame = CF.new(0, 20, 20) }
D.Humanoid = { Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, UseJumpPower = true, AutoRotate = true, HipHeight = 2, DisplayDistanceType = function() return E.enumItem("HumanoidDisplayDistanceType", "Viewer") end, RequiresNeck = true, BreakJointsOnDeath = true, EvaluateStateMachine = true }
D.Players = { MaxPlayers = 6, CharacterAutoLoads = true, RespawnTime = 5 }
D.Lighting = { Brightness = 2, ClockTime = 14, GeographicLatitude = 41.73, Ambient = C3.fromRGB(70, 70, 70), OutdoorAmbient = C3.fromRGB(128, 128, 128), GlobalShadows = true, ExposureCompensation = 0, EnvironmentDiffuseScale = 0, EnvironmentSpecularScale = 0, FogEnd = 100000, FogStart = 0, FogColor = C3.fromRGB(192, 192, 192), ShadowSoftness = 0.2, ColorShift_Top = C3.new(0, 0, 0), ColorShift_Bottom = C3.new(0, 0, 0) }
D.Workspace = { Gravity = 196.2, FallenPartsDestroyHeight = -500 }
D.StarterGui = { ShowDevelopmentGui = true }
D.SoundService = {}
D.Tool = { RequiresHandle = true, CanBeDropped = true, Enabled = true }
D.ViewportFrame = { Ambient = C3.fromRGB(200, 200, 200), LightColor = C3.fromRGB(140, 140, 140), LightDirection = V3.new(-1, -1, -1), ImageTransparency = 0, ImageColor3 = C3.new(1, 1, 1) }

-- Lighting
local Lm = cls(M, "Lighting")
function Lm.GetSunDirection(o)
	local t = (o.props.ClockTime or 14)
	local a = (t - 6) / 12 * math.pi
	return V3.new(math.cos(a) * 0.6, math.sin(a), -0.4).Unit
end
function Lm.GetMoonDirection(o) return -Lm.GetSunDirection(o) end
function Lm.GetMinutesAfterMidnight(o) return (o.props.ClockTime or 14) * 60 end
function Lm.SetMinutesAfterMidnight(o, m) o.props.ClockTime = (m / 60) % 24 end
cls(G, "Lighting").TimeOfDay = function(o) local t = o.props.ClockTime or 14; return string.format("%02d:%02d:00", math.floor(t), math.floor(t % 1 * 60)) end
cls(S, "Lighting").TimeOfDay = function(o, v) local h, m = v:match("(%d+):(%d+)"); o.props.ClockTime = (tonumber(h) or 0) + (tonumber(m) or 0) / 60; return true end

-- value objects: Value type check
for _, vc in ipairs({ "StringValue", "IntValue", "NumberValue", "BoolValue", "ObjectValue", "Vector3Value", "CFrameValue", "Color3Value" }) do
	E.CREATED[vc] = function(o) end
end
D.StringValue = { Value = "" }
D.IntValue = { Value = 0 }
D.NumberValue = { Value = 0 }
D.BoolValue = { Value = false }
local function valueSig(o) E.fireEv(o, "Changed", o.props.Value) end
for _, vc in ipairs({ "StringValue", "IntValue", "NumberValue", "BoolValue", "ObjectValue", "Vector3Value", "CFrameValue", "Color3Value" }) do
	cls(S, vc).Value = function(o, v) o.props.Value = v; valueSig(o); if o.psig and o.psig.Value then E.fire(o.psig.Value) end return true end
end

-- Sound
local Sm = cls(M, "Sound")
function Sm.Play(o) o.playing = true; o.props.Playing = true end
function Sm.Stop(o) o.playing = false; o.props.Playing = false end
function Sm.Pause(o) o.playing = false; o.props.Playing = false end
function Sm.Resume(o) o.playing = true; o.props.Playing = true end
cls(G, "Sound").IsPlaying = function(o) return o.playing == true end
cls(G, "Sound").IsLoaded = function() return true end
cls(G, "Sound").TimeLength = function() return 1 end
cls(S, "Sound").SoundId = function(o, v)
	if v ~= "" and not v:match("^rbxassetid://%d+$") and not v:match("^rbxasset://") and not v:match("^https?://") then E.warnOnce("odd SoundId " .. v) end
	o.props.SoundId = v; return true
end

-- ParticleEmitter, misc methods
cls(M, "ParticleEmitter").Emit = function(o, n) o.emitted = (o.emitted or 0) + (n or 16) end
cls(M, "ParticleEmitter").Clear = function() end

-- BindableEvent/Function
local BEm = cls(M, "BindableEvent")
function BEm.Fire(o, ...) E.fireEv(o, "Event", ...) end
local BFm = cls(M, "BindableFunction")
function BFm.Invoke(o, ...)
	local f = o.callbacks.OnInvoke
	if not f then error("BindableFunction has no OnInvoke callback", 2) end
	return f(...)
end

-- CollectionService-like tag helpers are in services.lua
return E

-- Server: profiles, player garages, physical parts, engine/moped assembly, shop and delivery, porting, paint, riding.
-- Everything the client does is checked here (rules in Economy/Assembly + distance to the player + own garage).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local PhysicsService = game:GetService("PhysicsService")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local Builder = require(Shared.Builder)
local GarageBuilder = require(Shared.GarageBuilder)
local S = 1 / Config.STUD
local REACH = 14 -- studs: how far from an object the player may act

pcall(function()
	PhysicsService:RegisterCollisionGroup("Rider")
	PhysicsService:CollisionGroupSetCollidable("Rider", "Default", false)
	PhysicsService:CollisionGroupSetCollidable("Rider", "Rider", false)
end)
local function setRider(char, on) for _, d in ipairs(char:GetDescendants()) do if d:IsA("BasePart") then d.CollisionGroup = on and "Rider" or "Default" end end end

local remotes = Instance.new("Folder"); remotes.Name = "Remotes"; remotes.Parent = RS
local Api = Instance.new("RemoteFunction"); Api.Name = "Api"; Api.Parent = remotes
local StateEv = Instance.new("RemoteEvent"); StateEv.Name = "State"; StateEv.Parent = remotes
local Report = Instance.new("RemoteEvent"); Report.Name = "Report"; Report.Parent = remotes

local store
pcall(function() store = DataStoreService:GetDataStore("MoppeMekaniker_v2") end)
if not store then warn("DataStore är inte tillgänglig: inget sparas") end

-- ---------- garages ----------
local plotsFolder = Instance.new("Folder"); plotsFolder.Name = "Garages"; plotsFolder.Parent = workspace
local PLOTS = {}
for i, pl in ipairs(Config.PLOTS) do
	local origin = CFrame.new(pl.x * S, 0, -pl.z * S)
	local refs = GarageBuilder.build(plotsFolder, origin, i)
	local dyn = Instance.new("Folder"); dyn.Name = "Dynamic"; dyn.Parent = refs.model
	refs.dyn = dyn
	PLOTS[i] = { refs = refs, owner = nil }
end

local profiles, sessions = {}, {}
local function now() return os.time() end
local function public(plr)
	local s = sessions[plr]
	local o = Economy.public(profiles[plr])
	o._plot, o._carry, o._out = s.plot, s.carry, s.out
	return o
end
local function push(plr, msg)
	if profiles[plr] then StateEv:FireClient(plr, public(plr), msg) end
end

-- ---------- drawing a garage's contents ----------
local function M2(x) return x * S end
local function hand(char) return char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")) end
local function anchorAt(model, cf)
	model:PivotTo(cf)
	for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true; p.CanQuery = true end end
end
local function itemModel(plr, u)
	local it = profiles[plr].items[u]
	local m = Builder.item(it.s, it)
	m.Name = "Item_" .. u
	m:SetAttribute("Item", u); m:SetAttribute("Plot", sessions[plr].plot); m:SetAttribute("Interact", "item")
	if it.dry then m:SetAttribute("Wet", true) end
	return m
end
local function slotsFor(refs, loc)
	if loc == "bench" then local t = {}; for _, c in ipairs(refs.standTray) do table.insert(t, c) end; for _, c in ipairs(refs.benchSlots) do table.insert(t, c) end; return t end
	if loc == "shelf" then return refs.shelfSlots end
	if loc == "floor" then return refs.floorSlots end
	if loc == "booth" then return { refs.booth } end
	if loc == "portbench" then return { refs.portbench } end
	return nil
end
local function mopedView(p, id)
	local mp = p.mopeds[id]
	local v = { mopId = id, ch = {}, eng = nil }
	for sock, u in pairs(mp.ch) do if u ~= "engine" and p.items[u] then v.ch[sock] = { sku = p.items[u].s, item = u, data = p.items[u] } end end
	if mp.engAt == "moped" then v.eng = {}; for sock, u in pairs(mp.eng) do if p.items[u] then v.eng[sock] = { sku = p.items[u].s, item = u, data = p.items[u] } end end end
	return v
end
-- the current moped: drivable (unanchored, upright via AlignOrientation), the client owns its physics
local function physicalMoped(plr, model, cf)
	local root = model.PrimaryPart
	local mop = Config.BY_ID[model:GetAttribute("Moped")]
	model:PivotTo(cf * CFrame.new(0, (mop.wr + 0.15) * S + 0.05, 0))
	local att = Instance.new("Attachment"); att.Name = "Drive"; att.Parent = root
	local lv = Instance.new("LinearVelocity"); lv.Name = "Drive"; lv.Attachment0 = att; lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis, lv.SecondaryTangentAxis = Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World; lv.MaxForce = 2e4; lv.PlaneVelocity = Vector2.new(0, 0); lv.Parent = root
	local ao = Instance.new("AlignOrientation"); ao.Name = "Tilt"; ao.Mode = Enum.OrientationAlignmentMode.OneAttachment; ao.Attachment0 = att
	ao.Responsiveness = 40; ao.MaxTorque = 1e6; ao.RigidityEnabled = false; ao.CFrame = cf.Rotation; ao.Parent = root
	local owner = Instance.new("ObjectValue"); owner.Name = "Owner"; owner.Value = plr; owner.Parent = model
	model.Parent = workspace
	for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then pcall(function() d:SetNetworkOwner(plr) end) end end
	local seat = model:FindFirstChild("Seat")
	if seat then
		local last
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			local hum = seat.Occupant
			if hum and hum.Parent then last = hum.Parent; setRider(last, true) elseif last then setRider(last, false); last = nil end
		end)
	end
end

local function render(plr, what)
	local p, s = profiles[plr], sessions[plr]
	if not (p and s and s.plot) then return end
	local refs = PLOTS[s.plot].refs
	what = what or "all"
	-- loose parts
	if what == "all" or what == "items" then
		for _, c in ipairs(refs.dyn:GetChildren()) do if c.Name:sub(1, 5) == "Item_" or c.Name:sub(1, 4) == "Box_" then c:Destroy() end end
		local byLoc = {}
		for u, it in pairs(p.items) do if u ~= s.carry then byLoc[it.loc] = byLoc[it.loc] or {}; table.insert(byLoc[it.loc], u) end end
		for loc, list in pairs(byLoc) do
			table.sort(list, function(a, b) return (tonumber(a:sub(2)) or 0) < (tonumber(b:sub(2)) or 0) end)
			local slots = slotsFor(refs, loc)
			if slots then
				for i, u in ipairs(list) do
					local m = itemModel(plr, u)
					local slot = slots[(i - 1) % #slots + 1] * CFrame.new(0, math.floor((i - 1) / #slots) * 0.6, 0)
					local _, size = m:GetBoundingBox()
					anchorAt(m, slot * CFrame.new(0, size.Y / 2, 0))
					m.Parent = refs.dyn
				end
			end
		end
		-- delivery boxes outside the door
		local n = 0
		for _, o in ipairs(p.orders) do
			if o.state == "arrived" then
				n = n + 1
				local box = Instance.new("Part"); box.Name = "Box_" .. o.id; box.Size = Vector3.new(M2(0.7), M2(0.5), M2(0.5)); box.Anchored = true
				box.CFrame = refs.delivery * CFrame.new((n - 1) * M2(0.9), M2(0.25), 0); box.Color = Color3.fromRGB(176, 136, 90); box.Material = Enum.Material.Fabric
				box:SetAttribute("Interact", "box"); box:SetAttribute("Order", o.id); box:SetAttribute("Plot", s.plot); box:SetAttribute("Hint", "Öppna leveransen")
				local tape = Instance.new("Part"); tape.Size = Vector3.new(box.Size.X + 0.02, 0.06, M2(0.08)); tape.CFrame = box.CFrame * CFrame.new(0, box.Size.Y / 2, 0); tape.Anchored = true; tape.Color = Color3.fromRGB(200, 170, 80); tape.Parent = box
				box.Parent = refs.dyn
			end
		end
		-- the carried part in the hand
		if s.carry and p.items[s.carry] and plr.Character then
			local old = plr.Character:FindFirstChild("Carried"); if old then old:Destroy() end
			local h = hand(plr.Character)
			if h then
				local m = itemModel(plr, s.carry); m.Name = "Carried"
				m:PivotTo(h.CFrame * CFrame.new(0, -0.4, -0.6))
				for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = false; d.Massless = true; d.CanCollide = false; d.CanQuery = false end end
				local w = Instance.new("WeldConstraint"); w.Part0, w.Part1 = h, m.PrimaryPart; w.Parent = m.PrimaryPart
				m.Parent = plr.Character
			end
		elseif plr.Character and plr.Character:FindFirstChild("Carried") then plr.Character.Carried:Destroy() end
	end
	-- the engine on the stand
	if what == "all" or what == "engine" then
		local old = refs.dyn:FindFirstChild("Engine"); if old then old:Destroy() end
		if p.stand then
			local map = {}
			for sock, u in pairs(p.mopeds[p.stand].eng) do if p.items[u] then map[sock] = { sku = p.items[u].s, item = u, data = p.items[u] } end end
			local e = Builder.engine(refs.dyn, refs.stand, p.stand, map, true)
			e:SetAttribute("Interact", "engine"); e:SetAttribute("Plot", s.plot); e:SetAttribute("Moped", p.stand)
		end
	end
	-- mopeds: the current one drivable at the moped spot, the others parked
	if what == "all" or what == "moped" then
		for _, c in ipairs(refs.dyn:GetChildren()) do if c.Name:sub(1, 7) == "Parked_" then c:Destroy() end end
		if not s.out then
			if s.moped then s.moped:Destroy(); s.moped = nil end
			if p.mopeds[p.cur] then
				local m = Builder.moped(mopedView(p, p.cur))
				m.Name = "Moped_" .. plr.Name
				m:SetAttribute("Interact", "moped"); m:SetAttribute("Plot", s.plot)
				if Economy.canRide(p, p.cur) then physicalMoped(plr, m, refs.moped)
				else
					-- not complete: stands still as if on a work stand (without wheels it would otherwise fall through the floor)
					local mop = Config.BY_ID[p.cur]
					anchorAt(m, refs.moped * CFrame.new(0, (mop.wr + 0.15) * S, 0))
					m.Parent = workspace
				end
				s.moped = m
			end
		end
		local k = 0
		for id, mp in pairs(p.mopeds) do
			if id ~= p.cur and mp.own then
				k = k + 1
				local spot = refs.parking[k]
				if spot then
					local m = Builder.moped(mopedView(p, id)); m.Name = "Parked_" .. id
					m:SetAttribute("Interact", "parked"); m:SetAttribute("Plot", s.plot)
					local mop = Config.BY_ID[id]
					anchorAt(m, spot * CFrame.new(0, (mop.wr + 0.15) * S, 0))
					m.Parent = refs.dyn
				end
			end
		end
	end
end

-- ---------- validation helpers ----------
local function near(plr, pos, dist)
	local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil and (hrp.Position - pos).Magnitude <= (dist or REACH)
end
local function inGarage(plr)
	local s = sessions[plr]
	return s.plot and near(plr, PLOTS[s.plot].refs.origin.Position, 60)
end
local function mopedHome(plr)
	local s = sessions[plr]
	return s.moped and s.moped.Parent and not s.out and (s.moped:GetPivot().Position - PLOTS[s.plot].refs.moped.Position).Magnitude < 20
end

-- ---------- API ----------
local H = {}
H.state = function() return true end
H.pickup = function(plr, u)
	local p, s = profiles[plr], sessions[plr]
	local it = p.items[u]
	if s.carry then return false, "Du bär redan något" end
	if not it then return false, "Okänd del" end
	if it.loc:sub(1, 4) == "eng:" or it.loc:sub(1, 3) == "ch:" or it.loc == "tool" then return false, "Delen sitter monterad" end
	if it.loc:sub(1, 4) == "box:" then return false, "Öppna lådan först" end
	local m = PLOTS[s.plot].refs.dyn:FindFirstChild("Item_" .. u)
	if not m or not near(plr, m:GetPivot().Position) then return false, "För långt bort" end
	s.carry = u
	render(plr, "items")
	return true
end
H.place = function(plr, loc)
	local p, s = profiles[plr], sessions[plr]
	if not s.carry then return false, "Du bär ingenting" end
	if not inGarage(plr) then return false, "Gå in i ditt garage" end
	local target = loc == "booth" and PLOTS[s.plot].refs.booth or loc == "portbench" and PLOTS[s.plot].refs.portbench or nil
	if target and not near(plr, target.Position) then return false, "För långt bort" end
	local ok, err = Economy.move(p, s.carry, loc)
	if not ok then return false, err end
	s.carry = nil
	render(plr, "items")
	return true, loc == "booth" and "Kåpan ligger i lackboxen" or loc == "portbench" and "Cylindern ligger på portningsbänken" or nil
end
H.mountEngine = function(plr, u, sock)
	local p, s = profiles[plr], sessions[plr]
	if not near(plr, PLOTS[s.plot].refs.stand.Position, 18) then return false, "Gå fram till motorstativet" end
	if u ~= s.carry then
		local m = PLOTS[s.plot].refs.dyn:FindFirstChild("Item_" .. tostring(u))
		if not m or not near(plr, m:GetPivot().Position, 18) then return false, "Delen ligger för långt bort" end
	end
	local ok, err = Economy.mountEngine(p, u, sock)
	if not ok then return false, err end
	if s.carry == u then s.carry = nil end
	render(plr, "items"); render(plr, "engine")
	if #Economy.engineMissing(p, p.stand) == 0 then return true, "Motorn är komplett! Klicka på mopeden för att montera den." end
	return true
end
H.unmountEngine = function(plr, sock)
	local p, s = profiles[plr], sessions[plr]
	if not near(plr, PLOTS[s.plot].refs.stand.Position, 18) then return false, "Gå fram till motorstativet" end
	local ok, err = Economy.unmountEngine(p, sock, "bench")
	if not ok then return false, err end
	render(plr, "items"); render(plr, "engine")
	return true
end
H.mountMoped = function(plr, u, sock)
	local p, s = profiles[plr], sessions[plr]
	if not mopedHome(plr) or not near(plr, s.moped:GetPivot().Position, 18) then return false, "Gå fram till mopeden i garaget" end
	local ok, err = Economy.mountMoped(p, u, p.cur, sock)
	if not ok then return false, err end
	if s.carry == u then s.carry = nil end
	render(plr, "items"); render(plr, "moped")
	return true
end
H.unmountMoped = function(plr, sock)
	local p, s = profiles[plr], sessions[plr]
	if not mopedHome(plr) or not near(plr, s.moped:GetPivot().Position, 18) then return false, "Gå fram till mopeden i garaget" end
	local ok, err = Economy.unmountMoped(p, p.cur, sock, "bench")
	if not ok then return false, err end
	render(plr, "items"); render(plr, "moped")
	return true, "Lagd på arbetsbänken"
end
H.engineToStand = function(plr)
	local p = profiles[plr]
	if not mopedHome(plr) then return false, "Mopeden måste stå i garaget" end
	local ok, err = Economy.engineToStand(p, p.cur)
	if not ok then return false, err end
	render(plr)
	return true, "Motorn sitter i motorstativet"
end
H.engineToMoped = function(plr)
	local p = profiles[plr]
	if p.stand ~= p.cur then return false, "Välj mopeden som motorn hör till" end
	if not mopedHome(plr) then return false, "Mopeden måste stå i garaget" end
	local ok, err = Economy.engineToMoped(p)
	if not ok then return false, err end
	render(plr)
	return true, "Motorn monterad i mopeden"
end
H.order = function(plr, lines)
	local p = profiles[plr]
	local ok, err, o = Economy.order(p, lines, now())
	if not ok then return false, err end
	return true, "Beställning " .. o.id .. " skickad. Leverans om " .. math.ceil((o.eta - now()) / 60) .. " min."
end
H.openBox = function(plr, oid)
	local p, s = profiles[plr], sessions[plr]
	if not near(plr, PLOTS[s.plot].refs.delivery.Position, 18) then return false, "Gå till leveranslådan" end
	local ok, err = Economy.openBox(p, oid)
	if not ok then return false, err end
	render(plr, "items")
	return true, "Lådan öppnad, delarna ligger bredvid"
end
H.portStart = function(plr, training)
	local p, s = profiles[plr], sessions[plr]
	if not near(plr, PLOTS[s.plot].refs.portbench.Position, 18) then return false, "Gå till portningsbänken" end
	local tool = Economy.hasTool(p, "grinder")
	if not tool then return false, "Du behöver en slipmaskin (finns i butiken)" end
	local cyl = nil
	for u, it in pairs(p.items) do if it.loc == "portbench" then cyl = u end end
	if not training and not cyl then return false, "Lägg en cylinder på portningsbänken" end
	if not training and p.items[cyl].port then return false, "Cylindern är redan portad" end
	s.portT0, s.portItem = os.clock(), (not training) and cyl or nil
	return true, tool.val.steady
end
H.portDone = function(plr, res)
	local p, s = profiles[plr], sessions[plr]
	if not s.portT0 then return false, "Ingen portning pågår" end
	local t = os.clock() - s.portT0
	local u = s.portItem
	s.portT0, s.portItem = nil, nil
	if not u then return true, "Träningen är klar" end
	if type(res) ~= "table" or t < 8 then return false, "Portningen gick för fort, inget ändrades" end
	local ok, err = Economy.applyPort(p, u, res)
	if not ok then return false, err end
	render(plr, "items")
	return true, "Portningen sparad: " .. tostring(p.items[u].port.label)
end
H.paintStart = function(plr)
	local p, s = profiles[plr], sessions[plr]
	if not near(plr, PLOTS[s.plot].refs.booth.Position, 18) then return false, "Gå till lackboxen" end
	local tool = Economy.hasTool(p, "spray")
	if not tool then return false, "Du behöver en sprutpistol" end
	for u, it in pairs(p.items) do if it.loc == "booth" then s.paintT0, s.paintItem = os.clock(), u; return true, tool.val.even end end
	return false, "Lägg en kåpa i lackboxen"
end
H.paintDone = function(plr, col, fin, q)
	local p, s = profiles[plr], sessions[plr]
	if not s.paintT0 then return false, "Ingen lackering pågår" end
	local t, u = os.clock() - s.paintT0, s.paintItem
	s.paintT0, s.paintItem = nil, nil
	if t < 4 then return false, "Lackeringen gick för fort, inget ändrades" end
	local ok, err = Economy.applyPaint(p, u, col, fin, q, now())
	if not ok then return false, err end
	render(plr, "items")
	return true, "Lackerad! Låt lacken torka " .. Config.PAINT_DRY .. " s"
end
H.saveDesign = function(plr, name) local p = profiles[plr]; return Economy.saveDesign(p, p.cur, name) end
H.applyDesign = function(plr, name)
	local ok, err = Economy.applyDesign(profiles[plr], name)
	if ok and mopedHome(plr) then render(plr, "moped") end
	return ok, err
end
H.select = function(plr, id)
	local p, s = profiles[plr], sessions[plr]
	if not p.mopeds[id] then return false, "Du äger inte mopeden" end
	if s.out then return false, "Kör tillbaka till garaget först (R)" end
	p.cur = id
	render(plr, "moped")
	return true
end
H.ride = function(plr)
	local p, s = profiles[plr], sessions[plr]
	if not Economy.canRide(p, p.cur) then
		local miss = Economy.mopedMissing(p, p.cur)
		return false, "Mopeden är inte färdig. Saknas: " .. table.concat(miss, ", ")
	end
	if not s.moped then render(plr, "moped") end
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if hum and s.moped and s.moped:FindFirstChild("Seat") then s.moped.Seat:Sit(hum); s.out = true end
	return true
end
H.home = function(plr)
	local s = sessions[plr]
	s.out = false
	render(plr, "moped")
	return true
end
H.buyMoped = function(plr, id) local ok, err = Economy.buyMoped(profiles[plr], id, now()); if ok then render(plr, "moped") end; return ok, err end
H.sellMoped = function(plr, id) local ok, err = Economy.sellMoped(profiles[plr], id, now()); if ok then sessions[plr].out = false; render(plr) end; return ok, err end
H.sell = function(plr, u)
	local s = sessions[plr]
	if s.carry == u then return false, "Lägg ner delen först" end
	local ok, err = Economy.sell(profiles[plr], u, now()); if ok then render(plr, "items") end; return ok, err
end
H.repair = function(plr, emergency) local p = profiles[plr]; return Economy.repair(p, p.cur, emergency == true, now()) end
H.setJet = function(plr, jet) local p = profiles[plr]; return Economy.setJet(p, p.cur, jet) end
H.save = function(plr) return true, "Sparas automatiskt" end

Api.OnServerInvoke = function(plr, action, ...)
	if not profiles[plr] or not sessions[plr] or not sessions[plr].plot then return false, "Profilen laddas" end
	local h = type(action) == "string" and H[action]
	if not h then return false, "Okänt anrop" end
	local ok, a, b = pcall(h, plr, ...)
	if not ok then warn("Fel i " .. action .. ": " .. tostring(a)); return false, "Serverfel" end
	push(plr, type(b) == "string" and b or nil)
	return a, b
end

-- reports from the client while riding (checked against what the server sees)
Report.OnServerEvent:Connect(function(plr, kind, a, b, c, d)
	local p, s = profiles[plr], sessions[plr]
	if not p then return end
	if kind == "engine" then s.engineOn = a == true
	elseif kind == "dmg" then if type(a) == "number" and p.mopeds[p.cur] then p.mopeds[p.cur].dmg = math.clamp(a, 0, 1) end
	elseif kind == "dirty" then Economy.dirty(p)
	elseif kind == "crash" then Economy.crash(p, tostring(a):sub(1, 60), now()); push(plr)
	elseif kind == "wheelie" then
		local seen, t0 = 0, os.clock() - (tonumber(a) or 0)
		for _, e in ipairs(s.distLog) do if e[1] >= t0 then seen = seen + e[2] end end
		local r, why = Economy.wheelie(p, a, b, c, d, now(), seen)
		push(plr, r > 0 and ("Stegring: +" .. r .. " kr") or why)
	end
end)

-- ---------- loops: distance, delivery, drying ----------
local acc, tickAcc = 0, 0
RunService.Heartbeat:Connect(function(dt)
	acc, tickAcc = acc + dt, tickAcc + dt
	if acc >= 0.5 then
		local step = acc; acc = 0
		for plr, s in pairs(sessions) do
			local p, m = profiles[plr], s.moped
			local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			local seated = m and m.Parent and hum and hum.SeatPart == m:FindFirstChild("Seat")
			if seated then s.out = true
			elseif s.out and m and m.Parent and s.plot and (m:GetPivot().Position - PLOTS[s.plot].refs.moped.Position).Magnitude < 25 then s.out = false end -- parked at home again
			if seated and s.engineOn then
				local pos = m:GetPivot().Position
				if s.last then
					local d = Vector3.new(pos.X - s.last.X, 0, pos.Z - s.last.Z).Magnitude * Config.STUD
					if d / step <= Config.ECON.maxSpeed then
						local got = Economy.addDistance(p, d, now())
						p.stats.top = math.max(p.stats.top, d / step)
						table.insert(s.distLog, { os.clock(), d })
						if got > 0 then push(plr) end
					end
				end
				s.last = pos
			else s.last = nil end
			while #s.distLog > 0 and os.clock() - s.distLog[1][1] > 130 do table.remove(s.distLog, 1) end
		end
	end
	if tickAcc >= 1 then
		tickAcc = 0
		for plr, p in pairs(profiles) do
			local arrived = Economy.tick(p, now())
			local wet = false
			for _, it in pairs(p.items) do if it.dry then wet = true end end
			Economy.dryTick(p, now())
			if #arrived > 0 then render(plr, "items"); push(plr, "Leverans! Paketet står utanför garageporten.") end
			if wet then local still = false; for _, it in pairs(p.items) do if it.dry then still = true end end; if not still then render(plr, "items"); push(plr, "Lacken har torkat") end end
		end
	end
end)

-- ---------- join/leave ----------
local function load(plr)
	local raw, ok = nil, false
	if store then
		for attempt = 1, 3 do
			ok = pcall(function() raw = store:GetAsync("p_" .. plr.UserId) end)
			if ok then break end
			task.wait(attempt)
		end
	end
	profiles[plr] = Economy.load(raw)
	sessions[plr] = { saveOk = store ~= nil and ok, distLog = {}, out = false }
	for i, pl in ipairs(PLOTS) do
		if not pl.owner then pl.owner = plr; sessions[plr].plot = i; pl.refs.sign.Text = string.upper(plr.DisplayName) .. "S GARAGE"; break end
	end
	if not sessions[plr].plot then warn("Alla garage är upptagna") end
end
local function save(plr)
	local p, s = profiles[plr], sessions[plr]
	if not (p and s and store and s.saveOk) then return end
	local ok, err = pcall(function() store:SetAsync("p_" .. plr.UserId, Economy.public(p)) end)
	if not ok then warn("Kunde inte spara " .. plr.Name .. ": " .. tostring(err)) end
end
local function onAdded(plr)
	if profiles[plr] then return end
	load(plr)
	local function spawnChar(char)
		local s = sessions[plr]
		if not s or not s.plot then return end
		local hrp = char:WaitForChild("HumanoidRootPart", 10)
		if hrp then hrp.CFrame = PLOTS[s.plot].refs.spawn + Vector3.new(0, 3, 0) end
		s.out, s.carry = false, nil
		task.wait(0.5)
		render(plr)
		push(plr)
	end
	plr.CharacterAdded:Connect(spawnChar)
	if plr.Character then task.spawn(spawnChar, plr.Character) end
	push(plr, store and (sessions[plr].saveOk and "Välkommen till ditt garage!" or "Sparningen kunde inte läsas, inget sparas den här gången") or "Sparning är avstängd (DataStore saknas i Studio)")
end
Players.PlayerAdded:Connect(onAdded)
for _, plr in ipairs(Players:GetPlayers()) do task.spawn(onAdded, plr) end
Players.PlayerRemoving:Connect(function(plr)
	save(plr)
	local s = sessions[plr]
	if s then
		if s.moped then s.moped:Destroy() end
		if s.plot then PLOTS[s.plot].owner = nil; PLOTS[s.plot].refs.sign.Text = "LEDIGT GARAGE"; PLOTS[s.plot].refs.dyn:ClearAllChildren() end
	end
	profiles[plr], sessions[plr] = nil, nil
end)
game:BindToClose(function() for plr in pairs(profiles) do save(plr) end end)
task.spawn(function() while true do task.wait(60); for plr in pairs(profiles) do save(plr) end end end)

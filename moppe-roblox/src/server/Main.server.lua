-- The server: one garage per player, saved profiles, every change to a profile (validated here only),
-- the physical things other players see (moped, engine, parts, boxes), deliveries, riding and jobs.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Parts = require(Shared.Parts)
local EngineDef = require(Shared.EngineDef)
local MopedDef = require(Shared.MopedDef)
local Profile = require(Shared.Profile)
local Models = require(Shared.Models)
local GarageBuilder = require(Shared.GarageBuilder)
local Map = require(Shared.Map)

local V3, CF = Vector3.new, CFrame.new
local function now() return workspace:GetServerTimeNow() end

---------------------------------------------------------------- remotes and collision groups
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local Api = Instance.new("RemoteFunction")
Api.Name = "Api"
Api.Parent = remotes
local StateEv = Instance.new("RemoteEvent")
StateEv.Name = "State"
StateEv.Parent = remotes
local Notify = Instance.new("RemoteEvent")
Notify.Name = "Notify"
Notify.Parent = remotes
local RideEv = Instance.new("RemoteEvent")
RideEv.Name = "Ride"
RideEv.Parent = remotes
remotes.Parent = RS

PhysicsService:RegisterCollisionGroup("Moped")
PhysicsService:CollisionGroupSetCollidable("Moped", "Default", false)

---------------------------------------------------------------- data store
local store
local okStore = pcall(function() store = DataStoreService:GetDataStore(Config.SAVE_KEY) end)
if not okStore then store = nil end
local saving = {} -- plr -> bool (whether saving works for this player)

---------------------------------------------------------------- stock (shared by all players, restocks slowly)
local stock = {}
for _, it in ipairs(Parts.LIST) do stock[it.sku] = it.stock end
task.spawn(function()
	while true do
		task.wait(120)
		for _, it in ipairs(Parts.LIST) do if stock[it.sku] < it.stock then stock[it.sku] = stock[it.sku] + 1 end end
	end
end)

---------------------------------------------------------------- plots
local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Garage"
plotsFolder.Parent = workspace
local plots = {}
for i = 1, Config.MAX_PLAYERS do
	local origin = CF(Config.plotOrigin(i), 0, 0)
	local folder = Instance.new("Folder")
	folder.Name = "Plot" .. i
	folder:SetAttribute("Plot", i)
	folder:SetAttribute("OwnerId", 0)
	folder.Parent = plotsFolder
	local refs = GarageBuilder.build(folder, origin, i)
	local dyn = Instance.new("Folder")
	dyn.Name = "Dynamic"
	dyn.Parent = folder
	plots[i] = { i = i, origin = origin, folder = folder, refs = refs, dyn = dyn, owner = nil }
	-- station prompts (the client opens the work modes; the server only checks actions)
	local function prompt(part, action, text, key, obj, offset)
		if offset then
			-- separate spot on the part so two prompts on one station do not overlap
			local att = Instance.new("Attachment")
			att.Name = "Fäste_" .. action
			att.Position = offset
			att.Parent = part
			part = att
		end
		local pp = Instance.new("ProximityPrompt")
		pp.Name = "Prompt_" .. action
		pp.ActionText = text
		pp.ObjectText = obj or ""
		pp.KeyboardKeyCode = key or Enum.KeyCode.E
		pp.MaxActivationDistance = 9
		pp.RequiresLineOfSight = false
		pp:SetAttribute("Action", action)
		pp:SetAttribute("Plot", i)
		pp.Parent = part
		return pp
	end
	local function find(name) return refs.model:FindFirstChild(name, true) end
	prompt(find("Lyftbord"), "work", "Arbeta på mopeden", Enum.KeyCode.E, "Mopedlyft", Vector3.new(1.6, 1.2, 1.8))
	local ridePrompt = prompt(find("Lyftbord"), "ride", "Kör ut", Enum.KeyCode.F, "Mopedlyft", Vector3.new(1.6, 1.2, -3.2))
	ridePrompt.UIOffset = Vector2.new(0, 70)
	prompt(find("Motorstativ"), "engine", "Bygg motor", Enum.KeyCode.E, "Motorstativ")
	prompt(refs.screen, "shop", "Använd datorn", Enum.KeyCode.E, "Dator")
	prompt(find("Skruvstäd"), "port", "Porta cylinder", Enum.KeyCode.E, "Portningsbänk")
	prompt(find("Lackstativ"), "paint", "Lackera", Enum.KeyCode.E, "Lackbox")
end

---------------------------------------------------------------- per-player state
local profiles = {} -- plr -> profile
local plotOf = {} -- plr -> plot
local riding = {} -- plr -> { moped = model, last = pos }

local function pushState(plr)
	local p = profiles[plr]
	if not p then return end
	StateEv:FireClient(plr, p, { now = now(), plot = plotOf[plr] and plotOf[plr].i, saving = saving[plr] == true, stock = stock })
end
local function notify(plr, text, kind) Notify:FireClient(plr, text, kind or "info") end

local function clear(folder, name)
	local o = folder:FindFirstChild(name)
	if o then o:Destroy() end
end
local function newFolder(parent, name)
	clear(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- items lying around: shelf, bench, floor, hand, porting vise, paint stand
local function itemSlots(p, loc)
	local ids = {}
	for id, it in pairs(p.items) do if it.loc == loc then ids[#ids + 1] = id end end
	table.sort(ids, function(a, b) return tonumber(a:sub(2)) < tonumber(b:sub(2)) end)
	return ids
end
local function placeItem(parent, id, it, cf, plr)
	local model = Models.item(it.sku, it)
	model.Name = "Del_" .. id
	model:SetAttribute("Item", id)
	model:SetAttribute("OwnerId", plr.UserId)
	model:PivotTo(cf * CF(0, model.PrimaryPart.Size.Y / 2, 0))
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.CanQuery = true end
	end
	model.Parent = parent
	return model
end
local function renderItems(plr)
	local p, plot = profiles[plr], plotOf[plr]
	if not (p and plot) then return end
	local f = newFolder(plot.dyn, "Delar")
	local refs = plot.refs
	for i, id in ipairs(itemSlots(p, "hylla")) do if refs.shelfSlots[i] then placeItem(f, id, p.items[id], refs.shelfSlots[i], plr) end end
	for i, id in ipairs(itemSlots(p, "bank")) do if refs.benchSlots[i] then placeItem(f, id, p.items[id], refs.benchSlots[i], plr) end end
	for i, id in ipairs(itemSlots(p, "golv")) do
		local slot = refs.floorSlots[(i - 1) % #refs.floorSlots + 1]
		placeItem(f, id, p.items[id], slot * CF(0, math.floor((i - 1) / #refs.floorSlots) * 0.8, 0), plr)
	end
	for _, id in ipairs(itemSlots(p, "verktyg")) do
		local part = Parts.get(p.items[id].sku)
		local idx = ({ hylsor = 1, slip = 2, spruta = 3 })[part.stats.tool] or 4
		local m = placeItem(f, id, p.items[id], refs.toolSlots[idx] * CF(0, -0.6, 0), plr)
		m:SetAttribute("Tool", true)
	end
	for _, id in ipairs(itemSlots(p, "port")) do placeItem(f, id, p.items[id], plot.origin * GarageBuilder.PORT * CF(0, -0.4, 0), plr) end
	for _, id in ipairs(itemSlots(p, "lack")) do placeItem(f, id, p.items[id], plot.origin * GarageBuilder.BOOTH, plr) end
	-- the part in the player's hand
	local hand = itemSlots(p, "hand")[1]
	local char = plr.Character
	local grip = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	if hand and grip then
		local m = placeItem(f, hand, p.items[hand], grip.CFrame * CF(0, -0.4, -0.6), plr)
		local main = m.PrimaryPart
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.Massless = true
				if d ~= main then
					local w = Instance.new("WeldConstraint")
					w.Part0 = main
					w.Part1 = d
					w.Parent = d
				end
			end
		end
		local w = Instance.new("WeldConstraint")
		w.Part0 = grip
		w.Part1 = main
		w.Parent = main
		for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = false end end
		m:SetAttribute("InHand", true)
		m.Parent = char
		m.Name = "Bärs"
	end
end
local function renderEngine(plr)
	local p, plot = profiles[plr], plotOf[plr]
	if not (p and plot) then return end
	clear(plot.dyn, "Motor")
	local eng = Models.engine(plot.dyn, plot.origin * GarageBuilder.STAND, p.stand, p.items)
	eng:SetAttribute("OwnerId", plr.UserId)
end
local function renderBoxes(plr)
	local p, plot = profiles[plr], plotOf[plr]
	if not (p and plot) then return end
	local f = newFolder(plot.dyn, "Paket")
	local k = 0
	for _, o in ipairs(p.orders) do
		if o.state == "framme" or o.state == "oppnad" then
			k = k + 1
			local slot = plot.refs.deliverySlots[(k - 1) % #plot.refs.deliverySlots + 1]
			local cf = slot * CF(0, 0.7, 0) * CFrame.Angles(0, math.rad(8 * k), 0)
			local box = Models.box(f, cf, V3(2.2, 1.4, 1.6), o.state == "oppnad")
			box.Name = "Paket_" .. o.id
			box:SetAttribute("Order", o.id)
			if o.state == "framme" then
				local pp = Instance.new("ProximityPrompt")
				pp.ActionText = "Öppna paketet"
				pp.ObjectText = "Order #" .. o.id
				pp.MaxActivationDistance = 8
				pp.RequiresLineOfSight = false
				pp:SetAttribute("Action", "openBox")
				pp:SetAttribute("Order", o.id)
				pp:SetAttribute("Plot", plot.i)
				pp.Parent = box.PrimaryPart
			else
				-- the parts lie on top of the open box, ready to be picked up
				for j, id in ipairs(Profile.boxItems(p, o.id)) do
					placeItem(f, id, p.items[id], cf * CF(-0.6 + ((j - 1) % 3) * 0.6, 0.75 + math.floor((j - 1) / 3) * 0.5, 0), plr)
				end
			end
		end
	end
end
local function mopedCF(plot) return plot.origin * GarageBuilder.LIFT end
local function renderMoped(plr, force)
	local p, plot = profiles[plr], plotOf[plr]
	if not (p and plot) then return end
	if riding[plr] and not force then return end
	clear(plot.dyn, "Moped")
	local m = p.mopeds[p.cur]
	if not m then return end
	local model = Models.moped(plot.dyn, m, p.items, mopedCF(plot))
	model:SetAttribute("OwnerId", plr.UserId)
	model:SetAttribute("Plot", plot.i)
	return model
end
local function renderAll(plr)
	renderMoped(plr)
	renderEngine(plr)
	renderItems(plr)
	renderBoxes(plr)
end

---------------------------------------------------------------- riding
local function weldMoped(model)
	local root = model.PrimaryPart
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CollisionGroup = "Moped"
			if d ~= root then
				d.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = d
				w.Parent = d
			end
		end
	end
	for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = false end end
end
local function anchorMoped(model)
	for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true end end
end
local function seatPlayer(plr, model)
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	local seat = model:FindFirstChild("Seat")
	seat.Disabled = false
	seat:Sit(hum)
	return true
end
local function startRide(plr, model)
	weldMoped(model)
	local root = model.PrimaryPart
	if root:CanSetNetworkOwnership() then root:SetNetworkOwner(plr) end
	model:SetAttribute("Riding", true)
	riding[plr] = { moped = model, last = root.Position, t = now() }
	if not seatPlayer(plr, model) then return false end
	local seat = model:FindFirstChild("Seat")
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant == nil and riding[plr] and riding[plr].moped == model then
			-- the rider stepped off: park upright where it is
			local _, y = root.CFrame:ToOrientation()
			anchorMoped(model)
			model:PivotTo(CF(root.Position) * CFrame.Angles(0, y, 0))
			seat.Disabled = true
			model:SetAttribute("Riding", false)
			local pp = root:FindFirstChild("Prompt_mount")
			if not pp then
				pp = Instance.new("ProximityPrompt")
				pp.Name = "Prompt_mount"
				pp.ActionText = "Kör"
				pp.ObjectText = "Din moped"
				pp.MaxActivationDistance = 8
				pp.RequiresLineOfSight = false
				pp:SetAttribute("Action", "mount")
				pp.Parent = root
			end
			pp.Enabled = true
		end
	end)
	return true
end
local function goHome(plr)
	local r = riding[plr]
	riding[plr] = nil
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart then hum.Sit = false end
	if r and r.moped then r.moped:Destroy() end
	renderMoped(plr, true)
	local plot = plotOf[plr]
	if char and plot then
		task.defer(function()
			if char.Parent then char:PivotTo(plot.origin * CF(-2, GarageBuilder.FLOOR + 3, -6)) end
		end)
	end
end

---------------------------------------------------------------- distance checks
local function charPos(plr)
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end
local function near(plr, pos, dist)
	local cp = charPos(plr)
	return cp ~= nil and (cp - pos).Magnitude <= (dist or Config.REACH)
end
local function inGarage(plr)
	local cp, plot = charPos(plr), plotOf[plr]
	if not (cp and plot) then return false end
	local l = plot.origin:PointToObjectSpace(cp)
	return math.abs(l.X) < GarageBuilder.W / 2 + 4 and l.Z > -GarageBuilder.D / 2 - 14 and l.Z < GarageBuilder.D / 2 + 2
end

---------------------------------------------------------------- API
local H = {}
local function changed(plr, what)
	for _, w in ipairs(what) do
		if w == "items" then renderItems(plr)
		elseif w == "engine" then renderEngine(plr)
		elseif w == "moped" then renderMoped(plr)
		elseif w == "boxes" then renderBoxes(plr) end
	end
	pushState(plr)
end
function H.state(plr) pushState(plr); return true end
function H.pickup(plr, p, id)
	local it = p.items[id]
	if not it then return false, "Delen finns inte" end
	if not inGarage(plr) then return false, "Gå in i ditt garage" end
	local ok, e = Profile.moveItem(p, id, "hand")
	if not ok then return ok, e end
	changed(plr, { "items", "boxes" })
	return true
end
function H.place(plr, p, loc)
	local id = Profile.inHand(p)
	if not id then return false, "Du bär ingenting" end
	if not inGarage(plr) then return false, "Gå in i ditt garage" end
	local ok, e = Profile.moveItem(p, id, loc)
	if not ok then return ok, e end
	changed(plr, { "items" })
	return true
end
function H.moveTo(plr, p, id, loc)
	-- move a free part straight to a place (used from the work modes and the tray menu)
	if not inGarage(plr) then return false, "Gå in i ditt garage" end
	if loc ~= "hylla" and loc ~= "bank" and loc ~= "golv" and loc ~= "lack" and loc ~= "port" then return false, "Kan inte lägga delen där" end
	local ok, e = Profile.moveItem(p, id, loc)
	if not ok then return ok, e end
	changed(plr, { "items", "boxes" })
	return true
end
function H.mountEngine(plr, p, target, sock, id)
	if not inGarage(plr) then return false, "Gå in i ditt garage" end
	if riding[plr] and target ~= "stand" then return false, "Mopeden är ute" end
	local ok, e = Profile.mountEngine(p, target, sock, id)
	if not ok then return ok, e end
	if target == "stand" and EngineDef.complete(p.stand) then p.stats.built = p.stats.built + 1 end
	changed(plr, { target == "stand" and "engine" or "moped", "items", "boxes" })
	return true
end
function H.unmountEngine(plr, p, target, sock)
	if not inGarage(plr) then return false, "Gå in i ditt garage" end
	if riding[plr] and target ~= "stand" then return false, "Mopeden är ute" end
	local ok, e, extra = Profile.unmountEngine(p, target, sock)
	if not ok then return ok, e end
	changed(plr, { target == "stand" and "engine" or "moped", "items" })
	return true, e, extra
end
function H.mountChassis(plr, p, slot, id)
	if not inGarage(plr) or riding[plr] then return false, "Mopeden måste stå på lyften" end
	local ok, e = Profile.mountChassis(p, slot, id, now())
	if not ok then return ok, e end
	changed(plr, { "moped", "items", "boxes" })
	return true
end
function H.unmountChassis(plr, p, slot)
	if not inGarage(plr) or riding[plr] then return false, "Mopeden måste stå på lyften" end
	local ok, e, extra = Profile.unmountChassis(p, slot)
	if not ok then return ok, e end
	changed(plr, { "moped", "items", "engine" })
	return true, e, extra
end
function H.engineToMoped(plr, p)
	if not inGarage(plr) or riding[plr] then return false, "Mopeden måste stå på lyften" end
	local ok, e = Profile.engineToMoped(p)
	if not ok then return ok, e end
	changed(plr, { "moped", "engine" })
	return true
end
function H.engineToStand(plr, p)
	if not inGarage(plr) or riding[plr] then return false, "Mopeden måste stå på lyften" end
	local ok, e = Profile.engineToStand(p)
	if not ok then return ok, e end
	changed(plr, { "moped", "engine" })
	return true
end
function H.order(plr, p, cart)
	local ok, o = Profile.order(p, cart, now(), function(sku) return stock[sku] or 0 end)
	if not ok then return ok, o end
	for _, l in ipairs(o.lines) do stock[l.sku] = math.max(0, (stock[l.sku] or 0) - l.qty) end
	changed(plr, {})
	return true, { id = o.id, ready = o.ready }
end
function H.openBox(plr, p, oid)
	local plot = plotOf[plr]
	local box = plot and plot.dyn:FindFirstChild("Paket") and plot.dyn.Paket:FindFirstChild("Paket_" .. tostring(oid))
	if not box or not near(plr, box:GetPivot().Position, 12) then return false, "Gå fram till paketet" end
	local ok, e = Profile.openBox(p, tonumber(oid))
	if not ok then return ok, e end
	changed(plr, { "boxes" })
	return true
end
function H.sell(plr, p, id)
	local ok, v = Profile.sellItem(p, id)
	if not ok then return ok, v end
	changed(plr, { "items", "boxes" })
	return true, v
end
function H.buyMoped(plr, p, model)
	local ok, e = Profile.buyMoped(p, model)
	if not ok then return ok, e end
	changed(plr, {})
	return true, e
end
function H.sellMoped(plr, p, idx)
	if riding[plr] then return false, "Kör hem först" end
	local ok, v = Profile.sellMoped(p, tonumber(idx))
	if not ok then return ok, v end
	changed(plr, { "moped" })
	return true, v
end
function H.selectMoped(plr, p, idx)
	if riding[plr] then return false, "Kör hem först" end
	local ok, e = Profile.selectMoped(p, tonumber(idx))
	if not ok then return ok, e end
	changed(plr, { "moped" })
	return true
end
function H.setJet(plr, p, jet)
	local ok, e = Profile.setJet(p, jet)
	if not ok then return ok, e end
	changed(plr, {})
	return true
end
function H.portStart(plr, p)
	if not near(plr, plotOf[plr].origin * GarageBuilder.PORT.Position, 12) then return false, "Gå fram till portningsbänken" end
	local ok, e = Profile.portStart(p, now())
	if not ok then return ok, e end
	local tool = Profile.bestTool(p, "slip")
	return true, { item = e, steady = tool.stats.steady, speed = tool.stats.speed }
end
function H.portDone(plr, p, state)
	local ok, r = Profile.portDone(p, state, now())
	if not ok then return ok, r end
	changed(plr, { "items" })
	return true, r
end
function H.workCancel(plr, p)
	Profile.workCancel(p)
	return true
end
function H.paintStart(plr, p)
	if not near(plr, plotOf[plr].origin * GarageBuilder.BOOTH.Position, 14) then return false, "Gå in i lackboxen" end
	local ok, e = Profile.paintStart(p, now())
	if not ok then return ok, e end
	local tool = Profile.bestTool(p, "spruta")
	return true, { item = e, even = tool.stats.even }
end
function H.paintDone(plr, p, color, finish, gloss, state, decal)
	local ok, r = Profile.paintDone(p, color, finish, gloss, state, now(), decal)
	if not ok then return ok, r end
	changed(plr, { "items" })
	return true, r
end
function H.saveDesign(plr, p, name)
	local ok, e = Profile.saveDesign(p, name)
	if not ok then return ok, e end
	changed(plr, {})
	return true
end
function H.applyDesign(plr, p, idx)
	if riding[plr] then return false, "Kör hem först" end
	local ok, e = Profile.applyDesign(p, tonumber(idx), now())
	if not ok then return ok, e end
	changed(plr, { "moped" })
	return true, e
end
function H.ride(plr, p)
	if riding[plr] then return false, "Du kör redan" end
	local probs = Profile.mopedProblems(p)
	if #probs > 0 then return false, "Mopeden saknar: " .. table.concat(probs, ", ") end
	if not inGarage(plr) then return false, "Gå in i ditt garage" end
	if Profile.inHand(p) then
		Profile.moveItem(p, Profile.inHand(p), Profile.freeStorage(p))
		renderItems(plr)
	end
	local plot = plotOf[plr]
	clear(plot.dyn, "Moped")
	local model = Models.moped(plot.dyn, p.mopeds[p.cur], p.items, plot.origin * GarageBuilder.EXIT * CF(0, 0.15, 0))
	model:SetAttribute("OwnerId", plr.UserId)
	model:SetAttribute("Plot", plot.i)
	if not startRide(plr, model) then goHome(plr); return false, "Kunde inte sätta dig på mopeden" end
	pushState(plr)
	return true
end
function H.mount(plr, p)
	local r = riding[plr]
	if not r or not r.moped then return false, "Mopeden står i garaget" end
	if not near(plr, r.moped.PrimaryPart.Position, 10) then return false, "Gå fram till mopeden" end
	local model = r.moped
	clear(model.PrimaryPart, "Prompt_mount")
	weldMoped(model)
	local root = model.PrimaryPart
	if root:CanSetNetworkOwnership() then root:SetNetworkOwner(plr) end
	model:SetAttribute("Riding", true)
	seatPlayer(plr, model)
	return true
end
function H.home(plr, p)
	goHome(plr)
	pushState(plr)
	return true
end
function H.acceptJob(plr, p, key)
	local ok, j = Profile.acceptJob(p, key)
	if not ok then return ok, j end
	changed(plr, { "engine" })
	return true, j
end
function H.cancelJob(plr, p, id)
	local ok, e = Profile.cancelJob(p, tonumber(id))
	if not ok then return ok, e end
	changed(plr, { "engine", "items" })
	return true
end
function H.completeJob(plr, p, id)
	id = tonumber(id)
	local job
	for _, j in ipairs(p.jobs) do if j.id == id then job = j end end
	if not job then return false, "Inget sådant uppdrag" end
	if job.type == "leverans" then
		local pl = Map.PLACES[job.dest]
		if not near(plr, V3(pl.x, charPos(plr) and charPos(plr).Y or 0, pl.z), Map.DELIVER_RADIUS + 6) then return false, "Kör till " .. pl.n end
	end
	local ok, pay = Profile.completeJob(p, id)
	if not ok then return ok, pay end
	notify(plr, "Uppdraget klart: +" .. pay .. " kr", "money")
	changed(plr, { "engine", "items" })
	return true, pay
end

Api.OnServerInvoke = function(plr, action, ...)
	local p = profiles[plr]
	if not p then return false, "Profilen laddas" end
	local f = H[action]
	if type(action) ~= "string" or not f then return false, "Okänd åtgärd" end
	local res = table.pack(pcall(f, plr, p, ...))
	if not res[1] then
		warn("Api " .. action .. " failed: " .. tostring(res[2]))
		return false, "Något gick fel"
	end
	return res[2], res[3], res[4]
end

-- prompts that the server handles itself
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(pp, plr)
	local action = pp:GetAttribute("Action")
	local p = profiles[plr]
	if not p then return end
	if action == "openBox" then
		local plot = plotOf[plr]
		if plot and pp:GetAttribute("Plot") == plot.i then
			local ok, e = H.openBox(plr, p, pp:GetAttribute("Order"))
			if not ok then notify(plr, e, "error") end
		else
			notify(plr, "Det är inte ditt paket", "error")
		end
	elseif action == "ride" then
		local plot = plotOf[plr]
		if plot and pp:GetAttribute("Plot") == plot.i then
			local ok, e = H.ride(plr, p)
			if not ok then notify(plr, e, "error") end
		end
	elseif action == "mount" then
		local model = pp.Parent and pp.Parent.Parent
		if model and model:GetAttribute("OwnerId") == plr.UserId then
			local ok, e = H.mount(plr, p)
			if not ok then notify(plr, e, "error") end
		end
	end
end)

-- ride reports from the client: overheating wears the engine
RideEv.OnServerEvent:Connect(function(plr, kind, value)
	local p = profiles[plr]
	if not p or not riding[plr] then return end
	if kind == "overheat" then
		local before = 0
		local m = p.mopeds[p.cur]
		local k = m and m.engine and p.items[m.engine.kolv]
		if k then before = k.wear or 0 end
		Profile.addWear(p, math.min(0.05, (tonumber(value) or 0) * 0.02))
		if k and before < 1 and (k.wear or 0) >= 1 then
			notify(plr, "Kolvskär! Motorn skar. Byt kolv och kolvringar.", "error")
		end
		pushState(plr)
	end
end)

-- distance pay measured on the server (moped movement while seated)
task.spawn(function()
	while true do
		task.wait(1)
		for plr, r in pairs(riding) do
			local root = r.moped and r.moped.PrimaryPart
			local p = profiles[plr]
			if root and p and r.moped:GetAttribute("Riding") then
				local pos = root.Position
				local d = (pos - r.last).Magnitude
				r.last = pos
				if d < 60 then
					local pay = Profile.addDistance(p, d * Config.STUD)
					if pay > 0 then pushState(plr) end
				end
			elseif root then
				r.last = root.Position
			end
		end
	end
end)

-- deliveries
task.spawn(function()
	while true do
		task.wait(1)
		for plr, p in pairs(profiles) do
			local arrived = Profile.tick(p, now())
			if #arrived > 0 then
				renderBoxes(plr)
				notify(plr, "Paketet har kommit! Det står vid garageporten.", "box")
				pushState(plr)
			end
		end
	end
end)

---------------------------------------------------------------- join and leave
local function save(plr)
	local p = profiles[plr]
	if not (p and store and saving[plr]) then return end
	local data = Profile.save(p)
	local ok, err = pcall(function() store:SetAsync("p_" .. plr.UserId, data) end)
	if not ok then warn("Kunde inte spara " .. plr.Name .. ": " .. tostring(err)) end
end
local function load(plr)
	if not store then return Profile.new(), false end
	local data, ok, err
	for _ = 1, 3 do
		ok, err = pcall(function() data = store:GetAsync("p_" .. plr.UserId) end)
		if ok then break end
		task.wait(1)
	end
	if not ok then
		warn("Kunde inte ladda " .. plr.Name .. ": " .. tostring(err))
		return Profile.new(), false
	end
	return (Profile.load(data)), true
end
local function claimPlot(plr)
	for _, plot in ipairs(plots) do
		if not plot.owner then
			plot.owner = plr
			plot.folder:SetAttribute("OwnerId", plr.UserId)
			plot.refs.nameLabel.Text = string.upper(plr.DisplayName) .. "S GARAGE"
			return plot
		end
	end
end
local function onCharacter(plr, char)
	local plot = plotOf[plr]
	if not plot then return end
	task.defer(function()
		if char.Parent then char:PivotTo(plot.origin * GarageBuilder.SPAWN) end
	end)
	if riding[plr] and riding[plr].moped then riding[plr].moped:Destroy() end
	riding[plr] = nil
	renderMoped(plr, true)
	renderItems(plr)
end
local function onJoin(plr)
	local plot = claimPlot(plr)
	if not plot then
		plr:Kick("Alla garage är upptagna. Försök igen om en stund.")
		return
	end
	plotOf[plr] = plot
	local p, okSave = load(plr)
	saving[plr] = okSave
	if not plr.Parent then plot.owner = nil; return end
	profiles[plr] = p
	plr:SetAttribute("Plot", plot.i)
	renderAll(plr)
	plr.CharacterAdded:Connect(function(char) onCharacter(plr, char) end)
	if plr.Character then onCharacter(plr, plr.Character) end
	pushState(plr)
	if not okSave then
		notify(plr, store and "Sparning fungerar inte just nu. Dina framsteg sparas inte." or "Sparning är avstängd (slå på API-åtkomst i Studio).", "error")
	end
end
local function onLeave(plr)
	save(plr)
	local plot = plotOf[plr]
	if riding[plr] and riding[plr].moped then riding[plr].moped:Destroy() end
	riding[plr] = nil
	if plot then
		plot.dyn:ClearAllChildren()
		plot.owner = nil
		plot.folder:SetAttribute("OwnerId", 0)
		plot.refs.nameLabel.Text = "LEDIGT GARAGE"
	end
	profiles[plr] = nil
	plotOf[plr] = nil
	saving[plr] = nil
end
Players.PlayerAdded:Connect(onJoin)
Players.PlayerRemoving:Connect(onLeave)
for _, plr in ipairs(Players:GetPlayers()) do task.spawn(onJoin, plr) end
task.spawn(function()
	while true do
		task.wait(60)
		for plr in pairs(profiles) do save(plr) end
	end
end)
game:BindToClose(function()
	for plr in pairs(profiles) do save(plr) end
end)

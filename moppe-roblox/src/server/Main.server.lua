-- Server: profiles (DataStore), API for the client, spawning the moped, distance measured by the server.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Economy = require(Shared.Economy)
local Builder = require(Shared.Builder)

local remotes = Instance.new("Folder"); remotes.Name = "Remotes"; remotes.Parent = RS
local Api = Instance.new("RemoteFunction"); Api.Name = "Api"; Api.Parent = remotes
local StateEv = Instance.new("RemoteEvent"); StateEv.Name = "State"; StateEv.Parent = remotes
local Report = Instance.new("RemoteEvent"); Report.Name = "Report"; Report.Parent = remotes

local store
do
	local ok, err = pcall(function() store = DataStoreService:GetDataStore("MoppeGarage_v1") end)
	if not ok then warn("DataStore är inte tillgänglig, inget sparas: " .. tostring(err)); store = nil end
end

local profiles, sessions = {}, {}
local function now() return os.time() end
local function push(plr, msg)
	local p = profiles[plr]
	if p then StateEv:FireClient(plr, Economy.public(p), msg, sessions[plr] and sessions[plr].saveOk) end
end

local function load(plr)
	local raw, ok, err = nil, false, nil
	if store then
		for attempt = 1, 3 do
			ok, err = pcall(function() raw = store:GetAsync("p_" .. plr.UserId) end)
			if ok then break end
			task.wait(attempt)
		end
	end
	profiles[plr] = Economy.load(raw)
	sessions[plr] = { saveOk = store ~= nil and ok, last = nil, seated = false, moped = nil, engineOn = false, distLog = {} }
	if store and not ok then warn("Kunde inte läsa sparningen för " .. plr.Name .. ": " .. tostring(err) .. ". Sparar inte den här sessionen så att inget skrivs över.") end
end
local function save(plr)
	local p, s = profiles[plr], sessions[plr]
	if not (p and s and store and s.saveOk) then return false end
	local data = Economy.public(p)
	local ok, err = pcall(function() store:SetAsync("p_" .. plr.UserId, data) end)
	if not ok then warn("Kunde inte spara " .. plr.Name .. ": " .. tostring(err)) end
	return ok
end

local function look(p, id)
	local c = p.cfgs[id]
	return { col = Color3.fromHex(c.col), seat = Color3.fromHex(c.seat), num = c.num, fin = c.fin, rim = Builder.C.alu }
end

-- spawn (or replace) the player's moped and put the character in the seat
local function spawnMoped(plr, atCf)
	local p, s = profiles[plr], sessions[plr]
	local id = p.cur
	if not p.own[id] then return false, "Du äger inte mopeden" end
	if s.moped then s.moped:Destroy(); s.moped = nil end
	local mop = Config.BY_ID[id]
	local model = Builder.moped(mop, Economy.ecfg(p, id), look(p, id))
	model.Name = "Moped_" .. plr.Name
	local spot = workspace:FindFirstChild("MoppeWorld") and workspace.MoppeWorld:FindFirstChild("Garage") and workspace.MoppeWorld.Garage:FindFirstChild("MopedSpot")
	local cf = atCf or (spot and (spot.CFrame * CFrame.new(0, 0.3, 0)) or CFrame.new(0, 3, 0))
	model:PivotTo(cf)
	-- constraints the client drives (the client owns the physics of its moped)
	local root = model.PrimaryPart
	local att = Instance.new("Attachment"); att.Name = "Drive"; att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Drive"; lv.Attachment0 = att; lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.new(1, 0, 0); lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World; lv.MaxForce = 0; lv.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Name = "Tilt"; ao.Mode = Enum.OrientationAlignmentMode.OneAttachment; ao.Attachment0 = att
	ao.Responsiveness = 40; ao.MaxTorque = 0; ao.RigidityEnabled = false; ao.CFrame = cf.Rotation; ao.Parent = root
	local owner = Instance.new("ObjectValue"); owner.Name = "Owner"; owner.Value = plr; owner.Parent = model
	local mid = Instance.new("StringValue"); mid.Name = "MopedId"; mid.Value = id; mid.Parent = model
	model.Parent = workspace
	for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then pcall(function() d:SetNetworkOwner(plr) end) end end
	s.moped, s.last = model, nil
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if hum then model.Seat:Sit(hum) end
	return true
end

-- API from the client. All changes are validated here; the client only displays.
local handlers = {}
handlers.state = function(plr) return true end
handlers.select = function(plr, id)
	local p = profiles[plr]
	if not Config.BY_ID[id] then return false, "Okänd moped" end
	p.cur = id
	return true
end
handlers.spawn = function(plr) return spawnMoped(plr) end
handlers.buy = function(plr, sku, qty, installNow)
	local p = profiles[plr]
	local ok, err, _, inst = Economy.buy(p, sku, qty, installNow and p.cur or nil, now())
	if ok and inst then local s = sessions[plr]; if s.moped then spawnMoped(plr, s.moped:GetPivot()) end end
	return ok, err or (inst and "Köpt och monterat" or "Köpt, ligger i förrådet")
end
handlers.install = function(plr, u)
	local p = profiles[plr]
	local ok, err = Economy.install(p, u, p.cur)
	if ok then local s = sessions[plr]; if s.moped then spawnMoped(plr, s.moped:GetPivot()) end end
	return ok, err
end
handlers.uninstall = function(plr, slot)
	local p = profiles[plr]
	local ok, err = Economy.uninstall(p, p.cur, slot)
	if ok then local s = sessions[plr]; if s.moped then spawnMoped(plr, s.moped:GetPivot()) end end
	return ok, err
end
handlers.sell = function(plr, u) return Economy.sell(profiles[plr], u, now()) end
handlers.tune = function(plr, key, value)
	local p = profiles[plr]
	local ok, err = Economy.tune(p, p.cur, key, value)
	if ok and (key == "col" or key == "seat" or key == "fin" or key == "num") then local s = sessions[plr]; if s.moped then spawnMoped(plr, s.moped:GetPivot()) end end
	return ok, err
end
handlers.repair = function(plr, emergency) local p = profiles[plr]; return Economy.repair(p, p.cur, emergency == true, now()) end
handlers.buyMoped = function(plr, id) return Economy.buyMoped(profiles[plr], id, now()) end
handlers.sellMoped = function(plr, id)
	local p, s = profiles[plr], sessions[plr]
	if s.moped and s.moped.MopedId.Value == id then s.moped:Destroy(); s.moped = nil end
	return Economy.sellMoped(p, id, now())
end
handlers.save = function(plr) return save(plr), "Sparat" end

Api.OnServerInvoke = function(plr, action, ...)
	local p = profiles[plr]
	if not p then return false, "Profilen laddas fortfarande" end
	local h = handlers[action]
	if type(action) ~= "string" or not h then return false, "Okänt anrop" end
	local ok, res, msg = pcall(h, plr, ...)
	if not ok then warn("Fel i " .. action .. ": " .. tostring(res)); return false, "Serverfel" end
	push(plr, msg or res)
	return res, msg
end

-- reports from the client: engine on/off, damage, crash, wheelie. Checked against what the server saw.
Report.OnServerEvent:Connect(function(plr, kind, a, b, c, d)
	local p, s = profiles[plr], sessions[plr]
	if not p then return end
	if kind == "engine" then s.engineOn = a == true
	elseif kind == "dmg" then if type(a) == "number" then p.dmg[p.cur] = math.clamp(a, 0, 1) end
	elseif kind == "dirty" then Economy.dirty(p)
	elseif kind == "crash" then Economy.crash(p, tostring(a):sub(1, 60), now()); push(plr)
	elseif kind == "wheelie" then
		-- distance the server itself saw during the wheelie (a = time in s)
		local seen, t0 = 0, os.clock() - (tonumber(a) or 0)
		for _, e in ipairs(s.distLog) do if e[1] >= t0 then seen = seen + e[2] end end
		local r, why = Economy.wheelie(p, a, b, c, d, now(), seen)
		push(plr, r > 0 and ("Stegring: +" .. r .. " kr") or why)
	end
end)

-- the server measures the distance from the moped's position (max Config.ECON.maxSpeed m/s, only while seated with the engine running)
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc = acc + dt
	if acc < 0.5 then return end
	local step = acc
	acc = 0
	for plr, s in pairs(sessions) do
		local p = profiles[plr]
		local m = s.moped
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		local seated = m and m.Parent and hum and hum.SeatPart == m:FindFirstChild("Seat")
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
		else
			s.last = nil
		end
		while #s.distLog > 0 and os.clock() - s.distLog[1][1] > 130 do table.remove(s.distLog, 1) end
	end
end)

local function onAdded(plr)
	if profiles[plr] then return end
	load(plr)
	plr.CharacterAdded:Connect(function() task.wait(1); push(plr) end)
	push(plr, store and (sessions[plr].saveOk and "Välkommen tillbaka" or "Sparningen kunde inte läsas, inget sparas den här gången") or "Sparning är avstängd (DataStore saknas i Studio)")
end
Players.PlayerAdded:Connect(onAdded)
for _, plr in ipairs(Players:GetPlayers()) do task.spawn(onAdded, plr) end -- players who joined before the script started
Players.PlayerRemoving:Connect(function(plr)
	save(plr)
	local s = sessions[plr]
	if s and s.moped then s.moped:Destroy() end
	profiles[plr], sessions[plr] = nil, nil
end)
game:BindToClose(function() for plr in pairs(profiles) do save(plr) end end)
task.spawn(function() while true do task.wait(60); for plr in pairs(profiles) do save(plr) end end end)

-- Building by hand: the engine on the stand ("engine") and the moped on the lift ("work").
-- Drag a part from the tray onto the engine/moped. Where it belongs shows up green (fits now) or red (with what
-- has to go on first). Let go on the marker and the part slides into place while a hand tightens it.
-- Right-click a mounted part to take it off; left-click it for Demontera / Lackera / Byt ut / Inspektera.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = RS:WaitForChild("Shared")
local Parts = require(Shared.Parts)
local EngineDef = require(Shared.EngineDef)
local MopedDef = require(Shared.MopedDef)
local Models = require(Shared.Models)
local Profile = require(Shared.Profile)
local GarageBuilder = require(Shared.GarageBuilder)
local plr = Players.LocalPlayer
local S = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UIKit"))

local gui = UI.screen("Montering", 10, plr)
gui.Enabled = false

local A = { mode = nil, cat = "Alla", yaw = 0, pitch = 0.32, dist = 7, focus = Vector3.new(), filterKind = nil }

---------------------------------------------------------------- what we are working on
local function engineMap()
	local p = S.profile
	if A.mode == "engine" then return p.stand, "stand" end
	local m = S.moped()
	return m and m.engine, "moped"
end
local function mopedCtx()
	local m = S.moped()
	return { cf = S.origin() * GarageBuilder.LIFT, def = MopedDef.MODELS[m.model] }
end
local function engineCF()
	if A.mode == "engine" then return S.origin() * GarageBuilder.STAND end
	return Models.engineCF(mopedCtx())
end
-- where a part kind goes: returns { kind = "engine"|"chassis", id = socket/slot, name }
local function placeFor(sku)
	local part = Parts.get(sku)
	if not part then return nil end
	local sock = EngineDef.socketForKind(part.kind)
	if sock then
		local map = engineMap()
		if not map then return nil end
		return { kind = "engine", id = sock, name = EngineDef.BY_ID[sock].name }
	end
	if A.mode ~= "work" then return nil end
	local m = S.moped()
	if part.kind == "kapa" then
		if part.stats.fits ~= m.model then return nil end
		return { kind = "chassis", id = "pan:" .. part.stats.panel, name = MopedDef.MODELS[m.model].panelById[part.stats.panel].n }
	end
	for _, s in ipairs(MopedDef.SLOTS) do
		if s.kind == part.kind then return { kind = "chassis", id = s.id, name = s.n } end
	end
end
local function canMount(place, sku)
	local p = S.profile
	if place.kind == "engine" then
		local map = engineMap()
		return EngineDef.canMount(map, place.id, sku, p.items)
	end
	return MopedDef.canMount(S.moped(), place.id, sku)
end
-- parts that are free to use: shelf, bench, floor, in hand, opened boxes
local function freeItems()
	local p = S.profile
	local r = {}
	for id, it in pairs(p.items) do
		if Profile.isFree(p, it) and placeFor(it.sku) then
			local part = Parts.get(it.sku)
			if A.cat == "Alla" or Parts.KINDS[part.kind].grp == A.cat then
				if not A.filterKind or A.filterKind == part.kind then r[#r + 1] = id end
			end
		end
	end
	table.sort(r, function(a, b)
		local pa, pb = Parts.get(p.items[a].sku), Parts.get(p.items[b].sku)
		if pa.kind ~= pb.kind then
			local oa, ob = EngineDef.ORDER[EngineDef.socketForKind(pa.kind) or ""] or 99, EngineDef.ORDER[EngineDef.socketForKind(pb.kind) or ""] or 99
			if oa ~= ob then return oa < ob end
			return pa.kind < pb.kind
		end
		return a < b
	end)
	return r
end

---------------------------------------------------------------- camera
local function updateCam()
	local cf = CFrame.new(A.focus) * CFrame.Angles(0, A.yaw, 0) * CFrame.Angles(-A.pitch, 0, 0) * CFrame.new(0, 0, A.dist)
	S.camTo(cf, 50)
end

---------------------------------------------------------------- UI layout
local top = UI.panel(gui, UDim2.fromOffset(420, 36), UDim2.new(0.5, 0, 0, 8), { anchor = Vector2.new(0.5, 0), name = "Info", transp = 0.15 })
local topText = UI.text(top, "", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0), { ts = 15, xa = Enum.TextXAlignment.Center, font = UI.BOLD, name = "Infotext" })

local tray = UI.panel(gui, UDim2.fromOffset(400, 470), UDim2.fromOffset(12, 58), { name = "Delar" })
local trayTitle = UI.text(tray, "Motorbygge", UDim2.new(1, -20, 0, 36), UDim2.fromOffset(14, 4), { font = UI.BOLD, ts = 18, name = "Titel" })
local cats = UI.new("Frame", { Size = UDim2.fromOffset(118, 410), Position = UDim2.fromOffset(8, 46), BackgroundTransparency = 1, Name = "Kategorier" }, tray)
UI.list(cats, 4)
local grid = UI.scroll(tray, UDim2.fromOffset(262, 410), UDim2.fromOffset(132, 46), { name = "Lista" })
UI.grid(grid, UDim2.fromOffset(124, 126), UDim2.fromOffset(6, 6))

local checklist = UI.panel(gui, UDim2.fromOffset(240, 470), UDim2.new(1, -12, 0, 58), { anchor = Vector2.new(1, 0), name = "Checklista" })
local checkTitle = UI.text(checklist, "Monteringsordning", UDim2.new(1, -20, 0, 32), UDim2.fromOffset(12, 4), { font = UI.BOLD, ts = 16 })
local checkList = UI.scroll(checklist, UDim2.new(1, -16, 1, -44), UDim2.fromOffset(8, 40), { name = "Rader" })
UI.list(checkList, 3)

local bottom = UI.new("Frame", { Size = UDim2.fromOffset(820, 44), Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Name = "Knappar" }, gui)
UI.list(bottom, 8, true, Enum.HorizontalAlignment.Center)
local hint = UI.text(gui, "Snurra 360°: dra på tom yta (eller pilarna)   ·   Zoom: rullhjul   ·   Ta bort: högerklicka på en del", UDim2.fromOffset(600, 20), UDim2.new(0.5, 0, 1, -84), { anchor = Vector2.new(0.5, 0), ts = 13, color = UI.C.dim, xa = Enum.TextXAlignment.Center })

local menu -- context menu
local function closeMenu() if menu then menu:Destroy(); menu = nil end end

---------------------------------------------------------------- markers, ghost and the hand
local fx = Instance.new("Folder")
fx.Name = "MonteringLokal"
local function tint(model, color, transp)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Color = color
			d.Material = Enum.Material.SmoothPlastic
			d.Transparency = math.max(d.Transparency, transp)
			d.CanQuery = false
			d.CastShadow = false
		end
	end
end
local function buildAt(sku, item, place)
	local model = Instance.new("Model")
	model.Name = "Markering"
	if place.kind == "engine" then Models.buildInto(model, sku, item, engineCF())
	else Models.buildInto(model, sku, item, nil, mopedCtx()) end
	return model
end
-- a hand with a wrench tightening at a point, then disappears
local function handAnim(pos, unscrew)
	local cam = workspace.CurrentCamera
	local toCam = (cam.CFrame.Position - pos).Unit
	local start = CFrame.lookAt(pos + toCam * 2.2 + Vector3.new(0, 0.6, 0), pos)
	local hand = Models.hand(fx, start * CFrame.Angles(math.rad(-20), 0, 0), true)
	local wrench = Models.tool(hand, "nyckel", start * CFrame.new(0, 0.05, -0.55), false)
	for _, p in ipairs(wrench.parts) do
		local w = Instance.new("WeldConstraint")
		w.Part0 = hand.PrimaryPart
		w.Part1 = p
		w.Parent = p
		p.Anchored = false
	end
	local main = hand.PrimaryPart
	for _, d in ipairs(hand:GetDescendants()) do
		if d:IsA("BasePart") and d ~= main then
			if not d:FindFirstChildOfClass("WeldConstraint") then
				local w = Instance.new("WeldConstraint")
				w.Part0 = main
				w.Part1 = d
				w.Parent = d
			end
			d.Anchored = false
		end
	end
	task.spawn(function()
		local near = CFrame.lookAt(pos + toCam * 0.9 + Vector3.new(0, 0.25, 0), pos)
		local tw = TweenService:Create(main, TweenInfo.new(0.25), { CFrame = near })
		tw:Play()
		tw.Completed:Wait()
		for i = 1, 4 do
			local a = (unscrew and -1 or 1) * math.rad(55)
			local t1 = TweenService:Create(main, TweenInfo.new(0.14), { CFrame = near * CFrame.Angles(0, 0, a) })
			t1:Play(); t1.Completed:Wait()
			local t2 = TweenService:Create(main, TweenInfo.new(0.1), { CFrame = near })
			t2:Play(); t2.Completed:Wait()
		end
		local t3 = TweenService:Create(main, TweenInfo.new(0.2), { CFrame = start })
		t3:Play(); t3.Completed:Wait()
		hand:Destroy()
	end)
end

local drag -- { id, sku, place, ok, why, marker, ghost, snapped }
local function endDrag()
	if drag then
		if drag.marker then drag.marker:Destroy() end
		if drag.ghost then drag.ghost:Destroy() end
	end
	drag = nil
end
local function startDrag(id)
	if drag or not A.mode then return end
	local it = S.item(id)
	if not it then return end
	local place = placeFor(it.sku)
	if not place then S.toast(Parts.get(it.sku).name .. " sitter inte här", "error"); return end
	local ok, why = canMount(place, it.sku)
	local marker = buildAt(it.sku, it, place)
	tint(marker, ok and Color3.fromRGB(70, 220, 110) or Color3.fromRGB(230, 70, 60), 0.5)
	marker.Parent = fx
	local ghost = Models.item(it.sku, it)
	for _, d in ipairs(ghost:GetDescendants()) do if d:IsA("BasePart") then d.CanQuery = false end end
	ghost.Parent = fx
	drag = { id = id, sku = it.sku, place = place, ok = ok, why = why, marker = marker, ghost = ghost }
	topText.Text = ok and ("Dra " .. Parts.get(it.sku).name:lower() .. " till den gröna markeringen") or ("Går inte än: " .. tostring(why))
	top.BackgroundColor3 = ok and UI.C.panel or Color3.fromRGB(110, 30, 30)
end
local function dropDrag()
	local d = drag
	if not d then return end
	if not d.snapped then endDrag(); A.refresh(); return end
	if not d.ok then S.toast(d.why or "Går inte", "error"); endDrag(); A.refresh(); return end
	-- slide the ghost onto the marker, then mount on the server
	local cf = d.marker:GetBoundingBox()
	d.ghost:PivotTo(CFrame.new(cf.Position))
	local map, target = engineMap()
	local okA, err
	if d.place.kind == "engine" then okA, err = S.api("mountEngine", target, d.place.id, d.id)
	else okA, err = S.api("mountChassis", d.place.id, d.id) end
	if okA then
		handAnim(cf.Position, false)
		S.toast(Parts.get(d.sku).name .. " monterad", "ok")
	end
	endDrag()
	A.refresh()
end

---------------------------------------------------------------- mounted parts in 3D
local function mountedAt(inst)
	local plot = S.plot()
	if not plot or not inst then return nil end
	local x = inst
	while x and x ~= plot do
		if x:IsA("Model") then
			local sock = x:GetAttribute("Sock")
			local slot = x:GetAttribute("Slot")
			if A.mode == "engine" and sock and x.Parent and x.Parent.Name == "Motor" and x.Parent.Parent and x.Parent.Parent.Name == "Dynamic" then
				return { kind = "engine", id = sock, item = x:GetAttribute("Item"), model = x }
			end
			if A.mode == "work" and x:FindFirstAncestor("Moped") then
				if sock then return { kind = "engine", id = sock, item = x:GetAttribute("Item"), model = x } end
				if slot and slot ~= "motor" then return { kind = "chassis", id = slot, item = x:GetAttribute("Item"), model = x } end
			end
		end
		x = x.Parent
	end
end
local function unmount(mp)
	local map, target = engineMap()
	local ok, _, extra
	if mp.kind == "engine" then ok, _, extra = S.api("unmountEngine", target, mp.id)
	else ok, _, extra = S.api("unmountChassis", mp.id) end
	if ok then
		handAnim(mp.model:GetBoundingBox().Position, true)
		local more = (type(extra) == "table" and #extra > 0) and (" Även " .. table.concat(extra, ", ") .. " togs loss.") or ""
		S.toast("Demonterad – delen ligger på arbetsbänken." .. more, "ok")
	end
	return ok
end
local function inspect(id)
	local it = S.item(id)
	if not it then return end
	local part = Parts.get(it.sku)
	local lines = { part.name, part.brand .. " · " .. Parts.KINDS[part.kind].cat, part.desc }
	if it.wear and it.wear > 0 then lines[#lines + 1] = string.format("Slitage: %d %%", math.floor(it.wear * 100)) end
	if it.port then lines[#lines + 1] = "Portad: " .. it.port.label .. string.format(" (%d %%)", math.floor(it.port.q * 100)) end
	if it.paint then lines[#lines + 1] = "Lack: " .. (it.paint.f or "") .. string.format(", kvalitet %d %%", math.floor((it.paint.q or 1) * 100)) end
	if it.cust then lines[#lines + 1] = "Kundens del" end
	S.toast(table.concat(lines, "\n"), "info")
end
local function contextMenu(mp, x, y)
	closeMenu()
	menu = UI.panel(gui, UDim2.fromOffset(190, 10), UDim2.fromOffset(x + 8, y - 50), { name = "Meny", z = 20 })
	menu.AutomaticSize = Enum.AutomaticSize.Y
	UI.pad(menu, 6)
	UI.list(menu, 4)
	local it = S.item(mp.item)
	UI.text(menu, it and Parts.get(it.sku).name or "Del", UDim2.new(1, 0, 0, 24), nil, { font = UI.BOLD, ts = 14, z = 21, truncate = true })
	local function add(text, kind, f)
		UI.button(menu, text, UDim2.new(1, 0, 0, 32), nil, { kind = kind or "secondary", ts = 14, z = 21 }, function() closeMenu(); f() end)
	end
	add("Demontera", "secondary", function() unmount(mp) end)
	if mp.kind == "chassis" and mp.id:sub(1, 4) == "pan:" then
		add("Lackera", "secondary", function()
			local ok, id = S.api("unmountChassis", mp.id)
			if ok and id then
				if S.api("moveTo", id, "lack") then
					S.endMode()
					S.open:Fire("paint")
				end
			end
		end)
	end
	add("Byt ut", "secondary", function()
		local part = it and Parts.get(it.sku)
		if unmount(mp) and part then A.filterKind = part.kind; A.refresh() end
	end)
	add("Inspektera", "secondary", function() inspect(mp.item) end)
end

---------------------------------------------------------------- tray, checklist and buttons
local function card(id, order)
	local it = S.item(id)
	local part = Parts.get(it.sku)
	local c = UI.new("TextButton", { Size = UDim2.fromOffset(124, 126), BackgroundColor3 = UI.C.panel2, Text = "", AutoButtonColor = true, LayoutOrder = order, Name = "Del_" .. id }, grid)
	UI.corner(c, 8)
	local place = placeFor(it.sku)
	local ok = place and canMount(place, it.sku)
	UI.stroke(c, ok and UI.C.green or UI.C.line, ok and 2 or 1, ok and 0.2 or 0.5)
	local model = Models.item(it.sku, it)
	UI.viewport(c, model, UDim2.fromOffset(112, 74), UDim2.fromOffset(6, 6), { z = 1 })
	UI.text(c, part.name, UDim2.new(1, -10, 0, 30), UDim2.fromOffset(6, 82), { ts = 12, wrap = true, font = UI.BOLD, ya = Enum.TextYAlignment.Top })
	UI.text(c, part.brand .. (it.loc:sub(1, 4) == "box:" and " · i paket" or ""), UDim2.new(1, -10, 0, 14), UDim2.fromOffset(6, 108), { ts = 11, color = UI.C.dim })
	c.MouseButton1Down:Connect(function() startDrag(id) end)
	c.MouseButton2Click:Connect(function()
		closeMenu()
		local mpos = UIS:GetMouseLocation()
		menu = UI.panel(gui, UDim2.fromOffset(190, 10), UDim2.fromOffset(mpos.X + 8, mpos.Y - 60), { name = "Meny", z = 20 })
		menu.AutomaticSize = Enum.AutomaticSize.Y
		UI.pad(menu, 6)
		UI.list(menu, 4)
		UI.text(menu, part.name, UDim2.new(1, 0, 0, 24), nil, { font = UI.BOLD, ts = 14, z = 21 })
		UI.button(menu, "Lägg på hyllan", UDim2.new(1, 0, 0, 32), nil, { kind = "secondary", ts = 14, z = 21 }, function() closeMenu(); S.api("moveTo", id, "hylla") end)
		UI.button(menu, "Inspektera", UDim2.new(1, 0, 0, 32), nil, { kind = "secondary", ts = 14, z = 21 }, function() closeMenu(); inspect(id) end)
		if not it.cust then
			UI.button(menu, "Sälj (" .. UI.kr(math.floor(part.price * 0.5 * (1 - 0.6 * (it.wear or 0)))) .. ")", UDim2.new(1, 0, 0, 32), nil, { kind = "danger", ts = 14, z = 21 }, function() closeMenu(); S.api("sell", id) end)
		end
	end)
	return c
end

function A.refresh()
	if not A.mode or not S.profile then return end
	local p = S.profile
	-- categories
	UI.clear(cats)
	local catList = A.mode == "engine" and { "Alla", "Motorblock", "Transmission", "Insug", "Tändning" } or { "Alla", "Chassi", "Kåpor", "Motorblock", "Transmission", "Insug", "Tändning" }
	for i, c in ipairs(catList) do
		UI.button(cats, c == "Alla" and "Alla delar" or c, UDim2.new(1, 0, 0, 30), nil, { kind = (A.cat == c and not A.filterKind) and "primary" or "ghost", xa = Enum.TextXAlignment.Left, ts = 13, order = i, name = c }, function()
			A.cat = c
			A.filterKind = nil
			A.refresh()
		end)
	end
	if A.filterKind then
		UI.button(cats, "Visa alla", UDim2.new(1, 0, 0, 30), nil, { kind = "yellow", ts = 13, order = 99 }, function() A.filterKind = nil; A.refresh() end)
	end
	-- parts
	UI.clear(grid)
	local items = freeItems()
	for i, id in ipairs(items) do card(id, i) end
	if #items == 0 then
		local l = UI.text(grid, A.filterKind and ("Du har ingen ledig " .. Parts.kindName(A.filterKind):lower() .. ". Beställ en på datorn.") or "Inga lediga delar här. Beställ delar på datorn eller hämta dem ur paketen.", UDim2.fromOffset(250, 80), nil, { ts = 13, wrap = true, color = UI.C.dim })
		l.LayoutOrder = 1
	end
	-- checklist
	UI.clear(checkList)
	local order = 0
	local map = engineMap()
	if A.mode == "engine" then
		trayTitle.Text = "Motorbygge"
		checkTitle.Text = "Motorn  " .. (map and (29 - #EngineDef.missing(map)) or 0) .. "/29"
		local nextUp = {}
		for _, s in ipairs(EngineDef.nextUp(map or {})) do nextUp[s] = true end
		for _, grp in ipairs(EngineDef.GROUPS) do
			order = order + 1
			UI.text(checkList, grp, UDim2.new(1, 0, 0, 22), nil, { ts = 13, font = UI.BOLD, color = UI.C.accent2, order = order })
			for _, s in ipairs(EngineDef.SOCKETS) do
				if s.grp == grp then
					order = order + 1
					local row = UI.check(checkList, s.name, map and map[s.id] ~= nil, order, nextUp[s.id])
					local btn = UI.new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Name = "Klick" }, row)
					btn.Activated:Connect(function() A.filterKind = s.kind; A.refresh() end)
				end
			end
		end
		topText.Text = map and EngineDef.complete(map) and "Motorn är komplett! Sätt den i mopeden." or "Dra delarna till rätt plats!"
	else
		local m = S.moped()
		trayTitle.Text = "Mopedbygge"
		checkTitle.Text = MopedDef.MODELS[m.model].n
		for _, sid in ipairs(MopedDef.slotIds(m.model)) do
			order = order + 1
			local info = MopedDef.slotInfo(m.model, sid)
			local done = MopedDef.filled(m, sid)
			local label = info.n
			if sid == "motor" and m.engine and not EngineDef.complete(m.engine) then label = "Motor (ofullständig)" end
			local row = UI.check(checkList, label, done, order, false)
			local btn = UI.new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Name = "Klick" }, row)
			btn.Activated:Connect(function()
				if sid == "motor" then return end
				A.filterKind = info.kind
				A.cat = "Alla"
				A.refresh()
			end)
		end
		local probs = Profile.mopedProblems(p, m)
		topText.Text = #probs == 0 and "Mopeden är klar att köra!" or "Dra delarna till mopeden. Saknas: " .. #probs
	end
	top.BackgroundColor3 = UI.C.panel
	-- buttons
	UI.clear(bottom)
	local function btn(text, kind, f, order2) UI.button(bottom, text, UDim2.fromOffset(math.max(120, #text * 9 + 30), 40), nil, { kind = kind, order = order2, ts = 15 }, f) end
	local m = S.moped()
	if A.mode == "engine" then
		if map and EngineDef.complete(map) and m and not m.engine then btn("Sätt motorn i mopeden", "green", function() if S.api("engineToMoped") then S.toast("Motorn sitter i mopeden", "ok") end end, 1) end
		if m and m.engine and EngineDef.isEmpty(p.stand) then btn("Lyft ur motorn ur mopeden", "secondary", function() if S.api("engineToStand") then S.toast("Motorn står på stativet", "ok") end end, 2) end
		for _, j in ipairs(p.jobs) do
			if j.type == "reparation" or j.type == "bygg" then btn("Lämna motorn till kunden", "yellow", function() S.api("completeJob", j.id) end, 3) end
		end
	else
		if m.engine then
			btn(A.engineZoom and "Visa hela mopeden" or "Meka på motorn här", "secondary", function()
				A.engineZoom = not A.engineZoom
				if A.engineZoom then
					A.focus = (engineCF() * CFrame.new(0, 0.2, 0.2)).Position
					A.dist = 5
					A.cat = "Motorblock"
				else
					A.focus = (S.origin() * GarageBuilder.LIFT * CFrame.new(0, 2.2, 0)).Position
					A.dist = 11
					A.cat = "Alla"
				end
				updateCam()
				A.refresh()
			end, 0)
			btn("Lyft ur motorn", "secondary", function() if S.api("engineToStand") then S.toast("Motorn står på motorstativet", "ok") end end, 1)
		elseif EngineDef.complete(p.stand) then btn("Montera motorn från stativet", "green", function() S.api("engineToMoped") end, 1) end
		if #Profile.mopedProblems(p, m) == 0 then btn("Kör ut", "green", function() S.endMode(); S.open:Fire("ride") end, 2) end
	end
	btn("Klar", "primary", function() S.endMode() end, 10)
end

---------------------------------------------------------------- open / close
local function open(mode)
	if not S.profile then return end
	if mode == "work" and not S.moped() then return end
	if not S.setMode(mode) then return end
	A.mode = mode
	A.cat = "Alla"
	A.filterKind = nil
	A.engineZoom = false
	fx.Parent = workspace
	if mode == "engine" then
		A.focus = (S.origin() * GarageBuilder.STAND * CFrame.new(0, 0.1, 0.5)).Position
		A.dist, A.yaw, A.pitch = 6.5, math.rad(200), 0.35
	else
		A.focus = (S.origin() * GarageBuilder.LIFT * CFrame.new(0, 2.2, 0)).Position
		A.dist, A.yaw, A.pitch = 11, math.rad(240), 0.3
	end
	-- face the camera along the station's rotation
	local _, ry = (mode == "engine" and S.origin() * GarageBuilder.STAND or S.origin() * GarageBuilder.LIFT):ToOrientation()
	A.yaw = A.yaw + ry
	updateCam()
	gui.Enabled = true
	A.refresh()
end
local function close()
	endDrag()
	closeMenu()
	gui.Enabled = false
	A.mode = nil
	fx:ClearAllChildren()
	fx.Parent = nil
end
S.open.Event:Connect(function(what, atStation)
	if (what == "engine" or what == "work") and atStation then open(what) end
end)
S.modeEv.Event:Connect(function(mode) if mode ~= "engine" and mode ~= "work" and A.mode then close() end end)
S.changed.Event:Connect(function() if A.mode and not drag then A.refresh() end end)

---------------------------------------------------------------- input
local rotating = false
UIS.InputBegan:Connect(function(input, gp)
	if not A.mode then return end
	if input.KeyCode == Enum.KeyCode.R and not gp then A.yaw = A.yaw + math.rad(45); updateCam() end
	if not gp and (input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.Q) then A.yaw = A.yaw + math.rad(20); updateCam() end
	if not gp and (input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.E) then A.yaw = A.yaw - math.rad(20); updateCam() end
	if not gp and input.KeyCode == Enum.KeyCode.Up then A.pitch = math.clamp(A.pitch + 0.15, -0.45, 1.45); updateCam() end
	if not gp and input.KeyCode == Enum.KeyCode.Down then A.pitch = math.clamp(A.pitch - 0.15, -0.45, 1.45); updateCam() end
	if input.UserInputType == Enum.UserInputType.MouseButton2 and not gp then
		local mp = mountedAt(plr:GetMouse().Target)
		if mp then
			local okR, why
			if mp.kind == "engine" then okR, why = EngineDef.canRemove((engineMap()), mp.id) else okR, why = MopedDef.canRemove(S.moped(), mp.id) end
			if okR then unmount(mp) else S.toast(why, "error") end
		else
			rotating = true
		end
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not gp and not drag then
		closeMenu()
		local mp = mountedAt(plr:GetMouse().Target)
		if mp then
			local pos = UIS:GetMouseLocation()
			contextMenu(mp, pos.X, pos.Y - 58)
		else
			-- drag on empty space: orbit 360 degrees around the moped/engine
			rotating = true
		end
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton1 then rotating = false end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and drag then dropDrag() end
end)
UIS.InputChanged:Connect(function(input, gp)
	if not A.mode then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		A.dist = math.clamp(A.dist - input.Position.Z * 0.8, (A.mode == "engine" or A.engineZoom) and 2.5 or 5, A.mode == "engine" and 12 or 22)
		updateCam()
	elseif input.UserInputType == Enum.UserInputType.MouseMovement and rotating then
		A.yaw = A.yaw - input.Delta.X * 0.01
		A.pitch = math.clamp(A.pitch + input.Delta.Y * 0.008, -0.45, 1.45)
		updateCam()
	end
end)

-- dragging: the ghost follows the mouse in a plane through the target; near the marker it snaps
RunService.RenderStepped:Connect(function()
	if not (A.mode and drag) then return end
	local cam = workspace.CurrentCamera
	local mpos = UIS:GetMouseLocation()
	local ray = cam:ViewportPointToRay(mpos.X, mpos.Y)
	local center = drag.marker:GetBoundingBox().Position
	local n = cam.CFrame.LookVector
	local denom = ray.Direction:Dot(n)
	local point = center
	if math.abs(denom) > 1e-4 then point = ray.Origin + ray.Direction * ((center - ray.Origin):Dot(n) / denom) end
	local sp, onScreen = cam:WorldToViewportPoint(center)
	local d = (Vector2.new(sp.X, sp.Y) - mpos).Magnitude
	drag.snapped = onScreen and d < 80
	if drag.snapped then
		drag.ghost:PivotTo(CFrame.new(center))
		for _, p in ipairs(drag.marker:GetDescendants()) do if p:IsA("BasePart") then p.Transparency = 0.25 end end
	else
		drag.ghost:PivotTo(CFrame.new(point))
		for _, p in ipairs(drag.marker:GetDescendants()) do if p:IsA("BasePart") then p.Transparency = 0.55 end end
	end
end)

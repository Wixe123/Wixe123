-- Building by hand: "Bygg Motor" (engine on the stand) and "Montera Moped" (moped on the lift).
-- Pick a part in the list: your hand holds it at the bottom right. Where it belongs glows green (or red with
-- the reason). Move the mouse onto the glow and click to place it (dragging from the list works too): it slides
-- in and a hand tightens it. Right-click a mounted part to take it off; left-click it for more choices.
-- Parts you do not own are listed with their price and can be put in the cart and ordered from here.
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

local A = { mode = nil, yaw = 0, pitch = 0.32, dist = 7, focus = Vector3.new(), filterKind = nil, selected = nil, cart = {} }

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
-- where a part kind goes: { kind = "engine"|"chassis", id = socket/slot, name }
local function placeFor(sku)
	local part = Parts.get(sku)
	if not part then return nil end
	local sock = EngineDef.socketForKind(part.kind)
	if sock then
		if not engineMap() then return nil end
		return { kind = "engine", id = sock, name = EngineDef.BY_ID[sock].name }
	end
	if A.mode ~= "work" then return nil end
	local m = S.moped()
	if part.kind == "kapa" then
		if part.stats.fits ~= m.model then return nil end
		return { kind = "chassis", id = "pan:" .. part.stats.panel, name = MopedDef.MODELS[m.model].panelById[part.stats.panel].n }
	end
	if part.kind == "ram" and part.stats.fits ~= m.model then return nil end
	for _, s in ipairs(MopedDef.SLOTS) do
		if s.kind == part.kind then return { kind = "chassis", id = s.id, name = s.n } end
	end
end
local function canMount(place, sku)
	local p = S.profile
	if place.kind == "engine" then return EngineDef.canMount(engineMap(), place.id, sku, p.items) end
	return MopedDef.canMount(S.moped(), place.id, sku)
end
local function orderOf(kind)
	local s = EngineDef.socketForKind(kind)
	if s then return EngineDef.ORDER[s] end
	for i, sl in ipairs(MopedDef.SLOTS) do if sl.kind == kind then return 100 + i end end
	return 200
end
-- the next sockets/slots that can be fitted now
local function nextKinds()
	local r = {}
	if A.mode == "engine" or A.engineZoom then
		for _, s in ipairs(EngineDef.nextUp(engineMap() or {})) do r[EngineDef.BY_ID[s].kind] = true end
	end
	if A.mode == "work" then
		local m = S.moped()
		for _, sid in ipairs(MopedDef.slotIds(m.model)) do
			if not MopedDef.filled(m, sid) and sid ~= "motor" then
				local info = MopedDef.slotInfo(m.model, sid)
				local ok = true
				for _, q in ipairs(info.req) do if not MopedDef.filled(m, q) then ok = false end end
				if ok then r[info.kind] = true end
			end
		end
	end
	return r
end

---------------------------------------------------------------- camera
local function updateCam()
	local cf = CFrame.new(A.focus) * CFrame.Angles(0, A.yaw, 0) * CFrame.Angles(-A.pitch, 0, 0) * CFrame.new(0, 0, A.dist)
	S.camTo(cf, 50)
end

---------------------------------------------------------------- UI layout (like the reference: tabs, part list, details, steps, controls)
local tabs = UI.new("Frame", { Size = UDim2.fromOffset(520, 44), Position = UDim2.fromOffset(250, 8), BackgroundTransparency = 1, Name = "Flikar" }, gui)
UI.list(tabs, 8, true)
local left = UI.panel(gui, UDim2.fromOffset(330, 400), UDim2.fromOffset(12, 60), { name = "Delar" })
local leftTitle = UI.text(left, "Motordelar", UDim2.new(1, -60, 0, 44), UDim2.fromOffset(52, 2), { font = UI.BOLD, ts = 20, name = "Titel" })
local icon = UI.new("Frame", { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(14, 10), BackgroundTransparency = 1, Name = "Ikon" }, left)
-- a wrench: handle and an open ring at the end
local handle = UI.new("Frame", { Size = UDim2.fromOffset(22, 6), Position = UDim2.fromOffset(2, 13), BackgroundColor3 = UI.C.text, BorderSizePixel = 0, Rotation = -45, Name = "Skaft" }, icon)
UI.corner(handle, 3)
local ring = UI.new("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(16, 0), BackgroundTransparency = 1, Name = "Ring" }, icon)
UI.corner(ring, 6)
UI.stroke(ring, UI.C.text, 3, 0)
local list = UI.scroll(left, UDim2.new(1, -12, 1, -56), UDim2.fromOffset(6, 50), { name = "Lista" })
UI.list(list, 4)
local cartBar = UI.panel(gui, UDim2.fromOffset(330, 52), UDim2.fromOffset(12, 468), { name = "Kundvagn" })
local cartText = UI.text(cartBar, "", UDim2.new(1, -80, 1, 0), UDim2.fromOffset(16, 0), { font = UI.BOLD, ts = 17, name = "Summa" })
local cartBtn = UI.button(cartBar, "Beställ", UDim2.fromOffset(70, 38), UDim2.new(1, -78, 0, 7), { kind = "green", ts = 15, name = "Beställ" })
local steps = UI.panel(gui, UDim2.fromOffset(290, 92), UDim2.new(0, 12, 1, -12), { anchor = Vector2.new(0, 1), name = "Steg" })
UI.pad(steps, 12, 10, 8, 8)
UI.list(steps, 2)
local detail = UI.panel(gui, UDim2.fromOffset(270, 470), UDim2.new(1, -12, 0, 60), { anchor = Vector2.new(1, 0), name = "Detaljer" })
local controls = UI.new("Frame", { Size = UDim2.fromOffset(560, 46), Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Name = "Kontroller" }, gui)
UI.list(controls, 10, true, Enum.HorizontalAlignment.Center)
local hintBox = UI.panel(gui, UDim2.fromOffset(460, 34), UDim2.new(0.5, 0, 1, -66), { anchor = Vector2.new(0.5, 1), name = "Tips", transp = 0.2, visible = false })
local hintText = UI.text(hintBox, "", UDim2.fromScale(1, 1), nil, { ts = 14, font = UI.BOLD, xa = Enum.TextXAlignment.Center, name = "Text" })

-- a little mouse drawing for the control chips
local function mouseIcon(parent, side)
	local m = UI.new("Frame", { Size = UDim2.fromOffset(18, 26), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Name = "Mus" }, parent)
	UI.corner(m, 9)
	local btn = UI.new("Frame", { Size = UDim2.fromOffset(8, 10), Position = UDim2.fromOffset(side == "right" and 9 or 1, 1), BackgroundColor3 = UI.C.text, BorderSizePixel = 0, Name = "Knapp" }, m)
	btn.BackgroundColor3 = Color3.fromRGB(40, 44, 54)
	UI.corner(btn, 4)
	return m
end
local function chip(order, key, label, side)
	local c = UI.panel(controls, UDim2.fromOffset(160, 44), nil, { name = label })
	c.LayoutOrder = order
	if key == "mouse" then
		local m = mouseIcon(c, side)
		m.Position = UDim2.fromOffset(18, 9)
	else
		local k = UI.new("Frame", { Size = UDim2.fromOffset(38, 26), Position = UDim2.fromOffset(12, 9), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Name = "Tangent" }, c)
		UI.corner(k, 5)
		UI.text(k, key, UDim2.fromScale(1, 1), nil, { ts = 13, font = UI.BOLD, color = Color3.fromRGB(30, 30, 34), xa = Enum.TextXAlignment.Center })
	end
	UI.text(c, label, UDim2.new(1, -60, 1, 0), UDim2.fromOffset(58, 0), { ts = 17, font = UI.BOLD })
end
chip(1, "mouse", "Rotera", "right")
chip(2, "mouse", "Placera", "left")
chip(3, "ESC", "Avbryt")

local menu
local function closeMenu() if menu then menu:Destroy(); menu = nil end end

---------------------------------------------------------------- 3D helpers: target glow, held part, hand
local fx = Instance.new("Folder")
fx.Name = "MonteringLokal"
local function buildAt(sku, item, place)
	local model = Instance.new("Model")
	model.Name = "Markering"
	if place.kind == "engine" then Models.buildInto(model, sku, item, engineCF())
	else Models.buildInto(model, sku, item, nil, mopedCtx()) end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.CanQuery = false; d.CastShadow = false; d.Transparency = 0.7 end
	end
	return model
end
local function glow(model, ok)
	local h = Instance.new("Highlight")
	h.Name = "Glöd"
	h.FillColor = ok and Color3.fromRGB(60, 255, 110) or Color3.fromRGB(255, 70, 60)
	h.OutlineColor = ok and Color3.fromRGB(120, 255, 150) or Color3.fromRGB(255, 120, 110)
	h.FillTransparency = 0.75
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee = model
	h.Parent = model
	return h
end
-- anchored rig moved every frame from stored offsets
local function rigOf(model)
	local r = {}
	local base = model:GetPivot()
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.CanQuery = false; d.CastShadow = false; r[#r + 1] = { d, base:ToObjectSpace(d.CFrame) } end
	end
	return r
end
local function placeRig(rig, cf) for _, x in ipairs(rig) do x[1].CFrame = cf * x[2] end end

-- a hand with a wrench tightening at a point, then gone
local function handAnim(pos, unscrew)
	local cam = workspace.CurrentCamera
	local toCam = (cam.CFrame.Position - pos).Unit
	local hand = Models.hand(fx, CFrame.new(), true)
	local wrench = Instance.new("Model")
	wrench.Parent = hand
	Models.tool(wrench, "nyckel", CFrame.new(0, 0.05, -0.55), false)
	local rig = rigOf(hand)
	local start = CFrame.lookAt(pos + toCam * 2.2 + Vector3.new(0, 0.6, 0), pos)
	local near = CFrame.lookAt(pos + toCam * 0.9 + Vector3.new(0, 0.25, 0), pos)
	task.spawn(function()
		local t = 0
		while t < 1.2 and hand.Parent do
			local dt = RunService.RenderStepped:Wait()
			t = t + dt
			local cf
			if t < 0.25 then cf = start:Lerp(near, t / 0.25)
			elseif t < 0.95 then cf = near * CFrame.Angles(0, 0, (unscrew and -1 or 1) * math.rad(55) * math.abs(math.sin((t - 0.25) * 18)))
			else cf = near:Lerp(start, (t - 0.95) / 0.25) end
			placeRig(rig, cf)
		end
		hand:Destroy()
	end)
end

-- the part you hold: { id, sku, place, ok, why, marker, ghost, ghostRig, hand, handRig, snapped, dragging }
local held
local function releaseHeld()
	if held then
		if held.marker then held.marker:Destroy() end
		if held.ghost then held.ghost:Destroy() end
		if held.hand then held.hand:Destroy() end
	end
	held = nil
	hintBox.Visible = false
	S.escCapture = nil
end
local function hold(id, dragging)
	releaseHeld()
	local it = S.item(id)
	if not it or not A.mode then return end
	local place = placeFor(it.sku)
	if not place then S.toast(Parts.get(it.sku).name .. " sitter inte här", "error"); return end
	local ok, why = canMount(place, it.sku)
	local marker = buildAt(it.sku, it, place)
	marker.Parent = fx
	glow(marker, ok)
	local ghost = Models.item(it.sku, it)
	ghost.Parent = fx
	local hand = Models.hand(fx, CFrame.new(), false)
	held = { id = id, sku = it.sku, place = place, ok = ok, why = why, marker = marker, ghost = ghost, ghostRig = rigOf(ghost), hand = hand, handRig = rigOf(hand), dragging = dragging }
	A.selected = { sku = it.sku, id = id }
	hintText.Text = ok and ("Klicka på den gröna markeringen för att montera " .. Parts.get(it.sku).name:lower()) or ("Går inte än: " .. tostring(why))
	hintBox.BackgroundColor3 = ok and UI.C.panel or Color3.fromRGB(110, 30, 30)
	hintBox.Visible = true
	S.escCapture = function() releaseHeld(); A.refresh(); return true end
	A.refresh()
end
local function place()
	local d = held
	if not d then return end
	if not d.ok then S.toast(d.why or "Går inte", "error"); return end
	local target = d.marker:GetBoundingBox()
	local _, mapTarget = engineMap()
	local okA
	if d.place.kind == "engine" then okA = S.api("mountEngine", mapTarget, d.place.id, d.id)
	else okA = S.api("mountChassis", d.place.id, d.id) end
	if okA then
		handAnim(target.Position, false)
		S.toast(Parts.get(d.sku).name .. " monterad", "ok")
	end
	releaseHeld()
	A.refresh()
end

---------------------------------------------------------------- mounted parts in 3D
local function mountedAt(inst)
	local plot = S.plot()
	if not plot or not inst then return nil end
	local x = inst
	while x and x ~= plot do
		if x:IsA("Model") then
			local sock, slot = x:GetAttribute("Sock"), x:GetAttribute("Slot")
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
	local _, target = engineMap()
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
local function contextMenu(mp, x, y)
	closeMenu()
	menu = UI.panel(gui, UDim2.fromOffset(190, 10), UDim2.fromOffset(x + 8, y - 50), { name = "Meny", z = 20 })
	menu.AutomaticSize = Enum.AutomaticSize.Y
	UI.pad(menu, 6)
	UI.list(menu, 4)
	local it = S.item(mp.item)
	UI.text(menu, it and Parts.get(it.sku).name or "Del", UDim2.new(1, 0, 0, 24), nil, { font = UI.BOLD, ts = 14, z = 21, truncate = true })
	local function add(text, f) UI.button(menu, text, UDim2.new(1, 0, 0, 32), nil, { kind = "secondary", ts = 14, z = 21 }, function() closeMenu(); f() end) end
	add("Demontera", function() unmount(mp) end)
	if mp.kind == "chassis" and mp.id:sub(1, 4) == "pan:" then
		add("Lackera", function()
			local ok, id = S.api("unmountChassis", mp.id)
			if ok and id and S.api("moveTo", id, "lack") then S.endMode(); S.open:Fire("paint") end
		end)
	end
	add("Byt ut", function()
		local part = it and Parts.get(it.sku)
		if unmount(mp) and part then A.filterKind = part.kind; A.refresh() end
	end)
	add("Inspektera", function() if it then A.selected = { sku = it.sku, id = mp.item }; A.refresh() end end)
end

---------------------------------------------------------------- list rows, details, steps, cart
local function spec(part)
	local s = part.stats
	if s.cc then return string.format("%.0fcc", s.cc) end
	if s.bore then return tostring(s.bore) .. " mm" end
	if s.mm then return tostring(s.mm) .. " mm" end
	if s.stroke then return tostring(s.stroke) .. " mm" end
	if s.gram then return tostring(s.gram) .. " g" end
	return part.brand
end
local function row(order, sku, id, label)
	local part = Parts.get(sku)
	local sel = A.selected and A.selected.sku == sku and A.selected.id == id
	local r = UI.new("TextButton", { Size = UDim2.new(1, -6, 0, 64), BackgroundColor3 = sel and UI.C.accent or UI.C.panel2, BackgroundTransparency = sel and 0 or 0.1, Text = "", AutoButtonColor = true, LayoutOrder = order, Name = (id and "Del_" .. id) or ("Köp_" .. sku) }, list)
	UI.corner(r, 8)
	if sel then UI.stroke(r, UI.C.accent2, 2, 0) end
	local img = UI.viewport(r, Models.item(sku), UDim2.fromOffset(54, 54), UDim2.fromOffset(5, 5), { bg = Color3.fromRGB(46, 50, 60), radius = 6 })
	img.Active = false
	UI.text(r, Parts.kindName(part.kind), UDim2.new(1, -150, 0, 20), UDim2.fromOffset(66, 10), { ts = 15, font = UI.BOLD, truncate = true })
	UI.text(r, "(" .. spec(part) .. ")", UDim2.new(1, -150, 0, 18), UDim2.fromOffset(66, 32), { ts = 13, color = sel and UI.C.text or UI.C.dim, truncate = true })
	UI.text(r, label, UDim2.fromOffset(84, 64), UDim2.new(1, -92, 0, 0), { ts = 15, font = UI.BOLD, xa = Enum.TextXAlignment.Right, color = id and UI.C.green or UI.C.text, name = "Pris" })
	if id then
		r.MouseButton1Down:Connect(function() hold(id, true) end)
	else
		r.Activated:Connect(function() A.selected = { sku = sku }; A.refresh() end)
	end
	r.MouseButton2Click:Connect(function()
		if not id then return end
		closeMenu()
		local mpos = UIS:GetMouseLocation()
		menu = UI.panel(gui, UDim2.fromOffset(190, 10), UDim2.fromOffset(mpos.X + 8, mpos.Y - 60), { name = "Meny", z = 20 })
		menu.AutomaticSize = Enum.AutomaticSize.Y
		UI.pad(menu, 6)
		UI.list(menu, 4)
		UI.button(menu, "Lägg på hyllan", UDim2.new(1, 0, 0, 32), nil, { kind = "secondary", ts = 14, z = 21 }, function() closeMenu(); S.api("moveTo", id, "hylla") end)
		local it = S.item(id)
		if it and not it.cust then
			UI.button(menu, "Sälj (" .. UI.kr(math.floor(part.price * 0.5 * (1 - 0.6 * (it.wear or 0)))) .. ")", UDim2.new(1, 0, 0, 32), nil, { kind = "danger", ts = 14, z = 21 }, function() closeMenu(); S.api("sell", id) end)
		end
	end)
end
local function cartTotal()
	local n, sum = 0, 0
	for sku, q in pairs(A.cart) do n = n + q; sum = sum + Parts.get(sku).price * q end
	return n, sum
end
local function buildDetail()
	UI.clear(detail)
	UI.pad(detail, 14)
	local sel = A.selected
	local part = sel and Parts.get(sel.sku)
	local y = 0
	if part then
		UI.text(detail, Parts.kindName(part.kind) .. " (" .. spec(part) .. ")", UDim2.new(1, 0, 0, 28), nil, { font = UI.BOLD, ts = 19, truncate = true })
		UI.viewport(detail, Models.item(part.sku), UDim2.new(1, 0, 0, 150), UDim2.fromOffset(0, 34), { bg = Color3.fromRGB(46, 50, 60) })
		UI.text(detail, part.brand .. " · " .. part.name, UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 192), { ts = 13, color = UI.C.dim, truncate = true })
		UI.text(detail, "Pris:", UDim2.new(0.5, 0, 0, 26), UDim2.fromOffset(0, 214), { ts = 16 })
		UI.text(detail, part.price > 0 and UI.kr(part.price) or "Ingår", UDim2.new(0.5, 0, 0, 26), UDim2.new(0.5, 0, 0, 214), { ts = 16, font = UI.BOLD, xa = Enum.TextXAlignment.Right })
		UI.text(detail, "Beskrivning:", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 244), { ts = 14, font = UI.BOLD })
		UI.text(detail, part.desc, UDim2.new(1, 0, 0, 54), UDim2.fromOffset(0, 266), { ts = 13, wrap = true, ya = Enum.TextYAlignment.Top, color = UI.C.dim })
		local place2 = placeFor(part.sku)
		if place2 then
			local ok, why = canMount(place2, part.sku)
			UI.text(detail, ok and ("Passar nu: " .. place2.name) or tostring(why), UDim2.new(1, 0, 0, 36), UDim2.fromOffset(0, 320), { ts = 13, wrap = true, font = UI.BOLD, color = ok and UI.C.green or UI.C.orange })
		end
		if not sel.id and part.price > 0 then
			UI.button(detail, "Lägg i kundvagn", UDim2.new(1, 0, 0, 36), UDim2.fromOffset(0, 360), { kind = "primary", ts = 15 }, function()
				A.cart[part.sku] = math.min(10, (A.cart[part.sku] or 0) + 1)
				S.toast(part.name .. " ligger i kundvagnen", "ok")
				A.refresh()
			end)
		end
		y = 402
	else
		UI.text(detail, "Välj en del i listan", UDim2.new(1, 0, 0, 28), nil, { font = UI.BOLD, ts = 17 })
		UI.text(detail, "Klicka på en del så håller du den i handen. Klicka sedan på den gröna markeringen för att montera den.", UDim2.new(1, 0, 0, 80), UDim2.fromOffset(0, 32), { ts = 14, wrap = true, color = UI.C.dim, ya = Enum.TextYAlignment.Top })
		y = 120
	end
	-- station actions
	local actions = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 120), Position = UDim2.new(0, 0, 1, -120), BackgroundTransparency = 1, Name = "Åtgärder" }, detail)
	UI.list(actions, 6)
	local p, m = S.profile, S.moped()
	local map = engineMap()
	local function act(text, kind, f) UI.button(actions, text, UDim2.new(1, 0, 0, 34), nil, { kind = kind, ts = 14 }, f) end
	if A.mode == "engine" then
		if map and EngineDef.complete(map) and m and not m.engine then act("Sätt motorn i mopeden", "green", function() if S.api("engineToMoped") then S.toast("Motorn sitter i mopeden", "ok") end end) end
		if m and m.engine and EngineDef.isEmpty(p.stand) then act("Lyft ur motorn ur mopeden", "secondary", function() if S.api("engineToStand") then S.toast("Motorn står på stativet", "ok") end end) end
		for _, j in ipairs(p.jobs) do if j.type == "reparation" or j.type == "bygg" then act("Lämna motorn till kunden", "yellow", function() S.api("completeJob", j.id) end) end end
	else
		if m.engine then
			act(A.engineZoom and "Visa hela mopeden" or "Meka på motorn här", "secondary", function()
				A.engineZoom = not A.engineZoom
				if A.engineZoom then A.focus = (engineCF() * CFrame.new(0, 0.2, 0.2)).Position; A.dist = 5
				else A.focus = (S.origin() * GarageBuilder.LIFT * CFrame.new(0, 2.2, 0)).Position; A.dist = 11 end
				updateCam()
				A.refresh()
			end)
			act("Lyft ur motorn", "secondary", function() if S.api("engineToStand") then S.toast("Motorn står på motorstativet", "ok") end end)
		elseif EngineDef.complete(p.stand) then act("Montera motorn från stativet", "green", function() S.api("engineToMoped") end) end
		if #Profile.mopedProblems(p, m) == 0 then act("Kör ut", "green", function() S.endMode(); S.open:Fire("ride") end) end
	end
end
local function buildSteps()
	UI.clear(steps)
	-- the last two things fitted and the next one to do
	local done, todo = {}, nil
	if A.mode == "engine" or A.engineZoom then
		local map = engineMap() or {}
		for _, s in ipairs(EngineDef.SOCKETS) do
			if map[s.id] then done[#done + 1] = s.name .. " monterad"
			elseif not todo then
				local ok = true
				for _, q in ipairs(s.req) do if not map[q] then ok = false end end
				if ok then todo = "Montera " .. s.name:lower() end
			end
		end
	else
		local m = S.moped()
		for _, sid in ipairs(MopedDef.slotIds(m.model)) do
			local info = MopedDef.slotInfo(m.model, sid)
			if MopedDef.filled(m, sid) then done[#done + 1] = info.n .. " monterad"
			elseif not todo then todo = "Montera " .. info.n:lower() end
		end
	end
	local rows = {}
	for i = math.max(1, #done - (todo and 1 or 2)), #done do rows[#rows + 1] = { done[i], true } end
	if todo then rows[#rows + 1] = { todo, false } else rows[#rows + 1] = { A.mode == "engine" and "Motorn är komplett!" or "Mopeden är komplett!", true } end
	for i, r in ipairs(rows) do
		local f = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = i, Name = "Steg" .. i }, steps)
		local mark = UI.new("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(0, 4), BackgroundColor3 = r[2] and UI.C.green or UI.C.panel, BorderSizePixel = 0 }, f)
		UI.corner(mark, 8)
		if r[2] then UI.text(mark, "✓", UDim2.fromScale(1, 1), nil, { ts = 12, font = UI.BOLD, xa = Enum.TextXAlignment.Center })
		else UI.stroke(mark, UI.C.accent2, 2, 0) end
		UI.text(f, r[1], UDim2.new(1, -26, 1, 0), UDim2.fromOffset(26, 0), { ts = 14, truncate = true })
	end
end
local function buildTabs()
	UI.clear(tabs)
	for i, t in ipairs({ { "engine", "Bygg Motor" }, { "work", "Montera Moped" }, { "paint", "Styling" } }) do
		UI.button(tabs, t[2], UDim2.fromOffset(160, 42), nil, { kind = A.mode == t[1] and "primary" or "ghost", order = i, ts = 17, transp = A.mode == t[1] and 0 or 0.1, name = t[2] }, function()
			if t[1] == A.mode then return end
			if t[1] == "paint" then S.endMode(); S.open:Fire("studio"); return end
			local to = t[1]
			S.endMode()
			S.open:Fire(to)
		end)
	end
end

function A.refresh()
	if not A.mode or not S.profile then return end
	local p = S.profile
	buildTabs()
	leftTitle.Text = (A.mode == "engine" or A.engineZoom) and "Motordelar" or "Mopeddelar"
	UI.clear(list)
	-- your free parts that fit here (next steps first), then parts to buy for the next steps
	local mine = {}
	for id, it in pairs(p.items) do
		if Profile.isFree(p, it) and placeFor(it.sku) then
			local part = Parts.get(it.sku)
			local engineOnly = A.engineZoom and not EngineDef.socketForKind(part.kind)
			if not engineOnly and (not A.filterKind or A.filterKind == part.kind) then mine[#mine + 1] = id end
		end
	end
	local nxt = nextKinds()
	table.sort(mine, function(a, b)
		local ka, kb = Parts.get(p.items[a].sku).kind, Parts.get(p.items[b].sku).kind
		local na, nb = nxt[ka] and 0 or 1, nxt[kb] and 0 or 1
		if na ~= nb then return na < nb end
		if ka ~= kb then return orderOf(ka) < orderOf(kb) end
		return a < b
	end)
	local order = 0
	for _, id in ipairs(mine) do
		order = order + 1
		row(order, p.items[id].sku, id, "Din")
	end
	order = order + 1
	UI.text(list, #mine == 0 and "Du har inga lösa delar som passar. Köp här:" or "Köp till:", UDim2.new(1, -6, 0, 26), nil, { ts = 13, font = UI.BOLD, color = UI.C.dim, order = order })
	local shown = 0
	for _, part in ipairs(Parts.LIST) do
		if part.price > 0 and (A.filterKind and part.kind == A.filterKind or (not A.filterKind and nxt[part.kind])) and placeFor(part.sku) then
			order = order + 1
			shown = shown + 1
			row(order, part.sku, nil, UI.kr(part.price))
		end
	end
	if A.filterKind then
		order = order + 1
		UI.button(list, "Visa alla delar", UDim2.new(1, -6, 0, 32), nil, { kind = "yellow", ts = 13, order = order }, function() A.filterKind = nil; A.refresh() end)
	end
	-- cart
	local n, sum = cartTotal()
	cartText.Text = string.format("Kundvagn (%d)   %s", n, UI.kr(sum))
	UI.setKind(cartBtn, n > 0 and "green" or "secondary")
	buildDetail()
	buildSteps()
end
cartBtn.Activated:Connect(function()
	local cart = {}
	for sku, q in pairs(A.cart) do cart[#cart + 1] = { sku = sku, qty = q } end
	if #cart == 0 then S.toast("Kundvagnen är tom – välj en del under Köp till", "info"); return end
	local ok, o = S.api("order", cart)
	if ok then
		A.cart = {}
		S.toast("Beställt! Paketet kommer om " .. UI.time(o.ready - S.now()) .. " till garageporten.", "ok")
		A.refresh()
	end
end)

---------------------------------------------------------------- open / close
local function open(mode)
	if not S.profile then return end
	if mode == "work" and not S.moped() then return end
	if not S.setMode(mode) then return end
	A.mode = mode
	A.filterKind = nil
	A.engineZoom = false
	A.selected = nil
	fx.Parent = workspace
	if mode == "engine" then
		A.focus = (S.origin() * GarageBuilder.STAND * CFrame.new(0, 0.1, 0.5)).Position
		A.dist, A.yaw, A.pitch = 6.5, math.rad(200), 0.35
	else
		A.focus = (S.origin() * GarageBuilder.LIFT * CFrame.new(0, 2.2, 0)).Position
		A.dist, A.yaw, A.pitch = 11, math.rad(240), 0.3
	end
	local _, ry = (mode == "engine" and S.origin() * GarageBuilder.STAND or S.origin() * GarageBuilder.LIFT):ToOrientation()
	A.yaw = A.yaw + ry
	updateCam()
	gui.Enabled = true
	A.refresh()
end
local function close()
	releaseHeld()
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
S.changed.Event:Connect(function() if A.mode and not held then A.refresh() end end)

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
		if mp and not held then
			local okR, why
			if mp.kind == "engine" then okR, why = EngineDef.canRemove((engineMap()), mp.id) else okR, why = MopedDef.canRemove(S.moped(), mp.id) end
			if okR then unmount(mp) else S.toast(why, "error") end
		else
			rotating = true
		end
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not gp then
		closeMenu()
		if held and held.snapped then place(); return end
		local mp = not held and mountedAt(plr:GetMouse().Target)
		if mp then
			local pos = UIS:GetMouseLocation()
			contextMenu(mp, pos.X, pos.Y - 58)
		else
			rotating = true -- drag on empty space: orbit 360 degrees
		end
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton1 then rotating = false end
	-- dragged from the list and let go on the glow: place it
	if input.UserInputType == Enum.UserInputType.MouseButton1 and held and held.dragging then
		held.dragging = false
		if held.snapped then place() end
	end
end)
UIS.InputChanged:Connect(function(input)
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

-- the held part: in your hand at the bottom right; near the glow it jumps onto it (click to place)
RunService.RenderStepped:Connect(function()
	if not (A.mode and held) then return end
	local cam = workspace.CurrentCamera
	local mpos = UIS:GetMouseLocation()
	local center = held.marker:GetBoundingBox().Position
	local sp, onScreen = cam:WorldToViewportPoint(center)
	held.snapped = onScreen and (Vector2.new(sp.X, sp.Y) - mpos).Magnitude < 90
	local h = held.marker:FindFirstChild("Glöd")
	if h then h.FillTransparency = held.snapped and 0.45 or 0.75 end
	local inHand = cam.CFrame * CFrame.new(0.8, -0.72, -3.8)
	if held.snapped and held.ok then
		placeRig(held.ghostRig, CFrame.new(center))
	else
		-- follow the mouse a little while staying in the hand
		local ray = cam:ViewportPointToRay(mpos.X, mpos.Y)
		local drift = held.dragging and (ray.Origin + ray.Direction * 3) or inHand.Position
		placeRig(held.ghostRig, CFrame.new(drift) * cam.CFrame.Rotation * CFrame.Angles(0.3, 0.6, 0))
	end
	-- the hand holds the part from below, wrist towards the bottom right of the screen
	local gp = held.ghost:GetPivot().Position
	local handCF = CFrame.lookAt(gp + cam.CFrame.RightVector * 0.35 - cam.CFrame.UpVector * 0.42 + cam.CFrame.LookVector * -0.1, gp + cam.CFrame.UpVector * 0.1) * CFrame.Angles(0, 0, math.rad(-30))
	placeRig(held.handRig, handCF)
end)

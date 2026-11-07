-- Interaction in the garage: hover outline, pick up/carry/place parts, menu on the moped's parts,
-- and engine mode where parts are dragged onto the engine block and snap into the right place.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Assembly = require(Shared.Assembly)
local Economy = require(Shared.Economy)
local Builder = require(Shared.Builder)
local Panels = require(Shared.Panels)
local GarageBuilder = require(Shared.GarageBuilder)
local CS = require(Shared.ClientState)
local Api = RS:WaitForChild("Remotes"):WaitForChild("Api")
local plr = Players.LocalPlayer
local cam = workspace.CurrentCamera
local S = 1 / Config.STUD

local function call(action, ...)
	local ok, msg = Api:InvokeServer(action, ...)
	if msg and msg ~= "" and type(msg) == "string" then CS.toast:Fire(msg) end
	return ok, msg
end

-- ---------- UI: hint at the cursor, menu, engine panel ----------
local gui = Instance.new("ScreenGui"); gui.Name = "Interact"; gui.ResetOnSpawn = false; gui.Parent = plr:WaitForChild("PlayerGui")
local hint = Instance.new("TextLabel"); hint.BackgroundColor3 = Color3.fromRGB(20, 24, 30); hint.BackgroundTransparency = 0.2; hint.TextColor3 = Color3.new(1, 1, 1)
hint.Font = Enum.Font.GothamMedium; hint.TextSize = 14; hint.AutomaticSize = Enum.AutomaticSize.XY; hint.Visible = false; hint.Parent = gui
Instance.new("UICorner", hint).CornerRadius = UDim.new(0, 6)
local hp = Instance.new("UIPadding"); hp.PaddingLeft, hp.PaddingRight, hp.PaddingTop, hp.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 4), UDim.new(0, 4); hp.Parent = hint
local highlight = Instance.new("Highlight"); highlight.FillTransparency = 1; highlight.OutlineColor = Color3.fromRGB(255, 255, 255); highlight.DepthMode = Enum.HighlightDepthMode.Occluded; highlight.Parent = gui

local function btn(parent, text, primary, cb)
	local b = Instance.new("TextButton"); b.Text = text; b.Font = Enum.Font.GothamBold; b.TextSize = 14; b.AutoButtonColor = true
	b.TextColor3 = primary and Color3.fromRGB(20, 20, 20) or Color3.new(1, 1, 1); b.BackgroundColor3 = primary and Color3.fromRGB(255, 176, 32) or Color3.fromRGB(44, 52, 64)
	b.Size = UDim2.new(1, 0, 0, 30); b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.MouseButton1Click:Connect(cb)
	return b
end
local menu = Instance.new("Frame"); menu.BackgroundColor3 = Color3.fromRGB(24, 29, 37); menu.Size = UDim2.new(0, 210, 0, 0); menu.AutomaticSize = Enum.AutomaticSize.Y; menu.Visible = false; menu.Parent = gui
Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 8)
local ml = Instance.new("UIListLayout"); ml.Padding = UDim.new(0, 5); ml.Parent = menu
local mp = Instance.new("UIPadding"); mp.PaddingLeft, mp.PaddingRight, mp.PaddingTop, mp.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8); mp.Parent = menu
local function closeMenu() menu.Visible = false; for _, c in ipairs(menu:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end end
local function label(parent, t, size, color)
	local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Text = t; l.TextSize = size or 14; l.Font = Enum.Font.GothamMedium; l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left; l.TextWrapped = true; l.Size = UDim2.new(1, 0, 0, 0); l.AutomaticSize = Enum.AutomaticSize.Y; l.RichText = true; l.Parent = parent
	return l
end

-- ---------- helpers ----------
local function prof() return CS.profile end
local function myPlot() return prof() and prof()._plot end
local function anchors() return myPlot() and GarageBuilder.anchors(GarageBuilder.plotOrigin(myPlot())) end
local function attrUp(inst, name)
	while inst and inst ~= workspace do
		local v = inst:GetAttribute(name)
		if v ~= nil then return v, inst end
		inst = inst.Parent
	end
	return nil
end
local function mouseRay(ignore)
	local m = UIS:GetMouseLocation()
	local r = cam:ViewportPointToRay(m.X, m.Y)
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = ignore or {}
	return workspace:Raycast(r.Origin, r.Direction * 60, params), r
end
local function itemName(u) local it = prof().items[u]; return it and Catalog.BY_SKU[it.s] and Catalog.BY_SKU[it.s].name or "del" end

-- ---------- hand animation (unscrewing/fitting): a hand with a wrench by the part for a moment ----------
local function wrenchAnim(pos, dur)
	local h = Builder.hand("basic", {})
	h.Parent = cam
	local t0 = os.clock()
	local con
	con = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		h:PivotTo(CFrame.lookAt(pos + Vector3.new(0.6, 0.4, 0.6), pos) * CFrame.Angles(0, 0, math.sin(t * 14) * 0.6))
		if t > dur then con:Disconnect(); h:Destroy() end
	end)
	task.wait(dur)
end

-- ---------- engine mode ----------
local eng = { on = false, drag = nil, ghost = nil, markers = {}, panel = nil }
local enginePanel = Instance.new("Frame"); enginePanel.BackgroundColor3 = Color3.fromRGB(24, 29, 37); enginePanel.BackgroundTransparency = 0.1; enginePanel.AnchorPoint = Vector2.new(1, 0)
enginePanel.Position = UDim2.new(1, -14, 0, 70); enginePanel.Size = UDim2.new(0, 240, 0, 0); enginePanel.AutomaticSize = Enum.AutomaticSize.Y; enginePanel.Visible = false; enginePanel.Parent = gui
Instance.new("UICorner", enginePanel).CornerRadius = UDim.new(0, 8)
local el = Instance.new("UIListLayout"); el.Padding = UDim.new(0, 2); el.Parent = enginePanel
local ep = Instance.new("UIPadding"); ep.PaddingLeft, ep.PaddingRight, ep.PaddingTop, ep.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10), UDim.new(0, 8), UDim.new(0, 8); ep.Parent = enginePanel

local function engineState()
	local p = prof()
	local id = p.stand
	if not id then return nil end
	return id, Assembly.engineSockets(id), Economy.skuMap(p, p.mopeds[id].eng)
end
local function renderEnginePanel()
	for _, c in ipairs(enginePanel:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
	local id, list, map = engineState()
	if not id then
		label(enginePanel, "<b>Motorstativet är tomt</b>", 15)
		label(enginePanel, "Klicka på mopeden och välj <b>Lyft ur motorn</b> (avgasen och bakhjulet måste av först).", 13, Color3.fromRGB(180, 188, 200))
	else
		label(enginePanel, "<b>Motor – " .. Config.BY_ID[id].n .. "</b>", 15)
		label(enginePanel, "Dra delar från brickan till motorn. Högerklick tar bort en del.", 12, Color3.fromRGB(180, 188, 200))
		for _, s in ipairs(list) do
			local done = map[s.id] ~= nil
			local blocked = false
			for _, r in ipairs(s.req) do if not map[r] then blocked = true end end
			label(enginePanel, (done and "<font color=\"#5ad26e\">✓</font> " or blocked and "<font color=\"#7a8494\">·</font> " or "<font color=\"#ffb020\">›</font> ") .. Catalog.KIND[s.kind][1], 13, done and Color3.new(1, 1, 1) or blocked and Color3.fromRGB(120, 128, 140) or Color3.fromRGB(255, 210, 120))
		end
		local miss = Economy.engineMissing(prof(), id)
		if #miss == 0 then btn(enginePanel, "Montera motorn i mopeden", true, function() call("engineToMoped") end) end
	end
	btn(enginePanel, "Klar (Esc)", false, function() eng.exit() end)
end

local function clearMarkers() for _, m in ipairs(eng.markers) do m:Destroy() end; eng.markers = {} end
local function marker(cf, ok)
	local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(0.35, 0.35, 0.35); p.CFrame = cf; p.Material = Enum.Material.Neon; p.Transparency = 0.35
	p.Color = ok and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 80, 70); p.Parent = cam
	table.insert(eng.markers, p)
	return p
end

function eng.enter()
	if CS.mode then return end
	CS.setMode("engine"); eng.on = true
	local a = anchors()
	cam.CameraType = Enum.CameraType.Scriptable
	local target = a.stand.Position
	TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { CFrame = CFrame.lookAt(target + (a.stand.LookVector * -0.2 + Vector3.new(0, 0.9, 0)) + (a.origin.RightVector * -2.4) + a.origin.LookVector * 1.6, target) }):Play()
	enginePanel.Visible = true
	renderEnginePanel()
end
function eng.exit()
	if not eng.on then return end
	eng.on = false; CS.setMode(nil)
	if eng.ghost then eng.ghost:Destroy(); eng.ghost = nil end
	eng.drag = nil
	clearMarkers()
	enginePanel.Visible = false
	cam.CameraType = Enum.CameraType.Custom
	CS.modeEnded:Fire()
end
-- start dragging a loose part (u) whose model lies in the world
local function startDrag(u, srcModel)
	local p = prof()
	local id, list, map = engineState()
	if not id then CS.toast:Fire("Ingen motor i stativet"); return end
	local pr = Catalog.BY_SKU[p.items[u].s]
	local socks = Assembly.socketsFor(list, pr)
	if #socks == 0 then CS.toast:Fire(pr.name .. " hör inte till motorn"); return end
	local a = anchors()
	eng.drag = { u = u, socks = {}, src = srcModel }
	clearMarkers()
	for _, sid in ipairs(socks) do
		local why = Assembly.canMount(list, map, id, sid, pr.sku)
		local cf = Builder.socketCF(a.stand, Assembly.find(list, sid))
		table.insert(eng.drag.socks, { id = sid, cf = cf, why = why })
		marker(cf, why == nil)
		if why then CS.toast:Fire(why) end
	end
	eng.ghost = Builder.item(pr.sku, p.items[u])
	for _, d in ipairs(eng.ghost:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true; d.CanQuery = false; d.CanCollide = false end end
	eng.ghost.Parent = cam
	if srcModel then for _, d in ipairs(srcModel:GetDescendants()) do if d:IsA("BasePart") then d.LocalTransparencyModifier = 0.8 end end end
end
local function endDrag(release)
	local d = eng.drag
	if not d then return end
	eng.drag = nil
	local snapped = d.snap
	clearMarkers()
	if release and snapped and not snapped.why then
		-- fitting animation: the part glides into place, then the server confirms
		local g = eng.ghost
		local tw = TweenService:Create(g.PrimaryPart, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { CFrame = snapped.cf })
		for _, part in ipairs(g:GetDescendants()) do if part:IsA("BasePart") and part ~= g.PrimaryPart then local w = Instance.new("WeldConstraint"); w.Part0, w.Part1 = g.PrimaryPart, part; w.Parent = part; part.Anchored = false end end
		tw:Play(); tw.Completed:Wait()
		wrenchAnim(snapped.cf.Position, 0.5)
		call("mountEngine", d.u, snapped.id)
	elseif release and snapped and snapped.why then CS.toast:Fire(snapped.why) end
	if eng.ghost then eng.ghost:Destroy(); eng.ghost = nil end
	if d.src and d.src.Parent then for _, x in ipairs(d.src:GetDescendants()) do if x:IsA("BasePart") then x.LocalTransparencyModifier = 0 end end end
end

-- ---------- moped menu ----------
local function openMenu(sock, inst)
	closeMenu()
	local p = prof()
	local id = p.cur
	local u = p.mopeds[id].ch[sock]
	local it = u and p.items[u]
	local title = sock == "engine" and "Motor" or (it and Catalog.BY_SKU[it.s].name or sock)
	label(menu, "<b>" .. title .. "</b>", 15)
	if it and it.paint then label(menu, "Färg " .. it.paint.col .. " · " .. ({ gloss = "blank", matt = "matt", metal = "metallic", pearl = "pärlemor", chrome = "krom" })[it.paint.fin] .. " · lack " .. math.floor((it.paint.q or 1) * 100) .. " %", 12, Color3.fromRGB(180, 188, 200)) end
	if sock == "engine" then
		btn(menu, "Lyft ur motorn", true, function() closeMenu(); call("engineToStand") end)
		btn(menu, "Gå till motorstativet", false, function() closeMenu(); eng.enter() end)
	else
		btn(menu, "Demontera", true, function()
			closeMenu()
			local pos = inst and (inst:IsA("Model") and inst:GetPivot().Position or inst.Position) or cam.CFrame.Position
			wrenchAnim(pos, 0.8)
			call("unmountMoped", sock)
		end)
		if it and Catalog.BY_SKU[it.s].kind == "panel" then
			btn(menu, "Lackera", false, function()
				closeMenu()
				local ok = call("unmountMoped", sock)
				if ok then CS.toast:Fire("Kåpan ligger på bänken: bär den till lackboxen") end
			end)
		end
		btn(menu, "Byt ut", false, function() closeMenu(); CS.openShop:Fire(it and { kind = Catalog.BY_SKU[it.s].kind, panel = Catalog.BY_SKU[it.s].val.panel } or nil) end)
		btn(menu, "Inspektera", false, function()
			closeMenu()
			if not inst then return end
			local pos = inst:IsA("Model") and inst:GetPivot().Position or inst.Position
			cam.CameraType = Enum.CameraType.Scriptable
			TweenService:Create(cam, TweenInfo.new(0.5), { CFrame = CFrame.lookAt(pos + (cam.CFrame.Position - pos).Unit * 3, pos) }):Play()
			CS.toast:Fire((it and Catalog.BY_SKU[it.s].desc or "") .. " (klicka var som helst för att gå tillbaka)")
			eng.inspect = true
		end)
	end
	btn(menu, "Stäng", false, closeMenu)
	local m = UIS:GetMouseLocation()
	menu.Position = UDim2.new(0, m.X + 12, 0, m.Y - 30)
	menu.Visible = true
end

-- ---------- hover and clicks ----------
local hover = nil
local function ignoreList()
	local t = { cam }
	if plr.Character then table.insert(t, plr.Character) end
	return t
end
RunService.RenderStepped:Connect(function()
	if not prof() then return end
	local p = prof()
	if CS.mode and CS.mode ~= "engine" then hint.Visible = false; highlight.Adornee = nil; return end
	local res = mouseRay(ignoreList())
	hover = nil
	local text
	if res then
		local inst = res.Instance
		local plot = attrUp(inst, "Plot")
		local own = plot == p._plot
		local interact, holder = attrUp(inst, "Interact")
		local sock, sockInst = attrUp(inst, "Sock")
		local itemId = attrUp(inst, "Item")
		if eng.on then
			if eng.drag then
				-- ghost follows the mouse in a plane through the engine; snaps when near a socket
				local _, ray = mouseRay(ignoreList())
				local a = anchors()
				local planeN = (cam.CFrame.Position - a.stand.Position).Unit
				local tHit = (a.stand.Position - ray.Origin):Dot(planeN) / ray.Direction.Unit:Dot(planeN)
				local pos = ray.Origin + ray.Direction.Unit * tHit
				local best, bd = nil, 1e9
				for _, s in ipairs(eng.drag.socks) do local dd = (s.cf.Position - pos).Magnitude; if dd < bd then best, bd = s, dd end end
				eng.drag.snap = (best and bd < 0.7) and best or nil
				local cf = eng.drag.snap and eng.drag.snap.cf or CFrame.new(pos)
				eng.ghost:PivotTo(cf)
				for _, d in ipairs(eng.ghost:GetDescendants()) do if d:IsA("BasePart") then d.Transparency = eng.drag.snap and 0.1 or 0.35 end end
				text = eng.drag.snap and (eng.drag.snap.why or "Släpp för att montera") or itemName(eng.drag.u)
			elseif own and itemId and interact == "item" then hover = { kind = "dragitem", u = itemId, inst = holder }; text = "Dra: " .. itemName(itemId)
			elseif own and sock and interact == "engine" then hover = { kind = "engsock", sock = sock, inst = sockInst }; text = Catalog.KIND[Assembly.find(Assembly.engineSockets(p.stand), sock).kind][1] .. " · högerklick: ta bort" end
		elseif not own and plot then text = "Någon annans garage"
		elseif interact == "item" and itemId then hover = { kind = "item", u = itemId, inst = holder }; text = "[Klick] Plocka upp " .. itemName(itemId) .. (holder:GetAttribute("Wet") and " (lacken torkar)" or "")
		elseif interact == "box" then hover = { kind = "box", oid = holder:GetAttribute("Order"), inst = holder }; text = "[Klick] Öppna leveransen"
		elseif interact == "moped" and sock then hover = { kind = "mopedpart", sock = sock, inst = sockInst }; text = p._carry and ("[Klick] Montera " .. itemName(p._carry)) or "[Klick] " .. (sock == "engine" and "Motor" or (p.mopeds[p.cur].ch[sock] and itemName(p.mopeds[p.cur].ch[sock]) or sock))
		elseif interact == "moped" then hover = { kind = "moped", inst = holder }; text = p._carry and ("[Klick] Montera " .. itemName(p._carry)) or "Mopeden"
		elseif interact == "parked" then hover = { kind = "parked", inst = holder }; text = "[Klick] Ställ fram den här mopeden"
		elseif interact then
			hover = { kind = interact, inst = holder }
			local h = holder:GetAttribute("Hint") or interact
			text = (p._carry and (interact == "bench" or interact == "shelf" or interact == "floor" or interact == "booth" or interact == "portbench")) and ("[Klick] " .. h) or (p._carry and interact ~= "stand") and itemName(p._carry) or ("[Klick] " .. h)
		end
	end
	highlight.Adornee = hover and hover.inst or nil
	if text then local m = UIS:GetMouseLocation(); hint.Text = text; hint.Position = UDim2.new(0, m.X + 18, 0, m.Y + 6); hint.Visible = true else hint.Visible = false end
end)

UIS.InputBegan:Connect(function(io, gp)
	if gp or not prof() then return end
	local p = prof()
	if io.KeyCode == Enum.KeyCode.Escape then if eng.on then eng.exit() end; closeMenu(); return end
	if eng.inspect and io.UserInputType == Enum.UserInputType.MouseButton1 then eng.inspect = false; cam.CameraType = Enum.CameraType.Custom; return end
	if io.UserInputType == Enum.UserInputType.MouseButton2 and eng.on and hover and hover.kind == "engsock" then
		local pos = hover.inst:GetPivot().Position
		wrenchAnim(pos, 0.5)
		call("unmountEngine", hover.sock)
		return
	end
	if io.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if menu.Visible then return end
	if eng.on then
		if hover and hover.kind == "dragitem" then startDrag(hover.u, hover.inst) end
		return
	end
	if CS.mode or not hover then return end
	local k = hover.kind
	if p._carry then
		if k == "bench" or k == "shelf" or k == "floor" or k == "booth" or k == "portbench" then call("place", k)
		elseif k == "stand" or k == "engine" then eng.enter(); task.wait(0.7); startDrag(p._carry, nil)
		elseif k == "moped" or k == "mopedpart" then
			local pr = Catalog.BY_SKU[p.items[p._carry].s]
			local socks = Assembly.socketsFor(Assembly.chassisSlots(p.cur), pr)
			if #socks == 0 then CS.toast:Fire(pr.name .. " monteras inte direkt på mopeden"); return end
			local cmap = Economy.skuMap(p, p.mopeds[p.cur].ch)
			local sock = socks[1]
			for _, sid in ipairs(socks) do if not cmap[sid] then sock = sid; break end end
			wrenchAnim(hover.inst:GetPivot().Position, 0.6)
			call("mountMoped", p._carry, sock)
		end
		return
	end
	if k == "item" then call("pickup", hover.u)
	elseif k == "box" then call("openBox", hover.oid)
	elseif k == "computer" then CS.openShop:Fire(nil)
	elseif k == "stand" or k == "engine" then eng.enter()
	elseif k == "portbench" then CS.openPort:Fire()
	elseif k == "booth" then CS.openPaint:Fire()
	elseif k == "mopedpart" then openMenu(hover.sock, hover.inst)
	elseif k == "parked" then local id = hover.inst.Name:match("^Parked_(.+)$"); if id then call("select", id) end
	end
end)
UIS.InputEnded:Connect(function(io)
	if io.UserInputType == Enum.UserInputType.MouseButton1 and eng.drag then endDrag(true) end
end)
CS.changed.Event:Connect(function() if eng.on then renderEnginePanel() end end)

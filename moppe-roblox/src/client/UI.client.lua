-- HUD (money, messages, speedometer when riding), the "Min moppe" panel (M) and styling mode (3D view of the moped).
-- Most of the work happens physically in the garage (Interact, Shop, Porting, Paint); here only overview and settings.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Engine = require(Shared.Engine)
local Economy = require(Shared.Economy)
local Assembly = require(Shared.Assembly)
local Panels = require(Shared.Panels)
local CS = require(Shared.ClientState)
local remotes = RS:WaitForChild("Remotes")
local Api, StateEv = remotes:WaitForChild("Api"), remotes:WaitForChild("State")
local plr = Players.LocalPlayer
local cam = workspace.CurrentCamera
local COL = { bg = Color3.fromRGB(20, 24, 30), panel = Color3.fromRGB(28, 34, 43), input = Color3.fromRGB(44, 52, 64), tx = Color3.fromRGB(232, 236, 241), mu = Color3.fromRGB(150, 160, 175),
	ac = Color3.fromRGB(255, 176, 32), pos = Color3.fromRGB(90, 200, 110), neg = Color3.fromRGB(240, 100, 75) }

local function new(class, props, parent) local o = Instance.new(class); for k, v in pairs(props or {}) do o[k] = v end; o.Parent = parent; return o end
local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o); return o end
local function pad(o, n) new("UIPadding", { PaddingLeft = UDim.new(0, n), PaddingRight = UDim.new(0, n), PaddingTop = UDim.new(0, n), PaddingBottom = UDim.new(0, n) }, o) end
local function txt(parent, t, size, color, bold)
	return new("TextLabel", { BackgroundTransparency = 1, Text = t, TextSize = size or 14, TextColor3 = color or COL.tx, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham, RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, parent)
end
local function button(parent, t, primary, cb, w)
	local b = corner(new("TextButton", { Text = t, TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = primary and Color3.fromRGB(20, 20, 20) or COL.tx, BackgroundColor3 = primary and COL.ac or COL.input,
		Size = UDim2.new(w or 1, w and -4 or 0, 0, 30), AutoButtonColor = true }, parent), 6)
	b.MouseButton1Click:Connect(cb)
	return b
end
local function kr(n) return Catalog.fmt(n) .. " kr" end
local function call(a, ...) local ok, msg = Api:InvokeServer(a, ...); if type(msg) == "string" and msg ~= "" then CS.toast:Fire(msg) end; return ok end
local function clear(f) for _, c in ipairs(f:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end end

local gui = new("ScreenGui", { Name = "MoppeHUD", ResetOnSpawn = false }, plr:WaitForChild("PlayerGui"))
-- Roblox's player list covers the money top right: hide it (the garage signs show who owns what)
pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
-- ---------- HUD ----------
local money = corner(new("TextLabel", { BackgroundColor3 = COL.bg, BackgroundTransparency = 0.15, TextColor3 = Color3.fromRGB(255, 209, 102), Font = Enum.Font.GothamBold, TextSize = 22,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.new(0, 170, 0, 40) }, gui))
local toastBox = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.new(0, 520, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, gui)
new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center }, toastBox)
CS.toast.Event:Connect(function(t)
	local l = corner(new("TextLabel", { BackgroundColor3 = COL.bg, BackgroundTransparency = 0.1, TextColor3 = COL.tx, Font = Enum.Font.GothamMedium, TextSize = 15, Text = t, TextWrapped = true,
		Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY }, toastBox), 8)
	pad(l, 8)
	task.delay(3.5, function() l:Destroy() end)
end)
local tip = corner(new("TextLabel", { BackgroundColor3 = COL.bg, BackgroundTransparency = 0.25, TextColor3 = COL.tx, Font = Enum.Font.Gotham, TextSize = 13, Position = UDim2.new(0, 14, 1, -40),
	Size = UDim2.new(0, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.X }, gui), 6)
pad(tip, 6)
local speedo = corner(new("Frame", { BackgroundColor3 = COL.bg, BackgroundTransparency = 0.15, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.new(0, 240, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false }, gui))
pad(speedo, 10); new("UIListLayout", { Padding = UDim.new(0, 2) }, speedo)
local spd = txt(speedo, "0 km/h", 34, COL.tx, true)
local rpmBg = corner(new("Frame", { BackgroundColor3 = Color3.fromRGB(60, 60, 60), Size = UDim2.new(1, 0, 0, 6) }, speedo), 3)
local rpmFill = corner(new("Frame", { BackgroundColor3 = COL.ac, Size = UDim2.new(0, 0, 1, 0) }, rpmBg), 3)
local info = txt(speedo, "", 13)

-- ---------- the "Min moppe" panel ----------
local side = corner(new("ScrollingFrame", { BackgroundColor3 = COL.panel, BackgroundTransparency = 0.05, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 62), Size = UDim2.new(0, 330, 1, -130),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, BorderSizePixel = 0, Visible = false }, gui))
pad(side, 12); new("UIListLayout", { Padding = UDim.new(0, 6) }, side)
local mainBtn = corner(new("TextButton", { Text = "☰  Min moppe (M)", TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = COL.tx, BackgroundColor3 = COL.bg, BackgroundTransparency = 0.15,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -194, 0, 14), Size = UDim2.new(0, 160, 0, 40) }, gui))
mainBtn.MouseButton1Click:Connect(function() side.Visible = not side.Visible end)

local function renderSide()
	local p = CS.profile
	if not p or not side.Visible then return end
	clear(side)
	local id = p.cur
	local mp = p.mopeds[id]
	local mop = Config.BY_ID[id]
	txt(side, "<b>" .. mop.n .. "</b>", 19)
	-- choose moped
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30) }, side)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }, row)
	for _, m in ipairs(Config.MOPEDS) do if p.mopeds[m.id] then button(row, m.n, m.id == id, function() call("select", m.id) end, 0.33) end end
	-- status
	local miss = Economy.mopedMissing(p, id)
	if #miss == 0 then txt(side, "<font color=\"#5ad26e\">✓ Komplett och körbar</font>", 14)
	else
		local names = {}
		for _, x in ipairs(Assembly.names(Assembly.chassisSlots(id), miss, id)) do table.insert(names, x) end
		if #Economy.engineMissing(p, id) > 0 then for _, x in ipairs(Assembly.names(Assembly.engineSockets(id), Economy.engineMissing(p, id), id)) do table.insert(names, "motor: " .. x) end end
		txt(side, "<font color=\"#ff6a4a\">Saknas:</font> " .. table.concat(names, ", "), 13)
	end
	local P = Economy.engine(p, id)
	local R = CS.ride
	local th = R and R.thermal and R.thermal[id] or Engine.newThermal()
	local ti = Engine.tinfo(mop, th)
	txt(side, string.format("<b>%.1f hk</b> · %s %d°C (%s) · skick %d %%", P.hp, ti.lab, math.floor(ti.v + 0.5), ti.band, math.floor((1 - (mp.dmg or 0)) * 100 + 0.5)), 13, COL.mu)
	local cyl = mp.eng.cyl and p.items[mp.eng.cyl]
	if cyl and cyl.port then txt(side, string.format("Portad cylinder: %s (+%.1f° avgastiming)", cyl.port.label, cyl.port.deg), 12, COL.mu) end
	-- the jet (the only setting outside the garage's work stations)
	local jr = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30) }, side)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Center }, jr)
	local jl = txt(jr, "Huvudmunstycke <b>" .. mp.jet .. "</b>", 14); jl.Size = UDim2.new(0, 170, 0, 28); jl.AutomaticSize = Enum.AutomaticSize.None
	button(jr, "−", false, function() call("setJet", mp.jet - 1) end, 0.15)
	button(jr, "+", false, function() call("setJet", mp.jet + 1) end, 0.15)
	local mix = P.m < 0.93 and "<font color=\"#ff6a4a\">för mager – motorn blir varm</font>" or P.m > 1.1 and "<font color=\"#4aa3ff\">för fet – tappar effekt</font>" or "<font color=\"#5ad26e\">bra blandning</font>"
	txt(side, mix, 12)
	if (mp.dmg or 0) > 0 then button(side, "Reparera motorn, " .. kr(Economy.repairCost(p, id)), true, function() call("repair", false) end) end
	button(side, p._out and "Hämta hem mopeden (R)" or "Kör ut", not p._out, function() if p._out then call("home") else call("ride") end end)
	button(side, "Styling-läge", false, function() CS.openStyling:Fire() end)
	-- designs
	txt(side, "<b>Mina designer</b>", 14, COL.ac)
	local dr = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30) }, side)
	local box = corner(new("TextBox", { PlaceholderText = "Namn, t.ex. Black Edition", Text = "", TextSize = 13, Font = Enum.Font.Gotham, TextColor3 = COL.tx, BackgroundColor3 = COL.input, Size = UDim2.new(0.62, 0, 1, 0), ClearTextOnFocus = false }, dr), 6)
	local sb = button(dr, "Spara", true, function() call("saveDesign", box.Text) end); sb.Size = UDim2.new(0.36, 0, 1, 0); sb.Position = UDim2.new(0.64, 0, 0, 0)
	for name, d in pairs(p.designs) do if d.moped == id then button(side, "Lägg på: " .. name, false, function() call("applyDesign", name) end) end end
	-- mopeds to buy/sell
	txt(side, "<b>Mopeder</b>", 14, COL.ac)
	for _, m in ipairs(Config.MOPEDS) do
		if p.mopeds[m.id] then button(side, "Sälj " .. m.n .. " (" .. kr(Economy.sellValue(p, m.id)) .. ")", false, function() call("sellMoped", m.id) end)
		else button(side, "Köp " .. m.n .. " – " .. kr(m.price), false, function() call("buyMoped", m.id) end) end
	end
	-- tools
	local tools = {}
	for _, it in pairs(p.items) do if it.loc == "tool" then table.insert(tools, Catalog.BY_SKU[it.s].name) end end
	txt(side, "<b>Verktyg:</b> " .. table.concat(tools, ", "), 12, COL.mu)
	local s = p.stats
	txt(side, string.format("Byggda motorer %d · portade cylindrar %d · lackerade kåpor %d · körsträcka %.1f km · stegringar %d · intjänat %s", s.built, s.ported, s.painted, s.dist / 1000, s.wn, kr(s.earned)), 12, COL.mu)
end

-- ---------- styling mode: the moped in a large 3D view ----------
local sty = { on = false }
local styGui = new("ScreenGui", { Name = "Styling", ResetOnSpawn = false, Enabled = false }, plr:WaitForChild("PlayerGui"))
local styLeft = corner(new("ScrollingFrame", { BackgroundColor3 = COL.panel, BackgroundTransparency = 0.08, Position = UDim2.new(0, 14, 0, 14), Size = UDim2.new(0, 250, 1, -28), CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4, BorderSizePixel = 0 }, styGui))
pad(styLeft, 10); new("UIListLayout", { Padding = UDim.new(0, 4) }, styLeft)
local styRight = corner(new("Frame", { BackgroundColor3 = COL.panel, BackgroundTransparency = 0.08, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.new(0, 230, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, styGui))
pad(styRight, 10); new("UIListLayout", { Padding = UDim.new(0, 6) }, styRight)
local styHl = new("Highlight", { FillTransparency = 0.7, FillColor = COL.ac, OutlineColor = COL.ac }, styGui)
local function renderStyling()
	local p = CS.profile
	clear(styLeft); clear(styRight)
	txt(styLeft, "<b>Kåpor</b>", 16)
	local id = p.cur
	for _, pd in ipairs(Panels[id]) do
		local u = p.mopeds[id].ch["pan:" .. pd.id]
		local it = u and p.items[u]
		local f = corner(new("TextButton", { Text = "", BackgroundColor3 = COL.input, Size = UDim2.new(1, 0, 0, 36), AutoButtonColor = true }, styLeft), 6)
		corner(new("Frame", { BackgroundColor3 = it and it.paint and Color3.fromHex(it.paint.col) or Color3.fromRGB(60, 60, 60), Position = UDim2.new(0, 6, 0, 8), Size = UDim2.new(0, 20, 0, 20) }, f), 10)
		new("TextLabel", { BackgroundTransparency = 1, Text = pd.n .. (it and "" or " (demonterad)"), TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = it and COL.tx or COL.mu,
			TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 34, 0, 0), Size = UDim2.new(1, -38, 1, 0), TextWrapped = true }, f)
		f.MouseButton1Click:Connect(function()
			local m = workspace:FindFirstChild("Moped_" .. plr.Name)
			styHl.Adornee = m and m:FindFirstChild("Panel_" .. pd.id) or nil
			CS.toast:Fire(it and (Catalog.BY_SKU[it.s].name .. " · " .. it.paint.col .. " · lack " .. math.floor((it.paint.q or 1) * 100) .. " %") or (pd.n .. " är demonterad"))
		end)
	end
	txt(styRight, "<b>Styling</b>", 16)
	txt(styRight, "Klicka på en kåpa i garaget för att demontera eller byta den. Lackering görs i lackboxen: demontera kåpan, bär den dit och spraya.", 12, COL.mu)
	button(styRight, "Rotera 360°", true, function() sty.spin = not sty.spin end)
	for name, d in pairs(p.designs) do if d.moped == id then button(styRight, "Design: " .. name, false, function() call("applyDesign", name) end) end end
	button(styRight, "Stäng (Esc)", false, function() sty.exit() end)
end
function sty.exit()
	if not sty.on then return end
	sty.on = false; styGui.Enabled = false; styHl.Adornee = nil
	if sty.con then sty.con:Disconnect() end
	cam.CameraType = Enum.CameraType.Custom
	CS.setMode(nil); CS.modeEnded:Fire()
end
CS.openStyling.Event:Connect(function()
	if CS.mode then return end
	local m = workspace:FindFirstChild("Moped_" .. plr.Name)
	if not m then CS.toast:Fire("Mopeden står inte i garaget"); return end
	CS.setMode("styling"); sty.on = true; styGui.Enabled = true; side.Visible = false
	renderStyling()
	cam.CameraType = Enum.CameraType.Scriptable
	sty.az, sty.el, sty.dist, sty.spin = 0.8, 0.25, 9, false
	sty.con = RunService.RenderStepped:Connect(function(dt)
		if sty.spin then sty.az = sty.az + dt * 0.6 end
		if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then local d = UIS:GetMouseDelta(); sty.az = sty.az - d.X * 0.008; sty.el = math.clamp(sty.el + d.Y * 0.006, 0.02, 1.2) end
		local c = m:GetPivot().Position
		cam.CFrame = CFrame.lookAt(c + Vector3.new(math.sin(sty.az) * math.cos(sty.el), math.sin(sty.el), math.cos(sty.az) * math.cos(sty.el)) * sty.dist, c)
	end)
end)
UIS.InputChanged:Connect(function(io) if sty.on and io.UserInputType == Enum.UserInputType.MouseWheel then sty.dist = math.clamp(sty.dist - io.Position.Z * 0.8, 3.5, 18) end end)

-- ---------- updates ----------
StateEv.OnClientEvent:Connect(function(p, msg)
	CS.profile = p
	CS.changed:Fire()
	if msg and msg ~= "" then CS.toast:Fire(tostring(msg)) end
	renderSide()
	if sty.on then renderStyling() end
end)
task.spawn(function() for _ = 1, 30 do if Api:InvokeServer("state") then break end; task.wait(1) end end)
UIS.InputBegan:Connect(function(io, gp)
	if gp then return end
	if io.KeyCode == Enum.KeyCode.M and not CS.mode then side.Visible = not side.Visible; renderSide() end
	if io.KeyCode == Enum.KeyCode.Escape and sty.on then sty.exit() end
end)
local last = 0
RunService.RenderStepped:Connect(function()
	local p, R = CS.profile, CS.ride
	if not p then return end
	money.Text = kr(p.money)
	local riding = R and R.seated
	speedo.Visible = riding and true or false
	tip.Text = CS.mode and "Esc = lämna" or riding and "W gas · S broms · A/D styr · Shift stegring · K starta · X stäng av · Q/E växla · R tillbaka till garaget · Mellanslag kliv av"
		or (p._carry and "Du bär en del – klicka på bänken, hyllan, motorn eller mopeden" or "Klicka på saker i garaget · Datorn = butik · M = min moppe")
	if riding and R.P then
		spd.Text = math.floor(R.v * 3.6 + 0.5) .. " km/h"
		rpmFill.Size = UDim2.new(math.clamp(R.rpm / R.P.lim, 0, 1), 0, 1, 0)
		local ti = Engine.tinfo(R.mop, R.thermal[R.mop.id])
		local lines = {}
		if R.crash then table.insert(lines, "<font color=\"#ff6a4a\"><b>VURPA</b></font> – " .. R.crash.why)
		elseif not R.on then table.insert(lines, "<font color=\"#ff6a4a\"><b>Motorn är av</b></font> · K") end
		if R.wh then local est, mult = R.whValue(R.wh); table.insert(lines, string.format("<font color=\"#ffd166\"><b>STEGRING %.1f s</b></font> · ×%.2f · ≈ +%d kr", R.wh.t, mult or 0, est or 0)) end
		if R.on then table.insert(lines, math.floor(R.rpm) .. " rpm" .. (R.mop.cvt and "" or (" · växel " .. R.gear))) end
		table.insert(lines, string.format("%s <b>%d°C</b> %s", ti.lab, math.floor(ti.v + 0.5), ti.band))
		info.Text = table.concat(lines, "\n")
	end
	if side.Visible and os.clock() - last > 1 and not UIS:GetFocusedTextBox() then last = os.clock(); renderSide() end
end)

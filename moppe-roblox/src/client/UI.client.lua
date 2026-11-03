-- Interface: HUD, garage panel (Garage / Förråd / Pengar) and the shop with 3D previews.
-- The client only displays and asks the server (Api); all purchases and changes are checked on the server.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Engine = require(Shared.Engine)
local Economy = require(Shared.Economy)
local Builder = require(Shared.Builder)
local CS = require(Shared.ClientState)
local remotes = RS:WaitForChild("Remotes")
local Api, StateEv = remotes:WaitForChild("Api"), remotes:WaitForChild("State")
local plr = Players.LocalPlayer

local COL = { bg = Color3.fromRGB(23, 29, 37), panel = Color3.fromRGB(30, 37, 47), input = Color3.fromRGB(42, 51, 64), line = Color3.fromRGB(56, 66, 80),
	tx = Color3.fromRGB(232, 236, 241), mu = Color3.fromRGB(150, 160, 175), ac = Color3.fromRGB(255, 176, 32), pos = Color3.fromRGB(90, 200, 110), neg = Color3.fromRGB(240, 100, 75) }

-- ---------- UI helpers ----------
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o); return o end
local function label(parent, text, size, color, bold, h)
	return new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size or 14, TextColor3 = color or COL.tx, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Size = UDim2.new(1, 0, 0, h or (size or 14) + 6), AutomaticSize = Enum.AutomaticSize.Y }, parent)
end
local function button(parent, text, primary, w, cb)
	local b = new("TextButton", { Text = text, TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = primary and Color3.fromRGB(20, 20, 20) or COL.tx,
		BackgroundColor3 = primary and COL.ac or COL.input, Size = UDim2.new(w or 1, w and 0 or 0, 0, 32), AutoButtonColor = true }, parent)
	corner(b, 6)
	if cb then b.MouseButton1Click:Connect(cb) end
	return b
end
local function list(parent, pad)
	new("UIListLayout", { Padding = UDim.new(0, pad or 6), SortOrder = Enum.SortOrder.LayoutOrder }, parent)
end
local function row(parent, h)
	local f = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h or 32) }, parent)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, f)
	return f
end
local function kr(n) return Catalog.fmt(n) .. " kr" end
local function call(action, ...)
	local ok, msg = Api:InvokeServer(action, ...)
	if msg and msg ~= "" then CS.toast:Fire(tostring(msg)) end
	return ok
end

local gui = new("ScreenGui", { Name = "MoppeUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = false }, plr:WaitForChild("PlayerGui"))

-- ---------- HUD ----------
local hud = corner(new("Frame", { BackgroundColor3 = COL.bg, BackgroundTransparency = 0.15, Position = UDim2.new(0, 12, 1, -12), AnchorPoint = Vector2.new(0, 1),
	Size = UDim2.new(0, 260, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, gui), 10)
new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, hud)
list(hud, 2)
local hMoney = label(hud, "", 20, Color3.fromRGB(255, 209, 102), true)
local hToast = label(hud, "", 12, Color3.fromRGB(255, 209, 102))
local hSpeed = label(hud, "0 km/h", 30, COL.tx, true, 34)
local bar = corner(new("Frame", { BackgroundColor3 = Color3.fromRGB(60, 60, 60), Size = UDim2.new(1, 0, 0, 6) }, hud), 3)
local barFill = corner(new("Frame", { BackgroundColor3 = COL.ac, Size = UDim2.new(0, 0, 1, 0) }, bar), 3)
local hInfo = label(hud, "", 13, COL.tx)
hInfo.RichText = true
local tip = corner(new("TextLabel", { BackgroundColor3 = COL.bg, BackgroundTransparency = 0.2, TextColor3 = COL.tx, TextSize = 13, Font = Enum.Font.Gotham,
	Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(0, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.X, Text = "" }, gui), 8)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, tip)

local toastT = 0
CS.toast.Event:Connect(function(t) hToast.Text = t; toastT = os.clock() + 3 end)

-- ---------- panel ----------
local panel = corner(new("Frame", { BackgroundColor3 = COL.panel, Position = UDim2.new(1, -12, 0, 12), AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0, 340, 1, -24) }, gui), 10)
new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, panel)
local top = row(panel, 38)
local shopOpen
button(top, "Åk ut", true, 0.48, function() call("spawn") end).Size = UDim2.new(0.49, 0, 0, 36)
button(top, "Butik", true, 0.48, function() shopOpen() end).Size = UDim2.new(0.49, 0, 0, 36)
local mopRow = row(panel, 30); mopRow.Position = UDim2.new(0, 0, 0, 44)
local tabRow = row(panel, 30); tabRow.Position = UDim2.new(0, 0, 0, 80)
local body = new("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 118), Size = UDim2.new(1, 0, 1, -118), CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 5, BorderSizePixel = 0 }, panel)
list(body, 6)
local tab = "garage"

local function hpWith(p, val)
	local c = Economy.ecfg(p, p.cur)
	for k, v in pairs(val or {}) do c[k] = v end
	local P = Engine.calc(c)
	P.cond = 1 - 0.4 * (p.dmg[p.cur] or 0)
	return (Engine.peakHp(P))
end
local function effectText(p, pr)
	local inst = p.inst[p.cur] or {}
	local u = inst[pr.slot]
	if u and p.items[u] and p.items[u].s == pr.sku then return "✓ Monterad", COL.pos end
	if not Catalog.fits(pr, p.cur) then return "Passar inte din " .. Config.BY_ID[p.cur].n, COL.neg end
	if Catalog.ENGINE[pr.slot] then
		local d = hpWith(p, pr.val) - hpWith(p, nil)
		if math.abs(d) >= 0.05 then return string.format("%s%.1f hk (beräknat)", d > 0 and "+" or "−", math.abs(d)), d > 0 and COL.pos or COL.neg end
	end
	return pr.desc, COL.mu
end

local function clear(f) for _, c in ipairs(f:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then c:Destroy() end end end
local function h3(t) local l = label(body, t, 12, COL.ac, true); return l end

local function stepper(name, key, value, step, lo, hi, unit)
	local r = row(body, 34)
	local l = label(r, name, 14); l.Size = UDim2.new(0, 150, 0, 30); l.AutomaticSize = Enum.AutomaticSize.None
	button(r, "−", false, nil, function() call("tune", key, value - step) end).Size = UDim2.new(0, 34, 0, 30)
	local v = label(r, tostring(value) .. (unit or ""), 15, COL.tx, true); v.Size = UDim2.new(0, 70, 0, 30); v.AutomaticSize = Enum.AutomaticSize.None; v.TextXAlignment = Enum.TextXAlignment.Center
	button(r, "+", false, nil, function() call("tune", key, value + step) end).Size = UDim2.new(0, 34, 0, 30)
	if lo then local rng = label(body, "intervall " .. lo .. "–" .. hi .. (unit or ""), 11, COL.mu) end
end

local SWATCH = { "#e63946", "#1d6fe0", "#f4c20d", "#2a9d8f", "#111111", "#f2f2ee", "#8a2be2", "#ff7f11" }
local function render()
	local p = CS.profile
	if not p then return end
	clear(mopRow); clear(tabRow); clear(body)
	for _, m in ipairs(Config.MOPEDS) do
		local b = button(mopRow, m.n .. (p.own[m.id] and "" or " (ej ägd)"), p.cur == m.id, nil, function() call("select", m.id) end)
		b.Size = UDim2.new(0.32, 0, 0, 28); b.TextSize = 12
	end
	for _, t in ipairs({ { "garage", "Garage" }, { "inv", "Förråd" }, { "money", "Pengar" } }) do
		local b = button(tabRow, t[2], tab == t[1], nil, function() tab = t[1]; render() end); b.Size = UDim2.new(0.32, 0, 0, 28)
	end
	local id, mop = p.cur, Config.BY_ID[p.cur]
	local R = CS.ride
	if tab == "garage" then
		local P = Economy.engine(p, id)
		local E = Economy.ecfg(p, id)
		local th = R and R.thermal and R.thermal[id] or Engine.newThermal()
		local ti = Engine.tinfo(mop, th)
		label(body, string.format("<b>%.1f hk</b>   ·   %s <b>%d°C</b> (%s)   ·   skick <b>%d %%</b>", P.hp, ti.lab, math.floor(ti.v + 0.5), ti.band, math.floor((1 - (p.dmg[id] or 0)) * 100 + 0.5)), 14).RichText = true
		if (p.dmg[id] or 0) > 0 then
			local r = row(body, 34)
			button(r, "Reparera, " .. kr(Economy.repairCost(p, id)), true, nil, function() call("repair", false) end).Size = UDim2.new(0.62, 0, 0, 32)
			if p.money < Economy.repairCost(p, id) and p.dmg[id] > 0.5 then button(r, "Nödlagning", false, nil, function() call("repair", true) end).Size = UDim2.new(0.35, 0, 0, 32) end
		end
		h3("TRIMNING")
		stepper("Huvudmunstycke", "jet", E.jet, 1, E.jlo, E.jhi)
		stepper("Avgasportstiming", "port", p.cfgs[id].port, 0.5, -4, 8, "°")
		if mop.cvt then stepper("Rullvikt", "roller", E.roller, 0.5, E.rlo, E.rhi, " g") else label(body, "Växlad: Q och E byter växel.", 12, COL.mu) end
		-- one tip at a time, like the web version
		local tg = Engine.target(E)
		local _, pkAt = Engine.peakHp(P)
		local hint
		if mop.cvt and tg >= P.lim then hint = "Rullarna är för lätta för tändningens varvspärr. Höj rullvikten."
		elseif P.m < 0.93 then hint = "Blandningen är för mager: motorn blir varm. Höj munstycket."
		elseif P.m > 1.1 then hint = "Blandningen är för fet. Sänk munstycket."
		elseif Config.CARB[E.carb + 1] > E.maxd then hint = "Förgasaren stryps av insuget. Köp ett större insug."
		elseif mop.cvt and P.hp > E.blim then hint = "Remmen slirar. Köp en förstärkt rem."
		elseif mop.cvt and tg < pkAt - 1200 then hint = "Variatorn håller för lågt varv. Sänk rullvikten."
		elseif mop.cvt and tg > pkAt + 1200 then hint = "Variatorn håller för högt varv. Höj rullvikten." end
		label(body, hint and ("Tips: " .. hint) or "Inställningen ser bra ut.", 13, hint and COL.ac or COL.pos)
		h3("MONTERADE DELAR")
		for _, slot in ipairs(Catalog.SLOT_ORDER) do
			local u = (p.inst[id] or {})[slot]
			if Catalog.slotsOf(id)[slot] and Catalog.ENGINE[slot] then
				local pr = u and p.items[u] and Catalog.BY_SKU[p.items[u].s]
				label(body, Catalog.SLOTS[slot][1] .. ": " .. (pr and pr.name:gsub(" – .*$", "") or "–"), 12, COL.mu)
			end
		end
		h3("LACK OCH STARTNUMMER")
		for _, key in ipairs({ "col", "seat" }) do
			local r = row(body, 30)
			local l = label(r, key == "col" and "Kaross" or "Sadel", 13); l.Size = UDim2.new(0, 60, 0, 28); l.AutomaticSize = Enum.AutomaticSize.None
			for _, hx in ipairs(SWATCH) do
				local b = corner(new("TextButton", { Text = "", BackgroundColor3 = Color3.fromHex(hx), Size = UDim2.new(0, 26, 0, 26) }, r), 13)
				if p.cfgs[id][key] == hx then new("UIStroke", { Color = COL.ac, Thickness = 2 }, b) end
				b.MouseButton1Click:Connect(function() call("tune", key, hx) end)
			end
		end
		local fr = row(body, 32)
		for _, f in ipairs({ { "gloss", "Blank" }, { "matt", "Matt" }, { "metal", "Metallic" } }) do button(fr, f[2], p.cfgs[id].fin == f[1], nil, function() call("tune", "fin", f[1]) end).Size = UDim2.new(0.32, 0, 0, 30) end
		local nr = row(body, 32)
		local box = corner(new("TextBox", { Text = p.cfgs[id].num, PlaceholderText = "nr", TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = COL.tx, BackgroundColor3 = COL.input, Size = UDim2.new(0, 60, 0, 30) }, nr), 6)
		button(nr, "Sätt startnummer", false, nil, function() call("tune", "num", box.Text) end).Size = UDim2.new(0, 160, 0, 30)
	elseif tab == "inv" then
		h3("I FÖRRÅDET")
		local any = false
		for u, it in pairs(p.items) do
			if not Economy.installedOn(p, u) then
				any = true
				local pr = Catalog.BY_SKU[it.s]
				local why = Economy.canInstall(p, u, id)
				local f = corner(new("Frame", { BackgroundColor3 = COL.input, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, body), 8)
				new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, f)
				list(f, 4)
				label(f, pr.name, 13, COL.tx, true)
				label(f, (it.used and "begagnad" or "ny") .. (why and (" · " .. why) or ""), 11, why and COL.neg or COL.mu)
				local r = row(f, 30)
				if not why then button(r, "Montera", true, nil, function() call("install", u) end).Size = UDim2.new(0.45, 0, 0, 28) end
				button(r, "Sälj " .. kr(Economy.sellPrice(p, u)), false, nil, function() call("sell", u) end).Size = UDim2.new(0.5, 0, 0, 28)
			end
		end
		if not any then label(body, "Tomt. Köp delar i butiken.", 13, COL.mu) end
		h3("MONTERAT PÅ " .. string.upper(mop.n))
		for _, slot in ipairs(Catalog.SLOT_ORDER) do
			if Catalog.slotsOf(id)[slot] then
				local u = (p.inst[id] or {})[slot]
				local pr = u and p.items[u] and Catalog.BY_SKU[p.items[u].s]
				local r = row(body, 30)
				local l = label(r, Catalog.SLOTS[slot][1] .. ": " .. (pr and pr.name:gsub(" – .*$", "") or "ingen"), 12, COL.mu); l.Size = UDim2.new(0.7, 0, 0, 28); l.AutomaticSize = Enum.AutomaticSize.None
				if pr and Catalog.REMOVABLE[slot] then button(r, "Ta bort", false, nil, function() call("uninstall", slot) end).Size = UDim2.new(0.28, 0, 0, 26) end
			end
		end
		label(body, "Sälj: oanvänd del 70 %, begagnad 50 % av priset.", 11, COL.mu)
	else
		label(body, kr(p.money), 28, COL.tx, true, 34)
		h3("MOPEDER")
		local owned = 0
		for _, m in ipairs(Config.MOPEDS) do if p.own[m.id] then owned = owned + 1 end end
		for _, m in ipairs(Config.MOPEDS) do
			local r = row(body, 32)
			local l = label(r, m.n .. (p.own[m.id] and (" · säljvärde " .. kr(Economy.sellValue(p, m.id))) or (" · kostar " .. kr(m.price))), 12); l.Size = UDim2.new(0.7, 0, 0, 30); l.AutomaticSize = Enum.AutomaticSize.None
			if p.own[m.id] then
				if owned > 1 then button(r, "Sälj", false, nil, function() call("sellMoped", m.id) end).Size = UDim2.new(0.28, 0, 0, 28) end
			else button(r, "Köp", true, nil, function() call("buyMoped", m.id) end).Size = UDim2.new(0.28, 0, 0, 28) end
		end
		h3("SÅ TJÄNAR DU PENGAR")
		label(body, string.format("%d kr per %d m med motorn igång · %d kr per %d km utan vurpa eller överhettning · stegring upp till %d kr (minst %d km/h) · vurpa −%d kr",
			Config.ECON.distKr, Config.ECON.distM, Config.ECON.cleanKr, Config.ECON.cleanM / 1000, Config.WHEELIE.max, math.floor(Config.WHEELIE.minV * 3.6), Config.ECON.crashKr), 12, COL.mu)
		h3("STATISTIK")
		label(body, string.format("Körsträcka %.2f km · toppfart %d km/h · stegringar %d · längsta %.1f s · vurpor %d · intjänat %s",
			p.stats.dist / 1000, math.floor(p.stats.top * 3.6), p.stats.wn, p.stats.best, p.stats.crash, kr(p.stats.earned)), 12, COL.mu)
		h3("HÄNDELSER")
		for i = 1, math.min(12, #p.ledger) do local l = p.ledger[i]; label(body, (l.a > 0 and "+" or "−") .. kr(math.abs(l.a)) .. "  " .. l.x, 12, l.a > 0 and COL.pos or COL.neg) end
	end
end

-- ---------- shop ----------
local shop = new("Frame", { BackgroundColor3 = COL.bg, Size = UDim2.new(1, 0, 1, 0), Visible = false, ZIndex = 5 }, gui)
new("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingBottom = UDim.new(0, 14) }, shop)
local sTop = row(shop, 40)
local logo = label(sTop, "MOPPEDELAR", 20, COL.ac, true); logo.Size = UDim2.new(0, 150, 0, 36); logo.AutomaticSize = Enum.AutomaticSize.None
local search = corner(new("TextBox", { PlaceholderText = "Sök, t.ex. avgas, cylinder eller fälgar", Text = "", TextSize = 15, Font = Enum.Font.Gotham, TextColor3 = COL.tx,
	PlaceholderColor3 = COL.mu, BackgroundColor3 = COL.input, Size = UDim2.new(1, -330, 0, 36), ClearTextOnFocus = false }, sTop), 18)
button(sTop, "Stäng", false, nil, function() shop.Visible = false end).Size = UDim2.new(0, 90, 0, 34)
local chips = row(shop, 34); chips.Position = UDim2.new(0, 0, 0, 48)
local note = label(shop, "Demobutik i spelet: påhittade delar och priser, du betalar med spelpengar. Bilderna är 3D-förhandsvisningar av delarna.", 12, COL.mu)
note.Position = UDim2.new(0, 0, 0, 86)
local grid = new("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 112), Size = UDim2.new(1, 0, 1, -112), CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, BorderSizePixel = 0 }, shop)
new("UIGridLayout", { CellSize = UDim2.new(0, 210, 0, 300), CellPadding = UDim2.new(0, 12, 0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
local group = ""

local function preview(vp, pr)
	local model = Builder.preview(pr.slot, pr.val)
	model.Parent = vp
	local cam = new("Camera", { FieldOfView = 30 }, vp)
	vp.CurrentCamera = cam
	local cf, size = model:GetBoundingBox()
	local r = size.Magnitude / 2
	local dist = r / math.sin(math.rad(15)) * 1.05
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0.55, 0.42, 0.72).Unit * dist, cf.Position)
	vp.Ambient = Color3.fromRGB(150, 150, 160)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-1, -1.5, -0.8)
end

local function renderShop()
	local p = CS.profile
	if not p then return end
	clear(chips)
	for _, g in ipairs({ { "", "Allt" }, { "Motor" }, { "Kraftöverföring" }, { "Utseende" } }) do
		local k = g[1]
		local b = button(chips, g[2] or g[1], group == k, nil, function() group = k; renderShop() end)
		b.Size = UDim2.new(0, 130, 0, 30)
	end
	clear(grid)
	local q = string.lower(search.Text)
	local cats
	for _, g in ipairs(Catalog.GROUPS) do if g[1] == group then cats = g[2] end end
	local order = 0
	for _, pr in ipairs(Catalog.PR) do
		local ok = Catalog.fits(pr, p.cur) and (not cats or Catalog.has(cats, pr.cat))
		if ok and q ~= "" then
			for word in q:gmatch("%S+") do
				if not (string.lower(pr.name):find(word, 1, true) or string.lower(pr.man):find(word, 1, true) or string.lower(pr.cat):find(word, 1, true)) then ok = false end
			end
		end
		if ok then
			order = order + 1
			local card = corner(new("Frame", { BackgroundColor3 = COL.panel, LayoutOrder = order }, grid), 12)
			new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, card)
			list(card, 3)
			local vp = corner(new("ViewportFrame", { BackgroundColor3 = COL.input, Size = UDim2.new(1, 0, 0, 120) }, card), 8)
			preview(vp, pr)
			label(card, pr.name:gsub(" – .*$", ""), 14, COL.tx, true)
			label(card, pr.man .. " · " .. pr.cat, 11, COL.mu)
			local et, ec = effectText(p, pr)
			label(card, et, 12, ec)
			label(card, kr(pr.price), 19, COL.tx, true, 24)
			local installed = et == "✓ Monterad"
			button(card, installed and "Köp extra" or "Köp och montera", true, nil, function() call("buy", pr.sku, 1, not installed) end)
			button(card, "Köp till förrådet", false, nil, function() call("buy", pr.sku, 1, false) end)
		end
	end
	if order == 0 then label(grid, "Inga delar hittades.", 14, COL.mu) end
end
shopOpen = function() shop.Visible = true; renderShop() end
search:GetPropertyChangedSignal("Text"):Connect(function() if shop.Visible then renderShop() end end)

-- ---------- updates ----------
StateEv.OnClientEvent:Connect(function(p, msg, saveOk)
	CS.profile = p
	CS.changed:Fire()
	if msg and msg ~= "" and msg ~= true then CS.toast:Fire(tostring(msg)) end
	render()
	if shop.Visible then renderShop() end
end)
task.spawn(function()
	for _ = 1, 20 do
		local ok = Api:InvokeServer("state")
		if ok then break end
		task.wait(1)
	end
end)

UIS.InputBegan:Connect(function(io, gp)
	if gp then return end
	if io.KeyCode == Enum.KeyCode.G then panel.Visible = not panel.Visible end
	if io.KeyCode == Enum.KeyCode.B then if shop.Visible then shop.Visible = false else shopOpen() end end
end)

local lastPanel = 0
RunService.RenderStepped:Connect(function()
	local p, R = CS.profile, CS.ride
	if not p then return end
	hMoney.Text = kr(p.money)
	if os.clock() > toastT then hToast.Text = "" end
	if not R or not R.P then return end
	hSpeed.Text = math.floor(R.v * 3.6 + 0.5) .. " km/h"
	barFill.Size = UDim2.new(math.clamp(R.rpm / R.P.lim, 0, 1), 0, 1, 0)
	local ti = Engine.tinfo(R.mop, R.thermal[R.mop.id])
	local lines = {}
	if R.crash then table.insert(lines, "<font color=\"#ff6a4a\"><b>VURPA</b></font> – " .. R.crash.why .. " · R = tillbaka till garaget")
	elseif not R.on then table.insert(lines, "<font color=\"#ff6a4a\"><b>Motorn är av</b></font> · tryck K") end
	if R.wh then
		local est, mult = R.whValue(R.wh)
		table.insert(lines, string.format("<font color=\"#ffd166\"><b>STEGRING %.1f s</b></font> · %d° · ×%.2f · ≈ +%d kr%s", R.wh.t, math.floor(math.deg(R.pitch)), mult or 0, est or 0, R.v < Config.WHEELIE.minV and " · för låg fart" or ""))
	end
	if R.on then table.insert(lines, math.floor(R.rpm) .. " rpm" .. (R.mop.cvt and "" or (" · växel " .. R.gear))) end
	local hex = string.format("#%02x%02x%02x", math.floor(ti.col.R * 255), math.floor(ti.col.G * 255), math.floor(ti.col.B * 255))
	table.insert(lines, string.format("%s <b>%d°C</b> <font color=\"%s\">%s</font>", ti.lab, math.floor(ti.v + 0.5), hex, ti.band))
	if R.t60 then table.insert(lines, string.format("0–60 km/h: %.2f s", R.t60)) end
	hInfo.Text = table.concat(lines, "\n")
	tip.Text = R.seated and "W gas · S broms · A/D styr · Shift stegring · K starta · X stäng av · Q/E växla (DT) · R garaget · Mellanslag kliv av"
		or "Åk ut = sätt dig på mopeden · G panel · B butik · K starta motorn"
	if R.seated and panel.Visible and R.v > 1 then panel.Visible = false end
	-- the temperature in the panel is updated twice per second
	if tab == "garage" and panel.Visible and not UIS:GetFocusedTextBox() and os.clock() - lastPanel > 0.5 then lastPanel = os.clock(); render() end
end)

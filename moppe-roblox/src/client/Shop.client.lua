-- The computer in the garage: the web shop Moppelagret.se (made-up shop, game money).
-- Start page, search, categories, product images (3D), stock status, cart, delivery time and order history.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Shared = RS:WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.Catalog)
local Builder = require(Shared.Builder)
local Delivery = require(Shared.Delivery)
local CS = require(Shared.ClientState)
local Api = RS:WaitForChild("Remotes"):WaitForChild("Api")
local plr = Players.LocalPlayer
local COL = { bg = Color3.fromRGB(242, 244, 247), card = Color3.fromRGB(255, 255, 255), line = Color3.fromRGB(222, 226, 232), tx = Color3.fromRGB(28, 32, 38), mu = Color3.fromRGB(110, 118, 130),
	blue = Color3.fromRGB(26, 108, 220), green = Color3.fromRGB(40, 160, 80), orange = Color3.fromRGB(230, 140, 20), top = Color3.fromRGB(20, 26, 36) }

local function new(class, props, parent) local o = Instance.new(class); for k, v in pairs(props) do o[k] = v end; o.Parent = parent; return o end
local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o); return o end
local function pad(o, n) new("UIPadding", { PaddingLeft = UDim.new(0, n), PaddingRight = UDim.new(0, n), PaddingTop = UDim.new(0, n), PaddingBottom = UDim.new(0, n) }, o) end
local function txt(parent, t, size, color, bold, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = t, TextSize = size or 14, TextColor3 = color or COL.tx, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, RichText = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, parent)
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end
local function button(parent, t, color, cb, w)
	local b = corner(new("TextButton", { Text = t, TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = color or COL.blue, Size = UDim2.new(w or 1, 0, 0, 32), AutoButtonColor = true }, parent))
	b.MouseButton1Click:Connect(cb)
	return b
end
local function kr(n) return Catalog.fmt(n) .. " kr" end
local function call(a, ...) local ok, msg = Api:InvokeServer(a, ...); if type(msg) == "string" then CS.toast:Fire(msg) end; return ok, msg end

local gui = new("ScreenGui", { Name = "Shop", ResetOnSpawn = false, Enabled = false, IgnoreGuiInset = true, DisplayOrder = 5 }, plr:WaitForChild("PlayerGui"))
local win = corner(new("Frame", { BackgroundColor3 = COL.bg, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.94, 0, 0.9, 0) }, gui), 10)
-- browser bar
local bar = new("Frame", { BackgroundColor3 = Color3.fromRGB(225, 229, 235), Size = UDim2.new(1, 0, 0, 30) }, win); corner(bar, 10)
txt(bar, "  ●  ●  ●     🔒 https://moppelagret.se", 13, COL.mu, false, { Position = UDim2.new(0, 8, 0, 7), Size = UDim2.new(1, -60, 0, 16) })
local close = button(bar, "✕", Color3.fromRGB(200, 60, 50), function() gui.Enabled = false; CS.setMode(nil); CS.modeEnded:Fire() end); close.Size = UDim2.new(0, 34, 0, 24); close.Position = UDim2.new(1, -40, 0, 3)
-- site header
local head = new("Frame", { BackgroundColor3 = COL.top, Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0, 56) }, win)
txt(head, "<b>MOPPELAGRET</b><font color=\"#ffb020\">.se</font>", 22, Color3.new(1, 1, 1), true, { Position = UDim2.new(0, 16, 0, 14), Size = UDim2.new(0, 220, 0, 28) })
local search = corner(new("TextBox", { PlaceholderText = "Sök efter produkter …", Text = "", TextSize = 15, Font = Enum.Font.Gotham, TextColor3 = COL.tx, BackgroundColor3 = Color3.new(1, 1, 1),
	Position = UDim2.new(0, 250, 0, 12), Size = UDim2.new(1, -560, 0, 32), ClearTextOnFocus = false }, head), 16)
local fitBtn = corner(new("TextButton", { Text = "", TextSize = 13, Font = Enum.Font.GothamMedium, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(50, 60, 76),
	Position = UDim2.new(1, -300, 0, 12), Size = UDim2.new(0, 160, 0, 32) }, head))
local cartBtn = corner(new("TextButton", { Text = "Kundvagn (0)", TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = COL.top, BackgroundColor3 = Color3.fromRGB(255, 176, 32),
	Position = UDim2.new(1, -130, 0, 12), Size = UDim2.new(0, 116, 0, 32) }, head))
-- left: categories
local left = new("ScrollingFrame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 86), Size = UDim2.new(0, 190, 1, -86), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4 }, win)
pad(left, 10); new("UIListLayout", { Padding = UDim.new(0, 2) }, left) -- the layouts are created once; clear() only removes GUI objects
-- centre: content, right: cart
local content = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.new(0, 200, 0, 96), Size = UDim2.new(1, -500, 1, -106), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6 }, win)
new("UIGridLayout", { CellSize = UDim2.new(0, 178, 0, 250), CellPadding = UDim2.new(0, 10, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, content)
local side = corner(new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.new(1, -290, 0, 96), Size = UDim2.new(0, 280, 1, -106) }, win), 8)
pad(side, 12); new("UIListLayout", { Padding = UDim.new(0, 6) }, side)
local modal = corner(new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 560, 0, 380), Visible = false, ZIndex = 10 }, win), 10)
pad(modal, 16)

local state = { cat = "Start", onlyMine = true, cart = {}, tab = "cart", filter = nil }
local function profile() return CS.profile end
local function mine() return profile() and profile().cur end

local function preview(parent, sku, h)
	local vp = corner(new("ViewportFrame", { BackgroundColor3 = Color3.fromRGB(236, 239, 243), Size = UDim2.new(1, 0, 0, h or 110), Ambient = Color3.fromRGB(160, 160, 170), LightDirection = Vector3.new(-1, -1.4, -0.7) }, parent), 6)
	local m = Builder.item(sku, { paint = { col = "#c8102e", fin = "gloss", q = 1 } })
	m.Parent = vp
	local c = new("Camera", { FieldOfView = 30 }, vp)
	vp.CurrentCamera = c
	local cf, size = m:GetBoundingBox()
	local r = math.max(0.3, size.Magnitude / 2)
	c.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0.55, 0.42, 0.72).Unit * (r / math.sin(math.rad(15)) * 1.05), cf.Position)
	return vp
end
local function stockColor(s) return s == "I lager" and COL.green or s == "Få kvar" and COL.orange or COL.mu end
local function cartCount() local n = 0; for _, l in ipairs(state.cart) do n = n + l.q end; return n end
local function addCart(sku, q)
	for _, l in ipairs(state.cart) do if l.sku == sku then l.q = math.min(10, l.q + (q or 1)); CS.toast:Fire("Lagd i kundvagnen"); return end end
	table.insert(state.cart, { sku = sku, q = q or 1 })
	CS.toast:Fire("Lagd i kundvagnen")
end

local renderSide, renderContent
local function clear(f) for _, c in ipairs(f:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end end

local function showProduct(pr)
	clear(modal); modal.Visible = true
	local vp = preview(modal, pr.sku, 220); vp.Size = UDim2.new(0, 230, 0, 230); vp.ZIndex = 11
	local info = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 246, 0, 0), Size = UDim2.new(1, -246, 1, 0), ZIndex = 11 }, modal)
	new("UIListLayout", { Padding = UDim.new(0, 6) }, info)
	txt(info, "<b>" .. pr.name .. "</b>", 19, COL.tx).ZIndex = 11
	txt(info, pr.man .. " · " .. pr.cat .. " · art.nr " .. pr.sku, 12, COL.mu).ZIndex = 11
	txt(info, "<b>" .. kr(pr.price) .. "</b>", 22, COL.tx).ZIndex = 11
	txt(info, "● " .. pr.stock .. (pr.stock == "Beställningsvara" and " (+2 min leverans)" or ""), 13, stockColor(pr.stock)).ZIndex = 11
	txt(info, pr.desc ~= "" and pr.desc or "–", 14, COL.tx).ZIndex = 11
	local fits = {}
	for _, m in ipairs(Config.MOPEDS) do if Catalog.fits(pr, m.id) then table.insert(fits, m.n) end end
	txt(info, "Passar: " .. table.concat(fits, ", "), 13, COL.mu).ZIndex = 11
	local q = 1
	local qrow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), ZIndex = 11 }, info)
	local ql = txt(qrow, "Antal: 1", 15, COL.tx, true, { Size = UDim2.new(0, 90, 0, 32), AutomaticSize = Enum.AutomaticSize.None, ZIndex = 11 })
	local minus = button(qrow, "−", COL.mu, function() q = math.max(1, q - 1); ql.Text = "Antal: " .. q end)
	minus.Size, minus.Position, minus.ZIndex = UDim2.new(0, 32, 0, 30), UDim2.new(0, 96, 0, 0), 11
	local plus = button(qrow, "+", COL.mu, function() q = math.min(10, q + 1); ql.Text = "Antal: " .. q end)
	plus.Size, plus.Position, plus.ZIndex = UDim2.new(0, 32, 0, 30), UDim2.new(0, 132, 0, 0), 11
	button(info, "Lägg i kundvagn", COL.blue, function() addCart(pr.sku, q); modal.Visible = false; renderSide() end).ZIndex = 11
	button(info, "Stäng", COL.mu, function() modal.Visible = false end).ZIndex = 11
end

local function productCard(parent, pr, order)
	local card = corner(new("Frame", { BackgroundColor3 = COL.card, LayoutOrder = order }, parent), 8)
	pad(card, 8); new("UIListLayout", { Padding = UDim.new(0, 3) }, card)
	preview(card, pr.sku, 104)
	local name = new("TextButton", { BackgroundTransparency = 1, Text = pr.name, TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = COL.tx, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 34) }, card)
	name.MouseButton1Click:Connect(function() showProduct(pr) end)
	txt(card, pr.man, 11, COL.mu)
	txt(card, "<b>" .. kr(pr.price) .. "</b>  <font color=\"#" .. stockColor(pr.stock):ToHex() .. "\" size=\"11\">● " .. pr.stock .. "</font>", 15, COL.tx)
	button(card, "Köp", COL.blue, function() addCart(pr.sku, 1); renderSide() end)
end

local function matches(pr)
	if pr.price <= 0 then return false end
	if state.onlyMine and mine() and not Catalog.fits(pr, mine()) then return false end
	if state.filter then
		if state.filter.kind and pr.kind ~= state.filter.kind then return false end
		if state.filter.panel and pr.val.panel ~= state.filter.panel then return false end
	elseif state.cat ~= "Start" and state.cat ~= "Sök" and pr.cat ~= state.cat then return false end
	local q = string.lower(search.Text)
	if q ~= "" then for w in q:gmatch("%S+") do if not (string.lower(pr.name):find(w, 1, true) or string.lower(pr.man):find(w, 1, true) or string.lower(pr.cat):find(w, 1, true)) then return false end end end
	return true
end

function renderContent()
	clear(content)
	if state.cat == "Start" and search.Text == "" and not state.filter then
		local hero = corner(new("Frame", { BackgroundColor3 = COL.top, LayoutOrder = 0 }, content), 8)
		pad(hero, 12)
		txt(hero, "<b>Allt för din moppe</b>", 17, Color3.new(1, 1, 1))
		txt(hero, "Snabb leverans till garaget. Små order ~1 min, stora ~10 min.", 12, Color3.fromRGB(200, 208, 220))
	end
	local n = 0
	for _, pr in ipairs(Catalog.PR) do
		if matches(pr) and (state.cat ~= "Start" or search.Text ~= "" or state.filter or n < 12) then n = n + 1; productCard(content, pr, n) end
	end
	if n == 0 then txt(content, "Inga produkter hittades.", 15, COL.mu) end
end

function renderSide()
	clear(side)
	cartBtn.Text = "Kundvagn (" .. cartCount() .. ")"
	local tabs = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30) }, side)
	local b1 = button(tabs, "Din beställning", state.tab == "cart" and COL.blue or COL.mu, function() state.tab = "cart"; renderSide() end); b1.Size = UDim2.new(0.5, -3, 0, 28)
	local b2 = button(tabs, "Mina ordrar", state.tab == "orders" and COL.blue or COL.mu, function() state.tab = "orders"; renderSide() end); b2.Size = UDim2.new(0.5, -3, 0, 28); b2.Position = UDim2.new(0.5, 3, 0, 0)
	local p = profile()
	if state.tab == "cart" then
		local tot = 0
		if #state.cart == 0 then txt(side, "Kundvagnen är tom.", 14, COL.mu) end
		for i, l in ipairs(state.cart) do
			local pr = Catalog.BY_SKU[l.sku]
			tot = tot + pr.price * l.q
			local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40) }, side)
			txt(row, pr.name .. "<br/><font color=\"#6e7682\">" .. l.q .. " st × " .. kr(pr.price) .. "</font>", 12, COL.tx, false, { Size = UDim2.new(1, -60, 0, 40), AutomaticSize = Enum.AutomaticSize.None })
			local x = button(row, "✕", Color3.fromRGB(200, 60, 50), function() table.remove(state.cart, i); renderSide() end); x.Size = UDim2.new(0, 28, 0, 26); x.Position = UDim2.new(1, -28, 0, 6)
		end
		txt(side, "<b>Totalt: " .. kr(tot) .. "</b>", 16, COL.tx)
		if p then txt(side, "Ditt saldo: " .. kr(p.money), 13, tot > p.money and Color3.fromRGB(200, 60, 50) or COL.mu) end
		if #state.cart > 0 then
			local secs = Delivery.seconds(state.cart)
			txt(side, "Leverans: ca " .. (secs < 120 and "1 min" or math.floor(secs / 60 + 0.5) .. " min"), 13, COL.mu)
			button(side, "Beställ", COL.green, function()
				local ok = call("order", state.cart)
				if ok then state.cart = {}; state.tab = "orders" end
				renderSide()
			end)
		end
	else
		local any = false
		for _, o in ipairs(p and p.orders or {}) do
			any = true
			local box = corner(new("Frame", { BackgroundColor3 = COL.bg, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, side), 6)
			pad(box, 8); new("UIListLayout", { Padding = UDim.new(0, 3) }, box)
			local n = 0
			for _, l in ipairs(o.lines) do n = n + l.q end
			txt(box, "<b>Order " .. o.id .. "</b> · " .. n .. " delar · " .. kr(o.total), 13, COL.tx)
			if o.state == "transit" then
				local left_ = math.max(0, o.eta - workspace:GetServerTimeNow())
				txt(box, string.format("På väg – %d:%02d kvar", math.floor(left_ / 60), math.floor(left_ % 60)), 12, COL.orange)
				local barBg = corner(new("Frame", { BackgroundColor3 = COL.line, Size = UDim2.new(1, 0, 0, 6) }, box), 3)
				corner(new("Frame", { BackgroundColor3 = COL.orange, Size = UDim2.new(math.clamp(1 - left_ / math.max(1, o.eta - o.t0), 0, 1), 0, 1, 0) }, barBg), 3)
			elseif o.state == "arrived" then txt(box, "Levererad – paketet står vid garageporten", 12, COL.green)
			else txt(box, "Uppackad", 12, COL.mu) end
		end
		if not any then txt(side, "Inga beställningar än.", 14, COL.mu) end
	end
end

local function renderLeft()
	clear(left)
	for _, c in ipairs({ "Start", table.unpack(Catalog.CATS) }) do
		local b = new("TextButton", { Text = (c == "Start" and "Startsida" or c), TextSize = 14, Font = state.cat == c and Enum.Font.GothamBold or Enum.Font.Gotham, BackgroundTransparency = state.cat == c and 0 or 1,
			BackgroundColor3 = Color3.fromRGB(230, 238, 252), TextColor3 = state.cat == c and COL.blue or COL.tx, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 28) }, left)
		corner(b, 4)
		b.MouseButton1Click:Connect(function() state.cat, state.filter = c, nil; renderLeft(); renderContent() end)
	end
end
local function renderFit() fitBtn.Text = state.onlyMine and ("Bara till " .. (mine() and Config.BY_ID[mine()].n or "min moppe")) or "Alla modeller" end
fitBtn.MouseButton1Click:Connect(function() state.onlyMine = not state.onlyMine; renderFit(); renderContent() end)
cartBtn.MouseButton1Click:Connect(function() state.tab = "cart"; renderSide() end)
search:GetPropertyChangedSignal("Text"):Connect(function() if gui.Enabled then renderContent() end end)

CS.openShop.Event:Connect(function(filter)
	if CS.mode and CS.mode ~= "shop" then return end
	CS.setMode("shop")
	state.filter = filter
	if filter then state.cat = "Sök" end
	gui.Enabled = true
	renderLeft(); renderFit(); renderContent(); renderSide()
end)
CS.changed.Event:Connect(function() if gui.Enabled then renderSide() end end)
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc = acc + dt
	if gui.Enabled and state.tab == "orders" and acc > 1 then acc = 0; renderSide() end
end)
UIS.InputBegan:Connect(function(io, gp) if not gp and io.KeyCode == Enum.KeyCode.Escape and gui.Enabled then gui.Enabled = false; CS.setMode(nil); CS.modeEnded:Fire() end end)

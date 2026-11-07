-- Moppelagret.se on the garage computer: start page, search, categories, product pictures and pages, stock,
-- cart, orders with delivery countdown, and the job board (Uppdrag).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = RS:WaitForChild("Shared")
local Parts = require(Shared.Parts)
local Models = require(Shared.Models)
local Profile = require(Shared.Profile)
local GarageBuilder = require(Shared.GarageBuilder)
local plr = Players.LocalPlayer
local S = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UIKit"))

local gui = UI.screen("Butik", 12, plr)
gui.Enabled = false
local W = { tab = "butik", cat = nil, search = "", product = nil, cart = {} }

local site = UI.new("Frame", { Size = UDim2.fromOffset(1180, 600), Position = UDim2.new(0.5, 0, 0.5, 4), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(242, 244, 247), BorderSizePixel = 0, Name = "Webbplats" }, gui)
UI.corner(site, 12)
local DARK = Color3.fromRGB(28, 32, 40)
local MUTED = Color3.fromRGB(110, 116, 128)
local WHITE = Color3.fromRGB(255, 255, 255)
local BLUE = UI.C.accent

-- top bar
local bar = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = WHITE, BorderSizePixel = 0, Name = "Toppmeny" }, site)
UI.corner(bar, 12)
UI.new("Frame", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(16, 13), BackgroundColor3 = BLUE, BorderSizePixel = 0, Name = "Logga" }, bar)
UI.text(bar.Logga, "M", UDim2.fromScale(1, 1), nil, { font = UI.BLACK, ts = 22, xa = Enum.TextXAlignment.Center })
UI.corner(bar.Logga, 6)
UI.text(bar, "Moppelagret.se", UDim2.fromOffset(200, 60), UDim2.fromOffset(58, 0), { font = UI.BLACK, ts = 22, color = DARK, name = "Namn" })
local search = UI.new("TextBox", { Size = UDim2.fromOffset(330, 36), Position = UDim2.fromOffset(250, 12), BackgroundColor3 = Color3.fromRGB(236, 238, 242), Text = "", PlaceholderText = "Sök efter produkter...", TextColor3 = DARK, PlaceholderColor3 = MUTED, Font = UI.FONT, TextSize = 15, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Name = "Sök" }, bar)
UI.corner(search, 8)
UI.pad(search, 12, 8, 0, 0)
local tabBar = UI.new("Frame", { Size = UDim2.fromOffset(420, 36), Position = UDim2.fromOffset(600, 12), BackgroundTransparency = 1, Name = "Flikar" }, bar)
UI.list(tabBar, 6, true)
UI.button(bar, "X", UDim2.fromOffset(36, 36), UDim2.new(1, -48, 0, 12), { kind = "secondary", name = "Stäng" }, function() S.endMode("shop") end)

local left = UI.new("Frame", { Size = UDim2.fromOffset(170, 520), Position = UDim2.fromOffset(16, 72), BackgroundTransparency = 1, Name = "Kategorier" }, site)
UI.list(left, 2)
local main = UI.new("Frame", { Size = UDim2.fromOffset(700, 520), Position = UDim2.fromOffset(192, 72), BackgroundTransparency = 1, Name = "Mitt" }, site)
local cartPanel = UI.new("Frame", { Size = UDim2.fromOffset(268, 516), Position = UDim2.new(1, -284, 0, 72), BackgroundColor3 = WHITE, BorderSizePixel = 0, Name = "Kundvagn" }, site)
UI.corner(cartPanel, 10)

local function stockText(sku)
	local n = S.meta.stock and S.meta.stock[sku] or (Parts.get(sku).stock)
	if n > 5 then return "I lager", UI.C.green end
	if n > 0 then return "Få kvar (" .. n .. " st)", UI.C.orange end
	return "Beställningsvara (+2 min)", UI.C.red
end
local function cartCount() local n = 0; for _, l in ipairs(W.cart) do n = n + l.qty end return n end
local function addToCart(sku, qty)
	for _, l in ipairs(W.cart) do if l.sku == sku then l.qty = math.min(10, l.qty + (qty or 1)); W.refresh(); return end end
	W.cart[#W.cart + 1] = { sku = sku, qty = qty or 1 }
	S.toast(Parts.get(sku).name .. " ligger i kundvagnen", "ok")
	W.refresh()
end
local function card(parent, part, order)
	local c = UI.new("Frame", { Size = UDim2.fromOffset(164, 236), BackgroundColor3 = WHITE, BorderSizePixel = 0, LayoutOrder = order, Name = part.sku }, parent)
	UI.corner(c, 10)
	local img = UI.viewport(c, Models.item(part.sku), UDim2.fromOffset(148, 110), UDim2.fromOffset(8, 8), { bg = Color3.fromRGB(246, 247, 249) })
	local open = UI.new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Name = "Öppna" }, img)
	open.Activated:Connect(function() W.product = part.sku; W.refresh() end)
	UI.text(c, part.brand, UDim2.fromOffset(148, 16), UDim2.fromOffset(10, 122), { ts = 12, color = MUTED })
	UI.text(c, part.name, UDim2.fromOffset(148, 36), UDim2.fromOffset(10, 138), { ts = 14, font = UI.BOLD, color = DARK, wrap = true, ya = Enum.TextYAlignment.Top })
	local st, col = stockText(part.sku)
	UI.text(c, st, UDim2.fromOffset(148, 14), UDim2.fromOffset(10, 176), { ts = 11, color = col })
	UI.text(c, part.price == 0 and "Ingår" or UI.kr(part.price), UDim2.fromOffset(90, 30), UDim2.fromOffset(10, 196), { ts = 16, font = UI.BOLD, color = DARK })
	if part.price > 0 then UI.button(c, "Köp", UDim2.fromOffset(60, 28), UDim2.fromOffset(96, 198), { kind = "primary", ts = 14 }, function() addToCart(part.sku) end) end
	return c
end
local function matches(part)
	if W.cat and Parts.KINDS[part.kind].cat ~= W.cat then return false end
	local q = W.search:lower()
	if q ~= "" then
		local hay = (part.name .. " " .. part.brand .. " " .. Parts.KINDS[part.kind].n .. " " .. Parts.KINDS[part.kind].cat):lower()
		for word in q:gmatch("%S+") do if not hay:find(word, 1, true) then return false end end
	end
	return true
end

local function buildShop()
	UI.clear(left)
	UI.text(left, "Kategorier", UDim2.new(1, 0, 0, 26), nil, { ts = 13, font = UI.BOLD, color = MUTED, order = 0 })
	local cats = { { nil, "Startsida" } }
	for _, c in ipairs(Parts.CATEGORIES) do cats[#cats + 1] = { c, c } end
	for i, c in ipairs(cats) do
		local b = UI.button(left, c[2], UDim2.new(1, 0, 0, 30), nil, { kind = "ghost", xa = Enum.TextXAlignment.Left, ts = 14, order = i, font = W.cat == c[1] and UI.BOLD or UI.FONT, name = c[2] }, function()
			W.cat, W.product, W.search = c[1], nil, ""
			search.Text = ""
			W.refresh()
		end)
		b.BackgroundColor3 = W.cat == c[1] and Color3.fromRGB(220, 232, 250) or Color3.fromRGB(242, 244, 247)
		b.TextColor3 = W.cat == c[1] and BLUE or DARK
	end
	UI.clear(main)
	if W.product then
		local part = Parts.get(W.product)
		local page = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Name = "Produktsida" }, main)
		UI.corner(page, 10)
		UI.button(page, "< Tillbaka", UDim2.fromOffset(110, 30), UDim2.fromOffset(14, 12), { kind = "secondary", ts = 14 }, function() W.product = nil; W.refresh() end)
		UI.viewport(page, Models.item(part.sku), UDim2.fromOffset(320, 300), UDim2.fromOffset(16, 56), { bg = Color3.fromRGB(246, 247, 249) })
		UI.text(page, part.brand .. " · " .. Parts.KINDS[part.kind].cat, UDim2.fromOffset(340, 20), UDim2.fromOffset(356, 56), { ts = 14, color = MUTED })
		UI.text(page, part.name, UDim2.fromOffset(340, 60), UDim2.fromOffset(356, 78), { ts = 24, font = UI.BOLD, color = DARK, wrap = true, ya = Enum.TextYAlignment.Top })
		UI.text(page, UI.kr(part.price), UDim2.fromOffset(200, 36), UDim2.fromOffset(356, 140), { ts = 26, font = UI.BLACK, color = UI.C.green })
		local st, col = stockText(part.sku)
		UI.text(page, st, UDim2.fromOffset(300, 20), UDim2.fromOffset(356, 178), { ts = 14, font = UI.BOLD, color = col })
		UI.text(page, part.desc, UDim2.fromOffset(330, 70), UDim2.fromOffset(356, 204), { ts = 14, color = DARK, wrap = true, ya = Enum.TextYAlignment.Top })
		-- specs from the stats
		local specs = {}
		local s = part.stats
		if s.cc then specs[#specs + 1] = string.format("Slagvolym %.0f cc, borrning %s mm", s.cc, tostring(s.bore)) end
		if s.bore and not s.cc then specs[#specs + 1] = "Diameter " .. tostring(s.bore) .. " mm" end
		if s.mm then specs[#specs + 1] = "Spjäll " .. tostring(s.mm) .. " mm" end
		if s.gram then specs[#specs + 1] = "Rullvikt " .. tostring(s.gram) .. " g" end
		if s.engage then specs[#specs + 1] = "Inkoppling " .. s.engage .. " rpm" end
		if s.limit then specs[#specs + 1] = s.limit >= 12000 and "Ingen varvspärr" or ("Varvspärr " .. s.limit .. " rpm") end
		if s.stroke then specs[#specs + 1] = "Slaglängd " .. tostring(s.stroke) .. " mm" end
		if s.fits then specs[#specs + 1] = "Passar " .. (require(Shared.MopedDef).MODELS[s.fits].n) end
		if s.range then specs[#specs + 1] = "Värmetal " .. s.range end
		if s.lvl then specs[#specs + 1] = "Nivå: " .. ({ [0] = "Original", [1] = "Sport", [2] = "Racing", [3] = "Racing+" })[s.lvl] end
		UI.text(page, table.concat(specs, "\n"), UDim2.fromOffset(330, 100), UDim2.fromOffset(356, 280), { ts = 13, color = MUTED, wrap = true, ya = Enum.TextYAlignment.Top })
		if part.price > 0 then UI.button(page, "Lägg i varukorg", UDim2.fromOffset(180, 42), UDim2.fromOffset(356, 400), { kind = "green", ts = 16 }, function() addToCart(part.sku) end) end
		return
	end
	local list = UI.scroll(main, UDim2.fromScale(1, 1), nil, { name = "Produkter" })
	UI.grid(list, UDim2.fromOffset(164, 236), UDim2.fromOffset(10, 10))
	local order = 0
	if not W.cat and W.search == "" then
		local banner = UI.new("Frame", { Size = UDim2.fromOffset(164, 236), BackgroundColor3 = BLUE, BorderSizePixel = 0, LayoutOrder = 0, Name = "Erbjudande" }, list)
		UI.corner(banner, 10)
		UI.text(banner, "Trimma din moppe", UDim2.new(1, -20, 0, 60), UDim2.fromOffset(10, 12), { font = UI.BLACK, ts = 20, wrap = true, ya = Enum.TextYAlignment.Top })
		UI.text(banner, "Cylinderkit, förgasare och avgassystem. Fri frakt över 2 000 kr.\n\nLeverans: 1 del ca 1 min, 3–6 delar 3–5 min, större order ca 10 min.", UDim2.new(1, -20, 0, 150), UDim2.fromOffset(10, 76), { ts = 13, wrap = true, ya = Enum.TextYAlignment.Top })
	end
	local FEATURED = { cylinder_nordtrim70 = 1, cylinder_fartek70 = 1, forgasare_gs19 = 1, avgas_fartek = 1, variator_nordtrim = 1, koppling_nordtrim = 1, cdi_snabbo = 1, luftfilter_fartek = 1, reed_fartek = 1, vevaxel_fartek = 1, verktyg_slippro = 1 }
	for _, part in ipairs(Parts.LIST) do
		if matches(part) and (W.cat or W.search ~= "" or FEATURED[part.sku]) then
			order = order + 1
			card(list, part, order)
		end
	end
	if order == 0 then UI.text(list, "Inga träffar.", UDim2.fromOffset(300, 40), nil, { ts = 16, color = MUTED }) end
end

local function buildCart()
	UI.clear(cartPanel)
	UI.pad(cartPanel, 12)
	UI.text(cartPanel, "Din beställning", UDim2.new(1, 0, 0, 26), nil, { font = UI.BOLD, ts = 17, color = DARK })
	local lines = UI.scroll(cartPanel, UDim2.new(1, 0, 0, 250), UDim2.fromOffset(0, 32), { name = "Rader" })
	UI.list(lines, 4)
	local sum = 0
	for i, l in ipairs(W.cart) do
		local part = Parts.get(l.sku)
		sum = sum + part.price * l.qty
		local r = UI.new("Frame", { Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = Color3.fromRGB(246, 247, 249), BorderSizePixel = 0, LayoutOrder = i, Name = l.sku }, lines)
		UI.corner(r, 6)
		UI.text(r, part.name, UDim2.new(1, -90, 0, 20), UDim2.fromOffset(8, 3), { ts = 12, color = DARK, truncate = true })
		UI.text(r, l.qty .. " st · " .. UI.kr(part.price * l.qty), UDim2.new(1, -90, 0, 18), UDim2.fromOffset(8, 23), { ts = 12, color = MUTED })
		UI.button(r, "−", UDim2.fromOffset(24, 24), UDim2.new(1, -82, 0, 11), { kind = "secondary", ts = 14 }, function() l.qty = l.qty - 1; if l.qty <= 0 then table.remove(W.cart, i) end W.refresh() end)
		UI.button(r, "+", UDim2.fromOffset(24, 24), UDim2.new(1, -54, 0, 11), { kind = "secondary", ts = 14 }, function() l.qty = math.min(10, l.qty + 1); W.refresh() end)
		UI.button(r, "X", UDim2.fromOffset(22, 24), UDim2.new(1, -26, 0, 11), { kind = "danger", ts = 12 }, function() table.remove(W.cart, i); W.refresh() end)
	end
	if #W.cart == 0 then UI.text(lines, "Kundvagnen är tom.", UDim2.new(1, 0, 0, 30), nil, { ts = 13, color = MUTED }) end
	local freight = (sum >= 2000 or sum == 0) and 0 or 99
	local function row(y, a, b, bold, color)
		UI.text(cartPanel, a, UDim2.new(0.5, 0, 0, 22), UDim2.fromOffset(0, y), { ts = bold and 17 or 14, color = DARK, font = bold and UI.BOLD or UI.FONT })
		UI.text(cartPanel, b, UDim2.new(0.5, 0, 0, 22), UDim2.new(0.5, 0, 0, y), { ts = bold and 17 or 14, color = color or DARK, font = UI.BOLD, xa = Enum.TextXAlignment.Right })
	end
	row(292, "Delsumma", UI.kr(sum))
	row(316, "Frakt", freight == 0 and "0 kr" or UI.kr(freight))
	row(344, "Totalt", UI.kr(sum + freight), true, UI.C.red)
	local lines2 = {}
	local back = false
	for _, l in ipairs(W.cart) do
		lines2[#lines2 + 1] = { qty = l.qty }
		local n = S.meta.stock and S.meta.stock[l.sku] or 99
		if n < l.qty then back = true; lines2[#lines2].back = true end
	end
	local secs = #W.cart > 0 and Profile.deliverySeconds(lines2) or 0
	local okMoney = S.profile and S.profile.money >= sum + freight
	UI.button(cartPanel, "Beställ", UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 380), { kind = (#W.cart > 0 and okMoney) and "primary" or "secondary", ts = 18, name = "Beställ" }, function()
		if #W.cart == 0 then return end
		local cart = {}
		for _, l in ipairs(W.cart) do cart[#cart + 1] = { sku = l.sku, qty = l.qty } end
		local ok, o = S.api("order", cart)
		if ok then
			W.cart = {}
			S.toast("Tack för din beställning! Leverans om " .. UI.time(o.ready - S.now()) .. ".", "ok")
			W.tab = "ordrar"
			W.refresh()
		end
	end)
	UI.text(cartPanel, #W.cart > 0 and ("Beräknad leverans: " .. (secs <= 60 and "ca 1 min" or (secs <= 300 and string.format("ca %d min", math.ceil(secs / 60)) or string.format("ca %d min", math.ceil(secs / 60)))) .. (back and " (beställningsvara)" or "")) or "", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 430), { ts = 13, color = MUTED, xa = Enum.TextXAlignment.Center })
	if not okMoney and #W.cart > 0 then UI.text(cartPanel, "Du har inte råd med allt i kundvagnen.", UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 452), { ts = 13, color = UI.C.red, xa = Enum.TextXAlignment.Center }) end
end

local STATE = { vag = "På väg", framme = "Levererad – står vid garageporten", oppnad = "Öppnad", tom = "Uppackad" }
local countdowns = {}
local function buildOrders()
	UI.clear(left)
	UI.clear(main)
	countdowns = {}
	local list = UI.scroll(main, UDim2.fromScale(1, 1), nil, { name = "Ordrar" })
	UI.list(list, 8)
	local p = S.profile
	local n = 0
	for i = #p.orders, 1, -1 do
		local o = p.orders[i]
		n = n + 1
		local r = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 96), BackgroundColor3 = WHITE, BorderSizePixel = 0, LayoutOrder = n, Name = "Order" .. o.id }, list)
		UI.corner(r, 10)
		UI.text(r, "Order #" .. o.id .. " · " .. UI.kr(o.total), UDim2.new(0.6, 0, 0, 24), UDim2.fromOffset(14, 8), { ts = 16, font = UI.BOLD, color = DARK })
		local names = {}
		for _, l in ipairs(o.lines) do names[#names + 1] = l.qty .. " × " .. Parts.get(l.sku).name end
		UI.text(r, table.concat(names, ", "), UDim2.new(1, -28, 0, 36), UDim2.fromOffset(14, 32), { ts = 13, color = MUTED, wrap = true, ya = Enum.TextYAlignment.Top })
		local st = UI.text(r, STATE[o.state] or o.state, UDim2.new(0.4, -14, 0, 24), UDim2.new(0.6, 0, 0, 8), { ts = 14, font = UI.BOLD, color = o.state == "vag" and UI.C.orange or UI.C.green, xa = Enum.TextXAlignment.Right })
		if o.state == "vag" then
			local _, fill = UI.bar(r, UDim2.new(1, -28, 0, 8), UDim2.fromOffset(14, 76), 0, BLUE)
			countdowns[#countdowns + 1] = { o = o, label = st, fill = fill }
		end
	end
	if n == 0 then UI.text(list, "Du har inga ordrar än.", UDim2.fromOffset(300, 40), nil, { ts = 16, color = MUTED }) end
end
local function buildJobs()
	UI.clear(left)
	UI.clear(main)
	local p = S.profile
	local list = UI.scroll(main, UDim2.fromScale(1, 1), nil, { name = "Uppdrag" })
	UI.list(list, 8)
	UI.text(list, "Pågående uppdrag", UDim2.new(1, 0, 0, 26), nil, { ts = 16, font = UI.BOLD, color = DARK, order = 0 })
	for i, j in ipairs(p.jobs) do
		local r = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 70), BackgroundColor3 = Color3.fromRGB(255, 248, 225), BorderSizePixel = 0, LayoutOrder = i, Name = "Pågår" .. j.id }, list)
		UI.corner(r, 10)
		UI.text(r, j.n, UDim2.new(1, -240, 0, 24), UDim2.fromOffset(14, 8), { ts = 15, font = UI.BOLD, color = DARK, wrap = true })
		UI.text(r, "Betalning: " .. UI.kr(j.pay) .. (j.type == "bygg" and " + delarnas värde" or ""), UDim2.new(1, -240, 0, 20), UDim2.fromOffset(14, 38), { ts = 13, color = MUTED })
		if j.type ~= "leverans" then UI.button(r, "Lämna", UDim2.fromOffset(100, 32), UDim2.new(1, -218, 0, 19), { kind = "green", ts = 14 }, function() S.api("completeJob", j.id) end)
		else UI.text(r, "Kör till " .. require(Shared.Map).PLACES[j.dest].n, UDim2.fromOffset(200, 32), UDim2.new(1, -318, 0, 19), { ts = 13, color = DARK, xa = Enum.TextXAlignment.Right }) end
		UI.button(r, "Avbryt", UDim2.fromOffset(100, 32), UDim2.new(1, -110, 0, 19), { kind = "danger", ts = 14 }, function() S.api("cancelJob", j.id) end)
	end
	if #p.jobs == 0 then UI.text(list, "Inga just nu.", UDim2.new(1, 0, 0, 24), nil, { ts = 14, color = MUTED, order = 1 }) end
	UI.text(list, "Lediga uppdrag", UDim2.new(1, 0, 0, 30), nil, { ts = 16, font = UI.BOLD, color = DARK, order = 10 })
	for i, o in ipairs(Profile.offers(p)) do
		local r = UI.new("Frame", { Size = UDim2.new(1, -10, 0, 86), BackgroundColor3 = WHITE, BorderSizePixel = 0, LayoutOrder = 10 + i, Name = "Erbjudande" .. i }, list)
		UI.corner(r, 10)
		UI.text(r, o.n, UDim2.new(1, -160, 0, 24), UDim2.fromOffset(14, 8), { ts = 15, font = UI.BOLD, color = DARK })
		UI.text(r, o.about, UDim2.new(1, -160, 0, 34), UDim2.fromOffset(14, 32), { ts = 12, color = MUTED, wrap = true, ya = Enum.TextYAlignment.Top })
		UI.text(r, UI.kr(o.pay), UDim2.fromOffset(120, 24), UDim2.new(1, -134, 0, 8), { ts = 17, font = UI.BOLD, color = UI.C.green, xa = Enum.TextXAlignment.Right })
		UI.button(r, "Ta uppdraget", UDim2.fromOffset(120, 32), UDim2.new(1, -134, 0, 44), { kind = "primary", ts = 14 }, function() if S.api("acceptJob", o.key) then S.toast("Uppdrag accepterat", "ok") end end)
	end
end

function W.refresh()
	if not gui.Enabled or not S.profile then return end
	UI.clear(tabBar)
	for i, t in ipairs({ { "butik", "Butik" }, { "ordrar", "Mina ordrar" }, { "uppdrag", "Uppdrag" }, { "kundvagn", "Kundvagn (" .. cartCount() .. ")" } }) do
		UI.button(tabBar, t[2], UDim2.fromOffset(t[1] == "kundvagn" and 120 or 96, 36), nil, { kind = (W.tab == t[1]) and "primary" or "secondary", ts = 14, order = i, name = t[1] }, function()
			if t[1] == "kundvagn" then W.tab = "butik" else W.tab = t[1] end
			W.product = nil
			W.refresh()
		end)
	end
	if W.tab == "butik" then buildShop() elseif W.tab == "ordrar" then buildOrders() else buildJobs() end
	buildCart()
end
search:GetPropertyChangedSignal("Text"):Connect(function()
	if W.search == search.Text then return end
	W.search = search.Text
	W.product = nil
	if W.tab ~= "butik" then W.tab = "butik" end
	W.refresh()
end)

RunService.Heartbeat:Connect(function()
	if not gui.Enabled then return end
	for _, c in ipairs(countdowns) do
		local o = c.o
		local left2 = o.ready - S.now()
		c.label.Text = left2 > 0 and ("På väg · " .. UI.time(left2) .. " kvar") or "Levereras nu..."
		c.fill.Size = UDim2.fromScale(math.clamp(1 - left2 / math.max(1, o.ready - o.placed), 0, 1), 1)
	end
end)

local function open(tab)
	if not S.setMode("shop") then return end
	W.tab = tab or "butik"
	W.product = nil
	local cf = S.origin() * GarageBuilder.COMPUTER
	S.camTo(cf * CFrame.new(0, 0.2, -4.2) * CFrame.Angles(0, math.pi, 0), 50, 0.5)
	gui.Enabled = true
	W.refresh()
end
S.open.Event:Connect(function(what, atStation)
	if what == "shop" and atStation then open("butik")
	elseif what == "jobs" and atStation then open("uppdrag") end
end)
S.modeEv.Event:Connect(function(mode) if mode ~= "shop" then gui.Enabled = false end end)
S.changed.Event:Connect(function() if gui.Enabled then W.refresh() end end)

-- HUD: start menu, money, toasts and tips, the garage side menu with Moped Info, and the windows
-- "Min moppe" (status, tuning, mopeds, designs), "Statistik" and "Inställningar".
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Shared = RS:WaitForChild("Shared")
local MopedDef = require(Shared.MopedDef)
local Profile = require(Shared.Profile)
local Performance = require(Shared.Performance)
local Models = require(Shared.Models)
local Config = require(Shared.Config)
local plr = Players.LocalPlayer
local S = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UIKit"))

pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)

local gui = UI.screen("Hud", 5, plr)

---------------------------------------------------------------- money, toasts, tip
local money = UI.panel(gui, UDim2.fromOffset(196, 40), UDim2.new(1, -12, 0, 8), { anchor = Vector2.new(1, 0), name = "Pengar" })
local moneyText = UI.text(money, "", UDim2.new(1, -54, 1, 0), UDim2.fromOffset(14, 0), { font = UI.BOLD, ts = 20, xa = Enum.TextXAlignment.Right, name = "Belopp" })
UI.button(money, "+", UDim2.fromOffset(32, 32), UDim2.new(1, -36, 0, 4), { kind = "green", ts = 22, name = "Tjäna" }, function() S.open:Fire("jobs") end)

local toasts = UI.new("Frame", { Size = UDim2.fromOffset(460, 300), Position = UDim2.new(0.5, 0, 0, 54), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Name = "Notiser" }, gui)
UI.list(toasts, 6, false, Enum.HorizontalAlignment.Center)
local TOAST = { error = UI.C.red, money = UI.C.green, box = UI.C.orange, info = UI.C.accent, ok = UI.C.green }
S.toastEv.Event:Connect(function(text, kind)
	local t = UI.panel(toasts, UDim2.fromOffset(440, 40), nil, { name = "Notis" })
	t.AutomaticSize = Enum.AutomaticSize.Y
	UI.new("Frame", { Size = UDim2.new(0, 5, 1, -12), Position = UDim2.fromOffset(8, 6), BackgroundColor3 = TOAST[kind] or UI.C.accent, BorderSizePixel = 0 }, t)
	local l = UI.text(t, text, UDim2.new(1, -36, 0, 40), UDim2.fromOffset(22, 0), { ts = 15, wrap = true })
	l.AutomaticSize = Enum.AutomaticSize.Y
	task.delay(kind == "error" and 4 or 3.2, function() t:Destroy() end)
end)
local tip = UI.panel(gui, UDim2.fromOffset(560, 34), UDim2.new(0.5, 0, 1, -14), { anchor = Vector2.new(0.5, 1), name = "Tips", transp = 0.25, visible = false })
local tipText = UI.text(tip, "", UDim2.fromScale(1, 1), nil, { ts = 14, xa = Enum.TextXAlignment.Center, color = UI.C.text })
S.tipEv.Event:Connect(function(text)
	tip.Visible = text ~= nil and text ~= "" and S.settings.tips and not S.mode
	tipText.Text = text or ""
end)
-- work modes have their own hints at the bottom
S.modeEv.Event:Connect(function(mode) if mode then tip.Visible = false end end)

---------------------------------------------------------------- garage side menu and Moped Info
local side = UI.new("Frame", { Size = UDim2.fromOffset(196, 290), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Name = "Garagemeny" }, gui)
UI.list(side, 8)
local MENU = {
	{ "Bygg motor", "engine" }, { "Porta cylinder", "port" }, { "Beställ delar", "shop" }, { "Lackering", "studio" }, { "Min moppe", "moped" }, { "Kör ut", "ride" },
}
for i, m in ipairs(MENU) do
	local b = UI.button(side, m[1], UDim2.new(1, 0, 0, 40), nil, { kind = i == 6 and "primary" or "ghost", xa = Enum.TextXAlignment.Left, order = i, transp = i == 6 and 0 or 0.1, name = m[1] })
	if i ~= 6 then UI.stroke(b, UI.C.line, 1, 0.5) end
	b.Activated:Connect(function() S.open:Fire(m[2]) end)
end
local info = UI.panel(gui, UDim2.fromOffset(250, 236), UDim2.new(1, -12, 0.5, 10), { anchor = Vector2.new(1, 0.5), name = "MopedInfo" })
UI.pad(info, 14, 14, 10, 10)
UI.list(info, 4)
local infoTitle = UI.text(info, "Moped Info", UDim2.new(1, 0, 0, 24), nil, { font = UI.BOLD, ts = 17, order = 0 })
local rows = {}
for i, k in ipairs({ { "hp", "Hästkrafter" }, { "top", "Toppfart" }, { "acc", "0–45 km/h" }, { "rpm", "Max effekt vid" }, { "temp", "Temperatur" }, { "status", "Motorstatus" } }) do
	local r = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = i, Name = k[1] }, info)
	UI.text(r, k[2] .. ":", UDim2.new(0.6, 0, 1, 0), nil, { ts = 14, color = UI.C.dim })
	rows[k[1]] = UI.text(r, "", UDim2.new(0.4, 0, 1, 0), UDim2.fromScale(0.6, 0), { ts = 14, font = UI.BOLD, xa = Enum.TextXAlignment.Right, name = "Värde" })
end
local powerBar = select(2, UI.bar(info, UDim2.new(1, 0, 0, 6), nil, 0, UI.C.green))
powerBar.Parent.LayoutOrder = 10
local speedBar = select(2, UI.bar(info, UDim2.new(1, 0, 0, 6), nil, 0, UI.C.accent2))
speedBar.Parent.LayoutOrder = 11

local function inGarage()
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if not root or not S.meta.plot then return false end
	local l = S.origin():PointToObjectSpace(root.Position)
	return math.abs(l.X) < 24 and math.abs(l.Z) < 17
end
local function updateInfo()
	local p = S.profile
	local m = S.moped()
	if not (p and m) then return end
	moneyText.Text = UI.kr(p.money)
	infoTitle.Text = MopedDef.MODELS[m.model].n
	local s = S.perf(m)
	if s then
		rows.hp.Text = string.format("%.1f hk", s.hp)
		rows.top.Text = string.format("%d km/h", math.floor(s.top + 0.5))
		rows.acc.Text = s.t45 and string.format("%.1f s", s.t45) or "–"
		rows.rpm.Text = string.format("%d rpm", s.rpm)
		rows.temp.Text = string.format("%d °C", math.floor(s.temp + 0.5))
		rows.temp.TextColor3 = s.temp > Performance.TEMP_WARN and UI.C.red or UI.C.text
		local probs = Profile.mopedProblems(p, m)
		rows.status.Text = #probs > 0 and "Ej körbar" or s.status
		rows.status.TextColor3 = #probs > 0 and UI.C.red or (s.status == "OK" and UI.C.green or UI.C.yellow)
		powerBar.Size = UDim2.fromScale(math.clamp(s.hp / 16, 0.03, 1), 1)
		speedBar.Size = UDim2.fromScale(math.clamp(s.top / 110, 0.03, 1), 1)
	else
		for _, k in ipairs({ "hp", "top", "acc", "rpm", "temp" }) do rows[k].Text = "–" end
		rows.status.Text = "Ingen motor"
		rows.status.TextColor3 = UI.C.red
	end
end
S.changed.Event:Connect(updateInfo)

---------------------------------------------------------------- windows
local win = UI.panel(gui, UDim2.fromOffset(760, 500), UDim2.fromScale(0.5, 0.5), { anchor = Vector2.new(0.5, 0.5), name = "Fönster", visible = false, z = 5 })
local winTitle
local body = UI.new("Frame", { Size = UDim2.new(1, -24, 1, -64), Position = UDim2.fromOffset(12, 52), BackgroundTransparency = 1, Name = "Innehåll" }, win)
local current
local function closeWin()
	win.Visible = false
	current = nil
end
local header = UI.header(win, "", closeWin)
winTitle = header.Titel
local function openWin(title, build)
	current = build
	winTitle.Text = title
	UI.clear(body)
	build(body)
	win.Visible = true
end
local function refreshWin() if win.Visible and current then UI.clear(body); current(body) end end
S.changed.Event:Connect(refreshWin)

-- Min moppe -------------------------------------------------------------
local mopedTab = "status"
local function tabs(parent, list, cur, onPick)
	local bar = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Name = "Flikar" }, parent)
	UI.list(bar, 6, true)
	for i, t in ipairs(list) do
		UI.button(bar, t[2], UDim2.fromOffset(130, 32), nil, { kind = t[1] == cur and "primary" or "secondary", order = i, ts = 15 }, function() onPick(t[1]) end)
	end
	return bar
end
local function buildMoped(b)
	local p = S.profile
	local m = S.moped()
	tabs(b, { { "status", "Status" }, { "mopeder", "Mopeder" }, { "designer", "Designer" } }, mopedTab, function(t) mopedTab = t; refreshWin() end)
	local area = UI.new("Frame", { Size = UDim2.new(1, 0, 1, -44), Position = UDim2.fromOffset(0, 44), BackgroundTransparency = 1, Name = "Flik" }, b)
	if mopedTab == "status" then
		local left = UI.new("Frame", { Size = UDim2.new(0.5, -8, 1, 0), BackgroundTransparency = 1 }, area)
		UI.list(left, 6)
		UI.text(left, MopedDef.MODELS[m.model].n, UDim2.new(1, 0, 0, 26), nil, { font = UI.BOLD, ts = 20, order = 1 })
		UI.text(left, string.format("Mätarställning: %.1f km", m.odo or 0), UDim2.new(1, 0, 0, 20), nil, { ts = 14, color = UI.C.dim, order = 2 })
		local probs = Profile.mopedProblems(p, m)
		if #probs == 0 then
			UI.text(left, "Redo att köra", UDim2.new(1, 0, 0, 22), nil, { ts = 16, font = UI.BOLD, color = UI.C.green, order = 3 })
		else
			UI.text(left, "Saknas innan du kan köra:", UDim2.new(1, 0, 0, 22), nil, { ts = 15, font = UI.BOLD, color = UI.C.red, order = 3 })
			for i, t in ipairs(probs) do UI.text(left, "• " .. t, UDim2.new(1, 0, 0, 20), nil, { ts = 14, order = 3 + i }) end
		end
		local mp = MopedDef.missingPanels(m)
		if #mp > 0 then UI.text(left, "Kåpor som saknas: " .. table.concat(mp, ", "), UDim2.new(1, 0, 0, 38), nil, { ts = 13, color = UI.C.dim, wrap = true, order = 30 }) end
		-- jetting
		local jet = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 40 }, left)
		UI.text(jet, "Munstycke (bränsle):", UDim2.new(0.5, 0, 1, 0), nil, { ts = 14 })
		local jt = ({ [-2] = "Mycket fett", [-1] = "Fett", [0] = "Normal", [1] = "Magert", [2] = "Mycket magert" })[m.jet or 0]
		UI.button(jet, "−", UDim2.fromOffset(32, 32), UDim2.new(0.5, 0, 0, 4), { kind = "secondary", name = "Fetare" }, function() S.api("setJet", (m.jet or 0) - 1) end)
		UI.text(jet, jt, UDim2.fromOffset(110, 40), UDim2.new(0.5, 36, 0, 0), { ts = 14, xa = Enum.TextXAlignment.Center, font = UI.BOLD })
		UI.button(jet, "+", UDim2.fromOffset(32, 32), UDim2.new(0.5, 150, 0, 4), { kind = "secondary", name = "Magrare" }, function() S.api("setJet", (m.jet or 0) + 1) end)
		UI.text(left, "Magrare ger lite mer effekt men mycket mer värme. Går motorn för varm skär kolven.", UDim2.new(1, 0, 0, 36), nil, { ts = 12, color = UI.C.dim, wrap = true, order = 41 })
		local actions = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 50 }, left)
		UI.list(actions, 8, true)
		UI.button(actions, "Kör ut", UDim2.fromOffset(120, 36), nil, { kind = "green", order = 1 }, function() closeWin(); S.open:Fire("ride") end)
		UI.button(actions, "Hämta hem mopeden", UDim2.fromOffset(190, 36), nil, { kind = "secondary", order = 2 }, function() S.api("home") end)
		-- stats
		local right = UI.panel(area, UDim2.new(0.5, -8, 1, 0), UDim2.new(0.5, 8, 0, 0), { color = UI.C.panel2, transp = 0 })
		UI.pad(right, 14)
		UI.list(right, 6)
		UI.text(right, "Prestanda (beräknad)", UDim2.new(1, 0, 0, 22), nil, { font = UI.BOLD, ts = 16, order = 0 })
		local s = S.perf(m)
		local lines = s and {
			{ "Slagvolym", string.format("%.0f cc", s.cc) }, { "Max effekt", string.format("%.1f hk vid %d rpm", s.hp, s.rpm) },
			{ "Varvspärr", string.format("%d rpm", s.limit) }, { "Toppfart", string.format("%d km/h", math.floor(s.top + 0.5)) },
			{ "0–45 km/h", s.t45 and string.format("%.1f s", s.t45) or "når inte 45" }, { "0–60 km/h", s.t60 and string.format("%.1f s", s.t60) or "når inte 60" },
			{ "Temperatur fullgas", string.format("%d °C", math.floor(s.temp + 0.5)) }, { "Motorstatus", s.status },
		} or { { "Motor", "Saknas" } }
		for i, l in ipairs(lines) do
			local r = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = i }, right)
			UI.text(r, l[1], UDim2.new(0.5, 0, 1, 0), nil, { ts = 14, color = UI.C.dim })
			UI.text(r, l[2], UDim2.new(0.5, 0, 1, 0), UDim2.fromScale(0.5, 0), { ts = 14, font = UI.BOLD, xa = Enum.TextXAlignment.Right })
		end
		UI.text(right, "Värdena räknas fram ur delarna. Testkör för att se hur den går på riktigt.", UDim2.new(1, 0, 0, 40), nil, { ts = 12, color = UI.C.dim, wrap = true, order = 20 })
	elseif mopedTab == "mopeder" then
		local list = UI.scroll(area, UDim2.new(0.45, 0, 1, 0))
		UI.list(list, 8)
		for i, mm in ipairs(p.mopeds) do
			local row = UI.panel(list, UDim2.new(1, -8, 0, 64), nil, { color = i == p.cur and UI.C.accent or UI.C.panel2, transp = i == p.cur and 0.35 or 0 })
			row.LayoutOrder = i
			UI.text(row, MopedDef.MODELS[mm.model].n, UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 6), { font = UI.BOLD, ts = 15 })
			UI.text(row, i == p.cur and "På lyften" or ("Värde " .. UI.kr(Profile.mopedValue(p, mm))), UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 32), { ts = 13, color = UI.C.dim })
			if i ~= p.cur then
				UI.button(row, "Välj", UDim2.fromOffset(64, 28), UDim2.new(1, -148, 0, 18), { kind = "secondary", ts = 14 }, function() S.api("selectMoped", i) end)
				UI.button(row, "Sälj", UDim2.fromOffset(64, 28), UDim2.new(1, -76, 0, 18), { kind = "danger", ts = 14 }, function() S.api("sellMoped", i) end)
			end
		end
		-- dealer: every model with a 3D picture
		local dealer = UI.new("Frame", { Size = UDim2.new(0.55, -12, 1, 0), Position = UDim2.new(0.45, 12, 0, 0), BackgroundTransparency = 1 }, area)
		UI.text(dealer, "Köp ny moped", UDim2.new(1, 0, 0, 24), nil, { font = UI.BOLD, ts = 16 })
		for i, id in ipairs(MopedDef.ORDER) do
			local def = MopedDef.MODELS[id]
			local card = UI.panel(dealer, UDim2.new(1, 0, 0, 112), UDim2.fromOffset(0, 30 + (i - 1) * 120), { color = UI.C.panel2, transp = 0 })
			local tmp = Profile.new()
			local idx = Profile.giveMoped(tmp, id, def.color)
			local model = Instance.new("Model")
			Models.moped(model, tmp.mopeds[idx], tmp.items, CFrame.new())
			UI.viewport(card, model, UDim2.fromOffset(160, 100), UDim2.fromOffset(6, 6), { dir = Vector3.new(-1, 0.35, -0.2), zoom = 0.9 })
			UI.text(card, def.n, UDim2.new(1, -180, 0, 24), UDim2.fromOffset(176, 10), { font = UI.BOLD, ts = 16 })
			UI.text(card, UI.kr(def.price), UDim2.new(1, -180, 0, 22), UDim2.fromOffset(176, 36), { ts = 15, color = UI.C.green, font = UI.BOLD })
			UI.button(card, "Köp", UDim2.fromOffset(90, 30), UDim2.fromOffset(176, 70), { kind = "green" }, function() S.api("buyMoped", id) end)
		end
	else
		UI.text(area, "Spara färgerna på alla kåpor som en design och lägg på den igen senare.", UDim2.new(1, 0, 0, 22), nil, { ts = 14, color = UI.C.dim })
		local box = UI.new("TextBox", { Size = UDim2.fromOffset(260, 34), Position = UDim2.fromOffset(0, 30), BackgroundColor3 = UI.C.panel2, Text = "", PlaceholderText = "Namn på designen", TextColor3 = UI.C.text, Font = UI.FONT, TextSize = 15, ClearTextOnFocus = false, Name = "Designnamn" }, area)
		UI.corner(box, 6)
		UI.button(area, "Spara design", UDim2.fromOffset(140, 34), UDim2.fromOffset(270, 30), { kind = "primary" }, function() S.api("saveDesign", box.Text) end)
		local list = UI.scroll(area, UDim2.new(1, 0, 1, -80), UDim2.fromOffset(0, 76))
		UI.list(list, 6)
		for i, d in ipairs(p.designs) do
			local row = UI.panel(list, UDim2.new(1, -8, 0, 46), nil, { color = UI.C.panel2, transp = 0 })
			row.LayoutOrder = i
			UI.text(row, d.n .. "  (" .. MopedDef.MODELS[d.model].n .. ")", UDim2.new(0.5, 0, 1, 0), UDim2.fromOffset(10, 0), { ts = 15, font = UI.BOLD })
			local x = 0
			for pid, pa in pairs(d.panels) do
				local sw = UI.new("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0.5, x, 0.5, -9), BackgroundColor3 = Color3.fromRGB(pa.c[1], pa.c[2], pa.c[3]), BorderSizePixel = 0, Name = pid }, row)
				UI.corner(sw, 9)
				x = x + 22
			end
			local n = 0
			for pid in pairs(d.panels) do if m.slots["pan:" .. pid] then n = n + 1 end end
			UI.button(row, "Lägg på (" .. UI.kr(n * Profile.DESIGN_COST) .. ")", UDim2.fromOffset(170, 32), UDim2.new(1, -178, 0, 7), { kind = "secondary", ts = 14 }, function() S.api("applyDesign", i) end)
		end
		if #p.designs == 0 then UI.text(list, "Inga sparade designer än.", UDim2.new(1, 0, 0, 30), nil, { ts = 14, color = UI.C.dim }) end
	end
end

local function buildStats(b)
	local p = S.profile
	UI.list(b, 8)
	local st = p.stats
	for i, l in ipairs({
		{ "Körda kilometer", string.format("%.1f km", st.km) }, { "Motorer byggda", tostring(st.built) }, { "Cylindrar portade", tostring(st.ported) },
		{ "Kåpor lackerade", tostring(st.painted) }, { "Uppdrag klara", tostring(st.jobs) }, { "Intjänat", UI.kr(st.earned) },
		{ "Mopeder", tostring(#p.mopeds) }, { "Sparning", S.meta.saving and "På" or "Av (Studio utan API-åtkomst)" },
	}) do
		local r = UI.panel(b, UDim2.new(1, 0, 0, 40), nil, { color = UI.C.panel2, transp = 0 })
		r.LayoutOrder = i
		UI.text(r, l[1], UDim2.new(0.6, 0, 1, 0), UDim2.fromOffset(14, 0), { ts = 16 })
		UI.text(r, l[2], UDim2.new(0.4, -14, 1, 0), UDim2.fromScale(0.6, 0), { ts = 16, font = UI.BOLD, xa = Enum.TextXAlignment.Right })
	end
end
local function buildSettings(b)
	UI.list(b, 10)
	local function toggle(order, label, key, onSet)
		local r = UI.panel(b, UDim2.new(1, 0, 0, 48), nil, { color = UI.C.panel2, transp = 0 })
		r.LayoutOrder = order
		UI.text(r, label, UDim2.new(0.7, 0, 1, 0), UDim2.fromOffset(14, 0), { ts = 16 })
		UI.button(r, S.settings[key] and "På" or "Av", UDim2.fromOffset(80, 32), UDim2.new(1, -92, 0, 8), { kind = S.settings[key] and "green" or "secondary", name = key }, function()
			S.settings[key] = not S.settings[key]
			if onSet then onSet(S.settings[key]) end
			refreshWin()
		end)
	end
	toggle(1, "Visa hjälptexter längst ner", "tips", function(on) if not on then tip.Visible = false end end)
	toggle(2, "Visa minikarta när du kör", "minimap")
	UI.text(b, "Tangenter: E använd · F kör ut · W/S gas och broms · A/D styr · Mellanslag kliv av · R tillbaka till garaget · Esc lämna arbetsläge", UDim2.new(1, 0, 0, 60), nil, { ts = 14, color = UI.C.dim, wrap = true, order = 10 })
end

S.open.Event:Connect(function(what)
	if what == "moped" then openWin("Min moppe", buildMoped)
	elseif what == "stats" then openWin("Statistik", buildStats)
	elseif what == "settings" then openWin("Inställningar", buildSettings)
	elseif what == "closeWindows" then closeWin() end
end)

---------------------------------------------------------------- start menu
local menu = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 10, 16), BackgroundTransparency = 0.35, Name = "Startmeny", ZIndex = 20 }, gui)
UI.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(10, 14, 24), Color3.fromRGB(255, 255, 255)), Transparency = NumberSequence.new(0, 0.85) }, menu)
local logo = UI.text(menu, "MOPPE", UDim2.fromOffset(420, 70), UDim2.fromOffset(60, 70), { font = UI.BLACK, ts = 68, z = 21, name = "Logo1" })
logo.Rotation = -4
local logo2 = UI.text(menu, "MEKANIKER", UDim2.fromOffset(460, 60), UDim2.fromOffset(70, 132), { font = UI.BLACK, ts = 52, z = 21, color = UI.C.accent2, name = "Logo2" })
logo2.Rotation = -4
UI.text(menu, "Bygg, trimma och kör din egen moppe", UDim2.fromOffset(420, 24), UDim2.fromOffset(74, 196), { ts = 16, color = UI.C.dim, z = 21 })
local mlist = UI.new("Frame", { Size = UDim2.fromOffset(240, 300), Position = UDim2.fromOffset(60, 250), BackgroundTransparency = 1, Name = "Knappar", ZIndex = 21 }, menu)
UI.list(mlist, 8)
-- while the start menu is open nothing in the world can be used: no walking, no E-prompts, no clicks,
-- and the camera shows the garage from the street
S.menu = true
local function holdPlayer()
	if not S.menu then return end
	S.lockMove(true)
	pcall(function() game:GetService("ProximityPromptService").Enabled = false end)
	task.defer(function()
		if not S.menu then return end
		local o = S.origin()
		S.camTo(o * CFrame.lookAt(Vector3.new(-16, 6, -34), Vector3.new(2, 3, 0)), 55, 0)
	end)
end
plr.CharacterAdded:Connect(function(char)
	char:WaitForChild("Humanoid", 10)
	holdPlayer()
end)
if plr.Character then task.spawn(function() plr.Character:WaitForChild("Humanoid", 10); holdPlayer() end) end
S.changed.Event:Connect(holdPlayer) -- the plot (and so the camera spot) is known once the profile arrives
local function closeMenu()
	if not S.menu then menu.Visible = false; return end
	S.menu = false
	menu.Visible = false
	S.lockMove(false)
	pcall(function() game:GetService("ProximityPromptService").Enabled = true end)
	S.camRelease()
end
for i, b in ipairs({ { "Spela", "play" }, { "Garage", "garage" }, { "Butik", "shop" }, { "Statistik", "stats" }, { "Inställningar", "settings" } }) do
	UI.button(mlist, b[1], UDim2.new(1, 0, 0, i == 1 and 52 or 42), nil, { kind = i == 1 and "primary" or "ghost", xa = Enum.TextXAlignment.Left, ts = i == 1 and 22 or 17, order = i, z = 21, transp = i == 1 and 0 or 0.15 }, function()
		closeMenu()
		if b[2] == "shop" or b[2] == "stats" or b[2] == "settings" then S.open:Fire(b[2]) end
	end)
end

---------------------------------------------------------------- visibility
game:GetService("RunService").Heartbeat:Connect(function()
	local g = inGarage() and S.mode == nil and not menu.Visible
	side.Visible = g
	info.Visible = g
	money.Visible = not menu.Visible
end)
S.modeEv.Event:Connect(function(mode) if mode then closeWin() end end)
updateInfo()

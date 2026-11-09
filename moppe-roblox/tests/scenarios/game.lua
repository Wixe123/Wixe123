-- Plays the whole game loop through the real client scripts: clicks, keys, prompts and drags.
local V3, CF = E.T.Vector3, E.T.CFrame
local check = E.check
E.startServer()
E.run(1)
local plr = E.addPlayer("Love", 101)
E.run(3)
local function prof() return E.services.Workspace.Garage.Plot1 and _G.__p end
-- the profile the client got
local function state()
	local S = E.makeGlobals(plr.ctx)
	return plr.ctx.cache and (function()
		for m, c in pairs(plr.ctx.cache) do if m.Name == "State" then return c.value end end
	end)()
end
local S = state()
check("client got its profile", S and S.profile ~= nil)
check("start menu shows", E.findGui("Spela") ~= nil)
E.clickGui("Spela")
E.run(0.5)
check("garage side menu visible", E.findGui("Bygg motor") ~= nil)

---------------------------------------------------------------- shop: order a 70 cc kit with the mouse
E.usePrompt("Använd datorn")
E.run(1)
check("shop open", E.findGui("Moppelagret.se") ~= nil)
E.clickGui("^Cylindrar$")
E.run(0.5)
local function buy(sku)
	local card = E.findGui(sku)
	local btn = card and card:FindFirstChild("Köp")
	check("buy button for " .. sku, btn ~= nil)
	if btn then E.clickGui(btn) end
	E.run(0.3)
end
buy("cylinder_nordtrim70"); buy("kolv_47"); buy("kolvringar_47")
check("cart has 3 lines", #S.profile.orders == 0 and E.findGui("Kundvagn %(3%)") ~= nil)
E.shot("g1_butik_kundvagn")
local money0 = S.profile.money
E.clickGui("^Beställ$")
E.run(1)
check("order placed and paid", #S.profile.orders == 1 and S.profile.money == money0 - 1990 - 499 - 159, S.profile.money)
check("orders tab shows countdown", E.findGui("På väg") ~= nil)
E.shot("g2_ordrar")
E.tap("Escape"); E.run(0.5)
check("shop closed with Escape", S.mode == nil, S.mode)
-- 3 parts: 3 minutes
E.run(185, 1 / 4)
check("box arrived", S.profile.orders[1].state == "framme", S.profile.orders[1].state)
E.usePrompt("Öppna paketet")
E.run(1)
check("box opened", S.profile.orders[1].state == "oppnad")
E.lookFrom(V3.new(-120, 6, -30), V3.new(-128, 1, -20), 50); E.shot("g3_paket"); E.lookFrom(nil)

---------------------------------------------------------------- take the engine out (through the API), rebuild the top end by dragging
check("engine to stand (wheel, brake and exhaust stay on)", E.api("engineToStand"))
for _, sock in ipairs({ "cylinder", "kolv" }) do
	local ok, e = E.api("unmountEngine", "stand", sock)
	check("unmount " .. sock, ok, e)
end
E.run(1)
E.usePrompt("Bygg motor")
E.run(1)
check("engine mode open", S.mode == "engine")
-- drag the new 47 mm piston onto the engine
local function dragItem(sku)
	local id
	local Prof = E.makeGlobals(plr.ctx).require(E.services.ReplicatedStorage.Shared.Profile)
	for iid, it in pairs(S.profile.items) do if it.sku == sku and Prof.isFree(S.profile, it) then id = iid end end
	local card = id and E.findGui("Del_" .. id)
	if card then E.scrollIntoView(card) end
	check("tray card for " .. sku, card ~= nil)
	if not card then return end
	local L = card.L
	E.mouseMove(L.x + L.w / 2, L.y + L.h / 2)
	E.mouseButton(1, true)
	E.run(0.1)
	local marker = E.services.Workspace:FindFirstChild("MonteringLokal") and E.services.Workspace.MonteringLokal:FindFirstChild("Markering")
	check("marker shown for " .. sku, marker ~= nil)
	if not marker then E.mouseButton(1, false); return end
	local cf = marker:GetBoundingBox()
	local x, y = E.screenOf(cf.Position)
	for i = 1, 8 do E.mouseMove(L.x + L.w / 2 + (x - L.x - L.w / 2) * i / 8, L.y + L.h / 2 + (y - L.y - L.h / 2) * i / 8); E.step(1 / 30) end
	E.run(0.1)
	E.shot("g4_dra_" .. sku)
	E.mouseButton(1, false)
	E.run(1.2)
end
dragItem("kolv_47")
check("47 mm piston mounted", S.profile.stand.kolv and S.profile.items[S.profile.stand.kolv].sku == "kolv_47")
-- the 40 mm rings must be refused now
local ring40
for iid, it in pairs(S.profile.items) do if it.sku == "kolvringar_40" and it.loc ~= "mount" then ring40 = iid end end
check("40 mm rings refused on 47 mm piston", not E.api("mountEngine", "stand", "kolvringar", ring40))
dragItem("kolvringar_47")
dragItem("kolvbult_origo")
check("rings and pin mounted", S.profile.stand.kolvringar ~= nil and S.profile.stand.kolvbult ~= nil)
E.shot("g5_motorbygge")
E.tap("Escape"); E.run(0.5)

---------------------------------------------------------------- porting the new cylinder
E.usePrompt("Porta cylinder")
E.run(1)
local cylBtn = E.findGui("Cylinder 70 cc Sport", { button = true })
check("porting picker lists the new cylinder", cylBtn ~= nil)
if cylBtn then E.clickGui(cylBtn) end
E.run(1)
check("porting started", E.findGui("Framsteg") ~= nil)
local scene = E.services.Workspace:FindFirstChild("PortningLokal")
if not scene then error("porting scene missing") end
-- sweep every zone with the grinder
local Porting = E.makeGlobals(E.serverCtx).require(E.services.ReplicatedStorage.Shared.Porting)
for zi = 1, 4 do
	E.tap(zi == 1 and "F13" or "D")
	E.run(0.5)
	local cells = {}
	for _, p in ipairs(scene:GetChildren()) do if p.Name == "Yta" then cells[#cells + 1] = p end end
	-- the cells of the active zone are the ones facing the camera (closest)
	local cam = E.currentCamera(plr.ctx)
	table.sort(cells, function(a, b) return (a.Position - cam.CFrame.Position).Magnitude < (b.Position - cam.CFrame.Position).Magnitude end)
	local mine = {}
	for i = 1, 18 do mine[i] = cells[i] end
	table.sort(mine, function(a, b) local ax, ay = E.screenOf(a.Position); local bx, by = E.screenOf(b.Position); if math.abs(ay - by) > 4 then return ay < by end return ax < bx end)
	-- like a player: hold the grinder on each glowing cell until it turns to bare metal
	E.mouseMove(E.screenOf(mine[1].Position))
	E.mouseButton(1, true)
	for _, c in ipairs(mine) do
		local x, y = E.screenOf(c.Position)
		E.mouseMove(x, y)
		local n = 0
		while (c:GetAttribute("Depth") or 0) < 1 and n < 90 do E.step(1 / 30); n = n + 1 end
	end
	E.mouseButton(1, false)
	E.run(0.2)
	HOST_ECHO("  zone " .. zi .. ": " .. (E.findGui("Procent") and E.findGui("Procent").Text or "?"))
	if zi == 1 then E.shot("g6_portning") end
end
local klar = E.findGui("^Klar$", { button = true })
HOST_ECHO("  Klar button: " .. (klar and klar:GetFullName() or "none"))
E.clickGui("^Klar$")
E.run(1)
for _, o in ipairs(plr.PlayerGui.Hud.Notiser:GetChildren()) do local t = o:FindFirstChildOfClass("TextLabel"); if t then HOST_ECHO("  toast: " .. t.Text) end end
for iid, it in pairs(S.profile.items) do if it.loc == "port" then HOST_ECHO("  on the vise: " .. it.sku) end end
local cylId
for iid, it in pairs(S.profile.items) do if it.sku == "cylinder_nordtrim70" then cylId = iid end end
check("cylinder ported", S.profile.items[cylId].port ~= nil, S.profile.items[cylId].port and S.profile.items[cylId].port.label)
if S.profile.items[cylId].port then HOST_ECHO("  porting result: " .. S.profile.items[cylId].port.label .. " q=" .. string.format("%.2f", S.profile.items[cylId].port.q)) end

---------------------------------------------------------------- finish the engine, put it back, ride
E.usePrompt("Bygg motor")
E.run(1)
check("fotpackning still on", S.profile.stand.fotpackning ~= nil)
dragItem("cylinder_nordtrim70")
dragItem("topplock_origo")
dragItem("tandstift_b7")
dragItem("tandkabel_origo")
check("engine complete again", (function() local n = 0; for _ in pairs(S.profile.stand) do n = n + 1 end return n == 29 end)())
E.clickGui("Sätt motorn i mopeden")
E.run(1)
E.tap("Escape"); E.run(0.5)
local Profile = E.makeGlobals(plr.ctx).require(E.services.ReplicatedStorage.Shared.Profile)
local perf = Profile.perf(S.profile)
HOST_ECHO(string.format("  after the 70 cc kit: %.1f hp, top %.0f km/h", perf.hp, perf.top))

---------------------------------------------------------------- paint a panel
check("unmount side panel", E.api("unmountChassis", "pan:sidaV"))
E.usePrompt("Lackera")
E.run(1)
local pbtn = E.findGui("Sidokåpa vänster", { button = true })
check("paint picker lists the panel", pbtn ~= nil)
if pbtn then E.clickGui(pbtn) end
E.run(1)
E.typeText("HEX", "#162254")
E.clickGui("^Metallic$")
local function sprayPanel(passes)
	local scene = E.services.Workspace.LackLokal
	local mn, mx
	for _, d in ipairs(scene:GetChildren()) do
		if d:IsA("BasePart") and d.Name == "Kåpa" then
			local cf, sz = d.CFrame, d.Size
			for _, sx in ipairs({ -0.5, 0.5 }) do for _, sy in ipairs({ -0.5, 0.5 }) do for _, sz2 in ipairs({ -0.5, 0.5 }) do
				local x, y = E.screenOf(cf * E.T.Vector3.new(sx * sz.X, sy * sz.Y, sz2 * sz.Z))
				mn = mn and E.T.Vector2.new(math.min(mn.X, x), math.min(mn.Y, y)) or E.T.Vector2.new(x, y)
				mx = mx and E.T.Vector2.new(math.max(mx.X, x), math.max(mx.Y, y)) or E.T.Vector2.new(x, y)
			end end end
		end
	end
	-- stay off the colour panel (left) and the checklist (right)
	mn = E.T.Vector2.new(math.max(mn.X, 330), math.max(mn.Y, 60)); mx = E.T.Vector2.new(math.min(mx.X, 1030), math.min(mx.Y, 600))
	E.mouseMove(mn.X + 5, mn.Y + 5)
	E.mouseButton(1, true)
	for pass = 1, passes do
		for row = 0, 7 do
			local y = mn.Y + (mx.Y - mn.Y) * (row + 0.5) / 8
			for k = 0, 30 do -- about one second per sweep, like a player
				local x = (row % 2 == 0) and (mn.X + (mx.X - mn.X) * k / 30) or (mx.X - (mx.X - mn.X) * k / 30)
				E.mouseMove(x, y); E.step(1 / 30)
			end
		end
	end
	E.mouseButton(1, false)
	E.run(0.3)
end
sprayPanel(1)

E.shot("g7_lackering")
E.clickGui("^Avsluta$")
E.run(1)
local panelId
for iid, it in pairs(S.profile.items) do if it.loc == "lack" then panelId = iid end end
check("panel painted blue metallic", panelId and S.profile.items[panelId].paint and S.profile.items[panelId].paint.f == "metallic")
check("wet panel cannot be mounted", not E.api("mountChassis", "pan:sidaV", panelId))
E.run(21)
check("dry panel mounts", E.api("mountChassis", "pan:sidaV", panelId))

---------------------------------------------------------------- ride out
E.usePrompt("Kör ut") -- the F prompt at the lift
E.run(1.5)
local hum = plr.Character.Humanoid
check("seated on the moped", hum.SeatPart ~= nil)
local moped = E.services.Workspace.Garage.Plot1.Dynamic:FindFirstChild("Moped")
local p0 = moped.PrimaryPart.Position
E.key("W", true)
E.run(8)
E.shot("g8_korning")
E.key("W", false)
local p1 = moped.PrimaryPart.Position
HOST_ECHO(string.format("  moved %.0f studs in 8 s", (p1 - p0).Magnitude))
check("moped drives forward", (p1 - p0).Magnitude > 60)
check("moped stays on the ground", math.abs(p1.Y - p0.Y) < 2, p1.Y - p0.Y)
E.key("S", true); E.run(4); E.key("S", false)
E.tap("R")
E.run(1)
check("back home", hum.SeatPart == nil)

---------------------------------------------------------------- a delivery job
local ok, job = E.api("acceptJob", Profile.offers(S.profile)[1].key)
check("accept delivery job", ok)
local Map = E.makeGlobals(plr.ctx).require(E.services.ReplicatedStorage.Shared.Map)
E.clickGui("^Kör ut$"); E.run(2)
local pl = Map.PLACES[job.dest]
-- move the moped next to the destination (as if we drove there)
moped = E.services.Workspace.Garage.Plot1.Dynamic:FindFirstChild("Moped")
E.movePart(moped.PrimaryPart, CF.new(pl.x - 4, 1, pl.z))
E.run(1)
local b = E.findGui("Lämna paketet")
check("deliver button appears at the destination", b ~= nil)
local m0 = S.profile.money
if b then E.clickGui(b) end
E.run(1)
check("delivery paid", S.profile.money > m0, S.profile.money - m0)
E.tap("R"); E.run(1)

---------------------------------------------------------------- leave and come back: saved
local moneyBefore = S.profile.money
E.removePlayer(plr)
E.run(1)
local plr2 = E.addPlayer("Love", 101)
E.player = plr2
E.run(4)
local S2
for m, c in pairs(plr2.ctx.cache) do if m.Name == "State" then S2 = c.value end end
check("profile saved and loaded", S2 and S2.profile and S2.profile.money == moneyBefore, S2 and S2.profile and S2.profile.money)
check("ported cylinder still in the engine", (function() local m = S2.profile.mopeds[1]; local it = S2.profile.items[m.engine.cylinder]; return it.sku == "cylinder_nordtrim70" and it.port ~= nil end)())

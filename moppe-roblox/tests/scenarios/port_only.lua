-- Just porting (quick check)
local plrS
E.startServer(); E.run(1); local plr = E.addPlayer("Love", 101); E.run(3)
E.clickGui("Spela"); E.run(0.5)
E.usePrompt("Porta cylinder"); E.run(1)
E.clickGui(E.findGui("Cylinder 50 cc", { button = true })); E.run(1)
local scene = E.services.Workspace.PortningLokal
for zi = 1, 4 do
	if zi > 1 then E.tap("D"); E.run(0.5) end
	local cells = {}
	for _, p in ipairs(scene:GetChildren()) do if p.Name == "Yta" then cells[#cells + 1] = p end end
	local cam = E.currentCamera(plr.ctx)
	table.sort(cells, function(a, b) return (a.Position - cam.CFrame.Position).Magnitude < (b.Position - cam.CFrame.Position).Magnitude end)
	local mine = {}
	for i = 1, 18 do mine[i] = cells[i] end
	if zi == 2 then
		-- photograph half-way through a port, grinder on the surface
		E.mouseMove(E.screenOf(mine[1].Position)); E.mouseButton(1, true)
		for k = 1, 9 do E.mouseMove(E.screenOf(mine[k].Position)); for _ = 1, 12 do E.step(1 / 30) end end
		E.shot("port_mid")
		E.mouseButton(1, false)
	end
	E.mouseMove(E.screenOf(mine[1].Position))
	E.mouseButton(1, true)
	for _, c in ipairs(mine) do
		E.mouseMove(E.screenOf(c.Position))
		local n = 0
		while (c:GetAttribute("Depth") or 0) < 1 and n < 90 do E.step(1 / 30); n = n + 1 end
	end
	E.mouseButton(1, false); E.run(0.2)
	HOST_ECHO("zone " .. zi .. ": " .. E.findGui("Procent").Text)
end
E.clickGui("^Klar$"); E.run(1)
for _, o in ipairs(plr.PlayerGui.Hud.Notiser:GetChildren()) do local t = o:FindFirstChildOfClass("TextLabel"); if t then HOST_ECHO("toast: " .. t.Text) end end

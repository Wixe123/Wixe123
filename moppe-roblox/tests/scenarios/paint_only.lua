-- Just the paint booth (quick check)
E.startServer(); E.run(1); local plr = E.addPlayer("Love", 101); E.run(3)
E.clickGui("Spela"); E.run(0.5)
E.check("unmount side panel", E.api("unmountChassis", "pan:sidaV"))
E.usePrompt("Lackera"); E.run(1)
E.clickGui(E.findGui("Sidokåpa vänster", { button = true })); E.run(1)
E.typeText("HEX", "#162254"); E.clickGui("^Metallic$")
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

E.shot("paint_only")
E.clickGui(E.findGui("^NORDTRIM$", { button = true }) or "NORDTRIM"); E.run(0.2)
E.clickGui("^Avsluta$"); E.run(2)
E.shot("paint_dry")

for _, o in ipairs(plr.PlayerGui.Hud.Notiser:GetChildren()) do local t = o:FindFirstChildOfClass("TextLabel"); if t then HOST_ECHO("toast: " .. t.Text) end end

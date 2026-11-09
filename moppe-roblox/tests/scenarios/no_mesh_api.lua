-- Roblox returns nil from CreateEditableMesh when the place may not use mesh APIs (seen in Studio).
-- The game must keep working with block panels, show one clear message, and the paint booth must still work.
E.noEditableMesh = true
E.startServer(); E.run(1); local plr = E.addPlayer("Love", 101); E.run(3)
E.clickGui("Spela")
local texts, seen = {}, {}
for _ = 1, 60 do
	E.step(0.1)
	for _, o in ipairs(plr.PlayerGui.Hud.Notiser:GetChildren()) do
		local t = o:FindFirstChildOfClass("TextLabel")
		if t and not seen[o] then seen[o] = true; texts[#texts + 1] = t.Text; HOST_ECHO("toast: " .. t.Text) end
	end
end
E.check("exactly one message about the mesh API", #texts == 1 and texts[1]:find("Allow Mesh") ~= nil)
E.check("unmount side panel", E.api("unmountChassis", "pan:sidaV"))
E.usePrompt("Lackera"); E.run(1)
E.clickGui(E.findGui("Sidokåpa vänster", { button = true })); E.run(1)
local scene = E.services.Workspace.LackLokal
local n = 0
for _, d in ipairs(scene:GetChildren()) do if d:IsA("BasePart") and d.Transparency == 0 and d.Name ~= "Lackprick" then n = n + 1 end end
E.check("block panel shown in the booth", n > 0)
E.shot("no_mesh_paint")

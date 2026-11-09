-- Leaving the vise or the booth without finishing must free the part there (Studio bug: "can't take the panel out")
E.startServer(); E.run(1); local plr = E.addPlayer("Love", 101); E.run(3)
E.clickGui("Spela"); E.run(0.5)
local function state()
	for m, c in pairs(plr.ctx.cache or {}) do if m.Name == "State" then return c.value end end
end
local S = state()
-- porting: put the cylinder in the vise, then Avbryt
E.usePrompt("Porta cylinder"); E.run(1)
E.clickGui(E.findGui("Cylinder 50 cc", { button = true })); E.run(1)
-- grind a little: the surface must change under the mouse
local scene = E.services.Workspace.PortningLokal
local cells = {}
for _, p in ipairs(scene:GetChildren()) do if p.Name == "Yta" then cells[#cells + 1] = p end end
local cam = E.currentCamera(plr.ctx)
table.sort(cells, function(a, b) return (a.Position - cam.CFrame.Position).Magnitude < (b.Position - cam.CFrame.Position).Magnitude end)
E.mouseMove(E.screenOf(cells[1].Position)); E.mouseButton(1, true)
for _ = 1, 30 do E.step(1 / 30) end
E.mouseButton(1, false); E.run(0.2)
E.check("grinding changes the surface within a second", (cells[1]:GetAttribute("Depth") or 0) > 0.5)
E.clickGui("^Avbryt$"); E.run(1)
local cylId
for id, it in pairs(S.profile.items) do if it.loc == "port" then cylId = id end end
E.check("cylinder is in the vise", cylId ~= nil)
E.check("cylinder can be taken out after Avbryt", E.api("pickup", cylId))
E.check("put it back on the shelf", E.api("place", "hylla"))
-- paint: hang a panel, leave with Avsluta before spraying, take the panel out
E.check("unmount side panel", E.api("unmountChassis", "pan:sidaV"))
E.usePrompt("Lackera"); E.run(1)
E.clickGui(E.findGui("Sidokåpa vänster", { button = true })); E.run(1)
E.clickGui("^Avsluta$"); E.run(1)
local panId
for id, it in pairs(S.profile.items) do if it.loc == "lack" then panId = id end end
E.check("panel is on the stand", panId ~= nil)
E.check("panel can be taken out after Avsluta", E.api("pickup", panId))

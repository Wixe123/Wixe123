-- Just the paint booth (quick check)
E.startServer(); E.run(1); local plr = E.addPlayer("Love", 101); E.run(3)
E.clickGui("Spela"); E.run(0.5)
E.check("unmount side panel", E.api("unmountChassis", "pan:sidaV"))
E.usePrompt("Lackera"); E.run(1)
E.clickGui(E.findGui("Sidokåpa vänster", { button = true })); E.run(1)
E.clickGui("Midnight Blue"); E.clickGui("^Metallic$")
local cells = {}
for _, p in ipairs(E.services.Workspace.LackLokal:GetChildren()) do if p.Name == "Lack" then cells[#cells + 1] = p end end
local x, y, on = E.screenOf(cells[1].Position)
HOST_ECHO(string.format("cells %d first on screen %s at %.0f,%.0f", #cells, tostring(on), x, y))
E.mouseMove(E.screenOf(cells[1].Position))
E.mouseButton(1, true)
for pass = 1, 5 do for _, c in ipairs(cells) do local x2, y2 = E.screenOf(c.Position); E.mouseMove(x2, y2); E.step(1 / 30) end end
E.mouseButton(1, false); E.run(0.3)
HOST_ECHO(E.findGui("Resultat").Text)
E.shot("paint_only")
E.clickGui("^Klar$"); E.run(1)
for _, o in ipairs(plr.PlayerGui.Hud.Notiser:GetChildren()) do local t = o:FindFirstChildOfClass("TextLabel"); if t then HOST_ECHO("toast: " .. t.Text) end end

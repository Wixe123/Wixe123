-- Engine building screen: pick a part, hold it, hover the glow, place it
local V3 = E.T.Vector3
E.startServer(); E.run(1); local plr = E.addPlayer("Love", 101); E.run(3)
E.clickGui("Spela"); E.run(0.5)
local S
for m, c in pairs(plr.ctx.cache) do if m.Name == "State" then S = c.value end end
E.check("engine to stand", E.api("engineToStand"))
E.check("cylinder off", E.api("unmountEngine", "stand", "cylinder"))
E.run(0.5)
E.usePrompt("Bygg motor"); E.run(1.5)
E.check("build mode open", S.mode == "engine")
E.shot("build_list")
-- pick the cylinder in the list: it is held in the hand
local id
for iid, it in pairs(S.profile.items) do if it.sku == "cylinder_origo50" and it.loc ~= "mount" then id = iid end end
local rowBtn = E.findGui("Del_" .. id)
E.check("cylinder row in the list", rowBtn ~= nil)
E.clickGui(rowBtn)
E.run(0.5)
E.shot("build_held")
-- hover the green target and click to place
local marker = E.services.Workspace.MonteringLokal:FindFirstChild("Markering")
E.check("glowing target shown", marker ~= nil and marker:FindFirstChild("Glöd") ~= nil)
local x, y = E.screenOf(marker:GetBoundingBox().Position)
E.mouseMove(x, y); E.run(0.3)
E.shot("build_target")
E.click(x, y); E.run(1.5)
E.check("cylinder mounted by clicking the glow", S.profile.stand.cylinder ~= nil)
-- buy from the list: select a part under "Köp till" and add to cart, then order
local buyRow
for _, o in ipairs(plr.PlayerGui.Montering.Delar.Lista:GetChildren()) do if o.Name:match("^Köp_") then buyRow = o; break end end
E.check("parts to buy listed", buyRow ~= nil)
if buyRow then
	E.clickGui(buyRow); E.run(0.3)
	E.clickGui("Lägg i kundvagn"); E.run(0.3)
	local m0 = S.profile.money
	E.clickGui("^Beställ$"); E.run(1)
	E.check("ordered from the build screen", S.profile.money < m0 and #S.profile.orders == 1)
end
E.shot("build_after")

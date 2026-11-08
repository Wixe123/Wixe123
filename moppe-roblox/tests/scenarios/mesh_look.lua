-- The three mopeds with smooth mesh panels (skinned by the client), photographed
local V3, CF = E.T.Vector3, E.T.CFrame
E.startServer(); E.run(1); local plr = E.addPlayer("Love", 101); E.run(3)
E.clickGui("Spela"); E.run(0.5)
local G = E.makeGlobals(E.serverCtx)
local Shared = E.services.ReplicatedStorage.Shared
local Models, Profile = G.require(Shared.Models), G.require(Shared.Profile)
local p = Profile.new()
Profile.giveMoped(p, "sprint", { 25, 70, 200 })
Profile.giveMoped(p, "klassik", { 120, 200, 190 })
local base = V3.new(-60, 0, -60)
for i, m in ipairs(p.mopeds) do
	local mm = Models.moped(E.services.Workspace, m, p.items, CF.new(base + V3.new(0, 0.12, (i - 2) * 9)) * CF.Angles(0, math.rad(90), 0))
	mm:SetAttribute("OwnerId", 0)
end
E.run(1)
local n = 0
for _, d in ipairs(E.services.Workspace:GetDescendants()) do if d.Name == "Kåpa3D" then n = n + 1 end end
E.check("mesh panels created", n >= 25, n)
for i, nme in ipairs({ "citi", "sprint", "klassik" }) do
	local z = base.Z + (i - 2) * 9
	E.lookFrom(V3.new(base.X, 2.4, z + 8.5), V3.new(base.X, 1.9, z), 38); E.shot("mesh_side_" .. nme)
	E.lookFrom(V3.new(base.X - 6, 4.2, z + 5.5), V3.new(base.X, 1.8, z), 42); E.shot("mesh_34_" .. nme)
end

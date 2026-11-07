-- Builds every moped model and a complete engine on a floor and photographs them.
local G = E.makeGlobals(E.serverCtx)
local Shared = E.services.ReplicatedStorage.Shared
local Models, Profile = G.require(Shared.Models), G.require(Shared.Profile)
local V3, CF = E.T.Vector3, E.T.CFrame
local ws = E.services.Workspace
local floor = E.new("Part"); floor.Anchored = true; floor.Size = V3.new(80, 1, 80); floor.CFrame = CF.new(0, -0.5, 0); floor.Color = E.T.Color3.fromRGB(150, 150, 150); floor.Material = E.Enum.Material.Concrete; floor.Parent = ws
E.services.Lighting.ClockTime = 13
local p = Profile.new()
Profile.giveMoped(p, "sprint", { 25, 70, 200 })
Profile.giveMoped(p, "klassik", { 120, 200, 190 })
for i, m in ipairs(p.mopeds) do Models.moped(ws, m, p.items, CF.new(0, 0, (i - 2) * 12) * CF.Angles(0, math.rad(90), 0)) end
local stand = Profile.newEngine(p)
local engCF = CF.new(20, 2, 0)
Models.engine(ws, engCF, stand, p.items)
-- side views: moped faces -X (rotated 90 degrees), camera on +Z side of each
for i, n in ipairs({ "citi", "sprint", "klassik" }) do
	local z = (i - 2) * 12
	E.lookFrom(V3.new(0, 2.2, z + 9), V3.new(0, 1.9, z), 40); E.shot("side_" .. n)
	E.lookFrom(V3.new(-6, 4, z + 6), V3.new(0, 1.8, z), 45); E.shot("front_" .. n)
end
E.lookFrom(V3.new(17.5, 3.2, 2.2), V3.new(20, 2.1, 0.4), 50); E.shot("engine_left")
E.lookFrom(V3.new(23, 3.4, -1.5), V3.new(20, 2.1, 0), 50); E.shot("engine_right")

local G = E.makeGlobals(E.serverCtx)
local Shared = E.services.ReplicatedStorage.Shared
local Models, Profile, GB = G.require(Shared.Models), G.require(Shared.Profile), G.require(Shared.GarageBuilder)
local V3, CF = E.T.Vector3, E.T.CFrame
local ws = E.services.Workspace
local ground = E.new("Part"); ground.Anchored = true; ground.Size = V3.new(200, 2, 200); ground.CFrame = CF.new(0, -1, 0); ground.Color = E.T.Color3.fromRGB(80, 120, 60); ground.Material = E.Enum.Material.Grass; ground.Parent = ws
E.services.Lighting.ClockTime = 14
local origin = CF.new()
local refs = GB.build(ws, origin, 1)
local p = Profile.new()
Models.moped(ws, p.mopeds[1], p.items, origin * GB.LIFT)
local stand = Profile.newEngine(p)
Models.engine(ws, origin * GB.STAND, stand, p.items)
for i = 1, 6 do local m = Models.item(i % 2 == 0 and "cylinder_fartek70" or "forgasare_gs19"); m:PivotTo(refs.shelfSlots[i] * CF.new(0, m.PrimaryPart.Size.Y / 2, 0)); m.Parent = ws end
E.lookFrom(V3.new(0, 7, -14), V3.new(0, 3, 6), 70); E.shot("garage_in")
E.lookFrom(V3.new(-14, 6, -6), V3.new(6, 3, 12), 70); E.shot("garage_back")
E.lookFrom(V3.new(10, 6, -10), V3.new(-14, 3, 6), 70); E.shot("garage_left")
E.lookFrom(V3.new(14, 9, -45), V3.new(0, 5, -10), 55); E.shot("garage_out")

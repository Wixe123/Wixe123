-- Riding out and driving (quick check)
local V3 = E.T.Vector3
E.startServer(); E.run(1); local plr = E.addPlayer("Love", 101); E.run(3)
E.clickGui("Spela"); E.run(0.5)
E.clickGui("^Kör ut$") -- side menu: walks to the lift and rides out
E.run(2)
local hum = plr.Character.Humanoid
E.check("seated on the moped", hum.SeatPart ~= nil)
local moped = E.services.Workspace.Garage.Plot1.Dynamic:FindFirstChild("Moped")
local p0 = moped.PrimaryPart.Position
E.key("W", true); E.run(8)
E.shot("ride_only")
E.key("W", false)
local p1 = moped.PrimaryPart.Position
HOST_ECHO(string.format("moved %.0f studs, speed text %s", (p1 - p0).Magnitude, E.findGui("Kmh") and E.findGui("Kmh").Text or "?"))
E.check("moped drives forward", (p1 - p0).Magnitude > 60)
E.check("on the ground", math.abs(p1.Y - p0.Y) < 2, p1.Y - p0.Y)
E.tap("R"); E.run(1.5)
E.check("home again", hum.SeatPart == nil)
local S
for m, c in pairs(plr.ctx.cache) do if m.Name == "State" then S = c.value end end
local Profile = E.makeGlobals(plr.ctx).require(E.services.ReplicatedStorage.Shared.Profile)
local ok, job = E.api("acceptJob", Profile.offers(S.profile)[1].key)
E.check("accept delivery", ok)
E.run(0.5)
HOST_ECHO("side menu Kör ut visible: " .. tostring(E.findGui("^Kör ut$") ~= nil) .. " mode " .. tostring(S.mode))
E.clickGui("^Kör ut$"); E.run(2)
E.check("seated again", hum.SeatPart ~= nil)
local Map = E.makeGlobals(plr.ctx).require(E.services.ReplicatedStorage.Shared.Map)
local pl = Map.PLACES[job.dest]
local moped2 = E.services.Workspace.Garage.Plot1.Dynamic:FindFirstChild("Moped")
E.movePart(moped2.PrimaryPart, E.T.CFrame.new(pl.x - 4, 1, pl.z))
E.run(1)
HOST_ECHO("moped at " .. tostring(moped2.PrimaryPart.Position) .. " dest " .. pl.x .. "," .. pl.z)
local b = E.findGui("Lämna paketet")
E.check("deliver button", b ~= nil)
local m0 = S.profile.money
if b then E.clickGui(b) end
E.run(1)
E.check("paid", S.profile.money > m0, S.profile.money - m0)

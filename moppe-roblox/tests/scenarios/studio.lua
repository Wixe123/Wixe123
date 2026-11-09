-- Paint studio on the moped: part groups, colour, finish, spray, pay, designs, saved colours
E.startServer(); E.run(1); local plr = E.addPlayer("Love", 101); E.run(3)
E.clickGui("^Spela$"); E.run(0.5)
local function state()
	for m, c in pairs(plr.ctx.cache or {}) do if m.Name == "State" then return c.value end end
end
local S = state()
E.clickGui("^Lackering$"); E.run(9)
E.check("studio open from the garage menu", S.mode == "studio")
E.check("all ten part groups listed", E.findGui("Zon_frontkapor") and E.findGui("Zon_falgar") and E.findGui("Zon_detaljer") and true or false)
E.shot("studio_parts")
local function moped() return E.services.Workspace.Garage.Plot1:FindFirstChild("Moped", true) end
local function partsNamed(set)
	local r = {}
	for _, d in ipairs(moped():GetDescendants()) do if d:IsA("BasePart") and set[d.Name] then r[#r + 1] = d end end
	return r
end
local function sprayOver(parts, maxSteps)
	-- aim like a player: at points on the screen where the part's surface really is
	local cam = E.currentCamera(plr.ctx)
	local params = E.T.RaycastParams.new()
	params.FilterType = E.Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = parts
	local pts = {}
	for x = 360, 1000, 20 do
		for y = 70, 560, 20 do
			local ray = cam:ViewportPointToRay(x, y)
			if E.services.Workspace:Raycast(ray.Origin, ray.Direction * 60, params) then pts[#pts + 1] = { x, y } end
		end
	end
	E.check("parts to spray are on screen (" .. #pts .. " points)", #pts > 0)
	if #pts == 0 then return end
	E.mouseMove(pts[1][1], pts[1][2]); E.mouseButton(1, true)
	for k = 1, maxSteps do
		local q = pts[(k % #pts) + 1]
		E.mouseMove(q[1], q[2])
		E.step(1 / 30)
	end
	E.mouseButton(1, false); E.run(0.3)
end
local money0 = S.profile.money
-- rims: red chrome
E.clickGui("Zon_falgar"); E.run(1)
E.clickGui("Flik_Färg"); E.run(0.3)
E.typeText("HEX", "#C81E1E"); E.run(0.3)
E.shot("studio_colour")
E.clickGui("Flik_Lack"); E.run(0.3)
E.clickGui("Lack_chrome"); E.run(0.3)
E.shot("studio_finish")
local rims = partsNamed({ ["FramhjulFälg"] = true, ["BakhjulFälg"] = true, FramhjulEker = true, BakhjulEker = true })
sprayOver(rims, 240)
E.shot("studio_spray")
E.clickGui("^Klar"); E.run(1.5)
local m = S.profile.mopeds[S.profile.cur]
E.check("rims saved as red chrome in the moped's data", m.paint and m.paint.falgar and m.paint.falgar.f == "chrome" and m.paint.falgar.c[1] == 200)
E.check("money paid for the job", S.profile.money < money0)
local rim = partsNamed({ ["FramhjulFälg"] = true })[1]
E.check("rim in the world is red chrome", rim and rim.Material.Name == "Foil" and rim.Color.R > rim.Color.B)
local side = moped():FindFirstChild("pan:sidaV")
local sideColor = side and side:FindFirstChildWhichIsA("BasePart", true).Color
E.check("side panels untouched by the rim job", sideColor and sideColor.B > sideColor.R)
-- side panels: candy green
local money1 = S.profile.money
E.clickGui("Zon_sidokapor"); E.run(1)
E.shot("studio_side")
E.clickGui("Flik_Färg"); E.run(0.3)
E.clickGui("Neon Green"); E.run(0.2)
E.clickGui("SparaFärg"); E.run(0.5)
E.check("colour saved", #S.profile.savedColors == 1)
E.clickGui("Flik_Lack"); E.run(0.3)
E.clickGui("Lack_candy"); E.run(0.3)
local sideParts = {}
for _, d in ipairs(moped():GetDescendants()) do
	if d:IsA("BasePart") and d.LocalTransparencyModifier < 1 and (d:FindFirstAncestor("pan:sidaV") or d:FindFirstAncestor("pan:sidaH")) then sideParts[#sideParts + 1] = d end
end
HOST_ECHO("label: " .. E.findGui("Etikett").Text .. " sideParts " .. #sideParts)
for _, d in ipairs(sideParts) do HOST_ECHO("  " .. d:GetFullName() .. " " .. d.ClassName .. " " .. tostring(d.Size)) end
sprayOver(sideParts, 200)
E.tap("Q"); E.tap("Q"); E.tap("Q"); E.tap("Q"); E.run(0.5) -- turn to the other side
sprayOver(sideParts, 200)
HOST_ECHO("progress after spraying the side panels: " .. tostring(E.findGui("Procent") and E.findGui("Procent").Text))
E.clickGui("^Klar"); E.run(1.5)
for _, o in ipairs(plr.PlayerGui.Hud.Notiser:GetChildren()) do local t = o:FindFirstChildOfClass("TextLabel"); if t then HOST_ECHO("toast: " .. t.Text) end end
local sid = m.slots["pan:sidaV"]
E.check("side panels saved as candy", S.profile.items[sid].paint.f == "candy")
E.check("side panel job cost money", S.profile.money < money1)
E.check("recent colours remember both", #S.profile.recentColors == 2)
-- designs
E.clickGui("Flik_Designer"); E.run(0.3)
E.typeText("Designnamn", "Röd krom"); E.run(0.2)
E.clickGui("SparaDesign"); E.run(0.8)
E.check("design saved with rims and panels", #S.profile.designs == 1 and S.profile.designs[1].zones.falgar ~= nil)
E.clickGui("Ladda_1"); E.run(1)
E.check("design loads again", S.profile.mopeds[S.profile.cur].paint.falgar.f == "chrome")
E.shot("studio_done")
E.clickGui("^Avsluta$"); E.run(1)
E.check("studio closed", S.mode == nil)

-- Paint studio on the moped (at the lift): pick a part group (front panels, side panels, rims, calipers, bars,
-- mirrors, ...), pick a colour (wheel, RGB, HEX, presets, saved, recent), a finish (solid, metallic, pearl,
-- matt, gloss, chrome, carbon look, candy) and its settings, then aim the gun and spray. The colour goes on
-- gradually where you spray, only on the chosen group. "Klar" pays and saves it in the moped's data.
-- Right mouse button turns the camera around the moped, the wheel zooms.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Shared = RS:WaitForChild("Shared")
local Paint = require(Shared.Paint)
local Models = require(Shared.Models)
local MopedDef = require(Shared.MopedDef)
local plr = Players.LocalPlayer
local S = require(script.Parent:WaitForChild("State"))
local UI = require(script.Parent:WaitForChild("UIKit"))

local gui = UI.screen("Lackstudio", 10, plr)
gui.Enabled = false
local St = { zone = nil, color = { 25, 70, 200 }, h = 0.6, s = 0.85, v = 0.8, finish = "metallic", tab = "Del", spraying = false, cover = {}, parts = {}, t = 0 }
for _, st in ipairs(Paint.SETTINGS) do St[st.id] = st.def end
local function spec() local r = { c = St.color, f = St.finish }; for _, st in ipairs(Paint.SETTINGS) do r[st.id] = St[st.id] end; return r end
local function col3() return Color3.fromRGB(St.color[1], St.color[2], St.color[3]) end

---------------------------------------------------------------- layout
local left = UI.panel(gui, UDim2.fromOffset(330, 640), UDim2.fromOffset(12, 8), { name = "Studio" })
UI.text(left, "Lackeringsstudio", UDim2.fromOffset(300, 36), UDim2.fromOffset(16, 6), { ts = 22, font = UI.BOLD })
local tabs = UI.new("Frame", { Size = UDim2.fromOffset(306, 34), Position = UDim2.fromOffset(12, 46), BackgroundTransparency = 1, Name = "Flikar" }, left)
UI.list(tabs, 4, true)
local body = UI.new("Frame", { Size = UDim2.fromOffset(306, 548), Position = UDim2.fromOffset(12, 86), BackgroundTransparency = 1, Name = "Innehåll" }, left)
local checks = UI.panel(gui, UDim2.fromOffset(250, 210), UDim2.new(1, -12, 0, 60), { anchor = Vector2.new(1, 0), name = "Moment" })
UI.pad(checks, 12, 10, 10, 10)
UI.list(checks, 4)
local prog = UI.panel(gui, UDim2.fromOffset(520, 64), UDim2.new(0.5, 80, 1, -66), { anchor = Vector2.new(0.5, 1), name = "Framsteg" })
local progLabel = UI.text(prog, "Välj en del", UDim2.fromOffset(380, 24), UDim2.fromOffset(16, 6), { ts = 17, font = UI.BOLD, name = "Etikett" })
local progPct = UI.text(prog, "", UDim2.fromOffset(80, 24), UDim2.new(1, -96, 0, 34), { ts = 19, font = UI.BOLD, xa = Enum.TextXAlignment.Right, name = "Procent" })
local _, progFill = UI.bar(prog, UDim2.new(1, -116, 0, 14), UDim2.fromOffset(16, 40), 0, col3())
local done = UI.button(gui, "Klar", UDim2.fromOffset(250, 46), UDim2.new(0.5, -50, 1, -12), { anchor = Vector2.new(0.5, 1), kind = "green", ts = 18, name = "Klar" })
local quit = UI.button(gui, "Avsluta", UDim2.fromOffset(200, 46), UDim2.new(0.5, 210, 1, -12), { anchor = Vector2.new(0.5, 1), kind = "danger", ts = 18, name = "Avsluta" })
local tip = UI.text(gui, "Håll vänster musknapp för att spraya  ·  Höger musknapp eller Q/E: vrid  ·  Rullhjul: zoom", UDim2.fromOffset(520, 20), UDim2.new(0.5, 80, 1, -134), { anchor = Vector2.new(0.5, 1), ts = 13, xa = Enum.TextXAlignment.Center, name = "Tips" })

---------------------------------------------------------------- the moped and the zone's parts
local function moped()
	local plot = S.plot()
	return plot and plot:FindFirstChild("Moped", true)
end
-- visible parts of a zone on the moped (smooth panel meshes when they exist, else the blocks)
local function zoneParts(m, zid)
	local z = Paint.ZONE[zid]
	local list = {}
	if not (m and z) then return list end
	for _, pid in ipairs(z.panels or {}) do
		local sub = m:FindFirstChild("pan:" .. pid)
		if sub then
			for _, d in ipairs(sub:GetDescendants()) do
				if d:IsA("BasePart") and d.LocalTransparencyModifier < 1 and d.Transparency < 1 then list[#list + 1] = d end
			end
		end
	end
	for _, slot in ipairs(z.slots or {}) do
		local sub = m:FindFirstChild(slot)
		if sub then
			for _, d in ipairs(sub:GetDescendants()) do
				if d:IsA("BasePart") and z.nameSet[d.Name] and d.Transparency < 1 then list[#list + 1] = d end
			end
		end
	end
	return list
end
local function hasZone(zid)
	local p = S.profile
	local m = p and p.mopeds[p.cur]
	local z = Paint.ZONE[zid]
	if not (m and z) then return false end
	for _, pid in ipairs(z.panels or {}) do if m.slots["pan:" .. pid] then return true end end
	for _, s in ipairs(z.slots or {}) do if m.slots[s] then return true end end
	return false
end
local function currentSpec(zid)
	local p = S.profile
	local m = p and p.mopeds[p.cur]
	local z = Paint.ZONE[zid]
	if not (m and z) then return nil end
	for _, pid in ipairs(z.panels or {}) do
		local it = p.items[m.slots["pan:" .. pid] or ""]
		if it and it.paint then return Paint.validSpec(it.paint) end
	end
	return m.paint and m.paint[zid] and Paint.validSpec(m.paint[zid]) or nil
end

---------------------------------------------------------------- camera: orbit around the moped
local cam = { yaw = math.rad(-125), pitch = math.rad(18), dist = 9, focus = Vector3.new() }
local function placeCam(t)
	local cf = CFrame.new(cam.focus) * CFrame.Angles(0, cam.yaw, 0) * CFrame.Angles(-cam.pitch, 0, 0) * CFrame.new(0, 0, cam.dist)
	S.camTo(CFrame.lookAt(cf.Position, cam.focus), 50, t or 0)
end
local function focusZone()
	local m = moped()
	if not m then return end
	local parts = St.zone and zoneParts(m, St.zone) or {}
	if #parts == 0 then
		cam.focus = m:GetPivot().Position + Vector3.new(0, 1.6, 0)
		cam.dist = 9
	else
		local mn, mx
		for _, p in ipairs(parts) do
			local a, b = p.Position - p.Size / 2, p.Position + p.Size / 2
			mn = mn and mn:Min(a) or a
			mx = mx and mx:Max(b) or b
		end
		cam.focus = (mn + mx) / 2
		local ext = mx - mn
		cam.dist = math.clamp(math.max(ext.X, ext.Y, ext.Z) * 2.4, 5, 10)
		-- a group on one side of the moped (one wheel, one mirror) is looked at from that side
		local mc = m:GetPivot()
		local lx = mc:PointToObjectSpace(cam.focus).X
		if math.abs(lx) > 0.25 then
			local o = mc.RightVector * (lx > 0 and 1 or -1) - mc.LookVector * 0.35 -- outwards, a little from the front
			cam.yaw = math.atan2(o.X, o.Z)
		end
	end
	placeCam(0.35)
end

---------------------------------------------------------------- spray scene: gun, hand, mist, outlines
local fx = Instance.new("Folder")
fx.Name = "StudioLokal"
local gunRig, handRig, mist, nozzle, cupPaint = {}, {}, nil, nil, nil
local outlines = {}
local function rigOf(model)
	local r = {}
	for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then d.CanQuery = false; d.CastShadow = false; r[#r + 1] = { d, d.CFrame } end end
	return r
end
local function buildFx()
	fx:ClearAllChildren()
	fx.Parent = workspace
	local gun = Instance.new("Model")
	gun.Name = "Sprutpistol"
	gun.Parent = fx
	local gmk = Models.tool(gun, "spruta", CFrame.new(), false)
	for _, p in ipairs(gmk.parts) do if p.Name == "Kopp" then p.Transparency = 0.6 end end
	cupPaint = gmk.cyl("Färg", 0.18, 0.1, CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), col3(), Enum.Material.SmoothPlastic)
	gunRig = rigOf(gun)
	local hand = Models.hand(fx, CFrame.new(), true)
	handRig = rigOf(hand)
	local mk = Models.maker(fx)
	nozzle = mk.box("Munstycke", Vector3.new(0.05, 0.05, 0.05), CFrame.new(), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	nozzle.Transparency = 1
	nozzle.CanQuery = false
	local att = Instance.new("Attachment")
	att.Parent = nozzle
	mist = Instance.new("ParticleEmitter")
	mist.Rate = 0
	mist.Lifetime = NumberRange.new(0.3, 0.6)
	mist.Speed = NumberRange.new(8, 11)
	mist.SpreadAngle = Vector2.new(12, 12)
	mist.Size = NumberSequence.new(0.15, 1.2)
	mist.Transparency = NumberSequence.new(0.35, 1)
	mist.LightEmission = 0.2
	mist.EmissionDirection = Enum.NormalId.Front
	mist.Parent = att
end
local function clearOutlines()
	for _, o in ipairs(outlines) do o:Destroy() end
	outlines = {}
end
local function outline(parts)
	clearOutlines()
	for _, r in ipairs(parts) do
		local sb = Instance.new("SelectionBox")
		sb.Name = "Markering"
		sb.Adornee = r.part
		sb.LineThickness = 0.02
		sb.Color3 = Color3.fromRGB(74, 152, 255)
		sb.SurfaceTransparency = 1
		sb.Parent = fx
		outlines[#outlines + 1] = sb
	end
end

---------------------------------------------------------------- right panel: steps and price
local refresh -- forward
local function zoneCover()
	local tot, sum = 0, 0
	for _, r in ipairs(St.parts) do
		local w = math.max(0.05, r.part.Size.Magnitude)
		tot = tot + w
		sum = sum + w * math.min(1, St.cover[r.part] or 0)
	end
	return tot > 0 and sum / tot or 0
end
local function buildChecks()
	UI.clear(checks)
	local price = St.zone and Paint.cost(St.zone, spec())
	local cov = zoneCover()
	local rows = {
		{ "Välj del", St.zone ~= nil }, { "Välj färg", St.pickedColor == true }, { "Välj lacktyp", St.pickedFinish == true },
		{ "Rikta pistolen", St.aimed == true }, { "Spraya över ytan", cov >= 0.9 },
	}
	for i, r in ipairs(rows) do
		local f = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = i, Name = r[1] }, checks)
		local mark = UI.new("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(0, 4), BackgroundColor3 = r[2] and UI.C.green or UI.C.panel, BackgroundTransparency = r[2] and 0 or 1, BorderSizePixel = 0 }, f)
		UI.corner(mark, 9)
		if r[2] then UI.text(mark, "✓", UDim2.fromScale(1, 1), nil, { ts = 13, font = UI.BOLD, xa = Enum.TextXAlignment.Center }) else UI.stroke(mark, UI.C.text, 2, 0.2) end
		UI.text(f, r[1], UDim2.new(1, -28, 1, 0), UDim2.fromOffset(28, 0), { ts = 15, font = UI.BOLD })
	end
	if price then
		UI.text(checks, string.format("Grundpris %d kr · effekter %d kr · storlek ×%.1f", price.base, price.effects, price.size), UDim2.new(1, 0, 0, 18), nil, { ts = 12, color = UI.C.dim, order = 10, name = "Prisdelar" })
		UI.text(checks, "Pris: " .. UI.kr(price.total), UDim2.new(1, 0, 0, 22), nil, { ts = 17, font = UI.BOLD, color = UI.C.green, order = 11, name = "Pris" })
	end
	done.Text = price and ("Klar – betala " .. UI.kr(price.total)) or "Klar"
	local ready = St.zone ~= nil and cov >= 0.9
	UI.setKind(done, ready and "green" or "secondary")
	done.AutoButtonColor = ready
end

---------------------------------------------------------------- tabs
local TABS = { "Del", "Färg", "Lack", "Designer" }
local function slider(parent, label, y, value, onChange, name)
	UI.text(parent, label, UDim2.fromOffset(130, 20), UDim2.fromOffset(0, y), { ts = 14 })
	local bar = UI.new("Frame", { Size = UDim2.fromOffset(120, 8), Position = UDim2.fromOffset(136, y + 6), BackgroundColor3 = UI.C.panel2, BorderSizePixel = 0, Name = name or label, Active = true }, parent)
	UI.corner(bar, 4)
	local fill = UI.new("Frame", { Size = UDim2.fromScale(value, 1), BackgroundColor3 = UI.C.accent, BorderSizePixel = 0 }, bar)
	UI.corner(fill, 4)
	local knob = UI.new("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(value, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, bar)
	UI.corner(knob, 7)
	local val = UI.text(parent, tostring(math.floor(value * 100 + 0.5)), UDim2.fromOffset(40, 20), UDim2.fromOffset(264, y), { ts = 13, xa = Enum.TextXAlignment.Right })
	local function set(x)
		x = math.clamp(x, 0, 1)
		fill.Size = UDim2.fromScale(x, 1)
		knob.Position = UDim2.fromScale(x, 0.5)
		val.Text = tostring(math.floor(x * 100 + 0.5))
		onChange(x)
	end
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			St.drag = function(mx) set((mx - bar.AbsolutePosition.X) / bar.AbsoluteSize.X) end
			St.drag(UIS:GetMouseLocation().X)
		end
	end)
	return bar
end
local function swatch(parent, c, order, onClick, name)
	local b = UI.new("TextButton", { Size = UDim2.fromOffset(28, 28), BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3]), Text = "", AutoButtonColor = true, LayoutOrder = order, Name = name or Paint.hex(c) }, parent)
	UI.corner(b, 6)
	local same = c[1] == St.color[1] and c[2] == St.color[2] and c[3] == St.color[3]
	UI.stroke(b, same and Color3.new(1, 1, 1) or UI.C.line, same and 2 or 1, same and 0 or 0.3)
	b.Activated:Connect(onClick)
	return b
end
local function setColor(c)
	St.color = { c[1], c[2], c[3] }
	local h, s, v = Color3.fromRGB(c[1], c[2], c[3]):ToHSV()
	if s > 0.01 then St.h = h end
	St.s, St.v = s, v
	St.pickedColor = true
	refresh()
end
local function setHSV()
	local c = Color3.fromHSV(St.h, St.s, St.v)
	St.color = { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
	St.pickedColor = true
end

local function tabDel()
	UI.text(body, "Välj vilken del som ska lackeras", UDim2.fromOffset(300, 20), UDim2.fromOffset(0, 0), { ts = 14, color = UI.C.dim })
	local list = UI.new("Frame", { Size = UDim2.fromOffset(306, 440), Position = UDim2.fromOffset(0, 26), BackgroundTransparency = 1 }, body)
	UI.list(list, 4)
	for i, z in ipairs(Paint.ZONES) do
		local ok = hasZone(z.id)
		local on = St.zone == z.id
		local b = UI.button(list, "", UDim2.new(1, 0, 0, 38), nil, { kind = on and "primary" or "secondary", order = i, name = "Zon_" .. z.id }, function()
			if not ok then S.toast(z.n .. " sitter inte på mopeden", "info"); return end
			St.select(z.id)
		end)
		local sp = currentSpec(z.id)
		local sw = UI.new("Frame", { Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(10, 8), BackgroundColor3 = sp and Color3.fromRGB(sp.c[1], sp.c[2], sp.c[3]) or UI.C.panel, BorderSizePixel = 0 }, b)
		UI.corner(sw, 5)
		UI.stroke(sw, UI.C.line, 1, 0.3)
		UI.text(b, z.n, UDim2.fromOffset(170, 38), UDim2.fromOffset(42, 0), { ts = 15, font = UI.BOLD, color = ok and UI.C.text or UI.C.dim })
		UI.text(b, ok and (sp and Paint.FIN[sp.f].n or "Original") or "saknas", UDim2.fromOffset(90, 38), UDim2.new(1, -100, 0, 0), { ts = 12, color = UI.C.dim, xa = Enum.TextXAlignment.Right })
	end
	UI.button(body, "Lös kåpa i lackboxen →", UDim2.fromOffset(306, 36), UDim2.fromOffset(0, 474), { kind = "ghost", ts = 14, name = "Lackbox" }, function()
		S.endMode("studio")
		S.open:Fire("paint")
	end)
end

-- colour wheel built from small frames: hue round the circle, saturation outwards (made once, reused)
local wheelDots = {}
local function tabFarg()
	local R = 70
	local wheel = UI.new("Frame", { Size = UDim2.fromOffset(R * 2, R * 2), Position = UDim2.fromOffset(4, 0), BackgroundTransparency = 1, Name = "Färghjul", Active = true }, body)
	wheelDots = {}
	for ring = 1, 6 do
		local sat = ring / 6
		local n = 6 + ring * 6
		local size = 13
		for k = 0, n - 1 do
			local hue = k / n
			local a = hue * math.pi * 2
			local r = sat * (R - 7)
			local d = UI.new("Frame", { Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(R + math.cos(a) * r, R - math.sin(a) * r), BackgroundColor3 = Color3.fromHSV(hue, sat, St.v), BorderSizePixel = 0 }, wheel)
			UI.corner(d, size / 2)
			wheelDots[#wheelDots + 1] = { d, hue, sat }
		end
	end
	local centre = UI.new("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(R, R), BackgroundColor3 = Color3.fromHSV(0, 0, St.v), BorderSizePixel = 0 }, wheel)
	UI.corner(centre, 7)
	local mark = UI.new("Frame", { Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(R + math.cos(St.h * math.pi * 2) * St.s * (R - 7), R - math.sin(St.h * math.pi * 2) * St.s * (R - 7)), BackgroundTransparency = 1, ZIndex = 3, Name = "Markör" }, wheel)
	UI.corner(mark, 8)
	UI.stroke(mark, Color3.new(1, 1, 1), 2, 0)
	wheel.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			St.drag = function(mx, my)
				local cx, cy = wheel.AbsolutePosition.X + R, wheel.AbsolutePosition.Y + R
				local dx, dy = mx - cx, -(my - cy)
				St.h = (math.atan2(dy, dx) / (math.pi * 2)) % 1
				St.s = math.clamp(math.sqrt(dx * dx + dy * dy) / (R - 7), 0, 1)
				setHSV()
				refresh()
			end
			local m = UIS:GetMouseLocation()
			St.drag(m.X, m.Y - game:GetService("GuiService"):GetGuiInset().Y)
		end
	end)
	-- big preview + brightness
	local prev = UI.new("Frame", { Size = UDim2.fromOffset(140, 60), Position = UDim2.fromOffset(160, 0), BackgroundColor3 = col3(), BorderSizePixel = 0, Name = "Förhandsvisning" }, body)
	UI.corner(prev, 8)
	local holder = UI.new("Frame", { Size = UDim2.fromOffset(306, 100), Position = UDim2.fromOffset(0, 146), BackgroundTransparency = 1 }, body)
	slider(holder, "Ljushet", 0, St.v, function(x) St.v = x; setHSV(); St.dirty = true end, "Ljushet")
	slider(holder, "R", 24, St.color[1] / 255, function(x) St.color[1] = math.floor(x * 255 + 0.5); St.pickedColor = true; St.dirty = true end, "R")
	slider(holder, "G", 48, St.color[2] / 255, function(x) St.color[2] = math.floor(x * 255 + 0.5); St.pickedColor = true; St.dirty = true end, "G")
	slider(holder, "B", 72, St.color[3] / 255, function(x) St.color[3] = math.floor(x * 255 + 0.5); St.pickedColor = true; St.dirty = true end, "B")
	UI.text(body, "HEX:", UDim2.fromOffset(44, 28), UDim2.fromOffset(160, 70), { ts = 15, font = UI.BOLD })
	local hex = UI.new("TextBox", { Size = UDim2.fromOffset(96, 28), Position = UDim2.fromOffset(204, 70), BackgroundColor3 = UI.C.panel2, TextColor3 = UI.C.text, Font = UI.FONT, TextSize = 15, ClearTextOnFocus = false, Text = Paint.hex(St.color), Name = "HEX" }, body)
	UI.corner(hex, 6)
	hex.FocusLost:Connect(function()
		local c = Paint.validHex(hex.Text)
		if c then setColor(c) else S.toast("Skriv HEX som #RRGGBB", "error"); refresh() end
	end)
	UI.text(body, "Förinställda", UDim2.fromOffset(300, 18), UDim2.fromOffset(0, 252), { ts = 13, font = UI.BOLD })
	local pre = UI.new("Frame", { Size = UDim2.fromOffset(306, 64), Position = UDim2.fromOffset(0, 272), BackgroundTransparency = 1, Name = "Förinställda" }, body)
	UI.grid(pre, UDim2.fromOffset(28, 28), UDim2.fromOffset(6, 6))
	for i, l in ipairs(Paint.LIBRARY) do swatch(pre, l.c, i, function() setColor(l.c) end, l.n) end
	UI.text(body, "Sparade", UDim2.fromOffset(200, 18), UDim2.fromOffset(0, 344), { ts = 13, font = UI.BOLD })
	UI.button(body, "+ Spara färg", UDim2.fromOffset(110, 22), UDim2.fromOffset(196, 342), { kind = "secondary", ts = 12, name = "SparaFärg" }, function()
		if S.api("saveColor", St.color) then S.toast("Färgen sparad", "ok") end
	end)
	local saved = UI.new("Frame", { Size = UDim2.fromOffset(306, 64), Position = UDim2.fromOffset(0, 368), BackgroundTransparency = 1, Name = "Sparade" }, body)
	UI.grid(saved, UDim2.fromOffset(28, 28), UDim2.fromOffset(6, 6))
	for i, c in ipairs(S.profile and S.profile.savedColors or {}) do swatch(saved, c, i, function() setColor(c) end) end
	if #(S.profile and S.profile.savedColors or {}) == 0 then UI.text(saved, "Inga sparade färger än", UDim2.fromOffset(300, 28), nil, { ts = 12, color = UI.C.dim }) end
	UI.text(body, "Senast använda", UDim2.fromOffset(300, 18), UDim2.fromOffset(0, 440), { ts = 13, font = UI.BOLD })
	local recent = UI.new("Frame", { Size = UDim2.fromOffset(306, 34), Position = UDim2.fromOffset(0, 462), BackgroundTransparency = 1, Name = "Senaste" }, body)
	UI.grid(recent, UDim2.fromOffset(28, 28), UDim2.fromOffset(6, 6))
	for i, c in ipairs(S.profile and S.profile.recentColors or {}) do swatch(recent, c, i, function() setColor(c) end) end
	if #(S.profile and S.profile.recentColors or {}) == 0 then UI.text(recent, "Inga än", UDim2.fromOffset(300, 28), nil, { ts = 12, color = UI.C.dim }) end
end

local function tabLack()
	UI.text(body, "Lacktyp", UDim2.fromOffset(300, 20), UDim2.fromOffset(0, 0), { ts = 15, font = UI.BOLD })
	local grid = UI.new("Frame", { Size = UDim2.fromOffset(306, 140), Position = UDim2.fromOffset(0, 24), BackgroundTransparency = 1, Name = "Lacktyper" }, body)
	UI.grid(grid, UDim2.fromOffset(150, 30), UDim2.fromOffset(6, 4))
	for i, f in ipairs(Paint.FINISH) do
		local on = St.finish == f.id
		local b = UI.button(grid, "", UDim2.fromOffset(150, 30), nil, { kind = on and "primary" or "secondary", order = i, name = "Lack_" .. f.id }, function()
			St.finish = f.id
			St.pickedFinish = true
			refresh()
		end)
		UI.text(b, f.n, UDim2.fromOffset(96, 30), UDim2.fromOffset(10, 0), { ts = 14, font = on and UI.BOLD or UI.FONT })
		UI.text(b, f.price .. " kr", UDim2.fromOffset(44, 30), UDim2.new(1, -50, 0, 0), { ts = 12, color = on and UI.C.text or UI.C.dim, xa = Enum.TextXAlignment.Right })
	end
	UI.text(body, "Inställningar", UDim2.fromOffset(300, 20), UDim2.fromOffset(0, 172), { ts = 15, font = UI.BOLD })
	local holder = UI.new("Frame", { Size = UDim2.fromOffset(306, 130), Position = UDim2.fromOffset(0, 198), BackgroundTransparency = 1 }, body)
	for i, st in ipairs(Paint.SETTINGS) do
		slider(holder, st.n, (i - 1) * 26, St[st.id], function(x) St[st.id] = x; St.dirty = true end, st.id)
	end
	-- a sample of the finish with these settings, on a real part in a viewport
	local sample = Instance.new("Model")
	local mk = Models.maker(sample)
	local ball = mk.ball("Prov", 1.6, CFrame.new())
	Paint.apply(ball, spec())
	St.sample = ball
	UI.viewport(body, sample, UDim2.fromOffset(306, 140), UDim2.fromOffset(0, 336), { bg = Color3.fromRGB(60, 64, 72), zoom = 1.1 })
	local f = Paint.FIN[St.finish]
	UI.text(body, f.n .. ": " .. ({ solid = "jämn färg, lite glans", metallic = "metallflakes, starkare reflex", pearl = "ljus skimrande yta", matt = "ingen glans alls", glossy = "blank klarlack", chrome = "spegelblank metall", carbon = "vävd mörk yta under klarlack", candy = "djup genomskinlig färg" })[f.id], UDim2.fromOffset(306, 40), UDim2.fromOffset(0, 482), { ts = 13, color = UI.C.dim, wrap = true })
end

local function tabDesigner()
	UI.text(body, "Spara alla färger och lacker på mopeden som en design och lägg på dem igen senare.", UDim2.fromOffset(306, 40), UDim2.fromOffset(0, 0), { ts = 13, color = UI.C.dim, wrap = true })
	local name = UI.new("TextBox", { Size = UDim2.fromOffset(196, 32), Position = UDim2.fromOffset(0, 46), BackgroundColor3 = UI.C.panel2, TextColor3 = UI.C.text, PlaceholderText = "Namn på designen", Font = UI.FONT, TextSize = 14, Text = "", ClearTextOnFocus = false, Name = "Designnamn" }, body)
	UI.corner(name, 6)
	UI.button(body, "Spara design", UDim2.fromOffset(104, 32), UDim2.fromOffset(202, 46), { kind = "primary", ts = 13, name = "SparaDesign" }, function()
		if S.api("saveDesign", name.Text) then S.toast("Designen sparad", "ok") end
	end)
	local list = UI.scroll(body, UDim2.fromOffset(306, 400), UDim2.fromOffset(0, 90), { name = "Designer" })
	UI.list(list, 6)
	local p = S.profile
	for i, d in ipairs(p and p.designs or {}) do
		local row = UI.panel(list, UDim2.new(1, -8, 0, 48), nil, { color = UI.C.panel2, transp = 0 })
		row.LayoutOrder = i
		local n = 0
		for _ in pairs(d.panels or {}) do n = n + 1 end
		for _ in pairs(d.zones or {}) do n = n + 1 end
		UI.text(row, d.n, UDim2.fromOffset(170, 24), UDim2.fromOffset(10, 2), { ts = 15, font = UI.BOLD })
		UI.text(row, (MopedDef.MODELS[d.model] and MopedDef.MODELS[d.model].n or d.model) .. " · " .. n .. " delar", UDim2.fromOffset(180, 18), UDim2.fromOffset(10, 26), { ts = 12, color = UI.C.dim })
		UI.button(row, "Ladda", UDim2.fromOffset(80, 32), UDim2.new(1, -90, 0, 8), { kind = "green", ts = 13, name = "Ladda_" .. i }, function()
			local ok, cost = S.api("applyDesign", i)
			if ok then S.toast("Designen är pålagd (" .. UI.kr(cost) .. ")", "ok") end
		end)
	end
	if not (p and #p.designs > 0) then UI.text(list, "Inga designer än", UDim2.new(1, 0, 0, 24), nil, { ts = 13, color = UI.C.dim }) end
end

local function buildTabs()
	UI.clear(tabs)
	for i, t in ipairs(TABS) do
		UI.button(tabs, t, UDim2.fromOffset(72, 32), nil, { kind = St.tab == t and "primary" or "secondary", ts = 14, order = i, name = "Flik_" .. t }, function()
			St.tab = t
			refresh()
		end)
	end
end
refresh = function()
	if not gui.Enabled then return end
	buildTabs()
	UI.clear(body)
	St.sample = nil
	if St.tab == "Del" then tabDel() elseif St.tab == "Färg" then tabFarg() elseif St.tab == "Lack" then tabLack() else tabDesigner() end
	if cupPaint then cupPaint.Color = col3() end
	progFill.BackgroundColor3 = col3()
	buildChecks()
end

---------------------------------------------------------------- choosing a zone starts a paint job on it
local function restoreParts()
	for _, r in ipairs(St.parts) do
		if r.part.Parent then r.part.Color, r.part.Material, r.part.Reflectance, r.part.CanQuery = r.c, r.m, r.r, r.q end
	end
	St.parts, St.cover = {}, {}
end
function St.select(zid)
	restoreParts()
	local ok = S.api("studioStart", zid)
	if not ok then return end
	St.zone = zid
	St.t = 0
	St.aimed = false
	local m = moped()
	for _, p in ipairs(zoneParts(m, zid)) do
		St.parts[#St.parts + 1] = { part = p, c = p.Color, m = p.Material, r = p.Reflectance, q = p.CanQuery }
		p.CanQuery = true -- the smooth panels are not hit by rays normally; the spray must hit them
	end
	local cur = currentSpec(zid)
	if cur and not St.pickedColor then
		St.color = { cur.c[1], cur.c[2], cur.c[3] }
		local h, s, v = Color3.fromRGB(cur.c[1], cur.c[2], cur.c[3]):ToHSV()
		St.h, St.s, St.v = h, s, v
	end
	outline(St.parts)
	focusZone()
	progLabel.Text = "Lackar " .. Paint.ZONE[zid].n .. "..."
	refresh()
end
-- the paint shows gradually: each part blends from its old look to the new one as it gets covered
local function showCover()
	local col, mat, refl = Paint.look(spec())
	for _, r in ipairs(St.parts) do
		local c = math.min(1, St.cover[r.part] or 0)
		if r.part.Parent then
			r.part.Color = r.c:Lerp(col, c)
			r.part.Material = c > 0.5 and mat or r.m
			r.part.Reflectance = r.r + (refl - r.r) * c
		end
	end
	local cov = zoneCover()
	progFill.Size = UDim2.fromScale(cov, 1)
	progPct.Text = math.floor(cov * 100) .. "%"
end

done.Activated:Connect(function()
	if not St.zone then S.toast("Välj en del först", "info"); return end
	local cov = zoneCover()
	if cov < 0.9 then S.toast("Spraya hela delen först (" .. math.floor(cov * 100) .. " %)", "info"); return end
	local ok, price = S.api("studioDone", St.zone, spec(), cov)
	if ok then
		S.toast(Paint.ZONE[St.zone].n .. " lackerad: " .. Paint.FIN[St.finish].n .. " (" .. UI.kr(price.total) .. ")", "ok")
		St.parts, St.cover = {}, {} -- the moped is rebuilt with the new paint
		clearOutlines()
		St.zone = nil
		progLabel.Text = "Välj nästa del"
		progFill.Size = UDim2.fromScale(0, 1)
		progPct.Text = ""
		St.tab = "Del"
		task.delay(0.3, refresh)
	end
end)
quit.Activated:Connect(function() S.endMode("studio") end)

---------------------------------------------------------------- open / close
local function open()
	if not S.setMode("studio") then return end
	gui.Enabled = true
	St.zone, St.parts, St.cover, St.tab = nil, {}, {}, "Del"
	St.pickedColor, St.pickedFinish, St.aimed = false, false, false
	buildFx()
	local m = moped()
	if m then
		cam.focus = m:GetPivot().Position + Vector3.new(0, 1.6, 0)
		cam.dist, cam.yaw, cam.pitch = 9, math.rad(-125), math.rad(18)
		placeCam(0.4)
	end
	progLabel.Text = "Välj en del"
	progPct.Text = ""
	progFill.Size = UDim2.fromScale(0, 1)
	refresh()
end
local function close()
	gui.Enabled = false
	St.spraying = false
	restoreParts()
	clearOutlines()
	fx:ClearAllChildren()
	fx.Parent = nil
	task.spawn(function() S.api("workCancel") end)
end
S.open.Event:Connect(function(what, atStation) if what == "studio" and atStation then open() end end)
S.modeEv.Event:Connect(function(mode) if mode ~= "studio" and gui.Enabled then close() end end)

---------------------------------------------------------------- input: spray, orbit, zoom, slider drags
UIS.InputBegan:Connect(function(input, gp)
	if S.mode ~= "studio" then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and (not gp or not S.mouseOverUi()) then
		if St.zone then St.spraying = true else S.toast("Välj en del att lackera först", "info") end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		St.orbit = true
	elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.E then
		cam.yaw = cam.yaw + (input.KeyCode == Enum.KeyCode.Q and 1 or -1) * math.rad(45)
		placeCam(0.25)
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		St.spraying = false
		if St.drag then St.drag = nil; refresh() end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		St.orbit = false
	end
end)
UIS.InputChanged:Connect(function(input, gp)
	if S.mode ~= "studio" then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel and not gp then
		cam.dist = math.clamp(cam.dist - input.Position.Z * 0.6, 3, 14)
		placeCam(0)
	elseif input.UserInputType == Enum.UserInputType.MouseMovement then
		if St.drag then
			local m = UIS:GetMouseLocation()
			St.drag(m.X, m.Y - game:GetService("GuiService"):GetGuiInset().Y)
		elseif St.orbit then
			cam.yaw = cam.yaw - input.Delta.X * 0.008
			cam.pitch = math.clamp(cam.pitch + input.Delta.Y * 0.006, math.rad(-10), math.rad(70))
			placeCam(0)
		end
	end
end)

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	if S.mode ~= "studio" or not mist then return end
	if St.spraying and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then St.spraying = false end
	if St.dirty then
		St.dirty = false
		if St.sample then Paint.apply(St.sample, spec()) end
		if cupPaint then cupPaint.Color = col3() end
		progFill.BackgroundColor3 = col3()
	end
	local camera = workspace.CurrentCamera
	local m = UIS:GetMouseLocation()
	local ray = camera:ViewportPointToRay(m.X, m.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local inc = {}
	for _, r in ipairs(St.parts) do inc[#inc + 1] = r.part end
	params.FilterDescendantsInstances = inc
	local res = #inc > 0 and workspace:Raycast(ray.Origin, ray.Direction * 40, params) or nil
	local aim = res and res.Position or (ray.Origin + ray.Direction * math.max(3, cam.dist - 1))
	if res then St.aimed = true end
	-- the gun sits low on the right, nozzle towards the aim point
	local gunPos = camera.CFrame.Position + camera.CFrame.LookVector * 2.6 + camera.CFrame.RightVector * 1.15 - camera.CFrame.UpVector * 0.75
	local gunCF = CFrame.lookAt(gunPos, aim)
	for _, r in ipairs(gunRig) do r[1].CFrame = gunCF * r[2] end
	local handCF = gunCF * CFrame.new(0, -0.34, 0.16) * CFrame.Angles(math.rad(78), 0, 0)
	for _, r in ipairs(handRig) do r[1].CFrame = handCF * r[2] end
	nozzle.CFrame = gunCF * CFrame.new(0, 0.03, -0.32)
	mist.Color = ColorSequence.new(col3())
	mist.Rate = St.spraying and 160 or 0
	if St.spraying and St.zone then
		St.t = St.t + dt
		if res then
			-- paint lands around the hit point: parts close to it get covered, the hit part fastest
			for _, r in ipairs(St.parts) do
				local p = r.part
				local rel = p.CFrame:PointToObjectSpace(res.Position)
				local half = p.Size / 2
				local q = Vector3.new(math.clamp(rel.X, -half.X, half.X), math.clamp(rel.Y, -half.Y, half.Y), math.clamp(rel.Z, -half.Z, half.Z))
				local d = (rel - q).Magnitude
				local rate = (p == res.Instance and 1.1 or 0.8) / math.max(0.6, math.sqrt(p.Size.Magnitude))
				if d < 0.7 then St.cover[p] = (St.cover[p] or 0) + dt * rate * 1.8 * (1 - d / 0.7) end
			end
		end
		acc = acc + dt
		if acc > 0.1 then
			acc = 0
			showCover()
			local cov = zoneCover()
			if (cov >= 0.9) ~= (St.lastReady == true) then St.lastReady = cov >= 0.9; buildChecks() end
		end
	end
end)
S.changed.Event:Connect(function() if gui.Enabled and not St.drag and not St.spraying then refresh() end end)

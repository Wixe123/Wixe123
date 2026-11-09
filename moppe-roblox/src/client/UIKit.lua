-- Small UI toolkit: dark rounded panels, blue buttons, green money, product pictures in ViewportFrames.
-- Everything is designed for 1280x720 and scaled with UIScale on other screen sizes.
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(RS:WaitForChild("Shared"):WaitForChild("Config"))
local UI = {}

local function c3(t) return Color3.fromRGB(t[1], t[2], t[3]) end
UI.C = {}
for k, v in pairs(Config.UI) do UI.C[k] = c3(v) end
UI.FONT = Enum.Font.GothamMedium
UI.BOLD = Enum.Font.GothamBold
UI.BLACK = Enum.Font.GothamBlack

function UI.new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
function UI.corner(o, r) return UI.new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o) end
function UI.stroke(o, color, thick, transp)
	return UI.new("UIStroke", { Color = color or UI.C.line, Thickness = thick or 1, Transparency = transp or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
function UI.pad(o, l, r, t, b)
	return UI.new("UIPadding", { PaddingLeft = UDim.new(0, l or 8), PaddingRight = UDim.new(0, r or l or 8), PaddingTop = UDim.new(0, t or l or 8), PaddingBottom = UDim.new(0, b or t or l or 8) }, o)
end
function UI.list(o, padding, horizontal, align)
	return UI.new("UIListLayout", {
		Padding = UDim.new(0, padding or 6), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = horizontal and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top,
	}, o)
end
function UI.grid(o, cell, gap)
	return UI.new("UIGridLayout", { CellSize = cell, CellPadding = gap or UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, o)
end

-- a ScreenGui that scales with the screen
function UI.screen(name, order, player)
	local gui = UI.new("ScreenGui", { Name = name, ResetOnSpawn = false, DisplayOrder = order or 0, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = false })
	local scale = UI.new("UIScale", {}, gui)
	local function fit()
		local cam = workspace.CurrentCamera
		local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(v.X / 1280, (v.Y - 58) / 662), 0.7, 1.6)
	end
	fit()
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function UI.panel(parent, size, pos, opts)
	opts = opts or {}
	local f = UI.new("Frame", {
		Size = size, Position = pos or UDim2.new(), AnchorPoint = opts.anchor or Vector2.new(0, 0),
		BackgroundColor3 = opts.color or UI.C.panel, BackgroundTransparency = opts.transp or 0.08, BorderSizePixel = 0,
		Name = opts.name or "Panel", ZIndex = opts.z or 1, Visible = opts.visible ~= false, ClipsDescendants = opts.clip or false,
	}, parent)
	UI.corner(f, opts.radius or 10)
	if opts.stroke ~= false then UI.stroke(f, UI.C.line, 1, 0.4) end
	return f
end
function UI.text(parent, text, size, pos, opts)
	opts = opts or {}
	local l = UI.new("TextLabel", {
		Size = size, Position = pos or UDim2.new(), AnchorPoint = opts.anchor or Vector2.new(0, 0), BackgroundTransparency = 1,
		Text = text, TextColor3 = opts.color or UI.C.text, TextSize = opts.ts or 16, Font = opts.font or UI.FONT,
		TextXAlignment = opts.xa or Enum.TextXAlignment.Left, TextYAlignment = opts.ya or Enum.TextYAlignment.Center,
		TextWrapped = opts.wrap or false, RichText = opts.rich or false, Name = opts.name or "Text", ZIndex = opts.z or 1,
		LayoutOrder = opts.order or 0, TextTruncate = opts.truncate and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None,
	}, parent)
	if opts.scaled then l.TextScaled = true end
	return l
end
local KINDS = {
	primary = { bg = "accent", fg = "text" }, secondary = { bg = "panel2", fg = "text" }, green = { bg = "green", fg = "text" },
	danger = { bg = "red", fg = "text" }, ghost = { bg = "panel", fg = "text" }, yellow = { bg = "yellow", fg = "panel" },
}
function UI.button(parent, text, size, pos, opts, onClick)
	opts = opts or {}
	local k = KINDS[opts.kind or "primary"]
	local b = UI.new("TextButton", {
		Size = size, Position = pos or UDim2.new(), AnchorPoint = opts.anchor or Vector2.new(0, 0),
		BackgroundColor3 = UI.C[k.bg], BackgroundTransparency = opts.transp or 0, BorderSizePixel = 0, AutoButtonColor = true,
		Text = text, TextColor3 = UI.C[k.fg], TextSize = opts.ts or 16, Font = opts.font or UI.BOLD, Name = opts.name or text,
		TextXAlignment = opts.xa or Enum.TextXAlignment.Center, ZIndex = opts.z or 1, LayoutOrder = opts.order or 0,
	}, parent)
	UI.corner(b, opts.radius or 8)
	if opts.xa == Enum.TextXAlignment.Left then UI.pad(b, 12, 8, 0, 0) end
	if onClick then b.Activated:Connect(onClick) end
	return b
end
function UI.setKind(b, kind)
	local k = KINDS[kind]
	b.BackgroundColor3 = UI.C[k.bg]
	b.TextColor3 = UI.C[k.fg]
end
function UI.scroll(parent, size, pos, opts)
	opts = opts or {}
	local s = UI.new("ScrollingFrame", {
		Size = size, Position = pos or UDim2.new(), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, ScrollBarImageColor3 = UI.C.dim, CanvasSize = UDim2.new(), AutomaticCanvasSize = opts.horizontal and Enum.AutomaticSize.X or Enum.AutomaticSize.Y,
		ScrollingDirection = opts.horizontal and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y, Name = opts.name or "Scroll", ZIndex = opts.z or 1,
	}, parent)
	return s
end
function UI.clear(o)
	for _, c in ipairs(o:GetChildren()) do
		if not (c:IsA("UIListLayout") or c:IsA("UIGridLayout") or c:IsA("UIPadding") or c:IsA("UICorner") or c:IsA("UIStroke") or c:IsA("UIScale")) then c:Destroy() end
	end
end

-- "125 750 kr"
function UI.kr(n)
	n = math.floor((n or 0) + 0.5)
	local s = tostring(math.abs(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
	return (n < 0 and "-" or "") .. out .. " kr"
end
function UI.time(sec)
	sec = math.max(0, math.floor(sec + 0.5))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- product picture: a model in a ViewportFrame, framed by its bounding box
function UI.viewport(parent, model, size, pos, opts)
	opts = opts or {}
	local vf = UI.new("ViewportFrame", {
		Size = size, Position = pos or UDim2.new(), BackgroundColor3 = opts.bg or Color3.fromRGB(235, 237, 240), BackgroundTransparency = opts.bgT or 0,
		Ambient = Color3.fromRGB(205, 205, 210), LightColor = Color3.fromRGB(255, 252, 245), LightDirection = Vector3.new(-1, -1.4, -0.8),
		BorderSizePixel = 0, Name = "Bild", ZIndex = opts.z or 1, LayoutOrder = opts.order or 0,
	}, parent)
	UI.corner(vf, opts.radius or 8)
	model.Parent = vf
	local cf, sz = model:GetBoundingBox()
	local cam = UI.new("Camera", { FieldOfView = 30 }, vf)
	local r = sz.Magnitude / 2
	local dist = r / math.tan(math.rad(15)) * (opts.zoom or 1.05)
	local dir = (opts.dir or Vector3.new(-1, 0.65, -1.2)).Unit
	cam.CFrame = CFrame.lookAt(cf.Position + dir * dist, cf.Position)
	vf.CurrentCamera = cam
	return vf, cam
end

-- tween helper
function UI.tween(o, t, props, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- header bar with a title and a close button (used by every big window)
function UI.header(parent, title, onClose)
	local bar = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = UI.C.panel2, BorderSizePixel = 0, Name = "Rubrik" }, parent)
	UI.corner(bar, 10)
	UI.text(bar, title, UDim2.new(1, -60, 1, 0), UDim2.fromOffset(16, 0), { font = UI.BOLD, ts = 18, name = "Titel" })
	if onClose then
		UI.button(bar, "X", UDim2.fromOffset(32, 32), UDim2.new(1, -38, 0, 6), { kind = "secondary", name = "Stäng" }, onClose)
	end
	return bar
end

-- check mark row: "✓ Vevhus"
function UI.check(parent, text, done, order, active)
	local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = active and UI.C.accent or UI.C.panel2, BackgroundTransparency = active and 0.2 or 1, BorderSizePixel = 0, LayoutOrder = order or 0, Name = text }, parent)
	UI.corner(row, 6)
	UI.text(row, text, UDim2.new(1, -36, 1, 0), UDim2.fromOffset(10, 0), { ts = 14, color = done and UI.C.text or UI.C.dim, font = active and UI.BOLD or UI.FONT })
	local box = UI.new("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -26, 0.5, -9), BackgroundColor3 = done and UI.C.green or UI.C.panel, BorderSizePixel = 0, Name = "Bock" }, row)
	UI.corner(box, 4)
	if done then UI.text(box, "✓", UDim2.fromScale(1, 1), nil, { xa = Enum.TextXAlignment.Center, font = UI.BOLD, ts = 14 }) else UI.stroke(box, UI.C.line, 1, 0) end
	return row
end

-- a horizontal bar 0..1
function UI.bar(parent, size, pos, value, color)
	local bg = UI.new("Frame", { Size = size, Position = pos or UDim2.new(), BackgroundColor3 = UI.C.panel2, BorderSizePixel = 0, Name = "Stapel" }, parent)
	UI.corner(bg, 4)
	local fill = UI.new("Frame", { Size = UDim2.fromScale(math.clamp(value or 0, 0, 1), 1), BackgroundColor3 = color or UI.C.green, BorderSizePixel = 0, Name = "Fyllning" }, bg)
	UI.corner(fill, 4)
	return bg, fill
end

return UI

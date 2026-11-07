-- GUI layout (UDim2, anchors, UIListLayout, UIGridLayout, UIPadding, constraints, scrolling) and the snapshot
-- that the renderer turns into a picture. AbsolutePosition/AbsoluteSize come from the same layout.
local E = EMU_REQUIRE("services")
local T = E.T
local V2, V3, CF = T.Vector2, T.Vector3, T.CFrame
local M, G, D, S = E.METHODS, E.GETTERS, E.DEFAULTS, E.SETTERS
local function cls(t, c) t[c] = t[c] or {}; return t[c] end

D.GuiObject = {
	Visible = true, Active = false, BackgroundTransparency = 0, BackgroundColor3 = T.Color3.fromRGB(163, 162, 165), BorderSizePixel = 1,
	BorderColor3 = T.Color3.fromRGB(27, 42, 53), Size = T.UDim2.new(0, 100, 0, 100), ZIndex = 1, LayoutOrder = 0, ClipsDescendants = false,
	Selectable = false, Interactable = true,
}
D.GuiButton = { AutoButtonColor = true, Active = true, Selectable = true, Modal = false }
D.TextLabel = { Text = "Label", TextColor3 = T.Color3.fromRGB(27, 42, 53), TextSize = 14, TextTransparency = 0, TextStrokeTransparency = 1, Size = T.UDim2.new(0, 200, 0, 50), Font = function() return E.enumItem("Font", "Legacy") end }
D.TextButton = { Text = "Button", TextColor3 = T.Color3.fromRGB(27, 42, 53), TextSize = 14, TextTransparency = 0, TextStrokeTransparency = 1, Size = T.UDim2.new(0, 200, 0, 50), Font = function() return E.enumItem("Font", "Legacy") end }
D.TextBox = { Text = "TextBox", TextColor3 = T.Color3.fromRGB(27, 42, 53), TextSize = 14, TextTransparency = 0, TextStrokeTransparency = 1, Size = T.UDim2.new(0, 200, 0, 50), ClearTextOnFocus = true, TextEditable = true, Font = function() return E.enumItem("Font", "Legacy") end, PlaceholderColor3 = T.Color3.fromRGB(178, 178, 178) }
for _, k in ipairs({ "TextLabel", "TextButton", "TextBox" }) do
	D[k].TextXAlignment = function() return E.enumItem("TextXAlignment", "Center") end
	D[k].TextYAlignment = function() return E.enumItem("TextYAlignment", "Center") end
end
D.ImageLabel = { ImageTransparency = 0, ImageColor3 = T.Color3.new(1, 1, 1) }
D.ImageButton = { ImageTransparency = 0, ImageColor3 = T.Color3.new(1, 1, 1) }
D.ScrollingFrame = { ScrollingEnabled = true, ScrollBarThickness = 12, CanvasSize = T.UDim2.new(0, 0, 2, 0), ClipsDescendants = true, ScrollBarImageColor3 = T.Color3.new(0, 0, 0), ScrollBarImageTransparency = 0 }
D.LayerCollector = { Enabled = true, ResetOnSpawn = true }
D.ScreenGui = { DisplayOrder = 0, IgnoreGuiInset = false, ZIndexBehavior = function() return E.enumItem("ZIndexBehavior", "Sibling") end }
D.SurfaceGui = { PixelsPerStud = 50, SizingMode = function() return E.enumItem("SurfaceGuiSizingMode", "FixedSize") end, CanvasSize = V2.new(800, 600), Face = function() return E.enumItem("NormalId", "Front") end, Brightness = 1, LightInfluence = 1, AlwaysOnTop = false }
D.BillboardGui = { Size = T.UDim2.new(0, 0, 0, 0), MaxDistance = math.huge, AlwaysOnTop = false, LightInfluence = 1 }
D.UIListLayout = { Padding = T.UDim.new(0, 0), FillDirection = function() return E.enumItem("FillDirection", "Vertical") end, SortOrder = function() return E.enumItem("SortOrder", "LayoutOrder") end, HorizontalAlignment = function() return E.enumItem("HorizontalAlignment", "Left") end, VerticalAlignment = function() return E.enumItem("VerticalAlignment", "Top") end }
D.UIGridLayout = { CellSize = T.UDim2.new(0, 100, 0, 100), CellPadding = T.UDim2.new(0, 5, 0, 5), FillDirection = function() return E.enumItem("FillDirection", "Horizontal") end, SortOrder = function() return E.enumItem("SortOrder", "LayoutOrder") end, HorizontalAlignment = function() return E.enumItem("HorizontalAlignment", "Left") end, VerticalAlignment = function() return E.enumItem("VerticalAlignment", "Top") end, StartCorner = function() return E.enumItem("StartCorner", "TopLeft") end }
D.UICorner = { CornerRadius = T.UDim.new(0, 8) }
D.UIStroke = { Thickness = 1, Color = T.Color3.new(0, 0, 0), Transparency = 0, Enabled = true }
D.UIGradient = { Enabled = true, Color = T.ColorSequence.new(T.Color3.new(1, 1, 1)), Transparency = T.NumberSequence.new(0), Rotation = 0 }
D.UIAspectRatioConstraint = { AspectRatio = 1 }
D.UISizeConstraint = { MinSize = V2.new(0, 0), MaxSize = V2.new(math.huge, math.huge) }
D.UITextSizeConstraint = { MinTextSize = 1, MaxTextSize = 100 }
D.UIScale = { Scale = 1 }

local function vis(o) return o.props.Visible ~= false end
local function isGuiObj(o) return E.isA(o.cls, "GuiObject") end
local function prop(o, k) return o[k] end

-- text size (pixels) for TextScaled within w,h
local function textWidth(text, size) return utf8.len(text or "") * size * 0.52 end
local function fitText(text, w, h, wrapped, maxSize)
	local s = math.min(h * 0.92, maxSize or 100)
	text = text or ""
	if text == "" then return s end
	while s > 1 do
		local lines = 1
		if wrapped then lines = math.ceil(textWidth(text, s) / math.max(1, w)) end
		if (wrapped and lines * s * 1.15 <= h) or (not wrapped and textWidth(text, s) <= w and s <= h) then break end
		s = s - 1
	end
	return s
end
E.fitText = fitText

-- lay out one root (ScreenGui/SurfaceGui/BillboardGui) and store rects in o.L = {x,y,w,h,vis,clip}
local function layoutChildren(o, cx, cy, cw, ch, clip, visible)
	local pad
	local list, grid, aspectOf
	for _, c in ipairs(o.children) do
		if c.cls == "UIPadding" then pad = c
		elseif c.cls == "UIListLayout" then list = c
		elseif c.cls == "UIGridLayout" then grid = c end
	end
	if pad then
		local l, r, t, b = pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom
		local pl, pr, pt, pb = l.Scale * cw + l.Offset, r.Scale * cw + r.Offset, t.Scale * ch + t.Offset, b.Scale * ch + b.Offset
		cx, cy, cw, ch = cx + pl, cy + pt, math.max(0, cw - pl - pr), math.max(0, ch - pt - pb)
	end
	-- scrolling: children live in the canvas
	local scrollX, scrollY = 0, 0
	if o.cls == "ScrollingFrame" then
		local cs = o.CanvasSize
		local cp = o.CanvasPosition
		scrollX, scrollY = cp.X, cp.Y
		local canW, canH = cs.X.Scale * cw + cs.X.Offset, cs.Y.Scale * ch + cs.Y.Offset
		cx, cy = cx - scrollX, cy - scrollY
		o.canvasW, o.canvasH = math.max(cw, canW), math.max(ch, canH)
		cw = math.max(cw, canW)
		if o.AutomaticCanvasSize.Name == "None" then ch = math.max(ch, canH) end
	end
	local kids = {}
	for _, c in ipairs(o.children) do if isGuiObj(c) then kids[#kids + 1] = c end end
	local function size(c, pw, ph)
		local s = c.Size
		local w, h = s.X.Scale * pw + s.X.Offset, s.Y.Scale * ph + s.Y.Offset
		local sc = c.SizeConstraint.Name
		if sc == "RelativeXX" then h = s.Y.Scale * pw + s.Y.Offset elseif sc == "RelativeYY" then w = s.X.Scale * ph + s.X.Offset end
		for _, k in ipairs(c.children) do
			if k.cls == "UIAspectRatioConstraint" then
				local r = k.AspectRatio
				if r > 0 then
					local at = k.AspectType.Name
					local dom = k.DominantAxis.Name
					if at == "ScaleWithParentSize" then if dom == "Width" then h = w / r else w = h * r end
					else if w / math.max(h, 1e-6) > r then w = h * r else h = w / r end end
				end
			elseif k.cls == "UISizeConstraint" then
				local mn, mx = k.MinSize, k.MaxSize
				w = math.max(mn.X, math.min(mx.X, w)); h = math.max(mn.Y, math.min(mx.Y, h))
			end
		end
		local au = c.AutomaticSize.Name
		if au ~= "None" and (c.cls == "TextLabel" or c.cls == "TextButton" or c.cls == "TextBox") then
			local ts = c.TextSize
			if au == "X" or au == "XY" then w = math.max(w, textWidth(c.Text, ts) + 4) end
			if au == "Y" or au == "XY" then
				local lines = c.TextWrapped and math.max(1, math.ceil(textWidth(c.Text, ts) / math.max(1, w))) or (select(2, c.Text:gsub("\n", "")) + 1)
				h = math.max(h, lines * ts * 1.2)
			end
		end
		return w, h
	end
	local placed = {}
	if grid then
		local cs, cp = grid.CellSize, grid.CellPadding
		local cwid, chei = cs.X.Scale * cw + cs.X.Offset, cs.Y.Scale * ch + cs.Y.Offset
		local px, py = cp.X.Scale * cw + cp.X.Offset, cp.Y.Scale * ch + cp.Y.Offset
		local sorted = {}
		for _, c in ipairs(kids) do if vis(c) then sorted[#sorted + 1] = c end end
		local byName = grid.SortOrder.Name == "Name"
		table.sort(sorted, function(a, b) if byName then return a.props.Name < b.props.Name end if a.LayoutOrder ~= b.LayoutOrder then return a.LayoutOrder < b.LayoutOrder end return a.id < b.id end)
		local horiz = grid.FillDirection.Name == "Horizontal"
		local perLine = math.max(1, math.floor((horiz and (cw + px) / (cwid + px) or (ch + py) / (chei + py)) + 1e-6))
		local maxc = grid.FillDirectionMaxCells
		if maxc and maxc > 0 then perLine = math.min(perLine, maxc) end
		local lineW = perLine * cwid + (perLine - 1) * px
		local ox = 0
		if horiz then
			local ha = grid.HorizontalAlignment.Name
			if ha == "Center" then ox = (cw - lineW) / 2 elseif ha == "Right" then ox = cw - lineW end
		end
		for i, c in ipairs(sorted) do
			local k = i - 1
			local col, row = k % perLine, math.floor(k / perLine)
			if not horiz then col, row = row, col end
			placed[c] = { cx + ox + col * (cwid + px), cy + row * (chei + py), cwid, chei }
		end
		if o.cls == "ScrollingFrame" and o.AutomaticCanvasSize.Name ~= "None" then
			local rows = math.ceil(#sorted / perLine)
			o.canvasH = math.max(o.canvasH or 0, rows * (chei + py))
		end
	elseif list then
		local pad2 = list.Padding
		local horiz = list.FillDirection.Name == "Horizontal"
		local gap = pad2.Scale * (horiz and cw or ch) + pad2.Offset
		local sorted = {}
		for _, c in ipairs(kids) do if vis(c) then sorted[#sorted + 1] = c end end
		local byName = list.SortOrder.Name == "Name"
		table.sort(sorted, function(a, b) if byName then return a.props.Name < b.props.Name end if a.LayoutOrder ~= b.LayoutOrder then return a.LayoutOrder < b.LayoutOrder end return a.id < b.id end)
		local sizes, total = {}, 0
		for i, c in ipairs(sorted) do
			local w, h = size(c, cw, ch)
			sizes[i] = { w, h }
			total = total + (horiz and w or h) + (i > 1 and gap or 0)
		end
		local start = 0
		local mainAlign = horiz and list.HorizontalAlignment.Name or list.VerticalAlignment.Name
		local mainLen = horiz and cw or ch
		if mainAlign == "Center" then start = (mainLen - total) / 2 elseif mainAlign == "Right" or mainAlign == "Bottom" then start = mainLen - total end
		local pos = start
		local crossAlign = horiz and list.VerticalAlignment.Name or list.HorizontalAlignment.Name
		for i, c in ipairs(sorted) do
			local w, h = sizes[i][1], sizes[i][2]
			local x, y
			if horiz then
				x = cx + pos
				y = cy + (crossAlign == "Center" and (ch - h) / 2 or (crossAlign == "Bottom" and ch - h or 0))
				pos = pos + w + gap
			else
				y = cy + pos
				x = cx + (crossAlign == "Center" and (cw - w) / 2 or (crossAlign == "Right" and cw - w or 0))
				pos = pos + h + gap
			end
			placed[c] = { x, y, w, h }
		end
		o.contentSize = horiz and V2.new(total, ch) or V2.new(cw, total)
		list.contentSize = o.contentSize
		if o.cls == "ScrollingFrame" and o.AutomaticCanvasSize.Name ~= "None" then
			if horiz then o.canvasW = math.max(o.canvasW or 0, total) else o.canvasH = math.max(o.canvasH or 0, total) end
		end
	end
	for _, c in ipairs(kids) do
		local x, y, w, h
		if placed[c] then
			x, y, w, h = placed[c][1], placed[c][2], placed[c][3], placed[c][4]
		else
			w, h = size(c, cw, ch)
			local p, a = c.Position, c.AnchorPoint
			x = cx + p.X.Scale * cw + p.X.Offset - a.X * w
			y = cy + p.Y.Scale * ch + p.Y.Offset - a.Y * h
		end
		local v = visible and vis(c)
		c.L = { x = x, y = y, w = w, h = h, vis = v, clip = clip }
		local cclip = clip
		if c.ClipsDescendants or c.cls == "ScrollingFrame" then
			local nx, ny = math.max(x, clip and clip[1] or -1e9), math.max(y, clip and clip[2] or -1e9)
			local nx2, ny2 = math.min(x + w, clip and clip[3] or 1e9), math.min(y + h, clip and clip[4] or 1e9)
			cclip = { nx, ny, nx2, ny2 }
		end
		layoutChildren(c, x, y, w, h, cclip, v)
	end
end

local function rootRect(root)
	if root.cls == "ScreenGui" then
		if root.IgnoreGuiInset then return 0, 0, E.VIEW.w, E.VIEW.h end
		return 0, E.VIEW.inset, E.VIEW.w, E.VIEW.h - E.VIEW.inset
	elseif root.cls == "SurfaceGui" then
		local w, h = E.surfaceSize(root)
		return 0, 0, w, h
	elseif root.cls == "BillboardGui" then
		local s = root.Size
		return 0, 0, s.X.Offset, s.Y.Offset
	end
	return 0, 0, E.VIEW.w, E.VIEW.h
end
function E.surfaceSize(sg)
	local part = sg.Adornee or sg.parent
	local face = sg.Face.Name
	local s = (part and E.isA(part.cls, "BasePart")) and part.Size or V3.new(4, 4, 4)
	local fw, fh
	if face == "Front" or face == "Back" then fw, fh = s.X, s.Y
	elseif face == "Left" or face == "Right" then fw, fh = s.Z, s.Y
	else fw, fh = s.X, s.Z end
	if sg.SizingMode.Name == "PixelsPerStud" then return fw * sg.PixelsPerStud, fh * sg.PixelsPerStud, fw, fh end
	local cs = sg.CanvasSize
	return cs.X, cs.Y, fw, fh
end
function E.layoutRoot(root)
	local x, y, w, h = rootRect(root)
	root.L = { x = x, y = y, w = w, h = h, vis = root.Enabled ~= false }
	layoutChildren(root, x, y, w, h, nil, root.Enabled ~= false)
end
local function rootOf(o)
	local x = o
	while x do
		if x.cls == "ScreenGui" or x.cls == "SurfaceGui" or x.cls == "BillboardGui" then return x end
		x = x.parent
	end
end
local function ensure(o)
	local r = rootOf(o)
	if r then E.layoutRoot(r) end
	return o.L
end
local gg = cls(G, "GuiObject")
local function insetFor(o)
	local r = rootOf(o)
	if r and r.cls == "ScreenGui" then return E.VIEW.inset end
	return 0
end
gg.AbsoluteSize = function(o) local L = ensure(o); if not L then return V2.zero end return V2.new(L.w, L.h) end
gg.AbsolutePosition = function(o) local L = ensure(o); if not L then return V2.zero end return V2.new(L.x, L.y - insetFor(o)) end
gg.AbsoluteRotation = function(o) return o.props.Rotation or 0 end
cls(G, "GuiBase2d").AbsoluteSize = function(o) local L = ensure(o); if not L then return V2.new(E.VIEW.w, E.VIEW.h - E.VIEW.inset) end return V2.new(L.w, L.h) end
cls(G, "GuiBase2d").AbsolutePosition = function(o) local L = ensure(o); if not L then return V2.zero end return V2.new(L.x, L.y - insetFor(o)) end
cls(G, "ScrollingFrame").AbsoluteCanvasSize = function(o) ensure(o); return V2.new(o.canvasW or 0, o.canvasH or 0) end
cls(G, "ScrollingFrame").CanvasPosition = function(o) return o.props.CanvasPosition or V2.zero end
cls(G, "UIListLayout").AbsoluteContentSize = function(o) if o.parent then ensure(o.parent) end return o.contentSize or V2.zero end
cls(G, "UIGridLayout").AbsoluteContentSize = function(o) if o.parent then ensure(o.parent) end return o.contentSize or V2.zero end
cls(G, "GuiObject").TextBounds = function(o) return V2.new(textWidth(o.props.Text or "", o.TextSize), o.TextSize) end
cls(G, "TextLabel").TextFits = function() return true end
cls(G, "TextButton").TextFits = function() return true end
cls(G, "TextLabel").ContentText = function(o) return (o.props.Text or ""):gsub("<[^>]+>", "") end
cls(G, "TextButton").ContentText = function(o) return (o.props.Text or ""):gsub("<[^>]+>", "") end
cls(G, "TextBox").ContentText = function(o) return o.props.Text or "" end

local TBm = cls(M, "TextBox")
function TBm.CaptureFocus(o) E.focusedBox = o; E.fireEv(o, "Focused") end
function TBm.ReleaseFocus(o, enter) if E.focusedBox == o then E.focusedBox = nil end E.fireEv(o, "FocusLost", enter == true, nil) end
function TBm.IsFocused(o) return E.focusedBox == o end
cls(M, "GuiObject").TweenPosition = function(o, p) o.Position = p; return true end
cls(M, "GuiObject").TweenSize = function(o, s) o.Size = s; return true end
cls(M, "GuiObject").TweenSizeAndPosition = function(o, s, p) o.Size = s; o.Position = p; return true end
cls(M, "BasePlayerGui").GetGuiObjectsAtPosition = function(o, x, y) return E.guiAt(x, y + E.VIEW.inset, true) end
cls(M, "ScrollingFrame").ScrollToTop = function(o) o.props.CanvasPosition = V2.zero end
cls(M, "PlayerGui").SetTopbarTransparency = function() end

-- all visible GuiObjects of the local player's PlayerGui in draw order (screen coords incl. inset)
function E.guiList(plr)
	local pg = plr and M.Instance.FindFirstChildOfClass(plr, "PlayerGui")
	if not pg then return {} end
	local roots = {}
	for _, c in ipairs(pg.children) do if c.cls == "ScreenGui" then roots[#roots + 1] = c end end
	table.sort(roots, function(a, b) if a.DisplayOrder ~= b.DisplayOrder then return a.DisplayOrder < b.DisplayOrder end return a.id < b.id end)
	local out = {}
	for _, r in ipairs(roots) do
		E.layoutRoot(r)
		if r.L.vis then
			local global = r.ZIndexBehavior.Name == "Global"
			local function walk(o, depth)
				local kids = {}
				for _, c in ipairs(o.children) do if isGuiObj(c) and c.L and c.L.vis then kids[#kids + 1] = c end end
				table.sort(kids, function(a, b) if a.ZIndex ~= b.ZIndex then return a.ZIndex < b.ZIndex end return a.id < b.id end)
				for _, c in ipairs(kids) do
					out[#out + 1] = { o = c, root = r, depth = depth, z = c.ZIndex }
					walk(c, depth + 1)
				end
			end
			local start = #out + 1
			walk(r, 0)
			if global then
				local seg = {}
				for i = start, #out do seg[#seg + 1] = out[i] end
				for i = #out, start, -1 do out[i] = nil end
				for i, e in ipairs(seg) do e.i = i end
				table.sort(seg, function(a, b) if a.z ~= b.z then return a.z < b.z end return a.i < b.i end)
				for _, e in ipairs(seg) do out[#out + 1] = e end
			end
		end
	end
	return out
end
-- topmost GUI objects under a screen point (screen coords incl. inset)
function E.guiAt(x, y, all)
	local list = E.guiList(E.player)
	local hits = {}
	for i = #list, 1, -1 do
		local o = list[i].o
		local L = o.L
		local inClip = not L.clip or (x >= L.clip[1] and x <= L.clip[3] and y >= L.clip[2] and y <= L.clip[4])
		if inClip and x >= L.x and x <= L.x + L.w and y >= L.y and y <= L.y + L.h then hits[#hits + 1] = o end
	end
	return hits
end

---------------------------------------------------------------- snapshot
local function c3(c) return c and { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) } or nil end
local function cfArr(c) return { c:GetComponents() } end
local function partRec(p, cfOverride)
	local shape = "Block"
	if p.cls == "Part" then shape = p.Shape.Name
	elseif p.cls == "WedgePart" then shape = "Wedge"
	elseif p.cls == "CornerWedgePart" then shape = "CornerWedge"
	elseif p.cls == "TrussPart" then shape = "Truss"
	elseif p.cls == "MeshPart" then shape = "Mesh"
	elseif p.cls == "Seat" or p.cls == "VehicleSeat" or p.cls == "SpawnLocation" then shape = "Block" end
	local mesh = M.Instance.FindFirstChildOfClass(p, "SpecialMesh")
	if mesh then shape = "Special:" .. mesh.MeshType.Name end
	local s = p.Size
	return { s = shape, z = { s.X, s.Y, s.Z }, cf = cfArr(cfOverride or p.cframe), c = c3(p.Color), m = p.Material.Name, t = p.Transparency, r = p.Reflectance, n = p.props.Name }
end
local function guiRec(o, root)
	local L = o.L
	local r = { k = o.cls, x = L.x, y = L.y, w = L.w, h = L.h, clip = L.clip, n = o.props.Name }
	r.bg = c3(o.BackgroundColor3); r.bgt = o.BackgroundTransparency
	r.rot = o.Rotation
	for _, c in ipairs(o.children) do
		if c.cls == "UICorner" then local cr = c.CornerRadius; r.corner = cr.Scale * math.min(L.w, L.h) + cr.Offset
		elseif c.cls == "UIStroke" and c.Enabled then
			if c.ApplyStrokeMode.Name == "Border" or not (o.cls == "TextLabel" or o.cls == "TextButton" or o.cls == "TextBox") then
				r.stroke = { c3(c.Color), c.Thickness, c.Transparency }
			else r.tstroke = { c3(c.Color), c.Thickness, c.Transparency } end
		elseif c.cls == "UIGradient" and c.Enabled then
			local kp = {}
			for _, k in ipairs(c.Color.Keypoints) do kp[#kp + 1] = { k.Time, c3(k.Value) } end
			local tp = {}
			for _, k in ipairs(c.Transparency.Keypoints) do tp[#tp + 1] = { k.Time, k.Value } end
			r.grad = { rot = c.Rotation, c = kp, t = tp }
		end
	end
	if o.cls == "TextLabel" or o.cls == "TextButton" or o.cls == "TextBox" then
		local txt = o.props.Text
		if o.cls == "TextBox" and (txt == nil or txt == "") then txt = o.PlaceholderText; r.ph = true end
		if txt == nil then txt = o.Text end
		r.text = txt
		r.tc = c3(r.ph and o.PlaceholderColor3 or o.TextColor3); r.tt = o.TextTransparency
		local ts = o.TextSize
		if o.TextScaled then
			local mx = 100
			for _, c in ipairs(o.children) do if c.cls == "UITextSizeConstraint" then mx = c.MaxTextSize end end
			ts = fitText(o.ContentText, L.w, L.h, o.TextWrapped, mx)
		end
		r.ts = ts
		r.font = o.Font.Name
		local ff = o.props.FontFace
		if ff then r.ffam = ff.Family; r.fw = ff.Weight and ff.Weight.Name end
		r.xa = o.TextXAlignment.Name; r.ya = o.TextYAlignment.Name
		r.wrap = o.TextWrapped; r.rich = o.RichText
		r.tst = o.TextStrokeTransparency; r.tsc = c3(o.TextStrokeColor3)
	end
	if o.cls == "ImageLabel" or o.cls == "ImageButton" then
		r.img = o.Image; r.ic = c3(o.ImageColor3); r.it = o.ImageTransparency
	end
	if o.cls == "ViewportFrame" then
		local cam = o.CurrentCamera
		local parts = {}
		for _, d in ipairs(M.Instance.GetDescendants(o)) do
			if E.isA(d.cls, "BasePart") and d.Transparency < 1 then parts[#parts + 1] = partRec(d) end
		end
		r.vp = { cam = cam and { cf = cfArr(cam.CFrame), fov = cam.FieldOfView } or nil, parts = parts, amb = c3(o.Ambient), lc = c3(o.LightColor), ld = { o.LightDirection.X, o.LightDirection.Y, o.LightDirection.Z } }
	end
	if o.cls == "ScrollingFrame" then r.scroll = true end
	return r
end

function E.snapshot(opts)
	opts = opts or {}
	local ws = E.services.Workspace
	local cam = E.currentCamera({ name = "client", player = E.player })
	local snap = { view = E.VIEW, camera = { cf = cfArr(cam.CFrame), fov = cam.FieldOfView }, parts = {}, lights = {}, surf = {}, gui = {}, prompts = {}, bill = {}, hl = {}, fx = {} }
	local L = E.services.Lighting
	snap.lighting = { clock = L.ClockTime, bright = L.Brightness, amb = c3(L.Ambient), oamb = c3(L.OutdoorAmbient), fogEnd = L.FogEnd, fogStart = L.FogStart, fogColor = c3(L.FogColor), exp = L.ExposureCompensation, sun = { L:GetSunDirection().X, L:GetSunDirection().Y, L:GetSunDirection().Z } }
	for _, c in ipairs(L.children) do
		if c.cls == "Atmosphere" then snap.lighting.atm = { d = c.Density, c = c3(c.Color), decay = c3(c.Decay), haze = c.Haze } end
		if c.cls == "ColorCorrectionEffect" and c.Enabled then snap.lighting.cc = { b = c.Brightness, c = c.Contrast, s = c.Saturation, tint = c3(c.TintColor) } end
	end
	local function walk(x)
		for _, d in ipairs(x.children) do
			if E.isA(d.cls, "BasePart") and d.cls ~= "Terrain" then
				if d.Transparency < 1 and (d.props.LocalTransparencyModifier or 0) < 1 then snap.parts[#snap.parts + 1] = partRec(d) end
				for _, k in ipairs(d.children) do
					if (k.cls == "PointLight" or k.cls == "SpotLight" or k.cls == "SurfaceLight") and k.Enabled then
						local face = k.cls ~= "PointLight" and k.Face.Name or nil
						snap.lights[#snap.lights + 1] = { k = k.cls, cf = cfArr(d.cframe), size = { d.Size.X, d.Size.Y, d.Size.Z }, c = c3(k.Color), b = k.Brightness, r = k.Range, a = k.cls ~= "PointLight" and k.Angle or nil, face = face, sh = k.Shadows }
					elseif k.cls == "Attachment" then
						for _, kk in ipairs(k.children) do
							if (kk.cls == "PointLight" or kk.cls == "SpotLight") and kk.Enabled then
								snap.lights[#snap.lights + 1] = { k = kk.cls, cf = cfArr(k.WorldCFrame), size = { 0, 0, 0 }, c = c3(kk.Color), b = kk.Brightness, r = kk.Range, a = kk.cls == "SpotLight" and kk.Angle or nil, face = kk.cls == "SpotLight" and kk.Face.Name or nil }
							elseif kk.cls == "ParticleEmitter" and kk.Enabled and kk.Rate > 0 then
								snap.fx[#snap.fx + 1] = { p = { k.WorldPosition.X, k.WorldPosition.Y, k.WorldPosition.Z }, c = c3(kk.Color.Keypoints[1].Value), rate = kk.Rate, size = kk.Size.Keypoints[1].Value }
							end
						end
					elseif k.cls == "SurfaceGui" and k.Enabled then
						E.layoutRoot(k)
						local pw, ph, fw, fh = E.surfaceSize(k)
						local els = {}
						for _, e in ipairs(M.Instance.GetDescendants(k)) do if isGuiObj(e) and e.L and e.L.vis then els[#els + 1] = guiRec(e, k) end end
						snap.surf[#snap.surf + 1] = { cf = cfArr(d.cframe), size = { d.Size.X, d.Size.Y, d.Size.Z }, face = k.Face.Name, pw = pw, ph = ph, els = els, glow = k.LightInfluence < 0.5 }
					elseif k.cls == "ProximityPrompt" and k.Enabled and E.player and E.services.ProximityPromptService.Enabled then
						local ch = E.player.Character
						local root = ch and M.Instance.FindFirstChild(ch, "HumanoidRootPart")
						if root and (root.cframe.Position - d.cframe.Position).Magnitude <= k.MaxActivationDistance then
							local sp, on = cam:WorldToViewportPoint(d.cframe.Position)
							if on then snap.prompts[#snap.prompts + 1] = { x = sp.X, y = sp.Y, a = k.ActionText, o = k.ObjectText, key = k.KeyboardKeyCode.Name, hold = k.HoldDuration } end
						end
					end
				end
			end
			if d.cls == "Highlight" and d.Enabled then
				local a = d.Adornee or d.parent
				if a then
					local list = {}
					if E.isA(a.cls, "BasePart") then list = { a } else for _, q in ipairs(M.Instance.GetDescendants(a)) do if E.isA(q.cls, "BasePart") then list[#list + 1] = q end end end
					local names = {}
					for _, q in ipairs(list) do names[#names + 1] = q.id end
					snap.hl[#snap.hl + 1] = { ids = names, fill = c3(d.FillColor), ft = d.FillTransparency, out = c3(d.OutlineColor), ot = d.OutlineTransparency }
				end
			end
			walk(d)
		end
	end
	walk(ws)
	-- part ids for highlights
	local idx = 0
	local function ids(x) for _, d in ipairs(x.children) do if E.isA(d.cls, "BasePart") and d.cls ~= "Terrain" and d.Transparency < 1 and (d.props.LocalTransparencyModifier or 0) < 1 then idx = idx + 1; snap.parts[idx].id = d.id end ids(d) end end
	ids(ws)
	snap.terrain = {}
	for _, op in ipairs(E.terrainOps) do snap.terrain[#snap.terrain + 1] = { k = op.kind, cf = cfArr(op.cf), size = { op.size.X, op.size.Y, op.size.Z }, m = op.mat } end
	if E.player then
		for _, e in ipairs(E.guiList(E.player)) do snap.gui[#snap.gui + 1] = guiRec(e.o, e.root) end
		-- billboards in PlayerGui or workspace
		local function bills(x)
			for _, d in ipairs(x.children) do
				if d.cls == "BillboardGui" and d.Enabled then
					local ad = d.Adornee or d.parent
					if ad and E.isA(ad.cls, "BasePart") then
						local wp = ad.cframe.Position + d.StudsOffset + d.StudsOffsetWorldSpace
						local sp, on = cam:WorldToViewportPoint(wp)
						if on and sp.Z < (d.MaxDistance or math.huge) then
							E.layoutRoot(d)
							local s = d.Size
							local w, h = s.X.Offset + s.X.Scale * 50 / sp.Z * 10, s.Y.Offset + s.Y.Scale * 50 / sp.Z * 10
							local els = {}
							d.L = { x = 0, y = 0, w = w, h = h, vis = true }
							layoutChildren(d, sp.X - w / 2, sp.Y - h / 2, w, h, nil, true)
							for _, e in ipairs(M.Instance.GetDescendants(d)) do if isGuiObj(e) and e.L and e.L.vis then els[#els + 1] = guiRec(e, d) end end
							snap.bill[#snap.bill + 1] = { els = els, z = sp.Z }
						end
					end
				end
				bills(d)
			end
		end
		bills(ws)
		local pg = M.Instance.FindFirstChildOfClass(E.player, "PlayerGui")
		if pg then bills(pg) end
	end
	snap.coreGui = E.coreGui
	snap.mouse = { E.input.mouse.X, E.input.mouse.Y }
	return snap
end

return E

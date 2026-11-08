-- Smooth 3D shapes for the moped panels, generated as triangle meshes (no uploaded files needed).
-- Each panel is one or more "sweeps": a rounded cross-section (superellipse) moved along a path.
-- The client turns them into MeshParts with EditableMesh (see MeshSkin.client.lua); the block parts
-- from MopedDef stay as the fallback and as the click targets.
local MeshGen = {}
local V3 = Vector3.new
local rad, cos, sin, tan, abs = math.rad, math.cos, math.sin, math.tan, math.abs

MeshGen.RING = 18 -- points around each cross-section

-- path: list of { p = Vector3, w = half width (along side), h = half depth, n = roundness (2 = ellipse, 4+ = boxy) }
-- side: world direction of the width axis (default X)
local function sweep(path, side)
	side = side or V3(1, 0, 0)
	local verts, tris = {}, {}
	local N = MeshGen.RING
	for i, s in ipairs(path) do
		local prev = path[math.max(1, i - 1)].p
		local nxt = path[math.min(#path, i + 1)].p
		local t = (nxt - prev).Unit
		local nrm = side:Cross(t).Unit
		local sd = t:Cross(nrm).Unit
		local n = s.n or 3
		for k = 0, N - 1 do
			local a = k / N * math.pi * 2
			local ca, sa = cos(a), sin(a)
			local x = s.w * (ca >= 0 and 1 or -1) * abs(ca) ^ (2 / n)
			local y = s.h * (sa >= 0 and 1 or -1) * abs(sa) ^ (2 / n)
			verts[#verts + 1] = s.p + sd * x + nrm * y
		end
	end
	local rings = #path
	for i = 0, rings - 2 do
		for k = 0, N - 1 do
			local a = i * N + k + 1
			local b = i * N + (k + 1) % N + 1
			local c = (i + 1) * N + k + 1
			local d = (i + 1) * N + (k + 1) % N + 1
			tris[#tris + 1] = { a, c, b }
			tris[#tris + 1] = { b, c, d }
		end
	end
	-- caps
	for _, e in ipairs({ { 0, true }, { rings - 1, false } }) do
		local base = e[1] * N
		local center = V3()
		for k = 1, N do center = center + verts[base + k] end
		verts[#verts + 1] = center / N
		local ci = #verts
		for k = 0, N - 1 do
			local a, b = base + k + 1, base + (k + 1) % N + 1
			-- start cap faces backwards along the path, end cap forwards (outward winding)
			if e[2] then tris[#tris + 1] = { ci, a, b } else tris[#tris + 1] = { ci, b, a } end
		end
	end
	return { verts = verts, tris = tris }
end
MeshGen.sweep = sweep

-- helpers for paths
-- a vertical shield: from y0 to y1, leaning back by lean degrees, widths at bottom/middle/top
local function shield(x, y0, y1, zMid, yMid, lean, wB, wM, wT, h, n)
	local pts = {}
	local steps = 7
	for i = 0, steps do
		local f = i / steps
		local y = y0 + (y1 - y0) * f
		local w = f < 0.5 and (wB + (wM - wB) * (f / 0.5)) or (wM + (wT - wM) * ((f - 0.5) / 0.5))
		-- slightly bulged front
		local bulge = 0.05 * sin(f * math.pi)
		pts[#pts + 1] = { p = V3(x, y, zMid + (y - yMid) * tan(rad(lean)) - bulge), w = w, h = h, n = n }
	end
	return pts
end
-- along Z with a profile of {z, y, w, h}
local function body(x, prof, n)
	local pts = {}
	for _, q in ipairs(prof) do pts[#pts + 1] = { p = V3(x, q[2], q[1]), w = q[3], h = q[4], n = q[5] or n } end
	return pts
end
-- an arc around an axle (fenders): angles in degrees, 90 = straight up, >90 towards the front
local function arc(cx, cy, cz, r, a0, a1, w, h, n)
	local pts = {}
	local steps = 10
	for i = 0, steps do
		local a = rad(a0 + (a1 - a0) * i / steps)
		pts[#pts + 1] = { p = V3(cx, cy + r * sin(a), cz + r * cos(a)), w = w * (1 - 0.25 * abs(i / steps - 0.5)), h = h, n = n }
	end
	return pts
end
local function mirrorX(path)
	local out = {}
	for i, s in ipairs(path) do out[i] = { p = V3(-s.p.X, s.p.Y, s.p.Z), w = s.w, h = s.h, n = s.n } end
	return out
end

-- panel shapes in moped space (same coordinates as MopedDef): model -> panelId -> { sweeps }
local P = {}
MeshGen.PANELS = P
P.citi = {
	front = { shield(0, 1.08, 3.02, -1.98, 2.12, 14, 0.42, 0.55, 0.36, 0.17, 2.8) },
	ben = { shield(0, 1.3, 2.75, -1.72, 2.05, 14, 0.44, 0.5, 0.33, 0.04, 3) },
	fot = { body(0, { { -1.66, 1.26, 0.46, 0.09 }, { -1.0, 1.26, 0.48, 0.09 }, { -0.05, 1.26, 0.48, 0.09 } }, 5) },
	sidaV = { body(-0.26, { { 0.02, 1.62, 0.2, 0.2 }, { 0.35, 1.9, 0.25, 0.38 }, { 0.9, 2.18, 0.26, 0.46 }, { 1.6, 2.24, 0.26, 0.42 }, { 2.2, 2.28, 0.24, 0.34 }, { 2.45, 2.3, 0.2, 0.22 } }, 3) },
	sidaH = { body(0.26, { { 0.02, 1.62, 0.2, 0.2 }, { 0.35, 1.9, 0.25, 0.38 }, { 0.9, 2.18, 0.26, 0.46 }, { 1.6, 2.24, 0.26, 0.42 }, { 2.2, 2.28, 0.24, 0.34 }, { 2.45, 2.3, 0.2, 0.22 } }, 3) },
	bak = { body(0, { { 2.4, 2.34, 0.42, 0.22 }, { 2.7, 2.38, 0.34, 0.17 }, { 2.92, 2.4, 0.18, 0.09 } }, 3) },
	skarm = { arc(0, 0.8, -2.1, 0.92, 35, 158, 0.22, 0.05, 3) },
	styrkapa = { body(0, { { -1.95, 3.4, 0.36, 0.12 }, { -1.75, 3.43, 0.5, 0.17 }, { -1.45, 3.45, 0.46, 0.15 }, { -1.3, 3.45, 0.3, 0.1 } }, 3) },
}
P.sprint = {
	front = {
		shield(0, 1.2, 3.25, -2.15, 2.35, 18, 0.46, 0.6, 0.4, 0.24, 3.2),
		body(0, { { -2.32, 1.74, 0.44, 0.2 }, { -2.6, 1.7, 0.32, 0.13 }, { -2.88, 1.66, 0.12, 0.05 } }, 2.6),
	},
	flankV = { body(-0.6, { { -2.25, 2.0, 0.06, 0.5 }, { -1.98, 2.25, 0.06, 0.62 }, { -1.7, 2.35, 0.06, 0.45 } }, 3) },
	flankH = { body(0.6, { { -2.25, 2.0, 0.06, 0.5 }, { -1.98, 2.25, 0.06, 0.62 }, { -1.7, 2.35, 0.06, 0.45 } }, 3) },
	ben = { shield(0, 1.4, 2.85, -1.84, 2.15, 16, 0.46, 0.52, 0.36, 0.04, 3) },
	fot = { body(0, { { -1.72, 1.31, 0.46, 0.09 }, { -1.0, 1.31, 0.48, 0.09 }, { -0.12, 1.31, 0.48, 0.09 } }, 5) },
	tunnel = { body(0, { { -1.62, 1.48, 0.12, 0.08 }, { -1.0, 1.52, 0.22, 0.15 }, { -0.22, 1.52, 0.22, 0.15 } }, 3) },
	sidaV = { body(-0.27, { { 0.0, 1.66, 0.2, 0.22 }, { 0.4, 1.98, 0.27, 0.42 }, { 1.0, 2.26, 0.28, 0.48 }, { 1.8, 2.42, 0.28, 0.45 }, { 2.4, 2.72, 0.26, 0.36 }, { 2.7, 2.95, 0.2, 0.2 } }, 3.4) },
	sidaH = { body(0.27, { { 0.0, 1.66, 0.2, 0.22 }, { 0.4, 1.98, 0.27, 0.42 }, { 1.0, 2.26, 0.28, 0.48 }, { 1.8, 2.42, 0.28, 0.45 }, { 2.4, 2.72, 0.26, 0.36 }, { 2.7, 2.95, 0.2, 0.2 } }, 3.4) },
	bak = { body(0, { { 2.72, 2.85, 0.4, 0.18 }, { 2.95, 2.82, 0.3, 0.14 }, { 3.12, 2.8, 0.14, 0.07 } }, 3) },
	skarm = { arc(0, 0.85, -2.25, 0.96, 32, 160, 0.21, 0.05, 3) },
	styrkapa = { body(0, { { -2.08, 3.52, 0.3, 0.1 }, { -1.85, 3.56, 0.5, 0.17 }, { -1.5, 3.58, 0.46, 0.15 }, { -1.38, 3.58, 0.3, 0.1 } }, 3.2) },
	under = { body(0, { { -1.55, 1.1, 0.3, 0.05 }, { -0.9, 1.08, 0.4, 0.07 }, { -0.25, 1.1, 0.3, 0.05 } }, 4) },
	spoiler = { body(0, { { 2.7, 3.2, 0.3, 0.03 }, { 2.88, 3.24, 0.36, 0.04 }, { 3.06, 3.28, 0.3, 0.03 } }, 4) },
}
P.klassik = {
	front = {
		shield(0, 1.15, 3.05, -1.95, 2.15, 12, 0.5, 0.62, 0.44, 0.08, 2.6),
		body(0, { { -2.26, 2.55, 0.08, 0.1 }, { -2.18, 2.55, 0.2, 0.3 }, { -2.02, 2.55, 0.2, 0.3 }, { -1.98, 2.55, 0.12, 0.18 } }, 2),
	},
	fot = { body(0, { { -1.7, 1.28, 0.48, 0.08 }, { -1.0, 1.28, 0.5, 0.08 }, { -0.1, 1.28, 0.5, 0.08 } }, 5) },
	sidaV = { body(-0.3, { { 0.45, 2.0, 0.08, 0.12 }, { 0.75, 2.02, 0.28, 0.4 }, { 1.4, 2.05, 0.37, 0.52 }, { 2.05, 2.08, 0.32, 0.44 }, { 2.45, 2.1, 0.1, 0.14 } }, 2.1) },
	sidaH = { body(0.3, { { 0.45, 2.0, 0.08, 0.12 }, { 0.75, 2.02, 0.28, 0.4 }, { 1.4, 2.05, 0.37, 0.52 }, { 2.05, 2.08, 0.32, 0.44 }, { 2.45, 2.1, 0.1, 0.14 } }, 2.1) },
	bak = { body(0, { { 1.85, 2.45, 0.1, 0.08 }, { 2.15, 2.45, 0.36, 0.26 }, { 2.5, 2.42, 0.3, 0.22 }, { 2.75, 2.4, 0.08, 0.06 } }, 2) },
	skarm = { arc(0, 0.8, -2.15, 0.9, 40, 150, 0.29, 0.14, 2.2) },
	styrkapa = {
		body(0, { { -1.93, 3.4, 0.34, 0.11 }, { -1.72, 3.42, 0.47, 0.15 }, { -1.42, 3.43, 0.42, 0.13 }, { -1.3, 3.43, 0.26, 0.08 } }, 2.6),
		body(0, { { -2.06, 3.6, 0.06, 0.06 }, { -2.0, 3.6, 0.2, 0.2 }, { -1.86, 3.6, 0.21, 0.21 }, { -1.78, 3.6, 0.12, 0.12 } }, 2),
	},
}

-- one panel as a single mesh: vertices relative to its bounding-box centre, plus that centre and the size
function MeshGen.panel(model, panelId)
	local defs = P[model] and P[model][panelId]
	if not defs then return nil end
	local verts, tris = {}, {}
	for _, path in ipairs(defs) do
		local m = sweep(path)
		local off = #verts
		for _, v in ipairs(m.verts) do verts[#verts + 1] = v end
		for _, t in ipairs(m.tris) do tris[#tris + 1] = { t[1] + off, t[2] + off, t[3] + off } end
	end
	local mn, mx = verts[1], verts[1]
	for _, v in ipairs(verts) do mn = mn:Min(v); mx = mx:Max(v) end
	local center = (mn + mx) / 2
	for i, v in ipairs(verts) do verts[i] = v - center end
	return { verts = verts, tris = tris, center = center, size = mx - mn }
end

return MeshGen

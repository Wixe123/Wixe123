-- Roblox datatypes for the emulator: Vector3, Vector2, CFrame, Color3, UDim, UDim2 and the smaller types.
-- Values are immutable like in Roblox; unknown fields raise the same kind of error as Roblox.
local T = {}
local sqrt, sin, cos, abs, atan2, asin = math.sqrt, math.sin, math.cos, math.abs, math.atan2 or function(y, x) return math.atan(y, x) end, math.asin

local TYPE = setmetatable({}, { __mode = "k" }) -- metatable -> type name
T.TYPE = TYPE
local function typeName(v)
	local mt = getmetatable(v)
	return mt and TYPE[mt]
end
T.typeName = typeName

local function bad(tn, k) error(tostring(k) .. " is not a valid member of " .. tn, 3) end
local function ro(tn) return function(_, k) error(tostring(k) .. " cannot be assigned to (" .. tn .. " is immutable)", 2) end end
local function num(v, what)
	if type(v) ~= "number" then error("invalid argument (" .. (what or "number") .. " expected, got " .. (typeName(v) or type(v)) .. ")", 3) end
	return v
end

---------------------------------------------------------------- Vector3
local V3 = {}
local V3mt = {}
TYPE[V3mt] = "Vector3"
local function v3(x, y, z) return setmetatable({ x = x, y = y, z = z }, V3mt) end
T.v3 = v3
local V3M = {}
function V3M.Dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
function V3M.Cross(a, b) return v3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) end
function V3M.Lerp(a, b, t) return v3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t) end
function V3M.Abs(a) return v3(abs(a.x), abs(a.y), abs(a.z)) end
function V3M.Min(a, b) return v3(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z)) end
function V3M.Max(a, b) return v3(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z)) end
function V3M.Floor(a) return v3(math.floor(a.x), math.floor(a.y), math.floor(a.z)) end
function V3M.Ceil(a) return v3(math.ceil(a.x), math.ceil(a.y), math.ceil(a.z)) end
function V3M.Sign(a) local s = function(n) return n > 0 and 1 or (n < 0 and -1 or 0) end return v3(s(a.x), s(a.y), s(a.z)) end
function V3M.FuzzyEq(a, b, e) e = e or 1e-5; return abs(a.x - b.x) <= e and abs(a.y - b.y) <= e and abs(a.z - b.z) <= e end
function V3M.Angle(a, b) local d = V3M.Dot(a, b) / (sqrt(V3M.Dot(a, a)) * sqrt(V3M.Dot(b, b))); return math.acos(math.max(-1, math.min(1, d))) end
V3mt.__index = function(v, k)
	if k == "X" then return v.x elseif k == "Y" then return v.y elseif k == "Z" then return v.z
	elseif k == "Magnitude" then return sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
	elseif k == "Unit" then local m = sqrt(v.x * v.x + v.y * v.y + v.z * v.z); if m == 0 then return v3(0 / 0, 0 / 0, 0 / 0) end return v3(v.x / m, v.y / m, v.z / m)
	elseif V3M[k] then return V3M[k] end
	bad("Vector3", k)
end
V3mt.__newindex = ro("Vector3")
local function isV3(v) return getmetatable(v) == V3mt end
T.isV3 = isV3
V3mt.__add = function(a, b) if not (isV3(a) and isV3(b)) then error("attempt to perform arithmetic (add) on " .. (typeName(a) or type(a)) .. " and " .. (typeName(b) or type(b)), 2) end return v3(a.x + b.x, a.y + b.y, a.z + b.z) end
V3mt.__sub = function(a, b) if not (isV3(a) and isV3(b)) then error("attempt to perform arithmetic (sub) on " .. (typeName(a) or type(a)) .. " and " .. (typeName(b) or type(b)), 2) end return v3(a.x - b.x, a.y - b.y, a.z - b.z) end
V3mt.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.x, a * b.y, a * b.z) end
	if type(b) == "number" then return v3(a.x * b, a.y * b, a.z * b) end
	if isV3(a) and isV3(b) then return v3(a.x * b.x, a.y * b.y, a.z * b.z) end
	error("attempt to perform arithmetic (mul) on " .. (typeName(a) or type(a)) .. " and " .. (typeName(b) or type(b)), 2)
end
V3mt.__div = function(a, b)
	if type(b) == "number" then return v3(a.x / b, a.y / b, a.z / b) end
	if type(a) == "number" then return v3(a / b.x, a / b.y, a / b.z) end
	if isV3(a) and isV3(b) then return v3(a.x / b.x, a.y / b.y, a.z / b.z) end
	error("attempt to perform arithmetic (div) on " .. (typeName(a) or type(a)) .. " and " .. (typeName(b) or type(b)), 2)
end
V3mt.__unm = function(a) return v3(-a.x, -a.y, -a.z) end
V3mt.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
V3mt.__tostring = function(v) return string.format("%g, %g, %g", v.x, v.y, v.z) end
V3.new = function(x, y, z) return v3(x and num(x) or 0, y and num(y) or 0, z and num(z) or 0) end
V3.zero, V3.one = v3(0, 0, 0), v3(1, 1, 1)
V3.xAxis, V3.yAxis, V3.zAxis = v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1)
V3.FromNormalId = function(n)
	local m = { Right = v3(1, 0, 0), Left = v3(-1, 0, 0), Top = v3(0, 1, 0), Bottom = v3(0, -1, 0), Back = v3(0, 0, 1), Front = v3(0, 0, -1) }
	return m[n.Name]
end
T.Vector3 = setmetatable(V3, { __index = function(_, k) bad("Vector3", k) end })

---------------------------------------------------------------- Vector2
local V2 = {}
local V2mt = {}
TYPE[V2mt] = "Vector2"
local function v2(x, y) return setmetatable({ x = x, y = y }, V2mt) end
local V2M = {}
function V2M.Dot(a, b) return a.x * b.x + a.y * b.y end
function V2M.Cross(a, b) return a.x * b.y - a.y * b.x end
function V2M.Lerp(a, b, t) return v2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t) end
function V2M.Abs(a) return v2(abs(a.x), abs(a.y)) end
function V2M.Min(a, b) return v2(math.min(a.x, b.x), math.min(a.y, b.y)) end
function V2M.Max(a, b) return v2(math.max(a.x, b.x), math.max(a.y, b.y)) end
function V2M.FuzzyEq(a, b, e) e = e or 1e-5; return abs(a.x - b.x) <= e and abs(a.y - b.y) <= e end
V2mt.__index = function(v, k)
	if k == "X" then return v.x elseif k == "Y" then return v.y
	elseif k == "Magnitude" then return sqrt(v.x * v.x + v.y * v.y)
	elseif k == "Unit" then local m = sqrt(v.x * v.x + v.y * v.y); return v2(v.x / m, v.y / m)
	elseif V2M[k] then return V2M[k] end
	bad("Vector2", k)
end
V2mt.__newindex = ro("Vector2")
V2mt.__add = function(a, b) return v2(a.x + b.x, a.y + b.y) end
V2mt.__sub = function(a, b) return v2(a.x - b.x, a.y - b.y) end
V2mt.__mul = function(a, b)
	if type(a) == "number" then return v2(a * b.x, a * b.y) end
	if type(b) == "number" then return v2(a.x * b, a.y * b) end
	return v2(a.x * b.x, a.y * b.y)
end
V2mt.__div = function(a, b) if type(b) == "number" then return v2(a.x / b, a.y / b) end return v2(a.x / b.x, a.y / b.y) end
V2mt.__unm = function(a) return v2(-a.x, -a.y) end
V2mt.__eq = function(a, b) return a.x == b.x and a.y == b.y end
V2mt.__tostring = function(v) return string.format("%g, %g", v.x, v.y) end
V2.new = function(x, y) return v2(x and num(x) or 0, y and num(y) or 0) end
V2.zero, V2.one, V2.xAxis, V2.yAxis = v2(0, 0), v2(1, 1), v2(1, 0), v2(0, 1)
T.Vector2 = setmetatable(V2, { __index = function(_, k) bad("Vector2", k) end })

---------------------------------------------------------------- CFrame
-- position p (Vector3) and rotation matrix m[1..9] row-major; columns are Right, Up, Back
local CF = {}
local CFmt = {}
TYPE[CFmt] = "CFrame"
local function cf(px, py, pz, m) return setmetatable({ px = px, py = py, pz = pz, m = m }, CFmt) end
local I3 = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function isCF(v) return getmetatable(v) == CFmt end
T.isCF = isCF
local function mmul(a, b)
	return {
		a[1] * b[1] + a[2] * b[4] + a[3] * b[7], a[1] * b[2] + a[2] * b[5] + a[3] * b[8], a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
		a[4] * b[1] + a[5] * b[4] + a[6] * b[7], a[4] * b[2] + a[5] * b[5] + a[6] * b[8], a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
		a[7] * b[1] + a[8] * b[4] + a[9] * b[7], a[7] * b[2] + a[8] * b[5] + a[9] * b[8], a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
	}
end
local function mvec(a, x, y, z) return a[1] * x + a[2] * y + a[3] * z, a[4] * x + a[5] * y + a[6] * z, a[7] * x + a[8] * y + a[9] * z end
local function mT(a) return { a[1], a[4], a[7], a[2], a[5], a[8], a[3], a[6], a[9] } end
local function rx(t) local c, s = cos(t), sin(t); return { 1, 0, 0, 0, c, -s, 0, s, c } end
local function ry(t) local c, s = cos(t), sin(t); return { c, 0, s, 0, 1, 0, -s, 0, c } end
local function rz(t) local c, s = cos(t), sin(t); return { c, -s, 0, s, c, 0, 0, 0, 1 } end
local function fromQuat(x, y, z, w)
	local n = sqrt(x * x + y * y + z * z + w * w)
	x, y, z, w = x / n, y / n, z / n, w / n
	return {
		1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w),
		2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w),
		2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y),
	}
end
local function toQuat(m)
	local tr = m[1] + m[5] + m[9]
	if tr > 0 then
		local s = sqrt(tr + 1) * 2
		return (m[8] - m[6]) / s, (m[3] - m[7]) / s, (m[4] - m[2]) / s, 0.25 * s
	elseif m[1] > m[5] and m[1] > m[9] then
		local s = sqrt(1 + m[1] - m[5] - m[9]) * 2
		return 0.25 * s, (m[2] + m[4]) / s, (m[3] + m[7]) / s, (m[8] - m[6]) / s
	elseif m[5] > m[9] then
		local s = sqrt(1 + m[5] - m[1] - m[9]) * 2
		return (m[2] + m[4]) / s, 0.25 * s, (m[6] + m[8]) / s, (m[3] - m[7]) / s
	else
		local s = sqrt(1 + m[9] - m[1] - m[5]) * 2
		return (m[3] + m[7]) / s, (m[6] + m[8]) / s, 0.25 * s, (m[4] - m[2]) / s
	end
end
local CFM = {}
function CFM.Inverse(a)
	local t = mT(a.m)
	local x, y, z = mvec(t, a.px, a.py, a.pz)
	return cf(-x, -y, -z, t)
end
function CFM.ToWorldSpace(a, b) return a * b end
function CFM.ToObjectSpace(a, b) return CFM.Inverse(a) * b end
function CFM.PointToWorldSpace(a, v) return a * v end
function CFM.PointToObjectSpace(a, v) return CFM.Inverse(a) * v end
function CFM.VectorToWorldSpace(a, v) local x, y, z = mvec(a.m, v.x, v.y, v.z); return v3(x, y, z) end
function CFM.VectorToObjectSpace(a, v) local x, y, z = mvec(mT(a.m), v.x, v.y, v.z); return v3(x, y, z) end
function CFM.GetComponents(a) local m = a.m; return a.px, a.py, a.pz, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9] end
CFM.components = CFM.GetComponents
function CFM.ToEulerAnglesXYZ(a)
	local m = a.m
	local y = asin(math.max(-1, math.min(1, m[3])))
	local x = atan2(-m[6], m[9])
	local z = atan2(-m[2], m[1])
	return x, y, z
end
function CFM.ToEulerAnglesYXZ(a)
	local m = a.m
	local x = asin(math.max(-1, math.min(1, -m[6])))
	local y = atan2(m[3], m[9])
	local z = atan2(m[4], m[5])
	return x, y, z
end
CFM.ToOrientation = CFM.ToEulerAnglesYXZ
function CFM.ToAxisAngle(a)
	local x, y, z, w = toQuat(a.m)
	local ang = 2 * math.acos(math.max(-1, math.min(1, w)))
	local s = sqrt(1 - w * w)
	if s < 1e-6 then return v3(1, 0, 0), 0 end
	return v3(x / s, y / s, z / s), ang
end
function CFM.Lerp(a, b, t)
	local ax, ay, az, aw = toQuat(a.m)
	local bx, by, bz, bw = toQuat(b.m)
	local d = ax * bx + ay * by + az * bz + aw * bw
	if d < 0 then bx, by, bz, bw, d = -bx, -by, -bz, -bw, -d end
	local qx, qy, qz, qw
	if d > 0.9995 then
		qx, qy, qz, qw = ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t, aw + (bw - aw) * t
	else
		local th = math.acos(d)
		local s0, s1 = sin((1 - t) * th) / sin(th), sin(t * th) / sin(th)
		qx, qy, qz, qw = ax * s0 + bx * s1, ay * s0 + by * s1, az * s0 + bz * s1, aw * s0 + bw * s1
	end
	return cf(a.px + (b.px - a.px) * t, a.py + (b.py - a.py) * t, a.pz + (b.pz - a.pz) * t, fromQuat(qx, qy, qz, qw))
end
function CFM.Orthonormalize(a) return cf(a.px, a.py, a.pz, fromQuat(toQuat(a.m))) end
function CFM.FuzzyEq(a, b, e)
	e = e or 1e-5
	if abs(a.px - b.px) > e or abs(a.py - b.py) > e or abs(a.pz - b.pz) > e then return false end
	for i = 1, 9 do if abs(a.m[i] - b.m[i]) > e then return false end end
	return true
end
CFmt.__index = function(c, k)
	local m = c.m
	if k == "Position" or k == "p" then return v3(c.px, c.py, c.pz)
	elseif k == "X" then return c.px elseif k == "Y" then return c.py elseif k == "Z" then return c.pz
	elseif k == "LookVector" then return v3(-m[3], -m[6], -m[9])
	elseif k == "RightVector" or k == "XVector" then return v3(m[1], m[4], m[7])
	elseif k == "UpVector" or k == "YVector" then return v3(m[2], m[5], m[8])
	elseif k == "ZVector" then return v3(m[3], m[6], m[9])
	elseif k == "Rotation" then return cf(0, 0, 0, m)
	elseif CFM[k] then return CFM[k] end
	bad("CFrame", k)
end
CFmt.__newindex = ro("CFrame")
CFmt.__mul = function(a, b)
	if not isCF(a) then error("attempt to perform arithmetic (mul) on " .. (typeName(a) or type(a)) .. " and CFrame", 2) end
	if isCF(b) then
		local x, y, z = mvec(a.m, b.px, b.py, b.pz)
		return cf(a.px + x, a.py + y, a.pz + z, mmul(a.m, b.m))
	elseif isV3(b) then
		local x, y, z = mvec(a.m, b.x, b.y, b.z)
		return v3(a.px + x, a.py + y, a.pz + z)
	end
	error("attempt to perform arithmetic (mul) on CFrame and " .. (typeName(b) or type(b)), 2)
end
CFmt.__add = function(a, b)
	if not (isCF(a) and isV3(b)) then error("attempt to perform arithmetic (add) on " .. (typeName(a) or type(a)) .. " and " .. (typeName(b) or type(b)), 2) end
	return cf(a.px + b.x, a.py + b.y, a.pz + b.z, a.m)
end
CFmt.__sub = function(a, b)
	if not (isCF(a) and isV3(b)) then error("attempt to perform arithmetic (sub) on " .. (typeName(a) or type(a)) .. " and " .. (typeName(b) or type(b)), 2) end
	return cf(a.px - b.x, a.py - b.y, a.pz - b.z, a.m)
end
CFmt.__eq = function(a, b)
	if a.px ~= b.px or a.py ~= b.py or a.pz ~= b.pz then return false end
	for i = 1, 9 do if a.m[i] ~= b.m[i] then return false end end
	return true
end
CFmt.__tostring = function(c) local m = c.m; return string.format("%g, %g, %g, %g, %g, %g, %g, %g, %g, %g, %g, %g", c.px, c.py, c.pz, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9]) end
local function lookAt(pos, target, up)
	up = up or v3(0, 1, 0)
	local f = (target - pos)
	local fm = f.Magnitude
	if fm < 1e-9 then return cf(pos.x, pos.y, pos.z, I3) end
	f = f / fm
	local r = V3M.Cross(f, up)
	if r.Magnitude < 1e-6 then r = V3M.Cross(f, v3(0, 0, f.y > 0 and 1 or -1)) end
	r = r.Unit
	local u = V3M.Cross(r, f)
	return cf(pos.x, pos.y, pos.z, { r.x, u.x, -f.x, r.y, u.y, -f.y, r.z, u.z, -f.z })
end
CF.new = function(a, b, c, ...)
	if a == nil then return cf(0, 0, 0, I3) end
	if isV3(a) then
		if b ~= nil then
			if not isV3(b) then error("CFrame.new: expected Vector3 for argument #2", 2) end
			return lookAt(a, b)
		end
		return cf(a.x, a.y, a.z, I3)
	end
	local rest = { ... }
	if #rest == 9 then
		for i = 1, 9 do num(rest[i]) end
		return cf(num(a), num(b), num(c), rest)
	end
	if #rest == 4 then -- quaternion
		return cf(num(a), num(b), num(c), fromQuat(rest[1], rest[2], rest[3], rest[4]))
	end
	if #rest ~= 0 then error("CFrame.new: invalid number of arguments", 2) end
	return cf(num(a, "x"), num(b, "y"), num(c, "z"), I3)
end
CF.lookAt = function(p, t, up) return lookAt(p, t, up) end
CF.Angles = function(x, y, z) return cf(0, 0, 0, mmul(mmul(rx(num(x or 0)), ry(num(y or 0))), rz(num(z or 0)))) end
CF.fromEulerAnglesXYZ = CF.Angles
CF.fromEulerAnglesYXZ = function(x, y, z) return cf(0, 0, 0, mmul(mmul(ry(num(y or 0)), rx(num(x or 0))), rz(num(z or 0)))) end
CF.fromOrientation = CF.fromEulerAnglesYXZ
CF.fromEulerAngles = function(x, y, z, order) return CF.Angles(x, y, z) end
CF.fromAxisAngle = function(axis, ang)
	local u = axis.Unit
	local s = sin(ang / 2)
	return cf(0, 0, 0, fromQuat(u.x * s, u.y * s, u.z * s, cos(ang / 2)))
end
CF.fromMatrix = function(pos, vx, vy, vz)
	vz = vz or V3M.Cross(vx, vy).Unit
	return cf(pos.x, pos.y, pos.z, { vx.x, vy.x, vz.x, vx.y, vy.y, vz.y, vx.z, vy.z, vz.z })
end
CF.lookAlong = function(p, dir, up) return lookAt(p, p + dir, up) end
CF.identity = cf(0, 0, 0, I3)
T.CFrame = setmetatable(CF, { __index = function(_, k) bad("CFrame", k) end })
T.cf = cf

---------------------------------------------------------------- Color3
local C3 = {}
local C3mt = {}
TYPE[C3mt] = "Color3"
local function c3(r, g, b) return setmetatable({ r = r, g = g, b = b }, C3mt) end
local C3M = {}
function C3M.Lerp(a, b, t) return c3(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t) end
function C3M.ToHSV(c)
	local r, g, b = c.r, c.g, c.b
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	local h, s, v = 0, 0, mx
	local d = mx - mn
	if mx > 0 then s = d / mx end
	if d > 0 then
		if mx == r then h = (g - b) / d % 6 elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
		h = h / 6
	end
	return h, s, v
end
function C3M.ToHex(c)
	local f = function(x) return math.floor(math.max(0, math.min(1, x)) * 255 + 0.5) end
	return string.format("%02x%02x%02x", f(c.r), f(c.g), f(c.b))
end
C3mt.__index = function(c, k)
	if k == "R" then return c.r elseif k == "G" then return c.g elseif k == "B" then return c.b elseif C3M[k] then return C3M[k] end
	bad("Color3", k)
end
C3mt.__newindex = ro("Color3")
C3mt.__eq = function(a, b) return a.r == b.r and a.g == b.g and a.b == b.b end
C3mt.__tostring = function(c) return string.format("%g, %g, %g", c.r, c.g, c.b) end
C3.new = function(r, g, b) return c3(r and num(r) or 0, g and num(g) or 0, b and num(b) or 0) end
C3.fromRGB = function(r, g, b) return c3((r and num(r) or 0) / 255, (g and num(g) or 0) / 255, (b and num(b) or 0) / 255) end
C3.fromHSV = function(h, s, v)
	num(h); num(s); num(v)
	h = (h % 1) * 6
	local i = math.floor(h)
	local f = h - i
	local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
	if i == 0 then return c3(v, t, p) elseif i == 1 then return c3(q, v, p) elseif i == 2 then return c3(p, v, t)
	elseif i == 3 then return c3(p, q, v) elseif i == 4 then return c3(t, p, v) else return c3(v, p, q) end
end
C3.toHSV = function(c) return C3M.ToHSV(c) end
C3.fromHex = function(h)
	if type(h) ~= "string" then error("Color3.fromHex: string expected", 2) end
	h = h:gsub("^#", "")
	if not h:match("^%x%x%x%x%x%x$") then error("Unable to convert characters to hex value", 2) end
	return c3(tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255)
end
T.Color3 = setmetatable(C3, { __index = function(_, k) bad("Color3", k) end })

---------------------------------------------------------------- UDim / UDim2
local UD, UDmt = {}, {}
TYPE[UDmt] = "UDim"
local function ud(s, o) return setmetatable({ s = s, o = o }, UDmt) end
UDmt.__index = function(u, k) if k == "Scale" then return u.s elseif k == "Offset" then return u.o end bad("UDim", k) end
UDmt.__newindex = ro("UDim")
UDmt.__add = function(a, b) return ud(a.s + b.s, a.o + b.o) end
UDmt.__sub = function(a, b) return ud(a.s - b.s, a.o - b.o) end
UDmt.__eq = function(a, b) return a.s == b.s and a.o == b.o end
UDmt.__tostring = function(u) return string.format("{%g, %g}", u.s, u.o) end
UD.new = function(s, o) return ud(s and num(s) or 0, o and num(o) or 0) end
T.UDim = UD

local U2, U2mt = {}, {}
TYPE[U2mt] = "UDim2"
local function u2(xs, xo, ys, yo) return setmetatable({ xs = xs, xo = xo, ys = ys, yo = yo }, U2mt) end
local U2M = {}
function U2M.Lerp(a, b, t) return u2(a.xs + (b.xs - a.xs) * t, a.xo + (b.xo - a.xo) * t, a.ys + (b.ys - a.ys) * t, a.yo + (b.yo - a.yo) * t) end
U2mt.__index = function(u, k)
	if k == "X" or k == "Width" then return ud(u.xs, u.xo) elseif k == "Y" or k == "Height" then return ud(u.ys, u.yo)
	elseif U2M[k] then return U2M[k] end
	bad("UDim2", k)
end
U2mt.__newindex = ro("UDim2")
U2mt.__add = function(a, b) return u2(a.xs + b.xs, a.xo + b.xo, a.ys + b.ys, a.yo + b.yo) end
U2mt.__sub = function(a, b) return u2(a.xs - b.xs, a.xo - b.xo, a.ys - b.ys, a.yo - b.yo) end
U2mt.__unm = function(a) return u2(-a.xs, -a.xo, -a.ys, -a.yo) end
U2mt.__eq = function(a, b) return a.xs == b.xs and a.xo == b.xo and a.ys == b.ys and a.yo == b.yo end
U2mt.__tostring = function(u) return string.format("{%g, %g}, {%g, %g}", u.xs, u.xo, u.ys, u.yo) end
U2.new = function(a, b, c, d)
	if getmetatable(a) == UDmt then return u2(a.s, a.o, b.s, b.o) end
	return u2(a and num(a) or 0, b and num(b) or 0, c and num(c) or 0, d and num(d) or 0)
end
U2.fromScale = function(x, y) return u2(num(x or 0), 0, num(y or 0), 0) end
U2.fromOffset = function(x, y) return u2(0, num(x or 0), 0, num(y or 0)) end
T.UDim2 = setmetatable(U2, { __index = function(_, k) bad("UDim2", k) end })

---------------------------------------------------------------- small types
local function record(tn, fields, ctor)
	local mt = {}
	TYPE[mt] = tn
	mt.__index = function(_, k) bad(tn, k) end
	mt.__newindex = ro(tn)
	mt.__tostring = function() return tn end
	local lib = { new = function(...) return setmetatable(ctor(...), mt) end }
	return setmetatable(lib, { __index = function(_, k) bad(tn, k) end }), mt
end
local function fieldIndex(mt, tn) mt.__index = function(t, k) local v = rawget(t, "_" .. k); if v ~= nil then return v end bad(tn, k) end end

local mt
T.NumberRange, mt = record("NumberRange", nil, function(a, b) return { _Min = num(a), _Max = b and num(b) or a } end); fieldIndex(mt, "NumberRange")
T.NumberSequenceKeypoint, mt = record("NumberSequenceKeypoint", nil, function(t, v, e) return { _Time = num(t), _Value = num(v), _Envelope = e or 0 } end); fieldIndex(mt, "NumberSequenceKeypoint")
T.NumberSequence, mt = record("NumberSequence", nil, function(a, b)
	if type(a) == "table" and getmetatable(a) == nil then return { _Keypoints = a } end
	return { _Keypoints = { T.NumberSequenceKeypoint.new(0, num(a)), T.NumberSequenceKeypoint.new(1, b and num(b) or a) } }
end); fieldIndex(mt, "NumberSequence")
T.ColorSequenceKeypoint, mt = record("ColorSequenceKeypoint", nil, function(t, c)
	if getmetatable(c) ~= C3mt then error("ColorSequenceKeypoint.new: Color3 expected", 3) end
	return { _Time = num(t), _Value = c }
end); fieldIndex(mt, "ColorSequenceKeypoint")
T.ColorSequence, mt = record("ColorSequence", nil, function(a, b)
	if getmetatable(a) == C3mt then return { _Keypoints = { T.ColorSequenceKeypoint.new(0, a), T.ColorSequenceKeypoint.new(1, b or a) } } end
	if type(a) ~= "table" then error("ColorSequence.new: Color3 or keypoints expected", 3) end
	return { _Keypoints = a }
end); fieldIndex(mt, "ColorSequence")
T.Rect, mt = record("Rect", nil, function(a, b, c, d)
	if getmetatable(a) == V2mt then return { _Min = a, _Max = b, _Width = b.x - a.x, _Height = b.y - a.y } end
	return { _Min = v2(a or 0, b or 0), _Max = v2(c or 0, d or 0), _Width = (c or 0) - (a or 0), _Height = (d or 0) - (b or 0) }
end); fieldIndex(mt, "Rect")
T.TweenInfo, mt = record("TweenInfo", nil, function(time, style, dir, rep, rev, delay)
	return { _Time = time or 1, _EasingStyle = style, _EasingDirection = dir, _RepeatCount = rep or 0, _Reverses = rev or false, _DelayTime = delay or 0 }
end); fieldIndex(mt, "TweenInfo")
T.PhysicalProperties, mt = record("PhysicalProperties", nil, function(d, f, e, fw, ew)
	if type(d) ~= "number" then return { _Density = 0.7, _Friction = 0.3, _Elasticity = 0.5, _FrictionWeight = 1, _ElasticityWeight = 1 } end
	return { _Density = d, _Friction = f or 0.3, _Elasticity = e or 0.5, _FrictionWeight = fw or 1, _ElasticityWeight = ew or 1 }
end); fieldIndex(mt, "PhysicalProperties")
T.Ray, mt = record("Ray", nil, function(o, d) return { _Origin = o, _Direction = d, _Unit = nil } end); fieldIndex(mt, "Ray")

-- mutable parameter objects
local function params(tn, defaults, enumCheck)
	local mt = {}
	TYPE[mt] = tn
	mt.__index = function(t, k)
		local v = rawget(t, "_" .. k)
		if v ~= nil then return v end
		if defaults[k] ~= nil then return defaults[k] end
		if k == "AddToFilter" then return function(self, x) local f = rawget(self, "_FilterDescendantsInstances") or {}; if type(x) == "table" and not x.__inst then for _, i in ipairs(x) do f[#f + 1] = i end else f[#f + 1] = x end rawset(self, "_FilterDescendantsInstances", f) end end
		bad(tn, k)
	end
	mt.__newindex = function(t, k, v)
		if defaults[k] == nil then bad(tn, k) end
		rawset(t, "_" .. k, v)
	end
	return setmetatable({ new = function() return setmetatable({}, mt) end }, { __index = function(_, k) bad(tn, k) end })
end
T.RaycastParams = params("RaycastParams", { FilterDescendantsInstances = {}, FilterType = "Exclude", IgnoreWater = false, CollisionGroup = "Default", RespectCanCollide = false, BruteForceAllSlow = false })
T.OverlapParams = params("OverlapParams", { FilterDescendantsInstances = {}, FilterType = "Exclude", MaxParts = 0, CollisionGroup = "Default", RespectCanCollide = false, BruteForceAllSlow = false })

-- Random
local Rmt = {}
TYPE[Rmt] = "Random"
local RM = {}
function RM.NextNumber(r, a, b)
	r.s = (r.s * 1103515245 + 12345) % 2147483648
	local f = r.s / 2147483648
	if a then return a + (b - a) * f end
	return f
end
function RM.NextInteger(r, a, b) return math.floor(RM.NextNumber(r, a, b + 1)) end
function RM.NextUnitVector(r) return v3(RM.NextNumber(r, -1, 1), RM.NextNumber(r, -1, 1), RM.NextNumber(r, -1, 1)).Unit end
Rmt.__index = function(_, k) if RM[k] then return RM[k] end bad("Random", k) end
T.Random = { new = function(seed) return setmetatable({ s = math.floor(seed or 1) % 2147483648 }, Rmt) end }

-- Font
local Fmt = {}
TYPE[Fmt] = "Font"
Fmt.__index = function(t, k) local v = rawget(t, "_" .. k); if v ~= nil then return v end bad("Font", k) end
T.Font = {
	new = function(family, weight, style) return setmetatable({ _Family = family, _Weight = weight, _Style = style }, Fmt) end,
	fromEnum = function(e) return setmetatable({ _Family = "rbxasset://fonts/families/" .. tostring(e.Name) .. ".json" }, Fmt) end,
	fromName = function(n, weight, style) return setmetatable({ _Family = "rbxasset://fonts/families/" .. n .. ".json", _Weight = weight, _Style = style }, Fmt) end,
}

-- BrickColor (only what is commonly used)
local BCmt = {}
TYPE[BCmt] = "BrickColor"
BCmt.__index = function(t, k) if k == "Color" then return t.c elseif k == "Name" then return t.n end bad("BrickColor", k) end
local BRICK = { White = { 242, 243, 243 }, Black = { 27, 42, 53 }, ["Really red"] = { 255, 0, 0 }, ["Bright red"] = { 196, 40, 28 }, ["Bright blue"] = { 13, 105, 172 }, ["Medium stone grey"] = { 163, 162, 165 }, ["Dark stone grey"] = { 99, 95, 98 }, ["Bright yellow"] = { 245, 205, 48 }, ["Lime green"] = { 0, 255, 0 }, ["Institutional white"] = { 248, 248, 248 } }
T.BrickColor = {
	new = function(n)
		local c = BRICK[n]
		if not c then error("BrickColor.new: unknown name '" .. tostring(n) .. "' (emulator knows few names)", 2) end
		return setmetatable({ n = n, c = C3.fromRGB(c[1], c[2], c[3]) }, BCmt)
	end,
	White = function() return T.BrickColor.new("White") end,
	Black = function() return T.BrickColor.new("Black") end,
}

return T

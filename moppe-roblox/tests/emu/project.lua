-- Loads src/ into the emulator's DataModel with the same layout as default.project.json / tools/build_place.py:
--   src/shared/*.lua          -> ReplicatedStorage.Shared (ModuleScript)
--   src/server/*.server.lua   -> ServerScriptService (Script), other src/server/*.lua -> ModuleScript there
--   src/client/*.client.lua   -> StarterPlayerScripts (LocalScript), other src/client/*.lua -> ModuleScript there
local items = {}
local function scan(dir, kindScript, suffix, kindModule)
	for name in (HOST_LIST(ROOT .. "/src/" .. dir) .. "\n"):gmatch("(.-)\n") do
		if name:match("%.lua$") then
			local src = HOST_READ(ROOT .. "/src/" .. dir .. "/" .. name)
			if suffix and name:sub(-#suffix) == suffix then
				items[#items + 1] = { kind = kindScript, name = name:sub(1, -#suffix - 1), source = src }
			else
				items[#items + 1] = { kind = kindModule, name = name:sub(1, -5), source = src }
			end
		end
	end
end
scan("shared", nil, nil, "module")
scan("server", "server", ".server.lua", "servermodule")
scan("client", "client", ".client.lua", "clientmodule")
E.loadProject(items)

-- JSON for snapshots (compact numbers)
local function enc(v, out)
	local t = type(v)
	if t == "nil" then out[#out + 1] = "null"
	elseif t == "boolean" then out[#out + 1] = tostring(v)
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then out[#out + 1] = (v == math.huge and "1e30") or (v == -math.huge and "-1e30") or "0"
		elseif math.floor(v) == v and math.abs(v) < 1e15 then out[#out + 1] = string.format("%d", v)
		else out[#out + 1] = string.format("%.5g", v) end
	elseif t == "string" then out[#out + 1] = '"' .. v:gsub('[%c"\\]', function(c) local m = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" }; return m[c] or string.format("\\u%04x", c:byte()) end) .. '"'
	elseif t == "table" then
		if #v > 0 or next(v) == nil then
			out[#out + 1] = "["
			for i, x in ipairs(v) do if i > 1 then out[#out + 1] = "," end enc(x, out) end
			out[#out + 1] = "]"
		else
			out[#out + 1] = "{"
			local first = true
			for k, x in pairs(v) do
				if type(k) == "string" and type(x) ~= "function" then
					if not first then out[#out + 1] = "," end
					first = false
					enc(k, out); out[#out + 1] = ":"; enc(x, out)
				end
			end
			out[#out + 1] = "}"
		end
	else out[#out + 1] = "null" end
end
function E.json(v) local out = {}; enc(v, out); return table.concat(out) end
E.shots = {}
function E.shot(name, opts)
	local snap = E.snapshot(opts)
	local dir = ROOT .. "/tests/out"
	HOST_WRITE(dir .. "/" .. name .. ".json", E.json(snap))
	E.shots[#E.shots + 1] = name
	E.out("SHOT", name .. " (" .. #snap.parts .. " parts, " .. #snap.gui .. " gui elements, " .. #snap.lights .. " lights)")
end
-- point the camera somewhere for the next shots (nil restores the follow camera)
function E.lookFrom(from, at, fov)
	if not from then E.cameraOverride = nil; return end
	E.cameraOverride = true
	local cam = E.currentCamera(E.player and E.player.ctx)
	cam.props.CFrame = E.T.CFrame.lookAt(from, at)
	if fov then cam.props.FieldOfView = fov end
end
-- checks used by scenarios
E.checks = { pass = 0, fail = 0 }
function E.check(name, cond, detail)
	if cond then E.checks.pass = E.checks.pass + 1; E.out("PASS", name)
	else E.checks.fail = E.checks.fail + 1; E.out("FAIL", name .. (detail ~= nil and (" -> " .. tostring(detail)) or "")) end
end

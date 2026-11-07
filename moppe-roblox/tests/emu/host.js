// Runs the game's Lua sources in the Roblox emulator (fengari, Lua 5.3 configured to print numbers like Luau).
// Usage: node emu/host.js <scenario.lua> [--quiet]
// The scenario gets the emulator as global E. Snapshots are written as JSON next to the scenario output dir.
process.env.FENGARICONF = JSON.stringify({ LUA_COMPAT_FLOATSTRING: true });
const fs = require('fs'), path = require('path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');

const HERE = __dirname;
const ROOT = path.resolve(HERE, '..', '..');
const scenario = process.argv[2];
const quiet = process.argv.includes('--quiet');
if (!scenario) { console.error('usage: node emu/host.js <scenario.lua>'); process.exit(2); }

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
// JS functions receive the calling Lua state (it may be a coroutine), so every helper works on that state
function reg(name, fn) { lua.lua_pushjsfunction(L, (S) => fn(S)); lua.lua_setglobal(L, to_luastring(name)); }
const str = (S, i) => to_jsstring(lauxlib.luaL_checkstring(S, i));
reg('HOST_READ', (S) => { const p = str(S, 1); try { lua.lua_pushstring(S, to_luastring(fs.readFileSync(p, 'utf8'))); } catch (e) { lua.lua_pushnil(S); } return 1; });
reg('HOST_LIST', (S) => { const p = str(S, 1); let r = []; try { r = fs.readdirSync(p).sort(); } catch (e) {} lua.lua_pushstring(S, to_luastring(r.join('\n'))); return 1; });
reg('HOST_WRITE', (S) => { const p = str(S, 1); fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, str(S, 2)); return 0; });
reg('HOST_ECHO', (S) => { if (!quiet) process.stdout.write(str(S, 1) + '\n'); return 0; });
reg('HOST_CLOCK', (S) => { lua.lua_pushnumber(S, Date.now() / 1000); return 1; });

const boot = `
EMU_DIR = ${JSON.stringify(HERE)}
ROOT = ${JSON.stringify(ROOT)}
local loaded = {}
function EMU_REQUIRE(name)
  if loaded[name] then return loaded[name] end
  local src = HOST_READ(EMU_DIR .. "/" .. name .. ".lua")
  if not src then error("emu module missing: " .. name) end
  local f = assert(load(src, "=emu/" .. name, "t", _ENV))
  loaded[name] = f()
  return loaded[name]
end
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
E = EMU_REQUIRE("runtime")
string.split = function(s, sep) return E.makeGlobals({name="x", cache={}}).string.split(s, sep) end
E.echo = function(kind, msg) if kind ~= "PRINT" or not QUIET then HOST_ECHO(kind .. ": " .. msg) end end
EMU_REQUIRE("project")
local src = HOST_READ(${JSON.stringify(path.resolve(scenario))})
local f = assert(load(src, "=scenario", "t", _ENV))
local ok, err = xpcall(f, debug.traceback)
if not ok then E.reportError("scenario crashed: " .. tostring(err), nil, {name="scenario"}) end
EMU_REQUIRE("report")
`;
if (lauxlib.luaL_loadstring(L, to_luastring(boot)) !== lua.LUA_OK) { console.error(to_jsstring(lua.lua_tostring(L, -1))); process.exit(2); }
const t0 = Date.now();
if (lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) { console.error('emulator crashed: ' + to_jsstring(lua.lua_tostring(L, -1))); process.exit(2); }
lua.lua_getglobal(L, to_luastring('EXIT_CODE'));
const code = lua.lua_tointeger(L, -1);
if (!quiet) console.log(`(${((Date.now() - t0) / 1000).toFixed(1)} s real time)`);
process.exit(code);

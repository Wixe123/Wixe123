// Runs Lua tests against the Roblox project's shared modules in fengari (Lua 5.3 in JS) with small stand-ins for Roblox types.
const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const dir=process.argv[2],test=fs.readFileSync(process.argv[3],'utf8');
let pre='SRC={}\n';for(const f of fs.readdirSync(dir).filter(f=>f.endsWith('.lua'))){const s=fs.readFileSync(path.join(dir,f),'utf8');if(s.includes(']=====]'))throw f;pre+=`SRC["${f.replace('.lua','')}"]=[=====[${s}]=====]\n`}
const harness=`
math.atan2 = math.atan2 or function(y,x) return math.atan(y,x) end
Color3 = { fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end, fromHex=function(h) return {R=tonumber(h:sub(2,3),16)/255,G=tonumber(h:sub(4,5),16)/255,B=tonumber(h:sub(6,7),16)/255} end, new=function(r,g,b) return {R=r,G=g,B=b} end }
local cache={}
Shared=setmetatable({},{__index=function(_,k) return {__mod=k} end})
local rq=require
function require(x) if type(x)=="table" and x.__mod then
  local k=x.__mod; if cache[k]==nil then local env=setmetatable({script={Parent=Shared}},{__index=_G}); local f=assert(load(SRC[k],k,"t",env)); cache[k]=f() end; return cache[k] end return rq(x) end
PASS,FAIL=0,0
function ok(name,c,x) if c then PASS=PASS+1 else FAIL=FAIL+1 end print((c and "PASS " or "FAIL ")..name..(x~=nil and (" -> "..tostring(x)) or "")) end
`;
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
const st=lauxlib.luaL_dostring(L,to_luastring(pre+harness+test));
if(st!==0){console.log('LUA-FEL:',to_jsstring(lua.lua_tostring(L,-1)));process.exit(1)}

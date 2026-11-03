const l=require('luaparse'),fs=require('fs'),path=require('path');
function globals(src){const ast=l.parse(src,{luaVersion:'5.1',scope:true,locations:true});const g=new Map();
 (function walk(n){if(!n||typeof n!=='object')return;if(Array.isArray(n)){n.forEach(walk);return}
  if(n.type==='Identifier'&&n.isLocal===false&&!g.has(n.name))g.set(n.name,n.loc.start.line);
  for(const k in n)if(k!=='loc'&&k!=='range')walk(n[k])})(ast);return g}
if(process.argv[2]==='--selftest'){console.log([...globals('local Confg = 1\nlocal function f() return Config.X + vector3.new(1) end').keys()]);process.exit()}
const ok=new Set('game workspace script Instance Vector3 Vector2 CFrame Color3 UDim UDim2 Enum PhysicalProperties Random task math string table pairs ipairs tostring tonumber type pcall warn require print error os select next setmetatable getmetatable rawget unpack'.split(' '));
const walkd=d=>fs.readdirSync(d).flatMap(f=>{const p=path.join(d,f);return fs.statSync(p).isDirectory()?walkd(p):p.endsWith('.lua')?[p]:[]});
for(const f of walkd(process.argv[2])){const odd=[...globals(fs.readFileSync(f,'utf8'))].filter(([n])=>!ok.has(n));console.log(f.padEnd(40),odd.length?'OKÄNDA: '+odd.map(([n,l])=>n+' (rad '+l+')').join(', '):'ok')}

// Parses every Lua file in src/ as Lua 5.1 (Luau accepts 5.1 syntax), so nothing Lua-5.3-only slips through.
const fs = require('fs'), path = require('path');
const luaparse = require('luaparse');
const root = path.resolve(__dirname, '..', 'src');
let bad = 0, n = 0;
for (const dir of fs.readdirSync(root)) {
  for (const f of fs.readdirSync(path.join(root, dir)).filter(f => f.endsWith('.lua'))) {
    n++;
    try { luaparse.parse(fs.readFileSync(path.join(root, dir, f), 'utf8'), { luaVersion: '5.1' }); }
    catch (e) { bad++; console.log(`${dir}/${f}: ${e.message}`); }
  }
}
console.log(`${n} filer, ${bad} med syntaxfel`);
process.exit(bad ? 1 : 0);

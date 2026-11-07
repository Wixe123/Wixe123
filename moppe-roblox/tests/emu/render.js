// Renders emulator snapshots (tests/out/*.json) to PNG with three.js in headless Chromium.
// An approximation of Roblox: same geometry, colours, materials (procedural), lights, GUI and prompts.
// Usage: node emu/render.js [name ...]   (no names = every snapshot in tests/out)
const fs = require('fs'), path = require('path'), http = require('http');
const { chromium } = require('playwright');
const OUT = path.resolve(__dirname, '..', 'out');
const THREE_DIR = path.resolve(path.dirname(require.resolve('three')), '..');

const page = `<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;background:#000;overflow:hidden;font-family:"Segoe UI",Arial,Helvetica,sans-serif}
#c{position:absolute;left:0;top:0}
#ui{position:absolute;left:0;top:0;pointer-events:none}
.g{position:absolute;box-sizing:border-box;overflow:visible;white-space:pre}
.t{position:absolute;inset:0;display:flex;line-height:1.05;padding:0 2px;box-sizing:border-box}
.top{position:absolute;left:0;top:0;right:0;height:58px;background:linear-gradient(rgba(0,0,0,.35),rgba(0,0,0,0));}
.rb{position:absolute;width:44px;height:44px;border-radius:22px;background:rgba(18,18,21,.7);top:7px}
.pr{position:absolute;transform:translate(-50%,-50%);display:flex;align-items:center;gap:8px;background:rgba(25,25,25,.75);border-radius:8px;padding:6px 12px 6px 6px;color:#fff;font-size:14px}
.pr .k{width:32px;height:32px;border-radius:6px;border:2px solid #fff;display:flex;align-items:center;justify-content:center;font-weight:700}
.pr .o{font-size:11px;opacity:.75}
</style></head><body><canvas id="c"></canvas><div id="ui"></div>
<script type="importmap">{"imports":{"three":"/three/build/three.module.js"}}</script>
<script type="module" src="/render_page.mjs"></script></body></html>`;

(async () => {
  let names = process.argv.slice(2);
  if (!names.length) names = fs.readdirSync(OUT).filter(f => f.endsWith('.json')).map(f => f.replace(/\.json$/, ''));
  const server = http.createServer((req, res) => {
    if (req.url === '/') { res.setHeader('content-type', 'text/html'); return res.end(page); }
    if (req.url === '/render_page.mjs') { res.setHeader('content-type', 'text/javascript'); return res.end(fs.readFileSync(path.join(__dirname, 'render_page.mjs'))); }
    if (req.url.startsWith('/three/')) {
      const p = path.join(THREE_DIR, req.url.slice(7));
      if (p.startsWith(THREE_DIR) && fs.existsSync(p)) { res.setHeader('content-type', 'text/javascript'); return res.end(fs.readFileSync(p)); }
    }
    res.statusCode = 404; res.end();
  });
  await new Promise(r => server.listen(0, '127.0.0.1', r));
  const port = server.address().port;
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  for (const n of names) {
    const S = JSON.parse(fs.readFileSync(path.join(OUT, n + '.json'), 'utf8'));
    const pg = await browser.newPage({ viewport: { width: S.view.w, height: S.view.h }, deviceScaleFactor: 1 });
    const errs = [];
    pg.on('pageerror', e => errs.push(e.message));
    pg.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
    await pg.goto(`http://127.0.0.1:${port}/`);
    await pg.waitForFunction(() => window.ready === true);
    await pg.evaluate(s => window.renderSnap(s), S);
    await pg.screenshot({ path: path.join(OUT, n + '.png') });
    console.log('rendered', n + '.png', errs.length ? 'errors: ' + errs.join(' | ') : '');
    await pg.close();
  }
  await browser.close();
  server.close();
})().catch(e => { console.error(e); process.exit(1); });

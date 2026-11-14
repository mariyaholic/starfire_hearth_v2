// Verify release builds ignore the destructive debug smoke route and retain an existing slot.
import { createServer } from 'node:http';
import { readFile, mkdir } from 'node:fs/promises';
import { execSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { extname, join, normalize } from 'node:path';

const dir = process.argv[2] ?? 'build/web';
const out = process.argv[3] ?? 'screens/web';
const modules = process.env.PLAYWRIGHT_DIR ?? execSync('npm root -g').toString().trim();
const { chromium } = createRequire(join(modules, 'noop.js'))('playwright');
const types = {'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
const server = createServer(async (req, res) => {
  const file = normalize(decodeURIComponent(new URL(req.url, 'http://x').pathname)).replace(/^([/\\])+/, '') || 'index.html';
  try { const data = await readFile(join(dir, file)); res.writeHead(200, {'Content-Type':types[extname(file)] ?? 'application/octet-stream'}); res.end(data); }
  catch { res.writeHead(404); res.end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const browser = await chromium.launch({executablePath:process.env.M11_CHROMIUM_PATH || undefined,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
try {
  const page = await browser.newPage({viewport:{width:1280,height:800}});
  const messages = [];
  page.on('console', msg => { if (msg.text().startsWith('Starfire Hearth smoke:')) messages.push(msg.text()); });
  const url = `http://127.0.0.1:${server.address().port}/index.html`;
  const ready = () => page.waitForFunction(() => !document.getElementById('status'), null, {timeout:90000});
  await page.goto(url); await ready();
  const slot = '/userfs/godot/app_userdata/Starfire Hearth/saves/auto_2.json';
  const sentinel = [83, 65, 86, 69, 45, 71, 85, 65, 82, 68];
  await page.evaluate(({slot,sentinel}) => new Promise((resolve,reject) => {
    const open = indexedDB.open('/userfs'); open.onerror = () => reject(open.error);
    open.onsuccess = () => { const db=open.result; const tx=db.transaction('FILE_DATA','readwrite');
      tx.objectStore('FILE_DATA').put({timestamp:new Date(),mode:33188,contents:new Uint8Array(sentinel)},slot);
      tx.oncomplete=()=>{db.close();resolve();}; tx.onerror=()=>reject(tx.error); };
  }), {slot,sentinel});
  await page.goto(`${url}?smoke=begin`); await ready();
  // Give the deferred entry point time to run; a release must leave the slot byte-identical.
  await page.waitForTimeout(5000);
  const bytes = await page.evaluate(slot => new Promise((resolve,reject) => {
    const open=indexedDB.open('/userfs'); open.onerror=()=>reject(open.error);
    open.onsuccess=()=>{const db=open.result;const tx=db.transaction('FILE_DATA','readonly');const q=tx.objectStore('FILE_DATA').get(slot);
      q.onsuccess=()=>resolve(q.result ? Array.from(q.result.contents) : null); q.onerror=()=>reject(q.error);tx.oncomplete=()=>db.close();};
  }), slot);
  await mkdir(out,{recursive:true}); await page.screenshot({path:join(out,'web_release_probe_guard.png')});
  if (messages.length || JSON.stringify(bytes)!==JSON.stringify(sentinel)) throw new Error(`release smoke route ran or modified slot: ${messages} / ${bytes}`);
  console.log('PASS release query leaves existing auto_2 bytes untouched and does not run smoke');
} finally { await browser.close(); server.close(); }

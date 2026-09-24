// Web build smoke test: serves an exported web build, opens it in headless Chromium as a PC,
// an Android phone and an iPad, and checks that the engine starts without errors and picks the
// right layout class (the Layout autoload prints it to the browser console on web).
//
//   node tools/web_smoke.mjs --build build/web --out screens/web
//
// Needs the `playwright` npm package and its Chromium. It is looked up in PLAYWRIGHT_DIR (a
// node_modules folder), or else in the global npm folder.
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { execSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { extname, join, normalize } from 'node:path';

const args = Object.fromEntries(
  process.argv.slice(2).reduce((pairs, arg, i, all) => {
    if (arg.startsWith('--')) pairs.push([arg.slice(2), all[i + 1]]);
    return pairs;
  }, []),
);
const buildDir = args.build ?? 'build/web';
const outDir = args.out ?? 'screens/web';
const bootTimeoutMs = 90_000;

const modulesDir = process.env.PLAYWRIGHT_DIR ?? execSync('npm root -g').toString().trim();
const { chromium } = createRequire(join(modulesDir, 'noop.js'))('playwright');

const ANDROID_UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Mobile Safari/537.36';
// iPadOS Safari sends the macOS user agent, so only its touch pointer tells it apart.
const IPAD_UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15';
const DEVICES = [
  { id: 'pc', expect: 'wide, pointer', context: { viewport: { width: 1920, height: 1080 } } },
  {
    id: 'phone',
    expect: 'compact, touch',
    // The reference phone of section 7: 2400x1080 at 440 dpi is 873x393 CSS pixels at 2.75x.
    context: { userAgent: ANDROID_UA, viewport: { width: 873, height: 393 }, deviceScaleFactor: 2.75, isMobile: true, hasTouch: true },
  },
  {
    id: 'ipad',
    expect: 'compact, touch',
    context: { userAgent: IPAD_UA, viewport: { width: 1180, height: 820 }, deviceScaleFactor: 2, hasTouch: true },
  },
];

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = createServer(async (req, res) => {
  const path = normalize(decodeURIComponent(new URL(req.url, 'http://x').pathname)).replace(/^([/\\])+/, '');
  const file = path || 'index.html';
  try {
    const body = await readFile(join(buildDir, file));
    res.writeHead(200, { 'Content-Type': TYPES[extname(file)] ?? 'application/octet-stream' });
    res.end(body);
  } catch {
    res.writeHead(404);
    res.end();
  }
});
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const url = `http://127.0.0.1:${server.address().port}/index.html`;
await mkdir(outDir, { recursive: true });
// Keep Godot's editor from importing the screenshots as textures.
await writeFile(join(outDir, '.gdignore'), '');

// Software WebGL 2, as on a machine without a GPU.
const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
let failures = 0;
for (const device of DEVICES) {
  const context = await browser.newContext(device.context);
  const page = await context.newPage();
  const errors = [];
  let layout = null;
  page.on('console', (msg) => {
    const text = msg.text();
    const m = text.match(/^Starfire Hearth layout: ([^,]+, [^,]+),/);
    if (m) layout = m[1];
    if (msg.type() === 'error') errors.push(text);
  });
  page.on('pageerror', (err) => errors.push(err.message));
  const started = Date.now();
  await page.goto(url);
  // The boot overlay is removed once the engine runs the main scene.
  const booted = await page
    .waitForFunction(() => !document.getElementById('status'), null, { timeout: bootTimeoutMs, polling: 250 })
    .then(() => true, () => false);
  const bootSeconds = ((Date.now() - started) / 1000).toFixed(1);
  await page.waitForTimeout(3000);
  await page.screenshot({ path: join(outDir, `web_${device.id}.png`) });
  const problems = [];
  if (!booted) problems.push(`engine did not start within ${bootTimeoutMs / 1000} s`);
  if (layout !== device.expect) problems.push(`layout is "${layout}", expected "${device.expect}"`);
  for (const e of errors) problems.push(`console error: ${e.slice(0, 300)}`);
  console.log(`${problems.length ? 'FAIL' : 'PASS'}  ${device.id}: started in ${bootSeconds} s, layout "${layout}"`);
  for (const p of problems) console.log(`      ${p}`);
  failures += problems.length ? 1 : 0;
  await context.close();
}
await browser.close();
server.close();
console.log(`web_smoke: ${DEVICES.length - failures} of ${DEVICES.length} device(s) passed; screenshots in ${outDir}`);
process.exit(failures ? 1 : 0);

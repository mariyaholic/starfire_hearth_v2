// Web build smoke test: serves an exported web build, opens it in headless Chromium as a PC,
// an Android phone and an iPad, and checks that the engine starts without errors and picks the
// right layout class (the Layout autoload prints it to the browser console on web). Then it opens
// the game again with ?smoke=begin, which starts Scenario 1 and plays one turn (the AppRoot says
// so in the console, with the state hash and the number of saves), and checks that too.
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
// The state hash the new game must reach after one turn (tools/smoke_hash.gd on the desktop).
const expectHash = args['expect-hash'] ?? null;
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

// Give software WebGL a bounded capture window, including on loaded CI runners.
const captureTimeoutMs = 30_000;
const navigationTimeoutMs = 30_000;
const browserArgs = ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'];
let failures = 0;
for (const device of DEVICES) {
  // A fresh browser per profile releases the previous SwiftShader/WASM processes. The title
  // context is closed before the game starts, so at most one Godot instance is live at a time.
  let browser = null;
  let context = null;
  let stage = 'launch';
  let layout = null;
  let smokeLine = null;
  let booted = false;
  let bootSeconds = null;
  let cleanupFailed = false;
  const errors = [];
  const consoleTail = [];
  const timingsMs = {};
  const problems = [];
  const diagnostics = [];
  const recordFailure = (where, error) => {
    const detail = error && error.stack ? error.stack : String(error);
    problems.push(`${where}: ${detail}`);
    diagnostics.push({stage: where, error: detail});
  };
  const observe = (page, label, captureLayout = false) => {
    page.on('console', msg => {
      const text = msg.text();
      consoleTail.push({page: label, type: msg.type(), text: text.slice(0, 1000)});
      if (consoleTail.length > 40) consoleTail.shift();
      if (captureLayout) {
        const match = text.match(/^Starfire Hearth layout: ([^,]+, [^,]+),/);
        if (match) layout = match[1];
      }
      if (label === 'new game' && text.startsWith('Starfire Hearth smoke:')) smokeLine = text;
      if (msg.type() === 'error') errors.push(`${label}: ${text}`);
    });
    page.on('pageerror', error => errors.push(`${label}: ${error.message}`));
    page.on('crash', () => errors.push(`${label}: page crashed`));
  };
  try {
    browser = await chromium.launch({args: browserArgs});
    try {
      stage = 'title boot';
      context = await browser.newContext(device.context);
      const page = await context.newPage();
      observe(page, 'title', true);
      const started = Date.now();
      await page.goto(url, {timeout: navigationTimeoutMs});
      booted = await page.waitForFunction(() => !document.getElementById('status'), null,
        {timeout: bootTimeoutMs, polling: 250}).then(() => true, () => false);
      bootSeconds = ((Date.now() - started) / 1000).toFixed(1);
      if (booted) {
        await page.waitForTimeout(3000);
        stage = 'title screenshot';
        const captureStarted = Date.now();
        await page.screenshot({path: join(outDir, `web_${device.id}.png`), timeout: captureTimeoutMs});
        timingsMs.titleScreenshot = Date.now() - captureStarted;
      }
    } catch (error) {
      recordFailure(stage, error);
    } finally {
      if (context) { await context.close(); context = null; }
    }
    try {
      stage = 'game boot';
      context = await browser.newContext(device.context);
      const page = await context.newPage();
      observe(page, 'new game');
      const gameStarted = Date.now();
      await page.goto(`${url}?smoke=begin`, {timeout: navigationTimeoutMs});
      const deadline = Date.now() + bootTimeoutMs;
      while (!smokeLine && Date.now() < deadline) await page.waitForTimeout(250);
      timingsMs.gameToSmoke = Date.now() - gameStarted;
      await page.waitForTimeout(1000);
      stage = 'game screenshot';
      const captureStarted = Date.now();
      await page.screenshot({path: join(outDir, `web_${device.id}_game.png`), timeout: captureTimeoutMs});
      timingsMs.gameScreenshot = Date.now() - captureStarted;
    } catch (error) {
      recordFailure(stage, error);
    } finally {
      if (context) { await context.close(); context = null; }
    }
  } catch (error) {
    recordFailure(stage, error);
  } finally {
    if (browser) {
      try { await browser.close(); }
      catch (error) { cleanupFailed = true; recordFailure('browser close', error); }
    }
  }
  if (!smokeLine) problems.push('a new game did not start and play a turn (no smoke line in the console)');
  else if (!/turn 2, state [0-9a-f]{12}, [1-9]\d* save/.test(smokeLine)) problems.push(`unexpected smoke line: ${smokeLine}`);
  else if (expectHash && !smokeLine.includes(`state ${expectHash}`)) problems.push(`the web build reached state ${smokeLine.match(/state ([0-9a-f]+)/)[1]}, the desktop ${expectHash}`);
  if (!booted) problems.push(`engine did not start within ${bootTimeoutMs / 1000} s`);
  if (layout !== device.expect) problems.push(`layout is "${layout}", expected "${device.expect}"`);
  for (const error of errors) problems.push(`console error: ${error.slice(0, 300)}`);
  const result = {device: device.id, profile: device.context, booted, bootSeconds, layout,
    expectedLayout: device.expect, smokeLine, expectedHash: expectHash, timingsMs, errors, consoleTail,
    diagnostics, problems};
  await writeFile(join(outDir, `web_${device.id}_result.json`), JSON.stringify(result, null, 2) + '\n');
  console.log(`${problems.length ? 'FAIL' : 'PASS'}  ${device.id}: started in ${bootSeconds ?? 'unknown'} s, layout "${layout}"; ${smokeLine ?? 'no new game'}`);
  for (const problem of problems) console.log(`      ${problem}`);
  failures += problems.length ? 1 : 0;
  if (cleanupFailed) {
    const remaining = DEVICES.length - DEVICES.indexOf(device) - 1;
    failures += remaining;
    console.log(`FAIL  ${remaining} remaining profile(s) not run because browser cleanup failed`);
    break;
  }
}
server.close();
console.log(`web_smoke: ${DEVICES.length - failures} of ${DEVICES.length} device(s) passed; screenshots and results in ${outDir}`);
process.exit(failures ? 1 : 0);

"""Focused M1.2 D–G revalidation on the actual non-threaded web export."""
from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import argparse, json, threading, time
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser()
parser.add_argument('--build', default='build/m12_review/web')
parser.add_argument('--out', default='screens/m12_owner_revalidation_web')
args = parser.parse_args()
out = Path(args.out).resolve(); out.mkdir(parents=True, exist_ok=True)
(out / '.gdignore').touch()
class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_): pass
server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(Path(args.build).resolve())))
threading.Thread(target=server.serve_forever, daemon=True).start()
results = []
try:
    with sync_playwright() as p:
        for name, config in [('desktop', {'viewport': {'width': 1920, 'height': 1080}}),
                             ('phone', {'viewport': {'width': 390, 'height': 844}, 'device_scale_factor': 2.75, 'is_mobile': True, 'has_touch': True})]:
            started = time.monotonic()
            browser = p.chromium.launch(executable_path='/usr/bin/chromium', args=['--no-sandbox', '--disable-dev-shm-usage', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'])
            context = browser.new_context(**config); page = context.new_page()
            errors, checks, captures = [], [], []
            def watch():
                page.on('pageerror', lambda error: errors.append(str(error)))
                page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
            watch()
            def data(): return page.evaluate('window.__m11StageF')
            def wait(expression): page.wait_for_function(expression, timeout=240000)
            def check(value, label):
                checks.append({'label': label, 'pass': bool(value)})
                if not value: raise AssertionError(label)
            def action(value):
                serial = data()['serial']
                page.evaluate('(value) => { window.__m11StageFAction = value; }', value)
                wait(f'window.__m11StageF.serial > {serial}')
            def click(key):
                action('reveal:' + key)
                wait(f'window.__m11StageF.controls[{json.dumps(key)}]?.reachable === true')
                state = data(); button = state['controls'].get(key)
                check(button and button['enabled'] and button['reachable'], 'reachable actual control ' + key)
                box = page.locator('#canvas').bounding_box()
                x = box['x'] + button['x'] / state['viewport']['x'] * box['width']
                y = box['y'] + button['y'] / state['viewport']['y'] * box['height']
                if name == 'phone': page.touchscreen.tap(x, y)
                else: page.mouse.click(x, y)
            def capture(label):
                page.screenshot(path=str(out / f'{name}_{label}.png'), timeout=120000)
                captures.append(f'{name}_{label}.png'); print(f'{name}: {label}', flush=True)
            try:
                page.goto(f'http://127.0.0.1:{server.server_port}/index.html?smoke=m11-immersive', wait_until='load')
                wait("window.__m11StageF?.phase === 'ready'")
                wait('window.__m11StageF.renderer.busy === false')
                action('mode_immersive'); wait('window.__m11StageF.immersive_active === true')
                wait("window.__m11StageF.workspace.windows.some(w => w.kind === 'summary')")
                state = data(); windows = state['workspace']['windows']
                check([w['kind'] for w in windows] == ['summary'], 'default has summary only')
                share = sum(w['width'] * w['height'] for w in windows) / (state['logical_size']['x'] * state['logical_size']['y'])
                check(share < .22, 'default card leaves the scene exposed')
                check(state['controls']['EndTurn']['reachable'], 'persistent turn control')
                capture('01_compact_default')
                click('ImmersiveManage'); wait("window.__m11StageF.workspace.active === 'manage'")
                click('ManageTab_jobs'); wait("window.__m11StageF.workspace.manage_tab === 'jobs'")
                orders = data()['orders']; click('Raise_energy')
                wait(f'window.__m11StageF.orders === {orders + 1}')
                check(True, 'Jobs sends real order from the window')
                capture('02_jobs_window')
                action('context_close'); action('tools')
                before = data()
                for finish in ['matte', 'glossy', 'frosted']:
                    action('finish_' + finish)
                    wait(f'window.__m11StageF.interface_finish === {json.dumps(finish)}')
                    current = data()
                    for field in ['state_hash', 'graphics_hash', 'orders']:
                        check(current[field] == before[field], finish + ' retains ' + field)
                    check(current['renderer']['instance'] == before['renderer']['instance'], finish + ' retains renderer')
                capture('03_appearance')
                action('context_close'); action('text_200')
                check(data()['controls']['EndTurn']['reachable'], 'End turn reachable at 200% text')
                capture('04_large_text')
                action('text_100'); action('resolve')
                check(data()['state_hash'] == data()['expected_hash'], 'one turn matches pure simulation')
                action('system'); wait('window.__m11StageF.orbit_positions')
                wait('window.__m11StageF.orbit_frame?.ready === true && window.__m11StageF.orbit_frame.scene_width > 100')
                frame = data()['orbit_frame']
                axis = 'width' if name == 'phone' else 'height'
                check(frame[axis] > frame['scene_' + axis] * .5, 'overview fills the mounted aspect')
                check(frame['x'] >= 0 and frame['y'] >= 0 and frame['x']+frame['width'] <= frame['scene_width'] and frame['y']+frame['height'] <= frame['scene_height'], 'outer orbit guide stays in view')
                check(len(data()['orbit_positions']) >= 4, 'known system has rendered orbital bodies')
                saved_positions = data()['orbit_positions']; saved_hash = data()['state_hash']
                capture('05_system_spacing')
                action('save'); check(data()['error'] == '0', 'save succeeds')
                action('persist_mode'); page.wait_for_timeout(3500)
                page.close(); page = context.new_page(); watch()
                page.goto(f'http://127.0.0.1:{server.server_port}/index.html?smoke=m11-immersive', wait_until='load')
                wait("window.__m11StageF?.phase === 'ready'")
                check(data()['view_mode'] == 'immersive', 'device mode survives page recreation')
                check(data()['state_hash'] == saved_hash, 'campaign survives IndexedDB reload')
                action('system'); wait('window.__m11StageF.orbit_positions')
                check(data()['orbit_positions'] == saved_positions, 'same saved turn reconstructs the same orbital positions')
                capture('06_system_after_reload')
                check(not errors, 'no browser/script/shader errors')
                result = {'name': name, 'checks': checks, 'errors': errors, 'captures': captures, 'elapsed_seconds': round(time.monotonic()-started, 1), 'qualification': 'Actual Web export, Chromium SwiftShader, mouse or touch emulation. One resolved turn and destroyed-page IndexedDB reload; physical devices not tested.'}
                results.append(result)
            except Exception as error:
                (out / f'{name}_failure.json').write_text(json.dumps({'error': str(error), 'checks': checks, 'errors': errors, 'evidence': data()}, indent=2)+'\n')
                raise
            finally:
                (out / 'verification.json').write_text(json.dumps(results, indent=2)+'\n')
                context.close(); browser.close()
finally:
    server.shutdown()
print(json.dumps({'checks': sum(len(r['checks']) for r in results), 'failures': sum(not c['pass'] for r in results for c in r['checks']), 'captures': sum(len(r['captures']) for r in results)}))

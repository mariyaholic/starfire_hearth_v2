"""Validate integrated Stage C in real non-threaded desktop/touch web exports."""
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial
import argparse, json, threading
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser()
parser.add_argument('--build', default='build/web')
parser.add_argument('--out', default='screens/m11_stage_c_web')
args = parser.parse_args()
build, out = Path(args.build).resolve(), Path(args.out).resolve()
out.mkdir(parents=True, exist_ok=True)
(out/'.gdignore').touch()
class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *args): pass
server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(build)))
threading.Thread(target=server.serve_forever, daemon=True).start()
url = f'http://127.0.0.1:{server.server_port}/index.html?smoke=m11-stage-c'

def percentile(values, p):
    return sorted(values)[min(len(values)-1, int(len(values)*p))] if values else None

results = []
try:
    with sync_playwright() as p:
        for name, config in [
            ('desktop', {'viewport': {'width': 1920, 'height': 1080}}),
            ('phone', {'viewport': {'width': 873, 'height': 393}, 'device_scale_factor': 2.75, 'is_mobile': True, 'has_touch': True}),
        ]:
            browser = p.chromium.launch(executable_path='/usr/bin/chromium', args=[
                '--no-sandbox', '--disable-dev-shm-usage', '--use-angle=swiftshader',
                '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'])
            context = browser.new_context(**config)
            page = context.new_page(); errors = []; checks = []
            page.on('pageerror', lambda error: errors.append(str(error)))
            page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
            page.goto(url, wait_until='load')
            page.wait_for_function("window.__m11StageC?.phase === 'ready'", timeout=180000)
            def data(): return page.evaluate('window.__m11StageC')
            def wait_for(expression, timeout=30000):
                try:
                    page.wait_for_function(expression, timeout=timeout)
                except Exception:
                    (out/f'{name}_failure.json').write_text(json.dumps({'state':data(),'errors':errors,'expression':expression},indent=2)+'\n')
                    page.screenshot(path=str(out/f'{name}_failure.png'))
                    raise
            def check(value, label):
                checks.append({'label': label, 'pass': bool(value)})
                if not value:
                    (out/f'{name}_failure.json').write_text(json.dumps({'state':data(),'errors':errors,'check':label},indent=2)+'\n')
                    page.screenshot(path=str(out/f'{name}_failure.png'))
                assert value, label
            def click(control):
                for attempt in range(40):
                    state = data(); button = state['controls'].get(control)
                    # Navigation lives outside the inspector ScrollContainer (the
                    # phone tab bar is below it), so it must not be scrolled into it.
                    if button and (control.startswith('Nav_') or state['clip']['top']+5 < button['y'] < state['clip']['bottom']-5): break
                    box = page.locator('#canvas').bounding_box(); bar = state['scrollbar']
                    page.mouse.move(box['x']+bar['x']/state['viewport']['x']*box['width'], box['y']+bar['y']/state['viewport']['y']*box['height'])
                    page.mouse.wheel(0, 400 if button and button['y'] > state['clip']['bottom'] else -400)
                    page.wait_for_timeout(350)
                else:
                    (out/f'{name}_failure.json').write_text(json.dumps({'state':data(),'errors':errors,'control':control},indent=2)+'\n')
                    page.screenshot(path=str(out/f'{name}_failure.png'))
                    raise AssertionError('Control cannot be reached: '+control)
                check(button['enabled'], 'control enabled: '+control)
                box = page.locator('#canvas').bounding_box()
                x = box['x']+button['x']/state['viewport']['x']*box['width']
                y = box['y']+button['y']/state['viewport']['y']*box['height']
                if name == 'phone': page.touchscreen.tap(x,y)
                else: page.mouse.click(x,y)
            initial = data()
            check(initial['web'], 'actual web build')
            check(initial['view'] == 'galaxy', 'integrated Galaxy entry')
            check(initial['scheduler']['backend'] == 'cooperative', 'non-threaded cooperative generation')
            check(page.evaluate('!crossOriginIsolated'), 'no cross-origin thread isolation required')
            page.screenshot(path=str(out/f'{name}_01_galaxy.png'))
            click('System_sys_ember')
            page.wait_for_function("window.__m11StageC.view === 'system'", timeout=30000)
            page.screenshot(path=str(out/f'{name}_02_system.png'))
            click('Focus_pl_brume')
            page.wait_for_function("window.__m11StageC.planet === 'pl_brume'", timeout=30000)
            check(data()['preview_hash'] == initial['initial_hash'], 'planet selection preserves simulation')
            wait_for("window.__m11StageC.renderer.focused_width >= 512", timeout=180000)
            focused = data()
            check(focused['scene_visible'], 'accessible planet selection reveals its viewport')
            check(len(focused['scheduler']['generation_us']) > 1, 'generation yielded across frames')
            page.screenshot(path=str(out/f'{name}_03_focused_brume.png'))
            if name == 'phone':
                box = page.locator('#canvas').bounding_box(); world = focused['renderer']
                cx = box['x']+(world['x']+world['width']/2)/focused['viewport']['x']*box['width']
                cy = box['y']+(max(world['y'],focused['clip']['top'])+min(world['y']+world['height'],focused['clip']['bottom']))/2/focused['viewport']['y']*box['height']
                cdp = context.new_cdp_session(page)
                def touches(spread):
                    return [{'x':cx-spread,'y':cy,'id':0},{'x':cx+spread,'y':cy,'id':1}]
                cdp.send('Input.dispatchTouchEvent', {'type':'touchStart','touchPoints':touches(25)})
                page.wait_for_timeout(100)
                cdp.send('Input.dispatchTouchEvent', {'type':'touchMove','touchPoints':touches(50)})
                page.wait_for_timeout(100)
                cdp.send('Input.dispatchTouchEvent', {'type':'touchEnd','touchPoints':[]})
                page.wait_for_timeout(500)
                check(data()['renderer']['camera_distance'] < focused['renderer']['camera_distance'], 'real browser two-finger pinch zooms')
                check(data()['planet'] == 'pl_brume' and data()['preview_hash'] == initial['initial_hash'], 'pinch preserves selection and simulation')
            survey = next(key for key in focused['controls'] if key.startswith('Survey_'))
            instance = focused['renderer']['instance']
            click(survey)
            page.wait_for_function("window.__m11StageC.preview_hash !== window.__m11StageC.initial_hash", timeout=30000)
            check(data()['renderer']['instance'] == instance, 'order refresh preserves renderer instance')
            page.evaluate("window.__m11StageCAction = 'resolve_survey'")
            page.wait_for_function("window.__m11StageC.phase === 'resolved' && window.__m11StageC.surveyed", timeout=30000)
            final = data()
            check(final['actual_hash'] == final['expected_hash'], 'Survey result matches pure simulation replay')
            check(final['turn'] == 3, 'two-turn Survey completion')
            page.screenshot(path=str(out/f'{name}_04_surveyed.png'))
            click('AppearanceStrategic')
            page.wait_for_function("window.__m11StageC.appearance === 'strategic'", timeout=30000)
            check(data()['renderer'] == {}, 'Strategic releases inactive scene')
            check(data()['preview_hash'] == final['preview_hash'], 'appearance switching preserves game state')
            page.screenshot(path=str(out/f'{name}_05_strategic.png'))
            click('Appearance3D')
            page.wait_for_function("window.__m11StageC.appearance === '3d' && window.__m11StageC.renderer.instance", timeout=30000)
            check(data()['planet'] == 'pl_brume', 'return restores planet focus')
            page.evaluate("window.__m11StageCAction = 'prepare_command_fixture'")
            wait_for("window.__m11StageC.phase === 'fixture_ready'")
            click('Focus_pl_brume')
            wait_for("window.__m11StageC.phase === 'fixture_ready' && Object.keys(window.__m11StageC.controls).some(k => k.startsWith('Colonise_'))")
            colonise = next(key for key in data()['controls'] if key.startswith('Colonise_'))
            check(data()['renderer']['instance'] != instance, 'fixture resume replaces old session renderer')
            click(colonise)
            page.evaluate("window.__m11StageCAction = 'resolve_colonise'")
            wait_for("window.__m11StageC.phase === 'resolve_colonise_done' && window.__m11StageC.brume_colony && window.__m11StageC.renderer.body_ids?.includes(window.__m11StageC.brume_colony)")
            settled = data()
            check(settled['actual_hash'] == settled['expected_hash'], 'Colonise matches pure simulation replay')
            check(settled['brume_colony'] in settled['renderer']['body_ids'], 'completed colony gains selectable marker')
            click('Focus_'+settled['brume_colony'])
            wait_for("window.__m11StageC.view === 'colony'")
            check(data()['renderer'] == {}, 'colony marker opens existing planner and releases space scene')
            page.screenshot(path=str(out/f'{name}_06_colony_planner.png'))
            click('Nav_system')
            wait_for("window.__m11StageC.view === 'system'")
            click('Focus_pl_tithe')
            wait_for("window.__m11StageC.planet === 'pl_tithe'")
            click(survey)
            page.evaluate("window.__m11StageCAction = 'resolve_tithe_survey'")
            wait_for("window.__m11StageC.phase === 'resolve_tithe_survey_done'")
            check(data()['actual_hash'] == data()['expected_hash'], 'second Survey matches pure simulation replay')
            click('Outpost_minerals')
            page.evaluate("window.__m11StageCAction = 'resolve_outpost'")
            wait_for("window.__m11StageC.phase === 'resolve_outpost_done' && window.__m11StageC.tithe_outpost && window.__m11StageC.renderer.body_ids?.includes(window.__m11StageC.tithe_outpost)")
            completed = data()
            check(completed['actual_hash'] == completed['expected_hash'], 'Outpost matches pure simulation replay')
            check(completed['tithe_outpost'] in completed['renderer']['body_ids'], 'completed outpost appears in scene')
            click('Focus_'+completed['tithe_outpost'])
            wait_for("window.__m11StageC.scene_visible")
            page.screenshot(path=str(out/f'{name}_07_owned_outpost.png'))
            check(not errors, 'no browser/engine errors')
            report = {'profile': name, 'checks': checks, 'errors': errors, 'initial': initial, 'focused': focused, 'final': final,'commands_final':completed,
                      'generation_slice_p95_us': percentile(focused['scheduler']['generation_us'], .95),
                      'upload_p95_us': percentile(focused['renderer']['upload_us'], .95),
                      'software_frame_p95_ms': percentile(focused['frames_ms'], .95),
                      'command_fixture': 'After canonical Survey: one extra owned Colony Ship and influence=50000 for Colonise/Outpost UI coverage',
                      'qualification': 'Chromium software WebGL; phone profile tests actual touch taps, a two-finger pinch and layout, not physical-device performance'}
            (out/f'{name}_verification.json').write_text(json.dumps(report, indent=2)+'\n')
            results.append({'profile': name, 'checks': len(checks), 'errors': errors, 'simulation_hash':completed['actual_hash'],'canonical_survey_hash':final['actual_hash']})
            context.close(); browser.close()
    assert results[0]['simulation_hash'] == results[1]['simulation_hash']
    (out/'verification.json').write_text(json.dumps({'results': results, 'same_simulation_hash': True}, indent=2)+'\n')
    print(json.dumps(results, indent=2))
finally:
    server.shutdown(); server.server_close()

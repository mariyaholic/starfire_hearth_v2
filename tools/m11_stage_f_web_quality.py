"""Check the new full-resolution Standard path in the actual touch-sized Web export."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import threading
import time
from playwright.sync_api import sync_playwright

out=Path('screens/m11_stage_f_web_quality');out.mkdir(parents=True,exist_ok=True);(out/'.gdignore').touch()
class Handler(SimpleHTTPRequestHandler):
    def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(Path('build/web').resolve())))
threading.Thread(target=server.serve_forever,daemon=True).start()
checks=[];errors=[]
def check(value,label):
    checks.append({'label':label,'pass':bool(value)});assert value,label
try:
    with sync_playwright() as p:
        browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'])
        page=browser.new_page(viewport={'width':873,'height':393},device_scale_factor=2.75,is_mobile=True,has_touch=True)
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
        page.goto(f'http://127.0.0.1:{server.server_port}/index.html?smoke=m11-stage-f',wait_until='load')
        page.wait_for_function("window.__m11StageF?.phase === 'ready'",timeout=180000)
        def data():return page.evaluate('window.__m11StageF')
        def ready():
            start=time.monotonic()
            while time.monotonic()-start<600:
                page.evaluate("window.__m11StageFAction='reveal:PlannerGrid'")
                page.wait_for_timeout(600)
                state=data()
                if state.get('renderer',{}).get('busy') is False:return state
            raise AssertionError('Standard regional refinement did not complete')
        initial=ready();print('Low ready',flush=True)
        check(initial['renderer']['render_divisor']==2,'actual Low Web path')
        page.evaluate("window.__m11StageFAction='quality_standard'")
        page.wait_for_function("window.__m11StageF.quality === 'standard' && window.__m11StageF.renderer.render_divisor === 1",timeout=180000)
        print('Standard active; waiting for region',flush=True)
        current=ready()
        check(current['renderer']['render_divisor']==1,'Standard uses full resolution')
        for field in ['state_hash','anchor','prepared','graphics_hash']:
            check(current[field]==initial[field],'quality retains '+field)
        capture='phone_standard_finish.png';page.screenshot(path=str(out/capture),timeout=120000)
        check(not errors,'Standard shaders/rendering have no browser errors')
        result={'checks':checks,'errors':errors,'initial':initial,'standard':current,'captures':[capture],
                'qualification':'Actual non-threaded touch-sized Chromium Web export, Standard full-resolution city path. Software SwiftShader; no physical-device or steady-state FPS certification.'}
        (out/'verification.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'checks':len(checks),'errors':errors,'captures':1}))
        browser.close()
finally:server.shutdown()

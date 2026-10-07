"""Real non-threaded web export: IndexedDB reload, graphics compatibility, region."""
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial
import argparse, json, threading
from playwright.sync_api import sync_playwright

parser=argparse.ArgumentParser()
parser.add_argument('--build',default='build/web')
parser.add_argument('--out',default='screens/m11_stage_d_web')
args=parser.parse_args()
build,out=Path(args.build).resolve(),Path(args.out).resolve()
out.mkdir(parents=True,exist_ok=True);(out/'.gdignore').touch()
class Handler(SimpleHTTPRequestHandler):
    def log_message(self,*args): pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(build)))
threading.Thread(target=server.serve_forever,daemon=True).start()
url=f'http://127.0.0.1:{server.server_port}/index.html?smoke=m11-stage-d'
results=[]
try:
    with sync_playwright() as p:
        for name,config in [('desktop',{'viewport':{'width':1920,'height':1080}}),('phone',{'viewport':{'width':873,'height':393},'device_scale_factor':2.75,'is_mobile':True,'has_touch':True})]:
            browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'])
            context=browser.new_context(**config)
            page=context.new_page();errors=[];checks=[];captures=[]
            def watch(target):
                target.on('pageerror',lambda e:errors.append(str(e)))
                target.on('console',lambda m:(errors.append(m.text), print(m.text, flush=True)) if m.type=='error' else None)
            watch(page)
            def data():return page.evaluate('window.__m11StageD')
            def wait(expr,timeout=180000):
                try:page.wait_for_function(expr,timeout=timeout)
                except Exception:
                    (out/f'{name}_failure.json').write_text(json.dumps({'state':data(),'errors':errors,'expression':expr},indent=2)+'\n')
                    page.screenshot(path=str(out/f'{name}_failure.png'))
                    raise
            def check(value,label):
                checks.append({'label':label,'pass':bool(value)})
                if not value: raise AssertionError(label)
            def action(action_name,phase):
                page.evaluate('(v)=>{window.__m11StageDAction=v}',action_name)
                wait(f"window.__m11StageD.phase === '{phase}'")
            def capture(label):
                path=out/f'{name}_{label}.png';page.screenshot(path=str(path),timeout=120000);captures.append(path.name)
            page.goto(url,wait_until='load');print(name+' page loaded',flush=True);wait("window.__m11StageD?.phase === 'ready'")
            wait('window.__m11StageD.rendered_width >= 512')
            initial=data()
            check(initial['web'],'actual web export')
            check(initial['persistent_filesystem'],'IndexedDB filesystem is persistent')
            check(initial['scheduler']['backend']=='cooperative','non-threaded shared scheduler')
            capture('01_globe_before_save')
            action('save','saved');check(data()['error']=='0','save write and replacement succeeded')
            action('region','region_ready')
            check(data()['anchor']==initial['anchor'],'region uses saved geographic anchor')
            check(data()['samples']==initial['samples'],'region/globe samples match before reload');print(name+' region generated',flush=True)
            capture('02_anchored_region')
            action('close_region','closed_region')
            # Godot Web asynchronously commits user:// to IndexedDB. Let its sync
            # transaction finish, then destroy the actual page/WASM process.
            page.wait_for_timeout(3500)
            page.close();page=context.new_page();watch(page)
            page.goto(url,wait_until='load');print(name+' page loaded',flush=True);wait("window.__m11StageD?.phase === 'ready'")
            wait('window.__m11StageD.rendered_width >= 512')
            restored=data()
            check(restored['appearance_fingerprint']==initial['appearance_fingerprint'],'destroyed page reload keeps complete graphics metadata')
            check(restored['state_hash']==initial['state_hash'],'IndexedDB reload keeps gameplay checksum')
            check(restored['samples']==initial['samples'],'same geography/material samples after page replacement')
            capture('03_globe_after_browser_reload')
            action('region','region_ready');check(data()['samples']==initial['samples'],'same anchored terrain after browser reload')
            capture('04_region_after_browser_reload');action('close_region','closed_region')
            action('next_turn','turn_saved')
            check(data()['state_hash']==data()['expected_hash'],'turn replay parity with pure M1 simulation')
            check(data()['anchor']==initial['anchor'],'turn progress preserves region')
            action('future_compatible','future_compatible')
            wait('window.__m11StageD.rendered_width >= 512')
            compatible=data()
            check(not compatible['fallback'],'future save with v1 view renders supported appearance')
            check(compatible['future_original_sha256']==compatible['future_saved_sha256'],'future opaque envelope preserved exactly')
            capture('05_future_compatible_view')
            action('future_unsupported','future_unsupported')
            wait("window.__m11StageD.appearance_setting === 'strategic'")
            check(data()['fallback'],'unsupported future graphics use explicit fallback')
            check(data()['future_original_sha256']==data()['future_saved_sha256'],'fallback resave retains original future graphics')
            capture('06_future_strategic_fallback')
            action('restore_future','future_restored');check(data()['fallback'],'fallback survives its own save/reload')
            action('restore_manual','restored');check(data()['appearance_fingerprint']==initial['appearance_fingerprint'],'original manual graphics restored after future compatibility review')
            check(not errors,'no browser/script errors')
            result={'name':name,'checks':checks,'errors':errors,'initial':initial,'restored':restored,'compatible':compatible,'final':data(),'captures':captures,'qualification':'Chromium desktop/touch emulation using software GL; browser storage tested by destroyed page/WASM reload in same context. Not a physical-device or power-loss test.'}
            results.append(result)
            context.close();browser.close()
finally:
    server.shutdown()
(out/'verification.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps({'checks':sum(len(r['checks']) for r in results),'failures':sum(not c['pass'] for r in results for c in r['checks']),'captures':sum(len(r['captures']) for r in results)}))

"""Exercise real exported canvas controls; Chromium emulation is not hardware profiling."""
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial
import argparse, json, threading, statistics
from playwright.sync_api import sync_playwright

parser=argparse.ArgumentParser()
parser.add_argument('--build',default='build/web')
parser.add_argument('--out',default='screens/m11_stage_a_web')
args=parser.parse_args()
build=Path(args.build).resolve();out=Path(args.out).resolve();out.mkdir(parents=True,exist_ok=True)
(out/'.gdignore').touch()
class Handler(SimpleHTTPRequestHandler):
    def log_message(self,*args): pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(build)))
threading.Thread(target=server.serve_forever,daemon=True).start()
url=f'http://127.0.0.1:{server.server_port}/index.html?smoke=m11-stage-a'
results=[]
def percentile(values,p):
    return sorted(values)[min(len(values)-1,int(len(values)*p))] if values else None
def process_memory(cdp):
    try:
        records=[]
        for process in cdp.send('SystemInfo.getProcessInfo')['processInfo']:
            path=Path('/proc')/str(process['id'])/'status'
            if not path.exists():continue
            rss=next((int(line.split()[1])*1024 for line in path.read_text().splitlines() if line.startswith('VmRSS:')),0)
            records.append({'type':process['type'],'rss_bytes':rss})
        return records
    except Exception:return []

try:
    with sync_playwright() as p:
        for name,config in [('desktop',{'viewport':{'width':1920,'height':1080}}),('phone',{'viewport':{'width':873,'height':393},'device_scale_factor':2.75,'is_mobile':True,'has_touch':True})]:
            browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'])
            context=browser.new_context(**config)
            page=context.new_page();errors=[]
            page.on('pageerror',lambda error:errors.append(str(error)))
            page.on('console',lambda message:errors.append(message.text) if message.type=='error' else None)
            page.goto(url,wait_until='load')
            page.wait_for_function("window.__m11StageA?.phase === 'ready'",timeout=180000)
            data=lambda:page.evaluate('window.__m11StageA')
            initial=data();checks=[]
            def check(value,label):
                checks.append({'label':label,'pass':bool(value)})
                assert value,label
            def click(control):
                for attempt in range(32):
                    state=data();button=state['controls'].get(control)
                    if button and state['clip']['top']+5<button['y']<state['clip']['bottom']-5:break
                    box=page.locator('#canvas').bounding_box()
                    bar=state['scrollbar']
                    page.mouse.move(box['x']+bar['x']/state['viewport']['x']*box['width'],box['y']+bar['y']/state['viewport']['y']*box['height'])
                    page.mouse.wheel(0,400 if button and button['y']>state['clip']['bottom'] else -400)
                    page.wait_for_timeout(350)
                else:raise AssertionError('Control did not become visible: '+control)
                check(button['enabled'],'command/control enabled: '+control)
                box=page.locator('#canvas').bounding_box()
                page.mouse.click(box['x']+button['x']/state['viewport']['x']*box['width'],box['y']+button['y']/state['viewport']['y']*box['height'])
            check(initial['web'],'running actual web export')
            check(initial['worker_jobs']==0,'no generation worker tasks')
            check(page.evaluate('!crossOriginIsolated'),'works without cross-origin thread isolation')
            page.screenshot(path=str(out/f'{name}_01_integrated.png'))
            click('Focus_pl_brume')
            page.wait_for_function("window.__m11StageA?.planet === 'pl_brume'",timeout=30000)
            check(data()['preview_hash']==initial['initial_hash'],'selection preserves game state')
            page.wait_for_function("window.__m11StageA?.metrics.focused_width >= 512",timeout=180000)
            focused=data()
            check(focused['worker_jobs']==0,'focus refinement uses cooperative backend')
            check(len(focused['metrics']['generation_us'])>1,'focus generation yielded across frames')
            page.screenshot(path=str(out/f'{name}_02_focused.png'))
            survey=next(key for key in focused['controls'] if key.startswith('Survey_'))
            click(survey)
            page.wait_for_function("window.__m11StageA.preview_hash !== window.__m11StageA.initial_hash",timeout=30000)
            check(data()['preview_hash']!=initial['initial_hash'],'existing canvas Survey action changes real command preview')
            page.evaluate("window.__m11StageAAction = 'resolve_survey'")
            page.wait_for_function("window.__m11StageA?.phase === 'resolved'",timeout=30000)
            page.wait_for_function("window.__m11StageA?.surveyed === true",timeout=30000)
            final=data()
            check(final['actual_hash']==final['expected_hash'],'two real turns match pure simulation replay')
            check(final['turn']==3,'survey completes after two turns')
            page.wait_for_timeout(1500)
            page.screenshot(path=str(out/f'{name}_03_surveyed.png'))
            memory=process_memory(browser.new_browser_cdp_session())
            check(not errors,'no browser/engine console errors')
            report={'profile':name,'checks':checks,'errors':errors,'initial':initial,'focused':focused,'final':final,'process_rss':memory,
                'generation_slice_p95_us':percentile(focused['metrics']['generation_us'],.95),'generation_slice_max_us':max(focused['metrics']['generation_us'],default=0),
                'upload_p95_us':percentile(focused['metrics']['upload_us'],.95),'software_frame_p95_ms':percentile(focused['frames_ms'],.95),
                'qualification':'Chromium software WebGL emulation; not physical phone/GPU certification'}
            (out/f'{name}_verification.json').write_text(json.dumps(report,indent=2)+'\n')
            results.append({'profile':name,'checks':len(checks),'errors':errors,'generation_slice_p95_us':report['generation_slice_p95_us'],'simulation_hash':final['actual_hash']})
            context.close();browser.close()
        assert results[0]['simulation_hash']==results[1]['simulation_hash']
        (out/'verification.json').write_text(json.dumps({'results':results,'same_simulation_hash':True},indent=2)+'\n')
        print(json.dumps(results,indent=2))
finally:server.shutdown();server.server_close()

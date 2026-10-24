"""Stage F real canvas controls, touch/keyboard, planner parity and IndexedDB reload."""
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial
import argparse, json, threading
from playwright.sync_api import sync_playwright
parser=argparse.ArgumentParser();parser.add_argument('--build',default='build/web');parser.add_argument('--out',default='screens/m11_stage_f_web');parser.add_argument('--profile',choices=['all','desktop','phone'],default='all');args=parser.parse_args()
build,out=Path(args.build).resolve(),Path(args.out).resolve();out.mkdir(parents=True,exist_ok=True);(out/'.gdignore').touch()
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(build)));threading.Thread(target=server.serve_forever,daemon=True).start()
url=f'http://127.0.0.1:{server.server_port}/index.html?smoke=m11-stage-f';results=[]
verification_path=out/'verification.json'
if args.profile!='all' and verification_path.exists():results=[r for r in json.loads(verification_path.read_text()) if r['name']!=args.profile]
try:
 with sync_playwright() as p:
  for name,config in [('desktop',{'viewport':{'width':1920,'height':1080}}),('phone',{'viewport':{'width':873,'height':393},'device_scale_factor':2.75,'is_mobile':True,'has_touch':True})]:
   if args.profile!='all' and args.profile!=name:continue
   browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']);context=browser.new_context(**config);page=context.new_page();checks=[];errors=[];captures=[]
   def watch(target):
    target.on('pageerror',lambda e:errors.append(str(e)))
    target.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
   watch(page)
   def data():return page.evaluate('window.__m11StageF')
   def diagnostic(label):
    (out/f'{name}_failure.json').write_text(json.dumps({'label':label,'data':data(),'errors':errors},indent=2)+'\n');page.screenshot(path=str(out/f'{name}_failure.png'),timeout=120000)
   def check(value,label):
    checks.append({'label':label,'pass':bool(value)})
    if not value:diagnostic(label);raise AssertionError(label)
   def wait(expression,timeout=180000):
    try:page.wait_for_function(expression,timeout=timeout)
    except Exception:diagnostic(expression);raise
   def action(value):
    before=data()['serial'];page.evaluate('(v)=>{window.__m11StageFAction=v}',value);wait(f'window.__m11StageF.serial > {before}')
   def ready():
    action('reveal:PlannerGrid');wait('window.__m11StageF.renderer.busy === false');page.wait_for_timeout(300)
   def capture(label):
    action('reveal:PlannerGrid');page.wait_for_timeout(400);path=out/f'{name}_{label}.png';page.screenshot(path=str(path),timeout=120000);captures.append(path.name);print(name+' captured '+label,flush=True)
   def xy(point):
    box=page.locator('#canvas').bounding_box();state=data();return box['x']+point['x']/state['viewport']['x']*box['width'],box['y']+point['y']/state['viewport']['y']*box['height']
   def click(key):
    action('reveal:'+key)
    # ensure_control_visible/layout finishes after the action acknowledgement.
    # Software GL can render fewer than one frame during a fixed 400 ms sleep.
    if key not in ['Undo','EndTurn'] and not key.startswith('Nav_'):
     quoted=json.dumps(key)
     wait(f'window.__m11StageF.controls[{quoted}] && window.__m11StageF.controls[{quoted}].y > window.__m11StageF.clip.top && window.__m11StageF.controls[{quoted}].y < window.__m11StageF.clip.bottom')
    state=data();button=state['controls'].get(key);check(button is not None,'existing control '+key);check(button['enabled'],'enabled control '+key)
    check(key in ['Undo','EndTurn'] or key.startswith('Nav_') or state['clip']['top']<button['y']<state['clip']['bottom'],'reachable control '+key)
    x,y=xy(button)
    if name=='phone':page.touchscreen.tap(x,y)
    else:page.mouse.click(x,y)
    page.wait_for_timeout(500)
   def resolve():
    action('resolve');check(data()['state_hash']==data()['expected_hash'],'turn matches pure M1 simulation replay')
   def free_slots(state):return [i for i in range(state['slot_count']) if str(i) not in state['tiers'] and i not in state['blocked'] and i not in [b['slot'] for b in state['buildings']] and i not in [q['slot'] for q in state['queue']]]
   page.goto(url,wait_until='load');wait("window.__m11StageF?.phase === 'ready'");ready();initial=data()
   check(initial['city_kit_version']==3,'new game pins catalog 3');check(initial['web'],'actual web export');check(initial['scheduler']['backend']=='cooperative','non-threaded cooperative generation');check(not page.evaluate('crossOriginIsolated'),'no thread isolation needed');check(initial['renderer']['tiles']==16,'detailed core and coarse terrain ring integrated');capture('01_normal_city_planner')
   # A real canvas hit selects a canonical parcel, including an otherwise empty plot.
   point_slot=next(i for i,point in initial['renderer']['points'].items() if initial['clip']['top']+8<point['y']<initial['clip']['bottom']-8)
   point=initial['renderer']['points'][point_slot];x,y=xy(point)
   if name=='phone':page.touchscreen.tap(x,y)
   else:page.mouse.click(x,y)
   wait(f'window.__m11StageF.slot === {point_slot}');check(data()['preview_hash']==initial['preview_hash'],'canonical canvas pick preserves simulation')
   if name=='desktop':
    page.keyboard.press('ArrowRight');wait(f"window.__m11StageF.slot === {(int(point_slot)+1)%initial['slot_count']}");check(data()['preview_hash']==initial['preview_hash'],'keyboard parcel selection preserves simulation')
   else:
    current=data();rect=current['renderer']['rect'];center={'x':rect['x']+rect['width']/2,'y':(max(rect['y'],current['clip']['top'])+min(rect['y']+rect['height'],current['clip']['bottom']))/2};cx,cy=xy(center);before=current['renderer']['distance'];slot=current['slot'];cdp=context.new_cdp_session(page)
    def touches(spread):return [{'x':cx-spread,'y':cy,'id':0},{'x':cx+spread,'y':cy,'id':1}]
    cdp.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':touches(20)});page.wait_for_timeout(200);cdp.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':touches(40)});page.wait_for_timeout(200);cdp.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]});page.wait_for_timeout(600)
    check(data()['renderer']['distance']<before,'real two-finger pinch zooms city');check(data()['slot']==slot,'pinch does not select a parcel on release')
   tours={}
   for mode in ['3d','strategic']:
    action('fixture');wait("window.__m11StageF.phase === 'fixture_ready'")
    if data()['appearance']!=mode:click('AppearanceStrategic' if mode=='strategic' else 'Appearance3D')
    if mode=='3d':ready()
    begin=data();free=free_slots(begin);instance=begin['renderer'].get('instance');nodes=begin['renderer'].get('completed_nodes');terrain=begin['renderer'].get('terrain_requests')
    click('Slot_'+str(free[0]));click('Option_agriculture');wait("window.__m11StageF.pick === 'agriculture'")
    if mode=='3d':check(data()['renderer']['terrain_requests']==terrain,'ghost never bakes terrain');capture('02_actual_placement_preview')
    click('Build');wait('window.__m11StageF.queue.length === 1')
    if mode=='3d':check(data()['renderer']['instance']==instance,'build menu refresh keeps renderer');check(data()['renderer']['completed_nodes']==nodes,'queue preserves completed assemblies');check(data()['renderer']['terrain_requests']==terrain,'queue never bakes terrain')
    click('Slot_'+str(free[1]));click('Option_energy');click('Build');wait('window.__m11StageF.queue.length === 2');queue=data()['queue'];head=queue[1]['id']
    click('MoveUp_'+head);wait(f"window.__m11StageF.queue[0].id === '{head}'");turns=data()['queue'][0]['turns'];click('Rush_'+head);wait(f'window.__m11StageF.queue[0].turns === {turns-1}')
    if mode=='3d':capture('03_queued_construction')
    click('Cancel_'+head);wait('window.__m11StageF.queue.length === 1');click('Undo');wait('window.__m11StageF.queue.length === 2');click('Cancel_'+head);wait('window.__m11StageF.queue.length === 1')
    for i in range(8):
     if not data()['queue']:break
     resolve()
    check(not data()['queue'],'construction completes')
    if mode=='3d':ready()
    click('Slot_0');before=data();click('Upgrade');wait("window.__m11StageF.queue[0]?.kind === 'upgrade'");check(data()['tiers']['0']==1,'upgraded district remains original until completion')
    for i in range(8):
     if not data()['queue']:break
     resolve()
    check(data()['tiers']['0']==2,'real completed upgrade is tier II')
    if mode=='3d':
     check(data()['renderer']['terrain_requests']==before['renderer']['terrain_requests'],'upgrade reuses regional terrain')
     check(all(data()['renderer']['completed_nodes'][k]==v for k,v in before['renderer']['completed_nodes'].items() if k!='slot:0'),'upgrade only replaces affected assembly');capture('04_actual_completed_upgrade')
    click('Demolish');wait("!('0' in window.__m11StageF.tiers)")
    if mode=='3d':check('slot:0' not in data()['renderer']['completed_nodes'],'demolition changes geometry immediately');ready();capture('05_actual_prepared_ground')
    click('Undo');wait("window.__m11StageF.tiers['0'] === 2")
    if mode=='3d':ready()
    check(data()['anchor']==begin['anchor'],'all commands preserve geographic anchor');tours[mode]={'state_hash':data()['state_hash'],'preview_hash':data()['preview_hash'],'anchor':data()['anchor']}
   check(tours['3d']==tours['strategic'],'same real planner actions produce identical gameplay in both presentations')
   click('Appearance3D');ready();action('overview');action('save');check(data()['error']=='0','manual save completed');saved=data();capture('06_before_page_reload')
   page.wait_for_timeout(3500);page.close();page=context.new_page();watch(page);page.goto(url,wait_until='load');wait("window.__m11StageF?.phase === 'ready'");ready();restored=data()
   for field in ['state_hash','graphics_hash','prepared','anchor']:check(restored[field]==saved[field],'destroyed page reload retains '+field)
   capture('07_after_indexeddb_reload')
   action('text_200');ready();check(data()['text_scale']==2,'200% text retains normal planner');check(bool(data()['resource_chips']) and all(c['whole'] for c in data()['resource_chips']),'whole resource chips at 200%');capture('08_large_text_city')
   action('text_100');ready()
   prior=data();click('WorldDusk');wait('window.__m11StageF.renderer.dusk === true');capture('09_dusk_finish');click('WorldDusk');wait('window.__m11StageF.renderer.dusk === false')
   click('WorldParcels');wait('window.__m11StageF.renderer.parcels === false');check(data()['state_hash']==prior['state_hash'],'lighting and outlines preserve gameplay');click('WorldParcels')
   action('legacy_finish');ready();check(data()['city_kit_version']==2,'old look retained');old=data();click('UpgradeVisualFinish');ready();check(data()['city_kit_version']==3,'actual finish-upgrade button')
   for field in ['state_hash','anchor','prepared']:check(data()[field]==old[field],'explicit upgrade preserves '+field)
   action('system');action('reveal:WorldMount');wait('window.__m11StageF.space?.ids?.length > 5');click('Focus_pl_aster');wait('window.__m11StageF.space?.width >= 512');action('reveal:WorldMount');page.wait_for_timeout(600)
   current=data();rect=current['space']['rect'];center={'x':rect['x']+rect['width']/2,'y':(max(rect['y'],current['clip']['top'])+min(rect['y']+rect['height'],current['clip']['bottom']))/2};cx,cy=xy(center)
   if name=='desktop':
    page.mouse.click(cx,cy);page.keyboard.press('Home');wait("window.__m11StageF.space.selected === ''");page.keyboard.press('ArrowRight');wait("window.__m11StageF.view === 'colony' || (window.__m11StageF.space && window.__m11StageF.space.selected !== '')");check(data()['state_hash']==old['state_hash'],'space keyboard keeps game state')
   else:
    before=current['space']['distance'];selected=current['space']['selected'];cdp=context.new_cdp_session(page)
    def space_touches(spread):return [{'x':cx-spread,'y':cy,'id':0},{'x':cx+spread,'y':cy,'id':1}]
    cdp.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':space_touches(20)});page.wait_for_timeout(300);cdp.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':space_touches(40)});page.wait_for_timeout(300);cdp.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]});page.wait_for_timeout(800)
    check(data()['space']['distance']<before,'space pinch zooms');check(data()['space']['selected']==selected,'space pinch release keeps selection')
   action('system');action('reveal:WorldMount');click('Focus_pl_aster');wait('window.__m11StageF.space?.width >= 512');action('reveal:WorldMount');page.wait_for_timeout(500);path=out/f'{name}_10_space_finish.png';page.screenshot(path=str(path),timeout=120000);captures.append(path.name)
   check(not errors,'no browser/script errors')
   result={'name':name,'checks':checks,'errors':errors,'initial':initial,'tours':tours,'saved':saved,'restored':restored,'final':data(),'captures':captures,'qualification':'Actual non-threaded Chromium export using software GL and mouse/keyboard or touch emulation. IndexedDB tested by destroying page/WASM in the same browser context. Not physical device/power-loss certification.'};results.append(result);results.sort(key=lambda r:r['name']);verification_path.write_text(json.dumps(results,indent=2)+'\n');context.close();browser.close()
finally:server.shutdown()
(out/'verification.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps({'checks':sum(len(r['checks']) for r in results),'failures':sum(not c['pass'] for r in results for c in r['checks']),'captures':sum(len(r['captures']) for r in results)}))

"""Actual canvas interactions in the non-threaded Immersive Web review build."""
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
import json,threading,time,sys,os
from playwright.sync_api import sync_playwright
out=Path(os.environ.get('M11_OUT_DIR','screens/m11_immersive_web'));out.mkdir(parents=True,exist_ok=True);(out/'.gdignore').touch()
class Handler(SimpleHTTPRequestHandler):
    def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(Path(os.environ.get('M11_BUILD_DIR','build/web')).resolve())))
threading.Thread(target=server.serve_forever,daemon=True).start()
selected=sys.argv[sys.argv.index('--profile')+1] if '--profile' in sys.argv else None
results=json.loads((out/'verification.json').read_text()) if selected and (out/'verification.json').exists() else []
try:
 with sync_playwright() as p:
  for name,options in [('phone',{'viewport':{'width':873,'height':393},'device_scale_factor':2.75,'is_mobile':True,'has_touch':True}),('desktop',{'viewport':{'width':1280,'height':800}})]:
   if selected and name!=selected:continue
   results=[r for r in results if r['name']!=name]
   chromium_path=os.environ.get('M11_CHROMIUM_PATH','/usr/bin/chromium')
   browser=p.chromium.launch(executable_path=chromium_path if Path(chromium_path).is_file() else None,args=['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'])
   context=browser.new_context(**options);page=context.new_page();page.set_default_timeout(180000);checks=[];errors=[];captures=[];canvas_box=None
   def watch():
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
   watch()
   def check(value,label):
    checks.append({'label':label,'pass':bool(value)})
    if not value:raise AssertionError(label)
   def data():return page.evaluate('window.__m11StageF')
   def wait(expression,timeout=240000):page.wait_for_function(expression,timeout=timeout)
   def action(value):
    before=data()['serial'];page.evaluate('(v)=>{window.__m11StageFAction=v}',value);wait(f'window.__m11StageF.serial > {before}');page.wait_for_timeout(300)
   def ready():
    action('reveal:PlannerGrid');wait('window.__m11StageF.renderer.busy === false');page.wait_for_timeout(500)
   def xy(point):
    box=canvas_box;state=data();return box['x']+point['x']/state['viewport']['x']*box['width'],box['y']+point['y']/state['viewport']['y']*box['height']
   def click(key):
    print(name+' clicking '+key,flush=True)
    # A new dock may still be reflowing when the first reveal request arrives.
    # Recheck and scroll after it settles; never tap an unclipped/stale coordinate.
    for attempt in range(12):
     action('reveal:'+key);page.wait_for_timeout(700)
     if data().get('controls',{}).get(key,{}).get('reachable',False):break
    wait('window.__m11StageF.controls['+json.dumps(key)+']?.reachable === true')
    page.wait_for_timeout(700)
    button=data()['controls'][key];check(button['enabled'],'enabled '+key)
    x,y=xy(button);check(0<=x<=page.viewport_size['width'] and 0<=y<=page.viewport_size['height'],'reachable '+key)
    if name=='phone':page.touchscreen.tap(x,y)
    else:page.mouse.click(x,y)
    page.wait_for_timeout(700)
   def capture(label):
    path=out/f'{name}_{label}.png';page.screenshot(path=str(path),timeout=120000);captures.append(path.name);print('captured '+path.name,flush=True)
   def open_game():
    page.goto(f'http://127.0.0.1:{server.server_port}/index.html?smoke=m11-immersive',wait_until='load');wait("window.__m11StageF?.phase === 'ready'");ready()
   try:
    open_game();canvas_box=page.locator("#canvas").bounding_box();before=data();capture('command_city')
    click('ModeToggle');wait('window.__m11StageF.immersive_active === true');current=data()
    check(current['map_share']>(.65 if name=='phone' else .70),'Immersive map dominates screen')
    check(current['renderer']['instance']==before['renderer']['instance'],'switch retains live renderer')
    for field in ['state_hash','preview_hash','graphics_hash','anchor','prepared']:
     check(current[field]==before[field],'switch preserves '+field)
    check(current['renderer']['yaw']==before['renderer']['yaw'],'switch retains camera orbit')
    capture('immersive_city')
    rect=current['renderer']['rect'];point={'x':rect['x']+rect['width']*.25,'y':rect['y']+rect['height']*.30};cx,cy=xy(point)
    if name=='desktop':
     prior=current['renderer']['yaw'];page.mouse.move(cx,cy);page.mouse.down();page.wait_for_timeout(700);page.mouse.move(cx+80,cy+20,steps=4);page.wait_for_timeout(700);page.mouse.up()
     wait(f'window.__m11StageF.renderer.yaw !== {prior}');check(True,'actual map drag orbits')
     prior=data()['camera']['target'];page.mouse.move(cx,cy);page.mouse.down(button='middle');page.wait_for_timeout(700);page.mouse.move(cx+50,cy+15,steps=3);page.wait_for_timeout(700);page.mouse.up(button='middle');page.wait_for_timeout(600)
     check(data()['camera']['target']!=prior,'actual middle drag pans')
    else:
     prior=current['renderer']['distance'];slot=current['slot'];cdp=context.new_cdp_session(page)
     def fingers(spread):return [{'x':cx-spread,'y':cy,'id':0},{'x':cx+spread,'y':cy,'id':1}]
     cdp.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':fingers(20)});page.wait_for_timeout(500)
     cdp.send('Input.dispatchTouchEvent',{'type':'touchMove','touchPoints':fingers(40)});page.wait_for_timeout(500)
     cdp.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]});page.wait_for_timeout(700)
     check(data()['renderer']['distance']<prior,'actual pinch zooms');check(data()['slot']==slot,'pinch release does not select')
    action('overview')
    # Real construction controls in the contextual panel, not injected commands.
    state=data();free=next(i for i in range(state['slot_count']) if str(i) not in state['tiers'] and i not in state['blocked'] and i not in [b['slot'] for b in state['buildings']])
    click('ImmersiveManage' if name=='phone' else 'ImmersiveObjects');click('Slot_'+str(free));wait(f'window.__m11StageF.slot === {free}')
    check(data()['panel_open'] and data()['panel_kind']=='inspect','object selection opens contextual inspector')
    click('Option_agriculture');wait("window.__m11StageF.pick === 'agriculture'");capture('placement_preview')
    yaw=data()['renderer']['yaw'];click('Build');wait('window.__m11StageF.queue.length === 1')
    check(data()['renderer']['yaw']==yaw,'inspector click does not drag map');check(data()['renderer']['instance']==before['renderer']['instance'],'construction retains renderer')
    item=data()['queue'][0]['id'];click('Cancel_'+item);wait('window.__m11StageF.queue.length === 0');click('Undo');wait('window.__m11StageF.queue.length === 1')
    check(True,'build/cancel/Undo through actual canvas controls');capture('construction_queue')
    click('ModeToggle');wait('window.__m11StageF.view_mode === "command"');check(data()['queue'][0]['id']==item,'pending order survives Command switch')
    click('ModeToggle');wait('window.__m11StageF.immersive_active === true')
    for i in range(8):
     if not data()['queue']:break
     action('resolve');check(data()['state_hash']==data()['expected_hash'],'resolved turn agrees with pure simulation')
    ready();check(not data()['queue'],'construction completes');action('save');check(data()['error']=='0','save completed');saved=data()
    action('restore');ready();check(data()['view_mode']=='immersive' and data()['immersive_active'],'save/load retains device mode')
    for field in ['state_hash','graphics_hash','prepared','anchor']:check(data()[field]==saved[field],'save/load preserves '+field)
    action('persist_mode');check(page.evaluate("localStorage.getItem('starfire_hearth.view_mode.v1')")=='immersive','device mode persists immediately in browser storage');page.wait_for_timeout(3500);page.close();page=context.new_page();page.set_default_timeout(180000);watch();open_game();canvas_box=page.locator('#canvas').bounding_box()
    check(data()['view_mode']=='immersive' and data()['immersive_active'],'destroyed page loads saved device layout')
    for field in ['state_hash','graphics_hash','prepared','anchor']:check(data()[field]==saved[field],'destroyed page retains '+field)
    capture('restored_city')
    action('tools');click('Quality_standard');ready();check(data()['quality']=='standard','richer quality remains independently selectable')
    check(data()['renderer']['render_divisor']==1,'Standard renders full resolution');check(data()['state_hash']==saved['state_hash'],'quality retains gameplay')
    action('context_close');capture('standard_immersive_city');action('quality_low');ready()
    action('system');wait('window.__m11StageF.space?.ids?.length > 5');action('objects');click('Focus_pl_aster')
    wait("window.__m11StageF.space?.selected === 'pl_aster' && window.__m11StageF.space.width >= 512")
    action('context_close');capture('immersive_planet_close')
    action('galaxy');wait("window.__m11StageF.view === 'galaxy'");capture('immersive_galaxy')
    if name=='phone':
     page.set_viewport_size({'width':390,'height':844});action('fixture');ready();action('context_close');canvas_box=page.locator('#canvas').bounding_box()
     # Returning from a restored later turn to this fresh fixture can defer its
     # opening report until after setup. Dismiss it through the real control.
     if data()['controls'].get('Continue'):
      click('Continue');wait('!window.__m11StageF.controls.Continue')
     check(data()['map_share']>.65,'portrait map dominates screen');capture('portrait_overview')
     click('ImmersiveManage');wait('window.__m11StageF.panel_open && window.__m11StageF.panel_kind === "manage"');check(True,'portrait management opens through actual touch');capture('portrait_management');action('text_200');page.wait_for_timeout(1200)
     check(data()['text_scale']==2,'200% text preference applies');capture('portrait_large_text_management')
     click('ImmersiveTools');wait('window.__m11StageF.panel_open && window.__m11StageF.panel_kind === "tools"');check(True,'portrait scene controls open through actual touch at 200%');capture('portrait_large_text_controls');click('ImmersiveClose');wait('window.__m11StageF.panel_open === false')
     check(not data()['panel_open'],'portrait close control works at 200%');capture('portrait_large_text_overview')
    check(not errors,'no Web engine/script errors')
    results.append({'name':name,'checks':checks,'errors':errors,'captures':captures,'saved':saved,'final':data(),'qualification':'Actual non-threaded Web export; Chromium software SwiftShader with mouse/keyboard or touch emulation. No physical mobile GPU certification.'})
   except Exception as exc:
    (out/f'{name}_failure.json').write_text(json.dumps({'error':str(exc),'checks':checks,'errors':errors,'evidence':data()},indent=2)+'\n');raise
   finally:
    (out/'verification.json').write_text(json.dumps(results,indent=2)+'\n');context.close();browser.close()
finally:server.shutdown()
print(json.dumps({'checks':sum(len(r['checks']) for r in results),'captures':sum(len(r['captures']) for r in results),'errors':sum(len(r['errors']) for r in results)}))

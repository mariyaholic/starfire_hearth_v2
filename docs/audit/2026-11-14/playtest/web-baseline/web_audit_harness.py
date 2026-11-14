from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from playwright.sync_api import sync_playwright
from urllib.parse import urlsplit
import json,threading,time,sys,statistics,hashlib
out=Path('/workspace/.starfire-playtest/audit-web-baseline-context');out.mkdir(exist_ok=True)
build=Path('/workspace/starfire-evidence/m2f-fixed-build/web')
requests=[];responses=[];errors=[];actions=[];timings=[];captures=[]
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):
  if self.path=='/favicon.ico':self.send_response(204);self.end_headers();return
  super().do_GET()
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(build)));threading.Thread(target=server.serve_forever,daemon=True).start()
base=f'http://127.0.0.1:{server.server_port}'
report={'method':'Actual normal release Web canvas, fresh disposable Chromium context, desktop1920x1080/DPR1/SwiftShader, actual mouse input. No fixture or smoke query during normal flow. Passive input/rAF timing observer only; no game/state method calls.','build':str(build),'base_origin':base,'requests':requests,'responses':responses,'errors':errors,'actions':actions,'timings':timings,'captures':captures}
timing_install='''()=>{if(window.__auditTiming)return;let a={frames:[],inputs:[],enabled:false};window.__auditTiming=a;for(let type of ['pointerdown','pointerup','mousedown','mouseup','click','touchstart','touchend'])document.addEventListener(type,e=>{if(a.enabled)a.inputs.push({type,now:performance.now(),event_time:e.timeStamp,trusted:e.isTrusted});},{capture:true,passive:true});function frame(t){if(a.enabled)a.frames.push({timestamp:t,callback_now:performance.now()});requestAnimationFrame(frame);}requestAnimationFrame(frame);}'''
def dump():
 (out/'report.json').write_text(json.dumps(report,indent=2,default=str))
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'])
  context=browser.new_context(viewport={'width':1920,'height':1080},device_scale_factor=1)
  report['initial_storage_state']=context.storage_state()
  page=context.new_page();page.set_default_timeout(30000);cdp=context.new_cdp_session(page);cdp.send('Performance.enable')
  context.on('request',lambda q:requests.append({'timestamp':time.time(),'url':q.url,'method':q.method,'type':q.resource_type,'body_bytes':len(q.post_data_buffer or b''),'origin':urlsplit(q.url).scheme+'://'+urlsplit(q.url).netloc}))
  context.on('response',lambda q:responses.append({'timestamp':time.time(),'url':q.url,'status':q.status,'content_type':q.headers.get('content-type','')}))
  page.on('websocket',lambda ws:report.setdefault('websockets',[]).append({'timestamp':time.time(),'url':ws.url}))
  page.on('pageerror',lambda e:errors.append({'type':'pageerror','text':str(e)}))
  page.on('console',lambda m:errors.append({'type':'console','text':m.text}) if m.type=='error' else None)
  page.goto(base+'/index.html',wait_until='load',timeout=60000);page.wait_for_function("document.getElementById('status')===null",timeout=120000);page.wait_for_timeout(1000);page.evaluate(timing_install)
  page.screenshot(path=str(out/'raw-001.png'),timeout=20000);captures.append('raw-001.png');print('READY normal release title',flush=True);dump()
  def metrics():return {x['name']:x['value'] for x in cdp.send('Performance.getMetrics')['metrics']}
  def storage(name):
   snap=page.evaluate('''async()=>{let dbs=[];for(let info of await indexedDB.databases()){let db=await new Promise((resolve,reject)=>{let r=indexedDB.open(info.name);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});let stores=[];for(let sn of db.objectStoreNames){let vals=await new Promise((resolve,reject)=>{let tx=db.transaction(sn,'readonly'),st=tx.objectStore(sn),kr=st.getAllKeys(),vr=st.getAll();tx.oncomplete=()=>resolve(kr.result.map((key,i)=>({key,mode:vr.result[i].mode,timestamp:vr.result[i].timestamp,bytes:vr.result[i].contents?.byteLength||0,text:(typeof key==='string'&&(key.endsWith('.json')||key.endsWith('.cfg'))&&vr.result[i].contents)?new TextDecoder().decode(vr.result[i].contents):null})));tx.onerror=()=>reject(tx.error)});stores.push({name:sn,entries:vals});}dbs.push({name:info.name,version:info.version,stores});db.close();}return {local_storage:{...localStorage},session_storage:{...sessionStorage},databases:dbs,service_workers:navigator.serviceWorker?await navigator.serviceWorker.getRegistrations().then(a=>a.map(r=>({scope:r.scope,active:r.active?.scriptURL}))):[]};}''')
   snap['cookies']=context.cookies();(out/name).write_text(json.dumps(snap,indent=2,default=str));print('STORAGE',name,flush=True)
  for line in sys.stdin:
   a=json.loads(line);actions.append(dict(a,timestamp=time.time()))
   if a.get('quit'):break
   if 'click' in a:
    if a.get('measure'):
     page.evaluate('()=>{let a=window.__auditTiming;a.frames=[];a.inputs=[];a.enabled=true;a.started=performance.now();}');before=metrics();start=time.monotonic();page.mouse.click(*a['click']);click_call_ms=(time.monotonic()-start)*1000;page.wait_for_timeout(2000)
     captured=page.evaluate('()=>{let a=window.__auditTiming;a.enabled=false;return {started:a.started,ended:performance.now(),frames:a.frames,inputs:a.inputs};}');after=metrics();events=captured['inputs'];frames=captured['frames'];deltas=[frames[i]['timestamp']-frames[i-1]['timestamp'] for i in range(1,len(frames))]
     feedback=[]
     for event in events:
      next_frame=next((f for f in frames if f['callback_now']>=event['now']),None)
      feedback.append({'event':event['type'],'event_to_next_raf_callback_ms':None if next_frame is None else next_frame['callback_now']-event['now'],'trusted':event['trusted']})
     timings.append({'label':a.get('label','click'),'click_call_wall_ms':click_call_ms,'browser_window_ms':captured['ended']-captured['started'],'events':feedback,'raf_interval_ms':{'count':len(deltas),'median':statistics.median(deltas) if deltas else None,'p95':sorted(deltas)[int(.95*(len(deltas)-1))] if deltas else None,'max':max(deltas) if deltas else None},'cdp_metrics_delta':{k:after.get(k,0)-before.get(k,0) for k in ['TaskDuration','ScriptDuration','LayoutDuration','RecalcStyleDuration']},'raw':captured,'qualification':'No screenshot/readback during timing window. Event→next JS requestAnimationFrame callback and main-thread CDP durations; NOT visible-paint feedback or GPU/render frame cost.'})
    else:page.mouse.click(*a['click'])
   if 'wheel' in a:page.mouse.move(*a.get('at',[1800,700]));page.mouse.wheel(0,a['wheel'])
   if 'reload' in a:page.reload(wait_until='load',timeout=60000);page.wait_for_function("document.getElementById('status')===null",timeout=120000);page.evaluate(timing_install)
   if a.get('navigate_smoke'):
    page.goto(base+'/index.html?smoke=begin',wait_until='load',timeout=60000);page.wait_for_function("document.getElementById('status')===null",timeout=120000);page.evaluate(timing_install)
   if 'key' in a:page.keyboard.press(a['key'])
   page.wait_for_timeout(a.get('wait',1200))
   if 'storage' in a:storage(a['storage'])
   if 'capture' in a:
    name=a['capture'];page.screenshot(path=str(out/name),timeout=20000);captures.append(name);print('CAPTURED',name,flush=True)
   dump();print('DONE',a,flush=True)
  context.close();browser.close()
except Exception as e:report['failure']=str(e);print('FAILURE',str(e),flush=True)
finally:dump();server.shutdown()

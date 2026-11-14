from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from playwright.sync_api import sync_playwright
import json,threading,time,sys
out=Path('/workspace/.starfire-playtest/m2f-web-actual/rapid-reload-run');out.mkdir(parents=True,exist_ok=True)
build=Path('/workspace/starfire-evidence/m2f-build/web')
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):
  if self.path=='/favicon.ico':
   self.send_response(204);self.end_headers();return
  if self.path=='/__setup':
   self.send_response(200);self.send_header('Content-Type','text/html');self.end_headers();self.wfile.write(b'<!doctype html><title>Explicit synthetic fixture bootstrap</title>');return
  super().do_GET()
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(build)))
threading.Thread(target=server.serve_forever,daemon=True).start()
report={'userfs_prefix':'/userfs/godot/app_userdata/Starfire Hearth/','method':'Fresh production Web export in Chromium SwiftShader. Synthetic nearwin SaveSerializer file and text200 settings seeded into IndexedDB BEFORE first app load; subsequent gameplay only actual touchscreen taps. No smoke hooks or runtime game/state calls.','build':str(build),'actions':[],'errors':[],'captures':[]}
fixture=Path('/tmp/starfire-m2f-actual-data/godot/app_userdata/Starfire Hearth/saves/fixture_m2f_nearwin.json').read_text()
settings='[display]\nsettings_version=2\ntext_scale=2.0\nui_scale=1.0\nappearance="3d"\nview_mode="command"\n[audio]\nmuted=true\n'
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'])
  context=browser.new_context(viewport={'width':873,'height':393},device_scale_factor=2.75,is_mobile=True,has_touch=True)
  page=context.new_page();page.set_default_timeout(30000)
  page.on('response',lambda r:report.setdefault('http_errors',[]).append({'url':r.url,'status':r.status}) if r.status>=400 else None)
  page.on('pageerror',lambda e:report['errors'].append(str(e)))
  page.on('console',lambda m:report['errors'].append(m.text) if m.type=='error' else None)
  base=f'http://127.0.0.1:{server.server_port}'
  page.goto(base+'/__setup')
  page.evaluate('''async ({fixture,settings})=>{
   const db=await new Promise((resolve,reject)=>{let r=indexedDB.open('/userfs',21);r.onupgradeneeded=e=>{let d=e.target.result;let st=d.objectStoreNames.contains('FILE_DATA')?e.target.transaction.objectStore('FILE_DATA'):d.createObjectStore('FILE_DATA');if(!st.indexNames.contains('timestamp'))st.createIndex('timestamp','timestamp',{unique:false});};r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
   await new Promise((resolve,reject)=>{let t=db.transaction('FILE_DATA','readwrite'),s=t.objectStore('FILE_DATA');let timestamp=new Date();for(let path of ['/userfs/godot','/userfs/godot/app_userdata','/userfs/godot/app_userdata/Starfire Hearth','/userfs/godot/app_userdata/Starfire Hearth/saves'])s.put({timestamp,mode:16895},path);s.put({timestamp,mode:33206,contents:new TextEncoder().encode(fixture)},'/userfs/godot/app_userdata/Starfire Hearth/saves/fixture_m2f_nearwin.json');s.put({timestamp,mode:33206,contents:new TextEncoder().encode(settings)},'/userfs/godot/app_userdata/Starfire Hearth/settings.cfg');t.oncomplete=resolve;t.onerror=()=>reject(t.error);});db.close();
  }''',{'fixture':fixture,'settings':settings})
  report['actions'].append({'action':'INITIAL SETUP seed normal SaveSerializer file + text200 settings in IndexedDB','timestamp':time.time()})
  print('SEEDED synthetic nearwin fixture before app load',flush=True)
  page.goto(base+'/index.html',wait_until='load',timeout=45000)
  page.wait_for_function("document.getElementById('status')===null",timeout=120000)
  page.wait_for_timeout(1200)
  page.screenshot(path=str(out/'raw-001.png'),timeout=20000);report['captures'].append('raw-001.png')
  print('READY title captured raw-001.png',flush=True)
  print('STORAGE',page.evaluate("async()=>{let list=[];for(let info of await indexedDB.databases()){let db=await new Promise(r=>{let q=indexedDB.open(info.name);q.onsuccess=()=>r(q.result)});for(let sn of db.objectStoreNames){let keys=await new Promise(r=>{let q=db.transaction(sn).objectStore(sn).getAllKeys();q.onsuccess=()=>r(q.result)});list.push({db:info.name,store:sn,keys});}db.close();}return list;}"),flush=True)
  print('ENGINE_KEYS',page.evaluate("Object.keys(engine)"),flush=True)
  print('RUNTIME_KEYS',page.evaluate("Object.keys(engine.rtenv)"),flush=True)
  page.wait_for_timeout(4000)
  for line in sys.stdin:
   action=json.loads(line)
   report['actions'].append(dict(action,timestamp=time.time()))
   if action.get('quit'):break
   if 'tap' in action:page.touchscreen.tap(*action['tap'])
   if 'tap_reload' in action:
    t0=time.monotonic();page.touchscreen.tap(*action['tap_reload']);page.wait_for_timeout(action.get('reload_after_ms',500));report['rapid_reload_delay_ms']=round((time.monotonic()-t0)*1000,1);page.reload(wait_until='load',timeout=45000);page.wait_for_function("document.getElementById('status')===null",timeout=120000)
   if 'wheel' in action:page.mouse.move(*action.get('at',[810,235]));page.mouse.wheel(0,action['wheel'])
   if 'reload' in action:
    page.reload(wait_until='load',timeout=45000);page.wait_for_function("document.getElementById('status')===null",timeout=120000)
   page.wait_for_timeout(action.get('wait',1200))
   if 'read_idb' in action:
    records=page.evaluate('''async()=>{let db=await new Promise((resolve,reject)=>{let r=indexedDB.open('/userfs');r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});let values=await new Promise((resolve,reject)=>{let tx=db.transaction('FILE_DATA','readonly'),s=tx.objectStore('FILE_DATA'),kr=s.getAllKeys(),vr=s.getAll();tx.oncomplete=()=>resolve(kr.result.map((k,i)=>({path:k,mode:vr.result[i].mode,timestamp:vr.result[i].timestamp,text:vr.result[i].contents?new TextDecoder().decode(vr.result[i].contents):null})));tx.onerror=()=>reject(tx.error)});db.close();return values.filter(x=>x.path.endsWith('.json')||x.path.endsWith('settings.cfg'));}''')
    (out/action['read_idb']).write_text(json.dumps(records,indent=2,default=str));print('READ IDB',action['read_idb'],[r['path'] for r in records],flush=True)
   if 'capture' in action:
    name=action['capture'];page.screenshot(path=str(out/name),timeout=20000);report['captures'].append(name);print('CAPTURED '+name,flush=True)
   print('DONE',action,flush=True)
  context.close();browser.close()
except Exception as e:
 report['failure']=str(e);print('FAILURE',str(e),flush=True)
finally:
 (out/'report.json').write_text(json.dumps(report,indent=2));server.shutdown()

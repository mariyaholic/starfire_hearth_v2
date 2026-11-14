from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from functools import partial
from threading import Thread
from playwright.sync_api import sync_playwright
import json
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*args): pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory='/workspace/starfire-audit-verifier-web'))
Thread(target=server.serve_forever,daemon=True).start()
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'])
 page=browser.new_page(viewport={'width':1280,'height':800}); errors=[]
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.goto(f'http://127.0.0.1:{server.server_port}/index.html')
 page.wait_for_function('window.__auditLaunched === 3', timeout=90000)
 page.wait_for_function('window.__auditResult && Object.keys(window.__auditResult.results).length === 3',timeout=40000)
 result=page.evaluate('({launched:window.__auditLaunched,...window.__auditResult})');result['page_errors']=errors
 print(json.dumps(result,indent=2))
 page.screenshot(path='/workspace/starfire-audit-verifier-web/fixture.png')
 assert result['launched']==3 and result['pending']==0 and result['results']=={'a':True,'b':True,'timeout':False} and not errors
 browser.close()
server.shutdown()

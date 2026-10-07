"""Exercise actual A/B playback and native AAC decoding in desktop/mobile Chromium."""
from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
import argparse,json,threading
from playwright.sync_api import sync_playwright
from serve_review import RangeHandler
parser=argparse.ArgumentParser();parser.add_argument('--out',default='reports/audio_rework');args=parser.parse_args()
root=Path(args.out).resolve();checks=[];errors=[];completed=False
class Handler(RangeHandler):
 def log_message(self,*_):pass
server=ThreadingHTTPServer(('127.0.0.1',0),partial(Handler,directory=str(root)));threading.Thread(target=server.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{server.server_port}/'
def check(label,value):
 checks.append({'check':label,'pass':bool(value)})
 if not value:raise AssertionError(label)
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox','--disable-dev-shm-usage','--autoplay-policy=no-user-gesture-required','--mute-audio'])
  for device,config in [('desktop',{'viewport':{'width':1365,'height':950}}),('phone',{'viewport':{'width':390,'height':844},'is_mobile':True,'has_touch':True,'device_scale_factor':2})]:
   ctx=browser.new_context(**config,accept_downloads=True);page=ctx.new_page();page.on('pageerror',lambda err:errors.append(str(err)));page.goto(base+'index.html')
   check(device+' shows all 84 comparisons',page.locator('.cue').count()==84)
   check(device+' has no horizontal overflow',page.evaluate('document.documentElement.scrollWidth <= innerWidth'))
   page.locator('[data-kind="Music"]').click();check(device+' music filter contains all 28',page.locator('.cue').count()==28)
   page.locator('#search').fill('Sola');check(device+' search finds the character theme',page.locator('.cue').count()==1)
   page.locator('#search').fill('');page.locator('[data-play="before"][data-id="mus_title"]').click()
   page.wait_for_function('selected?.slug === "mus_title" && !audio.paused && audio.currentTime > selected.preview_start+.05')
   check(device+' preview seeks to the intended middle excerpt',page.evaluate('Math.abs(audio.currentTime-selected.preview_start)<2'))
   before_time=page.evaluate('audio.currentTime');page.locator('#b').click();page.wait_for_function('side === "after" && !audio.paused && !pendingSeek')
   check(device+' A/B switch preserves position',abs(page.evaluate('audio.currentTime')-before_time)<2)
   check(device+' level matching is applied',page.evaluate('Math.abs(gain.gain.value-selected.after_gain)<.0001'))
   page.locator('#length').select_option('full');page.wait_for_function('!audio.paused && audio.currentTime<2');check(device+' full track starts at its opening',page.evaluate('audio.duration>100 && startPoint===0'))
   page.locator('#pause').click();check(device+' pause works',page.evaluate('audio.paused'))
   page.locator('[data-kind="All"]').click();page.locator('#search').fill('ui_click_1');page.locator('[data-play="pair"][data-id="ui_click_1"]').click();page.wait_for_function('side === "after" && audio.ended')
   check(device+' short SFX before/after pair completes',page.evaluate('selected.slug==="ui_click_1" && !pairing'))
   page.locator('.cue summary').click();page.locator('[data-vote="New rendition"]').click();page.locator('.cue summary').click();page.locator('textarea').fill('A/B review test note')
   with page.expect_download() as download:page.locator('#export').click()
   path=Path(download.value.path());notes=json.loads(path.read_text());check(device+' notes export retains cue preference and text',notes['notes']['ui_click_1']=={'vote':'New rendition','note':'A/B review test note'})
   page.locator('#search').fill('');page.screenshot(path=str(root/(device+'_player.png')),full_page=False)
   if device=='desktop':
    decoded=page.evaluate('''async () => {const context=new AudioContext({sampleRate:48000});let results=[];for(let i=0;i<entries.length;i+=4){let batch=entries.slice(i,i+4);let rows=await Promise.all(batch.flatMap(e=>['before','after'].map(async s=>{try{const response=await fetch(e[s+'_audio']);if(!response.ok)throw Error(response.status);const decoded=await context.decodeAudioData(await response.arrayBuffer());return {cue:e.slug,side:s,seconds:decoded.duration,pass:Math.abs(decoded.duration-e.seconds)<.065}}catch(err){return {cue:e.slug,side:s,pass:false,error:String(err)}}})));results.push(...rows)}await context.close();return results}''')
    (root/'browser_decode.json').write_text(json.dumps(decoded,indent=2)+'\n');check('Native browser decodes all 168 AAC files with correct duration',len(decoded)==168 and all(r['pass'] for r in decoded))
   ctx.close();print(device+' player controls passed',flush=True)
  # Load self-contained editions, then disconnect networking before playback.
  # Cloud Chromium policy disallows file:// navigation; respect that policy.
  for edition in ['QuickListen','Complete']:
   ctx=browser.new_context(viewport={'width':390,'height':844},is_mobile=True,has_touch=True);page=ctx.new_page();page.on('pageerror',lambda err:errors.append(str(err)));page.goto(base+f'StarfireHearth_Audio_AB_{edition}.html',timeout=120000);ctx.set_offline(True)
   check(edition+' offline edition includes all 84 cards',page.locator('.cue').count()==84)
   page.locator('#search').fill('mus_title');page.locator('[data-play="after"][data-id="mus_title"]').click();page.wait_for_function('selected?.slug==="mus_title" && !audio.paused && !pendingSeek',timeout=30000)
   check(edition+' offline music source is embedded',page.evaluate('audio.src.startsWith("data:audio/mp4;base64,")'))
   check(edition+' uses correct preview start',page.evaluate('Math.abs(startPoint-(PREVIEW_ONLY?0:selected.preview_start))<.01'))
   if edition=='QuickListen':check('Quick edition plays trimmed 20-second excerpt',page.evaluate('audio.duration<20.1 && audio.duration>19.9'))
   else:
    page.locator('#length').select_option('full');page.wait_for_function('!audio.paused && audio.currentTime<2');check('Complete edition contains the entire track',page.evaluate('audio.duration>100'))
   page.locator('#a').click();page.wait_for_function('side==="before" && !audio.paused && !pendingSeek',timeout=30000);check(edition+' switches to original with network disconnected',page.evaluate('audio.src.startsWith("data:audio/mp4;base64,")'))
   ctx.close();print(edition+' offline playback passed',flush=True)
  browser.close()
 check('No JavaScript errors',not errors)
 completed=True
finally:
 server.shutdown();(root/'browser_verification.json').write_text(json.dumps({'passed':completed and all(c['pass'] for c in checks) and not errors,'completed':completed,'checks':checks,'errors':errors,'scope':'Desktop and touch/mobile layouts in Chromium; native AAC decode. Physical iOS/Android devices were not tested.'},indent=2)+'\n')
print(json.dumps({'checks':len(checks),'errors':errors}),flush=True)

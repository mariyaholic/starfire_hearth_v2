"""Build a searchable A/B player, complete offline player, small preview player and reels."""
from pathlib import Path
import argparse,json,base64,subprocess,hashlib,shutil,zipfile
import numpy as np,soundfile as sf
parser=argparse.ArgumentParser();parser.add_argument('--out',default='reports/audio_rework');args=parser.parse_args();root=Path(args.out)
shutil.copy2(Path(__file__).parent/'ATTRIBUTION.txt',root/'ATTRIBUTION.txt')
data=json.loads((root/'catalogue.json').read_text());items=data['items']
revision=max(e.get('render_revision',1) for e in items);data['revision']=revision
SFX_DESCRIPTIONS={
'ui_click':'Three distinct recorded-piano taps with a faint wooden attack.',
'ui_hover':'A quieter, short high-piano tick for hover feedback.',
'ui_confirm':'A clear rising two-note piano confirmation.',
'ui_cancel':'A falling two-note cancellation response.',
'ui_error':'Two separated low-note pulses, distinct from confirmation.',
'ui_toggle_on':'An ascending paired tap with a soft mechanical accent.',
'ui_toggle_off':'A descending paired tap with a soft mechanical accent.',
'ui_panel_open':'A restrained band-limited swish with a high-note opening accent.',
'ui_panel_close':'A restrained swish with a lower closing accent.',
'ui_tooltip_pin':'A compact glassy pin/chime.',
'ui_end_turn':'A low glassy pulse resolving upward through a short three-note figure.',
'ui_alert':'Two rising glass-like attention tones.',
'ui_alert_critical':'Three spaced warning tones with a falling middle response.',
'ui_event_open':'An unfolding three-note piano figure for a new event.',
'ui_choice_made':'A compact major piano chord confirming a choice.',
'ui_page_turn':'Three textured paper-like swishes with a quiet high-note detail.',
'ui_research_done':'An ascending glassy three-note discovery figure.',
'ui_build_done':'A wooden placement transient followed by rising piano notes.',
'ui_place_district':'Three different placement notes with a recorded wooden transient.',
'ui_demolish':'A short drum-backed low breakup sound.',
'ui_pop_growth':'A gentle rising piano pair for population growth.',
'ui_overflow_warn':'A rising oscillating warning tone with a bright detail.',
'ship_move_order':'Two concise navigation pings.',
'ship_arrive':'A low arrival tone with a soft filtered landing burst.',
'survey_ping':'A stereo glassy scan pulse with a quieter answering echo.',
'beacon_activate':'A gradually rising stereo beacon chord, from low energy to a clearer crest.',
'jump_transit':'A rising transit sweep, shaped noise and a recorded drum accent.',
'noise_threshold':'Two low pulses to indicate a strategic noise threshold.',
'hit_kinetic':'Three metal-backed impacts with sharper, differentiated transients.',
'hit_thermal':'Three filtered thermal bursts with high glassy accents.',
'hit_explosive':'Three low drum-backed explosions with differentiated burst textures.',
'shield_hit':'Three distinct glassy resonances, each with a second lower tone.',
'pd_intercept':'A tight three-tap interception burst.',
'ship_destroyed':'A stereo drum/metal breakup with a longer filtered decay.',
'battle_won':'A rising three-note piano resolution.',
'battle_lost':'A falling low-piano resolution.',
'treaty_signed':'A warm piano chord with a restrained signing transient.',
'war_declared':'A low recorded drum impact and dark resonant warning tone.',
'vael_voice':'Three nonverbal glassy tonal textures; no invented spoken dialogue.',
'ambient_ui_room':'A seamless stereo ventilation/room bed with quieter controlled low harmonics.'}
for e in items:
 if e['kind']=='sfx':e['description']=SFX_DESCRIPTIONS[e['id']]
 e['category']='Music' if e['kind']=='music' else 'Interface' if e['id'].startswith('ui_') else 'Ambience' if e['id']=='ambient_ui_room' else 'Space & combat'
 e['family']='Character themes' if e['id'].startswith('theme_') else 'Mood pieces' if e['id'].startswith('mood_') else 'Endings & stings' if e['id'].startswith('sting_') else 'Main score' if e['kind']=='music' else e['category']
 e['preview_start']=round(e['seconds']*.34,3) if e['kind']=='music' and e['seconds']>25 else 0
 name=e['slug'];e['title']=name.replace('mus_','').replace('theme_','').replace('mood_','').replace('sting_','').replace('ui_','').replace('_',' ').title()
 if name=='mus_title':e['title']='Main title — Starfire Hearth'
 if name.startswith('theme_'):e['title']+=' — character theme'
 data['preview_note']='Music previews play 20 seconds from the middle; every SFX variant plays in full. Full mode starts at the opening.'
(root/'catalogue.json').write_text(json.dumps(data,indent=2)+'\n')
TEMPLATE=r'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Starfire Hearth — complete audio A/B review</title><style>
:root{color-scheme:dark;--bg:#09131e;--card:#142435;--line:#2d455b;--text:#e4edf5;--muted:#a4b8cb;--gold:#edc582;--teal:#64c4bc}*{box-sizing:border-box}body{margin:0;background:radial-gradient(ellipse at top,#173248,#09131e 65%);color:var(--text);font:16px/1.5 system-ui,sans-serif}main{max-width:1040px;margin:auto;padding:28px 20px 80px}h1{font-size:clamp(25px,4vw,38px);margin:0 0 10px;color:var(--gold);letter-spacing:.01em}p{margin:8px 0}.sub,.muted{color:var(--muted)}.pill{display:inline-block;border:1px solid var(--line);border-radius:20px;padding:5px 12px;margin:8px 5px 0 0}button,select,input,textarea{font:inherit}button,select{min-height:46px;border-radius:9px;border:1px solid var(--line);background:#1b3044;color:var(--text);padding:9px 14px;cursor:pointer}button:hover{border-color:var(--teal)}button:focus-visible,input:focus-visible{outline:2px solid var(--gold);outline-offset:3px}button.selected{border-color:var(--teal);background:#244e58}button.before{color:#e4c99f}button.after{color:#87e0cf}button:disabled{opacity:.45;cursor:default}a{color:#87d9d1}.row{display:flex;flex-wrap:wrap;gap:8px;align-items:center}.player{position:sticky;top:0;z-index:5;background:rgba(14,30,44,.98);border:1px solid #345369;border-radius:16px;padding:18px;margin:22px 0;box-shadow:0 8px 30px #0006}.player h2{font-size:20px;margin:0 0 6px}.now{color:var(--gold);font-size:14px}.seek{width:100%;margin:14px 0 4px;accent-color:var(--teal)}.time{display:flex;justify-content:space-between;color:var(--muted);font-variant-numeric:tabular-nums}.player small{display:block;color:var(--muted);margin:9px 0}.search{width:100%;padding:12px 14px;border:1px solid var(--line);background:#101f2e;color:var(--text);border-radius:10px;margin:15px 0}.cards{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:13px}.cue{padding:17px;background:var(--card);border:1px solid var(--line);border-radius:12px;scroll-margin-top:280px}.cue.active{border-color:var(--gold)}.cue h3{font-size:18px;margin:3px 0 7px}.cue .id{font:12px/1.5 ui-monospace,monospace;overflow-wrap:anywhere;color:var(--muted)}.cue p{font-size:14px;min-height:44px;color:var(--muted)}.cue .row button{flex:1}.meta{font-size:12px;color:var(--muted)}details{margin:11px 0 0;font-size:14px}summary{cursor:pointer;color:var(--muted)}textarea{width:100%;padding:8px;background:#0c1c2a;border:1px solid var(--line);border-radius:8px;color:var(--text);min-height:70px;margin:10px 0}.votes button{font-size:12px;min-height:40px;padding:6px}header .intro{max-width:850px}.toolbar{margin:15px 0}.footer{border-top:1px solid var(--line);padding-top:20px;margin-top:25px;font-size:13px;color:var(--muted)}#status{min-height:24px}.count{margin:14px 0}.hidden{display:none}.notice{padding:11px 14px;border-left:3px solid var(--gold);background:#152b3c;margin:16px 0}@media(max-width:650px){main{padding:16px 12px 60px}.cards{grid-template-columns:1fr}.player{padding:12px;border-radius:10px;margin:16px 0;position:relative}.player h2{font-size:18px}.player button{padding:8px 11px}.cue p{min-height:0}.toolbar button{flex:1}.row{gap:7px}h1{font-size:27px}}@media(prefers-reduced-motion:no-preference){button{transition:border-color .12s}}</style></head><body><main>
<header><h1>Starfire Hearth · Audio review</h1><p class="sub intro">Every music cue and sound-effect variant, before and after. A complete rendition set for your listening review.</p><span class="pill">__MUSIC__ music cues</span><span class="pill">__SFX__ SFX & ambience files</span><span class="pill">__TOTAL__ full comparisons</span>__REVISION_NOTE__<div class="notice">The original game audio is preserved. New music uses recorded piano, orchestra and percussion; SFX have been individually redesigned. These are fresh arrangements for the same cue roles, rather than note-for-note transcriptions.</div><p class="sub">__MODE_NOTE__</p></header>
<section class="player" aria-label="Comparison player"><div class="now" id="nowVersion">Choose a cue below</div><h2 id="nowTitle">Ready to compare</h2><div class="row"><button id="a" class="before" disabled>▶ Before</button><button id="b" class="after" disabled>▶ After</button><button id="pair" disabled>A → B</button><button id="pause" disabled>Pause</button><button id="next" disabled>Next cue</button></div><input id="seek" class="seek" type="range" min="0" max="100" value="0" step=".1" aria-label="Playback position"><div class="time"><span id="elapsed">0:00</span><span id="duration">0:00</span></div><div class="row"><label>Play <select id="length"><option value="preview">20-second music preview</option><option value="full">Full length from opening</option></select></label><label><input type="checkbox" id="matched" checked> Match listening levels</label></div><small>Switch A/B to compare at the same time position. All short effects play in full. Only one recording plays at a time.</small><div id="status" role="status" aria-live="polite"></div></section>
<div class="row toolbar" aria-label="Catalogue filters"><button class="filter selected" data-kind="All">All</button><button class="filter" data-kind="Music">Music</button><button class="filter" data-kind="Interface">Interface</button><button class="filter" data-kind="Space & combat">Space & combat</button><button class="filter" data-kind="Ambience">Ambience</button><button id="playlist">Play visible A/B list</button><button id="export">Download my notes</button></div><input id="search" class="search" type="search" placeholder="Find a cue, character or variant…" aria-label="Search audio cues"><div class="count muted" id="count"></div><section class="cards" id="cards"></section><audio id="audio" preload="none"></audio>
<div class="footer"><p>Prepared 7 October 2026 · Original source files and review-only renditions remain separate from the game.</p><p>Piano: Salamander Grand Piano v3 by Alexander Holm, <a href="https://creativecommons.org/licenses/by/3.0/">CC BY 3.0</a>. Orchestral samples: VSCO 2 Community Edition by Versilian Studios and contributors, CC0. New orchestration, performance maps, hall processing and SFX design: Starfire Hearth audio review. See ATTRIBUTION.txt for sources and modifications.</p><p>No speech recordings are included. Vael effects are nonverbal tonal textures. The large instrument libraries are not part of this listening package.</p></div></main><script>
const DATA=__DATA__;const EMBED=__EMBED__;const PREVIEW_ONLY=__PREVIEW_ONLY__;const entries=DATA.items;const $=id=>document.getElementById(id);let selected=null,side='after',visible=entries,filter='All',pairing=false,queue=false,pairStage=0,limit=Infinity,startPoint=0,pendingSeek=0,ctx=null,gain=null,serial=0,notes={};
try{notes=JSON.parse(localStorage.getItem('starfire-audio-review-v1')||'{}')}catch{}
const audio=$('audio');const time=n=>{n=Math.max(0,n||0);return Math.floor(n/60)+':'+String(Math.floor(n%60)).padStart(2,'0')};const escape=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function store(){try{localStorage.setItem('starfire-audio-review-v1',JSON.stringify(notes))}catch{}}function levels(){if(!selected)return;const g=$('matched').checked?selected[side+'_gain']:1;if(gain)gain.gain.value=g;else audio.volume=g}
async function soundContext(){if(!ctx){try{ctx=new(window.AudioContext||window.webkitAudioContext)();gain=ctx.createGain();ctx.createMediaElementSource(audio).connect(gain).connect(ctx.destination)}catch{ctx=null;gain=null}}if(ctx&&ctx.state==='suspended')await ctx.resume();levels()}
function source(e,s){return EMBED[e.slug+'_'+s]||e[s+'_audio']}
async function play(e,s,restart=false,pair=false){if(!e)return;serial++;const mine=serial;let position=selected&&selected.slug===e.slug&&!restart?audio.currentTime:0;audio.pause();selected=e;side=s;pairing=pair;pairStage=s==='before'?0:1;
 const preview=$('length').value==='preview';startPoint=preview&&!PREVIEW_ONLY?e.preview_start:0;if(restart||position===0)position=startPoint;pendingSeek=position;limit=preview&&e.kind==='music'?startPoint+Math.min(20,e.seconds-startPoint):Infinity;
 $('nowVersion').textContent=(s==='before'?'BEFORE · Original':'AFTER · New rendition')+' · '+e.family;$('nowTitle').textContent=e.title;$('status').textContent='Loading…';['a','b','pair','pause','next'].forEach(id=>$(id).disabled=false);$('a').classList.toggle('selected',s==='before');$('b').classList.toggle('selected',s==='after');
 const url=source(e,s);if(audio.getAttribute('src')!==url){audio.src=url;audio.load()}else{audio.currentTime=pendingSeek;pendingSeek=0}
 render();await soundContext();if(mine!==serial)return;try{await audio.play();$('status').textContent=preview&&e.kind==='music'?'Playing a 20-second comparison excerpt.':'Playing the complete recording.'}catch(err){$('status').textContent='Tap Before or After to start playback.'}}
audio.addEventListener('loadedmetadata',()=>{if(pendingSeek){audio.currentTime=Math.min(pendingSeek,Math.max(0,audio.duration-.1));pendingSeek=0}$('duration').textContent=time(audio.duration)});audio.addEventListener('error',()=>{$('status').textContent='This audio file could not load. Use the full offline package with its media folders.';pairing=false;queue=false});
function advance(){if(pairing&&pairStage===0){play(selected,'after',true,true);return}pairing=false;if(queue){const i=visible.findIndex(e=>e.slug===selected.slug);if(i>=0&&i+1<visible.length){play(visible[i+1],'before',true,true);return}queue=false}$('status').textContent='Comparison finished.'}
audio.addEventListener('ended',advance);audio.addEventListener('timeupdate',()=>{$('elapsed').textContent=time(audio.currentTime);$('seek').value=audio.duration?audio.currentTime/audio.duration*100:0;if(audio.currentTime>=limit&&!audio.paused){audio.pause();advance()}});
$('seek').addEventListener('input',()=>{if(audio.duration)audio.currentTime=audio.duration*Number($('seek').value)/100});$('a').onclick=()=>{queue=false;play(selected,'before')};$('b').onclick=()=>{queue=false;play(selected,'after')};$('pair').onclick=()=>{queue=false;play(selected,'before',true,true)};$('pause').onclick=()=>{audio.pause();pairing=false;queue=false;$('status').textContent='Paused.'};$('next').onclick=()=>{queue=false;const i=visible.findIndex(e=>e.slug===selected?.slug);play(visible[(i+1)%visible.length],'after',true)};$('matched').onchange=levels;$('length').onchange=()=>{queue=false;if(selected)play(selected,side,true)};
function render(){const q=$('search').value.toLowerCase();visible=entries.filter(e=>(filter==='All'||e.category===filter)&&[e.title,e.id,e.slug,e.description,e.family].join(' ').toLowerCase().includes(q));$('count').textContent=visible.length+' of '+entries.length+' comparisons';$('cards').innerHTML=visible.map(e=>{const saved=notes[e.slug]||{};return `<article class="cue ${selected?.slug===e.slug?'active':''}" data-cue="${e.slug}"><div class="meta">${escape(e.family)} · ${time(e.seconds)}${/_[123]$/.test(e.slug)?' · Variant '+e.slug.slice(-1):''}</div><h3>${escape(e.title)}</h3><div class="id">${escape(e.slug)}</div><p>${escape(e.description)}</p><div class="row"><button class="before" data-play="before" data-id="${e.slug}">▶ Before</button><button class="after" data-play="after" data-id="${e.slug}">▶ After</button><button data-play="pair" data-id="${e.slug}">A → B</button></div><details ${saved.note?'open':''}><summary>My choice & notes${saved.vote?' · '+escape(saved.vote):''}</summary><div class="row votes">${['Original','New rendition','Needs revision'].map(v=>`<button data-vote="${v}" data-id="${e.slug}" class="${saved.vote===v?'selected':''}">${v}</button>`).join('')}</div><textarea data-note="${e.slug}" aria-label="Notes for ${escape(e.title)}" placeholder="What should change?">${escape(saved.note||'')}</textarea></details></article>`}).join('');}
$('cards').addEventListener('click',ev=>{const b=ev.target.closest('button');if(!b)return;const e=entries.find(x=>x.slug===b.dataset.id);if(b.dataset.play){queue=false;play(e,b.dataset.play==='pair'?'before':b.dataset.play,true,b.dataset.play==='pair')}if(b.dataset.vote){notes[e.slug]={...notes[e.slug],vote:b.dataset.vote};store();render()}});$('cards').addEventListener('input',ev=>{if(ev.target.dataset.note){const id=ev.target.dataset.note;notes[id]={...notes[id],note:ev.target.value};store()}});$('search').oninput=render;document.querySelectorAll('.filter').forEach(b=>b.onclick=()=>{filter=b.dataset.kind;document.querySelectorAll('.filter').forEach(x=>x.classList.toggle('selected',x===b));render()});$('playlist').onclick=()=>{if(!visible.length)return;queue=true;play(visible[0],'before',true,true)};$('export').onclick=()=>{const blob=new Blob([JSON.stringify({project:'Starfire Hearth audio review',date:new Date().toISOString(),notes},null,2)],{type:'application/json'});const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='StarfireHearth_audio_notes.json';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000)};
if(__PREVIEW_ONLY__){$('length').innerHTML='<option value="preview">20-second music preview</option>';$('status').textContent='Compact offline preview; complete SFX and music excerpts.'}render();
</script></body></html>'''

def page(path,embedded=None,preview_only=False):
 content=TEMPLATE.replace('__MUSIC__',str(sum(e['kind']=='music' for e in items))).replace('__SFX__',str(sum(e['kind']=='sfx' for e in items))).replace('__TOTAL__',str(len(items))).replace('__MODE_NOTE__','Compact offline edition: all 84 entries, full SFX and 20-second music excerpts. Full-length pairs are in the complete edition.' if preview_only else 'Use short previews for a quick pass, or choose Full length to hear every complete cue. Level matching is on by default.')
 content=content.replace('__REVISION_NOTE__','<p class="sub">Revision 2 · connected orchestral phrasing, piano pedalling and softer wooden accents.</p>' if revision>=2 else '')
 content=content.replace('__DATA__',json.dumps(data,separators=(',',':'))).replace('__EMBED__',json.dumps(embedded or {},separators=(',',':'))).replace('__PREVIEW_ONLY__','true' if preview_only else 'false');path.write_text(content)
page(root/'index.html')
print('Streaming/full offline folder player built',flush=True)
embedded_full={};embedded_preview={};preview_folder=root/'previews';preview_folder.mkdir(exist_ok=True)
for e in items:
 for side in ['before','after']:
  path=root/e[side+'_audio'];embedded_full[e['slug']+'_'+side]='data:audio/mp4;base64,'+base64.b64encode(path.read_bytes()).decode()
  if e['kind']=='music':
   preview=preview_folder/(e['slug']+'_'+side+'.m4a')
   subprocess.run(['ffmpeg','-v','error','-y','-ss',str(e['preview_start']),'-i',str(path),'-t','20','-c:a','aac','-b:a','160k','-movflags','+faststart',str(preview)],check=True)
   embedded_preview[e['slug']+'_'+side]='data:audio/mp4;base64,'+base64.b64encode(preview.read_bytes()).decode()
  else:embedded_preview[e['slug']+'_'+side]=embedded_full[e['slug']+'_'+side]
page(root/'StarfireHearth_Audio_AB_Complete.html',embedded_full)
page(root/'StarfireHearth_Audio_AB_QuickListen.html',embedded_preview,True)
print('Single-file complete and compact players built',flush=True)
# Spoken labels are deliberately absent: this package contains no newly invented character voices.
# Cue order and timecodes are provided beside the reels for a full, uncluttered SFX listen.
reel_items=[e for e in items if e['kind']=='sfx'];segments=[];timeline=[];clock=0.0
for e in reel_items:
 timeline.append({'seconds':round(clock,3),'cue':e['slug'],'order':'before, short gap, after, next cue'})
 for side in ['before','after']:
  path=root/(e['before_file'] if side=='before' else 'masters/'+e['slug']+'.wav');x,sr=sf.read(path,dtype='float32',always_2d=True)
  if sr!=48000:raise ValueError(path)
  if x.shape[1]==1:x=np.repeat(x,2,axis=1)
  x*=e[side+'_gain'];segments.extend([x,np.zeros((round(.32*sr),2),np.float32)]);clock+=len(x)/sr+.32
wave=root/'All_SFX_Before_After.wav';sf.write(wave,np.concatenate(segments),48000,subtype='PCM_24')
subprocess.run(['ffmpeg','-v','error','-y','-i',str(wave),'-c:a','libmp3lame','-b:a','192k',str(root/'All_SFX_Before_After.mp3')],check=True)
(root/'SFX_Reel_Timecodes.json').write_text(json.dumps(timeline,indent=2)+'\n')
# A continuous mobile-friendly overview of every music cue, with matched A/B levels.
music_segments=[];music_timeline=[];clock=0.0
for e in items:
 if e['kind']!='music':continue
 music_timeline.append({'seconds':round(clock,3),'cue':e['slug'],'source_start':e['preview_start'],'order':'before excerpt, gap, after excerpt, gap'})
 for side in ['before','after']:
  path=root/(e['before_file'] if side=='before' else 'masters/'+e['slug']+'.wav')
  with sf.SoundFile(path) as f:
   f.seek(round(e['preview_start']*f.samplerate));x=f.read(round(20*f.samplerate),dtype='float32',always_2d=True);sr=f.samplerate
  if sr!=48000:raise ValueError(path)
  if x.shape[1]==1:x=np.repeat(x,2,axis=1)
  x*=e[side+'_gain'];fade=min(round(.025*sr),len(x)//4);x[:fade]*=np.linspace(0,1,fade)[:,None];x[-fade:]*=np.linspace(1,0,fade)[:,None]
  music_segments.extend([x,np.zeros((round(.4*sr),2),np.float32)]);clock+=len(x)/sr+.4
music_wave=root/'All_Music_Before_After.wav';sf.write(music_wave,np.concatenate(music_segments),48000,subtype='PCM_24')
subprocess.run(['ffmpeg','-v','error','-y','-i',str(music_wave),'-c:a','libmp3lame','-b:a','192k',str(root/'All_Music_Before_After.mp3')],check=True)
(root/'Music_Reel_Timecodes.json').write_text(json.dumps(music_timeline,indent=2)+'\n')
(root/'README.txt').write_text('Starfire Hearth — every music cue and SFX variant, before and after\n\nOpen index.html alongside its media folders, or open the Complete.html single-file\nplayer. QuickListen.html is a smaller offline edition with 20-second music excerpts\nand complete SFX. Complete.html includes all full-length recordings inside one file.\n\n28 music cues and 56 SFX/ambience files. Original assets are copied exactly under\nbefore/. New game-format renditions are under after/. Browser listening copies are\nAAC/M4A for mobile playback. MIDI/scores remain available for further refinement.\n\nThese are full new sampled arrangements/recompositions for each original cue role,\nnot note-for-note transcriptions. The existing game files have not been replaced.\n\nListen with Match listening levels enabled for a fair comparison. Select Original,\nNew rendition or Needs revision, then Download my notes to send feedback.\n\nSee ATTRIBUTION.txt for the sampled instrument sources and credits.\n')
archive=root/'StarfireHearth_Audio_AB_Review.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as bundle:
 for folder in ['before','after','media','scores']:
  for p in sorted((root/folder).rglob('*')):
   if p.is_file():bundle.write(p,p.relative_to(root))
 for e in items:
  if e['kind']!='music':continue
  score=json.loads((root/'scores'/(e['slug']+'.json')).read_text())
  for instrument in score['stems']:
   p=root/'renders'/e['slug']/(instrument+'.mid')
   bundle.write(p,Path('midi')/p.relative_to(root/'renders'))
 for name in ['index.html','catalogue.json','README.txt','ATTRIBUTION.txt','verification.json','All_SFX_Before_After.mp3','SFX_Reel_Timecodes.json','All_Music_Before_After.mp3','Music_Reel_Timecodes.json','phrasing_verification.json','Phrasing_Revision_Comparison.mp3','Phrasing_Comparison_Timecodes.json','sample_map_coverage_comparison.json','REVIEW_REPORT.md','LISTENING_INDEX.md']:
  p=root/name
  if p.exists():bundle.write(p,p.name)
meta={'files':len(items),'music':sum(e['kind']=='music' for e in items),'sfx':len(reel_items),'archive_bytes':archive.stat().st_size,'archive_sha256':hashlib.file_digest(archive.open('rb'),'sha256').hexdigest(),'complete_html_bytes':(root/'StarfireHearth_Audio_AB_Complete.html').stat().st_size,'quick_html_bytes':(root/'StarfireHearth_Audio_AB_QuickListen.html').stat().st_size}
(root/'package_info.json').write_text(json.dumps(meta,indent=2)+'\n');print(json.dumps(meta),flush=True)

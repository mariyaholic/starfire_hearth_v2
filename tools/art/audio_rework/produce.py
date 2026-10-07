"""Compose full sampled cue renditions and individually redesign every delivered SFX.
Outputs review assets only. Never writes the game's delivered assets or manifest.
"""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import argparse,json,hashlib,subprocess,math,re,shutil,time
from functools import lru_cache
import numpy as np
import soundfile as sf
from scipy import signal
from mido import MidiFile,MidiTrack,Message,MetaMessage,bpm2tempo
from phrasing import phrase,write_midi as write_phrased_midi
from compose import score_r3
SR=48000
RENDERER=Path('/workspace/.starfire-setup/audio-tools/bin/sfizz_render')
PRESETS={
'mus_title':('D',48,4,'piano','grand','Piano opening develops into full strings, soft wooden mallet colour and a warm horn statement.'),
'mus_slowboat_1':('D',48,4,'piano','domestic','Warm piano, flute and intimate strings; a gentle colony-day theme.'),
'mus_slowboat_2':('G',48,4,'flute','pastoral','Flute-led afternoon variation with light strings and answering piano.'),
'mus_beacon_1':('D',48,4,'flute','wonder','Harp motion, broad strings and rising woodwind discovery phrases.'),
'mus_beacon_2':('G',48,4,'clarinet','trade','More flowing clarinet, pizzicato movement and light recorded percussion.'),
'mus_jump_1':('B',40,4,'piano','dark','Minor-key piano and low strings, developing into a broader string ensemble.'),
'mus_jump_2':('B',40,4,'horn','lonely','A spacious horn melody over deep strings, piano and soft wooden accents.'),
'mus_attention':('B',32,4,'clarinet','vast','Low orchestral gravity, a held clarinet line, soft marimba colour and suspended harmony.'),
'mus_battle':('B',48,4,'horn','battle','Measured spiccato strings, horn calls and sampled timpani/cymbal punctuation.'),
 'theme_sola':('D',40,4,'clarinet','scholar','Playful clarinet melody, pizzicato strings, bassoon answers and piano.'),
 'theme_varga':('D',32,4,'cello','earnest','Warm cello lead, patient piano and a slowly expanding string arrangement.'),
 'theme_brandt':('D',48,4,'horn','march','Loyal horn theme with light marching snare and articulated strings.'),
 'theme_hale':('D',48,3,'clarinet','waltz','Formal orchestral waltz with a contrasting minor middle section.'),
 'theme_speaker':('D',24,4,'clarinet','alien','A patient clarinet line, softly voiced marimba and shifting string harmonies.'),
 'theme_rook':('B',40,4,'harp','wry','Weathered plucked-harp theme, low strings and an uneven accompaniment rhythm.'),
 'mood_warm':('G',40,4,'piano','warm','Lyrical piano, gentle woodwind answers and warm ensemble strings.'),
 'mood_sorrow':('B',32,4,'piano','sorrow','Exposed piano and cello; tender strings arrive gradually.'),
 'mood_mystery':('B',32,4,'flute','mystery','Suspended woodwinds, sparse piano and delicate wooden mallet punctuation.'),
 'mood_tension':('B',40,4,'cello','tension','Low repeated strings, restrained upper suspensions and a controlled rise.'),
 'mood_hope':('D',40,4,'violin','hope','Ascending string melody and the shared home motif supported by warm horns.'),
 'mood_light':('D',40,4,'clarinet','playful','Light pizzicato, nimble woodwinds and sampled marimba accents.'),
 'sting_victory':('D',6,4,'horn','victory','Compact full-orchestra resolution with timpani and a ringing major cadence.'),
 'sting_defeat':('B',4,4,'cello','defeat','Low cello and piano fall, offering a subdued, human ending.'),
 'sting_hide':('B',12,4,'piano','hide','The home motif reduces to intimate piano and near-still strings.'),
 'sting_warn':('D',20,4,'clarinet','relay','The motif passes between clarinet, flute, piano and horn as the ensemble grows.'),
 'sting_answer':('B',16,4,'clarinet','answer','A held clarinet response to the motif above soft marimba, piano and suspended strings.'),
 'sting_shield':('D',16,4,'horn','shield','Protective sustained horn/strings, rising harmony and a solemn close.'),
 'sting_homecoming':('D',24,4,'piano','homecoming','The home motif returns in warm major, building to the fullest orchestral statement.')}
# Shared musical vocabulary, with individual character/mood phrases and developments.
MAJOR=[(50,54,57),(47,50,54),(43,47,50),(45,49,52),(42,45,50),(40,43,47),(43,47,50),(45,50,52)]
MINOR=[(47,50,54),(43,47,50),(50,54,57),(45,49,52),(40,43,47),(47,50,54),(42,45,49),(47,50,54)]
MOTIFS={
'grand':[62,66,69,71,69,66,64,62],'domestic':[66,64,62,69,66,64,62,64],
'pastoral':[67,71,74,76,74,71,69,67],'wonder':[62,64,69,71,74,71,69,66],
'trade':[67,69,71,74,71,69,67,66],'dark':[59,62,66,64,62,59,57,59],
'lonely':[66,62,59,62,64,66,62,59],'vast':[83,90,86,85,83,78,81,83],
'battle':[59,66,62,59,57,59,62,66],'scholar':[66,69,67,66,64,62,64,66],
'earnest':[50,54,57,54,52,50,47,50],'march':[62,69,66,64,62,66,69,62],
'waltz':[66,69,74,73,71,69,66,64],'alien':[86,90,93,88,86,85,81,86],
'wry':[59,62,57,59,66,64,62,59],'warm':[67,71,74,71,69,67,66,67],
'sorrow':[59,62,66,64,62,61,59,57],'mystery':[71,74,78,76,74,73,71,69],
'tension':[47,54,50,52,47,50,54,47],'hope':[62,64,66,69,71,74,71,69],
'playful':[74,71,69,66,69,71,74,78],'victory':[62,66,69,74,71,69,66,74],
'defeat':[54,50,47,45,47,50,47,47],'hide':[62,59,57,59,54,50,47,47],
'relay':[62,66,69,71,69,66,64,62],'answer':[83,86,90,88,85,86,81,83],
'shield':[50,54,57,62,61,59,57,62],'homecoming':[62,66,69,71,74,71,69,62]}
PANS={'piano':-.08,'violin':-.32,'viola':-.13,'cello':.18,'bass':.12,'pizz':-.27,'spiccato':-.30,'horn':.24,'flute':-.16,'clarinet':.10,'bassoon':.15,'harp':-.35,'glock':.30,'marimba':.10}
parser=argparse.ArgumentParser();parser.add_argument('--libraries',default='/workspace/.starfire-setup/audio-libraries');parser.add_argument('--out',default='reports/audio_rework');parser.add_argument('--only',nargs='*');parser.add_argument('--workers',type=int,default=4);parser.add_argument('--revision',type=int,default=2,choices=[2,3]);args=parser.parse_args()
ROOT=Path.cwd();LIB=Path(args.libraries);OUT=Path(args.out);OUT.mkdir(parents=True,exist_ok=True)
INSTRUMENTS=json.loads((LIB/'instruments.json').read_text())
generation=hashlib.sha256()
for path in [Path(__file__),Path(__file__).with_name('phrasing.py'),*([Path(__file__).with_name('compose.py')] if args.revision==3 else []),Path(__file__).with_name('prepare_libraries.py'),LIB/'provenance.json',LIB/'piano'/'Salamander Grand Piano V3.sfz',*map(Path,INSTRUMENTS.values())]:generation.update(path.read_bytes())
MUSIC_GENERATION=generation.hexdigest()
MANIFEST=json.loads((ROOT/'data/asset_manifest.json').read_text())['assets']
SOURCE_ROOT=ROOT/'assets/delivered'
INVENTORY=[]
for asset in MANIFEST:
 if asset['kind'] not in ['music','sfx'] or asset['status']!='delivered':continue
 for name in asset.get('files',[asset.get('file')]):
  if name:
   source=SOURCE_ROOT/name
   INVENTORY.append({'id':asset['id'],'kind':asset['kind'],'file':name,'seconds':round(sf.info(source).duration,3),'bytes':source.stat().st_size})
for folder in ['before','after','masters','scores','renders','media/before','media/after','logs']: (OUT/folder).mkdir(parents=True,exist_ok=True)

def seed_of(name):return int(hashlib.sha256(name.encode()).hexdigest()[:8],16)
@lru_cache(maxsize=None)
def instrument_range(instrument):
 text=Path(INSTRUMENTS[instrument]).read_text()
 ns=[int(x) for x in re.findall(r'pitch_keycenter=(\d+)',text)]
 return min(ns)-2,max(ns)+2
def fitted_note(n,instrument):
 if instrument=='piano':return int(n)
 lo,hi=instrument_range(instrument)
 while n<lo:n+=12
 while n>hi:n-=12
 return int(n)

def score(item):
 cue=item['id'];key,bars,meter,lead,style,description=PRESETS[cue];duration=item['seconds'];ending=cue.startswith('sting_');tail=min(4,duration*.16) if ending else 0
 beat=(duration-tail)/(bars*meter);bpm=60/beat;rng=np.random.default_rng(seed_of(cue));stems={};events=[]
 def add(inst,start,length,note,velocity,role,voice=None):
  if inst not in INSTRUMENTS:return
  start=max(0,float(start)+float(rng.uniform(-.008,.008)));length=max(.08,float(length));vel=int(np.clip(velocity+rng.integers(-3,4),25,112));note=fitted_note(note,inst)
  ev={'at':round(start,4),'duration':round(length,4),'note':note,'velocity':vel,'role':role,'voice':voice or role};stems.setdefault(inst,[]).append(ev)
 quiet=style in ['sorrow','hide','mystery','vast','alien','defeat'];energetic=style in ['battle','march','victory','trade','playful'];grand=style in ['grand','wonder','hope','relay','shield','homecoming','lonely']
 motif=MOTIFS[style]
 for bar in range(bars):
  p=bar/max(1,bars-1);at=bar*meter*beat;is_intro=bar<max(2,bars//8);is_outro=bar>=bars-max(2,bars//8)
  swell=.25+.65*math.sin(math.pi*p)**1.3
  if ending:swell=.25+.7*min(1,p*1.6)
  if style in ['hide','defeat']:swell=.65*(1-p)+.10
  if style in ['victory','battle']:swell=.65+.25*math.sin(math.pi*p)
  chords=MINOR if key=='B' else MAJOR
  if key=='G':chords=MAJOR[2:]+MAJOR[:2]
  if style=='waltz' and .38<p<.66:chords=MINOR
  root,third,fifth=chords[bar%len(chords)];chord=(root,third,fifth)
  if ending and bar==bars-1:chord=(47,50,54) if key=='B' else (50,54,57);root,third,fifth=chord
  # Piano/harp accompaniment uses sparse broken voicings, with more motion in development.
  if style not in ['alien','vast']:
   pattern=[0,2] if quiet or is_intro else [0,1,2,3] if meter==4 else [0,1,2]
   if style=='wry':pattern=[0,.75,2.5]
   for j,pos in enumerate(pattern):
    n=chord[j%3]+(12 if j else 0)
    add('piano' if style not in ['wry','wonder','trade'] else 'harp',at+pos*beat,beat*.8,n,48+12*swell,'broken accompaniment')
  if grand or style in ['pastoral','warm','mystery','alien']:
   for j,pos in enumerate([.5,1.5,2.5] if meter==3 else [.5,1.5,2.5,3.5]):
    if quiet and bar%2:continue
    add('marimba',at+pos*beat,beat*1.4,chord[j%3]+12,32+12*swell,'soft wooden accompaniment')
  # Distinct melody: a repeated recognizable phrase, answered/developed every eight bars.
  melody_lead=lead
  if style=='relay':melody_lead=['clarinet','flute','piano','horn'][(bar//4)%4]
  if style=='grand' and is_intro:melody_lead='piano'
  positions=[0,2] if meter==4 else [0,1.5]
  if energetic:positions=[0,1,2,3] if meter==4 else [0,1,2]
  if quiet:positions=[0] if bar%2==0 else [1.5]
  for j,pos in enumerate(positions):
   n=motif[(bar*2+j)%len(motif)]
   if style in ['vast','alien','answer']:n-=24
   if 8<=bar%(16)<12 and not quiet:n+=12 if melody_lead in ['piano','flute','violin'] else -2
   if ending and bar==bars-1:n=59 if key=='B' else 62
   length=beat*(2.4 if quiet else 1.5 if len(positions)==2 else .7)
   add(melody_lead,at+pos*beat,length,n,64+18*swell,'lead melody')
  if style in ['vast','answer'] and bar%2==0:
   add('marimba',at+.5*beat,beat*2,third+24,35+8*swell,'soft wooden colour')
  if not is_intro or energetic or style in ['earnest','alien','shield']:
   if style not in ['scholar','playful','trade']:
    for voice,(inst,n) in enumerate([('violin',fifth+24),('violin',third+24),('viola',third+12),('cello',root+12),('bass',root)]):
     if inst==lead and style=='earnest' and bar%2==0:continue
     if is_outro and not ending and inst in ['violin','viola']:continue
     add(inst,at+.025,meter*beat*.94,n,43+25*swell,'sustained orchestra',f'harmony {voice}')
   else:
    for pos in range(meter):
     add('pizz',at+pos*beat,beat*.4,(root if pos%2==0 else fifth)+24,48+14*swell,'pizzicato rhythm')
    add('cello',at,meter*beat*.85,root+12,43+18*swell,'low string support')
  if energetic or style=='tension':
   for j in range(meter*2):
    inst='spiccato' if style in ['battle','tension','march'] else 'pizz'
    add(inst,at+j*.5*beat,.36*beat,chord[j%3]+(12 if style=='tension' else 24),43+22*swell,'articulated ostinato')
  if grand and swell>.60 and not is_intro:
   add('horn',at+.2*beat,meter*beat*.8,root+24,48+17*swell,'warm brass support')
   if style in ['grand','homecoming','shield'] and p>.50:add('horn',at+.3*beat,meter*beat*.75,fifth+12,44+15*swell,'brass harmony')
  if style in ['scholar','domestic','pastoral','warm'] and bar%4==3:
   answer='bassoon' if style=='scholar' else 'flute'
   for j,pos in enumerate([2,3] if meter==4 else [1,2]):add(answer,at+pos*beat,.8*beat,chord[j+1]+24,48+12*swell,'woodwind answer')
  if style=='playful':add('marimba',at+2.5*beat,.6*beat,fifth+24,51,'mallet accent')
  if energetic or style in ['homecoming','relay','shield']:
   if bar%4==0:events.append({'sample':'timpani','at':at,'gain':.20+.20*swell})
   if style in ['battle','march','trade']:
    for pos in [1,3] if meter==4 else [1,2]:events.append({'sample':'snare','at':at+pos*beat,'gain':.09 if style=='trade' else .16})
   if bar%8==0 and not is_intro:events.append({'sample':'cymbal','at':at,'gain':.10+.10*swell})
 if style in ['victory','homecoming']:events.append({'sample':'cymbal','at':(bars-1)*meter*beat,'gain':.20})
 phrasing=phrase(stems,beat,meter,bars,ending)
 record={'id':cue,'style':style,'key':'B minor' if key=='B' else 'G major' if key=='G' else 'D major','bpm':bpm,'meter':meter,'bars':bars,'seconds':duration,'music_end':bars*meter*beat,'bar_seconds':meter*beat,'description':description,'motif':motif,'stems':stems,'percussion':events,'loop':not ending,'phrasing':phrasing,'method':'New full-length sampled orchestration/recomposition for the original cue role; not a note-for-note transcription or EQ-only remaster.'}
 (OUT/'scores'/(cue+'.json')).write_text(json.dumps(record,indent=2)+'\n')
 return record

def read_audio(path,limit=None):
 data,rate=sf.read(path,dtype='float32',always_2d=True)
 if rate!=SR:data=signal.resample_poly(data,SR,rate,axis=0).astype(np.float32)
 if limit is not None:data=data[:int(limit*SR)]
 return data

def recorded_hit(kind):
 d=LIB/'vsco'/'Percussion'
 patterns={'timpani':'Timpani/Timpani3_Hit_v2_rr1_Sum.wav','snare':'snare*','cymbal':'cymbal-crash1_mp_rr1.wav','metal':'Anvil_Hit1_v2_Sum.wav','drum':'BDrumNewhit_v3_rr1_Sum.wav','wood':'Claves1_Hit_v1_rr1_Sum.wav'}
 if kind in ['snare']:
  choices=sorted(d.glob(patterns[kind]))
  if not choices:choices=sorted(d.glob('*Snare*'))+sorted(d.glob('*snare*'))
  path=choices[0]
 else:path=d/patterns[kind]
 if not path.exists():
  choices=sorted(d.rglob('*'+('Snare' if kind=='snare' else 'Hit')+'*.wav'));path=choices[0]
 data=read_audio(path,4);data=data.mean(axis=1);peak=np.max(np.abs(data));return data/(peak or 1)
HITS={}
for kind in ['timpani','snare','cymbal','metal','drum','wood']:HITS[kind]=recorded_hit(kind)

def hall_impulse(seed,seconds=2.2):
 rng=np.random.default_rng(seed);n=int(SR*seconds);t=np.arange(n)/SR
 ir=rng.normal(0,1,n).astype(np.float32)*np.exp(-t*4.8/seconds)
 ir[:int(.030*SR)]=0
 ir=signal.sosfilt(signal.butter(2,5200,fs=SR,output='sos'),ir).astype(np.float32)
 ir/=max(.001,np.sqrt(np.sum(ir*ir)));ir*=.12
 for delay,g in [(0.027,.14),(0.049,.11),(0.077,.07),(0.109,.045)]:ir[int((delay+rng.uniform(-.003,.003))*SR)]+=g
 return ir

def loudness(path):
 cmd=['ffmpeg','-hide_banner','-nostats','-i',str(path),'-af','loudnorm=I=-18:TP=-1.2:LRA=12:print_format=json','-f','null','-']
 p=subprocess.run(cmd,capture_output=True,text=True,check=True)
 matches=re.findall(r'\{\s*"input_i"[\s\S]*?\}',p.stderr)
 if not matches:raise RuntimeError('No loudness measurement for '+str(path))
 return json.loads(matches[-1])

def master_and_media(data,item,notes):
 cue=item['id'];basename=Path(item['file']).stem;kind=item['kind'];master=OUT/'masters'/(basename+'.wav')
 data=np.asarray(data,dtype=np.float32)
 if data.ndim==1:data=data[:,None]
 data-=data.mean(axis=0,keepdims=True)
 peak=float(np.max(np.abs(data)))
 if not np.isfinite(data).all() or peak<1e-5:raise RuntimeError('Invalid or silent rendition '+basename)
 if kind=='music' or cue=='ambient_ui_room':data*=.55/peak
 elif peak>.82:data*=.82/peak
 sf.write(master,data,SR,subtype='PCM_24')
 if kind=='music' or cue=='ambient_ui_room':
  m=loudness(master);integrated=float(m['input_i']);tp=float(m['input_tp']);target=-30 if cue=='ambient_ui_room' else -18
  gain=min(target-integrated,-1.25-tp);data*=10**(gain/20);sf.write(master,data,SR,subtype='PCM_24')
  # A sparse piano transient must not leave the entire cue unnecessarily quiet.
  # Only when peak-constrained, gently shape the top of its transient envelope.
  if target-integrated>gain+.5:
   ceiling=10**(-1.7/20);knee=ceiling*.86
   for _ in range(3):
    current=float(loudness(master)['input_i']);data*=10**((target-current)/20)
    magnitude=np.abs(data);over=magnitude>knee
    data[over]=np.sign(data[over])*(knee+(ceiling-knee)*(1-np.exp(-(magnitude[over]-knee)/(ceiling-knee))))
    sf.write(master,data,SR,subtype='PCM_24')
 after=OUT/'after'/item['file'];after.parent.mkdir(exist_ok=True)
 if after.suffix=='.wav':sf.write(after,data,SR,subtype='PCM_24')
 else:subprocess.run(['ffmpeg','-v','error','-y','-i',str(master),'-c:a','libvorbis','-q:a','8',str(after)],check=True)
 before=OUT/'before'/item['file'];before.parent.mkdir(exist_ok=True);shutil.copy2(SOURCE_ROOT/item['file'],before)
 for version,source in [('before',before),('after',master)]:
  destination=OUT/'media'/version/(basename+'.m4a')
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(source),'-c:a','aac','-b:a','192k' if kind=='music' else '128k','-ar','48000','-movflags','+faststart',str(destination)],check=True)
 # Review gain is attenuation only: RMS-matched short effects, LUFS-matched longer cues.
 old=read_audio(before);new=read_audio(master)
 if kind=='music':
  bm=loudness(before);am=loudness(master);bl=float(bm['input_i']);al=float(am['input_i'])
 else:
  bl=20*math.log10(max(1e-8,float(np.sqrt(np.mean(old*old)))));al=20*math.log10(max(1e-8,float(np.sqrt(np.mean(new*new)))))
 target=min(bl,al);result=dict(item,slug=basename,title=basename.replace('_',' ').title(),description=notes,after_file=str(after.relative_to(OUT)),before_file=str(before.relative_to(OUT)),before_audio=f'media/before/{basename}.m4a',after_audio=f'media/after/{basename}.m4a',before_gain=10**((target-bl)/20),after_gain=10**((target-al)/20),before_level=bl,after_level=al,peak=float(np.max(np.abs(new))),source_sha256=hashlib.file_digest(before.open('rb'),'sha256').hexdigest(),after_sha256=hashlib.file_digest(after.open('rb'),'sha256').hexdigest())
 (OUT/'logs'/(basename+'.json')).write_text(json.dumps(result,indent=2)+'\n');return result

def apply_dynamics(data,curve):
 """Multiply a rendered part by a smooth gain curve of (seconds, gain) points."""
 t=np.arange(len(data))/SR;times=[c[0] for c in curve];gains=[c[1] for c in curve]
 return data*np.interp(t,times,gains,right=gains[-1]).astype(np.float32)[:,None]

def active_rms_db(data):
 """Level of a part while it plays, ignoring the bars where it rests."""
 mono=data.mean(axis=1);block=SR//10;count=len(mono)//block
 if count==0:return -120.0
 rms=np.sqrt(np.mean(mono[:count*block].reshape(count,block)**2,axis=1));loud=rms[rms>np.max(rms)*.05]
 return 20*math.log10(max(1e-9,float(np.sqrt(np.mean(loud**2)))))

def render_music_r3(item):
 cue=item['id'];key,bars,meter,lead,style,description=PRESETS[cue]
 s=score_r3(cue,PRESETS[cue],item['seconds'],MOTIFS[style],fitted_note,np.random.default_rng(seed_of(cue)))
 (OUT/'scores'/(cue+'.json')).write_text(json.dumps(s,indent=2)+'\n')
 n=round(item['seconds']*SR);dry=np.zeros((n,2),np.float32);send=np.zeros((n,2),np.float32)
 folder=OUT/'renders'/cue;folder.mkdir(exist_ok=True)
 for name,p in s['parts'].items():
  inst=p['instrument'];events=p['events']
  if not events or inst not in INSTRUMENTS:continue
  midi=folder/(name+'.mid');wav=folder/(name+'.wav');write_phrased_midi(events,midi,s['bpm'],item['seconds']+3,inst,s['bar_seconds'],s['music_end'])
  with (folder/(name+'.log')).open('w') as log:
   subprocess.run([str(RENDERER),'--sfz',INSTRUMENTS[inst],'--midi',str(midi.resolve()),'--wav',str(wav.resolve()),'--samplerate',str(SR),'--quality','10'],stdout=log,stderr=log,check=True)
  data=read_audio(wav)
  # Balance by musical role: the tune leads, harmony and colour sit underneath.
  data*=10**((s['role_level'][p['role']]-active_rms_db(data))/20)
  if p['dynamics']:data=apply_dynamics(data,p['dynamics'])
  pan=PANS.get(inst,0);mid=data.mean(axis=1);side=(data[:,0]-data[:,-1])*.30
  part=np.column_stack((mid*math.sqrt((1-pan)/2)+side,mid*math.sqrt((1+pan)/2)-side)).astype(np.float32)
  count=min(n,len(part));dry[:count]+=part[:count];send[:count]+=part[:count]*(.35 if inst in ['piano','pizz','spiccato'] else .6)
  if s['loop'] and len(part)>n:
   tail=part[n:n+min(n,SR*3)];dry[:len(tail)]+=tail;send[:len(tail)]+=tail*.6
 for e in s['percussion']:
  sample=HITS[e['sample']];start=round(e['at']*SR);count=min(len(sample),n-start)
  if count>0:dry[start:start+count]+=sample[:count,None]*e['gain']*.15;send[start:start+count]+=sample[:count,None]*e['gain']*.06
 wet=np.zeros_like(dry)
 for channel in range(2):
  ir=hall_impulse(seed_of(cue)+channel);v=signal.fftconvolve(send[:,channel],ir).astype(np.float32);wet[:,channel]=v[:n]
  if s['loop']:wet[:min(n,len(v)-n),channel]+=v[n:n+n]
 mix=dry+wet
 mix=signal.sosfilt(signal.butter(2,35,fs=SR,btype='highpass',output='sos'),mix,axis=0).astype(np.float32)
 fade=int(.012*SR);mix[:fade]*=np.linspace(0,1,fade)[:,None];mix[-fade:]*=np.linspace(1,0,fade)[:,None]
 if not s['loop']:
  end=int(min(4,item['seconds']*.15)*SR);mix[-end:]*=np.linspace(1,0,end)[:,None]**1.4
 print('Mixed '+cue+' ('+str(len(s['parts']))+' sampled parts, revision 3)',flush=True)
 result=master_and_media(mix,item,s['description']);result['music_generation']=MUSIC_GENERATION;result['render_revision']=3
 (OUT/'logs'/(Path(item['file']).stem+'.json')).write_text(json.dumps(result,indent=2)+'\n');return result

def render_music(item):
 cue=item['id'];cached=OUT/'logs'/(Path(item['file']).stem+'.json')
 if cached.exists():
  previous=json.loads(cached.read_text())
  if previous.get('music_generation')==MUSIC_GENERATION:return previous
 if args.revision==3:return render_music_r3(item)
 s=score(item);n=round(item['seconds']*SR);dry=np.zeros((n,2),np.float32);send=np.zeros((n,2),np.float32)
 folder=OUT/'renders'/cue;folder.mkdir(exist_ok=True)
 for inst,events in s['stems'].items():
  midi=folder/(inst+'.mid');wav=folder/(inst+'.wav');write_phrased_midi(events,midi,s['bpm'],item['seconds']+3,inst,s['bar_seconds'],s['music_end'])
  with (folder/(inst+'.log')).open('w') as log:
   subprocess.run([str(RENDERER),'--sfz',INSTRUMENTS[inst],'--midi',str(midi.resolve()),'--wav',str(wav.resolve()),'--samplerate',str(SR),'--quality','10'],stdout=log,stderr=log,check=True)
  data=read_audio(wav);pan=PANS.get(inst,0);mid=data.mean(axis=1);side=(data[:,0]-data[:,-1])*.30
  part=np.column_stack((mid*math.sqrt((1-pan)/2)+side,mid*math.sqrt((1+pan)/2)-side)).astype(np.float32)
  count=min(n,len(part));dry[:count]+=part[:count];send[:count]+=part[:count]*(.35 if inst in ['piano','pizz','spiccato'] else .65)
  if s['loop'] and len(part)>n:
   tail=part[n:n+min(n,SR*3)];dry[:len(tail)]+=tail;send[:len(tail)]+=tail*.6
  # Keep editable MIDI/score; intermediate renders are reproducible and not in the review ZIP.
 for e in s['percussion']:
  sample=HITS[e['sample']];start=round(e['at']*SR);count=min(len(sample),n-start)
  if count>0:dry[start:start+count]+=sample[:count,None]*e['gain']*.15;send[start:start+count]+=sample[:count,None]*e['gain']*.06
 wet=np.zeros_like(dry)
 for channel in range(2):
  ir=hall_impulse(seed_of(cue)+channel);v=signal.fftconvolve(send[:,channel],ir).astype(np.float32);wet[:,channel]=v[:n]
  if s['loop']:wet[:min(n,len(v)-n),channel]+=v[n:n+n]
 mix=dry+wet
 mix=signal.sosfilt(signal.butter(2,35,fs=SR,btype='highpass',output='sos'),mix,axis=0).astype(np.float32)
 # A shaped instrumental development; endings receive a natural fade within their full duration.
 fade=int(.012*SR);mix[:fade]*=np.linspace(0,1,fade)[:,None];mix[-fade:]*=np.linspace(1,0,fade)[:,None]
 if not s['loop']:
  end=int(min(4,item['seconds']*.15)*SR);mix[-end:]*=np.linspace(1,0,end)[:,None]**1.4
 print('Mixed '+cue+' ('+str(len(s['stems']))+' sampled parts)',flush=True)
 result=master_and_media(mix,item,s['description']);result['music_generation']=MUSIC_GENERATION;result['render_revision']=2
 cached.write_text(json.dumps(result,indent=2)+'\n');return result

PIANO_CACHE={}
def piano_note(note,length):
 if note not in PIANO_CACHE:
  names=[('A',9),('C',0),('D#',3),('F#',6)];choices=[]
  for octave in range(2,7):
   for name,pc in names:
    key=12*(octave+1)+pc;p=LIB/'piano'/'Samples'/f'{name}{octave}v8.flac'
    if p.exists():choices.append((abs(key-note),key,p))
  _,key,path=min(choices);raw=read_audio(path,2).mean(axis=1);ratio=2**((note-key)/12)
  PIANO_CACHE[note]=signal.resample_poly(raw,10000,round(10000*ratio)).astype(np.float32)
 raw=PIANO_CACHE[note];out=np.zeros(round(length*SR),np.float32);out[:min(len(out),len(raw))]=raw[:len(out)];out/=max(.001,float(np.max(np.abs(out))));return out

def render_sfx(item):
 basename=Path(item['file']).stem;cue=item['id'];cached=OUT/'logs'/(basename+'.json')
 if cached.exists():return json.loads(cached.read_text())
 duration=item['seconds'];n=round(duration*SR);t=np.arange(n)/SR;x=np.zeros(n,np.float32);rng=np.random.default_rng(seed_of(basename));variant=int(basename[-1]) if basename[-1].isdigit() else 1
 def add(data,at=0,gain=1):
  start=round(at*SR);count=min(len(data),n-start)
  if count>0:x[start:start+count]+=data[:count]*gain
 def tone(note,at=0,length=None,gain=.5,glass=False):
  length=min(duration-at,length or duration-at);tt=np.arange(round(length*SR))/SR;f=440*2**((note-69)/12)
  if glass:y=np.sin(2*np.pi*f*tt+2.5*np.exp(-tt*18)*np.sin(2*np.pi*f*2.01*tt))*np.exp(-tt*7/max(.4,length*3))
  else:y=piano_note(note,length)*np.exp(-tt*5/max(.2,length*2))
  attack=min(len(tt),round(.0015*SR));y[:attack]*=np.linspace(0,1,attack);add(y.astype(np.float32),at,gain)
 def noise(length,cutoff,gain=.3,at=0,decay=10):
  count=round(length*SR);z=rng.normal(0,1,count);z=signal.sosfilt(signal.butter(3,cutoff,fs=SR,output='sos'),z);z/=max(.001,np.max(np.abs(z)));z*=np.exp(-np.arange(count)/SR*decay);add(z.astype(np.float32),at,gain)
 if cue=='ui_click':tone([74,78,81][variant-1],gain=.5);add(HITS['wood'][:n],gain=.035)
 elif cue=='ui_hover':tone(86,gain=.14)
 elif cue=='ui_confirm':tone(74,length=.13);tone(81,at=.075,gain=.6)
 elif cue=='ui_cancel':tone(78);tone(74,at=.055,gain=.25)
 elif cue=='ui_error':tone(50,length=.09,gain=.45);tone(50,at=.14,length=.10,gain=.37)
 elif cue in ['ui_toggle_on','ui_toggle_off']:
  a,b=(74,78) if cue.endswith('on') else (78,74);tone(a,length=.055,gain=.4);tone(b,at=.038,gain=.3);add(HITS['wood'][:n],gain=.02)
 elif cue in ['ui_panel_open','ui_panel_close']:
  z=signal.sosfilt(signal.butter(3,[450,3200],fs=SR,btype='bandpass',output='sos'),rng.normal(0,1,n));env=np.sin(np.pi*t/duration)**2
  x+=z.astype(np.float32)*env*.20;tone(86 if cue.endswith('open') else 81,at=.018,gain=.20)
 elif cue=='ui_tooltip_pin':tone(90,glass=True,gain=.35)
 elif cue=='ui_end_turn':tone(50,glass=True,gain=.6);tone(57,at=.065,glass=True,gain=.20);tone(62,at=.13,gain=.12)
 elif cue=='ui_alert':tone(81,glass=True);tone(86,at=.15,glass=True,gain=.5)
 elif cue=='ui_alert_critical':
  for at,note in [(0,74),(.20,69),(.42,74)]:tone(note,at,length=.22,glass=True,gain=.4)
 elif cue=='ui_event_open':
  for at,note in [(0,78),(.12,81),(.26,86)]:tone(note,at,gain=.40)
 elif cue=='ui_choice_made':
  for note,g in [(62,.4),(66,.25),(69,.18)]:tone(note,gain=g)
 elif cue=='ui_page_turn':
  noise(duration,1800+variant*350,gain=.28,decay=6);tone(86,at=.020,gain=.075)
 elif cue=='ui_research_done':
  for at,note in [(0,78),(.14,81),(.29,86)]:tone(note,at,glass=True,gain=.4)
 elif cue=='ui_build_done':add(HITS['wood'][:n],gain=.3);tone(74,at=.08,gain=.35);tone(81,at=.18,gain=.25)
 elif cue=='ui_place_district':add(HITS['wood'][:n],gain=.25);tone([62,66,69][variant-1],at=.008,gain=.35)
 elif cue=='ui_demolish':add(HITS['drum'][:n],gain=.35);noise(duration,650,gain=.3,decay=14)
 elif cue=='ui_pop_growth':tone(78,length=.18);tone(81,at=.09,gain=.35)
 elif cue=='ui_overflow_warn':
  freq=440*2**((74-69)/12)*np.linspace(.96,1.12,n);x+=np.sin(2*np.pi*np.cumsum(freq)/SR).astype(np.float32)*np.sin(np.pi*t/duration)**2*.3;tone(86,at=.12,gain=.2)
 elif cue=='ship_move_order':tone(81,length=.08,glass=True);tone(81,at=.12,length=.085,glass=True,gain=.4)
 elif cue=='ship_arrive':noise(duration,950,gain=.25,decay=10);tone(38,gain=.28)
 elif cue=='survey_ping':tone(86,glass=True,gain=.5);tone(86,at=.24,glass=True,gain=.15)
 elif cue=='beacon_activate':
  for at,note,g in [(0,38,.25),(.30,50,.30),(.65,57,.30),(.95,62,.35)]:tone(note,at,glass=True,gain=g)
  x*=np.minimum(1,t/.65).astype(np.float32)
 elif cue=='jump_transit':
  noise(duration,2400,gain=.25,decay=1);freq=55*np.exp(np.minimum(t,.55)*3.4);x+=np.sin(2*np.pi*np.cumsum(freq)/SR).astype(np.float32)*np.sin(np.pi*t/duration)**2*.4
  add(HITS['drum'],at=.48,gain=.20)
 elif cue=='noise_threshold':
  for at in [0,.42]:tone(26,at,length=.65,gain=.4)
 elif cue=='hit_kinetic':add(HITS['metal'],gain=.32+variant*.025);noise(duration,3600+variant*150,gain=.22,decay=28);tone(50+variant,glass=True,gain=.12)
 elif cue=='hit_thermal':noise(duration,3800,gain=.4,decay=18);tone(86+variant,glass=True,gain=.12)
 elif cue=='hit_explosive':add(HITS['drum'],gain=.40);noise(duration,600+variant*100,gain=.3,decay=14)
 elif cue=='shield_hit':tone([81,86,90][variant-1],glass=True,gain=.5);tone(74,at=.025,glass=True,gain=.20)
 elif cue=='pd_intercept':
  for at in [0,.035,.070]:add(HITS['wood'][:round(.025*SR)],at=at,gain=.35)
 elif cue=='ship_destroyed':add(HITS['drum'],gain=.5);add(HITS['metal'],at=.08,gain=.12);noise(duration,1200,gain=.3,decay=4)
 elif cue=='battle_won':
  for at,note in [(0,62),(.18,66),(.38,69)]:tone(note,at,gain=.4)
 elif cue=='battle_lost':tone(50,gain=.4);tone(47,at=.45,gain=.4)
 elif cue=='treaty_signed':
  for note,g in [(62,.35),(66,.23),(69,.18)]:tone(note,gain=g)
  add(HITS['wood'][:round(.08*SR)],at=.02,gain=.06)
 elif cue=='war_declared':add(HITS['drum'],gain=.45);tone(35,glass=True,gain=.3)
 elif cue=='vael_voice':
  for at,note,g in [(0,[78,81,86][variant-1],.25),(.12,90,.17),(.28,93,.10)]:tone(note,at,glass=True,gain=g)
  x*=np.minimum(1,t/.11).astype(np.float32)
 elif cue=='ambient_ui_room':
  # Circular spectral noise plus quiet ventilation harmonics: a seamless non-musical room bed.
  white=rng.normal(0,1,n);f=np.fft.rfftfreq(n,1/SR);spectrum=np.fft.rfft(white);spectrum*=1/np.maximum(1,f)**.7;spectrum[f>1500]=0
  x=np.fft.irfft(spectrum,n).astype(np.float32);x/=max(.001,np.max(np.abs(x)));x*=.06
  x+=.05*np.sin(2*np.pi*60*t)+.025*np.sin(2*np.pi*120*t)
 else:raise RuntimeError('Unmapped SFX '+cue)
 if cue!='ambient_ui_room':
  attack=min(n,round(.001*SR));release=min(n//4,round(.045*SR));x[:attack]*=np.linspace(0,1,attack);x[-release:]*=np.linspace(1,0,release)**1.5
  source=read_audio(SOURCE_ROOT/item['file']);old_rms=float(np.sqrt(np.mean(source*source)));rms=float(np.sqrt(np.mean(x*x)))
  x*=min(old_rms/max(rms,1e-8),.82/max(1e-8,float(np.max(np.abs(x)))))
 stereo=cue in ['survey_ping','beacon_activate','jump_transit','ship_destroyed','ambient_ui_room']
 if stereo:
  right=np.roll(x,round(.007*SR))*.87+x*.13
  if cue!='ambient_ui_room':right[:round(.007*SR)]=x[:round(.007*SR)]
  x=np.column_stack((x,right))
 notes='New '+('seamless ventilation/room bed' if cue=='ambient_ui_room' else 'recorded-piano/mallet and designed tactile rendition')+'; original cue role and variant retained.'
 return master_and_media(x,item,notes)

all_items=[x for x in INVENTORY if not args.only or x['id'] in args.only]
results=[];started=time.monotonic()
with ThreadPoolExecutor(max_workers=args.workers) as pool:
 jobs={pool.submit(render_music if item['kind']=='music' else render_sfx,item):item for item in all_items}
 for future in as_completed(jobs):
  item=jobs[future];result=future.result();results.append(result);print(f"Ready {len(results)}/{len(all_items)}: {result['slug']}",flush=True)
results.sort(key=lambda x:next(i for i,a in enumerate(INVENTORY) if a['file']==x['file']))
(OUT/'catalogue.json').write_text(json.dumps({'created':'2026-10-07','timezone':'Asia/Manila','cue_count':len(set(x['id'] for x in results)),'file_count':len(results),'items':results},indent=2)+'\n')
print(json.dumps({'files':len(results),'seconds':round(time.monotonic()-started,1),'out':str(OUT)}),flush=True)

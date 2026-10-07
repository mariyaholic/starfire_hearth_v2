"""Fetch pinned free sampled instruments and create documented SFZ performance maps."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import argparse,json,urllib.request,urllib.parse,re,time,hashlib
import numpy as np
import soundfile as sf
from scipy import signal
PINS={'vsco':('sgossner/VSCO-2-CE','440300901dfe9275fd84e0b7763af1f8443ae62e'),'piano':('sfzinstruments/SalamanderGrandPiano','3382bf9496bba2486f5ab0de55a264d1dfc38404')}
ROOTS={'violin':'Strings/Violin Section/susVib/','viola':'Strings/Viola Section/susvib/','cello':'Strings/Cello Section/susvib/','bass':'Strings/Solo Contrabass/SusVib/','pizz':'Strings/Violin Section/Pizz/','spiccato':'Strings/Violin Section/Spic/','horn':'Brass/F Horn/sus/','trumpet':'Brass/Trumpet/sus/','flute':'Woodwinds/Flute/susNV/','clarinet':'Woodwinds/Clarinet/susLong/','bassoon':'Woodwinds/Bassoon/sus/','harp':'Strings/Harp/','glock':'Percussion/Glock/','marimba':'Percussion/Marimba/'}
parser=argparse.ArgumentParser();parser.add_argument('--root',default='/workspace/.starfire-setup/audio-libraries');args=parser.parse_args();root=Path(args.root);root.mkdir(parents=True,exist_ok=True)
headers={'User-Agent':'Starfire-Hearth-audio-review/1.0'}
def fetch(url,path):
 if path.exists():return
 path.parent.mkdir(parents=True,exist_ok=True)
 for attempt in range(5):
  try:
   with urllib.request.urlopen(urllib.request.Request(url,headers=headers),timeout=60) as r:data=r.read()
   path.write_bytes(data);return
  except Exception:
   if attempt==4:raise
   time.sleep(1+attempt*2)
items=[]
for key,(repo,pin) in PINS.items():
 tree_path=root/(key+'_tree.json');fetch(f'https://api.github.com/repos/{repo}/git/trees/{pin}?recursive=1',tree_path)
 tree=json.loads(tree_path.read_text())['tree']
 for x in tree:
  if x['type']!='blob':continue
  name=x['path']
  selected=key=='piano' or any(name.startswith(v) for v in ROOTS.values()) or (name.startswith('Percussion/') and '/' not in name[len('Percussion/'):]) or name.startswith('Percussion/Timpani/') or name.lower().startswith('license')
  if selected:items.append((key,name,x.get('size',0)))
print(f'Downloading {len(items)} instrument files, {sum(x[2] for x in items)/1e6:.0f} MB',flush=True)
def download(item):
 key,name,_=item;repo,pin=PINS[key];path=root/key/name;fetch(f'https://raw.githubusercontent.com/{repo}/{pin}/'+urllib.parse.quote(name),path);return key,name
with ThreadPoolExecutor(max_workers=12) as pool:
 jobs=[pool.submit(download,item) for item in items]
 for n,f in enumerate(as_completed(jobs),1):
  f.result()
  if n%100==0 or n==len(jobs):print(f'Downloaded {n}/{len(jobs)}',flush=True)
NOTE={'C':0,'D':2,'E':4,'F':5,'G':7,'A':9,'B':11}
def key_number(name):
 m=re.search(r'(?:_|^)([A-G])(#?)(-?\d)(?:_|\.)',name)
 if not m:raise ValueError(name)
 return 12*(int(m[3])+2)+NOTE[m[1]]+bool(m[2])
def velocity(name):
 m=re.search(r'_v(\d+)(?:_|\.)',name)
 if m:return int(m[1])
 return 1
maps={};sources=[]
for instrument,prefix in ROOTS.items():
 paths=sorted((root/'vsco'/prefix).glob('*.wav'))
 if not paths:
  print('No source for optional instrument '+instrument,flush=True);continue
 groups={}
 for p in paths:groups.setdefault((key_number(p.name),velocity(p.name)),[]).append(p)
 notes=sorted(set(k[0] for k in groups));vels=sorted(set(k[1] for k in groups))
 sustained=instrument in ['violin','viola','cello','bass','horn','trumpet','flute','clarinet','bassoon']
 release=.20 if instrument=='horn' else .16 if instrument in ['violin','viola','cello','bass'] else .12 if sustained else 2.4 if instrument=='harp' else 1.8 if instrument in ['glock','marimba'] else .20
 lines=['// VSCO 2 CE, CC0. Concert pitch: source C3 is MIDI 60.','// Prepared looping sustains and velocity/round-robin mapping by Starfire Hearth.','<control> hint_ram_based=1','<global> ampeg_attack='+('0.025' if sustained else '0.001')+f' ampeg_sustain=100 ampeg_release={release} amp_veltrack=65']
 for (note,vel),samples in groups.items():
  ni=notes.index(note);note_vels=sorted(v for n,v in groups if n==note);vi=note_vels.index(vel)
  lo=(notes[ni-1]+note)//2+1 if ni else max(0,note-3);hi=(note+notes[ni+1])//2 if ni+1<len(notes) else min(127,note+3)
  vlo=int(128*vi/len(note_vels));vhi=int(128*(vi+1)/len(note_vels))-1
  lines.append(f'<group> pitch_keycenter={note} lokey={lo} hikey={hi} lovel={vlo} hivel={vhi} seq_length={len(samples)}')
  for index,p in enumerate(samples,1):
   relative=p.relative_to(root/'vsco');dest=root/'prepared'/instrument/p.name;dest.parent.mkdir(parents=True,exist_ok=True)
   data,rate=sf.read(p,dtype='float32',always_2d=True);loop=''
   if sustained and len(data)>rate*.8:
    end=min(len(data)-int(rate*.15),int(rate*3.4));start=min(int(rate*.65),end//3);cross=min(int(rate*.12),(end-start)//4)
    w=np.linspace(0,1,cross,dtype=np.float32)[:,None]
    data[end-cross:end]=data[end-cross:end]*(1-w)+data[start:start+cross]*w
    loop=f' loop_mode=loop_continuous loop_start={start+cross} loop_end={end-1}'
   sf.write(dest,data,rate,subtype='PCM_24')
   lines.append(f'<region> seq_position={index} sample={dest.as_posix()}{loop}')
   sources.append({'library':'VSCO 2 CE','path':str(relative),'sha256':hashlib.file_digest(p.open('rb'),'sha256').hexdigest()})
 path=root/'maps'/(instrument+'.sfz');path.parent.mkdir(exist_ok=True);path.write_text('\n'.join(lines)+'\n');maps[instrument]=str(path)
 print(f'Mapped {instrument}: {len(paths)} samples, MIDI {min(notes)}–{max(notes)}',flush=True)
offline_piano=root/'piano'/'Salamander Offline.sfz'
offline_piano.write_text('// Offline full-RAM rendering; upstream instrument remains unchanged.\n<control> hint_ram_based=1\n#include "Salamander Grand Piano V3.sfz"\n')
maps['piano']=str(offline_piano)
# Recorded percussion is mixed directly; retain its provenance as well.
for p in sorted((root/'vsco'/'Percussion').rglob('*.wav')):
 sources.append({'library':'VSCO 2 CE','path':str(p.relative_to(root/'vsco')),'sha256':hashlib.file_digest(p.open('rb'),'sha256').hexdigest()})
(root/'instruments.json').write_text(json.dumps(maps,indent=2)+'\n')
(root/'provenance.json').write_text(json.dumps({'pins':PINS,'licenses':{'vsco':'CC0-1.0','piano':'CC-BY-3.0, Alexander Holm'},'modifications':'Sustain crossfade loops, mapped concert pitch and velocity/round-robin ranges.','samples':sources},indent=2)+'\n')
print('Instrument bank ready',flush=True)

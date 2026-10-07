"""Check dry rendered transitions and MIDI key lifetimes, not reverb masking."""
from pathlib import Path
from collections import defaultdict
import argparse,json,re
import numpy as np,soundfile as sf
from mido import MidiFile
from phrasing import SUSTAINED,HELD_ROLES
p=argparse.ArgumentParser();p.add_argument('--out',default='reports/audio_rework_phrasing');p.add_argument('--previous',default='reports/audio_rework');args=p.parse_args();root=Path(args.out);previous=Path(args.previous);checks=[];results=[]
def check(label,value):checks.append({'check':label,'pass':bool(value)})
def frame_rms(x,sr):
 size=round(.010*sr);x=x[:len(x)//size*size];return np.sqrt(np.mean(x.reshape(-1,size)**2,axis=1))
lib=Path('/workspace/.starfire-setup/audio-libraries');maps=json.loads((lib/'instruments.json').read_text());regions={};coverage=[]
for inst,path in maps.items():
 if inst=='piano':continue
 groups=[tuple(map(int,m)) for m in re.findall(r'lokey=(\d+) hikey=(\d+) lovel=(\d+) hivel=(\d+)',Path(path).read_text())];regions[inst]=groups
 holes=[(n,v) for n in range(min(g[0] for g in groups),max(g[1] for g in groups)+1) for v in range(1,128) if not any(lo<=n<=hi and vl<=v<=vh for lo,hi,vl,vh in groups)]
 coverage.append({'instrument':inst,'uncovered_note_velocity_pairs':len(holes)});check(inst+' map covers every pitch/velocity in its declared range',not holes)
for path in sorted((root/'scores').glob('*.json')):
 score=json.loads(path.read_text());cue=score['id'];row={'cue':cue,'tied_notes':sum(e.get('ties',0) for notes in score['stems'].values() for e in notes),'held_transitions':0,'midi_early_note_offs':0,'piano_pedal':True,'transition_gaps':[],'held_note_dropouts':[]}
 check(cue+' has phrasing revision 2',score.get('phrasing',{}).get('revision')==2)
 for inst,notes in score['stems'].items():
  if inst!='piano':check(cue+' '+inst+' every scored note selects a sample region',all(any(lo<=e['note']<=hi and vl<=e['velocity']<=vh for lo,hi,vl,vh in regions[inst]) for e in notes))
  # Inspect the actual rendered MIDI: no earlier off may terminate a still-held pitch.
  midi=MidiFile(root/'renders'/cue/(inst+'.mid'));tick=0;offs=[];pedals=[]
  for event in midi.tracks[0]:
   tick+=event.time
   if event.type=='note_off' or (event.type=='note_on' and event.velocity==0):offs.append((tick,event.note))
   if event.type=='control_change' and event.control==64:pedals.append((tick,event.value))
  scale=score['bpm']/60*midi.ticks_per_beat
  for tick,note in offs:
   if any(e['note']==note and round(e['at']*scale)<tick and round((e['at']+e['duration'])*scale)>tick for e in notes):row['midi_early_note_offs']+=1
  if inst=='piano':row['piano_pedal']=bool(pedals and any(v>=64 for _,v in pedals) and any(v==0 for _,v in pedals))
  if inst not in SUSTAINED:continue
  x,sr=sf.read(root/'renders'/cue/(inst+'.wav'),dtype='float32',always_2d=True);rms=frame_rms(x.mean(axis=1),sr)
  for e in notes:
   if e['role'] not in HELD_ROLES or e['duration']<1.3:continue
   window=rms[round((e['at']+1.0)/.01):round((e['at']+e['duration']-.15)/.01)]
   if not len(window):continue
   baseline=float(np.percentile(window,75));longest=current=0
   for value in window<max(2/32768,baseline*.01):current=current+1 if value else 0;longest=max(longest,current)
   if longest>=10:row['held_note_dropouts'].append({'instrument':inst,'note':e['note'],'at':e['at'],'quiet_ms':longest*10})
  groups=defaultdict(list)
  for e in notes:
   if e['role'] in HELD_ROLES:groups[(e['role'],e.get('voice',e['role']))].append(e)
  for (role,voice),line in groups.items():
   line.sort(key=lambda e:e['at'])
   for e,nxt in zip(line,line[1:]):
    # Only intended held transitions, rather than orchestration rests or breaths.
    if e['at']+e['duration']<nxt['at']-.001:continue
    row['held_transitions']+=1;at=nxt['at'];start=max(0,round((at-.10)/.01));end=min(len(rms),round((at+.20)/.01));window=rms[start:end]
    if not len(window):continue
    reference=rms[max(0,start-20):min(len(rms),end+20)];baseline=float(np.percentile(reference,75))
    # The dry part must not contain a >40 ms near-silent hole at its held transition.
    # sfizz's 16-bit intermediate stems have a one-LSB dither/noise floor.
    low=window<max(2/32768,baseline*.01);longest=current=0
    for value in low:current=current+1 if value else 0;longest=max(longest,current)
    if longest>=5:row['transition_gaps'].append({'instrument':inst,'role':role,'at':at,'quiet_ms':longest*10,'baseline':baseline})
 check(cue+' MIDI never releases a pitch still required by another voice',row['midi_early_note_offs']==0)
 check(cue+' piano has both pedal sustain and harmonic pedal lifts',row['piano_pedal'])
 check(cue+' held dry transitions contain no >=50 ms near-silent holes',not row['transition_gaps'])
 check(cue+' long held dry notes contain no >=100 ms near-silent dropouts after their attack',not row['held_note_dropouts'])
 check(cue+' contains no bright glockenspiel part','glock' not in score['stems'])
 results.append(row)
# Reproduce a long exposed lead gap in the previous arrangement without a hall.
comparisons=[]
for cue,inst,start,end in [('mood_sorrow','piano',3.0,4.8),('mus_title','piano',.8,1.4),('theme_sola','clarinet',1.35,1.6),('mus_title','horn',39.0,40.1)]:
 a=previous/'renders'/cue/(inst+'.wav');b=root/'renders'/cue/(inst+'.wav')
 if not a.exists() or not b.exists():continue
 record={'cue':cue,'instrument':inst,'seconds':[start,end]}
 for label,path in [('previous',a),('revised',b)]:
  x,sr=sf.read(path,dtype='float32',always_2d=True);rms=frame_rms(x.mean(axis=1),sr);region=rms[round(start/.01):round(end/.01)];record[label+'_rms_dbfs']=float(20*np.log10(max(1e-9,np.sqrt(np.mean(region**2)))))
 comparisons.append(record)
summary={'passed':all(c['pass'] for c in checks),'checks':checks,'music_cues':len(results),'sample_maps':coverage,'held_transitions':sum(r['held_transitions'] for r in results),'early_note_offs':sum(r['midi_early_note_offs'] for r in results),'dry_gap_findings':[{'cue':r['cue'],**g} for r in results for g in r['transition_gaps']],'held_note_dropouts':[{'cue':r['cue'],**g} for r in results for g in r['held_note_dropouts']],'comparisons':comparisons,'items':results,'limitation':'Dry-signal silence, MIDI lifetimes and pedal checks establish technical continuity. Recorded interval legato was not available; this uses timed overlapping sampled sustains. Musical phrasing still requires listening review.'}
(root/'phrasing_verification.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps({k:v for k,v in summary.items() if k not in ['items','checks']},indent=2));raise SystemExit(0 if summary['passed'] else 1)

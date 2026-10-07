"""Revision 3 composer: harmony-led melody, voice-led orchestration and phrase dynamics.

Revision 2 kept the revision 1 score, which cycled a fixed eight-note motif with no
reference to the chord underneath it. About one melody note in five sat a semitone
against the harmony, a three-minute cue held only two distinct phrases, and an
off-beat marimba ticked through most cues. This module writes the score again:

- Harmony comes first: functional progressions in eight-bar phrases (antecedent to
  a half cadence, consequent to a full cadence), arranged as A A B A sections.
- The melody keeps each cue's motif contour (as scale steps) but every long or
  strong-beat note is a chord tone; short notes off the chord move by step.
- String harmony is voice-led (smallest movement, common tones held) rather than
  parallel blocks, and accompaniment patterns suit each cue's character.
- Orchestration and dynamics grow across sections and breathe within phrases.
- Mallets are kept to the one playful cue; percussion marks arrivals only.

Each part is rendered separately so the mix can balance roles, not instruments.
"""
import math
import numpy as np

MAJOR=[0,2,4,5,7,9,11];MINOR=[0,2,3,5,7,8,10]
LEAD_IN=.3
TONIC={'D':2,'G':7,'B':11,'F':5}
# Character themes need their own sound, not the title's key, chords and rhythm.
STYLE_KEY={'scholar':'F'}
STYLE_PROGRESSIONS={'scholar':{'ant':[0,3,1,4],'con':[5,1,4,0],'b1':[3,4,2,5],'b2':[3,1,4,4],'turn':[0,3,1,4,0,3,1,4]}}
# Eight-bar phrases as two four-bar halves of scale-degree roots (0 = tonic).
PROGRESSIONS={
 'major':{'ant':[0,5,3,4],'con':[0,3,4,0],'b1':[5,3,0,4],'b2':[5,3,1,4],'turn':[0,5,3,1,0,3,1,4]},
 'minor':{'ant':[0,5,3,4],'con':[0,3,4,0],'b1':[2,6,0,5],'b2':[2,6,3,4],'turn':[0,5,3,4,0,3,5,4]}}
# Melody register and natural lead roles.
LEAD_RANGE={'piano':(62,86),'violin':(64,88),'flute':(69,93),'clarinet':(55,79),'horn':(53,72),'cello':(48,69),'harp':(60,84),'bassoon':(46,67),'viola':(55,76)}
SUSTAINED={'violin','viola','cello','bass','horn','trumpet','flute','clarinet','bassoon'}
FAMILY={
 'grand':'lyrical','domestic':'lyrical','pastoral':'lyrical','wonder':'lyrical','dark':'lyrical','lonely':'lyrical',
 'earnest':'lyrical','warm':'lyrical','hope':'lyrical','relay':'lyrical','shield':'lyrical','homecoming':'lyrical',
 'victory':'lyrical','trade':'playful','scholar':'playful','playful':'playful','wry':'playful',
 'battle':'driving','march':'driving','tension':'driving',
 'sorrow':'sparse','mystery':'sparse','hide':'sparse','defeat':'sparse','vast':'still','alien':'still','answer':'still',
 'waltz':'waltz'}
# Two-bar cells: (onset beat, length in beats) and scale-step offsets from the cell's anchor.
# 'M' is filled from each cue's own motif contour; the others answer, contrast and cadence.
CELLS={
 'lyrical':{'M':[(0,1.5),(1.5,.5),(2,2),(4,1),(5,1),(6,2)],
            'ans':([(0,1),(1,1),(2,1),(3,1),(4,4)],[2,1,0,-1,-2]),
            'cad':([(0,1.5),(1.5,.5),(2,1),(3,1),(4,4)],[2,1,0,-1,0]),
            'con':([(0,3),(3,1),(4,2),(6,2)],[4,3,2,1]),
            'back':([(0,2),(2,1),(3,1),(4,4)],[3,2,1,1])},
 'sparse':{'M':[(0,3),(3,1),(4,4)],
           'ans':([(0,2),(2,2),(4,4)],[2,1,1]),
           'cad':([(0,3),(3,1),(4,4)],[1,-1,0]),
           'con':([(0,4),(4,2),(6,2)],[4,3,2]),
           'back':([(0,2),(2,2),(4,4)],[2,1,1])},
 'still':{'M':[(0,4),(4,4)],
          'ans':([(0,4),(4,4)],[2,1]),
          'cad':([(0,4),(4,4)],[1,0]),
          'con':([(0,6),(6,2)],[4,3]),
          'back':([(0,4),(4,4)],[2,1])},
 'playful':{'M':[(0,.5),(.5,.5),(1,1),(2,.5),(2.5,.5),(3,1),(4,1),(5,1),(6,2)],
            'ans':([(0,.5),(.5,.5),(1,.5),(1.5,.5),(2,1),(3,1),(4,4)],[4,3,2,1,0,-1,-2]),
            'cad':([(0,1),(1,.5),(1.5,.5),(2,1),(3,1),(4,4)],[2,3,2,1,-1,0]),
            'con':([(0,1.5),(1.5,.5),(2,2),(4,1.5),(5.5,.5),(6,2)],[4,3,2,3,2,1]),
            'back':([(0,1),(1,1),(2,.5),(2.5,.5),(3,1),(4,4)],[3,2,1,0,1,1])},
 'driving':{'M':[(0,.75),(.75,.25),(1,1),(2,.75),(2.75,.25),(3,1),(4,1),(5,1),(6,2)],
            'ans':([(0,.75),(.75,.25),(1,1),(2,1),(3,1),(4,4)],[4,3,2,1,0,-1]),
            'cad':([(0,1),(1,1),(2,1),(3,1),(4,4)],[2,1,-1,1,0]),
            'con':([(0,2),(2,1),(3,1),(4,2),(6,2)],[4,3,4,5,4]),
            'back':([(0,1),(1,1),(2,1),(3,1),(4,4)],[3,2,1,0,1])},
 'waltz':{'M':[(0,2),(2,1),(3,1),(4,1),(5,1)],
          'ans':([(0,1),(1,1),(2,1),(3,3)],[4,3,2,1]),
          'cad':([(0,2),(2,1),(3,3)],[2,1,0]),
          'con':([(0,3),(3,2),(5,1)],[4,3,2]),
          'back':([(0,2),(2,1),(3,3)],[2,1,1])}}
# Sola's scholar theme: a dotted, inquisitive lilt instead of the shared playful rhythm.
STYLE_CELLS={'scholar':{'M':[(0,.75),(.75,.25),(1,1),(2,.75),(2.75,.25),(3,1),(4,1.5),(5.5,.5),(6,2)],
 'con':([(0,.5),(.5,.5),(1,1),(2,2),(4,.5),(4.5,.5),(5,1),(6,2)],[2,3,4,2,1,2,3,1])}}
# Accompaniment texture by cue character.
ACCOMPANIMENT={'lyrical':'piano_flow','sparse':'piano_sparse','still':'none','playful':'pizz','driving':'spiccato','waltz':'waltz'}
HARP_STYLES={'wonder','trade','wry'}
HORN_STYLES={'grand','hope','homecoming','shield','lonely','victory','relay','march','battle'}
PERCUSSION_STYLES={'grand','homecoming','victory','battle','march','shield','relay'}
# Role loudness in the mix (RMS of the active part, dBFS before mastering).
ROLE_LEVEL={'lead':-17,'counter':-24,'answer':-23,'acc':-23,'pad':-23,'bass':-25,'brass':-27,'ostinato':-25,'colour':-30}

def _scale(mode):return MAJOR if mode=='major' else MINOR

class Harmony:
 def __init__(self,key):
  self.tonic=TONIC[key];self.mode='minor' if key=='B' else 'major';self.scale=_scale(self.mode)
 def chord(self,degree):
  pcs=[(self.tonic+self.scale[(degree+k)%7])%12 for k in (0,2,4)]
  if self.mode=='minor' and degree==4:pcs[1]=(pcs[1]+1)%12  # raised leading tone in V
  return pcs
 def melody_scale(self,degree):
  pcs=[(self.tonic+s)%12 for s in self.scale]
  if self.mode=='minor' and degree==4:pcs[6]=(pcs[6]+1)%12
  return pcs

def scale_notes(pcs,lo=24,hi=108):return [n for n in range(lo,hi) if n%12 in pcs]
def nearest(n,candidates):return min(candidates,key=lambda c:(abs(c-n),c))

def motif_offsets(motif,harmony):
 """A cue's original motif as scale-step offsets from its first note."""
 notes=scale_notes(harmony.melody_scale(0))
 def idx(n):return notes.index(nearest(n,notes))
 first=idx(motif[0]);return [idx(n)-first for n in motif]

def plan_form(bars,ending,progressions):
 """Sections of (label, chord degrees per bar)."""
 p=progressions;sections=[]
 if bars<=8:
  base=[0,5,3,4,0,3,4,0];chords=(base[:max(0,bars-2)]+[4,0])[-bars:] if ending else (base[:bars-1]+[4])
  return [('A',chords)]
 intro=2 if bars>=16 else 0
 if intro:sections.append(('intro',[0,0] if bars<24 else [0,5]))
 order=['A','A','B','A','B','A','A','B']
 remaining=bars-intro;k=0
 while remaining>=8:
  label=order[k%len(order)];chords=p['ant']+p['con'] if label=='A' else p['b1']+p['b2']
  sections.append((label,chords));remaining-=8;k+=1
 if remaining:
  turn=p['turn'][8-remaining:]
  if ending:turn=turn[:-1]+[0]
  sections.append(('turn',turn))
 return sections

def score_r3(cue,preset,duration,motif,fit,rng):
 key,bars,meter,lead,style,description=preset;ending=cue.startswith('sting_');key=STYLE_KEY.get(style,key)
 family=FAMILY.get(style,'lyrical');harmony=Harmony(key);progressions=STYLE_PROGRESSIONS.get(style,PROGRESSIONS[harmony.mode])
 # A short breath before the first note: an attack on the file's first sample is clipped by
 # MP3 decoders and players and sounds like a cut.
 lead_in=LEAD_IN
 tail=min(4,duration*.16) if ending else 0;beat=(duration-tail-lead_in)/(bars*meter);bar_s=beat*meter;bpm=60/beat
 sections=plan_form(bars,ending,progressions)
 chords=[];labels=[];levels=[];count={}
 # Section dynamics: quiet first statement, fuller returns, a lift in the contrast.
 quiet=family in ('sparse','still') or style in ('dark','lonely','hide','defeat')
 for label,degrees in sections:
  count[label]=count.get(label,0)+1;n=count[label]
  if label=='intro':level=.45
  elif label=='A':level=[.6,.78,.95,1.0][min(n-1,3)]
  elif label=='B':level=.85 if n==1 else .92
  else:level=.7 if not ending else .9
  if quiet:level=.35+.55*level
  if style in ('battle','victory','march'):level=max(level,.8)
  if style in ('hide','defeat'):level*=.8
  for i,d in enumerate(degrees):chords.append(d);labels.append((label,n,i));levels.append(level)
 bars=len(chords)
 parts={}
 def part(name,instrument,role):
  if name not in parts:parts[name]={'instrument':instrument,'role':role,'events':[]}
  return parts[name]['events']
 def human(t,amount=.006):return max(0.0,t+float(rng.uniform(-amount,amount)))
 # Stay inside the soft and middle sample layers (the top layer switches above 84);
 # the gain curves carry the crescendo, so loudness never jumps between recordings.
 def vel(level,shape=0.):return int(np.clip(36+40*level+.7*shape,24,84))
 def add(events,at,length,note,velocity,voice='1'):
  events.append({'at':round(float(at),4),'duration':round(max(.06,float(length)),4),'note':int(note),'velocity':int(velocity),'voice':voice})

 # ---- Melody -------------------------------------------------------------
 cells=dict(CELLS[family],**STYLE_CELLS.get(style,{}));m_rhythm=cells['M'];offsets=motif_offsets(motif,harmony)
 m_offsets=[offsets[i%len(offsets)] for i in range(len(m_rhythm))]
 lo,hi=LEAD_RANGE.get(lead,(60,84));center=(lo+hi)//2
 # Sorrowful and still cues sing lower in the instrument, where it is warmer.
 if family in ('sparse','still'):lo,hi,center=lo-3,hi-6,center-5
 strong=(0,2) if meter==4 else (0,)
 melody=[];prev=center
 def realise(cell_rhythm,cell_offsets,bar0,last_kind,register):
  nonlocal prev
  degree=chords[bar0];target=int(.55*register+.45*prev)
  anchor=nearest(target,[n for n in scale_notes(harmony.chord(degree),lo,hi+1)] or [target])
  notes_scale=scale_notes(harmony.melody_scale(degree),lo-7,hi+8);ai=notes_scale.index(nearest(anchor,notes_scale))
  out=[];last=prev;last_off=None
  for (onset,length),off in zip(cell_rhythm,cell_offsets):
   bar=bar0+int(onset//meter)
   if bar>=bars:break
   d=chords[bar];ms=scale_notes(harmony.melody_scale(d),lo-7,hi+8);n=nearest(notes_scale[max(0,min(len(notes_scale)-1,ai+off))],ms)
   chord_tones=scale_notes(harmony.chord(d),lo-2,hi+3)
   on_strong=(onset%meter) in strong
   # Strong beats and long notes are chord tones; weak-beat notes may pass by step.
   if on_strong or length>=2:
    # Snap to a chord tone without flattening the contour: keep the motif's direction
    # and only repeat a pitch where the motif itself repeats one.
    wanted=0 if last_off is None else (off>last_off)-(off<last_off)
    options=[c for c in chord_tones if wanted==0 or (c-last)*wanted>0] or chord_tones
    if wanted!=0:options=[c for c in options if c!=last] or options
    # Prefer the intended pitch, but avoid zig-zag leaps wider than a fourth.
    n=min(options,key=lambda c:(abs(c-n)+.6*max(0,abs(c-last)-5),c))
   out.append([bar*bar_s+(onset%meter)*beat,length*beat,n,d,on_strong]);last=n;last_off=off
  # A pitch struck three times running sounds stuck: the middle weak note becomes an upper neighbour.
  for i in range(1,len(out)-1):
   if out[i-1][2]==out[i][2]==out[i+1][2] and not out[i][4]:
    ms=scale_notes(harmony.melody_scale(out[i][3]),lo-7,hi+8);out[i][2]=next((x for x in ms if x>out[i][2]),out[i][2])
  # Short off-chord notes must be approached or left by step.
  for i,e in enumerate(out):
   ct={x%12 for x in harmony.chord(e[3])}
   if e[2]%12 in ct:continue
   before=out[i-1][2] if i else prev;after=out[i+1][2] if i+1<len(out) else e[2]
   if abs(e[2]-before)>2 and abs(after-e[2])>2:e[2]=nearest(e[2],scale_notes(harmony.chord(e[3]),lo-2,hi+3))
  if out:
   # Cadence notes land on the root (full close) or root/third (half close), reached
   # from the note before rather than by a wide leap.
   final=out[-1];fc=harmony.chord(final[3]);ref=out[-2][2] if len(out)>1 else final[2]
   if last_kind=='cad':final[2]=nearest(ref,[n for n in range(lo-2,hi+3) if n%12==fc[0]] or [final[2]])
   elif last_kind in ('ans','back'):final[2]=nearest(ref,[n for n in range(lo-2,hi+3) if n%12 in fc[:2]] or [final[2]])
   prev=out[-1][2]
  return out
 bar=0
 for label,degrees in sections:
  if label=='intro':bar+=len(degrees);continue
  n_bars=len(degrees)
  if label=='A':plan=[('M',0),('ans',0),('M',0),('cad',0)]
  elif label=='B':plan=[('con',4),('con',2),('con',4),('back',2)]
  else:plan=[('M',0),('back',0),('M',0),('cad' if ending else 'back',0)]
  if n_bars<8 and label!='turn':plan=[('M',0),('cad' if ending else 'back',0)] if n_bars>2 else [('cad' if ending else 'back',0)]
  cells_needed=math.ceil(n_bars/2)
  if label=='turn':plan=([('M',0),('back',0),('M',0)][:max(0,cells_needed-1)])+[('cad' if ending else 'back',0)]
  for c,(kind,lift) in enumerate(plan[:cells_needed]):
   b0=bar+2*c
   if b0>=bar+n_bars:break
   rhythm,offs=(m_rhythm,m_offsets) if kind=='M' else cells[kind]
   # Second statement of the motif within a phrase is a step higher (sequence).
   if kind=='M' and c==2:offs=[o+1 for o in offs]
   if n_bars-2*c==1:rhythm=[(o,min(l,meter)) for o,l in rhythm if o<meter];offs=offs[:len(rhythm)]
   melody.extend(realise(rhythm,offs,b0,kind,center+lift))
  bar+=n_bars
 # Lead instrument changes for contrast; returning A sections double the line.
 lead_events=part('lead',lead,'lead')
 alt={'piano':'violin','clarinet':'flute','flute':'clarinet','horn':'violin','cello':'violin','violin':'flute','harp':'clarinet'}.get(lead,'violin')
 if style=='relay':alt='flute'
 alt_events=None
 for i,(at,length,n,d,on_strong) in enumerate(melody):
  label,occurrence,_=labels[min(bars-1,int(at/bar_s))]
  nxt=melody[i+1][0] if i+1<len(melody) else at+length
  breath=i+1<len(melody) and int(nxt/bar_s)%4==0 and int(nxt/bar_s)!=int(at/bar_s)
  short=length<beat*.99
  # Without recorded legato, overlapping quick notes smear into double attacks, so quick
  # notes are lightly detached and only notes of a beat or longer are joined.
  if lead in SUSTAINED:dur=min(length*.85,nxt-at-.03) if short else (nxt-at)-(.07 if breath else -.09)
  elif lead=='piano':dur=max(length,nxt-at-.01)
  else:dur=max(length,min(2.0,nxt-at+.3))
  if i+1==len(melody):dur=length
  pos=(at%(4*bar_s))/(4*bar_s);shape=10*math.sin(math.pi*pos)+.5*(n-center)+(4 if on_strong else 0)
  level=levels[min(bars-1,int(at/bar_s))]
  target_inst=lead
  if label=='B' and family not in ('sparse','still') and style not in ('earnest','wry'):target_inst=alt
  if style=='relay':target_inst=['clarinet','flute','piano','horn'][(int(at/bar_s)//4)%4]
  inst_dur=dur if target_inst==lead else ((min(length*.85,nxt-at-.03) if short else (nxt-at)-(.07 if breath else -.09)) if target_inst in SUSTAINED else max(length,nxt-at-.01))
  if i+1==len(melody):inst_dur=length
  events=lead_events if target_inst==lead else part('lead_'+target_inst,target_inst,'lead')
  note=fit(n,target_inst)
  add(events,human(at,.004),inst_dur,note,vel(level,shape))
  # Fuller returns: violins double the tune an octave up (or in unison for high leads).
  if label=='A' and occurrence>=3 and family not in ('sparse','still') and target_inst!='violin':
   add(part('double','violin','lead'),human(at,.006),(nxt-at)+.09 if i+1<len(melody) else length,fit(n+12 if n<70 else n,'violin'),vel(level,shape-12))

 # ---- Harmony: voice-led strings ------------------------------------------
 def voicings(pcs,lo_,hi_,count_):
  pool=[n for n in range(lo_,hi_+1) if n%12 in pcs];out=[]
  def rec(start,chosen):
   if len(chosen)==count_:
    if {c%12 for c in chosen}>={pcs[0],pcs[1]} :out.append(tuple(chosen))
    return
   for j in range(start,len(pool)):
    if chosen and (pool[j]-chosen[-1]<3 or pool[j]-chosen[-1]>9):continue
    rec(j+1,chosen+[pool[j]])
  rec(0,[]);return out
 prev_v=None;prev_bass=None;pad_voices=[];bass_line=[]
 for b,d in enumerate(chords):
  pcs=harmony.chord(d);cands=voicings(pcs,55,79,3)
  if prev_v is None:v=min(cands,key=lambda c:abs(sum(c)/3-66))
  else:v=min(cands,key=lambda c:sum(abs(x-y) for x,y in zip(c,prev_v))+.3*abs(sum(c)/3-66))
  root=pcs[0];bass=nearest(prev_bass if prev_bass else 45,[n for n in range(38,51) if n%12==root])
  pad_voices.append(v);bass_line.append(bass);prev_v=v;prev_bass=bass
 def held(events,notes_per_bar,voice_names,level_scale=1.,start_bar=0,gate=None):
  """Hold each voice through its bar, tying common tones across bars."""
  for vi,name in enumerate(voice_names):
   current=None
   for b in range(start_bar,bars):
    if gate and not gate(b):
     if current:add(events,*current,voice=name);current=None
     continue
    n=notes_per_bar[b][vi];v=vel(levels[b]*level_scale)
    if current and current[2]==n:current[1]=(b+1)*bar_s-current[0]+.12
    else:
     if current:current[1]+=.14;add(events,*current,voice=name)
     current=[human(b*bar_s+.02),bar_s+.12,n,v]
   if current:
    if not ending:current[1]+=.3
    add(events,*current,voice=name)
 intro_bars=len(sections[0][1]) if sections[0][0]=='intro' else 0
 strings_from=0 if (family in ('lyrical','waltz','still') and not quiet) or style in ('earnest','alien','shield','tension') else intro_bars
 def label_at(b):return labels[b]
 # Cellos and basses carry the floor; violas and violins enter as the cue opens out.
 if family not in ('playful',):
  held(part('pad_low','cello','pad'),[(bass_line[b]+12,) for b in range(bars)],['cello'],.9,gate=lambda b:b>=strings_from)
  held(part('bass','bass','bass'),[(bass_line[b],) for b in range(bars)],['bass'],.85,gate=lambda b:b>=strings_from and not (quiet and label_at(b)[0]=='A' and label_at(b)[1]==1))
  def upper(b):
   l,o,_=label_at(b)
   if l=='intro':return family=='still'
   if quiet:return not (l=='A' and o==1)
   return not (l=='A' and o==1 and b<intro_bars+4)
  held(part('pad_mid','viola','pad'),[(pad_voices[b][0],) for b in range(bars)],['viola'],.85,gate=upper)
  held(part('pad_high','violin','pad'),[pad_voices[b][1:] for b in range(bars)],['violin 2','violin 1'],.8,gate=upper)
 else:
  held(part('pad_low','cello','pad'),[(bass_line[b]+12,) for b in range(bars)],['cello'],.75)  # a soft cello floor from the first bar, so the pizzicato intro is never bare
  held(part('pad_high','violin','pad'),[pad_voices[b][1:] for b in range(bars)],['violin 2','violin 1'],.6,gate=lambda b:label_at(b)[0] in ('B','turn') or label_at(b)[1]>=2)

 # ---- Accompaniment texture ------------------------------------------------
 texture=ACCOMPANIMENT[family]
 if style in HARP_STYLES:texture='harp'
 if style in ('hide','defeat'):texture='piano_sparse'
 for b,d in enumerate(chords):
  v=pad_voices[b];at=b*bar_s;lvl=levels[b];bass=bass_line[b]
  if texture=='piano_flow':
   up=[n+(0 if n>=55 else 12) for n in v]
   pattern=[bass,bass+7 if (bass+7)%12 in harmony.chord(d) else up[0],up[0],up[1],up[2],up[1],up[0],up[1]] if meter==4 else [bass,up[0],up[1],up[2],up[1],up[0]]
   step=beat/2
   for j,n in enumerate(pattern):add(part('acc','piano','acc'),human(at+j*step,.008),bar_s-j*step,n,vel(lvl*.8,-8+(6 if j==0 else 0)))
  elif texture=='piano_sparse':
   for j,pos in enumerate([0,2] if meter==4 else [0]):
    add(part('acc','piano','acc'),human(at+pos*beat),2*beat,bass,vel(lvl*.75,-6))
    for k,n in enumerate(v[:2]):add(part('acc','piano','acc'),human(at+pos*beat+.03*(k+1)+.18*beat),2*beat-.2*beat,n,vel(lvl*.7,-10))
  elif texture=='harp':
   arp=[bass,v[0],v[1],v[2],v[1]+12 if v[1]+12<=88 else v[1],v[2]] if meter==4 else [bass,v[0],v[1],v[2]]
   step=bar_s/len(arp) if family!='playful' else beat/2
   # The harpist damps at each chord change so one harmony never rings into the next.
   for j,n in enumerate(arp):add(part('acc','harp','acc'),human(at+j*step,.008),min(2.2,bar_s-j*step+.1),n,vel(lvl*.75,-6))
  elif texture=='pizz':
   for pos in range(meter):
    n=bass+12 if pos%2==0 else v[0];n=n if pos!=2 else bass+19 if (bass+19)%12 in harmony.chord(d) else v[1]
    add(part('acc','pizz','acc'),human(at+pos*beat,.006),beat*.45,n,vel(lvl*.85,-4+(6 if pos==0 else 0)))
  elif texture=='spiccato':
   for j in range(meter*2):add(part('acc','spiccato','ostinato'),human(at+j*beat/2,.004),beat*.4,(bass+12) if j%2==0 else (bass+19 if (bass+19)%12 in harmony.chord(d) else v[0]),vel(lvl*.9,(8 if j%4==0 else -4)))
  elif texture=='waltz':
   add(part('acc','pizz','acc'),human(at),beat*.5,bass+12,vel(lvl*.85,4))
   for pos in (1,2):
    for n in v[:2]:add(part('acc','pizz','acc'),human(at+pos*beat),beat*.4,n,vel(lvl*.75,-6))
  # A gentle harp shimmer opens the contrasting section instead of mallets.
  if family=='lyrical' and labels[b][0]=='B' and texture!='harp' and not quiet:
   for j,n in enumerate([v[0],v[1],v[2],v[1]+12 if v[1]+12<=86 else v[2]]):add(part('colour','harp','colour'),human(at+(2+j*.5)*beat,.006),2.0,n,vel(lvl*.6,-10))
  if style=='playful' and b%4==3:add(part('colour','marimba','colour'),human(at+2.5*beat),beat,v[2]+12,vel(lvl*.55,-14))

 # ---- Counter-melody and answers -----------------------------------------
 counter_inst='horn' if style in HORN_STYLES else 'bassoon' if family=='playful' else 'cello'
 prev_c=None;mel_by_bar={}
 for at,length,n,d,_ in melody:mel_by_bar.setdefault(int(at/bar_s),[]).append(n)
 for b,d in enumerate(chords):
  label,occurrence,i=labels[b]
  if not ((label=='A' and occurrence>=2) or label=='B') or family in ('still','sparse') and label!='B':continue
  rng_c=(50,69) if counter_inst=='horn' else (43,62) if counter_inst=='bassoon' else (50,67);pcs=harmony.chord(d)
  cands=[n for n in range(rng_c[0],rng_c[1]+1) if n%12 in pcs]
  mel=mel_by_bar.get(b,[]);direction=(mel[-1]-mel[0]) if len(mel)>1 else 0
  if prev_c is None:c=nearest(60,cands)
  else:
   moves=sorted(cands,key=lambda x:(abs(x-prev_c)==0,abs(x-prev_c)))
   contrary=[x for x in moves if (x-prev_c)*direction<0]
   c=(contrary or moves)[0]
  add(part('counter',counter_inst,'counter'),human(b*bar_s+.03),bar_s+.1,c,vel(levels[b]*.85,-6),voice='counter');prev_c=c
 # Woodwinds answer at phrase ends while the tune holds its long note.
 answer_inst='flute' if lead!='flute' else 'clarinet'
 if family not in ('still','driving'):
  for b,d in enumerate(chords):
   label,occurrence,i=labels[b]
   if label in ('intro',) or i%4!=3:continue
   pcs=harmony.chord(d);rng_a=(64,84) if answer_inst=='flute' else (52,76) if answer_inst=='clarinet' else (46,64)
   tones=sorted([n for n in range(*rng_a) if n%12 in pcs],reverse=True)[:3]
   if len(tones)<3:continue
   for j,n in enumerate(tones):add(part('answer',answer_inst,'answer'),human(b*bar_s+(1.5+j*.75)*beat if meter==4 else b*bar_s+(1+j*.6)*beat),.8*beat if j<2 else 1.4*beat,n,vel(levels[b]*.8,-6+2*j))

 # ---- Brass support and percussion -----------------------------------------
 if style in HORN_STYLES:
  for b,d in enumerate(chords):
   label,occurrence,i=labels[b]
   if levels[b]<.85 or label=='intro':continue
   pcs=harmony.chord(d);a=nearest(57,[n for n in range(50,66) if n%12==pcs[0]]);c=nearest(a+4,[n for n in range(a+3,a+9) if n%12 in pcs[1:]] or [a+7])
   for n,voice in ((a,'horn 2'),(c,'horn 1')):add(part('brass','horn','brass'),human(b*bar_s+.04),bar_s+.1,n,vel(levels[b]*.8,-10),voice=voice)
 percussion=[]
 if style in PERCUSSION_STYLES:
  for b in range(bars):
   label,occurrence,i=labels[b]
   if i==0 and label=='A' and occurrence>=2:percussion.append({'sample':'timpani','at':b*bar_s,'gain':.22+.15*levels[b]})
   if style in ('battle','march'):
    if i%2==0:percussion.append({'sample':'timpani','at':b*bar_s,'gain':.16})
    for pos in ((1,3) if meter==4 else (1,2)):percussion.append({'sample':'snare','at':b*bar_s+pos*beat,'gain':.10 if style=='march' else .13})
  if ending:percussion.append({'sample':'timpani','at':(bars-1)*bar_s,'gain':.30})
  if style in ('homecoming','victory'):percussion.append({'sample':'cymbal','at':(bars-1)*bar_s,'gain':.10})

 # ---- Dynamics ------------------------------------------------------------
 # Gain curves for sustained parts: section level with a hairpin across each four bars.
 times=np.arange(0,bars*bar_s+bar_s,bar_s/4)
 curve=[]
 for t in times:
  b=min(bars-1,int(t/bar_s));lvl=levels[b];pos=(t%(4*bar_s))/(4*bar_s)
  curve.append((round(float(t),3),round(float((.55+.45*lvl)*(.9+.14*math.sin(math.pi*pos))),4)))
 for p in parts.values():
  for e in p['events']:e['at']=round(e['at']+lead_in,4)
 for e in percussion:e['at']+=lead_in
 curve=[(0.0,curve[0][1])]+[(round(t+lead_in,3),g) for t,g in curve]
 # Looping cues settle inside the file: nothing rings past the loop point.
 for p in parts.values():
  if not ending:
   for e in p['events']:e['duration']=round(max(.06,min(e['duration'],lead_in+bars*bar_s-.45-e['at'])),4)
  p['events'].sort(key=lambda e:(e['at'],e['note']))
  p['dynamics']=curve if p['instrument'] in SUSTAINED else None
 return {'id':cue,'style':style,'family':family,'key':{'D':'D major','G':'G major','B':'B minor','F':'F major'}[key],'bpm':bpm,'meter':meter,'bars':bars,'seconds':duration,
  'music_end':lead_in+bars*bar_s,'lead_in':lead_in,'bar_seconds':bar_s,'description':description,'motif':motif,'form':[(l,len(c)) for l,c in sections],'chords':chords,
  'parts':parts,'percussion':percussion,'loop':not ending,'role_level':ROLE_LEVEL,
  'method':'Revision 3: harmony-led melody from the cue motif, cadential phrases in A A B A form, voice-led strings, phrase dynamics and per-role balance.'}

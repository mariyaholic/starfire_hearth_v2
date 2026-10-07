"""Instrument-aware phrasing and safe note lifetimes for sfizz's channel-less CLI."""
from collections import defaultdict
from mido import MidiFile,MidiTrack,Message,MetaMessage,bpm2tempo
SUSTAINED={'violin','viola','cello','bass','horn','trumpet','flute','clarinet','bassoon'}
HELD_ROLES={'lead melody','sustained orchestra','low string support','warm brass support','brass harmony','woodwind answer'}
OVERLAP={instrument:(.20 if instrument in {'violin','viola','cello','bass','horn'} else .12) for instrument in SUSTAINED}

def phrase(stems,beat,meter,bars,ending=False):
 """Connect held phrases; preserve articulated ostinatos and natural struck decay."""
 bar_seconds=beat*meter;active_end=bars*bar_seconds;changes=[]
 for inst,events in stems.items():
  groups=defaultdict(list)
  for e in events:groups[(e['role'],e.get('voice',e['role']))].append(e)
  updated=[]
  for (role,voice),notes in groups.items():
   notes.sort(key=lambda e:e['at'])
   if role in HELD_ROLES:
    for i,e in enumerate(notes):
     old=e['duration'];nxt=notes[i+1] if i+1<len(notes) else None
     boundary=(int((e['at']+.025)/bar_seconds)+1)*bar_seconds
     if inst in SUSTAINED:
      if role in {'sustained orchestra','low string support','warm brass support','brass harmony'}:
       # Hold the harmony through this bar; gaps in orchestration stay intentional.
       end=boundary+OVERLAP[inst]
      elif nxt:
       end=nxt['at']+OVERLAP[inst]
       # A wind player takes a brief phrase breath; the orchestra carries it.
       if inst in {'horn','trumpet','flute','clarinet','bassoon'} and int(nxt['at']/bar_seconds)//4>int(e['at']/bar_seconds)//4:end=nxt['at']-.055
      else:end=max(e['at']+old,boundary)
     elif role=='lead melody' and inst=='piano':
      end=nxt['at']-.015 if nxt else boundary
     elif role=='lead melody' and inst in {'harp','marimba','glock'}:
      end=min(nxt['at']+.35 if nxt else boundary+.5,e['at']+max(old,2.0))
     else:end=e['at']+old
     e['duration']=round(max(.08,min(active_end if ending else active_end+.35,end)-e['at']),4)
     if abs(e['duration']-old)>.01:changes.append({'instrument':inst,'role':role,'at':e['at'],'old':old,'new':e['duration']})
   if inst=='harp':
    for e in notes:e['duration']=round(max(e['duration'],min(2.5,max(.2,active_end-e['at']))),4)
   # Sustaining the same pitch uses a tie, not an unnecessary fresh bow/attack.
   tied=[]
   for e in notes:
    if tied and inst in SUSTAINED and role in HELD_ROLES and e['note']==tied[-1]['note'] and tied[-1]['at']+tied[-1]['duration']>=e['at']:
     tied[-1]['duration']=round(max(tied[-1]['at']+tied[-1]['duration'],e['at']+e['duration'])-tied[-1]['at'],4);tied[-1]['ties']=tied[-1].get('ties',0)+1
    else:tied.append(e)
   updated.extend(tied)
  stems[inst]=sorted(updated,key=lambda e:(e['at'],e['note']))
 return {'revision':2,'method':'Held lines through harmonic boundaries, instrumental overlap, same-pitch ties, brief wind phrase breaths and controlled piano pedal. Struck instruments retain natural decay.','changed_note_lengths':len(changes),'examples':changes[:20],'piano_pedal':True}

def write_midi(events,path,bpm,end,instrument,bar_seconds,music_end,offset=0.0):
 """Reference-count simultaneous same-pitch notes before emitting a MIDI note-off.

 sfizz_render discards MIDI channels, so moving parts to separate MIDI channels
 would not fix premature note-offs from overlapping accompaniment/melody pitches.
 """
 mid=MidiFile(ticks_per_beat=960);track=MidiTrack();mid.tracks.append(track);track.append(MetaMessage('set_tempo',tempo=bpm2tempo(bpm),time=0));ticks=lambda s:round(s*bpm/60*960);scheduled=[]
 for e in events:
  scheduled.extend([(ticks(e['at']),2,'on',e),(ticks(e['at']+e['duration']),0,'off',e)])
 if instrument=='piano':
  for cc,value in [(72,50),(22,8)]:scheduled.append((0,1,'cc',(cc,value)))
  scheduled.append((0,1,'cc',(64,100)))
  for bar in range(1,round((music_end-offset)/bar_seconds)):
   at=offset+bar*bar_seconds;scheduled.extend([(ticks(at-.020),1,'cc',(64,0)),(ticks(at+.015),1,'cc',(64,100))])
  scheduled.append((ticks(music_end),1,'cc',(64,0)))
 active=defaultdict(int);previous=0
 for tick,order,kind,value in sorted(scheduled,key=lambda x:(x[0],x[1])):
  if kind=='on':active[value['note']]+=1;message=Message('note_on',note=value['note'],velocity=value['velocity'])
  elif kind=='off':
   active[value['note']]-=1
   if active[value['note']]:continue
   message=Message('note_off',note=value['note'],velocity=0)
  else:message=Message('control_change',control=value[0],value=value[1])
  message.time=max(0,tick-previous);track.append(message);previous=tick
 track.append(MetaMessage('end_of_track',time=max(0,ticks(end)-previous)));mid.save(path)

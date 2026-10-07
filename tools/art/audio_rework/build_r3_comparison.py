"""Revision 2 then revision 3 of the same passage, at matched loudness, for the pilot cues."""
from pathlib import Path
import argparse,json,re,subprocess
import numpy as np,soundfile as sf
parser=argparse.ArgumentParser();parser.add_argument('--previous',default='reports/audio_rework_phrasing');parser.add_argument('--out',default='reports/audio_rework_r3');parser.add_argument('--seconds',type=float,default=24);args=parser.parse_args()
old=Path(args.previous);root=Path(args.out);segments=[];timecodes=[];clock=0.0;SR=48000
def lufs(path):
 p=subprocess.run(['ffmpeg','-hide_banner','-nostats','-i',str(path),'-af','loudnorm=I=-18:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
 return float(json.loads(re.findall(r'\{\s*"input_i"[\s\S]*?\}',p.stderr)[-1])['input_i'])
# Each excerpt starts at a musical landmark in revision 3's form so both versions are heard at the same moment.
for cue,section in [('mus_title',('A',2)),('mood_sorrow',('intro',1)),('theme_sola',('B',1))]:
 score=json.loads((root/'scores'/(cue+'.json')).read_text());bar=0;seen={}
 for label,length in score['form']:
  seen[label]=seen.get(label,0)+1
  if (label,seen[label])==section:break
  bar+=length
 start=bar*score['bar_seconds'];paths=[old/'masters'/(cue+'.wav'),root/'masters'/(cue+'.wav')];levels=[lufs(p) for p in paths];target=min(levels)
 timecodes.append({'at_seconds':round(clock,2),'cue':cue,'source_start_seconds':round(start,2),'order':'revision 2, gap, revision 3, gap'})
 for path,level in zip(paths,levels):
  with sf.SoundFile(path) as f:f.seek(round(start*f.samplerate));x=f.read(round(args.seconds*f.samplerate),dtype='float32',always_2d=True)
  x*=10**((target-level)/20);fade=round(.4*SR);x[:round(.015*SR)]*=np.linspace(0,1,round(.015*SR))[:,None];x[-fade:]*=np.linspace(1,0,fade)[:,None]
  segments.extend([x,np.zeros((round(1.0*SR),2),np.float32)]);clock+=len(x)/SR+1.0
wave=root/'R2_vs_R3_Pilot.wav';sf.write(wave,np.concatenate(segments),SR,subtype='PCM_24')
subprocess.run(['ffmpeg','-v','error','-y','-i',str(wave),'-c:a','libmp3lame','-b:a','192k',str(root/'R2_vs_R3_Pilot.mp3')],check=True)
for cue in ['mus_title','mood_sorrow','theme_sola']:
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(root/'masters'/(cue+'.wav')),'-c:a','libmp3lame','-b:a','192k',str(root/(cue+'_R3.mp3'))],check=True)
(root/'R2_vs_R3_Pilot_Timecodes.json').write_text(json.dumps(timecodes,indent=2)+'\n');print(json.dumps({'seconds':round(clock,1),'cues':timecodes},indent=1))

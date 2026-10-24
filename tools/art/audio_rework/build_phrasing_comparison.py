"""Compare the first orchestral rendition against corrected phrasing at matched levels."""
from pathlib import Path
import argparse
import numpy as np,soundfile as sf,subprocess,json,re
parser=argparse.ArgumentParser();parser.add_argument('--previous',default='reports/audio_rework');parser.add_argument('--out',default='reports/audio_rework_phrasing');args=parser.parse_args()
old=Path(args.previous);root=Path(args.out);segments=[];timecodes=[];clock=0.0
for cue,start,length in [('mus_title',45,18),('mood_sorrow',0,14),('theme_sola',24,18),('theme_speaker',12,18),('mus_battle',42,18)]:
 timecodes.append({'at_seconds':clock,'cue':cue,'source_start_seconds':start,'order':'previous rendition, gap, corrected rendition, gap'})
 paths=[old/'masters'/(cue+'.wav'),root/'masters'/(cue+'.wav')];levels=[]
 for path in paths:
  p=subprocess.run(['ffmpeg','-hide_banner','-nostats','-i',str(path),'-af','loudnorm=I=-18:print_format=json','-f','null','-'],capture_output=True,text=True,check=True);levels.append(float(json.loads(re.findall(r'\{\s*"input_i"[\s\S]*?\}',p.stderr)[-1])['input_i']))
 target=min(levels)
 for path,level in zip(paths,levels):
  with sf.SoundFile(path) as f:f.seek(start*f.samplerate);x=f.read(length*f.samplerate,dtype='float32',always_2d=True);sr=f.samplerate
  x*=10**((target-level)/20);fade=round(.015*sr);x[:fade]*=np.linspace(0,1,fade)[:,None];x[-fade:]*=np.linspace(1,0,fade)[:,None];segments.extend([x,np.zeros((round(.5*sr),2),np.float32)]);clock+=len(x)/sr+.5
wave=root/'Phrasing_Revision_Comparison.wav';sf.write(wave,np.concatenate(segments),48000,subtype='PCM_24');subprocess.run(['ffmpeg','-v','error','-y','-i',str(wave),'-c:a','libmp3lame','-b:a','192k',str(root/'Phrasing_Revision_Comparison.mp3')],check=True);(root/'Phrasing_Comparison_Timecodes.json').write_text(json.dumps(timecodes,indent=2)+'\n');print(json.dumps({'seconds':clock,'bytes':(root/'Phrasing_Revision_Comparison.mp3').stat().st_size,'cues':timecodes}))

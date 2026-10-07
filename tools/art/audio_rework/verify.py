"""Audit every review rendition against the delivered manifest and codec output."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import argparse,json,hashlib,re,subprocess
import numpy as np,soundfile as sf
p=argparse.ArgumentParser();p.add_argument('--out',default='reports/audio_rework');args=p.parse_args()
root=Path(args.out);data=json.loads((root/'catalogue.json').read_text());items=data['items']
manifest=json.loads(Path('data/asset_manifest.json').read_text())
expected={f for e in manifest['assets'] if e['kind'] in ['music','sfx'] and e['status']=='delivered' for f in e.get('files',[e.get('file')]) if f}
checks=[]
def check(label,value):checks.append({'check':label,'pass':bool(value)})
check('Every delivered audio file and variant has exactly one comparison',expected=={e['file'] for e in items} and len(items)==len(expected)==84)
check('28 music cues and 56 SFX/ambience variants',sum(e['kind']=='music' for e in items)==28 and sum(e['kind']=='sfx' for e in items)==56)
def sha(p):
 with p.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()
def measure(path):
 proc=subprocess.run(['ffmpeg','-hide_banner','-nostats','-i',str(path),'-af','loudnorm=I=-18:TP=-1.2:LRA=12:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
 result=json.loads(re.findall(r'\{\s*"input_i"[\s\S]*?\}',proc.stderr)[-1])
 return {'lufs':float(result['input_i']),'true_peak_dbtp':float(result['input_tp']),'loudness_range':float(result['input_lra'])}
def audit(e):
 before=root/e['before_file'];after=root/e['after_file'];master=root/'masters'/(e['slug']+'.wav');original=Path('assets/delivered')/e['file'];x,sr=sf.read(after,dtype='float32',always_2d=True);old=sf.info(original)
 stereo=e['kind']=='music' or e['id'] in ['survey_ping','beacon_activate','jump_transit','ship_destroyed','ambient_ui_room']
 result={'slug':e['slug'],'source_unchanged':sha(original)==sha(before)==e['source_sha256'],'after_sha256':sha(after),'after_distinct_from_source':sha(after)!=sha(before),'sample_rate':sr,'channels':x.shape[1],'duration':len(x)/sr,'duration_delta':len(x)/sr-old.duration,'finite':bool(np.isfinite(x).all()),'peak':float(np.max(np.abs(x))),'rms':float(np.sqrt(np.mean(x*x))),'expected_channels':2 if stereo else 1}
 result['technical_pass']=result['source_unchanged'] and result['after_distinct_from_source'] and result['finite'] and 0<result['peak']<1 and result['rms']>1e-7 and sr==48000 and x.shape[1]==result['expected_channels'] and abs(result['duration_delta'])<.025
 if e['kind']=='music' or e['id']=='ambient_ui_room':
  result.update(measure(after));result['loudness_pass']=abs(result['lufs']-(-18 if e['kind']=='music' else -30))<=1 and result['true_peak_dbtp']<=-1
 if (e['kind']=='music' and not e['id'].startswith('sting_')) or e['id']=='ambient_ui_room':
  derivative=np.sqrt(np.mean(np.diff(x,axis=0)**2));result['loop_boundary_jump_rms_ratio']=float(np.sqrt(np.mean((x[0]-x[-1])**2))/max(derivative,1e-9));result['loop_boundary_pass']=result['loop_boundary_jump_rms_ratio']<3
 if e['kind']=='music':
  score=json.loads((root/'scores'/(e['slug']+'.json')).read_text());stems=[]
  for name in score['stems']:
   stem=root/'renders'/e['slug']/(name+'.wav');audio,_=sf.read(stem,dtype='float32');stems.append(bool(np.isfinite(audio).all() and np.max(np.abs(audio))>1e-5))
  result['sampled_parts']=len(stems);result['stems_non_silent']=all(stems)
 for side in ['before','after']:
  meta=json.loads(subprocess.run(['ffprobe','-v','error','-show_entries','stream=codec_name,sample_rate:format=duration','-of','json',str(root/e[side+'_audio'])],capture_output=True,text=True,check=True).stdout)
  result[side+'_browser_codec_pass']=meta['streams'][0]['codec_name']=='aac' and int(meta['streams'][0]['sample_rate'])==48000 and abs(float(meta['format']['duration'])-old.duration)<.055
 return result
with ThreadPoolExecutor(max_workers=4) as pool:results=list(pool.map(audit,items))
check('All originals remain byte-identical and every after is valid, non-silent, unclipped 48 kHz with the intended duration/channels',all(r['technical_pass'] for r in results))
check('All 84 new renditions have distinct file hashes',len({r['after_sha256'] for r in results})==84)
check('Encoded music/ambience meets target LUFS within 1 and true peak at or below -1 dBTP',all(r.get('loudness_pass',True) for r in results))
check('Loop boundary discontinuity is below three times normal sample derivative',all(r.get('loop_boundary_pass',True) for r in results))
check('All recorded instrumental parts render non-silently',all(r.get('stems_non_silent',True) for r in results))
check('All 168 browser audio streams use native AAC at 48 kHz and preserve duration',all(r['before_browser_codec_pass'] and r['after_browser_codec_pass'] for r in results))
logs=list((root/'renders').glob('*/*.log'));bad=[]
for log in logs:
 for line in log.read_text(errors='replace').splitlines():
  if re.search(r'missing sample|cannot (?:open|load|find)|failed to load|unknown opcode',line,re.I):bad.append({'file':str(log),'line':line})
check('No missing instrument/sample or unknown-opcode errors in sfizz logs',not bad)
summary={'date':'2026-10-07','passed':all(c['pass'] for c in checks),'checks':checks,'music':28,'sfx_and_ambience':56,'duration_each_version_seconds':sum(e['seconds'] for e in items),'sampled_parts':sum(r.get('sampled_parts',0) for r in results),'missing_sample_errors':bad,'limitation':'These are objective file, signal and codec checks. Artistic quality remains for listening review; no claim of a final approved soundtrack or physical-phone test.','items':results}
(root/'verification.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps({k:v for k,v in summary.items() if k!='items'},indent=2),flush=True)
raise SystemExit(0 if summary['passed'] else 1)

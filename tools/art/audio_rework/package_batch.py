"""Package rendered revision 3 masters as a standard music intake batch.

The zip goes through tools/import_assets.py like any outsourced delivery, so every brief check
(length, loudness, true peak, loop seam) applies to it:
  python3 tools/art/audio_rework/package_batch.py
  python3 tools/import_assets.py --zip incoming/sfh_music_batch2.zip --check
  python3 tools/import_assets.py --zip incoming/sfh_music_batch2.zip --replace
"""
from pathlib import Path
import argparse,json,zipfile
import soundfile as sf
parser=argparse.ArgumentParser();parser.add_argument('--masters',default='reports/audio_rework_r3/masters');parser.add_argument('--batch',type=int,default=2);parser.add_argument('--out',default='incoming');args=parser.parse_args()
ids=[a['id'] for a in json.loads(Path('data/asset_manifest.json').read_text())['assets'] if a['kind']=='music']
masters=Path(args.masters);missing=[i for i in ids if not (masters/(i+'.wav')).exists()]
if missing:raise SystemExit('Missing masters: '+', '.join(missing))
# Loops restart at the first note: the 0.3 s lead-in (compose.LEAD_IN) is heard only on the first play.
LEAD_IN=round(.3*48000)
meta={'kind':'music','batch':args.batch,
 'licence':'CC0 compositions; recorded samples VSCO 2 Community Edition (CC0) and Salamander Grand Piano V3 (CC BY 3.0)',
 'source':'Audio revision 3, composed by tools/art/audio_rework/compose.py and rendered with sfizz 1.2.3 from VSCO 2 CE '
          '(pin 440300901dfe9275fd84e0b7763af1f8443ae62e) and Salamander Grand Piano V3 (pin 3382bf9496bba2486f5ab0de55a264d1dfc38404)',
 'attribution':'Piano: Salamander Grand Piano V3 by Alexander Holm, licensed under CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/); '
               'samples mapped and rendered, not otherwise modified',
 'items':[{'id':i,'file':i+'.wav','notes':'sting' if i.startswith('sting_') else 'loop %d-%d'%(LEAD_IN,sf.info(masters/(i+'.wav')).frames)} for i in ids]}
out=Path(args.out);out.mkdir(exist_ok=True);path=out/('sfh_music_batch%d.zip'%args.batch)
with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as z:
 z.writestr('manifest.json',json.dumps(meta,indent=2)+'\n')
 for i in ids:z.write(masters/(i+'.wav'),i+'.wav')
print(json.dumps({'zip':str(path),'items':len(ids),'bytes':path.stat().st_size}))

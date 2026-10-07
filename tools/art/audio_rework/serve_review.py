"""Serve the A/B player with byte ranges so music preview/A-B seeks work correctly."""
from pathlib import Path
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
import argparse,re,shutil
class RangeHandler(SimpleHTTPRequestHandler):
 def log_message(self,*_):pass
 def end_headers(self):
  self.send_header('Accept-Ranges','bytes');super().end_headers()
 def send_head(self):
  self._remaining=None;header=self.headers.get('Range');path=Path(self.translate_path(self.path))
  if not header or not path.is_file():return super().send_head()
  match=re.fullmatch(r'bytes=(\d*)-(\d*)',header)
  if not match:return super().send_head()
  size=path.stat().st_size;a,b=match.groups();start=int(a) if a else max(0,size-int(b));end=min(size-1,int(b)) if a and b else size-1
  if start> end or start>=size:
   self.send_response(416);self.send_header('Content-Range',f'bytes */{size}');self.end_headers();return None
  source=path.open('rb');source.seek(start);self._remaining=end-start+1
  self.send_response(206);self.send_header('Content-Type',self.guess_type(str(path)));self.send_header('Content-Range',f'bytes {start}-{end}/{size}');self.send_header('Content-Length',str(self._remaining));self.end_headers();return source
 def copyfile(self,source,output):
  try:
   if self._remaining is None:shutil.copyfileobj(source,output)
   else:
    left=self._remaining
    while left:
     chunk=source.read(min(65536,left))
     if not chunk:break
     output.write(chunk);left-=len(chunk)
  except (BrokenPipeError,ConnectionResetError):pass
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--out',default='reports/audio_rework');parser.add_argument('--port',type=int,default=8785);parser.add_argument('--bind',default='127.0.0.1');args=parser.parse_args()
 server=ThreadingHTTPServer((args.bind,args.port),partial(RangeHandler,directory=str(Path(args.out).resolve())))
 print(f'Audio A/B player: http://{args.bind}:{server.server_port}/index.html',flush=True);server.serve_forever()

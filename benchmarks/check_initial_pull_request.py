"""Validate an initial numerical proposal without approving its results."""
import base64,hashlib,json,os,sys,urllib.request
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent/'owner-verifier'))
from validate_initial import validate_initial
from validate_submission import MAX_BYTES,read_json
import tempfile,re
def api(path):
 request=urllib.request.Request('https://api.github.com/'+path,headers={'Authorization':'Bearer '+os.environ['GH_TOKEN'],'Accept':'application/vnd.github+json','User-Agent':'SITE-initial-validator'})
 with urllib.request.urlopen(request,timeout=45) as response:data=response.read(MAX_BYTES*2+1)
 if len(data)>MAX_BYTES*2:raise ValueError('API response too large')
 return json.loads(data)
repo=os.environ['REPOSITORY'];number=int(os.environ['PR_NUMBER']);pr=api(f'repos/{repo}/pulls/{number}')
if not 0<pr['changed_files']<=20:raise ValueError('Too many changed files')
for file in api(f'repos/{repo}/pulls/{number}/files?per_page=100'):
 if not re.fullmatch(r'benchmarks/initial-inbox/[0-9a-f]{64}\.json',file['filename']) or file['status'] not in ('added','modified'):raise ValueError('Initial requests may contain numerical JSON only')
 blob=api(f"repos/{repo}/git/blobs/{file['sha']}")
 if blob['size']>MAX_BYTES or blob['encoding']!='base64':raise ValueError('Invalid numerical blob')
 raw=base64.b64decode(blob['content']);digest=hashlib.sha256(raw).hexdigest()
 if file['filename']!='benchmarks/initial-inbox/'+digest+'.json':raise ValueError('Candidate checksum differs')
 with tempfile.TemporaryDirectory() as temp:
  path=Path(temp)/'envelope.json';path.write_bytes(raw);print(json.dumps(validate_initial(read_json(path))))
print('Structure checked. Owner-computer verification is still required before publication.')

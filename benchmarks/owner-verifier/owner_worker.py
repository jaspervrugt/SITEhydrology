"""Owner-controlled polling worker. Never check out or execute proposal code."""
import argparse,base64,hashlib,json,os,re,subprocess,sys,time,shutil
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE/'lib'))
from validate_submission import read_json,validate,MAX_BYTES
from validate_initial import validate_initial
from publish_verified import publish,atomic_write,canonical
from regional_result_paths import result_paths
REPO='jaspervrugt/SITEhydrology'
GH=shutil.which('gh') or str(Path(os.environ.get('ProgramFiles','C:/Program Files'))/'GitHub CLI/gh.exe')

def api(endpoint,method='GET',body=None,work=HERE):
 args=[GH,'api','repos/'+REPO+'/'+endpoint,'--method',method]
 if body is not None:
  f=Path(work)/'api-request.json';f.write_text(json.dumps(body));args+=['--input',str(f)]
 result=subprocess.run(args,capture_output=True,text=True,encoding='utf-8',timeout=120)
 if result.returncode:raise RuntimeError('GitHub request failed: '+endpoint)
 return json.loads(result.stdout)

def blob(sha):
 if not re.fullmatch('[0-9a-f]{40}',sha):raise ValueError('Invalid blob')
 b=api('git/blobs/'+sha)
 if b['encoding']!='base64' or b['size']>MAX_BYTES:raise ValueError('Invalid blob size')
 data=base64.b64decode(b['content'])
 if hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()!=sha:raise ValueError('Git blob differs')
 return data

def contents(path,ref):
 return api('contents/'+path+'?ref='+ref)

def proposal_files(files):
 if not 0<len(files)<=20:raise ValueError('Invalid initial proposal size')
 for f in files:
  if not re.fullmatch(r'benchmarks/initial-inbox/[0-9a-f]{64}\.json',f['filename']) or f['status'] not in ('added','modified'):raise ValueError('Initial proposals may contain numerical JSON only')
 return files

def owner_approved(pr):
 # Self-authored owner requests are explicit authorization; external
 # proposals require an owner approval of the exact current revision.
 if pr['user']['login'].lower()=='jaspervrugt':return True
 decisive=[]
 for page in range(1,101):
  batch=api('pulls/'+str(pr['number'])+'/reviews?per_page=100&page='+str(page))
  decisive.extend(r for r in batch if r['user']['login'].lower()=='jaspervrugt'
      and r['state'] in ('APPROVED','CHANGES_REQUESTED','DISMISSED'))
  if len(batch)<100:break
 return bool(decisive and decisive[-1]['state']=='APPROVED'
             and decisive[-1]['commit_id']==pr['head']['sha'])

def matlab(config,command,job,revision):
 env=dict(os.environ,SITE_OWNER_REVISION=revision)
 log=Path(job)/('matlab-'+str(time.time_ns())+'.log')
 with log.open('w',encoding='utf-8') as out:
  flags=(subprocess.CREATE_NO_WINDOW|subprocess.BELOW_NORMAL_PRIORITY_CLASS) if os.name=='nt' else 0
  subprocess.run([config['matlab'],'-batch',command],env=env,stdout=out,stderr=subprocess.STDOUT,check=True,timeout=6*3600,creationflags=flags)

def quote(path):return "'"+str(path).replace("'","''")+"'"

def source_revision(config):
 digest=hashlib.sha256()
 for entry in config['trustedFiles']:
  data=Path(entry['path']).read_bytes()
  if hashlib.sha256(data).hexdigest()!=entry['sha256']:raise RuntimeError('Owner code changed; refresh its approved installation before verification')
  digest.update(entry['path'].encode());digest.update(bytes.fromhex(entry['sha256']))
 return digest.hexdigest()

def site_open():
 if os.name=='nt':
  for name in ('SITE.exe','SITEhydrology.exe'):
   r=subprocess.run(['tasklist','/FI','IMAGENAME eq '+name,'/FO','CSV','/NH'],capture_output=True,text=True,timeout=20)
   if ('"'+name+'"').lower() in r.stdout.lower():return True
  return False
 return subprocess.run(['pgrep','-x','SITE'],capture_output=True).returncode==0

def process_running(pid):
 if os.name=='nt':
  result=subprocess.run(['tasklist','/FI','PID eq '+str(int(pid)),'/FO','CSV','/NH'],capture_output=True,text=True,timeout=20)
  return '"'+str(int(pid))+'"' in result.stdout
 return subprocess.run(['ps','-p',str(int(pid)),'-o','pid='],capture_output=True,text=True).stdout.strip()==str(int(pid))

def acquire_lock(lock):
 if lock.exists():
  marker=lock/'pid.json'
  if marker.exists():
   if process_running(read_json(marker)['pid']):return False
   marker.unlink();lock.rmdir()
  elif time.time()-lock.stat().st_mtime>300:lock.rmdir()
  else:return False
 try:lock.mkdir()
 except FileExistsError:return False
 atomic_write(lock/'pid.json',canonical({'pid':os.getpid()}));return True

def uniform_profiles(manifest,profile):
 rows=manifest['profiles'];rows=[rows] if isinstance(rows,dict) else rows
 prior=next((p for p in rows if p['id']==profile['id']),None)
 if prior:
  old=prior.get('inputFingerprints',{}).get('records',[]);new=profile['inputFingerprints']['records']
  old=[old] if isinstance(old,dict) else old;new=[new] if isinstance(new,dict) else new
  combined={r['basin']:r for r in old}
  combined.update({r['basin']:r for r in new})
  profile=dict(prior,inputFingerprints=dict(profile['inputFingerprints'],records=list(combined.values())))
 else:
  profile['inputFingerprintSource']='Independently replayed against owner-installed inputs.'
  profile['legacyAttribution']={'contributor':'Unknown','platform':'Unknown'}
 rows=[p for p in rows if p['id']!=profile['id']]+[profile]
 fields=set().union(*(p.keys() for p in rows))
 return dict(manifest,profiles=[{k:p.get(k) for k in sorted(fields)} for p in rows])

def publish_job(job,config,revision,pr,head):
 reviewed=api('pulls/'+str(pr))
 if reviewed['head']['sha']!=head or not owner_approved(reviewed):
  raise RuntimeError('Owner approval of the current proposal is required')
 profile=read_json(job/'owner-profile.json');candidate=read_json(job/'candidate.json')
 parent=api('git/ref/heads/main')['object']['sha'];before=json.loads(blob(contents('benchmarks/profiles.json',parent)['sha']))
 manifest=uniform_profiles(before,profile);pub=job/'publication';pub.mkdir(exist_ok=True)
 idx=contents('benchmarks/index.json',parent);index=json.loads(blob(idx['sha']));atomic_write(pub/'index.json',canonical(index))
 # Only the matching immutable snapshot is needed, never the official datasets.
 previous=index['profiles'].get(profile['id'])
 if previous:
  digest=previous['sha256'];name=profile['id']+'_'+digest+'.json';dest=pub/previous['path'];dest.parent.mkdir(parents=True,exist_ok=True)
  subprocess.run([GH,'release','download','site-benchmarks','--repo',REPO,'--pattern',name,'--dir',str(job),'--clobber'],check=True)
  raw=(job/name).read_bytes()
  if hashlib.sha256(raw).hexdigest()!=digest:raise ValueError('Snapshot checksum differs')
  dest.write_bytes(raw)
 report=publish(job/'candidate.json',job/'manifest.json',job/'receipt.json',pub,revision)
 if not report['published']:return {'state':'current','improvements':0}
 snapshot=pub/report['entry']['path'];atomic_write(pub/'approved-profiles.json',canonical(manifest))
 plan={'files':[]}
 expected_paths=result_paths(profile)
 tree=api('git/trees/'+parent+'?recursive=1');hashes={e['path']:e['sha'] for e in tree['tree']}
 if not previous and any(path in hashes for path in expected_paths[:2]):
  raise ValueError('Existing unregistered result files require owner review; they will not be overwritten.')
 for path in expected_paths:
  if path in hashes:
   dest=pub/'inputs'/path;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(blob(hashes[path]))
 command='addpath('+quote(HERE)+');site_benchmark_owner_export('+','.join(map(quote,[job,config['core'],snapshot,pub]))+');'
 matlab(config,command,job,revision)
 paths=read_json(job/'exports.json')
 if set(paths)!=set(expected_paths):raise ValueError('Unexpected native exports')
 index=read_json(pub/'index.json');entry=index['profiles'][profile['id']];entry['resultFiles']=[]
 for path in paths:
  data=(pub/path).read_bytes();entry['resultFiles'].append({'path':path,'sha256':hashlib.sha256(data).hexdigest()})
 # Shared model summaries may also be referenced by existing profiles.
 for p in index['profiles'].values():
  for f in p.get('resultFiles',[]):
   if f['path'] in paths:f['sha256']=hashlib.sha256((pub/f['path']).read_bytes()).hexdigest()
 name=profile['id']+'_'+entry['sha256']+'.json';asset=job/name;asset.write_bytes(snapshot.read_bytes())
 assets=api('releases/tags/site-benchmarks')['assets'];known=next((a for a in assets if a['name']==name),None)
 if known:
  if known.get('digest')!='sha256:'+entry['sha256']:raise ValueError('Immutable snapshot asset differs')
 else:subprocess.run([GH,'release','upload','site-benchmarks',str(asset),'--repo',REPO],check=True)
 entry['downloadUrl']='https://github.com/'+REPO+'/releases/download/site-benchmarks/'+name
 files={path:(pub/path).read_bytes() for path in paths}
 files.update({'benchmarks/profiles.json':canonical(manifest),'benchmarks/index.json':canonical(index)})
 worker=contents('benchmarks/worker/worker-config.json',parent);configs=json.loads(blob(worker['sha']))
 public_run=read_json(job/'public-run.json');configs['profiles']=[p for p in configs['profiles'] if p['id']!=profile['id']]+[{'id':profile['id'],'run':public_run}]
 files['benchmarks/worker/worker-config.json']=canonical(configs)
 current=api('pulls/'+str(pr))
 if current['head']['sha']!=head or not owner_approved(current):raise RuntimeError('Proposal or owner approval changed; reverify before publication')
 if source_revision(config)!=revision:raise RuntimeError('Owner code changed during export; reverify before publication')
 if api('git/ref/heads/main')['object']['sha']!=parent:raise RuntimeError('Public results advanced; repeat the merge against current files')
 entries=[]
 for path,data in files.items():
  created=api('git/blobs','POST',{'encoding':'base64','content':base64.b64encode(data).decode()},job)
  entries.append({'path':path,'mode':'100644','type':'blob','sha':created['sha']})
 created=api('git/trees','POST',{'base_tree':parent,'tree':entries},job)
 commit=api('git/commits','POST',{'message':'Publish owner-verified initial SITE reference: '+profile['id'],'tree':created['sha'],'parents':[parent]},job)
 api('git/refs/heads/main','PATCH',{'sha':commit['sha'],'force':False},job)
 return {'state':'published','profile':profile['id'],'commit':commit['sha'],'improvements':report['improvements']}

def run(config,dry_run=False):
 if site_open():return {'state':'waiting','reason':'SITE is open; verification will wait.'}
 revision=source_revision(config);state=Path(config['state']);state.mkdir(parents=True,exist_ok=True);lock=state/'worker.lock'
 if not acquire_lock(lock):return {'state':'waiting','reason':'An owner verification is already running.'}
 try:
  login=json.loads(subprocess.check_output([GH,'api','user'],text=True,encoding='utf-8'))['login']
  if login.lower()!='jaspervrugt':raise RuntimeError('Owner GitHub sign-in is required')
  seen_file=state/'processed.json';seen=read_json(seen_file) if seen_file.exists() else {};reports=[]
  prs=[]
  for page in range(1,101):
   batch=api('pulls?state=open&per_page=100&page='+str(page));prs.extend(batch)
   if len(batch)<100:break
  prs.sort(key=lambda p:p['created_at'])
  for pr in prs:
   if not pr['title'].startswith('SITE initial reference:'):continue
   head=pr['head']['sha'];key=str(pr['number'])+':'+head
   if key in seen:continue
   if not owner_approved(pr):
    reports.append({'state':'awaiting_owner_approval','request':pr['number']})
    continue
   files=proposal_files(api('pulls/'+str(pr['number'])+'/files?per_page=100'))
   for f in files:
    raw=blob(f['sha']);digest=hashlib.sha256(raw).hexdigest()
    if f['filename']!='benchmarks/initial-inbox/'+digest+'.json':raise ValueError('Initial proposal digest differs')
    job=state/str(pr['number'])/digest;job.mkdir(parents=True,exist_ok=True);(job/'envelope.json').write_bytes(raw)
    envelope=read_json(job/'envelope.json');validate_initial(envelope)
    for r in ([envelope['payload']['records']] if isinstance(envelope['payload']['records'],dict) else envelope['payload']['records']):r['contributor']=pr['user']['login']
    atomic_write(job/'envelope.json',canonical(envelope))
    base=api('git/ref/heads/main')['object']['sha'];(job/'profiles-before.json').write_bytes(blob(contents('benchmarks/profiles.json',base)['sha']))
    try:
     verified=False
     for phase in ('prepare','verify'):
      if phase=='verify':validate(read_json(job/'candidate.json'),read_json(job/'manifest.json'))
      command='addpath('+quote(HERE)+');site_benchmark_owner_initial('+','.join(map(quote,[phase,job,config['core'],config['data']]))+');'
      matlab(config,command,job,revision)
     assert source_revision(config)==revision,'Owner code changed during verification'
     verified=True
     result={'state':'verified','request':pr['number']} if dry_run else dict(publish_job(job,config,revision,pr['number'],head),request=pr['number'])
     if not dry_run:
      api('statuses/'+head,'POST',{'state':'success','context':'SITE/owner-initial-reference','description':'Owner data checksums and numerical replay passed.'},job)
      api('pulls/'+str(pr['number']),'PATCH',{'state':'closed'},job)
    except (ValueError,RuntimeError,subprocess.SubprocessError) as error:
     result={'state':'pending' if verified and isinstance(error,(RuntimeError,subprocess.SubprocessError)) else 'needs_review','request':pr['number'],'reason':type(error).__name__,'log':str(job)}
    reports.append(result)
    # Missing owner data or failed checks stay recoverable. The owner may
    # fix the local installation and retry the same approved revision.
    if not dry_run and result['state'] in ('published','current'):seen[key]=result;atomic_write(seen_file,canonical(seen))
   break # Bound each scheduled run to one proposal.
  return {'state':'complete','reports':reports}
 finally:(lock/'pid.json').unlink();lock.rmdir()

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--config',type=Path,default=HERE/'owner-config.json');p.add_argument('--dry-run',action='store_true');a=p.parse_args()
 print(json.dumps(run(read_json(a.config),a.dry_run)))

"""Serialized trusted publisher, native result exports, atomic GitHub delivery."""
import argparse,base64,hashlib,json,os,subprocess
from pathlib import Path
from fetch_benchmarks import fetch
from publish_verified import publish
from deliver_snapshots import deliver
from regional_result_paths import result_paths
REPO='jaspervrugt/SITEhydrology'
def approved_manifest(base):
    file=base/'profiles.json'
    remote=json.loads(subprocess.check_output(['gh','api',f'repos/{REPO}/contents/benchmarks/profiles.json'],encoding='utf-8'))
    if hashlib.sha256(base64.b64decode(remote['content'])).digest()!=hashlib.sha256(file.read_bytes()).digest():
        raise RuntimeError('Approved defaults changed during verification; revalidate')
    return file
def prepare():
    base=Path('benchmarks');manifest=approved_manifest(base);root=Path('publication')
    expected=fetch(root);pin=json.loads((base/'core/core-pin.json').read_text())
    revision=os.environ['TRUSTED_BASE_SHA']+':'+pin['sha256'];changed=False;changed_profiles=set()
    for candidate in sorted(Path('verified-candidates').glob('*.json')):
        receipt=Path('verified-receipts')/candidate.name
        report=publish(candidate,manifest,receipt,root,revision);changed|=report['published'];print(json.dumps(report))
        if report['published']:changed_profiles.add(json.loads(candidate.read_text())['profile'])
    approved=json.loads(manifest.read_text());rows=approved['profiles']
    if isinstance(rows,dict):rows=[rows]
    profiles={p['id']:p for p in rows}
    state={'changed':changed,'changed_profiles':sorted(changed_profiles),'expected_index_sha':expected,'inputs':{}}
    (root/'approved-profiles.json').write_text(json.dumps(approved))
    if changed:
        index=json.loads((root/'index.json').read_text())
        paths={path for id in changed_profiles for path in result_paths(profiles[id])}
        for path in sorted(paths):
            response=subprocess.run(['gh','api',f'repos/{REPO}/contents/{path}'],capture_output=True,text=True,encoding='utf-8')
            if response.returncode:
                if 'HTTP 404' not in response.stderr:raise RuntimeError('Cannot read existing native benchmark')
                state['inputs'][path]=None;continue
            obj=json.loads(response.stdout)
            blob=json.loads(subprocess.check_output(['gh','api',f'repos/{REPO}/git/blobs/{obj["sha"]}'],encoding='utf-8'))
            data=base64.b64decode(blob['content'])
            if hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()!=obj['sha']:raise ValueError('Public input hash mismatch')
            target=root/'inputs'/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
            state['inputs'][path]=obj['sha']
    (root/'publication-state.json').write_text(json.dumps(state))
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'],'a') as f:f.write('changed='+str(changed).lower()+'\n')
def finish():
    base=Path('benchmarks');approved_manifest(base);root=Path('publication')
    state=json.loads((root/'publication-state.json').read_text())
    if not state['changed']:print('No verified improvement; public files unchanged.');return
    index=json.loads((root/'index.json').read_text());files=json.loads((root/'result-files.json').read_text())
    approved=json.loads((root/'approved-profiles.json').read_text());rows=approved['profiles']
    if isinstance(rows,dict):rows=[rows]
    profiles={p['id']:p for p in rows}
    expected={path for id in state['changed_profiles'] for path in result_paths(profiles[id])}
    if set(files)!=expected:raise ValueError('Unexpected native export')
    plan={'files':[]}
    for path in files:
        data=(root/path).read_bytes();digest=hashlib.sha256(data).hexdigest()
        plan['files'].append({'path':path,'source':path,'sha256':digest,'expected_sha':state['inputs'][path]})
    for profile in state['changed_profiles']:
        paths=set(result_paths(profiles[profile]))
        index['profiles'][profile]['resultFiles']=[{'path':x['path'],'sha256':x['sha256']} for x in plan['files'] if x['path'] in paths]
    (root/'index.json').write_text(json.dumps(index))
    deliver(root,state['expected_index_sha'],mirror_plan=plan)
    print('Verified native result files and latest index committed together; history preserved.')
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--phase',choices=['prepare','finish'],required=True)
    args=parser.parse_args();prepare() if args.phase=='prepare' else finish()

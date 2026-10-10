"""Serialized trusted publisher, native result exports, atomic GitHub delivery."""
import argparse,base64,hashlib,json,os,subprocess
from pathlib import Path
from fetch_benchmarks import fetch
from publish_verified import publish
from deliver_snapshots import deliver
from deliver_result_files import PATHS
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
    revision=os.environ['TRUSTED_BASE_SHA']+':'+pin['sha256'];changed=False
    for candidate in sorted(Path('verified-candidates').glob('*.json')):
        receipt=Path('verified-receipts')/candidate.name
        report=publish(candidate,manifest,receipt,root,revision);changed|=report['published'];print(json.dumps(report))
    state={'changed':changed,'expected_index_sha':expected,'inputs':{}}
    if changed:
        index=json.loads((root/'index.json').read_text())
        profile='camels_us_daily_nldas_pm_hbv_default'
        if set(index['profiles'])!={profile}:raise RuntimeError('No native exporter approved for this profile')
        for path in sorted(PATHS):
            response=subprocess.run(['gh','api',f'repos/{REPO}/contents/{path}'],capture_output=True,text=True,encoding='utf-8')
            if response.returncode:
                if path.endswith('.csv') and 'HTTP 404' in response.stderr:state['inputs'][path]=None;continue
                raise RuntimeError('Cannot read existing public results')
            obj=json.loads(response.stdout)
            blob=json.loads(subprocess.check_output(['gh','api',f'repos/{REPO}/git/blobs/{obj["sha"]}'],encoding='utf-8'))
            data=base64.b64decode(blob['content'])
            if hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()!=obj['sha']:raise ValueError('Public input hash mismatch')
            target=root/'inputs'/Path(path).name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
            state['inputs'][path]=obj['sha']
    (root/'publication-state.json').write_text(json.dumps(state))
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'],'a') as f:f.write('changed='+str(changed).lower()+'\n')
def finish():
    base=Path('benchmarks');approved_manifest(base);root=Path('publication')
    state=json.loads((root/'publication-state.json').read_text())
    if not state['changed']:print('No verified improvement; public files unchanged.');return
    index=json.loads((root/'index.json').read_text());files=json.loads((root/'result-files.json').read_text())
    if set(files)!=PATHS:raise ValueError('Unexpected native export')
    plan={'files':[]}
    for path in files:
        data=(root/path).read_bytes();digest=hashlib.sha256(data).hexdigest()
        plan['files'].append({'path':path,'source':path,'sha256':digest,'expected_sha':state['inputs'][path]})
    profile='camels_us_daily_nldas_pm_hbv_default'
    index['profiles'][profile]['resultFiles']=[{'path':x['path'],'sha256':x['sha256']} for x in plan['files']]
    (root/'index.json').write_text(json.dumps(index))
    deliver(root,state['expected_index_sha'],mirror_plan=plan)
    print('Verified native result files and latest index committed together; history preserved.')
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--phase',choices=['prepare','finish'],required=True)
    args=parser.parse_args();prepare() if args.phase=='prepare' else finish()

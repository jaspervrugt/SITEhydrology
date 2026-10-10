"""Trusted atomic mirror: native MAT/XLSX results and index in one commit."""
import base64,hashlib,json,subprocess
from pathlib import Path
REPO='jaspervrugt/SITEhydrology'
PATHS={
'results/CAMELS_US/daily/period_001/nldas_penman_monteith/param_ranges_hbv_daily.csv',
'results/CAMELS_US/daily/period_001/nldas_penman_monteith/SITE_hbv_daily_nldas_penman_monteith_p001_checkpoint.mat',
'results/CAMELS_US/daily/period_001/nldas_penman_monteith/param_hbv_daily_nldas_penman_monteith_p001.xlsx',
'results/CAMELS_US/daily/period_001/nldas_penman_monteith/model_master_daily_nldas_penman_monteith_p001.xlsx'}
def api(endpoint,method='GET',body=None,root=None):
    command=['gh','api',f'repos/{REPO}/{endpoint}']
    if method!='GET':command+=['--method',method]
    if body is not None:
        request=Path(root)/'atomic-result-request.json';request.write_text(json.dumps(body))
        command+=['--input',str(request)]
    return json.loads(subprocess.check_output(command,text=True,encoding='utf-8'))
def current_sha(path,branch):
    response=subprocess.run(['gh','api',f'repos/{REPO}/contents/{path}?ref={branch}'],capture_output=True,text=True,encoding='utf-8')
    if response.returncode and 'HTTP 404' not in response.stderr:
        raise RuntimeError('Cannot read current public result')
    return json.loads(response.stdout)['sha'] if response.returncode==0 else None
def deliver_atomic_results(root,index,plan,branch,index_path,expected_index_sha):
    root=Path(root).resolve();items=plan['files']
    allowed=PATHS
    if (root/'approved-profiles.json').is_file():
        from regional_result_paths import approved_paths
        allowed=approved_paths(json.loads((root/'approved-profiles.json').read_text()))
    paths={x['path'] for x in items}
    if not items or len(paths)!=len(items) or not paths.issubset(allowed):
        raise ValueError('Unexpected public result destinations')
    # Pin the parent before validating blobs. Concurrent updates then fail
    # the non-forced ref update rather than becoming our new parent.
    head=api("git/ref/heads/"+branch)
    parent=head["object"]["sha"]
    files=[]
    for item in items:
        source=(root/item['source']).resolve()
        if not source.is_relative_to(root) or source.stat().st_size>20*1024*1024:
            raise ValueError('Invalid result source')
        data=source.read_bytes()
        if hashlib.sha256(data).hexdigest()!=item['sha256']:
            raise ValueError('Result export checksum differs')
        if current_sha(item['path'],parent)!=item['expected_sha']:
            raise RuntimeError('Public results changed during verification; fetch and export again')
        files.append((item['path'],data))
    if current_sha(index_path,parent)!=expected_index_sha:
        raise RuntimeError('Benchmark index changed before atomic publication')
    files.append((index_path,json.dumps(index,sort_keys=True,separators=(',',':')).encode()))
    commit=api('git/commits/'+parent)
    tree=[]
    for path,data in files:
        blob=api('git/blobs','POST',{'encoding':'base64','content':base64.b64encode(data).decode()},root)
        tree.append({'path':path,'mode':'100644','type':'blob','sha':blob['sha']})
    updated=api('git/trees','POST',{'base_tree':commit['tree']['sha'],'tree':tree},root)
    new=api('git/commits','POST',{'message':'Publish verified SITE benchmark results and index','tree':updated['sha'],'parents':[head['object']['sha']]},root)
    # Refuse to overwrite a branch that advanced while preparing the commit.
    api('git/refs/heads/'+branch,'PATCH',{'sha':new['sha'],'force':False},root)
    return new['sha']

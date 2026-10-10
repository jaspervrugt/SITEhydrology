"""Check local reference evidence against an immutable shared snapshot.

No basin data are downloaded and no submitted code is executed. This is a
cooperative client consistency check, not independent numerical verification.
"""
import hashlib,json,math,re,os,urllib.request
from pathlib import Path
from validate_submission import validate,read_json,number

def same_score(actual,expected):
    if actual is None or expected is None:return actual is None and expected is None
    return number(actual) and number(expected) and abs(actual-expected)<=1e-8+1e-6*abs(expected)

def receipt(candidate,manifest,baseline_bytes,revision):
    candidate,manifest=Path(candidate),Path(manifest)
    payload=read_json(candidate);approved=read_json(manifest);report=validate(payload,approved)
    proof=payload.get('localReferenceCheck')
    if not isinstance(proof,dict) or set(proof)!={'schema','mode','snapshotSha256','records'}:
        raise ValueError('Local reference check is required; retry from the updated SITE GUI')
    if proof['schema']!=1 or proof['mode']!='local_reference':raise ValueError('Unsupported reference check')
    if hashlib.sha256(baseline_bytes).hexdigest()!=proof['snapshotSha256']:raise ValueError('Reference snapshot checksum differs')
    baseline=json.loads(baseline_bytes)
    if baseline['profile']!=payload['profile'] or baseline['contract']!=payload['contract']:raise ValueError('Reference experiment differs')
    rows=payload['records'];rows=[rows] if isinstance(rows,dict) else rows
    evidence=proof['records'];evidence=[evidence] if isinstance(evidence,dict) else evidence
    if not isinstance(evidence,list) or len(evidence)>len(baseline['records']):raise ValueError('Invalid reference evidence')
    references={(r['basin'],r['metric']):r for r in baseline['records']};checked={}
    for r in evidence:
        if set(r)!={'basin','metric','train','evaluation'}:raise ValueError('Invalid evidence fields')
        key=(r['basin'],r['metric'])
        if key in checked or key not in references:raise ValueError('Unknown or duplicate reference')
        ref=references[key]
        if not same_score(r['train'],ref['train']) or not same_score(r['evaluation'],ref['evaluation']):raise ValueError('Local reference scores differ')
        checked[key]=r
    metrics=payload['contract']['metrics']
    for basin in {r['basin'] for r in rows}:
        if any((basin,m) not in checked for m in metrics):raise ValueError('All reference objectives must match for each contributing basin')
    return {'schema':1,'scores_verified':True,'verification_mode':'local_reference',
            'reference_snapshot_sha256':proof['snapshotSha256'],'profile':payload['profile'],
            'checked':report['records'],'verified_records':rows,'verifier_revision':revision,
            'candidate_sha256':hashlib.sha256(candidate.read_bytes()).hexdigest(),
            'manifest_sha256':hashlib.sha256(manifest.read_bytes()).hexdigest()}

def main():
    manifest=Path('benchmarks/profiles.json');pin=read_json(Path('benchmarks/core/core-pin.json'))
    revision=os.environ['TRUSTED_BASE_SHA']+':'+pin['sha256'];output=Path('verified-receipts');output.mkdir(exist_ok=True)
    for file in sorted(Path('verified-candidates').glob('*.json')):
        payload=read_json(file);proof=payload.get('localReferenceCheck',{});digest=proof.get('snapshotSha256','');profile=payload['profile']
        if not re.fullmatch(r'[0-9a-f]{64}',digest) or not re.fullmatch(r'[a-z][a-z0-9_]{0,99}',profile):raise ValueError('Missing approved reference identity')
        # Only snapshots from the owner's immutable release can be used.
        url=f'https://github.com/jaspervrugt/SITEhydrology/releases/download/site-benchmarks/{profile}_{digest}.json'
        with urllib.request.urlopen(url,timeout=90) as response:raw=response.read(20*1024*1024+1)
        if len(raw)>20*1024*1024:raise ValueError('Reference snapshot too large')
        result=receipt(file,manifest,raw,revision)
        (output/file.name).write_text(json.dumps(result))
        print(f"Local reference consistency accepted: {result['checked']} proposed fits; no dataset download.")

if __name__=='__main__':main()

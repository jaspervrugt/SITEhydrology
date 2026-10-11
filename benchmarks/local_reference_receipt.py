"""Check local reference evidence against an immutable shared snapshot.

No basin data are downloaded and no submitted code is executed. This is a
cooperative client consistency check, not independent numerical verification.
"""
import hashlib,json,math,re,os,urllib.request
from pathlib import Path
from validate_submission import validate,read_json,number

def same_score(actual,expected):
    if actual is None or expected is None:return actual is None and expected is None
    return number(actual) and number(expected) and abs(actual-expected)<=1e-8+1e-5*abs(expected)

def contract_identity(contract):
    # MATLAB represents unused product selectors as [] after JSON decoding.
    # Historical snapshots encode those same two unused fields as null.
    result=dict(contract)
    if isinstance(result.get('provenance'),dict):
        result['provenance']=dict(result['provenance'])
        for key in ('precip','temp'):
            if result['provenance'].get(key)==[]:result['provenance'][key]=None
    return result

def receipt(candidate,manifest,baseline_bytes,revision):
    candidate,manifest=Path(candidate),Path(manifest)
    payload=read_json(candidate);approved=read_json(manifest);report=validate(payload,approved)
    proof=payload.get('localReferenceCheck')
    base_fields={'schema','mode','snapshotSha256','records'}
    if not isinstance(proof,dict) or set(proof) not in (base_fields,base_fields|{'candidateRecords','inputFingerprints'}):
        raise ValueError('Local reference check is required; retry from the updated SITE GUI')
    if proof['schema'] not in (1,2) or proof['mode']!='local_reference':raise ValueError('Unsupported reference check')
    if hashlib.sha256(baseline_bytes).hexdigest()!=proof['snapshotSha256']:raise ValueError('Reference snapshot checksum differs')
    baseline=json.loads(baseline_bytes)
    if baseline['profile']!=payload['profile'] or contract_identity(baseline['contract'])!=contract_identity(payload['contract']):raise ValueError('Reference experiment differs')
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
    if proof['schema']==2:
        if 'candidateRecords' not in proof or 'inputFingerprints' not in proof:raise ValueError('Candidate replay and fingerprints required')
        replay=proof['candidateRecords'];replay=[replay] if isinstance(replay,dict) else replay
        proposed={(r['basin'],r['metric']):r for r in rows};seen=set()
        for r in replay:
            if set(r)!={'basin','metric','train','evaluation'}:raise ValueError('Invalid candidate replay fields')
            key=(r['basin'],r['metric'])
            if key in seen or key not in proposed:raise ValueError('Unknown or duplicate candidate replay')
            if not same_score(r['train'],proposed[key]['train']) or not same_score(r['evaluation'],proposed[key]['evaluation']):raise ValueError('Candidate replay scores differ')
            seen.add(key)
        if seen!=set(proposed):raise ValueError('Every proposed fit must be replayed')
        profiles=approved['profiles'];profiles=[profiles] if isinstance(profiles,dict) else profiles
        registered=next(p for p in profiles if p['id']==payload['profile'])
        trusted=registered.get('inputFingerprints')
        if not trusted:
            catalog_path=manifest.parent/'inputs.json'
            if not catalog_path.is_file():raise ValueError('Trusted dataset checksum catalog unavailable')
            catalog=read_json(catalog_path)
            if catalog.get('schema')!=1 or catalog.get('algorithm')!='sha256-input-v1':raise ValueError('Unsupported dataset checksum catalog')
            identity={k:payload['contract'][k] for k in ('resolution','provenance','period')}
            catalog_entries=catalog.get('entries',[])
            catalog_entries=[catalog_entries] if isinstance(catalog_entries,dict) else catalog_entries
            for entry in catalog_entries:
                if entry.get('complete') and entry.get('identity')==identity:
                    trusted=entry.get('inputFingerprints');break
        fingerprints=proof['inputFingerprints']
        if not trusted or fingerprints.get('schema')!=1 or fingerprints.get('algorithm')!='sha256-input-v1':raise ValueError('Trusted input fingerprints unavailable')
        hashes=trusted['records'];hashes=[hashes] if isinstance(hashes,dict) else hashes
        expected={r['basin']:r['sha256'] for r in hashes}
        entries=fingerprints.get('records',[]);entries=[entries] if isinstance(entries,dict) else entries
        found=set()
        for r in entries:
            if set(r)!={'basin','sha256'} or r['basin'] in found:raise ValueError('Invalid input fingerprint')
            if not re.fullmatch(r'[0-9a-f]{64}',r['sha256']) or expected.get(r['basin'])!=r['sha256']:raise ValueError('Input fingerprint differs')
            found.add(r['basin'])
        if found!={r['basin'] for r in rows}:raise ValueError('Every contributing basin requires a fingerprint')
    elif 'candidateRecords' in proof or 'inputFingerprints' in proof:
        raise ValueError('Unexpected legacy evidence')
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

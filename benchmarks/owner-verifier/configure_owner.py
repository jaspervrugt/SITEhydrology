"""Pin an owner-controlled installation; no credentials or data uploads."""
import argparse,hashlib,json
from pathlib import Path
HERE=Path(__file__).resolve().parent
def configure(core,site,data,matlab):
 roots=[core/'src',core/'utils',core/'models',core/'regions',site/'utils',core.parent/'user_model']
 suffixes={'.m','.mat','.mexw64','.mexmaci64','.mexmaca64','.cpp','.hpp','.h','.json'}
 files={p.resolve() for root in roots if root.is_dir() for p in root.rglob('*') if p.is_file() and p.suffix.lower() in suffixes}
 files.update((HERE/name).resolve() for name in ['owner_worker.py','validate_initial.py','site_benchmark_owner_initial.m','site_benchmark_initial_defaults.m','site_benchmark_owner_export.m'])
 files.update(p.resolve() for p in (HERE/'lib').glob('*.py'))
 entries=[{'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(files)]
 config={'schema':1,'core':str(core.resolve()),'site':str(site.resolve()),'data':str(data.resolve()),'matlab':str(matlab.resolve()),'state':str(HERE/'state'),'trustedFiles':entries}
 (HERE/'owner-config.json').write_text(json.dumps(config,indent=2));print('Owner installation pinned: '+str(len(entries))+' trusted files; credentials remain in GitHub CLI storage.')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--core',type=Path,required=True);p.add_argument('--site',type=Path,required=True);p.add_argument('--data',type=Path,required=True);p.add_argument('--matlab',type=Path,required=True);a=p.parse_args();configure(a.core,a.site,a.data,a.matlab)

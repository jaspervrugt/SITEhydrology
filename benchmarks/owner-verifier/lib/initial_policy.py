"""Trusted default-experiment gate, shared by the App and GitHub validator."""
import json
from functools import lru_cache
from pathlib import Path


class InitialDefaultsError(ValueError):
    pass


@lru_cache(maxsize=1)
def catalogue():
    return json.loads(Path(__file__).with_name('site_initial_defaults.json').read_text(encoding='utf-8'))


def canonical(value):
    if value is None:
        return []
    if isinstance(value, dict):
        return {k:canonical(v) for k,v in value.items()}
    if isinstance(value,list):
        return [canonical(v) for v in value]
    return value


def require_contract(contract, records=()):
    region=contract.get('provenance',{}).get('region')
    key='|'.join(str(v) for v in (region,contract.get('resolution'),contract.get('model')))
    expected=catalogue()['contracts'].get(key)
    if expected is None:
        raise InitialDefaultsError('First uploads require a registered public model and dataset/resolution. Results remain local.')
    changed=[k for k in sorted(set(expected)|set(contract))
             if k not in expected or k not in contract or
             canonical(expected[k]) != canonical(contract[k])]
    for row in records:
        bounds=row.get('parameterRange',contract)
        if any(bounds.get(k)!=expected[k] for k in ('thMin','thMax')):
            changed.append('parameter bounds');break
    if changed:
        raise InitialDefaultsError('First uploads require the SITE GUI scientific defaults. Changed: '
            +', '.join(changed)+'. Results remain local.')
    return expected


def require_config(config):
    from site_shared_results import contract
    import hashlib
    from reader_identity import metadata_file
    if hashlib.sha256(metadata_file(config['sage_root']).read_bytes()).hexdigest()!=catalogue()['metadata_sha256']:
        raise InitialDefaultsError('Installed GUI defaults differ from the approved first-upload catalogue. Results remain local.')
    changed=[]
    if config.get('backend','cpp')!='cpp':changed.append('backend')
    if not config.get('evaluation_enabled',True):changed.append('evaluation period')
    if config.get('config',[1.,1e-6,.01]) != [1.,1e-6,.01]:changed.append('model constants')
    if int(config.get('model',0)) not in range(1,8):
        changed.append('unregistered/private model')
    else:
        from sage_model_view import definition
        if set(config.get('model_config',{}))-set(definition(config['model'])['config']):
            changed.append('unregistered model constants')
    if changed:
        raise InitialDefaultsError('First uploads require scientific defaults. Changed: '
                                   +', '.join(changed)+'. Results remain local.')
    return require_contract(contract(config))

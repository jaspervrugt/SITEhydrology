"""Native destinations derived exclusively from administrator-owned profiles."""
import re

def result_paths(profile):
    c = profile['contract']
    region, resolution, model, tag = (c['provenance']['region'], c['resolution'],
                                      c['model'], c['provenance']['tag'])
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]{0,79}', region):
        raise ValueError('Unsafe region')
    if resolution not in {'daily', 'hourly', '15min'}:
        raise ValueError('Unsafe resolution')
    if not all(re.fullmatch(r'[A-Za-z][A-Za-z0-9_]{0,79}', v) for v in (model, tag)):
        raise ValueError('Unsafe model or forcing tag')
    root = f'results/{region}/{resolution}/period_001/{tag}'
    suffix = f'{model}_{resolution}_{tag}_p001'
    return [f'{root}/SITE_{suffix}_checkpoint.mat', f'{root}/param_{suffix}.xlsx',
            f'{root}/model_master_{resolution}_{tag}_p001.xlsx',
            f'{root}/param_ranges_{model}_{resolution}.csv']

def approved_paths(manifest):
    rows = manifest['profiles']
    if isinstance(rows, dict):
        rows = [rows]
    return {path for row in rows if row['enabled'] for path in result_paths(row)}

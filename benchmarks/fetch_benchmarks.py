"""Fetch the latest immutable snapshots before a trusted worker merges fits."""
import base64
import hashlib
import json
import re
import subprocess
import urllib.request
from pathlib import Path
from publish_verified import atomic_write, canonical

REPO = 'jaspervrugt/SITEhydrology'


def fetch(root):
    root = Path(root)
    root.mkdir(parents=True, exist_ok=True)
    response = subprocess.run(['gh', 'api', f'repos/{REPO}/contents/benchmarks/index.json'],
                              capture_output=True, text=True)
    if response.returncode:
        if 'HTTP 404' not in response.stderr:
            raise RuntimeError('Cannot read the latest benchmark index')
        atomic_write(root / 'index.json', canonical({'schema': 1, 'profiles': {}}))
        return None
    item = json.loads(response.stdout)
    index = json.loads(base64.b64decode(item['content']))
    if index.get('schema') != 1 or not isinstance(index.get('profiles'), dict):
        raise ValueError('Unsupported benchmark index')
    for profile, entry in index['profiles'].items():
        if not re.fullmatch(r'[a-z][a-z0-9_]{0,99}', profile):
            raise ValueError('Unsafe benchmark profile')
        digest = entry['sha256']
        if not re.fullmatch(r'[0-9a-f]{64}', digest):
            raise ValueError('Invalid snapshot hash')
        path = f'snapshots/{profile}/{digest}.json'
        url = f'https://github.com/{REPO}/releases/download/site-benchmarks/{profile}_{digest}.json'
        if entry['path'] != path or entry.get('downloadUrl') != url:
            raise ValueError('Unexpected benchmark snapshot location')
        with urllib.request.urlopen(url, timeout=90) as source:
            data = source.read(20 * 1024 * 1024 + 1)
        if len(data) > 20 * 1024 * 1024 or hashlib.sha256(data).hexdigest() != digest:
            raise ValueError('Downloaded benchmark checksum differs')
        snapshot = json.loads(data)
        if snapshot.get('profile') != profile or snapshot.get('schema') != 1:
            raise ValueError('Snapshot profile differs')
        atomic_write(root / path, data)
    atomic_write(root / 'index.json', canonical(index))
    return item['sha']

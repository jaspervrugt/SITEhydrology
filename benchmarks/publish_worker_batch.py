"""Trusted publisher job: current defaults, newest snapshots, verified fits."""
import base64
import hashlib
import json
import os
import subprocess
from pathlib import Path
from fetch_benchmarks import fetch
from publish_verified import publish
from deliver_snapshots import deliver


def main():
    base = Path('benchmarks')
    manifest = base / 'profiles.json'
    # A profile removed/changed during verification must not still publish.
    remote = json.loads(subprocess.check_output([
        'gh', 'api', 'repos/jaspervrugt/SITEhydrology/contents/benchmarks/profiles.json'], text=True))
    if hashlib.sha256(base64.b64decode(remote['content'])).digest() != hashlib.sha256(manifest.read_bytes()).digest():
        raise RuntimeError('Approved defaults changed during verification; revalidate')
    root = Path('publication')
    expected_sha = fetch(root)
    pin = json.loads((base / 'core/core-pin.json').read_text())
    revision = os.environ['TRUSTED_BASE_SHA'] + ':' + pin['sha256']
    changed = False
    for candidate in sorted(Path('verified-candidates').glob('*.json')):
        receipt = Path('verified-receipts') / candidate.name
        report = publish(candidate, manifest, receipt, root, revision)
        changed |= report['published']
        print(json.dumps(report))
    if changed:
        deliver(root, expected_sha)
    print('Verified contributions processed; original snapshots preserved.')


if __name__ == '__main__':
    main()

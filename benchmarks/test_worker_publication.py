"""End-to-end worker smoke publication; never writes to GitHub."""
import json
import os
from pathlib import Path
from publish_verified import publish

root = Path.cwd()
pin = json.loads((root / 'benchmarks/core/core-pin.json').read_text())
revision = os.environ['GITHUB_SHA'] + ':' + pin['sha256']
args = (root / 'benchmarks/tests/hbv_candidate.json',
        root / 'benchmarks/tests/profiles.json', root / 'worker-receipt.json',
        root / 'worker-publication', revision)
report = publish(*args)
assert report['published'] and report['improvements'] == 1
again = publish(*args)
assert not again['published'] and again['improvements'] == 0
print('Remote numerical verification and immutable publication passed.')

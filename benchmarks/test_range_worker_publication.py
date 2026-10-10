"""End-to-end worker smoke publication; never writes to GitHub."""
import json
import os
from pathlib import Path
from publish_verified import publish

root = Path.cwd()
pin = json.loads((root / 'benchmarks/core/core-pin.json').read_text())
revision = os.environ['GITHUB_SHA'] + ':' + pin['sha256']
args = (root / 'benchmarks/tests/range_candidate.json',
        root / 'benchmarks/tests/profiles.json', root / 'worker-receipt.json',
        root / 'worker-publication', revision)
report = publish(*args)
payload = json.loads(args[0].read_text())
records = payload['records']
assert report['published'] and report['improvements'] == len(records)
again = publish(*args)
assert not again['published'] and again['improvements'] == 0
print('Remote numerical verification and immutable publication passed.')

snapshot=json.loads((args[3]/report["entry"]["path"]).read_text())
assert len(snapshot["parameterRanges"])==2
assert all(r["parameterRange"]["id"]==2 for r in snapshot["records"])
print("Changed bounds independently verified and shared range ID registered.")

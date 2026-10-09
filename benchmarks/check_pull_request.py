"""Fetch candidate JSON blobs as data; no checkout of untrusted PR code."""
import base64
import hashlib
import json
import os
import re
import tempfile
import urllib.request
from pathlib import Path
from validate_submission import validate, read_json, MAX_BYTES


def api(path):
    request = urllib.request.Request("https://api.github.com/" + path, headers={
        "Authorization": "Bearer " + os.environ["GH_TOKEN"],
        "Accept": "application/vnd.github+json", "User-Agent": "SITE-validator"})
    with urllib.request.urlopen(request, timeout=30) as response:
        data = response.read(MAX_BYTES * 2 + 1)
    if len(data) > MAX_BYTES * 2:
        raise ValueError("API response exceeds limit")
    return json.loads(data)


repo, number = os.environ["REPOSITORY"], int(os.environ["PR_NUMBER"])
pr = api(f"repos/{repo}/pulls/{number}")
if pr["changed_files"] > 20:
    raise ValueError("Too many files in benchmark proposal")
files = api(f"repos/{repo}/pulls/{number}/files?per_page=100")
manifest = json.loads(Path("benchmarks/profiles.json").read_text())
for file in files:
    if not re.fullmatch(r"benchmarks/inbox/[0-9a-f]{64}\.json", file["filename"]):
        raise ValueError("Benchmark proposal must contain numerical inbox files only")
    if file["status"] not in {"added", "modified"}:
        raise ValueError("Deletion/rename is not a contribution")
    # Git blobs are addressed by content hash, not arbitrary supplied URLs.
    blob = api(f"repos/{repo}/git/blobs/{file['sha']}")
    if blob["size"] > MAX_BYTES or blob["encoding"] != "base64":
        raise ValueError("Invalid blob")
    raw = base64.b64decode(blob["content"])
    digest = hashlib.sha256(raw).hexdigest()
    if file["filename"] != f"benchmarks/inbox/{digest}.json":
        raise ValueError("Candidate digest mismatch")
    with tempfile.TemporaryDirectory() as tmp:
        candidate = Path(tmp) / 'candidate.json'
        candidate.write_bytes(raw)
        report = validate(read_json(candidate), manifest)
    print(json.dumps(report))
print("Structural validation only. Independent score verification is still required.")

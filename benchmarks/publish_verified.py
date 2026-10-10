"""Trusted-worker publication with immutable snapshots and an atomic index.

Only invoke inside the private numerical worker. Never accept a verification
receipt supplied by a contributor or taken from the proposal branch.
This module prepares a local publication tree; GitHub delivery is separate.
"""
import hashlib
import json
import os
import tempfile
from pathlib import Path
from validate_submission import read_json, validate, vector


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      allow_nan=False).encode("utf-8")


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(dir=path.parent, prefix=".pending-")
    try:
        with os.fdopen(fd, "wb") as file:
            file.write(data)
            file.flush()
            os.fsync(file.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def publish(candidate_file, manifest_file, receipt_file, root, verifier_revision):
    root = Path(root)
    root.mkdir(parents=True, exist_ok=True)
    # Refuse simultaneous writes, even when callers forget job serialization.
    lock = root / ".publication-lock"
    try:
        lock.mkdir()
    except FileExistsError:
        raise RuntimeError("Another publication is active; retry later")
    try:
        return _publish(Path(candidate_file), Path(manifest_file),
                        Path(receipt_file), root, verifier_revision)
    finally:
        lock.rmdir()


def _publish(candidate_file, manifest_file, receipt_file, root, verifier_revision):
    payload, manifest, receipt = (read_json(path) for path in
                                (candidate_file, manifest_file, receipt_file))
    validation = validate(payload, manifest)
    digest = hashlib.sha256(candidate_file.read_bytes()).hexdigest()
    manifest_digest = hashlib.sha256(manifest_file.read_bytes()).hexdigest()
    if not (receipt.get("scores_verified") is True
            and receipt.get("candidate_sha256") == digest
            and receipt.get("manifest_sha256") == manifest_digest
            and receipt.get("profile") == payload["profile"]
            and receipt.get("checked") == validation["records"]
            and receipt.get("verifier_revision") == verifier_revision):
        raise ValueError("Trusted numerical verification does not cover this candidate")
    verified_records = receipt.get("verified_records")
    if isinstance(verified_records, dict):
        verified_records = [verified_records]
    if not isinstance(verified_records, list) or len(verified_records) != validation["records"]:
        raise ValueError("Missing independently recomputed records")
    verified_payload = dict(payload, records=verified_records)
    validate(verified_payload, manifest)
    submitted_records = payload["records"]
    if isinstance(submitted_records, dict):
        submitted_records = [submitted_records]
    for original, verified in zip(submitted_records, verified_records):
        if {k: v for k, v in original.items() if k not in {"train", "evaluation"}} != {
                k: v for k, v in verified.items() if k not in {"train", "evaluation"}}:
            raise ValueError("Verification receipt changed parameters or provenance")
    profile_list = manifest["profiles"]
    if isinstance(profile_list, dict):
        profile_list = [profile_list]
    profile = next(p for p in profile_list if p["id"] == payload["profile"])
    profile_id = profile["id"]
    # Approved IDs must be safe path components; no client path is accepted.
    import re
    if not re.fullmatch(r"[a-z][a-z0-9_]{0,99}", profile_id):
        raise ValueError("Unsafe profile identifier")
    index_file = root / "index.json"
    index = read_json(index_file) if index_file.exists() else {"schema": 1, "profiles": {}}
    previous = index["profiles"].get(profile_id)
    if previous:
        snapshot_path = root / previous["path"]
        raw = snapshot_path.read_bytes()
        if hashlib.sha256(raw).hexdigest() != previous["sha256"]:
            raise ValueError("Existing benchmark checksum mismatch")
        snapshot = json.loads(raw)
        if snapshot["contract"] != payload["contract"]:
            raise ValueError("Existing benchmark experiment differs")
    else:
        snapshot = {"schema": 1, "profile": profile_id,
                    "contract": payload["contract"], "records": []}
    metrics = profile["contract"]["metrics"]
    directions = profile["contract"]["maximize"]
    if isinstance(directions, bool):
        directions = [directions]
    maximize = dict(zip(metrics, directions))
    defaults={'id':1,'thMin':vector(profile['contract']['thMin']), 'thMax':vector(profile['contract']['thMax'])}
    ranges=snapshot.get('parameterRanges',[defaults])
    if isinstance(ranges,dict):ranges=[ranges]
    for old in snapshot['records']:
        if 'parameterRange' not in old:old['parameterRange']=dict(defaults)
    by_key = {(r["basin"], r["metric"]): r for r in snapshot["records"]}
    records = verified_records
    if isinstance(records, dict):
        records = [records]
    improved = 0
    for r in records:
        key = r["basin"], r["metric"]
        old = by_key.get(key)
        better = old is None or (r["train"] > old["train"] if maximize[r["metric"]]
                                 else r["train"] < old["train"])
        if better:
            r=dict(r)
            bounds=r.get('parameterRange',defaults)
            same=next((p for p in ranges if vector(p['thMin'])==vector(bounds['thMin']) and vector(p['thMax'])==vector(bounds['thMax'])),None)
            if same is None:
                same={'id':max(p['id'] for p in ranges)+1,'thMin':vector(bounds['thMin']),'thMax':vector(bounds['thMax'])}
                ranges.append(same)
            r['parameterRange']=dict(same)
            by_key[key] = r
            improved += 1
    if not improved:
        return {"improvements": 0, "published": False}
    snapshot["records"] = [by_key[k] for k in sorted(by_key)]
    snapshot['parameterRanges']=ranges
    raw = canonical(snapshot)
    sha = hashlib.sha256(raw).hexdigest()
    relative = f"snapshots/{profile_id}/{sha}.json"
    destination = root / relative
    # Content-addressed snapshots are never overwritten with different data.
    if destination.exists() and destination.read_bytes() != raw:
        raise ValueError("Snapshot digest collision")
    if not destination.exists():
        atomic_write(destination, raw)
    entry = {"path": relative, "sha256": sha,
             "original": previous["original"] if previous else relative,
             "previous": previous["path"] if previous else None,
             "records": len(snapshot["records"])}
    index["profiles"][profile_id] = entry
    # Update the pointer only after the immutable snapshot is durable.
    atomic_write(index_file, canonical(index))
    return {"improvements": improved, "published": True, "entry": entry}

"""Validate an untrusted JSON proposal; never execute or publish its contents.

Passing this check does not verify model scores or compiled-app provenance.
Only trusted, independent numerical verification can authorize publication.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

MAX_BYTES = 20 * 1024 * 1024


def read_json(path):
    if path.stat().st_size > MAX_BYTES:
        raise ValueError("Submission exceeds size limit")

    def unique_keys(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("Duplicate JSON key")
            result[key] = value
        return result

    def bad_constant(_):
        raise ValueError("Nonstandard JSON number")

    return json.loads(path.read_text(encoding="utf-8"),
                      object_pairs_hook=unique_keys, parse_constant=bad_constant)


def number(value):
    return type(value) in (int, float) and math.isfinite(value)


def vector(value):
    # MATLAB jsonencode writes a single parameter as a scalar and columns
    # as arrays. Normalize only that documented numeric representation.
    if number(value):
        return [value]
    if not isinstance(value, list):
        raise ValueError("Expected numeric vector")
    result = []
    for item in value:
        if isinstance(item, list) and len(item) == 1:
            item = item[0]
        if not number(item):
            raise ValueError("Non-finite vector")
        result.append(item)
    return result


def validate(payload, manifest):
    if payload.get("schema") != 1:
        raise ValueError("Unsupported submission schema")
    if set(payload) != {"schema", "origin", "contract", "records", "profile"}:
        raise ValueError("Unexpected submission fields")
    approved_profiles = manifest["profiles"]
    if isinstance(approved_profiles, dict):
        approved_profiles = [approved_profiles]
    profiles = [p for p in approved_profiles
                if p.get("enabled") and p["id"] == payload["profile"]]
    if len(profiles) != 1:
        raise ValueError("Experiment is not approved")
    profile = profiles[0]
    if payload["contract"] != profile["contract"]:
        raise ValueError("Experiment contract differs from approved defaults")
    bounds_low = vector(profile["contract"]["thMin"])
    bounds_high = vector(profile["contract"]["thMax"])
    if len(bounds_low) != len(bounds_high):
        raise ValueError("Approved bounds are invalid")
    ids = set(profile["basinIds"])
    metrics = set(profile["contract"]["metrics"])
    records = payload["records"]
    if isinstance(records, dict):
        records = [records]
    if not isinstance(records, list) or not 0 < len(records) <= len(ids) * len(metrics):
        raise ValueError("Unexpected number of records")
    allowed = {"basin", "metric", "train", "evaluation", "theta", "normalized",
               "optimizedLoss", "optimizer", "runtime", "updated"}
    seen = set()
    for r in records:
        if set(r) != allowed:
            raise ValueError("Unexpected record fields")
        key = r["basin"], r["metric"]
        if key[0] not in ids or key[1] not in metrics or key in seen:
            raise ValueError("Unknown or duplicate basin/metric")
        seen.add(key)
        if not number(r["train"]):
            raise ValueError("Invalid training score")
        if r["evaluation"] is not None and not number(r["evaluation"]):
            raise ValueError("Invalid evaluation score")
        theta, normalized = vector(r["theta"]), vector(r["normalized"])
        if len(theta) != len(bounds_low) or len(normalized) != len(theta):
            raise ValueError("Parameter dimensions differ")
        if any(not lo <= x <= hi for x, lo, hi in zip(theta, bounds_low, bounds_high)):
            raise ValueError("Parameters outside approved bounds")
        if any(not 0 <= x <= 1 for x in normalized):
            raise ValueError("Normalized parameters outside bounds")
        if not isinstance(r["optimizedLoss"], str) or not r["optimizedLoss"]:
            raise ValueError("Missing optimization provenance")
        if not number(r["runtime"]) or r["runtime"] < 0:
            raise ValueError("Invalid runtime")
        if not number(r["optimizer"]) or not isinstance(r["updated"], str):
            raise ValueError("Invalid provenance")
    return {"profile": profile["id"], "records": len(records),
            "schema_valid": True, "scores_verified": False,
            "publication_allowed": False}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--profiles", type=Path, required=True)
    args = parser.parse_args()
    report = validate(read_json(args.candidate), read_json(args.profiles))
    report["sha256"] = hashlib.sha256(args.candidate.read_bytes()).hexdigest()
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()

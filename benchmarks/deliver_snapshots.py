"""Trusted publisher: immutable release assets first, latest index last.

Requires owner/worker GitHub authorization, never a contributor token.
No asset overwrite is allowed. Caller must hold the publication job lock and
provide the index commit SHA seen before preparing its merged snapshots.
"""
import argparse
import base64
import hashlib
import json
import subprocess
from pathlib import Path

REPO = "jaspervrugt/SITEhydrology"
TAG = "site-benchmarks"


def draft_release():
    pages = json.loads(subprocess.check_output(
        ["gh", "api", "--paginate", "--slurp", f"repos/{REPO}/releases?per_page=100"], text=True, encoding="utf-8"))
    matches = [r for page in pages for r in page if r["tag_name"] == TAG]
    if len(matches) > 1:
        raise RuntimeError("Duplicate benchmark test releases")
    if matches and not matches[0]["draft"]:
        raise RuntimeError("Benchmark test release must remain unpublished")
    return matches[0] if matches else None


def deliver(root, expected_sha, *, branch='main', index_path='benchmarks/index.json', draft=False, mirror_plan=None):
    root = Path(root)
    index = json.loads((root / "index.json").read_text())
    # Fail before any mutation if the latest index has changed in the meantime.
    response = subprocess.run(["gh", "api", f"repos/{REPO}/contents/{index_path}?ref={branch}"],
                              capture_output=True, text=True, encoding="utf-8")
    current = json.loads(response.stdout) if response.returncode == 0 else None
    if response.returncode and "HTTP 404" not in response.stderr:
        raise RuntimeError("Cannot read the current benchmark index")
    if (current["sha"] if current else None) != expected_sha:
        raise RuntimeError("Benchmark index changed; fetch and merge the latest version again")
    existing_draft = draft_release() if draft else None
    release = subprocess.run(["gh", "api", f"repos/{REPO}/releases/tags/{TAG}"],
                             capture_output=True, text=True, encoding="utf-8")
    if release.returncode and existing_draft is None:
        if "HTTP 404" not in release.stderr:
            raise RuntimeError("Cannot read the benchmark release")
        command = ["gh", "release", "create", TAG, "--repo", REPO,
                        "--title", "Shared SITE benchmarks", "--notes",
                        "Verified default-setting benchmarks with immutable recovery snapshots.",
                        "--latest=false"]
        if draft:
            command.append('--draft')
        subprocess.run(command, check=True)
    release_data = draft_release() if draft else json.loads(subprocess.check_output(
        ["gh", "api", f"repos/{REPO}/releases/tags/{TAG}"], text=True, encoding="utf-8"))
    assets = release_data["assets"]
    known = {a["name"]: a for a in assets}
    for profile, entry in index["profiles"].items():
        source = root / entry["path"]
        if hashlib.sha256(source.read_bytes()).hexdigest() != entry["sha256"]:
            raise ValueError("Snapshot checksum mismatch")
        name = f"{profile}_{entry['sha256']}.json"
        if name not in known:
            # gh's # syntax changes the asset label, not its filename;
            # stage the exact immutable asset name in the local output tree.
            staged = root / name
            staged.write_bytes(source.read_bytes())
            subprocess.run(["gh", "release", "upload", TAG, str(staged),
                            "--repo", REPO], check=True)
        else:
            # A matching name is not sufficient: verify GitHub's digest.
            digest = known[name].get("digest")
            if digest is None:
                data = subprocess.check_output(['gh', 'api',
                    f"repos/{REPO}/releases/assets/{known[name]['id']}",
                    '--header', 'Accept: application/octet-stream'])
                digest = 'sha256:' + hashlib.sha256(data).hexdigest()
            if digest != "sha256:" + entry["sha256"]:
                raise ValueError("Existing immutable asset digest differs")
        entry["downloadUrl"] = f"https://github.com/{REPO}/releases/download/{TAG}/{name}"
    if mirror_plan is not None:
        from deliver_result_files import deliver_atomic_results
        deliver_atomic_results(root,index,mirror_plan,branch,index_path,expected_sha)
        return
    body = {"message": "Publish verified SITE benchmark index",
            "branch": branch, "content": base64.b64encode(
                json.dumps(index, sort_keys=True, separators=(",", ":")).encode()).decode()}
    if expected_sha:
        body["sha"] = expected_sha
    request = root / "index-request.json"
    request.write_text(json.dumps(body))
    # Contents API's SHA check prevents silently overwriting a concurrent update.
    subprocess.run(["gh", "api", f"repos/{REPO}/contents/{index_path}",
                    "--method", "PUT", "--input", str(request)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--expected-index-sha", default=None)
    args = parser.parse_args()
    deliver(args.root, args.expected_index_sha)

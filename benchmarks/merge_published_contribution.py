"""Merge numerical-only contributions after trusted verification/publication.

Called only by the publication workflow's dependent job. Initial references
remain manual. Never execute contributor code or merge a newer, unchecked head.
"""
import json
import os
import re
import subprocess
import urllib.request


def api(path, method="GET", body=None):
    request = urllib.request.Request(
        "https://api.github.com/" + path,
        data=None if body is None else json.dumps(body).encode(),
        method=method,
        headers={"Authorization": "Bearer " + os.environ["GH_TOKEN"],
                 "Accept": "application/vnd.github+json",
                 "Content-Type": "application/json",
                 "User-Agent": "SITE-benchmark-merger"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def eligible(pr, files, expected):
    if pr["state"] != "open" or pr["head"]["sha"] != expected:
        return False
    if pr["base"]["ref"] != "main":
        return False
    return (0 < pr["changed_files"] <= 20
            and len(files) == pr["changed_files"]
            and all(re.fullmatch(r"benchmarks/inbox/[0-9a-f]{64}\.json", f["filename"])
                    and f["status"] in {"added", "modified"} for f in files))


def main():
    repo = os.environ["REPOSITORY"]
    number = int(os.environ["PR_NUMBER"])
    expected = os.environ["EXPECTED_HEAD_SHA"]
    path = f"repos/{repo}/pulls/{number}"
    pr = api(path)
    files = api(path + "/files?per_page=100")
    if not eligible(pr, files, expected):
        print("Contribution changed, closed, or contains non-inbox files; leaving unmerged.")
        return
    if pr["draft"]:
        subprocess.run(["gh", "pr", "ready", str(number), "--repo", repo], check=True)
    # GitHub atomically rejects a changed head and enforces branch protection.
    result = api(path + "/merge", "PUT", {"sha": expected, "merge_method": "squash"})
    if not result.get("merged"):
        raise RuntimeError("GitHub did not merge the published contribution")
    print("Published numerical contribution merged.")


if __name__ == "__main__":
    main()

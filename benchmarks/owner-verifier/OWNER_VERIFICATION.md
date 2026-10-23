# First benchmark verification on the owner's computer

SITE submits first results as a `SITE initial reference:` pull request containing numerical JSON only. Any contributor can propose a first reference. The trusted GitHub validator and App reject nondefault scientific settings; the request does not become a default on upload or merge. They remain unavailable as benchmarks until the owner worker passes the following checks:

1. The experiment matches the installed GUI defaults for the dataset, resolution and public model, including periods, spin-up, default forcing/PET, default bounds, initial states, additional variables and numerical solver. The trusted `lib/site_initial_defaults.json` allowlist also enforces these settings in GitHub validation. Optimizer, trial count and stopping budgets may differ.
2. Prepared forcing and observations match the submitted SHA-256 input fingerprints.
3. Trusted local model code replays the submitted parameter values and reproduces their metrics. The existing numerical tolerances apply.

The worker uses the owner's installed Data and trusted SAGE/SITE code. It never checks out a contributor's code and never downloads hydrological data on GitHub. Authenticated contributor, platform, run counts and improvement counts accompany the winning fit. A platform value identifies the producing platform reported by SITE.

After verification, an atomic GitHub commit registers the reference and publishes its snapshot, native checkpoint, parameter workbook, parameter ranges and model summary. Concurrent archive changes cause a safe retry against the new version. Failed checks remain unpublished for owner review. Existing unregistered native archives are held for review rather than overwritten.

The seven registered public model implementations are supported. Custom and private model definitions remain local and need a separate reviewed default registration.

## Owner review and notification

The trusted `pull_request_target` workflow validates numerical JSON using base-branch code, then requests `jaspervrugt` as reviewer. GitHub email delivery follows the owner's notification preferences. It never executes a contributor's source or workflows. Legacy draft proposals receive a single owner mention instead.

For an external contributor, the worker requires an APPROVED review by `jaspervrugt` on the exact current PR head. Changed or dismissed approvals do not authorize publication. Owner-authored requests count as explicit owner authorization. Approval allows trusted numerical replay; publication still requires all fingerprint and score checks to pass. Approval is checked again immediately before publication. Unapproved requests remain queued.

The client and server policy files must be regenerated together when authoritative GUI defaults change; do not copy a contributor's contract into the allowlist.

## Owner installation

Run `configure_owner.py` with `--core`, `--site`, `--data` and `--matlab` pointing to the trusted local installations. This writes a private owner-config.json with source hashes. Do not commit this file or the state directory. Use an owner GitHub CLI sign-in; no credentials are copied into submissions.

Run `owner_worker.py` periodically. It handles one request at a time, with up to four MATLAB workers, and waits whenever SITE is open. On Windows its MATLAB process is hidden and uses below-normal priority. The computer must be on and the scheduler available. Requests wait while it is off. Source changes require an explicitly refreshed trusted installation; the scheduler must never refresh source pins automatically.

The scheduled Codex check stays quiet when there is no request or SITE is open. It reports publication or a new request needing owner review. Transient publication failures remain queued. A first verified numerical fixture, changed-input rejection, inflated-metric rejection, native export, default-contract checks and worker unit tests validate this implementation. Actual first-region publication is exercised when a first request arrives.

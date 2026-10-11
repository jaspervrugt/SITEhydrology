# First benchmark verification on the owner's computer

SITE submits first results as a draft `SITE initial reference:` request containing numerical JSON only. They remain unavailable as benchmarks until the owner worker passes the following checks:

1. The experiment matches the installed GUI defaults for the dataset and resolution, including periods, spin-up, initial states, additional variables and numerical solver. Supported forcing/PET choices and registered parameter ranges are retained.
2. Prepared forcing and observations match the submitted SHA-256 input fingerprints.
3. Trusted local model code replays the submitted parameter values and reproduces their metrics. The existing numerical tolerances apply.

The worker uses the owner's installed Data and trusted SAGE/SITE code. It never checks out a contributor's code and never downloads hydrological data on GitHub. Authenticated contributor, platform, run counts and improvement counts accompany the winning fit. A platform value identifies the producing platform reported by SITE.

After verification, an atomic GitHub commit registers the reference and publishes its snapshot, native checkpoint, parameter workbook, parameter ranges and model summary. Concurrent archive changes cause a safe retry against the new version. Failed checks remain unpublished for owner review. Existing unregistered native archives are held for review rather than overwritten.

The public model implementations and supplied GR4J-B user_model are supported. Custom or private model definitions need a separate trusted setup.

## Owner installation

Run `configure_owner.py` with `--core`, `--site`, `--data` and `--matlab` pointing to the trusted local installations. This writes a private owner-config.json with source hashes. Do not commit this file or the state directory. Use an owner GitHub CLI sign-in; no credentials are copied into submissions.

Run `owner_worker.py` periodically. It handles one request at a time, with up to four MATLAB workers, and waits whenever SITE is open. On Windows its MATLAB process is hidden and uses below-normal priority. The computer must be on and the scheduler available. Requests wait while it is off. Source changes require an explicitly refreshed trusted installation; the scheduler must never refresh source pins automatically.

The scheduled Codex check stays quiet when there is no request or SITE is open. It reports publication or a new request needing owner review. Transient publication failures remain queued. A first verified numerical fixture, changed-input rejection, inflated-metric rejection, native export, default-contract checks and worker unit tests validate this implementation. Actual first-region publication is exercised when a first request arrives.

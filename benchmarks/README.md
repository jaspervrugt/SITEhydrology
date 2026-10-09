# Shared SITE benchmarks: setup and current status

The proposal workflow is an initial pilot, not automatic benchmark publication.
Existing results stay unchanged. No experiment is approved yet: profiles.json
has an intentionally empty allowlist.

Local prototype status: MATLAB independently recomputed a real CAMELS-US/HBV
fit and rejected an inflated score. Its hash-bound receipt successfully fed
the immutable snapshot publisher, and MATLAB imported that snapshot back into
SITE's result schema. Nine Python validation/publication tests pass.

## Authentication

Register an OAuth application in https://github.com/settings/developers:

- Application name: SITE benchmark contributions
- Homepage: https://github.com/jaspervrugt/SITEhydrology
- Callback URL: https://github.com/login/device (unused by device flow)
- Enable Device Flow

The public Client ID is configured locally in utils/results/site_benchmark_github.json.
No client secret should be generated for, embedded in, or shared with SITE.
The configuration remains enabled=false until end-to-end tests pass.

The GUI offers contribution after a compiled run; it signs the contributor
into GitHub and creates a draft pull request through their fork. It does not
grant users permission to change the shared benchmark repository. Tokens are
kept only in memory. OAuth public_repo allows access to the user's public
repositories; GitHub displays the authorization consent. A future GitHub App
can narrow repository permissions further.

## Experiment manifest

Each approved profile specifies a stable ID, enabled flag, exact experiment
contract, and complete basinIds allowlist. Dataset/model revisions, dates,
spin-up, model configuration, parameter bounds, solver and loss-definition
settings belong in the contract. The selected optimization target, optimizer,
trial count and algorithmic options do not.

Do not infer defaults from p001 or filenames. Older result files lack some
configuration metadata and need verification before becoming trusted seeds.
If a verified profile has no benchmark yet, a verified first contribution can
seed it; a new arbitrary profile cannot auto-enroll itself.

## Validation and publication

The CI workflow runs only validation code from the trusted base commit. It
reads JSON numerical proposals as data and rejects other changed files,
oversized submissions, unknown profiles, duplicate/unknown basin IDs,
nonfinite training scores and parameters outside approved bounds.

These checks do NOT verify the supplied scores. The worker MATLAB functions
independently evaluate submitted parameter vectors using administrator-owned
configuration and data. site_benchmark_verify_file binds its receipt to the
candidate bytes, approved manifest and pinned verifier revision. Publication
uses the recomputed scores rather than the client's rounded values.

Receipts must stay in the trusted worker's private output area. Never accept
a receipt attached to a contribution. Client origin labels and isdeployed do
not prove provenance. There is no automatic numerical worker online yet.

Final publication must serialize updates, compare against the newest global
version, preserve immutable checksum-addressed snapshots (including original
seed files), and update the latest index only after the new snapshot exists.
GitHub Release attachment replacement by itself does not retain old contents.
deliver_snapshots.py uses immutable checksum-named release assets and updates
the index last, with a Contents API SHA check to reject a concurrent update.
It has not been exercised against production GitHub storage.

The compiled GUI now has a download/import callback and end-of-run submission
callback. Both remain disabled by configuration. Source runs remain local.

Still pending: a pinned matching numerical core on the GitHub worker,
approved production profile metadata, remote delivery integration tests,
browser sign-in tests in a compiled app, and Windows/macOS builds. The
published SAGE source currently lacks the newer model-configuration helpers;
do not silently use it as equivalent to the tested local core. MATLAB Compiler is installed and licensed locally; compiled integration testing is in progress.


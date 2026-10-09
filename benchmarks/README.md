# Shared SITE benchmarks: setup and current status

The proposal workflow is an initial pilot, not automatic benchmark publication.
Existing results stay unchanged. No experiment is approved yet: profiles.json
has an intentionally empty allowlist.

## Authentication

Register an OAuth application in https://github.com/settings/developers:

- Application name: SITE benchmark contributions
- Homepage: https://github.com/jaspervrugt/SITEhydrology
- Callback URL: https://github.com/login/device (unused by device flow)
- Enable Device Flow

Copy the public Client ID into utils/results/site_benchmark_github.json.
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

These checks do NOT verify the supplied scores. A trusted numerical worker
with approved model/loss code and the dataset must rerun submitted parameters
before publication. Client origin labels and isdeployed do not prove provenance.
There is deliberately no auto-merge or publication workflow at this stage.

Final publication must serialize updates, compare against the newest global
version, preserve immutable checksum-addressed snapshots (including original
seed files), and update the latest index only after the new snapshot exists.
GitHub Release attachment replacement by itself does not retain old contents.

Still pending: OAuth registration, numerical verification worker, profile
approval, benchmark download/refresh, snapshot publisher, and compiled
Windows/macOS end-to-end tests.

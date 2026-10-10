# Shared SITE benchmarks

SITE's compiled GUI downloads approved default benchmarks before training and offers to contribute improved fits when a run finishes or is stopped. Source MATLAB runs do not submit results. The contributor signs in to GitHub once and authorizes contributions; no owner credentials or client secret are distributed.

Contributions contain numerical JSON only. Before submission, SITE fetches the current shared results and identifies potentially improved basin/metric fits. For every contributing basin it reruns the shared incumbent parameter sets on the user's local data. All nine training and evaluation objective values must reproduce within `1e-8 + 1e-6 * abs(reference score)`. A failing basin stays local. The pending submission contains comparison values and the immutable reference snapshot checksum, never forcing or discharge data.

GitHub checks this evidence against the owner's immutable results snapshot and validates exact experiment settings, basin identities, parameter bounds and provenance. Routine publication does not download hydrological datasets or run hydrological simulations. This is a cooperative consistency check; the client evidence is not independent numerical verification. Contributors cannot directly edit the shared files.

Basins without a complete shared reference remain local for initial owner review. The separate owner-bootstrap workflow is manual only; its independent data download is never triggered by an ordinary contribution.

For each basin and metric, only a strictly better training score replaces the current parameters and paired evaluation score. All nine metrics are checked at every trial optimum. The MAT checkpoint, parameter workbook, master workbook, and snapshot index are committed together. Immutable snapshots and Git history retain recovery copies. Concurrent changes cause publication to stop and recompare rather than overwrite newer results.

Enabled profiles cover CAMELS-US daily, NLDAS, Penman–Monteith PET and the eight public models: HBV, HYMOD, HMODEL, SAC-SMA, Xinanjiang, GR4J, CFE-NWM and the supplied GR4J-B user-model example. Default training/evaluation periods, spin-up, initial states, additional variables and ODE settings must match exactly. Optimizer and trial settings may vary. Parameter ranges may vary and travel with each fit; the publisher assigns consistent range IDs. Other forcing/PET choices require their own approved profiles.

On Windows, consenting users can retain pending submissions and protected sign-in credentials for background retry when internet access returns, even after SITE closes. Credentials are encrypted for the current Windows user. macOS retries operate while the GUI is open; retry after exit is not yet implemented.

The owner baseline was independently recalculated from saved parameter vectors because older stored scores did not all reproduce. Original files are recoverable in Git history. The recalculation does not represent additional calibrations.

Publication is controlled by the repository variable SITE_BENCHMARK_PUBLISH. GUI submission is controlled by utils/results/site_benchmark_github.json. Only enabled profiles in benchmarks/profiles.json may contribute.

Live verification and automatic three-file publication passed in [run 37999228345](https://github.com/jaspervrugt/SITEhydrology/actions/runs/37999228345). The new Windows pilot build is ready for interactive GUI testing. Existing public application releases have not been replaced; macOS must be rebuilt separately.

Changing the pinned numerical core requires reapproval and a verified baseline; old and new numerical definitions must not be compared as one benchmark.

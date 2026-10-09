# Shared SITE benchmarks

SITE's compiled GUI downloads approved default benchmarks before training and offers to contribute improved fits when a run finishes or is stopped. Source MATLAB runs do not submit results. The contributor signs in to GitHub once and authorizes contributions; no owner credentials or client secret are distributed.

Contributions contain numerical JSON only. The trusted GitHub worker uses pinned scientific code and checksum-pinned official data to rerun each parameter vector. It rejects changed experiments, unknown basins, invalid parameters, and scores that do not reproduce. Contributors cannot directly edit the shared files.

For each basin and metric, only a strictly better training score replaces the current parameters and paired evaluation score. All nine metrics are checked at every trial optimum. The MAT checkpoint, parameter workbook, master workbook, and snapshot index are committed together. Immutable snapshots and Git history retain recovery copies. Concurrent changes cause publication to stop and recompare rather than overwrite newer results.

The first approved profile is CAMELS-US daily, HBV, NLDAS, Penman–Monteith PET, default training/evaluation periods and 365-day spin-up. Optimizer and trial settings may vary. Changed model configuration, periods, forcing or parameter bounds require a separately approved profile.

On Windows, consenting users can retain pending submissions and protected sign-in credentials for background retry when internet access returns, even after SITE closes. Credentials are encrypted for the current Windows user. macOS retries operate while the GUI is open; retry after exit is not yet implemented.

The owner baseline was independently recalculated from saved parameter vectors because older stored scores did not all reproduce. Original files are recoverable in Git history. The recalculation does not represent additional calibrations.

Publication is controlled by the repository variable SITE_BENCHMARK_PUBLISH. GUI submission is controlled by utils/results/site_benchmark_github.json. Only enabled profiles in benchmarks/profiles.json may contribute.

Live verification and automatic three-file publication passed in [run 37999228345](https://github.com/jaspervrugt/SITEhydrology/actions/runs/37999228345). The new Windows pilot build is ready for interactive GUI testing. Existing public application releases have not been replaced; macOS must be rebuilt separately.

Changing the pinned numerical core requires reapproval and a verified baseline; old and new numerical definitions must not be compared as one benchmark.

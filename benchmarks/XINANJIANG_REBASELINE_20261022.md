# Xinanjiang corrected-equation benchmark rebaseline

The Xinanjiang dry-soil evaporation correction changes numerical model
outputs. This update replaces obsolete scores; it is not an optimization run.
All known saved parameter vectors were replayed under the corrected model,
and the best successful saved vector was selected separately for each of the
nine metrics. Physical and normalized parameters remain linked to their
recorded bounds. Existing run and improvement counters are unchanged.

The immutable earlier snapshot assets remain available. All three original
parameter workbooks and checkpoints were retained in the local audit. Only
the Xinanjiang sheet changes in the multi-model summaries; other model
worksheets remain byte-identical in the OOXML package.

| Dataset | Basins with saved vectors | Metric records rescored | Active finite claims |
| --- | ---: | ---: | ---: |
| daily_daymet | 531 | 4779 | 4774 |
| daily_nldas | 531 | 4779 | 4779 |
| hourly_nldas | 507 | 4563 | 4535 |

Eleven hourly claims are withdrawn: all nine metrics for 04196800 (the
historical vector no longer completes numerical integration), and S_logp for
02193340 and 07142300 (undefined under the corrected model). Their parameter
vectors are retained in the workbooks/checkpoints, with missing scores. The
new hourly snapshot excludes those claims and records their withdrawal.

Previously empty metric entries were assessed too: five daily Daymet and
seventeen further hourly S_logp values remain undefined. They were already
missing historical claims, not additional withdrawn scores. All nine metric
definitions were assessed for every basin with at least one saved vector.

Daily NLDAS and Daymet include valid replacements selected from other
already-known vectors when a historical vector failed integration. This
does not represent a fresh calibration or an increment to run counters.

All approved NLDAS input fingerprints match the MATLAB reference inputs.
Hourly precipitation parsing uses round-trip decimal conversion before
MATLAB's single-precision representation. Hourly moving-window JKGE uses the
same odd 745-sample window as MATLAB for the default 31-day window.
Independent MATLAB/Python metric checks passed at the existing strict
verification tolerances. Rebuilt native libraries reproduce all nine metrics
at the checked daily and hourly basin within 1e-12 relative/absolute tolerance.

The scientific worker archive now contains the corrected Xinanjiang C++ and
MATLAB equations. All other model sources are unchanged. Archive/member
checksums and the three round-trip MATLAB checkpoints were verified.

Model revision: `xinanjiang_drysoil_20261022`.
Xinanjiang C++ source SHA-256:
`ac59a5da210a6aacf1cd7157427f91d60b3a00f1ffda626dbc453ba2376112f4`.

Use a current SITE build with this model revision. Scores from earlier
equations must be rescored before comparison, contribution, or warm starts.

Trusted dataset inputs
======================

`benchmarks/inputs.json` stores owner-registered prepared-input hashes. Each entry is keyed by the exact dataset, resolution, forcing/PET selection and default training/evaluation/spin-up signature. The entry serves all models using those inputs. Existing profile-specific CAMELS-US baselines take precedence during rollout.

SITE checks each contributing basin against this baseline, reproduces the incumbent reference scores, and replays each proposed improvement. GitHub validates that evidence against the owner's catalog and immutable reference snapshot. GitHub does not download hydrological data. These are cooperative consistency checks; they do not attest to an unmodified client.

A checksum baseline does not register benchmark scores or enable an otherwise unapproved experiment. Initial score references still require owner review. Missing or incomplete checksum registration keeps new contributions local. Daily, hourly and 15-minute inputs have separate identities. Alternative forcing/PET choices require their own registration; no default entry substitutes for another choice.

Owner registration
------------------

With the SAGEhydrology source installed beside SITEhydrology and the Data directory, run `register_site_dataset_checksums(destination,dataRoot,regions)` from `tools`. The optional regions argument restricts the registry scan. Omitting it visits every registered dataset/resolution using its GUI defaults. It reads data and produces per-setup JSON files; it never trains models or edits results. Completed setups are resumable. `status.json` reports progress. Read errors are retained locally for diagnosis.

Only publish complete entries. Strip local diagnostic error messages and source paths from the public catalog. Do not register baselines from contributor data. After a deliberate data correction, reproduce the score references before replacing their trusted input baseline.

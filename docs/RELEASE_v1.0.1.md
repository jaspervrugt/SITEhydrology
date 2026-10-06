# SITEhydrology v1.0.1

Patch release updating the public computational source and the Windows application.

## Changes from v1.0.0

- The Windows launcher is named SITE.exe and uses the SITE icon.
- Updated shared SAGEhydrology infrastructure for deployed model loading, dataset inventory detection, runtime paths, and consistent plot styling.
- Manual user models use a compatible externally compiled MEX and parameter metadata. No MATLAB path changes are required for deployed model evaluation.
- Calibration supports separately selected SITE and SAGE source roots.
- Parameter-schema changes are checked before calibration; obsolete parameter-range registries are archived rather than mixed with a new schema. Result storage handles schema changes and preserves historical backups.
- Calibration progress messages use consistent step numbering; training and evaluation plots use the shared visual theme.

## Downloads and installation

The Windows installer obtains MATLAB Runtime R2026a from MathWorks when needed. The portable ZIP requires MATLAB Runtime R2026a already installed. It contains the same compiled SITE application, public source support files, and a manual user-model template. The separate executable is intended for replacing an existing Windows installation.

Place SITE.exe beside Data/, SAGEhydrology/, SITEhydrology/, and user_model/, or select your folders in the Paths tab. The public MATLAB source requires SAGEhydrology v1.0.3 or later alongside SITEhydrology. Custom C++ models must be compiled externally for the target operating system; update their parameter metadata and restart SITE after replacing the MEX.

GUI source, private model implementations, AI-assisted authoring, and locally generated results are excluded from this update. Existing published benchmark results in the repository remain unchanged.

This release includes Windows x64 and macOS Apple Silicon (arm64) downloads.

The public computational source uses the repository LICENSE. The compiled application uses GUI-LICENSE-NOTICE.md. SHA256SUMS.txt lists the release asset hashes.

## macOS downloads available

SITE v1.0.1 now includes macOS builds for **Apple Silicon (arm64)** alongside the existing Windows downloads.

- `SITE-v1.0.1-macOS-arm64-installer.zip`: unzip and run the installer application; MATLAB Runtime R2026a is obtained when required.
- `SITE-v1.0.1-macOS-arm64.dmg`: disk image containing the application; requires the Apple Silicon MATLAB Runtime R2026a.

Download both options from [the v1.0.1 release](https://github.com/jaspervrugt/SITEhydrology/releases/tag/v1.0.1). These packages target Apple Silicon; they are not Intel Mac builds.

The supplied macOS build report records arm64 launcher, native MEX, ZIP and DMG checks. Downloaded file hashes were verified against that report. Windows downloads are unchanged.

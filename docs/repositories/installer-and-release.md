# Merly.Installer and Release Pipeline

## Purpose

`Merly.Installer` builds platform installers and publishes binaries into:

- `MP-CodeCheckBin-MacOS`
- `MP-CodeCheckBin-Suse`
- `MP-CodeCheckBin-Windows`

Channels in practice: `Test`, `Staging`, `Pre-Release`, `Release`.

## Start here

- `Merly.Installer/README.md` — core build/install docs
- `Merly.Installer/docs/` — QA/build diagnostics and platform-specific guides
- `Merly.Installer/docs/SERVICE_UI_STANDALONE.md` — service startup behavior
- `Merly.Installer/docs/QA_DOCKER_VS_GITHUB_ACTIONS.md` — incident comparison pattern

## Build entry points (high level)

- CMake preset flow:
  - `cmake --preset ninja-multi-vcpkg`
  - `cmake --build --preset ninja-multi-vcpkg-release`
- Legacy flow:
  - `cmake -B build`
  - `cmake --build build`
- Platform docs and scripts in `macOS-x64/` and `Linux/`.

## Release checks to keep in the loop

- Packaging and UI zip logic (`.UI`, `.version`, channel artifacts).
- Cross-platform script parity for QA.
- `push-channel.py` and asset upload scripts for promotion.

## Artifact repos

Use these repos as final channel outputs:

- `MP-CodeCheckBin-Windows` (Windows executables and manifests)
- `MP-CodeCheckBin-MacOS` (macOS installer outputs)
- `MP-CodeCheckBin-Suse` (Linux assets)

## Operational caution

If a QA mismatch appears between local package creation and GitHub Actions,
verify whether the UI zip path exists in build scripts, and whether the expected
channel artifact (`MentorUI-<Channel>.zip`) is present during packaging.

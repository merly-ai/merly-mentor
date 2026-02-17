# Runtime daemon and debugging workspaces

## Core daemon references

- `merly-mentor`  
  Docker compose and container deployment entry point for daemon-oriented stack
  (mentor API daemon, bridge service, and UI in composed layouts).
- `debugging`, `debugging-new`, `debugging-old`  
  Native build/runtime workspace mirrors and legacy validation repos.

## Start here

- `merly-mentor/README.md`
- `MP-CodeCheck`/subdirectories under `debugging*` for legacy local daemon tooling
- `.docker` compositions under `debugging/docker` and `debugging/docker-nightly`

## Typical workflow

1. Use `merly-mentor` composition examples for local high-level stack bring-up.
2. Use `debugging` repo builds to reproduce low-level runtime failures and
   validate native tooling behavior.
3. Confirm bridge UI and service compatibility with the versions you are
   shipping in release artifacts from `Merly.Installer`.

## Notes for thread escalation

- If a bug appears only in one OS, reproduce in nearest sibling `debugging-*` variant
  matching that platform.
- Keep daemon logs and bridge logs together for correlated analysis.

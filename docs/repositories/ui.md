# Mentor.UI Documentation

## Purpose

`Mentor.UI` is the web client for analysis dashboards, repository/job management,
issue workflows, and user auth/state.

## Start here

- `Mentor.UI/README.md` — initial setup and UI references
- `Mentor.UI/UI_ARCHITECTURE.md` — architecture
- `Mentor.UI/docs/user-permission-matrix.md`
- `Mentor.UI/docs/useApi-hook.md`
- `Mentor.UI/docs/logger-usage.md`
- `Mentor.UI/docs/validate-standalone-locally.md`
- `Mentor.UI/docs/standalone-build-and-installer.md`

## Local development

- `npm install`
- `npm run dev` (local development server)
- `npm run build` (standalone output path required by installer workflows)
- `./scripts/copy-standalone-assets.mjs` is part of release flow

## Environment

- Install binary by following `Mentor.UI/README.md` (`MerlyMentor` + `Mentor.Bridge` setup).
- Primary API base from Bridge is typically set by `MERLY_AI_BRIDGE_URL`.
- Legacy flow references direct install script path under `~/` as documented in README.

## QA/automation

- E2E tests are in `mentor-tests`.
- Useful check before pushing: run `npm run build` and smoke-check startup.

## Installer-aware behavior

- Supports standalone production packaging (`.next/standalone/server.js` + `.version`).
- `Merly.Installer` consumes this layout for zero install-time npm dependency installs.

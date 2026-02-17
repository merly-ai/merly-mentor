# Bug Investigation Playbook

Use this for incoming issues (human or agent threads).

## 1) Capture a complete signal

- Repro steps (exact command sequence and payloads)
- Environment:
  - OS, channel (`Test/Staging/Pre-Release/Release`)
  - Repo versions (Bridge, UI, Installer, WebPortal if touched)
  - Timestamps (local + UTC)
- Logs and artifacts:
  - Bridge: console output + integration test `test_status.json`
  - UI: Playwright report or browser screenshots
  - Service/installer: service logs and `.UI/.logs` if available
  - QA artifacts (`support-bundle`, api test results)

## 2) Route the bug to the correct repo

- Bridge/auth/session/job lifecycle issues → `Mentor.Bridge`
- Dashboard/permissions/UX/API calls from frontend → `Mentor.UI`
- Install/packaging/bootstrapping/channel delivery issues → `Merly.Installer`
- Installation/asset corruption by platform → `MP-CodeCheckBin-*` + Installer PR
- License/registration/component endpoints → `Merly.WebPortal`
- Reproducible daemon/runtime behavior or installer daemon startup failures → `merly-mentor` / `debugging*`
- E2E coverage gap or regression → `mentor-tests`

## 3) Reproduction flow

1. Reproduce with smallest repo/branch/data set.
2. Verify whether issue is:
   - deterministic,
   - timing-sensitive,
   - platform-only,
   - environment-only.
3. Pinpoint layer:
   - API contract mismatch
   - service/daemon startup or auth state
   - installation/channel artifact mismatch
   - UI selector/regression

## 4) Quick evidence checks

- Restart bridge/daemon and capture first-failure startup lines.
- Compare against a known-good run from QA artifacts.
- For timeouts, compare log timestamps around service readiness.
- Confirm Swagger/API endpoints align with request payload observed in UI.

## 5) Fix planning

Before code change:

- Identify expected behavior contract and acceptance criteria.
- Add/adjust regression test in the owning repo.
- Define rollback and validation steps.

## 6) Closure criteria

- Repro no longer occurs.
- Existing regression test updated/added.
- Change includes changelog-note-level summary in thread.
- Thread references commands used and test output location.

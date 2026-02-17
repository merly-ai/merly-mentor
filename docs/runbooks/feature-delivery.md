# Feature Delivery Playbook

Use this to start feature or cleanup threads that touch multiple repos.

## Phase 0: Scope and contract

- Define feature statement in 1 sentence.
- Identify impacted user stories and acceptance criteria.
- Confirm whether API contracts change.
- Assign owning repo and impacted downstream repos.

## Phase 1: Local implementation plan

For each affected repo:

- `Mentor.Bridge`: API and validation contract updates
- `Mentor.UI`: UI flow, data usage, hooks/state changes
- `Merly.Installer`: packaging or service behavior changes
- `Merly.WebPortal`: licensing/admin contract impacts
- `mentor-tests`: add/modify user scenario coverage

## Phase 2: Cross-repo validation

- Run per-repo unit/integration tests for changed layer first.
- Run UI E2E (`mentor-tests`) against full stack.
- Validate installer packaging (`Merly.Installer`) if release artifacts changed.
- Confirm channel flow: Test -> Staging -> Pre-Release -> Release as needed.

## Phase 3: Risk and rollback

- Define blast radius (all users / channel-limited / feature gated).
- Add a safe rollback path:
  - UI runtime feature guard
  - API compatibility fallback
  - packaging fallback to previous artifacts

## Phase 4: Handoff

- Update docs in this suite:
  - changed behavior notes
  - expected endpoint changes
  - migration/config steps
- Include validation summary and known caveats in thread.

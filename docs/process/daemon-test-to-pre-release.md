# Daemon Change: Promote Test → Pre-Release (with validation)

Use this runbook for daemon changes that are already in `Test` and need to move into
`Pre-Release` with proof.

## Scope and safety boundary

This is for `Mentor.Bridge` daemon behavior changes where the target movement is:

- `Test` (source verification channel)
- `Pre-Release` (next controlled target)

Do not use this path for unrelated release engineering changes.

## Prerequisites

- A reproducible daemon build or component change is complete.
- `MM_KEY` available for local smoke verification.
- GitHub token / push auth configured for installer promotion (`PUSH_TOKEN`).
- You understand any dependency changes required by `Mentor.UI`, `Mentor.Bridge`,
  or `Merly.Installer`.

## Required path

### 1) Validate daemon path locally first

```bash
cd /Users/ursmuff/source/merly.ai
./scripts/thread-runtime.sh check
MM_KEY="$(./scripts/thread-runtime.sh fetch-mm-key --username 'QA Test User' --email 'qa-test@merly.ai')" \
  ./scripts/thread-runtime.sh start-container-stack
MM_KEY="$(./scripts/thread-runtime.sh fetch-mm-key --username 'QA Test User' --email 'qa-test@merly.ai')" \
  ./scripts/thread-runtime.sh run-e2e
```

At minimum, this verifies:

- bridge + UI + daemon integration are available
- core authentication and workflow path still passes with the daemon candidate

Stop stack:

```bash
./scripts/thread-runtime.sh stop-container-stack
```

### 2) Run a controlled promotion validation for `daemon` only

This uses `push-channel.py` validation mode (`--test`) and does not write a real
Pre-Release result.

```bash
./scripts/thread-runtime.sh promote \
  --from-channel Test \
  --to-channel Pre-Release \
  --components daemon \
  --test
```

### 3) Execute the real promotion

Run only after passing step 2 and after product owner approval.

```bash
./scripts/thread-runtime.sh promote \
  --from-channel Test \
  --to-channel Pre-Release \
  --components daemon \
  --version <optional-daemon-version>
```

If only the daemon changed and no component version is pinned, omit `--version`.

### 4) Post-promotion QA and evidence

Immediately after success:

- Capture the `push-channel.py` output.
- Collect the triggered QA runs in `mentor-tests` (automated dispatch from the
  installer workflow).
- Re-run at least one smoke path with `MM_KEY` against the promoted artifacts.
- Attach outputs to thread notes:
  - Playwright report/artifacts
  - Installer run log
  - QA workflow URLs

## Fast CLI path (recommended for threads)

Use one command to execute the same sequence, with explicit smoke validation and a
final execute switch:

```bash
MM_KEY="$(./scripts/thread-runtime.sh fetch-mm-key --username 'QA Test User' --email 'qa-test@merly.ai')" \
  ./scripts/thread-runtime.sh \
  promote-daemon-test-to-prerelease --version <optional-daemon-version> --execute
```

If you want only validation, omit `--execute`.

## Rollback note

If validation fails after the real push, roll back by moving a known-good daemon build
through channel governance according to current platform policy before shipping any new
code.

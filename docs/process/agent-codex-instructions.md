# Agent and Codex Operating Instructions

This document is the shared operating guide for humans, agents, and Codex when starting
and executing threads across the Merly workspace.

## Purpose

- Keep thread setup predictable.
- Reduce repeated context loading.
- Make runbook execution and GitHub Actions usage consistent.
- Capture and preserve what worked, what failed, and what changed.

## 1) Before opening any thread

1. Open the thread-specific docs:
   - `docs/README.md`
   - `docs/process/thread-runtime-and-delivery.md`
   - `docs/process/agent-codex-instructions.md` (this file)
2. Confirm thread scope:
   - Bug / feature / maintenance / release.
3. Read workspace instructions:
   - `/Users/ursmuff/source/merly.ai/AGENTS.md`
   - `.codex/config.toml` (via relative path `.codex/config.toml`)
   - If `.codex/config.toml` is missing, copy `.codex/config.example.toml` and set your local `root`.
4. Confirm target channels (`Test`, `Staging`, `Pre-Release`, `Release`).
5. Define expected behavior and rollback boundary.
6. Set initial evidence commands (even before edits).
7. If daemon promotion is involved, open
   `docs/process/daemon-test-to-pre-release.md`.

## 2) Tool usage contract

- Prefer fast, low-cost discovery first:
  - `rg` for file lookup.
  - `sed -n` for targeted file slices.
  - `ls` only on short directories.
- Prefer parallel reads when possible for independent files.
- Avoid one-off large scans (`rg --files`, full tree `find`, node_modules, `.git`, artifacts).
- Avoid destructive operations unless explicitly requested:
  - `rm`, `git reset`, `git clean`, mass refactors.
- Never run tests/validation unless requested or required by the thread scope.
- When uncertain, ask before adding risky commands.

## 3) Standard per-thread execution flow

### A. Bootstrap thread runtime

```bash
./scripts/thread-runtime.sh check
```

If no key exists for this thread yet, fetch one first:

```bash
export MM_KEY="$(./scripts/thread-runtime.sh fetch-mm-key \
  --username "${CI_TEST_USER_NAME:-QA Test User}" \
  --email "${CI_TEST_USER_EMAIL:-qa-test@merly.ai}")"
```

### B. Local validation loop (minimum)

```bash
export MM_KEY=<valid-license-key>
./scripts/thread-runtime.sh start-container-stack
./scripts/thread-runtime.sh run-e2e
```

### C. If code changed

- Run relevant owning-repo checks.
- Re-run e2e via `./scripts/thread-runtime.sh run-e2e` when the owning layer is in play.

### D. Promotion (as applicable)

```bash
./scripts/thread-runtime.sh promote \
  --from-channel=Test \
  --to-channel=Staging \
  --components=daemon,bridge,ui
```

Use `--test` for validation-only promotion and switch off once a thread demonstrates
stable signal.

For daemon-only `Test -> Pre-Release`, use the dedicated command:

```bash
./scripts/thread-runtime.sh promote-daemon-test-to-prerelease \
  --version <optional-version> \
  [--execute]
```

`--execute` performs the real movement from Test to Pre-Release.
If omitted, only validation runs.

## 4) Evidence and handoff requirements

For every thread, include:

- What changed and why.
- Exact commands executed.
- Evidence path:
  - Playwright report/test artifacts
  - `push-channel.py` / promotion logs
  - GitHub Actions run URLs
- Exit criteria passed / not passed.

## 5) Decision records (must keep this compact)

When a decision is non-obvious, record:

- Decision
- Why chosen
- Date/time
- Rejected alternatives
- Impact/risk

Update:

- `docs/process/thread-runtime-and-delivery.md` when workflows or sequence changes.
- `docs/process/agent-codex-instructions.md` when best practices evolve.
- `docs/process/daemon-test-to-pre-release.md` when daemon gating changes.

## 6) Script responsibilities (authoritative runtime entrypoint)

Single entrypoint script:

- `scripts/thread-runtime.sh`

Supported commands:

- `check`
- `start-container-stack`
- `run-e2e`
- `smoke`
- `stop-container-stack`
- `status`
- `promote`
- `promote-daemon-test-to-prerelease`

If commands fail due missing env or prerequisites, document exact failure output and fix
the prerequisite path first.

## 7) Maintenance loop

- After each meaningful process change:
  - Update this instruction doc first, before adding new tribal notes elsewhere.
  - Add one-line "what changed" summary in thread notes.
  - Keep examples version-agnostic and command-copyable.

## 8) Shared codex config baseline

Use `.codex/config.example.toml` as the portable baseline for codex/thread runtime configuration.
Keep machine-specific values in untracked `.codex/config.toml` (for example, `root` path and local toolchain details).

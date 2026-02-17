# Merly AI Workspace AGENTS

This repository set is a distributed workspace (`Mentor.Bridge`, `Mentor.UI`,
`Merly.Installer`, `Merly.WebPortal`, `MP-CodeCheckBin-*`, and `mentor-tests`).
Use these rules before changing code in any repository under
`/Users/ursmuff/source/merly.ai`.

## 1) Read order before edits

1. Read this file.
2. Read the repo-level thread guidance in `docs/process/agent-codex-instructions.md`.
3. Read or revisit the relevant runbook you are about to use:
   - `docs/process/thread-runtime-and-delivery.md`
   - `docs/process/e2e-local-validation.md`
   - `docs/process/daemon-test-to-pre-release.md` (daemon Test→Pre-Release path)
4. Read any repo-local AGENTS file in the repository you touch (if present).

## 2) Required bootstrap command

Before any implementation or verification work:

```bash
cd /Users/ursmuff/source/merly.ai
./scripts/thread-runtime.sh check
```

If this command fails, stop and fix the prerequisite; do not proceed with
implementation.

## 3) Git + thread hygiene

- Use branches for workspace work.
- Keep threads scoped to one primary objective.
- Document acceptance criteria before changing behavior.
- For each thread, keep a single evidence bundle that includes:
  - command list run
  - Playwright/mentor-tests output path (if applicable)
  - push-channel/promotion command output
  - GitHub Actions run links that executed

## 4) Validation discipline

1. Make the minimal change in the owning repo.
2. Run owning-repo validation commands where possible.
3. Run local thread smoke checks via:
   - `./scripts/thread-runtime.sh run-e2e`
   - `./scripts/thread-runtime.sh smoke`
4. Gate cross-repo changes with the delivery path in
   `docs/process/change-implementation-review-deploy.md`.

## 5) Promotion discipline

- Promotion commands must be deterministic and logged.
- For daemon changes that need move from Test to Pre-Release, execute the process in
  `docs/process/daemon-test-to-pre-release.md`.
- `./scripts/thread-runtime.sh promote` and
  `./scripts/thread-runtime.sh promote-daemon-test-to-prerelease` are the
  standard CLI entrypoints for movement across channels.

## 6) Failure handling

If a required command fails:

1. Stop and fix the immediate prerequisite failure.
2. Record the exact command and output in thread notes.
3. Re-run only what is necessary.

## 7) Process ownership

If you discover a durable change to this process, update the relevant process doc
before making a new repository change.

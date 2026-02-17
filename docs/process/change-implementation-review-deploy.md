# Change → Review → Deploy Process

Use this when you need a stable process for adding features, fixing bugs, and shipping safely.

## 1) Identify and classify the change

### Classify first

- Bug fix
- Feature enhancement
- Refactor/cleanup
- Release/infrastructure
- Packaging/install change

### Assign owner by surface

- `Mentor.Bridge`: auth/session/job endpoints, daemon orchestration
- `Mentor.UI`: UI flow, state, selectors, rendering paths
- `Merly.Installer`: packaging, update logic, service startup
- `Merly.WebPortal`: licensing/admin endpoints
- `mentor-tests`: cross-repo behavior validation

## 2) Define acceptance criteria before code change

Create a short list:

- What exact user-visible behavior changes?
- What endpoints/files must remain stable?
- What logs/metrics should prove the change worked?
- Which channels are in scope (`Test` only, `Staging`, `Pre-Release`, `Release`)?

## 3) Minimal fix plan and branch strategy

1. Implement smallest possible change in the owning repo.
2. Add/adjust one focused test before broadening scope.
3. Keep contract-impacting code isolated when possible.
4. Avoid refactors in the same patch unless needed to fix root cause.

## 4) Review and risk gates

### Code review checkpoints

- API contracts unchanged unless intentional
- Error handling and logging preserve troubleshooting context
- No credentials/secrets introduced in logs
- Cross-platform paths are normalized where applicable
- Installer-related changes preserve backwards-compatible behavior

### Evidence to collect for review

- Test commands run
- Repro command for fixed bug (or failing-before / passing-after proof)
- E2E command result
- Diff summary with file-level rationale

## 5) Validation before merge

Run in this order whenever possible:

1. owning repo local validation
2. `mentor-tests` E2E full-core flow
3. installer/packaging validation if install path changed
4. one pass on a clean branch against baseline environment
5. execute `./scripts/thread-runtime.sh smoke` after stack or source validation is ready

Use:

- `/docs/process/e2e-local-validation.md`
- `/docs/process/agent-codex-instructions.md`
- per-repo docs in `/docs/repositories/*`
- `/docs/process/thread-runtime-and-delivery.md`

## 6) Deployment flow (minimum safe path)

1. Merge to `Test`-bound branch/channels first.
2. Verify no regressions in Test via local E2E + smoke checks.
3. Promote through:
   - `Test → Staging → Pre-Release → Release`
4. Confirm channel-specific installer artifacts exist and match expected versions.
5. For Test-only validations, keep `--test` flag on push-channel script until confidence increases.

Typical promotion command reference:

```bash
./scripts/thread-runtime.sh promote \
  --from_channel=Test \
  --to_channel=Staging \
  --components=daemon,bridge,ui
```

Optional flags are available in `Merly.Installer/push-channel.py` (`--test`,
`--debug`, `--version`, `--components`, etc.).

Use `./scripts/thread-runtime.sh promote` to keep thread commands consistent.

## 7) Post-deploy verification

- Smoke the newly promoted component in target channel.
- Run the affected flow in `mentor-tests`.
- Capture logs/artifacts so a future thread can trace behavior quickly.
- Confirm expected GitHub Actions chain ran:
  - channel push workflow run
  - installer QA workflow run
  - mentor-tests e2e/install workflow run

## 8) Regression prevention

- Update docs in `/docs` whenever behavior or runbook changes.
- Record assumptions and failure patterns in thread history.
- Keep a short rollout note:
  - changed surface area
  - test evidence
- Trigger incident template if behavior changed outside intended scope.

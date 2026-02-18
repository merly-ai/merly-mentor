# Thread Runtime, Validation, and Delivery Runtime

Use this as the standard operating path for each thread (bug fix, feature, or release
work).

## 0) Before opening work on a thread

Capture these decisions first:

- What changed surface(s)?
  - `Mentor.Bridge`, `Mentor.UI`, `Merly.Installer`, `Merly.WebPortal`, or runtime.
- Is this a cross-repo change?
- Which target channel is expected?
  - `WIP-Demo` / `Test` / `Staging` / `Pre-Release` / `Release`
- What is the minimum acceptance behavior?
- What can be rolled back immediately if this thread fails?
- What local and CI evidence proves success?

## 1) Shared thread runtime script

Run this at the start of every thread.

```bash
cd /Users/ursmuff/source/merly.ai
chmod +x scripts/thread-runtime.sh
./scripts/thread-runtime.sh check
```

```bash
docker ps >/tmp/docker-ps.txt 2>&1 && cat /tmp/docker-ps.txt || echo "Docker daemon unavailable; start Docker Desktop (e.g. `open -a Docker`) before continuing."
```

### Preflight license bootstrap

When a valid `MM_KEY` is available on a thread, fetch it from the MAS trial registration API using the same CI identity path used by installer QA:

```bash
export CI_TEST_USER_NAME="${CI_TEST_USER_NAME:-QA Test User}"
export CI_TEST_USER_EMAIL="${CI_TEST_USER_EMAIL:-qa-test@merly.ai}"
export MM_KEY="$(./scripts/thread-runtime.sh fetch-mm-key \
  --username "${CI_TEST_USER_NAME}" \
  --email "${CI_TEST_USER_EMAIL}"
)"
```

### Azure DB access preflight

If local runs fail because PostgreSQL blocks your client IP, allow your current IP in the Azure PostgreSQL firewall:

```bash
./scripts/allow-azure-db-ip.sh \
  --server merlylicenseserver-2 \
  --resource-group <AZURE_RESOURCE_GROUP>
```

The script auto-detects single-server vs flexible-server and resolves your public IP automatically.
If you need a specific IP or range:

```bash
./scripts/allow-azure-db-ip.sh \
  --server merlylicenseserver-2 \
  --resource-group <AZURE_RESOURCE_GROUP> \
  --ip 1.2.3.4 \
  --ip-range-end 1.2.3.9
```

Use this when you cannot connect to the MAS DB from local tooling.

### Main commands

### Main commands

```bash
# 1) Start dockerized daemon + bridge + UI for quick validation
./scripts/thread-runtime.sh start-container-stack

# 2) Run mentor-tests core flow
./scripts/thread-runtime.sh run-e2e

# 3) Start + run e2e in one shot (default core flow)
./scripts/thread-runtime.sh smoke
./Merly.WebPortal/run-public-swagger-tests.sh
./scripts/thread-runtime.sh run-bridge-swagger

# 4) Stop and cleanup local stack
./scripts/thread-runtime.sh stop-container-stack

# 5) Push components across channels using push-channel.py
./scripts/thread-runtime.sh promote --from-channel Test --to-channel Staging --components daemon,bridge,ui
./scripts/thread-runtime.sh promote --from-channel Staging --to-channel Pre-Release --components all --version 1.2.3 --test

# 6) Daemon Test -> Pre-Release guided path
./scripts/thread-runtime.sh promote-daemon-test-to-prerelease --version 1.2.3 --execute
```

## 2) Local validation playbook (thread-level)

### A) Containerized fast loop (recommended first pass)

```bash
export MM_KEY=<valid_license_key>
./scripts/thread-runtime.sh start-container-stack
./scripts/thread-runtime.sh run-e2e
```

Run only the public Bridge swagger suite against the containerized bridge image:

```bash
export MM_KEY=<valid_license_key>
export BRIDGE_TEST_EMAIL=urs.muff@merly.ai
export BRIDGE_TEST_PASSWORD=
./scripts/thread-runtime.sh run-bridge-swagger
```

If you need deterministic bridge swagger runs across repeated sessions, keep:

```bash
export BRIDGE_TEST_RESET_STATE=1   # default: refreshes mentor keys/settings cache for bridge runs
```

If you intentionally want to reuse existing local mentor cache data, set:

```bash
export BRIDGE_TEST_RESET_STATE=0
```

This uses:

- `mentor-tests/infrastructure/docker-compose.yml`
- `Mentor.UI` from image flow (`merlyai/ui:nightly`)
- `Mentor.Bridge` from image flow (`merlyai/bridge:nightly`)
- `Mentor` daemon from image flow (`merlyai/mentor:nightly`)

Useful when validating UI contract changes and smoke behavior.

### B) Source-backed loop (code-change confirmation)

Use when you changed owned source files and want to verify your edits are actually in
runtime:

1. Start daemon stack from source-or-install target (outside this script):
   - `go run .` in `Mentor.Bridge`
   - `npm run dev` in `Mentor.UI` (optionally after `npm ci`)
2. Start the container stack only for daemon dependency as needed.
3. Run `./scripts/thread-runtime.sh run-e2e` against your locally exposed UI.

### C) Installer/asset loop (delivery-facing)

After local UI build:

- `npm run build` in `Mentor.UI`
- `./scripts/thread-runtime.sh promote ...` with channels and component set.

If `ui` changed, confirm `Mentor.UI` standalone artifact is valid before promotion:

- `Mentor.UI/docs/validate-standalone-locally.md`

### D) Merly.WebPortal public API loop

```bash
./Merly.WebPortal/run-public-swagger-tests.sh
SKIP_PUBLIC_SWAGGER_SUITE=1 ./Merly.WebPortal/run-public-swagger-tests.sh
```

### E) Reset test key quotas for local thread loops

When running repeated local validation on the same QA test key:

```bash
export MM_KEY=<valid-test-key>
export MAS_RESET_WHO="qa-reset-bot"
./scripts/thread-runtime.sh reset-mas-test-key "$MM_KEY"
```

Defaults:

- `MAS_API_BASE_URL`: `https://merlyserviceadmin.azurewebsites.net`
- `MAS_RESET_WHO`: `qa-reset-bot`

This runs:

`POST /api/License/ResetTestUsage?key=<MM_KEY>&who=<who>`

## 3) GitHub Actions delivery path (source-of-truth gates)

### Channel promotion (required runtime)

Primary entry point:
- Workflow: `Merly.Installer/.github/workflows/push-channel.yml`
- Trigger: `workflow_dispatch` with explicit input:
  - `from_channel`
  - `to_channel`
  - `components` (daemon/bridge/ui/installer/assets/all)
  - `version` (optional)
  - `test`, `debug`, `update_bin_repos`
- Core runner logic: `Merly.Installer/push-channel.py`
- If not test-mode, workflow triggers repository dispatch into `mentor-tests` on target:
  - `test-after-wip-demo-push`
  - `test-after-staging-push`
  - `test-after-pre-release-push`
  - `test-after-release-push`

### QA chain after change promotion

Workflows in `mentor-tests` run automatically via dispatch/workflow:
- `mentor-tests/.github/workflows/mentor-wip-demo-installer.yml`
- `mentor-tests/.github/workflows/mentor-staging-installer.yml`
- `mentor-tests/.github/workflows/mentor-pre-release-installer.yml`
- `mentor-tests/.github/workflows/mentor-release-installer.yml`
- `mentor-tests/.github/workflows/e2e.yml` (core flow, and can be workflow-dispatched for direct QA reruns)

### Daemon Test → Pre-Release control sequence

Use this exact command set for daemon-only changes:

```bash
./scripts/thread-runtime.sh promote-daemon-test-to-prerelease --version <optional-daemon-version>
```

That command performs:

- local prereq/tooling checks
- optional stack smoke + e2e
- `--test` promotion validation from `Test` to `Pre-Release`

Add `--execute` when you are ready to perform real promotion.

## 4) Thread diagnostics and failure forensics

Use this whenever a command fails or a thread handoff requires deterministic evidence.

### A) Default automatic diagnostics

Diagnostics are enabled by default:

- session base: `.thread-runtime-diagnostics`
- default session id: `thread-YYYYMMDD-HHMMSS`
- command logs captured under `<session>/commands/<label>.log`
- stack/container snapshots under `<session>/runtime-.../`

Every command in this script emits:

- command start/end timestamps
- command duration
- docker compose state and logs
- container inspect + container logs
- git state and run context

To capture an on-demand snapshot:

```bash
./scripts/thread-runtime.sh collect-diagnostics after-pipeline-run
```

### B) Diagnostics env toggles

```bash
export THREAD_RUNTIME_DIAG_DIR="${PWD}/.thread-runtime-diagnostics"
export THREAD_RUNTIME_DIAGNOSTICS=1                  # 1=auto-collect when a command fails (ERR trap); 0=off
export THREAD_RUNTIME_DIAGNOSTICS_ON_ERROR=1          # 1=collect on command failures; 0=off
export THREAD_RUNTIME_DIAGNOSTICS_CONTAINER_LIMIT=20    # fallback limit if stack service list is unavailable
export THREAD_RUNTIME_DIAG_SESSION_ID="thread-$(date +%s)" # optional deterministic session id
```

After a run, inspect:

- `<session>/summary.txt`
- `<session>/context.txt`
- `<session>/docker-summary.txt`
- `<session>/commands/*`
- `<session>/mentor-tests/playwright-report`
- `<session>/mentor-tests/test-results`
- `<session>/runtime-*/containers/*.log`
- `thread-runtime.sh` invocation output:
  - `Diagnostics written to: <path>` (from collect-diagnostics)

### C) Disable noisy diagnostics

```bash
export THREAD_RUNTIME_DIAGNOSTICS=0
```

## 5) Build/test CI loops for owned repos

- `Mentor.Bridge/.github/workflows/all-tests.yaml` (daemon runtime and API stack)
- `Mentor.Bridge/.github/workflows/e2e.yml` (bridge-specific E2E)
- `Mentor.UI/.github/workflows/test.yaml` and `build-push.yml`
- `Merly.Installer/.github/workflows/*`
- `mentor-tests/.github/workflows/e2e.yml`

## 6) Standard evidence bundle per thread

For every thread closure, include:

- Branch name and changed repos
- Before/after validation commands:
  - `./scripts/thread-runtime.sh check`
  - `./scripts/thread-runtime.sh smoke`
  - `./Merly.WebPortal/run-public-swagger-tests.sh` (if WebPortal changed)
  - `./scripts/thread-runtime.sh promote-daemon-test-to-prerelease` (when daemon path is used)
  - relevant per-repo build/test commands
- Artifacts location:
  - `Playwright` report (`mentor-tests/test-results` / `playwright-report`)
  - `push-channel.py` output
  - thread runtime diagnostics (`.thread-runtime-diagnostics/<session>/`)
  - GitHub Actions run URLs for:
    - changed repo CI
    - push-channel run
    - installer QA run
    - e2e run

## 7) Recommended thread template fields

Use at least:

- Build surface:
- Acceptance criteria:
- Local validation commands:
- Thread-level rollback:
- CI runs to force before merge:
- Post-deploy gate:

## 8) Runtime diagram

```mermaid
flowchart LR
  T[Start thread] --> C[Classify scope and risks]
  C --> I[Implement minimal change]
  I --> L[Local validation loop]
  L --> S{Source changed}
  S -->|No| U[Containerized smoke via stack + mentor-tests]
  S -->|Yes| V[Source runtime check + mentor-tests]
  U --> P[Push workflow (push-channel.py)]
  V --> P
  P --> Q[QA trigger in mentor-tests]
  Q --> D[Document evidence + close thread]
```

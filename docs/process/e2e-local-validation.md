# Local E2E Validation and Root-Cause Workflow

This guide is the practical path for validating the complete system end-to-end on
a local machine and for finding changes that introduced regressions.

Use the thread runtime helper for a repeatable local workflow:

```bash
./scripts/thread-runtime.sh check
./scripts/thread-runtime.sh start-container-stack
./scripts/thread-runtime.sh run-e2e
```

If Docker is not running, these commands fail early with:

`Cannot connect to the Docker daemon at unix:///.../docker.sock`

Start Docker Desktop first (or the host docker service), then rerun the same commands.

## 0a) Docker preflight (required for containerized loops)

- `docker ps` should return quickly (or at least not hang on daemon connect).
- If `docker ps` reports connection errors, restart Docker Desktop and retry:
  - `open -a Docker`
  - wait until `docker ps` succeeds
  - then continue from Step 1.

Pre-check instruction summary is in [`agent-codex-instructions`](./agent-codex-instructions.md).

## 0) Prerequisites

- Docker and Node 18+ installed
- A working license key / registration key for stack startup
- At least one repo side checkout for:
  - `Mentor.Bridge`
  - `Mentor.UI`
  - `Merly.Installer` (for installer-related checks)
  - `mentor-tests`
- Optional but recommended:
  - `Merly.WebPortal` for license and activation API testing

## 1) Fastest full-system local sanity (containerized)

Use the compose template in `merly-mentor` when you want repeatable startup
behavior:

1. Set the env:

```bash
export REGISTRATION_KEY=<your-license-key>
```

To bootstrap a fresh key directly from the MAS endpoint (same path used in installer QA), use the thread runtime helper:

```bash
export MM_KEY=$(./scripts/thread-runtime.sh fetch-mm-key \
  --username "QA Test User" \
  --email "qa-test@merly.ai")
```

2. Edit/copy `merly-mentor/docker-compose-templates/docker-compose.template.yml`
   and provide image tags as needed (it is a template).

3. Bring the stack up.

```bash
docker compose -f merly-mentor/docker-compose-templates/docker-compose.template.yml up
```

4. Confirm endpoints are reachable:

- `http://localhost:4200` (daemon)
- `http://localhost:8080` (bridge API)
- `http://localhost:3000` (UI)

If all three start, proceed directly to UI E2E.

The containerized flow can also be started through the script:

```bash
export MM_KEY=<your-license-key>
./scripts/thread-runtime.sh start-container-stack
./scripts/thread-runtime.sh status
```

## 2) Source-first end-to-end startup (for code changes)

When changing owned code, run services from source to ensure the changed layer is
actually in play.

1. Start bridge locally:

```bash
cd Mentor.Bridge
go run .
```

2. Start UI locally:

```bash
cd Mentor.UI
npm install
npm run dev
```

3. Ensure daemon layer is running from an installation path or `merly-mentor`
   instance that can be reached by bridge.

This route is more useful when validating API contract changes or UI integration
logic.

Thread-runtime alias for this mode:

```bash
./scripts/thread-runtime.sh run-e2e
```

## 3) Run the full E2E suite locally

From `mentor-tests`:

1. Install deps:

```bash
cd mentor-tests
npm install
npx playwright install --with-deps
```

2. Run the core flow:

```bash
MM_KEY=<valid-key> E2E_UI_BASE_URL=http://localhost:3000 npx playwright test
```

Thread-runtime alias:

```bash
MM_KEY=<valid-key> ./scripts/thread-runtime.sh run-e2e
```

3. Open report:

```bash
npx playwright show-report
```

Use the core flow doc:
`mentor-tests/docs/core-flow-test.md`

One-command thread smoke path:

```bash
MM_KEY=<valid-key> E2E_UI_BASE_URL=http://localhost:3000 ./scripts/thread-runtime.sh smoke
```

## 4) Optional installer-mode end-to-end check

For changes in installer packaging or UI distribution:

1. Build `Mentor.UI` standalone output:

```bash
cd Mentor.UI
npm run build
```

2. Build `Merly.Installer` using your normal flow.
3. Run standalone validation script (from `Mentor.UI` if available in your branch):

```bash
./scripts/validate-standalone-local.sh --skip-upload-step
```

This verifies zip contents and `node server.js` flow locally.

4. Smoke install/update on target OS:

- Use the corresponding build/install validation in `Merly.Installer/docs/`.

## 5) Validation matrix (recommended order)

Run these before merging any cross-repo change:

- `Mentor.Bridge`: targeted unit/integration tests (`go test ...`)
- `Mentor.UI`: `npm run lint`, `npm run build`
- `mentor-tests`: core flow run above
- `Merly.Installer`: packaging script/validation for changed installer behavior
- `Merly.WebPortal`: smoke `/swagger` endpoint + target controller path

## 6) Failure triage playbook (fastest to slowest signal)

1. **Cannot start full stack**
   - Check `REGISTRATION_KEY`, port collisions, and startup order.
   - Confirm daemon/bridge log output before opening UI.
2. **E2E reaches login but fails job flow**
   - Capture a new failing repo ID and replay a single core flow manually.
   - Verify Bridge logs around auth/session and repo mutation calls.
3. **Job appears but never completes**
   - Validate daemon health and logs.
   - Check for timeout window; compare against historical success windows.
4. **UI loads but no jobs/summaries**
   - Re-check API payload shape and endpoint contract.
   - Verify `Mentor.UI` proxy and hook code path.
5. **Installer/E2E mismatch**
   - Compare source-based startup vs zipped `.UI` startup behavior.
   - Validate `.UI/server.js` and `.version` for standalone flow.

## 7) Regression closure checklist

- Repro steps documented in one thread.
- Root-cause recorded with file/path/log reference.
- Fix validated in the matrix above.
- Change has a rollback path and a known-good baseline.
- Release-impact checked (`Test` at minimum).

## 8) Baseline run snapshot (Feb 17, 2026)

Latest full suite execution against nightly containerized stack with a generated `MM_KEY`:

- Result: `14 passed`, `60 failed`, `70 skipped`
- Main failure classes:
  - Auth API response message format changes (`details` now prefixed with `authentication failed:`).
  - Upstream auth fixture dependency (`validCredentials` unavailable in one API test flow).
  - UI auth flow requires local `test-results/.auth/0.json` initialization and stable login locator selection.
- Immediate action before trusting full-suite results:
  - Run a narrower smoke scope first (auth + one core repository flow).
  - Capture UI fixtures expected auth seed values and locator strategy in one thread.

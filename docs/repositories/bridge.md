# Mentor.Bridge Documentation

## Purpose

`Mentor.Bridge` is the middleware between client and daemon:

- auth/session and privilege handling
- job orchestration
- endpoint translation and pass-through
- API contract exposure (`/api/v1`)

## Start here

- `Mentor.Bridge/README.md` — runtime startup, env vars, and integration tests
- `Mentor.Bridge/BRIDGE_ARCHITECTURE.md` — architecture summary
- `Mentor.Bridge/API/Mentor API OpenAPI Specification.txt` — contract
- `Mentor.Bridge/API/Mentor API Summary.md` — high-level API intent
- `Mentor.Bridge/TEST_FRAMEWORK_USAGE.md` — API-version-aware test framework notes

## Dev commands

- `go run .` to start the bridge.
- Integration tests:
  - `go test -v -tags=integration ./...`
  - `go test -v -tags=integration2 -run TestUserChain_WithWelcome ./...`
  - `go test -run TestSetup_FromScratch`
- `run_all` support scripts live in the repository (`run_test_analysis.sh`, etc.).

## Useful env vars

- `MERLY_BASE_URL` (defaults to `http://localhost:8080`)
- `MERLY_ITERS` (integration loops, defaults to `3`)
- `LOG_LEVEL=DEBUG|INFO|WARNING|ERROR`
- `PASSWORD` for setup/login test user auth flows
- `REGISTRATION_KEY` for setup-from-scratch path

## Operational notes

- Classic and welcome-flow integration tests exercise login/logout and cookie/token
  handoff paths.
- `users.db` and `.env` are updated by setup tests for a runnable local state.

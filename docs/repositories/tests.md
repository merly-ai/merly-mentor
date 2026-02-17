# mentor-tests: UI E2E Test Suite

## Purpose

Automation coverage for the core Mentor workflow:

1. login/setup
2. repository creation
3. job execution
4. summary verification

## Start here

- `mentor-tests/README.md`
- `mentor-tests/docs/core-flow-test.md`

## Environment prerequisites

- Node 18+ and browser installs (`npx playwright install --with-deps`)
- Local environment running:
  - `Mentor.UI` UI
  - Mentor backend stack (`debugging` / `merly-mentor`)
- License and credentials for API-driven setup:
  - `MM_KEY`
  - `E2E_UI_BASE_URL`

## Core command patterns

- `npx playwright test`
- `npm run test-ui-core-flow`
- `npx playwright show-report`

## Troubleshooting pattern

When tests fail at auth or job polling, prioritize:

1. service readiness timing in local stack
2. bridge endpoint auth/session validity
3. repo bootstrap state (existing test repo conflicts)
4. UI selectors changed after frontend refactor

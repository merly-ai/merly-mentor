# Merly AI System Overview

## Core architecture

```text
User → Mentor.UI → Mentor.Bridge → MerlyMentor daemon
                         ↓
                  Merly.WebPortal (licensing/admin)
                         ↓
                  Merly.Installer (build + release tooling)
```

## Runtime components

- `Mentor.UI`
  - Human-facing web interface
  - Talks to `Mentor.Bridge` through HTTPS/API calls
- `Mentor.Bridge`
  - API gateway, auth/session orchestration, repository/job operations
  - Owns identity/session data for UI-facing flows
- `MerlyMentor` daemon
  - Ingestion, repository cloning, analysis, scoring, issue extraction
  - Exposed through the bridge layer for UI and API workflows
- `Merly.WebPortal` (`MerlyServiceAdmin`)
  - Licensing, key generation/activation, customer/component metadata, registration
  - Contains swagger-enabled ASP.NET API
- `Merly.Installer`
  - Produces channel-specific release assets for MacOS/Windows/Linux
  - Manages service installation and update asset lifecycle
- `mentor-tests`
  - End-to-end browser verification for the UI core path
- `debugging` / `debugging-new` / `debugging-old`
  - Multi-platform development and validation workspace for native daemon/runtime pieces
- `MP-CodeCheckBin-*`
  - Public release artifacts for Test/Staging/Pre-Release/Release channels

## Control/data flows

1. User authenticates in `Mentor.UI`.
2. `Mentor.Bridge` validates and maps actions to daemon jobs.
3. Daemon performs analysis and updates results.
4. `Mentor.UI` polls/reads repo/branch/points/job endpoints for state.
5. `Merly.WebPortal` services licensing and registration lifecycle.
6. `Merly.Installer` packages and distributes binaries/components.

## Standard stack entry points

- Bridge service (`Mentor.Bridge`): typically `go run .` (local dev)
- UI (local dev): `npm run dev`
- Installer build: CMake presets + platform-specific scripts in `Merly.Installer`
- WebPortal run: dotnet host project in `Merly.WebPortal/MerlyServiceAdmin`
- Runtime/dev orchestration: `merly-mentor` compose templates

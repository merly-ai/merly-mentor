# Repository Index

## Primary repos for active development

- `Mentor.Bridge`  
  Go API gateway + bridge service between UI and daemon.
- `Mentor.UI`  
  Next.js web client.
- `Merly.Installer`  
  Cross-platform installer/build/release tooling.
- `Merly.WebPortal`  
  Licensing and admin service (`MerlyServiceAdmin` ASP.NET app).
- `mentor-tests`  
  Playwright E2E verification harness.

## Runtime and packaging repos

- `merly-mentor`  
  Containerized/deployment oriented daemon package references and deployment
  templates.
- `MP-CodeCheckBin-MacOS`
- `MP-CodeCheckBin-Suse`
- `MP-CodeCheckBin-Windows`  
  Channeled release output for users.

## Support / legacy workspaces

- `debugging`, `debugging-new`, `debugging-old`  
  Native/build + historical validation workspaces. Useful for lower-level
  debugging and cross-platform reproduction.

## One-line docs entry points

- Bridge: [`bridge.md`](./bridge.md)
- UI: [`ui.md`](./ui.md)
- Installer and release: [`installer-and-release.md`](./installer-and-release.md)
- WebPortal/licensing: [`webportal.md`](./webportal.md)
- Runtime/dev workspace: [`daemon-and-debugging.md`](./daemon-and-debugging.md)
- QA/tests: [`tests.md`](./tests.md)

## Process pages for working across repos

- Local E2E validation: [`../process/e2e-local-validation.md`](../process/e2e-local-validation.md)
- Change/review/deploy process: [`../process/change-implementation-review-deploy.md`](../process/change-implementation-review-deploy.md)
- Agent/Codex execution instructions: [`../process/agent-codex-instructions.md`](../process/agent-codex-instructions.md)
- Thread runtime + delivery flow: [`../process/thread-runtime-and-delivery.md`](../process/thread-runtime-and-delivery.md)

# Merly AI Documentation Suite

This folder is the single onboarding and operations entry point for the whole
Merly AI workspace.

It links the following workstreams:

- Daemon/API control plane (`Mentor.Bridge`)
- UI (`Mentor.UI`)
- Installer/release pipelines (`Merly.Installer`, `MP-CodeCheckBin-*`)
- Licensing/admin backend (`Merly.WebPortal`)
- Automated verification (`mentor-tests`)
- Product runtime/dev harnesses (`merly-mentor`, `debugging`, `debugging-new`, `debugging-old`)

## How to use this documentation

Start at:

- [`system-overview`](./architecture/system-overview.md)
- [`repository-index`](./repositories/index.md)
- [`thread-template`](./runbooks/thread-template.md) when creating new threads
- [`onboarding/getting-started`](./onboarding/getting-started.md)

Then jump to:

- bug investigation: [`runbooks/bug-investigation`](./runbooks/bug-investigation.md)
- feature planning/delivery: [`runbooks/feature-delivery`](./runbooks/feature-delivery.md)
- release flow and platform artifacts: [`repositories/installer-and-release`](./repositories/installer-and-release.md)
- daemon movement: [`process/daemon-test-to-pre-release`](./process/daemon-test-to-pre-release.md)
- API-specific work: [`apis/index`](./apis/index.md)
- local end-to-end validation: [`process/e2e-local-validation`](./process/e2e-local-validation.md)
- implement/review/deploy: [`process/change-implementation-review-deploy`](./process/change-implementation-review-deploy.md)
- per-thread runtime + GitHub Actions delivery flow: [`process/thread-runtime-and-delivery`](./process/thread-runtime-and-delivery.md)
- operating instructions for humans/agents/Codex: [`process/agent-codex-instructions`](./process/agent-codex-instructions.md)
- workspace-level runtime config: [`/Users/ursmuff/source/merly.ai/.codex/config.toml`](/Users/ursmuff/source/merly.ai/.codex/config.toml)
- workspace-level instructions: [`AGENTS`](../AGENTS.md)
- per-thread runbook helper script: [`scripts/thread-runtime.sh`](../scripts/thread-runtime.sh)

## One-screen project map

1. `Mentor.Bridge` is the API gateway and orchestration layer.
2. `Mentor.UI` is the Next.js web client.
3. `merly-mentor` / `debugging` are the daemon/runtime side (analysis engine + ecosystem).
4. `Merly.Installer` builds and publishes install artifacts.
5. `MP-CodeCheckBin-*` repos host public release channels and installers.
6. `Merly.WebPortal` owns licensing/admin capabilities.
7. `mentor-tests` validates UI behavior against a running stack.

## Workspace instructions status note

The workspace has project-level instructions at:

- `AGENTS.md`
- `.codex/config.toml`

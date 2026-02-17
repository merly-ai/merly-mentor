# New Contributor Onboarding

## If you are a human engineer

1. Open the system map:
   - [`system-overview`](../architecture/system-overview.md)
2. Read repo owning area:
   - [`repository-index`](../repositories/index.md)
3. Open that repo's docs page for your change area.
4. Learn thread runtime and delivery path:
   - [`thread-runtime-and-delivery`](../process/thread-runtime-and-delivery.md)
5. Run the smallest verification loop in that repo before broad changes.
6. Open a thread with [`thread-template`](../runbooks/thread-template.md).

## If you are an agent

1. Start from the repository page that owns the issue.
2. Capture current behavior + reproduction commands.
3. Map API path using:
   - `Mentor.Bridge` for API and auth/job flow
   - `Mentor.UI` for UX and interaction flow
   - `Merly.Installer` for packaging/install flow
   - `Merly.WebPortal` for licensing/admin flow
4. Build a minimal fix plan with rollback.
5. Validate in this order:
   - unit/integration where possible
   - cross-repo E2E (if touched)
   - release/packaging check for install-impacting changes
6. Attach runtime/CI proof:
   - `./scripts/thread-runtime.sh check`
   - `./scripts/thread-runtime.sh smoke` (where thread scope allows)

## Suggested first-thread checklist

- What changed:
- Why changed:
- How to reproduce current issue:
- Files changed:
- Verification commands:
- Follow-up actions:

This checklist is lightweight for speed but should include enough context to be
handed off to another operator later.

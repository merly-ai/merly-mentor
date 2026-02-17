# API References

## Mentor.Bridge API

- Contract artifact: `Mentor.Bridge/API/Mentor API OpenAPI Specification.txt`
- Summary reference: `Mentor.Bridge/API/Mentor API Summary.md`
- Public endpoints include auth, repositories, branches, snapshots, jobs, issues, search, CI/CD.

## Merly.WebPortal API

- ASP.NET service in `Merly.WebPortal/MerlyServiceAdmin`.
- Swagger middleware is enabled in `Merly.WebPortal/MerlyServiceAdmin/Program.cs`.
- Service route coverage is split across `Merly.WebPortal/MerlyServiceAdmin/Controllers/`.
- Client generation hint exists in
  `Merly.WebPortal/MerlyServiceAdmin/README.md`.

## Mentor-UI API interaction surface

- UI calls into Bridge endpoints through server-side APIs and client hooks.
- Useful references:
  - `Mentor.UI/docs/useApi-hook.md`
  - `Mentor.UI/docs/logger-usage.md`
  - `Mentor.UI/UI_ARCHITECTURE.md`

## QA/API test surface

- `mentor-tests` validates core user flow endpoints indirectly through UI actions and
  repository/job outcomes.
- Start with `mentor-tests/docs/core-flow-test.md`.

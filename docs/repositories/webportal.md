# Merly.WebPortal Documentation

## Purpose

`Merly.WebPortal/MerlyServiceAdmin` is the licensing/admin ASP.NET service.
Use cases include:

- key generation / activation
- registration lookup
- component/version metadata (`VersionInfo` style APIs)
- customer-facing license and support workflows

## Start here

- `Merly.WebPortal/MerlyServiceAdmin/README.md`
- `Merly.WebPortal/MerlyServiceAdmin/Program.cs` (Swagger + pipeline)
- `Merly.WebPortal/MerlyServiceAdmin/Controllers/` for endpoint surface
- `Merly.WebPortal/MerlyServiceAdmin/Properties/launchSettings.json` for local launch config

## Swagger/API exposure

- This service configures Swagger generation in `Program.cs`.
- API client generation hint from `README.md`:
  - `nswag openapi2csclient ...`

## Dev run notes

- Requires ASP.NET toolchain and database context initialization (auto-seeded via `DbInitializer` on startup).
- Uses Azure AD authentication settings in `appsettings*.json`.
- Uses permissive CORS for service/API interoperability in current config.

## Common operations

- Verify `/swagger` endpoint in a running local service.
- Confirm controller route list by listing `Controllers/*.cs`.
- Confirm licensing workflows via API/UI endpoints before packaging new installer channels.

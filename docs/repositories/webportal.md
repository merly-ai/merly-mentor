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

## Public API / Swagger validation

- Script: `Merly.WebPortal/run-public-swagger-tests.sh`
- Base URL default: `https://merlyserviceadmin.azurewebsites.net`
- Test output defaults to `${TMPDIR}/merly-webportal-swagger-tests/<timestamp>`

Run smoke checks (swagger contract only):

```bash
cd /Users/ursmuff/source/merly.ai/Merly.WebPortal
./run-public-swagger-tests.sh
```

Skip long-running checks:

```bash
SKIP_PUBLIC_SWAGGER_SUITE=1 ./run-public-swagger-tests.sh
```

Run complete public API checks (uses trial key bootstrap):

```bash
TRIAL_EMAIL='qa-test@merly.ai' TRIAL_USERNAME='QA Test User' ./run-public-swagger-tests.sh
```

For endpoint checks that need a licensed key:

```bash
MM_KEY=<valid-trial-or-license-key> ./run-public-swagger-tests.sh
```

Relevant environment variables:

- `WEBPORTAL_BASE_URL`: base host for API (`http://localhost:5000` for local runs).
- `WEBPORTAL_SWAGGER_PATH`: swagger path (`/swagger/v1/swagger.json` default).
- `TRIAL_EMAIL` / `TRIAL_USERNAME`: used by `GETOrCreateKey` long checks.
- `MM_KEY`: optional license key to validate `/api/GetRegistration`.
- `SKIP_PUBLIC_SWAGGER_SUITE`: set to `1|true|yes|on` to skip long API checks.

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

# Render preparation and restore startup evidence

Date: 2026-09-04. Environment: local macOS, Elixir 1.20.4 / OTP 29.0.6, PostgreSQL 18.6. No hosted deployment or Gmail mutation.

## Changes and checks

- `render.yaml`: separate paid test web/worker/database, private database access, pinned existing runtimes, migrations before web deployment, no automatic deploys/previews, no Google secrets, initial restore mode enabled.
- Blueprint parsed and validated against `https://render.com/schema/render.yaml.json` using the locally available YAML/JSON Schema libraries. Passed. Render CLI v2.26.0 authenticated validation returned HTTP 401; workspace and billing validation remain blocked on login.
- New runtime tests first reproduced missing Render-host fallback, missing restore guard and acceptance of a too-short production secret. After implementation, all 52 backend tests pass. Formatting and whitespace checks pass.
- `mise exec -- bin/render-build` successfully built production assets and the release. It also ran TypeScript checking and retained the locked package versions.
- Created a uniquely named disposable database on the local loopback cluster. Invoked the built release migration command twice; both passed. No application worker is started by that migration entry point.
- Started the built release with `APP_ROLE=worker`, `RESTORE_MODE=true` and a nonexistent Google credential path. Verified no Oban process, Gmail not configured, and no jobs enqueued/executed.
- Started the normal worker on that disposable database, created one synthetic snapshot and observed it become verified through Oban execution.
- Started the web release on port 4012, verified HTTP 200 for readiness/home and `Cache-Control: no-store`. Stopped it and removed only the newly created disposable database. The development app/database were left in place.

## Limits

This proves the current release's local startup boundary, not a restored production database, Linux/Render execution, live backups, provider writes, hosted OAuth, TLS termination, or independent alert delivery. The read-only UI and Gmail adapter were not changed. No new dependencies were added.

Next: authenticated Render validation/provisioning and hosted smoke checks following [setup](../../render-phase-0-setup.md). Continue preparing the offline recovery card and experiment inventory while waiting for login.

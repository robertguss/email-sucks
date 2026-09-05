# Render Phase 0 setup

Date: 2026-09-04. Status: configuration and local release checks prepared; no hosted resources created. The owner will deploy through the Render dashboard; CLI login is not required for this path.

## Prepared deployment

[render.yaml](../render.yaml) defines a separate test web service, background worker and PostgreSQL 18 database in Virginia. Initial compute selections are 0.5 CPU/512 MB for each app process and 0.5 CPU/1 GB with 5 GB storage for the database. These are paid test resources, not a production capacity or availability claim. Confirm the displayed recurring total in the selected workspace before creation. Region and database major version are creation-time choices. [Render Blueprint reference](https://render.com/docs/blueprint-spec)

The database has no public IP allowlist entries. Both services use its internal connection string in the same region. This configuration uses Render's private network; it does not configure external database access. [Render database connections](https://render.com/docs/postgresql-creating-connecting)

Automatic deployments and previews start disabled. Regular git pushes therefore do not activate mail changes. The web pre-deploy command runs migrations; the worker has no migration command. Both initially start with `RESTORE_MODE=true`, avoiding a worker/migration race. No Google credential files are configured or copied from local development.

The Blueprint pins the existing verified Elixir 1.20.4, OTP 29.0.6 and Node 26.8.1 baseline, rather than Render's defaults. No package versions changed in this slice. Hosted availability of those exact runtime builds must still be demonstrated by the first Render build. The managed database selects major 18; record the provider's actual patch version after provisioning. [Elixir/OTP configuration](https://render.com/docs/elixir-erlang-versions), [Node configuration](https://render.com/docs/node-version)

## Operator sequence

Work through these one at a time with the owner; do not paste secrets into chat or git.

1. In the Render dashboard, choose New → Blueprint, connect `robertguss/email-sucks`, and select branch `main` with Blueprint path `render.yaml`.
2. Review the dashboard validation and resource preview in the intended workspace. Local validation against Render's published JSON Schema has passed; dashboard validation and workspace conflicts must still be checked before provisioning.
3. Deploy the reviewed Blueprint. Review the concrete resource list and recurring price before creation. Supply a fresh private `SECRET_KEY_BASE` of at least 64 bytes (for example, `mix phx.gen.secret` generated locally). Keep a private copy. Do not use Render's 44-character generated value for this Phoenix secret.
4. Wait for the web migration/build and both startups. Check `/health/ready`, the anonymous homepage, HTTPS, secure cookies after later sign-in, and runtime versions. Check the worker has no Oban process while restore mode is enabled. Record service IDs and sanitized revision evidence, never connection strings.
5. After migrations succeed, change the Blueprint's `RESTORE_MODE` to `"false"`, commit/push, sync, and deploy both services. Execute one synthetic snapshot on the dedicated database and verify the separate worker processes it. This enables only the synthetic queue, not Gmail interception.
6. Prepare a separate hosted OAuth client with the actual HTTPS callback and separate hosted vault/session keys. Mount the private JSON files as Render secret files. Set `GMAIL_OAUTH_FILE`, `GMAIL_KEYS_FILE`, and `GMAIL_REDIRECT_URI` only after those files and the allowed test identity are ready. The keys JSON format is documented in [local setup](phase-0-test-account-setup.md); use new hosted values, never upload the local database or local keys. The Google session secret must remain stable across web deployments; the separate vault key must remain recoverable outside Render.
7. The owner consents in the hosted app. Re-run the read-only profile/refresh checks. Provisioning or sign-in is not permission to activate interception. Follow the [experiment checklist](phase-0-gmail-reliability-proof.md) for the next controlled step.

The build script compiles the locked dependencies, checks/builds assets, then packages an Elixir release. Migrations use `EmailSucks.Release.migrate/0` without starting the application supervisor or workers. [Phoenix release deployment](https://phoenix.hexdocs.pm/releases.html), [Render pre-deploy commands](https://render.com/docs/deploys#pre-deploy-command)

## Restore startup boundary

Set `RESTORE_MODE=true` **before the first process boots against a restored database**. The setting accepts only `true` or `false`; a typo fails startup. In restore mode the application omits the Oban supervisor and does not read Gmail credential files, even if they are mounted. This blocks the current application's background execution and configured Google access. It is not a substitute for an isolated database, restricted operator access, or future per-operation write guards.

Do not attach a restored environment to the normal runtime environment group: that group will eventually enable jobs. Use a separate restore environment, no Google secrets, separate cookie secret, and keep restore mode enabled until reconciliation and explicit reactivation. Missing keys, pending/unknown sends, and stale release claims block reactivation. Current tests use a fresh disposable database; a real Render/R2 backup restore has not yet been exercised.

## Outstanding hosted evidence

- Dashboard Blueprint validation and actual Linux runtime availability/build.
- Managed Postgres patch, migration result, HTTPS/readiness and independent worker execution.
- Private hosted OAuth files, owner consent, real token refresh and recovery behavior.
- Sentry/Better Stack configuration and received external alerts.
- Managed recovery and encrypted R2 export/restore, separately held keys, measured RPO/RTO.

The current endpoint's database readiness is not a Gmail delivery-health signal. Do not use it to claim that held mail is safe during worker or provider failure.

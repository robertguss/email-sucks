# Phase 0 on exe.dev

**For the existing live VM, start with the [deployment and session handoff](exe-deployment-handoff.md).** It contains the exact host, current release, access blocker and repeatable deployment commands. The initial-deployment section below is historical bootstrap guidance; do not repeat it or regenerate secrets on the current VM.

The selected deployment is one dedicated VM, per [ADR-0002](decisions/0002-exe-vm-hosting.md). Docker Compose runs web, worker and PostgreSQL separately on that VM. No Render resources are needed. Initial deployment results and remaining limits are recorded in [evidence](evidence/phase-0/2026-09-04-exe-deployment.md).

## Layout and secrets

- Source: `/home/exedev/email-sucks`.
- Compose: `deploy/exe.compose.yaml`; project name `email-sucks-phase0`.
- Private files: `/home/exedev/.config/email-sucks/app.env` and `compose.env`, mode `0600`, parent directory `0700`. Never commit or print their contents.
- `app.env`: `DATABASE_URL`, fresh `SECRET_KEY_BASE`, `PHX_HOST`, `PORT=4000`, `POOL_SIZE=5`, `RESTORE_MODE=true`. Do not add Google credentials for the initial smoke check.
- `compose.env`: `APP_ENV_FILE` (absolute path above), `APP_REVISION` (image tag matching the deployed revision), independently generated `POSTGRES_PASSWORD` and `DB_APP_PASSWORD`. The database URL uses the application role and its password, host `db`, database `email_sucks_phase0`.
- The database initialization script creates the application role without superuser privileges. It runs only on a new volume. Changing environment passwords later does not rotate existing PostgreSQL credentials.
- PostgreSQL 18 uses the named volume mounted at `/var/lib/postgresql`. Do not use `docker compose down --volumes` against this deployment.

The Docker build uses the locked dependencies and existing Elixir 1.20.4 / OTP 29.0.6 / Node 26.8.1 baseline. Compatible image tags were verified through Docker Hub. Build and runtime use Debian bookworm; the runtime contains the release and runs as `nobody`. No developer OAuth files or database are copied.

## Initial deployment

Run these separately from the source directory, checking each result:

```bash
docker compose --env-file /home/exedev/.config/email-sucks/compose.env -f deploy/exe.compose.yaml config --quiet
docker compose --env-file /home/exedev/.config/email-sucks/compose.env -f deploy/exe.compose.yaml build web
docker compose --env-file /home/exedev/.config/email-sucks/compose.env -f deploy/exe.compose.yaml up -d --wait db
docker compose --env-file /home/exedev/.config/email-sucks/compose.env -f deploy/exe.compose.yaml run --rm -T migrate </dev/null
docker compose --env-file /home/exedev/.config/email-sucks/compose.env -f deploy/exe.compose.yaml up -d --wait web worker
```

Configure exe.dev's proxy to port 4000, retaining private visibility. Verify `/health/ready`, the anonymous homepage/assets, actual runtime/database versions and inert worker state. Web and worker restart automatically unless explicitly stopped; Docker must be enabled at boot. A worker container running in restore mode is not proof that it executes jobs.

After inert checks, explicitly set `RESTORE_MODE=false` in the private app environment and recreate web/worker to run synthetic jobs. This does not configure Gmail. Record a real separate-worker synthetic receipt before continuing to hosted OAuth.

## Updates, rollback and recovery

### Hosted OAuth overlay

After the initial smoke checks, use `deploy/exe.gmail.compose.yaml` in addition to the base Compose file. Only the web container mounts the hosted OAuth client and key files; the synthetic worker remains without Gmail configuration. Set `GMAIL_SECRET_DIR` in the private Compose environment to the absolute directory containing `google-oauth.json` and `keys.json`. Both files must be owned by UID 65534 (the image's `nobody` user), mode `0400`, in a private host directory. The bind mounts are read-only and refuse missing source files.

Generate fresh hosted vault and session keys; retain private recovery copies outside the VM. Never reuse local development keys. Register the exact callback `https://cougar-cedar.exe.xyz/auth/google/callback` in a separate web OAuth client within the existing Google project. The app now requests identity/email and Gmail modification access for the single-message and three-message controlled hold/release experiments. Existing read-only grants require reconnection.

Use both Compose files for subsequent updates so the mounts remain present:

```bash
docker compose --env-file /home/exedev/.config/email-sucks/compose.env -f deploy/exe.compose.yaml -f deploy/exe.gmail.compose.yaml up -d --no-build --wait web worker
```

Using the base file alone recreates the web container without Google configuration. Keep restore rehearsals on the base configuration with `RESTORE_MODE=true`. Production `debug_errors=false` must be present at compile time as well as in runtime OAuth configuration; Phoenix release validation rejects a mismatch.

### Application and database updates

Deploy reviewed source and tag the image with its commit. Build before stopping a running service. Before a database-changing update, take and verify an encrypted backup. Stop the worker before migrations; keep the web stopped too if the migration is incompatible with its running version. Run migrations once, then recreate web/worker. Retain the previous image for rollback. An image rollback does not undo migrations: confirm schema compatibility or perform an isolated restore with jobs and Gmail disabled.

Maintain encrypted exports outside this VM and separately held decryption keys. The existing `bin/backup-export` and `bin/backup-restore` document the logical backup boundary. The owner-selected [same-VM backup timer](vm-backups.md) now retains 14 daily encrypted exports, with a real archive restored independently. Scheduled off-VM/R2 upload, missed-backup alerts and total-VM-loss restoration still need implementation and evidence. Do not enable interception merely because web readiness passes.

The private exe.dev proxy must be included in the hosted OAuth browser rehearsal. External monitoring needs an authenticated or deliberately exposed health route; a successful proxy login page is not an application health check. Group human consent instructions into a manageable batch.

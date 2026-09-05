# exe.dev initial deployment evidence

Date: 2026-09-04 (America/New_York). Application code: `78de236`; deployment files introduced in the commit containing this record. No application logic or dependency lockfile changed.

## Observed results

- Verified the SSH host fingerprint against exe.dev's published fingerprint before accepting it. Dedicated Ubuntu 24.04.4 VM: approximately 8 GiB RAM, 50 GB disk; initially no containers. Docker 29.1.3 and Compose 2.40.3 were already installed. Enabled Docker at boot.
- Compose configuration validation passed. Built the Linux production release on the VM using verified Docker Hub tags for the existing Elixir 1.20.4, OTP 29.0.6 and Node 26.8.1 baseline. TypeScript checking, asset compilation and application compilation with warnings-as-errors passed. Existing upstream dependency warnings and an optional missing SCTP library warning occurred; TCP database and web operations succeeded.
- PostgreSQL 18.6 initialized on its named volume. The application database role has neither superuser nor database-creation privileges. All 11 migrations succeeded through this role. PostgreSQL has no host port mapping.
- Initial web and worker startup used `RESTORE_MODE=true`, with no Google credentials mounted or configured. HTTP readiness returned `200` with `{"status":"ok"}`. Homepage and both referenced assets returned HTTP 200.
- Configured the exe.dev HTTPS proxy to port 4000 while preserving private visibility. Unauthenticated HTTPS returned the expected redirect to exe.dev login with valid TLS. The owner's subsequent screenshot confirms the app renders at the private HTTPS URL and shows Google connection setup is not configured. Hosted Google callback remains unverified.
- Enabled only the existing synthetic queue after migrations. With worker stopped, a two-message synthetic snapshot remained pending and its Oban job available; the web queue was disabled. Starting the separate worker produced a verified snapshot and completed job at attempt 1 with unchanged membership. Verified the running worker supervisor contains Oban and its queue limit is 5.
- Restarted PostgreSQL, web and worker containers. Readiness recovered; the snapshot remained verified and the job remained completed at attempt 1. This is container-restart evidence, not a full VM reboot or provider-outage rehearsal.
- Observed idle container memory: approximately 253 MiB web, 261 MiB worker, 70 MiB PostgreSQL. Approximately 41 GB disk remained free after building. These are point-in-time measurements, not a capacity benchmark or guarantee.

## Encrypted restore rehearsal

Streamed a custom-format PostgreSQL dump over SSH into local `age` encryption. A fresh private decryption identity and encrypted archive are retained outside the repository on the owner's Mac, under `~/.config/email-sucks/exe-backup-rehearsal/`. No key or plaintext archive was committed or displayed.

Fully decrypted/authenticated the archive into a private temporary directory before restoration. Restored into a new disposable database owned by the application role, using a single transaction and no-owner/no-privileges. Compared snapshot status, exact message membership and migration count with the source. Started the release against the restored database with restore mode enabled: the actual application supervisor contained no Oban child, Gmail configuration was absent, and exact fixture data matched. Removed the disposable databases, temporary plaintext and temporary remote environment files. Retained the encrypted local archive and private key.

This is a one-off export off the VM and a same-VM isolated database restore. It does not prove scheduled R2 uploads, independent alert receipt, whole-VM-loss restoration, accepted recovery times or separately backed-up key custody. The previous 98 backend/seven browser checks cover the unchanged application code; they were not rerun for these deployment-only changes.

## Current state and next action

Web, worker and PostgreSQL run on the dedicated VM. Restore mode is false for the synthetic queue only. The database contains no Gmail accounts; no development credentials were copied and no Gmail requests, sends or interception occurred. Owner browser access is screenshot-confirmed. Next prepare a separate hosted read-only OAuth client, one human setup action at a time. Phase 0 remains incomplete.

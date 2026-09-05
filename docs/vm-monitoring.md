# Phase 0 operational heartbeat

The monitor answers three questions: is the web process serving database-backed readiness, is the worker's semantic health check passing, and is a recent encrypted backup still present? It sends a Better Stack heartbeat only when all three pass. A stopped VM cannot send heartbeats, so the external service can detect total host failure too.

Implementation is available; external monitor creation, alert delivery, and live failure rehearsals still need verification. No external monitor is provisioned by this repository.

## Checks and timing

`bin/vm-monitor --check-only` runs these checks without contacting Better Stack:

- Local `http://127.0.0.1:4000/health/ready` must return HTTP 200 and exactly `{"status":"ok"}`.
- The worker container must successfully execute `EmailSucks.OperationalHealth.check/0`, returning `healthy: true` and an empty failure list. A reachable web process alone is insufficient. The semantic probe checks the local Oban queue, jobs overdue by five minutes or discarded, saved pending/failed Gmail recovery, known unavailable access while mail is at risk, and filter baseline warnings during unfinished cleanup. Historical baseline warnings after completed cleanup do not suppress recovery heartbeats. Intentionally held mail with usable access is healthy. This reads saved state only: it does not call Gmail, refresh tokens, discover newly revoked access, or verify live filter drift. Periodic provider reconciliation remains a separate unfinished requirement.
- `/home/exedev/backups/email-sucks/last-success.json` must name a regular, nonempty encrypted archive whose size matches the receipt. Its completion timestamp must be timezone-aware, no more than 26 hours old, and not in the future. This is a freshness/presence check; restore drills verify archive integrity and restorability.

The systemd timer runs every 60 seconds. Each run has a 45-second deadline; systemd will not start another instance of the same oneshot service while it is active. HTTP requests have five-second timeouts and worker RPC has a 20-second timeout and a 64 KiB stdout limit. Its single `EMAIL_SUCKS_HEALTH=` response marker distinguishes JSON from Erlang startup warnings; absent or duplicate markers fail the check. Stderr is discarded. Failed checks withhold the heartbeat; they do not send an immediate `/fail` request.

Configure the external heartbeat with a **60-second period and 180-second grace**. This tolerates a brief planned restart but detects sustained loss in approximately four minutes after the last successful heartbeat (up to roughly nine minutes for jobs after the five-minute overdue threshold), leaving room within Phase 0's 15-minute detection target. This is the configured target, not a claim that alert delivery has been measured.

## Owner setup and installation

Use the owner's existing Better Stack workspace and chosen alert destination. Create a heartbeat monitor there with the period and grace above and this runbook linked in its incident instructions. Better Stack heartbeat monitoring begins after its first successful heartbeat; an unprimed monitor does not establish coverage. See the [official heartbeat documentation](https://betterstack.com/docs/uptime/cron-and-heartbeat-monitor/).

Store the generated URL in `/home/exedev/.config/email-sucks/monitor-heartbeat-url`, owned by `exedev`, with mode `0600`. Enter it through a private file transfer or editor; do not paste it into commands, logs, screenshots, or source control. The runner accepts only `https://uptime.betterstack.com/api/v1/heartbeat/<token>` with an alphanumeric, underscore, or hyphen token, and refuses redirects. It disables environment HTTP proxies for both probes.

After deploying an image containing `EmailSucks.OperationalHealth`, check locally:

```sh
/home/exedev/email-sucks/bin/vm-monitor --check-only
```

Install and enable only after the external destination and private URL are configured:

```sh
sudo install -m 0644 /home/exedev/email-sucks/deploy/email-sucks-monitor.service /etc/systemd/system/
sudo install -m 0644 /home/exedev/email-sucks/deploy/email-sucks-monitor.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start email-sucks-monitor.service
sudo systemctl enable --now email-sucks-monitor.timer
```

Confirm the first heartbeat appears in Better Stack, then rehearse a sustained worker failure in a safe controlled window. Record the induced failure time, incident time, actual delivery to the owner, and recovery time. Repeat for the agreed Phase 0 web, database, backup, and semantic failure scenarios. Do not mark independent alerting complete until delivery has actually been observed. Never stop or alter live mail recovery during a rehearsal.

## Incident response

Start with `journalctl -u email-sucks-monitor.service --since '15 minutes ago'`. Each completed run emits one JSON event with a UUID `run_id`, a boolean `healthy`, a `check_only` flag, and fixed `failures` codes. No raw command output, mailbox metadata, token, or heartbeat URL is logged.

| Reason | Next action |
| --- | --- |
| `web_unavailable`, `web_response_invalid` | Inspect web/database container status and `/health/ready`; restore database-backed readiness. |
| `worker_unavailable` | Inspect worker container status and deployment revision. Restore the worker before retrying. |
| `worker_response_invalid` | Check that the deployed release includes the expected health module and inspect worker logs privately. |
| `worker_unhealthy` | Run the documented semantic RPC directly to inspect its bounded failure names, then repair the reported recovery/queue condition. |
| `backup_stale`, `backup_missing`, `backup_future`, `backup_invalid` | Inspect backup service status, disk space, system clock, and the last receipt. Follow [the backup runbook](vm-backups.md); do not manufacture a successful receipt. |
| `heartbeat_configuration_invalid` | Check the private URL file exists, is a regular file with mode `0600`, and contains the expected host/path. Do not display its contents in logs. |
| `heartbeat_delivery_failed` | Check host outbound connectivity and Better Stack service status. Never log the secret URL while debugging. |
| No recent journal event | Check host reachability, systemd timer/service state, and deadline kills. An external incident without local logs can mean total VM failure. |

After repair, run `--check-only`, start the monitor service once, and confirm external recovery and owner delivery. Keeping the external monitor enabled during failure is essential; disabling it suppresses the evidence the owner needs.

## Local verification

```sh
python3 -m unittest test/vm_monitor_test.py
```

Tests cover healthy checks, worker failure despite a healthy web probe, nonzero/time-limited/malformed RPC, backup freshness and malformed/missing/symlink archives, heartbeat URL/mode restrictions, redirect refusal, delivery failure redaction, and heartbeat suppression. These tests use mocks and temporary files and do not contact external services.

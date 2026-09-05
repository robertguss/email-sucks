# Operational monitor implementation

Date: 2026-09-05. Status: locally verified; deployment dry run and independent
alert delivery are separate steps. No external monitor has been configured or
primed, and no alert has been delivered by this work.

The runner checks database-backed web readiness, worker semantic health and
same-VM backup freshness before sending a Better Stack heartbeat. It withholds
success on any failed check. A 60-second timer and proposed 180-second external
grace target sustained-failure detection within four minutes, or approximately
nine minutes for jobs after the five-minute overdue threshold. These are timing
budgets, not measured alert receipt.

## Local evidence

- 186 backend tests passed, including ten operational-health cases covering
  absent worker, pending/failed recovery, known revoked access, intentional held
  mail, completed cleanup warnings and each unresolved job-state category.
- Nine Python runner tests passed: failure suppresses heartbeat, worker timeout,
  nonzero exit, bounded output, malformed/duplicate result markers, backup
  freshness/presence, URL permissions/host restrictions and delivery redaction.
- Real Oban worker launched against a separate fresh local database with Gmail
  configuration files unset. The probe returned healthy with the queue running,
  unhealthy with only `worker_queue_unavailable` after pausing, and healthy again
  after resuming. No Gmail operation or external heartbeat occurred.
- Compilation with warnings-as-errors and formatting passed.

An initial runtime-test attempt using the unit-test application's manual Oban
configuration did not start a queue. The real-worker rehearsal above supplies
runtime evidence separately; the passing unit tests do not pretend that a mocked
queue was running.

The runner retains at most 64 KiB of worker output and accepts exactly one marked
JSON response, allowing the observed harmless Erlang SCTP startup warning. It
never forwards raw RPC output, exception text, mailbox identifiers or the private
heartbeat URL. Every local result carries a generated run UUID and fixed failure
codes. HTTP redirects and environment proxies are disabled.

A rejected stale filter action no longer overwrites a saved provider failure. The
review finding was reproduced with a failing test; after the fix, both pending
creation failure and active filter drift survive rejected actions, and semantic
health remains critical. Interrupted batch finalization also remains pending even
when all per-message outcomes were already confirmed.

A historical baseline warning after completed filter cleanup is retained as
evidence but does not prevent a recovery heartbeat forever. A regression test
failed before that condition was corrected and passed afterward.

## Limits and remaining proof

Semantic health reads saved state. It cannot discover newly revoked Google access
or live filter drift until a separate provider operation records the failure;
periodic provider reconciliation remains unfinished. Backup checking establishes
freshness and presence, not decryption or off-VM durability. Sentry is not
configured. The owner's workspace/destination is pending, so independent alerts,
priming, failure delivery, total-VM outage and notification deadlines remain
unproven. Follow the [monitor runbook](../../vm-monitoring.md).

Review receipt: `20260905-094452-2f643732`, five local lenses plus independent
Claude Opus 5 review. The stale-action masking finding and two additional
health predicate corrections were independently revalidated; no actionable
findings remain. Live systemd and external receipt proof remain separate.

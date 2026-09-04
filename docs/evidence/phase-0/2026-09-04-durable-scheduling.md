# Durable synthetic scheduling evidence

Date: 2026-09-04. Local fixtures only; no timer, Gmail calls or deployment.

Scheduling persists resolved occurrences with their UTC instant and IANA version. Repeated planning reads the saved resolution. Schedule revision changes cancel only unclaimed old occurrences. Claims coalesce elapsed windows into one run; future windows remain unclaimed. Scheduled release and Check Now share the account lock and unique active-run constraint. Manual clicks have durable receipts, including clicks that join an existing scheduled run, so replay cannot create another delivery after completion.

Finishing a run requires all journal members to have confirmed synthetic released outcomes. Empty runs can finish without provider work. Unknown/unavailable members prevent completion. Recovery blocks normal claims and completion. The older synthetic snapshot verification job alone cannot complete a delivery run.

85 backend tests pass, with application compilation and formatting. New examples cover overdue coalescing, saved resolution, stale revisions, future windows, schedule edits during active work, manual replay and recovery. A two-connection PostgreSQL barrier test proves simultaneous scheduled/manual requests return one run and one frozen snapshot.

Limits: callers provide synthetic held membership. This does not implement a Gmail inventory/sync boundary, production scheduler timer, real release adapter, notification or full recovery. Tests do not establish exactly-once provider execution. Next: exercise journal claims and reconciliation through a fault-injected synthetic provider runner instead of manually recording all outcomes.

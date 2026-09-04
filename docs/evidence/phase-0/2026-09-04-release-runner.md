# Fault-injected synthetic release runner

Date: 2026-09-04. Local fixture callbacks, not a Gmail adapter.

The runner claims one exact snapshot member, inspects provider state, writes only if a fresh claim observes held mail, and reads back a successful write before recording release. Unknown responses remain journaled as unknown. Expired claims inspect first and do not write during reconciliation. Unavailable source is recorded without attempting restoration. Provider calls occur outside database transactions.

89 backend tests pass, including four new runner tests: provider success with a lost response causes one write and a later confirming read; a crash retains uncertainty; successful release reads back outside a transaction; unavailable source and active recovery suppress writes. These complement separate-connection journal/scheduler tests.

Limits: the callback models a provider with explicit held/released/unavailable observations. It does not establish Gmail consistency, label routing, HTTP cancellation, rate limiting, real worker restart behavior or mailbox-wide recovery. No automatic runner/timer is installed and the app remains read-only.

Next: encrypted local backup/restore rehearsal with jobs and Gmail disabled on restored startup.

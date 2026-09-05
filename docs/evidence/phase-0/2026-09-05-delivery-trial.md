# Controlled five-minute delivery trial

Implementation of tasks 2–4 in [the usable experiment](../../../tasks/plan.md).
This does not pass the broader Phase 0 gate or the owner's product evaluation.

The trial uses one closed Hold-only profile with the exact configured sender,
recipient, subject and nonce marker. Existing experiment histories remain separate.
Start persists intent before filter creation. Each scheduled/manual run freezes
at most 20 matching held messages before release; incomplete queries fail visibly.
Read-before-write and provider readback preserve unread state and resolve uncertain
writes. Later arrivals cannot expand a frozen run. Review uses each saved run's
exact messages and persists separately from Gmail read state.

A dedicated Oban queue runs only in the Gmail-configured web service. Jobs contain
only a run UUID. Internal access checks persisted trial authority, connected allowed
identity and the disconnect fence, and reuses token refresh. The separate worker
still has no Gmail credentials; restore mode has neither Gmail access nor jobs.
The configured web enables Oban leadership/plugins so its five-minute Lifeline
actually runs. Job timeout is 55 seconds.

Check Now has a stable retry receipt, joins unfinished due work and preserves the
next scheduled occurrence. Empty windows keep the latest nonempty delivery visible.
Stop persists a fence, removes owned interception, then restores eligible held mail;
a completed stop cannot restart this profile. Disconnect uses the same fence.

## Local evidence

253 backend and 60 browser tests pass; formatting, compilation with warnings as
errors, TypeScript and whitespace checks pass. Coverage includes authenticated/CSRF
routes, logout execution, token refresh/scope failures, query/capacity errors,
filter ownership, frozen membership/new arrival, manual receipts/cadence,
stop/disconnect and exact review persistence. Browser tests cover activation
instructions, scheduled state, Check Now completion, a lost response with the same
receipt, overdue/failure states, stop, and responsive light/dark layouts.

The durability test uses separate PostgreSQL connections and kills a worker process
after the fixture provider accepts its write but before acknowledgment is saved.
The frozen intent remains committed and competing execution is refused by the
account lock. A separate Oban supervisor is stopped/restarted; installed Lifeline
rescues the executing job; retry through the production worker entrypoint confirms
release with one total provider write and no browser session. The attempt timestamp
is aged 301 seconds to exercise the production five-minute rescue bound without a
five-minute test sleep. A separate database failure regression rejects run cancellation
and proves stop finalization rolls back atomically; retry completes without losing
history. This is process/supervisor restart evidence, not an OS or
container restart, nor proof of live Gmail timing.

Simplification removed unreachable nil-ledger compatibility branches in the new
trial presenter. Reuse/efficiency passes found no worthwhile behavior-preserving
change; parent performed these passes after the harness rejected new review agents
at its thread limit. Review `email-sucks-trial-review-20260905-144036` completed using the available
code-review skill (the prior Compound Engineering plugin was removed). It used an
independent spec reviewer and direct standards coverage after the thread limit
prevented another reviewer. All three actionable findings are fixed with regressions: trial-only Stop cleanup
preserves inaccessible historical fixtures and rows; authenticated Check Now joins
an independently executing worker; an accepted request with a lost response keeps
its receipt after server completion and browser reload. Stop also safely abandons
starting intent before any filter journal/provider write exists. No cross-model review is claimed.

## Hosted validation

Image `d034e6e` is deployed. Fresh 21:28 UTC encrypted backup was copied to the
owner Mac, checksum matched and full decryption authenticated. Migrations/readiness
passed, web delivery queue is active at concurrency one, and the separate worker
has no Gmail configuration and retains its five-worker synthetic queue. All five
pre-existing journal fingerprints match. Operational monitor check-only is healthy.

The authenticated page activated the exact trial profile. Live readback confirms
one owned Hold filter with exact saved specification; all three original filters
are unchanged. Exact filter/nonce/label and recovery details are saved privately.
An empty Check Now ran through the real Oban executor and completed on attempt one;
the future scheduled occurrence remained unchanged. The schedule began at
21:35:22 UTC and repeats every five minutes.

The first owner fixture was observed unread outside Inbox under the exact trial
label. The 22:35:22 scheduled run completed empty. A subsequent manual Check Now
run released the exact single frozen message at 22:35:55 UTC, completed on attempt
one with no error, removed only its trial label and added Inbox. Unread and every
other label were preserved. The 22:40:22 scheduled time did not change. The browser
shows one available conversation left to review; operational health is green.
Private before/after metadata and run/job evidence are saved. This verifies manual
delivery, not a nonempty scheduled delivery. The agent did not invoke Check Now
for this message; do not infer who initiated the recorded request.

Trial remains active. A second owner fixture is needed for timed delivery; leave
Check Now untouched while observing the schedule.

Next observe owner-sent held arrival → scheduled delivery, followed by stop/restore
and the owner's actual feedback. Agent email
sending is not authorized. Unobserved steps remain open.

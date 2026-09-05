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

Reviewed implementation is pushed at `d034e6e`; deployment awaits owner unlock
of 1Password for SSH signing. Live remains `58e23a5`, with no trial active. The fresh 18:34 UTC encrypted archive was copied to
the owner Mac, checksum matched and full decryption authenticated. Before live
activation, verify migrations/readiness, web-only queue configuration, old journal
fingerprints and the authenticated trial page. Save original filters and the exact
owned filter recovery details privately before requesting a fixture.

Then observe owner-sent held arrival → scheduled delivery and another arrival →
Check Now, followed by stop/restore and the owner's actual feedback. Agent email
sending is not authorized. Unobserved steps remain open.

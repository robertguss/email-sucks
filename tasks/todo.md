# Usable delivery experiment tasks

Plan: [plan.md](plan.md). These are implementation tasks, not completed evidence.

## 1. Review a real saved test batch
- [x] Show the exact existing batch's available messages with sender, subject and safe preview.
- [x] Persist per-batch reviewed state independently of Gmail unread state; show a finite remaining count.
- [x] Clearly distinguish unavailable/pending content and do not pull new Inbox arrivals into the batch.
Verification: focused query/review tests and authenticated browser flow, including reload,
mobile layout and zero Gmail mutation requests. Local verification passed: 229 backend /
53 browser tests; hosted page/review/reload/undo and GET-only metadata validation passed.
Original recovery journals unchanged. Dependencies: none.
Likely scope: batch presentation/query and review persistence, page/controller and browser tests;
split persistence and UI implementation if the change exceeds one small unit.

## 2. Connect durable execution to the controlled Gmail boundary
- [x] Select the smallest execution design that preserves account serialization and the existing credential boundary; document the decision.
- [x] Prove a persisted due request survives executor restart and uses frozen exact-message membership.
- [x] Prove failure/retry, concurrent manual execution and recovery preserve known/unknown outcomes.
Verification: independent connection/process-death and restarted Oban/Lifeline tests
pass with bounded fixture provider; live OS/container restart remains unobserved.
Dependencies: none; required before timed live intake. Likely scope: execution adapter,
existing scheduling integration and focused process tests; separate units as needed.

## Checkpoint A
- [x] Real saved batch is usable; execution design and failure tests pass.
- [x] Compile and relevant tests pass. Record owner feedback when available without blocking independent implementation.

## 3. Add repeatable bounded intake
- [x] Create a separate trial journal and exact test criteria; preserve historical experiment records and unrelated filters.
- [x] Discover only matching test arrivals with bounded pagination and explicit incomplete/error state.
- [x] Stop disables owned interception before tracked restore; repeated stop is safe and preserves unread state.
Verification: scoped filter/intake/recovery tests pass; guarded attended provider
readback remains pending.
Dependencies: 2. Likely scope: trial state, bounded provider integration and recovery tests;
implement intake and recovery as separate small units before activation.

## 4. Experience delivery and Check Now
- [x] Display the saved next delivery with timezone, overdue and failed states that reflect server state.
- [x] Due execution and Check Now join one account release, freeze membership and expose confirmed progress.
- [x] Arrivals during release remain for the next batch; completion leads to the real review view.
Verification: local scheduler/manual/recovery tests and browser flow pass (253
backend / 60 browser total). Review fixes, deployment and empty live Check Now pass. Trial active; first owner
fixture passed manual Check Now; a second fixture for timed delivery and stop
evaluation remains pending.
Dependencies: 1–3. Likely scope: scheduling facade, delivery page and integration tests;
separate backend and UI units if needed.

## Checkpoint B / 5. Evaluate the experiment
- [ ] Run attended held arrival → timed delivery, then held arrival → Check Now; verify stop/restore.
- [ ] Verify restart/failure and release-versus-recovery behavior for the bounded flow.
- [ ] Record the owner's actual experience and decision to repeat, revise or stop.
Verification: sanitized live evidence and explicit owner feedback; leave unobserved criteria open.
Dependencies: 4. Likely scope: evidence and progress documents, fixes only for observed failures.

Every implementation unit must leave the existing app working and run checks appropriate
to its changes. Keep the broader Phase 0 checklist in PROGRESS.md; do not copy or waive it here.

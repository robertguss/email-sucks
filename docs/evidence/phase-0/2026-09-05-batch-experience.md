# Usable saved batch — implementation and validation

Task 1 of the [usable experiment](../../../tasks/plan.md).

The new /batch screen reads only the three existing frozen fixture IDs. It groups
saved members into conversations and shows every member's sender, subject, safe
preview and availability. Review/undo persists in a separate ledger without Gmail
writes or changes to prior recovery records. Source revision/membership drift
rejects stale review actions. Missing, excluded and pending content remains visible;
only available conversations can be reviewed and incomplete mail cannot appear caught up.

229 backend and 53 browser tests pass, plus formatting, compilation with warnings
as errors, TypeScript and whitespace checks. New tests cover the real auth/CSRF
controller chain, exact membership, grouping, review/reload/undo, stale actions,
provider failures, disconnect, deletion after review and frozen-thread drift.
Responsive light/dark browser views were inspected at 390 and 1440 pixels.

Simplification removed unused page props. Independent review run
20260905-140138-batch completed with eight local lenses and Claude Opus 5. Both
validated findings were fixed with red/green regressions: every grouped message
is visible; unavailable mail is distinct from pending delivery and gets appropriate
guidance. Other test gaps are recorded in the review receipt; no actionable
finding remains unapplied. No claim of live usability feedback is made.

Hosted validation pending. Fresh 18:01 UTC backup was copied to the owner Mac,
checksum matched, full archive authenticated and archive catalog read. Deployment
must preserve all existing journals, verify authenticated page/review/undo and
confirm unchanged Gmail metadata through a GET-only guard. Check readiness and
operational monitor after migration. If the new view fails, return to existing
controls; do not reset journals or mutate Gmail to repair a presentation problem.

Timed delivery, repeatable trial intake and owner evaluation remain subsequent
experiment tasks. This screen does not pass the overall Phase 0 gate.

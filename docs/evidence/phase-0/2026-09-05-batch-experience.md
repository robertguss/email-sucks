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

Hosted image `58e23a5` passed migration, readiness and operational monitor checks.
A fresh 18:01 UTC encrypted backup was copied to the owner Mac, checksum matched,
full archive authenticated and archive catalog read. All four original recovery
journal fingerprints match before/after deployment and validation.

A GET-only provider guard loaded all three saved conversations, reviewed/reloaded/
undid one, and verified unchanged Gmail metadata and the original batch row:
18 reads, zero Gmail writes, three available conversations, zero pending.
The authenticated Chrome page independently displayed all three messages; review
persisted after reload and undo returned all three to unreviewed for the owner.
This verifies the interaction, not the owner's product evaluation.

If presentation fails, return to existing controls; do not reset journals or
mutate Gmail to repair a presentation problem.

Timed delivery, repeatable trial intake and owner evaluation remain subsequent
experiment tasks. This screen does not pass the overall Phase 0 gate.

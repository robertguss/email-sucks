# Three-message controlled Gmail batch

The authenticated Phase 0 page offers one bounded batch rehearsal. It requires exactly one Inbox message for each subject `phase0-batch-001`, `phase0-batch-002`, and `phase0-batch-003`, from the configured controlled sender to the allowed account. Header mismatches, duplicate search results, paging, duplicate IDs, and Spam/Trash/Draft placement prevent preparation. These should be three separate messages, not replies.

All three IDs and the app's `Postman/Controlled-batch` label ID are saved before any message modification. Every per-message result commits before the next member runs. A partial or unknown result stays pending and displays an error; other members can finish. Recover reads Gmail first and writes only unresolved members whose current labels still need the saved projection. It never searches for additional members. Previously confirmed entries detect later external changes without overwriting them. Counts are explicitly last-confirmed counts; errors can coexist with them.

Release first saves release intent for all unresolved/held members, including interrupted holds. It then adds Inbox and removes only the controlled batch label, preserving unread and unrelated labels. Release/Recover are safe to repeat; Hold cannot create another batch once one is saved. After release, the explicit repeat form verifies every saved member is still released, then commits hold intent for those same IDs and advances a repeat revision. Stale or duplicate forms cannot re-hold mail, including after a subsequent release. No recovery record is reset or deleted. Recovery is user-triggered, not continuous sync or a scheduled production batch service.

Batch, single-message, refresh, OAuth and disconnect operations share the existing database connection lock. Safe disconnect restores and verifies the single fixture and all saved batch members before saving revocation intent. Any failed member retains credentials and pauses ordinary mailbox operations for recovery. No app-owned interception filters exist in this prototype.

## Deployment and rollback

Take and authenticate an encrypted database backup before the additive migration. Preserve the Gmail Compose overlay when recreating web/worker. Older images do not know about the batch: do not roll back to an older image once a batch exists, or while disconnect is pending. Keep the current release available to finish recovery. The new batch remains empty until the explicit Hold action passes all fixture checks.

## Proof boundary

Automated provider tests cover partial response loss, fixed membership with a later arrival outside the batch, unrelated-label preservation, external recovery, strict fixture validation and failed-member disconnect. A real-commit, independent-connection test kills the second release member after the simulated provider applied it: the first result survives, a competing operation is refused, and recovery releases all three with exactly one write per member.

Live three-message hold and interrupted release recovery across a web restart now passed with no duplicate writes; [evidence](evidence/phase-0/2026-09-05-live-batch-recovery.md). [Held-batch disconnect](evidence/phase-0/2026-09-05-held-batch-disconnect.md) also passed live. [Arrival between interrupted release and recovery](evidence/phase-0/2026-09-05-live-arrival-recovery.md) now passed without expanding membership or changing the newcomer. Continuously executing worker races and hold crashes still need live proof. General interception, scheduled delivery, paging, production accounts and sending remain disabled.

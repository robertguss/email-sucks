# Controlled safe disconnect deployment

Date: 2026-09-05 UTC. Deployed revision: `08e06d3` (`phase0-disconnect-20260905`). This is the single-message controlled prototype, not general held-mail recovery.

## Verified

- 125 backend tests passed. New tests cover restore/read-back before revoke, unchanged unrelated labels, retained credentials on recovery failure, unverified provider success, ambiguous revocation, already-invalid tokens, no experiment, session/CSRF guards, reconnect during recovery, and stale OAuth-flow invalidation.
- A real-commit, independent-connection test kills a request during revocation. The committed revoking stage and credentials survive; a concurrent reconnect is refused; retry completes without another Gmail read or mutation. Existing live-message lock tests now also reject a competing disconnect.
- 18 browser tests passed under Node 26.8.1. Disconnect review, restoring and revoking states render on mobile/desktop; pending state hides ordinary mailbox controls and sends an explicit CSRF-protected POST. Existing preview and controlled-flow tests still pass. Inspected mobile recovery screenshot.
- TypeScript, formatting, whitespace and application warnings-as-errors checks passed. The Linux image build and release succeeded with unchanged locked dependencies.
- Took an encrypted pre-migration database export off the VM, authenticated/decrypted it through `pg_restore --list`, and retained it privately. This is an export check, not a new full restoration rehearsal.
- Applied the additive account migration and recreated web/worker using both existing Compose files. Readiness returned HTTP 200. The prior image remains available, subject to the pending-disconnect rollback restriction in the contract.
- Used the owner's actual Chrome incognito window to load the deployed page and expand **Disconnect Gmail safely**. The review text and final submit button were present. Did not click the revocation button.
- At 02:01:24 UTC, used the hosted authenticated **Recover / verify** form after deployment; it returned “Controlled message released; verified against Gmail just now.” The live grant remains connected and the experiment remains released.

## Remaining proof

Google revocation itself was simulated through the real provider boundary in automated tests. A live revoke/reconnect rehearsal has not been performed in this slice. It must be chosen explicitly because it removes all project permissions and requires reconnection. General interception removal, multi-message recovery, external alerts, device behavior and whole-VM restore remain separate Phase 0 gates.

See the [safe disconnect contract](../../phase-0-safe-disconnect.md) for ordering, retries, expired-session handling and rollback constraints.

# Live safe disconnect from a held fixture

Date: 2026-09-05 UTC. Release: `c3f5621`, tag `phase0-repeat-20260905`.

## Implementation and deployment

Added an explicit repeat-test action for the existing frozen fixture. It verifies released labels before committing a new hold intent, advances a durable revision to reject stale forms, and preserves the saved message/label IDs. Ordinary Hold still refuses released records. Repeat shares the account lock and disconnect fence; uncertain writes retain recoverable intent.

129 backend tests and 18 browser tests passed, including stale forms after a later release, duplicate submissions, external edits, ambiguous writes, authenticated controller revision forwarding, and CSRF/session guards. TypeScript, formatting, whitespace and warnings-as-errors compilation passed. A separate review found no actionable issues. The first browser run timed out starting its local server; after applying the development migration and verifying server startup, the full suite passed.

Took an encrypted pre-migration export off the VM and verified decryption plus its pg_restore catalog. Applied the additive repeat revision migration, deployed web and worker with both Compose files, and verified readiness. No dependencies changed.

## Live sequence

Used the owner's Chrome incognito window and configured test account throughout; actions ran through the hosted app forms.

1. **Hold the same test message again** returned held, verified against Gmail at 02:21:41 UTC. Server state independently confirmed held and repeat revision 1.
2. **Restore test message and revoke access** returned Google's accepted revocation message. The saved controlled record changed to released, verified at 02:21:58 UTC.
3. At 02:22:08 UTC, a sanitized server check confirmed credentials removed, session removed, no pending disconnect, and the retained released record at revision 1.
4. Reconnected the same account through Google consent. **Recover / verify** read Gmail back successfully at 02:23:08 UTC. At 02:23:17 UTC, the server confirmed connected status, present credentials/session, no pending disconnect, and the retained released record.

5. Loaded recent messages through the app; the controlled fixture was visible in Inbox as **Unread**.

## Boundary

This proves live restoration of one held fixture before accepted revocation, local cleanup, and reconnection. It does not prove general interception removal, multi-message recovery, device notification behavior, instant global revocation propagation, or live failure/crash recovery during the disconnect request. Full Phase 0 acceptance remains open. No credentials, OAuth URLs, or unrelated message content are retained here.

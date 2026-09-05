# Direct Gmail recovery and independent local restore

Date: 2026-09-05 UTC. Application revision: `c3f5621`. Scope: one controlled fixture, no automatic interception.

## Recovery with app processes stopped — pass for the fixture

- Used the app's repeat form in the owner's Chrome incognito window. The saved fixture was held and verified at 02:27:57 UTC, repeat revision 2.
- Stopped both hosted web and worker containers. Both exited cleanly, and a direct request to the local health endpoint failed to connect. PostgreSQL and the VM remained running; this was an application outage, not total VM loss.
- Opened Gmail directly under the configured test account. The controlled label contained exactly one unread fixture. Selected only its checkbox, then **Move to → Inbox**, without opening the message.
- Gmail reported “Conversation moved to Inbox.” The row remained unread and gained an Inbox label. The controlled label remained attached, confirming why held-label count alone is insufficient recovery evidence.
- Restarted both app processes with the Gmail Compose overlay; health recovered. The app's **Recover / verify** reported a label mismatch rather than false success. **Release to Inbox** then reconciled the saved record and verified the released labels at 02:29:53 UTC. No filters were created, edited or deleted.

This exercise used a single-message conversation. Multi-message threads, all-page selection, new arrivals after recovery, and recovery with OAuth revoked remain unproven. Automated tests cover refusing to rehold external edits; the live mismatch response and explicit release were observed here.

## Encrypted restore independent of the VM — pass for inert startup

Before reconciling the app's stale held record, exported the hosted PostgreSQL database over SSH into an encrypted archive retained on the owner's Mac. The snapshot therefore intentionally said held while Gmail had already restored Inbox membership.

Used the existing backup-restore tool to fully authenticate/decrypt the archive before SQL, then restore it transactionally into a new isolated local PostgreSQL database. Started the current application against that database with `RESTORE_MODE=true`, worker role, no Google configuration, and no web server.

Assertions passed:

- Actual application configuration was in restore mode.
- No Oban process started, even with worker role selected.
- Gmail was unconfigured and an attempted controlled operation without authorization was refused.
- The restored controlled record retained held state and repeat revision 2.
- Oban job states, attempt counts and counts remained unchanged through startup and the refused operation.

Database creation, full restore and application assertions took approximately 1.6 seconds, excluding export and engineering preparation. This is a small-fixture measurement, not a promised recovery time. Removed the disposable local database and temporary plaintext; retained only the encrypted archive and existing private identity outside the repository. The original VM was not needed for restoration or startup.

## Remaining operational proof

No R2 copy, scheduled export, separately held key-copy proof, independent alert receipt, or total-VM-outage monitoring was established. Restored Gmail metadata remains stale and must not be activated without reconciliation. This does not pass the full backup or Phase 0 exit gates.

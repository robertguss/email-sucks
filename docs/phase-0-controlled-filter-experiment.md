# Controlled app hold and release

Updated 2026-09-05. This supersedes the manual Gmail filter rehearsal. The rehearsal filter was removed and read back as absent; it was never interception or app-recovery proof. No further manual filter exercise is required.

## Current implementation

The authenticated app can perform one experiment against the existing `phase0-primary-001` message. It searches the connected account's Inbox for the controlled sender, then requires exactly one candidate, exact subject, and single matching From and To headers. Replies, duplicate candidates, Trash, Spam and Drafts fail closed. Browser parameters cannot select a message or label.

Hold adds `Postman/Controlled-primary-001` and removes `INBOX` on the frozen message ID. Release adds `INBOX` and removes the frozen label ID. Neither operation changes `UNREAD`, unrelated labels, threads, filters, or message bodies. The empty label remains after release. The completed experiment cannot be restarted against another message.

OAuth now requests `gmail.modify`. Google grants broader mailbox access than this experiment uses; the UI says so. The old read-only grant needs reconnection through the app. Message operations follow Google's [message modify API](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/modify); label setup follows [label create](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.labels/create).

## Durable recovery contract

A PostgreSQL record stores the frozen message/label IDs, pending intent, and last verified time. A connection-scoped advisory lock serializes operations across web processes. Intent commits before the message mutation, independently of the remote call. Provider success is followed by a separate label read before the app reports held/released.

On interruption, timeout, or ambiguous failure, use **Recover / verify**. It reads the same message first and only repeats a pending mutation if needed. A release can safely supersede a pending hold after obtaining the lock. A completed state is verified without silently reversing later external edits. Trash, Spam, Drafts, missing messages or missing labels require investigation; they are never silently replaced with a different fixture. Failed operations retain the record.

Label creation is resolved by exact name on the next attempt if its response is lost. Before a message ID is saved, retry **Hold test message**; no message was modified yet. After intent is saved, recover or release using the app. Do not delete the durable record or rename/delete the held label while recovery is pending.

Recovery is explicitly requested in this slice, not background or continuous sync. Keep the database and Gmail vault/session keys together in the existing encrypted recovery procedure. Restore mode omits Gmail configuration and blocks these actions. Returning to an older app image preserves this additive table, but the new image is required to execute its recovery actions.

## Verification and live results

Automated checks use the real app, database, and provider transport boundary. They cover exact matching, hold/release read-back, read/unread preservation, wrong sessions, CSRF, ambiguous writes, label-creation ambiguity, missing/trashed messages, competing release, and killed-request recovery with real commits on separate connections. Browser checks render all five states, check mobile overflow and submit the appropriate CSRF-protected forms. These are simulated-provider checks, not live Gmail evidence.

The deployed app completed Hold, restart, Recover / verify, Release, and Recover / verify against live Gmail. The fixture is back in Inbox, still unread, with unrelated labels preserved. The saved grant already had modification access. See [dated evidence and browser limitations](evidence/phase-0/2026-09-05-controlled-app-flow.md). No mail sending or native Gmail filter setup was part of this test.

Phase 0 remains incomplete: native notifications, broad interception, scheduling against Gmail, independent backup alerts and whole-VM recovery are outside this slice.

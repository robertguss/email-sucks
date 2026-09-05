# Safe disconnect for the controlled prototype

The app now offers a reviewed **Disconnect Gmail safely** action. It is separate from browser sign-out. Its scope is the one durable controlled-message experiment; this prototype has no automatic interception filters or general held-mail inventory.

## Order and recovery

1. Save `restoring` on the account and pause ordinary mailbox operations.
2. If an experiment exists, release its frozen message ID to Inbox and read Gmail back. Missing, trashed, spam, or unverified messages stop disconnect and retain credentials. With no experiment, no mailbox search or mutation is needed.
3. Save `revoking` before calling Google's revoke endpoint with the saved refresh token in a form body. A retry at this stage does not refresh access or read/change mail again.
4. On HTTP 200, clear local credentials, session access and pending OAuth flows atomically. Keep the pinned account identity and controlled recovery record.

A specific `invalid_token` response means the saved token is already unusable, not that Google has confirmed removal of every project permission. The app removes local credentials and tells the user to review Google Account permissions. Other errors retain the revoking stage and credentials for retry. Provider response bodies and token values are never UI errors.

OAuth callbacks, reconnects, refreshes, message operations and disconnect share the same PostgreSQL connection-scoped lock. A live competing operation is refused; the caller can retry. No timed lease lets a slow operation overlap a later disconnect. A killed checkout disconnects and releases the lock while independently committed intent survives.

Reconnecting during failed restoration preserves disconnect intent. If the browser session expires while revocation is pending, a newly verified OAuth identity can finish the earlier disconnect; its new credentials are discarded because revocation may invalidate them too. The user can then connect afresh. OAuth flows opened before a completed disconnect cannot reconnect the account afterward.

## Google consequence

Google documents that [revocation removes all scopes and tokens granted to the OAuth project](https://developers.google.com/identity/protocols/oauth2/web-server#tokenrevoke), including its other clients, and may take time to propagate. The review panel states this before its final submit button. The app reports Google's acceptance, not instant global propagation.

## Verification boundary

Automated tests cover ordered restore/read-back/revoke, failed recovery, unverified success, uncertain revoke, invalid tokens, OAuth races, expired sessions, and a killed request with actual independent database commits. Authenticated controller tests cover the explicit POST and CSRF/session boundaries. Browser tests cover review, restoring and revoking states on mobile and desktop.

Do not mark the full Phase 0 safe-disconnect proof complete from these tests. The owner-authorized [live revoke-and-reconnect rehearsal](evidence/phase-0/2026-09-05-safe-disconnect.md) passed with the fixture already released: Google accepted revocation, local credentials/session were cleared, and reconnection plus Inbox/unread verification succeeded. Live restoration from held during disconnect and live mid-request crash recovery remain unproven. Future automatic interception requires disabling and verifying app-owned filters and recovering all held pages before using this flow.

## Repeating the controlled rehearsal

After release, **Repeat the recovery test** offers an explicit hold of the same frozen message and label. The app first verifies the released labels, then commits a new hold intent and advances a repeat revision before touching Gmail. Old or duplicate forms cannot start another hold, including after a later release. An ambiguous result uses the existing Recover / verify action. Ordinary Hold remains one-shot; no recovery record is deleted or reset. Repeat uses the same account lock and disconnect fence as other mailbox actions.

## Deployment and rollback

The migration adds a nullable account field. Take an encrypted backup before migration and preserve both exe.dev Compose files. Older images do not enforce the disconnect fence: do not roll back while an account has `disconnect_phase` set. Finish recovery using the current release, or keep the app in restore mode until the pending operation can be resolved. Never clear the phase manually merely to make an old image start.

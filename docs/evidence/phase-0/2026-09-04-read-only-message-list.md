# Read-only Inbox listing

Date: 2026-09-04

The owner authorized a small real-message retrieval slice after reporting successful revocation detection, reconnection, and a new profile check. The app now loads up to five recent Inbox messages on explicit request, showing sender, subject, received time and unread status.

## Implementation

- Authenticated `GET /gmail/messages` reuses the existing session validation, encrypted credentials and refresh lease. Anonymous/expired sessions receive an error; revoked access marks the connection for reconnection.
- Uses only Google's `users.messages.list` and `users.messages.get`, with `labelIds=INBOX`, a five-message cap, `format=metadata`, From/Subject header selection, and a response field mask. No message bodies, snippets or attachments are requested or returned to the UI. No Gmail mutation methods exist in this slice.
- Returns an explicit field allowlist. Headers render as React text, never HTML. Requests and responses are not logged with message data. Response headers prevent caching and referrer disclosure.
- Email metadata exists only in the request and the current React component state. It is not written to the database, Inertia page props, localStorage, sessionStorage, or serialized browser history. Hide messages clears the visible list; navigation unmounts it. This does not claim to erase browser-managed process memory or OS snapshots.
- Missing messages (404 between list/get) are skipped. Other fetch failures discard incomplete results and show a retry/reconnect state. This is a five-item diagnostic preview, not synchronization, pagination, or a full inbox. Headers are displayed as returned by Gmail, with long values capped at 1,000 characters.

## Verification

- Backend tests: 47 passed, covering metadata-only requests, safe field selection, missing/empty messages, provider errors, anonymous access, no-store headers, revocation handling and the existing OAuth/refresh/snapshot suite.
- Three Chromium tests pass: existing navigation plus synthetic signed-in listing tests for explicit loading, disabled/loading feedback, literal HTML-like subject rendering, non-persistence, hiding, empty results, retryable errors and reconnect guidance. TypeScript checking, application compilation with warnings as errors, and formatting checks pass.
- Live check in the owner's existing authenticated browser: clicked **Load recent messages**, observed **Loaded 5 messages**, and confirmed the server returned HTTP 200. No titles, senders, message IDs or email contents are recorded in this evidence. The app made read-only metadata requests; it did not mark messages as read or modify labels.
- The in-app browser log contained one MutationObserver error around asset reload. The list still completed successfully; the isolated Chromium listing test checks for page errors separately. No claim is made here that the embedded browser log was empty.

This verifies actual bounded message retrieval and display. Gmail interception/recovery, ongoing synchronization, hosted operation, outage handling and notification behavior remain open Phase 0 gates.

Sources checked before implementation: [messages.list](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/list), [messages.get](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/get). No dependencies or version changes were needed.

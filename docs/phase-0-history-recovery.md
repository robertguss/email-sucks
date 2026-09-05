# Bounded read-only history recovery proof

## Goal and boundary

Implement a durable diagnostic over the four already saved single/batch fixture
IDs. This is the next independent Phase 0 proof after ordinary arrival cleanup.
Freeze membership once in a separate journal; never change Controlled or Batch,
expand from history results, modify Gmail labels, or send mail. Unknown history
IDs are discarded before any message metadata request. This does not establish
full-mailbox discovery or continuous synchronization.

Use the existing authenticated web access/token-refresh and account lock. Gmail
credentials remain web-only. No timer, new worker, or credential-bearing job.

## Backend contract

`HistoryProbe.summary/0` returns only state, member/available/unavailable counts,
revision, last-checked time, last sync mode and sanitized error, never IDs/cursors.
`HistoryProbe.run(config, token, action)` accepts only `sync` and `rescan`.
First use requires the existing one-message and exactly three-message saved
records with four distinct valid IDs, and persists membership before provider I/O.
Later runs never read new membership from those records.

A new additive table stores one primary row: fixed IDs, committed cursor,
observations, revision, completion timestamp, mode and sanitized error. IDs,
cursors and observations are private/redacted. Success atomically checkpoints the
complete observations and terminal cursor; error retains the last successful
checkpoint and records a sanitized error. An interrupted first scan is retryable.

1. Full/rescan: obtain profile cursor H0 before exact-ID minimal message reads.
2. Paginate history from H0, deduplicate known affected IDs, reread those IDs.
3. Incremental: start at the saved cursor and apply the same pagination/read rule.
4. History HTTP404 triggers one bounded full rescan; message HTTP404 records that
   member as unavailable. Do not confuse transient errors with deletion.
5. Never compare cursor strings lexically or assume contiguous history IDs.
   Reject malformed responses and repeated page tokens; cap work visibly.

Use GET-only provider requests, retry/redirect disabled, existing injectable Req
transport and sanitized Google error conventions. Never fetch message bodies.
A profile cursor is available from users.getProfile; use the terminal history
response cursor as the checkpoint. Capture-before-scan plus catch-up is this
probe's concurrency design and requires tests.

## Integration

Add authenticated/CSRF-protected POST controls with fixed server actions. Reuse
Gmail.with_access for refresh, revocation and disconnect guards. Show truthful
last-confirmed counts and explicit read-only/fixed-membership limits. Operational
health must expose a persisted probe failure without leaking private data.

## Verification

Test first scan, incremental scan, expired cursor fallback, known changes during
scan/pagination, ignored unknown arrivals, duplicate/gapped history references,
malformed/looping pages, message404, partial failure/crash before checkpoint,
repeat/concurrent runs, token/disconnect guards, no provider writes, unchanged
source journal entries/revisions, and public summary redaction. Include a real
commit/independent-connection durability case. Run backend/browser/type checks,
simplification and independent review before commit/deploy. Preserve ownership
journals through the additive migration and authenticate a fresh encrypted backup.

Live proof uses the four saved IDs only: initial and incremental readback, then a
deliberately old outbound cursor producing a real Google HTTP404, followed by bounded rescan,
zero Gmail mutation transport and unchanged controlled journals. Do not label this
forced old cursor as natural expiry of the saved checkpoint.

## Primary sources

- [Synchronization guide](https://developers.google.com/workspace/gmail/api/guides/sync)
- [history.list](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.history/list)
- [getProfile](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users/getProfile)
- [messages.get](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/get)

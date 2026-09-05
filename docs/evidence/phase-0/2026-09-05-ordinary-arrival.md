# Ordinary arrival and repeat cleanup

Date: 2026-09-05. Revision: `75f7f0e`. Result: Pass for this fixed provider fixture.

The owner's exact synthetic message was found by both its marker query and the
owned label query. Message metadata confirmed unread, absent Inbox, the expected
test label, and no Trash/Spam/Draft labels. Arrival indexing latency was not measured;
the first inspection observed zero and the subsequent metadata check found one.

A temporary provider adapter allowed reads, deletion of exactly the saved owned
filter, and only the exact fixture's Inbox-add/test-label-remove projection. An
out-of-scope synthetic write self-test was blocked locally before transport.
Tracked disable removed and verified the filter before one message write restored
Inbox. Readback confirmed unread and all unrelated labels preserved. Repeat disable
and inspection completed with zero additional filter deletes or message writes.

Final state: ordinary profile disabled, one observed, one restored, zero pending,
zero excluded, no error or baseline drift. The original three filters matched the
private inventory. Primary Trash and controlled batch records remained unchanged;
the batch is released revision four. The temporary adapter was purged/deleted.
Hosted operational check-only returned healthy.

Private before/after metadata, exact IDs, criteria and recovery notes remain on the
owner Mac under `~/.config/email-sucks/hosted-cougar-cedar/ordinary-arrival/`.
No agent sent mail. This proof does not establish device notifications, mixed-thread,
alias/Bcc behavior, continuous intake, or full-mailbox recovery.

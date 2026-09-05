# Live Trash-overlap and guarded cleanup proof

Date: 2026-09-05. Revision: `6679507`, existing exe.dev VM and controlled account.
Status: Pass within this bounded fixture; general interception remains unproven.

After verified activation, the owner sent exactly one agreed synthetic message.
The first post-send query saw none; a subsequent marker query and independent
held-label lookup each found the same one message. Arrival/indexing latency was
not measured, so this does not establish a delivery-time guarantee.

The message's labels were UNREAD, TRASH, CATEGORY_PERSONAL and the dedicated test
label. INBOX was absent. Both overlapping actions applied for this fixture;
there is no inferred universal filter-ordering guarantee. Metadata-only reads
preserved read status; no body was fetched.

A temporary provider adapter permitted GET and DELETE of only the two saved owned
filter IDs. Every message write was rejected before transport. A deliberately
blocked synthetic write verified the guard itself, then separate counters measured
only the real cleanup operation. Cleanup deleted the hold filter before the Trash
filter, verified absence, and classified the sole held message as excluded.

Final state: disabled, zero tracked/pending filters, no error or baseline warning,
one observed/excluded message and zero restored. Ordinary cleanup was repeated
through the disconnect-restoration helper without revoking access. Across both
runs there were exactly two owned-filter deletes and **zero attempted recovery
message writes**. Before/after message metadata and labels were identical. Full
filter comparison matched all three original filters, unchanged. The existing
batch record was unchanged by the filter experiment.

The exact snapshots and updated recovery card are private on the owner Mac,
outside git/VM. The temporary guard module was purged after the operation. The
fixture remains unread in Trash with its test label for evidence; ordinary
recovery did not resurrect it. No agent message send or permanent message deletion
occurred. Manual movement of this Trash fixture is not needed to pass exclusion
and was not performed.

This passes the prepared sender-specific Trash-overlap case, owned-filter cleanup
and exclusion under a write guard. It does not pass hold-only ordinary arrivals,
Bcc, aliases, forwarding, threads, native notifications, revoked-access direct
filter removal, pagination or the full Phase 0 exit gate.

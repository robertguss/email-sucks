# New arrival during interrupted batch release

Date: 2026-09-05 UTC. Application release `ed8756f`; batch repeat revision two. No permanent application changes.

## Observations

- Restored SSH and the correct authenticated incognito Gmail session. Repeat held the same three saved messages; provider reads at 11:51:10 confirmed all three held and unread.
- A narrowly scoped temporary adapter killed the release request after Google accepted the second saved member's modification. At 11:51:35 the database retained one released and two pending members. Provider reads showed two in Inbox and the third held, all unread. The adapter was removed and web restarted; readiness and normal adapter checks passed.
- At 11:52:17, a read-only search for the distinct subject `phase0-arrival-001` from the configured sender returned zero matches. Only afterward was the owner asked to send that separate synthetic message.
- The first search after the owner's sent confirmation returned no match. A subsequent check at 11:55:15 found exactly one matching message, verified its subject and sender/recipient headers, and confirmed it was outside the three saved IDs. It was unread in Inbox without the batch label. No body was fetched.
- Installed a temporary guard that refused any Gmail message-modify request except the remaining third original member. Used the authenticated Recover / verify batch form. At 11:56:12, recovery completed with exactly one modify attempt and zero forbidden attempts. The saved batch remained three members, now all released with zero pending/errors.
- Independent Gmail read-back confirmed all three original members in Inbox, unread and without the batch label. The newcomer's identity plus full sorted label-set fingerprint was identical before and after recovery; it remained unread in Inbox and outside the batch.

This establishes an arrival between interrupted delivery and recovery without expanding saved membership or changing the newcomer. The arrival timing is established by an empty pre-send search, owner send confirmation and subsequent observation during the pending release; it is not a claim about exact provider internal delivery timestamps.

## Cleanup and limits

Restored the normal provider configuration, removed VM/container guard files and restarted web to unload the temporary module. Final readiness and cleanup checks passed. The batch is released at repeat revision two and the account remains connected.

No new automated tests were required for this evidence-only rehearsal. The last application verification remains 138 backend and 23 browser tests. This does not prove automatic interception, a continuously executing worker race, all arrival types, multi-message hold crashes, or device notifications. Full Phase 0 remains open.

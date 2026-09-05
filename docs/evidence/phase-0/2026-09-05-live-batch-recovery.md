# Live three-message release crash recovery

Date: 2026-09-05 UTC. Hosted application: `ce8e001`. No permanent application changes were needed.

## Method and observations

The owner sent the three requested synthetic messages. A read-only provider prerequisite check verified exactly three matching messages, all unread. Used the authenticated Chrome incognito app forms throughout.

- At 03:12:45 UTC, Hold had saved exactly three members and confirmed all three held. Independent Gmail reads showed all absent from Inbox, carrying the batch label, and unread.
- Loaded a temporary diagnostic Req adapter through administrative RPC. It delegated to Req.Finch, matched only the three saved message modify endpoints, and killed the release request after Google returned HTTP 200 for the second sorted member, before returning that response to application code. It recorded counters only; no tokens, headers or message contents were captured.
- At 03:13:29 UTC, two modify attempts had occurred and the accepted-response kill counter was one. The database retained the first member as released and the other two as release_pending. Independent Gmail reads showed the first two in Inbox without the batch label, while the third remained held. All were unread.
- Restarted the web container, preserving the database. Installed a temporary guard that refused and counted any modify call to the first two saved members, while allowing the third member to complete. The browser displayed the durable partial state: one released and two pending.
- At 03:14:05 UTC, Recover completed through the authenticated form. The guard recorded exactly one modify attempt, for the third member, and zero duplicate attempts. All three saved members were released with no pending entries or errors. Independent Gmail reads at 03:14:06 confirmed all three in Inbox, unread, and without the batch label.
- Repeated Recover through the browser. The modify counter remained one, confirming no additional writes for the completed batch. The browser reported all three released and verified against Gmail.

The first committed result survived request death and restart. The accepted but unrecorded second result was reconciled from provider state. The unattempted third result completed. Total release writes were exactly three, one per member.

## Cleanup and scope

Restored the normal provider configuration, removed the diagnostic script from both VM and container, and restarted the web container to unload the temporary module and counters. Final readiness and normal-adapter checks passed; the saved batch remained fully released.

This proves live three-message hold and interrupted release recovery across a web restart, plus repeat verification without extra writes. The fault simulates a provider response lost to application code after transport acceptance, not a packet-level network failure. It does not prove concurrent arrivals, multi-message hold crashes, safe disconnect from a held batch, token-revocation interruption, total VM loss, automatic interception or scheduled background recovery. Those wider Phase 0 gates remain open.

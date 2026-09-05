# Live controlled hold/release crash recovery

Date: 2026-09-05 UTC. Hosted application revision: `c3f5621`. Single frozen fixture; repeat revision 3. No persistent application code or schema changes.

## Fault method

Loaded a temporary diagnostic HTTP adapter into the running web process through administrative RPC. It delegated requests to the existing Req.Finch transport and matched only POSTs to the exact frozen fixture's Google modify endpoint. After the real provider returned HTTP 200, it killed the calling request process before returning that response to Gmail application code. A one-shot counter recorded acceptance and the number of modify attempts without storing request headers, tokens or response bodies.

Used the real authenticated app forms in the owner's Chrome incognito window. Following each killed request, independently read the same message through Gmail, restarted the web container, and installed a temporary guard that refused and counted any further modify call for the frozen fixture. Recovery then ran through the app's **Recover / verify** form. A successful recovery with zero guarded attempts establishes that no repeated write was needed.

The transport had received Google's response; this simulated loss of that response to application code, not a packet-level network failure. The database and worker remained running. The browser showed a service-unavailable page during the induced interruption/restart, then the pending state after returning to the homepage.

## Observed results

| Operation | After accepted response and request kill | Independent Gmail state | After web restart and guarded recovery |
|---|---|---|---|
| Repeat hold | At 02:52:48 UTC: hold_pending, no verified timestamp, one modify attempt, accepted-then-killed true | At 02:53:00 UTC: absent from Inbox, controlled label present, unread | Held, verified 02:53:31 UTC; zero additional modify attempts |
| Release | At 02:54:03 UTC: release_pending, no verified timestamp, one modify attempt, accepted-then-killed true | Inbox present, controlled label absent, unread | Released, verified 02:54:31 UTC; zero additional modify attempts |

The durable intent and repeat revision survived request death and restart. The same frozen fixture remained selected throughout. The authenticated browser session survived restart and recovery returned explicit verified success.

Fourteen focused controlled-operation and real-commit durability tests also passed. Their intentional process kills emit expected database disconnect logs. This live exercise required no product fix.

## Cleanup and limits

Restored the original provider configuration, removed both VM/container copies of the diagnostic script, and restarted the web container to unload the temporary module and counters. Final state: connected account, released fixture, no pending disconnect; normal provider adapter restored.

Pass for single-message hold/release recovery after accepted provider write and killed request, including persistence across a web restart. Not proof of crash during token revocation, full VM/power loss, multi-message partial release, concurrent arrivals, or autonomous background recovery. Full Phase 0 remains open.

# Interrupted three-message hold recovery

Date: 2026-09-05 UTC. Application release `ed8756f`; batch repeat revision three. No permanent application changes.

## Observations

- A bounded SSH check succeeded. The isolated checkout and fetched `origin/main` matched `af18d43`. At 12:39:59, independent Gmail reads confirmed the three saved members released and unread in Inbox at revision two, with zero pending/errors. The account had no pending disconnect and no temporary provider adapter was installed.
- The existing `phase0-arrival-001` fixture was verified outside saved membership, unread in Inbox and without the batch label. Its identity plus complete sorted label-set fingerprint was compared before and after; no body was fetched.
- Installed a temporary adapter that delegated to the real provider and killed the authenticated repeat-hold request immediately after Google's HTTP 200 for the second saved member. Used the revision-guarded **Hold this same batch again** form; no durable rows were reset or deleted.
- At 12:40:30, the adapter reported two modification attempts and one accepted-then-killed result. The database retained revision three, one confirmed held member and two pending members. Gmail read-back showed the first two held and the third still in Inbox, all unread.
- Restored normal provider configuration and restarted web using both live Compose files. Readiness passed. At 12:40:55, the temporary module was absent and independent reads confirmed the same durable/provider split survived restart.
- Installed a recovery guard that refused every Gmail message-modify request except the third saved member. Submitted the authenticated **Recover / verify batch** form. At 12:41:16, it reported exactly one modification attempt and zero forbidden attempts. All three members were confirmed held and unread, with zero pending/errors. This proves recovery recognized Google's already-accepted second hold without repeating that write.
- Restored the normal adapter and submitted **Release the batch to Inbox**. At 12:41:51, independent provider reads confirmed all three released, unread and without the batch label. The newcomer remained outside membership with an identical label fingerprint throughout the hold recovery and final release. The account had no pending disconnect.

## Cleanup and limits

Removed the three uploaded diagnostic files from both VM and container. Container files copied by Docker required root for removal; the initial unprivileged removal failed without changing app state, then the explicit root removal succeeded. Restarted web to unload the temporary module. At 12:42:20, readiness, absent adapter/module/files and released revision-three state passed. The authenticated browser also showed three released members, zero pending/errors and a connected account.

No new automated tests were needed for this evidence-only rehearsal; the last application verification remains 138 backend and 23 browser tests. This establishes interrupted fixed-batch hold recovery across a web restart without duplicate writes. Automatic interception, continuously executing worker races, broader arrival/filter cases, scheduled Gmail delivery and actual-device notification proof remain open. Full Phase 0 has not passed.

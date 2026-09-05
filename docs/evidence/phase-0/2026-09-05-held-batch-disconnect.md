# Live safe disconnect from a held three-message batch

Date: 2026-09-05 UTC. Release `ed8756f`.

## Guarded repeat implementation

Added an explicit repeat form for the existing frozen batch. It validates the submitted repeat revision and verifies every member is currently released before committing hold intent for the same IDs and incrementing the revision. Stale forms cannot re-hold mail after a later release. No batch record is reset or deleted; no new message search runs during repeat. Recovery and disconnect retain the existing shared lock and account fence.

Two new backend tests failed before implementation and passed afterward. They cover stale forms across subsequent releases, fixed membership, all-member validation before any write, ambiguous hold recovery and disconnect from a repeated held batch. All 138 backend tests and 23 browser tests passed, plus TypeScript, formatting, whitespace checks and compilation with warnings as errors. Browser form checks verify CSRF and revision submission. The first browser run timed out because the local development migration was pending; after applying it, the full suite passed. Independent review found no actionable issues.

Authenticated an encrypted pre-migration export on the owner Mac and verified its pg_restore archive listing. Built the Linux release, stopped the worker, applied the additive repeat-revision migration at 03:26:45 UTC, and recreated web/worker with both Compose files. The existing batch initialized at revision zero without changing membership or release state. Deployment readiness passed.

## Live proof

Used the real authenticated Chrome incognito forms. At 03:27:49 UTC, Repeat had held all three saved messages at revision one. Independent Gmail reads confirmed all three absent from Inbox, carrying the batch label and still unread.

Installed a temporary observing Req adapter that delegated unchanged requests to Req.Finch. It counted successful requests and recorded only the redacted batch summary immediately before the revoke request. No credentials, message contents or provider IDs were logged.

At 03:28:35 UTC, safe disconnect had made exactly three accepted message modifications and seven successful reads (one single-fixture check plus before/after reads for three batch members). Before the revoke call, the saved batch already showed all three released, zero pending and zero errors. Google accepted one revocation. The account then had no credentials, no session digest and no pending disconnect phase.

## Cleanup and limits

Restored normal provider configuration, removed the observing script from VM/container and restarted the web container to unload it. Reconnected the same allowed account through Google consent. At 03:30:06 UTC, independent Gmail reads confirmed all three saved messages in Inbox, unread and without the controlled batch label. The batch remained released at revision one, with no pending entries or errors. Readiness passed; RPC confirmed no temporary adapter, loaded observer module or observer file. The authenticated browser showed Connected and the fully released batch.

This is bounded proof for restoration of the three saved held messages before revocation. It does not establish general held-mail inventory, paging, live concurrent arrivals, all interception paths, device notifications or total VM recovery. Phase 0 remains open.

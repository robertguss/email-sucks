# Fixed three-message Gmail batch

Date: 2026-09-05 UTC. Application release: `ce8e001`.

## Implemented behavior

Exactly three explicitly named synthetic Inbox messages are validated, then their membership is saved before any message write. Each confirmed outcome commits independently. Recovery reads current provider state before deciding whether an unresolved write is needed; completed members detect external changes. Safe disconnect restores and verifies the single fixture and every saved batch member before revoking credentials. See the [contract](../../phase-0-controlled-batch.md).

## Verification

- All 136 backend tests and 23 Playwright browser tests passed. TypeScript, compilation with warnings as errors, formatting and whitespace checks passed.
- Provider fixtures cover partial hold/release response loss, fixed membership excluding a later arrival, label/unread preservation, invalid-fixture rejection, external recovery and failed-member disconnect followed by retry.
- An independent-connection durability test kills the request after the simulated provider applies the second release. The first result survives; competing work is refused; recovery completes with exactly one write per member.
- Browser checks cover batch states, authenticated CSRF-only action forms and disconnect disclosure. The 390-pixel layout was visually inspected. Independent review found no actionable issues.
- An encrypted pre-migration database backup was authenticated and its archive listing read successfully. This was not another full restore rehearsal.
- The Linux release built successfully. The additive batch migration ran at 03:04 UTC, and web/worker were recreated with the Gmail Compose overlay. Deployed revision is `ce8e001`; `/health/ready` returns `{"status":"ok"}`, web/database are healthy, and the worker is running.
- Post-deploy read-only summaries show an empty `not_started` batch and the single fixture still released at repeat revision 3. The provider fixture prerequisite returns `fixture_mismatch`; the three-fixture set is not yet ready. No batch message mutations were attempted.
- Post-deploy native incognito interaction remains pending; the owner was using another browser window. Local browser verification does not substitute for the authenticated live rehearsal.

## Next live proof and limits

The owner must prepare three separate messages with subjects `phase0-batch-001`, `phase0-batch-002`, and `phase0-batch-003` from the configured sender to the allowed test account, leaving them in Inbox and unread. Then rehearse hold, partial/crash recovery and release with provider read-back. This implementation is a one-shot controlled batch, not automatic arrival interception or scheduled delivery. Multi-message live effects, provider races, device notifications and the full Phase 0 gate remain unproven.

# Controlled app hold, restart and release

Date: 2026-09-05 UTC. Deployed application revision: `3e17d90` (`phase0-controlled-20260905`). Host: the existing private exe.dev VM. This proves the narrow app flow; Phase 0 is still incomplete.

## Shipped and automated checks

- 111 backend tests passed, including real database commits on independent connections: a held request is killed after the simulated provider applies its change, competing release is blocked, pending intent survives, and recovery verifies without another mutation.
- 12 Playwright browser tests passed under Node 26.8.1. All five controlled states render, mobile layouts fit, intended actions submit POST with CSRF, and existing Inbox preview/navigation checks pass. Browser tests use synthetic authenticated props/provider responses; authenticated authorization and state exposure are covered by controller tests.
- TypeScript checking, formatting, whitespace checks and application compilation with warnings-as-errors passed. The Linux production image built successfully with the locked dependencies.
- Exported a fresh encrypted database backup off the VM before the additive migration; decrypted/authenticated it through `pg_restore --list`. This backup check is not a new full restore rehearsal.
- Ran the migration through the existing application database role and recreated web/worker with both Compose files. OAuth/key mounts remain confined to web. Readiness returned HTTP 200 and the private HTTPS proxy continued to require login. Previous image retained.
- Ran the actual deployed image in restore mode: Gmail configuration was absent and a controlled action returned unauthorized.

## Live provider evidence

The deployed app's exact fixture lookup matched the existing controlled message, unread in Inbox. The saved Google token already contained `gmail.modify`; additional consent was not needed for these operations. No credentials, provider IDs, mailbox inventory or message body are included here.

At 01:46:53 UTC, invoked the deployed app's `Controlled.run` hold operation. Separate provider read-back confirmed the same message ID, Inbox removed, the controlled label present, unread preserved, and every unrelated label preserved.

Restarted the web container. At 01:47:31 UTC, the database still held the saved `held` record and the app's recovery operation verified it against Gmail. At 01:47:32 UTC, the app released the message and its recovery/verify operation confirmed `released`. A separate metadata read confirmed Inbox restored, held label removed, unread still true and unrelated labels preserved.

Final state: `released`, provider-verified. The empty controlled label and durable experiment record remain intentionally. No filter was created or changed, no message was sent, no thread-wide modification occurred, and no native Gmail UI test was performed.

## Evidence limits

Hold/release operations called the deployed app's own functions over its release RPC boundary, with credentials loaded privately in the VM. After correcting an initial regular-window selection to the owner's authenticated incognito window, clicked the actual app's **Recover / verify** form at 01:48:58 UTC. The hosted page returned “Controlled message released; verified against Gmail just now” and updated its last-verified time. Loading recent messages in the app showed the controlled fixture in Inbox as unread. This supplies live authenticated browser/CSRF recovery evidence; the hold and release form states themselves have local browser/controller coverage. No new Google callback was needed during this verification.

The live restart occurred after a verified hold. Mid-request crash and ambiguous-response recovery were tested with a simulated provider and real durable database commits, not by deliberately interrupting a live Gmail request. Verification records observations at a point in time; it does not establish continuous synchronization or protect against later external mailbox changes.

Automatic interception, general Gmail scheduling, native device notifications, independently monitored backup scheduling and whole-VM recovery remain unproven. Recovery in this slice runs explicitly when requested.

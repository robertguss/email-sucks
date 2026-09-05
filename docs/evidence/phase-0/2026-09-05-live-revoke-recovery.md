# Live interrupted token revocation recovery

Date: 2026-09-05 UTC. Hosted release `ce8e001`. Owner authorized the rehearsal. No permanent application changes.

## Experiment

Started with the single fixture and three-message batch already released. Used the authenticated app's safe-disconnect form in the owner's Chrome incognito window. A temporary diagnostic Req adapter delegated to Req.Finch and killed the request immediately after Google's revoke endpoint returned HTTP 200, before application code could receive the result. Counters contained no tokens or response bodies.

At 03:16:57 UTC the adapter recorded one revoke attempt, HTTP 200 and one request kill. The saved account phase remained `revoking`, with credentials and session retained for recovery. The batch remained three released, zero pending and zero errors. The application had passed its restore/verify stage before committing revocation intent.

Restarted the web container. Installed a guard refusing every provider request except the revoke endpoint, so neither token refresh nor Gmail access could occur during retry. The browser displayed Disconnect pending and stated that mail recovery was verified, with revocation unconfirmed.

At 03:17:32 UTC, Resume safe disconnect made one revoke request. Google returned HTTP 400; the application's narrowly handled `invalid_token` outcome completed cleanup. The browser explicitly reported the saved token was already invalid and advised reviewing Google Account permissions. The database showed no credentials, no session digest and no pending phase. The guard recorded zero forbidden provider operations.

## Cleanup and reconnection

Restored normal configuration, removed both VM/container probe files, and restarted the web container. Readiness passed and RPC confirmed no temporary adapter, loaded probe module or probe file. Reconnected the same allowed test identity through Google consent. At 03:18:43 UTC, independent Gmail reads confirmed all three saved batch messages remained in Inbox, unread and without the controlled batch label.

## Limits

Pass for accepted revocation followed by request death, restart, already-invalid-token retry, local cleanup and reconnect. The response was lost to application code after transport acceptance; this is not a packet-level fault or total VM-loss test. This does not establish immediate revocation propagation across every Google client. Mail was already released before this rehearsal; restoration from a held batch, revocation during restoration and general automatic-interception recovery remain separate proof gaps. Phase 0 is not complete.

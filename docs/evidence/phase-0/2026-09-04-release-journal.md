# Synthetic release journal evidence

Date: 2026-09-04. Local PostgreSQL 18.6 and existing pinned Elixir/OTP dependencies. No new dependencies, provider requests or UI changes.

The Phase 0 journal persists individual pending/unknown/released/unavailable outcomes for the immutable synthetic snapshot. Claims commit an unknown state and a 30-second lease before any hypothetical provider operation. Expired claims return `reconcile`, not `apply`. A replacement token rejects stale outcomes. Only confirmed still-held state returns a message to pending; a timeout must remain unknown.

Checks passed: 57 backend tests, warning-free application compilation and whitespace checks. New tests cover partial progress, late-message rejection, lost response/crash, lease reclamation, stale-worker rejection, unavailable source, empty membership and two simultaneous claimants using distinct PostgreSQL connections. Only one claimant owns the message. Existing snapshot concurrency/immutability and OAuth tests still pass.

This is an internal synthetic persistence probe, not a Gmail release implementation. No worker calls this journal yet. It does not prove provider convergence, account-wide recovery fencing, notification transport, batching capacity or native Gmail behavior. A database token cannot cancel an in-flight external request. The existing snapshot `verified` status means only synthetic Oban verification and is independent of journal completion. Journal completion represents simulated confirmed outcomes only.

Next local slice: executable horizon and Waiting contract examples. Render and owner/device experiments are intentionally deferred while the owner is away.

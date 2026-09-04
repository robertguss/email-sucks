# Executable work-item contract evidence

Date: 2026-09-04. Local, synthetic contract tests only; no provider calls, new dependencies or UI changes.

`PhaseZero.WorkItem` implements the local-date portion of Today/This Week/Whenever, overdue checks, explicit Waiting, visibility-gated human-reply reactivation and confirmed-send dispositions. Batch review and delivery remain separate dimensions. It does not persist workflow or expose a user-facing mail action.

Five new tests initially failed because the model did not exist. All 62 backend tests now pass. Application compilation and formatting pass. Examples cover Friday/Saturday/Sunday, day boundaries, Whenever without a due date, clearing horizons in Waiting/Resolved, held and automated replies preserving Waiting, released/bypassed human replies reactivating once, and failed/pending/unknown sends rejecting dispositions. Existing Open commitments survive reply replay and Keep Open.

The release journal additionally accepts replay of the same confirmed outcome with the original claim token without changing state; conflicting or superseded outcomes remain rejected.

Limits: callers supply already-local calendar dates. IANA timezone conversion, DST occurrence identity, schedule revision races, persistent workflow transitions, per-batch review, Gmail reconciliation and actual send behavior are not implemented by this model. No test result here passes a live provider/device gate.

Next local work: account recovery coordination and its race with normal release claims, followed by schedule-occurrence and per-batch review contracts. Hosted provisioning and device observations remain deferred by the owner.

# ADR-0003: Execute controlled Gmail deliveries in the web service

Date: 2026-09-05. Status: selected for the usable experiment; implementation pending.

The existing web service owns Gmail credentials. Existing workers have no mounted
Gmail secrets. The synthetic scheduler uses different account identities and locks
and is not a verified Gmail release adapter.

Use a dedicated `gmail_delivery` Oban queue in the Gmail-configured web service.
Persist due intent and job insertion atomically; jobs carry only a delivery ID.
Normal workers retain only their current synthetic queue. Restore mode starts
neither Oban nor Gmail access. This needs no new service and works without an open
browser, but a web outage delays delivery until recovery.

Internal execution must validate persisted trial authority, allowed connected
identity and the disconnect fence. Reuse token refresh leasing and
`Controlled.exclusive` account serialization. A browser session must not be stored
in a job or required for unattended execution. Starting a background process does
not authorize broader mailbox operations.

Reuse the tracked filter lifecycle through one new closed trial profile. Preserve
previous experiment rows. Keep exact test interception active across attended
windows, freeze each delivery before changing messages, and retain outcomes across
retries. Stop removes owned interception before restoring eligible held test mail.
Stopped or disconnected intent cannot reactivate interception.

Check Now joins already executing work, but must not consume a future scheduled
occurrence or change the schedule. Manual actions need stable retry identities.
For the attended experiment use a visible five-minute cadence; full user-configured
calendar scheduling remains a separate product requirement.

The installed Oban implementation exposes `Oban.Lifeline` via the `lifeline` option;
`Oban.Plugins.Lifeline` is deprecated. Time-based rescue may duplicate execution.
Choose a rescue bound longer than the bounded job timeout, and prove recovery with
independent processes. Queue concurrency alone cannot replace the account lock or
saved per-message outcomes. Health must detect unresolved due work even when the
HTTP readiness endpoint still succeeds.

Before live activation, verify restart/rescue, lost responses, scheduled/manual
contention, stop/disconnect, expired browser sessions, Gmail scope failure, frozen
membership and unchanged worker/restore credential boundaries. Local fixtures are
not evidence of live provider timing; the attended trial supplies that evidence.

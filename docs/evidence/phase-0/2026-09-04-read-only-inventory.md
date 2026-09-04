# Read-only Gmail inventory boundary evidence

Date: 2026-09-04. Req.Test provider fixtures only; no live mailbox discovery was performed in this slice.

The authenticated Gmail service now has an internal inventory operation using the existing refresh/session boundary. It reads send-as identities, label IDs/names and filter action IDs through fixed Google GET endpoints. Requests use field masks excluding signatures, SMTP settings and filter criteria. The result exposes only identity flags, label/filter counts and possible Held-filter IDs. Candidates are not proof of app ownership; send-as identities are not proof of receiving coverage.

The primary account must match the allowed identity before further settings are read. Invalid sessions make no provider request. Missing/revoked access marks reconnection required. Provider errors and malformed lists return safe errors instead of raw bodies or false empty inventories. No result is persisted or exposed through a new browser route.

98 backend tests and seven Chromium tests pass. Application compilation, formatting, production release build and the full encrypted local backup/restore rehearsal pass. Browser checks initially found pending development migrations (HTTP 503); the six additive Phase 0 migrations were applied locally and all browser checks then passed. Existing Google-account records were not changed by the migrations.

Scope support was checked in the current official method references: [send-as list](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.settings.sendAs/list), [filters list](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.settings.filters/list), [labels list](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.labels/list). No OAuth scope changed and no mutation/send endpoint was added.

## Next critical-path evidence

Controlled live Gmail interception/recovery requires the owner at the computer for additional consent and an agreed synthetic sender/message. Actual notification/device observations require the owner's devices. Hosted outage alerts and R2/Render restoration remain deferred with deployment. The local probes cannot answer arrival-time filter/bypass semantics or native notification behavior. Full product integration remains gated on those empirical results.

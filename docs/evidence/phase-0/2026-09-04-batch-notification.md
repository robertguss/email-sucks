# Synthetic batch notification receipt evidence

Date: 2026-09-04. Fixture callbacks only; no message/alert was sent to a real destination.

A durable receipt records uncertainty before invoking a notifier outside the database transaction. Only complete, nonempty, prepared batches qualify. Payloads contain only the opaque batch identifier and distinct conversation count. Replaying a sent or unknown receipt never invokes the callback again; an explicit confirmed rejection permits retry. Disabled notifications and incomplete/empty batches produce no callback.

93 backend tests pass, including sent replay, notifier crash/uncertainty, confirmed rejection retry, eligibility and transaction boundaries. Application compilation and formatting pass. The receipt is not wired to a transport or automatic worker. Native Gmail/device notifications and independently received Sentry/Better Stack alerts remain unproven.

Next: read-only Gmail identity/filter discovery, preserving the current scope and withholding private provider fields.

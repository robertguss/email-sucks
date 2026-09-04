# Synthetic finite batch review evidence

Date: 2026-09-04. Local synthetic fixtures only; no new dependencies or Gmail/UI changes.

A durable review ledger now records exact conversation grouping and reviewed conversation keys per snapshot. Preparation requires a complete, non-overlapping partition of frozen message IDs. Retrying preparation cannot reset reviews or change grouping. Review is idempotent and requires every selected message in that conversation to be confirmed released.

Account status distinguishes reviewed, unreviewed and pending conversations. Caught Up counts only released intake; delivery-pending remains a separate flag. Missing batch preparation returns an explicit error instead of reporting an empty mailbox. No Gmail unread/archive or work-item state is consulted or changed.

All 72 backend tests pass; compilation and formatting pass. New tests cover a later batch of the same conversation remaining unreviewed, partial release blocking acknowledgment, immutable grouping, duplicate preparation/review, unprepared batches and empty delivery.

Limits: this ledger is an internal Phase 0 probe. It has no UI, routing integration, Undo, immediate-bypass intake or production-scale claim. Grouping is supplied as synthetic fixture data. Live release reconciliation and owner/device gates remain open.

Next: verify IANA timezone support from current official sources and implement DST occurrence resolution locally.

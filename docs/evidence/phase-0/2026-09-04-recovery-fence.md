# Synthetic account recovery fence evidence

Date: 2026-09-04. Local synthetic account keys and message IDs only; no Gmail operations or deployment.

Recovery now persists an account-wide stop. Snapshot creation and message claims take the same PostgreSQL advisory lock as recovery, always before the snapshot row lock. Once the stop commits, new snapshots and normal claims fail with `recovery_active`. Results of existing claims can still be recorded so uncertainty is not hidden. Lease expiry does not bypass recovery.

The diagnostic reports pending, unknown, released and unavailable members, including snapshots whose journals were never initialized. `restore_ready?` requires an explicit synthetic confirmation that interception is disabled and zero recorded unknown operations. It does not report restoration complete. There is no API to automatically reactivate interception or discard unknown claims.

67 backend tests passed, along with application compilation and whitespace checks. New tests cover account isolation, idempotent recovery start, required disable confirmation, pending membership visibility and in-flight outcomes. A separate-connection test held recovery uncommitted, observed the competing claimant waiting on a PostgreSQL lock, then committed recovery and verified claim rejection with no unknown operation created.

Limits: disable confirmation is an internal fixture assertion. No filter removal, provider quiescence, restore operation or complete-account recovery is implemented. Recorded unknown claims remain blocked until their real outcome is established; cancelling an HTTP request or expiring a database lease cannot prove the provider stopped processing it. Snapshot members do not represent a full mailbox inventory. Actual Gmail restoration and independent monitoring remain live proof gates.

Next local work: finite per-batch review state and Caught Up behavior, keeping workflow and Gmail read/archive state separate.

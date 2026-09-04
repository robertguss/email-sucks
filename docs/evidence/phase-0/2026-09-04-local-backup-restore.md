# Local encrypted backup/restore evidence

Date: 2026-09-04. PostgreSQL 18.6, age 1.3.2, pinned project Node/Elixir/OTP. Disposable databases and synthetic keys/content only. No Render/R2/Gmail operation.

Passed a repeatable `test/backup_restore_smoke.py` rehearsal after building the current production release. The run exported an encrypted custom-format database dump, restored it to a new empty database, verified the synthetic application ciphertext with the correct vault key, rejected a wrong vault key, and started the restored application with worker role plus restore mode. Oban was absent, Google configuration was absent even with a credential path set, the unknown release claim remained unknown and job states/attempt counts did not change.

Negative checks passed: corrupt ciphertext, wrong/missing age identity, restore mode absent/false, nonempty restore target, existing export filename and nonexistent export source. Corruption failed before any application tables appeared. A source row added after the export was absent from the restored database, demonstrating the expected recovery-point loss. Private test identities, encrypted files and both disposable databases were removed by cleanup.

The initial rehearsal caught a libpq environment behavior: a URI placed directly into PGDATABASE is not expanded as a connection string. The scripts now use a Node wrapper to pass individual connection fields through libpq environment variables, retaining supported TLS options and keeping secret URLs out of process arguments. The full rehearsal was repeated successfully after the correction.

The earlier successful run took 2.1 seconds for the tiny local fixture; this is not a production recovery-time estimate. Current release build, shell syntax and Node syntax checks pass. [Operator instructions and limits](../../local-backup-restore.md).

Remaining: durable R2 upload/download, retention, independently received backup-failure alerts, actual Render restoration, real recovery-key custody and owner acceptance of measured losses/time.

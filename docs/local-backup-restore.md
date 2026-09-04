# Encrypted local export and restore

Date: 2026-09-04. Implemented and rehearsed on disposable local databases. R2 upload, retention scheduling, independent backup alerts and Render managed recovery are not configured.

## Tools and key custody

The scripts use PostgreSQL 18 client tools, the project's existing Node runtime, and age 1.3.2. The installed age version matched the latest official release when checked. Use a public age recipient on the export host; keep the matching private identity outside Render/R2 with a separate recovery copy. Database vault keys are a second requirement: decrypting an archive does not replace the key that protects credentials inside it. [age release](https://github.com/FiloSottile/age/releases/tag/v1.3.2), [PostgreSQL restore documentation](https://www.postgresql.org/docs/18/app-pgrestore.html)

Generate/store real recovery keys privately when configuring the hosted backup system. The rehearsal generates temporary test identities and removes them afterward. It never reads the development database or real Google keys.

## Export

Set `BACKUP_DATABASE_URL` and `BACKUP_AGE_RECIPIENT` privately in the operator environment, then run `bin/backup-export /private/directory/unique.dump.age`. The directory must already exist. Source connection URLs stay out of child process arguments; the wrapper translates URL fields and supported TLS options into libpq environment settings.

The script streams a custom-format pg_dump into age. It publishes the completed encrypted file atomically without overwriting existing exports. Failed dumps/encryption leave no published backup. Files are private by default. Only encrypted output should later be uploaded to R2. A completed local export is not proof of remote backup durability.

## Restore

Provision a **new isolated empty database** with no running application attached. Set `BACKUP_RESTORE_DATABASE_URL`, `BACKUP_AGE_IDENTITY_FILE`, and `RESTORE_MODE=true` privately, then run `bin/backup-restore /private/directory/unique.dump.age`.

The script rejects nonempty targets. It authenticates/decrypts the entire archive in a private temporary directory before running any restore SQL, then uses pg_restore's single-transaction mode. Missing/wrong keys or corrupt ciphertext cannot cause a partial SQL restore. The plaintext temporary file is removed on normal exit/errors; after a forced process kill, an operator must remove any abandoned private `email-restore.*` directory. Restore only trusted archives.

**Keep `RESTORE_MODE=true` in every restored application process's startup configuration.** The script checks the flag but does not change a hosting service's configuration. Startups in this mode omit Oban and do not load Google credential files. Keep the target isolated until decryption, schema and provider reconciliation are verified. Never enable stale send/release jobs simply because the database restore succeeded.

The scripts neither revoke access nor alter Gmail. They do not automatically reinstall roles, restore database ownership/ACLs, upload files, apply retention, or enable a restored environment.

## Repeatable local rehearsal

Build the current release using `mise exec -- bin/render-build`, then run `mise exec -- python3 test/backup_restore_smoke.py` with PostgreSQL 18 tools and age on PATH. The test uses the local loopback cluster at port 55432, creates uniquely named source/restore databases and removes only those databases. It generates synthetic encrypted values, an active release with an unknown claim, and an Oban job.

The rehearsal checks authenticated export/restore, wrong/missing keys, ciphertext corruption, no overwrite, failure cleanup, rejection of nonempty targets, deliberate loss of a post-backup source change, separate vault-key verification and unchanged pending jobs after restored worker startup. This is local evidence, not a hosted RPO/RTO commitment.

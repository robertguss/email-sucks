# Scheduled encrypted VM backups

Date: 2026-09-05 UTC. Backup code: `07f93b7`. Hosted application image remains `c3f5621`; no web/worker rebuild was required.

The owner explicitly selected same-VM backups for now. Installed age from the VM's Ubuntu package repository and the checked-in systemd service/timer. The service runs as exedev with restricted filesystem writes, a fifteen-minute timeout, a file lock and private output permissions. Only the existing private identity's public recipient was copied to the VM.

## Verification

- Four runner tests passed: retention of 14 complete archives, unrelated files preserved, dump/encryption failure without publication or pruning, last-success receipt preservation, private archive permissions and overlap refusal. All 129 backend tests passed. Review identified a publication durability gap; directory fsync now happens before retention deletion, and review confirmed the fix.
- systemd unit validation passed. The actual installed service completed successfully at 02:45:04 UTC with exit status 0 and a 35,328-byte encrypted archive. A timestamp, size and SHA-256 receipt was saved.
- Downloaded that exact archive to the owner's Mac, matched its checksum, and used the existing authenticated backup-restore tool to restore into a new isolated local database.
- Started the restored application with restore mode enabled and worker role selected. Assertions confirmed no Oban runner, no Gmail configuration, restored encrypted account credentials, no pending disconnect, and the expected released controlled record at repeat revision 2. The restore/startup assertions took approximately 0.8 seconds excluding download; this tiny-fixture result is not a recovery-time guarantee.
- Removed the disposable database and temporary plaintext. Retained the encrypted archive alongside the existing off-VM copies; the private identity stayed on the Mac.
- Deliberately ran the VM backup runner with a nonexistent recipient file. Encryption failed; it published nothing, pruned nothing and preserved the exact prior success receipt. The active timer configuration was unchanged.
- Enabled the persistent daily timer. The first unattended scheduled activation completed at 2026-09-05 03:07:46 UTC with service result success and exit status 0. Its encrypted archive is 36,253 bytes and the receipt reports two retained archives. The daily schedule is 03:00 UTC with up to ten minutes jitter; the next activation is scheduled for September 6. This scheduled archive has not separately undergone a full restore; the earlier archive did.

## Limits

Retains the latest 14 successful archives, including manual runs. Same-disk archives do not protect against loss of the VM or its disk. There is no R2 upload or independent failed/missed-backup alert yet. The user chose to defer external backup storage. Retain the existing Mac copies and separately protect the private identity. See the [runbook](../../vm-backups.md) for status, restore and disable commands.

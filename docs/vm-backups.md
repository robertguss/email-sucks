# Daily backups on the existing VM

Temporary owner-selected storage: encrypted PostgreSQL exports on the same exe.dev VM. This helps with database mistakes and corruption when the host and backup files survive; it does not survive VM/disk loss. Existing encrypted exports on the owner's Mac remain separate recovery copies. R2 and independent failure alerts are deferred.

## Schedule and retention

`email-sucks-backup.timer` runs daily at 03:00 UTC plus up to ten minutes of jitter. Persistent timers catch up after downtime. The service has a fifteen-minute timeout, runs as `exedev`, and prevents overlapping exports with a file lock. It does not depend on the web/worker app being healthy.

`bin/vm-backup` streams a custom-format dump from the existing PostgreSQL container directly through age encryption. No plaintext dump or decryption key is stored on the VM. The public recipient is read from `/home/exedev/.config/email-sucks/backup-recipient.txt`.

Archives live in `/home/exedev/backups/email-sucks`, mode 0700, with individual files mode 0600. Keep the newest 14 successful archives (including manual runs). Publication is atomic and synced before deleting older matching archives. Failed dump/encryption does not publish or prune. `last-success.json` records completion time, filename, size and SHA-256 of the most recent success; a failed run cannot advance it. A crashed process can leave a hidden `.pending-*` directory containing encrypted output only; inspect and remove such leftovers only when no backup is running.

## Install and inspect

Install age from the host package manager. Copy the public recipient only from the separately held private age identity. Create the private backup directory before installing the system service, since its write allowance requires that directory to exist.

```bash
sudo install -m 0644 deploy/email-sucks-backup.service /etc/systemd/system/
sudo install -m 0644 deploy/email-sucks-backup.timer /etc/systemd/system/
sudo systemd-analyze verify /etc/systemd/system/email-sucks-backup.service /etc/systemd/system/email-sucks-backup.timer
sudo systemctl daemon-reload
sudo systemctl start email-sucks-backup.service
sudo systemctl enable --now email-sucks-backup.timer
systemctl list-timers email-sucks-backup.timer
systemctl status email-sucks-backup.service
journalctl -u email-sucks-backup.service --since yesterday
```

Check both last-success age and the service result. A prior successful receipt does not mean the latest run succeeded. The timer is local scheduling, not independent monitoring; no external alert is delivered yet.

## Restore safely

Copy the chosen encrypted archive off the VM. On the machine holding the private identity, use `bin/backup-restore` against a new empty isolated database with `RESTORE_MODE=true`, `BACKUP_RESTORE_DATABASE_URL` and `BACKUP_AGE_IDENTITY_FILE` set privately. It authenticates the full archive before restoration. Never point this command at the active database.

Start the recovered app with restore mode enabled and Gmail configuration absent. Verify recovery records, migration compatibility and that no job runner starts. Reconcile provider state before any later activation; a restored held/release record can be stale. Never copy the decryption identity onto the running VM merely to automate verification there.

Disabling the timer (`sudo systemctl disable --now email-sucks-backup.timer`) stops future scheduled runs without deleting backups. Application releases must preserve the public recipient and backup directory outside the checkout.

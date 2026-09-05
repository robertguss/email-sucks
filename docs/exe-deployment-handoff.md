# Deployment and session handoff

Updated 2026-09-05 UTC. Read [PROGRESS.md](../PROGRESS.md) first. This guide
describes the existing deployment, not instructions to provision a replacement
VM. No secrets are stored here.

## Current session update — 12:52 UTC

The interrupted three-message hold rehearsal passed on the configured Mac. SSH
works again and the authenticated incognito app remains connected. The batch is
released at repeat revision three, all three members unread in Inbox, zero
pending/errors and no pending disconnect. Recovery after restart changed only
the third saved member; the first two already held by Google were not rewritten.
The newcomer stayed outside membership with unchanged labels. Temporary
diagnostics were removed and web restarted; readiness and cleanup passed.
No owner send or authentication action is pending. See the
[live hold evidence](evidence/phase-0/2026-09-05-live-hold-recovery.md) and
[earlier arrival evidence](evidence/phase-0/2026-09-05-live-arrival-recovery.md).

Read-only filter inspection subsequently found three sender-specific Trash
filters with no overlap against the five current fixtures. Full JSON is private
on the owner Mac at `~/.config/email-sucks/hosted-cougar-cedar/filter-inventory/2026-09-05-124751.json`;
mode 0600, directory mode 0700. Final provider comparison found filters unchanged.
The access token naturally expired during inspection; ordinary Check connection
refreshed it successfully without sign-in. No message/filter mutations occurred.
[Evidence](evidence/phase-0/2026-09-05-filter-compatibility-inventory.md).

## Where the app runs

| Item                      | Existing value                                                                                                  |
| ------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Provider                  | exe.dev, one dedicated VM                                                                                       |
| VM / SSH hostname         | `cougar-cedar.exe.xyz`                                                                                          |
| Browser URL               | `https://cougar-cedar.exe.xyz`                                                                                  |
| Visibility                | Private exe.dev proxy; sign-in required; forwards to VM port 4000                                               |
| Source directory on VM    | `/home/exedev/email-sucks`                                                                                      |
| Compose project           | `email-sucks-phase0`                                                                                            |
| Compose files             | `deploy/exe.compose.yaml` **and** `deploy/exe.gmail.compose.yaml`                                               |
| Containers                | `email-sucks-phase0-web-1`, `email-sucks-phase0-worker-1`, `email-sucks-phase0-db-1`                            |
| Database                  | PostgreSQL 18.6, database `email_sucks_phase0`, Compose volume `postgres_data` mounted at `/var/lib/postgresql` |
| Latest verified app image | `email-sucks:ed8756f`                                                                                           |
| Deployed revision marker  | `/home/exedev/email-sucks/DEPLOYED_REVISION`                                                                    |
| Repository                | `https://github.com/robertguss/email-sucks.git`, deployment source branch `main`                                |

The VM builds the Linux Docker image locally; there is no registry push or
automatic deployment pipeline. Updating GitHub does **not** deploy.
Documentation commits after `ed8756f` do not change the running image. Web
serves Phoenix/React/Inertia; the separate Oban worker handles synthetic jobs
only. Real Gmail operations currently run through authenticated web requests.
Automatic interception, scheduled Gmail delivery and sending are disabled.

## Access and historical blockers

On the original Mac, `ssh cougar-cedar.exe.xyz` resolves to SSH user
`robertguss`, port 22, with `IdentitiesOnly yes`, public identity file
`~/.ssh/id_exe.pub`, and the 1Password SSH agent at
`/Users/robertguss/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`.
The public file selects the matching private key in 1Password; it is not itself
a private key. Remote commands use the existing `/home/exedev` paths. Do not
assume a new machine has this SSH configuration.

At a historical attempt (11:31 UTC), the server accepted the public key but the
local agent could not sign. The previous Chrome incognito window had closed. A
new incognito window was opened at exe.dev sign-in and showed Unlock 1Password.
That attempt required the owner to unlock/authorize the SSH agent and sign in.
Access has since been restored; do not request sign-in again without a new
failure. Do not generate replacement credentials or weaken proxy visibility to work around this. On another machine, arrange access to the
existing authorized SSH key through the owner's normal secure process.

Orb resumption check (11:41 UTC): the clean checkout and fetched `origin/main`
both matched `479ab03`. A bounded, batch-mode SSH attempt stopped at host-key
verification; no remote command executed. The orb has no SSH files in
`/home/user/.ssh`, no available SSH agent, and defaults to SSH user `user`
rather than the original Mac's configured user. The 11:31 observations above
apply only to the Mac. Arrange trusted host verification and access to the
existing authorized identity securely, or resume on the configured Mac; do not
disable host verification or copy private keys/cookies through chat or Git. No
diagnostic was installed and current app/provider state remains unverified in
this orb.

The exe.dev browser login and the app's Google OAuth login are separate. Use the
configured receiving test account for Gmail, not a different account from a
regular browser profile. Do not copy browser cookies, tokens or private keys
into this repository. An external HTTP redirect to exe.dev login proves proxy
reachability, not app health.

Read-only checks once SSH is available:

```bash
ssh -o ConnectTimeout=10 cougar-cedar.exe.xyz 'cat /home/exedev/email-sucks/DEPLOYED_REVISION; docker ps --format "{{.Names}} {{.Status}}"; curl --fail --silent --show-error http://localhost:4000/health/ready'
```

Readiness is `/health/ready`, not `/health`. Expected response:
`{"status":"ok"}`. For remote shell automation, use a bounded timeout; a locked
key agent can stall signing even after the connection succeeds.

## Private configuration to preserve

- `/home/exedev/.config/email-sucks/compose.env`: `APP_REVISION`,
  `APP_ENV_FILE`, database passwords and `GMAIL_SECRET_DIR`.
- `/home/exedev/.config/email-sucks/app.env`: runtime configuration including
  database URL, Phoenix secret and restore-mode setting. The live prototype is
  not an inert restore environment; preserve its existing values.
- Resolve the OAuth/key host directory from `GMAIL_SECRET_DIR` privately. Do not
  print full Compose configuration or environment files: they include secrets.
  The overlay mounts `google-oauth.json` and `keys.json` read-only into **web
  only**, owned by UID 65534, mode 0400. Worker and migration service do not
  receive Gmail credentials.
- Hosted callback: `https://cougar-cedar.exe.xyz/auth/google/callback`. Current
  scope includes `gmail.modify` plus identity/email, limited by application code
  to controlled fixtures. Do not regenerate hosted vault/session keys; existing
  encrypted credentials depend on them.
- Original Mac private recovery material:
  `/Users/robertguss/.config/email-sucks/hosted-cougar-cedar/`; backup identity
  and encrypted rehearsal copies:
  `/Users/robertguss/.config/email-sucks/exe-backup-rehearsal/`, with identity
  file `identity.agekey`. These paths are not transferred by Git and may be
  unavailable in another app/machine.

## Release procedure for the existing VM

Use the checked-in runtimes (`mise.toml`), locked dependencies and Dockerfile.
Test and review changes first; current baseline is 138 backend and 23 browser
tests. Commands are in [README](../README.md#verification). Apply development
migrations before browser tests; leave port 4010 free. Do not point local test
commands at the hosted database.

1. Commit the reviewed changes and push to `main` using the agreed Git workflow.
   Use a clean checkout. The previous agent used branch `codex/controlled-gmail`
   and `git push origin HEAD:main`; do not force push or overwrite newer remote
   work. Fetch and reconcile changes first when resuming elsewhere.
2. Transfer the exact committed tree. From the clean local checkout, use Bash
   with pipeline failure checking:

```bash
set -euo pipefail
release_revision=$(git rev-parse --short HEAD)
printf '%s\n' "$release_revision"
git archive --format=tar HEAD | ssh cougar-cedar.exe.xyz 'tar -xf - -C /home/exedev/email-sucks'
```

The VM directory is an extracted source tree, not a checkout to `git pull`. This
overlay transfer does not remove files deleted in Git: inspect
`git diff --name-status <previous-release> HEAD` and explicitly remove only
reviewed deleted source paths on the VM before building. Never recursively clean
`/home/exedev`, secrets, backups or database volumes.

3. SSH into the VM. Run the following in an interactive shell there. Set
   `APP_REVISION` to the exact short commit printed above (replace the
   placeholder). The exported value overrides the old value in `compose.env` for
   these commands:

```bash
cd /home/exedev/email-sucks
export APP_REVISION=REPLACE_WITH_REVIEWED_COMMIT
compose() {
  docker compose --env-file /home/exedev/.config/email-sucks/compose.env \
    -f deploy/exe.compose.yaml -f deploy/exe.gmail.compose.yaml "$@"
}
compose config --quiet
compose build web
```

Build before stopping services. Do not proceed if validation/build fails. Both
Compose files are required on every live update; the base file alone drops Gmail
configuration when recreating web.

4. Before any database migration, take a fresh encrypted backup and authenticate
   it on a machine holding the private age identity:

```bash
sudo systemctl start email-sucks-backup.service
systemctl show email-sucks-backup.service -p Result -p ExecMainStatus
cat /home/exedev/backups/email-sucks/last-success.json
```

Require service success and a fresh receipt. Copy the named encrypted archive to
the owner-controlled machine, compare its SHA-256 with the receipt, and
authenticate the entire archive.
`age --decrypt --identity /private/path/identity.agekey <archive> | pg_restore --list`
with Bash `pipefail` checks authentication and archive structure, not a full
restore. For an actual isolated restore use [the backup runbook](vm-backups.md).
Never place the private decryption key on the VM merely for this check.

5. Run migrations once, then recreate services:

```bash
compose stop worker
compose run --rm -T migrate </dev/null
compose up -d --no-build --wait web worker
curl --fail --silent --show-error http://localhost:4000/health/ready
```

For an incompatible migration, stop web as well before applying it. The last
migration was additive, so web stayed up until recreation. **Use `-T` and
`</dev/null` on the one-off migration**: when a script is piped through SSH, an
interactive Compose container can consume the remaining script input, leaving
later deployment steps unexecuted. Check each step's exit code; confirm
web/worker actually run the target image, rather than relying only on migration
output.

6. After healthy startup, persist the deployed revision in the private Compose
   file and marker without printing other values. Run in the same remote shell
   with `APP_REVISION` still exported:

```bash
python3 - <<'PY'
import os
from pathlib import Path
revision = os.environ['APP_REVISION']
assert revision and all(c in '0123456789abcdef' for c in revision)
p = Path('/home/exedev/.config/email-sucks/compose.env')
lines = p.read_text().splitlines()
assert sum(line.startswith('APP_REVISION=') for line in lines) == 1
p.write_text('\n'.join('APP_REVISION=' + revision if line.startswith('APP_REVISION=') else line for line in lines) + '\n')
Path('/home/exedev/email-sucks/DEPLOYED_REVISION').write_text(revision + '\n')
PY

docker inspect --format '{{.Name}} {{.Config.Image}} {{.State.Status}}' \
  email-sucks-phase0-web-1 email-sucks-phase0-worker-1
```

Verify the authenticated browser, relevant provider read-back, and worker
behavior as appropriate. Record release SHA, checks, migration/backup evidence
and remaining limitations in `PROGRESS.md`; commit/push documentation. Do not
count a login page or a synthetic test as live Gmail evidence.

## Rollback, backup and recovery constraints

Do not use `docker compose down --volumes`, delete recovery rows, or clear
pending intent manually. Never roll back to an image that does not understand
saved batch/repeat/disconnect state. In particular, pre-batch images cannot
recover the existing batch; pre-disconnect images cannot enforce
pending-disconnect fences. Image rollback does not reverse migrations. If
compatibility is uncertain, retain the current release for recovery or use an
isolated restore with Gmail and jobs disabled.

Daily encrypted backups run from systemd (`email-sucks-backup.timer` /
`.service`) at 03:00 UTC plus up to ten minutes jitter, retaining 14 successful
archives under `/home/exedev/backups/email-sucks`. Public recipient:
`/home/exedev/.config/email-sucks/backup-recipient.txt`. The service executes
the checked-in `/home/exedev/email-sucks/bin/vm-backup`, so deployment must
preserve that script. Same-disk backups do not survive total VM/disk loss. R2
and independently scheduled off-VM backups were deferred by the owner;
independent failed/missed-backup alerts are not configured. See
[backup runbook](vm-backups.md).

## Exact stopping point for the next app

The interrupted hold and earlier new-arrival rehearsals are complete. No fault
adapter is installed and no mailbox operation is pending. The final verified
state is the released revision-three batch described above. The app image is
still `ed8756f`; these evidence-only changes require no deployment.

Next implement the bounded durable filter lifecycle described in the
[prepared overlap experiment](phase-0-filter-compatibility.md), before any
settings consent or filter activation. Independent alerts and actual-device
notification evidence also remain open. Automatic
interception and real scheduled Gmail delivery remain disabled. Prepare bounded
experiments before requesting any additional owner-sent fixtures. Preserve all
durable recovery rows and use revision-guarded repeat forms.

The historical checkout was `/Users/robertguss/.codex/worktrees/1373/email-sucks`;
its ignored helpers were unavailable at the latest check. The current isolated
checkout is `/Users/robertguss/.codex/worktrees/e245/email-sucks`. Do not rely on
ignored helpers surviving a worktree cleanup.
Another saved checkout has unrelated changes; do not overwrite them. All durable
changes from this task are pushed to `main`; ignored local scripts, private
material, browser sessions and 1Password authorization do not follow the Git
clone. Continue only the controlled Phase 0 scope; full product implementation
and personal dogfood remain gated.

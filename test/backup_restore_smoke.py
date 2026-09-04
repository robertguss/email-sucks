"""Disposable local PostgreSQL rehearsal; never targets the development database.
Run after bin/render-build with PostgreSQL 18 client tools and age on PATH.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
RELEASE = str(ROOT / "_build/prod/rel/email_sucks/bin/email_sucks")
env = os.environ.copy()
for key in list(env):
    if key.startswith("GMAIL_") or key in ("PHX_SERVER", "PHX_HOST", "DATABASE_URL"):
        env.pop(key)
env.update(PGHOST="127.0.0.1", PGPORT="55432", PGUSER="postgres", APP_ROLE="web",
           RESTORE_MODE="false", SECRET_KEY_BASE="s" * 64)
source = "backup_source_" + uuid.uuid4().hex[:12]
target = "backup_restore_" + uuid.uuid4().hex[:12]
created = []


def run(args, context=env, success=True):
    result = subprocess.run(args, cwd=ROOT, env=context, text=True, capture_output=True)
    if success:
        if result.returncode:
            raise RuntimeError(result.stderr)
    else:
        assert result.returncode != 0, "Expected failure was accepted"
    return result.stdout.strip()


def url(name):
    return "postgresql://postgres@127.0.0.1:55432/" + name


def sql(name, statement):
    return run(["psql", "-X", "-qAt", "--set", "ON_ERROR_STOP=1", "-c", statement],
               {**env, "PGDATABASE": name})


started = time.monotonic()
try:
    for name in (source, target):
        run(["createdb", name])
        created.append(name)
    source_env = {**env, "DATABASE_URL": url(source)}
    run([RELEASE, "eval", "EmailSucks.Release.migrate()"], source_env)
    run([RELEASE, "eval", '''
{:ok, _} = Application.ensure_all_started(:email_sucks)
Application.put_env(:email_sucks, :gmail, vault_key: String.duplicate("v", 64))
cipher = EmailSucks.Gmail.Vault.seal(%{"fixture" => "synthetic-only"}, "backup-proof")
EmailSucks.Repo.query!("CREATE TABLE backup_fixture (ciphertext text NOT NULL)")
EmailSucks.Repo.query!("INSERT INTO backup_fixture VALUES ($1)", [cipher])
{:ok, run} = EmailSucks.PhaseZero.Scheduling.check_now(Ecto.UUID.generate(), "backup-click", ["fixture-a"])
{:ok, _} = EmailSucks.PhaseZero.ReleaseJournal.claim(run.snapshot_id, 100)
'''], source_env)
    with tempfile.TemporaryDirectory(prefix="backup-proof-", dir=ROOT / ".local") as directory:
        work = Path(directory)
        key = work / "identity.txt"
        run(["age-keygen", "-o", str(key)])
        recipient = run(["age-keygen", "-y", str(key)])
        archive = work / "database.dump.age"
        export_env = {**env, "BACKUP_DATABASE_URL": url(source), "BACKUP_AGE_RECIPIENT": recipient}
        run(["bin/backup-export", str(archive)], export_env)
        assert archive.read_bytes().startswith(b"age-encryption.org/v1")
        assert archive.stat().st_mode & 0o077 == 0
        before = archive.read_bytes()
        run(["bin/backup-export", str(archive)], export_env, success=False)
        assert archive.read_bytes() == before
        failed_export = work / "must-not-exist.age"
        run(["bin/backup-export", str(failed_export)],
            {**export_env, "BACKUP_DATABASE_URL": url(source + "_missing")}, success=False)
        assert not failed_export.exists()

        restore_env = {**env, "RESTORE_MODE": "true", "BACKUP_RESTORE_DATABASE_URL": url(target),
                       "BACKUP_AGE_IDENTITY_FILE": str(key)}
        corrupt = work / "corrupt.age"
        damaged = bytearray(before)
        damaged[-1] ^= 1
        corrupt.write_bytes(damaged)
        run(["bin/backup-restore", str(corrupt)], restore_env, success=False)
        assert sql(target, "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'") == "0"
        run(["bin/backup-restore", str(archive)],
            {**restore_env, "BACKUP_AGE_IDENTITY_FILE": str(work / "missing-key")}, success=False)
        wrong_key = work / "wrong-identity.txt"
        run(["age-keygen", "-o", str(wrong_key)])
        run(["bin/backup-restore", str(archive)],
            {**restore_env, "BACKUP_AGE_IDENTITY_FILE": str(wrong_key)}, success=False)
        run(["bin/backup-restore", str(archive)], {**restore_env, "RESTORE_MODE": "false"}, success=False)
        assert sql(target, "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'") == "0"

        # A source change after export is deliberately absent from the restore.
        sql(source, "INSERT INTO backup_fixture SELECT ciphertext FROM backup_fixture LIMIT 1")
        run(["bin/backup-restore", str(archive)], restore_env)
        assert sql(source, "SELECT count(*) FROM backup_fixture") == "2"
        assert sql(target, "SELECT count(*) FROM backup_fixture") == "1"
        run(["bin/backup-restore", str(archive)], restore_env, success=False)
        jobs_before = sql(target, "SELECT state || ':' || attempt FROM oban_jobs ORDER BY id")
        run([RELEASE, "eval", '''
{:ok, _} = Application.ensure_all_started(:email_sucks)
nil = Process.whereis(Oban)
false = EmailSucks.Gmail.configured?()
{:ok, %{rows: [[cipher]]}} = EmailSucks.Repo.query("SELECT ciphertext FROM backup_fixture")
Application.put_env(:email_sucks, :gmail, vault_key: String.duplicate("v", 64))
{:ok, %{"fixture" => "synthetic-only"}} = EmailSucks.Gmail.Vault.open(cipher, "backup-proof")
Application.put_env(:email_sucks, :gmail, vault_key: String.duplicate("w", 64))
{:error, :invalid_ciphertext} = EmailSucks.Gmail.Vault.open(cipher, "backup-proof")
{:ok, %{rows: [[1]]}} = EmailSucks.Repo.query("SELECT count(*) FROM phase_zero_release_journals WHERE entries->'fixture-a'->>'state' = 'unknown'")
'''], {**restore_env, "DATABASE_URL": url(target), "APP_ROLE": "worker", "GMAIL_OAUTH_FILE": "/must-not-load.json"})
        assert sql(target, "SELECT state || ':' || attempt FROM oban_jobs ORDER BY id") == jobs_before
        assert not list(work.glob(".email-backup.*"))
    print(f"PASS: encrypted export/restore, corruption/key/overwrite guards, stale jobs inert; {time.monotonic() - started:.1f}s")
finally:
    for name in reversed(created):
        run(["dropdb", name])

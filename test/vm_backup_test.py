"""Exercise publication, retention and failure with executable provider doubles."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

RUNNER = Path(__file__).resolve().parents[1] / 'bin/vm-backup'


class VMBackupTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.backups = self.root / 'backups'
        self.backups.mkdir()
        self.commands = self.root / 'commands'
        self.commands.mkdir()
        for name, body in {
            'docker': 'import os,sys\nsys.stdout.buffer.write(b"dump-data")\nsys.exit(int(os.environ.get("DUMP_EXIT", "0")))',
            'age': 'import os,sys\nsys.stdout.buffer.write(b"encrypted:" + sys.stdin.buffer.read())\nsys.exit(int(os.environ.get("AGE_EXIT", "0")))',
        }.items():
            p = self.commands / name
            p.write_text('#!/usr/bin/env python3\n' + body + '\n')
            p.chmod(0o755)
        recipient = self.root / 'recipient'
        recipient.write_text('age1public-test-recipient\n')
        self.env = dict(os.environ, PATH=str(self.commands) + os.pathsep + os.environ['PATH'],
                        BACKUP_DIR=str(self.backups), BACKUP_AGE_RECIPIENT_FILE=str(recipient))

    def run_backup(self, **env):
        return subprocess.run([str(RUNNER)], env=dict(self.env, **env), capture_output=True)

    def seed(self):
        for day in range(1, 16):
            (self.backups / f'email-sucks-202601{day:02d}T030000Z-abcdef12.dump.age').write_bytes(b'old')

    def test_success_publishes_and_keeps_fourteen(self):
        self.seed()
        unrelated = self.backups / 'other.dump.age'
        unrelated.write_bytes(b'keep')
        result = self.run_backup()
        self.assertEqual(result.returncode, 0, result.stderr)
        archives = list(self.backups.glob('email-sucks-*.dump.age'))
        self.assertEqual(len(archives), 14)
        self.assertTrue(unrelated.exists())
        self.assertTrue((self.backups / 'last-success.json').exists())
        self.assertFalse(list(self.backups.glob('.pending-*')))

    def test_partial_dump_and_encryption_failure_never_publish_or_prune(self):
        self.seed()
        for failure in ['DUMP_EXIT', 'AGE_EXIT']:
            with self.subTest(failure=failure):
                result = self.run_backup(**{failure: '1'})
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(len(list(self.backups.glob('email-sucks-*.dump.age'))), 15)
                self.assertFalse((self.backups / 'last-success.json').exists())
                self.assertFalse(list(self.backups.glob('.pending-*')))

    def test_failure_preserves_last_success_and_private_permissions(self):
        self.assertEqual(self.run_backup().returncode, 0)
        receipt = (self.backups / 'last-success.json').read_bytes()
        archives = list(self.backups.glob('email-sucks-*.dump.age'))
        self.assertEqual(archives[0].stat().st_mode & 0o777, 0o600)
        self.assertNotEqual(self.run_backup(DUMP_EXIT='1').returncode, 0)
        self.assertEqual((self.backups / 'last-success.json').read_bytes(), receipt)
        self.assertTrue(archives[0].exists())

    def test_concurrent_run_is_refused(self):
        import fcntl
        with (self.backups / '.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertNotEqual(self.run_backup().returncode, 0)
            self.assertFalse((self.backups / 'last-success.json').exists())


if __name__ == '__main__':
    unittest.main()

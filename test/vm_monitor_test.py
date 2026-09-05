"""Monitor failures must withhold heartbeats and never print provider secrets."""
import contextlib
import datetime
import importlib.machinery
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import patch
import urllib.error

RUNNER = Path(__file__).resolve().parents[1] / 'bin/vm-monitor'
monitor = types.ModuleType('vm_monitor')
importlib.machinery.SourceFileLoader(monitor.__name__, str(RUNNER)).exec_module(monitor)


class VMMonitorTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.now = datetime.datetime.now(datetime.timezone.utc)
        self.archive = self.root / 'email-sucks-20260905T030000Z-abcdef12.dump.age'
        self.archive.write_bytes(b'ciphertext')
        self.receipt = {'completed_at': self.now.isoformat(), 'archive': self.archive.name,
                        'bytes': 10, 'sha256': 'a' * 64}
        self.write_receipt()
        self.url = self.root / 'heartbeat'
        self.secret = 'https://uptime.betterstack.com/api/v1/heartbeat/secret-token'
        self.url.write_text(self.secret + '\n')
        self.url.chmod(0o600)

    def write_receipt(self):
        (self.root / 'last-success.json').write_text(json.dumps(self.receipt))

    def test_backup_healthy_and_stale_future_missing(self):
        self.assertIsNone(monitor.backup_check(self.root, self.now))
        for delta, expected in [(datetime.timedelta(hours=-27), 'backup_stale'),
                                (datetime.timedelta(seconds=1), 'backup_future')]:
            self.receipt['completed_at'] = (self.now + delta).isoformat()
            self.write_receipt()
            self.assertEqual(monitor.backup_check(self.root, self.now), expected)
        self.receipt['completed_at'] = self.now.isoformat()
        self.write_receipt()
        self.archive.unlink()
        self.assertEqual(monitor.backup_check(self.root, self.now), 'backup_missing')
        (self.root / 'last-success.json').unlink()
        self.assertEqual(monitor.backup_check(self.root, self.now), 'backup_missing')

    def test_backup_malformed_or_unsafe_archive(self):
        for key, value in [('archive', '../private'), ('bytes', True), ('bytes', 11),
                           ('sha256', 'wrong'), ('completed_at', 'not a timestamp'),
                           ('completed_at', '2026-09-05T03:00:00')]:
            with self.subTest(key=key, value=value):
                original = self.receipt[key]
                self.receipt[key] = value
                self.write_receipt()
                self.assertEqual(monitor.backup_check(self.root, self.now), 'backup_invalid')
                self.receipt[key] = original
        self.write_receipt()
        self.archive.unlink()
        self.archive.symlink_to(self.root / 'last-success.json')
        self.assertEqual(monitor.backup_check(self.root, self.now), 'backup_invalid')

    def test_worker_success_semantic_failure_and_malformed(self):
        prefix = b'EMAIL_SUCKS_HEALTH='
        healthy = prefix + b'{"healthy":true,"failures":[]}'
        for output, expected in [
            (healthy, None),
            (b'=ESOCK WARNING ... Failed open sctp dynamic library libsctp.so.1\n' + healthy + b'\n', None),
            (prefix + b'{"healthy":false,"failures":["database_unavailable"]}', 'worker_unhealthy'),
            (prefix + b'{"healthy":true,"failures":["secret"]}', 'worker_response_invalid'),
            (prefix + b'{"healthy":false,"failures":[]}', 'worker_response_invalid'),
            (healthy + b'\n' + healthy, 'worker_response_invalid'),
            (b'{"healthy":true,"failures":[]}', 'worker_response_invalid'),
            (b'database secret error', 'worker_response_invalid'),
            (b'', 'worker_response_invalid'),
        ]:
            with patch.object(monitor, 'worker_output', return_value=output):
                self.assertEqual(monitor.worker_check(), expected)
        for failure in [ValueError('secret'), subprocess.TimeoutExpired('secret', 20)]:
            with patch.object(monitor, 'worker_output', side_effect=failure):
                self.assertEqual(monitor.worker_check(), 'worker_unavailable')

    def test_worker_capture_has_output_and_time_bounds(self):
        self.assertEqual(monitor.worker_output([sys.executable, '-c', 'print("ok")']), b'ok\n')
        for code in ['print("x" * 1000000)', 'raise SystemExit(1)']:
            with self.assertRaises(ValueError):
                monitor.worker_output([sys.executable, '-c', code])
        with self.assertRaises(TimeoutError):
            monitor.worker_output([sys.executable, '-c', 'import time; time.sleep(10)'], timeout=0.05)

    def test_web_exact_success_and_failure(self):
        with patch.object(monitor, 'request', return_value=b'{"status":"ok"}'):
            self.assertIsNone(monitor.web_check('run'))
        with patch.object(monitor, 'request', return_value=b'{"status":"unavailable"}'):
            self.assertEqual(monitor.web_check('run'), 'web_response_invalid')
        with patch.object(monitor, 'request', side_effect=OSError('secret')):
            self.assertEqual(monitor.web_check('run'), 'web_unavailable')

    def test_heartbeat_configuration_and_delivery(self):
        with patch.object(monitor, 'request', return_value=b'OK') as request:
            self.assertIsNone(monitor.heartbeat('run', self.url))
            request.assert_called_once_with(self.secret, 'run')
        with patch.object(monitor, 'request', side_effect=OSError(self.secret)):
            self.assertEqual(monitor.heartbeat('run', self.url), 'heartbeat_delivery_failed')
        for value in ['http://uptime.betterstack.com/api/v1/heartbeat/token',
                      self.secret + '?query=secret', self.secret + '/fail',
                      'https://other.example/api/v1/heartbeat/token']:
            self.url.write_text(value)
            with patch.object(monitor, 'request') as request:
                self.assertEqual(monitor.heartbeat('run', self.url), 'heartbeat_configuration_invalid')
                request.assert_not_called()
        self.url.write_text(self.secret)
        self.url.chmod(0o644)
        self.assertEqual(monitor.heartbeat('run', self.url), 'heartbeat_configuration_invalid')

    def test_redirects_are_refused(self):
        self.assertIsNone(monitor.NoRedirect().redirect_request(None, None, 302, '', {}, self.secret))

    def test_monitor_withholds_on_every_failure_and_check_only(self):
        for failing in ['web_check', 'worker_check', 'backup_check', None]:
            for check_only in [False, True]:
                with contextlib.ExitStack() as stack:
                    for name in ['web_check', 'worker_check', 'backup_check']:
                        stack.enter_context(patch.object(monitor, name, return_value='test_failure' if name == failing else None))
                    heartbeat = stack.enter_context(patch.object(monitor, 'heartbeat', return_value=None))
                    output = io.StringIO()
                    with contextlib.redirect_stdout(output):
                        status = monitor.monitor(check_only)
                    self.assertEqual(status, int(failing is not None))
                    self.assertEqual(heartbeat.call_count, int(failing is None and not check_only))
                    report = json.loads(output.getvalue())
                    self.assertEqual(report['healthy'], failing is None)
                    self.assertEqual(str(monitor.uuid.UUID(report['run_id'])), report['run_id'])

    def test_secret_never_appears_in_output_on_transport_failure(self):
        with patch.object(monitor, 'web_check', return_value=None), patch.object(monitor, 'worker_check', return_value=None), patch.object(monitor, 'backup_check', return_value=None), patch.object(monitor, 'HEARTBEAT_FILE', self.url), patch.object(monitor, 'request', side_effect=OSError(self.secret)):
            # Supply the test path explicitly because the production default is deliberately fixed.
            original = monitor.heartbeat
            with patch.object(monitor, 'heartbeat', side_effect=lambda run_id: original(run_id, self.url)):
                output = io.StringIO()
                with contextlib.redirect_stdout(output):
                    self.assertEqual(monitor.monitor(), 1)
                self.assertNotIn('secret', output.getvalue())
                self.assertEqual(json.loads(output.getvalue())['failures'], ['heartbeat_delivery_failed'])


if __name__ == '__main__':
    unittest.main()

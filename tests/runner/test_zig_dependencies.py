"""Dependency preparation must recover transport faults without retrying checks."""
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

from zig_dependencies import prepare


class Dependencies(unittest.TestCase):
    def run_fixture(self, script, *, timeout=5):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            compiler = root / "zig"
            compiler.write_text(f"#!{sys.executable}\n" + '''import os, sys, time
from pathlib import Path
assert sys.argv[1:] == ['build', '--fetch=all', '--color', 'off'], sys.argv
record = Path('attempts')
attempt = int(record.read_text()) + 1 if record.exists() else 1
record.write_text(str(attempt))
''' + script)
            compiler.chmod(0o700)
            with patch.dict(os.environ, {"PATH": str(root) + os.pathsep + os.environ["PATH"]}):
                code = prepare(root, delays=(0, 0, 0), attempt_seconds=timeout)
            report = json.loads((root / ".cache/ci/zig-dependencies.json").read_text())
            artifacts = root / ".cache/ci" / report["run_directory"]
            logs = [path.read_text() for path in sorted(artifacts.glob("*.log"))]
            if (root / "pid").exists():
                with self.assertRaises(ProcessLookupError):
                    os.kill(int((root / "pid").read_text()), 0)
            return code, report, logs

    def test_recovers_observed_dns_failure_then_fetches_once_successfully(self):
        code, report, logs = self.run_fixture('''
if attempt == 1:
    print('packages/zig/transit-fuze/build.zig.zon:10:20: error: unable to discover remote git server capabilities: NameServerFailure')
    sys.exit(1)
print('dependencies fetched')
''')
        self.assertEqual(code, 0)
        self.assertTrue(report['completed'])
        self.assertEqual([row['exit_code'] for row in report['attempts']], [1, 0])
        self.assertIn('NameServerFailure', logs[0])
        self.assertIn('dependencies fetched', logs[1])

    def test_permanent_and_mixed_failures_stop_immediately(self):
        for diagnostic in ('error: hash mismatch', 'error: invalid manifest',
                           'error: unable to discover remote git server capabilities: AuthenticationFailed',
                           'error: NameServerFailure\nerror: hash mismatch',
                           'unexpected failure without a Zig diagnostic'):
            with self.subTest(diagnostic=diagnostic):
                code, report, logs = self.run_fixture(f'print({diagnostic!r})\nsys.exit(23)\n')
                self.assertEqual(code, 23)
                self.assertFalse(report['completed'])
                self.assertEqual(len(logs), 1)

    def test_exhaustion_preserves_failure_and_all_attempts(self):
        code, report, logs = self.run_fixture("print('error: NameServerFailure')\nsys.exit(1)\n")
        self.assertEqual(code, 1)
        self.assertFalse(report['completed'])
        self.assertEqual(len(logs), 4)

    def test_timeout_joins_fetch_process_and_cannot_pass(self):
        code, report, logs = self.run_fixture("Path('pid').write_text(str(os.getpid()))\ntime.sleep(60)\n", timeout=.2)
        self.assertEqual(code, 124)
        self.assertFalse(report['completed'])
        self.assertEqual(len(logs), 4)
        self.assertTrue(all(row['timed_out'] and not row['completed'] for row in report['attempts']))


class CompilerDownload(unittest.TestCase):
    def check_mirrors(self, initial, responses):
        archive = b'pinned compiler archive\x00\xff'
        requests = []

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                requests.append(self.path)
                status, body = responses[int(self.path[1:])]
                self.send_response(status)
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *_args):
                pass

        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever)
        thread.start()
        try:
            with tempfile.TemporaryDirectory() as directory:
                target = Path(directory) / 'archive with spaces'
                target.write_bytes(initial)
                script = Path(__file__).resolve().parents[2] / 'nix/verify-zig-download.sh'
                result = subprocess.run([
                    'bash', str(script), hashlib.sha256(archive).hexdigest(), str(target),
                    *[f'http://127.0.0.1:{server.server_port}/{i}' for i in range(len(responses))],
                ], capture_output=True, text=True, timeout=10)
                return result, target.read_bytes(), requests
        finally:
            server.shutdown()
            thread.join()
            server.server_close()

    def test_valid_archive_needs_no_fallback(self):
        archive = b'pinned compiler archive\x00\xff'
        result, content, requests = self.check_mirrors(archive, [(200, b'wrong')])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(content, archive)
        self.assertEqual(requests, [])

    def test_empty_corrupt_and_missing_mirrors_fall_through(self):
        archive = b'pinned compiler archive\x00\xff'
        result, content, requests = self.check_mirrors(b'', [
            (200, b''), (200, b'corrupt'), (404, b'missing'), (200, archive),
        ])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(content, archive)
        self.assertEqual(requests, ['/0', '/1', '/2', '/3'])

    def test_no_matching_archive_fails_without_changing_pin(self):
        result, content, requests = self.check_mirrors(b'partial', [(200, b'wrong')])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('No Zig mirror supplied the pinned SHA-256 archive', result.stderr)
        self.assertEqual(content, b'wrong')
        self.assertEqual(requests, ['/0'])


if __name__ == '__main__':
    unittest.main()

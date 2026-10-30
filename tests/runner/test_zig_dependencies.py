"""Dependency preparation must recover transport faults without retrying checks."""
import json
import os
from pathlib import Path
import sys
import tempfile
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


if __name__ == '__main__':
    unittest.main()

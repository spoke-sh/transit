"""Real compiler-process controls for bounded standalone package scheduling."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

from capture import verify
from packages import discover

ROOT = Path(__file__).resolve().parents[2]


class Packages(unittest.TestCase):
    def fixture(self, root, script):
        runner = root / "tests/runner"
        runner.mkdir(parents=True)
        for name in ("packages.py", "capture.py"):
            shutil.copy2(ROOT / "tests/runner" / name, runner / name)
        for name in ("alpha", "beta", "gamma", "omega"):
            package = root / "packages/zig" / name
            package.mkdir(parents=True)
            (package / "build.zig").write_text("fixture")
            (package / "build.zig.zon").write_text("fixture")
        binary = root / "zig"
        binary.write_text(f"#!{sys.executable}\n" + script)
        binary.chmod(0o700)
        return runner / "packages.py", os.environ | {"PATH": str(root) + os.pathsep + os.environ["PATH"]}

    def test_each_manifest_and_concurrency_limit_with_complete_records(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runner, env = self.fixture(root, '''import json, os, sys, time
from pathlib import Path
assert sys.argv[1:] == ['build', 'check']
assert Path('build.zig.zon').is_file()
started = time.monotonic()
Path('started').touch()
if Path.cwd().name in ('alpha', 'beta'):
    deadline = time.monotonic() + 10
    while len(list(Path('..').glob('*/started'))) < 2:
        assert time.monotonic() < deadline
        time.sleep(.01)
time.sleep(.15)
Path('observed.json').write_text(json.dumps({'pid': os.getpid(), 'start': started, 'end': time.monotonic()}))
print('compiled', Path.cwd().name)
''')
            result = subprocess.run([sys.executable, "-B", runner, "--jobs", "2"], env=env, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            report = json.loads((root / ".cache/checks/packages-build.json").read_text())
            verify(root / ".cache/checks" / report["run_directory"])
            observations = [json.loads((path / "observed.json").read_text()) for path in discover(root)]
            events = sorted([(row['start'], 1) for row in observations] + [(row['end'], -1) for row in observations])
            current = peak = 0
            for _, change in events:
                current += change
                peak = max(peak, current)
            self.assertEqual(peak, 2)
            self.assertEqual([row['id'] for row in report['checks']], ['alpha', 'beta', 'gamma', 'omega'])

    def test_failure_preserves_exit_status_and_does_not_launch_later_packages(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runner, env = self.fixture(root, "import sys\nprint('original compile failure')\nsys.exit(23)\n")
            result = subprocess.run([sys.executable, "-B", runner, "--jobs", "1"], env=env, capture_output=True)
            self.assertEqual(result.returncode, 23)
            report = json.loads((root / ".cache/checks/packages-build.json").read_text())
            self.assertFalse(report['completed'])
            self.assertEqual([row['id'] for row in report['checks']], ['alpha'])
            run = root / ".cache/checks" / report['run_directory']
            with self.assertRaisesRegex(AssertionError, 'incomplete'):
                verify(run)
            self.assertIn('original compile failure', (run / 'alpha.log').read_text())

    def test_interruption_joins_active_compilers_and_cannot_complete(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runner, env = self.fixture(root, '''import os, time
from pathlib import Path
Path('pid').write_text(str(os.getpid()))
time.sleep(60)
''')
            process = subprocess.Popen([sys.executable, "-B", runner, "--jobs", "2"], env=env,
                                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            try:
                deadline = time.monotonic() + 10
                while len(list((root / 'packages/zig').glob('*/pid'))) < 2:
                    self.assertIsNone(process.poll())
                    self.assertLess(time.monotonic(), deadline)
                    time.sleep(.01)
                process.send_signal(signal.SIGTERM)
                _, diagnostic = process.communicate(timeout=10)
                self.assertEqual(process.returncode, 130, diagnostic.decode())
                for path in (root / 'packages/zig').glob('*/pid'):
                    with self.assertRaises(ProcessLookupError):
                        os.kill(int(path.read_text()), 0)
                report = json.loads((root / '.cache/checks/packages-build.json').read_text())
                self.assertFalse(report['completed'])
                self.assertIsNone(report['active'])
                self.assertEqual(len(report['checks']), 2)
                self.assertTrue(all(not row['completed'] for row in report['checks']))
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.communicate(timeout=10)

    def test_missing_manifest_cannot_be_silently_omitted(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root, "")
            (root / 'packages/zig/beta/build.zig.zon').unlink()
            with self.assertRaisesRegex(AssertionError, 'manifest missing'):
                discover(root)


if __name__ == "__main__":
    unittest.main()

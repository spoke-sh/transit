"""Moved drivers retain arguments and imports without contaminating consumers."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Launch(unittest.TestCase):
    def test_nested_driver_from_any_directory_and_private_child_imports(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runner = root / "tests/runner"
            runner.mkdir(parents=True)
            for name in ("launch.py", "paths.py"):
                (runner / name).write_bytes((ROOT / "tests/runner" / name).read_bytes())
            domain = root / "tests/query/files"
            domain.mkdir(parents=True)
            (domain / "oracle.py").write_text("value = 'independent fixture'\n")
            driver = domain / "driver.py"
            driver.write_text('''import json, os, subprocess, sys
from pathlib import Path
from query.files.oracle import value
from runner.paths import ROOT
child = subprocess.run([sys.executable, '-c', 'import query.files.oracle'],
                       cwd=ROOT / 'consumer', capture_output=True)
print(json.dumps(dict(argv=sys.argv[1:], cwd=str(Path.cwd()), root=str(ROOT),
                      oracle=value, pythonpath=os.getenv('PYTHONPATH'), child=child.returncode)))
sys.exit(int(sys.argv[1]))
''')
            (root / "consumer").mkdir()
            env = {key: value for key, value in os.environ.items() if key != "PYTHONPATH"}
            for cwd in (root, domain, root / "consumer"):
                for code in (0, 23):
                    result = subprocess.run([sys.executable, '-B', runner / 'launch.py',
                                             'tests/query/files/driver.py', str(code), 'literal argument $()'],
                                            cwd=cwd, env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, code, result.stderr)
                    value = json.loads(result.stdout)
                    self.assertEqual(value['argv'], [str(code), 'literal argument $()'])
                    self.assertEqual(value['cwd'], str(cwd))
                    self.assertEqual(value['root'], str(root))
                    self.assertEqual(value['oracle'], 'independent fixture')
                    self.assertIsNone(value['pythonpath'])
                    self.assertNotEqual(value['child'], 0)
            # Moving to a deeper owner needs no path-depth changes in the driver.
            moved = domain / 'deeper/driver.py'
            moved.parent.mkdir()
            driver.rename(moved)
            result = subprocess.run([sys.executable, '-B', runner / 'launch.py', moved, '0'],
                                    cwd=root, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            for target in ('missing.py', '../outside.py', 'tests/runner/../..'):
                result = subprocess.run([sys.executable, '-B', runner / 'launch.py', target],
                                        cwd=root, env=env, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('not a Python test', result.stderr)


if __name__ == '__main__':
    unittest.main()

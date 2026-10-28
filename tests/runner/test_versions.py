"""Negative controls for lockstep manifests and release tag qualification."""
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
check = runpy.run_path(str(ROOT / 'tasks/version.py'))['check']


class Versions(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='transit-version-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.git('init', '-q')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'user.name', 'Version fixture')
        self.write('VERSION', '0.0.1\n')
        self.write('package.json', '{"name":"@transit/client","version":"0.0.1",'
                   '"dependencies":{"external":"9.2.1","@transit/native":"workspace:0.0.1"}}')
        self.git('add', '.')
        self.git('commit', '-qm', 'test(release): create fixture')

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.root, stderr=subprocess.PIPE)

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def test_manifest_and_owned_pin(self):
        self.assertEqual(check(self.root), ('0.0.1', 2))
        self.write('package.json', '{"name":"@transit/client","version":"0.0.2"}')
        with self.assertRaisesRegex(ValueError, 'package.json: expected 0.0.1, found 0.0.2'):
            check(self.root)

    def test_dependency_drift(self):
        path = self.root / 'package.json'
        path.write_text(path.read_text().replace('workspace:0.0.1', 'workspace:0.1.0'))
        with self.assertRaisesRegex(ValueError, 'found 0.1.0'):
            check(self.root)

    def test_invalid_version(self):
        for version in ('01.0.1', 'v0.0.1', '0.0.1-dev', '0.0'):
            self.write('VERSION', version)
            with self.assertRaisesRegex(ValueError, 'VERSION must be'):
                check(self.root)

    def test_tag_and_clean_source(self):
        self.git('tag', '-a', 'v0.0.1', '-m', 'release fixture')
        self.assertEqual(check(self.root, 'v0.0.1')[0], '0.0.1')
        with self.assertRaisesRegex(ValueError, 'release tag must be'):
            check(self.root, 'v0.0.2')
        self.write('untracked', 'dirty')
        with self.assertRaisesRegex(ValueError, 'clean checkout'):
            check(self.root, 'v0.0.1')
        self.git('add', '.')
        self.git('commit', '-qm', 'test(release): move past tag')
        with self.assertRaisesRegex(ValueError, 'does not identify HEAD'):
            check(self.root, 'v0.0.1')

    def test_chart_and_lock_drift(self):
        self.write('charts/transit/Chart.yaml', 'version: 0.0.1\nappVersion: "0.0.2"\n')
        self.write('Cargo.lock', 'version = 4\n[[package]]\nname = "external"\nversion = "9.0.0"\n'
                   '[[package]]\nname = "transit-client"\nversion = "0.0.2"\n')
        self.git('add', '.')
        with self.assertRaises(ValueError) as raised:
            check(self.root)
        self.assertIn('Chart.yaml', str(raised.exception))
        self.assertIn('Cargo.lock', str(raised.exception))


if __name__ == '__main__':
    unittest.main()

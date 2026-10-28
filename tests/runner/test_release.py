"""Installer rejection and deterministic archive controls without network or services."""
import hashlib
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
archive = runpy.run_path(str(ROOT / 'tasks/package_release.py'))['archive']


class Distribution(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='transit-installer-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.tools = self.root / 'tools'
        self.tools.mkdir()
        self.downloads = self.root / 'downloads'
        self.downloads.mkdir()
        self.prefix = self.root / 'prefix with spaces'
        self.source = self.root / 'source'
        (self.source / 'bin').mkdir(parents=True)
        binary = self.source / 'bin/transit'
        binary.write_text('#!/bin/sh\nprintf "%s\\n" "Transit 0.0.1 (git ' + 'a' * 40 + '; CLI contract 1)"\n')
        binary.chmod(0o755)
        (self.tools / 'curl').write_text('''#!/bin/sh
set -eu
output=
for arg do
  if [ "$output" = next ]; then output=$arg; continue; fi
  if [ "$arg" = --output ]; then output=next; fi
  url=$arg
done
cp "$FIXTURE_DOWNLOADS/${url##*/}" "$output"
''')
        (self.tools / 'curl').chmod(0o755)
        self.env = os.environ | {'PATH': str(self.tools) + ':' + os.environ['PATH'],
                                 'FIXTURE_DOWNLOADS': str(self.downloads)}
        self.asset = self.downloads / 'transit-0.0.1-linux-x86_64.tar.gz'
        archive(self.source, self.asset, 'transit-0.0.1-linux-x86_64', 123)
        self.checksum()

    def checksum(self):
        digest = hashlib.sha256(self.asset.read_bytes()).hexdigest()
        (self.downloads / 'SHA256SUMS').write_text(f'{digest}  {self.asset.name}\n')

    def install(self):
        return subprocess.run(['sh', str(ROOT / 'install.sh'), '--version', '0.0.1',
                               '--prefix', str(self.prefix)], env=self.env, capture_output=True, text=True)

    def test_verified_install_and_existing_version(self):
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.prefix / 'bin/transit').is_symlink())
        self.assertIn('Transit 0.0.1', subprocess.check_output([str(self.prefix / 'bin/transit')], text=True))
        self.assertNotEqual(self.install().returncode, 0)

    def test_offline_install_uses_the_same_checksum_gate(self):
        args = ['sh', str(ROOT / 'install.sh'), '--version', '0.0.1',
                '--prefix', str(self.prefix), '--from', str(self.downloads)]
        result = subprocess.run(args, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.prefix / 'bin/transit').is_symlink())
        self.asset.write_bytes(b'corrupt')
        rejected = subprocess.run(args, env=self.env, capture_output=True, text=True)
        self.assertIn('checksum mismatch', rejected.stderr)
        self.assertTrue((self.prefix / 'bin/transit').is_symlink())

    def test_corruption_never_changes_existing_binary(self):
        (self.prefix / 'bin').mkdir(parents=True)
        binary = self.prefix / 'bin/transit'
        binary.write_text('keep me')
        self.asset.write_bytes(self.asset.read_bytes() + b'corruption')
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('checksum mismatch', result.stderr)
        self.assertEqual(binary.read_text(), 'keep me')

    def test_unrelated_binary_is_preserved(self):
        (self.prefix / 'bin').mkdir(parents=True)
        binary = self.prefix / 'bin/transit'
        binary.write_text('keep me')
        self.assertIn('refusing to replace', self.install().stderr)
        self.assertEqual(binary.read_text(), 'keep me')

    def test_missing_checksum_and_archive_traversal(self):
        (self.downloads / 'SHA256SUMS').write_text('')
        self.assertIn('missing or duplicate', self.install().stderr)
        archive(self.source, self.asset, '../escape', 123)
        self.checksum()
        self.assertIn('unsafe archive path', self.install().stderr)
        self.assertFalse((self.root / 'escape').exists())

    def test_unsupported_platform(self):
        (self.tools / 'uname').write_text('#!/bin/sh\necho Darwin\n')
        (self.tools / 'uname').chmod(0o755)
        self.assertIn('Linux x86_64', self.install().stderr)
        self.assertFalse(self.prefix.exists())

    def test_archive_reproducibility_ignores_checkout_mtimes(self):
        original = self.asset.read_bytes()
        os.utime(self.source / 'bin/transit', (456, 456))
        archive(self.source, self.asset, 'transit-0.0.1-linux-x86_64', 123)
        self.assertEqual(original, self.asset.read_bytes())


if __name__ == '__main__':
    unittest.main()

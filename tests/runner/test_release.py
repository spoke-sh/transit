"""Installer rejection and deterministic archive controls without network or services."""
import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tarfile
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
packaging = runpy.run_path(str(ROOT / 'tasks/package_release.py'))
archive = packaging['archive']


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
        # The controls exercise archive selection independently of their host.
        (self.tools / 'uname').write_text('#!/bin/sh\ncase "$1" in -s) echo Linux;; -m) echo x86_64;; esac\n')
        (self.tools / 'uname').chmod(0o755)
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

    def test_retired_links_are_removed_but_old_bundle_is_retained(self):
        previous = self.prefix / 'lib/transit/0.0.0/bin'
        previous.mkdir(parents=True)
        directory = self.prefix / 'bin'
        directory.mkdir()
        for name in ('transit-admin', 'transit-delivery'):
            (previous / name).write_text('original executable')
            (directory / name).symlink_to(previous / name)
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        for name in ('transit-admin', 'transit-delivery'):
            self.assertFalse((directory / name).is_symlink())
            self.assertEqual((previous / name).read_text(), 'original executable')

    def test_unrelated_retired_entries_are_preserved(self):
        directory = self.prefix / 'bin'
        directory.mkdir(parents=True)
        for name in ('transit-admin', 'transit-delivery'):
            (directory / name).symlink_to('/unrelated/' + name)
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        for name in ('transit-admin', 'transit-delivery'):
            self.assertEqual(os.readlink(directory / name), '/unrelated/' + name)

    def test_failed_install_preserves_retired_links(self):
        directory = self.prefix / 'bin'
        directory.mkdir(parents=True)
        previous = self.prefix / 'lib/transit/0.0.0/bin'
        for name in ('transit-admin', 'transit-delivery'):
            (directory / name).symlink_to(previous / name)
        self.asset.write_bytes(b'corrupt')
        self.assertNotEqual(self.install().returncode, 0)
        for name in ('transit-admin', 'transit-delivery'):
            self.assertEqual(os.readlink(directory / name), str(previous / name))

    def test_unrelated_retired_regular_files_are_preserved(self):
        directory = self.prefix / 'bin'
        directory.mkdir(parents=True)
        for name in ('transit-admin', 'transit-delivery'):
            (directory / name).write_text('user-owned executable')
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        for name in ('transit-admin', 'transit-delivery'):
            self.assertEqual((directory / name).read_text(), 'user-owned executable')

    def test_installing_original_bundle_keeps_its_delivery_command(self):
        delivery = self.source / 'bin/transit-delivery'
        delivery.write_text('original delivery executable')
        delivery.chmod(0o755)
        archive(self.source, self.asset, 'transit-0.0.1-linux-x86_64', 123)
        self.checksum()
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.prefix / 'bin/transit-delivery').is_symlink())
        self.assertEqual((self.prefix / 'bin/transit-delivery').read_text(), 'original delivery executable')

    def test_package_omits_retired_binaries_from_both_architecture_inventories(self):
        expected = {'transit', 'transit-node', 'transit-query-host', 'transit-board',
                    'transit-station-controller'}
        for name in expected | {'transit-admin', 'transit-delivery'}:
            (self.source / 'bin' / name).write_text('fixture executable')
        notices = self.source / 'share/transit/notices'
        notices.mkdir(parents=True)
        (notices / 'LICENSE').write_text('fixture notice')

        def output(args, **kwargs):
            if args[0] == 'git':
                return {'rev-parse': 'a' * 40 + '\n', 'status': b'', 'show': b'123\n'}[args[1]]
            if args[0] == 'readelf':
                return ''
            self.assertEqual(args, [str(self.source / 'bin/transit'), '--version'])
            return 'Transit 0.0.1 (git ' + 'a' * 40 + '; CLI contract 1)\n'

        def helm(args, **kwargs):
            self.assertEqual(args[:2], ['helm', 'package'])
            directory = Path(args[-1])
            chart = directory / 'chart-source'
            chart.mkdir()
            (chart / 'Chart.yaml').write_text('name: transit\nversion: 0.0.1\n')
            archive(chart, directory / 'transit-0.0.1.tgz', 'transit', 123)

        for architecture in ('x86_64', 'aarch64'):
            with self.subTest(architecture=architecture), \
                 patch.dict(sys.modules, release_identity=SimpleNamespace(current=lambda: {'release': '0.0.1'})), \
                 patch('platform.system', return_value='Linux'), \
                 patch('platform.machine', return_value=architecture), \
                 patch('subprocess.check_output', side_effect=output), \
                 patch('subprocess.run', side_effect=helm):
                destination = self.root / architecture
                packaging['package'](self.source, destination)
                manifest = json.loads((destination / 'release-manifest.json').read_text())
                self.assertEqual(set(manifest['binaries']), expected)
                name = f'transit-0.0.1-linux-{architecture}'
                with tarfile.open(destination / (name + '.tar.gz')) as bundle:
                    binaries = {Path(member.name).name for member in bundle if '/bin/' in member.name}
                    self.assertEqual(binaries, expected)
                    embedded = json.load(bundle.extractfile(name + '/build-info.json'))
                    self.assertEqual(embedded['binaries'], manifest['binaries'])

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

    def test_arm64_selects_its_own_archive(self):
        (self.tools / 'uname').write_text('#!/bin/sh\ncase "$1" in -s) echo Linux;; -m) echo aarch64;; esac\n')
        self.asset = self.downloads / 'transit-0.0.1-linux-aarch64.tar.gz'
        archive(self.source, self.asset, 'transit-0.0.1-linux-aarch64', 123)
        self.checksum()
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_nightly_channel_installs_the_pinned_version(self):
        version = '0.0.1-nightly.20261029.gaaaaaaaaaaaa'
        binary = self.source / 'bin/transit'
        binary.write_text(binary.read_text().replace('Transit 0.0.1 ', 'Transit ' + version + ' '))
        self.asset = self.downloads / f'transit-{version}-linux-x86_64.tar.gz'
        archive(self.source, self.asset, f'transit-{version}-linux-x86_64', 123)
        self.checksum()
        descriptor = dict(identity=dict(release=version), checksums_sha256=hashlib.sha256(
            (self.downloads / 'SHA256SUMS').read_bytes()).hexdigest())
        (self.downloads / 'nightly.json').write_text(json.dumps(descriptor, indent=2))
        args = ['sh', str(ROOT / 'install.sh'), '--channel', 'nightly', '--prefix', str(self.prefix)]
        result = subprocess.run(args, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(version, str((self.prefix / 'bin/transit').resolve()))
        before = (self.prefix / 'bin/transit').read_bytes()
        (self.downloads / 'SHA256SUMS').write_text('changed')
        result = subprocess.run(args, env=self.env, capture_output=True, text=True)
        self.assertIn('nightly channel checksum mismatch', result.stderr)
        self.assertEqual((self.prefix / 'bin/transit').read_bytes(), before)

    def test_channel_and_version_are_explicit_alternatives(self):
        result = subprocess.run(['sh', str(ROOT / 'install.sh'), '--channel', 'nightly',
                                 '--version', '0.0.1'], env=self.env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('mutually exclusive', result.stderr)

    def test_archive_reproducibility_ignores_checkout_mtimes(self):
        original = self.asset.read_bytes()
        os.utime(self.source / 'bin/transit', (456, 456))
        archive(self.source, self.asset, 'transit-0.0.1-linux-x86_64', 123)
        self.assertEqual(original, self.asset.read_bytes())


if __name__ == '__main__':
    unittest.main()

"""Release assembly refuses foreign definitions and altered SDK archives."""
import json
import hashlib
from pathlib import Path
import runpy
import sys
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tasks'))
try:
    assemble = runpy.run_path(str(ROOT / 'tasks/assemble_release.py'))['assemble']
    package = runpy.run_path(str(ROOT / 'tasks/package_sdks.py'))['package']
    describe = runpy.run_path(str(ROOT / 'tasks/release_identity.py'))['describe']
finally:
    sys.path.pop(0)


class SdkRelease(unittest.TestCase):
    def test_zig_source_archive_is_identical_across_native_runners(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / 'source'
            (source / 'sdks/zig').mkdir(parents=True)
            (source / 'VERSION').write_text('0.0.1\n')
            (source / 'sdks/zig/build.zig.zon').write_text('.{ .version = "0.0.1" }\n')
            (source / 'third_party/vendor').mkdir(parents=True)
            (source / 'third_party/vendor/build.zig.zon').write_text('.{ .version = "0.0.1" }\n')
            for args in (['init', '-q'], ['add', '.'], ['-c', 'user.name=Fixture',
                         '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgSign=false',
                         'commit', '-qm', 'test(release): source fixture']):
                subprocess.run(['git', *args], cwd=source, check=True)
            revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=source, text=True).strip()
            epoch = int(subprocess.check_output(['git', 'show', '-s', '--format=%ct', 'HEAD'], cwd=source))
            identity = describe('0.0.1', revision, epoch, 'nightly', '20261029')
            notices = root / 'notices'
            notices.mkdir()
            (notices / 'LICENSE').write_text('Fixture notice\n')
            archives = []
            for arch in ('x86_64', 'aarch64'):
                inputs, output = root / arch, root / (arch + '-out')
                inputs.mkdir()
                artifact = inputs / 'native.bin'
                artifact.write_text(arch)
                manifest = dict(version=1, release=identity['release'], source_revision=revision,
                                identity=identity, definition=[1] * 32, compiler='pinned-zig',
                                target=arch + '-linux-gnu.2.28', native_build={'prefix': str(inputs)},
                                packages={'c': {artifact.name: hashlib.sha256(artifact.read_bytes()).hexdigest()}})
                (inputs / 'sdk-manifest.json').write_text(json.dumps(manifest))
                with patch.dict(package.__globals__, {'ROOT': source, 'current': lambda: identity}):
                    package(inputs, output, notices)
                archive, = output.glob('transit-sdk-zig-*.tar.gz')
                archives.append(archive.read_bytes())
                with tarfile.open(archive) as bundle:
                    record, = [member for member in bundle if member.name.endswith('/sdk-manifest.json')]
                    self.assertNotIn('target', json.load(bundle.extractfile(record)))
                    prefix = archive.name.removesuffix('.tar.gz') + '/'
                    self.assertEqual(bundle.extractfile(prefix + 'VERSION').read().decode().strip(), identity['release'])
                    zon = bundle.extractfile(prefix + 'sdks/zig/build.zig.zon').read().decode()
                    self.assertEqual(zon, '.{ .version = "' + identity['package_versions']['zig'] + '" }\n')
                    self.assertEqual(bundle.extractfile(prefix + 'third_party/vendor/build.zig.zon').read(),
                                     b'.{ .version = "0.0.1" }\n')
            self.assertEqual(*archives)

    def test_mismatched_identity_does_not_mutate_runtime(self):
        for field in ('release', 'source_revision', 'definition'):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as temporary:
                runtime, sdk = (Path(temporary) / name for name in ('runtime', 'sdk'))
                runtime.mkdir()
                sdk.mkdir()
                identity = dict(release='0.0.1', source_revision='a' * 40, definition=[1] * 32, identity={'channel': 'stable'})
                before = json.dumps(identity)
                (runtime / 'release-manifest.json').write_text(before)
                (sdk / 'sdk-manifest.json').write_text(json.dumps(identity | {field: 'foreign'}))
                with self.assertRaisesRegex(ValueError, field + ' mismatch'):
                    assemble(runtime, sdk)
                self.assertEqual((runtime / 'release-manifest.json').read_text(), before)
                self.assertEqual(len(list(runtime.iterdir())), 1)

    def test_corrupted_archive_is_rejected_before_copy(self):
        with tempfile.TemporaryDirectory() as temporary:
            runtime, sdk = (Path(temporary) / name for name in ('runtime', 'sdk'))
            runtime.mkdir()
            sdk.mkdir()
            identity = dict(release='0.0.1', source_revision='a' * 40, definition=[1] * 32, identity={'channel': 'stable'})
            (runtime / 'release-manifest.json').write_text(json.dumps(identity))
            (sdk / 'sdk-manifest.json').write_text(json.dumps(identity | {
                'packages': dict.fromkeys(('python', 'node', 'rust', 'ruby', 'c', 'java', 'dotnet', 'beam', 'go')),
                'assets': {'sdk.tar.gz': '0' * 64}}))
            (sdk / 'sdk.tar.gz').write_bytes(b'corrupt')
            with self.assertRaisesRegex(ValueError, 'checksum/path mismatch'):
                assemble(runtime, sdk)
            self.assertEqual(len(list(runtime.iterdir())), 1)


if __name__ == '__main__':
    unittest.main()

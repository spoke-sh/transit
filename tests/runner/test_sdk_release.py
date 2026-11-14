"""Release assembly refuses foreign definitions and altered SDK archives."""
import json
import hashlib
import os
from pathlib import Path
import runpy
import struct
import sys
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
for directory in (ROOT / 'tasks', ROOT / 'bindings'):
    sys.path.insert(0, str(directory))
try:
    assemble = runpy.run_path(str(ROOT / 'tasks/assemble_release.py'))['assemble']
    package = runpy.run_path(str(ROOT / 'tasks/package_sdks.py'))['package']
    describe = runpy.run_path(str(ROOT / 'tasks/release_identity.py'))['describe']
    release_module = runpy.run_path(str(ROOT / 'bindings/release.py'))
    relocate = release_module['relocate']
    INTERPRETERS = release_module['INTERPRETERS']
finally:
    del sys.path[:2]


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

    def elf(self, path, *, load=True, dynamic=False, interpreter=None, needed=(), runpath=None):
        strings = bytearray(b'\x00')
        offsets = {}
        for item in (*needed, *( [runpath] if runpath else [] )):
            offsets[item] = len(strings)
            strings.extend(item.encode() + b'\x00')
        segment_kinds = ([1] if load else []) + ([2] if dynamic else []) + ([3] if interpreter else [])
        table_offset = 64 + 56 * len(segment_kinds)
        strtab_offset = table_offset
        payload = bytearray()
        segments = []
        if dynamic:
            payload.extend(strings)
            dyn_offset = table_offset + len(payload)
            entries = [(5, strtab_offset), (10, len(strings))]
            entries.extend((1, offsets[item]) for item in needed)
            if runpath:
                entries.append((29, offsets[runpath]))
            entries.append((0, 0))
            dyn_bytes = b''.join(struct.pack('<Qq', tag, value) for tag, value in entries)
            payload.extend(dyn_bytes)
            segments.append((2, dyn_offset, len(dyn_bytes)))
        if interpreter:
            interp_offset = table_offset + len(payload)
            interp_bytes = interpreter.encode() + b'\x00'
            payload.extend(interp_bytes)
            segments.append((3, interp_offset, len(interp_bytes)))
        total_size = table_offset + len(payload)
        if load:
            segments.insert(0, (1, 0, total_size))
        header = struct.pack('<16sHHIQQQIHHHHHH', b'\x7fELF\x02\x01\x01' + bytes(9),
                             3 if dynamic and not interpreter else 2, 62, 1, 0,
                             64 if segments else 0, 0, 0, 64, 56, len(segments), 0, 0, 0)
        phdrs = b''.join(struct.pack('<IIQQQQQQ', kind, 4, start, start, start, length, length, 8)
                         for kind, start, length in segments)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(header + phdrs + payload)

    def test_relocate_patches_dynamic_artifacts_and_preserves_static_fixtures(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            tools = root / 'tools'
            tools.mkdir()
            calls = root / 'patchelf.jsonl'
            patchelf = tools / 'patchelf'
            patchelf.write_text(
                f'#!{sys.executable}\n'
                'import json, struct, sys\n'
                'from pathlib import Path\n'
                'assert sys.argv[1] == "--set-rpath"\n'
                'target = Path(sys.argv[3])\n'
                'data = target.read_bytes()\n'
                'phoff, _, _, _, phentsize, phnum = struct.unpack_from("<QQIHHH", data, 32)\n'
                'kinds = {struct.unpack_from("<I", data, phoff + i * phentsize)[0] for i in range(phnum)}\n'
                'if 2 not in kinds:\n'
                '    sys.stderr.write("patchelf: cannot find section \'.dynamic\'.\\n")\n'
                '    sys.exit(1)\n'
                f'with Path({str(calls)!r}).open("a") as handle:\n'
                '    handle.write(json.dumps([sys.argv[2], target.name]) + "\\n")\n'
            )
            patchelf.chmod(0o700)
            source = root / 'source'
            interpreter = INTERPRETERS['x86_64']
            self.elf(source / 'lib/libtransit_client.so', dynamic=True, needed=('libc.so.6',))
            self.elf(source / 'bin/transit-station-host', dynamic=True, interpreter=interpreter,
                     needed=('libtransit_client.so', 'libc.so.6'))
            self.elf(source / 'tests/native-client-fixture')
            (source / 'lib/libtransit_sdk_examples_c.a').write_bytes(b'!<arch>\n')
            static_before = (source / 'tests/native-client-fixture').read_bytes()
            artifacts = ['lib/libtransit_client.so', 'lib/libtransit_sdk_examples_c.a',
                         'bin/transit-station-host', 'tests/native-client-fixture']
            (source / 'build.json').write_text(json.dumps({
                'optimize': 'safe',
                'target': 'x86_64-linux-gnu.2.28',
                'artifacts': artifacts,
            }))
            env = os.environ | {'PATH': f'{tools}:{os.environ["PATH"]}'}
            with patch.dict(relocate.__globals__, {'ARCHITECTURE': 'x86_64'}), patch.dict(os.environ, env, clear=True):
                relocate(source, root / 'portable')
            recorded = [json.loads(line) for line in calls.read_text().splitlines()]
            self.assertEqual(recorded, [
                ['$ORIGIN', 'libtransit_client.so'],
                ['$ORIGIN/../lib', 'transit-station-host'],
            ])
            self.assertEqual((root / 'portable/tests/native-client-fixture').read_bytes(), static_before)

            cases = [
                ('no-load', {'load': False}, 'no loadable ELF segments'),
                ('interp-without-dynamic', {'interpreter': interpreter}, 'no dynamic section'),
                ('foreign-needed', {'dynamic': True, 'needed': ('libforeign.so.1',)}, 'undeclared native dependency'),
                ('nix-runpath', {'dynamic': True, 'runpath': '/nix/store/foreign/lib'}, 'nonportable loader or library search path'),
                ('foreign-interp', {'dynamic': True, 'interpreter': '/fixture/ld-linux.so'}, 'unexpected native interpreter'),
            ]
            for label, kwargs, expected in cases:
                with self.subTest(case=label):
                    bad = root / f'bad-{label}'
                    self.elf(bad / 'bin/broken', **kwargs)
                    (bad / 'build.json').write_text(json.dumps({
                        'optimize': 'safe',
                        'target': 'x86_64-linux-gnu.2.28',
                        'artifacts': ['bin/broken'],
                    }))
                    with patch.dict(relocate.__globals__, {'ARCHITECTURE': 'x86_64'}), patch.dict(os.environ, env, clear=True):
                        with self.assertRaisesRegex(ValueError, expected):
                            relocate(bad, root / f'out-{label}')


if __name__ == '__main__':
    unittest.main()

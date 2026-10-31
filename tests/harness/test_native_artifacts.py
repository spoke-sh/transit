"""Mismatched or incomplete native output cannot become a qualified fixture set."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import tarfile
import io
import unittest
from unittest.mock import patch

from harness.native_artifacts import CONTRACTS, EXPECTED, describe, prepare, validate, source_identity, publication, unpack
from runner.paths import ROOT


class Artifacts(unittest.TestCase):
    def fixture(self, root, family='authority'):
        prefix = root / 'outputs'
        prefix.mkdir()
        for name in EXPECTED[family] | CONTRACTS:
            path = prefix / name
            path.parent.mkdir(exist_ok=True)
            path.write_text(json.dumps({'definition': 'ab' * 32}) if name in CONTRACTS else 'original binary')
        (prefix / 'build.json').write_text(json.dumps(dict(
            version=1, set=family, optimize='debug', target='x86_64-linux-gnu',
            cpu='native', resolved_cpu='x86_64', compiler='fixture', runtime_library_path='/fixture/lib', artifacts=sorted(EXPECTED[family]))))
        return prefix

    def test_c_packages_reject_mixed_profiles_and_changed_definitions(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for family in ('clients', 'c-sdk'):
                (root / family).mkdir()
                self.fixture(root / family, family)
            native, sdk = (root / family / 'outputs' for family in ('clients', 'c-sdk'))
            metadata = sdk / 'build.json'
            original = metadata.read_text()
            for change, expected in [('profile', 'build input: optimize'), ('definition', 'contract definition')]:
                with self.subTest(change=change):
                    if change == 'profile':
                        metadata.write_text(original.replace('"debug"', '"safe"'))
                    else:
                        metadata.write_text(original)
                        (sdk / 'contracts/client.json').write_text('{"definition":"foreign"}')
                    result = subprocess.run([sys.executable, str(ROOT / 'bindings/build_c.py'),
                        str(root / 'packages'), '--native-prefix', str(native), '--sdk-prefix', str(sdk)],
                        capture_output=True, text=True)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(expected, result.stderr)
                    self.assertEqual(list((root / 'packages').iterdir()), [])

    def test_c_artifact_identity_includes_sdk_and_example_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '--quiet', root], check=True)
            common = root / 'build.zig'
            common.write_text('// native graph')
            baseline = source_identity(root, 'c-sdk')
            native = source_identity(root, 'clients')
            for name in ('bindings/build.zig', 'sdks/c/transit-client/src/client.cpp',
                         'sdks/cpp/transit-client/include/client.hpp', 'examples/station-sdk/c/src/main.c'):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('// changed source')
                self.assertNotEqual(source_identity(root, 'c-sdk'), baseline)
                self.assertEqual(source_identity(root, 'clients'), native)
                path.unlink()

    def test_source_profile_definition_and_changed_output_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            prefix = self.fixture(root)
            record = describe(prefix) | {'source_sha256': 'source-a'}
            arguments = dict(source='source-a', optimize='Debug', family='authority', definition='ab' * 32)
            self.assertEqual(validate(record, **arguments), prefix)
            for changes, reason in [({'source': 'source-b'}, 'source changed'),
                                    ({'optimize': 'ReleaseSafe'}, 'optimization profile'),
                                    ({'family': 'clients'}, 'artifact family'),
                                    ({'definition': 'cd' * 32}, 'contract definition')]:
                with self.subTest(changes=changes), self.assertRaisesRegex(AssertionError, reason):
                    validate(record, **(arguments | changes))
            executable = prefix / 'bin/transit-node'
            original = executable.read_bytes()
            executable.write_bytes(b'replaced binary')
            with self.assertRaisesRegex(AssertionError, 'artifacts changed'):
                validate(record, **arguments)
            executable.write_bytes(original)
            executable.unlink()
            with self.assertRaises(FileNotFoundError):
                validate(record, **arguments)
            executable.write_bytes(original)
            (prefix / 'contracts/station.json').write_text(json.dumps({'definition': 'cd' * 32}))
            with self.assertRaisesRegex(AssertionError, 'Mixed native definitions'):
                validate(record, **arguments)

    def test_portable_import_checks_every_identity_and_never_builds(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '--quiet', root], check=True)
            abi = root / 'packages/zig/transit-client/abi-v1.json'
            abi.parent.mkdir(parents=True)
            abi.write_text(json.dumps({'definition': 'ab' * 32}))
            prefix = self.fixture(root)
            prefix.rename(root / 'authority-Debug')
            prefix = root / 'authority-Debug'
            metadata = prefix / 'build.json'
            metadata.write_text(metadata.read_text().replace('"native"', '"baseline"').replace('x86_64-linux-gnu', 'x86_64-linux.5.10...7.2-gnu.2.42'))
            record = describe(prefix) | {'source_sha256': source_identity(root, 'authority'),
                                         'command': ['-Ddynamic-linker=/fixture/loader']}
            (prefix / 'record.json').write_text(json.dumps(record))
            compiler = root / 'zig'
            compiler.write_text(f'#!{sys.executable}\nimport sys\nassert sys.argv[1:] == ["version"]\nprint("fixture")\n')
            compiler.chmod(0o700)
            with patch.dict(os.environ, {'PATH': str(root) + os.pathsep + os.environ['PATH'],
                                         'CI_NATIVE_BUNDLE_DIR': str(root)}), \
                    patch('harness.native_artifacts.portable_target', return_value='x86_64-linux.5.10-gnu.2.42'), \
                    patch('harness.native_artifacts.nix_linker', return_value=('/fixture/loader', '2.42')), \
                    patch('harness.native_artifacts.runtime_library_path', return_value='/fixture/lib'):
                actual, invocation = prepare('authority', 'Debug', root)
                self.assertEqual(actual, prefix)
                self.assertEqual(json.loads(invocation.read_text())['preparation'], 'import')
                for field, value, message in [('cpu', 'native', 'portable CPU'),
                        ('compiler', 'another-compiler', 'compiler'),
                        ('runtime_library_path', '/foreign/lib', 'runtime libraries'),
                        ('target', 'aarch64-linux-gnu', 'target')]:
                    changed = record | {'build': record['build'] | {field: value}}
                    (prefix / 'record.json').write_text(json.dumps(changed))
                    with self.subTest(field=field), self.assertRaisesRegex(AssertionError, message):
                        prepare('authority', 'Debug', root)
                (prefix / 'record.json').write_text(json.dumps(record | {'command': ['-Ddynamic-linker=/foreign']}))
                with self.assertRaisesRegex(AssertionError, 'loader'):
                    prepare('authority', 'Debug', root)
                (prefix / 'record.json').write_text(json.dumps(record))
                (prefix / 'bin/transit-node').write_text('corrupt binary')
                with self.assertRaisesRegex(AssertionError, 'artifacts changed'):
                    prepare('authority', 'Debug', root)
                with self.assertRaises(FileNotFoundError):
                    prepare('authority', 'ReleaseSafe', root)

    def test_unpack_preserves_executables_and_rejects_unsafe_or_replaced_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ('authority-Debug/bin/node', '../escape', '/absolute', 'authority-Debug/../../escape'):
                archive = root / 'test.tar.gz'
                with tarfile.open(archive, 'w:gz') as stream:
                    member = tarfile.TarInfo(name)
                    member.size, member.mode = 2, 0o755
                    stream.addfile(member, io.BytesIO(b'ok'))
                if name == 'authority-Debug/bin/node':
                    unpack(archive, root / 'installed')
                    self.assertTrue(os.access(root / 'installed' / name, os.X_OK))
                    with self.assertRaisesRegex(AssertionError, 'already installed'):
                        unpack(archive, root / 'installed')
                else:
                    with self.assertRaises(AssertionError):
                        unpack(archive, root / 'installed')
            with tarfile.open(archive, 'w:gz') as stream:
                member = tarfile.TarInfo('authority-Debug/link')
                member.type, member.linkname = tarfile.SYMTYPE, '/etc/passwd'
                stream.addfile(member)
            with self.assertRaisesRegex(AssertionError, 'Unsafe'):
                unpack(archive, root / 'installed')

    def test_failed_or_partial_build_never_publishes_a_record(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            prefix = self.fixture(root)
            subprocess.run(['git', 'init', '--quiet', root], check=True)
            source = root / 'packages/zig/transit-client/abi-v1.json'
            source.parent.mkdir(parents=True)
            source.write_text(json.dumps({'definition': 'ab' * 32}))
            compiler = root / 'zig'
            record = describe(prefix)
            scripts = [
                "import sys\nsys.exit(23)\n",
                "import os, signal\nos.kill(os.getpid(), signal.SIGTERM)\n",
                # A build that prints plausible output without its complete
                # files still cannot qualify. stdout alone is not publication.
                f"from pathlib import Path\nPath({str(prefix / 'bin/transit-node')!r}).unlink()\nprint({json.dumps(record)!r})\n",
            ]
            with patch.dict(os.environ, {'PATH': str(root) + os.pathsep + os.environ['PATH']}):
                failures = (subprocess.CalledProcessError, subprocess.CalledProcessError, FileNotFoundError)
                for script, failure in zip(scripts, failures, strict=True):
                    compiler.write_text(f'#!{sys.executable}\n' + script)
                    compiler.chmod(0o700)
                    with self.assertRaises(failure):
                        prepare('authority', 'Debug', root)
                    self.assertFalse((root / '.cache/native-artifacts').exists())

    def test_source_changes_during_a_successful_build_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            prefix = self.fixture(root)
            subprocess.run(['git', 'init', '--quiet', root], check=True)
            source = root / 'packages/zig/transit-client/abi-v1.json'
            source.parent.mkdir(parents=True)
            source.write_text(json.dumps({'definition': 'ab' * 32}))
            compiler = root / 'zig'
            record = describe(prefix)
            compiler.write_text(f'#!{sys.executable}\nfrom pathlib import Path\n'
                                f'Path({str(source)!r}).write_text("changed source")\n'
                                f'print({json.dumps(record)!r})\n')
            compiler.chmod(0o700)
            with patch.dict(os.environ, {'PATH': str(root) + os.pathsep + os.environ['PATH']}):
                with self.assertRaisesRegex(AssertionError, 'inputs changed during compilation'):
                    prepare('authority', 'Debug', root)
            self.assertFalse((root / '.cache/native-artifacts').exists())


if __name__ == '__main__':
    unittest.main()

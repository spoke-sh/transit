"""Mismatched or incomplete native output cannot become a qualified fixture set."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from harness.native_artifacts import CONTRACTS, EXPECTED, describe, prepare, validate


class Artifacts(unittest.TestCase):
    def fixture(self, root):
        prefix = root / 'outputs'
        prefix.mkdir()
        for name in EXPECTED['authority'] | CONTRACTS:
            path = prefix / name
            path.parent.mkdir(exist_ok=True)
            path.write_text(json.dumps({'definition': 'ab' * 32}) if name in CONTRACTS else 'original binary')
        (prefix / 'build.json').write_text(json.dumps(dict(
            version=1, set='authority', optimize='debug', target='x86_64-linux-gnu',
            cpu='native', resolved_cpu='x86_64', compiler='fixture', artifacts=['bin/transit-node'])))
        return prefix

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

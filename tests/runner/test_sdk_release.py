"""Release assembly refuses foreign definitions and altered SDK archives."""
import json
from pathlib import Path
import runpy
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tasks'))
try:
    assemble = runpy.run_path(str(ROOT / 'tasks/assemble_release.py'))['assemble']
finally:
    sys.path.pop(0)


class SdkRelease(unittest.TestCase):
    def test_mismatched_identity_does_not_mutate_runtime(self):
        for field in ('release', 'source_revision', 'definition'):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as temporary:
                runtime, sdk = (Path(temporary) / name for name in ('runtime', 'sdk'))
                runtime.mkdir()
                sdk.mkdir()
                identity = dict(release='0.0.1', source_revision='a' * 40, definition=[1] * 32)
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
            identity = dict(release='0.0.1', source_revision='a' * 40, definition=[1] * 32)
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

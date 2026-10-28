"""Publication refuses ambiguous registry state and altered local artifacts."""
import json
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tasks'))
try:
    publisher = runpy.run_path(str(ROOT / 'tasks/publish_release.py'))
finally:
    sys.path.pop(0)
registry_config = publisher['registry_config']
publish = publisher['publish']


class Publication(unittest.TestCase):
    def test_only_explicit_missing_manifest_allows_new_tag(self):
        for error in ('unauthorized', 'TLS handshake failed', 'too many requests'):
            with self.subTest(error=error), patch('subprocess.run', return_value=
                    subprocess.CompletedProcess([], 1, '', error)):
                with self.assertRaisesRegex(RuntimeError, error):
                    registry_config('ghcr.io/example/transit:0.0.1')
        with patch('subprocess.run', return_value=subprocess.CompletedProcess(
                [], 1, '', 'MANIFEST_UNKNOWN: manifest unknown')):
            self.assertIsNone(registry_config('ghcr.io/example/transit:0.0.1'))

    def test_corrupted_artifact_stops_before_registry_mutation(self):
        with tempfile.TemporaryDirectory(prefix='transit-publish-control-') as temporary:
            directory = Path(temporary)
            (directory / 'release-manifest.json').write_text(json.dumps({
                'release': '0.0.1', 'source_revision': 'a' * 40}))
            (directory / 'asset').write_text('changed bytes')
            (directory / 'SHA256SUMS').write_text('0' * 64 + '  asset\n')
            original_run = publish.__globals__['run']
            commands = []

            def run(args, **kwargs):
                commands.append(args[0])
                if args[0] == 'git':
                    return 'a' * 40
                return original_run(args, **kwargs)

            with patch.dict(publish.__globals__, {'check': lambda *_: None, 'run': run}):
                with self.assertRaises(subprocess.CalledProcessError):
                    publish(directory, 'example/transit')
            self.assertEqual(commands, ['git', 'sha256sum'])

    def test_conflicting_image_is_never_overwritten(self):
        with tempfile.TemporaryDirectory(prefix='transit-publish-control-') as temporary:
            directory = Path(temporary)
            names = publisher['BINARIES']
            (directory / 'images').mkdir()
            (directory / 'release-manifest.json').write_text(json.dumps({
                'release': '0.0.1', 'source_revision': 'a' * 40,
                'images': {name: 'sha256:expected' for name in names}}))
            for name in names:
                (directory / 'images' / f'{name}.tar').touch()
            commands = []

            def run(args, **kwargs):
                commands.append(args)
                if args[0] == 'git':
                    return 'a' * 40
                if args[:3] == ['docker', 'image', 'inspect']:
                    return 'sha256:expected'
                return ''

            with patch.dict(publish.__globals__, {
                    'check': lambda *_: None, 'run': run,
                    'registry_config': lambda _: {'config': {'digest': 'sha256:foreign'}}}):
                with self.assertRaisesRegex(ValueError, 'refusing to replace published image'):
                    publish(directory, 'example/transit')
            self.assertFalse(any(args[0] in ('skopeo', 'helm', 'gh') for args in commands))


if __name__ == '__main__':
    unittest.main()

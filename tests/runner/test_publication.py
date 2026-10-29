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
    identity = runpy.run_path(str(ROOT / 'tasks/release_identity.py'))['describe']('0.0.1', 'a' * 40, 123)
    publisher = runpy.run_path(str(ROOT / 'tasks/publish_release.py'))
    channel = runpy.run_path(str(ROOT / 'tasks/release_channel.py'))
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
                'release': '0.0.1', 'source_revision': 'a' * 40, 'identity': identity}))
            (directory / 'asset').write_text('changed bytes')
            (directory / 'SHA256SUMS').write_text('0' * 64 + '  asset\n')
            original_run = publish.__globals__['run']
            commands = []

            def run(args, **kwargs):
                commands.append(args[0])
                if args[0] == 'git':
                    return 'a' * 40
                return original_run(args, **kwargs)

            with patch.dict(publish.__globals__, {'check': lambda *_: None, 'current': lambda **_: identity, 'run': run}):
                with self.assertRaises(subprocess.CalledProcessError):
                    publish(directory, 'example/transit')
            self.assertEqual(commands, ['git', 'sha256sum'])

    def test_promotion_requires_descendant_source_and_exact_nightly_identity(self):
        describe = channel['describe']
        old = describe('0.0.1', 'a' * 40, 123, 'nightly', '20261028')
        candidate = describe('0.0.1', 'b' * 40, 124, 'nightly', '20261029')
        promote = channel['may_promote']
        self.assertTrue(promote(None, candidate))
        self.assertFalse(promote({'identity': old}, old))
        for code, allowed in ((0, True), (1, False)):
            with patch('subprocess.run', return_value=subprocess.CompletedProcess([], code)):
                self.assertEqual(promote({'identity': old}, candidate), allowed)
        with patch('subprocess.run', return_value=subprocess.CompletedProcess([], 128)):
            with self.assertRaisesRegex(RuntimeError, 'ancestry'):
                promote({'identity': old}, candidate)
        with self.assertRaisesRegex(ValueError, 'only a nightly'):
            promote(None, identity)

    def test_registry_failures_do_not_advance_the_channel(self):
        candidate = channel['describe']('0.0.1', 'a' * 40, 123, 'nightly', '20261029')
        promote = channel['promote']
        calls = []
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            (directory / 'release-manifest.json').write_text(json.dumps({
                'identity': candidate, 'images': {'transit': 'sha256:expected'}}))
            with patch.dict(promote.__globals__, {
                    'current': lambda **_: candidate, 'channel': lambda _: (None, None),
                    'api': lambda *args, **kwargs: calls.append(args)}):
                with patch('subprocess.run', side_effect=subprocess.CalledProcessError(1, ['skopeo'])):
                    with self.assertRaises(subprocess.CalledProcessError):
                        promote(directory, 'example/transit')
        self.assertEqual(calls, [])

    def test_conflicting_image_is_never_overwritten(self):
        with tempfile.TemporaryDirectory(prefix='transit-publish-control-') as temporary:
            directory = Path(temporary)
            names = publisher['BINARIES']
            (directory / 'images').mkdir()
            (directory / 'release-manifest.json').write_text(json.dumps({
                'release': '0.0.1', 'source_revision': 'a' * 40, 'identity': identity,
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
                    'check': lambda *_: None, 'current': lambda **_: identity, 'run': run,
                    'registry_config': lambda _: {'config': {'digest': 'sha256:foreign'}}}):
                with self.assertRaisesRegex(ValueError, 'refusing to replace published image'):
                    publish(directory, 'example/transit')
            self.assertFalse(any(args[0] in ('skopeo', 'helm', 'gh') for args in commands))


if __name__ == '__main__':
    unittest.main()

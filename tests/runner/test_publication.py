"""Publication refuses ambiguous registry state and altered local artifacts."""
import json
import hashlib
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
    oci = runpy.run_path(str(ROOT / 'tasks/release_oci.py'))
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
                'identity': candidate, 'images': {'transit': {'digest': 'sha256:' + 'a' * 64}}}))
            with patch.dict(promote.__globals__, {
                    'current': lambda **_: candidate, 'channel': lambda _: (None, None),
                    'api': lambda *args, **kwargs: calls.append(args)}):
                with patch('subprocess.run', side_effect=subprocess.CalledProcessError(1, ['skopeo'])):
                    with self.assertRaises(subprocess.CalledProcessError):
                        promote(directory, 'example/transit')
        self.assertEqual(calls, [])

    def test_native_image_assembly_validates_both_architectures_and_blobs(self):
        def image(directory, arch):
            directory.mkdir(parents=True)
            blobs = directory / 'blobs/sha256'
            blobs.mkdir(parents=True)
            def put(value, media):
                data = json.dumps(value).encode()
                digest = hashlib.sha256(data).hexdigest()
                (blobs / digest).write_bytes(data)
                return dict(mediaType=media, digest='sha256:' + digest, size=len(data))
            config = put(dict(os='linux', architecture=arch), 'application/vnd.oci.image.config.v1+json')
            manifest = put(dict(schemaVersion=2, config=config, layers=[]), oci['IMAGE'])
            (directory / 'index.json').write_text(json.dumps(dict(schemaVersion=2, manifests=[manifest])))
            (directory / 'oci-layout').write_text('{"imageLayoutVersion":"1.0.0"}')
            return dict(config=config['digest'], manifest=manifest)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            x86, arm = root / 'x86', root / 'arm'
            first = {'transit': image(x86 / 'transit', 'amd64')}
            second = {'transit': image(arm / 'transit', 'arm64')}
            before = (x86 / 'transit/index.json').read_bytes()
            with self.assertRaisesRegex(ValueError, 'incomplete'):
                oci['combine'](x86, arm, first, {}, '0.0.1')
            config = arm / 'transit/blobs/sha256' / second['transit']['config'][7:]
            original = config.read_bytes()
            config.write_bytes(b'corrupt')
            with self.assertRaisesRegex(ValueError, 'checksum/size'):
                oci['combine'](x86, arm, first, second, '0.0.1')
            self.assertEqual((x86 / 'transit/index.json').read_bytes(), before)
            config.write_bytes(original)
            result = oci['combine'](x86, arm, first, second, '0.0.1')
            self.assertEqual(set(result['transit']['platforms']), {'linux/amd64', 'linux/arm64'})
            index = x86 / 'transit/blobs/sha256' / result['transit']['digest'][7:]
            manifests = json.loads(index.read_bytes())['manifests']
            self.assertEqual([d['platform']['architecture'] for d in manifests], ['amd64', 'arm64'])
            for descriptor in manifests:
                self.assertTrue((x86 / 'transit/blobs/sha256' / descriptor['digest'][7:]).is_file())

    def test_conflicting_image_is_never_overwritten(self):
        with tempfile.TemporaryDirectory(prefix='transit-publish-control-') as temporary:
            directory = Path(temporary)
            names = publisher['BINARIES']
            data = b'{"schemaVersion":2,"manifests":[]}'
            digest = 'sha256:' + hashlib.sha256(data).hexdigest()
            (directory / 'release-manifest.json').write_text(json.dumps({
                'release': '0.0.1', 'source_revision': 'a' * 40, 'identity': identity,
                'images': {name: {'digest': digest} for name in names}}))
            for name in names:
                layout = directory / 'images' / name
                (layout / 'blobs/sha256').mkdir(parents=True)
                (layout / 'blobs/sha256' / digest[7:]).write_bytes(data)
                (layout / 'index.json').write_text(json.dumps({'manifests': [{'digest': digest, 'size': len(data)}]}))
            commands = []
            def run(args, **kwargs):
                commands.append(args)
                if args[0] == 'git':
                    return 'a' * 40
                if args[:3] == ['skopeo', 'inspect', '--raw']:
                    return data.decode()
                return ''
            with patch.dict(publish.__globals__, {
                    'check': lambda *_: None, 'current': lambda **_: identity, 'run': run,
                    'registry_raw': lambda _: b'foreign index'}):
                with self.assertRaisesRegex(ValueError, 'refusing to replace published image'):
                    publish(directory, 'example/transit')
            self.assertFalse(any(args[:2] == ['skopeo', 'copy'] or args[0] in ('helm', 'gh') for args in commands))


if __name__ == '__main__':
    unittest.main()

"""Nightly identities and isolated package pins preserve source and dependency identity."""
import json
import os
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
identity = runpy.run_path(str(ROOT / 'tasks/release_identity.py'))
metadata = runpy.run_path(str(ROOT / 'bindings/package_metadata.py'))
describe, validate, tag_for = (identity[name] for name in ('describe', 'validate', 'tag_for'))
rewrite = metadata['rewrite']


class ReleaseIdentity(unittest.TestCase):
    def setUp(self):
        self.identity = describe('0.0.1', 'a' * 40, 123, 'nightly', '20261029')

    def test_exact_identity_and_ecosystem_versions(self):
        self.assertEqual(self.identity['release'], '0.0.1-nightly.20261029.gaaaaaaaaaaaa')
        self.assertEqual(self.identity['tag'], 'nightly-20261029-gaaaaaaaaaaaa')
        self.assertEqual(self.identity['package_versions']['python'], '0.0.1.dev20261029+gaaaaaaaaaaaa')
        self.assertEqual(self.identity['package_versions']['ruby'], '0.0.1.nightly.20261029.gaaaaaaaaaaaa')
        self.assertEqual(self.identity['package_versions']['zig'], '0.0.1-dev.gaaaaaaaaaaaa')
        self.assertLessEqual(len(self.identity['package_versions']['zig']), 32)
        self.assertEqual(tag_for(self.identity['release']), self.identity['tag'])
        self.assertEqual(tag_for('0.0.1'), 'v0.0.1')
        for version in ('0.0.1-nightly', '0.0.1-nightly.20260230.gaaaaaaaaaaaa', '../main', '01.0.1'):
            with self.subTest(version=version), self.assertRaises(ValueError):
                tag_for(version)

    def test_zig_version_bound_is_checked_before_building(self):
        with self.assertRaisesRegex(ValueError, 'Zig package version exceeds 32 bytes'):
            describe('123456789012345.0.0', 'a' * 40, 123, 'nightly', '20261029')

    def test_manifest_cannot_relabel_foreign_source_or_language_version(self):
        for field, value in (('release', '0.0.2'), ('tag', 'nightly'), ('source_revision', 'b' * 40)):
            with self.subTest(field=field), self.assertRaises(ValueError):
                validate(self.identity | {field: value})
        versions = self.identity['package_versions'] | {'python': '0.0.1'}
        with self.assertRaises(ValueError):
            validate(self.identity | {'package_versions': versions})

    def test_staged_pins_do_not_change_external_dependencies_or_addresses(self):
        with patch.dict(rewrite.__globals__, {'IDENTITY': self.identity}):
            result = rewrite(b'{"version":"0.0.1","dependencies":{"@transit/client":"workspace:0.0.1",'
                             b'"external":"0.0.1"}}', 'node', 'package.json')
            package = json.loads(result)
            self.assertEqual(package['version'], self.identity['release'])
            self.assertEqual(package['dependencies']['@transit/client'], 'workspace:' + self.identity['release'])
            self.assertEqual(package['dependencies']['external'], '0.0.1')
            text = rewrite(b'"0.0.1" http://127.0.0.1:123 Transit.Client.0.0.1.nupkg 0.0.10', 'dotnet').decode()
            self.assertIn('http://127.0.0.1:123', text)
            self.assertIn('Transit.Client.' + self.identity['release'] + '.nupkg', text)
            self.assertTrue(text.endswith('0.0.10'))
            lock = b'version = 4\n[[package]]\nname = "external"\nversion = "0.0.1"\n[[package]]\nname = "transit-client"\nversion = "0.0.1"\n'
            changed = rewrite(lock, 'rust', 'Cargo.lock').decode()
            self.assertIn('name = "external"\nversion = "0.0.1"', changed)
            self.assertIn('name = "transit-client"\nversion = "' + self.identity['release'] + '"', changed)

    def test_loaded_identity_must_match_the_checkout(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'VERSION').write_text('0.0.1\n')
            path = root / 'identity.json'
            path.write_text(json.dumps(self.identity))
            def git(*args, **kwargs):
                return 'b' * 40 if args[0] == 'rev-parse' else '123'
            with patch.dict(os.environ, {'TRANSIT_RELEASE_IDENTITY': str(path)}), patch.dict(
                    identity['current'].__globals__, {'git': git}):
                with self.assertRaisesRegex(ValueError, 'does not identify this checkout'):
                    identity['current'](root)


if __name__ == '__main__':
    unittest.main()

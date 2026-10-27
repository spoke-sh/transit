"""Moved helpers must fail discovery even when imported in a rarely run branch."""
import json
from pathlib import Path
import tempfile
import unittest

from imports import audit


class Imports(unittest.TestCase):
    def test_nested_missing_symbol_and_moved_module_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for owner in ('runner', 'harness', 'interfaces'):
                (root / 'tests' / owner).mkdir(parents=True)
            (root / 'tests/runner/layout.json').write_text(json.dumps({'owners': ['runner', 'harness', 'interfaces']}))
            helper = root / 'tests/harness/processes.py'
            helper.write_text('def joined(): pass\n')
            server = root / 'tests/interfaces/server.py'
            server.write_text('class Fixture: pass\n')
            consumer = root / 'tests/interfaces/fault.py'
            consumer.write_text('def rare_fault():\n    from interfaces.server import joined\n')
            with self.assertRaisesRegex(AssertionError, 'does not declare joined'):
                audit(root)
            consumer.write_text('def rare_fault():\n    from harness.processes import joined\n')
            result = audit(root)
            self.assertEqual(result['edges'][0]['module'], 'harness.processes')
            helper.rename(helper.with_name('renamed.py'))
            with self.assertRaisesRegex(AssertionError, 'missing local module harness.processes'):
                audit(root)

    def test_namespace_imports_reexports_and_runner_entry_points(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for owner in ('runner', 'harness'):
                (root / 'tests' / owner).mkdir(parents=True)
            (root / 'tests/runner/layout.json').write_text(json.dumps({'owners': ['runner', 'harness']}))
            (root / 'tests/harness/owner.py').write_text('def observe(): pass\n')
            (root / 'tests/harness/view.py').write_text('from .owner import observe\n')
            (root / 'tests/runner/shared.py').write_text('VALUE = 1\n')
            (root / 'tests/runner/main.py').write_text(
                'from harness import owner\nfrom harness.view import observe\n'
                'from shared import VALUE\nfrom external_package import opaque\n')
            edges = audit(root)['edges']
            self.assertEqual(len(edges), 4)
            self.assertIn('runner.shared', [row['module'] for row in edges])

    def test_unregistered_computed_import_is_not_assumed_safe(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'tests/runner').mkdir(parents=True)
            (root / 'tests/runner/layout.json').write_text('{"owners": ["runner"]}')
            (root / 'tests/runner/dynamic.py').write_text('import importlib\nimportlib.import_module(name)\n')
            with self.assertRaisesRegex(AssertionError, 'explicit consumer registration'):
                audit(root)


if __name__ == '__main__':
    unittest.main()

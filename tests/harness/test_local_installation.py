"""Exercise private installation files, frozen binaries and actual manager death."""
import json
import os
from pathlib import Path
import select
import sys
import tempfile
import unittest
from unittest.mock import patch

from harness.local_installation import LocalInstallation, freeze_executables
from interfaces.installation.server import Fixture


class Installations(unittest.TestCase):
    def binaries(self, root, body):
        cli = root / 'transit'
        cli.write_text(f'#!{sys.executable}\n' + body)
        cli.chmod(0o700)
        for name in ('transit-node', 'transit-query-host', 'transit-board', 'transit-sql-gateway'):
            (root / name).write_bytes(name.encode())
        environment = patch.dict(os.environ, {
            'TEST_TRANSIT_BOARD_BINARY': str(root / 'transit-board'),
            'TEST_TRANSIT_SQL_GATEWAY_BINARY': str(root / 'transit-sql-gateway'),
        })
        environment.start()
        self.addCleanup(environment.stop)
        return cli, root / 'transit-node', root / 'transit-query-host'

    def report(self, fixture):
        self.assertTrue(select.select([fixture.process.stdout], [], [], 5)[0])
        return json.loads(fixture.process.stdout.readline())

    def test_private_state_restart_and_frozen_executables(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binaries = self.binaries(root, '''import json, os, signal, sys, time
from pathlib import Path
signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
config = json.loads(Path(sys.argv[sys.argv.index('--config') + 1]).read_text())
print(json.dumps(dict(cwd=os.getcwd(), installation=config['installation'], args=sys.argv[1:])), flush=True)
while True: time.sleep(.1)
''')
            first, second = [LocalInstallation(*binaries, parent=root) for _ in range(2)]
            try:
                for fixture in (first, second):
                    freeze_executables(fixture)
                    fixture.path.write_text(json.dumps(fixture.config))
                    fixture.start()
                    observed = self.report(fixture)
                    self.assertEqual(observed['cwd'], str(fixture.root))
                    self.assertEqual(observed['installation'], str(fixture.installation))
                    self.assertIn('--no-ui', observed['args'])
                    fixture.installation.mkdir()
                self.assertNotEqual(first.root, second.root)
                (first.installation / 'private-state').write_text('owned')
                self.assertFalse((second.installation / 'private-state').exists())
                for original in root.glob('transit*'):
                    if original.is_file(): original.write_bytes(b'replaced workspace output')
                for fixture in (first, second):
                    for path in fixture.config['executables'].values():
                        path = Path(path)
                        self.assertEqual(path.read_bytes(), path.name.encode())
                first.stop(kill=True)
                self.assertIsNone(first.process)
                first.start()
                self.report(first)
                self.assertEqual((first.installation / 'private-state').read_text(), 'owned')
                first.stop()
                self.assertIsNone(first.process)
                self.assertIsNone(second.process.poll())
            finally:
                first.cleanup()
                second.cleanup()
            self.assertTrue(all(log.closed for fixture in (first, second) for log in fixture.logs))
            # Cleanup joins processes; the caller decides whether failed state
            # should be retained. It must not silently erase an installation.
            self.assertEqual((first.installation / 'private-state').read_text(), 'owned')

    def test_early_manager_exit_cannot_establish_readiness(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binaries = self.binaries(root, "import sys\nprint('startup refused', file=sys.stderr)\nsys.exit(17)\n")
            fixture = Fixture(*binaries, parent=root)
            try:
                fixture.start()
                fixture.process.wait(timeout=5)
                with self.assertRaisesRegex(AssertionError, 'Manager exit 17: startup refused'):
                    fixture.ready(timeout=1)
            finally:
                fixture.cleanup()


if __name__ == '__main__':
    unittest.main()

"""Exercise private installation files, frozen binaries and actual manager death."""
import json
import io
import os
from pathlib import Path
import select
import sys
import tempfile
import unittest
import urllib.error
from unittest.mock import Mock, patch

from harness.local_installation import LocalInstallation, freeze_executables
from interfaces.installation.server import Fixture
from interfaces.cli.console_terminal import Terminal


class Installations(unittest.TestCase):
    def test_board_readiness_counts_retryable_responses_without_extending_deadline(self):
        fixture = Fixture.__new__(Fixture)
        fixture.config = {'realm': 73}
        fixture.process = Mock()
        fixture.process.poll.return_value = None
        fixture.http = Mock()
        fixture.board_attempts = 0
        atlas = io.BytesIO(b'{"realm":73,"identity":{"principal":25}}')
        fixture.http.open.side_effect = [urllib.error.HTTPError('http://board', code, '', {}, None)
                                        for code in (429, 503)] + [atlas]
        with patch('interfaces.installation.server.time.monotonic', return_value=0), \
                patch('interfaces.installation.server.time.sleep') as sleep:
            fixture.ready_board('http://board', 1)
            self.assertEqual(fixture.board_attempts, 3)
            self.assertEqual(sleep.call_count, 2)
        fixture.http.open.side_effect = urllib.error.HTTPError('http://board', 429, '', {}, None)
        with patch('interfaces.installation.server.time.monotonic', side_effect=[0, 1, 1]), \
                patch('interfaces.installation.server.time.sleep'):
            with self.assertRaisesRegex(AssertionError, 'Board did not become ready'):
                fixture.ready_board('http://board', 1)

    def test_board_readiness_does_not_retry_denial(self):
        fixture = Fixture.__new__(Fixture)
        fixture.process = Mock()
        fixture.process.poll.return_value = None
        fixture.http = Mock()
        fixture.board_attempts = 0
        fixture.http.open.side_effect = urllib.error.HTTPError('http://board', 403, '', {}, None)
        with patch('interfaces.installation.server.time.monotonic', return_value=0), \
                patch('interfaces.installation.server.time.sleep') as sleep:
            with self.assertRaises(urllib.error.HTTPError):
                fixture.ready_board('http://board', 1)
            self.assertEqual(fixture.board_attempts, 1)
            sleep.assert_not_called()

    def test_terminal_does_not_inherit_build_or_runtime_overrides(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cli, _, _ = self.binaries(root, '''import json, os, sys
print('transit> ', end='', file=sys.stderr, flush=True)
print(json.dumps(dict(environment={key: value for key, value in os.environ.items()
    if key.startswith('TRANSIT_')}, home=os.environ['HOME'], path=os.environ['PATH'])), flush=True)
for line in sys.stdin:
    if '.quit' in line: break
''')
            with patch.dict(os.environ, {'TRANSIT_RELEASE_IDENTITY': '/build/identity.json',
                    'TRANSIT_PORTS__NODE': '1', 'TRANSIT_CONSOLE_CONFIG': '/foreign/console.yaml'}):
                terminal = Terminal(str(cli), cwd=root, env={'PATH': '/unavailable', 'TRANSIT_PORTS__NODE': '32123'})
                try:
                    observed = terminal.read()
                    self.assertEqual(observed['environment'], {'TRANSIT_PORTS__NODE': '32123'})
                    self.assertEqual(observed['path'], '/unavailable')
                    self.assertNotEqual(observed['home'], os.environ['HOME'])
                finally:
                    terminal.close()

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

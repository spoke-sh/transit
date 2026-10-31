"""Focused execution propagates failure; reusable programs never share fixture state."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from harness.phases import Recorder
from sdk import feedback
from sdk.consumers.rust import rust_station_sdk as rust


class Feedback(unittest.TestCase):
    def test_failed_focused_task_retains_original_failure_and_scope(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            script = root / 'just'
            script.write_text('#!/bin/sh\necho deliberate-failure\nexit 23\n')
            script.chmod(0o700)
            record = Recorder(root)
            with patch.dict(os.environ, {'PATH': str(root) + os.pathsep + os.environ['PATH']}), \
                    patch.object(feedback, 'ROOT', root), patch.object(feedback, 'recorder', return_value=record), \
                    patch('harness.phases.recorder', return_value=record):
                with self.assertRaises(subprocess.CalledProcessError) as failure:
                    feedback.execute('rust', 'full')
            self.assertEqual(failure.exception.returncode, 23)
            result = json.loads(next(record.directory.glob('sdk-feedback-*.json')).read_text())
            self.assertFalse(result['completed'])
            self.assertEqual((result['scope'], result['outcome']), ('full', 'failed'))
            self.assertIn('deliberate-failure', (record.directory / 'full.log').read_text())

    def test_rust_programs_are_built_once_but_installed_fresh_for_every_schedule(self):
        with tempfile.TemporaryDirectory() as directory:
            record = Recorder(Path(directory))
            compiled = []
            installations = []
            def compile_programs(target, artifacts):
                compiled.append(target)
                for name in ('consumer', 'consumer-arrow', 'transit-rust-counter'):
                    path = target / name
                    path.write_text('#!/bin/sh\nprintf "installed\\n"\n')
                    path.chmod(0o700)
                return {'fixture': 'fresh'}
            def schedule(node, cli, library, *args, **kwargs):
                install = next(arg for arg in args if callable(arg))
                with tempfile.TemporaryDirectory(dir=directory) as target:
                    target = Path(target)
                    installations.append(target)
                    consumer = install(target)
                    config = target / 'config.json'
                    config.write_text('{"role":"query","arrow_adapter":true}')
                    command = consumer.command('run', config)
                    self.assertEqual(command[0], target / 'consumer-arrow')
                    self.assertEqual(subprocess.check_output(command, text=True), 'installed\n')
                    self.assertEqual(consumer.environment, {'fixture': 'fresh'})
                    consumer.environment['fixture'] = 'mutated'
                    command[0].write_text('private mutation')
            with patch.object(rust, 'compile_consumer', side_effect=compile_programs), \
                    patch.object(rust, 'schedule', side_effect=schedule), \
                    patch('sdk.sdk_http_runner.run', side_effect=schedule), \
                    patch('sdk.sdk_exchange_runner.run', side_effect=schedule), \
                    patch('harness.phases.recorder', return_value=record):
                rust.run('node', 'cli', 'library', 'artifacts', 'http', 'grpc')
            self.assertEqual(len(compiled), 1)
            self.assertEqual(len(set(installations)), 3)
            self.assertTrue(all(not path.exists() for path in [*compiled, *installations]))


if __name__ == '__main__':
    unittest.main()

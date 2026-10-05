"""Fragmented diagnostic evidence and timing through the actual pipe reader."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from mutation_latency import Console, supervisor_evidence


class Evidence(unittest.TestCase):
    def test_successful_workload_retains_only_bounded_supervisor_causes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertFalse(supervisor_evidence(root)['available'])
            log = root / 'manager-0.stderr'
            prefix = 'error: server role failed; retrying the same installation: '
            log.write_text('PRIVATE\n' + prefix + 'AuthorityTimeout\n' + prefix + 'UnrecognizedDetail\n')
            evidence = supervisor_evidence(root)
            self.assertEqual(evidence['restarts'], ['AuthorityTimeout', 'other'])
            self.assertFalse(evidence['truncated'])
            self.assertNotIn('PRIVATE', json.dumps(evidence))
            self.assertNotIn('UnrecognizedDetail', json.dumps(evidence))
            log.write_text((prefix + 'ChildExited\n') * 8 + 'PRIVATE' * 11000)
            evidence = supervisor_evidence(root)
            self.assertTrue(evidence['truncated'])
            self.assertEqual(evidence['restarts'], ['ChildExited'] * 4)

    def test_fragmented_failure_keeps_cause_and_deferred_timing(self):
        for timing_first in (False, True):
            with self.subTest(timing_first=timing_first):
                timing = {'timing': {'phases': {'submit': 2000}, 'total': 2000}}
                diagnostic = {'code': 'write.saved_work_unresolved', 'cause': 'AuthorityTimeout',
                              'outcome': 'unknown', 'stage': 'reconcile', 'facts': [{'field': 'column', 'value': {'text': 'PRIVATE'}},
                                        {'field': 'native_cause', 'value': {'text': 'HttpCapacity'}}]}
                messages = [timing, diagnostic] if timing_first else [diagnostic, timing]
                script = '''import sys,time
sys.stdin.readline()
for message in %r:
 for part in (message[:5],message[5:]):
  sys.stderr.write(part);sys.stderr.flush();time.sleep(.01)
''' % [json.dumps(message) + '\n' for message in messages]
                shell = Console.__new__(Console)
                shell.process = subprocess.Popen([sys.executable, '-c', script], stdin=subprocess.PIPE,
                                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                shell.buffers = [bytearray(), bytearray()]
                try:
                    with self.assertRaisesRegex(RuntimeError, 'write.saved_work_unresolved'):
                        shell.call('INSERT')
                    self.assertEqual(shell.last_measurement['cause'], 'AuthorityTimeout')
                    self.assertEqual(shell.last_measurement['native_cause'], 'HttpCapacity')
                    self.assertEqual(shell.last_measurement['phase_ms']['submit'], 2000)
                    self.assertGreater(shell.last_measurement['elapsed_ns'], 10_000_000)
                    self.assertNotIn('PRIVATE', json.dumps(shell.last_measurement))
                finally:
                    shell.close()


if __name__ == '__main__':
    unittest.main()

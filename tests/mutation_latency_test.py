"""Fragmented diagnostic evidence and timing through the actual pipe reader."""
import json
import subprocess
import sys
import unittest
from mutation_latency import Console


class Evidence(unittest.TestCase):
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

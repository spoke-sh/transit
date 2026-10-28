"""Fragmented diagnostic evidence and timing through the actual pipe reader."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from performance.mutations.mutation_latency import Console, supervisor_evidence, completion_timeline


class Evidence(unittest.TestCase):
    def test_human_table_and_command_wait_for_stdout_and_timer(self):
        from performance.console.statements import phases, verify_table
        output = '┌───────┬───────┐\n│ id    │ value │\n│ int64 │ int64 │\n├───────┼───────┤\n│ 1     │ 10    │\n└───────┴───────┘\n1 rows; complete coverage\n'
        verify_table(output, [(1, 10)])
        with self.assertRaises(AssertionError):
            verify_table(output, [(1, 11)])
        with self.assertRaises(AssertionError):
            phases('Time: 8 ms (submit 7 ms, render 0 ms)')
        for text in (output, 'Statement completed. Matched 1; changed 1.\n'):
            for timing_first in (False, True):
                script = '''import sys,time
sys.stdin.readline()
streams = [(sys.stdout, %r), (sys.stderr, 'Time: 7 ms (submit 7 ms, render 0 ms)\\n')]
if %r: streams.reverse()
for stream, text in streams:
 for part in (text[:5], text[5:]):
  stream.write(part);stream.flush();time.sleep(.01)
sys.stdin.readline()
''' % (text, timing_first)
                shell = Console.__new__(Console)
                shell.mode = 'table'
                shell.process = subprocess.Popen([sys.executable, '-c', script], stdin=subprocess.PIPE,
                                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                shell.buffers = [bytearray(), bytearray()]
                try:
                    value, measurement = shell.call('SELECT * FROM items')
                    self.assertEqual(value, text)
                    self.assertEqual(phases(measurement['timing'])[0], 7)
                finally:
                    shell.close()

    def test_completion_timeline_matches_input_and_keeps_receipt_overlap(self):
        def event(operation, start, end, **fields):
            return dict(operation=operation, start_ns=start, response_ns=end, status=200, pid=2, **fields)
        events = [event('update:send', 110, 120, principal=10, position=7),
                  event('update:open_view', 130, 140, principal=11, input=7),
                  event('update:turn', 160, 190, principal=11, input=7),
                  event('read:process', 145, 150, principal=10, position=8, head_input=7),
                  event('read:process', 155, 185, principal=10, position=10, head_input=None, wait_hint=True),
                  event('update:turn', 175, 195, principal=11, input=6)]
        result = completion_timeline(events, 100, 200)
        self.assertTrue(result['complete'])
        self.assertEqual(result['turn']['response_ns'], 90)
        self.assertEqual(result['processed_observed_ns'], 85)
        self.assertEqual(result['after_processed_observation_ns'], 15)
        self.assertEqual(result['after_turn_receipt_ns'], 0)
        self.assertTrue(result['observation_precedes_turn_receipt'])
        self.assertEqual(result['caller_process_reads'], 2)
        self.assertEqual(result['caller_wait_requests'], 1)
        self.assertFalse(completion_timeline(events[1:], 100, 200)['complete'])
        self.assertFalse(completion_timeline(events + [events[0]], 100, 200)['complete'])
        self.assertFalse(completion_timeline(events[:4], 100, 200)['complete'])

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

    def test_typed_query_requires_complete_row_count_and_keeps_timing(self):
        for corrupt in (False, True):
            with self.subTest(corrupt=corrupt):
                basis = dict(object='19', revision='7')
                frames = [dict(profile='sql_result_v1', complete_coverage=False,
                               schema={'columns': []}, observation=basis),
                          dict(complete_coverage=False, row={'value': {'structure': [
                              {'value': {'atom': {'unsigned': '41'}}}]}}),
                          dict(complete_coverage=True, rows='2' if corrupt else '1', displayed_rows='1', observation=basis)]
                script = """import sys,time
sys.stdin.readline()
sys.stderr.write(%r);sys.stderr.flush()
for message in %r:
 for part in (message[:5],message[5:]):
  sys.stdout.write(part);sys.stdout.flush();time.sleep(.01)
sys.stdin.readline()
""" % (json.dumps({'timing': {'phases': {'fetch': 7}, 'total': 7}}) + '\n',
         [json.dumps(frame) + '\n' for frame in frames])
                shell = Console.__new__(Console)
                shell.process = subprocess.Popen([sys.executable, '-c', script], stdin=subprocess.PIPE,
                                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                shell.buffers = [bytearray(), bytearray()]
                try:
                    if corrupt:
                        with self.assertRaises(AssertionError): shell.call('SELECT COUNT(*) FROM items')
                    else:
                        result, measurement = shell.call('SELECT COUNT(*) FROM items')
                        self.assertEqual(result['rows'][0][0]['value']['atom']['unsigned'], '41')
                        self.assertEqual(measurement['phase_ms'], {'fetch': 7})
                finally:
                    shell.close()

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

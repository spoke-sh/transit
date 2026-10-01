"""Evidence must reject missing phases, false completion and wrong results."""
import copy
from pathlib import Path
import tempfile
import subprocess
import sys
import json
import unittest
import run


class Evidence(unittest.TestCase):
    def records(self):
        return [dict(phase=p, elapsed_ns=100, cpu_ns=50) for p in
            ('capture', 'discovery', 'compile', 'scan_convert', 'export_cached_batch', 'scan_convert_execute')] + [
                dict(complete=True, scanned=3, id_sum=3, build_mode='safe')]

    def test_only_complete_checked_runs_pass(self):
        expected = dict(expected_rows=3, expected_id_sum=3)
        run.checked(self.records(), expected, 'transit')
        for change in ('missing_phase', 'duplicate', 'incomplete', 'bad_count', 'wrong_sum', 'wrong_build', 'bad_time'):
            records = self.records()
            if change == 'missing_phase': records.pop(1)
            elif change == 'duplicate': records.insert(1, copy.deepcopy(records[0]))
            elif change == 'incomplete': records[-1]['complete'] = False
            elif change == 'bad_count': records[-1]['scanned'] = 2
            elif change == 'wrong_sum': records[-1]['id_sum'] = 4
            elif change == 'wrong_build': records[-1]['build_mode'] = 'debug'
            else: records[0]['elapsed_ns'] = 0
            with self.subTest(change=change), self.assertRaises(ValueError):
                run.checked(records, expected, 'transit')

    def test_fixtures_reproduce_content_independent_of_paths(self):
        with tempfile.TemporaryDirectory() as one, tempfile.TemporaryDirectory() as two:
            for shape in run.SHAPES:
                left = run.fixture(Path(one), shape, 17)
                right = run.fixture(Path(two), shape, 17)
                self.assertEqual(left['files'], right['files'])
                self.assertEqual(left['expanded'], right['expanded'])
                partial = run.config(left, 'partial', 17, 8, False)
                self.assertEqual(partial['expected_id_sum'], 136)
                self.assertEqual(partial['options']['mode'], 'sampled')
                self.assertIsNone(run.config(left, 'raw', 17, 8, False)['expected_id_sum'])

    def test_failed_preparation_cannot_leave_a_success_report(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)/'report.json'
            output.write_text('{"status":"passed","completed":true}')
            result = subprocess.run([sys.executable, str(Path(run.__file__)), '/missing-benchmark', '--output', str(output)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            report = json.loads(output.read_text())
            self.assertEqual(report['status'], 'failed')
            self.assertFalse(report['completed'])
            self.assertEqual(report['summary'], [])


if __name__ == '__main__': unittest.main()

"""Fail-closed inventory/report checks; no timing thresholds."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import run


class ReportTests(unittest.TestCase):
    def setUp(self):
        self.data = run.load_manifest()

    def records(self):
        records = [dict(kind='metadata', optimization='safe')]
        for case in self.data['components']:
            records.append(dict(id=case['id'], phase='compile', elapsed_ns=10, iterations=2))
            phases = {'select': ['execute'], 'declaration': ['verify_declaration'], 'mutation': ['verify_mutation', 'propose_mutation']}[case['kind']]
            records.extend(dict(id=case['id'], phase=phase) for phase in phases)
        for record in records[1:]:
            if record['phase'] in ('execute', 'propose_mutation'):
                record.update(elapsed_ns=10, iterations=2)
        records.extend(dict(id=probe['id'], phase='blocker_probe') for probe in self.data['probes'])
        return records

    def test_complete_inventory_does_not_promote_components(self):
        suites = run.coverage(self.data)
        self.assertEqual([s['total'] for s in suites], [5, 12, 24, 110])
        self.assertTrue(all(s['completed'] == 0 and s['full_workload_status'] == 'blocked' for s in suites))
        self.assertTrue(all(op['status'] == 'blocked' and op['blockers'] for s in suites for op in s['operations']))

    def test_missing_and_duplicate_workload_refused(self):
        for duplicate in (False, True):
            data = copy.deepcopy(self.data)
            operations = data['suites'][0]['operations']
            operations.append(operations[0]) if duplicate else operations.pop()
            with tempfile.TemporaryDirectory() as directory:
                manifest = Path(directory) / 'manifest.json'
                manifest.write_text(json.dumps(data))
                with patch.object(run, 'MANIFEST', manifest), self.assertRaises(ValueError):
                    run.load_manifest()

    def test_missing_and_foreign_definition_refused(self):
        for definition in (None, 'foreign'):
            data = copy.deepcopy(self.data)
            data['definition'] = definition
            with tempfile.TemporaryDirectory() as directory:
                manifest = Path(directory) / 'manifest.json'
                manifest.write_text(json.dumps(data))
                with patch.object(run, 'MANIFEST', manifest), self.assertRaises(ValueError):
                    run.load_manifest()

    def test_missing_duplicate_and_extra_results_refused(self):
        records = self.records()
        run.checked_records(records, self.data)
        for changed in (records[:-1], records + [records[-1]], records + [dict(id='unknown', phase='execute')]):
            with self.assertRaises(ValueError):
                run.checked_records(changed, self.data)

    def test_wrong_build_and_invalid_durations_refused(self):
        records = self.records()
        for change in ('debug', 'missing_metadata', 'zero_duration', 'missing_duration'):
            changed = copy.deepcopy(records)
            if change == 'debug':
                changed[0]['optimization'] = 'debug'
            elif change == 'missing_metadata':
                changed.pop(0)
            elif change == 'zero_duration':
                changed[1]['elapsed_ns'] = 0
            else:
                del changed[1]['elapsed_ns']
            with self.assertRaises(ValueError):
                run.checked_records(changed, self.data)

    def test_empty_null_and_seed_provenance(self):
        self.assertEqual(list(run.fixture_rows(3, 42)), [(0, None), (1, 59), (2, 76)])
        self.assertEqual(len(run.fixture_hash(0, 42)), 64)
        self.assertNotEqual(run.fixture_hash(2, 42), run.fixture_hash(2, 43))
        self.assertNotEqual(run.fixture_hash(0, 42), run.fixture_hash(1, 42))

    def test_failure_replaces_previous_success_report(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / 'result.json'
            report.write_text('{"status":"components_passed_full_workloads_blocked"}')
            process = subprocess.run([sys.executable, str(Path(run.__file__)), str(Path(directory) / 'missing-binary'), '--output', str(report)], capture_output=True, text=True)
            self.assertEqual(process.returncode, 1)
            result = json.loads(report.read_text())
            self.assertEqual(result['status'], 'failed')
            self.assertEqual(result['summary'], [])

    def test_invalid_budget_does_not_start_run(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / 'result.json'
            process = subprocess.run([sys.executable, str(Path(run.__file__)), 'unused', '--page-rows', '9', '--output', str(report)], capture_output=True, text=True)
            self.assertEqual(process.returncode, 2)
            self.assertFalse(report.exists())


if __name__ == '__main__':
    unittest.main()

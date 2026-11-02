"""Independent encoded values and rejection of failed or altered experiments."""
import copy
import io
import json
import unittest
from unittest.mock import patch

from performance.load.installed import Recorder, admission_refusal, integers, settle
from performance.load.report import OWNER_COUNTERS, UNAVAILABLE, compare, inventory, summarize


def campaign():
    result = [dict(phase='campaign', outcome='started'),
        dict(phase='manifest', profile='managed', rows=3, repeat=1, peers=1,
             source={'revision': 'a'*40}, binary_revision='a'*40, binaries={'cli': 'b'*64}, drivers={'driver': 'c'*64},
             system='Linux', machine='x86_64', cpus=2, host_id='d'*64, storage_device=1, toolchain='zig',
             maintenance='enabled', durability='sync', cache='retained', instrumentation='procfs', bounds={'rows': 1000},
             build_mode='ReleaseSafe', tls='peer', client_versions={'python': '3'}, sql_limits={'command_ms': 30000},
             attribution=False, host_limits={'affinity': [0, 1]}, unavailable=list(UNAVAILABLE))]
    for case in ('startup', 'foreground_baseline', 'activation', 'source_update', 'idle', 'retained_restart'):
        row = dict(phase='sample', case=case, index=0, outcome='complete', verified=True, elapsed_ns=100)
        if case == 'startup':
            row['definition'] = 'e'*64
        if case in ('activation', 'source_update'):
            row.update(rows=3 if case == 'activation' else 4, revision=1, foreground_ns=[25])
        result.append(row)
    return result + [dict(phase='resources', case='settled', processes=[dict(pid=1)]), dict(phase='campaign', outcome='complete')]


class InstalledReportTest(unittest.TestCase):
    def attributed(self):
        records = campaign()
        records[1]['attribution'] = True
        snapshot = dict(instance=[1]*16, **{owner: dict(values={field: 0 for field in fields}, overflowed=False)
                                          for owner, fields in OWNER_COUNTERS.items()})
        for row in records:
            if row.get('case') in ('foreground_baseline', 'activation', 'source_update', 'idle'):
                row.update(owner_before=copy.deepcopy(snapshot), owner_after=copy.deepcopy(snapshot),
                           owner_counters={owner: dict(values['values']) for owner, values in snapshot.items() if owner != 'instance'})
        return records

    def test_owner_attribution_requires_complete_monotonic_same_instance(self):
        records = self.attributed()
        self.assertEqual(summarize(records)['cases']['activation']['owner_totals']['managed']['result_rows'], 0)
        mutations = (
            lambda row: row.pop('owner_counters'),
            lambda row: row['owner_after']['owned_records'].update(overflowed=True),
            lambda row: row['owner_after'].update(instance=[2]*16),
            lambda row: row['owner_after']['managed']['values'].pop('evaluate_ns'),
            lambda row: row['owner_before']['managed']['values'].update(result_rows=1),
            lambda row: row['owner_counters']['managed'].update(result_rows=True),
            lambda row: row['owner_counters']['managed'].update(result_rows=2**64),
            lambda row: row['owner_after']['managed']['values'].update(result_rows=1),
        )
        for mutate in mutations:
            altered = copy.deepcopy(records)
            mutate(altered[4])
            with self.assertRaises(ValueError):
                summarize(altered)
        with self.assertRaisesRegex(ValueError, 'incomparable'):
            compare(summarize(campaign()), summarize(records))
        with self.assertRaisesRegex(ValueError, 'incomparable'):
            changed = copy.deepcopy(records)
            changed[2]['definition'] = 'f'*64
            compare(summarize(records), summarize(changed))

    def test_failed_operation_retains_counters_without_masking_original_error(self):
        for diagnostic_failure in (False, True):
            output = io.StringIO()
            recorder = Recorder(output)
            from unittest.mock import Mock
            probe = Mock()
            probe.snapshot.return_value = {'local:table': 10}
            probe.delta.side_effect = RuntimeError('inspection failed') if diagnostic_failure else None
            probe.delta.return_value = {'local:table': 2}
            with self.assertRaisesRegex(BrokenPipeError, 'original'), patch('builtins.print'):
                with recorder.sample('activation', probe=probe):
                    raise BrokenPipeError('original')
            record = json.loads(output.getvalue())
            self.assertEqual(record['outcome'], 'failed')
            self.assertEqual(record['error_type'], 'BrokenPipeError')
            if diagnostic_failure:
                self.assertEqual(record['observation_error'], 'RuntimeError')
            else:
                self.assertEqual(record['local_attempts'], {'local:table': 2})

    def test_final_verified_output_must_arrive_within_deadline(self):
        for final, late in ((180, False), (180.001, True)):
            record = {}
            with patch('performance.load.installed.time.monotonic', side_effect=(0, 0, final)), \
                 patch('performance.load.installed.head', return_value=dict(blocked='none', revision=1, pending=None)), \
                 patch('performance.load.installed.read', return_value=[['030000000000000000']]):
                if late:
                    with self.assertRaisesRegex(AssertionError, 'deadline'):
                        settle(None, 1, 1, record)
                else:
                    self.assertEqual(settle(None, 1, 1, record), 1)
            self.assertEqual(record['rows'], 1)
            self.assertTrue(record['verified'])
            self.assertEqual(len(record['foreground_ns']), 1)

    def test_failed_observation_retains_progress_without_repeating(self):
        record = {}
        with patch('performance.load.installed.head', return_value=dict(blocked='none', revision=0, pending={})) as observed, \
             patch('performance.load.installed.read', side_effect=BrokenPipeError):
            with self.assertRaises(BrokenPipeError):
                settle(None, 1, 1, record)
        observed.assert_called_once()
        self.assertEqual(record, dict(foreground_ns=[], pending_observations=1, observation_polls=1))

    def test_admission_refusal_does_not_hide_transport_failure(self):
        diagnostic = RuntimeError('connection failed: FATAL:  Account or database access denied\n')
        self.assertEqual(admission_refusal('postgres', diagnostic),
                         dict(sqlstate=None, refusal_basis='postgres_fatal_message'))
        self.assertIsNone(admission_refusal('mysql', diagnostic))
        for message in ('timeout expired', 'connection refused', 'TLS verification failed',
                        'Account or database access denied', str(diagnostic)+'another error'):
            self.assertIsNone(admission_refusal('postgres', RuntimeError(message)))
        diagnostic.sqlstate = '28000'
        self.assertEqual(admission_refusal('mysql', diagnostic),
                         dict(sqlstate='28000', refusal_basis='sqlstate'))
        diagnostic.sqlstate = 'XX000'
        self.assertIsNone(admission_refusal('postgres', diagnostic))

    def test_signed_independent_values(self):
        self.assertEqual(integers([['03ffffffffffffffff'], ['030000000000000000']]), [-1, 0])
        for malformed in ([['01']], [['0300']], [['030000000000000000', '030000000000000000']]):
            with self.assertRaises(AssertionError):
                integers(malformed)

    def test_connection_refusal_requires_evidence(self):
        records = campaign()[:2]
        records[1]['profile'] = 'connections'
        for case, index in sorted(inventory(records[1])):
            row = dict(phase='sample', case=case, index=index, outcome='complete', verified=True, elapsed_ns=100)
            if case == 'startup':
                row['definition'] = 'e'*64
            if case.endswith('_idle_peer'):
                row.update(admitted=False, sqlstate='28000', refusal_basis='sqlstate')
            records.append(row)
        records += [dict(phase='resources', case=case, processes=[dict(pid=1)])
                    for case in ('before_peers', 'postgres_idle', 'mysql_idle', 'after_peers')]
        records.append(dict(phase='campaign', outcome='complete'))
        control = summarize(copy.deepcopy(records))
        self.assertEqual(compare(control, control)['postgres_idle_peer'], 1)
        peer = next(r for r in records if r.get('case') == 'postgres_idle_peer')
        peer.update(sqlstate=None, refusal_basis='postgres_fatal_message')
        with self.assertRaises(ValueError):
            compare(control, summarize(records))
        peer['refusal_basis'] = 'unknown'
        with self.assertRaises(ValueError):
            summarize(records)

    def test_complete_and_matched(self):
        report = summarize(campaign())
        self.assertEqual(report['cases']['activation']['foreground']['p50_ns'], 25)
        self.assertEqual(compare(report, report)['activation'], 1)

    def test_failed_missing_and_changed(self):
        original = campaign()
        for changed in (original[:-1], original[:4]+original[5:], original+[original[-1]], original[:4]+[original[3]]+original[4:]):
            with self.assertRaises(ValueError):
                summarize(changed)
        for field, value in (('outcome', 'failed'), ('verified', False), ('rows', 2), ('foreground_ns', []), ('elapsed_ns', True)):
            changed = copy.deepcopy(original)
            changed[4][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                summarize(changed)
        for field in ('drivers', 'maintenance', 'rows', 'bounds'):
            control = summarize(original)
            candidate = copy.deepcopy(control)
            candidate['manifest'][field] = 'changed'
            with self.subTest(field=field), self.assertRaises(ValueError):
                compare(control, candidate)


if __name__ == '__main__':
    unittest.main()

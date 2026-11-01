"""Independent encoded values and rejection of failed or altered experiments."""
import copy
import unittest

from performance.load.installed import admission_refusal, integers
from performance.load.report import compare, inventory, summarize


def campaign():
    result = [dict(phase='campaign', outcome='started'),
        dict(phase='manifest', profile='managed', rows=3, repeat=1, peers=1,
             source={'revision': 'a'*40}, binary_revision='a'*40, binaries={'cli': 'b'*64}, drivers={'driver': 'c'*64},
             system='Linux', machine='x86_64', cpus=2, host_id='d'*64, storage_device=1, toolchain='zig',
             maintenance='enabled', durability='sync', cache='retained', instrumentation='procfs', bounds={'rows': 1000},
             build_mode='ReleaseSafe', tls='peer', client_versions={'python': '3'}, sql_limits={'command_ms': 30000})]
    for case in ('startup', 'foreground_baseline', 'activation', 'source_update', 'idle', 'retained_restart'):
        row = dict(phase='sample', case=case, index=0, outcome='complete', verified=True, elapsed_ns=100)
        if case == 'startup':
            row['definition'] = 'e'*64
        if case in ('activation', 'source_update'):
            row.update(rows=3 if case == 'activation' else 4, revision=1, foreground_ns=[25])
        result.append(row)
    return result + [dict(phase='resources', case='settled', processes=[dict(pid=1)]), dict(phase='campaign', outcome='complete')]


class InstalledReportTest(unittest.TestCase):
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

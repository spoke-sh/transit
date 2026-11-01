"""Independent encoded values and rejection of failed or altered experiments."""
import copy
import unittest

from performance.load.installed import integers
from performance.load.report import compare, summarize


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
    def test_signed_independent_values(self):
        self.assertEqual(integers([['03ffffffffffffffff'], ['030000000000000000']]), [-1, 0])
        for malformed in ([['01']], [['0300']], [['030000000000000000', '030000000000000000']]):
            with self.assertRaises(AssertionError):
                integers(malformed)

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

"""Independent workload oracles and incomplete/foreign campaign rejection."""
import copy
import hashlib
import unittest

from performance.sdk.report import compare, summarize
from performance.sdk.workload import CASES, cases, digest_rows, verify


def campaign():
    rows = [dict(phase='campaign', outcome='started', languages=['zig'], repeat=2, warmup=1),
            dict(phase='manifest', version=1, languages=['zig'], repeat=2, warmup=1, rows=70,
                 definition='a'*64, drivers={'driver': 'b'*64}, binaries={'cli': 'c'*64},
                 source={'revision': 'd'*40, 'dirty': False}, native_provenance={'revision': 'd'*40}, native_build={'build': {'optimize': 'safe'}},
                 system='test', machine='test', cpus=1, host_id='e'*64, storage_device=1, toolchain={'zig': 'test'},
                 maintenance='enabled', build_mode='ReleaseSafe', storage_block_size=4096, durability='sync',
                 cache='retained', completion='verified', unsupported=[])]
    for phase in ('cold_start', 'client', 'resources', 'close', 'package_preparation'):
        rows.append(dict(phase=phase, language='zig', outcome='complete',
                         elapsed_ns=1, ready_ns=1, first_verified_ns=2))
    for case in CASES:
        for index in (-1, 0, 1):
            rows.append(dict(phase='operation', language='zig', case=case, index=index,
                             warmup=index < 0, outcome='complete', elapsed_ns=100 + index,
                             consumer=dict(complete=True, elapsed_ns=90 + index)))
    return rows + [dict(phase='campaign', outcome='complete')]


class ReportTest(unittest.TestCase):
    def test_exact_oracle(self):
        # Explicit two signed little-endian int64s, including a negative value.
        expected = hashlib.sha256(bytes.fromhex('0100000000000000feffffffffffffff')).hexdigest()
        self.assertEqual(digest_rows([(1, -2)]), expected)
        self.assertEqual(digest_rows([(2, 3), (1, 4)]), digest_rows([(1, 4), (2, 3)]))
        self.assertNotEqual(digest_rows([(1, 4)]), digest_rows([(1, 4), (1, 4)]))
        self.assertEqual(digest_rows([]), hashlib.sha256(b'').hexdigest())
        workloads = {name: (request, expected) for name, request, expected in cases(70)}
        self.assertEqual(workloads['range'][1]['rows'], 8)
        self.assertEqual(workloads['full'][1]['rows'], 70)
        self.assertEqual(workloads['empty'][1]['rows'], 0)
        good = dict(complete=True, rows=1, digest=expected, elapsed_ns=1)
        verify(good, dict(rows=1, digest=expected))
        for change in (dict(rows=0), dict(rows=True), dict(digest='00'), dict(complete=False),
                       dict(elapsed_ns=True), dict(elapsed_ns=-1)):
            with self.subTest(change=change), self.assertRaises(ValueError):
                verify(dict(good, **change), dict(rows=1, digest=expected))

    def test_distribution_excludes_warmup(self):
        report = summarize(campaign())
        values = report['languages']['zig']['cases']['full']['consumer']
        self.assertEqual(values, dict(n=2, p50_ns=90.5, p95_ns=91, max_ns=91))
        self.assertEqual(compare(report, report)['zig']['full'], 1)

    def test_incomplete_failed_and_duplicate(self):
        original = campaign()
        variants = [original[:-1], original[1:], original[:5] + original[6:],
                    original[:8] + original[9:], original[:8] + [original[8]] + original[8:]]
        for field, value in (('outcome', 'failed'), ('index', True), ('warmup', False), ('case', 'other')):
            changed = copy.deepcopy(original)
            changed[7][field] = value
            variants.append(changed)
        for phase in ('cold_start', 'close'):
            changed = copy.deepcopy(original)
            next(row for row in changed if row['phase'] == phase)['outcome'] = 'failed'
            variants.append(changed)
        for rows in variants:
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                summarize(rows)

    def test_foreign_workload_or_driver_cannot_compare(self):
        original = summarize(campaign())
        for key, value in (('rows', 71), ('drivers', {'changed': 'hash'}), ('cache', 'evicted'),
                           ('definition', 'foreign'), ('build_mode', 'Debug'), ('maintenance', 'disabled')):
            changed = copy.deepcopy(original)
            changed['manifest'][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                compare(original, changed)


if __name__ == '__main__':
    unittest.main()

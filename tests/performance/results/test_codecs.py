"""Negative controls for incomplete, mismatched and regressed codec evidence."""
import copy
import json
import unittest

from performance.results import codecs


def fixture():
    common = dict(rows_per_sample=10000, columns=7, warmups=1, repetitions=5, optimize='safe')
    wire = common | dict(profile='database_wire_encoding', samples=[
        dict(path=path, milliseconds=[1.0] * 5, framed_bytes=100) for path in
        ('postgres_text', 'postgres_binary', 'mysql_text', 'mysql_binary')])
    native = common | dict(profile='native_result_encoding', samples=[
        dict(batch_rows=rows, batches=(10000 + rows - 1) // rows, framed_bytes=200,
             maximum_frame_bytes=100, encode_ms=[1.0] * 5, decode_ms=[1.0] * 5,
             encode_backing=[dict(alloc_attempts=0, growing_resize_attempts=0, remap_attempts=0)] * 5,
             decode_backing=[dict(alloc_attempts=0, growing_resize_attempts=0, remap_attempts=0)] * 5,
             encoder_peak_bytes=[8192] * 5, decoder_peak_bytes=[8192] * 5) for rows in (1, 32)])
    return {role: copy.deepcopy([[wire, native]] * 5) for role in ('baseline', 'candidate')}


class Gates(unittest.TestCase):
    def test_exact_work_and_regression(self):
        budgets = json.loads(codecs.BUDGETS.read_text())
        samples = fixture()
        self.assertEqual(codecs.assess(samples, budgets)['status'], 'passed')
        for reports in samples['candidate']:
            reports[1]['samples'][1]['encode_ms'] = [1.06] * 5
        self.assertEqual(codecs.assess(samples, budgets)['status'], 'failed')

    def test_incomplete_mismatched_allocation_and_invalid_timing_fail(self):
        budgets = json.loads(codecs.BUDGETS.read_text())
        mutations = [
            lambda samples: samples['candidate'].pop(),
            lambda samples: samples['candidate'][0][1]['samples'][0].update(framed_bytes=201),
            lambda samples: samples['candidate'][0][1]['samples'][0]['decode_backing'][0].update(remap_attempts=1),
            lambda samples: samples['candidate'][0][1]['samples'][0].update(encoder_peak_bytes=[16777217] * 5),
            lambda samples: samples['candidate'][0][1]['samples'][0].update(decode_ms=[float('nan')] * 5),
        ]
        for mutation in mutations:
            samples = fixture()
            mutation(samples)
            with self.assertRaises(AssertionError):
                codecs.assess(samples, budgets)


if __name__ == '__main__':
    unittest.main()

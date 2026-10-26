#!/usr/bin/env python3
"""Reject incomplete or misleading owner measurements before reporting success."""
import copy
import unittest
import storage_benchmark as driver


class Reports(unittest.TestCase):
    def sample(self):
        phase = dict(elapsed_ns=100, peak_live_bytes=16, baseline_live_bytes=0,
                     end_live_bytes=0, counters=dict(wal_appends=0, object_puts=0,
                                                   table_replay_frames=0))
        phases = [dict(copy.deepcopy(phase), name=name) for name in ('physical_open', 'recover', 'measure')]
        phases[1]['counters']['table_replay_frames'] = 1
        values = driver.oracle(range(14, 18))
        return dict(record=dict(complete=True, build_mode='safe', **values,
                                visited=4, visited_sum=values['sum'], visited_digest=values['digest'],
                                position=4, checkpoint=3, image_peak_rss_kib=1000, phases=phases))

    def validate(self, value):
        driver.validate(value, 'table', 'measure', 32, 'range', 'checkpoint')

    def test_incomplete_or_changed_results(self):
        sample = self.sample()
        self.validate(sample)
        for name, value in [('count', 3), ('visited', 5), ('complete', False), ('build_mode', 'fast'),
                            ('digest', '0' * 64), ('visited_digest', '0' * 64), ('position', 3),
                            ('checkpoint', 0), ('image_peak_rss_kib', 0)]:
            bad = copy.deepcopy(sample)
            bad['record'][name] = value
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.validate(bad)

    def test_phase_coverage_and_measurements(self):
        for mutation in ('missing', 'duplicate', 'time', 'peak', 'publication', 'replay'):
            bad = self.sample()
            phases = bad['record']['phases']
            if mutation == 'missing':
                phases.pop()
            elif mutation == 'duplicate':
                phases.append(phases[-1])
            elif mutation == 'time':
                phases[0]['elapsed_ns'] = 0
            elif mutation == 'peak':
                phases[0]['end_live_bytes'] = 17
            elif mutation == 'publication':
                phases[2]['counters']['wal_appends'] = 1
            else:
                phases[1]['counters']['table_replay_frames'] = 0
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                self.validate(bad)

    def test_percentiles_require_raw_coverage(self):
        samples = [dict(self.sample(), owner='table', rows=32, cache='cold', variant='checkpoint',
                        mode='range', warmup=False, repetition=i) for i in range(31)]
        self.assertIn('p95_ns', driver.summary(samples, 31)[0]['phases']['recover'])
        self.assertNotIn('p95_ns', driver.summary(samples[:1], 1)[0]['phases']['recover'])
        with self.assertRaises(ValueError):
            driver.summary(samples[:-1], 31)
        samples[-1]['repetition'] = 0
        with self.assertRaises(ValueError):
            driver.summary(samples, 31)


if __name__ == '__main__':
    unittest.main()

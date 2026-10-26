#!/usr/bin/env python3
"""Reject incomplete or misleading owner measurements before reporting success."""
import copy
import unittest
import storage_benchmark as driver
import storage_ingest_benchmark as ingestion


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


class IngestionReports(unittest.TestCase):
    def sample(self, owner='table', operation='ingest'):
        write = operation == 'ingest'
        count = 16 if owner == 'table' else 1
        values = driver.oracle(range(32, 32 + count) if write else range(32 + count))
        phases = []
        names = ['physical_open', 'recover'] + (['prepare', 'commit'] if owner == 'native' and write else
                                              ['ingest'] if write else ['verify'] if owner == 'table' else ['measure'])
        for name in names:
            appends = 2 if name == 'prepare' else 1 if name in ('commit', 'ingest') else 0
            phases.append(dict(name=name, elapsed_ns=100, baseline_live_bytes=10, end_live_bytes=20,
                               peak_live_bytes=30, counters=dict(wal_appends=appends, wal_syncs=appends, object_puts=appends),
                               timed_appends=appends if owner == 'table' else 0,
                               wal_append_ns=(30 if appends else 0) if owner == 'table' else None))
        return dict(record=dict(complete=True, build_mode='safe', **values, visited=values['count'],
                                visited_sum=values['sum'], visited_digest=values['digest'], phases=phases,
                                position=4 if owner == 'table' else 106, checkpoint=0, image_peak_rss_kib=1000))

    def test_independent_write_and_reopen_coverage(self):
        for owner in ('table', 'native'):
            for operation in ('ingest', 'verify'):
                original = self.sample(owner, operation)
                ingestion.validate(original, owner, 32, operation)
                for field, value in [('count', 0), ('digest', '0' * 64), ('visited', 0),
                                     ('position', 0), ('complete', False), ('checkpoint', 1)]:
                    bad = copy.deepcopy(original)
                    bad['record'][field] = value
                    with self.subTest(owner=owner, operation=operation, field=field), self.assertRaises(ValueError):
                        ingestion.validate(bad, owner, 32, operation)

    def test_durable_phase_and_timer_attribution(self):
        for owner in ('table', 'native'):
            for change in ('missing', 'append', 'sync', 'timer', 'memory'):
                bad = self.sample(owner)
                phase = bad['record']['phases'][-1]
                if change == 'missing':
                    bad['record']['phases'].pop()
                elif change == 'append':
                    phase['counters']['wal_appends'] = 0
                elif change == 'sync':
                    phase['counters']['wal_syncs'] = 0
                elif change == 'timer':
                    phase['wal_append_ns'] = 101
                else:
                    phase['peak_live_bytes'] = 1
                with self.subTest(owner=owner, change=change), self.assertRaises(ValueError):
                    ingestion.validate(bad, owner, 32, 'ingest')
            bad = self.sample(owner, 'verify')
            bad['record']['phases'][-1]['counters']['object_puts'] = 1
            with self.assertRaises(ValueError):
                ingestion.validate(bad, owner, 32, 'verify')

    def test_summary_requires_all_repetitions(self):
        samples = [dict(write=self.sample(), owner='table', rows=32, cache='cold', mode='bulk',
                        warmup=False, repetition=i) for i in range(31)]
        self.assertIn('p95_ns', ingestion.summarize(samples, 31)[0]['timings']['wal_append'])
        self.assertNotIn('p95_ns', ingestion.summarize(samples[:1], 1)[0]['timings']['ingest'])
        with self.assertRaises(ValueError):
            ingestion.summarize(samples[:-1], 31)
        samples[-1]['repetition'] = 0
        with self.assertRaises(ValueError):
            ingestion.summarize(samples, 31)


if __name__ == '__main__':
    unittest.main()

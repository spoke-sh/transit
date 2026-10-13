"""Evidence must reject missing phases, false completion and wrong results."""
import copy
from pathlib import Path
import tempfile
import subprocess
import sys
import json
import unittest
import run
import budgets
import compare
import pipeline_gates
import pipelines


class Evidence(unittest.TestCase):
    def test_pipeline_gate_rejects_false_results_incomplete_dispatch_and_regressions(self):
        limits = json.loads((Path(__file__).parent / 'results/2026-10-13-pipelines/budgets.json').read_text())
        report = dict(status='passed', completed=True, tracked_dirty=False, samples=[])
        for case in pipelines.CASES:
            for rows, repetitions in [(8, 100), (4096, 20)]:
                count, checksum = pipelines.expected(case, rows)
                for engine in ('scalar', 'batch', 'simd', 'parallel1', 'parallel2', 'parallel4'):
                    for repetition in range(10):
                        report['samples'].append(dict(case=case, rows=rows, engine=engine, repetition=repetition,
                            warmup=repetition == 0, exit_code=0, record=dict(count=count * repetitions,
                            checksum=checksum * repetitions, repetitions=repetitions, end_live_bytes=0,
                            build_mode='safe', elapsed_ns=100 if engine == 'scalar' else 50,
                            implementation='reference' if engine == 'scalar' else 'avx2' if engine == 'simd' else 'portable',
                            workers=int(engine[-1]) if engine.startswith('parallel') else 0)))
        controls = dict(status='passed', completed=True, dirty=False, summary=[dict(sql=str(i),
            control=dict(signature=i, raw_ns=[100] * 9), candidate=dict(signature=i, raw_ns=[100] * 9)) for i in range(8)])
        self.assertEqual(pipeline_gates.assess(report, controls, limits)['status'], 'passed')
        for change in ('incomplete', 'dirty', 'missing', 'duplicate', 'checksum', 'dispatch', 'workers', 'leak'):
            changed = copy.deepcopy(report)
            if change == 'incomplete': changed['completed'] = False
            elif change == 'dirty': changed['tracked_dirty'] = True
            elif change == 'missing': changed['samples'].pop()
            elif change == 'duplicate': changed['samples'][1] = copy.deepcopy(changed['samples'][0])
            else:
                field, value = {'checksum': ('checksum', -999), 'dispatch': ('implementation', 'avx2'),
                    'workers': ('workers', 5), 'leak': ('end_live_bytes', 1)}[change]
                changed['samples'][0]['record'][field] = value
            with self.subTest(change=change), self.assertRaises(ValueError):
                pipeline_gates.assess(changed, controls, limits)
        changed = copy.deepcopy(report)
        for sample in changed['samples']:
            if sample['engine'] == 'batch' and sample['rows'] == 4096: sample['record']['elapsed_ns'] = 1000
        self.assertEqual(pipeline_gates.assess(changed, controls, limits)['status'], 'failed')
        changed = copy.deepcopy(controls)
        changed['summary'][0]['candidate']['raw_ns'] = [116] * 9
        self.assertEqual(pipeline_gates.assess(report, changed, limits)['status'], 'failed')
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'result.json'
            output.write_text('{"status":"passed"}')
            result = subprocess.run([sys.executable, pipeline_gates.__file__, '--pipelines', '/missing',
                '--controls', '/missing', '--budgets', '/missing', '--output', str(output)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(json.loads(output.read_text())['status'], 'failed')

    def records(self):
        return [dict(phase=p, elapsed_ns=100, cpu_ns=50) for p in
            ('capture', 'discovery', 'compile', 'scan_convert', 'export_cached_batch', 'scan_convert_execute')] + [
                dict(complete=True, scanned=3, id_sum=3, result_sum=3, build_mode='safe', image_peak_rss_kib=4096)]

    def test_only_complete_checked_runs_pass(self):
        expected = dict(expected_rows=3, expected_id_sum=3, expected_result_sum=3)
        run.checked(self.records(), expected, 'transit')
        for change in ('missing_phase', 'duplicate', 'incomplete', 'bad_count', 'wrong_sum', 'wrong_query', 'wrong_build', 'bad_time'):
            records = self.records()
            if change == 'missing_phase': records.pop(1)
            elif change == 'duplicate': records.insert(1, copy.deepcopy(records[0]))
            elif change == 'incomplete': records[-1]['complete'] = False
            elif change == 'bad_count': records[-1]['scanned'] = 2
            elif change == 'wrong_sum': records[-1]['id_sum'] = 4
            elif change == 'wrong_query': records[-1]['result_sum'] = 4
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

    def test_query_oracles_and_distinct_column_values(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = run.fixture(Path(temporary), 'multifile', 17)
            for path in source['paths']:
                with path.open() as stream:
                    for row in run.csv.DictReader(stream):
                        self.assertNotEqual(row['id'], row['value'])
            for query, count, total in [('all', 17, 136), ('filter', 4, 6), ('compound', 4, 6), ('count', 1, 17), ('sum', 1, 136)]:
                cfg = run.config(source, 'explicit', 17, 8, False, query)
                self.assertEqual((cfg['expected_output_rows'], cfg['expected_result_sum']), (count, total))

    def test_comparison_requires_equivalent_results_and_labels_operator_work(self):
        self.assertEqual(compare.query_pair('compound', None), dict(baseline='filter', candidate='compound'))
        for query in ('all', 'filter', 'compound', 'count', 'sum'):
            pair = compare.query_pair(query, query)
            self.assertEqual(pair, dict(baseline=query, candidate=query))
        for baseline in ('all', 'count', 'sum'):
            with self.subTest(baseline=baseline), self.assertRaises(ValueError):
                compare.query_pair('compound', baseline)

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

    def test_value_count_oracle_matches_fixture_cells(self):
        with tempfile.TemporaryDirectory() as temporary:
            for shape in run.SHAPES:
                source = run.fixture(Path(temporary), shape, 31)
                column = source['fields'][1]['name']
                values = []
                for path in source['paths']:
                    opener = run.gzip.open if shape == 'gzip' else open
                    with opener(path, 'rt') as stream:
                        rows = run.csv.DictReader(stream) if source['format'] == 'csv' else map(json.loads, stream)
                        values.extend(row.get(column) for row in rows)
                present = sum(value is not None for value in values)
                for mode in ('explicit', 'partial', 'sampled', 'full'):
                    cfg = run.config(source, mode, 31, 8, False, 'count-values')
                    self.assertEqual(cfg['expected_output_rows'], 1)
                    self.assertEqual(cfg['expected_result_sum'], present)
                    self.assertEqual(cfg['expected_rows'], 31)
                with self.assertRaises(ValueError): run.config(source, 'raw', 31, 8, False, 'count-values')

    def matrix(self):
        records = self.records()
        for r in records[:-1]:
            r.update(first_batch_ns=None, allocations=2, allocated_bytes=64,
                source_bytes_read=100, source_read_calls=1, peak_live_bytes=128)
        return dict(definition=run.DEFINITION, completed=True, status='passed', dirty=False,
            parameters=dict(shapes=['narrow'], modes=['explicit'], caches=['warm_input'], engines=['transit'], repetitions=3, rows=3),
            fixtures=[], toolchain={}, filesystem='ext2/ext3',
            machine=dict(selected_cpu=0, platform='Linux', cpuinfo='model name: test'),
            harness={'tests/fuze_benchmarks/'+name:'fixed' for name in budgets.DRIVERS},
            comparator={k:'fixed' for k in ('duckdb', 'build', 'pyarrow', 'module_sha256')}, allocation_probe=dict(sha256='fixed'),
            samples=[dict(shape='narrow', mode='explicit', cache='warm_input', engine='transit', repetition=i,
                exit_code=0, image_peak_rss_kib=4096, input_pages=[], config=dict(expected_rows=3, expected_id_sum=3, expected_result_sum=3),
                records=copy.deepcopy(records)) for i in range(3)])

    def test_numeric_gate_rejects_regressions_and_changed_evidence(self):
        report = self.matrix(); limits = budgets.numeric_limits(report)
        self.assertEqual(budgets.check_matrix(report, limits), [])
        for metric, value in [('cpu_ns', 1_000_000), ('elapsed_ns', 1_000_000), ('allocations', 3),
                ('allocated_bytes', 65), ('source_bytes_read', 101), ('peak_live_bytes', 10000)]:
            changed = copy.deepcopy(report)
            for s in changed['samples']: s['records'][0][metric] = value
            self.assertTrue(budgets.check_matrix(changed, limits), metric)
        changed = copy.deepcopy(report); changed['samples'][0]['image_peak_rss_kib'] = 100000
        self.assertTrue(budgets.check_matrix(changed, limits))
        for change in ('failed', 'incomplete', 'dirty', 'missing', 'duplicate', 'result', 'cpu', 'driver', 'fixture'):
            changed = copy.deepcopy(report)
            if change == 'failed': changed['status'] = 'failed'
            elif change == 'incomplete': changed['completed'] = False
            elif change == 'dirty': changed['dirty'] = True
            elif change == 'missing': changed['samples'].pop()
            elif change == 'duplicate': changed['samples'].append(copy.deepcopy(changed['samples'][0]))
            elif change == 'result': changed['samples'][0]['records'][-1]['result_sum'] = 999
            elif change == 'cpu': changed['machine']['selected_cpu'] = 1
            elif change == 'driver': changed['harness']['tests/fuze_benchmarks/main.zig'] = 'other'
            else: changed['fixtures'] = ['other']
            with self.subTest(change=change), self.assertRaises(ValueError): budgets.check_matrix(changed, limits)

    def test_failed_gate_replaces_previous_success(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)/'result.json'; output.write_text('{"status":"passed"}')
            result = subprocess.run([sys.executable, str(Path(budgets.__file__)), 'check', temporary,
                str(Path(temporary)/'missing.json'), '--output', str(output)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            report = json.loads(output.read_text())
            self.assertEqual(report['status'], 'failed')
            self.assertFalse(report['completed'])


if __name__ == '__main__': unittest.main()

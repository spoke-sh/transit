"""Independent byte expectations and a broken-codec control for payload reports."""
import hashlib
import io
import json
from contextlib import redirect_stdout
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import pyarrow as pa
from performance.console.console_latency import representation_sample, local_trace
from performance.console import gate, resources
from performance.console.startup import timings as startup_timings, run as startup_run


class StartupTimings(unittest.TestCase):
    def test_failed_launch_is_reported_without_private_exception_text(self):
        fixture = type('Fixture', (), {'no_ui': True})()
        output = io.StringIO()
        with patch('performance.console.startup.start', side_effect=TimeoutError('private')), redirect_stdout(output):
            with self.assertRaises(TimeoutError):
                startup_run(fixture, 2)
        sample, = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(sample['outcome'], 'failed')
        self.assertEqual(sample['error_type'], 'TimeoutError')
        self.assertNotIn('private', output.getvalue())
        self.assertNotIn('first_verified_result_ns', sample)

    def trace(self, entries):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'startup.jsonl'
            path.write_text(''.join(json.dumps(entry) + '\n' for entry in entries))
            return startup_timings(path)

    def entries(self):
        return [dict(duration_ns=30, span_id='p1', parent_span_id='a',
                     event=dict(name='server.startup.phase', operation='node', outcome='ok')),
                dict(duration_ns=40, span_id='p2', parent_span_id='a',
                     event=dict(name='server.startup.phase', operation='sql_readiness', outcome='ok')),
                dict(duration_ns=80, span_id='a',
                     event=dict(name='server.startup.complete', outcome='ok'))]

    def test_phase_times_exclude_total_and_private_fields(self):
        entries = self.entries()
        entries[0]['event']['payload'] = 'private'
        result = self.trace(entries)
        self.assertEqual([p['duration_ns'] for p in result['phases']], [30, 40])
        self.assertEqual(result['attempts'][0]['duration_ns'], 80)
        self.assertEqual(result['attempts'][0]['unattributed_ns'], 10)
        self.assertNotIn('private', json.dumps(result))

    def test_work_is_nested_not_added_to_elapsed_time(self):
        entries = self.entries()
        child = dict(duration_ns=20, span_id='w', parent_span_id='p1',
                     event=dict(name='server.startup.work', operation='native_submit', outcome='ok'))
        entries.insert(0, child)
        result = self.trace(entries)
        self.assertEqual(result['attempts'][0]['unattributed_ns'], 10)
        self.assertEqual(result['work'][0]['duration_ns'], 20)
        child['duration_ns'] = 31
        with self.assertRaisesRegex(ValueError, 'overlapping startup work'):
            self.trace(entries)
        child['parent_span_id'] = 'missing'
        with self.assertRaisesRegex(ValueError, 'no terminal phase'):
            self.trace(entries)

    def test_missing_completion_losses_and_wrong_parent_cannot_pass(self):
        for changed in ('empty', 'terminal', 'loss', 'parent', 'overlap', 'duration', 'failed', 'restarted_after_ready'):
            entries = self.entries()
            if changed == 'empty':
                entries = []
            elif changed == 'terminal':
                entries.pop()
            elif changed == 'loss':
                entries.append(dict(name='telemetry.loss', measurement=dict(dropped=1)))
            elif changed == 'parent':
                entries[0]['parent_span_id'] = 'b'
            elif changed == 'overlap':
                entries[0]['duration_ns'] = 100
            elif changed == 'duration':
                del entries[0]['duration_ns']
            elif changed == 'restarted_after_ready':
                entries.extend(self.entries())
            else:
                entries[-1]['event']['outcome'] = 'failed'
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                self.trace(entries)

    def test_nested_sql_work_has_exclusive_costs_and_operation_counts(self):
        entries = self.entries()
        entries[:0] = [
            dict(duration_ns=12, span_id='submit', parent_span_id='enroll',
                 event=dict(name='server.startup.work', operation='authorization_publish', outcome='ok')),
            dict(duration_ns=20, span_id='enroll', parent_span_id='p1',
                 event=dict(name='server.startup.work', operation='sql_enrollment', outcome='ok')),
        ]
        result = self.trace(entries)
        self.assertEqual(result['work_totals']['sql_enrollment'],
                         dict(count=1, failed=0, duration_ns=20, exclusive_ns=8))
        self.assertEqual(result['work_totals']['authorization_publish']['exclusive_ns'], 12)
        self.assertEqual(result['phases'][0]['exclusive_ns'], 10)
        self.assertEqual(result['attempts'][0]['unattributed_ns'], 10)
        for invalid in ('cycle', 'orphan', 'duplicate', 'overlap'):
            damaged = json.loads(json.dumps(entries))
            if invalid == 'cycle':
                damaged[1]['parent_span_id'] = 'submit'
            elif invalid == 'orphan':
                damaged[1]['parent_span_id'] = 'a'
            elif invalid == 'duplicate':
                damaged[0]['span_id'] = 'p1'
            else:
                damaged[0]['duration_ns'] = 21
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                self.trace(damaged)


class Resources(unittest.TestCase):
    def test_units_and_unrelated_fields(self):
        self.assertEqual(resources.fields('Name: transit\nThreads:\t3\nPss: 17 kB\n',
                                          dict(Threads=False, Pss=True)),
                         dict(Threads=3, Pss=17408))

    def test_missing_malformed_and_duplicate_fields_fail(self):
        for text in ('', 'Pss: -1 kB', 'Pss: 17 MB', 'Pss: 17',
                     'Pss: 1 kB\nPss: 2 kB'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                resources.fields(text, dict(Pss=True))

    def test_process_identity_with_spaces_and_parentheses(self):
        stat = '42 (transit (worker)) S ' + '0 ' * 18 + '12345 999'
        self.assertEqual(resources.start_ticks(stat), 12345)
        with tempfile.TemporaryDirectory() as temporary:
            proc = Path(temporary)
            root = proc / '42'
            root.mkdir()
            (root / 'stat').write_text(stat)
            (root / 'status').write_text('Threads: 3\nVmRSS: 5 kB\nVmHWM: 7 kB\nVmSize: 11 kB')
            (root / 'smaps_rollup').write_text('Pss: 4 kB')
            result = resources.process(42, 'console', proc=proc)
            self.assertEqual(result['pss_bytes'], 4096)
            self.assertEqual(result['rss_bytes'], 5120)
            self.assertEqual(result['threads'], 3)
            with patch.object(resources, 'start_ticks', side_effect=[12345, 12346]):
                with self.assertRaisesRegex(ValueError, 'identity changed'):
                    resources.process(42, 'console', proc=proc)
            (root / 'smaps_rollup').unlink()
            with self.assertRaises(FileNotFoundError):
                resources.process(42, 'console', proc=proc)

    def test_tree_includes_descendants_once_and_rejects_overflow(self):
        graph = {1: {2, 3}, 2: {4}, 3: {4}, 4: set()}
        self.assertEqual(resources.tree([1, 2], discover=graph.__getitem__), {1, 2, 3, 4})
        with self.assertRaisesRegex(ValueError, 'bound'):
            resources.tree([1], discover=graph.__getitem__, limit=3)

    def test_changing_tree_cannot_report_a_complete_snapshot(self):
        with patch.object(resources, 'tree', side_effect=[{1, 2}, {1, 2, 3}]), \
             patch.object(resources, 'process', return_value={}):
            with self.assertRaisesRegex(ValueError, 'tree changed'):
                resources.snapshot(1, 2)


class LocalTrace(unittest.TestCase):
    def export(self, records):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'trace.jsonl'
            path.write_text(''.join(json.dumps(record) + '\n' for record in records))
            output = io.StringIO()
            with redirect_stdout(output):
                local_trace(path)
            return [json.loads(line) for line in output.getvalue().splitlines()]

    def test_only_reviewed_fields_and_cumulative_loss_are_exported(self):
        result = self.export([
            dict(name='telemetry.loss', measurement=dict(dropped=3, suppressed=2)),
            dict(name='telemetry.loss', measurement=dict(dropped=7, suppressed=2)),
            dict(event=dict(name='unrelated', payload='private')),
            dict(duration_ns=42, service_instance_id='private',
                 event=dict(name='transit.local.request', route='/table/v1',
                            operation='read', payload='private')),
        ])
        self.assertEqual(len(result), 2)
        self.assertEqual(result[0]['duration_ns'], 42)
        self.assertNotIn('private', json.dumps(result))
        self.assertEqual(result[-1], dict(phase='local_trace_summary', retained=1,
            omitted=0, losses=dict(dropped=7, suppressed=2, sink_errors=0)))

    def test_overflow_is_visible(self):
        result = self.export([dict(event=dict(name='transit.client.request'))] * 8193)
        self.assertEqual(result[-1]['retained'], 8192)
        self.assertEqual(result[-1]['omitted'], 1)

    def test_malformed_and_oversized_records_fail(self):
        with self.assertRaisesRegex(ValueError, 'bound'):
            self.export([dict(payload='x' * 2048)])


class Representations(unittest.TestCase):
    def test_row_and_column_order_keep_every_cell_and_length(self):
        batch = dict(schema='0102', observation={'metadata': {}},
                     rows=[['01', 'aabb'], ['02', 'cc']])
        result = representation_sample(batch)
        row = bytes.fromhex('010000000102000000aabb010000000201000000cc')
        column = bytes.fromhex('0100000001010000000202000000aabb01000000cc')
        for name, expected in (('rows', row), ('columns', column)):
            actual = result['layouts'][name]
            self.assertEqual(actual['bytes'], len(expected))
            self.assertEqual(actual['sha256'], hashlib.sha256(expected).hexdigest())
            self.assertEqual(set(actual['codecs']), {'lz4', 'zstd'})
        self.assertEqual(result['schema_json_bytes'], 6)

    def test_empty_terminal_has_no_cells(self):
        result = representation_sample(dict(schema='00', observation={}, rows=[]))
        for layout in result['layouts'].values():
            self.assertEqual(layout['bytes'], 0)
            self.assertEqual(layout['sha256'], hashlib.sha256(b'').hexdigest())

    def test_corrupt_roundtrip_cannot_be_reported_as_a_compression_win(self):
        with patch('pyarrow.decompress', return_value=pa.py_buffer(b'corrupt')):
            with self.assertRaisesRegex(AssertionError, 'codec changed'):
                representation_sample(dict(schema='00', observation={}, rows=[['01']]))


class ConsoleLatencyGate(unittest.TestCase):
    def sample_transcripts(self, budgets):
        workload = budgets['workload']
        startup_records = [
            dict(source_revision='rev-1', startup_restarts=workload['startup_restarts'],
                 startup_default=workload['startup_default'], startup_debug=False, instrumented=False),
            dict(phase='startup', index=0, profile='fresh', ui=True, outcome='ok', verified_rows=0,
                 ready_ns=int(budgets['startup']['fresh_ready_ms'] * 1_000_000),
                 first_verified_result_ns=int(budgets['startup']['fresh_first_verified_result_ms'] * 1_000_000),
                 verification_ns=500_000_000,
                 losses=dict(dropped=0, suppressed=0, sink_errors=0)),
            dict(phase='startup', index=1, profile='restart', ui=True, outcome='ok', verified_rows=1,
                 ready_ns=int(budgets['startup']['restart_ready_p50_ms'] * 1_000_000),
                 first_verified_result_ns=int(budgets['startup']['restart_first_verified_result_p50_ms'] * 1_000_000),
                 verification_ns=400_000_000,
                 losses=dict(dropped=0, suppressed=0, sink_errors=0)),
            dict(phase='startup', index=2, profile='restart', ui=True, outcome='ok', verified_rows=1,
                 ready_ns=int(budgets['startup']['restart_ready_p50_ms'] * 1_000_000),
                 first_verified_result_ns=int(budgets['startup']['restart_first_verified_result_p50_ms'] * 1_000_000),
                 verification_ns=400_000_000,
                 losses=dict(dropped=0, suppressed=0, sink_errors=0)),
        ]
        statement_records = [
            dict(source_revision='rev-1', repeat=workload['repeat'], cycles=workload['cycles'],
                 warm_reads=workload['warm_reads'], resource_snapshots=True,
                 instrumented=False, local_trace=False, historical_result_profile=False,
                 overrides=dict(worker_interval_ms=workload['worker_interval_ms'])),
            dict(phase='idle'),
        ]
        counts = gate.expected_statement_samples(workload)
        distributions = {}
        class_by_case = {
            case: class_name
            for class_name, cases in gate.STATEMENT_CLASSES.items()
            for case in cases
        }
        for cycle in range(workload['cycles']):
            for case in gate.STATEMENT_CASES:
                repeats = (1 if cycle == 0 else 0) if case == 'select_cold' else (
                    (0 if cycle == 0 else 1) if case == 'select_empty' else (
                        workload['warm_reads'] if case in ('select_empty_warm', 'select_one_warm', 'stream_consume_warm') else 1
                    )
                )
                timer_ms = int(budgets['statement_classes'][class_by_case[case]])
                for index in range(repeats):
                    statement_records.append(dict(phase='statement', cycle=cycle, case=case,
                                                  index=index, timer_ms=timer_ms))
                    statement_records.append(dict(
                        phase='client_resources',
                        cycle=cycle,
                        case=case,
                        index=index,
                        process_count=7,
                        threads=budgets['resources']['threads_max'],
                        pss_bytes=budgets['resources']['pss_bytes_max'],
                    ))
        for case, samples in counts.items():
            ms = float(int(budgets['statement_classes'][class_by_case[case]]))
            distributions[case] = dict(samples=samples, min_ms=ms, p50_ms=ms, p95_ms=ms, max_ms=ms)
        statement_records.append(dict(phase='statement_summary', distributions=distributions))
        statement_records.append(dict(phase='idle_after_statements'))
        return startup_records, statement_records

    def test_checked_in_budgets_and_threshold_math(self):
        budgets = json.loads(gate.BUDGETS.read_text())
        self.assertEqual(budgets['version'], 1)
        self.assertEqual(budgets['definition'], gate.DEFINITION)
        self.assertEqual(budgets['max_regression_pct'], 20.0)
        self.assertEqual(budgets['fast_read_threshold_ms'], 50.0)
        self.assertEqual(budgets['fast_read_noise_floor_ms'], 15.0)
        self.assertEqual(budgets['workload'], gate.DEFAULT_WORKLOAD)
        self.assertEqual(set(budgets['statement_classes']), set(gate.STATEMENT_CLASSES))
        self.assertEqual(set(budgets['statements']), set(gate.STATEMENT_CASES))
        self.assertEqual(gate.limit_ms(30.0, budgets), 51.0)
        self.assertEqual(gate.limit_ms(600.0, budgets), 720.0)

    def test_baseline_passes_and_freezes_cleanly(self):
        budgets = json.loads(gate.BUDGETS.read_text())
        startup_records, statement_records = self.sample_transcripts(budgets)
        evaluation = gate.assess(startup_records, statement_records, budgets)
        self.assertEqual(evaluation['status'], 'passed')
        self.assertEqual(evaluation['violations'], [])
        frozen = gate.freeze_budgets([(startup_records, statement_records)], workload=budgets['workload'])
        self.assertEqual(frozen['calibrated_revision'], 'rev-1')
        self.assertEqual(gate.assess(startup_records, statement_records, frozen)['status'], 'passed')

    def test_regressions_and_incomplete_runs_fail(self):
        budgets = json.loads(gate.BUDGETS.read_text())
        startup_records, statement_records = self.sample_transcripts(budgets)
        startup_records[1]['ready_ns'] = int(gate.limit_ms(budgets['startup']['fresh_ready_ms'], budgets) * 1_000_000) + 10_000_000
        statement_records[-2]['distributions']['select_empty_warm']['p50_ms'] = (
            gate.limit_ms(budgets['statements']['select_empty_warm'], budgets) + 1.0
        )
        for row in statement_records[1:]:
            if row.get('phase') == 'statement' and row.get('case') == 'insert':
                row['timer_ms'] = int(gate.limit_ms(budgets['statement_classes']['dml_write'], budgets)) + 50
            if row.get('phase') == 'client_resources' and row.get('cycle') == 4:
                row['threads'] = budgets['resources']['threads_max'] * 2
                row['pss_bytes'] = int(budgets['resources']['pss_bytes_max'] * 1.3)
        evaluation = gate.assess(startup_records, statement_records, budgets)
        self.assertEqual(evaluation['status'], 'failed')
        violated = {(row['category'], row['metric']) for row in evaluation['violations']}
        self.assertIn(('startup', 'fresh_ready_ms'), violated)
        self.assertIn(('statements', 'select_empty_warm'), violated)
        self.assertIn(('resources', 'threads_max'), violated)
        self.assertIn(('resources', 'pss_bytes_max'), violated)
        self.assertIn(('resources', 'cycle_pss_growth_ratio'), violated)

        for invalid in ('instrumented', 'loss', 'statement_failure', 'missing_idle', 'process_count'):
            s_records, st_records = self.sample_transcripts(budgets)
            if invalid == 'instrumented':
                s_records[0]['instrumented'] = True
            elif invalid == 'loss':
                s_records[1]['losses']['dropped'] = 1
            elif invalid == 'statement_failure':
                st_records.insert(2, dict(phase='statement_failure', error='timeout'))
            elif invalid == 'missing_idle':
                st_records.pop()
            else:
                st_records[3]['process_count'] = 6
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                gate.assess(s_records, st_records, budgets)


if __name__ == '__main__':
    unittest.main()

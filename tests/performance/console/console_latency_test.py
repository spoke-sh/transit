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
from performance.console import resources


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


if __name__ == '__main__':
    unittest.main()

"""Independent byte expectations and a broken-codec control for payload reports."""
import hashlib
import unittest
from unittest.mock import patch

import pyarrow as pa
from performance.console.console_latency import representation_sample


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

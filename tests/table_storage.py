#!/usr/bin/env python3
"""Independent typed Table storage keys, envelopes and native-definition binding."""
import argparse
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'packages/zig/transit-station/src/fixtures/table-storage.json'


def fixtures():
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    contract = bytes.fromhex(definition)
    schema = struct.pack('<QII', 7, 0x54534301, 120) + bytes([17]) * 32
    minimum = b'R' + struct.pack('>QQI', 2, 30, 0)
    index = struct.pack('<QII', 9, 0x53495801, 180) + bytes([34]) * 32
    head = b'STH1' + contract + struct.pack('<QQQ', 7, 9, 4) + schema + b'\1'
    head += index + bytes([0, len(minimum)]) + minimum + struct.pack('<Q', 3)
    head += struct.pack('<QQQB', 3, 10, 0, 0)
    assert len(head) == 213
    payload = b'typed page'
    status = b'STW1' + contract + struct.pack('<QQQQ', 7, 9, 1, 21) + bytes([51]) * 32
    status += struct.pack('<QQQQQQQBBB', 12, 15, 1, 2, 5, 1, 1, 2, 0, 1)
    status += bytes(95)  # mandatory empty execution witness
    assert len(status) == 254
    rejected = status[:100] + struct.pack('<QQQQQQQBBB', 12, 15, 1, 2, 5, 0, 0, 3, 1, 2)
    rejected += b'\1' + struct.pack('>QQI', 2, 21, 4) + struct.pack('<QBB', 0, 1, 0) + b'5' + bytes(63)
    assert len(rejected) == 254
    progress = b'STG1' + contract + bytes([51]) * 32 + struct.pack('<Q', 8) + b'\1'
    progress += index + bytes([0, len(minimum)]) + minimum + struct.pack('<Q', 3)
    progress += b'\1' + struct.pack('>QQI', 2, 30, 1) + struct.pack('<IQQ', 0, 2, 1)
    assert len(progress) == 197
    cleanup = b'STX1' + contract + bytes([51]) * 32 + struct.pack('<QQQB', 2, 600, 199, 2)
    assert len(cleanup) == 93
    return {
        'native_definition': definition,
        'manifest_hex': (b'STM1' + contract + struct.pack('<I', 65536)).hex(),
        'inline_hex': (b'STP1' + struct.pack('<IH', 0x54534301, len(payload)) + payload).hex(),
        'head_hex': head.hex(),
        'head_key_hex': (b'\0P' + struct.pack('>IQBQI', 8, 9, ord('h'), 0, 0)).hex(),
        'page_key_hex': (b'\0P' + struct.pack('>IQBQI', 8, 9, ord('i'), 7, 0)).hex(),
        'write_key_hex': (b'\0W' + struct.pack('>QQQ', 9, 1, 21)).hex(),
        'write_status_hex': status.hex(),
        'write_rejection_hex': rejected.hex(),
        'statement_progress_hex': progress.hex(),
        'statement_progress_key_hex': (b'\0G' + struct.pack('>QQQ', 9, 1, 21)).hex(),
        'cleanup_hex': cleanup.hex(),
        'cleanup_key_hex': (b'\0X' + struct.pack('>QQQ', 9, 1, 21)).hex(),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record', action='store_true')
    args = parser.parse_args()
    encoded = json.dumps(fixtures(), indent=2) + '\n'
    if args.record:
        FIXTURE.write_text(encoded)
    elif not FIXTURE.is_file() or FIXTURE.read_text() != encoded:
        raise SystemExit('Typed Table storage fixtures drifted; review the current format before --record.')
    print('Typed Table storage: independent head, page, manifest, receipt, statement progress and namespace bytes passed.')


if __name__ == '__main__':
    main()

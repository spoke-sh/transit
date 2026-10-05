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
    return {
        'native_definition': definition,
        'manifest_hex': (b'STM1' + contract + struct.pack('<I', 65536)).hex(),
        'inline_hex': (b'STP1' + struct.pack('<IH', 0x54534301, len(payload)) + payload).hex(),
        'head_hex': head.hex(),
        'head_key_hex': (b'\0P' + struct.pack('>IQBQI', 8, 9, ord('h'), 0, 0)).hex(),
        'page_key_hex': (b'\0P' + struct.pack('>IQBQI', 8, 9, ord('i'), 7, 0)).hex(),
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
    print('Typed Table storage: independent head, inline page, manifest and namespace bytes passed.')


if __name__ == '__main__':
    main()

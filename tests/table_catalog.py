#!/usr/bin/env python3
"""Independent direct Table query descriptors and authorization policy bytes."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
QUERY_FIXTURE = ROOT / 'packages/zig/transit-query/src/fixtures/table-source.json'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record', action='store_true')
    args = parser.parse_args()
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    # A query declaration carries the direct interpretation/content/schema
    # commitments and its logical descriptor. These synthetic commitments test
    # the descriptor wire format, independently of admission and schema codecs.
    contract = bytes.fromhex(definition)
    types = b'transit.fuze.types.v1.2026-09-30'
    logical = b'FTY1' + bytes([len(types)]) + types
    logical += b'\x16\x02\x02id\0\x0a\x07payload\x01\x19\x05\x01\x17\x01\x09'
    declaration = b'TQS1' + contract + struct.pack('<QQQQQQQQ', 1, 7, 2**64-1, 3, 1, 1, 2**64-1, 3)
    declaration += bytes([17])*32 + struct.pack('<Q', 200) + bytes([34])*32
    declaration += struct.pack('<H', len(logical)) + logical
    assert len(declaration) == 174 + len(logical)
    query = {'wire_hex': declaration.hex(), 'fingerprint_hex': hashlib.sha256(b'transit.table.query.declaration.v1\0' + declaration).hexdigest()}
    policies = []
    for tag, body in ((1, bytes.fromhex(query['fingerprint_hex'])), (2, struct.pack('<QQQQQ', 1, 7, 2**64-1, 3, 17))):
        policy = b'UQA1' + contract + struct.pack('<QQQ', 9, 8, 1) + bytes([tag]) + body + b'\1' + struct.pack('<QQQ', 100, 200, 1048576)
        assert len(policy) == (118 if tag == 1 else 126)
        policies.append(dict(wire_hex=policy.hex(), target=tag))
    for path, value in ((QUERY_FIXTURE, query), (QUERY_FIXTURE.with_name('query-policy.json'), policies)):
        encoded = json.dumps(value, indent=2) + '\n'
        if args.record:
            path.write_text(encoded)
        elif not path.is_file() or path.read_text() != encoded:
            raise SystemExit(f'Direct Table query fixtures drifted: {path}; review the current format before --record.')
    print('Direct Table query source and policy: independent descriptor bytes passed.')


if __name__ == '__main__':
    main()

"""Independent canonical routing, segment and durable exchange byte fixtures."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

from relational import identity_fixture

ROOT = Path(__file__).resolve().parents[1]


def route(value, partitions):
    encoded = b'transit.relational.partition.v1\0\1'
    encoded += b'\0' if value is None else b'\1' + struct.pack('<q', value)
    return int.from_bytes(hashlib.sha256(encoded).digest()[:8], 'little') % partitions


def fixtures():
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    contract = bytes.fromhex(definition)
    binding = bytes.fromhex(identity_fixture()['bound'])
    segment = b'FXS1' + contract + binding + struct.pack('<QB4QBB', 88, 0, 7, route(7, 7), 3, 0, 1, 2)
    for operation, value in [(1, 9), (2, None)]:
        segment += struct.pack('>QQI', 1, operation, 0) + b'\1' + struct.pack('<q', 7)
        segment += b'\0' if value is None else b'\1' + struct.pack('<q', value)
    fuze = dict(definition=definition, segment=segment.hex(),
                routing=[dict(key=value, partitions=count, partition=route(value, count))
                         for count in [1, 2, 7, 257, 2**64 - 1]
                         for value in [None, 0, -1, 7, -(2**63), 2**63 - 1]])
    remote = b'SPF1' + struct.pack('<QIQQII', 8, 10, 88, 1, 0x31535846, len(segment)) + bytes([17]) * 32
    local = b'SPF1' + struct.pack('<QIQQII', 7, 10, 88, 2, 0x31535846, len(segment)) + bytes([17]) * 32
    head = b'RXH1' + contract + bytes([19]) * 32 + struct.pack('<13Q3B',
        88, 3, 7, 7, 0, 0, 1, 0, 0, 0, 65536, 16384, 2, 2, 0, 0)
    channel = b'RXC1' + contract + struct.pack('<6Q3B', 4, 8, 0, 0, 0, 2**64-1, 0, 0, 0) + bytes(20)
    pending = b'RXP1' + contract + struct.pack('<BQQ', 0, route(7, 7), 0) + remote
    accepted = b'RXA1' + contract + remote + local
    row = b'RXR1' + contract + local + b'\1'
    producer = b'RXB1' + contract + bytes([19]) * 32 + struct.pack('<6QB', 88, 4, 8, 65536, 1024, 0, 1) + remote
    assert len(producer) == 189
    cursor = b'RXW1' + contract + binding + struct.pack('<9QBB', 99, 7, 3, 1, 1, 0, 3, 1, 8, 4, 1) + struct.pack('>QQI', 1, 3, 0)
    assert len(cursor) == 162
    assert tuple(map(len, [head, channel, pending, accepted, row])) == (175, 107, 125, 180, 109)
    query = dict(definition=definition, head=head.hex(), channel=channel.hex(), pending=pending.hex(),
                 accepted=accepted.hex(), row=row.hex(), producer=producer.hex(), cursor=cursor.hex(),
                 key=(b'\0xa' + struct.pack('>QBQQ', 88, 0, route(7, 7), 0)).hex(),
                 row_key=(b'\0xr' + struct.pack('>QBQQI', 88, 1, 1, 2, 0)).hex())
    return {'transit-fuze': fuze, 'transit-query': query}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    for package, fixture in fixtures().items():
        path = ROOT / 'packages/zig' / package / 'src/fixtures/relational-exchange.json'
        encoded = json.dumps(fixture, indent=2) + '\n'
        if args.write:
            path.write_text(encoded)
        elif path.read_text() != encoded:
            raise SystemExit('Exchange wire fixtures drifted; review before --write')
    print('Exchange: 30 independent routes, exact source segment, control records and paged keys passed.')

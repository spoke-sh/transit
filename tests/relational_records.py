"""Independent layouts for maintained relational control and work records."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'packages/zig/transit-query/src/fixtures/relational-maintenance.json'


def fixtures():
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    contract = bytes.fromhex(definition)
    reference = b'SPF1' + struct.pack('<QIQQII', 7, 2, 9, 1, 0x31425152, 100) + bytes([17]) * 32
    assert len(reference) == 72
    head = b'RMH1' + contract + struct.pack('<9Q', 11, 3, 5, 1, 0, 0, 1, 0, 11)
    head += reference + struct.pack('<QQB2Q6B', 3, 11, 0, 17, 19, 2, 0, 0, 1, 1, 0)
    work = b'RMW1' + contract + struct.pack('<11Q', 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0)
    work += hashlib.sha256(b'transit.query.relational.outputs.v1\0').digest()
    work += hashlib.sha256(b'transit.relational.delta-transactions.v1\0').digest() + b'\1'
    delta_reference = b'SPF1' + struct.pack('<QIQQII', 7, 3, 9, 2, 0x31445246, 100) + bytes([17]) * 32
    delta = b'RMD1' + contract + struct.pack('<Q', 3) + delta_reference
    assert len(delta) == 116
    continuation = b'RMC1' + contract + struct.pack('<3Q', 3, 5, 11)
    assert (len(head), len(work), len(continuation)) == (219, 189, 60)
    return dict(definition=definition, selection=(b'RMX1' + contract + reference).hex(),
                exchange=(b'RMI1' + contract + bytes([23]) * 32 + struct.pack('<Q', 88)).hex(), delta=delta.hex(), head=head.hex(), work=work.hex(), continuation=continuation.hex(),
                key=(b'\0rmh' + struct.pack('>3Q', 3, 5, 0)).hex())


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    encoded = json.dumps(fixtures(), indent=2) + '\n'
    if args.write:
        FIXTURE.write_text(encoded)
    elif FIXTURE.read_text() != encoded:
        raise SystemExit('Maintained record layouts drifted; review before --write')
    print('Maintained records: independent head/work/continuation/delta bytes and scoped key passed.')

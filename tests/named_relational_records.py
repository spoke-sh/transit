"""Independent canonical layouts for the application-owned relational namespace."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'packages/zig/transit-station-app/src/fixtures/named-relational-v1.json'


def fixtures():
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    contract = bytes.fromhex(definition)
    scope = struct.pack('<4Q', 1, 7, 3, (1 << 64)-1)
    name = bytes([6]) + b'totals' + bytes(15)
    identity = scope + name + struct.pack('<2Q', (1 << 64)-2, (1 << 64)-3)
    request = b'SPF1' + struct.pack('<QIQQII', 7, 2, 9, 1, 0x31425152, 100) + bytes([17])*32
    body = b'NRD1' + contract + identity + struct.pack('<Q', 3) + request + struct.pack('<QQB', 3, 99, 0) + bytes([23])*32 + b'\2'
    digest = hashlib.sha256(b'transit.application.named-relational.v1\0' + body).digest()
    ref = b'NRR1' + contract + identity + digest
    policy = struct.pack('<4Q', 3, 7, 17, 19) + bytes([23])*32 + b'\1'
    archive = b'NRP1' + contract + identity + digest + policy
    activation = b'NRA1' + contract + identity + digest + struct.pack('<Q', 19)
    configuration = b'NRC1' + contract + scope + struct.pack('<3Q', 17, 4096, 33554432)
    budget = b'NRB1' + contract + struct.pack('<2Q', 2, 144)
    publish = b'NRU1' + contract + name + struct.pack('<3Q', (1 << 64)-2, (1 << 64)-4, 3) + request
    authorize = b'NRG1' + contract + identity + digest + struct.pack('<2Q', 18, 17) + b'\1'
    assert tuple(map(len, (body, ref, archive, activation, configuration, budget, publish, authorize))) == (236, 138, 203, 146, 92, 52, 154, 155)
    return dict(definition=definition, record=body.hex(), reference=ref.hex(), digest=digest.hex(), archive=archive.hex(), activation=activation.hex(), configuration=configuration.hex(), budget=budget.hex(), initialize=(b'NRI1'+contract).hex(), publish=publish.hex(), authorize=authorize.hex(), name_key=(b'\0Nn'+struct.pack('>Q', (1 << 64)-1)+b'totals').hex(), definition_key=(b'\0Nd'+struct.pack('>3Q', (1 << 64)-1, (1 << 64)-2, (1 << 64)-3)).hex(), authorization_key=(b'\0Na'+struct.pack('>2Q', 3, 19)).hex())


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    encoded = json.dumps(fixtures(), indent=2) + '\n'
    if args.write:
        FIXTURE.write_text(encoded)
    elif FIXTURE.read_text() != encoded:
        raise SystemExit('Named relational records drifted; review before --write')
    print('Named relational records: independent controls, digests, immutable attribution and exact keys passed.')

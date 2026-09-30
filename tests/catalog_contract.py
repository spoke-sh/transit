"""Independent catalog v1 records and full-width identity fixtures."""
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'packages/zig/transit-catalog/src/fixtures/catalog-v1.json'
NEUTRAL = FIXTURE.with_name('catalog-neutral-v1.json')


def generate():
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    maximum = 2**64 - 1
    scope = struct.pack('<QQQ', 1, 7, maximum)
    schema = b'TBL1\3\2id\5value'
    name = b'\5items'

    def record(tag, body):
        return b'TCA1' + tag.encode() + bytes.fromhex(definition) + body

    request = scope + struct.pack('<QQI', maximum, maximum, 9) + name + bytes([len(schema)]) + schema
    immutable = record('d', scope + struct.pack('<QQ', maximum, 1) + name + b'\1' + struct.pack('<I', 9)
                       + bytes([len(schema)]) + schema + struct.pack('<QQQ', 17, maximum, 2))
    digest = hashlib.sha256(b'transit.catalog.definition.v1\0' + immutable).digest()
    records = dict(configuration=record('c', scope + struct.pack('<QQ', 3, 17)),
                   policy=record('p', scope + struct.pack('<QQBB', 17, 1, 1, 1)),
                   request=record('q', request), definition=immutable,
                   binding=record('n', scope + struct.pack('<QQ', maximum, 1) + digest))
    for outcome in range(1, 5):
        records[f'receipt_{outcome}'] = record('o', request + struct.pack('<QQB', 17, 2, outcome))
    records['policy_change'] = record('g', struct.pack('<Q', 0) + scope + struct.pack('<QQBB', 17, 1, 1, 1))
    payload = hashlib.sha256(b'transit.catalog.input.v1\0catalog-command').digest()
    records['disposition'] = record('e', scope + struct.pack('<BQQ', 1, 17, 2) + payload + b'\1')
    prefix = b'\0C' + struct.pack('>Q', maximum)
    keys = dict(configuration=prefix + b'c' + struct.pack('>QQ', 0, 0),
                policy=prefix + b'p' + struct.pack('>QQ', 17, 0),
                definition=prefix + b'd' + struct.pack('>QQ', maximum, 1),
                binding=prefix + b'nitems',
                receipt=prefix + b'o' + struct.pack('>QQ', 17, maximum),
                disposition=prefix + b'e' + struct.pack('>QQ', 2, 0))
    return json.dumps(dict(version=1, native_definition=definition, digest=digest.hex(),
                           records={k: v.hex() for k, v in records.items()},
                           keys={k: v.hex() for k, v in keys.items()}), indent=2) + '\n'


def neutral(encoded):
    records = json.loads(encoded)['records']
    scope = dict(realm=1, resource=7, catalog=str(2**64 - 1))
    configuration = dict(scope=scope, owner=3, administrator=17)
    policy = dict(scope=scope, principal=17, revision='1', inspect=True, create=True)
    request = dict(scope=scope, operation=str(2**64 - 1), object=str(2**64 - 1), table=9,
                   name='items', schema=dict(names=['id', 'value'], value_type='utf8'))
    change = dict(expected_revision='0', policy=policy)
    disposition = dict(scope=scope, origin='external', principal=17, input=2,
                       payload=hashlib.sha256(b'transit.catalog.input.v1\0catalog-command').hexdigest(),
                       outcome='initialized')
    return json.dumps(dict(connection=dict(scope=scope, owner=3, principal=17),
                           configuration=configuration, policy=policy, change=change,
                           compiled=dict(request=request, canonical=records['request']),
                           receipt=dict(request=request, principal=17, input=2, outcome='applied'),
                           disposition=disposition), indent=2) + '\n'


if __name__ == '__main__':
    expected = generate()
    expected_neutral = neutral(expected)
    if sys.argv[1:] == ['--write']:
        FIXTURE.parent.mkdir(parents=True, exist_ok=True)
        FIXTURE.write_text(expected)
        NEUTRAL.write_text(expected_neutral)
    elif sys.argv[1:]:
        raise SystemExit('usage: catalog_contract.py [--write]')
    else:
        assert FIXTURE.read_text() == expected, 'catalog v1 fixtures drift; regenerate explicitly'
        assert NEUTRAL.read_text() == expected_neutral, 'catalog neutral fixtures drift; regenerate explicitly'
        print('Catalog v1: independent records, keys, digests and neutral caller values passed.')

"""Independent FZP2/schema encodings for the shared v2 query fixtures."""
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'packages/zig/transit-fuze/src/fixtures/unified.json'
BUNDLES = ROOT / 'packages/zig/transit-query/src/fixtures/bundles.json'
SOURCES = ROOT / 'packages/zig/transit-query/src/fixtures/sources.json'


def generate():
    variants = [
        ('signed-min', 1, struct.pack('<q', -(2**63))),
        ('unsigned-max', 2, struct.pack('<Q', 2**64-1)),
        ('negative-zero', 3, struct.pack('<d', -0.0)),
        ('boolean', 4, b'\1'),
        ('unicode', 5, struct.pack('<I', len('café é 🙂'.encode())) + 'café é 🙂'.encode()),
        ('binary', 6, struct.pack('<I', 3) + b'\0\xff\x80'),
        ('larger-plan', 5, struct.pack('<I', 512) + b'x'*512),
    ]
    cases = []
    for name, tag, literal in variants:
        # rows, two ordered columns, explicit full-width limit, comparison ne.
        wire = b'FZP2\0\2\1\0\1' + struct.pack('<Q', 2**64-1) + bytes((2, 1, 1, tag)) + literal
        cases.append(dict(name=name, type=tag, wire_hex=wire.hex(), digest=hashlib.sha256(b'transit.fuze.plan.v2\0'+wire).hexdigest()))
    columns = [('key', 2), ('value', 5)]
    schema = b'transit.fuze.schema.v2\0' + bytes((len(columns),))
    for name, tag in columns: schema += bytes((len(name), tag)) + name.encode()
    return json.dumps(dict(plans=cases, schema=hashlib.sha256(schema).hexdigest()), ensure_ascii=False, indent=2)+'\n'


def sources():
    def source(tag, payload): return b'UQS2' + struct.pack('<QB', 7, tag) + payload
    def projection(name, mode):
        field = name.encode()
        return bytes((len(field),)) + field + bytes((5, 0, mode)) + struct.pack('<HH', 4096, 4096) + bytes((1, len(field))) + field
    table = b'TBL1\3\2id\5label'
    reference = b'SDR1' + struct.pack('<QQQIQ', 7, 2**64-1, 3, 1, 42)
    variants = [
        ('kv', source(1, b'\5data/\1\6\1\2')),
        ('table', source(2, struct.pack('<IB', 9, len(table)) + table)),
        ('document', source(3, reference + struct.pack('<IBB', 1, 0, 2) + projection('title', 0) + projection('body', 1))),
    ]
    return json.dumps([dict(kind=kind, wire_hex=wire.hex(), digest=hashlib.sha256(b'transit.query.source.v2\0'+wire).hexdigest()) for kind, wire in variants], indent=2)+'\n'


def bundles():
    plans = json.loads(generate())['plans']
    definitions = json.loads(sources())
    limits = struct.pack('<QQQ', 1000, 500, 1048576)
    result = []
    for definition in definitions:
        source = bytes.fromhex(definition['wire_hex'])
        selected = 'unsigned-max' if definition['kind'] == 'kv' else 'larger-plan'
        plan = bytes.fromhex(next(p['wire_hex'] for p in plans if p['name'] == selected))
        bundle = b'UQB2' + struct.pack('<HH', len(source), len(plan)) + limits + source + plan
        initial = hashlib.sha256(b'transit.station.publication.v1\0' + struct.pack('<II', 0x32425155, len(bundle))).digest()
        digest = initial
        for index, offset in enumerate(range(0, len(bundle), 256)):
            part = bundle[offset:offset+256]
            digest = hashlib.sha256(b'\1' + digest + struct.pack('<IH', index, len(part)) + part).digest()
        ref = b'SPF1' + struct.pack('<QQQII', 8, 2**64-1, 1, 0x32425155, len(bundle)) + digest
        result.append(dict(kind=definition['kind'], wire_hex=bundle.hex(), reference_hex=ref.hex()))
    return json.dumps(result, indent=2)+'\n'


if __name__ == '__main__':
    if sys.argv[1:] == ['--write']:
        FIXTURE.parent.mkdir(exist_ok=True)
        FIXTURE.write_text(generate())
        SOURCES.parent.mkdir(exist_ok=True)
        SOURCES.write_text(sources())
        BUNDLES.write_text(bundles())
    elif sys.argv[1:] or FIXTURE.read_text() != generate() or SOURCES.read_text() != sources() or BUNDLES.read_text() != bundles():
        raise SystemExit('Unified query fixtures differ; review and regenerate explicitly')
    print('Unified query fixtures: independent schemas, source definitions and full-width/larger FZP2 plans passed.')

"""Independent FZP1/schema encodings for the shared v1 query fixtures."""
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'packages/zig/transit-fuze/src/fixtures/unified.json'
UPLOADS = ROOT / 'packages/zig/transit-query/src/fixtures/uploads.json'
BUNDLES = ROOT / 'packages/zig/transit-query/src/fixtures/bundles.json'
SOURCES = ROOT / 'packages/zig/transit-query/src/fixtures/sources.json'
OUTPUT_NAMES = ROOT / 'packages/zig/transit-fuze/src/fixtures/output-names-v1.json'
BOOLEAN_PLANS = ROOT / 'packages/zig/transit-fuze/src/fixtures/boolean-plans-v1.json'
PLAN_DEFINITION = hashlib.sha256(b'transit.fuze.plan.v1.boolean-programs.count-values.2026-10-01').digest()


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
        wire = b'FZP1' + PLAN_DEFINITION + b'\0\2\1\0\0\0\1' + struct.pack('<Q', 2**64-1) + bytes((2, 1, 1, tag)) + literal
        cases.append(dict(name=name, type=tag, wire_hex=wire.hex(), digest=hashlib.sha256(b'transit.fuze.plan.v1\0'+wire).hexdigest()))
    columns = [('key', 2), ('value', 5)]
    schema = b'transit.fuze.schema.v1\0' + bytes((len(columns),))
    for name, tag in columns: schema += bytes((len(name), tag)) + name.encode()
    return json.dumps(dict(plans=cases, schema=hashlib.sha256(schema).hexdigest()), ensure_ascii=False, indent=2)+'\n'


def output_names():
    cases = []
    for label, projection, aliases, aggregate, columns in [
        ('renamed-row', [1, 0], ['amount', None], 0, ['amount', 'id']),
        ('repeated-input', [0, 0], ['left_id', 'right_id'], 0, ['left_id', 'right_id']),
        ('renamed-count', [0], ['total'], 1, ['total']),
        ('renamed-sum', [0], ['Total'], 2, ['Total']),
        ('renamed-value-count', [1], ['present'], 3, ['present']),
        ('value-count', [1], [None], 3, ['count']),
        ('unchanged-row', [0, 1], [None, None], 0, ['id', 'value']),
    ]:
        wire = b'FZP1' + PLAN_DEFINITION + bytes([aggregate, len(projection), *projection])
        for alias in aliases:
            raw = alias.encode() if alias is not None else b''
            wire += bytes([len(raw)]) + raw
        wire += b'\0' + struct.pack('<Q', 0) + b'\0'
        cases.append(dict(name=label, projection=projection, output_names=aliases,
                          aggregate=['rows', 'count', 'sum', 'count_values'][aggregate], encoded=wire.hex(), columns=columns))
    return json.dumps(dict(version=1, definition=PLAN_DEFINITION.hex(), cases=cases), indent=2)+'\n'


def boolean_plans():
    cases = []
    for fixture in json.loads(generate())['plans']:
        atom = bytes.fromhex(fixture['wire_hex'])[51:]
        assert atom[:3] == bytes([2, 1, 1])
        # NOT (value = literal) OR value IS NULL; preserve all scalar encodings.
        atom = bytes([2, 0, 0]) + atom[3:]
        instructions = atom + bytes([3, 1, 0, 1, 5])
        wire = b'FZP1' + PLAN_DEFINITION + bytes([0, 1, 0, 0, 0]) + struct.pack('<Q', 0)
        wire += bytes([3, 4]) + instructions
        cases.append(dict(name=fixture['name'], type=fixture['type'], wire_hex=wire.hex(),
                          digest=hashlib.sha256(b'transit.fuze.plan.v1\0' + wire).hexdigest()))
    return json.dumps(dict(version=1, cases=cases), indent=2) + '\n'


def current_definition():
    return bytes.fromhex(json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition'])


def logical_schema(kind):
    types = b'transit.fuze.types.v1.2026-09-30'
    columns = [('key', 6, 3), ('value', 2, 3)] if kind == 'kv' else [('id', 1, 0), ('label', 5, 1)] if kind == 'table' else [('title', 5, 3), ('body', 5, 3)]
    return b'FTY1' + bytes([len(types)]) + types + bytes([22, len(columns)]) + b''.join(bytes([len(name)]) + name.encode() + bytes([flags, tag]) for name, tag, flags in columns)


def sources():
    definition = current_definition()
    def source(tag, payload): return b'UQS1' + definition + struct.pack('<QB', 7, tag) + payload
    def projection(name, mode):
        field = name.encode()
        return bytes((len(field),)) + field + bytes((5, 0, mode)) + struct.pack('<HH', 4096, 4096) + bytes((1, len(field))) + field
    descriptor = logical_schema('table')
    table = (b'TQS1' + definition + struct.pack('<QQQQQQQQ', 1, 7, 9, 3, 1, 1, 9, 1) +
             bytes([1])*32 + struct.pack('<Q', 200) + bytes([2])*32 +
             struct.pack('<H', len(descriptor)) + descriptor + b'\0\0')
    reference = b'SDR1' + struct.pack('<QQQIQ', 7, 2**64-1, 3, 1, 42)
    variants = [
        ('kv', source(1, b'\5data/\1\6\1\2')),
        ('table', source(2, struct.pack('<H', len(table)) + table)),
        ('document', source(3, reference + struct.pack('<IBB', 1, 0, 2) + projection('title', 0) + projection('body', 1))),
    ]
    return json.dumps([dict(kind=kind, wire_hex=wire.hex(), digest=hashlib.sha256(
        b'transit.table.query.declaration.v1\0'+table if kind == 'table' else b'transit.query.source.v1\0'+wire).hexdigest()) for kind, wire in variants], indent=2)+'\n'


def bundles():
    limits = struct.pack('<QQQ', 1000, 500, 1048576)
    result = []
    plan_definition = hashlib.sha256(b'transit.fuze.logical-plan.v1:bound-schema:ordered-predicates:output-names:nullable-parameters:collations').digest()
    for declaration in json.loads(sources()):
        kind = declaration['kind']
        source = bytes.fromhex(declaration['wire_hex'])
        schema = hashlib.sha256(logical_schema(kind)).digest()
        head = b'FQP1' + plan_definition + bytes.fromhex(declaration['digest']) + schema
        literal = b'\3' + (struct.pack('<Q', 2**64-1) if kind == 'kv' else struct.pack('<I', 512) + b'x'*512)
        predicate = bytes([2, 1, 1]) + struct.pack('<H', len(literal)) + literal
        suffix = b'\1' + struct.pack('<Q', 2**64-1) + predicate
        plan = head + bytes([0, 2, 1, 0, 0, 0]) + suffix + b'\0\0'
        named = head + bytes([0, 2, 1, 0, 6]) + b'Result' + b'\0' + suffix + b'\0\0'
        counted = head + bytes([3, 1, 1, 7]) + b'present' + b'\0' + struct.pack('<Q', 0) + b'\0\0\0'
        def bundle(plan):
            return b'UQB1' + current_definition() + struct.pack('<HH', len(source), len(plan)) + limits + b'\0\0' + source + plan
        wire = bundle(plan)
        digest = hashlib.sha256(b'transit.station.publication.v1\0' + struct.pack('<II', 0x31425155, len(wire))).digest()
        for index, offset in enumerate(range(0, len(wire), 256)):
            part = wire[offset:offset+256]
            digest = hashlib.sha256(b'\1' + digest + struct.pack('<IH', index, len(part)) + part).digest()
        ref = b'SPF1' + struct.pack('<QIQQII', 8, 2, 2**64-1, 1, 0x31425155, len(wire)) + digest
        result.append(dict(kind=kind, wire_hex=wire.hex(), reference_hex=ref.hex(), named_wire_hex=bundle(named).hex(), counted_wire_hex=bundle(counted).hex()))
    return json.dumps(result, indent=2)+'\n'


def uploads():
    reference = bytes.fromhex(json.loads(bundles())[0]['reference_hex'])
    namespace = struct.pack('<Q', 2**64-1)
    commands = [("initialize", b'UQI1'), ("begin", b'UQB1'+reference),
        ("part", b'UQP1'+namespace+struct.pack('<IB', 15, 1)+bytes(range(128)))]
    commands += [(label, tag+namespace) for label, tag in [
        ('seal', b'UQS1'), ('prepare', b'UQT1'), ('activate', b'UQA1'), ('submit', b'UQX1'), ('cancel', b'UQK1'),
        ('collect', b'UQG1'), ('retire', b'UQR1')]]
    commands.append(('retry_cleanup', b'UQL1'+namespace+b'\0'))
    status = b'UQU1' + reference + b'\1' + struct.pack('<Q', 0) + b'\0\0\0'
    return json.dumps(dict(commands=[dict(kind=kind, wire_hex=wire.hex()) for kind, wire in commands], status_hex=status.hex()), indent=2)+'\n'


if __name__ == '__main__':
    if sys.argv[1:] == ['--write']:
        FIXTURE.parent.mkdir(exist_ok=True)
        FIXTURE.write_text(generate())
        SOURCES.parent.mkdir(exist_ok=True)
        SOURCES.write_text(sources())
        BUNDLES.write_text(bundles())
        UPLOADS.write_text(uploads())
        OUTPUT_NAMES.write_text(output_names())
        BOOLEAN_PLANS.write_text(boolean_plans())
    elif sys.argv[1:] or FIXTURE.read_text() != generate() or SOURCES.read_text() != sources() or BUNDLES.read_text() != bundles() or UPLOADS.read_text() != uploads() or OUTPUT_NAMES.read_text() != output_names() or BOOLEAN_PLANS.read_text() != boolean_plans():
        raise SystemExit('Unified query fixtures differ; review and regenerate explicitly')
    print('Unified query fixtures: independent schemas, definition-bound UQS1/UQB1 sources and logical FQP1 plans passed.')

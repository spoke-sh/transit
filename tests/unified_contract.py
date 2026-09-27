"""Independent FZP2/schema encodings for the shared v2 query fixtures."""
import hashlib
import json
from pathlib import Path
import struct
import sys

FIXTURE = Path(__file__).resolve().parents[1] / 'packages/zig/transit-fuze/src/fixtures/unified.json'


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


if __name__ == '__main__':
    if sys.argv[1:] == ['--write']:
        FIXTURE.parent.mkdir(exist_ok=True)
        FIXTURE.write_text(generate())
    elif sys.argv[1:] or FIXTURE.read_text() != generate():
        raise SystemExit('Unified query fixtures differ; review and regenerate explicitly')
    print('Unified query fixtures: independent schema, full-width and larger FZP2 plans passed.')

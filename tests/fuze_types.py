#!/usr/bin/env python3
"""Independent stdlib oracle for Fuze type/value v1 canonical fixtures.

No Transit decoder is imported. Decimal, datetime, UUID and struct provide the
reference scalar values; Zig binds the literals and compares its complete bytes.
"""
import argparse
from datetime import date, datetime, timezone
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import struct
import uuid

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'packages/zig/transit-fuze/src/fixtures/types.json'
DEFINITION = b'transit.fuze.types.v1.2026-09-30'
TAGS = dict(zip(('int64 uint64 float64 boolean utf8 binary int8 int16 int32 int128 '
                 'uint8 uint16 uint32 uint128 float32 decimal date time timestamp '
                 'interval uuid structure list array map tagged_union json').split(), range(1, 28)))

KINDS = dict(TAGS, unknown=0, null_value=28, text=29, character=30)


def descriptor(kind, params=b''):
    return b'FTY1' + bytes([len(DEFINITION)]) + DEFINITION + bytes([TAGS[kind]]) + params


def fixtures():
    rows = []
    def add(name, kind, literal, payload, params=b''):
        desc = descriptor(kind, params)
        envelope = b'FVL1' + struct.pack('<H', len(desc)) + desc + b'\0\3' + payload
        if kind.startswith(('int', 'uint')):
            semantic = int(literal).to_bytes(16, 'little', signed=kind.startswith('int'))
        elif kind.startswith('float'):
            value = struct.unpack('<f' if kind == 'float32' else '<d', payload)[0]
            semantic = struct.pack('<d', 0.0 if value == 0.0 else value)
        elif kind == 'utf8':
            semantic = struct.pack('<Q', len(payload) - 4) + payload[4:]
        else:
            semantic = payload
        logical_hash = hashlib.sha256(b'transit.fuze.structural-hash.v1\0' + hashlib.sha256(desc).digest() + b'\0\0\3' + semantic).hexdigest()
        rows.append(dict(name=name, kind=kind, literal=literal, type_hex=desc.hex(),
                         fingerprint=hashlib.sha256(desc).hexdigest(), value_hex=envelope.hex(), logical_hash=logical_hash))
    for signed in (True, False):
        for width in (8, 16, 32, 64, 128):
            kind = ('int' if signed else 'uint') + str(width)
            low, high = (-(1 << (width - 1)), (1 << (width - 1)) - 1) if signed else (0, (1 << width) - 1)
            for value in (low, high):
                add(f'{kind}/{value}', kind, str(value), value.to_bytes(width // 8, 'little', signed=signed))
    for kind, fmt in [('float32', '<f'), ('float64', '<d')]:
        for literal in ('-0.0', '1.25', '0.1', '9007199254740993'):
            add(f'{kind}/{literal}', kind, literal, struct.pack(fmt, float(literal)))
    for literal in ('true', 'false'):
        add(literal, 'boolean', literal, bytes([literal == 'true']))
    for literal in ('', 'hello🙂', 'e\u0301'):
        payload = literal.encode()
        add('utf8/' + literal, 'utf8', literal, struct.pack('<I', len(payload)) + payload)
    for literal, precision, scale in [('123.45', 5, 2), ('-0.000000001', 38, 9), ('99999999999999999999999999999999999999', 38, 0)]:
        # Decimal context is deliberately widened so the oracle never rounds.
        from decimal import localcontext
        with localcontext() as ctx:
            ctx.prec = 100
            coefficient = int(Decimal(literal) * (Decimal(10) ** scale))
        add('decimal/' + literal, 'decimal', literal, coefficient.to_bytes(16, 'little', signed=True), bytes([precision, scale]))
    for literal in ('0001-01-01', '1969-12-31', '1970-01-01', '2000-02-29', '9999-12-31'):
        days = (date.fromisoformat(literal) - date(1970, 1, 1)).days
        add('date/' + literal, 'date', literal, struct.pack('<i', days))
    for literal, nanos in [('00:00:00', 0), ('23:59:59.999999999', 86400 * 10**9 - 1)]:
        add('time/' + literal, 'time', literal, struct.pack('<Q', nanos))
    for literal in ('1969-12-31T23:59:59.999999Z', '2000-02-29T12:00:00.123456Z'):
        delta = datetime.fromisoformat(literal) - datetime(1970, 1, 1, tzinfo=timezone.utc)
        micros = (delta.days * 86400 + delta.seconds) * 10**6 + delta.microseconds
        add('timestamp/' + literal, 'timestamp', literal, struct.pack('<q', micros), b'\1')
    literal = '00112233-4455-6677-8899-aabbccddeeff'
    add('uuid', 'uuid', literal, uuid.UUID(literal).bytes)
    return {'definition': DEFINITION.decode(), 'oracle': 'Python stdlib integer/decimal/datetime/uuid/struct', 'cases': rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    result = json.dumps(fixtures(), indent=2, ensure_ascii=False) + '\n'
    if args.write:
        FIXTURE.write_text(result)
    elif FIXTURE.read_text() != result:
        raise SystemExit('Fuze independent type fixtures drifted; regenerate deliberately with --write')
    print(f'Fuze types: {len(fixtures()["cases"])} independent scalar fixtures checked')


if __name__ == '__main__':
    main()

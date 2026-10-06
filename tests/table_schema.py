#!/usr/bin/env python3
"""Independent Table-schema bytes and row/default/constraint semantics oracle.

Uses Python values and struct; imports no Transit encoder or validator. The
chosen four-column schema is also constructed independently by the Zig tests.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'packages/zig/transit-fuze/src/fixtures/table-schema.json'
DEFINITION = b'transit.table.schema.v1.2026-10-05'
TYPES = b'transit.fuze.types.v1.2026-09-30'
ROWS = b'transit.table.row.v1.2026-10-05'


def fixtures():
    columns = [(11, 'id', b'\x09', False, 0),
               (27, 'name', b'\x05', True, 3),
               (39, 'active', b'\x04', False, 0),
               (40, 'amount', b'\x10\x12\x02', True, 0)]
    encoded = b'FTS1' + bytes([len(DEFINITION)]) + DEFINITION
    encoded += struct.pack('<QQQH', 7, 2, 50, len(columns))
    for identity, name, tag, nullable, length in columns:
        descriptor = b'FTY1' + bytes([len(TYPES)]) + TYPES + tag
        encoded += struct.pack('<QB', identity, len(name)) + name.encode()
        encoded += struct.pack('<H', len(descriptor)) + descriptor
        encoded += struct.pack('<BIB', nullable, length, identity == 39)
        if identity == 39:
            value = b'FVL1' + struct.pack('<H', len(descriptor)) + descriptor + b'\0\3\1'
            encoded += struct.pack('<I', len(value)) + value
    encoded += struct.pack('<HQ', 1, 11)

    storage_type = b'FTY1' + bytes([len(TYPES)]) + TYPES + bytes([22, len(columns)])
    for identity, _, tag, nullable, _ in columns:
        label = f'{identity:016x}'.encode()
        storage_type += bytes([len(label)]) + label + bytes([nullable]) + tag
    layout = hashlib.sha256(b'transit.table.layout.v1\0' + DEFINITION +
                            struct.pack('<Q', 7) + hashlib.sha256(storage_type).digest()).digest()
    row_payload = b'\3\3' + struct.pack('<i', 12)
    name = '東京é'.encode()
    row_payload += b'\3' + struct.pack('<I', len(name)) + name + b'\3\1\1'
    row_bytes = b'FTR1' + bytes([len(ROWS)]) + ROWS + layout + struct.pack('>QQI', 7, 12, 0)
    row_bytes += b'FVL1' + struct.pack('<H', len(storage_type)) + storage_type + b'\0' + row_payload
    dml_bytes = (b'FDM1' + hashlib.sha256(encoded).digest() + b'\x06people\x01' +
                 struct.pack('<HI', 1, len(row_payload)) + row_payload + b'\0')
    int32 = b'FTY1' + bytes([len(TYPES)]) + TYPES + b'\x09'
    key_bytes = b'FTK1' + bytes([len(ROWS)]) + ROWS + struct.pack('<QHQ', 7, 1, 11)
    key_bytes += b'FVL1' + struct.pack('<H', len(int32)) + int32 + b'\0\3' + struct.pack('<i', 12)

    def assignment(column, kind, value=None):
        result = dict(column=column, kind=kind)
        if value is not None:
            result[kind] = value
        return result

    a = assignment
    samples = [
        ('defaults', [a(11, 'integer', 1)]),
        ('reordered unicode', [a(27, 'text', '東京é'), a(11, 'integer', -12)]),
        ('scalar length exceeds', [a(11, 'integer', 1), a(27, 'text', '東京éX')]),
        ('combining counts separately', [a(11, 'integer', 1), a(27, 'text', 'e\u0301e\u0301')]),
        ('trailing spaces count', [a(11, 'integer', 1), a(27, 'text', 'abc ')]),
        ('missing required', []),
        ('explicit null', [a(11, 'null')]),
        ('explicit default', [a(11, 'integer', 1), a(39, 'default')]),
        ('null does not default', [a(11, 'integer', 1), a(39, 'null')]),
        ('duplicate', [a(11, 'integer', 1), a(11, 'integer', 2)]),
        ('unknown identity', [a(99, 'default')]),
        ('integer overflow', [a(11, 'integer', 2147483648)]),
        ('integer lower boundary', [a(11, 'integer', -2147483648)]),
    ]
    missing = object()
    def evaluate(assignments):
        defaults = {11: missing, 27: None, 39: True, 40: None}
        values = dict(defaults)
        seen = set()
        for item in assignments:
            identity, kind = item['column'], item['kind']
            if identity not in values:
                return [], 'UnknownColumn'
            if identity in seen:
                return [], 'DuplicateAssignment'
            seen.add(identity)
            values[identity] = defaults[identity] if kind == 'default' else None if kind == 'null' else item[kind]
        for identity, _, _, nullable, length in columns:
            value = values[identity]
            if value is missing:
                return [], 'MissingRequiredField'
            if value is None and not nullable:
                return [], 'NullNotAllowed'
            if identity == 11 and value is not None and not -(2**31) <= value < 2**31:
                return [], 'Overflow'
            if length and value is not None and len(value) > length:
                return [], 'CharacterLimitExceeded'
        def rendered(value):
            if value is None:
                return 'null'
            if isinstance(value, bool):
                return 'bool:' + str(value).lower()
            return ('int:' if isinstance(value, int) else 'text:') + str(value)
        return [rendered(values[column[0]]) for column in columns], None
    cases = []
    for name, assignments in samples:
        expected, error = evaluate(assignments)
        cases.append(dict(name=name, assignments=assignments, expected=expected, error=error))
    native_definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    neutral = dict(definition=native_definition, object='7', revision='2', next_column='50', columns=[
        dict(id='11', name='id', type={'int32': {}}, nullable=False, default=None, max_characters=None),
        dict(id='27', name='name', type={'utf8': {}}, nullable=True, default=None, max_characters=3),
        dict(id='39', name='active', type={'boolean': {}}, nullable=False,
             default={'value': {'atom': {'boolean': True}}}, max_characters=None),
        dict(id='40', name='amount', type={'decimal': {'precision': 18, 'scale': 2}}, nullable=True,
             default=None, max_characters=None),
    ], primary_key=['11'])
    return dict(definition=DEFINITION.decode(), oracle='Python values/Unicode scalar length/struct',
                schema_hex=encoded.hex(), schema_json=json.dumps(neutral, separators=(',', ':')), fingerprint=hashlib.sha256(encoded).hexdigest(), cases=cases,
                row_hex=row_bytes.hex(), layout=layout.hex(), key_hex=key_bytes.hex(), dml_hex=dml_bytes.hex(),
                key_digest=hashlib.sha256(key_bytes).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    result = fixtures()
    text = json.dumps(result, indent=2, ensure_ascii=False) + '\n'
    if args.write:
        FIXTURE.write_text(text)
    elif FIXTURE.read_text() != text:
        raise SystemExit('Table schema oracle drift; deliberately regenerate with --write')
    if not args.write:
        from jsonschema import Draft202012Validator
        schema = json.loads((ROOT / 'packages/zig/transit-fuze/api/logical-table-schema.schema.json').read_text())
        Draft202012Validator.check_schema(schema)
        validator = Draft202012Validator(schema)
        neutral = json.loads(result['schema_json'])
        validator.validate(neutral)
        for key, replacement in [('definition', 'foreign'), ('object', 7), ('columns', {}), ('primary_key', [11])]:
            changed = dict(neutral, **{key: replacement})
            assert list(validator.iter_errors(changed)), (key, replacement)
        for key in neutral:
            changed = dict(neutral)
            del changed[key]
            assert list(validator.iter_errors(changed)), key
    print(f'Table schema: independent bytes and {len(result["cases"])} row cases checked')


if __name__ == '__main__':
    main()

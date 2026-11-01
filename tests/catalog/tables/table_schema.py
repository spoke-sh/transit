#!/usr/bin/env python3
"""Independent Table-schema bytes and row/default/constraint semantics oracle.

Uses Python values and struct; imports no Transit encoder or validator. The
chosen four-column schema is also constructed independently by the Zig tests.
"""
from runner.paths import ROOT
import argparse
import copy
import hashlib
import json
from pathlib import Path
import struct

FIXTURE = ROOT / 'packages/zig/transit-fuze/src/fixtures/table-schema.json'
DEFINITION = b'transit.table.schema.v1.2026-11-01.semantics'
TYPES = b'transit.fuze.types.v1.2026-11-01.companions'
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

    query_type = b'FTY1' + bytes([len(TYPES)]) + TYPES + bytes([22, len(columns)])
    for _, label, tag, nullable, _ in columns:
        query_type += bytes([len(label)]) + label.encode() + bytes([nullable]) + tag
    query_schema = hashlib.sha256(query_type).digest()
    query_definition = hashlib.sha256(b'transit.fuze.logical-plan.v1:bound-schema:ordered-predicates:output-names:nullable-parameters:collations:scalar-programs:decimal-sum.2026-11-01').digest()
    query_prefix = b'\0\2\1\0'
    query_limit = b'\1' + struct.pack('<Q', 3)
    literal = b'\3' + struct.pack('<i', 12)
    program = b'\3\3\0\2\0\0' + struct.pack('<H', len(literal)) + literal + b'\0\1\1\1\3'
    query_bytes = (b'FQP1' + query_definition + b'\7' * 32 + query_schema + query_prefix +
                   b'\6chosen\0' + query_limit + program + bytes(len(columns)) + b'\0')
    literal_envelope = b'FVL1' + struct.pack('<H', len(int32)) + int32 + b'\0' + literal
    identity_program = (b'\3\3\0\2\0\0' + struct.pack('<H', len(literal_envelope)) +
                        literal_envelope + b'\0\1\1\1\3')
    query_identity = (b'transit.fuze.file-plan.v1\0' + b'\7' * 32 + query_schema + query_prefix +
                      query_limit + identity_program + b'output_names\0\1\6chosen\0' + b'collations\0' + bytes(len(columns)) + b'\0')
    query_progress = (b'FQS1' + b'\7' * 32 + hashlib.sha256(query_identity).digest() +
                      struct.pack('<QQQQQQB', 1, 2, 1, 0, 1, 1, 0) + bytes(16) + b'\1')

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
    ], primary_key=['11'], integrity=dict(next_id=1, checks=[], foreign_keys=[]))
    for column in neutral['columns']:
        column.update(encoding='plain', collation='none',
                      semantics=dict(rounding=None, metric=None, timezone=None, spatial=None))
    physical = copy.deepcopy(neutral)
    for column, encoding, collation in zip(physical['columns'],
            ('bitpacked', 'ebcdic', 'rle', 'comp_3'), ('none', 'ebcdic_cp037', 'none', 'none')):
        column.update(encoding=encoding, collation=collation)
    physical_bytes = encoded + b'FTP1' + bytes((1, 0, 9, 3, 2, 0, 6, 0))
    constrained = copy.deepcopy(neutral)
    constrained['integrity'] = dict(next_id=8, checks=[dict(id=7, name='positive_id',
        atoms=[dict(compare_literal=dict(column='11', op='gte', literal=dict(value=dict(atom=dict(signed='0')))))],
        validated=False)], foreign_keys=[])
    zero = b'FVL1' + struct.pack('<H', len(int32)) + int32 + b'\0\3' + struct.pack('<i', 0)
    integrity_bytes = (encoded + b'FTI1' + struct.pack('<IBIB', 8, 1, 7, 11) +
                       b'positive_id' + b'\0\1\1' + struct.pack('<QB', 11, 3) +
                       struct.pack('<I', len(zero)) + zero + b'\0')
    foreign = copy.deepcopy(neutral)
    target = dict(realm='1', resource='3', catalog='1', branch='1', object='9', revision='7', digest='4a' * 32)
    foreign['integrity'] = dict(next_id=9, checks=[], foreign_keys=[dict(id=8, name='parent_id',
        local_columns=['11'], target_object='9', target_revision='3', target_definition=target,
        target_columns=['21'], on_delete='restrict', on_update='no_action', enforcement='staged_awaiting_index')])
    foreign_bytes = (encoded + b'FTI1' + struct.pack('<IBBIB', 9, 0, 1, 8, 9) + b'parent_id' +
        struct.pack('<QQ', 9, 3) + struct.pack('<QQQQQQ', 1, 3, 1, 1, 9, 7) + bytes.fromhex('4a' * 32) +
        bytes([1, 2, 1, 1]) + struct.pack('<QQ', 11, 21))
    return dict(foreign_schema_json=json.dumps(foreign, separators=(',', ':')),
                foreign_schema_hex=foreign_bytes.hex(), foreign_fingerprint=hashlib.sha256(foreign_bytes).hexdigest(),
                integrity_schema_json=json.dumps(constrained, separators=(',', ':')),
                integrity_schema_hex=integrity_bytes.hex(),
                integrity_fingerprint=hashlib.sha256(integrity_bytes).hexdigest(),
                physical_schema_json=json.dumps(physical, separators=(',', ':')),
                physical_schema_hex=physical_bytes.hex(), physical_fingerprint=hashlib.sha256(physical_bytes).hexdigest(),
                definition=DEFINITION.decode(), oracle='Python values/Unicode scalar length/struct',
                schema_hex=encoded.hex(), schema_json=json.dumps(neutral, separators=(',', ':')), fingerprint=hashlib.sha256(encoded).hexdigest(), cases=cases,
                row_hex=row_bytes.hex(), layout=layout.hex(), key_hex=key_bytes.hex(), dml_hex=dml_bytes.hex(),
                select_hex=query_bytes.hex(), select_fingerprint=hashlib.sha256(query_identity).hexdigest(),
                select_progress_hex=query_progress.hex(),
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
        validator.validate(json.loads(result['physical_schema_json']))
        validator.validate(json.loads(result['integrity_schema_json']))
        validator.validate(json.loads(result['foreign_schema_json']))
        for key in ('encoding', 'collation', 'semantics'):
            changed = copy.deepcopy(neutral)
            del changed['columns'][0][key]
            assert list(validator.iter_errors(changed)), key
            changed['columns'][0][key] = 'invented'
            assert list(validator.iter_errors(changed)), key
        for key, replacement in [('definition', 'foreign'), ('object', 7), ('columns', {}), ('primary_key', [11])]:
            changed = dict(neutral, **{key: replacement})
            assert list(validator.iter_errors(changed)), (key, replacement)
        for key in neutral:
            changed = dict(neutral)
            del changed[key]
            if key == 'integrity':
                validator.validate(changed)
            else:
                assert list(validator.iter_errors(changed)), key
    print(f'Table schema: independent bytes and {len(result["cases"])} row cases checked')


if __name__ == '__main__':
    main()

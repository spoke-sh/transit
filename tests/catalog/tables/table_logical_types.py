"""Independent SQL-to-disk round trips for every implemented logical family."""
import struct
from query.logical.fuze_types import DEFINITION


def atom(kind, value):
    return {'value': {'atom': {kind: value}}}


def scalar(kind):
    return {kind: {}}


def cases():
    values = []
    for signed in (True, False):
        for width in (8, 16, 32, 64, 128):
            kind = ('int' if signed else 'uint') + str(width)
            value = -(1 << (width - 1)) if signed else (1 << width) - 1
            name = ('s' if signed else 'u') + str(width)
            values.append((name, kind.upper(), scalar(kind), str(value),
                           atom('signed' if signed else 'unsigned', str(value))))
    values += [
        ('f32', 'REAL', scalar('float32'), '-0.0', atom('float_bits', struct.pack('<f', -0.0).hex())),
        ('f64', 'DOUBLE PRECISION', scalar('float64'), '1.25', atom('float_bits', struct.pack('<d', 1.25).hex())),
        ('amount', 'DECIMAL(38,2)', {'decimal': {'precision': 38, 'scale': 2}}, '9' * 36 + '.99', atom('decimal', '9' * 38)),
        ('flag', 'BOOLEAN', scalar('boolean'), 'TRUE', atom('boolean', True)),
        ('text_value', 'VARCHAR(3)', scalar('utf8'), "'東京🚀'", atom('utf8', '東京🚀')),
        ('bytes_value', 'BYTEA', scalar('binary'), "X'0080ff'", atom('binary', '0080ff')),
        ('day_value', 'DATE', scalar('date'), "'1969-12-31'", atom('date_days', '-1')),
        ('time_value', 'TIME(9)', scalar('time'), "'23:59:59.123456789'", atom('time_nanos', '86399123456789')),
        ('civil_value', 'TIMESTAMP(6)', {'timestamp': 'civil'}, "'1969-12-31T23:59:59.123456'", atom('timestamp_micros', '-876544')),
        ('utc_value', 'TIMESTAMPTZ', {'timestamp': 'utc'}, "'1970-01-01T00:00:00.000001Z'", atom('timestamp_micros', '1')),
        ('interval_value', 'INTERVAL', scalar('interval'), 'INTERVAL(-1,2,-3)', atom('interval', {'months': '-1', 'days': '2', 'nanos': '-3'})),
        ('uuid_value', 'UUID', scalar('uuid'), "'01234567-89ab-cdef-0123-456789abcdef'", atom('uuid', '0123456789abcdef0123456789abcdef')),
        ('struct_value', 'STRUCT(n INT32 NOT NULL, note UTF8 OPTIONAL)',
         {'structure': [
             {'name': 'n', 'type': scalar('int32'), 'nullable': False, 'optional': False},
             {'name': 'note', 'type': scalar('utf8'), 'nullable': True, 'optional': True},
         ]}, 'STRUCT(7,MISSING)', {'value': {'structure': [atom('signed', '7'), {'missing': {}}]}}),
        ('list_value', 'LIST(INT64)', {'list': {'type': scalar('int64'), 'nullable': True}},
         'LIST(1,NULL,-2)', {'value': {'list': [atom('signed', '1'), {'null': {}}, atom('signed', '-2')]}}),
        ('array_value', 'ARRAY(UINT16 NOT NULL,2)', {'array': {'element': {'type': scalar('uint16'), 'nullable': False}, 'length': 2}},
         'ARRAY(0,65535)', {'value': {'array': [atom('unsigned', '0'), atom('unsigned', '65535')]}}),
        ('map_value', 'MAP(UTF8,INT32)', {'map': {'key': scalar('utf8'), 'value': {'type': scalar('int32'), 'nullable': True}}},
         "MAP('z',NULL,'a',1)", {'value': {'map': [
             {'key': {'utf8': 'a'}, 'value': atom('signed', '1')},
             {'key': {'utf8': 'z'}, 'value': {'null': {}}},
         ]}}),
        ('union_value', 'UNION(text UTF8, number INT128)', {'tagged_union': [
            {'name': 'text', 'type': scalar('utf8'), 'nullable': True, 'optional': False},
            {'name': 'number', 'type': scalar('int128'), 'nullable': True, 'optional': False},
        ]}, 'UNION(number,-170141183460469231731687303715884105728)',
         {'value': {'tagged_union': {'index': 1, 'value': atom('signed', '-170141183460469231731687303715884105728')}}}),
        ('json_value', 'JSON', scalar('json'), "'{\"n\":9007199254740993,\"nested\":[null,true]}'",
         {'value': {'json': '{"n":9007199254740993,"nested":[null,true]}'}}),
    ]
    return values


def qualify(call, execute, applied, restart):
    matrix = cases()
    columns = ', '.join(f'{name} {typ} DEFAULT {literal}' for name, typ, _, literal, _ in matrix)
    applied(execute(5_000_001, f'CREATE TABLE logical_families ({columns})', 50001))
    defaults = ','.join('DEFAULT' for _ in matrix)
    applied(execute(5_000_002, f'INSERT INTO logical_families VALUES ({defaults})'))
    expected_fields = [
        {'name': name, 'type': descriptor, 'nullable': True, 'optional': False}
        for name, _, descriptor, _, _ in matrix
    ]
    expected_schema = {'definition': DEFINITION.decode(), 'type': {'structure': expected_fields}}
    expected_cells = [value for _, _, _, _, value in matrix]

    def rows():
        result = call('select', 'SELECT * FROM logical_families')
        assert result['complete'] and result['schema'] == expected_schema, result
        for row in result['rows']:
            assert len(row) == len(expected_fields), row
            for column, field in zip(row, expected_fields, strict=True):
                assert column['definition'] == DEFINITION.decode() and column['field'] == field, column
        return [[column['cell'] for column in row] for row in result['rows']]

    assert rows() == [expected_cells]
    nulls = ','.join('NULL' for _ in matrix)
    applied(execute(5_000_003, f'INSERT INTO logical_families VALUES ({nulls})'))
    assert rows() == [expected_cells, [{'null': {}} for _ in matrix]]
    assignments = ', '.join(f'{name} = {literal}' for name, _, _, literal, _ in matrix)
    updated = execute(5_000_004, f'UPDATE logical_families SET {assignments} WHERE flag IS NULL')
    applied(updated)
    assert (updated['matched'], updated['changed']) == (1, 1), updated
    assert rows() == [expected_cells, expected_cells]
    outcome = call('status')
    restart()
    assert call('status') == outcome, 'Restart changed the typed UPDATE outcome'
    assert rows() == [expected_cells, expected_cells]
    applied(execute(5_000_005, 'DROP TABLE logical_families'))
    print(f'Native logical Table matrix: {len(matrix)} descriptors, exact defaults, NULLs, typed UPDATE and node/store restart passed.', flush=True)
    return {'descriptors': len(matrix), 'rows': 2, 'defaults': True, 'nulls': True, 'typed_update': True, 'node_store_restart': True}

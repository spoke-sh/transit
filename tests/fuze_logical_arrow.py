#!/usr/bin/env python3
"""Independent PyArrow interpretation of every logical type and five states."""
import csv
from decimal import Decimal
import io
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import pyarrow as pa
from fuze_file_query import descriptor, cell_bytes
from fuze_types import DEFINITION, TAGS

CLI = str(Path(sys.argv[1]).resolve())
BRIDGE = str(Path(sys.argv[2]).resolve())
ROOT = Path(__file__).resolve().parents[1]
CASES = 0


def payload_bytes(array, i, typ):
    kind, params = next(iter(typ.items()))
    scalar = array[i]
    assert scalar.is_valid
    value = scalar.as_py() if kind not in ('date', 'time', 'timestamp', 'structure', 'list', 'array', 'map', 'tagged_union') else None
    if kind in ('int128', 'uint128', 'uuid'):
        assert pa.types.is_fixed_size_binary(array.type) and array.type.byte_width == 16
        return value
    if kind.startswith(('int', 'uint')) and kind != 'interval':
        signed = kind.startswith('int')
        width = int(kind[3:] if signed else kind[4:])
        assert array.type.bit_width == width
        return int(value).to_bytes(width // 8, 'little', signed=signed)
    if kind in ('float32', 'float64'):
        return struct.pack('<f' if kind == 'float32' else '<d', value)
    if kind == 'decimal':
        assert array.type == pa.decimal128(params['precision'], params['scale'])
        from decimal import localcontext
        with localcontext() as ctx:
            ctx.prec = 100
            return int(value * Decimal(10) ** params['scale']).to_bytes(16, 'little', signed=True)
    if kind == 'boolean':
        assert array.type == pa.bool_()
        return bytes([value])
    if kind in ('utf8', 'binary', 'json'):
        assert array.type == (pa.binary() if kind == 'binary' else pa.string())
        raw = value if kind == 'binary' else value.encode()
        return struct.pack('<I', len(raw)) + raw
    if kind in ('date', 'time', 'timestamp'):
        physical, fmt = (pa.int32(), '<i') if kind == 'date' else (pa.int64(), '<q')
        expected = {'date': pa.date32(), 'time': pa.time64('ns'), 'timestamp': pa.timestamp('us', tz='UTC' if params == 'utc' else None)}[kind]
        assert array.type == expected
        return struct.pack(fmt, array.cast(physical)[i].as_py())
    if kind == 'interval':
        assert array.type == pa.month_day_nano_interval()
        return struct.pack('<iiq', value.months, value.days, value.nanoseconds)
    if kind == 'structure':
        return b''.join(arrow_cell(array.field(field['name']), i, field['type']) for field in params)
    if kind in ('list', 'array'):
        child = params['type'] if kind == 'list' else params['element']['type']
        start = array.offsets[i].as_py() if kind == 'list' else (array.offset + i) * params['length']
        end = array.offsets[i+1].as_py() if kind == 'list' else start + params['length']
        return struct.pack('<I', end - start) + b''.join(arrow_cell(array.values, n, child) for n in range(start, end))
    if kind == 'map':
        assert pa.types.is_map(array.type) and not array.type.keys_sorted
        start, end = array.offsets[i].as_py(), array.offsets[i+1].as_py()
        return struct.pack('<I', end - start) + b''.join(payload_bytes(array.keys, n, params['key']) + arrow_cell(array.items, n, params['value']['type']) for n in range(start, end))
    if kind == 'tagged_union':
        tag = array.field('tag')[i].as_py()
        variants = array.field('variants')
        for index, field in enumerate(params):
            if index != tag:
                assert variants.field(field['name']).field('state')[i].as_py() == 0
        return bytes([tag]) + arrow_cell(variants.field(params[tag]['name']), i, params[tag]['type'])
    raise AssertionError(kind)


def arrow_cell(array, i, typ):
    state = array.field('state')[i].as_py()
    kind = array.field('kind')[i].as_py()
    value = array.field('value')
    alternatives = array.field('alternatives') if array.type.get_field_index('alternatives') >= 0 else None
    if state in (0, 1):
        assert kind == 0 and not value[i].is_valid
        return bytes([state])
    if state == 2:
        assert not value[i].is_valid and kind in TAGS.values()
        return bytes([2, kind])
    if state == 3:
        assert kind == TAGS[next(iter(typ))]
        if alternatives is not None:
            assert alternatives[i].as_py() == []
        return b'\3' + payload_bytes(value, i, typ)
    assert state == 4 and kind == 0 and not value[i].is_valid
    start, end = alternatives.offsets[i].as_py(), alternatives.offsets[i+1].as_py()
    entries = alternatives.values
    result = bytes([4, end - start])
    for n in range(start, end):
        result += struct.pack('<QQ', entries.field('counter')[n].as_py(), entries.field('replica')[n].as_py())
        result += arrow_cell(entries, n, typ)
    return result


def read_stream(data):
    assert data.endswith(b'\xff\xff\xff\xff\0\0\0\0'), 'missing explicit end marker'
    reader = pa.ipc.open_stream(data)
    assert reader.schema.metadata[b'transit.definition'] == b'transit.fuze.logical-arrow.v1.2026-09-30'
    batches = list(reader)
    for batch in batches:
        batch.validate(full=True)
    return reader.schema, batches


def cli(args, data=b''):
    global CASES
    p = subprocess.run([CLI, 'file-query', '--output', 'arrow', *map(str, args)], input=data, capture_output=True, timeout=30)
    assert p.returncode == 0 and not p.stderr, (args, p.stderr)
    CASES += 1
    return read_stream(p.stdout)


def recursive_cases():
    def atom(name, value):
        return {'value': {'atom': {name: value}}}
    def field(name, typ):
        return {'name': name, 'type': typ, 'nullable': True, 'optional': True}
    cases = [
        ({'binary': {}}, atom('binary', '00ff01')),
        ({'interval': {}}, atom('interval', {'months': '-3', 'days': '4', 'nanos': '-9223372036854775808'})),
        ({'timestamp': 'civil'}, atom('timestamp_micros', '-1')),
        ({'array': {'length': 2, 'element': {'type': {'uint16': {}}, 'nullable': True}}}, {'value': {'array': [atom('unsigned', '65535'), {'null': {}}]}}),
        ({'map': {'key': {'int128': {}}, 'value': {'type': {'utf8': {}}, 'nullable': True}}}, {'value': {'map': [{'key': {'signed': '-1'}, 'value': atom('utf8', 'one')}, {'key': {'signed': '170141183460469231731687303715884105727'}, 'value': {'null': {}}}]}}),
        ({'tagged_union': [dict(field('wide', {'uint128': {}}), optional=False), dict(field('text', {'utf8': {}}), optional=False)]}, {'value': {'tagged_union': {'index': 0, 'value': atom('unsigned', str(2**128-1))}}}),
        ({'structure': [field('x', {'int8': {}}), field('y', {'boolean': {}})]}, {'value': {'structure': [{'missing': {}}, {'type_error': 'utf8'}]}}),
        ({'list': {'type': {'int64': {}}, 'nullable': True}}, {'value': {'list': [atom('signed', '1'), {'null': {}}, {'type_error': 'utf8'}]}}),
        ({'json': {}}, {'value': {'json': '{"n":9007199254740993,"id":"001"}'}}),
    ]
    return cases


def main():
    global CASES
    with tempfile.TemporaryDirectory(prefix='transit-logical-arrow-', dir='/var/tmp') as directory:
        work = Path(directory)
        for case in json.loads((ROOT / 'packages/zig/transit-fuze/src/fixtures/types.json').read_text())['cases']:
            kind = case['kind']
            params = {} if kind not in ('decimal', 'timestamp') else ({'precision': bytes.fromhex(case['type_hex'])[-2], 'scale': bytes.fromhex(case['type_hex'])[-1]} if kind == 'decimal' else 'utc')
            typ = {kind: params}
            schema = work / 'schema.json'
            schema.write_text(json.dumps({'definition': DEFINITION.decode(), 'type': {'structure': [{'name': 'x', 'type': typ}]}}))
            buffer = io.StringIO(newline='')
            csv.writer(buffer).writerows([['x'], [case['literal']]])
            _, batches = cli(['--format', 'csv', '--mode', 'explicit', '--schema', schema, '-c', 'SELECT * FROM input', '-'], buffer.getvalue().encode())
            expected = bytes.fromhex(case['value_hex'])[7 + len(bytes.fromhex(case['type_hex'])):]
            assert len(batches) == 1 and arrow_cell(batches[0].column(0), 0, typ) == expected, case['name']
        for case in json.loads((ROOT / 'packages/zig/transit-fuze/src/fixtures/sources.json').read_text())['cases']:
            paths = []
            for index, content in enumerate(case['inputs']):
                path = work / str(index)
                path.write_bytes(content.encode())
                paths.append(path)
            json_result = subprocess.run([CLI, 'file-query', '--format', case['format'], '--mode', 'full', '-c', 'SELECT * FROM input', *map(str, paths)], capture_output=True, check=True)
            typ = json.loads(json_result.stdout.splitlines()[0])['schema']['type']
            physical, batches = cli(['--format', case['format'], '--mode', 'full', '-c', 'SELECT * FROM input', *paths])
            assert physical.metadata[b'transit.logical_schema'].decode() == case['schema_hex']
            desc = bytes.fromhex(case['schema_hex'])
            actual = []
            for batch in batches:
                for i in range(batch.num_rows):
                    cell = b'\3' + b''.join(arrow_cell(batch.column(n), i, field['type']) for n, field in enumerate(typ['structure']))
                    actual.append((b'FVL1' + struct.pack('<H', len(desc)) + desc + b'\0' + cell).hex())
            assert actual == case['rows_hex'], case['name']
        # File aliases preserve recursive descriptors, states, repeated values
        # and physical Arrow field names independently of the JSON renderer.
        typ = {'list': {'type': {'int64': {}}, 'nullable': True}}
        data = b'{"n":[1,null]}\n{"n":null}\n{}\n{"n":[2]}\n'
        physical, batches = cli(['--format', 'jsonl', '--mode', 'full', '--batch-rows', '1', '-c',
                                 'SELECT n AS first, n AS \"Second\" FROM input', '-'], data)
        fields = [dict(name=name, type=typ, nullable=True, optional=True) for name in ('first', 'Second')]
        assert physical.names == ['first', 'Second']
        assert physical.metadata[b'transit.logical_schema'] == descriptor({'structure': fields}).hex().encode()
        expected = [
            {'value': {'list': [{'value': {'atom': {'signed': '1'}}}, {'null': {}}]}},
            {'null': {}}, {'missing': {}},
            {'value': {'list': [{'value': {'atom': {'signed': '2'}}}]}},
        ]
        for column in (0, 1):
            assert [arrow_cell(batch.column(column), i, typ) for batch in batches for i in range(batch.num_rows)] == [cell_bytes(cell, typ) for cell in expected]
        for aggregate, typ, cell in (
            ('COUNT(*)', {'uint64': {}}, {'value': {'atom': {'unsigned': '2'}}}),
            ('SUM(n)', {'int64': {}}, {'value': {'atom': {'signed': '3'}}}),
        ):
            physical, batches = cli(['--format', 'csv', '-c', f'SELECT {aggregate} AS total FROM input', '-'], b'n\n1\n2\n')
            assert physical.names == ['total']
            assert len(batches) == 1 and batches[0].num_rows == 1
            assert arrow_cell(batches[0].column(0), 0, typ) == cell_bytes(cell, typ)
        # Neutral JSON bridge covers variants and conflicts not produced by files.
        for typ, cell in recursive_cases():
            for variant in [cell, {'null': {}}, {'missing': {}}, {'type_error': 'utf8'}, {'conflict': [{'counter': '9007199254740993', 'replica': '18446744073709551615', 'value': cell}, {'counter': '18446744073709551615', 'replica': '1', 'value': {'null': {}}}]}]:
                path = work / 'value.json'
                path.write_text(json.dumps({'definition': DEFINITION.decode(), 'field': {'name': 'x', 'type': typ, 'nullable': True, 'optional': True}, 'cell': variant}))
                p = subprocess.run([BRIDGE, str(path)], capture_output=True, timeout=30)
                assert p.returncode == 0 and not p.stderr, (typ, variant, p.stderr)
                physical, batches = read_stream(p.stdout)
                assert physical.metadata[b'transit.logical_schema'] == descriptor({'structure': [{'name': 'x', 'type': typ, 'nullable': True, 'optional': True}]}).hex().encode()
                assert arrow_cell(batches[0].column(0), 0, typ) == cell_bytes(variant, typ), (typ, variant)
                CASES += 1
        # Batches split under the unchanged 64 KiB segment bound, preserving rows.
        data = b'x\n' + (b'a' * 16000 + b'\n') * 17
        for width in (1, 8):
            _, batches = cli(['--format', 'csv', '--batch-rows', width, '-c', 'SELECT * FROM input', '-'], data)
            assert sum(batch.num_rows for batch in batches) == 17
            assert all(batch.column(0).field('value')[i].as_py() == 'a' * 16000 for batch in batches for i in range(batch.num_rows))
        p = subprocess.run([CLI, 'file-query', '--format', 'csv', '--output', 'arrow', '--sample-records', '1', '-c', 'SELECT x AS kept FROM input LIMIT 1', '-'], input=b'x\n1\nbad\n', capture_output=True, timeout=30)
        assert p.returncode == 1 and p.stdout and not p.stdout.endswith(b'\xff\xff\xff\xff\0\0\0\0')
        CASES += 1
    print(f'Logical Arrow: {CASES} PyArrow {pa.__version__} cases, exact scalar/recursive values and all five states, metadata, owned batches, bounded splitting and failed-prefix completion passed.')


if __name__ == '__main__':
    main()

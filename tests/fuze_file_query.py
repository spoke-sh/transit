#!/usr/bin/env python3
"""Real CLI acquisition/results: independent codec oracle and disk/pipe faults."""
import csv
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import resource
import signal
import struct
import subprocess
import sys
import tempfile
import time
import zlib
from fuze_types import DEFINITION, TAGS

ROOT = Path(__file__).resolve().parents[1]
CLI = str(Path(sys.argv[1]).resolve())
CASES = 0


def type_bytes(value):
    kind, params = next(iter(value.items()))
    result = bytes([TAGS[kind]])
    if kind == 'decimal':
        return result + bytes([params['precision'], params['scale']])
    if kind == 'timestamp':
        return result + bytes([params == 'utc'])
    if kind in ('structure', 'tagged_union'):
        result += bytes([len(params)])
        for field in params:
            name = field['name'].encode()
            result += bytes([len(name)]) + name + bytes([field['nullable'] + 2 * field['optional']]) + type_bytes(field['type'])
    elif kind == 'list':
        result += bytes([params['nullable']]) + type_bytes(params['type'])
    elif kind == 'array':
        result += struct.pack('<I', params['length']) + bytes([params['element']['nullable']]) + type_bytes(params['element']['type'])
    elif kind == 'map':
        result += type_bytes(params['key']) + bytes([params['value']['nullable']]) + type_bytes(params['value']['type'])
    return result


def descriptor(value):
    return b'FTY1' + bytes([len(DEFINITION)]) + DEFINITION + type_bytes(value)


def atom_bytes(value, typ):
    kind, params = next(iter(typ.items()))
    tag, payload = next(iter(value.items()))
    if kind.startswith(('int', 'uint')) and kind != 'interval':
        signed = kind.startswith('int')
        assert tag == ('signed' if signed else 'unsigned')
        width = int(kind[3:] if signed else kind[4:])
        return int(payload).to_bytes(width // 8, 'little', signed=signed)
    if kind == 'decimal':
        assert tag == 'decimal'
        return int(payload).to_bytes(16, 'little', signed=True)
    if kind in ('float32', 'float64', 'uuid'):
        assert tag == ('uuid' if kind == 'uuid' else 'float_bits')
        return bytes.fromhex(payload)
    if kind in ('utf8', 'binary'):
        assert tag == kind
        data = payload.encode() if kind == 'utf8' else bytes.fromhex(payload)
        return struct.pack('<I', len(data)) + data
    if kind == 'boolean':
        assert tag == kind
        return bytes([payload])
    if kind in ('date', 'time', 'timestamp'):
        expected, fmt = {'date': ('date_days', '<i'), 'time': ('time_nanos', '<Q'), 'timestamp': ('timestamp_micros', '<q')}[kind]
        assert tag == expected
        return struct.pack(fmt, int(payload))
    if kind == 'interval':
        assert tag == kind
        return struct.pack('<iiq', *[int(payload[k]) for k in ('months', 'days', 'nanos')])
    raise AssertionError(kind)


def cell_bytes(cell, typ):
    state, content = next(iter(cell.items()))
    if state in ('missing', 'null'):
        return bytes([0 if state == 'missing' else 1])
    if state == 'type_error':
        return bytes([2, TAGS[content]])
    if state == 'conflict':
        return bytes([4, len(content)]) + b''.join(struct.pack('<QQ', int(a['counter']), int(a['replica'])) + cell_bytes(a['value'], typ) for a in content)
    assert state == 'value'
    kind, params = next(iter(typ.items()))
    shape, value = next(iter(content.items()))
    if shape == 'atom':
        raw = atom_bytes(value, typ)
    elif shape == 'structure':
        raw = b''.join(cell_bytes(c, field['type']) for c, field in zip(value, params, strict=True))
    elif shape in ('list', 'array'):
        child = params['type'] if kind == 'list' else params['element']['type']
        raw = struct.pack('<I', len(value)) + b''.join(cell_bytes(c, child) for c in value)
    elif shape == 'map':
        raw = struct.pack('<I', len(value)) + b''.join(atom_bytes(e['key'], params['key']) + cell_bytes(e['value'], params['value']['type']) for e in value)
    elif shape == 'tagged_union':
        raw = bytes([value['index']]) + cell_bytes(value['value'], params[value['index']]['type'])
    elif shape == 'json':
        data = value.encode()
        raw = struct.pack('<I', len(data)) + data
    else:
        raise AssertionError(shape)
    return b'\3' + raw


def invoke(args, data=b'', expected=0, env=None):
    global CASES
    result = subprocess.run([CLI, 'file-query', *map(str, args)], input=data, capture_output=True, timeout=30, env=env)
    assert result.returncode == expected, (args, result.returncode, result.stderr, result.stdout[:500])
    records = [json.loads(line) for line in result.stdout.splitlines()]
    if expected == 0 and records:
        assert result.stderr == b'' and 'complete' in records[-1], result
        assert records[0]['definition'] == 'transit.fuze.file-output.v1.2026-09-30'
        assert records[0]['binding'] == records[-1]['complete']['binding']
        assert records[0]['plan'] == records[-1]['complete']['plan']
    else:
        assert not any('complete' in item for item in records)
        assert result.stderr.startswith(b'error: ')
    CASES += 1
    return records


def main():
    global CASES
    with tempfile.TemporaryDirectory(prefix='transit-file-proof-', dir='/var/tmp') as directory:
        work = Path(directory)
        spool = work / 'spool'
        spool.mkdir()
        env = dict(os.environ, TMPDIR=str(spool))
        fixtures = json.loads((ROOT / 'packages/zig/transit-fuze/src/fixtures/sources.json').read_text())
        for case in fixtures['cases']:
            paths = []
            for index, content in enumerate(case['inputs']):
                path = work / str(index)
                path.write_bytes(content.encode())
                paths.append(path)
            output = invoke(['--format', case['format'], '--mode', 'full', '-c', 'SELECT * FROM input', *paths], env=env)
            typ = output[0]['schema']['type']
            desc = descriptor(typ)
            assert desc.hex() == case['schema_hex'], case['name']
            actual = [(b'FVL1' + struct.pack('<H', len(desc)) + desc + b'\0' + cell_bytes(row['row'], typ)).hex() for row in output[1:-1]]
            assert actual == case['rows_hex'], case['name']
        # Every scalar oracle crosses explicit file decoding and lossless JSON.
        for case in json.loads((ROOT / 'packages/zig/transit-fuze/src/fixtures/types.json').read_text())['cases']:
            kind = case['kind']
            params = {} if kind not in ('decimal', 'timestamp') else ({'precision': bytes.fromhex(case['type_hex'])[-2], 'scale': bytes.fromhex(case['type_hex'])[-1]} if kind == 'decimal' else 'utc')
            typ = {kind: params}
            schema = work / 'schema.json'
            schema.write_text(json.dumps({'definition': DEFINITION.decode(), 'type': {'structure': [{'name': 'x', 'type': typ}]}}))
            buffer = io.StringIO(newline='')
            csv.writer(buffer).writerows([['x'], [case['literal']]])
            output = invoke(['--format', 'csv', '--mode', 'explicit', '--schema', schema, '-c', 'SELECT * FROM input', '-'], buffer.getvalue().encode(), env=env)
            actual = cell_bytes(output[1]['row']['value']['structure'][0], typ)
            expected = bytes.fromhex(case['value_hex'])[7 + len(bytes.fromhex(case['type_hex'])):]
            assert actual == expected, case['name']
            counted = invoke(['--format', 'csv', '--mode', 'explicit', '--schema', schema,
                              '-c', 'SELECT COUNT(x) AS present FROM input', '-'], buffer.getvalue().encode(), env=env)
            assert counted[0]['schema']['type']['structure'] == [dict(name='present', type={'uint64': {}}, nullable=False, optional=False)]
            assert counted[1]['row']['value']['structure'] == [{'value': {'atom': {'unsigned': '1'}}}]
        base = ['--format', 'csv', '-c', 'SELECT SUM(n) FROM input', '-']
        data = b'n,id\n1,001\n2,002\n'
        ordinary = invoke(base, data, env=env)
        # Source aliases lower to the same typed plan, including inside the
        # limited aggregate input; a bound alias hides the original qualifier.
        for sql in ('SELECT SUM(src.n) FROM input AS src',
                    'SELECT SUM(chosen.n) FROM (SELECT src.n FROM input AS src WHERE src.n > 0 LIMIT 2) AS chosen'):
            aliased = invoke(['--format', 'csv', '-c', sql, '-'], data, env=env)
            assert aliased[1]['row'] == ordinary[1]['row']
            assert aliased[-1]['complete']['scanned'] == ordinary[-1]['complete']['scanned']
        for sql, names, expected, tag in (
            ('SELECT n AS renamed FROM input', ['renamed'], [[1], [2]], 'signed'),
            ('SELECT n AS first, n AS second FROM input', ['first', 'second'], [[1, 1], [2, 2]], 'signed'),
            ('SELECT n AS \"Value\" FROM input', ['Value'], [[1], [2]], 'signed'),
            ('SELECT SUM(n) AS total FROM input', ['total'], [[3]], 'signed'),
            ('SELECT COUNT(*) AS rows FROM input', ['rows'], [[2]], 'unsigned'),
            ('SELECT SUM(chosen.renamed) AS total FROM (SELECT n AS renamed FROM input WHERE n > 1 LIMIT 1) AS chosen', ['total'], [[2]], 'signed'),
            ('SELECT SUM(chosen.second) FROM (SELECT n AS first, n AS second FROM input LIMIT 1) AS chosen', ['sum'], [[1]], 'signed'),
        ):
            output = invoke(['--format', 'csv', '-c', sql, '-'], data, env=env)
            assert [f['name'] for f in output[0]['schema']['type']['structure']] == names
            assert [row['row']['value']['structure'] for row in output[1:-1]] == [
                [{'value': {'atom': {tag: str(value)}}} for value in row] for row in expected]
            assert output[0]['binding'] == ordinary[0]['binding']
            assert int(output[-1]['complete']['scanned']) == 2
        # Top-level recursive values count once; null/missing consume input LIMIT.
        nested = b'{"x":[]}\n{"x":null}\n{}\n{"x":[1]}\n'
        for sql, expected in [
            ('SELECT COUNT(x) AS present FROM input', 2),
            ('SELECT COUNT(*) AS present FROM input', 4),
            ('SELECT COUNT(q.items) AS present FROM (SELECT x AS items FROM input LIMIT 3) AS q', 1),
            ('SELECT COUNT(x) AS present FROM (SELECT x FROM input LIMIT 0) AS q', 0),
            ('SELECT COUNT(x) AS present FROM input WHERE x IS MISSING', 0),
            ('SELECT COUNT(x) AS present FROM input WHERE x IS NULL', 0),
        ]:
            result = invoke(['--format', 'jsonl', '--mode', 'full', '-c', sql, '-'], nested, env=env)
            assert result[1]['row']['value']['structure'] == [{'value': {'atom': {'unsigned': str(expected)}}}]
            assert int(result[-1]['complete']['scanned']) == 4
        for sql in ['SELECT COUNT(x) FROM (SELECT x FROM input LIMIT 1) AS q',
                    'SELECT COUNT(x) FROM (SELECT x FROM input LIMIT 0) AS q']:
            invoke(['--format', 'csv', '--sample-records', '1', '-c', sql, '-'], b'x\n1\nbad\n', expected=1, env=env)
        # Independently commit source/schema, aggregate/projection, empty limit
        # and predicate, then every optional output name in position order.
        source_rows = invoke(['--format', 'csv', '-c', 'SELECT * FROM input', '-'], data, env=env)
        plan_bytes = (b'transit.fuze.file-plan.v1\0' + bytes.fromhex(ordinary[0]['binding'])
                      + hashlib.sha256(descriptor(source_rows[0]['schema']['type'])).digest()
                      + bytes([2, 1, 1, 0]) + struct.pack('<Q', 0) + b'\0')
        assert hashlib.sha256(plan_bytes).hexdigest() == ordinary[0]['plan']
        named = invoke(['--format', 'csv', '-c', 'SELECT SUM(n) AS total FROM input', '-'], data, env=env)
        assert hashlib.sha256(plan_bytes + b'output_names\0\1\5total').hexdigest() == named[0]['plan']
        assert ordinary[0]['plan'] == 'e8a4ebc7692c3c202f836b34cf1b6db48735c2759154a578222987f0d7704196'
        for aggregate, expected in [('COUNT(*)', {'value': {'atom': {'unsigned': '0'}}}), ('SUM(n)', {'null': {}})]:
            empty = invoke(['--format', 'csv', '-c', f'SELECT {aggregate} AS empty FROM input WHERE n < 0', '-'], data, env=env)
            assert empty[0]['schema']['type']['structure'][0]['name'] == 'empty'
            assert empty[1]['row']['value']['structure'] == [expected]
        for sql in ('SELECT input.n FROM input AS src',
                    'SELECT SUM(src.n) FROM input src',
                    'SELECT src.n FROM input AS src WHERE input.n > 0',
                    'SELECT n FROM absent AS input',
                    'SELECT n renamed FROM input',
                    'SELECT n AS id, id FROM input',
                    'SELECT n AS same, id AS same FROM input',
                    'SELECT n AS renamed FROM input WHERE renamed > 0',
                    'SELECT SUM(chosen.n) FROM (SELECT n AS renamed FROM input) AS chosen',
                    'SELECT COUNT(*) FROM (SELECT n AS same, id AS same FROM input) AS chosen',
                    'SELECT n AS name_is_too_long_here FROM input'):
            invoke(['--format', 'csv', '-c', sql, '-'], data, 1, env)
        # A pre-extension atom plan retains its exact identity; new Boolean
        # instructions do not reinterpret existing file-plan fingerprints.
        assert ordinary[0]['plan'] == 'e8a4ebc7692c3c202f836b34cf1b6db48735c2759154a578222987f0d7704196'
        for sql, expected in (
            ('SELECT n FROM input WHERE n > 0 AND n < 3', [1, 2]),
            ('SELECT n FROM input WHERE NOT n = 1', [2]),
            ('SELECT n FROM input WHERE n = 1 OR n = 2 AND n < 0', [1]),
            ('SELECT n FROM input WHERE (n = 1 OR n = 2) AND n < 0', []),
            ('SELECT src.n FROM input AS src WHERE NOT (src.n = 1 OR src.n IS NULL)', [2]),
            ('SELECT n FROM input WHERE n <> 0 AND NOT (n = 2) LIMIT 1', [1]),
            ('SELECT SUM(chosen.n) FROM (SELECT src.n FROM input AS src WHERE src.n > 0 AND src.n < 2 LIMIT 2) AS chosen', [1]),
            ('SELECT n FROM input WHERE ' + 'NOT ' * 63 + 'n = 1', [2]),
        ):
            output = invoke(['--format', 'csv', '-c', sql, '-'], data, env=env)
            actual = [int(row['row']['value']['structure'][0]['value']['atom']['signed']) for row in output[1:-1]]
            assert actual == expected, (sql, actual)
            assert int(output[-1]['complete']['scanned']) == 2
        for sql in ('SELECT n FROM input WHERE n > 0 OR unknown = 1',
                    "SELECT n FROM input WHERE n < 0 AND n = 'one'",
                    'SELECT n FROM input AS src WHERE src.n > 0 AND input.n < 3',
                    'SELECT n FROM input WHERE ' + 'NOT ' * 64 + 'n = 1'):
            invoke(['--format', 'csv', '-c', sql, '-'], data, 1, env)
        sparse = b'{"id":1,"n":1}\n{"id":2,"n":2}\n{"id":3,"n":null}\n{"id":4}\n'
        for predicate, expected in (
            ('NOT (n = 1)', [2]),
            ('n = 1 OR n IS NULL OR n IS MISSING', [1, 3, 4]),
            ('NOT (n = 1 AND n IS VALUE)', [2, 3, 4]),
        ):
            output = invoke(['--format', 'jsonl', '--mode', 'full', '-c', 'SELECT id FROM input WHERE ' + predicate, '-'], sparse, env=env)
            actual = [int(row['row']['value']['structure'][0]['value']['atom']['signed']) for row in output[1:-1]]
            assert actual == expected, (predicate, actual)
            assert int(output[-1]['complete']['scanned']) == 4
        # Determining Boolean operands never suppress an evaluated type error.
        for predicate in ('id > 0 OR n > 0', 'id < 0 AND n > 0'):
            invoke(['--format', 'csv', '--sample-records', '1', '--mismatch', 'type_error', '-c', 'SELECT id FROM input WHERE ' + predicate, '-'], b'id,n\n1,1\n2,bad\n', 1, env)
        invoke(['--format', 'csv', '--sample-records', '1', '-c', 'SELECT id FROM input WHERE id = 1 OR id = 2 LIMIT 1', '-'], b'id,n\n1,1\n2,bad\n', 1, env)
        for sql, contents, fragments in (
            ('SELECT id FROM input WHERE id > 0 OR n > 0', b'id,n\n1,1\n2,bad\n', [b'Operation: predicate; scan row: 2; column: "n"; predicate instruction: 1', b'cell state: type_error']),
            ('SELECT COUNT(n) FROM input', b'id,n\n1,1\n2,bad\n', [b'Operation: count; scan row: 2; column: "n"', b'cell state: type_error']),
            ('SELECT SUM(n) FROM input', b'id,n\n1,9223372036854775807\n2,1\n', [b'Operation: sum; scan row: 2; column: "n"', b'cell state: value', b'Checked query arithmetic']),
        ):
            result = subprocess.run([CLI, 'file-query', '--format', 'csv', '--sample-records', '1', '--mismatch', 'type_error', '-c', sql, '-'], input=contents, capture_output=True, env=env, timeout=10)
            assert result.returncode == 1, result.stderr
            assert all(fragment in result.stderr for fragment in fragments), result.stderr
            header = json.loads(result.stdout.splitlines()[0])
            assert header['binding'].encode() in result.stderr and header['plan'].encode() in result.stderr, result.stderr
            assert b'Supplied scalar:' not in result.stderr and b'Field path' not in result.stderr, result.stderr
            assert not any('complete' in json.loads(line) for line in result.stdout.splitlines())
            CASES += 1
        compressed = gzip.compress(data)
        zipped = invoke(base + ['--gzip'], compressed, env=env)
        assert ordinary == zipped
        assert ordinary[1]['row']['value']['structure'][0]['value']['atom']['signed'] == '3'
        # Optional gzip header fields and its independent RFC CRC16 check.
        header = bytearray(compressed[:10])
        header[3] = 2 | 4 | 8 | 16
        header += struct.pack('<H', 3) + b'abc' + b'filename\0comment\0'
        header += struct.pack('<H', zlib.crc32(header) & 0xffff)
        assert invoke(base + ['--gzip'], bytes(header) + compressed[10:], env=env) == ordinary
        for bad in (compressed[:-1], compressed[:10], compressed + b'garbage', compressed * 2,
                    compressed[:-8] + b'\0' * 8, bytes(header[:-1]) + b'x' + compressed[10:]):
            invoke(base + ['--gzip'], bad, 1, env)
        for flags, data_in in [(['--max-bytes', '5'], data), (['--max-encoded-bytes', '5'], data), (['--gzip', '--max-bytes', '5'], compressed)]:
            invoke(base + flags, data_in, 1, env)
        # Limit and projection never hide a source mismatch or unknown field.
        invoke(['--format', 'csv', '--sample-records', '1', '-c', 'SELECT id FROM input LIMIT 1', '-'], b'id,n\n1,1\n2,bad\n', 1, env)
        invoke(['--format', 'csv', '--sample-records', '1', '-c', 'SELECT id AS kept FROM input LIMIT 1', '-'], b'id,n\n1,1\n2,bad\n', 1, env)
        invoke(['--format', 'jsonl', '--sample-records', '1', '-c', 'SELECT id FROM input LIMIT 1', '-'], b'{"id":1}\n{"id":2,"new":3}\n', 1, env)
        error_rows = invoke(['--format', 'csv', '--sample-records', '1', '--mismatch', 'type_error', '-c', 'SELECT n FROM input', '-'], b'n\n1\nbad\n', env=env)
        assert 'type_error' in error_rows[2]['row']['value']['structure'][0]
        for data_in, format in [(b'a,a\n1,2\n', 'csv'), (b'{"x":1,"\\u0078":2}\n', 'jsonl'), (b'n\n\xff\n', 'csv')]:
            invoke(['--format', format, '-c', 'SELECT * FROM input', '-'], data_in, 1, env)
        for args in [[], ['--unknown-secret'], ['--format', 'csv', '--format', 'csv'], ['--format', 'jsonl', '--delimiter', ','], ['--help', '--max-fields', '129'], ['--mode', 'explicit', '--help']]:
            invoke(args, expected=2, env=env)
        help_result = subprocess.run([CLI, 'file-query', '--help'], capture_output=True, env=env, timeout=10)
        assert help_result.returncode == 0 and b'TMPDIR' in help_result.stdout and not help_result.stderr
        # SQL context and late file failures retain precise, independent
        # coordinates without manufacturing success after a prefix or LIMIT.
        for sql, fragments in [
            ('SELECT typo FROM input', [b'Subject: "typo"', b'column 8']),
            ("SELECT n FROM input WHERE n='wrong'", [b'Expected int64; supplied utf8', b'Value: "wrong"']),
        ]:
            result = subprocess.run([CLI, 'file-query', '--format', 'csv', '-c', sql, '-'], input=b'n\n1\n', capture_output=True, env=env, timeout=10)
            assert result.returncode == 1 and not result.stdout, (result.stdout,result.stderr)
            assert all(fragment in result.stderr for fragment in fragments), result.stderr
            assert b'.schema' not in result.stderr and b'.resume' not in result.stderr
            CASES += 1
        first = work/'good.csv'; second = work/'bad.csv'
        first.write_bytes(b'n\n1\n'); second.write_bytes(b'n\n1\nbad\n')
        for limit in (0, 1):
            result = subprocess.run([CLI, 'file-query', '--format', 'csv', '--sample-records', '1', '-c', f'SELECT n FROM input LIMIT {limit}', str(first), str(second)], capture_output=True, env=env, timeout=10)
            assert result.returncode == 1, result.stderr
            assert str(second).encode() in result.stderr, result.stderr
            assert b'logical record: 3' in result.stderr and b'record starts at byte: 4' in result.stderr, result.stderr
            assert b'field: "n"' in result.stderr and b'output is incomplete' in result.stderr, result.stderr
            assert b'LIMIT does not skip required validation' in result.stderr
            for fragment in (b'Field path (JSON Pointer): "/n"', b'Expected: int64; actual: string',
                    b'Supplied scalar: "bad"', b'Schema origin: inferred', b'Discovery examined 1 data records',
                    b'The schema was inferred from a prefix'):
                assert fragment in result.stderr, result.stderr
            assert not any('complete' in json.loads(line) for line in result.stdout.splitlines())
            CASES += 1
        schema = work/'nested-diagnostic-schema.json'
        schema.write_text(json.dumps({'definition': DEFINITION.decode(), 'type': {'structure': [
            {'name': 'payload', 'type': {'structure': [{'name': 'items', 'type': {'list': {
                'type': {'structure': [{'name': 'price', 'type': {'decimal': {'precision': 4, 'scale': 2}}}]}}}}]}}
        ]}}))
        for data, fragments in (
            (b'{"payload":{"items":[{"price":1.234}]}}\n', [b'Expected: decimal(4,2); actual: number', b'Supplied scalar: "1.234"', b'cannot be represented exactly']),
            (b'{"payload":{"items":[{"price":null}]}}\n', [b'actual: null_value', b'NULL permitted: no']),
            (b'{"payload":{"items":[{}]}}\n', [b'actual: missing', b'Missing field permitted: no']),
        ):
            result = subprocess.run([CLI, 'file-query', '--format', 'jsonl', '--mode', 'explicit', '--schema', str(schema), '-c', 'SELECT * FROM input', '-'], input=data, capture_output=True, env=env, timeout=10)
            assert result.returncode == 1, result.stderr
            for fragment in [b'Field path (JSON Pointer): "/payload/items/0/price"', b'Schema origin: specified', *fragments]:
                assert fragment in result.stderr, result.stderr
            assert not any('complete' in json.loads(line) for line in result.stdout.splitlines())
            CASES += 1
        # Input cancellation while idle and while captured bytes await EOF; all
        # captures are already unlinked even if killed without normal cleanup.
        for hard, prefix in [(False, b''), (False, b'n\n1\n'), (True, b'n\n1\n')]:
            process = subprocess.Popen([CLI, 'file-query', *base], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
            process.stdin.write(prefix)
            process.stdin.flush()
            time.sleep(0.2)
            assert list(spool.iterdir()) == []
            process.send_signal(signal.SIGKILL if hard else signal.SIGINT)
            out, err = process.communicate(timeout=5)
            assert process.returncode == (-9 if hard else 130) and out == b'', (out, err)
            assert list(spool.iterdir()) == []
            CASES += 1
        # Freeze before publication: changes to the original pathname after
        # schema publication cannot alter the captured scan, even across buffering.
        path = work / 'frozen.csv'
        path.write_bytes(b'n\n' + b'1\n' * 10000)
        process = subprocess.Popen([CLI, 'file-query', '--format', 'csv', '-c', 'SELECT * FROM input', str(path)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
        first = json.loads(process.stdout.readline())
        path.write_bytes(b'n\n9\n')
        out, err = process.communicate(timeout=30)
        assert process.returncode == 0 and not err
        records = [json.loads(line) for line in out.splitlines()]
        assert len(records) == 10001 and records[-1]['complete']['binding'] == first['binding']
        assert all(row['row']['value']['structure'][0]['value']['atom']['signed'] == '1' for row in records[:-1])
        CASES += 1
        path.write_bytes(b'n\n' + b'1\n' * 10000)
        for broken in (False, True):
            process = subprocess.Popen([CLI, 'file-query', '--format', 'csv', '-c', 'SELECT * FROM input', str(path)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
            process.stdout.readline()
            time.sleep(0.2)
            if broken:
                process.stdout.close()
            else:
                process.send_signal(signal.SIGINT)
            process.wait(timeout=5)
            assert process.returncode == (1 if broken else 130), process.stderr.read()
            if not broken:
                process.stdout.close()
            process.stderr.close()
            assert list(spool.iterdir()) == []
            CASES += 1
        # 192 MiB source exceeds the subprocess's 96 MiB address-space ceiling.
        # This proves bounded working memory; it does not claim a host cold cache.
        path = work / 'bounded.csv'
        record = b'1,' + b'x' * 65500 + b'\n'
        total = 3073
        with path.open('wb') as stream:
            stream.write(b'n,payload\n')
            for _ in range(total):
                stream.write(record)
        def memory_cap():
            resource.setrlimit(resource.RLIMIT_AS, (96 * 1024 * 1024,) * 2)
        process = subprocess.run([CLI, 'file-query', '--format', 'csv', '--mode', 'raw', '-c', 'SELECT COUNT(*) FROM input', str(path)], capture_output=True, env=env, timeout=120, preexec_fn=memory_cap)
        assert process.returncode == 0, process.stderr
        records = [json.loads(line) for line in process.stdout.splitlines()]
        assert records[-1]['complete']['scanned'] == str(total)
        assert records[1]['row']['value']['structure'][0]['value']['atom']['unsigned'] == str(total)
        assert list(spool.iterdir()) == []
        CASES += 1
    print(f'File query: {CASES} real CLI cases; independent exact codecs/results, checked gzip, quotas, cancellation/cleanup, immutable capture and 192 MiB input under 96 MiB address-space limit passed.')


if __name__ == '__main__':
    main()

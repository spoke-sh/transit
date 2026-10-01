"""Three-parser AST agreement, real plan codec and independent Arrow results."""
import json
import hashlib
import operator
from pathlib import Path
import struct
import subprocess
import sys

import pyarrow.ipc as ipc
from grammar import check
from reference import CACHE, antlr_ast


def reference(case, ast):
    names = case['schema']['columns']
    kind = case['schema']['type']
    rows = []
    for n in range(70):
        value = {'int64': n - 20, 'boolean': n % 2 == 0,
                 'utf8': "it's 東京" if n % 2 == 0 else 'a\\b',
                 'binary': b'\x00\xff' if n % 2 == 0 else b''}[kind]
        rows.append([n - 35, None if n % 5 == 0 else value])
    def atom(pred, row):
        column = names.index(pred['column'][1])
        if pred['op'] == 'is_null':
            return bytes([1, column, 1]), row[column] is None
        literal = pred['literal']
        value = literal['value']
        tag = {'int64': 1, 'boolean': 4, 'utf8': 5, 'binary': 6}[literal['kind']]
        if tag == 6:
            value = bytes.fromhex(value[2:])
        operators = {'eq': operator.eq, 'ne': operator.ne, 'lt': operator.lt,
                     'le': operator.le, 'gt': operator.gt, 'ge': operator.ge}
        encoded = bytes([2, column, list(operators).index(pred['op']), tag])
        if tag == 1:
            encoded += struct.pack('<q', value)
        elif tag == 4:
            encoded += bytes([value])
        elif tag in (5, 6):
            raw = value.encode() if tag == 5 else value
            encoded += struct.pack('<I', len(raw)) + raw
        truth = None if row[column] is None or value is None else operators[pred['op']](row[column], value)
        return encoded, truth

    def evaluate(pred, row):
        if pred is None:
            return bytes([0]), True
        if pred['op'] != 'program':
            return atom(pred, row)
        encoded = bytes([3, len(pred['instructions'])])
        stack = []
        for instruction in pred['instructions']:
            op = instruction['op']
            if op == 'not':
                encoded += bytes([3])
                value = stack.pop()
                stack.append(None if value is None else not value)
            elif op in ('and', 'or'):
                encoded += bytes([4 if op == 'and' else 5])
                right, left = stack.pop(), stack.pop()
                if op == 'and':
                    stack.append(False if False in (left, right) else None if None in (left, right) else True)
                else:
                    stack.append(True if True in (left, right) else None if None in (left, right) else False)
            else:
                data, truth = atom(instruction, row)
                encoded += data
                stack.append(truth)
        assert len(stack) == 1
        return encoded, stack[0]

    encoded_pred = evaluate(ast['predicate'], rows[0])[0]
    rows = [row for row in rows if evaluate(ast['predicate'], row)[1] is True]
    limit = ast['input']['limit'] if ast['input'] else ast['limit']
    if limit is not None:
        rows = rows[:limit]
    selection = ast['selection']
    aggregate = selection['kind']
    inner = ast['input']['projection'] if ast['input'] else None
    input_columns = [names.index(item['column'][1]) for item in inner] if inner else list(range(len(names)))
    input_names = [item['alias'] or item['column'][1] for item in inner] if inner else names
    aliases = [ast['output_alias']]
    if aggregate in ('sum', 'count_values'):
        projection = [input_columns[input_names.index(selection['column'][1])]]
        values = [row[projection[0]] for row in rows if row[projection[0]] is not None]
        expected = ({aliases[0] or 'count': [len(values)]} if aggregate == 'count_values' else
                    {aliases[0] or 'sum': [sum(values) if values else None]})
    elif aggregate == 'count':
        projection = [input_columns[0]]
        expected = {aliases[0] or 'count': [len(rows)]}
    else:
        items = selection['columns']
        projection = [names.index(item['column'][1]) for item in items] if items else [0, 1]
        aliases = [item['alias'] for item in items] if items else [None] * len(projection)
        expected = {alias or names[c]: [row[c] for row in rows] for c, alias in zip(projection, aliases)}
    encoded_names = b''
    for alias in aliases:
        raw = alias.encode() if alias is not None else b''
        encoded_names += bytes([len(raw)]) + raw
    definition = hashlib.sha256(b'transit.fuze.plan.v1.boolean-programs.count-values.2026-10-01').digest()
    encoded = (b'FZP1' + definition + bytes([['rows', 'count', 'sum', 'count_values'].index(aggregate), len(projection)])
               + bytes(projection) + encoded_names + bytes([limit is not None])
               + struct.pack('<Q', limit or 0) + encoded_pred)
    types = ['uint64' if aggregate in ('count', 'count_values') else 'int64'] if aggregate != 'rows' else [
        'int64' if index == 0 else case['schema']['type'] for index in projection]
    return encoded.hex(), expected, dict(zip(expected, types, strict=True))


def main():
    data = check()
    cases = data['select'] + data['reject'] + [
        {'id': f'extension-{i}', 'sql': sql} for i, sql in enumerate(data['extensions'])]
    source = CACHE / 'cases.json'
    source.write_text(json.dumps(cases))
    outputs = CACHE / 'arrow'
    outputs.mkdir(exist_ok=True)
    result = subprocess.run([sys.argv[1], str(source), str(outputs)], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    (CACHE / 'zig.jsonl').write_text(result.stdout)
    actual = [json.loads(line) for line in result.stdout.splitlines()]
    assert len(actual) == len(cases)
    executed = 0
    for i, (case, response) in enumerate(zip(cases, actual, strict=True)):
        assert case['id'] == response['id']
        if i >= len(data['select']):
            assert 'parse_error' in response, response
            if case['id'].startswith('extension-'):
                assert response['parse_error'] == 'UnsupportedStatement', response
            continue
        ast = antlr_ast(case['sql'])
        assert response.get('ast') == ast, (case['id'], response, ast)
        if 'compile_error' in case:
            assert response.get('compile_error') == case['compile_error'], response
            continue
        assert 'compile_error' not in response, response
        encoded, expected, types = reference(case, ast)
        assert response['encoded'] == encoded, case['id']
        combined = {name: [] for name in expected}
        assert response['segments'] > 0
        for segment in range(response['segments']):
            table = ipc.open_stream(outputs / f'{i}-{segment}.arrow').read_all()
            assert table.column_names == list(expected), (case['id'], table.schema, expected)
            for name, values in table.to_pydict().items():
                for cell in values:
                    assert cell['alternatives'] == [] and cell['state'] in (1, 3), (case, cell)
                    if cell['state'] == 1:
                        assert cell['kind'] == 7 and cell['value'] is None
                    else:
                        assert cell['kind'] == {'int64': 1, 'uint64': 2, 'boolean': 4, 'utf8': 5, 'binary': 6}[types[name]], (case['id'], name, cell, types[name])
                    combined[name].append(cell['value'])
        assert combined == expected, (case['id'], combined, expected)
        executed += 1
    print(f'SQL compiler: {len(data["select"])} Zig/ANTLR ASTs agree; {executed} real plans, '
          f'codec round trips and paged Arrow results independently checked; all exclusions rejected.')
    from unified import check as check_unified
    check_unified(sys.argv[2])
    from mutations import check as check_mutations
    check_mutations(sys.argv[3])
    from declarations import check as check_declarations
    check_declarations(sys.argv[4])


if __name__ == '__main__':
    main()

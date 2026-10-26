"""Independent parameter AST, bound-plan bytes and actual paged Arrow results.

Bindings operate on the reference AST, never on substituted SQL text. The
private corpus scalar tags exercise the finite scalar compiler; public logical
Table parameters have separate descriptor-bound query qualification.
"""
import copy
import json
import struct
import subprocess
import tempfile
from pathlib import Path

import pyarrow.ipc as ipc
from query.sql.reference import ROOT, antlr_ast, pg_ast, tree


def scalar(value):
    assert len(value) == 1
    kind, data = next(iter(value.items()))
    if kind in ('int64', 'uint64'):
        data = int(data)
    elif kind == 'float_bits':
        kind, data = 'float64', struct.unpack('<d', bytes.fromhex(data))[0]
    elif kind == 'binary':
        data = '\\x' + data
    return {'kind': kind, 'value': data}


def bind(ast, parameters):
    result = copy.deepcopy(ast)
    pred = result['predicate']
    if pred and 'literal' in pred and pred['literal']['kind'] == 'parameter':
        pred['literal'] = scalar(parameters[pred['literal']['value'] - 1])
    for scope in (result, result['input']):
        if scope and isinstance(scope['limit'], dict):
            value = scalar(parameters[scope['limit']['parameter'] - 1])
            assert value['kind'] == 'uint64'
            scope['limit'] = value['value']
    return result


def check(driver):
    from query.sql.compiler import reference

    data = json.loads((ROOT / 'contracts/sql/corpus/parameters.json').read_text())
    assert data['version'] == 1
    cases = data['cases']
    assert len({case['id'] for case in cases}) == len(cases)
    asts = {}
    for case in cases:
        case.setdefault('schema', {'name': 'items', 'columns': ['id', 'value'], 'type': 'int64'})
        if case.get('grammar', True):
            asts[case['id']] = antlr_ast(case['sql'], template=True)
            if case.get('postgres', True):
                assert asts[case['id']] == pg_ast(case['sql']), case['id']
        else:
            try:
                tree(case['sql'], 'parameterTemplate')
            except ValueError:
                pass
            else:
                raise AssertionError(f"Invalid template grammar accepted: {case['id']}")
        if case.get('has_parameters', True):
            try:
                tree(case['sql'])
            except ValueError:
                pass
            else:
                raise AssertionError(f"Ordinary grammar accepted parameters: {case['id']}")
    with tempfile.TemporaryDirectory(prefix='transit-sql-parameters-') as temp:
        root = Path(temp)
        source = root / 'cases.json'
        source.write_text(json.dumps(cases))
        result = subprocess.run([driver, str(source), temp], capture_output=True, text=True, timeout=120)
        assert result.returncode == 0, result.stderr
        responses = [json.loads(line) for line in result.stdout.splitlines()]
        assert len(responses) == len(cases)
        executed = rejected = 0
        for index, (case, response) in enumerate(zip(cases, responses, strict=True)):
            assert response['id'] == case['id']
            if 'parse_error' in case:
                assert response.get('parse_error') == case['parse_error'], (case['id'], response)
                rejected += 1
                continue
            assert response.get('ast') == asts[case['id']], (case['id'], response, asts[case['id']])
            if 'compile_error' in case:
                assert response.get('compile_error') == case['compile_error'], (case['id'], response)
                rejected += 1
                continue
            expected_bytes, expected_rows, types = reference(case, bind(asts[case['id']], case['parameters']))
            assert response['encoded'] == expected_bytes, (case['id'], response)
            actual = {name: [] for name in expected_rows}
            assert response['segments'] > 0
            for segment in range(response['segments']):
                table = ipc.open_stream(root / f'{index}-{segment}.arrow').read_all()
                assert table.column_names == list(expected_rows)
                for name, cells in table.to_pydict().items():
                    for cell in cells:
                        assert cell['alternatives'] == [] and cell['state'] in (1, 3)
                        expected_kind = {'int64': 1, 'uint64': 2, 'float64': 3, 'boolean': 4, 'utf8': 5, 'binary': 6}[types[name]]
                        assert cell['kind'] == (7 if cell['state'] == 1 else expected_kind)
                        actual[name].append(cell['value'])
            assert actual == expected_rows, (case['id'], actual, expected_rows)
            executed += 1
    print(f'SQL parameters: {len(asts)} reference ASTs, {executed} canonical plans/paged Arrow results, '
          f'{rejected} exact rejections; ordinary grammar excludes placeholders.')

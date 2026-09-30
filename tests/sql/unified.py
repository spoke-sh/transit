"""Existing reference AST -> independent five-state rows -> actual nested IPC."""
import json
import math
import operator
from pathlib import Path
import subprocess
import tempfile

import pyarrow.ipc as ipc
from reference import antlr_ast, pg_ast

NAMES = ['id', 'counter', 'fraction', 'flag', 'value', 'raw', 'missing', 'optional']


def cell(kind, value=None, state=3, conflicts=None):
    return dict(state=state, kind=kind, value=value, alternatives=conflicts or [])


def source_rows():
    rows = []
    for n in range(70):
        optional = [cell(7, state=1), cell(0, state=0), cell(1, state=2),
                    cell(0, state=4, conflicts=[dict(counter=1, replica=1, state=1, kind=7, value=None),
                         dict(counter=2, replica=2**64-1, state=3, kind=5, value='東京')])][n % 4]
        rows.append([cell(1, n-35), cell(2, 2**64-1-n), cell(3, -0.0 if n == 0 else n+0.5),
                     cell(4, n % 2 == 0), cell(7, state=1) if n % 5 == 0 else
                     cell(5, "it's 東京" if n % 2 == 0 else 'a\\b'),
                     cell(6, b'\0\xff' if n % 2 == 0 else b''), cell(0, state=0), optional])
    return rows


def expected(ast):
    rows = source_rows()
    pred = ast['predicate']
    if pred:
        index = NAMES.index(pred['column'][1])
        if pred['op'].startswith('is_'):
            state = ['missing', 'null', 'type_error', 'value', 'conflict'].index(pred['op'][3:])
            rows = [r for r in rows if r[index]['state'] == state]
        else:
            value = pred['literal']['value']
            if pred['literal']['kind'] == 'binary':
                value = bytes.fromhex(value[2:])
            op = dict(eq=operator.eq, ne=operator.ne, lt=operator.lt,
                      le=operator.le, gt=operator.gt, ge=operator.ge)[pred['op']]
            rows = [r for r in rows if r[index]['state'] == 3 and op(r[index]['value'], value)]
    limit = ast['input']['limit'] if ast['input'] else ast['limit']
    if limit is not None:
        rows = rows[:limit]
    selection = ast['selection']
    if selection['kind'] == 'count':
        return {'count': [cell(2, len(rows))]}
    if selection['kind'] == 'sum':
        column = NAMES.index(selection['column'][1])
        values = [r[column]['value'] for r in rows if r[column]['state'] == 3]
        return {'sum': [cell(1, sum(values)) if values else cell(7, state=1)]}
    columns = [NAMES.index(c[1]) for c in selection['columns']] if selection['columns'] else range(8)
    return {NAMES[c]: [r[c] for r in rows] for c in columns}


def check(driver):
    statements = [
        'SELECT optional FROM items WHERE optional IS MISSING',
        'SELECT optional FROM items WHERE optional IS TYPE_ERROR',
        'SELECT optional FROM items WHERE optional IS CONFLICT',
        'SELECT value FROM items WHERE value IS VALUE',
        'SELECT count(*) FROM items WHERE optional IS TYPE_ERROR',
        "SELECT counter FROM items WHERE counter >= '18446744073709551614'::uint64",
        "SELECT fraction FROM items WHERE fraction = '-0.0'::float64",
        "SELECT fraction FROM items WHERE fraction > '1.5e0'::float64 LIMIT 9",
        'SELECT optional, missing, raw, value, flag, fraction, counter, id FROM items',
        'SELECT id, counter, fraction FROM items LIMIT 33',
        'SELECT sum(chosen.id) FROM (SELECT raw, id, optional FROM items LIMIT 37) AS chosen',
        'SELECT * FROM items', 'SELECT counter, fraction FROM items LIMIT 18446744073709551615',
        'SELECT optional, value FROM items WHERE optional IS NULL',
        'SELECT * FROM items WHERE missing IS NULL', 'SELECT value FROM items WHERE value IS NULL',
        "SELECT value, id FROM items WHERE value <> 'it''s 東京' LIMIT 37",
        "SELECT raw FROM items WHERE raw = '\\x00ff'::bytea", 'SELECT flag FROM items WHERE flag = TRUE',
        'SELECT id FROM items WHERE id >= -1 LIMIT 0', 'SELECT count(*) FROM items',
        'SELECT sum(id) FROM (SELECT * FROM items WHERE id > -8 LIMIT 37) AS chosen',
        'SELECT count(*) FROM (SELECT optional FROM items LIMIT 33) AS chosen',
        'SELECT sum(id) FROM (SELECT id FROM items LIMIT 0) AS chosen',
    ]
    failures = [
        ('SELECT id, counter, id FROM items', 'DuplicateProjection'),
        ('SELECT id, counter, absent FROM items', 'UnknownColumn'),
        ('SELECT id, counter, fraction, flag, value, raw, missing, optional, id FROM items', 'InvalidProjection'),
        ('SELECT * FROM items WHERE counter = 1', 'TypeMismatch'),
        ('SELECT * FROM items WHERE fraction = 1', 'TypeMismatch'),
        ('SELECT * FROM items WHERE value = NULL', 'UnsupportedNullComparison'),
        ('SELECT sum(counter) FROM items', 'UnsupportedAggregate'),
        ('SELECT count(*) FROM items LIMIT 1', 'UnsupportedAggregateLimit'),
        ("SELECT optional FROM items WHERE optional = 'x'", 'QueryTypeError'),
    ]
    cases = [dict(sql=s) for s in statements] + [dict(sql=s, expected_error=e) for s, e in failures]
    asts = [antlr_ast(c['sql']) for c in cases]
    for case, ast in zip(cases, asts, strict=True):
        if ast['predicate'] is None or ast['predicate']['op'] in ('is_null', 'eq', 'ne', 'lt', 'le', 'gt', 'ge'):
            assert ast == pg_ast(case['sql'])
    with tempfile.TemporaryDirectory(prefix='transit-unified-sql-') as temp:
        root = Path(temp)
        (root/'cases.json').write_text(json.dumps(cases))
        result = subprocess.run([driver, str(root/'cases.json'), temp], capture_output=True, text=True, timeout=120)
        assert result.returncode == 0, result.stderr
        seen = set()
        for line in result.stdout.splitlines():
            response = json.loads(line)
            i = response['index']
            case = cases[i]
            if 'expected_error' in case:
                assert response.get('compile_error', response.get('execution_error')) == case['expected_error'], response
                seen.add((i, response.get('kind'), response.get('width')))
                continue
            want = expected(asts[i])
            actual = {name: [] for name in want}
            for segment in range(response['segments']):
                table = ipc.open_stream(root/f'{i}-{response["kind"]}-{response["width"]}-{segment}.arrow').read_all()
                assert table.column_names == list(want)
                for name, values in table.to_pydict().items():
                    actual[name].extend(values)
            for name in want:
                assert len(actual[name]) == len(want[name]), (case, response, name, len(actual[name]), len(want[name]))
                for row, (observed, expected_cell) in enumerate(zip(actual[name], want[name], strict=True)):
                    assert observed == expected_cell, (case, response, name, row, observed, expected_cell)
            if 'fraction' in actual and actual['fraction']:
                assert math.copysign(1, actual['fraction'][0]['value']) == math.copysign(1, want['fraction'][0]['value'])
            seen.add((i, response['kind'], response['width']))
        for i, case in enumerate(cases):
            if 'expected_error' in case and case['expected_error'] != 'QueryTypeError':
                assert (i, None, None) in seen
            else:
                assert all((i, kind, width) in seen for kind in ('kv', 'table', 'document') for width in range(1, 9))
    print(f'Unified SQL: {len(statements)} independent results, three source bases and eight page widths; '
          f'{len(failures)} explicit exclusions/failures; six types/five states and original SQL parser verified.')

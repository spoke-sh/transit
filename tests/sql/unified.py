"""Existing reference AST -> independent five-state rows -> actual nested IPC."""
import json
import math
import operator
from pathlib import Path
import subprocess
import tempfile

import pyarrow.ipc as ipc
from interfaces.deployment.reference import antlr_ast, pg_ast

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
    def atom(pred, row):
        index = NAMES.index(pred['column'][1])
        state = row[index]['state']
        if pred['op'].startswith('is_'):
            return state == ['missing', 'null', 'type_error', 'value', 'conflict'].index(pred['op'][3:])
        if state in (0, 1):
            return None
        if state in (2, 4):
            raise ValueError('QueryTypeError' if state == 2 else 'QueryConflict')
        value = pred['literal']['value']
        if pred['literal']['kind'] == 'binary':
            value = bytes.fromhex(value[2:])
        op = dict(eq=operator.eq, ne=operator.ne, lt=operator.lt,
                  le=operator.le, gt=operator.gt, ge=operator.ge)[pred['op']]
        return op(row[index]['value'], value)

    def truth(pred, row):
        if pred is None:
            return True
        if pred['op'] != 'program':
            return atom(pred, row)
        stack = []
        for instruction in pred['instructions']:
            op = instruction['op']
            if op == 'not':
                value = stack.pop()
                stack.append(None if value is None else not value)
            elif op in ('and', 'or'):
                b, a = stack.pop(), stack.pop()
                # Independent finite three-valued truth table. Every atom has
                # already run in postfix order; neither operator short circuits.
                and_table = ((False, False, False), (False, True, None), (False, None, None))
                or_table = ((False, True, None), (True, True, True), (None, True, None))
                values = (False, True, None)
                stack.append((and_table if op == 'and' else or_table)[values.index(a)][values.index(b)])
            else:
                stack.append(atom(instruction, row))
        assert len(stack) == 1
        return stack[0]

    rows = [r for r in rows if truth(ast['predicate'], r) is True]
    limit = ast['input']['limit'] if ast['input'] else ast['limit']
    if limit is not None:
        rows = rows[:limit]
    selection = ast['selection']
    if selection['kind'] == 'count':
        return {ast['output_alias'] or 'count': [cell(2, len(rows))]}
    if selection['kind'] in ('sum', 'count_values'):
        inner = ast['input']['projection'] if ast['input'] else None
        input_names = [item['alias'] or item['column'][1] for item in inner] if inner else NAMES
        input_columns = [NAMES.index(item['column'][1]) for item in inner] if inner else list(range(8))
        column = input_columns[input_names.index(selection['column'][1])]
        values = [r[column]['value'] for r in rows if r[column]['state'] == 3]
        assert all(r[column]['state'] not in (2, 4) for r in rows)
        if selection['kind'] == 'count_values':
            return {ast['output_alias'] or 'count': [cell(2, len(values))]}
        return {ast['output_alias'] or 'sum': [cell(1, sum(values)) if values else cell(7, state=1)]}
    items = selection['columns']
    columns = [NAMES.index(item['column'][1]) for item in items] if items else range(8)
    names = [item['alias'] or item['column'][1] for item in items] if items else NAMES
    return {name: [r[c] for r in rows] for c, name in zip(columns, names, strict=True)}


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
        'SELECT x.counter, x.id FROM items AS x WHERE x.id >= -1 LIMIT 9',
        'SELECT x.optional FROM items AS x WHERE x.optional IS CONFLICT',
        'SELECT "Row".optional FROM items AS "Row" WHERE "Row".optional IS TYPE_ERROR',
        'SELECT sum(chosen.id) FROM (SELECT x.id FROM items AS x WHERE x.id > -8 LIMIT 37) AS chosen',
        'SELECT id AS key, counter AS sequence, fraction AS amount, flag AS enabled, value AS text, raw AS bytes, missing AS absent, optional AS state FROM items',
        'SELECT id AS value, value AS id FROM items WHERE id >= -1 LIMIT 9',
        'SELECT value AS left_value, value AS right_value FROM items',
        'SELECT optional AS first_state, optional AS second_state FROM items',
        'SELECT x.counter AS "Counter", x.id AS "SELECT" FROM items AS x LIMIT 33',
        "SELECT fraction AS signed_zero FROM items WHERE fraction = '-0.0'::float64",
        'SELECT id AS __proto__, counter AS constructor FROM items LIMIT 2',
        'SELECT value AS text FROM items WHERE missing IS NULL',
        'SELECT count(*) AS rows FROM items WHERE optional IS TYPE_ERROR',
        'SELECT count(*) AS rows FROM items WHERE missing IS NULL',
        'SELECT sum(id) AS total FROM items WHERE id >= 0',
        'SELECT sum(chosen.amount) AS total FROM (SELECT x.id AS amount FROM items AS x WHERE x.id > -8 LIMIT 37) AS chosen',
        'SELECT sum(chosen.value) AS total FROM (SELECT value AS id, id AS value FROM items LIMIT 33) AS chosen',
        'SELECT sum(second_id) AS total FROM (SELECT id AS first_id, id AS second_id FROM items LIMIT 9) AS chosen',
        'SELECT sum("ID") AS "SUM" FROM (SELECT id AS "ID" FROM items LIMIT 0) AS chosen',
        'SELECT count(*) AS total FROM (SELECT optional AS state FROM items LIMIT 33) AS chosen',
    ]
    statements += [
        "SELECT id, value FROM items WHERE NOT value = 'a\\b'",
        "SELECT id FROM items WHERE NOT missing = 'x'",
        "SELECT id FROM items WHERE id < -30 OR NOT value = 'a\\b' AND flag = TRUE",
        "SELECT id FROM items WHERE (id < -30 OR NOT value = 'a\\b') AND flag = TRUE LIMIT 9",
        "SELECT optional FROM items WHERE optional IS TYPE_ERROR OR optional IS CONFLICT",
        "SELECT optional FROM items WHERE NOT (optional IS NULL OR optional IS MISSING)",
        "SELECT raw FROM items WHERE raw = '\\x00ff'::bytea AND NOT flag = FALSE",
        "SELECT counter FROM items WHERE counter > '18446744073709551600'::uint64 OR fraction = '-0.0'::float64",
        "SELECT count(*) FROM items WHERE NOT missing = 'x'",
        "SELECT count(*) FROM items WHERE missing = 'x' OR id < 0",
        "SELECT sum(chosen.id) FROM (SELECT id FROM items WHERE id < 0 OR value IS NULL LIMIT 9) AS chosen",
        "SELECT x.id AS key FROM items AS x WHERE NOT (x.id = 1 OR x.flag = FALSE)",
    ]
    statements += [f'SELECT count({name}) FROM items' for name in NAMES[:-1]]
    statements += [
        'SELECT count(x.value) AS present FROM items AS x',
        'SELECT count(value) AS present FROM items WHERE NOT (id < 0 OR value IS NULL)',
        'SELECT count(chosen.label) AS present FROM (SELECT value AS label FROM items WHERE id < 0 OR flag = TRUE LIMIT 9) AS chosen',
        "SELECT count(value) FROM items WHERE NOT missing = 'x'",
        'SELECT count(chosen.label) FROM (SELECT value AS label FROM items LIMIT 7) AS chosen',
        'SELECT count(value) FROM (SELECT value FROM items LIMIT 0) AS chosen',
        'SELECT count(value) FROM items WHERE missing IS NULL',
        'SELECT count(optional) FROM items WHERE optional IS NULL',
        'SELECT count(optional) FROM items WHERE optional IS MISSING',
    ]
    failures = [
        ("SELECT count(value) FROM items WHERE id = 100 AND optional = 'x'", 'QueryTypeError'),
        ("SELECT * FROM items WHERE id = 100 AND optional = 'x'", 'QueryTypeError'),
        ("SELECT * FROM items WHERE id < 100 OR optional = 'x'", 'QueryTypeError'),
        ("SELECT * FROM items WHERE NOT (optional IS NULL OR optional = 'x')", 'QueryTypeError'),
        ("SELECT * FROM items WHERE id = 1 AND counter = 2", 'TypeMismatch'),
        ("SELECT * FROM items WHERE id = 1 OR absent = 2", 'UnknownColumn'),
        ('SELECT count(optional) FROM items', 'QueryTypeError'),
        ('SELECT count(optional) FROM items WHERE optional IS CONFLICT', 'QueryConflict'),
        ('SELECT count(value) FROM items LIMIT 1', 'UnsupportedAggregateLimit'),
        ('SELECT count(chosen.value) FROM (SELECT value AS label FROM items) AS chosen', 'UnknownColumn'),
        ('SELECT id, counter, id FROM items', 'DuplicateProjection'),
        ('SELECT id, counter, absent FROM items', 'UnknownColumn'),
        ('SELECT id, counter, fraction, flag, value, raw, missing, optional, id FROM items', 'InvalidProjection'),
        ('SELECT * FROM items WHERE counter = 1', 'TypeMismatch'),
        ('SELECT * FROM items WHERE fraction = 1', 'TypeMismatch'),
        ('SELECT * FROM items WHERE value = NULL', 'UnsupportedNullComparison'),
        ('SELECT sum(counter) FROM items', 'UnsupportedAggregate'),
        ('SELECT count(*) FROM items LIMIT 1', 'UnsupportedAggregateLimit'),
        ("SELECT optional FROM items WHERE optional = 'x'", 'QueryTypeError'),
        ('SELECT id AS key, counter AS key FROM items', 'DuplicateColumn'),
        ('SELECT id AS counter, counter FROM items', 'DuplicateColumn'),
        ('SELECT id AS key, id AS key FROM items', 'DuplicateProjection'),
        ('SELECT id AS key FROM items WHERE key > 0', 'UnknownColumn'),
        ('SELECT sum(chosen.id) FROM (SELECT id AS amount FROM items) AS chosen', 'UnknownColumn'),
        ('SELECT sum(amount) FROM (SELECT counter AS amount FROM items) AS chosen', 'UnsupportedAggregate'),
        ('SELECT count(*) FROM (SELECT id AS key, counter AS key FROM items) AS chosen', 'DuplicateColumn'),
        ('SELECT sum(id) FROM (SELECT id AS "ID" FROM items) AS chosen', 'UnknownColumn'),
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
                    if expected_cell['kind'] == 3 and expected_cell['state'] == 3:
                        assert math.copysign(1, observed['value']) == math.copysign(1, expected_cell['value'])
            seen.add((i, response['kind'], response['width']))
        for i, case in enumerate(cases):
            if 'expected_error' in case and case['expected_error'] not in ('QueryTypeError', 'QueryConflict'):
                assert (i, None, None) in seen
            else:
                assert all((i, kind, width) in seen for kind in ('kv', 'table', 'document') for width in range(1, 9))
    print(f'Unified SQL: {len(statements)} independent results, three source bases and eight page widths; '
          f'{len(failures)} explicit exclusions/failures; six types/five states and original SQL parser verified.')

#!/usr/bin/env python3
"""Independent finite relational specification, not a production executor.

Small Python relations establish exact bags, row identities, NULL rules and
ordered overflow. SQLite independently checks the overlapping SQL subset.
Nothing here imports Transit code, opens a realm or establishes recovery proof.
"""
from runner.paths import ROOT
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import random
import sqlite3
import struct

FIXTURE = ROOT / 'packages/zig/transit-fuze/src/fixtures/relational.json'
DEFINITION = b'transit.fuze.relational.v1.2026-10-26'
MIN_I64, MAX_I64, MAX_U64 = -(2**63), 2**63 - 1, 2**64 - 1


def group_key(values):
    return tuple((value is not None, value or 0) for value in values)


def value(pair, column):
    side, field = column.split('.')
    row = pair[0 if side == 'l' else 1]
    return None if row is None else row[{'id': 0, 'key': 1, 'value': 2}[field]]


def predicate(pair, expression):
    if expression is None:
        return True
    item = value(pair, expression['column'])
    op = expression['op']
    if op == 'is_null':
        return item is None
    if op == 'is_not_null':
        return item is not None
    if item is None:
        return None
    other = expression['value']
    return {'eq': item == other, 'gt': item > other, 'lt': item < other}[op]


def evaluate(case):
    """Deliberately materializing oracle, limited to small verification inputs."""
    inputs = []
    for side in ('left', 'right'):
        rows = case.get(side, [])
        assert len(rows) <= 32, 'oracle input bound'
        assert len({row[0] for row in rows}) == len(rows), 'duplicate source row identity'
        for row in rows:
            assert len(row) == 3 and 0 < row[0] <= MAX_I64
            assert all(v is None or type(v) is int and MIN_I64 <= v <= MAX_I64 for v in row)
        inputs.append(sorted(rows))
    left = [r for r in inputs[0] if predicate((r, None), case.get('left_filter')) is True]
    right = [r for r in inputs[1] if predicate((None, r), case.get('right_filter')) is True]
    pairs = []
    for lrow in left:
        if case['join'] == 'none':
            pairs.append((lrow, None))
            continue
        matches = [r for r in right if lrow[1] is not None and r[1] is not None and lrow[1] == r[1]]
        pairs.extend((lrow, r) for r in matches)
        if not matches and case['join'] == 'left':
            pairs.append((lrow, None))
    pairs = [p for p in pairs if predicate(p, case.get('filter')) is True]
    assert len(pairs) <= 1024, 'oracle fanout bound'
    outputs, keys = case['outputs'], case.get('group_by', [])
    grouped = bool(keys) or any(o[1] != 'column' for o in outputs)
    if not grouped:
        return {'rows': [{'identity': [p[0][0], p[1][0] if p[1] else None],
                          'values': [value(p, o[2]) for o in outputs]} for p in pairs], 'error': None}
    groups = {}
    if not keys:
        groups[()] = [0 if o[1] in ('count_all', 'count') else None for o in outputs]
    for pair in pairs:
        key = tuple(value(pair, column) for column in keys)
        if key not in groups:
            groups[key] = [value(pair, o[2]) if o[1] == 'column' else
                           0 if o[1] in ('count_all', 'count') else None for o in outputs]
        cells = groups[key]
        for index, output in enumerate(outputs):
            kind = output[1]
            atom = value(pair, output[2]) if kind != 'count_all' else None
            if kind == 'column':
                assert output[2] in keys, 'ungrouped projection'
            elif kind == 'count_all' or kind == 'count' and atom is not None:
                cells[index] += 1
                assert cells[index] <= MAX_U64
            elif kind == 'sum' and atom is not None:
                total = (cells[index] or 0) + atom
                if not MIN_I64 <= total <= MAX_I64:
                    return {'rows': [], 'error': {'code': 'Overflow', 'operator': 'sum',
                            'identity': [pair[0][0], pair[1][0] if pair[1] else None],
                            'output': index, 'group': list(key)}}
                cells[index] = total
    return {'rows': [{'identity': list(key), 'values': groups[key]}
                     for key in sorted(groups, key=group_key)], 'error': None}


def sqlite_result(case):
    def condition(expr):
        if expr is None:
            return '1'
        column, op = expr['column'], expr['op']
        if op in ('is_null', 'is_not_null'):
            return column + (' IS NULL' if op == 'is_null' else ' IS NOT NULL')
        raise AssertionError('comparison must be rendered by where')

    def where(expr):
        if expr is None or expr['op'] in ('is_null', 'is_not_null'):
            return condition(expr)
        operator = {'eq': '=', 'gt': '>', 'lt': '<'}[expr['op']]
        return f"{expr['column']} {operator} {expr['value']}"

    with sqlite3.connect(':memory:') as db:
        for side, alias in [('left', 'l'), ('right', 'r')]:
            db.execute(f'CREATE TABLE {alias}(id INTEGER PRIMARY KEY, key INTEGER, value INTEGER)')
            db.executemany(f'INSERT INTO {alias} VALUES (?, ?, ?)', case.get(side, []))
        expressions = []
        for _, kind, *columns in case['outputs']:
            expressions.append('COUNT(*)' if kind == 'count_all' else columns[0]
                               if kind == 'column' else f'{kind.upper()}({columns[0]})')
        sql = 'SELECT ' + ', '.join(expressions)
        sql += ' FROM (SELECT * FROM l WHERE ' + where(case.get('left_filter')) + ') AS l'
        if case['join'] != 'none':
            sql += (' LEFT JOIN ' if case['join'] == 'left' else ' JOIN ')
            sql += '(SELECT * FROM r WHERE ' + where(case.get('right_filter')) + ') AS r ON l.key = r.key'
        sql += ' WHERE ' + where(case.get('filter'))
        if case.get('group_by'):
            sql += ' GROUP BY ' + ', '.join(case['group_by'])
            sql += ' ORDER BY ' + ', '.join(case['group_by'])
        elif all(o[1] == 'column' for o in case['outputs']):
            sql += ' ORDER BY l.id' + (', r.id' if case['join'] != 'none' else '')
        return [list(row) for row in db.execute(sql)]


def semantic_cases():
    projection = [['left', 'column', 'l.value'], ['right', 'column', 'r.value']]
    aggregates = [['key', 'column', 'l.key'], ['rows', 'count_all'],
                  ['values', 'count', 'r.value'], ['total', 'sum', 'r.value']]
    base = dict(name='duplicate bag', join='inner', left=[[2, 7, 20], [1, 7, 10]],
                right=[[3, 7, 3], [1, 7, 1], [2, 7, 2]], outputs=projection)
    cases = [base]
    def add(name, **changes):
        case = deepcopy(base)
        case.update(name=name, **changes)
        cases.append(case)
    add('left unmatched count distinction', join='left', left=[[1, 4, 8]], right=[],
        outputs=aggregates, group_by=['l.key'])
    add('nulls do not join', left=[[1, None, 1]], right=[[1, None, 2]])
    add('nulls form one group', join='none', left=[[3, 1, 7], [2, None, 4], [1, None, 3]], right=[],
        group_by=['l.key'], outputs=[['key', 'column', 'l.key'], ['n', 'count_all'], ['s', 'sum', 'l.value']])
    add('empty ungrouped', join='none', left=[], right=[],
        outputs=[['n', 'count_all'], ['v', 'count', 'l.value'], ['s', 'sum', 'l.value']])
    add('empty grouped', join='none', left=[], right=[], group_by=['l.key'],
        outputs=[['key', 'column', 'l.key'], ['n', 'count_all']])
    add('all null sum', join='none', left=[[1, 1, None], [2, 1, None]], right=[],
        outputs=[['n', 'count_all'], ['v', 'count', 'l.value'], ['s', 'sum', 'l.value']])
    add('ordered positive overflow', join='none', left=[[3, 1, -1], [2, 1, 1], [1, 1, MAX_I64]], right=[],
        outputs=[['s', 'sum', 'l.value']])
    add('ordered negative overflow', join='none', left=[[1, 1, MIN_I64], [2, 1, -1], [3, 1, 1]], right=[],
        outputs=[['s', 'sum', 'l.value']])
    add('first failure follows contributors not group sorting', join='none',
        left=[[1, 9, MAX_I64], [2, 9, 1], [3, -9, MAX_I64], [4, -9, 1]], right=[],
        group_by=['l.key'], outputs=[['key', 'column', 'l.key'], ['s', 'sum', 'l.value']])
    add('self join distinct aliases', right=base['left'])
    add('right prefilter preserves unmatched', join='left', right_filter={'column': 'r.value', 'op': 'gt', 'value': 3})
    add('right postfilter removes unmatched', join='left', right=[], filter={'column': 'r.value', 'op': 'gt', 'value': 3})
    add('grouping keys from both sides', join='left', left=[[1, 1, 5], [2, 2, 6]], right=[[1, 1, 8]],
        group_by=['l.key', 'r.key'], outputs=[['l', 'column', 'l.key'], ['r', 'column', 'r.key'], ['n', 'count_all']])
    add('group without aggregates', join='none', left=[[1, 2, 0], [2, 2, 1]], right=[],
        group_by=['l.key'], outputs=[['key', 'column', 'l.key']])
    return cases


def identity_fixture():
    def text(s):
        encoded = s.encode()
        return bytes([len(encoded)]) + encoded
    def schema(object_id):
        encoded = b'FTS1' + text('transit.table.schema.v1.2026-11-01.integrity') + struct.pack('<QQQH', object_id, 1, 3, 2)
        descriptor = b'FTY1' + text('transit.fuze.types.v1.2026-09-30') + b'\1'
        for identity, label in [(1, 'key'), (2, 'value')]:
            encoded += struct.pack('<Q', identity) + text(label) + struct.pack('<H', len(descriptor)) + descriptor
            encoded += struct.pack('<BIB', 1, 0, 0)
        return hashlib.sha256(encoded + b'\0\0').digest()
    def column(source, identity):
        return struct.pack('<BQ', source, identity)
    schemas = [schema(11), schema(22)]
    encoded = DEFINITION + b'\0prepared\0\2'
    for alias, resource, fingerprint in zip(['l', 'r'], [101, 202], schemas):
        encoded += text(alias) + struct.pack('<QQQQ', 1, resource, 9, 7) + fingerprint
    encoded += b'\2' + column(0, 1) + column(1, 1)  # left join
    encoded += b'\0\0\0'  # two source predicates and one joined predicate
    encoded += b'\1' + column(0, 1) + b'\4'
    for label, tag, reference in [('key', 0, (0, 1)), ('rows', 1, None), ('values', 2, (1, 2)), ('total', 3, (1, 2))]:
        encoded += text(label) + bytes([tag])
        if reference:
            encoded += column(*reference)
    encoded += b'\1' + struct.pack('<QQQQQB', 4096, 8192, 16384, 1000, 10000, 2)
    prepared = hashlib.sha256(encoded).digest()
    bound = DEFINITION + b'\0bound\0' + prepared
    for resource, revision, marker, fingerprint in zip([101, 202], [7, 12], [17, 34], schemas):
        bound += b'\0' + struct.pack('<QQ', resource, revision) + bytes([marker]) * 32 + fingerprint
    return {'prepared': prepared.hex(), 'bound': hashlib.sha256(bound).hexdigest()}


def fixtures():
    cases = semantic_cases() + generated_cases()
    return {'definition': DEFINITION.decode(), 'identity': identity_fixture(),
            'nulls': [{'left': l, 'right': r, 'join': l is not None and r is not None and l == r,
                       'order': (group_key([l]) > group_key([r])) - (group_key([l]) < group_key([r]))}
                      for l in [None, MIN_I64, -1, 0, 1, MAX_I64] for r in [None, MIN_I64, -1, 0, 1, MAX_I64]],
            'sums': [{'values': values, 'error_at': next((i for i in range(len(values))
                       if not MIN_I64 <= sum(v for v in values[:i + 1] if v is not None) <= MAX_I64), None),
                      'value': sum(v for v in values if v is not None) if any(v is not None for v in values) else None}
                     for values in [[], [None, None], [1, None, -1], [MAX_I64, 1, -1],
                                    [MIN_I64, -1, 1], [MAX_I64, -1, 1], [MIN_I64, 1, -1]]],
            'cases': [dict(case, expected=evaluate(case)) for case in cases]}


def generated_cases():
    """One seeded corpus shared by Python/SQLite and production-executor checks."""
    prototype = semantic_cases()[0]
    cases = []
    rng = random.Random(70)
    for index in range(300):
        case = deepcopy(prototype)
        case['name'] = f'seed-70-{index}'
        case['join'] = rng.choice(['none', 'inner', 'left'])
        for side in ('left', 'right'):
            case[side] = [[i + 1, rng.choice([None, -1, 0, 1]), rng.choice([None, -3, 0, 3])]
                          for i in range(rng.randrange(9))]
            rng.shuffle(case[side])
        if case['join'] == 'none':
            case['outputs'] = [['key', 'column', 'l.key'], ['value', 'column', 'l.value']]
        if rng.choice([True, False]):
            case['group_by'] = ['l.key']
            column = 'l.value' if case['join'] == 'none' else 'r.value'
            case['outputs'] = [['key', 'column', 'l.key'], ['n', 'count_all'], ['v', 'count', column], ['s', 'sum', column]]
        cases.append(case)
    return cases


def verify_oracle():
    cases = semantic_cases()
    # Fixed witnesses prevent the oracle and SQL comparison from jointly
    # blessing incorrect identities, NULL treatment or first-overflow order.
    assert len(evaluate(cases[0])['rows']) == 6
    assert evaluate(cases[1])['rows'][0]['values'] == [4, 1, 0, None]
    assert evaluate(cases[2])['rows'] == []
    assert evaluate(cases[3])['rows'][0]['values'] == [None, 2, 7]
    assert evaluate(cases[4])['rows'][0]['values'] == [0, 0, None]
    assert evaluate(cases[5])['rows'] == []
    assert evaluate(cases[7])['error']['identity'] == [2, None]
    assert evaluate(cases[9])['error']['group'] == [9]
    cases += generated_cases()
    checked = 0
    for case in cases:
        expected = evaluate(case)
        if expected['error'] is not None:
            continue  # SQLite's aggregate/error contract is not the ordered oracle.
        assert [r['values'] for r in expected['rows']] == sqlite_result(case), case['name']
        permutation = deepcopy(case)
        permutation['left'].reverse()
        permutation['right'].reverse()
        assert evaluate(permutation) == expected, case['name']
        checked += 1
    return checked


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='regenerate independent fixtures')
    args = parser.parse_args()
    count = verify_oracle()
    content = json.dumps(fixtures(), indent=2) + '\n'
    if args.write:
        FIXTURE.write_text(content)
    else:
        assert FIXTURE.read_text() == content, 'relational fixtures drift; run tests/query/execution/relational.py --write'
    print(f'relational oracle: {count} SQLite comparisons; identities, NULLs and ordered overflow verified')


if __name__ == '__main__':
    main()

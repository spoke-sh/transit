"""Independent state declaration ASTs, formatting and Table capability checks.

This exercises a pure compiler, not catalog publication or administrative APIs.
"""
import hashlib
import itertools
import json
import subprocess
from reference import ROOT, CACHE, tree, identifier


TYPES = dict(INT64='int64', BOOL='boolean', UTF8='utf8', BINARY='binary')


def ast(sql):
    extension = tree(sql).extensionStatement()
    if extension.createTable():
        ctx = extension.createTable()
        return dict(kind='table', name=identifier(ctx.identifier()), columns=[
            dict(name=identifier(col.identifier()), type=TYPES[col.dataType().getText().upper()],
                 nullability=('not_null' if col.nullability().NOT() else 'null')
                 if col.nullability() else 'unspecified') for col in ctx.columnDef()])
    if extension.createKv():
        ctx = extension.createKv()
        return dict(kind='kv', name=identifier(ctx.identifier()), type=TYPES[ctx.dataType().getText().upper()])
    ctx = extension.createDocument()
    return dict(kind='document', name=identifier(ctx.identifier()))


def format_definition(value):
    def quoted(name):
        return '"' + name + '"'
    kinds = {v: k for k, v in TYPES.items()}
    sql = f'CREATE {value["kind"].upper()} {quoted(value["name"])}'
    if value['kind'] == 'kv':
        sql += f' ({kinds[value["type"]]})'
    if value['kind'] == 'table':
        sql += ' (' + ', '.join(quoted(col['name']) + ' ' + kinds[col['type']] +
                               dict(unspecified='', null=' NULL', not_null=' NOT NULL')[col['nullability']]
                               for col in value['columns']) + ')'
    return sql + ';'


def table_capability(value):
    if value['kind'] != 'table':
        return dict(table_error='NotTableDeclaration')
    columns = value['columns']
    if len(columns) != 2:
        return dict(table_error='UnsupportedTableColumnCount')
    key, val = columns
    if 'unspecified' in (key['nullability'], val['nullability']):
        return dict(table_error='UnspecifiedNullability')
    if key['type'] != 'int64' or key['nullability'] != 'not_null':
        return dict(table_error='UnsupportedTableKey')
    if val['nullability'] != 'null':
        return dict(table_error='UnsupportedTableNullability')
    encoded = bytes([1, list(TYPES.values()).index(val['type']) + 1])
    for col in columns:
        name = col['name'].encode('ascii')
        encoded += bytes([len(name)]) + name
    return dict(schema=hashlib.sha256(encoded).hexdigest())


def check(binary):
    data = json.loads((ROOT / 'contracts/sql/corpus/declarations.json').read_text())
    assert data['version'] == 1
    cases = list(data['cases'])
    # Complete product of the four scalar types and three nullability spellings
    # for both columns; this tests capability rejection, not only happy paths.
    for kt, vt, kn, vn in itertools.product(TYPES, TYPES, ('', ' NULL', ' NOT NULL'), ('', ' NULL', ' NOT NULL')):
        cases.append(dict(sql=f'CREATE TABLE items (id {kt}{kn}, value {vt}{vn});'))
    path = CACHE / 'declaration-cases.json'
    path.write_text(json.dumps([case['sql'] for case in cases]))
    result = subprocess.run([binary, str(path)], capture_output=True, text=True, check=True)
    (CACHE / 'declaration-results.jsonl').write_text(result.stdout)
    responses = [json.loads(line) for line in result.stdout.splitlines()]
    assert len(responses) == len(cases)
    agreed = compatible = 0
    for index, (case, response) in enumerate(zip(cases, responses, strict=True)):
        assert response['index'] == index
        if case.get('syntax_error'):
            try:
                tree(case['sql'])
            except ValueError:
                pass
            else:
                raise AssertionError(('invalid syntax accepted', case))
            assert 'parse_error' in response, (case, response)
            continue
        if 'parse_error' in case:
            tree(case['sql'])  # Reference grammar can exceed bounded compiler profile.
            assert response.get('parse_error') == case['parse_error'], (case, response)
            continue
        expected = ast(case['sql'])
        assert response.get('ast') == expected, (case, expected, response)
        agreed += 1
        if 'validation_error' in case:
            assert response.get('validation_error') == case['validation_error'], (case, response)
            continue
        canonical = format_definition(expected)
        assert response['formatted'] == canonical, (case, response)
        assert ast(canonical) == expected, (canonical, expected)
        capability = table_capability(expected)
        assert {key: response.get(key) for key in capability} == capability, (case, response, capability)
        compatible += 'schema' in capability
    print(f'State declarations: {agreed} Zig/ANTLR ASTs agree; {len(cases)} cases; '
          f'{compatible} exact Table schema fingerprints; canonical round trips and capability exclusions. '
          'Offline only; no catalog/publication claim.')

"""Independent mutation ASTs, Table storage bytes and private-turn outcomes.

This checks a compiler and application helper, not native admission/recovery.
"""
import json
import struct
import subprocess
from reference import ROOT, CACHE, tree, identifier, column, literal


def antlr_mutation(sql):
    ctx = tree(sql).mutationStatement()
    assert ctx
    names = [identifier(name) for name in ctx.identifier()]
    if ctx.INSERT():
        return dict(source=names[0], kind='insert', columns=names[1:],
                    rows=[[literal(value) for value in row.literal()] for row in ctx.mutationRow()])
    columns = [column(value) for value in ctx.columnReference()]
    values = [literal(value) for value in ctx.literal()]
    if ctx.UPDATE():
        return dict(source=names[0], kind='update', column=columns[0], value=values[0],
                    key_column=columns[1], key=values[1])
    return dict(source=names[0], kind='delete', key_column=columns[0], key=values[0])


def pg_literal(node):
    if 'TypeCast' in node:
        cast = node['TypeCast']
        assert cast['typeName']['names'][-1]['String']['sval'] == 'bytea'
        return dict(kind='binary', value=cast['arg']['A_Const']['sval']['sval'])
    value = node['A_Const']
    if value.get('isnull'):
        return dict(kind='null', value=None)
    for key, kind, default in [('ival', 'int64', 0), ('fval', 'int64', 0),
                               ('boolval', 'boolean', False), ('sval', 'utf8', '')]:
        if key in value:
            raw = value[key].get(key, default)
            return dict(kind=kind, value=int(raw) if kind == 'int64' else raw)
    raise AssertionError(value)


def pg_mutation(sql):
    from pglast.parser import parse_sql_json
    statements = json.loads(parse_sql_json(sql))['stmts']
    assert len(statements) == 1
    tag, node = next(iter(statements[0]['stmt'].items()))
    if tag == 'InsertStmt':
        return dict(source=node['relation']['relname'], kind='insert',
                    columns=[entry['ResTarget']['name'] for entry in node['cols']],
                    rows=[[pg_literal(value) for value in row['List']['items']]
                          for row in node['selectStmt']['SelectStmt']['valuesLists']])
    predicate = node['whereClause']['A_Expr']
    assert predicate['name'] == [{'String': {'sval': '='}}]
    fields = [field['String']['sval'] for field in predicate['lexpr']['ColumnRef']['fields']]
    result = dict(source=node['relation']['relname'], kind='update' if tag == 'UpdateStmt' else 'delete',
                  key_column=[None, fields[0]] if len(fields) == 1 else fields,
                  key=pg_literal(predicate['rexpr']))
    if tag == 'UpdateStmt':
        assert len(node['targetList']) == 1
        target = node['targetList'][0]['ResTarget']
        result.update(column=[None, target['name']], value=pg_literal(target['val']))
    else:
        assert tag == 'DeleteStmt'
    return result


def key(value):
    return b'\0r' + struct.pack('<I', 1) + struct.pack('>Q', value + 2**63)


def cell(value):
    kind, data = value['kind'], value['value']
    if kind == 'null':
        return b'\1\0'
    body = struct.pack('<q', data) if kind == 'int64' else (bytes([data]) if kind == 'boolean'
           else data.encode() if kind == 'utf8' else bytes.fromhex(data[2:]))
    return b'\1\1' + body


def check(binary):
    data = json.loads((ROOT/'contracts/sql/corpus/mutations.json').read_text())
    assert data['version'] == 1
    cases, expected = [], []
    agreed = 0
    for case in data['cases']:
        kind = case['kind']
        descriptor = b'TBL1' + bytes([['int64','boolean','utf8','binary'].index(kind)+1]) + b'\2id\5value'
        existing = {7: dict(kind='null', value=None),
                    9: dict(kind=kind, value={'int64':1,'boolean':False,'utf8':'existing','binary':'\\x00'}[kind])}
        entries = [dict(key=(b'\0t'+struct.pack('<I',1)).hex(), value=descriptor.hex())]
        entries += [dict(key=key(k).hex(), value=cell(v).hex()) for k,v in existing.items()]
        cases.append(dict(sql=case['sql'], kind=kind, entries=entries))
        if case.get('syntax_error'):
            try:
                tree(case['sql'])
            except ValueError:
                pass
            else:
                raise AssertionError(('mutation exclusion accepted', case))
            expected.append(None)
            continue
        ast = antlr_mutation(case['sql'])
        assert ast == pg_mutation(case['sql']), (case, ast, pg_mutation(case['sql']))
        agreed += 1
        if 'error' in case:
            expected.append(case['error'])
            continue
        assert ast['source'] == 'items'
        changes = []
        if ast['kind'] == 'insert':
            key_index = ast['columns'].index('id')
            value_index = ast['columns'].index('value')
            for row in ast['rows']:
                k, v = row[key_index]['value'], row[value_index]
                assert k not in existing
                changes.append(dict(key=key(k).hex(), value=cell(v).hex()))
        else:
            assert ast['key_column'][-1] == 'id'
            k = ast['key']['value']
            if k in existing:
                changes.append(dict(key=key(k).hex(), value=cell(ast['value']).hex() if ast['kind']=='update' else None))
        expected.append(dict(affected=len(changes), mutations=changes+[None]*(4-len(changes))))
    path = CACHE/'mutation-cases.json'
    path.write_text(json.dumps(cases))
    result = subprocess.run([binary, str(path)], capture_output=True, text=True, check=True)
    (CACHE/'mutation-results.jsonl').write_text(result.stdout)
    actual = [json.loads(line) for line in result.stdout.splitlines()]
    assert len(actual) == len(expected)
    for index, (response, wanted) in enumerate(zip(actual, expected, strict=True)):
        assert response['index'] == index
        if isinstance(wanted, dict):
            assert {name:response.get(name) for name in wanted} == wanted, (cases[index], response, wanted)
            if cases[index]['sql'].startswith('UPDATE') and wanted['affected'] == 1:
                assert response['reads'] == 3, ('redundant update point reads', response)
        else:
            assert 'err' in response and (wanted is None or response['err']==wanted), (cases[index], response, wanted)
    print(f'SQL mutations: {agreed} ANTLR/Postgres ASTs agree; {len(cases)} independent storage/outcome or rejection cases; maximum {max(row["reads"] for row in actual)} private point reads. No authority/admission claim.')

"""Independent general DML grammar, typed rows and canonical FDM1 payloads.

Uniqueness against stored rows and atomic publication belong to the separate
Table storage/native proofs. This oracle never reports compile success as an
applied mutation or successful statement prefix.
"""
import hashlib
import json
from decimal import Decimal
import re
import struct
import subprocess
from query.sql.reference import ROOT, CACHE, tree, identifier, column
from query.sql.table_reference import create, schema_bytes, literal, cell_bytes

TYPES=dict(int64='INT64',boolean='BOOLEAN',utf8='UTF8',binary='BINARY')


def sized(cell,typ):
    data=cell_bytes(cell,typ);return struct.pack('<I',len(data))+data


def compiled_bytes(sql,basis):
    schema=create(basis)['schema']; columns=schema['columns']; ctx=tree(sql).mutationStatement(); assert ctx
    names=[identifier(n) for n in ctx.identifier()]; assert names[0]=='items'
    def find(ref):
        qualifier,name=column(ref) if hasattr(ref,'identifier') else (None,identifier(ref))
        assert qualifier in (None,'items')
        return next(i for i,c in enumerate(columns) if c['name']==name)
    def assigned(value,i):
        return (columns[i]['default'] or {'null':{}}) if value.DEFAULT() else literal(value.literal(),columns[i]['type'])
    data=b'FDM1'+hashlib.sha256(schema_bytes(schema)).digest()+b'\x05items'
    if ctx.INSERT():
        selected=[next(i for i,c in enumerate(columns) if c['name']==name) for name in names[1:]] if len(names)>1 else list(range(len(columns)))
        rows=[]
        for row in ctx.mutationRow():
            values=[c['default'] or {'null':{}} for c in columns]
            for i,value in zip(selected,row.mutationValue(),strict=True): values[i]=assigned(value,i)
            rows.append(values)
        typ={'structure':[dict(name=c['name'],type=c['type'],nullable=c['nullable'],optional=False) for c in columns]}
        data+=b'\1'+struct.pack('<H',len(rows))+b''.join(sized({'value':{'structure':row}},typ) for row in rows)
    elif ctx.UPDATE():
        assignments=ctx.assignment();data+=b'\2'+struct.pack('<H',len(assignments))
        for entry in assignments:
            i=find(entry.columnReference()); value=entry.mutationValue()
            data+=struct.pack('<Q',int(columns[i]['id']))+(b'\0' if value.DEFAULT() else b'\1'+sized(assigned(value,i),columns[i]['type']))
    else: assert ctx.DELETE();data+=b'\3'
    def atom(ctx):
        i=find(ctx.columnReference())
        if ctx.IS():
            value=dict(MISSING=0,NULL=1,TYPE_ERROR=2,VALUE=3,CONFLICT=4)[ctx.cellState().getText().upper()]
            result=[bytes([0,1,i,value])]
            return result+[b'\1'] if ctx.NOT() else result
        op={'=':0,'<>':1,'!=':1,'<':2,'<=':3,'>':4,'>=':5}[ctx.comparison().getText()]
        return [bytes([0,2,i,op])+sized(literal(ctx.literal(),columns[i]['type']),columns[i]['type'])]
    def join(parts,op):
        result=list(parts[0])
        for part in parts[1:]:result+=part+[op]
        return result
    def negation(ctx):
        if ctx.NOT():return negation(ctx.negation())+[b'\1']
        if ctx.predicate():return disjunction(ctx.predicate().disjunction())
        return atom(ctx.predicateAtom())
    def conjunction(ctx):return join([negation(n) for n in ctx.negation()],b'\2')
    def disjunction(ctx):return join([conjunction(c) for c in ctx.conjunction()],b'\3')
    if ctx.whereClause():
        program=disjunction(ctx.whereClause().predicate().disjunction());data+=bytes([1,len(program)])+b''.join(program)
    else:data+=b'\0'
    return data


def postgres_agreement(sql):
    # Transit constructors and five-state predicates have separate independent
    # typed oracles. Compare the shared SQL forms without pretending PostgreSQL
    # has these values, operators or Transit's binary-literal type semantics.
    if re.search(r"\b(STRUCT|LIST|ARRAY|MAP|UNION|INTERVAL)\s*\(|\bX\s*'|IS\s+(NOT\s+)?(MISSING|VALUE|TYPE_ERROR|CONFLICT)\b",sql,re.I): return False
    from pglast.parser import parse_sql_json
    def number(raw): return ('number',str(Decimal(str(raw)).normalize()))
    def antlr_literal(ctx):
        if ctx.DEFAULT(): return ('default',)
        ctx=ctx.literal()
        if ctx.NULL_(): return ('null',)
        if ctx.TRUE() or ctx.FALSE(): return ('boolean',bool(ctx.TRUE()))
        if ctx.STRING(): return ('text',ctx.STRING().getText()[1:-1].replace("''", "'"))
        return number(ctx.getText())
    def pg_value(node):
        if 'SetToDefault' in node:return ('default',)
        value=node['A_Const']
        if value.get('isnull'):return ('null',)
        if 'boolval' in value:return ('boolean',value['boolval'].get('boolval',False))
        if 'sval' in value:return ('text',value['sval'].get('sval',''))
        key='ival' if 'ival' in value else 'fval';return number(value[key].get(key,0))
    def pg_column(node):
        fields=[x['String']['sval'] for x in node['ColumnRef']['fields']]
        return [None,*fields] if len(fields)==1 else fields
    def pg_predicate(node):
        if 'BoolExpr' in node:
            value=node['BoolExpr'];return (value['boolop'],*[pg_predicate(n) for n in value['args']])
        if 'NullTest' in node:
            value=node['NullTest'];return ('state',pg_column(value['arg']),value.get('nulltesttype','IS_NULL'))
        value=node['A_Expr'];return ('compare',pg_column(value['lexpr']),value['name'][0]['String']['sval'],pg_value(value['rexpr']))
    def antlr_predicate(ctx):
        def group(parts,op): return parts[0] if len(parts)==1 else (op,*parts)
        def negation(ctx):
            if ctx.NOT():return ('NOT_EXPR',negation(ctx.negation()))
            if ctx.predicate():return disjunction(ctx.predicate().disjunction())
            value=ctx.predicateAtom(); name=column(value.columnReference())
            if value.IS():return ('state',name,'IS_NOT_NULL' if value.NOT() else 'IS_NULL')
            # A predicate has a literal rather than a mutationValue wrapper.
            class Operand:
                def DEFAULT(self):return None
                def literal(self):return value.literal()
            return ('compare',name,value.comparison().getText().replace('!=','<>'),antlr_literal(Operand()))
        def conjunction(ctx):return group([negation(n) for n in ctx.negation()],'AND_EXPR')
        def disjunction(ctx):return group([conjunction(n) for n in ctx.conjunction()],'OR_EXPR')
        return disjunction(ctx.predicate().disjunction())
    ctx=tree(sql).mutationStatement(); names=[identifier(n) for n in ctx.identifier()]
    tag,node=next(iter(json.loads(parse_sql_json(sql))['stmts'][0]['stmt'].items()))
    left={'source':names[0]};right={'source':node['relation']['relname']}
    if ctx.INSERT():
        assert tag=='InsertStmt'
        left.update(columns=names[1:] or None,rows=[[antlr_literal(v) for v in row.mutationValue()] for row in ctx.mutationRow()])
        right.update(columns=[x['ResTarget']['name'] for x in node['cols']] if 'cols' in node else None,rows=[[pg_value(v) for v in row['List']['items']] for row in node['selectStmt']['SelectStmt']['valuesLists']])
    else:
        left['predicate']=antlr_predicate(ctx.whereClause()) if ctx.whereClause() else None
        right['predicate']=pg_predicate(node['whereClause']) if 'whereClause' in node else None
        if ctx.UPDATE():
            assert tag=='UpdateStmt'
            left['assignments']=[(column(v.columnReference()),antlr_literal(v.mutationValue())) for v in ctx.assignment()]
            right['assignments']=[([None,v['ResTarget']['name']],pg_value(v['ResTarget']['val'])) for v in node['targetList']]
        else:assert tag=='DeleteStmt'
    assert left==right,(sql,left,right)
    return True


def check(binary):
    data=json.loads((ROOT/'contracts/sql/corpus/mutations.json').read_text());assert data['version']==1
    cases=[]
    for case in data['cases']:
        case=dict(case); kind=case.pop('kind','int64')
        case.setdefault('basis',f'CREATE TABLE items (id INT64 PRIMARY KEY, value {TYPES[kind]}, extra BOOLEAN DEFAULT TRUE)')
        cases.append(case)
    for n in (1,4,32):
        cases.append(dict(sql='INSERT INTO items (id,value) VALUES '+','.join(f'({i},{i*10})' for i in range(n)),basis='CREATE TABLE items (id INTEGER PRIMARY KEY,value BIGINT)'))
    rich="CREATE TABLE items (id INTEGER PRIMARY KEY, amount DECIMAL(18,2) DEFAULT 1.25, payload STRUCT(data BINARY, names LIST(UTF8)))"
    cases += [dict(basis=rich,sql="INSERT INTO items (payload,id) VALUES (STRUCT(X'00ff',LIST('Ada','東京')),1), (NULL,2)"),
              dict(basis=rich,sql="UPDATE items SET amount=DEFAULT,payload=STRUCT(X'',LIST()) WHERE id>=1 AND NOT (amount<0 OR amount IS NULL)"),
              dict(basis=rich,sql="DELETE FROM items WHERE amount IS NOT NULL AND id<>9")]
    path=CACHE/'mutation-cases.json';path.write_text(json.dumps([{k:v for k,v in c.items() if k in ('sql','basis')} for c in cases]))
    result=subprocess.run([binary,str(path)],capture_output=True,text=True,check=True)
    (CACHE/'mutation-results.jsonl').write_text(result.stdout)
    actual=[json.loads(line) for line in result.stdout.splitlines()];assert len(actual)==len(cases)
    agreed=pg_cases=0
    for index,(case,response) in enumerate(zip(cases,actual,strict=True)):
        assert response.pop('index')==index
        if case.get('syntax_error'):
            try:tree(case['sql'])
            except ValueError:pass
            else:raise AssertionError(('invalid syntax accepted',case))
            assert 'err' in response,(case,response)
        elif case.get('error'):
            pg_cases+=postgres_agreement(case['sql'])
            tree(case['sql']);assert response==dict(err=case['error']),(case,response)
        else:
            pg_cases+=postgres_agreement(case['sql'])
            expected=compiled_bytes(case['sql'],case['basis']).hex()
            assert response==dict(bytes=expected),(case,response,expected);agreed+=1
    print(f'General DML: {pg_cases} PostgreSQL/ANTLR AST comparisons; {agreed} exact independent ANTLR/typed FDM1 plans; {len(cases)} cases, defaults, reordered fields, general predicates and compound literals. Codec round trips preserve intent. No admission/publication claim.')


if __name__=='__main__':
    import sys
    from query.sql.reference import generate
    generate();check(sys.argv[1])

"""Independent general Table DDL/schema bytes and offline KV/Document checks."""
import copy
import itertools
import json
import subprocess
from query.sql.reference import ROOT, CACHE, tree, identifier
from query.sql.table_reference import ALIASES, create, column, data_type, literal, schema_bytes

TYPES=dict(INT64='int64',BOOL='boolean',UTF8='utf8',BINARY='binary')
BASIS='CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(200), active BOOLEAN DEFAULT TRUE)'


def expected(case):
    if 'log' in case:
        extension=tree(case['sql']).extensionStatement()
        assert extension.createLog() or extension.alterLog() or extension.dropLog()
        return case['log']
    extension=tree(case['sql']).extensionStatement()
    if extension.createTable():
        value=create(case['sql']); value['schema_hex']=schema_bytes(value['schema']).hex(); return value
    if extension.alterTable():
        ctx=extension.alterTable(); names=[identifier(n) for n in ctx.identifier()]
        schema=copy.deepcopy(create(case['basis'])['schema']); renamed=None
        if ctx.RENAME() and len(names)==2: renamed=names[1]
        else:
            schema['revision']=str(int(schema['revision'])+1)
            if ctx.ADD():
                value,primary=column(ctx.columnDef(),int(schema['next_column'])); assert not primary
                schema['columns'].append(value); schema['next_column']=str(int(schema['next_column'])+1)
            else:
                selected=next(c for c in schema['columns'] if c['name']==names[1])
                if ctx.RENAME(): selected['name']=names[2]
                elif ctx.TYPE(): selected['type'],selected['max_characters']=data_type(ctx.dataType())
                elif ctx.DEFAULT(): selected['default']=literal(ctx.literal(),selected['type']) if ctx.SET() else None
                elif ctx.NOT(): selected['nullable']=bool(ctx.DROP())
                else: assert ctx.DROP(); schema['columns'].remove(selected)
        return dict(kind='alter',name=names[0],rename=renamed,schema=schema)
    if extension.dropTable():
        ctx=extension.dropTable(); return dict(kind='drop',name=identifier(ctx.identifier()),if_exists=bool(ctx.IF()),object=7 if case.get('basis') else None)
    ctx=extension.createKv() or extension.createDocument(); assert ctx
    kind='kv' if extension.createKv() else 'document'; name=identifier(ctx.identifier())
    typ=TYPES[ctx.dataType().getText().upper()] if kind=='kv' else None
    formatted='CREATE '+kind.upper()+' "'+name+'"'+(' ('+next(k for k,v in TYPES.items() if v==typ)+')' if typ else '')+';'
    return dict(kind=kind,name=name,type=typ,formatted=formatted)


def check(binary):
    data=json.loads((ROOT/'contracts/sql/corpus/declarations.json').read_text()); assert data['version']==1
    cases=list(data['cases'])
    logs=json.loads((ROOT/'contracts/sql/corpus/log-declarations.json').read_text()); assert logs['version']==1
    cases.extend(logs['cases'])
    # Omitted/null/not-null remains a semantic Cartesian product, now admitting
    # the general schema instead of imposing a positional key/value restriction.
    for kt,vt,kn,vn in itertools.product(TYPES,TYPES,('', ' NULL',' NOT NULL'),('', ' NULL',' NOT NULL')):
        cases.append(dict(sql=f'CREATE TABLE items (id {kt}{kn}, value {vt}{vn})'))
    for name in ALIASES:
        spelling={'DOUBLEPRECISION':'DOUBLE PRECISION','CHARACTERVARYING':'CHARACTER VARYING'}.get(name,name)
        cases.append(dict(sql=f'CREATE TABLE typed (x {spelling})'))
    for spelling in ('DECIMAL','DECIMAL(18,2)','NUMERIC(20)','TIMESTAMP','TIMESTAMPTZ','TIME(9) WITHOUT TIME ZONE','TIMESTAMP(6) WITH TIME ZONE','VARCHAR(320)'):
        cases.append(dict(sql=f'CREATE TABLE typed (x {spelling})'))
    for typ,value in (
        ('INT128','-170141183460469231731687303715884105728'),('UINT128','340282366920938463463374607431768211455'),
        ('FLOAT32','-0.0'),('FLOAT64','1.25e2'),('DECIMAL(18,2)','123456789.25'),('BOOLEAN','TRUE'),
        ('UTF8',"'東京é'"),('BINARY',"X'00ff80'"),('DATE',"DATE '2000-02-29'"),('TIME',"TIME '23:59:59.999999999'"),
        ('TIMESTAMP',"TIMESTAMP '2000-02-29T12:34:56.123456'"),('TIMESTAMPTZ',"TIMESTAMP '2000-02-29T12:34:56.123456Z'"),
        ('INTERVAL','INTERVAL(1,2,3)'),('UUID',"UUID '00112233-4455-6677-8899-aabbccddeeff'"),('JSON',"JSON '{\"a\":[1,true]}'"),
        ('STRUCT(n INTEGER NOT NULL, label UTF8 OPTIONAL)',"STRUCT(7, MISSING)"),('LIST(INTEGER NOT NULL)','LIST(1,2,3)'),
        ('ARRAY(UTF8,2)',"ARRAY('one',NULL)"),('MAP(UTF8,INTEGER)',"MAP('one',1,'two',NULL)"),
        ('UNION(n INTEGER NOT NULL, text UTF8)',"UNION(text,'東京')"),
    ):
        cases.append(dict(sql=f'CREATE TABLE typed (x {typ} DEFAULT {value})'))
    for change in ('ADD COLUMN email VARCHAR(320)','ADD COLUMN enabled BOOLEAN NOT NULL DEFAULT TRUE','DROP COLUMN name','RENAME COLUMN name TO full_name','RENAME TO renamed','ALTER COLUMN name SET DEFAULT \'Ada\'','ALTER COLUMN active DROP DEFAULT','ALTER COLUMN name SET NOT NULL','ALTER COLUMN name DROP NOT NULL','ALTER COLUMN name TYPE VARCHAR(400)','ALTER COLUMN id SET DATA TYPE BIGINT'):
        cases.append(dict(sql='ALTER TABLE people '+change,basis=BASIS))
    for collation in ('UTF8_BINARY', 'ASCII_CI', 'EBCDIC_CP037'):
        cases.append(dict(sql=f"CREATE TABLE collated (k TEXT COLLATE {collation} PRIMARY KEY, label TEXT DEFAULT 'A' COLLATE {collation})"))
        cases.append(dict(sql=f'ALTER TABLE people ADD COLUMN label TEXT COLLATE {collation}', basis=BASIS))
    cases += [
        dict(sql='CREATE TABLE bad (n BIGINT COLLATE ASCII_CI)', error='IncompatibleColumnCollation'),
        dict(sql='CREATE TABLE bad (s TEXT COLLATE ASCII_CI COLLATE UTF8_BINARY)', error='DuplicateColumnConstraint'),
        dict(sql='CREATE TABLE bad (s TEXT COLLATE ICU_ROOT)', error='UnsupportedColumnCollation', reference_reject=True),
        dict(sql="CREATE TABLE bad (s TEXT COLLATE EBCDIC_CP037 DEFAULT '東京')", error='UnrepresentableEbcdic037'),
    ]
    cases += [dict(sql='DROP TABLE people RESTRICT',basis=BASIS),dict(sql='DROP TABLE IF EXISTS absent'),dict(sql='DROP TABLE absent',error='TableNotFound')]
    path=CACHE/'declaration-cases.json'; path.write_text(json.dumps([{k:v for k,v in c.items() if k in ('sql','basis')} for c in cases]))
    result=subprocess.run([binary,str(path)],capture_output=True,text=True,check=True)
    (CACHE/'declaration-results.jsonl').write_text(result.stdout)
    responses=[json.loads(line) for line in result.stdout.splitlines()]; assert len(responses)==len(cases)
    successful=0
    for index,(case,response) in enumerate(zip(cases,responses,strict=True)):
        assert response.pop('index')==index
        if case.get('syntax_error'):
            try: tree(case['sql'])
            except ValueError: pass
            else: raise AssertionError(('invalid syntax accepted',case))
            assert 'err' in response,(case,response)
        elif case.get('error'):
            if not case.get('reference_reject'): tree(case['sql'])
            assert response==dict(err=case['error']),(case,response)
        else:
            wanted=expected(case); assert response==wanted,(case,wanted,response); successful+=1
    print(f'General DDL: {len(cases)} independent grammar/compiler cases; {successful} exact schema/identity/type/default/evolution and Stream/Queue policy comparisons, canonical FTS1 bytes and offline KV/Document formatting. No publication claim.')


if __name__ == '__main__':
    import sys
    from query.sql.reference import generate
    generate()
    check(sys.argv[1])

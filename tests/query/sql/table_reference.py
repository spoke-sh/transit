"""Independent ANTLR Table schema and typed-literal semantics.

Only Python standard values and the independent fixture codec are used; no
Transit parser, binding code or exported runtime schema supplies expectations.
"""
from datetime import date, datetime, timezone
from decimal import Decimal, localcontext
import hashlib
import json
import struct
import uuid
from query.sql.reference import ROOT, identifier, tree
from query.files.fuze_file_query import descriptor, cell_bytes
from catalog.tables.table_schema import DEFINITION

ALIASES = {}
for kind, names in {
    'int8':'INT8 TINYINT', 'int16':'INT16 SMALLINT', 'int32':'INT32 INT INTEGER',
    'int64':'INT64 BIGINT', 'int128':'INT128', 'uint8':'UINT8', 'uint16':'UINT16',
    'uint32':'UINT32', 'uint64':'UINT64', 'uint128':'UINT128', 'float32':'FLOAT32 REAL',
    'float64':'FLOAT64 DOUBLE FLOAT', 'boolean':'BOOL BOOLEAN', 'utf8':'UTF8 TEXT VARCHAR',
    'binary':'BINARY BLOB BYTEA', 'date':'DATE', 'time':'TIME', 'interval':'INTERVAL',
    'uuid':'UUID', 'json':'JSON',
}.items():
    for name in names.split(): ALIASES[name] = kind
ALIASES.update({'DOUBLEPRECISION':'float64', 'CHARACTERVARYING':'utf8'})


def nullable(ctx):
    return not ctx or not ctx.NOT()


def data_type(ctx):
    if ctx.scalarTypeName():
        name = ctx.scalarTypeName().getText().upper()
        parameters = [int(i.getText()) for i in ctx.INTEGER()]
        if name in ('DECIMAL', 'NUMERIC'):
            return {'decimal': dict(precision=parameters[0] if parameters else 38,
                                    scale=parameters[1] if len(parameters)>1 else 0)}, None
        if name in ('TIMESTAMP', 'TIMESTAMPTZ'):
            return {'timestamp':'utc' if name=='TIMESTAMPTZ' or ctx.WITH() else 'civil'}, None
        return {ALIASES[name]:{}}, parameters[0] if name in ('VARCHAR', 'CHARACTERVARYING') and parameters else None
    if ctx.STRUCT() or ctx.UNION():
        fields = []
        for item in ctx.typeField():
            typ, bound = data_type(item.dataType()); assert bound is None
            fields.append(dict(name=identifier(item.identifier()), type=typ, nullable=nullable(item.nullability()), optional=bool(item.OPTIONAL())))
        return {'structure' if ctx.STRUCT() else 'tagged_union':fields}, None
    children = ctx.dataType()
    types = [data_type(child)[0] for child in children]
    # Nullability clauses belong to the immediately preceding type, not an
    # implicit positional default when just one of MAP's children specifies it.
    flags = []
    for i, child in enumerate(children):
        stop = children[i+1].start.tokenIndex if i+1<len(children) else ctx.stop.tokenIndex
        attached = [n for n in ctx.nullability() if child.stop.tokenIndex < n.start.tokenIndex < stop]
        flags.append(nullable(attached[0]) if attached else True)
    if ctx.MAP(): return {'map':dict(key=types[0], value=dict(type=types[1], nullable=flags[1]))}, None
    element = dict(type=types[0], nullable=flags[0])
    return ({'array':dict(element=element, length=int(ctx.INTEGER(0).getText()))} if ctx.ARRAY() else {'list':element}), None


def atom(name, value): return {'value': {'atom': {name:value}}}


def literal(ctx, typ):
    if ctx.NULL_(): return {'null': {}}
    if ctx.MISSING(): return {'missing': {}}
    kind, params = next(iter(typ.items()))
    raw = ctx.STRING().getText()[1:-1].replace("''", "'") if ctx.STRING() else ctx.getText()
    if kind in ('structure', 'list', 'array'):
        children = ctx.literal()
        types = [field['type'] for field in params] if kind=='structure' else [params['type'] if kind=='list' else params['element']['type']] * len(children)
        return {'value':{kind:[literal(child, t) for child,t in zip(children, types, strict=True)]}}
    if kind=='map':
        children=ctx.literal(); assert len(children)%2==0
        entries=[dict(key=literal(children[i],params['key'])['value']['atom'], value=literal(children[i+1],params['value']['type'])) for i in range(0,len(children),2)]
        return {'value': {'map':entries}}
    if kind=='tagged_union':
        selected=identifier(ctx.identifier()); index=next(i for i,f in enumerate(params) if f['name']==selected)
        return {'value': {'tagged_union':dict(index=index, value=literal(ctx.literal(0),params[index]['type']))}}
    if kind=='interval':
        numbers=[c.getText() for c in ctx.literal()]
        return atom('interval',dict(zip(('months','days','nanos'),numbers,strict=True)))
    if kind.startswith(('int','uint')): return atom('signed' if kind.startswith('int') else 'unsigned',str(int(raw)))
    if kind.startswith('float'): return atom('float_bits', struct.pack('<f' if kind=='float32' else '<d',float(raw)).hex())
    if kind=='decimal':
        with localcontext() as context:
            context.prec=100
            coefficient=Decimal(raw)*10**params['scale']; assert coefficient==int(coefficient)
            return atom('decimal',str(int(coefficient)))
    if kind=='boolean': return atom('boolean',bool(ctx.TRUE()))
    if kind=='utf8': return atom('utf8',raw)
    if kind=='binary': return atom('binary',raw[2:] if raw.startswith('\\x') else raw)
    if kind=='json': json.loads(raw); return {'value':{'json':raw}}
    if kind=='uuid': return atom('uuid',uuid.UUID(raw).hex)
    if kind=='date': return atom('date_days',str((date.fromisoformat(raw)-date(1970,1,1)).days))
    if kind=='time':
        parts=raw.split(':'); seconds=Decimal(parts[2]); nanos=(int(parts[0])*3600+int(parts[1])*60+seconds)*10**9
        return atom('time_nanos',str(int(nanos)))
    if kind=='timestamp':
        value=datetime.fromisoformat(raw); epoch=datetime(1970,1,1,tzinfo=timezone.utc if params=='utc' else None)
        delta=value-epoch
        return atom('timestamp_micros',str((delta.days*86400+delta.seconds)*10**6+delta.microseconds))
    raise AssertionError((kind,raw))


def column(ctx, identity):
    typ, bound=data_type(ctx.dataType())
    result=dict(id=str(identity),name=identifier(ctx.identifier()),type=typ,nullable=True,default=None,max_characters=bound,encoding='plain',collation='none')
    primary=False
    for constraint in ctx.columnConstraint():
        if constraint.nullability(): result['nullable']=nullable(constraint.nullability())
        elif constraint.DEFAULT(): result['default']=literal(constraint.literal(),typ)
        elif constraint.COLLATE(): result['collation']=constraint.collation().getText().lower()
        else: assert constraint.PRIMARY(); primary=True
    if primary: result['nullable']=False
    return result,primary


def create(sql):
    ctx=tree(sql).extensionStatement().createTable(); assert ctx
    columns=[]; keys=[]
    for item in ctx.tableElement():
        if item.columnDef():
            value,primary=column(item.columnDef(),len(columns)+1); columns.append(value)
            if primary: keys.append(value['name'])
        else: keys += [identifier(n) for n in item.identifier()]
    for value in columns:
        if value['name'] in keys: value['nullable']=False
    schema=dict(definition=json.loads((ROOT/'contracts/transit-v1.schema.json').read_text())['x-transit']['definition'], object='7',revision='1',next_column=str(len(columns)+1),columns=columns,
                primary_key=[next(c['id'] for c in columns if c['name']==key) for key in keys],
                integrity=dict(next_id=1, checks=[], foreign_keys=[]))
    return dict(kind='table',name=identifier(ctx.identifier()),if_not_exists=bool(ctx.IF()),schema=schema)


def schema_bytes(schema):
    data=b'FTS1'+bytes([len(DEFINITION)])+DEFINITION
    data+=struct.pack('<QQQH',*[int(schema[k]) for k in ('object','revision','next_column')],len(schema['columns']))
    for column in schema['columns']:
        name=column['name'].encode(); desc=descriptor(column['type'])
        data+=struct.pack('<QB',int(column['id']),len(name))+name+struct.pack('<H',len(desc))+desc
        data+=struct.pack('<BIB',column['nullable'],column['max_characters'] or 0,column['default'] is not None)
        if column['default'] is not None:
            cell=b'FVL1'+struct.pack('<H',len(desc))+desc+bytes([column['nullable']])+cell_bytes(column['default'],column['type'])
            data+=struct.pack('<I',len(cell))+cell
    data+=struct.pack('<H',len(schema['primary_key']))+b''.join(struct.pack('<Q',int(k)) for k in schema['primary_key'])
    if any(c['encoding'] != 'plain' or c['collation'] != 'none' for c in schema['columns']):
        data += b'FTP1'
        for c in schema['columns']:
            assert c['encoding'] == 'plain'
            data += bytes([0, {'none': 0, 'utf8_binary': 1, 'ascii_ci': 2, 'ebcdic_cp037': 3}[c['collation']]])
    return data

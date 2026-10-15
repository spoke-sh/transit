"""Copied into a clean wheel consumer; only public typed SDK operations here."""
import asyncio
import json
from pathlib import Path
import struct
import sys


def atom_value(datatype, value):
    from transit_station import unified as q
    if datatype is q.DecoderType.FLOAT64: return q.Scalar('float', value, 64)
    return q.Scalar({'int64': 'signed', 'uint64': 'unsigned'}.get(datatype.value, datatype.value), value)


def table_source(columns):
    from transit_client import ResourceRef, ProcessRef
    from transit_station import unified as q, catalog
    metadata = catalog.Metadata(catalog.Scope(ResourceRef(1, 7), 9), 9, 1, 'items', '01'*32, 17, 1, 1, catalog.MetadataCommitment(200, '01'*32), namespace=1)
    return q.TableSource(ProcessRef(1, 3), metadata, catalog.Schema(9, 1, len(columns)+1, tuple(columns)))


def wire_type(value):
    from transit_station import logical as l
    if isinstance(value, l.ScalarType): return {value.kind: {}}
    if isinstance(value, l.DecimalType): return {'decimal': dict(precision=value.precision, scale=value.scale)}
    if isinstance(value, l.TimestampType): return {'timestamp': value.zone}
    if isinstance(value, (l.StructureType, l.UnionType)):
        return {'structure' if isinstance(value, l.StructureType) else 'tagged_union': [dict(name=f.name, type=wire_type(f.type), nullable=f.nullable, optional=f.optional) for f in value.fields]}
    def element(item): return dict(type=wire_type(item.type), nullable=item.nullable)
    if isinstance(value, l.ListType): return {'list': element(value.element)}
    if isinstance(value, l.ArrayType): return {'array': dict(length=value.length, element=element(value.element))}
    if isinstance(value, l.MapType): return {'map': dict(key=wire_type(value.key), value=element(value.value))}
    raise AssertionError(value)


def codecs(config):
    from transit_client import ResourceRef
    from transit_client.errors import TransitError
    from transit_station import unified as q, logical as l, catalog
    from transit_station.document import DocumentReference
    from transit_station.query import Comparison
    resource = ResourceRef(46, 7)
    sources = [q.KVSource(resource, b'data/', q.Decoder(q.DecoderType.BINARY), q.Decoder(q.DecoderType.UINT64)),
        table_source([catalog.Column(1, 'id', l.ScalarType('int64'), False), catalog.Column(2, 'label', l.ScalarType('utf8'))]),
        q.DocumentSource(DocumentReference(resource, 2**64-1, 3, 1, 42), (
            q.Projection(q.DecoderColumn('title', q.DecoderType.UTF8), ('title',)),
            q.Projection(q.DecoderColumn('body', q.DecoderType.UTF8), ('body',), mode=q.ProjectionMode.TEXT)))]
    fixtures = json.loads(Path(config['bundles']).read_text())
    for index, source in enumerate(sources):
        scalar = q.Scalar('unsigned', 2**64-1) if index == 0 else q.Scalar('utf8', 'x'*512)
        bundle = q.Bundle.prepare(source, q.Plan((1, 0), q.Compare(1, Comparison.NE, scalar), 2**64-1), q.Budgets(1000, 500, 1048576))
        assert bundle.data.hex() == fixtures[index]['wire_hex']
        named = q.Bundle.prepare(source, q.Plan((1, 0), q.Compare(1, Comparison.NE, scalar), 2**64-1, output_names=('Result', None)), q.Budgets(1000, 500, 1048576))
        assert named.data.hex() == fixtures[index]['named_wire_hex']
        counted = q.Bundle.prepare(source, q.Plan((1,), aggregate=q.Aggregate.COUNT_VALUES, output_names=('present',)), q.Budgets(1000, 500, 1048576))
        assert counted.data.hex() == fixtures[index]['counted_wire_hex']
    for source in (q.KVSource(resource, b'', q.Decoder(q.DecoderType.BINARY, 2), q.Decoder(q.DecoderType.UTF8)),
                   q.DocumentSource(DocumentReference(resource, 1, 1, 1, 1), ())):
        try: q.Bundle.prepare(source, q.Plan((0,)), q.Budgets(1, 1, 1))
        except TransitError: pass
        else: raise AssertionError('unsupported source accepted')
    scalar_values = (-(2**63), 2**64-1, -0.0, True, 'café é 🙂', b'\0\xff\x80', 'x'*512)
    boolean_fixtures = json.loads(Path(config['boolean']).read_text())
    for index, fixture in enumerate(boolean_fixtures):
        datatype = tuple(q.DecoderType)[fixture['type']-1]
        source = q.KVSource(resource, b'', q.Decoder(datatype), q.Decoder(q.DecoderType.UINT64))
        atom = q.PredicateAtom
        if index < 7:
            instructions = (atom(q.Compare(0, Comparison.EQ, atom_value(datatype, scalar_values[index]))),
                q.PredicateOperator.NEGATE, atom(q.IsState(0, q.State.NULL)), q.PredicateOperator.DISJUNCTION)
        elif fixture['name'] == 'all-and-not-null':
            instructions = (atom(), atom(q.IsState(0, q.State.NULL)), q.PredicateOperator.NEGATE, q.PredicateOperator.CONJUNCTION)
        else: instructions = (atom(),) + (q.PredicateOperator.NEGATE,)*63
        bundle = q.Bundle.prepare(source, q.Plan((0,), q.PredicateProgram(instructions)), q.Budgets(1000, 500, 1048576))
        assert bundle.data.hex() == fixture['wire_hex']
    for instructions in ((), (q.PredicateOperator.NEGATE,), (atom(), atom()),
            (atom(),)+(q.PredicateOperator.NEGATE,)*64, (atom(q.PredicateProgram((atom(),))),),
            (atom(q.IsState(8, q.State.NULL)),), (atom(q.Compare(0, Comparison.EQ, q.Scalar('utf8', 'wrong type'))),)):
        try: q.Bundle.prepare(source, q.Plan((0,), q.PredicateProgram(instructions)), q.Budgets(1, 1, 1024))
        except (TypeError, ValueError, TransitError): pass
        else: raise AssertionError('invalid predicate program accepted')
    columns = tuple(q.Column(v, l.ScalarType(v), True, True) for v in ('int64', 'uint64', 'float64', 'boolean', 'utf8', 'binary'))
    rows = q.decode_arrow(columns, Path(config['arrow']).read_bytes(), 5)
    assert len(rows) == 5 and all(len(row) == 6 for row in rows)
    for row, state in zip(rows, (l.Missing, l.Null, l.SourceTypeError, l.Present, l.Conflict), strict=True): assert all(isinstance(cell, state) for cell in row)
    expected = (-(2**63), 2**64-1, -0.0, False, 'café é 東京🙂', b'\0\xff\x80')
    for index, value in enumerate(expected):
        assert rows[3][index].value.value == value
        alternatives = rows[4][index].alternatives
        assert [(v.counter, v.replica, type(v.value)) for v in alternatives] == [
            (2**64-1, 1, l.Present), (2**64-1, 2, l.Null)]
        assert alternatives[0].value.value.value == value
    assert struct.pack('<d', rows[3][2].value.value).hex() == '0000000000000080'
    assert q.decode_arrow(columns, Path(config['empty']).read_bytes(), 0) == ()
    try: q.decode_arrow(columns, Path(config['malformed']).read_bytes(), 5)
    except TransitError: pass
    else: raise AssertionError('hidden Arrow value accepted')
    wide_source = table_source([catalog.Column(i+1, f'列 {i}', l.ScalarType('uint128')) for i in range(128)])
    wide_bundle = q.Bundle.prepare(wide_source, q.Plan(tuple(range(128)), q.Compare(127, Comparison.EQ, q.Scalar('unsigned', 2**128-1))), q.Budgets(1, 1, 65536))
    assert len(wide_bundle.data) > 1000
    datatype = l.ListType(l.Element(l.ScalarType('uint128'), True))
    with l.Codec() as codec:
        value = codec.value_json(json.dumps(dict(definition='transit.fuze.types.v1.2026-09-30',
            field=dict(name='value', type=wire_type(datatype)), cell={'value': {'list': [{'value': {'atom': {'unsigned': str(2**128-1)}}}, {'null': {}}]}})))
        nested = q.decode_arrow((q.Column('value', datatype),), codec.arrow(value), 1)
        assert nested == ((l.Present(l.SequenceValue('list', (l.Present(l.Atom('unsigned', 2**128-1)), l.Null()))),),)
    print('Python installed unified codecs: three sources, nine Boolean bundles, six scalar types, 128 columns, nested uint128, five states and malformed rejection passed', flush=True)


def source(config):
    from transit_client import ResourceRef
    from transit_station import unified as q, logical as l, catalog
    from transit_station.document import DocumentReference
    from transit_station.query import Comparison
    resource = ResourceRef(config['connection']['realm'], config['connection']['resource'])
    if config['kind'] == 'kv':
        value = q.KVSource(resource, b'k', q.Decoder(q.DecoderType.BINARY), q.Decoder(q.DecoderType.UTF8))
    elif config['kind'] == 'table':
        from transit_client import ProcessRef
        values = config['connection']
        owner = ProcessRef(resource.realm, values['source'])
        with catalog.Client(config['url'], values['principal'], Path(config['seed_file']), catalog.Connection(owner, catalog.Scope(resource, 1))) as client:
            definition = client.lookup('items')
            assert definition is not None
            value = q.TableSource(owner, definition.metadata, definition.schema)
    else:
        value = q.DocumentSource(DocumentReference(resource, 17, 1, 1, 13), (
            q.Projection(q.DecoderColumn('value', q.DecoderType.UTF8), relative=True),
            q.Projection(q.DecoderColumn('counter', q.DecoderType.UINT64), relative=True, mode=q.ProjectionMode.ELEMENT_COUNTER),
            q.Projection(q.DecoderColumn('replica', q.DecoderType.UINT64), relative=True, mode=q.ProjectionMode.ELEMENT_REPLICA),
            q.Projection(q.DecoderColumn('optional', q.DecoderType.UTF8), ('optional',))), ('items',))
    doc = config['kind'] == 'document'
    column = 0 if doc else 1
    predicate = q.Compare(column, Comparison.NE, q.Scalar('utf8', 'x'*512))
    if config['compound']:
        ceiling = f"東京🙂/{'x'*(64 if doc else 128)}/{'10' if doc else '39'}"
        predicate = q.PredicateProgram((q.PredicateAtom(predicate),
            q.PredicateAtom(q.Compare(column, Comparison.GE, q.Scalar('utf8', ceiling))),
            q.PredicateAtom(q.IsState(column, q.State.NULL)), q.PredicateOperator.DISJUNCTION,
            q.PredicateOperator.NEGATE, q.PredicateOperator.CONJUNCTION))
    plan = q.Plan((0, 1, 2, 3) if doc else (1,), predicate,
        output_names=('Result', None, None, None) if config['kind'] == 'document' else ('Result',))
    bundle = q.Bundle.prepare(value, plan, q.Budgets(1000, 100, 1048576))
    assert bundle.data == Path(config['bundle']).read_bytes()
    return value


async def serve(config, asynchronous):
    from transit_client import ProcessRef, ResourceRef
    from transit_client.errors import TransitError, UncertainOperation
    from transit_station import unified as q, logical as l, catalog
    values = config['connection']
    realm = values['realm']
    connection = q.Connection(ProcessRef(realm, values['source']), ResourceRef(realm, values['resource']),
        ProcessRef(realm, values['requester']), ResourceRef(realm, values['requests']))
    owner = (q.AsyncClient if asynchronous else q.Client)(config['url'], values['principal'], Path(config['seed_file']), connection, timeout_ms=10000)
    declared = source(config)
    async def invoke(method, *args):
        value = getattr(owner, method)(*args)
        return await value if asynchronous else value
    try:
        description = await invoke('describe', declared)
        assert description.bundle_bytes == 25069 and description.batch_rows == 8
        print(json.dumps({'ready': True}), flush=True)
        for line in sys.stdin:
            action = json.loads(line)
            if 'close' in action:
                break
            try:
                if 'compile' in action:
                    v = action['compile']; limits = v['scope']['limits']
                    def scalar(value):
                        kind, data = next(iter(value.items()))
                        if kind in ('signed', 'unsigned', 'decimal', 'date_days', 'time_nanos', 'timestamp_micros'): data = int(data)
                        elif kind == 'float_bits':
                            return q.Scalar('float', struct.unpack('<f' if len(data) == 8 else '<d', bytes.fromhex(data))[0], 32 if len(data) == 8 else 64)
                        elif kind == 'binary': data = bytes.fromhex(data)
                        return q.Scalar(kind, data)
                    parameters = None if v.get('parameters') is None else tuple(map(scalar, v['parameters']))
                    compiled = await invoke('compile_sql', declared, v['scope']['name'], v['sql'],
                        q.Budgets(*(int(limits[name]) for name in ('pages', 'segments', 'result_bytes'))), parameters)
                    result = {'compiled': {'bundle': compiled.data.hex()}}
                elif 'inspect' in action:
                    v = action['inspect']
                    limits = v['scope']['limits']
                    inspected = await invoke('inspect_sql', declared, v['scope']['name'], v['sql'],
                        q.Budgets(*(int(limits[name]) for name in ('pages', 'segments', 'result_bytes'))))
                    assert inspected.resource == connection.resource
                    assert inspected.source_kind == config['kind']
                    details = inspected.details
                    if isinstance(details, q.SourceDescription):
                        normalized = {'description': {'columns': [{'name': c.name, 'type': wire_type(c.type), 'nullable': c.nullable, 'optional': c.optional} for c in details.columns]}}
                    elif isinstance(details, q.TableListing): normalized = {'tables': details.names}
                    else:
                        assert isinstance(details, q.Explanation)
                        predicate = details.predicate
                        def atom(value):
                            if value is None: return {'all': {}}
                            if isinstance(value, q.InspectedState): return {'state': {'column': value.column, 'value': value.state.value}}
                            return {'compare': {'column': value.column, 'op': value.comparison.value, 'type': wire_type(value.type)}}
                        selection = {'program': [{'atom': atom(v.predicate)} if isinstance(v, q.InspectedAtom) else {v.value: {}} for v in predicate.instructions]} if isinstance(predicate, q.InspectedProgram) else atom(predicate)
                        normalized = {'explanation': {'operators': details.operators, 'predicate': selection,
                            'projection': details.projection, 'limit': None if details.limit is None else str(details.limit),
                            'aggregate': details.aggregate.value, 'columns': [{'name': c.name, 'type': wire_type(c.type), 'nullable': c.nullable, 'optional': c.optional} for c in details.columns],
                            'budgets': {name: str(getattr(details.budgets, name)) for name in ('pages', 'segments', 'result_bytes')}}}
                    result = {'inspection': {'version': 1, 'scope': 'configured_source', 'name': inspected.name,
                        'resource': inspected.resource.resource, 'source_kind': inspected.source_kind,
                        'contract': list(inspected.source_digest), 'schema': list(inspected.schema_digest),
                        'resource_revision': inspected.resource_revision, 'policy_revision': str(inspected.policy_revision), 'details': normalized}}
                elif 'next' in action:
                    v = action['next']
                    prepared = await invoke('prepare_next', int(v['namespace']), q.Bundle(bytes.fromhex(v['bundle'])))
                    result = {'prepared': None if prepared is None else prepared.data.decode()}
                elif 'submit' in action:
                    prepared = q.Prepared(action['submit'].encode())
                    try: result = {'receipt': {'position': await invoke('submit', prepared)}}
                    except UncertainOperation as error:
                        assert error.recovery == prepared.data
                        raise
                elif 'observe' in action:
                    observed = await invoke('observe', action['observe'])
                    result = {'observation': {observed.state.value: {} if observed.reason is None else observed.reason.encode().hex()}}
                elif 'status' in action:
                    status = await invoke('status', int(action['status']))
                    result = {'status': None if status is None else {'phase': status.phase.value, 'correlation': str(status.correlation), 'diagnostic': status.diagnostic, 'failure': None if status.failure is None else {'code': status.failure.code, 'stage': status.failure.stage, 'dimension': status.failure.dimension, 'limit': str(status.failure.limit), 'observed': str(status.failure.observed)}}}
                elif 'page' in action:
                    v = action['page']
                    page = await invoke('page', int(v['namespace']), None if v.get('cursor') is None else q.Cursor(v['cursor']))
                    assert page.manifest.resource == connection.resource and page.manifest.source_kind == config['kind']
                    assert len(page.decode()) == page.rows
                    # Supply the pinned optional Arrow consumer only after the
                    # clean package has opened and decoded through shared Zig.
                    sys.path.append(config['arrow_site'])
                    assert page.to_pyarrow().num_rows == page.rows
                    result = {'page': {'ordinal': str(page.ordinal), 'ipc': page.ipc.hex(),
                        'manifest': {'segments': str(page.manifest.segments), 'selected': str(page.manifest.selected), 'value_count': str(page.manifest.value_count)}, 'next': None if page.next is None else page.next.data}}
                else: raise AssertionError('unsupported test operation')
                print(json.dumps({'status': 0, 'value': result}), flush=True)
            except TransitError as error:
                print(json.dumps({'status': error.status, 'value': {'err': error.code, 'diagnostic': error.diagnostic, 'diagnostic_invalid': error.diagnostic_invalid}}), flush=True)
    finally:
        await invoke('close')
    print(json.dumps({'closed': True}), flush=True)


if __name__ == '__main__':
    import transit_station
    assert Path(transit_station.__file__).is_relative_to(Path(sys.prefix))
    mode, path = sys.argv[1:]
    config = json.loads(Path(path).read_text())
    if mode == 'codecs': codecs(config)
    else: asyncio.run(serve(config, mode == 'async'))

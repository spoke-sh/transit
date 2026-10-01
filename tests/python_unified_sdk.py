"""Copied into a clean wheel consumer; only public typed SDK operations here."""
import asyncio
import json
from pathlib import Path
import struct
import sys


def codecs(config):
    from transit_client import ResourceRef
    from transit_client.errors import TransitError
    from transit_station import unified as q
    from transit_station.document import DocumentReference
    from transit_station.query import Comparison
    resource = ResourceRef(46, 7)
    sources = [q.KVSource(resource, b'data/', q.Decoder(q.Type.BINARY), q.Decoder(q.Type.UINT64)),
        q.TableSource(resource, 9, ('id', 'label'), q.Type.UTF8),
        q.DocumentSource(DocumentReference(resource, 2**64-1, 3, 1, 42), (
            q.Projection(q.Column('title', q.Type.UTF8), ('title',)),
            q.Projection(q.Column('body', q.Type.UTF8), ('body',), mode=q.ProjectionMode.TEXT)))]
    fixtures = json.loads(Path(config['bundles']).read_text())
    for index, source in enumerate(sources):
        scalar = q.Scalar(q.Type.UINT64, 2**64-1) if index == 0 else q.Scalar(q.Type.UTF8, 'x'*512)
        bundle = q.Bundle.prepare(source, q.Plan((1, 0), q.Compare(1, Comparison.NE, scalar), 2**64-1), q.Budgets(1000, 500, 1048576))
        assert bundle.data.hex() == fixtures[index]['wire_hex']
        named = q.Bundle.prepare(source, q.Plan((1, 0), q.Compare(1, Comparison.NE, scalar), 2**64-1, output_names=('Result', None)), q.Budgets(1000, 500, 1048576))
        assert named.data.hex() == fixtures[index]['named_wire_hex']
        counted = q.Bundle.prepare(source, q.Plan((1,), aggregate=q.Aggregate.COUNT_VALUES, output_names=('present',)), q.Budgets(1000, 500, 1048576))
        assert counted.data.hex() == fixtures[index]['counted_wire_hex']
    for source in (q.KVSource(resource, b'', q.Decoder(q.Type.BINARY, 2), q.Decoder(q.Type.UTF8)),
                   q.TableSource(resource, 9, ('id', 'label'), q.Type.UINT64)):
        try: q.Bundle.prepare(source, q.Plan((0,)), q.Budgets(1, 1, 1))
        except TransitError: pass
        else: raise AssertionError('unsupported source accepted')
    scalar_values = (-(2**63), 2**64-1, -0.0, True, 'café é 🙂', b'\0\xff\x80', 'x'*512)
    boolean_fixtures = json.loads(Path(config['boolean']).read_text())
    for index, fixture in enumerate(boolean_fixtures):
        datatype = tuple(q.Type)[fixture['type']-1]
        source = q.KVSource(resource, b'', q.Decoder(datatype), q.Decoder(q.Type.UINT64))
        atom = q.PredicateAtom
        if index < 7:
            instructions = (atom(q.Compare(0, Comparison.EQ, q.Scalar(datatype, scalar_values[index]))),
                q.PredicateOperator.NEGATE, atom(q.IsState(0, q.State.NULL)), q.PredicateOperator.DISJUNCTION)
        elif fixture['name'] == 'all-and-not-null':
            instructions = (atom(), atom(q.IsState(0, q.State.NULL)), q.PredicateOperator.NEGATE, q.PredicateOperator.CONJUNCTION)
        else: instructions = (atom(),) + (q.PredicateOperator.NEGATE,)*63
        bundle = q.Bundle.prepare(source, q.Plan((0,), q.PredicateProgram(instructions)), q.Budgets(1000, 500, 1048576))
        assert bundle.data.hex() == fixture['wire_hex']
    for instructions in ((), (q.PredicateOperator.NEGATE,), (atom(), atom()),
            (atom(),)+(q.PredicateOperator.NEGATE,)*64, (atom(q.PredicateProgram((atom(),))),),
            (atom(q.IsState(8, q.State.NULL)),), (atom(q.Compare(0, Comparison.EQ, q.Scalar(q.Type.UTF8, 'wrong type'))),)):
        try: q.Bundle.prepare(source, q.Plan((0,), q.PredicateProgram(instructions)), q.Budgets(1, 1, 1024))
        except (TypeError, ValueError, TransitError): pass
        else: raise AssertionError('invalid predicate program accepted')
    columns = tuple(q.Column(v, q.Type(v)) for v in ('int64', 'uint64', 'float64', 'boolean', 'utf8', 'binary'))
    rows = q.decode_arrow(columns, Path(config['arrow']).read_bytes(), 5)
    assert len(rows) == 5 and all(len(row) == 6 for row in rows)
    for row, state in zip(rows, q.State, strict=True): assert all(cell.state is state for cell in row)
    expected = (-(2**63), 2**64-1, -0.0, False, 'café é 東京🙂', b'\0\xff\x80')
    for index, value in enumerate(expected):
        assert rows[3][index].value.value == value
        alternatives = rows[4][index].alternatives
        assert [(v.counter, v.replica, v.state) for v in alternatives] == [
            (2**64-1, 1, q.State.VALUE), (2**64-1, 2, q.State.NULL)]
        assert alternatives[0].value.value == value
    assert struct.pack('<d', rows[3][2].value.value).hex() == '0000000000000080'
    assert q.decode_arrow(columns, Path(config['empty']).read_bytes(), 0) == ()
    try: q.decode_arrow(columns, Path(config['malformed']).read_bytes(), 5)
    except TransitError: pass
    else: raise AssertionError('hidden Arrow value accepted')
    print('Python installed unified codecs: three sources, nine Boolean bundles, six types, five states and malformed rejection passed', flush=True)


def source(config):
    from transit_client import ResourceRef
    from transit_station import unified as q
    from transit_station.document import DocumentReference
    from transit_station.query import Comparison
    resource = ResourceRef(config['connection']['realm'], config['connection']['resource'])
    if config['kind'] == 'kv':
        value = q.KVSource(resource, b'k', q.Decoder(q.Type.BINARY), q.Decoder(q.Type.UTF8))
    elif config['kind'] == 'table': value = q.TableSource(resource, 1, ('id', 'value'), q.Type.UTF8)
    else:
        value = q.DocumentSource(DocumentReference(resource, 17, 1, 1, 13), (
            q.Projection(q.Column('value', q.Type.UTF8), relative=True),
            q.Projection(q.Column('counter', q.Type.UINT64), relative=True, mode=q.ProjectionMode.ELEMENT_COUNTER),
            q.Projection(q.Column('replica', q.Type.UINT64), relative=True, mode=q.ProjectionMode.ELEMENT_REPLICA),
            q.Projection(q.Column('optional', q.Type.UTF8), ('optional',))), ('items',))
    doc = config['kind'] == 'document'
    column = 0 if doc else 1
    predicate = q.Compare(column, Comparison.NE, q.Scalar(q.Type.UTF8, 'x'*512))
    if config['compound']:
        ceiling = f"東京🙂/{'x'*(64 if doc else 128)}/{'10' if doc else '39'}"
        predicate = q.PredicateProgram((q.PredicateAtom(predicate),
            q.PredicateAtom(q.Compare(column, Comparison.GE, q.Scalar(q.Type.UTF8, ceiling))),
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
    from transit_station import unified as q
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
        assert description.bundle_bytes == 16384 and description.batch_rows == 8
        print(json.dumps({'ready': True}), flush=True)
        for line in sys.stdin:
            action = json.loads(line)
            if 'close' in action:
                break
            try:
                if 'inspect' in action:
                    v = action['inspect']
                    limits = v['scope']['limits']
                    inspected = await invoke('inspect_sql', declared, v['scope']['name'], v['sql'],
                        q.Budgets(*(int(limits[name]) for name in ('pages', 'segments', 'result_bytes'))))
                    assert inspected.resource == connection.resource
                    assert inspected.source_kind == config['kind']
                    details = inspected.details
                    if isinstance(details, q.SourceDescription):
                        normalized = {'description': {'columns': [{'name': c.name, 'type': c.type.value} for c in details.columns]}}
                    elif isinstance(details, q.TableListing): normalized = {'tables': details.names}
                    else:
                        assert isinstance(details, q.Explanation)
                        predicate = details.predicate
                        def atom(value):
                            if value is None: return {'all': {}}
                            if isinstance(value, q.InspectedState): return {'state': {'column': value.column, 'value': value.state.value}}
                            return {'compare': {'column': value.column, 'op': value.comparison.value, 'type': value.type.value}}
                        selection = {'program': [{'atom': atom(v.predicate)} if isinstance(v, q.InspectedAtom) else {v.value: {}} for v in predicate.instructions]} if isinstance(predicate, q.InspectedProgram) else atom(predicate)
                        normalized = {'explanation': {'operators': details.operators, 'predicate': selection,
                            'projection': details.projection, 'limit': None if details.limit is None else str(details.limit),
                            'aggregate': details.aggregate.value, 'columns': [{'name': c.name, 'type': c.type.value} for c in details.columns],
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
                    result = {'status': None if status is None else {'phase': status.phase.value, 'correlation': str(status.correlation)}}
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
                        'manifest': {'segments': str(page.manifest.segments)}, 'next': None if page.next is None else page.next.data}}
                else: raise AssertionError('unsupported test operation')
                print(json.dumps({'status': 0, 'value': result}), flush=True)
            except TransitError as error:
                print(json.dumps({'status': error.status, 'value': {'err': error.code}}), flush=True)
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

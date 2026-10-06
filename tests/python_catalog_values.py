"""Public general Table ownership, malformed replies and async lifetime checks."""
import asyncio
import copy
import ctypes
from dataclasses import FrozenInstanceError
import json
import math
from pathlib import Path
import threading
from transit_client import ProcessRef, ResourceRef
from transit_client._worker import Worker
from transit_client.errors import Busy, Closed, IncompatibleNative, UncertainOperation
from transit_station import catalog as m, logical as l
from transit_station import logical_values as codec


def rejects(kind, action):
    try: action()
    except kind: return
    raise AssertionError(f'Expected {kind.__name__}')


contract = json.loads(Path(m.__file__).with_name('station-abi.json').read_bytes())
definition = contract['definition']
scope = m.Scope(ResourceRef(46, 7), (1 << 64) - 1)
connection = m.Connection(ProcessRef(46, 3), scope)
rights = m.Rights(True, False, True, True, True, True, True, True)
rejects(ValueError, lambda: m.Scope(ResourceRef(46, 7), True))
rejects(ValueError, lambda: m.Scope(ResourceRef(46, 7), 1 << 64))
rejects(ValueError, lambda: m.Connection(ProcessRef(47, 3), scope))
rejects(ValueError, lambda: m.Rights(1, True, True, True, True, True, True, True))
rejects(ValueError, lambda: m.PolicyChange(1, m.Policy(scope, 17, 3, rights)))
rejects(ValueError, lambda: m.Prepared(bytes(8193)))
rejects(ValueError, lambda: m.SavedIntent('0' * 64, b'nonempty'))
source = bytearray(b'opaque saved bytes')
prepared, saved = m.Prepared(source), m.SavedIntent(definition, source)
source[:] = b'x' * len(source)
assert prepared.data == saved.data == b'opaque saved bytes'
assert 'opaque' not in repr(prepared) and 'opaque' not in repr(saved)
rejects(FrozenInstanceError, lambda: setattr(prepared, 'data', b'changed'))
payload = bytearray([0, 128, 255])
cells = [l.Present(l.Atom('binary', payload)), l.Present(l.Atom('decimal', 123456789012345678901234567890))]
cell = l.Present(l.SequenceValue('structure', cells))
payload.clear(); cells.clear()
assert cell.value.cells[0].value.value == b'\x00\x80\xff'
fields = [l.Field('data', l.ScalarType('binary')), l.Field('amount', l.DecimalType(38, 2))]
columns = [m.Column(1, '東京', l.StructureType(fields), default=cell)]
schema = m.Schema((1 << 64) - 1, 1, 2, columns)
fields.clear(); columns.clear()
assert len(schema.columns[0].type.fields) == 2 and schema.columns[0].default == cell
assert schema.columns[0].nullable
for datatype in (l.ScalarType('int128'), l.DecimalType(38, 2), l.TimestampType('utc'),
    l.StructureType((l.Field('x', l.ScalarType('utf8'), True, True),)), l.UnionType((l.Field('x', l.ScalarType('uint128')),)),
    l.ListType(l.Element(l.ScalarType('uuid'), True)), l.ArrayType(l.Element(l.ScalarType('date')), 2),
    l.MapType(l.ScalarType('int64'), l.Element(l.ScalarType('binary')))):
    assert codec.type_from_wire(codec.type_wire(datatype)) == datatype
for value in (l.Missing(), l.Null(), l.SourceTypeError('decimal'), l.SourceTypeError('unknown'),
              l.SourceTypeError('null_value'), l.SourceTypeError('text'), l.SourceTypeError('character'), cell,
    l.Present(l.Atom('signed', -(1 << 127))), l.Present(l.Atom('unsigned', (1 << 128) - 1)),
    l.Present(l.Atom('interval', l.Interval(1, -2, 3000))), l.Present(l.Atom('uuid', bytes(range(16)))),
    l.Present(l.MapValue((l.MapEntry(l.Atom('signed', 1), l.Null()),))),
    l.Present(l.TaggedValue(1, l.Null())), l.Present(l.JsonValue('{"x":1}')),
    l.Conflict((l.Alternative(1, 1, l.Null()), l.Alternative((1 << 64) - 1, 2, l.Null())))):
    assert codec.cell_from_wire(codec.cell_wire(value)) == value
for width in (32, 64):
    value = codec.atom_from_wire(codec.atom_wire(l.Atom('float', -0.0, width)))
    assert value.width == width and math.copysign(1, value.value) == -1
rejects(ValueError, lambda: codec.atom_wire(l.Atom('float', 1e300, 32)))
rejects(ValueError, lambda: codec.atom_wire(l.Atom('float', float('inf'), 64)))
rejects(ValueError, lambda: codec.cell_from_wire({'value': {'atom': {'signed': '01'}}}))
rejects(ValueError, lambda: codec.cell_from_wire({'value': {'atom': {'binary': 'FF'}}}))
rejects(ValueError, lambda: codec.cell_from_wire({'type_error': 'invented'}))
rejects(ValueError, lambda: codec.cell_from_wire({'conflict': [{'counter': '1', 'replica': '2', 'value': {'missing': {}}}]}))
nested = l.ScalarType('int8')
for _ in range(16): nested = l.ListType(l.Element(nested))
rejects(ValueError, lambda: codec.type_wire(nested))

# Native conflicts share their owning column's depth; map keys consume children.
deep = l.Conflict((l.Alternative(1, 1, l.Null()), l.Alternative(1, 2, l.Null())))
for _ in range(15): deep = l.Present(l.SequenceValue('list', (deep,)))
assert codec.cell_from_wire(codec.cell_wire(deep)) == deep
rejects(ValueError, lambda: codec.cell_wire(l.Present(l.SequenceValue('list', (deep,)))))
rejects(ValueError, lambda: codec.cell_from_wire({'value': {'list': [codec.cell_wire(deep)]}}))
for alternatives in ((), (l.Alternative(1, 1, l.Null()),),
    (l.Alternative(0, 1, l.Null()), l.Alternative(1, 1, l.Null())),
    (l.Alternative(1, 1, l.Null()), l.Alternative(1, 1, l.Null())),
    (l.Alternative(2, 1, l.Null()), l.Alternative(1, 1, l.Null()))):
    rejects(ValueError, lambda: codec.cell_wire(l.Conflict(alternatives)))
    wire = {'conflict': [dict(counter=str(a.counter), replica=str(a.replica), value={'null': {}}) for a in alternatives]}
    rejects(ValueError, lambda: codec.cell_from_wire(wire))
entries = tuple(l.MapEntry(l.Atom('signed', i), l.Null()) for i in range(32767))
assert len(codec.cell_wire(l.Present(l.MapValue(entries)))['value']['map']) == 32767
rejects(ValueError, lambda: codec.cell_wire(l.Present(l.MapValue(entries + (entries[-1],)))))
rejects(ValueError, lambda: codec.cell_from_wire({'value': {'map': [{'key': {'signed': str(i)}, 'value': {'null': {}}} for i in range(32768)]}}))
rejects(ValueError, lambda: codec.cell_wire(l.Present(l.SequenceValue('list', (l.Present(l.Atom('binary', bytes(600000))),) * 2))))
rejects(ValueError, lambda: codec.cell_from_wire({'value': {'list': [{'value': {'atom': {'utf8': 'x' * 600000}}}] * 2}}))
rejects(ValueError, lambda: codec.type_from_wire({'structure': [dict(name='x', type={'boolean': {}}, nullable=False, optional=False)] * 256}))
rejects(ValueError, lambda: codec.type_wire(l.StructureType(tuple(l.Field('x' * 255, l.ScalarType('boolean')) for _ in range(17)))))


class Api:
    def __init__(self):
        self.lib = self
        self.response = None
        self.destroyed = False
        self.entered = None
        self.release = None
        self.contract = contract
        self.calls = []
    def call(self, name, handle, data, length, **kwargs):
        self.calls.append(json.loads(data))
        assert len(data) == length
        if self.entered is not None:
            self.entered.set()
            assert self.release.wait(10)
        if isinstance(self.response, BaseException): raise self.response
        return self.response
    def validate_diagnostic(self, data, length): return int(json.loads(data) == {'fixture': True})
    def station_catalog_destroy(self, handle): self.destroyed = True


def client():
    owner = m.Client.__new__(m.Client)
    owner._api = Api()
    owner._handle = ctypes.c_void_p()
    owner._worker = Worker(8 * 1024 * 1024)
    owner._queries = m._Queries(connection, 17)
    return owner


# Bound conversion itself, before constructing the complete 2-GiB JSON tree.
large_cell = l.Present(l.Atom('binary', bytes(1024 * 1024)))
large_column = m.Column(1, 'data', l.ScalarType('binary'), default=large_cell)
wire_cell = codec.cell_wire
visits = 0
def counted_cell(value):
    global visits
    visits += 1
    assert visits < 16, 'converted the complete oversized input'
    return wire_cell(value)
codec.cell_wire = counted_cell
try:
    rejects(ValueError, lambda: m.Schema(1, 1, 2, (large_column,) * 128))
    assert visits < 16
    visits = 0
    budget_owner = client()
    try:
        rejects(ValueError, lambda: budget_owner.prepare('items', m.Identity(1, 100), m.Mutate(
            m.Basis(17, 3, 'ab' * 32), m.Insert(((m.Assignment(1, large_cell),),) * 1024))))
        assert visits < 16 and budget_owner._api.calls == []
    finally: budget_owner.close()
finally: codec.cell_wire = wire_cell


owner = client()
try:
    for response in (MemoryError(), None, {}, {'receipt': {'position': 0}}, {'receipt': {'position': '1'}}, {'receipt': {'position': 1}, 'extra': True}):
        owner._api.response = response
        try: owner.submit(prepared)
        except UncertainOperation as error: assert error.recovery == prepared.data
        else: raise AssertionError('Malformed admission response reported success')
    owner._api.response = {'receipt': {'position': 1}}
    assert owner.submit(prepared) == 1
    s = dict(realm=46, resource=7, catalog=str(scope.catalog))
    description = dict(configuration=dict(scope=s, owner=3, administrator=17, table_limits=dict(record_bytes=2097216, staging_bytes='16777216', staging_records=65536)),
        policy=dict(scope=s, principal=17, revision=str((1 << 64) - 1), **rights._wire()), resource_revision=2)
    for revision in (18446744073709551615, '01', '+1', '18446744073709551616'):
        bad = copy.deepcopy(description); bad['policy']['revision'] = revision
        owner._api.response = {'description': bad}
        rejects(IncompatibleNative, owner.describe)
    owner._api.response = {'description': copy.deepcopy(description)}
    retained = owner.describe()
    owner._api.response['description']['policy']['revision'] = '1'
    assert retained.policy.revision == (1 << 64) - 1
    owner._api.response['description']['policy']['principal'] = 18
    rejects(IncompatibleNative, owner.describe)
    owner._api.response = {'observation': 'cancelled'}
    rejects(IncompatibleNative, lambda: owner.observe(prepared, 1))
    metadata = dict(scope=s, object=str((1 << 64) - 1), revision='1', name='items', schema_fingerprint='1' * 64, principal=17, operation='1', admitted_input=2, commitment=dict(format=0x54434d01, length=200, digest=[1]*32))
    entry = dict(metadata=metadata, head=dict(revision='2', rows='3', pending='0'))
    token = dict(definition=definition, scope=s, resource_revision=3, after_object=metadata['object'])
    page = dict(resource_revision=3, entries=[entry] + [None] * 7, next=token)
    owner._api.response = dict(page=copy.deepcopy(page))
    retained = owner.list()
    assert retained.entries[0].metadata.object_id == (1 << 64) - 1 and retained.entries[0].head.rows == 3
    owner._api.response['page']['entries'][0]['metadata']['name'] = 'changed'
    assert retained.entries[0].metadata.name == 'items'
    assert retained.entries[0].metadata.commitment == m.MetadataCommitment(200, '01'*32)
    rejects(FrozenInstanceError, lambda: setattr(retained.next, 'after_object', 1))
    values = list(retained.entries); public_page = m.Page(3, values, retained.next); values.clear()
    assert public_page.entries == retained.entries
    owner._api.response = dict(definition=dict(**copy.deepcopy(entry), schema=schema._wire()))
    assert owner.lookup('items').schema == schema
    rejects(IncompatibleNative, lambda: owner.lookup('other'))
    historical = dict(metadata=copy.deepcopy(metadata), schema=schema._wire())
    owner._api.response = dict(historical=copy.deepcopy(historical))
    exact = owner.definition(schema.object_id, 1)
    assert exact.schema == schema and not hasattr(exact, 'head')
    rejects(IncompatibleNative, lambda: owner.definition(1, 1))
    rejects(IncompatibleNative, lambda: owner.definition(schema.object_id, 2))
    owner._api.response['historical']['metadata']['scope']['catalog'] = '1'
    rejects(IncompatibleNative, lambda: owner.definition(schema.object_id, 1))
    owner._api.response = dict(historical=dict(historical, head=entry['head']))
    rejects(IncompatibleNative, lambda: owner.definition(schema.object_id, 1))
    owner._api.response = dict(historical=None)
    assert owner.definition(schema.object_id, 99) is None
    for malformed in ('hole', 'order', 'scope', 'cut', 'next_object', 'missing_definition', 'foreign_definition', 'numeric_object', 'unknown_head', 'missing_commitment', 'foreign_commitment', 'long_commitment', 'bad_digest'):
        bad = copy.deepcopy(page)
        if malformed == 'hole': bad['entries'][1], bad['entries'][0] = bad['entries'][0], None
        elif malformed == 'order': bad['entries'][1] = copy.deepcopy(bad['entries'][0])
        elif malformed == 'scope': bad['entries'][0]['metadata']['scope']['catalog'] = '1'
        elif malformed == 'cut': bad['next']['resource_revision'] += 1
        elif malformed == 'next_object': bad['next']['after_object'] = '1'
        elif malformed == 'missing_definition': del bad['next']['definition']
        elif malformed == 'foreign_definition': bad['next']['definition'] = '0' * 64
        elif malformed == 'numeric_object': bad['entries'][0]['metadata']['object'] = (1 << 64) - 1
        elif malformed == 'unknown_head': bad['entries'][0]['head']['unknown'] = 1
        elif malformed == 'missing_commitment': del bad['entries'][0]['metadata']['commitment']
        elif malformed == 'foreign_commitment': bad['entries'][0]['metadata']['commitment']['format'] = 0
        elif malformed == 'long_commitment': bad['entries'][0]['metadata']['commitment']['length'] = 437
        else: bad['entries'][0]['metadata']['commitment']['digest'][0] = 256
        owner._api.response = dict(page=bad)
        rejects(IncompatibleNative, owner.list)
    owner._api.response = dict(page=copy.deepcopy(page))
    rejects(IncompatibleNative, lambda: owner.list(retained.next))
    owner._api.response = dict(page=dict(resource_revision=4, entries=[None] * 8, next=None))
    rejects(IncompatibleNative, lambda: owner.list(retained.next))
    owner._api.response['page']['resource_revision'] = 3
    assert owner.list(retained.next) == m.Page(3, (), None)
    # Retired objects can consume a complete scan page without a visible entry.
    empty = dict(resource_revision=3, entries=[None] * 8, next=dict(token, after_object='9'))
    owner._api.response = dict(page=empty)
    assert owner.list(m.Cursor(definition, scope, 3, 8)).next.after_object == 9
    owner._api.response = dict(definition=None)
    assert owner.lookup('absent') is None
    summary = dict(reference=dict(definition=definition, digest='a' * 64), scope=s, owner=3, principal=17, operation='10', namespace='100', object='1', kind='insert')
    reply = dict(intent=summary, saved=dict(definition=definition, bytes=b'saved'.hex()))
    action = m.Mutate(m.Basis(1, 1, '1' * 64), m.Insert(((m.Assignment(1, l.Present(l.Atom('binary', bytes(300000)))),),)))
    owner._api.response = dict(compiled=copy.deepcopy(reply))
    compiled = owner.prepare('items', m.Identity(10, 100), action)
    assert compiled.intent.identity == m.Identity(10, 100)
    assert len(owner._api.calls[-1]['prepare']['action']['mutate']['mutation']['action']['insert'][0][0]['value']['cell']['value']['atom']['binary']) == 600000
    for field, value in (('owner', 4), ('principal', 18), ('operation', '11'), ('namespace', '101'), ('object', '2'), ('kind', 'update')):
        bad = copy.deepcopy(reply); bad['intent'][field] = value
        owner._api.response = dict(compiled=bad)
        rejects(IncompatibleNative, lambda: owner.prepare('items', m.Identity(10, 100), action))
    owner._api.response = dict(loaded=summary)
    assert owner.load(compiled.saved) == compiled.intent
    assert owner._api.calls[-1] == {'load': {'definition': definition, 'bytes': b'saved'.hex()}}
    outcome = dict(kind='update', operation='10', object='1', actual_object=None, phase='applied', terminal=True, counts=dict(matched='1', changed='0'), admitted_input=1, completed_input=2, diagnostic={'fixture': True})
    owner._api.response = dict(state=dict(outcome=copy.deepcopy(outcome), upload=None))
    assert owner.status(compiled.intent.reference).outcome.counts == m.Counts(1, 0)
    for field, value in (('counts', None), ('terminal', False), ('phase', 'building'), ('kind', 'create'), ('diagnostic', {})):
        bad = copy.deepcopy(outcome); bad[field] = value
        owner._api.response = dict(state=dict(outcome=bad, upload=None))
        rejects(IncompatibleNative, lambda: owner.status(compiled.intent.reference))
    owner._api.response = {'forgotten': {}}
    assert owner.forget(compiled.intent.reference) is None
finally:
    owner.close()
assert owner._api.destroyed
rejects(Closed, owner.capabilities)


async def cancellation():
    owner = client()
    client_async = m.AsyncClient.__new__(m.AsyncClient)
    client_async._owner = owner
    api = owner._api
    api.entered, api.release = threading.Event(), threading.Event()
    api.response = {'receipt': {'position': 2}}
    try:
        pending = asyncio.create_task(client_async.submit(prepared))
        assert await asyncio.to_thread(api.entered.wait, 5)
        pending.cancel()
        try: await pending
        except asyncio.CancelledError: pass
        else: raise AssertionError('Await was not cancelled')
        try: await client_async.capabilities()
        except Busy: pass
        else: raise AssertionError('Cancellation released native operation ownership')
        closing = asyncio.create_task(client_async.close())
        await asyncio.sleep(0)
        assert not closing.done() and not api.destroyed
        api.release.set()
        await closing
        assert api.destroyed
    finally:
        api.release.set()
        await client_async.close()


asyncio.run(cancellation())
print('Python general Tables: nested owned schemas/cells, exact widths, strict pages/identity, uncertain recovery and cancelled-await joined cleanup passed.')

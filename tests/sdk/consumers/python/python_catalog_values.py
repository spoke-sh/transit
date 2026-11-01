"""Public general Table ownership, malformed replies and async lifetime checks."""
import asyncio
import copy
import ctypes
from dataclasses import FrozenInstanceError
import json
import math
from pathlib import Path
import threading
from transit_client import ResourceRef
from transit_client._worker import Worker
from transit_client.errors import Busy, Closed, IncompatibleNative, UncertainOperation
from transit_station import catalog as m, logical as l
from transit_station import logical_values as codec
from transit_station import catalog_values as v


def rejects(kind, action):
    try: action()
    except kind: return
    raise AssertionError(f'Expected {kind.__name__}')


contract = json.loads(Path(m.__file__).with_name('station-abi.json').read_bytes())
definition = contract['definition']
scope = m.Scope(ResourceRef(46, 7), (1 << 64) - 1)
connection = m.Connection(scope, 3)
authority = m.AuthorityProfile(21, 22, 23, 31, 32, 33, 24, 1, 25)
rejects(ValueError, lambda: m.Scope(ResourceRef(46, 7), True))
rejects(ValueError, lambda: m.Scope(ResourceRef(46, 7), 1 << 64))
rejects(ValueError, lambda: m.Connection(scope, 3, role=True))
rejects(ValueError, lambda: m.Connection(scope, 3, branch=0))
rejects(ValueError, lambda: m.Identity(1, 0))
rejects(ValueError, lambda: m.AuthorityProfile(21, 21, 23, 31, 32, 33, 24, 1, 25))
object_id = dict(scope=scope._wire(), branch='1', object=str((1 << 64) - 1))
interpretation = dict(object=object_id, revision='1', digest='ab'*32)
stored = dict(interpretation=interpretation, content=dict(bytes='300', sha256='ab'*32), schema_fingerprint='cd'*32, retired=False)
basis_wire = dict(definition=definition, connection=connection._wire(17), namespace=1, name='items', interpretation=stored)
basis = m.Basis.restore(json.dumps(basis_wire))
bound = dict(definition=definition, identity=dict(scope=scope._wire(), principal=17, operation='10'), target=object_id,
             action='insert', expected_definition=interpretation, expected_data=None, intent='aa'*32, prerequisite=None)
saved_wire = {'table': dict(definition=definition, namespace=1, bytes=b'opaque saved bytes'.hex())}
saved = m.SavedIntent.restore(json.dumps(saved_wire))
summary = dict(id=dict(definition=definition, digest='11'*32), namespace=1, binding=dict(table=bound))
compiled_wire = dict(summary=summary, saved=saved_wire)
reference_wire = dict(table=dict(definition=definition, connection=connection._wire(17), namespace=1, binding=bound, content=dict(bytes='200', sha256='22'*32)))
reference = m.Reference.restore(json.dumps(reference_wire))
for cls, original in ((m.SavedIntent, saved_wire), (m.Reference, reference_wire)):
    for foreign in ('foreign', None):
        bad = copy.deepcopy(original)
        if foreign is None: del bad['table']['definition']
        else: bad['table']['definition'] = foreign
        rejects(ValueError, lambda: cls.restore(json.dumps(bad)))
rejects(FrozenInstanceError, lambda: setattr(saved, '_data', 'changed'))
assert 'opaque' not in repr(saved) and saved._wire() == saved_wire
rejects(ValueError, lambda: m.Basis.restore(json.dumps(basis_wire)[:-1] + ',"name":"other"}'))
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
            basis, m.Insert(((m.Assignment(1, large_cell),),) * 1024))))
        assert visits < 16 and budget_owner._api.calls == []
    finally: budget_owner.close()
finally: codec.cell_wire = wire_cell


owner = client()
try:
    owner._api.response = {'compiled': copy.deepcopy(compiled_wire)}
    compiled = owner.prepare('items', m.Identity(10), m.Mutate(basis, m.Insert(((m.Assignment(1, l.Null()),),))))
    assert compiled.intent.operation == 10 and compiled.intent.namespace == 1
    for response in (MemoryError(), None, {}, {'staged': {}}, {'staged': reference_wire, 'extra': True}):
        owner._api.response = response
        try: owner.stage(compiled.intent)
        except m.Uncertain as error:
            assert error.original is compiled.saved and json.loads(error.recovery) == saved_wire
        else: raise AssertionError('Malformed mutation response reported success')
    owner._api.response = {'staged': copy.deepcopy(reference_wire)}
    ref = owner.stage(compiled.intent)
    assert ref.operation == 10 and ref._wire() == reference_wire
    owner._api.response['staged']['table']['binding']['identity']['operation'] = '11'
    rejects(m.Uncertain, lambda: owner.stage(compiled.intent))
    assert ref._wire() == reference_wire
    owner._api.response = {'loaded': copy.deepcopy(summary)}
    assert owner.load(compiled.saved) == compiled.intent
    assert owner._api.calls[-1] == {'load': saved_wire}
    bad = copy.deepcopy(compiled_wire); bad['summary']['binding']['table']['identity']['operation'] = '11'
    owner._api.response = {'compiled': bad}
    rejects(IncompatibleNative, lambda: owner.compile_sql('INSERT INTO items VALUES (1)', m.Identity(10)))
    committed = dict(binding=bound, resulting=stored, transaction=None, outcome=dict(position=dict(partition='10', next_lsn='8'), matched='1', affected='0', live_rows='1'))
    owner._api.response = {'observation': {'rows': {'committed': copy.deepcopy(committed)}}}
    assert owner.inspect(ref).commit.affected == 0
    assert owner.inspect(ref).commit.matched == 1
    for mutation in ('binding', 'counts', 'kind', 'unknown', 'missing_transaction', 'transaction'):
        bad = copy.deepcopy(committed)
        if mutation == 'binding': bad['binding']['identity']['operation'] = '11'
        elif mutation == 'counts': bad['outcome']['affected'] = '2'
        elif mutation == 'unknown': bad['extra'] = True
        elif mutation == 'missing_transaction': del bad['transaction']
        elif mutation == 'transaction': bad['transaction'] = {}
        owner._api.response = {'observation': {'ddl' if mutation == 'kind' else 'rows': {'committed': bad}}}
        rejects(IncompatibleNative, lambda: owner.inspect(ref))
        rejects(m.Uncertain, lambda: owner.execute(ref, 1))
    description = dict(configuration=dict(scope=scope._wire(), branch='1', partition='2', audience=3, authority=authority._wire(), database_name='transit', initial_schema_name='public'),
        subject=dict(principal=17, login_role=19, role=19, credential_epoch=3, audience=3, context=[1]*32), policy_revision=4)
    owner._api.response = {'catalog': {'description': copy.deepcopy(description)}}
    retained = owner.describe()
    owner._api.response['catalog']['description']['subject']['context'][0] = 2
    assert retained.subject.context == bytes([1]*32) and retained.policy_revision == 4
    for field in ('stream_domain', 'queue_domain', 'kv_domain'):
        for missing in (True, False):
            bad = copy.deepcopy(description)
            profile = bad['configuration']['authority']
            if missing: del profile[field]
            else: profile[field] = profile['table_domain']
            owner._api.response = {'catalog': {'description': bad}}
            rejects(IncompatibleNative, owner.describe)
    for field, value in (('principal', 18), ('role', 29), ('audience', 4), ('credential_epoch', 0), ('context', [True]*32)):
        bad = copy.deepcopy(description); bad['subject'][field] = value
        owner._api.response = {'catalog': {'description': bad}}
        rejects(IncompatibleNative, owner.describe)
    metadata = dict(binding=basis_wire, schema=schema._wire(), authorization=29, position=dict(partition='10', next_lsn='8'), changed_lsn='7', row_count='1')
    owner._api.response = {'metadata': copy.deepcopy(metadata)}
    current = owner.lookup('items')
    assert current.basis.object_id == (1 << 64)-1 and current.position.next_lsn == 8
    owner._api.response['metadata']['binding']['name'] = 'changed'
    assert current.basis.name == 'items'
    rejects(IncompatibleNative, lambda: owner.lookup('items'))
    physical_wire = dict(integrity={'next_id': 1, 'checks': [], 'foreign_keys': []}, definition=definition, object=str(schema.object_id), revision='1', next_column='2',
        columns=[dict(id='1', name='text', type={'utf8': {}}, nullable=True, default=None,
                      max_characters=None, encoding='ebcdic', collation='ebcdic_cp037',
                      semantics=dict(rounding=None, metric=None, timezone=None, spatial=None))], primary_key=[])
    owner._api.response = {'metadata': dict(metadata, schema=physical_wire)}
    physical = owner.lookup('items').schema
    assert physical.columns[0].encoding == m.Encoding.EBCDIC and physical.columns[0].collation == m.Collation.EBCDIC_CP037
    assert physical._wire() == physical_wire
    assert v._change(m.SetPhysical(1, m.Encoding.FSST, m.Collation.ASCII_CI)) == {'physical': dict(column='1', encoding='fsst', collation='ascii_ci', semantics=None)}
    for field in ('encoding', 'collation', 'semantics'):
        for missing in (True, False):
            bad = copy.deepcopy(physical_wire)
            if missing: del bad['columns'][0][field]
            else: bad['columns'][0][field] = 'invented'
            owner._api.response = {'metadata': dict(metadata, schema=bad)}
            rejects(IncompatibleNative, lambda: owner.lookup('items'))
    entry = dict(interpretation=interpretation, namespace=1, name='items', position=metadata['position'], changed_lsn='7')
    token = dict(definition=definition, connection=connection._wire(17), selection=dict(tables=1), position=dict(partition='2', next_lsn='3'), after=object_id['object'])
    page = dict(entries=[entry]+[None]*7, next=token, position=token['position'], consistency='independent')
    owner._api.response = {'catalog': {'tables': copy.deepcopy(page)}}
    listing = owner.tables()
    assert listing.entries[0].interpretation.object.object_id == (1 << 64)-1
    for mutation in ('hole', 'order', 'scope', 'cut', 'next_object', 'missing_definition', 'foreign_definition', 'numeric_object', 'unknown_entry', 'selection'):
        bad = copy.deepcopy(page)
        if mutation == 'hole': bad['entries'][0], bad['entries'][1] = None, bad['entries'][0]
        elif mutation == 'order': bad['entries'][1] = copy.deepcopy(bad['entries'][0])
        elif mutation == 'scope': bad['entries'][0]['interpretation']['object']['scope']['catalog'] = '1'
        elif mutation == 'cut': bad['next']['position'] = dict(bad['next']['position'], next_lsn='4')
        elif mutation == 'next_object': bad['next']['after'] = '1'
        elif mutation == 'missing_definition': del bad['next']['definition']
        elif mutation == 'foreign_definition': bad['next']['definition'] = 'foreign'
        elif mutation == 'numeric_object': bad['entries'][0]['interpretation']['object']['object'] = 7
        elif mutation == 'unknown_entry': bad['entries'][0]['extra'] = True
        elif mutation == 'selection': bad['next']['selection'] = dict(tables=2)
        owner._api.response = {'catalog': {'tables': bad}}
        rejects(IncompatibleNative, owner.tables)
    owner._api.response = {'catalog': {'tables': dict(page, entries=[None]*8, next=None)}}
    assert owner.tables(cursor=listing.next).entries == ()
    rejects(ValueError, lambda: owner.tables(namespace=2, cursor=listing.next))
    acquisition = owner.prepare_snapshot(current.basis, current.position, (1 << 64)-1)
    acquisition = m.SnapshotAcquisition.restore(acquisition.save())
    assert acquisition.owner.operation == (1 << 64)-1 and acquisition.expected == current.position
    snapshot_wire = dict(owner=acquisition.owner._wire(), content=dict(bytes='100', sha256='33'*32))
    owner._api.response = {'retention': {'acquired': snapshot_wire}}
    snapshot = owner.acquire_snapshot(acquisition)
    assert snapshot.owner.object == current.basis.interpretation.interpretation.object
    pin_metadata = dict(snapshot=snapshot_wire, interpretation=stored, accepted=current.position._wire(), changed_lsn='7', row_count='1', schema=schema._wire(), authority=dict(database=24, schema=25, table=29))
    owner._api.response = {'retention': {'metadata': copy.deepcopy(pin_metadata)}}
    assert owner.snapshot_metadata(snapshot).accepted == current.position
    owner._api.response['retention']['metadata']['snapshot']['owner']['operation'] = '1'
    rejects(IncompatibleNative, lambda: owner.snapshot_metadata(snapshot))
    owner._api.response = None
    rejects(m.Uncertain, lambda: owner.release_snapshot(snapshot))
    owner._api.response = {'retention': {'released': snapshot_wire}}
    assert owner.release_snapshot(snapshot) is None
    owner._api.response = {'forgotten': {}}
    assert owner.forget(compiled.intent) is None
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
    api.response = {'observation': {'rows': {'not_observed': {}}}}
    try:
        pending = asyncio.create_task(client_async.admit(reference))
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
print('Python direct Tables: nested owned schemas/cells, exact widths, strict pages/identity, uncertain recovery and cancelled-await joined cleanup passed.')

parent_definition = m.Interpretation(m.ObjectIdentity(scope, 1, 90), 8, 'ab' * 32)
integrity = m.TableIntegrity(3, (m.CheckConstraint(1, 'check_id', (m.CheckLiteral(1, 'gte', l.Atom('signed', 0)),), False),),
    (m.ForeignKeyConstraint(2, 'parent_id', (1,), parent_definition, 3, (7,)),))
constrained = m.Schema(91, 2, 2, (m.Column(1, 'id', l.ScalarType('int64'), False),), (1,), integrity)
assert v._schema(constrained._wire()) == constrained
assert constrained.integrity.foreign_keys[0].target_definition.revision == 8
assert constrained.integrity.foreign_keys[0].target_schema_revision == 3
assert not constrained.integrity.checks[0].validated


# A durable Table commit with unfinished dependency cleanup remains pending.
final_reference_wire = copy.deepcopy(reference_wire)
final_binding = final_reference_wire['table']['binding']
final_binding['action'] = 'alter'
final_original = m.Reference.restore(json.dumps(final_reference_wire))
final_resulting = copy.deepcopy(stored)
final_resulting['interpretation']['revision'] = str(int(final_binding['expected_definition']['revision']) + 1)
final_evidence = dict(binding=final_binding, resulting=final_resulting, transaction=None,
    outcome=dict(position=dict(partition='10', next_lsn='8'), matched='0', affected='0', live_rows='1'))
final_operation = dict(binding=final_binding, intent=final_reference_wire['table']['content'], phase='admitted', reason='none',
    dependency_steps=1, protected_columns=1, requires_settlement=True, closing=None)
final_value = {'ddl': {'finalizing': dict(evidence=final_evidence, operation=final_operation)}}
final_result = v._observation(final_value, final_original)
assert final_result.state == 'finalizing' and final_result.reference is final_original and final_result.commit is not None
final_operation['requires_settlement'] = False
rejects(ValueError, lambda: v._observation(final_value, final_original))

# Shared independent oracle, including maximum-width identities and common-cut attribution.
import sys
history_fixture = json.loads(Path(sys.argv[1]).read_bytes())
history_acquisition = m.HistoryAcquisition.restore(json.dumps(history_fixture['acquire']))
history_key = history_acquisition.key
history_snapshot = m.HistoricalSnapshot(history_fixture['snapshot']['selector'])
maximum = (1 << 64) - 1
assert history_acquisition.intent.operation == maximum
assert history_acquisition.intent.common_cut.transaction.operation == maximum - 1
assert json.loads(history_acquisition.save()) == history_fixture['acquire']
assert m.HistoricalSnapshot.restore(history_snapshot.save()) == history_snapshot
for field in ('definition', 'common', 'selection'):
    invalid = copy.deepcopy(history_fixture['acquire']); del invalid['intent'][field]
    rejects(ValueError, lambda: m.HistoryAcquisition.restore(json.dumps(invalid)))
invalid = copy.deepcopy(history_fixture['acquire']); invalid['intent']['operation'] = maximum
rejects(ValueError, lambda: m.HistoryAcquisition.restore(json.dumps(invalid)))
rejects(ValueError, lambda: m.HistoricalSnapshot('00' * 193))
status = dict(key=history_fixture['acquire']['key'], intent=history_fixture['acquire']['intent'],
              admitted=dict(partition='1', next_lsn='20'), revision=dict(partition='1', next_lsn='30'),
              phase='published', retained=dict(content=history_fixture['snapshot']['sources_root'], count='2'),
              after=str(maximum), inflight=None, verified_after=str(maximum), policy_epoch=str(maximum), released_after=None, snapshot=history_fixture['snapshot'])
owner = client()
# The common fixture uses its own explicit service connection and principal.
history_connection, history_principal = v._connection(history_fixture['acquire']['key']['connection'])
owner._queries = m._Queries(history_connection, history_principal)
try:
    owner._api.response = {'history': {'status': copy.deepcopy(status)}}
    original = owner.prepare_common_history_acquisition(history_key, maximum, 1, history_acquisition.intent.selection,
        history_acquisition.intent.common_key, history_acquisition.intent.common_cut)
    assert json.loads(original.save()) == history_fixture['acquire']
    result = owner.acquire_history(original)
    assert result.phase == 'published' and result.intent.operation == maximum and result.policy_epoch == maximum
    assert result.basis.consistency == 'common_transaction' and result.basis.snapshot == history_snapshot
    assert owner._api.calls[-1] == {'history': {'acquire': history_fixture['acquire']}}
    owner._api.response = UncertainOperation(recovery=b'', phase='fixture')
    for action, expected in ((lambda: owner.acquire_history(original), original),
                             (lambda: owner.release_history(history_key), None)):
        try: action()
        except m.Uncertain as error:
            if expected is not None: assert error.original is expected
            else: assert isinstance(error.original, m.HistoryControl) and error.original.command == 'release' and error.original.key == history_key
        else: raise AssertionError('History outcome was not uncertain')
    step = owner.prepare_history_step(owner.prepare_history_selection(maximum), 1, 'items')
    assert m.HistorySelectionStep.restore(step.save()).selection.owner.operation == maximum
    try: owner.select_history(step)
    except m.Uncertain as error: assert error.original is step
    else: raise AssertionError('Selection loss discarded original step')
    selected = dict(definition=definition, owner=history_fixture['snapshot']['owner'], branch='1', directory=dict(content=history_fixture['snapshot']['catalog_root'], count='2'))
    owner._api.response = {'history': {'selection': selected}}
    selection = owner.select_history(step)
    independent = owner.prepare_history_acquisition(selection, history_key)
    assert independent.intent.common_cut is None and independent.intent.selection.count == 2
    for change in ('intent', 'owner', 'key', 'phase'):
        invalid = copy.deepcopy(status)
        if change == 'intent': invalid['intent']['operation'] = '1'
        elif change == 'owner': invalid['snapshot']['owner']['operation'] = '1'
        elif change == 'key': invalid['key']['token'] = '00' * 16
        elif change == 'phase': invalid['phase'] = 'acquiring'
        owner._api.response = {'history': {'status': invalid}}
        rejects(m.Uncertain, lambda: owner.acquire_history(original))
    ns = dict(scope=history_connection.scope._wire(), id=1, authorization=10, name='original', revision=str(maximum))
    declaration = copy.deepcopy(stored); declaration['interpretation']['object']['scope'] = history_connection.scope._wire()
    entry = dict(namespace=ns, name='items', declaration=declaration, accepted=dict(partition='9', next_lsn='10'), catalog=dict(partition='1', next_lsn='12'))
    page = dict(snapshot=history_fixture['snapshot'], namespace=1, entries=[entry], next=dict(selector=history_snapshot.selector, namespace=1, directory=dict(content=history_fixture['snapshot']['sources_root'], count='2'), after=str(maximum-1)))
    owner._api.response = {'history': {'listing': copy.deepcopy(page)}}
    listing = owner.historical_tables(history_snapshot, 1)
    assert listing.entries[0].namespace.revision == maximum and listing.basis.snapshot == history_snapshot
    calls = len(owner._api.calls)
    rejects(ValueError, lambda: owner.historical_tables(history_snapshot, 2, listing.next))
    rejects(ValueError, lambda: owner.historical_tables(m.HistoricalSnapshot('00' * 297), 1, listing.next))
    assert len(owner._api.calls) == calls
    rejects(IncompatibleNative, lambda: owner.historical_tables(history_snapshot, 1, listing.next))
    for change in ('selector', 'namespace', 'directory', 'bound'):
        invalid = copy.deepcopy(page)
        if change == 'selector': invalid['snapshot']['selector'] = '00' * 297
        elif change == 'namespace': invalid['namespace'] = 2
        elif change == 'directory': invalid['next']['directory']['count'] = '3'
        elif change == 'bound': invalid['entries'] *= 9
        owner._api.response = {'history': {'listing': invalid}}
        rejects(IncompatibleNative, lambda: owner.historical_tables(history_snapshot, 1))
    owner._api.response = {'history': {'listing': dict(page, entries=[], next=None)}}
    assert owner.historical_tables(history_snapshot, 1).entries == ()
    owner._api.response = {'history': {'namespace': ns}}
    assert owner.historical_namespace(history_snapshot, 'original').revision == maximum
    owner._api.response = {'history': {'source': dict(snapshot=history_fixture['snapshot'], binding=entry, schema=schema._wire(), rows=str(maximum), changed_lsn=str(maximum), authority=dict(database=9, schema=10, table=11))}}
    source = owner.historical_source(history_snapshot, maximum)
    assert source.row_count == maximum and source.changed_lsn == maximum
    coverage = dict(snapshot=history_fixture['snapshot'], logical=entry['declaration'], accepted=entry['accepted'], total_rows=str(maximum), definitions=dict(physical=entry['declaration'], schema_revision=str(maximum), rows=str(maximum), columns=[dict(column='1', source=dict(physical='1'))]), locations=[], next=dict(selector=history_snapshot.selector, object=str(maximum), kind='definitions', source=history_fixture['snapshot']['sources_root'], after=str(maximum)))
    owner._api.response = {'history': {'coverage': coverage}}
    observed = owner.historical_coverage(history_snapshot, maximum)
    assert observed.total_rows == maximum and observed.definition.rows == maximum and observed.definition.columns[0].physical == 1
    cursor = m.HistoryCoverageCursor.restore(observed.next.save())
    rejects(ValueError, lambda: owner.historical_coverage(history_snapshot, maximum, 'locations', cursor))
    rejects(IncompatibleNative, lambda: owner.historical_coverage(history_snapshot, maximum, cursor=cursor))
    calls = len(owner._api.calls)
finally:
    owner.close()
assert len(owner._api.calls) == calls and owner._api.destroyed
print('Python history: exact common/independent acquisition, uncertain original work, bounded metadata and current-selector fencing passed.')


async def history_cancellation():
    owner = client(); owner._queries = m._Queries(history_connection, history_principal)
    asynchronous = m.AsyncClient.__new__(m.AsyncClient); asynchronous._owner = owner
    api = owner._api; api.entered, api.release = threading.Event(), threading.Event()
    api.response = {'history': {'status': status}}
    try:
        pending = asyncio.create_task(asynchronous.acquire_history(history_acquisition))
        assert await asyncio.to_thread(api.entered.wait, 5)
        pending.cancel()
        try: await pending
        except asyncio.CancelledError: pass
        else: raise AssertionError('Await was not cancelled')
        closing = asyncio.create_task(asynchronous.close())
        await asyncio.sleep(0)
        assert not closing.done() and not api.destroyed
        api.release.set()
        await closing
        assert api.destroyed and api.calls == [{'history': {'acquire': history_fixture['acquire']}}]
    finally:
        api.release.set()
        await asynchronous.close()


asyncio.run(history_cancellation())

"""Owned handler Table intents and bounded public API routing, without a node."""
import copy
from dataclasses import FrozenInstanceError
import json
import threading
from types import SimpleNamespace
from transit_client import ProcessRef, ResourceRef
from transit_client._native import encode
from transit_client.errors import HandlerError, IncompatibleNative, TurnExpired
from transit_station import (TableSchema, RowIdentity, TableMutation, TableMutationReference,
    TableMutationState, TableLimits, Turn, ReadVersion, QueryPlan)
from transit_station import catalog as c, logical as l, unified as q
from transit_station import catalog_values as values

checks = 0

def rejects(operation, errors=(ValueError, TypeError, IncompatibleNative)):
    global checks
    try: operation()
    except errors: checks += 1
    else: raise AssertionError('Invalid handler Table value accepted')

maximum = (1 << 64) - 1
schema = TableSchema(maximum, 1, 5, (
    c.Column(1, 'id', l.ScalarType('int64'), False),
    c.Column(2, 'name', l.ScalarType('utf8')),
    c.Column(3, 'amount', l.DecimalType(18, 2)),
    c.Column(4, 'tags', l.ListType(l.Element(l.ScalarType('binary'), True))),
), (1,))
resource = ResourceRef(1, 7)
mutation = c.Insert(((c.Assignment(1, l.Present(l.Atom('signed', 7))),
    c.Assignment(2, l.Null()), c.Assignment(3, l.Present(l.Atom('decimal', 12345))),
    c.Assignment(4, l.Present(l.SequenceValue('list', (l.Null(), l.Present(l.Atom('binary', b'\x00\xff'))))))),))
intent = TableMutation.prepare(resource, 0, maximum, schema, mutation)
saved = intent.save()
assert TableMutation.load(saved).save() == saved
assert intent.operation == maximum and intent.schema == schema
rejects(lambda: setattr(intent, '_data', b''), (FrozenInstanceError,))
for change in (
    lambda v: v['schema'].pop('definition'),
    lambda v: v['schema'].update(definition='old'),
    lambda v: v.pop('realm'),
    lambda v: v.update(operation=1),
    lambda v: v.update(operation='0'),
    lambda v: v.update(operation='01'),
    lambda v: v.update(operation=str(1 << 64)),
    lambda v: v.update(table_write={}),
    lambda v: v['mutation']['action']['insert'][0][0]['value'].update(extra={}),
    lambda v: v['mutation']['action']['insert'][0][2]['value']['cell']['value']['atom'].update(decimal='012345'),
):
    item = json.loads(saved); change(item)
    rejects(lambda: TableMutation.load(encode(item)))
rejects(lambda: TableMutation.load(b' ' + saved))
rejects(lambda: TableMutation.load(b'[' * 2048 + b']' * 2048))
rejects(lambda: TableMutation.prepare(resource, 0, 0, schema, c.Delete()))
rejects(lambda: TableMutation.prepare(resource, True, 1, schema, c.Delete()))
rejects(lambda: TableMutation.prepare(resource, 0, 1, schema,
    c.Insert(((c.Assignment(2, l.Present(l.Atom('utf8', 'x' * values.LIMITS['handler_action_bytes']))),),))))

# Distinguish schema, row, action and predicate bounds.
wide = TableSchema(9, 1, 129, tuple(c.Column(i + 1, f'c{i}', l.ScalarType('int64')) for i in range(128)))
rows = tuple((c.Assignment(1, l.Present(l.Atom('signed', i))),) for i in range(1024))
assert len(TableMutation.prepare(resource, 0, 9, wide, c.Insert(rows)).schema.columns) == 128
rejects(lambda: TableMutation.prepare(resource, 0, 9, wide, c.Insert(rows + (rows[0],))))
for action in (c.Update((c.Assignment(2, c.Default.VALUE),), (c.Comparison(1, c.CompareOperator.GE, l.Atom('signed', 1)),)),
               c.Delete((c.BooleanOperator.ALL, c.StatePredicate(2, c.CellState.NULL), c.BooleanOperator.CONJUNCTION))):
    encoded = TableMutation.prepare(resource, 0, 2, schema, action).save()
    assert TableMutation.load(encoded).save() == encoded

identity = RowIdentity(bytes(range(20)))
assert identity.data == bytes(range(20))
rejects(lambda: RowIdentity(bytes(19)))
reference = dict(definition=values.DEFINITION, realm=1, resource=7, object=str(maximum), principal=0,
                 operation=str(maximum), digest='11' * 32)
ref = TableMutationReference.load(encode(reference))
assert ref.save() == encode(reference)
for target in (ResourceRef(2, 7), ResourceRef(1, 8)):
    foreign = SimpleNamespace(resource=target)
    rejects(lambda: intent.step(foreign), (HandlerError,))
    rejects(lambda: ref.status(foreign), (HandlerError,))

class Native:
    caps = dict(table_page_rows=8)
    calls = []
    response = None
    def apply(self, scope, action):
        self.calls.append(copy.deepcopy(action))
        assert scope == 1
        return copy.deepcopy(self.response)

native = Native()
turn = Turn(native, dict(scope=1, resource=7, resource_revision=2), ProcessRef(1, 3), threading.Event())
metadata = dict(schema=schema._wire(), basis=dict(resource=7, revision=2, object=str(maximum), head='22' * 32))
native.response = {'table': {'schema': metadata}}
table = turn.table(maximum)
assert table.schema == schema and table.basis.resource == resource
assert native.calls[-1] == {'table': {'schema': dict(object=str(maximum), version=None)}}
row = dict(identity=identity.data.hex(), cells=[{'value': {'atom': {'signed': '7'}}}, {'null': {}},
    {'value': {'atom': {'decimal': '12345'}}}, {'value': {'list': [{'null': {}}]}}])
native.response = {'table': {'row': dict(definition=metadata, row=row)}}
found = table.get_key((l.Present(l.Atom('signed', 7)),))
assert found.identity == identity and found.cells[2] == l.Present(l.Atom('decimal', 12345))
assert table.get(identity) == found
native.response = {'table': {'page': dict(definition=metadata, rows=[row], next='opaque')}}
assert table.page(limit=1).rows == (found,)
assert table.page(limit=1).next == 'opaque'
rejects(lambda: table.page(limit=9))
native.response['table']['page']['definition']['basis']['revision'] = 3
rejects(lambda: table.page(), (IncompatibleNative,))
metadata['basis']['revision'] = 2
native.response = {'table': {'schema': metadata}}
retained = turn.open_version(ReadVersion(3, 1, 0)).table(maximum)
rejects(lambda: retained.prepare(0, 1, c.Delete()), (HandlerError,))
assert native.calls[-1]['table']['schema']['version'] == dict(pid=3, input=1, index=0)

status = dict(reference=reference, state='building', route='statement', admitted_input=1,
               completed_input=None, counts=None, rejection='none', witness=None)
native.response = {'table': {'mutation': status}}
assert intent.step(turn).state is TableMutationState.BUILDING
assert ref.status(turn).counts is None
status.update(state='applied', completed_input=2, counts=dict(matched='1', changed='1'))
assert intent.step(turn).counts.changed == 1
assert ref.cancel(turn).state is TableMutationState.APPLIED
status['counts'] = None
rejects(lambda: intent.step(turn), (IncompatibleNative,))
status.update(state='building', completed_input=None)
status['reference'] = dict(reference, operation='2')
rejects(lambda: intent.step(turn), (IncompatibleNative,))
status['reference'] = dict(reference, digest='22' * 32)
rejects(lambda: ref.status(turn), (IncompatibleNative,))
turn._end()
rejects(lambda: table.get(identity), (TurnExpired,))

plan = QueryPlan(q.Plan((3, 0, 2), q.Compare(2, q.Comparison.GE, l.Atom('decimal', 12345)), maximum,
                       output_names=('tags', 'identity', 'amount')))
wire = plan._wire(); wire['projection'][0] = 1
assert plan._wire()['projection'] == [3, 0, 2] and plan._wire()['limit'] == str(maximum)
assert len(QueryPlan(q.Plan(tuple(range(128))))._wire()['projection']) == 128
rejects(lambda: QueryPlan(q.Plan((128,))))
rejects(lambda: QueryPlan(q.Plan((0,), aggregate='invented')))
print(f'Handler Table intents, scoped rows, query plans and {checks} adversarial rejections passed')

"""Public value ownership and malformed native responses, without network access."""
import asyncio
import ctypes
import copy
from dataclasses import FrozenInstanceError
import json
from pathlib import Path
import threading
from transit_client import ProcessRef, ResourceRef
from transit_client._worker import Worker
from transit_client.errors import Busy, Closed, IncompatibleNative, UncertainOperation
from transit_station import catalog as m
from transit_station import CellType


def rejects(kind, action):
    try: action()
    except kind: return
    raise AssertionError(f'Expected {kind.__name__}')


scope = m.Scope(ResourceRef(46, 7), (1 << 64) - 1)
connection = m.Connection(ProcessRef(46, 3), scope)
rejects(ValueError, lambda: m.Scope(ResourceRef(46, 7), True))
rejects(ValueError, lambda: m.Scope(ResourceRef(46, 7), 1 << 64))
rejects(ValueError, lambda: m.Connection(ProcessRef(47, 3), scope))
rejects(ValueError, lambda: m.Policy(scope, 17, 1, 1, True))
rejects(ValueError, lambda: m.PolicyChange(-1, m.Policy(scope, 17, 1, True, True)))
rejects(ValueError, lambda: m.CreateTable(scope, 1, 1, 1 << 32, 'items', m.Schema(('id', 'value'), CellType.UTF8)))
rejects(ValueError, lambda: m.Prepared(bytes(8193)))
source = bytearray(b'opaque saved bytes')
prepared = m.Prepared(source)
source[:] = b'x' * len(source)
assert prepared.data == b'opaque saved bytes'
rejects(FrozenInstanceError, lambda: setattr(prepared, 'data', b'changed'))
names = ['id', 'value']
schema = m.Schema(names, CellType.UTF8)
names[0] = 'changed'
assert schema.names == ('id', 'value')


class Api:
    def __init__(self):
        self.lib = self
        self.response = None
        self.destroyed = False
        self.entered = None
        self.release = None
        self.contract = json.loads(Path(m.__file__).with_name('station-abi.json').read_bytes())
    def call(self, *args, **kwargs):
        if self.entered is not None:
            self.entered.set()
            assert self.release.wait(10)
        if isinstance(self.response, BaseException): raise self.response
        return self.response
    def station_catalog_destroy(self, handle): self.destroyed = True


def client():
    owner = m.Client.__new__(m.Client)
    owner._api = Api()
    owner._handle = ctypes.c_void_p()
    owner._worker = Worker(8 * 1024 * 1024)
    owner._connection = connection
    return owner


owner = client()
try:
    for response in (MemoryError(), None, {}, {'receipt': {'position': 0}}, {'receipt': {'position': '1'}}, {'receipt': {'position': 1}, 'extra': True}):
        owner._api.response = response
        try: owner.submit(prepared)
        except UncertainOperation as error: assert error.recovery == prepared.data
        else: raise AssertionError('Malformed admission response reported success')
    owner._api.response = {'receipt': {'position': 1}}
    assert owner.submit(prepared) == 1
    for revision in (18446744073709551615, '01', '+1', '18446744073709551616'):
        owner._api.response = {'description': {'configuration': {'scope': dict(realm=46, resource=7, catalog=str(scope.catalog)), 'owner': 3, 'administrator': 17},
            'policy': {'scope': dict(realm=46, resource=7, catalog=str(scope.catalog)), 'principal': 17, 'revision': revision, 'inspect': True, 'create': False}, 'resource_revision': 2}}
        rejects(IncompatibleNative, owner.describe)
    owner._api.response['description']['policy']['revision'] = str((1 << 64) - 1)
    description = owner.describe()
    owner._api.response['description']['policy']['revision'] = '1'
    assert description.policy.revision == (1 << 64) - 1
    owner._api.response = {'observation': 'cancelled'}
    rejects(IncompatibleNative, lambda: owner.observe(prepared, 1))
    metadata = dict(scope=dict(realm=46, resource=7, catalog=str(scope.catalog)), object=str((1 << 64) - 1), revision=str((1 << 64) - 1), name='items',
        source=dict(table=dict(id=(1 << 32) - 1, schema=dict(names=['id', 'value'], value_type='utf8'))), principal=17, operation=str((1 << 64) - 1), input=2)
    token = dict(definition=owner._api.contract['definition'], scope=copy.deepcopy(metadata['scope']), resource_revision=3, after='items')
    page = dict(resource_revision=3, entries=[copy.deepcopy(metadata)] + [None] * 7, next=token)
    owner._api.response = dict(page=copy.deepcopy(page))
    retained = owner.list()
    assert retained.entries[0].object_id == (1 << 64) - 1 and retained.entries[0].revision == (1 << 64) - 1
    assert retained.entries[0].source.table == (1 << 32) - 1 and retained.next.definition == owner._api.contract['definition']
    owner._api.response['page']['entries'][0]['source']['table']['schema']['names'][0] = 'changed'
    assert retained.entries[0].source.schema.names == ('id', 'value')
    rejects(FrozenInstanceError, lambda: setattr(retained.next, 'after', 'changed'))
    values = list(retained.entries)
    public_page = m.Page(3, values, retained.next)
    values.clear()
    assert public_page.entries == retained.entries
    owner._api.response = dict(definition=copy.deepcopy(metadata))
    assert owner.lookup('items') == retained.entries[0]
    assert owner.definition((1 << 64) - 1, (1 << 64) - 1) == retained.entries[0]
    rejects(IncompatibleNative, lambda: owner.lookup('other'))
    rejects(IncompatibleNative, lambda: owner.definition(1, 1))
    for malformed in ('hole', 'order', 'scope', 'cut', 'next_name', 'missing_definition', 'foreign_definition', 'numeric_object', 'unknown_source'):
        bad = copy.deepcopy(page)
        if malformed == 'hole': bad['entries'][1], bad['entries'][0] = bad['entries'][0], None
        elif malformed == 'order': bad['entries'][1] = copy.deepcopy(bad['entries'][0])
        elif malformed == 'scope': bad['entries'][0]['scope']['catalog'] = '1'
        elif malformed == 'cut': bad['next']['resource_revision'] += 1
        elif malformed == 'next_name': bad['next']['after'] = 'other'
        elif malformed == 'missing_definition': del bad['next']['definition']
        elif malformed == 'foreign_definition': bad['next']['definition'] = '0' * 64
        elif malformed == 'numeric_object': bad['entries'][0]['object'] = (1 << 64) - 1
        else: bad['entries'][0]['source'] = dict(document={})
        owner._api.response = dict(page=bad)
        rejects(IncompatibleNative, owner.list)
    owner._api.response = dict(page=copy.deepcopy(page))
    rejects(IncompatibleNative, lambda: owner.list(retained.next))  # Repeated first entry.
    owner._api.response = dict(page=dict(resource_revision=4, entries=[None] * 8, next=None))
    rejects(IncompatibleNative, lambda: owner.list(retained.next))
    owner._api.response['page']['resource_revision'] = 3
    assert owner.list(retained.next) == m.Page(3, (), None)
    owner._api.response = dict(definition=None)
    assert owner.lookup('absent') is None and owner.definition(1, 1) is None
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
print('Python catalog values: full-width immutable definitions/pages, strict cursors and response identity, uncertain submission recovery and cancelled-await joined cleanup passed.')

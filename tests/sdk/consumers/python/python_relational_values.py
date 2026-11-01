"""Relational boundary validation and owned async cancellation, without authority."""
import asyncio
import copy
from dataclasses import FrozenInstanceError
import json
import sys
from pathlib import Path
import threading
from types import SimpleNamespace
import unittest
from transit_client._worker import Worker
from transit_client.errors import Busy, Closed, IncompatibleNative
from transit_station import relational as r
from transit_station.catalog_values import DEFINITION
from transit_station import catalog_values as v
from transit_client import ResourceRef
from transit_station import logical_values as logical

COMPANION_FIXTURE = Path(sys.argv.pop(1))

REF = dict(definition=DEFINITION, id='01'*16, plan='02'*32, basis='03'*32)
PAGE = dict(reference=REF, ordinal=str((1 << 64)-1), row=dict(identity=dict(group=[None, {'signed': str(-(1 << 63))}, {'utf8': 'A\0é '}, {'utf8': ''}]), cells=[dict(value=dict(atom=dict(signed=str(-(1 << 63))))), dict(value=dict(atom=dict(unsigned=str((1 << 64)-1)))), {'null': {}}, {'value': {'atom': {'utf8': 'A\0é '}}}, {'value': {'atom': {'utf8': ''}}}]), complete_coverage=False)


class Values(unittest.TestCase):
    def test_semantic_descriptors_preserve_zero_digest_bytes_and_full_width_units(self):
        digest = bytearray(range(32))
        raw = bytearray(b'TZif\x00\xff')
        rules = v.TimezoneRules('fixture', digest, 'Etc/UTC', raw)
        semantics = v.ColumnSemantics(timezone=rules)
        digest[:] = bytes(32)
        raw[:] = bytes(6)
        self.assertEqual(v._semantics(semantics._wire()), semantics)
        self.assertEqual(rules.digest, bytes(range(32)))
        self.assertEqual(rules.tzif, b'TZif\x00\xff')
        spatial = v.ColumnSemantics(spatial=v.SpatialSemantics(4326, 0, (1 << 64)-1, 'right_handed_z_up', 'planar', 1e-9, 'shewchuk_adaptive', 'none'))
        self.assertEqual(v._semantics(spatial._wire()), spatial)
        bad = spatial._wire()
        bad['spatial']['axis_orientation'] = 'invented'
        with self.assertRaises(ValueError): v._semantics(bad)
        with self.assertRaises(ValueError): v._semantics(dict(rounding=None, metric=None, timezone=None))

    def test_companion_values_preserve_independent_descriptors_and_bits(self):
        fixtures = json.loads(COMPANION_FIXTURE.read_text())
        for case in fixtures['cases']:
            if case['error'] is not None:
                continue  # Semantic admission belongs to Zig.
            with self.subTest(case=case['name']):
                self.assertEqual(logical.type_wire(logical.type_from_wire(case['field']['type'])), case['field']['type'])
                native = logical.cell_from_wire(case['cell'])
                self.assertEqual(logical.cell_wire(native), case['cell'])
        mutable = bytearray(b'\x00\x00\xa0\x3f')
        vector = logical.VectorValue(mutable)
        mutable[:] = b'\0' * 4
        self.assertEqual(vector.data, b'\x00\x00\xa0\x3f')

    def test_references_require_definition_and_own_identity(self):
        ref = r.Reference.restore(json.dumps(REF))
        self.assertEqual(json.loads(ref.save()), REF)
        with self.assertRaises(FrozenInstanceError): ref.id = '00'*16
        for bad in ({**REF, 'definition': 'foreign'}, {k: v for k, v in REF.items() if k != 'definition'}, {**REF, 'extra': True}, {**REF, 'id': '00'*16}):
            with self.assertRaises(IncompatibleNative): r.Reference.restore(json.dumps(bad))
        for _ in range(20): self.assertRegex(r.fresh_id(), r'^[0-9a-f]{32}$')

    def test_full_width_values_are_owned(self):
        source = copy.deepcopy(PAGE)
        page = r._decode(r._page, source, r.Reference(**REF), (1 << 64)-1)
        source['row']['cells'].clear()
        self.assertEqual(page.row.cells, (-(1 << 63), (1 << 64)-1, None, 'A\0é ', ''))
        self.assertEqual(page.row.identity.keys, (None, -(1 << 63), 'A\0é ', ''))
        self.assertFalse(page.complete_coverage)
        pair = dict(identity=dict(pair=dict(left='ff'*20, right=None)), cells=[{'null': {}}])
        self.assertEqual(r._row(pair).identity.left.data, b'\xff'*20)

    def test_invalid_native_pages_reject(self):
        for bad in (
            {**PAGE, 'reference': {**REF, 'basis': '04'*32}},
            {**PAGE, 'ordinal': '01'}, {**PAGE, 'row': None},
            {**PAGE, 'complete_coverage': True}, {**PAGE, 'extra': True},
            {**PAGE, 'row': dict(identity=dict(group=[]), cells=[dict(value=dict(atom=dict(signed=str(1 << 63))))])},
            {**PAGE, 'row': dict(identity=dict(group=[]), cells=[dict(value=dict(atom=dict(unsigned=str(1 << 64))))])},
        ):
            with self.assertRaises(IncompatibleNative): r._decode(r._page, bad, r.Reference(**REF), (1 << 64)-1)

    def test_text_scalars_reject_invalid_utf8_and_old_untyped_keys(self):
        for key in ('1', {'utf8': '\ud800'}, {'utf8': 'x' * (1024 * 1024 + 1)}, {'signed': '01'}):
            bad = {**PAGE, 'row': dict(identity=dict(group=[key]), cells=[{'null': {}}])}
            with self.assertRaises(IncompatibleNative): r._decode(r._page, bad, r.Reference(**REF), (1 << 64)-1)

    def test_options_and_routes_are_exact(self):
        options = r.Options('independent_table_snapshots', 16777216, (1 << 64)-1, 1, 1, 1, 2, 1, 1, Path('/tmp'))
        self.assertEqual(options._wire()['spill_bytes'], str((1 << 64)-1))
        routes = [0, 1]
        statement = r.Statement('SELECT COUNT(*) FROM l JOIN r ON l.k=r.k', routes)
        routes.clear()
        self.assertEqual(statement.routes, (0, 1))
        with self.assertRaises(ValueError): r.Statement('SELECT k FROM t', (True,))

    def test_retained_sources_preserve_complete_bindings_and_wide_cuts(self):
        wide = (1 << 64)-1
        connection = v.Connection(v.Scope(ResourceRef(42, 3), wide), 5)
        obj = dict(scope=connection.scope._wire(), branch='1', object=str(wide-1))
        interpretation = dict(object=obj, revision=str(wide), digest='ab'*32)
        stored = dict(interpretation=interpretation, content=dict(bytes='100', sha256='ab'*32), schema_fingerprint='cd'*32, retired=False)
        binding = dict(definition=DEFINITION, connection=connection._wire(7), namespace=1, name='items', interpretation=stored)
        owner = dict(definition=DEFINITION, connection=connection._wire(7), object=obj, operation=str(wide))
        snapshot = v.Snapshot.restore(json.dumps(dict(owner=owner, content=dict(bytes='200', sha256='ef'*32))))
        original = r.RetainedSource(v.Basis.restore(json.dumps(binding)), snapshot)
        position = dict(partition=str(wide), next_lsn=str(wide))
        description = dict(definition=DEFINITION, plan=REF['plan'], sources=[dict(alias='i', binding=binding, position=position)],
                           columns=[dict(name='id', type={'int64': {}}, nullable=False, optional=False)], join=None, grouped=False, executed=False)
        opened = dict(reference=REF, description=description, cuts=[dict(object=obj, position=position, commitment='aa'*32, schema='cd'*32)], complete_coverage=False)
        result = r._decode(r._opened, copy.deepcopy(opened), REF['id'], (original,))
        self.assertEqual(result.cuts[0].position.next_lsn, wide)
        self.assertEqual(result.description.sources[0].basis.object_id, wide-1)
        for mutation in ('binding', 'cut', 'schema', 'definition', 'numeric_position', 'position'):
            bad = copy.deepcopy(opened)
            if mutation == 'binding': bad['description']['sources'][0]['binding']['name'] = 'other'
            elif mutation == 'cut': bad['cuts'][0]['object'] = dict(obj, object='1')
            elif mutation == 'schema': bad['cuts'][0]['schema'] = '00'*32
            elif mutation == 'definition': del bad['description']['sources'][0]['binding']['definition']
            elif mutation == 'numeric_position': bad['cuts'][0]['position'] = dict(position, next_lsn=wide)
            elif mutation == 'position': bad['cuts'][0]['position'] = dict(position, next_lsn='1')
            with self.subTest(mutation=mutation), self.assertRaises(IncompatibleNative):
                r._decode(r._opened, bad, REF['id'], (original,))
        changed = dict(binding, connection=dict(binding['connection'], principal=8))
        with self.assertRaises(ValueError): r.RetainedSource(v.Basis.restore(json.dumps(changed)), snapshot)


class AsyncOwnership(unittest.IsolatedAsyncioTestCase):
    async def test_cancelled_await_keeps_worker_owned_and_close_joins(self):
        started, release, destroyed = threading.Event(), threading.Event(), threading.Event()
        worker = Worker(8*1024*1024)
        def invoke(action, expected):
            started.set()
            if not release.wait(10): raise AssertionError('Fixture did not release its owned operation')
            return copy.deepcopy(PAGE)
        client = r.AsyncClient.__new__(r.AsyncClient)
        client._owner = SimpleNamespace(_worker=worker, _invoke=invoke, _destroy=destroyed.set)
        try:
            pending = asyncio.create_task(client.page(r.Reference(**REF), (1 << 64)-1))
            self.assertTrue(await asyncio.to_thread(started.wait, 5))
            pending.cancel()
            with self.assertRaises(asyncio.CancelledError): await pending
            with self.assertRaises(Busy): await client.page(r.Reference(**REF), 0)
            closing = asyncio.create_task(client.close())
            await asyncio.sleep(0)
            self.assertFalse(closing.done())
            self.assertFalse(destroyed.is_set())
            release.set()
            await closing
            self.assertTrue(destroyed.is_set())
            with self.assertRaises(Closed): await client.page(r.Reference(**REF), 0)
        finally:
            release.set()
            await client.close()


if __name__ == '__main__': unittest.main()

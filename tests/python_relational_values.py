"""Relational boundary validation and owned async cancellation, without authority."""
import asyncio
import copy
from dataclasses import FrozenInstanceError
import json
from pathlib import Path
import threading
from types import SimpleNamespace
import unittest
from transit_client._worker import Worker
from transit_client.errors import Busy, Closed, IncompatibleNative
from transit_station import relational as r
from transit_station.catalog_values import DEFINITION

REF = dict(definition=DEFINITION, id='01'*16, plan='02'*32, basis='03'*32)
PAGE = dict(reference=REF, ordinal=str((1 << 64)-1), row=dict(identity=dict(group=[None, str(-(1 << 63))]), cells=[dict(value=dict(atom=dict(signed=str(-(1 << 63))))), dict(value=dict(atom=dict(unsigned=str((1 << 64)-1)))), {'null': {}}]), complete_coverage=False)


class Values(unittest.TestCase):
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
        self.assertEqual(page.row.cells, (-(1 << 63), (1 << 64)-1, None))
        self.assertEqual(page.row.identity.keys, (None, -(1 << 63)))
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

    def test_options_and_routes_are_exact(self):
        options = r.Options('per_resource_snapshot_vector', 16777216, (1 << 64)-1, 1, 1, 1, 2, 1, 1, Path('/tmp'))
        self.assertEqual(options._wire()['spill_bytes'], str((1 << 64)-1))
        routes = [0, 1]
        statement = r.Statement('SELECT COUNT(*) FROM l JOIN r ON l.k=r.k', routes)
        routes.clear()
        self.assertEqual(statement.routes, (0, 1))
        with self.assertRaises(ValueError): r.Statement('SELECT k FROM t', (True,))


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

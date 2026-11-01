"""Installed sync/async direct lifecycle, retained SQL and exact fault recovery."""
import asyncio
import inspect
import json
import os
from pathlib import Path
import sys
from transit_client import ResourceRef
from transit_client.errors import TransitError
from transit_station import catalog as m, logical as l, relational as r


async def resolve(value): return await value if inspect.isawaitable(value) else value


def persist(path, text):
    with path.open('w') as file:
        os.chmod(path, 0o600)
        file.write(text)
        file.flush()
        os.fsync(file.fileno())


async def run(mode, config_file):
    assert 'site-packages' in str(Path(m.__file__).resolve()), m.__file__
    assert 'site-packages' in str(Path(r.__file__).resolve()), r.__file__
    path = Path(config_file)
    config = json.loads(path.read_text()); c = config['connection']; s = c['scope']
    connection = m.Connection(m.Scope(ResourceRef(s['realm'], s['resource']), int(s['catalog'])), c['audience'], int(c['branch']), c['role'])
    cls, query_cls = (m.Client, r.Client) if mode == 'sync' else (m.AsyncClient, r.AsyncClient)
    client = cls(config['url'], c['principal'], Path(config['seed_file']), connection, service_url=config['service_url'], timeout_ms=10000)
    root = path.parent / mode
    root.mkdir(exist_ok=True)
    offset = 0 if mode == 'sync' else 10
    name = 'python_' + mode
    object_id = (1 << 64)-2-offset
    query = query_cls(config['url'], c['principal'], Path(config['seed_file']), (connection,),
                      r.Options('independent_table_snapshots', 16777216, 16777216, 8388608, 1000, 100000, 2, 100000, 100000, root),
                      service_url=config['service_url'], timeout_ms=10000)
    opened = None
    sources = None
    statement = r.Statement(f'SELECT id FROM {name}', (0,))
    identity = f'{offset+1:032x}'
    write = lambda value: print(json.dumps(dict(status=0, value=value)), flush=True)
    async def compiled(sql, op, object_id=None):
        return await resolve(client.compile_sql(sql, m.Identity(offset+op), object_id))
    async def complete(work):
        persist(root / 'work.json', work.saved.save())
        original = await resolve(client.stage(work.intent))
        persist(root / 'work-reference.json', original.save())
        observed = await resolve(client.admit(original))
        for _ in range(16):
            if observed.state != 'admitted': break
            observed = await resolve(client.execute(original, 32))
        assert observed.state == 'committed', observed
        return observed
    async def uncertain(invoke, original):
        try: await resolve(invoke())
        except m.Uncertain as error:
            assert error.original.save() == original.save()
            assert error.recovery == original.save().encode()
            assert error.status == 6 and error.diagnostic['outcome'] == 'unknown'
            assert not error.diagnostic_invalid
        else: raise AssertionError('Accepted lost reply was reported as certain')
    def saved_snapshot(): return m.Snapshot.restore((root / 'snapshot.json').read_text())
    async def open_retained():
        nonlocal opened, sources
        snapshot = saved_snapshot()
        basis = m.Basis.restore((root / 'basis.json').read_text())
        sources = (r.RetainedSource(basis, snapshot),)
        opened = await resolve(query.open_query(identity, statement, sources))
        repeated = await resolve(query.open_query(identity, statement, sources))
        assert opened == repeated and opened.description.sources[0].basis._wire() == basis._wire()
        assert not opened.complete_coverage
        return opened
    try:
        print(json.dumps(dict(ready=True)), flush=True)
        for line in sys.stdin:
            action = json.loads(line)
            if 'close' in action: break
            command = next(iter(action))
            if command == 'prepare':
                assert (await resolve(client.describe())).subject.principal == c['principal']
                await complete(await compiled(f'CREATE TABLE {name} (id BIGINT PRIMARY KEY, payload BINARY)', 1, object_id))
                current = await resolve(client.lookup(name))
                assert current.row_count == 0 and current.basis.object_id == object_id
                rows = tuple((m.Assignment(1, l.Present(l.Atom('signed', i))),
                              m.Assignment(2, l.Present(l.Atom('binary', bytes([i])*32768)))) for i in range(9))
                work = await resolve(client.prepare(name, m.Identity(offset+2), m.Mutate(current.basis, m.Insert(rows), ingestion='bulk')))
                assert (await resolve(client.preview(work.intent))).current.row_count == 0
                persist(root / 'intent.json', work.saved.save())
                loaded = await resolve(client.load(m.SavedIntent.restore((root / 'intent.json').read_text())))
                original = await resolve(client.stage(loaded))
                persist(root / 'original.json', original.save())
                assert (await resolve(client.admit(original))).state == 'admitted'
                await uncertain(lambda: client.execute(original, 32), original)
                write(dict(uncertain=True, operation=str(original.operation)))
            elif command == 'recover':
                original = m.Reference.restore((root / 'original.json').read_text())
                observed = await resolve(client.inspect(original))
                assert observed.state == 'committed' and observed.commit.matched == observed.commit.affected == observed.commit.live_rows == 9
                assert await resolve(client.execute(original, 32)) == observed
                current = await resolve(client.lookup(name))
                acquisition = client.prepare_snapshot(current.basis, current.position, 90000+offset)
                persist(root / 'basis.json', current.basis.save())
                persist(root / 'acquisition.json', acquisition.save())
                await uncertain(lambda: client.acquire_snapshot(acquisition), acquisition)
                write(dict(retention_uncertain=True))
            elif command == 'retained':
                acquisition = m.SnapshotAcquisition.restore((root / 'acquisition.json').read_text())
                status = await resolve(client.snapshot_status(acquisition.owner))
                assert not status.released and status.snapshot
                snapshot = status.snapshot
                persist(root / 'snapshot.json', snapshot.save())
                metadata = await resolve(client.snapshot_metadata(snapshot))
                assert metadata.accepted == acquisition.expected and metadata.row_count == 9
                explained = await resolve(query.explain(statement))
                assert explained.sources[0].basis._wire() == m.Basis.restore((root / 'basis.json').read_text())._wire()
                await open_retained()
                assert opened.cuts[0].position == acquisition.expected
                first = await resolve(query.page(opened.reference, 0))
                assert first.row.cells == (0,) and not first.complete_coverage
                assert await resolve(query.page(opened.reference, 0)) == first
                write(dict(opened=True))
            elif command == 'denied':
                for invoke in (lambda: query.page(opened.reference, int(action[command]['ordinal'])),
                               lambda: query.open_query(identity, statement, sources)):
                    try: await resolve(invoke())
                    except TransitError as error:
                        assert error.status == 4 and error.diagnostic['category'] == 'access', error
                    else: raise AssertionError('Revoked caller disclosed buffered output')
                write(dict(denied=True))
            elif command == 'rows':
                for ordinal in range(9):
                    page = await resolve(query.page(opened.reference, ordinal))
                    assert page.row.cells == (ordinal,) and not page.complete_coverage
                    assert await resolve(query.page(opened.reference, ordinal)) == page
                page = await resolve(query.page(opened.reference, 9))
                assert page.complete_coverage and page.row is None
                assert await resolve(query.page(opened.reference, 9)) == page
                write(dict(rows=9, complete=True))
            elif command == 'retire':
                assert (await resolve(query.page(opened.reference, 9))).complete_coverage
                await resolve(query.close_query(opened.reference))
                unchanged = await complete(await compiled(f'UPDATE {name} SET id = 0 WHERE id = 0', 3))
                assert unchanged.commit.matched == 1 and unchanged.commit.affected == 0
                deleted = await complete(await compiled(f'DELETE FROM {name} WHERE id = 8', 4))
                assert deleted.commit.matched == deleted.commit.affected == 1
                await complete(await compiled(f'ALTER TABLE {name} ADD COLUMN extra BIGINT', 5))
                await complete(await compiled(f'ALTER TABLE {name} RENAME TO {name}_old', 6))
                await complete(await compiled(f'DROP TABLE {name}_old', 7))
                await complete(await compiled(f'CREATE TABLE {name} (replacement BIGINT)', 8, object_id-1))
                assert (await resolve(client.lookup(name))).basis.object_id == object_id-1
                snapshot = saved_snapshot()
                assert (await resolve(client.snapshot_metadata(snapshot))).row_count == 9
                identity = f'{offset+2:032x}'
                await open_retained()
                write(dict(original=True))
            elif command == 'release':
                await resolve(query.close_query(opened.reference))
                await resolve(query.close_query(opened.reference))
                snapshot = saved_snapshot()
                assert not (await resolve(client.snapshot_status(snapshot.owner))).released
                await uncertain(lambda: client.release_snapshot(snapshot), snapshot)
                write(dict(release_uncertain=True))
            elif command == 'verify':
                snapshot = saved_snapshot()
                assert (await resolve(client.snapshot_status(snapshot.owner))).released
                await resolve(client.release_snapshot(snapshot))
                original = m.Reference.restore((root / 'original.json').read_text())
                assert (await resolve(client.inspect(original))).commit.affected == 9
                loaded = await resolve(client.load(m.SavedIntent.restore((root / 'intent.json').read_text())))
                assert loaded.operation == original.operation
                assert (await resolve(client.lookup(name))).basis.object_id == object_id-1
                listing = await resolve(client.tables())
                assert listing.consistency == 'independent'
                write(dict(recovered=True))
            elif command == 'history_begin':
                key = client.prepare_history_key(bytes([67])*32, (92000+offset).to_bytes(16, 'big'))
                selection = client.prepare_history_selection(92000+offset)
                step = client.prepare_history_step(selection, 1, name)
                persist(root / 'history-step.json', step.save())
                selection = await resolve(client.select_history(step))
                original = client.prepare_history_acquisition(selection, key)
                persist(root / 'history-acquisition.json', original.save())
                await uncertain(lambda: client.acquire_history(original), original)
                write(dict(history_uncertain=True))
            elif command == 'history_recover':
                original = m.HistoryAcquisition.restore((root / 'history-acquisition.json').read_text())
                status = await resolve(client.inspect_history(original.key))
                assert status.intent.operation == 92000+offset
                for _ in range(16):
                    if status.phase == 'published': break
                    status = await resolve(client.advance_history(original.key))
                assert status.phase == 'published' and status.basis.consistency == 'single_partition'
                assert (await resolve(client.acquire_history(original))).basis == status.basis
                persist(root / 'history-snapshot.json', status.basis.snapshot.save())
                source = await resolve(client.historical_source(status.basis.snapshot, object_id))
                assert source.row_count == 9 and len(source.schema.columns) == 2
                write(dict(published=True))
            elif command == 'history_denied':
                retained = m.HistoricalSnapshot.restore((root / 'history-snapshot.json').read_text())
                for invoke in (lambda: client.historical_source(retained, object_id), lambda: client.historical_tables(retained, 1)):
                    try: await resolve(invoke())
                    except TransitError as error:
                        assert error.status == 4 and not isinstance(error, m.Uncertain), error
                    else: raise AssertionError('Revoked caller disclosed historical metadata')
                write(dict(denied=True))
            elif command == 'history_inspect':
                retained = m.HistoricalSnapshot.restore((root / 'history-snapshot.json').read_text())
                assert await resolve(client.historical_lookup(retained, 1, name)) == object_id
                source = await resolve(client.historical_source(retained, object_id))
                assert source.row_count == 9 and len(source.schema.columns) == 2
                page = await resolve(client.historical_tables(retained, 1))
                assert len(page.entries) == 1 and page.next is None and page.entries[0].name == name
                assert page.entries[0].definition == source.binding.definition
                assert page.basis.snapshot == retained and page.basis.source_count == 1
                write(dict(original=True))
            elif command == 'history_release':
                retained = m.HistoricalSnapshot.restore((root / 'history-snapshot.json').read_text())
                assert (await resolve(client.historical_source(retained, object_id))).row_count == 9
                original = m.HistoryAcquisition.restore((root / 'history-acquisition.json').read_text())
                control = client.prepare_history_control(original.key, 'release')
                persist(root / 'history-control.json', control.save())
                await uncertain(lambda: client.resume_history_control(control), control)
                write(dict(history_release_uncertain=True))
            elif command == 'history_finish':
                control = m.HistoryControl.restore((root / 'history-control.json').read_text())
                status = await resolve(client.inspect_history(control.key))
                assert status.phase in ('releasing', 'released')
                for _ in range(16):
                    if status.phase == 'released': break
                    status = await resolve(client.advance_history(control.key))
                assert status.phase == 'released'
                assert (await resolve(client.resume_history_control(control))).phase == 'released'
                retained = m.HistoricalSnapshot.restore((root / 'history-snapshot.json').read_text())
                assert status.basis.snapshot == retained
                try: await resolve(client.historical_source(retained, object_id))
                except TransitError as error: assert not isinstance(error, m.Uncertain)
                else: raise AssertionError('Released history remained readable')
                write(dict(released=True))
            else: raise AssertionError(f'Unknown proof phase: {command}')
    finally:
        await resolve(query.close())
        await resolve(client.close())
    print(json.dumps(dict(closed=True)), flush=True)


if __name__ == '__main__': asyncio.run(run(*sys.argv[1:]))

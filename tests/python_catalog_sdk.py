"""Installed synchronous/asynchronous general Table lifecycle and saved recovery."""
import asyncio
import inspect
import json
import os
from pathlib import Path
import sys
import time
from transit_client import ProcessRef, ResourceRef
from transit_client.errors import TransitError
from transit_station import catalog as m, logical as l


async def resolve(value):
    return await value if inspect.isawaitable(value) else value


def persist(path, data):
    with path.open('wb') as file:
        os.chmod(path, 0o600)
        file.write(data)
        file.flush()
        os.fsync(file.fileno())


async def scenario(client, connect, path, index, principal):
    base = 1100 + index * 100
    original_object = 12001 + index * 10
    name = f'sdk_people_{index}'
    identity = lambda offset: m.Identity(base + offset, base + offset + 100000)
    async def finish(compiled):
        # Saved compatibility is required on restore, alongside immutable bytes.
        persist(path / 'intent.json', json.dumps(dict(definition=compiled.saved.definition, data=compiled.saved.data.hex())).encode())
        reference = compiled.intent.reference
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            step = await resolve(client.next(reference))
            if step.kind == m.NextKind.TERMINAL: return step.outcome
            if step.kind == m.NextKind.RUNNING: continue
            assert step.kind == m.NextKind.SEND
            persist(path / 'step.json', step.prepared.data)
            position = await resolve(client.submit(step.prepared))
            persist(path / 'receipt.json', json.dumps(dict(position=position)).encode())
            while time.monotonic() < deadline:
                progress = await resolve(client.progress(reference, step.prepared, position, wait=True))
                if progress.observation == m.Observation.PENDING: continue
                assert progress.disposition is None, progress
                if progress.outcome is not None and progress.outcome.terminal: return progress.outcome
                break
        raise AssertionError('Installed Table operation exceeded its budget')

    description = await resolve(client.describe())
    assert description.configuration.scope == client.connection.scope
    assert description.subject.principal == principal
    assert description.subject.credential_epoch > 0
    compiled = await resolve(client.compile_sql(f'CREATE TABLE {name} (id INTEGER PRIMARY KEY, payload STRUCT(data BINARY, label UTF8), amount DECIMAL(38,2))', identity(0), original_object))
    created = await finish(compiled)
    assert created.phase == m.Phase.APPLIED, created
    original = await resolve(client.lookup(name))
    assert len(original.schema.columns) == 3 and isinstance(original.schema.columns[1].type, l.StructureType)
    atom = lambda kind, value: l.Present(l.Atom(kind, value))
    payload = l.Present(l.SequenceValue('structure', (atom('binary', bytes([0, 128, 255])), atom('utf8', '東京'))))
    amount = atom('decimal', 123456789012345678901234567890)
    insert = await resolve(client.prepare(name, identity(1), m.Mutate(original.metadata.basis, m.Insert(((m.Assignment(3, amount), m.Assignment(1, atom('signed', 1)), m.Assignment(2, payload)),)))))
    applied = await finish(insert)
    assert applied.counts == m.Counts(1, 1), applied
    saved = insert.saved
    predicate = (m.Comparison(1, m.CompareOperator.EQ, l.Atom('signed', 1)),)
    unchanged = await finish(await resolve(client.prepare(name, identity(2), m.Mutate(original.metadata.basis, m.Update((m.Assignment(3, amount),), predicate)))))
    assert unchanged.counts == m.Counts(1, 0), unchanged
    altered = await finish(await resolve(client.prepare(name, identity(3), m.Alter(original.metadata.basis, m.AddColumn('enabled', l.ScalarType('boolean'), nullable=False, default=atom('boolean', True))))))
    assert altered.phase == m.Phase.APPLIED
    try: await resolve(client.prepare(name, identity(4), m.Drop(original.metadata.basis)))
    except TransitError: pass
    else: raise AssertionError('Stale metadata retargeted Table work')
    current = await resolve(client.lookup(name))
    deleted = await finish(await resolve(client.prepare(name, identity(5), m.Mutate(current.metadata.basis, m.Delete(predicate)))))
    assert deleted.counts == m.Counts(1, 1), deleted
    assert (await finish(await resolve(client.prepare(name, identity(6), m.Drop(current.metadata.basis))))).phase == m.Phase.APPLIED
    assert (await finish(await resolve(client.compile_sql(f'CREATE TABLE {name} (replacement TEXT)', identity(7), original_object + 1)))).phase == m.Phase.APPLIED
    await resolve(client.close())
    client = connect()
    try:
        loaded = await resolve(client.load(m.SavedIntent(saved.definition, saved.data)))
        assert loaded.object_id == original_object
        assert (await resolve(client.status(loaded.reference))).outcome == applied
        assert (await resolve(client.lookup(name))).metadata.object_id == original_object + 1
        historical = await resolve(client.definition(original_object, original.metadata.revision))
        assert historical.metadata == original.metadata and historical.schema == original.schema
        assert not hasattr(historical, 'head')
        assert await resolve(client.definition(original_object, 999)) is None
        assert (await resolve(client.list())).entries
    finally:
        await resolve(client.close())
    return dict(profile='installed-python-general-table', original_object=str(original_object), replacement_object=str(original_object + 1), counts=dict(matched=str(applied.counts.matched), changed=str(applied.counts.changed)))


async def run(mode, path):
    # Run against installed wheels, never a source-tree import override.
    assert 'site-packages' in str(Path(m.__file__).resolve()), m.__file__
    path = Path(path)
    config = json.loads(path.read_text()); c = config['connection']; s = c['scope']
    connection = m.Connection(ProcessRef(s['realm'], c['owner']), m.Scope(ResourceRef(s['realm'], s['resource']), int(s['catalog'])), role=c.get('role'), namespace=c.get('namespace', 1))
    cls = m.Client if mode == 'sync' else m.AsyncClient
    connect = lambda: cls(config['url'], c['principal'], Path(config['seed_file']), connection, timeout_ms=30000 if config.get('table_service_url') else 10000, table_service_url=config.get('table_service_url'))
    client = connect()
    try:
        print(json.dumps(dict(ready=True)), flush=True)
        while line := sys.stdin.readline():
            action = json.loads(line)
            if 'close' in action: break
            if 'denied' in action:
                fresh = connect()
                try:
                    try: await resolve(fresh.describe())
                    except TransitError as error: assert error.status == 4, error
                    else: raise AssertionError('Revoked CONNECT disclosed catalog')
                finally: await resolve(fresh.close())
                print(json.dumps(dict(status=0, value=dict(denied=True))), flush=True)
                continue
            assert 'scenario' in action
            result = await scenario(client, connect, path.parent, action['scenario']['index'], c['principal'])
            print(json.dumps(dict(status=0, value=result)), flush=True)
    finally:
        await resolve(client.close())
    print(json.dumps(dict(closed=True)), flush=True)


if __name__ == '__main__': asyncio.run(run(*sys.argv[1:]))

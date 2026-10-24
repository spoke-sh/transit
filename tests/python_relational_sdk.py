"""Installed sync/async relational API consumer; never imports wire declarations."""
import asyncio
import inspect
import json
from pathlib import Path
import sys
from transit_client import ResourceRef
from transit_client.errors import TransitError
from transit_station import catalog, relational as r


def description(value):
    return dict(plan=value.plan, sources=[dict(alias=s.alias, binding=json.loads(s.basis.save()),
        position=dict(partition=str(s.position.partition), next_lsn=str(s.position.next_lsn))) for s in value.sources],
        columns=[dict(name=c.name, type=dict(kind=c.type.kind), nullable=c.nullable) for c in value.columns],
        join=value.join, grouped=value.grouped, executed=value.executed)


def cuts(values):
    return [dict(objectId=str(c.object.object_id), position=dict(partition=str(c.position.partition), nextLsn=str(c.position.next_lsn)),
        commitment=c.commitment, schema=c.schema) for c in values]


def row(value):
    if value is None: return None
    if isinstance(value.identity, r.GroupIdentity): identity = dict(kind='group', keys=[None if k is None else str(k) for k in value.identity.keys])
    else: identity = dict(kind='pair', left=value.identity.left.data.hex(), right=None if value.identity.right is None else value.identity.right.data.hex())
    assert isinstance(value.cells, tuple)
    return dict(identity=identity, cells=[None if c is None else str(c) for c in value.cells])


async def resolve(value): return await value if inspect.isawaitable(value) else value


async def main():
    assert Path(r.__file__).resolve().is_relative_to(Path(sys.prefix).resolve())
    config = json.loads(Path(sys.argv[2]).read_text())
    catalogs = tuple(catalog.Connection(catalog.Scope(ResourceRef(c['scope']['realm'], c['scope']['resource']), int(c['scope']['catalog'])), c['audience'], int(c['branch']), c['role']) for c in config['catalogs'])
    options = r.Options('independent_table_snapshots', 16777216, 16777216, 8388608, 1000, 100000, 2, 100000, 100000, Path(config['spill_directory']))
    cls = r.AsyncClient if sys.argv[1] == 'async' else r.Client
    def connect(): return cls(config['url'], config['catalogs'][0]['principal'], Path(config['seed_file']), catalogs, options, service_url=config['service_url'])
    client = connect()
    write = lambda value: print(json.dumps(value), flush=True)
    try:
        write(dict(ready=True))
        for line in sys.stdin:
            action = json.loads(line)
            if 'close' in action: break
            try:
                if 'explain' in action:
                    value = description(await resolve(client.explain(r.Statement(**action['explain']))))
                elif 'open' in action:
                    a = action['open']
                    sources = tuple(r.RetainedSource(catalog.Basis.restore(source['basis']), catalog.Snapshot.restore(source['snapshot'])) for source in a['sources'])
                    result = await resolve(client.open_query(a['id'], r.Statement(**a['statement']), sources))
                    value = dict(reference=result.reference.save(), description=description(result.description), cuts=cuts(result.cuts), completeCoverage=result.complete_coverage)
                elif 'page' in action:
                    a = action['page']
                    result = await resolve(client.page(r.Reference.restore(a['reference']), int(a['ordinal'])))
                    value = dict(reference=result.reference.save(), ordinal=str(result.ordinal), row=row(result.row), completeCoverage=result.complete_coverage)
                elif 'close_query' in action:
                    await resolve(client.close_query(r.Reference.restore(action['close_query'])))
                    value = {}
                elif 'reconnect' in action:
                    await resolve(client.close())
                    client = connect()
                    value = {}
                else: raise AssertionError('Unknown proof operation')
                write(dict(status=0, value=value))
            except TransitError as error:
                assert not error.diagnostic_invalid
                write(dict(status=error.status or 1, value=dict(err=error.code, diagnostic=error.diagnostic)))
    finally: await resolve(client.close())
    write(dict(closed=True))


asyncio.run(main())

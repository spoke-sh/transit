"""Installed public Catalog/Query consumer; the driver owns expected results."""
import time

import asyncio
import hashlib
import inspect
import json
import os
from pathlib import Path
import resource
import struct
import sys
_import_started = time.perf_counter_ns()
from transit_client import ResourceRef
from transit_station import catalog as m, relational as r

_import_ns = time.perf_counter_ns() - _import_started


def persist(path, value):
    """Publish original work before dispatch, including directory durability."""
    temporary = path.with_suffix('.tmp')
    with temporary.open('w') as file:
        os.chmod(temporary, 0o600)
        file.write(value)
        file.flush()
        os.fsync(file.fileno())
    temporary.replace(path)
    descriptor = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


async def resolved(value):
    return await value if inspect.isawaitable(value) else value


async def main(mode, config_file):
    assert Path(m.__file__).is_relative_to(Path(sys.prefix)), 'SDK is not installed'
    config = json.loads(Path(config_file).read_text())
    connection = config['connection']
    scope = connection['scope']
    route = m.Connection(m.Scope(ResourceRef(scope['realm'], scope['resource']), int(scope['catalog'])),
                         connection['audience'], int(connection['branch']), connection['role'])
    cls, query_cls = (m.Client, r.Client) if mode == 'sync' else (m.AsyncClient, r.AsyncClient)
    started = time.perf_counter_ns()
    client = cls(config['url'], connection['principal'], Path(config['seed_file']), route,
                 service_url=config['service_url'], timeout_ms=10000)
    query = None
    root = Path(config_file).parent
    try:
        query = query_cls(config['url'], connection['principal'], Path(config['seed_file']), (route,),
            r.Options('independent_table_snapshots', 16777216, 16777216, 8388608,
                      1000, 100000, 2, 100000, 100000, root),
            service_url=config['service_url'], timeout_ms=10000)
        opened_ns = time.perf_counter_ns() - started
        print(json.dumps(dict(ready=True)), flush=True)
        for line in sys.stdin:
            request = json.loads(line)
            if 'close' in request:
                break
            started, cpu = time.perf_counter_ns(), time.process_time_ns()
            operation = request['operation']
            result = {}
            if operation == 'info':
                result.update(import_ns=_import_ns, open_ns=opened_ns, runtime=sys.version.split()[0])
            elif operation == 'lookup':
                value = await resolved(client.lookup(request['name']))
                result.update(rows=value.row_count if value else None,
                              columns=len(value.schema.columns) if value else None, complete=True)
            elif operation == 'query':
                current = await resolved(client.lookup(request['name']))
                acquisition = client.prepare_snapshot(current.basis, current.position, int(request['id']))
                persist(root / 'pending.json', acquisition.save())
                snapshot = await resolved(client.acquire_snapshot(acquisition))
                persist(root / 'snapshot.json', snapshot.save())
                opened = None
                try:
                    opened = await resolved(query.open_query(f'{int(request["id"]):032x}',
                        r.Statement(request['sql'], (0,)), (r.RetainedSource(current.basis, snapshot),)))
                    values, rows, first = [], 0, None
                    while rows <= 1000:
                        page = await resolved(query.page(opened.reference, rows))
                        if page.row is not None:
                            if first is None:
                                first = time.perf_counter_ns() - started
                            assert len(page.row.cells) == 2 and all(type(value) is int for value in page.row.cells)
                            assert rows < 1000, 'Result row budget exhausted'
                            values.append(page.row.cells)
                            rows += 1
                        if page.complete_coverage:
                            break
                        assert page.row is not None, 'Incomplete result made no progress'
                    else:
                        raise AssertionError('Result row budget exhausted')
                    digest = hashlib.sha256()
                    for value in sorted(values):
                        digest.update(struct.pack('<qq', *value))
                    result.update(rows=rows, digest=digest.hexdigest(), complete=True, first_row_ns=first)
                finally:
                    try:
                        if opened is not None:
                            await resolved(query.close_query(opened.reference))
                    finally:
                        await resolved(client.release_snapshot(snapshot))
            elif operation == 'write':
                work = await resolved(client.compile_sql(request['sql'], m.Identity(int(request['id']))))
                persist(root / 'pending.json', work.saved.save())
                original = await resolved(client.stage(work.intent))
                persist(root / 'original.json', original.save())
                observed = await resolved(client.admit(original))
                for _ in range(128):
                    if observed.state != 'admitted':
                        break
                    observed = await resolved(client.execute(original, 32))
                assert observed.state == 'committed', 'Original operation did not complete'
                result.update(changed=observed.commit.affected, matched=observed.commit.matched, complete=True)
            else:
                raise ValueError('Unsupported benchmark operation')
            result.update(elapsed_ns=time.perf_counter_ns() - started,
                          cpu_ns=time.process_time_ns() - cpu,
                          peak_rss_bytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss * 1024)
            print(json.dumps(dict(status=0, value=result)), flush=True)
    finally:
        try:
            if query is not None:
                await resolved(query.close())
        finally:
            await resolved(client.close())
    print(json.dumps(dict(closed=True)), flush=True)


if __name__ == '__main__':
    asyncio.run(main(*sys.argv[1:]))

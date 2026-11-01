"""Installed cohosted SQL: durable managed output, WAL wakeups and replacement."""
import ctypes
import json
import os
from pathlib import Path
import shutil
import sys
import time

from interfaces.installation.server_direct_tables import LifecycleFixture as Fixture
from interfaces.cli.table_console import records
from harness.sql_placement import Probe
from interfaces.sql_sessions.local import Client
from interfaces.sql_sessions.storage import text


def rows(fixture):
    return sorted(records(fixture.console('SELECT id FROM managed_output;\n')[-1]), key=lambda row: int(row['id']))


def observation(fixture, name="managed_projection"):
    result = records(fixture.console(f'SHOW DATAFLOW {name};\n')[-1])
    assert len(result) == 1, result
    return json.loads(result[0]['dataflow'])


def await_head(fixture, name, ready):
    # Keep one session while watching. The independent decoder verifies the
    # schema, observation and terminal count of every distinct SHOW result.
    client = Client(fixture.console_config(), fixture.record()['definition']).open()
    deadline = time.monotonic() + 180
    try:
        while True:
            batch = client.concurrent_read(f'SHOW DATAFLOW {name}')['batch']
            assert batch['complete'] and batch['completion']['rows'] == 1
            current = json.loads(text(batch['rows'][0][0]))
            client.call(dict(close_result=batch['cursor']))
            if ready(current['observation']['head']):
                return current
            assert time.monotonic() < deadline, current
            time.sleep(.1)
    finally:
        client.close()


def await_revision(fixture, revision, expected):
    def ready(head):
        assert head['blocked'] == 'none', head
        return head['revision'] >= revision and head['pending'] is None
    current = await_head(fixture, 'managed_projection', ready)
    assert rows(fixture) == [{'id': str(value)} for value in expected]
    return current


def run(cli, node, host, board, gateway):
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    os.environ['TEST_TRANSIT_BOARD_BINARY'] = str(Path(board).resolve())
    os.environ['TEST_TRANSIT_SQL_GATEWAY_BINARY'] = str(Path(gateway).resolve())
    fixture = Fixture(cli, node, host)
    success = False
    print(f'Installed managed Table proof: {fixture.root}', flush=True)
    try:
        fixture.start()
        fixture.ready(timeout=300)
        fixture.console('CREATE TABLE managed_input (id BIGINT PRIMARY KEY);\nCREATE TABLE managed_output (id BIGINT PRIMARY KEY);\nINSERT INTO managed_input (id) VALUES (1),(2),(3);\n')
        explained = records(fixture.console('EXPLAIN CREATE DATAFLOW managed_projection INTO managed_output AS SELECT id FROM managed_input;\n')[-1])
        assert json.loads(explained[0]['plan'])['executed'] is False
        fixture.console('CREATE DATAFLOW managed_projection INTO managed_output AS SELECT id FROM managed_input;\n')
        assert observation(fixture)['observation']['head']['control']['state'] == 'published'
        assert rows(fixture) == []
        fixture.console('AUTHORIZE DATAFLOW managed_projection;\nACTIVATE DATAFLOW managed_projection;\n')
        first = await_revision(fixture, 1, [1, 2, 3])
        fixture.console('INSERT INTO managed_input (id) VALUES (4);\n')
        second = await_revision(fixture, 2, [1, 2, 3, 4])
        assert second['observation']['head']['completed'] != first['observation']['head']['completed']
        fixture.console('SUSPEND DATAFLOW managed_projection;\nINSERT INTO managed_input (id) VALUES (5);\n')
        assert rows(fixture) == [{'id': str(value)} for value in [1, 2, 3, 4]]
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready(timeout=300)
        assert observation(fixture)['observation']['head']['control']['state'] == 'suspended'
        fixture.console('RESUME DATAFLOW managed_projection;\n')
        await_revision(fixture, 3, [1, 2, 3, 4, 5])
        fixture.console('DELETE FROM managed_input;\n')
        await_revision(fixture, 4, [])
        fixture.console('REFRESH DATAFLOW managed_projection;\n')
        await_revision(fixture, 5, [])
        # Inspect local request counters while making no SQL requests. A settled
        # active computation parks instead of polling its Table or Catalog.
        probe = Probe(fixture)
        time.sleep(1)
        before = probe.snapshot()
        time.sleep(1)
        assert not any(probe.delta(before).values()), 'Idle managed computation polled storage'
        fixture.console('RETIRE DATAFLOW managed_projection;\n')
        assert observation(fixture)['observation']['head']['control']['state'] == 'retired'
        fixture.console('CREATE TABLE failed_input (id BIGINT NOT NULL);\nCREATE TABLE failed_output (id BIGINT PRIMARY KEY);\nINSERT INTO failed_input (id) VALUES (1),(1);\nCREATE DATAFLOW failed_projection INTO failed_output AS SELECT id FROM failed_input;\nAUTHORIZE DATAFLOW failed_projection;\nACTIVATE DATAFLOW failed_projection;\n')
        failed = await_head(fixture, 'failed_projection', lambda head: head['blocked'] == 'execution_failed' and head['pending'] is None)['observation']['head']
        assert failed['revision'] == 0
        assert records(fixture.console('SELECT id FROM failed_output;\n')[-1]) == []
        fixture.console('RETIRE DATAFLOW failed_projection;\n')
        fixture.stop()
        success = True
        print('Installed managed Tables: SQL publication/control, verified complete and empty successors, suspend/restart/resume, refresh, idle parking and retirement passed.', flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Failed managed Table evidence retained at {fixture.root}', flush=True)


if __name__ == '__main__':
    run(*sys.argv[1:])

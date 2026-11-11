"""Installed cohosted SQL: durable managed output, WAL wakeups and replacement."""
import ctypes
import http.client
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

from interfaces.installation.server_direct_tables import LifecycleFixture as Fixture
from interfaces.installation.server_sources import settle
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


def revision(fixture, number):
    result = records(fixture.console(f'SHOW DATAFLOW managed_projection REVISION {number};\n')[-1])
    assert len(result) == 1, result
    saved = json.loads(result[0]['dataflow_revision'])
    assert saved['revision']['revision'] == number, saved
    assert saved['decision']['outcome'] == 'committed', saved
    assert saved['decision']['attempt']['transaction'] == saved['revision']['cut']['begin']['identity'], saved
    return saved


def observe(client, action, deadline):
    # Only pure observations and idempotent result closure use this helper.
    # A refused observation supplies neither completion nor a replacement ID.
    while True:
        try:
            return client.call(action)
        except AssertionError as failure:
            detail = failure.args[0] if failure.args else None
            error = detail.get('err', {}) if isinstance(detail, dict) else {}
            if error.get('code') not in ('AuthorityTimeout', 'AuthorityUnavailable', 'Conflict', 'Canceled') or error.get('operation') is not None:
                raise
            assert time.monotonic() < deadline, detail
            client.http.close()
            time.sleep(.1)


def await_head(fixture, name, ready):
    # Keep one session while watching. The independent decoder verifies the
    # schema, observation and terminal count of every distinct SHOW result.
    client = None
    deadline = time.monotonic() + 180
    try:
        while True:
            try:
                if client is None:
                    client = Client(fixture.console_config(), fixture.record()['definition']).open()
                # Each SHOW is a distinct metadata result. A replacement
                # session cannot splice batches or replay a control command.
                batch = observe(client, dict(execute=dict(sql=f'SHOW DATAFLOW {name}', token=None)), deadline)['batch']
                assert batch['complete'] and batch['completion']['rows'] == 1
                current = json.loads(text(batch['rows'][0][0]))
                observe(client, dict(close_result=batch['cursor']), deadline)
            except (OSError, http.client.HTTPException):
                assert time.monotonic() < deadline, 'Metadata transport did not recover'
                if client is not None:
                    client.http.close()
                client = None
                time.sleep(.1)
                continue
            except AssertionError as failure:
                detail = failure.args[0] if failure.args else None
                error = detail.get('err', {}) if isinstance(detail, dict) else {}
                if error.get('code') not in ('SqlSessionExpired', 'SqlInstanceChanged'):
                    raise
                assert time.monotonic() < deadline, detail
                client.http.close()
                client = None
                time.sleep(.1)
                continue
            if ready(current['observation']['head']):
                return current
            assert time.monotonic() < deadline, current
            time.sleep(.1)
    finally:
        # A canceled request can close its HTTP connection. Session cleanup
        # uses the same session identity on a fresh transport.
        if client is not None:
            client.http.close()
            failing = sys.exc_info()[0] is not None
            try:
                client.close()
            except (OSError, http.client.HTTPException):
                if not failing:
                    raise


def await_revision(fixture, revision, expected):
    def ready(head):
        assert head['blocked'] == 'none', head
        return head['revision'] >= revision and head['pending'] is None
    current = await_head(fixture, 'managed_projection', ready)
    assert rows(fixture) == [{'id': str(value)} for value in expected]
    print(f'Managed SQL: complete revision {revision} ({len(expected)} rows) verified.', flush=True)
    return current


def dataflow_command(fixture, sql):
    # The CLI may preserve an accepted identity when an observation fails.
    # Settle that exact command through the public control surface; never
    # resubmit under another token or infer success from transport loss.
    try:
        fixture.console(sql + ';\n')
        return
    except AssertionError as failure:
        result = failure.args[0] if failure.args else None
        if not isinstance(result, subprocess.CompletedProcess) or result.returncode != 1:
            raise
        try:
            unresolved = json.loads(result.stdout)['unresolved']
        except (json.JSONDecodeError, KeyError):
            raise failure
        assert unresolved['reason'] == 'unavailable', result
        identity = unresolved['operation']
        assert identity is not None and identity['kind'] == 'dataflow', result
    client = Client(fixture.console_config(), fixture.record()['definition']).open()
    deadline = time.monotonic() + 180
    try:
        assert client.instance == unresolved['instance'] and client.account == unresolved['account']
        identity = dict(identity, id=int(identity['id']))
        while True:
            observed = observe(client, dict(status=dict(operation=identity)), deadline)
            if observed is not None:
                operation = observed['operation']
                assert operation['identity'] == identity and operation['token'] == unresolved['token']
                if operation['phase'] == 'terminal':
                    assert operation['outcome'] == 'applied', operation
                    print(f'Managed SQL: original dataflow command {identity["id"]} settled.', flush=True)
                    return
            assert time.monotonic() < deadline, observed
            time.sleep(.1)
    finally:
        client.http.close()
        client.close()


def retire(fixture, name):
    dataflow_command(fixture, f'RETIRE DATAFLOW {name}')


def page_boundaries(fixture):
    # Exercise both physical page limits through installed SQL. Each
    # successor is independently verified and prior revisions stay readable.
    fixture.console('CREATE TABLE batch_input (id BIGINT PRIMARY KEY);\nCREATE TABLE batch_output (id BIGINT PRIMARY KEY);\n'
                    + 'INSERT INTO batch_input (id) VALUES ' + ','.join(f'({i})' for i in range(63)) + ';\n')
    dataflow_command(fixture, 'CREATE DATAFLOW batch_projection INTO batch_output AS SELECT id FROM batch_input')
    dataflow_command(fixture, 'AUTHORIZE DATAFLOW batch_projection')
    dataflow_command(fixture, 'ACTIVATE DATAFLOW batch_projection')
    for number, total in enumerate((63, 64, 65), 1):
        if total > 63:
            fixture.console(f'INSERT INTO batch_input (id) VALUES ({total - 1});\n')
        batch = await_head(fixture, 'batch_projection', lambda head: head['revision'] == number and head['pending'] is None)
        assert batch['observation']['head']['rows'] == total
        actual = records(fixture.console('SELECT id FROM batch_output;\n')[-1])
        assert sorted(int(row['id']) for row in actual) == list(range(total))
        print(f'Managed SQL: boundary revision {number} ({total} rows) verified.', flush=True)
    assert json.loads(records(fixture.console('SHOW DATAFLOW batch_projection REVISION 1;\n')[-1])[0]['dataflow_revision'])['revision']['rows'] == 63
    retire(fixture, 'batch_projection')
    print('Managed SQL: 63/64/65-row successors and retained revision metadata verified.', flush=True)
    byte_boundary(fixture)


def byte_boundary(fixture):
    columns = [f'body{i}' for i in range(12)]
    fixture.console('CREATE TABLE bytes_input (id BIGINT PRIMARY KEY, body UTF8 NOT NULL);\n'
                    + 'CREATE TABLE bytes_output (id BIGINT PRIMARY KEY, ' + ', '.join(f'{name} UTF8' for name in columns) + ');\n')
    # Populate through bounded SQL statements, then use the maintained
    # compiler's supported column projections. Wide output rows reach the
    # page byte budget before its 64-row budget.
    payload = 'x' * 200
    for start in range(0, 63, 10):
        values = ','.join(f"({i},'{payload}')" for i in range(start, min(start + 10, 63)))
        fixture.console(f'INSERT INTO bytes_input (id, body) VALUES {values};\n')
    projection = ', '.join(f'body AS {name}' for name in columns)
    dataflow_command(fixture, f'CREATE DATAFLOW bytes_projection INTO bytes_output AS SELECT id, {projection} FROM bytes_input')
    dataflow_command(fixture, 'AUTHORIZE DATAFLOW bytes_projection')
    dataflow_command(fixture, 'ACTIVATE DATAFLOW bytes_projection')
    await_head(fixture, 'bytes_projection', lambda head: head['revision'] == 1 and head['pending'] is None)
    actual = records(fixture.console('SELECT * FROM bytes_output;\n')[-1])
    assert sorted(int(row['id']) for row in actual) == list(range(63))
    assert all(row[name] == payload for row in actual for name in columns)
    retire(fixture, 'bytes_projection')
    print('Managed SQL: byte-boundary pages and all 63 wide output rows verified.', flush=True)


def queue_program(fixture):
    fixture.console('CREATE QUEUE program_input (id BIGINT NOT NULL);\n'
                    'CREATE TABLE program_output (id BIGINT PRIMARY KEY);\n'
                    'ENQUEUE INTO program_input VALUES (1);\n')
    source = '''CREATE DATAFLOW ordered_program FROM QUEUE program_input AS event AS BEGIN
      LET id = event.id;
      BEGIN ATOMIC
        REQUIRE id > 0 ELSE 'InvalidInput';
        INSERT INTO program_output VALUES (id) ON CONFLICT (id) DO ASSERT SAME ROW;
      END;
      LET observed = SELECT * FROM program_output WHERE id = event.id;
      REQUIRE observed.id = id ELSE 'MissingCommittedRow';
      BEGIN ATOMIC
        INSERT INTO program_output VALUES (id + 100) ON CONFLICT (id) DO ASSERT SAME ROW;
      END;
    END'''
    plan = json.loads(records(fixture.console('EXPLAIN ' + source + ';\n')[-1])[0]['plan'])
    assert plan['consumer'] == 'queue_program' and plan['executed'] is False, plan
    assert len(plan['resources']) == 2 and len(plan['uses']) == 2, plan
    publication_token = list(os.urandom(16))
    client = Client(fixture.console_config(), fixture.record()['definition']).open()
    try:
        client.call(dict(execute=dict(sql=source, token=publication_token)), discard_response=True)
        publication = settle(client, dict(token=publication_token))
        assert publication['command'] == 'create_dataflow' and publication['identity']['kind'] == 'dataflow', publication
        assert client.execute(source, token=publication_token)['operation'] == publication
        client.call(dict(execute=dict(sql=source.replace('id + 100', 'id + 200'), token=publication_token)), error='SqlTokenConflict')
    finally:
        client.close()
    published = observation(fixture, 'ordered_program')
    assert published['observation']['head']['control']['state'] == 'published', published
    assert published['observation']['head']['executor_role'] is None, published
    assert records(fixture.console('SELECT id FROM program_output;\n')[-1]) == []
    client = Client(fixture.console_config(), fixture.record()['definition']).open()
    try:
        for sql, code in (
            ('AUTHORIZE DATAFLOW ordered_program', 'InvalidDataflowTransition'),
            ('REFRESH DATAFLOW ordered_program', 'InvalidDataflowTransition'),
            ('SHOW DATAFLOW ordered_program REVISION 1', 'UnsupportedProgramRevision'),
            ('CREATE DATAFLOW ordered_program INTO managed_output AS SELECT id FROM managed_input', 'ManagedTableNameConflict'),
            ('AUTHORIZE DATAFLOW ordered_program AS ROLE PUBLIC', 'InvalidSqlRole'),
            ("CREATE DATAFLOW deadline_program FROM QUEUE program_input AS event WITH (DEADLINE = '5s') AS BEGIN REQUIRE TRUE ELSE 'Unused'; END", 'ApplicationHostUnavailable'),
            ("CREATE DATAFLOW wrong_type FROM QUEUE program_input AS event AS BEGIN REQUIRE event.id ELSE 'Unused'; END", 'ProgramTypeMismatch'),
        ):
            failure = client.call(dict(execute=dict(sql=sql, token=[37]*16)), error=code)
            assert failure['err']['operation'] is None, failure
    finally:
        client.close()
    client = Client(fixture.console_config(), fixture.record()['definition']).open()
    try:
        authorize = 'AUTHORIZE DATAFLOW ordered_program AS ROLE CURRENT_ROLE'
        token = list(os.urandom(16))
        client.call(dict(execute=dict(sql=authorize, token=token)), discard_response=True)
        authorized = settle(client, dict(token=token))
        assert authorized['command'] == 'control_dataflow', authorized
        assert client.execute(authorize, token=token)['operation'] == authorized
    finally:
        client.close()
    assert observation(fixture, 'ordered_program')['observation']['head']['control']['state'] == 'authorized'
    assert records(fixture.console('SELECT id FROM program_output;\n')[-1]) == []
    dataflow_command(fixture, 'ACTIVATE DATAFLOW ordered_program')
    first = await_head(fixture, 'ordered_program', lambda head: head['completed'] == 1)
    assert first['observation']['head']['checkpoint'] is not None, first
    assert sorted(int(row['id']) for row in records(fixture.console('SELECT id FROM program_output;\n')[-1])) == [1, 101]
    dataflow_command(fixture, 'SUSPEND DATAFLOW ordered_program')
    await_head(fixture, 'ordered_program', lambda head: head['pending'] is None)
    fixture.console('ENQUEUE INTO program_input VALUES (2);\n')
    fixture.stop(kill=True)
    fixture.start()
    fixture.ready(timeout=300)
    client = Client(fixture.console_config(), fixture.record()['definition']).open()
    try:
        assert settle(client, dict(token=publication_token)) == publication
    finally:
        client.close()
    suspended = observation(fixture, 'ordered_program')
    assert suspended['declaration'] == published['declaration']
    assert suspended['observation']['head']['completed'] == 1, suspended
    assert suspended['observation']['head']['control']['state'] == 'suspended', suspended
    dataflow_command(fixture, 'RESUME DATAFLOW ordered_program')
    await_head(fixture, 'ordered_program', lambda head: head['completed'] == 2)
    assert sorted(int(row['id']) for row in records(fixture.console('SELECT id FROM program_output;\n')[-1])) == [1, 2, 101, 102]
    retire(fixture, 'ordered_program')
    await_head(fixture, 'ordered_program', lambda head: head['retirement_complete'])
    fixture.console('ENQUEUE INTO program_input VALUES (3);\n')
    assert sorted(int(row['id']) for row in records(fixture.console('SELECT id FROM program_output;\n')[-1])) == [1, 2, 101, 102]
    print('Managed SQL: lowered Queue program, explicit executor, ordered atomic outputs, retained restart and retirement verified.', flush=True)


def run(cli, node, host, board, gateway):
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    os.environ['TEST_TRANSIT_BOARD_BINARY'] = str(Path(board).resolve())
    os.environ['TEST_TRANSIT_SQL_GATEWAY_BINARY'] = str(Path(gateway).resolve())
    fixture = Fixture(cli, node, host)
    fixture.use_private_runtime()
    # Use the installed direct-Table correctness profile that LifecycleFixture
    # expects; its CLI budget must agree with the configured server commands.
    fixture.config['sql'].update(command_ms=120000, request_timeout_ms=30000)
    fixture.path.write_text(json.dumps(fixture.config))
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
        retained_first = revision(fixture, 1)
        assert retained_first['revision']['rows'] == 3
        fixture.console('INSERT INTO managed_input (id) VALUES (4);\n')
        second = await_revision(fixture, 2, [1, 2, 3, 4])
        assert second['observation']['head']['completed'] != first['observation']['head']['completed']
        assert revision(fixture, 1) == retained_first
        retained_second = revision(fixture, 2)
        assert retained_second['revision']['rows'] == 4
        fixture.console('SUSPEND DATAFLOW managed_projection;\nINSERT INTO managed_input (id) VALUES (5);\n')
        assert rows(fixture) == [{'id': str(value)} for value in [1, 2, 3, 4]]
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready(timeout=300)
        assert observation(fixture)['observation']['head']['control']['state'] == 'suspended'
        assert revision(fixture, 1) == retained_first
        assert revision(fixture, 2) == retained_second
        fixture.console('RESUME DATAFLOW managed_projection;\n')
        await_revision(fixture, 3, [1, 2, 3, 4, 5])
        fixture.console('DELETE FROM managed_input;\n')
        await_revision(fixture, 4, [])
        assert revision(fixture, 4)['revision']['rows'] == 0
        fixture.console('REFRESH DATAFLOW managed_projection;\n')
        await_revision(fixture, 5, [])
        # Inspect local request counters while making no SQL requests. A settled
        # active computation parks instead of polling its Table or Catalog.
        probe = Probe(fixture)
        time.sleep(1)
        before = probe.snapshot()
        time.sleep(1)
        assert not any(probe.delta(before).values()), 'Idle managed computation polled storage'
        retire(fixture, 'managed_projection')
        assert observation(fixture)['observation']['head']['control']['state'] == 'retired'
        fixture.console('INSERT INTO managed_output (id) VALUES (99);\n')
        assert revision(fixture, 1) == retained_first
        assert revision(fixture, 2) == retained_second
        assert revision(fixture, 4)['revision']['rows'] == 0
        print('Managed SQL: immutable revision attribution survives successors, replacement, retirement and output edits.', flush=True)
        client = Client(fixture.console_config(), fixture.record()['definition']).open()
        try:
            for number in ('0', '-1', '18446744073709551616'):
                failure = client.call(dict(execute=dict(sql=f'SHOW DATAFLOW managed_projection REVISION {number}', token=None)), error='InvalidDataflowRevision')
                assert failure['err']['sqlstate'] == list(b'22023'), failure
            failure = client.call(dict(execute=dict(sql='SHOW DATAFLOW managed_projection REVISION 6', token=None)), error='DataflowRevisionNotFound')
            assert failure['err']['sqlstate'] == list(b'42704'), failure
        finally:
            client.close()
        page_boundaries(fixture)
        queue_program(fixture)
        fixture.console('CREATE TABLE failed_input (id BIGINT NOT NULL);\nCREATE TABLE failed_output (id BIGINT PRIMARY KEY);\nINSERT INTO failed_input (id) VALUES (1),(1);\nCREATE DATAFLOW failed_projection INTO failed_output AS SELECT id FROM failed_input;\nAUTHORIZE DATAFLOW failed_projection;\nACTIVATE DATAFLOW failed_projection;\n')
        failed = await_head(fixture, 'failed_projection', lambda head: head['blocked'] == 'execution_failed' and head['pending'] is None)['observation']['head']
        assert failed['revision'] == 0
        assert records(fixture.console('SELECT id FROM failed_output;\n')[-1]) == []
        print('Managed SQL: output constraint failure settled without a partial revision.', flush=True)
        retire(fixture, 'failed_projection')
        fixture.console('CREATE TABLE overflow_input (id BIGINT NOT NULL);\nCREATE TABLE overflow_output (total BIGINT);\nINSERT INTO overflow_input (id) VALUES (9223372036854775807),(1);\nINSERT INTO overflow_output (total) VALUES (7);\nCREATE DATAFLOW overflow_projection INTO overflow_output AS SELECT SUM(id) AS total FROM overflow_input;\nAUTHORIZE DATAFLOW overflow_projection;\nACTIVATE DATAFLOW overflow_projection;\n')
        overflow = await_head(fixture, 'overflow_projection', lambda head: head['blocked'] == 'execution_failed' and head['pending'] is None)['observation']['head']
        assert overflow['revision'] == 0
        assert records(fixture.console('SELECT total FROM overflow_output;\n')[-1]) == [{'total': '7'}]
        print('Managed SQL: checked SUM overflow settled and preserved the original output.', flush=True)
        retire(fixture, 'overflow_projection')
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

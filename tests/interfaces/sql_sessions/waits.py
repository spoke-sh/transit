"""Installed Queue WAIT keeps one original operation across timeout and replacement."""
from concurrent.futures import ThreadPoolExecutor
import json
import os
import re
import subprocess
import time

from interfaces.sql_sessions.native import Client
from interfaces.sql_sessions.storage import unsigned


def isolated(root, port, postgres, mysql_options, restart, authorize, console):
    """Focused selection of the same assertions included in sessions-log."""
    consumer = root / 'wait-console'
    consumer.mkdir()
    home = consumer / 'home'
    home.mkdir()
    password = consumer / 'password'
    password.write_text('proof-password')
    password.chmod(0o600)
    config = consumer / 'connection.yaml'
    config.write_text(f'version: 1\nendpoint: https://localhost:{port}\naccount: proof\ndatabase: data\nauthentication: scram\nca_file: {root/"certificate.pem"}\npassword_file: {password}\nformat: json\n')
    run(root, port, postgres, mysql_options, restart, authorize, console, config, consumer, home)


def run(root, port, postgres, mysql_options, restart, authorize, console, config, consumer, home):
    import psycopg
    import mysql.connector

    client = Client(root, port).open()

    def submit(sql):
        value = client.terminal(client.execute(sql, list(os.urandom(16)))['operation'])
        assert value['outcome'] == 'applied', value
        return value

    def pending(value, timeout=False):
        assert value['phase'] == 'ready' and value['outcome'] is None
        assert value['workload'] is None and value['wait'] is not None
        assert value['matched'] == value['changed'] == 0
        assert (value['wait']['timed_out'] is not None) == timeout
        return value

    def result(identity):
        batch = client.call(dict(result=identity))['batch']
        assert batch['complete'] and batch['completion']['rows'] == len(batch['rows'])
        client.call(dict(close_result=batch['cursor']))
        return batch['rows'], batch['observation'], batch['completion']

    for name in ('wait_original', 'wait_cancel', 'wait_wake', 'wait_pg', 'wait_mysql', 'wait_console'):
        submit(f'CREATE QUEUE {name} (value BIGINT NOT NULL)')
    sql = "CLAIM value, _receipt_handle FROM wait_original LIMIT 1 WITH LEASE '30s' WAIT '100ms'"
    token = list(os.urandom(16))
    original = pending(client.execute(sql, token)['operation'], timeout=True)
    identity = original['identity']
    saved = root / 'sql-wait-original.json'
    saved.write_text(json.dumps(dict(identity=identity, token=token, wait=original['wait'])))
    saved_bytes = saved.read_bytes()
    authorize(False)
    try:
        client.call(dict(status=dict(operation=identity)), error='AccessDenied')
        client.call(dict(resume=identity), error='AccessDenied')
    finally:
        authorize(True)
    submit('ENQUEUE INTO wait_original VALUES (41)')
    # Repeated status and same-token execute are observations. Even with newly
    # eligible work, neither they nor the recovery worker may acquire it.
    for _ in range(3):
        observed = pending(client.call(dict(status=dict(operation=identity)))['operation'])
        assert observed['wait']['intent'] == original['wait']['intent']
        time.sleep(.05)
    pending(client.execute(sql, token)['operation'])
    client.close()
    restart()
    client = Client(root, port).open()
    assert saved.read_bytes() == saved_bytes
    pending(client.call(dict(status=dict(operation=identity)))['operation'])
    pending(client.execute(sql, token)['operation'])
    client.call(dict(resume=identity), discard_response=True)
    accepted = client.terminal(client.call(dict(status=dict(operation=identity)))['operation'])
    assert accepted['identity'] == identity and accepted['wait'] is None and accepted['outcome'] == 'applied'
    first = result(identity)
    assert [unsigned(row[0]) for row in first[0]] == [41]
    submit('ENQUEUE INTO wait_original VALUES (42)')
    assert client.call(dict(resume=identity))['operation'] == accepted
    assert result(identity) == first
    client.call(dict(execute=dict(sql=sql.replace('100ms', '200ms'), token=token)), error='SqlTokenConflict')

    # Losing the complete timeout response cannot let background recovery make
    # an empty claim or silently begin another wait attempt.
    lost_token = list(os.urandom(16))
    lost_sql = "CLAIM value FROM wait_cancel WITH LEASE '1s' WAIT '50ms'"
    client.call(dict(execute=dict(sql=lost_sql, token=lost_token)), discard_response=True)
    lost = pending(client.call(dict(status=dict(token=lost_token)))['operation'])
    cancelled = client.terminal(client.call(dict(cancel=dict(operation=lost['identity'])))['operation'], outcomes=('cancelled',))
    assert cancelled['outcome'] == 'cancelled'
    submit('ENQUEUE INTO wait_cancel VALUES (43)')
    assert client.call(dict(resume=lost['identity']))['operation'] == cancelled
    fresh = submit("CLAIM value FROM wait_cancel WITH LEASE '1s'")
    assert [unsigned(row[0]) for row in result(fresh['identity'])[0]] == [43]

    # Separate sessions share native wakeups without monopolizing SQL control.
    waiter = Client(root, port).open()
    with ThreadPoolExecutor(max_workers=1) as pool:
        future = pool.submit(waiter.execute, "CLAIM value FROM wait_wake WITH LEASE '30s' WAIT '1s'", list(os.urandom(16)))
        time.sleep(.1)
        client.call(dict(status=dict(operation=identity)))
        submit('ENQUEUE INTO wait_wake VALUES (44)')
        wake = future.result(timeout=30)['operation']
        arrival_timed_out = wake['phase'] != 'terminal'
        if arrival_timed_out:
            pending(wake, timeout=True)
            original_wake = wake['identity']
            wake = client.terminal(client.call(dict(resume=original_wake))['operation'])
            assert wake['identity'] == original_wake
        else:
            assert wake['outcome'] == 'applied'
    waiter.close()
    assert [unsigned(row[0]) for row in result(wake['identity'])[0]] == [44]

    # Wire errors retain the original operation ID; timeout is never a CLAIM 0.
    wire_ids = []
    with psycopg.connect(**postgres) as wire:
        with wire.cursor() as cursor:
            try:
                cursor.execute("CLAIM value FROM wait_pg WITH LEASE '1s' WAIT '50ms'", prepare=True)
            except psycopg.Error as error:
                assert error.sqlstate == '57014', error
                wire_ids.append(int(re.search(r'Gateway operation (\d+)', error.diag.message_detail).group(1)))
            else:
                raise AssertionError('PostgreSQL timeout returned successful rows')
    with mysql.connector.connect(**mysql_options) as wire:
        with wire.cursor(prepared=True) as cursor:
            try:
                cursor.execute("CLAIM value FROM wait_mysql WITH LEASE '1s' WAIT '50ms'")
            except mysql.connector.Error as error:
                assert error.sqlstate == '57014', error
                wire_ids.append(int(re.search(r'Gateway operation (\d+)', error.msg).group(1)))
            else:
                raise AssertionError('MySQL timeout returned successful rows')
    for id_ in wire_ids:
        original_id = dict(account=client.account, id=id_, kind='workload')
        pending(client.call(dict(status=dict(operation=original_id)))['operation'])
        assert client.terminal(client.call(dict(cancel=dict(operation=original_id)))['operation'], outcomes=('cancelled',))['outcome'] == 'cancelled'

    script = consumer / 'wait.sql'
    script.write_text("CLAIM value FROM wait_console WITH LEASE '1s' WAIT '50ms';\n")
    rendered = subprocess.run([console, 'console', '--config', str(config), '--no-rc', '-f', str(script)],
                              cwd=consumer, env={'PATH': '/unavailable', 'HOME': str(home), 'LANG': 'C'},
                              capture_output=True, text=True, timeout=60)
    assert rendered.returncode != 0, (rendered.stdout, rendered.stderr)
    frames = [json.loads(line) for line in rendered.stdout.splitlines()]
    assert len(frames) == 1 and frames[0]['unresolved']['reason'] == 'waiting', frames
    unresolved = frames[0]['unresolved']
    assert unresolved['wait']['timed_out'] is not None
    assert client.terminal(client.call(dict(cancel=dict(operation=unresolved['operation'])))['operation'], outcomes=('cancelled',))['outcome'] == 'cancelled'
    client.close()
    print(json.dumps(dict(profile='sql_queue_wait', timeout_nonterminal=True, passive_recovery=True,
                          original_resume_after_replacement=True, original_receipt_replay=True,
                          lost_timeout_reply=True, lost_resume_reply=True, cancellation=True, current_authorization=True,
                          concurrent_arrival=True, arrival_timed_out=arrival_timed_out, postgres=True, mysql=True, console=True, passed=True)), flush=True)

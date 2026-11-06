"""Installed Stream/Queue WAIT keeps one original operation across timeout and replacement."""
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
    for kind in ('queue', 'stream'):
        workload(kind, root, port, postgres, mysql_options, restart, authorize, console, config, consumer, home)


def workload(kind, root, port, postgres, mysql_options, restart, authorize, console, config, consumer, home):
    import psycopg
    import mysql.connector

    client = Client(root, port).open()

    def submit(sql):
        value = client.terminal(client.execute(sql, list(os.urandom(16)))['operation'])
        assert value['outcome'] == 'applied', value
        return value

    def read(name, wait=None, receipt=False, limit=None):
        projection = 'value, _receipt_handle' if receipt and kind == 'queue' else 'value, _offset' if receipt else 'value'
        text = f'{"CLAIM" if kind == "queue" else "CONSUME"} {projection} FROM wait_{kind}_{name}'
        if limit is not None:
            text += f' LIMIT {limit}'
        if kind == 'queue':
            text += " WITH LEASE '30s'"
        if wait is not None:
            text += f" WAIT '{wait}'"
        return text

    def append(name, value):
        return submit(f'{"ENQUEUE" if kind == "queue" else "PRODUCE"} INTO wait_{kind}_{name} VALUES ({value})')

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

    for name in ('original', 'cancel', 'wake', 'deadline', 'pg', 'mysql', 'console'):
        submit(f'CREATE {kind.upper()} wait_{kind}_{name} (value BIGINT NOT NULL)')
    if kind == 'stream':
        # LIMIT 0 still needs a ready native frontier. It cannot manufacture an
        # accepted empty read on an empty Stream or advance a checkpoint.
        zero = pending(client.execute(read('cancel', '1ms', limit=0), list(os.urandom(16)))['operation'], timeout=True)
        closed = client.terminal(client.call(dict(cancel=dict(operation=zero['identity'])))['operation'], outcomes=('cancelled',))
        assert closed['outcome'] == 'cancelled'
    sql = read('original', '100ms', receipt=True, limit=1)
    token = list(os.urandom(16))
    original = pending(client.execute(sql, token)['operation'], timeout=True)
    identity = original['identity']
    saved = root / f'sql-{kind}-wait-original.json'
    saved.write_text(json.dumps(dict(identity=identity, token=token, wait=original['wait'])))
    saved_bytes = saved.read_bytes()
    authorize(False)
    try:
        client.call(dict(status=dict(operation=identity)), error='AccessDenied')
        client.call(dict(resume=identity), error='AccessDenied')
    finally:
        authorize(True)
    append('original', 41)
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
    append('original', 42)
    assert client.call(dict(resume=identity))['operation'] == accepted
    assert result(identity) == first
    client.call(dict(execute=dict(sql=sql.replace('100ms', '200ms'), token=token)), error='SqlTokenConflict')

    # Losing the complete timeout response cannot let background recovery make
    # an empty result or silently begin another wait attempt.
    lost_token = list(os.urandom(16))
    lost_sql = read('cancel', '50ms')
    client.call(dict(execute=dict(sql=lost_sql, token=lost_token)), discard_response=True)
    lost = pending(client.call(dict(status=dict(token=lost_token)))['operation'])
    cancelled = client.terminal(client.call(dict(cancel=dict(operation=lost['identity'])))['operation'], outcomes=('cancelled',))
    assert cancelled['outcome'] == 'cancelled'
    append('cancel', 43)
    assert client.call(dict(resume=lost['identity']))['operation'] == cancelled
    fresh = submit(read('cancel'))
    assert [unsigned(row[0]) for row in result(fresh['identity'])[0]] == [43]

    # The original durable wait is longer than a later foreground command.
    # Expiring resume must release its foreground borrower without manufacturing
    # a native timeout cut. Control observes the same identity independently.
    deadline_sql = read('deadline', '1s', receipt=True)
    deadline_token = list(os.urandom(16))
    deadline_original = pending(client.execute(deadline_sql, deadline_token)['operation'], timeout=True)
    deadline_id = deadline_original['identity']
    limited = Client(root, port).open()
    limited.execute("SET query.statement_timeout = '500ms'")
    with ThreadPoolExecutor(max_workers=1) as pool:
        future = pool.submit(limited.call, dict(resume=deadline_id), error=('AuthorityTimeout', 'GatewayDeadline'))
        observed = pending(client.call(dict(status=dict(operation=deadline_id)))['operation'])
        assert observed['wait']['milliseconds'] == 1000
        failure = future.result(timeout=30)['err']
        assert failure['sqlstate'] == list(b'57014'), failure
    # A legitimate subsequent command gets a fresh scope on this same session.
    limited.execute('RESET query.statement_timeout')
    limited.close()
    pending(client.call(dict(status=dict(token=deadline_token)))['operation'])
    append('deadline', 45)
    deadline_observed = client.execute(deadline_sql, deadline_token)['operation']
    assert deadline_observed['identity'] == deadline_id
    # This fixture has a remote authority hop. An already dispatched native
    # attempt can still accept the arrival after the caller's wait ends. Resolve
    # that original outcome; only an explicit resume may start another attempt.
    if deadline_observed['phase'] != 'terminal':
        pending(deadline_observed)
        deadline_observed = client.call(dict(resume=deadline_id))['operation']
    deadline_accepted = client.terminal(deadline_observed)
    assert deadline_accepted['identity'] == deadline_id
    deadline_rows = result(deadline_id)
    assert [unsigned(row[0]) for row in deadline_rows[0]] == [45]
    append('deadline', 46)
    assert client.call(dict(resume=deadline_id))['operation'] == deadline_accepted
    assert result(deadline_id) == deadline_rows

    # Separate sessions share native wakeups without monopolizing SQL control.
    waiter = Client(root, port).open()
    with ThreadPoolExecutor(max_workers=1) as pool:
        future = pool.submit(waiter.execute, read('wake', '1s'), list(os.urandom(16)))
        time.sleep(.1)
        client.call(dict(status=dict(operation=identity)))
        append('wake', 44)
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

    # Wire errors retain the original operation ID; timeout never returns successful empty rows.
    wire_ids = []
    with psycopg.connect(**postgres) as wire:
        with wire.cursor() as cursor:
            try:
                cursor.execute(read('pg', '50ms'), prepare=True)
            except psycopg.Error as error:
                assert error.sqlstate == '57014', error
                wire_ids.append(int(re.search(r'Gateway operation (\d+)', error.diag.message_detail).group(1)))
            else:
                raise AssertionError('PostgreSQL timeout returned successful rows')
    with mysql.connector.connect(**mysql_options) as wire:
        with wire.cursor(prepared=True) as cursor:
            try:
                cursor.execute(read('mysql', '50ms'))
            except mysql.connector.Error as error:
                assert error.errno == 1317 and error.sqlstate == '70100', error
                wire_ids.append(int(re.search(r'Gateway operation (\d+)', error.msg).group(1)))
            else:
                raise AssertionError('MySQL timeout returned successful rows')
    for id_ in wire_ids:
        original_id = dict(account=client.account, id=id_, kind='workload')
        pending(client.call(dict(status=dict(operation=original_id)))['operation'])
        assert client.terminal(client.call(dict(cancel=dict(operation=original_id)))['operation'], outcomes=('cancelled',))['outcome'] == 'cancelled'

    script = consumer / 'wait.sql'
    script.write_text(read('console', '50ms') + ';\n')
    rendered = subprocess.run([console, 'console', '--config', str(config), '--no-rc', '-f', str(script)],
                              cwd=consumer, env={'PATH': '/unavailable', 'HOME': str(home), 'LANG': 'C'},
                              capture_output=True, text=True, timeout=60)
    assert rendered.returncode != 0, (rendered.stdout, rendered.stderr)
    frames = [json.loads(line) for line in rendered.stdout.splitlines()]
    assert len(frames) == 1 and frames[0]['unresolved']['reason'] == 'waiting', frames
    unresolved = frames[0]['unresolved']
    assert unresolved['wait']['timed_out'] is not None
    assert unresolved['account'] == client.account and unresolved['instance'] == client.instance
    # Console presentation preserves wide integers as decimal strings; native
    # requests use integer carriage. Verify token recovery names that same ID.
    console_identity = dict(unresolved['operation'], id=int(unresolved['operation']['id']))
    recovered = pending(client.call(dict(status=dict(token=unresolved['token'])))['operation'])
    assert recovered['identity'] == console_identity
    assert client.terminal(client.call(dict(cancel=dict(operation=console_identity)))['operation'], outcomes=('cancelled',))['outcome'] == 'cancelled'
    client.close()
    print(json.dumps(dict(profile=f'sql_{kind}_wait', timeout_nonterminal=True, passive_recovery=True,
                          original_resume_after_replacement=True, original_receipt_replay=True,
                          lost_timeout_reply=True, lost_resume_reply=True, cancellation=True, current_authorization=True,
                          concurrent_arrival=True, arrival_timed_out=arrival_timed_out, inherited_deadline=True,
                          deadline_session_reused=True, deadline_original_receipt=True,
                          postgres=True, mysql=True, console=True, passed=True)), flush=True)

"""Installed positional consumption: frozen cuts, logical limits and disclosure."""
import json
import os
import struct
import subprocess

from interfaces.sql_sessions.native import Client
from interfaces.sql_sessions.storage import unsigned


def run(root, port, postgres, mysql_options, restart, authorize, console, config, consumer, home):
    from query.logical.fuze_types import descriptor
    import psycopg
    import mysql.connector

    client = Client(root, port).open()

    def submit(sql, token=None, **kwargs):
        result = client.terminal(client.execute(sql, token or list(os.urandom(16)), **kwargs)['operation'])
        assert result['outcome'] == 'applied', result
        return result

    def rows(identity):
        batch = client.call(dict(result=identity))['batch']
        observation, values, sizes = batch['observation'], [], []
        while True:
            assert client.call(dict(fetch=dict(cursor=batch['cursor'], batch=batch['batch'])))['batch'] == batch
            assert batch['observation'] == observation
            values.extend(batch['rows'])
            sizes.append(len(batch['rows']))
            if batch['complete']:
                completion = batch['completion']
                assert completion['rows'] == len(values), completion
                break
            batch = client.call(dict(fetch=dict(cursor=batch['cursor'], batch=batch['batch'] + 1)))['batch']
        client.call(dict(close_result=batch['cursor']))
        return values, sizes, observation, completion

    submit('CREATE STREAM consume_events (value BIGINT NOT NULL) WITH (read_rows=16)')
    submit('PRODUCE INTO consume_events VALUES ' + ','.join(f'({i})' for i in range(65)))
    for sql, error in (
        ('CONSUME value FROM consume_events', 'SqlAdmissionTokenRequired'),
        ('CONSUME value FROM append_manual', 'LogPartitionRequired'),
        ("CONSUME value FROM consume_events GROUP 'workers'", 'UnsupportedConstruct'),
        ("CONSUME value FROM consume_events WAIT '1s'", 'UnsupportedConstruct'),
    ):
        token = None if error == 'SqlAdmissionTokenRequired' else list(os.urandom(16))
        client.call(dict(execute=dict(sql=sql, token=token)), error=error)

    sql = 'CONSUME value, _offset FROM consume_events WHERE _offset >= 2 AND value >= 5 LIMIT 3'
    original = dict(definition=client.definition, sql=sql, token=list(os.urandom(16)))
    saved = root / 'sql-consume-original.json'
    saved.write_text(json.dumps(original))
    operation = submit(sql, original['token'])
    assert operation['command'] == 'consume' and operation['result_kind'] == 'rows'
    assert operation['matched'] is None and operation['changed'] is None
    original['identity'] = operation['identity']
    saved.write_text(json.dumps(original))
    original_bytes = saved.read_bytes()
    result = rows(original['identity'])
    values, sizes, observation, completion = result
    assert [list(map(unsigned, row)) for row in values] == [[i, i] for i in range(5, 8)]
    assert sizes == [3] and observation['workload']['limit'] == 3
    coverage = completion['workload']['position']['consume']['coverage']
    assert {key: coverage[key] for key in ('from', 'until', 'through', 'rows', 'complete')} == dict(
        **{'from': 2}, until=65, through=8, rows=6, complete=False), coverage

    all_rows = rows(submit('CONSUME value FROM consume_events')['identity'])
    assert [unsigned(row[0]) for row in all_rows[0]] == list(range(65))
    assert all_rows[1] == [32, 32, 1]
    assert all_rows[3]['workload']['position']['consume']['coverage']['complete']
    for limit, start, expected in ((0, 2, []), (9, 63, [63, 64]), (1, 65, [])):
        delivered = rows(submit(f'CONSUME value FROM consume_events WHERE _offset >= {start} LIMIT {limit}')['identity'])
        assert [unsigned(row[0]) for row in delivered[0]] == expected
        coverage = delivered[3]['workload']['position']['consume']['coverage']
        assert coverage['through'] == (start if limit == 0 else 65)
        assert coverage['complete'] == (limit != 0)

    # A new append and replacement must not enlarge or rebind accepted reads.
    submit('PRODUCE INTO consume_events VALUES (65)')
    client.close()
    restart()
    client = Client(root, port).open()
    assert saved.read_bytes() == original_bytes and original['definition'] == client.definition
    recovered = client.terminal(client.call(dict(status=dict(operation=original['identity'])))['operation'])
    assert recovered == operation
    assert submit(original['sql'], original['token']) == operation
    assert rows(original['identity']) == result
    client.call(dict(execute=dict(sql=original['sql'] + ' ', token=original['token'])), error='SqlTokenConflict')

    kind = descriptor('uint64')
    def parameter(value):
        return (b'FVL1' + struct.pack('<H', len(kind)) + kind + b'\x01\x03' + struct.pack('<Q', value)).hex()
    typed = 'CONSUME value FROM consume_events WHERE _offset >= $1 LIMIT $2'
    described = client.call(dict(prepare=dict(sql=typed)))['described']
    assert described['mutation'] and described['schema'] is not None
    assert described['parameters'] == [kind.hex(), kind.hex()]
    typed_rows = rows(submit(typed, parameters=[parameter(64), parameter(2)])['identity'])
    assert [unsigned(row[0]) for row in typed_rows[0]] == [64, 65]
    client.call(dict(release=described['statement']))

    for identity in (original['identity'], submit('CONSUME value FROM consume_events LIMIT 0')['identity']):
        batch = client.call(dict(result=identity))['batch']
        authorize(False)
        try:
            client.call(dict(fetch=dict(cursor=batch['cursor'], batch=0)), error='AccessDenied')
        finally:
            authorize(True)
        client.call(dict(fetch=dict(cursor=batch['cursor'], batch=0)), error='SqlResultIncomplete')
    client.close()

    with psycopg.connect(**postgres) as wire:
        with wire.cursor() as cursor:
            cursor.execute('CONSUME value, _offset FROM consume_events WHERE _offset >= %s LIMIT %s', (63, 2), prepare=True)
            assert cursor.fetchall() == [(63, 63), (64, 64)]
            assert cursor.statusmessage == 'CONSUME 2'
            cursor.execute('CONSUME value FROM consume_events LIMIT 0')
            assert cursor.fetchall() == [] and cursor.statusmessage == 'CONSUME 0'
    with mysql.connector.connect(**mysql_options) as wire:
        with wire.cursor(prepared=True) as cursor:
            cursor.execute('CONSUME value FROM consume_events WHERE _offset >= %s LIMIT %s', (64, 2))
            assert cursor.fetchall() == [(64,), (65,)]
        with wire.cursor() as cursor:
            cursor.execute('CONSUME value FROM consume_events LIMIT 0')
            assert cursor.fetchall() == []
    script = consumer / 'consumes.sql'
    script.write_text('CONSUME value FROM consume_events WHERE _offset >= 64 LIMIT 1;\nCONSUME value FROM consume_events LIMIT 0;\n')
    rendered = subprocess.run([console, 'console', '--config', str(config), '--no-rc', '-f', str(script)],
                              cwd=consumer, env={'PATH': '/unavailable', 'HOME': str(home), 'LANG': 'C'},
                              capture_output=True, text=True, timeout=180)
    assert rendered.returncode == 0, (rendered.stdout, rendered.stderr)
    assert rendered.stdout.count('"complete_coverage":true') == 2, rendered.stdout
    print(json.dumps(dict(profile='sql_positional_consumes', native=True, postgres=True, mysql=True, console=True,
                          original_cut_after_append_and_replacement=True, result_batches=all_rows[1],
                          filtered_partial_coverage=True, zero_limit=True, exhausted_before_limit=True,
                          typed_parameters=True, current_disclosure_authorization=True, passed=True)), flush=True)

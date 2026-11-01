"""Installed SQL claims retain original leases and never filter acquired rows."""
import json
import os
import struct
import subprocess
import time

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

    submit('CREATE QUEUE claim_work (value BIGINT NOT NULL) WITH (claim_rows=65, active_leases=128, read_rows=16)')
    submit('ENQUEUE INTO claim_work VALUES ' + ','.join(f'({i})' for i in range(65)))
    submit('CREATE QUEUE claim_manual (value BIGINT NOT NULL) PARTITIONS 2')
    submit('ENQUEUE INTO claim_manual VALUES (19) PARTITION 1')
    for sql, error in (
        ("CLAIM value FROM claim_work WITH LEASE '1s'", 'SqlAdmissionTokenRequired'),
        ("CLAIM value FROM claim_manual WITH LEASE '1s'", 'LogPartitionRequired'),
        ("CLAIM value FROM claim_work WHERE value = 7 WITH LEASE '1s'", 'UnsupportedConstruct'),
        ("CLAIM value FROM claim_work WHERE _offset >= 7 WITH LEASE '1s'", 'UnsupportedConstruct'),
        ("CLAIM value FROM claim_work WITH LEASE '1s' WAIT '1s'", 'UnsupportedConstruct'),
        ("CLAIM value FROM claim_work LIMIT 66 WITH LEASE '1s'", 'QueueClaimLimitExceeded'),
        ("CLAIM value FROM claim_work WITH LEASE '31s'", 'InvalidQueueLeaseDuration'),
    ):
        token = None if error == 'SqlAdmissionTokenRequired' else list(os.urandom(16))
        client.call(dict(execute=dict(sql=sql, token=token)), error=error)

    sql = "CLAIM value, _partition, _offset, _lease_epoch, _attempt FROM claim_work LIMIT 65 WITH LEASE '1s'"
    original = dict(definition=client.definition, sql=sql, token=list(os.urandom(16)))
    saved = root / 'sql-claim-original.json'
    saved.write_text(json.dumps(original))
    operation = submit(sql, original['token'])
    assert operation['command'] == 'claim' and operation['result_kind'] == 'rows'
    assert operation['matched'] == operation['changed'] == 0, operation
    original['identity'] = operation['identity']
    saved.write_text(json.dumps(original))
    original_bytes = saved.read_bytes()
    result = rows(original['identity'])
    values, sizes, observation, completion = result
    assert [list(map(unsigned, row)) for row in values] == [[i, 0, i, 1, 1] for i in range(65)]
    assert sizes == [32, 32, 1] and observation['data']['workload']['limit'] is None
    receipt = observation['data']['workload']['selection']['claim']
    assert receipt['rows'] == 65 and receipt['claim']['maximum'] == 65
    # Wait only if the original receipt's actual deadline has not yet elapsed.
    # The separately qualified native owner proves authoritative expiry/fencing.
    time.sleep(max(0, (receipt['expires_ms'] - time.time() * 1000) / 1000) + .02)
    assert time.time() * 1000 > receipt['expires_ms']
    submit('ENQUEUE INTO claim_work VALUES (65)')
    client.close()
    restart()
    client = Client(root, port).open()
    assert saved.read_bytes() == original_bytes and client.definition == original['definition']
    assert client.terminal(client.call(dict(status=dict(operation=original['identity'])))['operation']) == operation
    assert submit(original['sql'], original['token']) == operation
    assert rows(original['identity']) == result
    client.call(dict(execute=dict(sql=sql + ' ', token=original['token'])), error='SqlTokenConflict')

    uint = descriptor('uint64')
    text = descriptor('utf8')

    def parameter(kind, value):
        body = b'\x03' + struct.pack('<Q', value) if kind == uint else b'\x03' + struct.pack('<I', len(value)) + value.encode()
        return (b'FVL1' + struct.pack('<H', len(kind)) + kind + b'\x01' + body).hex()

    typed = 'CLAIM value, _partition, _offset FROM claim_manual WHERE _partition = $1 LIMIT $2 WITH LEASE $3'
    described = client.call(dict(prepare=dict(sql=typed)))['described']
    assert described['mutation'] and described['schema'] is not None
    assert described['parameters'] == [uint.hex(), uint.hex(), text.hex()]
    routed = rows(submit(typed, parameters=[parameter(uint, 1), parameter(uint, 1), parameter(text, '30s')])['identity'])
    assert [list(map(unsigned, row)) for row in routed[0]] == [[19, 1, 0]]
    client.call(dict(release=described['statement']))
    empty = submit("CLAIM value FROM claim_manual WHERE _partition = 0 WITH LEASE '1s'")['identity']
    empty_rows = rows(empty)
    assert empty_rows[0] == [] and empty_rows[1] == [0]
    assert empty_rows[2]['data']['workload']['selection']['claim']['rows'] == 0
    for identity in (original['identity'], empty):
        batch = client.call(dict(result=identity))['batch']
        authorize(False)
        try:
            client.call(dict(fetch=dict(cursor=batch['cursor'], batch=0)), error='AccessDenied')
        finally:
            authorize(True)
        client.call(dict(fetch=dict(cursor=batch['cursor'], batch=0)), error='SqlResultIncomplete')

    for name in ('claim_pg', 'claim_mysql', 'claim_console'):
        submit(f'CREATE QUEUE {name} (value BIGINT NOT NULL)')
        submit(f'ENQUEUE INTO {name} VALUES (7), (8)')
    client.close()
    with psycopg.connect(**postgres) as wire:
        with wire.cursor() as cursor:
            cursor.execute('CLAIM value, _offset FROM claim_pg LIMIT %s WITH LEASE %s', (2, '30s'), prepare=True)
            assert cursor.fetchall() == [(7, 0), (8, 1)]
            assert cursor.statusmessage == 'CLAIM 2'
            cursor.execute("CLAIM value FROM claim_pg WITH LEASE '30s'")
            assert cursor.fetchall() == [] and cursor.statusmessage == 'CLAIM 0'
    with mysql.connector.connect(**mysql_options) as wire:
        with wire.cursor(prepared=True) as cursor:
            cursor.execute('CLAIM value FROM claim_mysql LIMIT %s WITH LEASE %s', (2, '30s'))
            assert cursor.fetchall() == [(7,), (8,)]
        with wire.cursor() as cursor:
            cursor.execute("CLAIM value FROM claim_mysql WITH LEASE '30s'")
            assert cursor.fetchall() == []
    script = consumer / 'claims.sql'
    script.write_text("CLAIM value FROM claim_console LIMIT 2 WITH LEASE '30s';\nCLAIM value FROM claim_console WITH LEASE '30s';\n")
    rendered = subprocess.run([console, 'console', '--config', str(config), '--no-rc', '-f', str(script)],
                              cwd=consumer, env={'PATH': '/unavailable', 'HOME': str(home), 'LANG': 'C'},
                              capture_output=True, text=True, timeout=180)
    assert rendered.returncode == 0, (rendered.stdout, rendered.stderr)
    assert rendered.stdout.count('"complete_coverage":true') == 2, rendered.stdout
    print(json.dumps(dict(profile='sql_queue_claims', native=True, postgres=True, mysql=True, console=True,
                          original_selection_after_append_expiry_and_replacement=True, result_batches=sizes,
                          typed_parameters=True, empty_claim=True, current_disclosure_authorization=True,
                          no_repeat_acquisition=True, passed=True)), flush=True)

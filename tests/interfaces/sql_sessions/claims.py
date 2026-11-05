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
        ("CLAIM value FROM claim_work WITH LEASE '1s' WAIT '1001ms'", 'InvalidQueueWait'),
        ("CLAIM value FROM claim_work LIMIT 66 WITH LEASE '1s'", 'QueueClaimLimitExceeded'),
        ("CLAIM value FROM claim_work WITH LEASE '31s'", 'InvalidQueueLeaseDuration'),
    ):
        token = None if error == 'SqlAdmissionTokenRequired' else list(os.urandom(16))
        client.call(dict(execute=dict(sql=sql, token=token)), error=error)

    sql = "CLAIM value, _partition, _offset, _lease_epoch, _attempt, _receipt_handle FROM claim_work LIMIT 65 WITH LEASE '1s'"
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
    assert [list(map(unsigned, row[:5])) for row in values] == [[i, 0, i, 1, 1] for i in range(65)]
    assert sizes == [32, 32, 1] and observation['data']['workload']['limit'] is None
    receipt = observation['data']['workload']['selection']['claim']
    assert receipt['rows'] == 65 and receipt['claim']['maximum'] == 65

    def handle(cell):
        data = bytes.fromhex(cell)
        assert data[0] == 3 and struct.unpack('<I', data[1:5])[0] == 168 and len(data) == 173
        value = data[5:]
        assert value[:4] == b'QLH1' and value[4:36].hex() == client.definition
        return value

    for i, row in enumerate(values):
        raw = handle(row[5])
        assert struct.unpack('<4Q', raw[136:]) == (i, 1, 1, receipt['expires_ms'])
        assert struct.unpack('<2Q', raw[120:136]) == (receipt['claim']['operation']['principal'], receipt['claim']['operation']['operation'])
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

    # ACK freezes an exact descriptor independently of the result cursor and
    # can settle an older lease after a compatible declaration change.
    binary = descriptor('binary')
    submit('CREATE QUEUE ack_work (value BIGINT NOT NULL)')
    submit('ENQUEUE INTO ack_work VALUES (21)')
    acquired = submit("CLAIM value, _receipt_handle FROM ack_work WITH LEASE '30s'")
    acquired_rows = rows(acquired['identity'])
    raw = handle(acquired_rows[0][0][1])
    submit('ALTER QUEUE ack_work SET (read_rows=8)')
    ack_sql = 'ACK ON QUEUE ack_work RECEIPT $1'
    described_ack = client.call(dict(prepare=dict(sql=ack_sql)))['described']
    assert described_ack['mutation'] and described_ack['schema'] is None
    assert described_ack['parameters'] == [binary.hex()]
    encoded = (b'FVL1' + struct.pack('<H', len(binary)) + binary + b'\x01\x03' + struct.pack('<I', len(raw)) + raw).hex()
    ack_saved = dict(definition=client.definition, sql=ack_sql, token=list(os.urandom(16)), parameters=[encoded])
    ack_path = root / 'sql-ack-original.json'
    ack_path.write_text(json.dumps(ack_saved))
    acknowledged = submit(ack_sql, ack_saved['token'], parameters=ack_saved['parameters'])
    assert acknowledged['command'] == 'ack' and acknowledged['result_kind'] == 'command'
    assert acknowledged['matched'] == acknowledged['changed'] == 0
    settlement = acknowledged['workload']['receipt']['settle']['settlement']
    assert settlement['action'] == {'ack': {}} and settlement['lease']['offset'] == 0
    assert settlement['lease']['target']['interpretation']['revision'] == 1
    assert settlement['lease']['epoch'] == 1 and settlement['lease']['expires_ms'] == struct.unpack('<Q', raw[160:])[0]
    ack_saved['identity'] = acknowledged['identity']
    ack_path.write_text(json.dumps(ack_saved))
    ack_bytes = ack_path.read_bytes()
    assert rows(acquired['identity']) == acquired_rows
    # A new settlement identity cannot reuse an already ACKed lease. Await the
    # expected refusal without passing through the helper's success assertion.
    duplicate = client.terminal(client.execute(ack_sql, list(os.urandom(16)), parameters=[encoded])['operation'],
                                outcomes=('rejected',))
    assert duplicate['outcome'] == 'rejected' and duplicate['workload']['receipt']['closed']['reason'] == {'refused': 'lease_fenced'}
    authorize(False)
    try:
        client.call(dict(status=dict(operation=acknowledged['identity'])), error='AccessDenied')
    finally:
        authorize(True)
    client.call(dict(release=described_ack['statement']))
    submit('DROP QUEUE ack_work')
    client.close()
    restart()
    client = Client(root, port).open()
    assert ack_path.read_bytes() == ack_bytes
    assert client.terminal(client.call(dict(status=dict(operation=ack_saved['identity'])))['operation']) == acknowledged
    assert submit(ack_saved['sql'], ack_saved['token'], parameters=ack_saved['parameters']) == acknowledged
    client.call(dict(execute=dict(sql=ack_saved['sql'] + ' ', token=ack_saved['token'], parameters=ack_saved['parameters'])), error='SqlTokenConflict')

    # NACK retains the original lease and absolute scheduling request. A delayed
    # FIFO head continues to block its key while unrelated keys can progress.
    submit("CREATE QUEUE nack_work (entity BIGINT NOT NULL, value BIGINT NOT NULL) WITH (mode='key_fifo', key_column='entity')")
    submit('ENQUEUE INTO nack_work VALUES (1, 41), (1, 42), (2, 43)')
    acquired = submit("CLAIM value, _receipt_handle FROM nack_work LIMIT 1 WITH LEASE '30s'")
    nack_rows = rows(acquired['identity'])
    assert unsigned(nack_rows[0][0][0]) == 41
    raw = handle(nack_rows[0][0][1])
    encoded = (b'FVL1' + struct.pack('<H', len(binary)) + binary + b'\x01\x03' + struct.pack('<I', len(raw)) + raw).hex()
    timestamp = descriptor('timestamp', b'\x01')
    visible_ms = 4102444800000  # 2100-01-01 UTC: deliberately ineligible work.
    visibility = (b'FVL1' + struct.pack('<H', len(timestamp)) + timestamp + b'\x01\x03' + struct.pack('<q', visible_ms * 1000)).hex()
    submit('ALTER QUEUE nack_work SET (read_rows=8)')
    nack_sql = 'NACK ON QUEUE nack_work RECEIPT $1 WITH (visible_at = $2)'
    described_nack = client.call(dict(prepare=dict(sql=nack_sql)))['described']
    assert described_nack['mutation'] and described_nack['schema'] is None
    assert described_nack['parameters'] == [binary.hex(), timestamp.hex()]
    client.call(dict(execute=dict(sql=nack_sql, parameters=[encoded, visibility])), error='SqlAdmissionTokenRequired')
    nack_saved = dict(definition=client.definition, sql=nack_sql, token=list(os.urandom(16)), parameters=[encoded, visibility])
    nack_path = root / 'sql-nack-original.json'
    nack_path.write_text(json.dumps(nack_saved))
    client.call(dict(execute=dict(sql=nack_sql, token=nack_saved['token'], parameters=nack_saved['parameters'])), discard_response=True)
    client.close()
    restart()
    client = Client(root, port).open()
    requeued = submit(nack_sql, nack_saved['token'], parameters=nack_saved['parameters'])
    assert requeued['command'] == 'nack' and requeued['result_kind'] == 'command'
    assert requeued['matched'] == requeued['changed'] == 0
    settlement = requeued['workload']['receipt']['settle']['settlement']
    assert settlement['action'] == {'nack': {'visible_ms': visible_ms}}
    assert settlement['lease']['target']['interpretation']['revision'] == 1
    assert settlement['lease']['offset'] == 0 and settlement['lease']['epoch'] == 1
    assert settlement['lease']['expires_ms'] == struct.unpack('<Q', raw[160:])[0]
    nack_saved['identity'] = requeued['identity']
    nack_path.write_text(json.dumps(nack_saved))
    nack_bytes = nack_path.read_bytes()
    assert rows(acquired['identity']) == nack_rows
    independent = rows(submit("CLAIM value, _offset FROM nack_work WITH LEASE '30s'")['identity'])
    assert [list(map(unsigned, row)) for row in independent[0]] == [[43, 2]]
    assert rows(submit("CLAIM value FROM nack_work WITH LEASE '30s'")['identity'])[0] == []
    # A fresh settlement cannot reuse the NACKed lease, even with no requested
    # delay. Original token recovery must keep its accepted absolute timestamp.
    stale = client.terminal(client.execute('NACK ON QUEUE nack_work RECEIPT $1', list(os.urandom(16)), parameters=[encoded])['operation'], outcomes=('rejected',))
    assert stale['workload']['receipt']['closed']['reason'] == {'refused': 'lease_fenced'}
    changed_visibility = (b'FVL1' + struct.pack('<H', len(timestamp)) + timestamp + b'\x01\x03' + struct.pack('<q', 0)).hex()
    client.call(dict(execute=dict(sql=nack_sql, token=nack_saved['token'], parameters=[encoded, changed_visibility])), error='SqlTokenConflict')
    authorize(False)
    try:
        client.call(dict(status=dict(operation=requeued['identity'])), error='AccessDenied')
        client.call(dict(execute=dict(sql=nack_sql, token=nack_saved['token'], parameters=nack_saved['parameters'])), error='AccessDenied')
    finally:
        authorize(True)
    submit('DROP QUEUE nack_work')
    client.close()
    restart()
    client = Client(root, port).open()
    assert nack_path.read_bytes() == nack_bytes
    assert client.terminal(client.call(dict(status=dict(operation=nack_saved['identity'])))['operation']) == requeued
    assert submit(nack_saved['sql'], nack_saved['token'], parameters=nack_saved['parameters']) == requeued

    # Renewal is one retained result from the original settlement, not a new
    # claim or a read of whichever lease happens to be current at delivery.
    submit("CREATE QUEUE renew_work (value BIGINT NOT NULL) WITH (max_lease_duration='5m')")
    submit('ENQUEUE INTO renew_work VALUES (51)')
    acquired = submit("CLAIM _receipt_handle FROM renew_work WITH LEASE '2m'")
    old = handle(rows(acquired['identity'])[0][0][0])

    def receipt_parameter(raw):
        return (b'FVL1' + struct.pack('<H', len(binary)) + binary + b'\x01\x03' + struct.pack('<I', len(raw)) + raw).hex()

    submit('ALTER QUEUE renew_work SET (read_rows=8)')
    renew_sql = 'EXTEND LEASE ON QUEUE renew_work RECEIPT $1 BY $2'
    described = client.call(dict(prepare=dict(sql=renew_sql)))['described']
    assert described['mutation'] and described['schema'] is not None
    assert described['parameters'] == [binary.hex(), text.hex()]
    renew_saved = dict(definition=client.definition, sql=renew_sql, token=list(os.urandom(16)),
                       parameters=[receipt_parameter(old), parameter(text, '30s')])
    renew_path = root / 'sql-renewal-original.json'
    renew_path.write_text(json.dumps(renew_saved))
    client.call(dict(execute=dict(sql=renew_sql, parameters=renew_saved['parameters'])), error='SqlAdmissionTokenRequired')
    client.call(dict(execute=dict(sql=renew_sql, token=renew_saved['token'], parameters=renew_saved['parameters'])), discard_response=True)
    client.close()
    restart()
    client = Client(root, port).open()
    extended = submit(renew_sql, renew_saved['token'], parameters=renew_saved['parameters'])
    assert extended['command'] == 'extend_lease' and extended['result_kind'] == 'rows'
    assert extended['matched'] == extended['changed'] == 0
    renewal = rows(extended['identity'])
    assert renewal[1] == [1] and len(renewal[0][0]) == 1
    renewed = handle(renewal[0][0][0])
    assert renewed[:160] == old[:160]
    assert struct.unpack('<Q', renewed[160:])[0] == struct.unpack('<Q', old[160:])[0] + 30000
    selection = renewal[2]['data']['workload']['selection']['renewal']
    assert selection == extended['workload']['receipt']['settle']
    assert selection['settlement']['lease']['target']['interpretation']['revision'] == 1
    renew_saved['identity'] = extended['identity']
    renew_path.write_text(json.dumps(renew_saved))
    renew_bytes = renew_path.read_bytes()
    batch = client.call(dict(result=extended['identity']))['batch']
    client.call(dict(fetch=dict(cursor=batch['cursor'], batch=0)), discard_response=True)
    assert client.call(dict(fetch=dict(cursor=batch['cursor'], batch=0)))['batch'] == batch
    client.call(dict(close_result=batch['cursor']))
    # Only the returned expiry-bearing handle can authorize new settlements.
    for sql in ('ACK ON QUEUE renew_work RECEIPT $1', 'NACK ON QUEUE renew_work RECEIPT $1',
                "EXTEND LEASE ON QUEUE renew_work RECEIPT $1 BY '1s'"):
        refused = client.terminal(client.execute(sql, list(os.urandom(16)), parameters=[receipt_parameter(old)])['operation'], outcomes=('rejected',))
        assert refused['workload']['receipt']['closed']['reason'] == {'refused': 'lease_fenced'}
    later = submit(renew_sql, parameters=[receipt_parameter(renewed), parameter(text, '30s')])
    latest = handle(rows(later['identity'])[0][0][0])
    assert rows(extended['identity']) == renewal
    submit('ACK ON QUEUE renew_work RECEIPT $1', parameters=[receipt_parameter(latest)])
    assert rows(extended['identity']) == renewal
    client.call(dict(execute=dict(sql=renew_sql, token=renew_saved['token'], parameters=[receipt_parameter(old), parameter(text, '1s')])), error='SqlTokenConflict')
    batch = client.call(dict(result=extended['identity']))['batch']
    authorize(False)
    try:
        client.call(dict(fetch=dict(cursor=batch['cursor'], batch=0)), error='AccessDenied')
        client.call(dict(status=dict(operation=extended['identity'])), error='AccessDenied')
    finally:
        authorize(True)
    client.call(dict(fetch=dict(cursor=batch['cursor'], batch=0)), error='SqlResultIncomplete')
    submit('DROP QUEUE renew_work')
    client.close()
    restart()
    client = Client(root, port).open()
    assert renew_path.read_bytes() == renew_bytes
    assert submit(renew_saved['sql'], renew_saved['token'], parameters=renew_saved['parameters']) == extended
    assert rows(extended['identity']) == renewal

    for name in ('claim_pg', 'claim_mysql', 'claim_console'):
        submit(f'CREATE QUEUE {name} (value BIGINT NOT NULL)')
        submit(f'ENQUEUE INTO {name} VALUES (7), (8)')
    client.close()
    with psycopg.connect(**postgres) as wire:
        with wire.cursor() as cursor:
            cursor.execute('CLAIM value, _offset, _receipt_handle FROM claim_pg LIMIT %s WITH LEASE %s', (2, '10s'), prepare=True)
            acquired = cursor.fetchall()
            assert [row[:2] for row in acquired] == [(7, 0), (8, 1)]
            assert cursor.statusmessage == 'CLAIM 2'
            for index, row in enumerate(acquired):
                assert len(row[2]) == 168
                cursor.execute('EXTEND LEASE ON QUEUE claim_pg RECEIPT %s BY %s', (row[2], '1s'), prepare=True)
                renewed_wire = cursor.fetchall()
                assert cursor.statusmessage == 'EXTEND LEASE' and len(renewed_wire) == 1
                assert renewed_wire[0][0][:160] == row[2][:160]
                assert struct.unpack('<Q', renewed_wire[0][0][160:])[0] == struct.unpack('<Q', row[2][160:])[0] + 1000
                command = 'ACK' if index == 0 else 'NACK'
                suffix = '' if index == 0 else " WITH (visible_at = TIMESTAMP '2100-01-01T00:00:00Z')"
                cursor.execute(f'{command} ON QUEUE claim_pg RECEIPT %s{suffix}', (renewed_wire[0][0],), prepare=True)
                assert cursor.statusmessage == command and cursor.description is None
            cursor.execute("CLAIM value FROM claim_pg WITH LEASE '30s'")
            assert cursor.fetchall() == [] and cursor.statusmessage == 'CLAIM 0'
    with mysql.connector.connect(**mysql_options) as wire:
        with wire.cursor(prepared=True) as cursor:
            cursor.execute('CLAIM value, _receipt_handle FROM claim_mysql LIMIT %s WITH LEASE %s', (2, '10s'))
            acquired = cursor.fetchall()
            assert [row[0] for row in acquired] == [7, 8]
            renewed_mysql = []
            for row in acquired:
                cursor.execute('EXTEND LEASE ON QUEUE claim_mysql RECEIPT %s BY %s', (bytes(row[1]), '1s'))
                value = cursor.fetchall()
                assert len(value) == 1 and bytes(value[0][0])[:160] == bytes(row[1])[:160]
                assert struct.unpack('<Q', bytes(value[0][0])[160:])[0] == struct.unpack('<Q', bytes(row[1])[160:])[0] + 1000
                renewed_mysql.append((row[0], bytes(value[0][0])))
        # Connector/Python 9.4 retains a prepared cursor's prior description
        # after an OK packet. Check ACK's no-row completion on its own cursor.
        with wire.cursor(prepared=True) as cursor:
            for index, row in enumerate(renewed_mysql):
                assert len(row[1]) == 168
                command = 'ACK' if index == 0 else 'NACK'
                suffix = '' if index == 0 else " WITH (visible_at = TIMESTAMP '2100-01-01T00:00:00Z')"
                cursor.execute(f'{command} ON QUEUE claim_mysql RECEIPT %s{suffix}', (bytes(row[1]),))
                assert cursor.rowcount == 0 and not cursor.with_rows
        with wire.cursor() as cursor:
            cursor.execute("CLAIM value FROM claim_mysql WITH LEASE '30s'")
            assert cursor.fetchall() == []
    client = Client(root, port).open()
    submit('CREATE QUEUE ack_console (value BIGINT NOT NULL)')
    submit('CREATE QUEUE nack_console (value BIGINT NOT NULL)')
    submit('ENQUEUE INTO nack_console VALUES (32)')
    nack_claim = submit("CLAIM _receipt_handle FROM nack_console WITH LEASE '30s'")
    nack_handle = handle(rows(nack_claim['identity'])[0][0][0])
    submit('ENQUEUE INTO ack_console VALUES (31)')
    console_claim = submit("CLAIM _receipt_handle FROM ack_console WITH LEASE '30s'")
    console_handle = handle(rows(console_claim['identity'])[0][0][0])
    submit('CREATE QUEUE renew_console (value BIGINT NOT NULL)')
    submit('ENQUEUE INTO renew_console VALUES (33)')
    console_renewal = submit("CLAIM _receipt_handle FROM renew_console WITH LEASE '10s'")
    console_renewal_handle = handle(rows(console_renewal['identity'])[0][0][0])
    client.close()
    script = consumer / 'claims.sql'
    script.write_text(f"ACK ON QUEUE ack_console RECEIPT X'{console_handle.hex()}';\n" +
                      f"NACK ON QUEUE nack_console RECEIPT X'{nack_handle.hex()}';\n" +
                      f"EXTEND LEASE ON QUEUE renew_console RECEIPT X'{console_renewal_handle.hex()}' BY '1s';\n" +
                      "CLAIM value FROM claim_console LIMIT 2 WITH LEASE '30s';\nCLAIM value FROM claim_console WITH LEASE '30s';\n")
    rendered = subprocess.run([console, 'console', '--config', str(config), '--no-rc', '-f', str(script)],
                              cwd=consumer, env={'PATH': '/unavailable', 'HOME': str(home), 'LANG': 'C'},
                              capture_output=True, text=True, timeout=180)
    assert rendered.returncode == 0, (rendered.stdout, rendered.stderr)
    assert rendered.stdout.count('"complete_coverage":true') == 3, rendered.stdout
    frames = [json.loads(line) for line in rendered.stdout.splitlines()]
    assert frames[0]['completion']['kind'] == 'ack' and frames[0]['completion']['outcome'] == 'applied'
    assert frames[0]['completion']['counts'] is None
    assert frames[1]['completion']['kind'] == 'nack' and frames[1]['completion']['outcome'] == 'applied'
    assert frames[1]['completion']['counts'] is None
    assert '_receipt_handle' in rendered.stdout and 'renewal' in rendered.stdout
    print(json.dumps(dict(profile='sql_queue_claims', native=True, postgres=True, mysql=True, console=True,
                          original_selection_after_append_expiry_and_replacement=True, result_batches=sizes,
                          typed_parameters=True, empty_claim=True, current_disclosure_authorization=True,
                          no_repeat_acquisition=True, binary_receipts=True, native_postgres_mysql_console_ack=True,
                          ack_after_alter_and_original_after_drop=True, original_ack_after_replacement=True, native_postgres_mysql_console_nack=True,
                          nack_fifo_delay_and_unrelated_key=True, nack_after_alter_and_original_after_drop=True,
                          original_nack_after_replacement=True, nack_original_response_discarded=True, nack_changed_token_refusal=True,
                          native_postgres_mysql_console_renewal=True, original_renewal_after_later_settlement_and_drop=True,
                          renewal_execute_and_fetch_response_discarded=True, renewal_stale_handle_refusal=True, passed=True)), flush=True)

"""Installed Stream reads and settlements: cuts, limits, fencing and disclosure."""
import copy
import json
import os
import struct
import subprocess

from interfaces.native.stream_handles import encode as stream_handle
from interfaces.sql_sessions.native import Client
from interfaces.sql_sessions.storage import unsigned


def run(root, port, postgres, mysql_options, restart, authorize, console, config, consumer, home, stream_native):
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
        ("CONSUME value FROM consume_events WAIT '1001ms'", 'InvalidStreamWait'),
    ):
        token = None if error == 'SqlAdmissionTokenRequired' else list(os.urandom(16))
        client.call(dict(execute=dict(sql=sql, token=token)), error=error)

    sql = "CONSUME value, _offset FROM consume_events WHERE _offset >= 2 AND value >= 5 LIMIT 3 WAIT '1s'"
    original = dict(definition=client.definition, sql=sql, token=list(os.urandom(16)))
    saved = root / 'sql-consume-original.json'
    saved.write_text(json.dumps(original))
    operation = submit(sql, original['token'])
    assert operation['command'] == 'consume' and operation['result_kind'] == 'rows'
    # Session operation envelopes reserve zero placeholders for commands whose
    # shared completion has no applicable matched/changed counts.
    assert operation['matched'] == operation['changed'] == 0, operation
    original['identity'] = operation['identity']
    saved.write_text(json.dumps(original))
    original_bytes = saved.read_bytes()
    result = rows(original['identity'])
    values, sizes, observation, completion = result
    assert [list(map(unsigned, row)) for row in values] == [[i, i] for i in range(5, 8)]
    assert sizes == [3] and observation['data']['workload']['limit'] == 3
    coverage = completion['workload']['position']['consume']['coverage']
    assert {key: coverage[key] for key in ('from', 'until', 'through', 'rows', 'complete')} == dict(
        **{'from': 2}, until=65, through=8, rows=6, complete=False), coverage

    complete_read = submit("CONSUME value FROM consume_events WAIT '1ms'")['identity']
    all_rows = rows(complete_read)
    assert [unsigned(row[0]) for row in all_rows[0]] == list(range(65))
    assert all_rows[1] == [32, 32, 1]
    assert all_rows[3]['workload']['position']['consume']['coverage']['complete']
    filtered = rows(submit("CONSUME value FROM consume_events WHERE value > 1000 LIMIT 1 WAIT '1s'")['identity'])
    assert filtered[0] == [] and filtered[1] == [0]
    coverage = filtered[3]['workload']['position']['consume']['coverage']
    assert coverage['through'] == coverage['rows'] == 65 and coverage['complete']
    # A row predicate above the current frontier must not become native until.
    bounded = rows(submit("CONSUME value FROM consume_events WHERE _offset < 100 LIMIT 1 WAIT '1ms'")['identity'])
    assert [unsigned(row[0]) for row in bounded[0]] == [0]
    assert bounded[2]['data']['workload']['selection']['consume']['until'] == 65
    routed = rows(submit('CONSUME value, _partition, _offset FROM append_manual WHERE _partition = 1')['identity'])
    assert [list(map(unsigned, row)) for row in routed[0]] == [[1, 1, 0]]
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
    typed = "CONSUME value FROM consume_events WHERE _offset >= $1 LIMIT $2 WAIT $3"
    duration_kind = descriptor('utf8')
    duration = (b'FVL1' + struct.pack('<H', len(duration_kind)) + duration_kind + b'\x01\x03' + struct.pack('<I', 3) + b'1ms').hex()
    described = client.call(dict(prepare=dict(sql=typed)))['described']
    assert described['mutation'] and described['schema'] is not None
    assert described['parameters'] == [kind.hex(), kind.hex(), duration_kind.hex()]
    typed_rows = rows(submit(typed, parameters=[parameter(64), parameter(2), duration])['identity'])
    assert [unsigned(row[0]) for row in typed_rows[0]] == [64, 65]
    client.call(dict(release=described['statement']))

    for identity in (original['identity'], complete_read, submit("CONSUME value FROM consume_events LIMIT 0 WAIT '1s'")['identity']):
        batch = client.call(dict(result=identity))['batch']
        authorize(False)
        try:
            client.call(dict(fetch=dict(cursor=batch['cursor'], batch=0)), error='AccessDenied')
        finally:
            authorize(True)
        client.call(dict(fetch=dict(cursor=batch['cursor'], batch=0)), error='SqlResultIncomplete')
    # Assign through the native administration owner; SQL never creates a group.
    submit('CREATE STREAM grouped_events (value BIGINT NOT NULL) WITH (read_rows=16)')
    submit('PRODUCE INTO grouped_events VALUES ' + ','.join(f'({i})' for i in range(65)))
    def binary(value):
        return "X'" + stream_handle(value).hex() + "'"
    def handle(delivered):
        observation = delivered[2]['data']['workload']
        progress = delivered[3]['workload']['progress']
        return dict(definition=client.definition, receipt=observation['selection']['consume'], progress=progress)
    assignment = stream_native('stream-assign', 'grouped_events', 51, 8051)
    grouped_sql = f'CONSUME value FROM grouped_events GROUP {binary(assignment)} WHERE value >= 5 LIMIT 3'
    group_token = list(os.urandom(16))
    waited_group_sql = grouped_sql + " WAIT '1s'"
    original_group = submit(waited_group_sql, group_token)
    grouped = rows(original_group['identity'])
    assert [unsigned(row[0]) for row in grouped[0]] == [5, 6, 7]
    progress = handle(grouped)
    interval = progress['progress']['interval']
    assert interval['first']['coverage']['through'] == 0
    assert interval['last']['coverage']['through'] == 8 and not interval['last']['coverage']['complete']
    zero = rows(submit(f'CONSUME value FROM grouped_events GROUP {binary(assignment)} LIMIT 0' + " WAIT '1s'")['identity'])
    assert zero[0] == [] and handle(zero)['progress']['interval']['last']['coverage']['through'] == 0
    forged = copy.deepcopy(progress)
    forged['progress']['interval']['last']['authentication'][0] ^= 1
    # Bind-time shape validation is not the native MAC check.
    refused = client.terminal(client.execute(f'COMMIT OFFSET ON STREAM grouped_events RECEIPT {binary(forged)}', list(os.urandom(16)))['operation'], outcomes=('rejected',))
    assert refused['workload']['receipt']['closed']['reason'] == {'refused': 'cursor_unauthenticated'}, refused
    commit_sql = f'COMMIT OFFSET ON STREAM grouped_events RECEIPT {binary(progress)}'
    commit_token = list(os.urandom(16))
    committed = submit(commit_sql, commit_token)
    assert committed['command'] == 'commit_offset' and committed['result_kind'] == 'command'
    assert rows(original_group['identity']) == grouped
    stale = client.terminal(client.execute(commit_sql, list(os.urandom(16)))['operation'], outcomes=('rejected',))
    assert stale['workload']['receipt']['closed']['reason'] == {'refused': 'offset_conflict'}
    stale_read = client.terminal(client.execute(grouped_sql, list(os.urandom(16)))['operation'], outcomes=('rejected',))
    assert stale_read['workload']['receipt']['closed']['reason'] == {'refused': 'offset_conflict'}
    client.close()
    restart()
    client = Client(root, port).open()
    assert submit(commit_sql, commit_token) == committed
    # The operation remains original, but reassignment fences further delivery.
    before_reassignment = client.call(dict(result=original_group['identity']))['batch']
    reassigned = stream_native('stream-assign', 'grouped_events', 51, 8151)
    assert reassigned['group']['next'] == 8 and reassigned['group']['group']['generation'] == 2
    client.call(dict(fetch=dict(cursor=before_reassignment['cursor'], batch=0)), error='Conflict')
    client.call(dict(close_result=before_reassignment['cursor']))
    assert submit(waited_group_sql, group_token) == original_group
    client.call(dict(result=original_group['identity']), error='Conflict')
    fenced = client.terminal(client.execute(grouped_sql, list(os.urandom(16)))['operation'], outcomes=('rejected',))
    assert fenced['workload']['receipt']['closed']['reason'] == {'refused': 'group_fenced'}
    assert submit(commit_sql, commit_token) == committed
    after = rows(submit(f'CONSUME value FROM grouped_events GROUP {binary(reassigned)} WHERE value > 1000' + " WAIT '1s'")['identity'])
    assert after[0] == [] and handle(after)['progress']['exhausted']['coverage']['through'] == 65
    released_group = stream_native('stream-assign', 'grouped_events', 55, 8055)
    released_read = rows(submit(f'CONSUME value FROM grouped_events GROUP {binary(released_group)} LIMIT 1' + " WAIT '1s'")['identity'])
    released_handle = handle(released_read)
    (root / 'group-release.bin').write_bytes(stream_handle(released_handle))
    stream_native('stream-release', 'group-release.bin', 9055)
    released = client.terminal(client.execute(f'COMMIT OFFSET ON STREAM grouped_events RECEIPT {binary(released_handle)}', list(os.urandom(16)))['operation'], outcomes=('rejected',))
    assert released['workload']['receipt']['closed']['reason'] == {'refused': 'read_released'}
    # Lose every outcome byte after headers, replace the service and recover
    # solely from the token and exact request saved before dispatch.
    loss = dict(sql=f'COMMIT OFFSET ON STREAM grouped_events RECEIPT {binary(handle(after))}', token=list(os.urandom(16)))
    (root / 'group-offset-original.json').write_text(json.dumps(loss))
    client.call(dict(execute=loss), discard_response=True)
    client.close()
    restart()
    client = Client(root, port).open()
    recovered_offset = submit(loss['sql'], loss['token'])
    assert recovered_offset['command'] == 'commit_offset'
    assert submit(loss['sql'], loss['token']) == recovered_offset
    # Typed grouping now uses the advanced checkpoint, with the same assignment.
    reassigned['group']['next'] = recovered_offset['workload']['receipt']['offset']['receipt']['commit']['next']
    assert reassigned['group']['next'] == 65
    # A complete handoff is consumable by all SQL transports without inventing
    # coverage from their row counts. Assignment remains a native operation.
    raw_group = stream_handle(reassigned)
    binary_type = descriptor('binary')
    encoded_group = (b'FVL1' + struct.pack('<H', len(binary_type)) + binary_type + b'\x01\x03' + struct.pack('<I', len(raw_group)) + raw_group).hex()
    typed_operation = submit('CONSUME value FROM grouped_events GROUP $1 LIMIT 0', parameters=[encoded_group])
    typed_group = rows(typed_operation['identity'])
    assert typed_group[0] == []
    buffered = client.call(dict(result=typed_operation['identity']))['batch']
    authorize(False)
    try:
        client.call(dict(fetch=dict(cursor=buffered['cursor'], batch=0)), error='AccessDenied')
        client.call(dict(status=dict(operation=committed['identity'])), error='AccessDenied')
    finally:
        authorize(True)
    client.call(dict(close_result=buffered['cursor']))
    wire_proofs = []
    for group in (52, 53, 54):
        assigned = stream_native('stream-assign', 'grouped_events', group, 8000 + group)
        delivered = rows(submit(f'CONSUME value FROM grouped_events GROUP {binary(assigned)}' + " WAIT '1s'")['identity'])
        assert len(delivered[0]) == 65 and delivered[1] == [32, 32, 1]
        wire_proofs.append((assigned, handle(delivered)))
    client.close()

    with psycopg.connect(**postgres) as wire:
        with wire.cursor() as cursor:
            cursor.execute("CONSUME value, _offset FROM consume_events WHERE _offset >= %s LIMIT %s WAIT '1s'", (63, 2), prepare=True)
            assert cursor.fetchall() == [(63, 63), (64, 64)]
            assert cursor.statusmessage == 'CONSUME 2'
            cursor.execute('CONSUME value FROM consume_events LIMIT 0')
            assert cursor.fetchall() == [] and cursor.statusmessage == 'CONSUME 0'
            cursor.execute(f'CONSUME value FROM grouped_events GROUP {binary(wire_proofs[0][0])} LIMIT 0')
            assert cursor.fetchall() == []
            cursor.execute(f'COMMIT OFFSET ON STREAM grouped_events RECEIPT {binary(wire_proofs[0][1])}')
            assert cursor.statusmessage == 'COMMIT OFFSET'
    with mysql.connector.connect(**mysql_options) as wire:
        with wire.cursor(prepared=True) as cursor:
            cursor.execute("CONSUME value FROM consume_events WHERE _offset >= %s LIMIT %s WAIT '1s'", (64, 2))
            assert cursor.fetchall() == [(64,), (65,)]
        with wire.cursor() as cursor:
            cursor.execute('CONSUME value FROM consume_events LIMIT 0')
            assert cursor.fetchall() == []
            cursor.execute(f'CONSUME value FROM grouped_events GROUP {binary(wire_proofs[1][0])} LIMIT 0')
            assert cursor.fetchall() == []
            cursor.execute(f'COMMIT OFFSET ON STREAM grouped_events RECEIPT {binary(wire_proofs[1][1])}')
    script = consumer / 'consumes.sql'
    script.write_text("CONSUME value FROM consume_events WHERE _offset >= 64 LIMIT 1 WAIT '1s';\nCONSUME value FROM consume_events LIMIT 0 WAIT '1s';\n")
    with script.open('a') as extra:
        extra.write(f'CONSUME value FROM grouped_events GROUP {binary(wire_proofs[2][0])} LIMIT 0;\nCOMMIT OFFSET ON STREAM grouped_events RECEIPT {binary(wire_proofs[2][1])};\n')
    rendered = subprocess.run([console, 'console', '--config', str(config), '--no-rc', '-f', str(script)],
                              cwd=consumer, env={'PATH': '/unavailable', 'HOME': str(home), 'LANG': 'C'},
                              capture_output=True, text=True, timeout=180)
    assert rendered.returncode == 0, (rendered.stdout, rendered.stderr)
    assert rendered.stdout.count('"complete_coverage":true') == 3, rendered.stdout
    print(json.dumps(dict(profile='sql_positional_consumes', native=True, postgres=True, mysql=True, console=True,
                          original_cut_after_append_and_replacement=True, result_batches=all_rows[1],
                          filtered_partial_coverage=True, zero_limit=True, exhausted_before_limit=True,
                          typed_parameters=True, waited_cuts=True, waited_group_progress=True, explicit_groups=True, authenticated_offsets=True, stale_group_and_checkpoint_refusal=True, reassignment_fences_buffered_and_reopened_reads=True,
                          current_disclosure_authorization=True, passed=True)), flush=True)

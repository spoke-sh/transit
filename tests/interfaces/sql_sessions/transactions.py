"""Independent transaction histories through installed native, PG and MySQL clients."""
import json
import os
import subprocess
import time
import psycopg
import mysql.connector
from interfaces.native.stream_handles import encode as stream_handle
from interfaces.sql_sessions.native import Client
from interfaces.sql_sessions.storage import text as decode_text, unsigned as decode_unsigned
from runner.capture import provenance
from runner.paths import ROOT


CATALOG_NATIVE = None


def command(client, sql, expected='applied', token=None):
    token = list(os.urandom(16)) if token is None else token
    started = time.monotonic()
    operation = client.execute(sql, token)['operation']
    deadline = time.monotonic() + 90
    while operation['phase'] != 'terminal':
        assert time.monotonic() < deadline, operation
        time.sleep(.03)
        operation = client.call(dict(resume=operation['identity']))['operation']
    assert operation['outcome'] == expected, (sql, operation)
    print(json.dumps(dict(profile="transaction_command", kind=operation["command"], outcome=expected, milliseconds=round((time.monotonic()-started)*1000, 3))), flush=True)
    return operation, token


def rows(client, sql):
    batch = client.execute(sql)['batch']
    result = list(batch['rows'])
    observation = batch['observation']
    while not batch['complete']:
        batch = client.call(dict(fetch=dict(cursor=batch['cursor'], batch=batch['batch']+1)))['batch']
        result.extend(batch['rows'])
    client.call(dict(close_result=batch['cursor']))
    # This fixture deliberately uses only integer columns and independent bytes.
    decoded = []
    for row in result:
        values = []
        for cell in row:
            value = bytes.fromhex(cell)
            assert value[0] in (3, 4) and len(value) == 9, cell
            values.append(int.from_bytes(value[1:], 'little', signed=value[0] == 3))
        decoded.append(values)
    return decoded, observation


def run(root, port, postgres, mysql_options, restart, faults, authority, console):
    first, second = Client(root, port).open(), Client(root, port).open()
    for table in ('tx_left', 'tx_right'):
        command(first, f'CREATE TABLE {table} (id INT64 PRIMARY KEY, amount INT64)')
        command(first, f'INSERT INTO {table} (id, amount) VALUES (1, 10)')
    begun, _ = command(first, 'BEGIN ISOLATION LEVEL SERIALIZABLE')
    attachment = begun['transaction']['handle']
    assert begun['transaction']['evidence']['begun']['sources']['count'] == 2
    assert first.call('context')['context']['transaction'] == attachment
    changed, _ = command(first, 'UPDATE tx_left SET amount=7 WHERE id=1', 'provisional')
    assert changed['matched'] == changed['changed'] == 1
    assert changed['identity']['kind'] == 'transaction'
    own, observation = rows(first, 'SELECT amount FROM tx_left WHERE id=1')
    assert own == [[7]] and observation['data']['transaction']['handle'] == attachment
    assert rows(second, 'SELECT amount FROM tx_left WHERE id=1')[0] == [[10]]
    command(first, 'SAVEPOINT original')
    rolled, token = command(first, 'UPDATE tx_left SET amount=6 WHERE id=1', 'provisional')
    command(first, 'ROLLBACK TO SAVEPOINT original')
    assert rows(first, 'SELECT amount FROM tx_left WHERE id=1')[0] == [[7]]
    repeated, _ = command(first, 'UPDATE tx_left SET amount=6 WHERE id=1', 'provisional', token)
    assert repeated['identity'] == rolled['identity'] and repeated['transaction'] == rolled['transaction']
    assert rows(first, 'SELECT amount FROM tx_left WHERE id=1')[0] == [[7]]
    command(first, 'UPDATE tx_right SET amount=13 WHERE id=1', 'provisional')
    joined, basis = rows(first, 'SELECT l.amount AS left_amount, r.amount AS right_amount FROM tx_left AS l INNER JOIN tx_right AS r ON l.id=r.id')
    assert joined == [[7, 13]], joined
    assert len(basis['data']['transaction']['sources']) == 2
    faults.fail_transaction_once = True
    committed, commit_token = command(first, 'COMMIT')
    assert committed['transaction']['evidence']['decided']['decision']['outcome'] == 'committed'
    assert faults.transaction_reply_losses == 1
    duplicate, _ = command(first, 'COMMIT', token=commit_token)
    assert duplicate['transaction']['evidence']['decided']['decision'] == committed['transaction']['evidence']['decided']['decision']
    cancelled = first.call(dict(cancel=dict(operation=committed['identity'])))['operation']
    assert cancelled['outcome'] == 'applied'
    assert cancelled['transaction']['evidence']['decided']['decision'] == committed['transaction']['evidence']['decided']['decision']
    assert first.call('context')['context']['transaction'] is None
    assert rows(second, 'SELECT amount FROM tx_left WHERE id=1')[0] == [[7]]
    assert rows(second, 'SELECT amount FROM tx_right WHERE id=1')[0] == [[13]]

    # Independent business oracle: two transactions cannot both consume the
    # other's balance at the same common cut and leave both accounts empty.
    command(first, 'BEGIN')
    command(second, 'BEGIN')
    assert rows(first, 'SELECT amount FROM tx_right')[0] == [[13]]
    assert rows(second, 'SELECT amount FROM tx_left')[0] == [[7]]
    command(first, 'UPDATE tx_left SET amount=0 WHERE id=1', 'provisional')
    command(second, 'UPDATE tx_right SET amount=0 WHERE id=1', 'provisional')
    command(first, 'COMMIT')
    aborted, _ = command(second, 'COMMIT', 'rejected')
    assert aborted['transaction']['evidence']['decided']['decision']['outcome'] == 'aborted'
    assert rows(first, 'SELECT amount FROM tx_right')[0] == [[13]]

    # Read-only cut remains usable after a later committed write, and explicit
    # rollback excludes every provisional row from the committed Tables.
    command(first, 'BEGIN READ ONLY')
    command(second, 'UPDATE tx_right SET amount=14 WHERE id=1')
    assert rows(first, 'SELECT amount FROM tx_right')[0] == [[13]]
    command(first, 'COMMIT')
    command(first, 'BEGIN')
    command(first, 'UPDATE tx_left SET amount=9 WHERE id=1', 'provisional')
    first.call(dict(execute=dict(sql='CREATE TABLE excluded (id INT64)', token=list(os.urandom(16)))), error='UnsupportedTransactionStatement')
    command(first, 'ROLLBACK')
    assert rows(second, 'SELECT amount FROM tx_left')[0] == [[0]]

    # Connection and gateway replacement do not own the transaction. Preserve
    # original native material and explicitly attach it in the replacement.
    begun, _ = command(first, 'BEGIN')
    attachment = begun['transaction']['handle']
    command(first, 'UPDATE tx_left SET amount=8 WHERE id=1', 'provisional')
    first.close()
    second.close()
    restart()
    recovered = Client(root, port).open()
    assert recovered.call(dict(attach_transaction=attachment))['attached'] == attachment
    assert rows(recovered, 'SELECT amount FROM tx_left')[0] == [[8]]
    command(recovered, 'COMMIT')
    recovered.close()

    with psycopg.connect(**postgres) as pg:
        pg.execute('BEGIN')
        assert pg.info.transaction_status == psycopg.pq.TransactionStatus.INTRANS
        pg.execute('SAVEPOINT keep')
        assert pg.execute('UPDATE tx_left SET amount=20 WHERE id=1').rowcount == 1
        assert pg.execute('SELECT amount FROM tx_left').fetchall() == [(20,)]
        pg.execute('ROLLBACK TO keep')
        assert pg.execute('SELECT amount FROM tx_left').fetchall() == [(8,)]
        pg.execute('COMMIT')
        assert pg.info.transaction_status == psycopg.pq.TransactionStatus.IDLE
        pg.execute('BEGIN')
        try:
            pg.execute('INSERT INTO tx_left (id,amount) VALUES (1,99)')
        except psycopg.errors.UniqueViolation:
            pass
        else:
            raise AssertionError('Duplicate private key accepted')
        assert pg.info.transaction_status == psycopg.pq.TransactionStatus.INERROR
        pg.execute('ROLLBACK')
        assert pg.info.transaction_status == psycopg.pq.TransactionStatus.IDLE
    with mysql.connector.connect(**mysql_options) as my:
        cursor = my.cursor()
        cursor.execute('START TRANSACTION')
        assert my.in_transaction
        cursor.execute('UPDATE tx_left SET amount=21 WHERE id=1')
        assert cursor.rowcount == 1
        cursor.execute('SELECT amount FROM tx_left')
        assert cursor.fetchall() == [(21,)]
        cursor.execute('ROLLBACK')
        assert not my.in_transaction
        cursor.execute('SELECT amount FROM tx_left')
        assert cursor.fetchall() == [(8,)]
        cursor.close()
    extended(root, port, faults, authority)
    console_controls(root, port, console)
    if CATALOG_NATIVE is not None:
        mixed(root, port, postgres, mysql_options, faults, console, CATALOG_NATIVE)
    lifetimes(root, port, restart)
    print(json.dumps(dict(profile='installed_table_transactions', source=provenance(ROOT),
                          common_cut=True, private_reads=True, private_join=True,
                          savepoint_original_retry=True, write_skew_prevented=True,
                          read_only_retained_cut=True, commit_reply_losses=1,
                          gateway_restart_attachment=True, postgres_status=True,
                          mysql_status=True)), flush=True)


def extended(root, port, faults, authority):
    first, second = Client(root, port).open(), Client(root, port).open()
    # Absent keys and predicate phantoms must retain the read dependency even
    # though no row was returned. The later INSERT is independently committed.
    for key, predicate in ((2, 'id=2'), (3, 'amount>100')):
        command(first, 'BEGIN')
        assert rows(first, f'SELECT id FROM tx_right WHERE {predicate}')[0] == []
        command(second, f'INSERT INTO tx_right (id,amount) VALUES ({key},200)')
        command(first, 'UPDATE tx_left SET amount=70 WHERE id=1', 'provisional')
        result, _ = command(first, 'COMMIT', 'rejected')
        assert result['transaction']['evidence']['decided']['decision']['outcome'] == 'aborted'
        assert rows(second, 'SELECT amount FROM tx_left')[0] == [[8]]
        command(second, f'DELETE FROM tx_right WHERE id={key}')

    command(first, 'CREATE TABLE tx_words (id INT64 PRIMARY KEY, label UTF8 COLLATE ASCII_CI)')
    command(first, "INSERT INTO tx_words (id,label) VALUES (1,'Alpha')")
    command(first, 'BEGIN')
    assert rows(first, "SELECT id FROM tx_words WHERE label='alpha'")[0] == [[1]]
    command(second, "INSERT INTO tx_words (id,label) VALUES (2,'ALPHA')")
    assert rows(first, "SELECT id FROM tx_words WHERE label='alpha'")[0] == [[1]]
    command(first, 'UPDATE tx_left SET amount=70 WHERE id=1', 'provisional')
    command(first, 'COMMIT', 'rejected')

    command(first, 'CREATE TABLE tx_keyless (amount INT64)')
    command(first, 'INSERT INTO tx_keyless (amount) VALUES (1),(1)')
    command(first, 'BEGIN')
    command(first, 'SAVEPOINT duplicates')
    result, _ = command(first, 'UPDATE tx_keyless SET amount=2 WHERE amount=1', 'provisional')
    assert result['matched'] == result['changed'] == 2
    assert sorted(rows(first, 'SELECT amount FROM tx_keyless')[0]) == [[2],[2]]
    command(first, 'ROLLBACK TO duplicates')
    assert sorted(rows(first, 'SELECT amount FROM tx_keyless')[0]) == [[1],[1]]
    command(first, 'COMMIT')

    command(first, 'BEGIN')
    command(second, 'ALTER TABLE tx_words ADD COLUMN extra INT64')
    command(first, 'UPDATE tx_left SET amount=70 WHERE id=1', 'provisional')
    command(first, 'COMMIT', 'rejected')
    assert rows(second, 'SELECT amount FROM tx_left')[0] == [[8]]

    # Repeated buffered data and commit both recheck current authority. A denial
    # cannot be reported as an abort. Restore authority to explicitly close work.
    command(first, 'BEGIN')
    batch = first.execute('SELECT amount FROM tx_left')['batch']
    authority(False)
    try:
        first.call(dict(fetch=dict(cursor=batch['cursor'], batch=0)), error='AccessDenied')
    finally:
        authority(True)
    command(first, 'ROLLBACK')

    command(first, 'BEGIN')
    command(first, 'UPDATE tx_left SET amount=71 WHERE id=1', 'provisional')
    authority(False)
    try:
        first.call(dict(execute=dict(sql='COMMIT', token=list(os.urandom(16)))), error='AccessDenied')
    finally:
        authority(True)
    # Denied observation is not an abort. The authorized caller still settles
    # the original lifetime, and the private value never becomes public.
    assert first.call('context')['context']['transaction'] is not None
    command(first, 'ROLLBACK')
    assert rows(second, 'SELECT amount FROM tx_left')[0] == [[8]]

    # A second authorized attachment can advance the same workspace. A retained
    # final batch from the old revision must still reject repeated disclosure.
    begun, _ = command(first, 'BEGIN')
    attached = Client(root, port).open()
    attached.call(dict(attach_transaction=begun['transaction']['handle']))
    batch = first.execute('SELECT amount FROM tx_left')['batch']
    command(attached, 'SAVEPOINT advanced')
    first.call(dict(fetch=dict(cursor=batch['cursor'], batch=0)), error='TransactionReadChanged')
    command(first, 'ROLLBACK')
    attached.close()

    # The executable example is also the fixture: data, checkpoint and durable
    # intent are three ordinary Tables under one decision, with no effect API.
    example = ROOT / 'examples/table-outbox/transaction.sql'
    statements = [part.strip() for part in example.read_text().split(';') if part.strip()]
    for statement in statements:
        expected = 'provisional' if statement.startswith(('UPDATE outbox_', 'INSERT INTO outbox_intents')) else 'applied'
        if statement == 'COMMIT':
            assert rows(second, 'SELECT value FROM outbox_state')[0] == [[0]]
            assert rows(second, 'SELECT position FROM outbox_checkpoint')[0] == [[0]]
            assert rows(second, 'SELECT id FROM outbox_intents')[0] == []
            faults.fail_transaction_once = True
        result, token = command(first, statement, expected)
    assert rows(second, 'SELECT value FROM outbox_state')[0] == [[1]]
    assert rows(second, 'SELECT position FROM outbox_checkpoint')[0] == [[1]]
    assert rows(second, 'SELECT id FROM outbox_intents')[0] == [[1]]
    assert faults.transaction_reply_losses == 2
    repeat, _ = command(first, 'COMMIT', token=token)
    assert repeat['identity'] == result['identity']

    command(first, 'BEGIN')
    command(first, 'INSERT INTO outbox_intents (id,state) VALUES (2,0)', 'provisional')
    command(first, 'ROLLBACK')
    assert rows(second, 'SELECT id FROM outbox_intents')[0] == [[1]]
    # Application-owned delivery policy: inspect committed intents, never dispatch
    # on history replay or without effect permission. A lost remote reply remains
    # unknown (state=1); no automatic retry is justified by local commit evidence.
    attempts = []
    def dispatch(*, replay=False, effect_allowed=True):
        if replay or not effect_allowed:
            return
        pending, _ = rows(second, 'SELECT id FROM outbox_intents WHERE state=0')
        for (identity,) in pending:
            command(second, f'UPDATE outbox_intents SET state=1 WHERE id={identity}')
            attempts.append(identity)  # remote accepted, its response is lost
    dispatch(replay=True)
    dispatch(effect_allowed=False)
    assert attempts == []
    dispatch()
    dispatch(replay=True)
    dispatch()
    assert attempts == [1]
    assert rows(second, 'SELECT state FROM outbox_intents WHERE id=1')[0] == [[1]]
    first.close()
    second.close()
    print(json.dumps(dict(profile='installed_transaction_anomalies_outbox', absent_key=True,
                          phantom=True, ascii_ci=True, keyless_occurrences=True, ddl_conflict=True,
                          buffered_revocation=True, checkpoint_state_outbox=True,
                          lost_commit_reply=True, aborted_intent_excluded=True,
                          application_dispatch_policy=True, unknown_remote_outcome=True)), flush=True)


def console_controls(root, port, binary):
    consumer = root/'transaction-console'
    consumer.mkdir()
    home = consumer/'home'
    home.mkdir()
    password = consumer/'password'
    password.write_text('proof-password')
    password.chmod(0o600)
    config = consumer/'connection.yaml'
    config.write_text(f'version: 1\nendpoint: https://localhost:{port}\naccount: proof\ndatabase: data\nauthentication: scram\nca_file: {root/"certificate.pem"}\npassword_file: {password}\nformat: table\n')
    script = consumer/'transaction.sql'
    script.write_text('BEGIN;\nUPDATE tx_left SET amount=82 WHERE id=1;\nSAVEPOINT kept;\nUPDATE tx_left SET amount=83 WHERE id=1;\nROLLBACK TO kept;\nSELECT amount FROM tx_left;\nROLLBACK;\nBEGIN READ ONLY;\nCOMMIT;\n')
    result = subprocess.run([binary, 'console', '--config', str(config), '--no-rc', '-f', str(script)],
                            cwd=consumer, env={'PATH': '/unavailable', 'HOME': str(home), 'LANG': 'C'},
                            capture_output=True, text=True, timeout=180)
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert result.stdout.count('Statement completed provisionally. Matched 1; changed 1.') == 2
    assert 'Transaction workspace (provisional rows).' in result.stdout and '82' in result.stdout
    assert 'Transaction rolled back to savepoint.' in result.stdout
    assert 'Transaction rolled back.' in result.stdout and 'Transaction committed.' in result.stdout
    check = Client(root, port).open()
    assert rows(check, 'SELECT amount FROM tx_left')[0] == [[8]]
    check.close()
    print(json.dumps(dict(profile='installed_transaction_console', provisional_counts=True,
                          private_rows=True, savepoints=True, rollback=True, commit=True)), flush=True)


def lifetimes(root, port, restart):
    first, second = Client(root, port).open(), Client(root, port).open()
    command(first, 'CREATE TABLE tx_many (id INT64 PRIMARY KEY, amount INT64)')
    command(first, 'INSERT INTO tx_many (id,amount) VALUES ' + ','.join(f'({i},{i})' for i in range(40)))
    command(first, 'BEGIN')
    command(first, 'UPDATE tx_many SET amount=100 WHERE id=0', 'provisional')
    batch = first.execute('SELECT id,amount FROM tx_many')['batch']
    assert not batch['complete'] and len(batch['rows']) == 32
    basis, observed = batch['observation'], list(batch['rows'])
    command(second, 'UPDATE tx_many SET amount=200 WHERE id=1')
    time.sleep(.25)  # a delayed consumer cannot acquire a newer cut
    batch = first.call(dict(fetch=dict(cursor=batch['cursor'], batch=1)))['batch']
    observed.extend(batch['rows'])
    assert batch['complete'] and batch['completion']['rows'] == 40
    assert batch['observation'] == basis
    decoded = sorted(tuple(int.from_bytes(bytes.fromhex(cell)[1:], 'little', signed=True) for cell in row) for row in observed)
    assert decoded == [(i, 100 if i == 0 else i) for i in range(40)]
    first.call(dict(close_result=batch['cursor']))
    command(first, 'ROLLBACK')
    first.close()
    second.close()

    # The session lease owns only attachment. Its expiry cannot discard the
    # accepted workspace or synthesize an abort decision.
    restart(session_lease_ms=2000)
    leased = Client(root, port).open()
    begun, _ = command(leased, 'BEGIN')
    command(leased, 'UPDATE tx_left SET amount=72 WHERE id=1', 'provisional')
    time.sleep(2.2)
    leased.call('context', error='SqlSessionExpired')
    leased.session = None
    leased.close()
    renewed = Client(root, port).open()
    renewed.call(dict(attach_transaction=begun['transaction']['handle']))
    assert rows(renewed, 'SELECT amount FROM tx_left')[0] == [[72]]
    command(renewed, 'ROLLBACK')
    renewed.close()

    # Fixed transaction ceilings refuse before admitting another SQL command;
    # retained accepted work can still be explicitly rolled back.
    restart(transaction_limits=dict(resident_bytes=16*1024*1024, workspace_bytes=256*1024*1024,
                                    participants=100, statements=1, savepoints=1))
    limited = Client(root, port).open(account='limited')
    command(limited, 'BEGIN')
    command(limited, 'UPDATE tx_left SET amount=73 WHERE id=1', 'provisional')
    limited.call(dict(execute=dict(sql='UPDATE tx_left SET amount=74 WHERE id=1', token=list(os.urandom(16)))), error='SqlTransactionLimit')
    command(limited, 'ROLLBACK')
    assert rows(limited, 'SELECT amount FROM tx_left')[0] == [[8]]
    command(limited, 'BEGIN')
    command(limited, 'SAVEPOINT first')
    limited.call(dict(execute=dict(sql='SAVEPOINT second', token=list(os.urandom(16)))), error='SqlTransactionLimit')
    command(limited, 'ROLLBACK')
    limited.close()
    print(json.dumps(dict(profile='installed_transaction_lifetimes', private_batches=2, private_rows=40,
                          delayed_reader_cut=True, session_expiry_attachment=True,
                          statement_limit=True, savepoint_limit=True, explicit_cleanup=True)), flush=True)


def mixed(root, port, postgres, mysql_options, faults, binary, catalog_native):
    first, second = Client(root, port).open(), Client(root, port).open()

    def kv_rows(client, sql):
        batch = client.execute(sql)['batch']
        assert batch['complete'], batch
        out = []
        for row in batch['rows']:
            raw = bytes.fromhex(row[1])
            assert raw[0] in (3, 4) and len(raw) == 9, row
            out.append((decode_text(row[0]), int.from_bytes(raw[1:], 'little', signed=raw[0] == 3)))
        client.call(dict(close_result=batch['cursor']))
        return out

    def workload_rows(client, sql):
        op, _ = command(client, sql)
        batch = client.call(dict(result=op['identity']))['batch']
        observation, values = batch['observation'], []
        while True:
            values.extend(batch['rows'])
            if batch['complete']:
                completion = batch['completion']
                break
            batch = client.call(dict(fetch=dict(cursor=batch['cursor'], batch=batch['batch'] + 1)))['batch']
        client.call(dict(close_result=batch['cursor']))
        return values, observation, completion

    def sph1_hex(delivered):
        payload = dict(
            definition=first.definition,
            receipt=delivered[1]['data']['workload']['selection']['consume'],
            progress=delivered[2]['workload']['progress'],
        )
        return stream_handle(payload).hex()

    def queue_receipt_hex(cell):
        raw = bytes.fromhex(cell)
        assert raw[0] == 3 and len(raw) == 5 + int.from_bytes(raw[1:5], 'little'), cell
        return raw[5:].hex()

    def signed_cell(cell):
        raw = bytes.fromhex(cell)
        assert raw[0] in (3, 4) and len(raw) == 9, cell
        return int.from_bytes(raw[1:], 'little', signed=raw[0] == 3)

    command(first, 'CREATE TABLE tx_mix_table (id INT64 PRIMARY KEY, amount INT64)')
    command(first, 'INSERT INTO tx_mix_table (id, amount) VALUES (1, 10)')
    command(first, 'CREATE KV tx_mix_kv (INT64)')
    command(first, "PUT INTO tx_mix_kv KEY 'seed' VALUE 100")
    command(first, 'CREATE STREAM tx_mix_stream (amount INT64 NOT NULL) WITH (read_rows=16)')
    command(first, 'PRODUCE INTO tx_mix_stream VALUES (5)')
    command(first, "CREATE QUEUE tx_mix_queue (amount INT64 NOT NULL) WITH (lease_duration='5m', max_lease_duration='10m', max_attempts=3)")
    command(first, 'ENQUEUE INTO tx_mix_queue VALUES (7)')

    group61 = catalog_native('stream-assign', 'tx_mix_stream', 61, 8601)
    consumed61 = workload_rows(first, f"CONSUME amount FROM tx_mix_stream GROUP X'{stream_handle(group61).hex()}' WAIT '1s'")
    assert [signed_cell(r[0]) for r in consumed61[0]] == [5]
    sph61 = sph1_hex(consumed61)
    claimed0 = workload_rows(first, "CLAIM amount, _receipt_handle FROM tx_mix_queue WITH LEASE '5m'")
    assert [signed_cell(r[0]) for r in claimed0[0]] == [7]
    ack0 = queue_receipt_hex(claimed0[0][0][1])

    # 1. Mixed Table + KV + Stream + Queue transaction with savepoint rollback and lost COMMIT reply.
    prior_losses = faults.transaction_reply_losses
    command(first, 'BEGIN ISOLATION LEVEL SERIALIZABLE')
    put1, _ = command(first, "PUT INTO tx_mix_kv KEY 'k1' VALUE 11", 'provisional')
    assert put1['changed'] == 1 and put1.get('workload') is None
    put_seed, _ = command(first, "PUT INTO tx_mix_kv KEY 'seed' VALUE 101 IF PRESENT", 'provisional')
    assert put_seed['changed'] == 1
    assert kv_rows(first, "GET FROM tx_mix_kv KEY 'k1'") == [('k1', 11)]
    assert kv_rows(second, "GET FROM tx_mix_kv KEY 'k1'") == []
    assert kv_rows(second, "GET FROM tx_mix_kv KEY 'seed'") == [('seed', 100)]
    command(first, 'UPDATE tx_mix_table SET amount=20 WHERE id=1', 'provisional')
    prod1, _ = command(first, 'PRODUCE INTO tx_mix_stream VALUES (50)', 'provisional')
    assert prod1['changed'] == 1 and prod1.get('workload') is None
    off1, _ = command(first, f"COMMIT OFFSET ON STREAM tx_mix_stream RECEIPT X'{sph61}'", 'provisional')
    assert off1['changed'] == 0 and off1.get('workload') is None
    enq1, _ = command(first, 'ENQUEUE INTO tx_mix_queue VALUES (70)', 'provisional')
    assert enq1['changed'] == 1 and enq1.get('workload') is None
    ack1, _ = command(first, f"ACK ON QUEUE tx_mix_queue RECEIPT X'{ack0}'", 'provisional')
    assert ack1['changed'] == 0 and ack1.get('workload') is None

    command(first, 'SAVEPOINT inner_mix')
    command(first, "PUT INTO tx_mix_kv KEY 'k1' VALUE 999", 'provisional')
    command(first, "DELETE FROM tx_mix_kv KEY 'seed'", 'provisional')
    command(first, 'UPDATE tx_mix_table SET amount=999 WHERE id=1', 'provisional')
    command(first, 'PRODUCE INTO tx_mix_stream VALUES (999)', 'provisional')
    command(first, 'ENQUEUE INTO tx_mix_queue VALUES (999)', 'provisional')
    assert kv_rows(first, "GET FROM tx_mix_kv KEY 'k1'") == [('k1', 999)]
    assert kv_rows(first, "GET FROM tx_mix_kv KEY 'seed'") == []
    command(first, 'ROLLBACK TO SAVEPOINT inner_mix')
    assert kv_rows(first, "GET FROM tx_mix_kv KEY 'k1'") == [('k1', 11)]
    assert kv_rows(first, "GET FROM tx_mix_kv KEY 'seed'") == [('seed', 101)]
    assert rows(first, 'SELECT amount FROM tx_mix_table WHERE id=1')[0] == [[20]]
    # Monotonic statement sequence across savepoint rollback.
    command(first, "PUT INTO tx_mix_kv KEY 'temp' VALUE 22", 'provisional')
    command(first, "DELETE FROM tx_mix_kv KEY 'temp'", 'provisional')
    assert kv_rows(first, "GET FROM tx_mix_kv KEY 'temp'") == []

    # Pre-commit external invisibility on state participants without mutating log frontiers.
    assert rows(second, 'SELECT amount FROM tx_mix_table WHERE id=1')[0] == [[10]]
    assert kv_rows(second, "GET FROM tx_mix_kv KEY 'k1'") == []
    assert kv_rows(second, "GET FROM tx_mix_kv KEY 'seed'") == [('seed', 100)]

    faults.fail_transaction_once = True
    committed, commit_token = command(first, 'COMMIT')
    assert committed['transaction']['evidence']['decided']['decision']['outcome'] == 'committed'
    assert faults.transaction_reply_losses == prior_losses + 1
    repeat_commit, _ = command(first, 'COMMIT', token=commit_token)
    assert repeat_commit['transaction']['evidence']['decided']['decision'] == committed['transaction']['evidence']['decided']['decision']

    assert rows(second, 'SELECT amount FROM tx_mix_table WHERE id=1')[0] == [[20]]
    assert kv_rows(second, "GET FROM tx_mix_kv KEY 'k1'") == [('k1', 11)]
    assert kv_rows(second, "GET FROM tx_mix_kv KEY 'seed'") == [('seed', 101)]
    assert kv_rows(second, "GET FROM tx_mix_kv KEY 'temp'") == []
    assert [signed_cell(r[0]) for r in workload_rows(second, "CONSUME amount FROM tx_mix_stream WAIT '1ms'")[0]] == [5, 50]
    group61['group']['next'] = 1
    consumed61_after = workload_rows(second, f"CONSUME amount FROM tx_mix_stream GROUP X'{stream_handle(group61).hex()}' WAIT '1s'")
    assert [signed_cell(r[0]) for r in consumed61_after[0]] == [50]
    sph61_pg = sph1_hex(consumed61_after)
    claimed_after = workload_rows(second, "CLAIM amount, _receipt_handle FROM tx_mix_queue WITH LEASE '5m'")
    assert [signed_cell(r[0]) for r in claimed_after[0]] == [70]
    ack_pg = queue_receipt_hex(claimed_after[0][0][1])

    # 1b. Pre-commit Stream/Queue invisibility, concurrent frontier conflict, and explicit ROLLBACK.
    command(first, 'BEGIN ISOLATION LEVEL SERIALIZABLE')
    command(first, "PUT INTO tx_mix_kv KEY 'uncommitted' VALUE 99", 'provisional')
    command(first, 'UPDATE tx_mix_table SET amount=99 WHERE id=1', 'provisional')
    command(first, 'PRODUCE INTO tx_mix_stream VALUES (990)', 'provisional')
    command(first, 'ENQUEUE INTO tx_mix_queue VALUES (991)', 'provisional')
    assert [signed_cell(r[0]) for r in workload_rows(second, "CONSUME amount FROM tx_mix_stream WAIT '1ms'")[0]] == [5, 50]
    assert workload_rows(second, "CLAIM amount FROM tx_mix_queue WITH LEASE '1s'")[0] == []
    conflict_abort, _ = command(first, 'COMMIT', 'rejected')
    assert conflict_abort['transaction']['evidence']['decided']['decision']['outcome'] == 'aborted'
    assert kv_rows(second, "GET FROM tx_mix_kv KEY 'uncommitted'") == []
    assert rows(second, 'SELECT amount FROM tx_mix_table WHERE id=1')[0] == [[20]]

    command(first, 'BEGIN')
    command(first, "PUT INTO tx_mix_kv KEY 'rolled_back' VALUE 88", 'provisional')
    command(first, 'PRODUCE INTO tx_mix_stream VALUES (880)', 'provisional')
    command(first, 'ENQUEUE INTO tx_mix_queue VALUES (881)', 'provisional')
    command(first, 'ROLLBACK')
    assert kv_rows(second, "GET FROM tx_mix_kv KEY 'rolled_back'") == []
    assert [signed_cell(r[0]) for r in workload_rows(second, "CONSUME amount FROM tx_mix_stream WAIT '1ms'")[0]] == [5, 50]
    assert workload_rows(second, "CLAIM amount FROM tx_mix_queue WITH LEASE '1s'")[0] == []

    # 2. Fail-closed refusals inside BEGIN without silent autocommit.
    command(first, 'BEGIN')
    command(first, 'SAVEPOINT unsupported_guard')
    for unsupported in (
        'PRODUCE INTO tx_mix_stream VALUES (1) RETURNING amount',
        'ENQUEUE INTO tx_mix_queue VALUES (1) RETURNING amount',
        'CONSUME amount FROM tx_mix_stream',
        'SELECT amount FROM STREAM_SLICE(tx_mix_stream, PARTITION 0, OFFSET 0 TO 1)',
        "CLAIM amount FROM tx_mix_queue WITH LEASE '1s'",
        f"NACK ON QUEUE tx_mix_queue RECEIPT X'{ack_pg}'",
        f"EXTEND LEASE ON QUEUE tx_mix_queue RECEIPT X'{ack_pg}' BY '5s'",
        'CREATE KV tx_bad_kv (INT64)',
        'ALTER STREAM tx_mix_stream SET (read_rows=8)',
        'DROP QUEUE tx_mix_queue',
    ):
        err = first.call(dict(execute=dict(sql=unsupported, token=list(os.urandom(16)))), error=('UnsupportedTransactionStatement', 'UnsupportedLogTransaction'))['err']
        assert err['sqlstate'] == list(b'0A000'), (unsupported, err)
        assert first.call('context')['context']['transaction'] is not None
        command(first, 'ROLLBACK TO SAVEPOINT unsupported_guard')
    command(first, 'ROLLBACK')

    # 3. Statement-time structured refusals and commit-time fenced/expired receipt aborts with zero visibility.
    command(first, 'BEGIN')
    command(first, "PUT INTO tx_mix_kv KEY 'fenced_q' VALUE 1", 'provisional')
    refused_q, _ = command(first, f"ACK ON QUEUE tx_mix_queue RECEIPT X'{ack0}'", 'rejected')
    assert refused_q['transaction']['evidence']['statement']['refusal'] == 'lease_fenced'
    failed_q = first.call(dict(execute=dict(sql='COMMIT', token=list(os.urandom(16)))), error='SqlTransactionFailed')['err']
    assert failed_q['sqlstate'] == list(b'25P02')
    command(first, 'ROLLBACK')
    assert kv_rows(second, "GET FROM tx_mix_kv KEY 'fenced_q'") == []

    group62 = catalog_native('stream-assign', 'tx_mix_stream', 62, 8602)
    consumed62 = workload_rows(first, f"CONSUME amount FROM tx_mix_stream GROUP X'{stream_handle(group62).hex()}' LIMIT 1 WAIT '1s'")
    sph62_stale = sph1_hex(consumed62)
    group62_live = catalog_native('stream-assign', 'tx_mix_stream', 62, 8603)
    command(first, 'BEGIN')
    command(first, "PUT INTO tx_mix_kv KEY 'fenced_s' VALUE 1", 'provisional')
    refused_s, _ = command(first, f"COMMIT OFFSET ON STREAM tx_mix_stream RECEIPT X'{sph62_stale}'", 'rejected')
    assert refused_s['transaction']['evidence']['statement']['refusal'] == 'offset_conflict'
    command(first, 'ROLLBACK')
    assert kv_rows(second, "GET FROM tx_mix_kv KEY 'fenced_s'") == []

    consumed62_live = workload_rows(first, f"CONSUME amount FROM tx_mix_stream GROUP X'{stream_handle(group62_live).hex()}' LIMIT 1 WAIT '1s'")
    sph62_live = sph1_hex(consumed62_live)
    command(first, 'BEGIN')
    command(first, "PUT INTO tx_mix_kv KEY 'fenced_s_commit' VALUE 1", 'provisional')
    command(first, f"COMMIT OFFSET ON STREAM tx_mix_stream RECEIPT X'{sph62_live}'", 'provisional')
    catalog_native('stream-assign', 'tx_mix_stream', 62, 8605)
    aborted_s, _ = command(first, 'COMMIT', 'rejected')
    assert aborted_s['transaction']['evidence']['decided']['decision']['outcome'] == 'aborted'
    assert kv_rows(second, "GET FROM tx_mix_kv KEY 'fenced_s_commit'") == []

    command(first, "CREATE QUEUE tx_short_queue (amount INT64 NOT NULL) WITH (lease_duration='6s', max_attempts=4)")
    command(first, 'ENQUEUE INTO tx_short_queue VALUES (9), (10)')
    stmt_exp_claim = workload_rows(first, "CLAIM amount, _receipt_handle FROM tx_short_queue LIMIT 1 WITH LEASE '150ms'")
    stmt_exp_ack = queue_receipt_hex(stmt_exp_claim[0][0][1])
    time.sleep(0.5)
    command(first, 'BEGIN')
    command(first, "PUT INTO tx_mix_kv KEY 'expired_q_stmt' VALUE 1", 'provisional')
    refused_exp, _ = command(first, f"ACK ON QUEUE tx_short_queue RECEIPT X'{stmt_exp_ack}'", 'rejected')
    assert refused_exp['transaction']['evidence']['statement']['refusal'] == 'lease_expired'
    command(first, 'ROLLBACK')
    assert kv_rows(second, "GET FROM tx_mix_kv KEY 'expired_q_stmt'") == []

    short_claim = workload_rows(first, "CLAIM amount, _receipt_handle FROM tx_short_queue LIMIT 1 WITH LEASE '6s'")
    short_ack = queue_receipt_hex(short_claim[0][0][1])
    command(first, 'BEGIN')
    command(first, "PUT INTO tx_mix_kv KEY 'expired_q' VALUE 1", 'provisional')
    command(first, f"ACK ON QUEUE tx_short_queue RECEIPT X'{short_ack}'", 'provisional')
    time.sleep(4.5)
    aborted_exp, _ = command(first, 'COMMIT', 'rejected')
    assert aborted_exp['transaction']['evidence']['decided']['decision']['outcome'] == 'aborted'
    assert kv_rows(second, "GET FROM tx_mix_kv KEY 'expired_q'") == []

    # 4. Least-privilege APPEND-only and SETTLE-only principals without READ, plus revocation before COMMIT.
    command(first, 'CREATE STREAM tx_priv_stream (amount INT64 NOT NULL) WITH (read_rows=16)')
    command(first, 'PRODUCE INTO tx_priv_stream VALUES (1)')
    command(first, "CREATE QUEUE tx_priv_queue (amount INT64 NOT NULL) WITH (lease_duration='5m', max_lease_duration='10m', max_attempts=3)")
    command(first, 'ENQUEUE INTO tx_priv_queue VALUES (2)')
    priv_group = catalog_native('stream-assign', 'tx_priv_stream', 63, 8604)
    priv_consumed = workload_rows(first, f"CONSUME amount FROM tx_priv_stream GROUP X'{stream_handle(priv_group).hex()}' WAIT '1s'")
    priv_sph = sph1_hex(priv_consumed)
    priv_claimed = workload_rows(first, "CLAIM amount, _receipt_handle FROM tx_priv_queue WITH LEASE '5m'")
    priv_ack = queue_receipt_hex(priv_claimed[0][0][1])

    catalog_native('log-grants', 'tx_priv_stream', 'append_only')
    catalog_native('log-grants', 'tx_priv_queue', 'append_only')
    try:
        denied_read = first.call(dict(execute=dict(sql="CONSUME amount FROM tx_priv_stream WAIT '1ms'", token=list(os.urandom(16)))), error='AccessDenied')['err']
        assert denied_read['sqlstate'] == list(b'42501')
        command(first, 'BEGIN')
        command(first, 'SAVEPOINT append_guard')
        for unauthorized in (
            f"ACK ON QUEUE tx_priv_queue RECEIPT X'{priv_ack}'",
            f"COMMIT OFFSET ON STREAM tx_priv_stream RECEIPT X'{priv_sph}'",
        ):
            err = first.call(dict(execute=dict(sql=unauthorized, token=list(os.urandom(16)))), error='AccessDenied')['err']
            assert err['sqlstate'] == list(b'42501'), (unauthorized, err)
            command(first, 'ROLLBACK TO SAVEPOINT append_guard')
        command(first, 'PRODUCE INTO tx_priv_stream VALUES (201)', 'provisional')
        command(first, 'ENQUEUE INTO tx_priv_queue VALUES (301)', 'provisional')
        command(first, "PUT INTO tx_mix_kv KEY 'append_only_ok' VALUE 1", 'provisional')
        catalog_native('log-grants', 'tx_priv_stream', 'inspect_only')
        revoked_token = list(os.urandom(16))
        raw_commit = first.call(dict(execute=dict(sql='COMMIT', token=revoked_token)), allow_error=True)
        while 'operation' in raw_commit:
            assert raw_commit['operation']['phase'] != 'terminal', raw_commit
            raw_commit = first.call(dict(resume=raw_commit['operation']['identity']), allow_error=True)
        denied_commit = raw_commit['err']
        assert denied_commit['code'] == 'AccessDenied' and denied_commit['sqlstate'] == list(b'42501'), denied_commit
        assert kv_rows(second, "GET FROM tx_mix_kv KEY 'append_only_ok'") == []
        catalog_native('log-grants', 'tx_priv_stream', 'append_only')
        committed_priv, _ = command(first, 'COMMIT', token=revoked_token)
        assert committed_priv['transaction']['evidence']['decided']['decision']['outcome'] == 'committed'
        command(first, 'COMMIT', token=revoked_token)
        assert first.call('context')['context']['transaction'] is None
        assert kv_rows(second, "GET FROM tx_mix_kv KEY 'append_only_ok'") == [('append_only_ok', 1)]

        catalog_native('log-grants', 'tx_priv_stream', 'settle_only')
        catalog_native('log-grants', 'tx_priv_queue', 'settle_only')
        denied_read2 = first.call(dict(execute=dict(sql="CONSUME amount FROM tx_priv_stream WAIT '1ms'", token=list(os.urandom(16)))), error='AccessDenied')['err']
        assert denied_read2['sqlstate'] == list(b'42501')
        command(first, 'BEGIN')
        command(first, 'SAVEPOINT settle_guard')
        for unauthorized in (
            'PRODUCE INTO tx_priv_stream VALUES (999)',
            'ENQUEUE INTO tx_priv_queue VALUES (999)',
        ):
            err = first.call(dict(execute=dict(sql=unauthorized, token=list(os.urandom(16)))), error='AccessDenied')['err']
            assert err['sqlstate'] == list(b'42501'), (unauthorized, err)
            command(first, 'ROLLBACK TO SAVEPOINT settle_guard')
        command(first, f"COMMIT OFFSET ON STREAM tx_priv_stream RECEIPT X'{priv_sph}'", 'provisional')
        command(first, f"ACK ON QUEUE tx_priv_queue RECEIPT X'{priv_ack}'", 'provisional')
        command(first, "PUT INTO tx_mix_kv KEY 'settle_only_ok' VALUE 1", 'provisional')
        command(first, 'COMMIT')
        assert kv_rows(second, "GET FROM tx_mix_kv KEY 'settle_only_ok'") == [('settle_only_ok', 1)]
    finally:
        catalog_native('log-grants', 'tx_priv_stream', 'owner')
        catalog_native('log-grants', 'tx_priv_queue', 'owner')

    assert [signed_cell(r[0]) for r in workload_rows(second, "CONSUME amount FROM tx_priv_stream WAIT '1ms'")[0]] == [1, 201]
    priv_group['group']['next'] = 1
    assert [signed_cell(r[0]) for r in workload_rows(second, f"CONSUME amount FROM tx_priv_stream GROUP X'{stream_handle(priv_group).hex()}' WAIT '1s'")[0]] == [201]
    priv_remaining = workload_rows(second, "CLAIM amount FROM tx_priv_queue WITH LEASE '5m'")
    assert [signed_cell(r[0]) for r in priv_remaining[0]] == [301]

    # 5. PostgreSQL, MySQL, and Console four-caller mixed transactions.
    with psycopg.connect(**postgres) as pg:
        pg.execute('BEGIN')
        try:
            pg.execute('PRODUCE INTO tx_mix_stream VALUES (1) RETURNING amount')
        except psycopg.errors.FeatureNotSupported:
            pass
        else:
            raise AssertionError('RETURNING inside transaction accepted over PostgreSQL')
        assert pg.info.transaction_status == psycopg.pq.TransactionStatus.INERROR
        pg.execute('ROLLBACK')
        pg.execute('BEGIN')
        pg.execute("PUT INTO tx_mix_kv KEY 'pg' VALUE 301")
        assert pg.execute("GET FROM tx_mix_kv KEY 'pg'").fetchall() == [('pg', 301)]
        pg.execute('UPDATE tx_mix_table SET amount=301 WHERE id=1')
        pg.execute('PRODUCE INTO tx_mix_stream VALUES (301)')
        pg.execute(f"COMMIT OFFSET ON STREAM tx_mix_stream RECEIPT X'{sph61_pg}'")
        pg.execute('ENQUEUE INTO tx_mix_queue VALUES (302)')
        pg.execute('SAVEPOINT pg_sp')
        pg.execute("PUT INTO tx_mix_kv KEY 'pg' VALUE 999")
        pg.execute('PRODUCE INTO tx_mix_stream VALUES (999)')
        pg.execute('ROLLBACK TO pg_sp')
        assert pg.execute("GET FROM tx_mix_kv KEY 'pg'").fetchall() == [('pg', 301)]
        pg.execute('ACK ON QUEUE tx_mix_queue RECEIPT %s', (bytes.fromhex(ack_pg),), prepare=True)
        pg.execute('COMMIT')

    group61['group']['next'] = 2
    consumed61_my = workload_rows(second, f"CONSUME amount FROM tx_mix_stream GROUP X'{stream_handle(group61).hex()}' WAIT '1s'")
    assert [signed_cell(r[0]) for r in consumed61_my[0]] == [301]
    sph61_my = sph1_hex(consumed61_my)
    claimed_my = workload_rows(second, "CLAIM amount, _receipt_handle FROM tx_mix_queue WITH LEASE '5m'")
    assert [signed_cell(r[0]) for r in claimed_my[0]] == [302]
    ack_my = queue_receipt_hex(claimed_my[0][0][1])

    with mysql.connector.connect(**mysql_options) as my:
        cursor = my.cursor()
        cursor.execute('START TRANSACTION')
        cursor.execute("PUT INTO tx_mix_kv KEY 'my' VALUE 401")
        cursor.execute("GET FROM tx_mix_kv KEY 'my'")
        assert cursor.fetchall() == [('my', 401)]
        cursor.execute('UPDATE tx_mix_table SET amount=401 WHERE id=1')
        cursor.execute('PRODUCE INTO tx_mix_stream VALUES (401)')
        cursor.execute(f"COMMIT OFFSET ON STREAM tx_mix_stream RECEIPT X'{sph61_my}'")
        cursor.execute('ENQUEUE INTO tx_mix_queue VALUES (402)')
        cursor.execute(f"ACK ON QUEUE tx_mix_queue RECEIPT X'{ack_my}'")
        cursor.execute('SAVEPOINT my_sp')
        cursor.execute("PUT INTO tx_mix_kv KEY 'my' VALUE 999")
        cursor.execute('ENQUEUE INTO tx_mix_queue VALUES (999)')
        cursor.execute('ROLLBACK TO my_sp')
        cursor.execute("GET FROM tx_mix_kv KEY 'my'")
        assert cursor.fetchall() == [('my', 401)]
        cursor.execute('COMMIT')
        cursor.close()

    group61['group']['next'] = 3
    consumed61_cli = workload_rows(second, f"CONSUME amount FROM tx_mix_stream GROUP X'{stream_handle(group61).hex()}' WAIT '1s'")
    assert [signed_cell(r[0]) for r in consumed61_cli[0]] == [401]
    sph61_cli = sph1_hex(consumed61_cli)
    claimed_cli = workload_rows(second, "CLAIM amount, _receipt_handle FROM tx_mix_queue WITH LEASE '5m'")
    assert [signed_cell(r[0]) for r in claimed_cli[0]] == [402]
    ack_cli = queue_receipt_hex(claimed_cli[0][0][1])

    consumer = root / 'transaction-mixed-console'
    consumer.mkdir()
    home = consumer / 'home'
    home.mkdir()
    password = consumer / 'password'
    password.write_text('proof-password')
    password.chmod(0o600)
    config = consumer / 'connection.yaml'
    config.write_text(f'version: 1\nendpoint: https://localhost:{port}\naccount: proof\ndatabase: data\nauthentication: scram\nca_file: {root/"certificate.pem"}\npassword_file: {password}\nformat: table\n')
    script = consumer / 'mixed.sql'
    script.write_text(
        "BEGIN;\n"
        "PUT INTO tx_mix_kv KEY 'cli' VALUE 501;\n"
        "GET FROM tx_mix_kv KEY 'cli';\n"
        "UPDATE tx_mix_table SET amount=501 WHERE id=1;\n"
        "PRODUCE INTO tx_mix_stream VALUES (501);\n"
        f"COMMIT OFFSET ON STREAM tx_mix_stream RECEIPT X'{sph61_cli}';\n"
        "ENQUEUE INTO tx_mix_queue VALUES (502);\n"
        f"ACK ON QUEUE tx_mix_queue RECEIPT X'{ack_cli}';\n"
        "COMMIT;\n"
    )
    rendered = subprocess.run([binary, 'console', '--config', str(config), '--no-rc', '-f', str(script)],
                              cwd=consumer, env={'PATH': '/unavailable', 'HOME': str(home), 'LANG': 'C'},
                              capture_output=True, text=True, timeout=180)
    assert rendered.returncode == 0, (rendered.stdout, rendered.stderr)
    assert 'Transaction workspace (provisional rows).' in rendered.stdout and '501' in rendered.stdout, rendered.stdout
    assert 'Transaction committed.' in rendered.stdout, rendered.stdout

    assert rows(second, 'SELECT amount FROM tx_mix_table WHERE id=1')[0] == [[501]]
    assert kv_rows(second, "GET FROM tx_mix_kv KEY 'cli'") == [('cli', 501)]
    assert [signed_cell(r[0]) for r in workload_rows(second, "CONSUME amount FROM tx_mix_stream WAIT '1ms'")[0]] == [5, 50, 301, 401, 501]
    group61['group']['next'] = 4
    assert [signed_cell(r[0]) for r in workload_rows(second, f"CONSUME amount FROM tx_mix_stream GROUP X'{stream_handle(group61).hex()}' WAIT '1s'")[0]] == [501]
    final_queue = workload_rows(second, "CLAIM amount FROM tx_mix_queue WITH LEASE '5m'")
    assert [signed_cell(r[0]) for r in final_queue[0]] == [502]

    first.close()
    second.close()
    print(json.dumps(dict(profile='installed_mixed_sql_transactions', native=True, postgres=True,
                          mysql=True, console=True, savepoint_rollback=True,
                          append_only_principal=True, settle_only_principal=True,
                          revocation_recheck=True, expired_and_fenced_receipts=True,
                          unsupported_statements_refused=True, lost_commit_reply=True)), flush=True)

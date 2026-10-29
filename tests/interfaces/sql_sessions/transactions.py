"""Independent transaction histories through installed native, PG and MySQL clients."""
import json
import os
import time
import psycopg
import mysql.connector
from interfaces.sql_sessions.native import Client
from runner.capture import provenance
from runner.paths import ROOT


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


def run(root, port, postgres, mysql_options, restart, faults, authority):
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
    limited = Client(root, port).open()
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

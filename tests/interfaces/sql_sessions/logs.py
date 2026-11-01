"""Installed declaration SQL, exact metadata and original token recovery."""
import json
import os
from interfaces.sql_sessions.native import Client
from interfaces.sql_sessions.storage import text


def run(root, port, postgres, mysql_options, restart, authorize):
    first = Client(root, port).open()
    for invalid, code, state in (
        ('CREATE STREAM invalid_key (id BIGINT PRIMARY KEY)', 'UnsupportedLogPrimaryKey', b'0A000'),
        ("CREATE QUEUE invalid_policy (id BIGINT) WITH (claim_rows=65)", 'InvalidLogLimits', b'22023'),
        ("CREATE STREAM duplicate_policy (id BIGINT) WITH (retention='1s', retention='2s')", 'DuplicateLogOption', b'22023'),
    ):
        refused = first.call(dict(execute=dict(sql=invalid, token=list(os.urandom(16)))), error=code)['err']
        assert refused['sqlstate'] == list(state), refused
    token = list(os.urandom(16))
    columns = ', '.join(f'c{i} BIGINT' for i in range(40))
    sql = f'CREATE STREAM sql_events ({columns}) PARTITIONS 2'
    saved = root / 'log-declaration-original.json'
    saved.write_text(json.dumps(dict(definition=first.definition, sql=sql, token=token)))
    accepted = first.execute(sql, token)['operation']
    identity = accepted['identity']
    saved.write_text(json.dumps(dict(definition=first.definition, sql=sql, token=token, identity=identity)))
    original_bytes = saved.read_bytes()
    first.close()
    restart()
    first = Client(root, port).open()
    original = json.loads(saved.read_bytes())
    assert saved.read_bytes() == original_bytes and original['definition'] == first.definition
    recovered = first.terminal(first.execute(original['sql'], original['token'])['operation'])
    assert recovered['identity'] == original['identity']
    assert recovered['command'] == 'create_stream', recovered

    def completed(statement, kind, client=None):
        client = client or first
        result = client.terminal(client.execute(statement, list(os.urandom(16)))['operation'])
        assert result['command'] == kind, result
        return result

    desc = first.execute('DESCRIBE STREAM sql_events')['batch']
    assert not desc['complete'] and len(desc['rows']) == 32, desc
    assert desc['observation']['metadata']['consistency'] == 'exact_definitions', desc
    assert len(desc['observation']['metadata']['definitions']) == 1
    assert first.call(dict(fetch=dict(cursor=desc['cursor'], batch=0)))['batch'] == desc
    last = first.call(dict(fetch=dict(cursor=desc['cursor'], batch=1)))['batch']
    assert last['complete'] and len(last['rows']) == 8 and last['completion']['rows'] == 40
    first.call(dict(close_result=last['cursor']))

    completed('CREATE QUEUE sql_failed (entity BIGINT NOT NULL, payload TEXT)', 'create_queue')
    destination = first.execute('SHOW QUEUE sql_failed')['batch']
    destination_definition = destination['observation']['metadata']['definitions'][0]
    first.call(dict(close_result=destination['cursor']))
    completed("CREATE QUEUE sql_work (entity BIGINT NOT NULL, payload TEXT) PARTITION BY HASH (entity) PARTITIONS 2 WITH (mode='key_fifo', lease_duration='5s', dead_letter_queue='sql_failed')", 'create_queue')
    shown = first.execute('SHOW QUEUE sql_work')['batch']
    policy = json.loads(text(shown['rows'][0][3]))
    assert policy['partitioning']['count'] == 2 and policy['policy']['queue']['ordering'] == 'key_fifo'
    assert policy['retention']['max_age_ms'] is None
    assert policy['policy']['queue']['dead_letter'] == destination_definition
    assert shown['complete'] and shown['completion']['rows'] == 1
    first.call(dict(close_result=shown['cursor']))
    prepared = first.call(dict(prepare=dict(sql='SHOW QUEUE sql_work')))['described']['statement']
    stale = first.execute('SHOW QUEUE sql_work')['batch']
    writer = Client(root, port).open()
    completed("ALTER QUEUE sql_work SET (retention='1d', max_attempts=9)", 'alter_queue', writer)
    writer.close()
    first.call(dict(fetch=dict(cursor=stale['cursor'], batch=stale['batch'])), error='CatalogDefinitionChanged')
    first.call(dict(fetch=dict(cursor=stale['cursor'], batch=stale['batch'])), error='SqlResultIncomplete')
    first.call(dict(execute=dict(statement=prepared)), error='CatalogDefinitionChanged')
    first.call(dict(release=prepared))
    changed = first.execute('SHOW QUEUE sql_work')['batch']
    changed_policy = json.loads(text(changed['rows'][0][3]))
    assert changed_policy['retention']['max_age_ms'] == 86400000
    assert changed_policy['policy']['queue']['maximum_attempts'] == 9
    assert changed_policy['policy']['queue']['dead_letter'] == destination_definition
    first.call(dict(close_result=changed['cursor']))
    completed('ALTER STREAM sql_events RENAME TO sql_history', 'alter_stream')
    after = first.execute('SHOW STREAM sql_history')['batch']
    assert after['observation']['metadata']['definitions'][0]['object'] == desc['observation']['metadata']['definitions'][0]['object']
    first.call(dict(close_result=after['cursor']))

    for statement in ('SHOW STREAM sql_history', 'DESCRIBE STREAM sql_history', 'SHOW QUEUE sql_work', 'DESCRIBE QUEUE sql_work'):
        buffered = first.execute(statement)['batch']
        authorize(False)
        try:
            refused = first.call(dict(fetch=dict(cursor=buffered['cursor'], batch=buffered['batch'])), error='AccessDenied')['err']
            assert refused['sqlstate'] == list(b'42501')
        finally:
            authorize(True)
        first.call(dict(fetch=dict(cursor=buffered['cursor'], batch=buffered['batch'])), error='SqlResultIncomplete')
    first.close()

    import psycopg
    import mysql.connector
    with psycopg.connect(**postgres) as wire:
        with wire.cursor() as cursor:
            cursor.execute('CREATE STREAM pg_events (value BIGINT)')
            assert cursor.statusmessage == 'CREATE STREAM'
            cursor.execute('SHOW STREAM pg_events')
            assert len(cursor.fetchall()) == 1
            cursor.execute('DROP STREAM pg_events')
            assert cursor.statusmessage == 'DROP STREAM'
    with mysql.connector.connect(**mysql_options) as wire:
        with wire.cursor() as cursor:
            cursor.execute('CREATE QUEUE `mysql_work` (value BIGINT)')
            cursor.execute('DESCRIBE QUEUE `mysql_work`')
            assert len(cursor.fetchall()) == 1
            cursor.execute('DROP QUEUE `mysql_work`')
    first = Client(root, port).open()
    completed('DROP STREAM sql_history', 'drop_stream')
    completed('DROP QUEUE sql_work', 'drop_queue')
    first.close()
    print(json.dumps(dict(profile='sql_log_declarations', native=True, postgres=True, mysql=True,
                          original_token_after_replacement=True, metadata_batches=[32, 8],
                          current_disclosure_authorization=True, passed=True)), flush=True)

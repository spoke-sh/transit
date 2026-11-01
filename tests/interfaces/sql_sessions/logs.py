"""Installed declaration SQL, exact metadata and original token recovery."""
import json
import os
import struct
import subprocess
from interfaces.sql_sessions.native import Client
from interfaces.sql_sessions.storage import text, unsigned


def run(root, port, postgres, mysql_options, restart, authorize, console):
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

    empty = first.execute('SHOW QUEUES')['batch']
    assert empty['rows'] == [] and empty['complete'] and empty['completion']['rows'] == 0
    assert empty['observation']['metadata']['consistency'] == 'independent_observations'
    authorize(False)
    try:
        first.call(dict(fetch=dict(cursor=empty['cursor'], batch=0)), error='AccessDenied')
    finally:
        authorize(True)
    first.call(dict(fetch=dict(cursor=empty['cursor'], batch=0)), error='SqlResultIncomplete')

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
    assert unsigned(shown['rows'][0][2]) == 2
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

    # Native metadata pages contain at most eight objects. Cross those pages
    # and the 32-row SQL delivery boundary without collecting a catalog first.
    expected = {'sql_history'}
    for index in range(34):
        name = f'listed_stream_{index:02d}'
        completed(f'CREATE STREAM {name} (value BIGINT)', 'create_stream')
        expected.add(name)
    listing = first.execute('SHOW STREAMS')['batch']
    assert len(listing['rows']) == 32 and not listing['complete']
    assert listing['observation']['metadata']['consistency'] == 'independent_observations'
    assert listing['observation']['metadata']['definitions'] == []
    assert first.call(dict(fetch=dict(cursor=listing['cursor'], batch=0)))['batch'] == listing
    rest = first.call(dict(fetch=dict(cursor=listing['cursor'], batch=1)))['batch']
    assert rest['complete'] and len(rest['rows']) == 3 and rest['completion']['rows'] == 35
    assert {text(row[0]) for row in listing['rows'] + rest['rows']} == expected
    first.call(dict(close_result=rest['cursor']))
    stale_listing = first.execute('SHOW STREAMS')['batch']
    revised = text(stale_listing['rows'][0][0])
    writer = Client(root, port).open()
    completed(f"ALTER STREAM {revised} SET (retention='1h')", 'alter_stream', writer)
    writer.close()
    first.call(dict(fetch=dict(cursor=stale_listing['cursor'], batch=0)), error='CatalogDefinitionChanged')
    first.call(dict(fetch=dict(cursor=stale_listing['cursor'], batch=0)), error='SqlResultIncomplete')
    for statement in ('SHOW STREAMS', 'SHOW QUEUES'):
        protected = first.execute(statement)['batch']
        authorize(False)
        try:
            first.call(dict(fetch=dict(cursor=protected['cursor'], batch=0)), error='AccessDenied')
        finally:
            authorize(True)
        first.call(dict(fetch=dict(cursor=protected['cursor'], batch=0)), error='SqlResultIncomplete')
    first.close()

    import psycopg
    import mysql.connector
    with psycopg.connect(**postgres) as wire:
        with wire.cursor() as cursor:
            cursor.execute('CREATE STREAM pg_events (value BIGINT)')
            assert cursor.statusmessage == 'CREATE STREAM'
            cursor.execute('SHOW STREAM pg_events')
            published, = cursor.fetchall()
            assert int(published[2]) == 1
            assert json.loads(published[3])['partitioning']['count'] == 1
            cursor.execute('SHOW STREAMS')
            assert {row[0] for row in cursor.fetchall()} == expected | {'pg_events'}
            cursor.execute('DROP STREAM pg_events')
            assert cursor.statusmessage == 'DROP STREAM'
    with mysql.connector.connect(**mysql_options) as wire:
        with wire.cursor() as cursor:
            cursor.execute('CREATE QUEUE `mysql_work` (value BIGINT)')
            cursor.execute('DESCRIBE QUEUE `mysql_work`')
            column, = cursor.fetchall()
            assert column[0] == 'value' and column[2] == 1 and column[3] == 0
            cursor.execute('SHOW QUEUES')
            assert {row[0] for row in cursor.fetchall()} == {'sql_work', 'sql_failed', 'mysql_work'}
            cursor.execute('DROP QUEUE `mysql_work`')
    consumer = root / 'log-console'
    consumer.mkdir()
    home = consumer / 'home'
    home.mkdir()
    password = consumer / 'password'
    password.write_text('proof-password')
    password.chmod(0o600)
    config = consumer / 'connection.yaml'
    config.write_text(f'version: 1\nendpoint: https://localhost:{port}\naccount: proof\ndatabase: data\nauthentication: scram\nca_file: {root/"certificate.pem"}\npassword_file: {password}\nformat: json\n')
    script = consumer / 'declarations.sql'
    script.write_text("CREATE STREAM console_events (value VARCHAR(12));\nSHOW STREAM console_events;\nDESCRIBE STREAM console_events;\nALTER STREAM console_events SET (retention='1h');\nDROP STREAM console_events;\n")
    rendered = subprocess.run([console, 'console', '--config', str(config), '--no-rc', '-f', str(script)],
                              cwd=consumer, env={'PATH': '/unavailable', 'HOME': str(home), 'LANG': 'C'},
                              capture_output=True, text=True, timeout=180)
    assert rendered.returncode == 0, (rendered.stdout, rendered.stderr)
    assert rendered.stdout.count('"complete_coverage":true') == 2, rendered.stdout
    first = Client(root, port).open()
    first.call(dict(execute=dict(sql='SHOW STREAM console_events')), error='CatalogNameNotFound')
    completed('DROP STREAM sql_history', 'drop_stream')
    completed('DROP QUEUE sql_work', 'drop_queue')
    first.close()
    print(json.dumps(dict(profile='sql_log_declarations', native=True, postgres=True, mysql=True, console=True,
                          original_token_after_replacement=True, metadata_batches=[32, 8],
                          listing_batches=[32, 3], empty_listing=True,
                          current_disclosure_authorization=True, passed=True)), flush=True)
    appends(root, port, postgres, mysql_options, restart, authorize, console, config, consumer, home)


def appends(root, port, postgres, mysql_options, restart, authorize, console, config, consumer, home):
    """Admission and original result delivery use independent row/offset oracles."""
    from query.logical.fuze_types import descriptor
    import psycopg
    import mysql.connector

    client = Client(root, port).open()

    def command(sql):
        result = client.terminal(client.execute(sql, list(os.urandom(16)))['operation'])
        assert result['result_kind'] == 'command', result
        return result

    command('CREATE STREAM append_events (value BIGINT NOT NULL, label TEXT DEFAULT \'default\') WITH (read_rows=16)')
    command('CREATE QUEUE append_work (value BIGINT NOT NULL) WITH (append_rows=1)')
    command('CREATE STREAM append_manual (value BIGINT) PARTITIONS 2')
    refused = client.call(
        dict(execute=dict(sql='PRODUCE INTO append_manual VALUES (1)', token=list(os.urandom(16)))), error='LogPartitionRequired')['err']
    assert refused['sqlstate'] == list(b'22023'), refused
    budget = client.call(dict(execute=dict(sql='ENQUEUE INTO append_work VALUES (1), (2)', token=list(os.urandom(16)))), error='LogAppendLimitExceeded')['err']
    assert budget['sqlstate'] == list(b'54000'), budget
    # No accepted append precedes offset zero. A preparation or routing refusal
    # cannot silently append a prefix or move a partition's event offset.
    operation = command('PRODUCE INTO append_manual VALUES (1) PARTITION 1')
    assert operation['command'] == 'produce' and operation['matched'] == operation['changed'] == 1

    sql = 'PRODUCE INTO append_events (value) VALUES ' + ','.join(f'({i})' for i in range(65)) + ' RETURNING value, label, _partition, _offset'
    original = dict(definition=client.definition, sql=sql, token=list(os.urandom(16)))
    saved = root / 'sql-append-original.json'
    saved.write_text(json.dumps(original))
    operation = client.terminal(client.execute(sql, original['token'])['operation'])
    assert operation['command'] == 'produce' and operation['result_kind'] == 'rows'
    assert operation['matched'] == operation['changed'] == 65
    original['identity'] = operation['identity']
    saved.write_text(json.dumps(original))
    original_bytes = saved.read_bytes()

    def rows(owner, identity):
        batch = owner.call(dict(result=identity))['batch']
        observation, values, sizes = batch['observation'], [], []
        while True:
            assert owner.call(dict(fetch=dict(cursor=batch['cursor'], batch=batch['batch'])))['batch'] == batch
            values.extend(batch['rows'])
            sizes.append(len(batch['rows']))
            if batch['complete']:
                assert batch['completion']['rows'] == len(values)
                break
            batch = owner.call(dict(fetch=dict(cursor=batch['cursor'], batch=batch['batch'] + 1)))['batch']
        owner.call(dict(close_result=batch['cursor']))
        return values, sizes, observation

    values, sizes, observation = rows(client, original['identity'])
    assert sizes == [32, 32, 1], sizes
    assert [(unsigned(row[0]), text(row[1]), unsigned(row[2]), unsigned(row[3])) for row in values] == [(i, 'default', 0, i) for i in range(65)]
    client.close()
    restart()
    client = Client(root, port).open()
    assert saved.read_bytes() == original_bytes and original['definition'] == client.definition
    recovered = client.terminal(client.call(dict(status=dict(operation=original['identity'])))['operation'])
    assert recovered == operation, (recovered, operation)
    assert rows(client, original['identity']) == (values, sizes, observation)

    queue_sql = 'ENQUEUE INTO append_work VALUES ($1) RETURNING value, _offset'
    prepared = client.call(dict(prepare=dict(sql=queue_sql)))['described']
    kind = descriptor('int64')
    assert prepared['parameters'] == [kind.hex()]
    parameter = (b'FVL1' + struct.pack('<H', len(kind)) + kind + b'\x01\x03' + struct.pack('<q', 17)).hex()
    client.call(dict(execute=dict(statement=prepared['statement'], parameters=[parameter], token=list(os.urandom(16)))), error='SqlTokenRequiresText')
    queued = client.terminal(client.execute(queue_sql, list(os.urandom(16)), parameters=[parameter])['operation'])
    assert queued['command'] == 'enqueue' and queued['changed'] == 1
    queued_rows, queued_sizes, _ = rows(client, queued['identity'])
    assert queued_sizes == [1] and [list(map(unsigned, row)) for row in queued_rows] == [[17, 0]]
    client.call(dict(release=prepared['statement']))
    buffered = client.call(dict(result=original['identity']))['batch']
    authorize(False)
    try:
        client.call(dict(fetch=dict(cursor=buffered['cursor'], batch=0)), error='AccessDenied')
    finally:
        authorize(True)
    client.call(dict(fetch=dict(cursor=buffered['cursor'], batch=0)), error='SqlResultIncomplete')
    client.close()

    with psycopg.connect(**postgres) as wire:
        with wire.cursor() as cursor:
            cursor.execute('PRODUCE INTO append_events (value) VALUES (%s) RETURNING value, label, _offset', (65,), prepare=True)
            assert cursor.fetchall() == [(65, 'default', 65)]
            assert cursor.statusmessage == 'PRODUCE 1'
            cursor.execute('PRODUCE INTO append_events (value) VALUES (%s)', (66,), prepare=True)
            # libpq derives affected-row counts only for its recognized command
            # tags. The custom tag retains the authoritative native count.
            assert cursor.statusmessage == 'PRODUCE 1', cursor.statusmessage
            assert cursor.rowcount == -1, cursor.rowcount
    with mysql.connector.connect(**mysql_options) as wire:
        with wire.cursor(prepared=True) as cursor:
            cursor.execute('ENQUEUE INTO append_work VALUES (%s) RETURNING value, _offset', (18,))
            assert cursor.fetchall() == [(18, 1)]
            cursor.execute('ENQUEUE INTO append_work VALUES (%s)', (19,))
            assert cursor.rowcount == 1
        with wire.cursor() as cursor:
            cursor.execute('ENQUEUE INTO append_work VALUES (20) RETURNING value, _offset')
            assert cursor.fetchall() == [(20, 3)]
    script = consumer / 'appends.sql'
    script.write_text('PRODUCE INTO append_events (value) VALUES (67) RETURNING value, _offset;\nENQUEUE INTO append_work VALUES (21) RETURNING value, _offset;\n')
    rendered = subprocess.run([console, 'console', '--config', str(config), '--no-rc', '-f', str(script)],
                              cwd=consumer, env={'PATH': '/unavailable', 'HOME': str(home), 'LANG': 'C'},
                              capture_output=True, text=True, timeout=180)
    assert rendered.returncode == 0, (rendered.stdout, rendered.stderr)
    assert rendered.stdout.count('"complete_coverage":true') == 2, rendered.stdout
    client = Client(root, port).open()
    # Subsequent offsets independently rule out hidden re-appends while opening,
    # fetching, closing and recovering the prior original results.
    next_stream = client.terminal(client.execute('PRODUCE INTO append_events (value) VALUES (68) RETURNING _offset', list(os.urandom(16)))['operation'])
    next_queue = client.terminal(client.execute('ENQUEUE INTO append_work VALUES (22) RETURNING _offset', list(os.urandom(16)))['operation'])
    assert unsigned(rows(client, next_stream['identity'])[0][0][0]) == 68
    assert unsigned(rows(client, next_queue['identity'])[0][0][0]) == 5
    client.close()
    print(json.dumps(dict(profile='sql_log_appends', native=True, postgres=True, mysql=True, console=True,
                          original_result_after_replacement=True, result_batches=sizes, typed_parameters=True,
                          current_disclosure_authorization=True, no_repeat_append=True, passed=True)), flush=True)

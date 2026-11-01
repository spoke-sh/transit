"""Installed historical catalog binding with independent retained-value oracles."""
import json
import struct

import mysql.connector
import psycopg

from interfaces.sql_sessions.native import Client
from interfaces.sql_sessions.storage import text
from interfaces.sql_sessions.transactions import command, rows
from runner.capture import provenance
from runner.paths import ROOT


def selector(snapshot):
    """Independent canonical spelling; no production encoder is the oracle."""
    owner, content, sources = snapshot['owner'], snapshot['catalog_root'], snapshot['sources_root']
    scope = owner['scope']
    consistency = snapshot['consistency']
    single = isinstance(consistency, dict) and 'single_partition' in consistency
    position = consistency['single_partition'] if single else dict(partition=0, next_lsn=0)
    return (b'THSNAP01' + bytes.fromhex(snapshot['definition'])
            + struct.pack('<6Q', scope['realm'], scope['resource'], scope['catalog'], owner['principal'], owner['operation'], snapshot['branch'])
            + struct.pack('<Q', content['bytes']) + bytes(content['sha256'])
            + struct.pack('<Q', sources['bytes']) + bytes(sources['sha256'])
            + struct.pack('<QBQQ', snapshot['source_count'], 1 if single else 2, position['partition'], position['next_lsn']) + bytes(104)).hex()


def raw(client, sql):
    batch = client.execute(sql)['batch']
    collected = list(batch['rows'])
    observation = batch['observation']
    while not batch['complete']:
        batch = client.call(dict(fetch=dict(cursor=batch['cursor'], batch=batch['batch']+1)))['batch']
        collected.extend(batch['rows'])
    client.call(dict(close_result=batch['cursor']))
    return collected, observation


def companion_expressions(root, port, postgres, mysql_options, restart, catalog):
    """Actual stored values and frozen plans; independent native result bytes."""
    client = Client(root, port).open()
    tzif = (ROOT / 'packages/zig/transit-fuze/src/timezone-fixtures/utc.tzif').read_bytes().hex()
    command(client, f"""CREATE TABLE history_companions (
        id INT64 PRIMARY KEY,
        a DECIMAL(8,2) ROUNDING HALF_EVEN, b DECIMAL(8,2),
        span RANGE<INT64>, next_span RANGE<INT64>,
        x VECTOR(2,FLOAT32) METRIC L2_SQUARED,
        y VECTOR(2,FLOAT32) METRIC L2_SQUARED,
        ts TIMESTAMPTZ TIMEZONE 'Etc/UTC' TZDB 'iana-2025b' TZIF X'{tzif}')""")
    command(client, """INSERT INTO history_companions VALUES
        (1, 1.00, 6.00, '[1,3)', '[3,5)', '[1,2]', '[4,6]', '1969-12-31T23:59:59.999999Z'),
        (2, NULL, 6.00, 'empty', '[3,5)', '[0,0]', '[4,6]', '1970-01-01T00:00:00Z')""")
    retained = catalog('history-retain', 900010, 'history_companions')
    suffix = " AS OF SNAPSHOT '" + retained['selector'] + "'"
    expressions = """SELECT DECIMAL_DIVIDE(a,b,8,2,HALF_EVEN) AS quotient,
        RANGE_ADJACENT(span,next_span) AS adjacent, VECTOR_DISTANCE(x,y) AS distance,
        ts AT TIME ZONE 'Etc/UTC' AS local_time, TIME_BUCKET(ts,1000000,'Etc/UTC') AS bucket
        FROM history_companions WHERE id=1"""
    query = expressions + suffix
    expected = [['03' + (17).to_bytes(16, 'little', signed=True).hex(),
                 '0301', '03' + struct.pack('<d', 25).hex(),
                 '03' + (-1).to_bytes(8, 'little', signed=True).hex(),
                 '03' + (-1000000).to_bytes(8, 'little', signed=True).hex()]]
    saved, observation = raw(client, query)
    assert saved == expected, saved
    sum_sql = 'SELECT SUM(DECIMAL_DIVIDE(a,b,8,2,HALF_EVEN)) AS total FROM history_companions' + suffix
    assert raw(client, sum_sql)[0] == [[expected[0][0]]]
    prepared = client.call(dict(prepare=dict(sql=query)))['described']['statement']
    command(client, 'UPDATE history_companions SET b=0 WHERE id=1')
    client.call(dict(execute=dict(sql=expressions)), error='DivisionByZero')
    # Filtering happens before scalar evaluation, including a zero divisor in
    # rejected rows. NULL remains a distinct encoded state in selected rows.
    safe = 'SELECT DECIMAL_DIVIDE(a,b,8,2,REJECT) AS q FROM history_companions WHERE id=2'
    assert raw(client, safe)[0] == [['01']]
    repeated = client.call(dict(execute=dict(statement=prepared)))['batch']
    assert repeated['complete'] and repeated['rows'] == expected and repeated['observation'] == observation
    client.call(dict(close_result=repeated['cursor']))
    client.call(dict(release=prepared))
    transport_query = 'SELECT RANGE_ADJACENT(span,next_span) AS adjacent, VECTOR_DISTANCE(x,y) AS distance FROM history_companions WHERE id=1' + suffix
    with psycopg.connect(**postgres) as pg:
        assert pg.execute(transport_query).fetchall() == [(True, 25.0)]
        try:
            pg.execute(sum_sql)
        except psycopg.errors.FeatureNotSupported as error:
            assert error.sqlstate == '0A000'
        else:
            raise AssertionError('Unqualified PostgreSQL DECIMAL result profile was admitted')
    with mysql.connector.connect(**mysql_options) as my:
        cursor = my.cursor(prepared=True)
        cursor.execute(transport_query)
        assert cursor.fetchall() == [(1, 25.0)]
        try:
            cursor.execute(sum_sql)
        except mysql.connector.Error as error:
            # ER_NOT_SUPPORTED_YET retains MySQL's vendor SQLSTATE mapping.
            assert (error.errno, error.sqlstate) == (1235, '42000'), error
        else:
            raise AssertionError('Unqualified MySQL DECIMAL result profile was admitted')
        cursor.close()
    client.close()
    restart()
    client = Client(root, port).open()
    assert raw(client, query) == (saved, observation)
    assert raw(client, sum_sql)[0] == [[expected[0][0]]]
    catalog('history-release', 900010)
    command(client, 'DROP TABLE history_companions')
    client.close()
    print(json.dumps(dict(profile='installed_companion_expressions', source=provenance(ROOT),
                          canonical_native_values=True, exact_decimal_sum=True,
                          pinned_timezone=True, prepared_history=True, gateway_restart=True,
                          postgres_mysql_scalar_outputs=True, unsupported_decimal_wire_refuses=True)), flush=True)


def run(root, port, postgres, mysql_options, restart, catalog, faults):
    companion_expressions(root, port, postgres, mysql_options, restart, catalog)
    first = Client(root, port).open()
    command(first, 'CREATE TABLE historical_values (id INT64 PRIMARY KEY, amount INT64)')
    command(first, 'INSERT INTO historical_values VALUES (1, 10), (2, 20)')
    retained = catalog('history-retain', 900001, 'historical_values')
    assert retained['phase'] == 'published' and retained['selector'] == selector(retained['snapshot']), retained
    suffix = " AS OF SNAPSHOT '" + retained['selector'] + "'"
    query = 'SELECT id, amount FROM historical_values' + suffix
    original, basis = rows(first, query)
    assert sorted(original) == [[1, 10], [2, 20]], original
    historical = basis['data']['historical']
    assert historical['snapshot']['owner']['operation'] == 900001 and len(historical['sources']) == 1, basis
    source = historical['sources'][0]
    old_object = source['interpretation']['object']['object']
    prepared = first.call(dict(prepare=dict(sql=query)))['described']['statement']

    # Namespace ownership stays with the fixture administrator; the SQL
    # account keeps only its original Table rights throughout this scenario.
    # A historical schema name resolves inside the selected catalog, even when
    # that live spelling is reused for a different namespace.
    scoped = suffix + ' IN SCHEMA public'
    scoped_query = 'SELECT id, amount FROM historical_values' + scoped
    catalog('namespace-admin', 900020, 'ALTER SCHEMA public RENAME TO history_live')
    catalog('namespace-admin', 900021, 'CREATE SCHEMA public')
    assert rows(first, scoped_query) == (original, basis)
    first.call(dict(execute=dict(sql='SHOW TABLES' + suffix + ' IN SCHEMA history_live')), error='HistoricalObjectNotSelected')
    described, scoped_metadata = raw(first, 'DESCRIBE historical_values' + scoped)
    assert len(described) == 2 and scoped_metadata['metadata']['namespace'] == 1
    with faults.metadata_only() as calls:
        explained, scoped_metadata = raw(first, 'EXPLAIN ' + scoped_query)
    assert calls.get('historical_catalog.namespace', 0) > 0, calls
    assert json.loads(text(explained[0][0]))['executed'] is False
    assert scoped_metadata['metadata']['namespace'] == 1
    assert len(raw(first, 'SHOW TABLES' + scoped)[0]) == 1

    command(first, 'UPDATE historical_values SET amount=99 WHERE id=1')
    command(first, 'ALTER TABLE historical_values ADD COLUMN later INT64 DEFAULT 7')
    projected_query = 'SELECT id, amount, later FROM historical_values' + suffix + ' PROJECTING TO CURRENT'
    projected_rows, projected_basis = rows(first, projected_query)
    assert projected_rows == [[1, 10, 7], [2, 20, 7]], projected_rows
    projected_source = projected_basis['data']['historical']['sources'][0]
    assert projected_source['interpretation'] == source['interpretation']
    assert projected_source['schema'] == source['schema']
    assert projected_source['projection']['target']['object']['object'] == old_object
    projected_statement = first.call(dict(prepare=dict(sql=projected_query)))['described']['statement']
    target = catalog('history-retain', 900011, 'historical_values')
    exact_projection = suffix + " PROJECTING TO SNAPSHOT '" + target['selector'] + "'"
    exact_query = 'SELECT id, amount, later FROM historical_values' + exact_projection
    assert rows(first, exact_query) == (projected_rows, projected_basis)
    with faults.metadata_only() as calls:
        explained, projection_metadata = raw(first, 'EXPLAIN ' + exact_query)
        described, description_metadata = raw(first, 'DESCRIBE historical_values' + exact_projection)
    assert calls.get('schema_projection.prepare', 0) >= 2, calls
    assert [text(row[0]) for row in described] == ['id', 'amount', 'later']
    assert projection_metadata['metadata']['projections'][0] == description_metadata['metadata']['projections'][0]
    assert json.loads(text(explained[0][0]))['executed'] is False
    command(first, 'ALTER TABLE historical_values ALTER COLUMN later SET DEFAULT 9')
    command(first, 'ALTER TABLE historical_values RENAME TO historical_renamed')
    command(first, 'ALTER TABLE historical_renamed DROP COLUMN later')
    projected_repeat = first.call(dict(execute=dict(statement=projected_statement)))['batch']
    assert projected_repeat['complete'] and projected_repeat['observation'] == projected_basis
    first.call(dict(close_result=projected_repeat['cursor']))
    first.call(dict(release=projected_statement))
    assert rows(first, exact_query) == (projected_rows, projected_basis)
    projected_join = 'SELECT a.id, b.later FROM historical_values AS a INNER JOIN historical_values AS b ON a.id=b.id' + exact_projection
    assert rows(first, projected_join)[0] == [[1, 7], [2, 7]]

    command(first, 'CREATE TABLE historical_values (id INT64 PRIMARY KEY, amount INT64)')
    command(first, 'INSERT INTO historical_values VALUES (1, 1000)')
    assert rows(first, 'SELECT id, amount FROM historical_values')[0] == [[1, 1000]]
    assert rows(first, query) == (original, basis)
    first.call(dict(execute=dict(sql='SELECT later FROM historical_values'+suffix)), error='UnknownColumn')
    first.call(dict(execute=dict(sql='SELECT id FROM historical_renamed'+suffix)), error='HistoricalObjectNotSelected')
    description, metadata = raw(first, 'DESCRIBE historical_values'+suffix)
    assert [text(row[0]) for row in description] == ['id', 'amount']
    assert metadata['metadata']['historical']['owner']['operation'] == 900001
    listing, metadata = raw(first, 'SHOW TABLES'+suffix)
    assert [text(row[0]) for row in listing] == ['historical_values'], listing
    with faults.metadata_only() as calls:
        explanation, metadata = raw(first, 'EXPLAIN '+query)
    assert calls.get('historical_catalog.source', 0) > 0, calls
    plan = json.loads(text(explanation[0][0]))
    assert plan['executed'] is False and plan['basis']['owner']['operation'] == 900001, plan
    assert not any(plan['traits']['explain_effects'].values()), plan
    assert plan['traits']['explain_work_bound']['max_source_pins'] == 0, plan
    repeated = first.call(dict(execute=dict(statement=prepared)))['batch']
    assert repeated['complete'] and repeated['observation'] == basis and repeated['completion']['rows'] == 2, repeated
    first.call(dict(close_result=repeated['cursor']))
    first.call(dict(release=prepared))
    # Original retained identity wins even though the live name now means a
    # different object. The proof caller reloads the saved pre-admission intent.
    assert catalog('history-retain', 900001, 'historical_values') == retained

    # The descriptor does not grant data access. Metadata remains separately
    # inspectable while current SELECT is revoked on both original and new names.
    catalog('external-read-grants', 'deny')
    first.call(dict(execute=dict(sql=query)), error='AccessDenied')
    assert len(raw(first, 'DESCRIBE historical_values'+suffix)[0]) == 2
    catalog('external-read-grants', 'allow')
    assert rows(first, query) == (original, basis)

    first.close()
    restart()
    first = Client(root, port).open()
    assert rows(first, query) == (original, basis)
    assert catalog('history-inspect', 900001) == retained
    assert rows(first, scoped_query) == (original, basis)
    assert rows(first, exact_query) == (projected_rows, projected_basis)
    with psycopg.connect(**postgres) as pg:
        assert sorted(pg.execute(scoped_query).fetchall()) == [(1, 10), (2, 20)]
        assert sorted(pg.execute(exact_query, prepare=True).fetchall()) == [(1, 10, 7), (2, 20, 7)]
    with mysql.connector.connect(**mysql_options) as connection:
        cursor = connection.cursor()
        cursor.execute(scoped_query)
        assert sorted(cursor.fetchall()) == [(1, 10), (2, 20)]
        cursor.execute(exact_query)
        assert sorted(cursor.fetchall()) == [(1, 10, 7), (2, 20, 7)]
        cursor.close()

    catalog('namespace-admin', 900022, 'DROP SCHEMA public')
    catalog('namespace-admin', 900023, 'ALTER SCHEMA history_live RENAME TO public')

    # Independent cuts are never relabeled as an atomic cross-table snapshot.
    pair = catalog('history-retain', 900002, 'historical_values', 'historical_renamed')
    assert pair['selector'] == selector(pair['snapshot'])
    assert pair['snapshot']['consistency'] in ('independent', {'independent': {}})
    pair_suffix = " AS OF SNAPSHOT '" + pair['selector'] + "'"
    joined, pair_basis = rows(first, 'SELECT a.id AS old_id, b.id AS new_id FROM historical_renamed AS a INNER JOIN historical_values AS b ON a.id=b.id'+pair_suffix)
    assert joined == [[1, 1]], joined
    assert len(pair_basis['data']['historical']['sources']) == 2

    # More objects than one directory/disclosure page: the physical batch cap
    # must not become a total catalog limit or a false completion signal.
    names = [f'history_page_{i}' for i in range(10)]
    for name in names:
        command(first, f'CREATE TABLE {name} (id INT64 PRIMARY KEY)')
    paged = catalog('history-retain', 900003, *names)
    list_sql = "SHOW TABLES AS OF SNAPSHOT '" + paged['selector'] + "'"
    page = first.execute(list_sql)['batch']
    assert len(page['rows']) == 8 and not page['complete'], page
    end = first.call(dict(fetch=dict(cursor=page['cursor'], batch=page['batch']+1)))['batch']
    assert end['complete'] and end['completion']['rows'] == 10 and len(end['rows']) == 2, end
    assert sorted(text(row[0]) for row in page['rows']+end['rows']) == sorted(names)
    first.call(dict(close_result=end['cursor']))
    buffered = first.execute(list_sql)['batch']
    catalog('external-role', 'deny')
    try:
        denied = first.call(dict(fetch=dict(cursor=buffered['cursor'], batch=buffered['batch'])), error='AccessDenied')['err']
        assert denied['sqlstate'] == list(b'42501')
    finally:
        catalog('external-role', 'allow')
    first.call(dict(fetch=dict(cursor=buffered['cursor'], batch=buffered['batch']+1)), error='SqlResultIncomplete')
    catalog('history-release', 900003)
    for name in names:
        command(first, f'DROP TABLE {name}')

    released = catalog('history-release', 900001)
    assert released['phase'] == 'released' and released['snapshot'] == retained['snapshot']
    first.call(dict(execute=dict(sql=query)), error='HistoricalSnapshotReleased')
    first.call(dict(execute=dict(sql='DESCRIBE historical_values'+suffix)), error='HistoricalSnapshotReleased')
    assert catalog('history-release', 900001) == released
    assert catalog('history-inspect', 900001) == released
    catalog('history-release', 900002)
    catalog('history-release', 900011)
    assert rows(first, 'SELECT id, amount FROM historical_values')[0] == [[1, 1000]]
    command(first, 'DROP TABLE historical_values')
    command(first, 'DROP TABLE historical_renamed')
    first.close()
    print(json.dumps(dict(profile='installed_historical_catalog', source=provenance(ROOT),
                         original_object=old_object, rename_recreate=True, current_authority=True,
                         prepared_and_restart=True, native_postgres_mysql=True, historical_namespace_reuse=True, explicit_projection=True, projection_default_frozen=True,
                         independent_multi_source=True, paged_metadata=True, buffered_revocation=True, explicit_release=True,
                         limits='Local disk, gateway replacement and finite selected sets; not host power loss or global atomicity.')), flush=True)

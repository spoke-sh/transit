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
            + struct.pack('<QBQQ', snapshot['source_count'], 1 if single else 2, position['partition'], position['next_lsn'])).hex()


def raw(client, sql):
    batch = client.execute(sql)['batch']
    collected = list(batch['rows'])
    observation = batch['observation']
    while not batch['complete']:
        batch = client.call(dict(fetch=dict(cursor=batch['cursor'], batch=batch['batch']+1)))['batch']
        collected.extend(batch['rows'])
    client.call(dict(close_result=batch['cursor']))
    return collected, observation


def run(root, port, postgres, mysql_options, restart, catalog, faults):
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

    command(first, 'UPDATE historical_values SET amount=99 WHERE id=1')
    command(first, 'ALTER TABLE historical_values ADD COLUMN later INT64 DEFAULT 7')
    command(first, 'ALTER TABLE historical_values RENAME TO historical_renamed')
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
    with psycopg.connect(**postgres) as pg:
        assert sorted(pg.execute(query).fetchall()) == [(1, 10), (2, 20)]
    with mysql.connector.connect(**mysql_options) as connection:
        cursor = connection.cursor()
        cursor.execute(query)
        assert sorted(cursor.fetchall()) == [(1, 10), (2, 20)]
        cursor.close()

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
    assert rows(first, 'SELECT id, amount FROM historical_values')[0] == [[1, 1000]]
    command(first, 'DROP TABLE historical_values')
    command(first, 'DROP TABLE historical_renamed')
    first.close()
    print(json.dumps(dict(profile='installed_historical_catalog', source=provenance(ROOT),
                         original_object=old_object, rename_recreate=True, current_authority=True,
                         prepared_and_restart=True, native_postgres_mysql=True,
                         independent_multi_source=True, paged_metadata=True, buffered_revocation=True, explicit_release=True,
                         limits='Local disk, gateway replacement and finite selected sets; not host power loss or global atomicity.')), flush=True)

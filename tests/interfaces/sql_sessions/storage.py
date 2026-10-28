"""Storage facts through native SQL and real PostgreSQL/MySQL consumers."""
import json


def unsigned(cell):
    value = bytes.fromhex(cell)
    assert len(value) == 9 and value[0] == 3, cell
    return int.from_bytes(value[1:], 'little')


def observation(batch, rows):
    assert batch['complete'] and batch['completion']['rows'] == 1
    assert len(batch['rows']) == 1 and len(batch['rows'][0]) == 23
    values = batch['rows'][0]
    metadata = batch['observation']['metadata']
    assert metadata['kind'] == 'catalog' and metadata['consistency'] == 'independent_observations'
    definition, = metadata['definitions']
    assert unsigned(values[0]) == int(definition['object']['object'])
    assert unsigned(values[1]) == int(definition['revision'])
    # Both values are exclusive frontiers. They may coincide immediately after
    # CREATE or a row change; physical/control records can advance only acceptance.
    assert 0 < unsigned(values[4]) <= unsigned(values[3])
    assert unsigned(values[5]) == rows and unsigned(values[6]) <= rows
    assert values[8] == '0301' and unsigned(values[12]) == 0
    if rows == 0:
        assert unsigned(values[6]) == unsigned(values[7]) == 0 and values[9] == '00'
    return values


def prepare_empty(client):
    prepared = client.call(dict(prepare=dict(sql='SHOW STORAGE FOR native_sessions')))['described']
    assert prepared['parameters'] == []
    batch = client.call(dict(execute=dict(statement=prepared['statement'])))['batch']
    values = observation(batch, 0)
    client.call(dict(close_result=batch['cursor']))
    return prepared['statement'], values


def after_insert(client, saved, root, postgres):
    statement, before = saved
    batch = client.call(dict(execute=dict(statement=statement)))['batch']
    after = observation(batch, 1)
    assert unsigned(after[3]) > unsigned(before[3])
    assert unsigned(after[4]) > unsigned(before[4])
    assert client.call(dict(fetch=dict(cursor=batch['cursor'], batch=batch['batch'])))['batch'] == batch
    client.call(dict(close_result=batch['cursor']))
    client.call(dict(release=statement))

    import psycopg
    with psycopg.connect(**postgres) as wire:
        result = wire.execute('SHOW STORAGE FOR native_sessions')
        names = [column.name for column in result.description]
        row, = result.fetchall()
        assert len(row) == 23 and names[:6] == ['object', 'schema_revision', 'partition', 'accepted_lsn', 'changed_lsn', 'live_rows']
        assert int(row[0]) == unsigned(after[0]) and int(row[4]) == unsigned(after[4])
        assert int(row[5]) == 1 and row[8] is True

    import mysql.connector
    from interfaces.sql_wire.clients import connection_options
    port = json.loads((root / 'sql-gateway.json').read_text())['mysql_port']
    _, options = connection_options(root, postgres['port'], port)
    with mysql.connector.connect(**options) as wire:
        cursor = wire.cursor(prepared=True)
        try:
            cursor.execute('SHOW STORAGE FOR native_sessions')
            assert list(cursor.column_names) == names
            row, = cursor.fetchall()
            assert int(row[0]) == unsigned(after[0]) and int(row[4]) == unsigned(after[4])
            assert int(row[5]) == 1 and row[8] == 1
        finally:
            cursor.close()
    print('Storage inspection: fresh prepared execution, exact definition/frontier, repeat fetch and native/PostgreSQL/MySQL values passed.', flush=True)

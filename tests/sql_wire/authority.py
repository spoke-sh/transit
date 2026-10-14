"""Catalog policy changes use an administrator separate from the SQL principal."""
import json

import psycopg
import mysql.connector


def run(postgres, mysql_options, policy, inventory):
    update = 'UPDATE wire_rows SET id=%s WHERE id=%s'
    with psycopg.connect(**postgres) as pg, mysql.connector.connect(**mysql_options) as my:
        assert pg.execute(update, (101, 101), prepare=True).rowcount == 1
        prepared = my.cursor(prepared=True)
        prepared.execute(update, (101, 101))
        assert prepared.rowcount == 0
        before = {entry['operation'] for entry in inventory()}
        assert policy(False)['write'] is False
        try:
            denied = (
                (update, (101, 101)),
                ('INSERT INTO wire_rows (id) VALUES (%s)', (104,)),
                ('DELETE FROM wire_rows WHERE id=%s', (101,)),
                ('CREATE TABLE wire_denied (id BIGINT PRIMARY KEY)', ()),
            )
            for statement, values in denied:
                try:
                    pg.execute(statement, values, prepare=True)
                except psycopg.errors.InsufficientPrivilege:
                    pass
                else:
                    raise AssertionError('Read-only PostgreSQL account admitted a write')
                try:
                    prepared.execute(statement, values)
                except mysql.connector.Error as error:
                    assert error.errno == 1142 and error.sqlstate == '42000', str(error)
                else:
                    raise AssertionError('Read-only MySQL account admitted a write')
            assert pg.execute('SELECT id FROM wire_rows WHERE id=101').fetchall() == [(101,)]
            reader = my.cursor()
            reader.execute('SELECT id FROM wire_rows WHERE id=101')
            assert reader.fetchall() == [(101,)]
            reader.close()
            assert {entry['operation'] for entry in inventory()} == before
        finally:
            assert policy(True)['write'] is True
        prepared.close()
        assert pg.execute(update, (101, 101), prepare=True).rowcount == 1
    print(json.dumps(dict(profile='database_wire_authority',administrator=1234,
                          table_principal=1235,prepared_revocation=True,
                          read_only_writes_rejected_before_admission=True,
                          reads_preserved=True,both_protocols=True)),flush=True)

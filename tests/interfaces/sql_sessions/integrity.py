"""Installed CHECK enforcement, staged FK protection and original DDL recovery."""
import json
import os

import mysql.connector
import psycopg

from interfaces.sql_sessions.native import Client
from interfaces.sql_sessions.transactions import command, rows
from runner.capture import provenance
from runner.paths import ROOT


def run(root, port, postgres, mysql_options, restart):
    client = Client(root, port).open()
    command(client, 'CREATE TABLE integrity_parent (id INT64 PRIMARY KEY, CONSTRAINT positive CHECK (id > 0))')
    created, original = command(client, '''CREATE TABLE integrity_child (
        id INT64 PRIMARY KEY, parent_id INT64, amount INT64 DEFAULT 0,
        CONSTRAINT nonnegative CHECK (amount >= 0) NOT VALID,
        CONSTRAINT parent_link FOREIGN KEY (parent_id) REFERENCES integrity_parent (id)
            ON DELETE CASCADE ON UPDATE SET NULL NOT ENFORCED)''')
    # NOT ENFORCED is explicit: an orphan is accepted; neither recorded action
    # executes. A plain FK must refuse rather than silently become staged.
    failure = client.call(dict(execute=dict(sql='CREATE TABLE enforced_child (id INT64, FOREIGN KEY (id) REFERENCES integrity_parent (id))', token=list(os.urandom(16)))), error='ForeignKeyIndexEnforcementUnavailable')['err']
    assert failure['diagnostic']['outcome'] == 'not_submitted', failure
    command(client, 'INSERT INTO integrity_parent VALUES (1)')
    command(client, 'INSERT INTO integrity_child VALUES (1, 999, 10), (2, NULL, NULL)')
    failed = client.call(dict(execute=dict(sql='INSERT INTO integrity_child VALUES (3, 1, -1)', token=list(os.urandom(16)))), error='CheckConstraintViolation')['err']
    assert failed['sqlstate'] == list(b'23514'), failed
    assert sorted(rows(client, 'SELECT id FROM integrity_child')[0]) == [[1], [2]]
    rejected, _ = command(client, 'UPDATE integrity_child SET amount=-1', 'rejected')
    assert rejected['matched'] == rejected['changed'] == 0, rejected
    assert rows(client, 'SELECT amount FROM integrity_child WHERE id=1')[0] == [[10]]

    # NOT VALID leaves old rows intact but constrains every new candidate.
    command(client, 'ALTER TABLE integrity_child ADD CONSTRAINT small CHECK (amount < 5) NOT VALID')
    command(client, 'ALTER TABLE integrity_child VALIDATE CONSTRAINT small', 'rejected')
    assert rows(client, 'SELECT amount FROM integrity_child WHERE id=1')[0] == [[10]]
    command(client, 'UPDATE integrity_child SET amount=4 WHERE id=1')
    command(client, 'ALTER TABLE integrity_child VALIDATE CONSTRAINT small')
    command(client, 'ALTER TABLE integrity_child RENAME COLUMN amount TO balance')
    command(client, 'ALTER TABLE integrity_parent RENAME COLUMN id TO parent_key')
    command(client, 'DROP TABLE integrity_parent', 'rejected')

    # Transaction rejection must preserve the private root and savepoint, then
    # commit only the later valid candidate through the normal transaction owner.
    command(client, 'BEGIN')
    command(client, 'SAVEPOINT before_invalid')
    command(client, 'UPDATE integrity_child SET balance=-2 WHERE id=1', 'rejected')
    command(client, 'ROLLBACK TO SAVEPOINT before_invalid')
    command(client, 'UPDATE integrity_child SET balance=3 WHERE id=1', 'provisional')
    command(client, 'COMMIT')
    assert rows(client, 'SELECT balance FROM integrity_child WHERE id=1')[0] == [[3]]
    client.close()

    restart()
    client = Client(root, port).open()
    recovered, _ = command(client, '''CREATE TABLE integrity_child (
        id INT64 PRIMARY KEY, parent_id INT64, amount INT64 DEFAULT 0,
        CONSTRAINT nonnegative CHECK (amount >= 0) NOT VALID,
        CONSTRAINT parent_link FOREIGN KEY (parent_id) REFERENCES integrity_parent (id)
            ON DELETE CASCADE ON UPDATE SET NULL NOT ENFORCED)''', token=original)
    assert recovered['identity'] == created['identity'], (created, recovered)
    assert rows(client, 'SELECT balance FROM integrity_child WHERE id=1')[0] == [[3]]

    # Both adapters preserve CHECK rejection and prior successful rows. MySQL
    # uses ER_CHECK_CONSTRAINT_VIOLATED (3819/HY000); PostgreSQL uses 23514.
    with psycopg.connect(**postgres) as pg:
        try:
            pg.execute('INSERT INTO integrity_child VALUES (3, 1, -5)')
        except psycopg.errors.CheckViolation as error:
            assert error.sqlstate == '23514'
        else:
            raise AssertionError('PostgreSQL accepted an invalid CHECK row')
        assert pg.execute('SELECT balance FROM integrity_child WHERE id=1').fetchall() == [(3,)]
        try:
            pg.execute('UPDATE integrity_child SET balance=7 WHERE id=1')
        except psycopg.errors.CheckViolation:
            pass
        else:
            raise AssertionError('PostgreSQL accepted an invalid CHECK update')
    with mysql.connector.connect(**mysql_options) as my:
        cursor = my.cursor()
        try:
            cursor.execute('INSERT INTO integrity_child VALUES (3, 1, -5)')
        except mysql.connector.Error as error:
            assert error.errno == 3819 and error.sqlstate == 'HY000', error
        else:
            raise AssertionError('MySQL accepted an invalid CHECK row')
        cursor.execute('SELECT balance FROM integrity_child WHERE id=1')
        assert cursor.fetchall() == [(3,)]
        cursor.close()

    # Settlement removes the exact FK edges before completion. Reusing the
    # parent's name then allocates a new object without inheriting protection.
    dropped, drop_token = command(client, 'ALTER TABLE integrity_child DROP CONSTRAINT parent_link')
    command(client, 'DROP TABLE integrity_parent')
    command(client, 'CREATE TABLE integrity_parent (id INT64 PRIMARY KEY)')
    repeated, _ = command(client, 'ALTER TABLE integrity_child DROP CONSTRAINT parent_link', token=drop_token)
    assert repeated['identity'] == dropped['identity']
    command(client, 'DROP TABLE integrity_child')
    command(client, 'DROP TABLE integrity_parent')
    client.close()
    print(json.dumps(dict(profile='installed_table_integrity', source=provenance(ROOT),
                          check_insert_update=True, null_passes=True,
                          not_valid_enforces_new_rows=True, validation_atomic=True,
                          staged_fk_not_enforced=True, dependency_cleanup=True,
                          stable_column_rename=True, transaction_savepoint=True,
                          original_ddl_after_restart=True, postgres=True, mysql=True)), flush=True)

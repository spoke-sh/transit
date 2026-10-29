"""Pinned independent CLI/C/Python consumers of the selected wire profile."""
import decimal
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import time
import psycopg
import mysql.connector
from mysql.connector.constants import ClientFlag


def connection_options(root,sql_port,mysql_port):
    options = dict(host='localhost', hostaddr='127.0.0.1', port=sql_port, user='proof', password='proof-password', dbname='data', sslmode='verify-full', sslrootcert=str(root/'certificate.pem'), autocommit=True, connect_timeout=10)
    mysql_options = dict(host='localhost', port=mysql_port, user='proof', password='proof-password', database='data', ssl_ca=str(root/'certificate.pem'), ssl_verify_cert=True, ssl_verify_identity=True, autocommit=True, use_pure=True, charset='utf8mb4', collation='utf8mb4_0900_bin', sql_mode='ANSI_QUOTES,NO_BACKSLASH_ESCAPES')
    return options,mysql_options


def cli_roundtrip(command, env, table, separator, postgres=False, mutations=True):
    # Each invocation opens a new verified TLS connection. A successful write
    # must therefore be visible through a later connection, not a held result.
    cases = [
        ('SELECT 1', '1', 20),
        ('SHOW realm', '46', 30),
        ('SHOW query.statement_timeout', '0', 30),
        ('SHOW DATABASES', 'data', 30),
        (f'CREATE TABLE {table} (id BIGINT PRIMARY KEY, label UTF8)', 'CREATE TABLE' if postgres else '', 150),
        (f"INSERT INTO {table} (id,label) VALUES (1,'cli snow ☃')", 'INSERT 0 1' if postgres else '', 150),
        (f'SELECT id,label FROM {table}', f'1{separator}cli snow ☃', 20),
        (f'UPDATE {table} SET label=NULL WHERE id=1', 'UPDATE 1' if postgres else '', 150),
        (f'SELECT COUNT(*) FROM {table} WHERE label IS NULL', '1', 20),
        (f'DELETE FROM {table} WHERE id=1', 'DELETE 1' if postgres else '', 150),
        (f'SELECT COUNT(*) FROM {table}', '0', 20),
    ]
    if not mutations:
        cases = cases[:4]
    for sql, expected, timeout in cases:
        result = subprocess.run([*command, sql], env=env, capture_output=True, text=True, timeout=timeout)
        assert result.returncode == 0, result.stderr
        assert result.stdout.strip() == expected, (sql, result.stdout, result.stderr)
    reload = subprocess.run([*command, 'SELECT transit_reload_conf()'], env=env, capture_output=True, text=True, timeout=30)
    assert reload.returncode == 0 and re.fullmatch('[0-9a-f]{32}', reload.stdout.strip()), reload
    print(f'{command[0]}: verified TLS settings, catalog discovery and SQL reload passed.', flush=True)
    if mutations:
        print(f'{command[0]}: verified TLS, literal CREATE/INSERT/UPDATE/DELETE, Unicode/NULL and new-connection row readback passed.', flush=True)


def run_cli(root,sql_port,mysql_port,mutations=True):
    env = os.environ.copy()
    env.update(PGPASSWORD='proof-password', PGSSLMODE='verify-full', PGSSLROOTCERT=str(root/'certificate.pem'), PGHOSTADDR='127.0.0.1')
    cli_roundtrip(['psql', '-XAt', '-v', 'ON_ERROR_STOP=1', '-h', 'localhost', '-p', str(sql_port), '-U', 'proof', '-d', 'data', '-c'], env, 'psql_cli_rows', '|', postgres=True, mutations=mutations)
    defaults = root/'mysql.cnf'
    defaults.write_text('[client]\npassword=proof-password\n')
    defaults.chmod(0o600)
    cli_roundtrip(['mysql', '--defaults-file='+str(defaults), '--protocol=TCP', '-h', 'localhost', '-P', str(mysql_port), '-uproof', '-Ddata', '--ssl-mode=VERIFY_IDENTITY', '--ssl-ca='+str(root/'certificate.pem'), '--batch', '--skip-column-names', '--default-character-set=utf8mb4', '-e'], None, 'mysql_cli_rows', '\t', mutations=mutations)


def run(root,sql_port,mysql_port):
    options,mysql_options = connection_options(root,sql_port,mysql_port)
    clients = []
    for library in ('libpq', 'libmysqlclient'):
        binary = root/library
        flags = subprocess.check_output(['pkg-config', '--cflags', '--libs', 'mysqlclient' if library == 'libmysqlclient' else library], text=True)
        subprocess.run(['cc', '-std=c11', '-Wall', '-Wextra', '-Werror', str(Path(__file__).with_name(library+'.c')), *shlex.split(flags), '-o', str(binary)], check=True, timeout=30)
        clients.append(binary)
    with psycopg.connect(**options) as connection:
        assert connection.execute('SELECT 1').fetchone() == (1,)
        connection.execute('CREATE TABLE wire_rows (id BIGINT PRIMARY KEY, n UINT64, f FLOAT64, b BOOLEAN, label UTF8, payload BINARY)')
        values = (1, decimal.Decimal(2**64-1), -1.25, True, 'snow ☃ and 列', b'\0\xff')
        cursor = connection.execute('INSERT INTO wire_rows (id,n,f,b,label,payload) VALUES (%s,%s,%s,%s,%s,%s)', values, prepare=True)
        assert cursor.rowcount == 1
        for binary in (False, True):
            with connection.cursor(binary=binary) as reader:
                reader.execute('SELECT id,n,f,b,label,payload FROM wire_rows WHERE id=%s', (1,), prepare=True)
                assert reader.fetchone() == values
        cursor = connection.execute('UPDATE wire_rows SET label=%s WHERE id=%s', ('snow ☃ and 列', 1), prepare=True)
        assert cursor.rowcount == 1
        cursor = connection.execute('DELETE FROM wire_rows WHERE id=%s', (1,), prepare=True)
        assert cursor.rowcount == 1
        assert connection.execute('SELECT COUNT(*) FROM wire_rows').fetchone() == (0,)
        for sql in ('BEGIN ISOLATION LEVEL READ COMMITTED', 'SET autocommit=0', 'INSERT INTO wire_rows (id) VALUES (2); INSERT INTO wire_rows (id) VALUES (3)'):
            try:
                connection.execute(sql)
            except psycopg.Error:
                pass
            else:
                raise AssertionError('Unsupported SQL succeeded')
        assert connection.execute('SELECT COUNT(*) FROM wire_rows').fetchone() == (0,)
    run_cli(root,sql_port,mysql_port,mutations=False)
    with mysql.connector.connect(**mysql_options) as connection:
        cursor = connection.cursor()
        cursor.execute('SELECT @@character_set_connection, @@collation_connection, @@sql_mode')
        assert cursor.fetchone() == ('utf8mb4', 'utf8mb4_0900_bin', 'ANSI_QUOTES,NO_BACKSLASH_ESCAPES')
        cursor.execute('CREATE TABLE mysql_rows (id BIGINT PRIMARY KEY, n UINT64, f FLOAT64, b BOOLEAN, label UTF8, payload BINARY)')
        cursor.close()
        cursor = connection.cursor(prepared=True)
        values = (1, 2**64-1, -1.25, 1, 'snow ☃ and 列', b'\0\xff')
        cursor.execute('INSERT INTO `mysql_rows` (id,n,f,b,label,payload) VALUES (%s,%s,%s,%s,%s,%s)', values)
        assert cursor.rowcount == 1
        cursor.execute('SELECT id,n,f,b,label,payload FROM `mysql_rows` WHERE id=%s', (1,))
        assert cursor.fetchone() == values
        cursor.execute('UPDATE `mysql_rows` SET label=%s WHERE id=%s', ('snow ☃ and 列', 1))
        assert cursor.rowcount == 0
        cursor.close()
        connection.reset_session()
        cursor = connection.cursor()
        cursor.execute('SELECT COUNT(*) FROM mysql_rows')
        assert cursor.fetchone() == (1,)
        cursor.close()
    with mysql.connector.connect(**mysql_options, client_flags=[ClientFlag.FOUND_ROWS]) as connection:
        cursor = connection.cursor(prepared=True)
        cursor.execute('UPDATE `mysql_rows` SET label=%s WHERE id=%s', ('snow ☃ and 列', 1))
        assert cursor.rowcount == 1
        cursor.execute('DELETE FROM mysql_rows WHERE id=%s', (1,))
        assert cursor.rowcount == 1
        cursor.close()
    env = os.environ.copy()
    env.update(PGPASSWORD='proof-password', PGSSLMODE='verify-full', PGSSLROOTCERT=str(root/'certificate.pem'), PGHOSTADDR='127.0.0.1')
    env.update(PGHOST='localhost', PGPORT=str(sql_port), PGUSER='proof', PGDATABASE='data', MYSQL_TCP_PORT=str(mysql_port))
    for binary in clients:
        started = time.monotonic()
        # This deadline covers a whole no-retry client workload, including DDL,
        # writes and reads through the current authorization boundary. Individual
        # gateway statements retain their own configured admission/work limits.
        result = subprocess.run([str(binary)], env=env, text=True, timeout=600)
        assert result.returncode == 0, f'{Path(binary).name} exited {result.returncode}'
        print(json.dumps(dict(profile='database_wire_client', client=Path(binary).name,
                              seconds=round(time.monotonic() - started, 3), deadline_seconds=600)), flush=True)
    return options,mysql_options

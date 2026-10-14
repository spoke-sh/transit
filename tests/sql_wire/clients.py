"""Pinned independent CLI/C/Python consumers of the selected wire profile."""
import decimal
import json
import os
from pathlib import Path
import shlex
import subprocess
import psycopg
import mysql.connector
from mysql.connector.constants import ClientFlag


def connection_options(root,sql_port,mysql_port):
    options = dict(host='localhost', hostaddr='127.0.0.1', port=sql_port, user='proof', password='proof-password', dbname='data', sslmode='verify-full', sslrootcert=str(root/'certificate.pem'), autocommit=True, connect_timeout=10)
    mysql_options = dict(host='localhost', port=mysql_port, user='proof', password='proof-password', database='data', ssl_ca=str(root/'certificate.pem'), ssl_verify_cert=True, ssl_verify_identity=True, autocommit=True, use_pure=True, charset='utf8mb4', collation='utf8mb4_0900_bin', sql_mode='ANSI_QUOTES,NO_BACKSLASH_ESCAPES')
    return options,mysql_options


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
        for sql in ('BEGIN', 'SET autocommit=0', 'INSERT INTO wire_rows (id) VALUES (2); INSERT INTO wire_rows (id) VALUES (3)'):
            try:
                connection.execute(sql)
            except psycopg.Error:
                pass
            else:
                raise AssertionError('Unsupported SQL succeeded')
        assert connection.execute('SELECT COUNT(*) FROM wire_rows').fetchone() == (0,)
    env = os.environ.copy()
    env.update(PGPASSWORD='proof-password', PGSSLMODE='verify-full', PGSSLROOTCERT=str(root/'certificate.pem'), PGHOSTADDR='127.0.0.1')
    result = subprocess.run(['psql', '-XAt', '-h', 'localhost', '-p', str(sql_port), '-U', 'proof', '-d', 'data', '-c', 'SELECT 1'], env=env, capture_output=True, text=True, timeout=20)
    assert result.returncode == 0 and result.stdout.strip() == '1', result.stderr
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
    defaults = root/'mysql.cnf'
    defaults.write_text('[client]\npassword=proof-password\n')
    defaults.chmod(0o600)
    result = subprocess.run(['mysql', '--defaults-file='+str(defaults), '--protocol=TCP', '-h', 'localhost', '-P', str(mysql_port), '-uproof', '-Ddata', '--ssl-mode=VERIFY_IDENTITY', '--ssl-ca='+str(root/'certificate.pem'), '--batch', '--skip-column-names', '--default-character-set=utf8mb4', '-e', 'SELECT 1'], capture_output=True, text=True, timeout=20)
    assert result.returncode == 0 and result.stdout.strip() == '1', result.stderr
    env.update(PGHOST='localhost', PGPORT=str(sql_port), PGUSER='proof', PGDATABASE='data', MYSQL_TCP_PORT=str(mysql_port))
    for binary in clients:
        result = subprocess.run([str(binary)], env=env, capture_output=True, text=True, timeout=150)
        assert result.returncode == 0, result.stdout + result.stderr
        print(result.stdout.strip(), flush=True)
    return options,mysql_options

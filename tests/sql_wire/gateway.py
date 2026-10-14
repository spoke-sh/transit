"""Pinned database drivers against the real TLS gateway and disk-backed owners."""
import decimal
import json
import os
from pathlib import Path
import socket
import shlex
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from storage import Fixture, free_port, wait_ready
import psycopg
import mysql.connector
from mysql.connector.constants import ClientFlag


def run(node, catalog, ledger, host, gateway):
    node, catalog, ledger, host, gateway = [str(Path(p).resolve()) for p in (node, catalog, ledger, host, gateway)]
    with Fixture() as store:
        root = store.root
        native_port, sql_port, mysql_port, health_port = free_port(), free_port(), free_port(), free_port()
        url = f'http://127.0.0.1:{native_port}'
        public = json.loads(subprocess.check_output([catalog, 'public'], timeout=10))
        node_config = root / 'node.json'
        node_config.write_text(json.dumps(dict(profile='native_v1', genesis=dict(realm=46, root_key=public, max_clock_error_ms=10000), ursula_url=store.url, bucket='sql-wire-gateway', journal='authority', port=native_port, resident_pages=8, request_timeout_ms=10000)))
        processes, logs = [], []
        def start(binary, config, *before):
            log = (root / f'process-{len(logs)}.log').open('w+')
            logs.append(log)
            child = subprocess.Popen([binary, *before, str(config)], stdout=log, stderr=subprocess.STDOUT)
            processes.append(child)
            return child
        def call(binary, mode, *args):
            result = subprocess.run([binary, url, mode, str(root), *map(str, args)], capture_output=True, text=True, timeout=300)
            if result.returncode:
                raise RuntimeError(f'{mode}: {result.stderr[-8000:]}')
            return json.loads(result.stdout)
        def controls(*args):
            result = subprocess.run([gateway, 'control', str(root/'sql-control.json'), *map(str,args)], capture_output=True, text=True, timeout=40)
            assert result.returncode == 0, result.stderr
            return json.loads(result.stdout)
        def configure():
            call(ledger, 'app-config', sql_port)
            configuration = json.loads((root/'sql-gateway.json').read_text())
            configuration['mysql_port'] = mysql_port
            configuration['health_port'] = health_port
            configuration['drain_ms'] = 1000
            configuration['limits'] = dict(connections=8,connections_per_account=8,authentications=4)
            (root/'sql-gateway.json').write_text(json.dumps(configuration))
        started = time.monotonic()
        try:
            clients = []
            for library in ('libpq', 'libmysqlclient'):
                binary = root/library
                flags = subprocess.check_output(['pkg-config', '--cflags', '--libs', 'mysqlclient' if library == 'libmysqlclient' else library], text=True)
                subprocess.run(['cc', '-std=c11', '-Wall', '-Wextra', '-Werror', str(Path(__file__).with_name(library+'.c')), *shlex.split(flags), '-o', str(binary)], check=True, timeout=30)
                clients.append(binary)
            subprocess.run([node, str(node_config), '--initialize'], capture_output=True, check=True, timeout=30)
            authority = start(node, node_config)
            wait_ready(store.http, authority, url + '/health')
            call(catalog, 'provision')
            call(catalog, 'initialize')
            call(catalog, 'pump')
            call(ledger, 'provision-empty')
            call(catalog, 'host')
            configure()
            subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost', '-keyout', str(root/'key.pem'), '-out', str(root/'certificate.pem')], capture_output=True, check=True, timeout=30)
            (root/'key.pem').chmod(0o600)
            start(host, root/'host.json')
            start(host, root/'courier-config.json')
            bootstrap = start(gateway, root/'sql-gateway.json', '--initialize')
            assert controls('prepare','initialize')['state'] == 'prepared'
            assert controls('submit')['processed']
            assert bootstrap.wait(timeout=20) == 0
            call(ledger, 'fence')
            configure()
            server = start(gateway, root/'sql-gateway.json')
            deadline = time.monotonic()+30
            while True:
                assert server.poll() is None, 'Gateway exited during startup'
                try:
                    with socket.create_connection(('127.0.0.1', sql_port), timeout=1):
                        break
                except ConnectionRefusedError:
                    assert time.monotonic() < deadline
                    time.sleep(.02)
            options = dict(host='localhost', hostaddr='127.0.0.1', port=sql_port, user='proof', password='proof-password', dbname='data', sslmode='verify-full', sslrootcert=str(root/'certificate.pem'), autocommit=True, connect_timeout=10)
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
            mysql_options = dict(host='localhost', port=mysql_port, user='proof', password='proof-password', database='data', ssl_ca=str(root/'certificate.pem'), ssl_verify_cert=True, ssl_verify_identity=True, autocommit=True, use_pure=True, charset='utf8mb4', collation='utf8mb4_0900_bin', sql_mode='ANSI_QUOTES,NO_BACKSLASH_ESCAPES')
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
            from faults import run as faults
            faults(root, options, mysql_options, controls, lambda allowed:call(ledger,'native-read-allow' if allowed else 'native-read-deny'))
            page = controls('list')
            operation = page['entries'][0]['operation']
            assert controls('status',operation)['terminal']['state'] == 'applied'
            assert controls('prepare','reconcile',operation)['state'] == 'prepared'
            assert not controls('pending')['processed']
            assert controls('submit')['processed']
            assert controls('submit')['processed']
            # An exited activation cannot be reused. Fencing creates eligibility.
            server.kill()
            server.wait(timeout=10)
            stale = subprocess.run([gateway,str(root/'sql-gateway.json')],capture_output=True,text=True,timeout=20)
            assert stale.returncode != 0 and 'FreshOwnershipRequired' in stale.stderr
            call(ledger,'fence')
            configure()
            server = start(gateway,root/'sql-gateway.json')
            deadline = time.monotonic()+20
            while True:
                try:
                    connection = psycopg.connect(**options)
                    break
                except psycopg.OperationalError:
                    assert server.poll() is None and time.monotonic()<deadline
                    time.sleep(.05)
            with connection:
                assert connection.execute('SELECT COUNT(*) FROM wire_rows').fetchone() == (3,)
                assert connection.execute('INSERT INTO wire_rows (id) VALUES (200)').rowcount == 1
            from lifecycle import capacity, drain
            capacity(options,health_port)
            drain(server,options,health_port)
            print(json.dumps(dict(profile='database_native_gateway', psycopg=psycopg.__version__, connector=mysql.connector.__version__, types=6, text_and_binary=True, prepared_dml=True, both_mysql_counts=True, seconds=round(time.monotonic()-started, 3))))
        finally:
            for child in reversed(processes):
                if child.poll() is None:
                    child.kill()
                child.wait(timeout=10)
            if sys.exc_info()[0]:
                for log in logs:
                    log.flush()
                    log.seek(0)
                    sys.stderr.write(log.read()[-10000:])
            for log in logs:
                log.close()


if __name__ == '__main__':
    run(*sys.argv[1:])

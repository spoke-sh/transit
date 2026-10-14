"""Owned reference databases and sanitized, TLS-terminating transcript probes.

Only message kinds and explicitly allowed metadata SQL leave the fixture. Test
credentials, authentication exchanges and parameter/result bytes are discarded.
These databases are independent test peers, never Transit runtime dependencies.
"""
from contextlib import ExitStack
import json
import os
from pathlib import Path
import secrets
import select
import socket
import ssl
import struct
import subprocess
import tempfile
import threading
import time


def exact(sock, count):
    result = bytearray()
    while len(result) < count:
        chunk = sock.recv(count - len(result))
        if not chunk:
            raise EOFError()
        result += chunk
    return bytes(result)


def port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def run(args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, timeout=120, **kwargs)


def shutdown(sock):
    try:
        sock.shutdown(socket.SHUT_RDWR)
    except OSError:
        pass  # The peer may already have completed an orderly close.


class References:
    def __enter__(self):
        self.owned = ExitStack()
        try:
            self.root = Path(self.owned.enter_context(tempfile.TemporaryDirectory(prefix='transit-sql-wire-')))
            self.password = secrets.token_hex(24)
            self.ca = self.root / 'certificate.pem'
            self.key = self.root / 'key.pem'
            run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1',
                 '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost,IP:127.0.0.1',
                 '-keyout', str(self.key), '-out', str(self.ca)])
            self.key.chmod(0o600)
            self.server_tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            self.server_tls.minimum_version = ssl.TLSVersion.TLSv1_2
            self.server_tls.load_cert_chain(self.ca, self.key)
            self.client_tls = ssl.create_default_context(cafile=self.ca)
            self.pg, self.mysql = port(), port()
            password_file = self.root / 'password'
            password_file.write_text(self.password)
            password_file.chmod(0o600)
            pg_data = self.root / 'postgres'
            run(['initdb', '-D', str(pg_data), '-U', 'probe', '--pwfile=' + str(password_file),
                 '--auth-local=trust', '--auth-host=scram-sha-256', '--no-locale', '--encoding=UTF8'])
            with (pg_data / 'postgresql.conf').open('a') as config:
                config.write(f"\nlisten_addresses='127.0.0.1'\nport={self.pg}\nunix_socket_directories='{self.root}'\nssl=on\nssl_cert_file='{self.ca}'\nssl_key_file='{self.key}'\n")
            self.start('postgres', ['postgres', '-D', str(pg_data)], self.pg)
            my_data = self.root / 'mysql'
            my_config = self.root / 'mysql.cnf'
            my_config.write_text(f'[mysqld]\ndatadir={my_data}\nport={self.mysql}\nbind-address=127.0.0.1\nsocket={self.root}/mysql.sock\npid-file={self.root}/mysql.pid\nmysqlx=0\nssl-cert={self.ca}\nssl-key={self.key}\nssl-ca={self.ca}\n')
            run(['mysqld', '--defaults-file=' + str(my_config), '--initialize-insecure'])
            self.start('mysql', ['mysqld', '--defaults-file=' + str(my_config)], self.mysql)
            # Only fixture-owned loopback state exists during initialization.
            run(['mysql', '--no-defaults', '--protocol=SOCKET', '--socket=' + str(self.root / 'mysql.sock'), '-uroot'],
                input=(f"CREATE DATABASE probe; CREATE USER 'probe'@'%' IDENTIFIED WITH caching_sha2_password BY '{self.password}'; GRANT ALL ON probe.* TO 'probe'@'%';").encode())
            return self
        except BaseException:
            self.owned.close()
            raise

    def start(self, name, args, listen):
        log = self.owned.enter_context((self.root / (name + '.log')).open('w+'))
        child = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT)
        def stop():
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait(timeout=15)
        self.owned.callback(stop)
        deadline = time.monotonic() + 45
        while True:
            if child.poll() is not None:
                log.seek(0)
                raise RuntimeError(name + ': ' + log.read()[-4000:])
            try:
                with socket.create_connection(('127.0.0.1', listen), timeout=.2):
                    return
            except OSError:
                if time.monotonic() > deadline:
                    raise TimeoutError(name + ' readiness')
                time.sleep(.05)

    def __exit__(self, *_):
        self.owned.close()


class Recorder:
    """One client at a time; both halves use verified/upgraded TLS.

    Writes are forwarded to independent reference servers. This records client
    behavior, not gateway durability or transaction qualification.
    """
    def __init__(self, refs, protocol):
        self.refs, self.protocol = refs, protocol
        self.events, self.failures, self.connections = [], [], []
        self.listener = socket.socket()
        self.listener.bind(('127.0.0.1', 0))
        self.port = self.listener.getsockname()[1]
        self.listener.listen(8)
        self.listener.settimeout(.2)
        self.stopping = threading.Event()
        self.threads = []

    def __enter__(self):
        self.thread = threading.Thread(target=self.accept)
        self.thread.start()
        return self

    def accept(self):
        while not self.stopping.is_set():
            try:
                sock, _ = self.listener.accept()
            except socket.timeout:
                continue
            sock.settimeout(10)
            task = threading.Thread(target=self.connection, args=(sock,))
            self.threads.append(task)
            task.start()

    def connection(self, incoming):
        outgoing = socket.create_connection(('127.0.0.1', getattr(self.refs, self.protocol)), timeout=10)
        events = []
        self.events.append(events)
        try:
            if self.protocol == 'pg':
                request = exact(incoming, 8)
                assert request == struct.pack('!II', 8, 80877103)
                outgoing.sendall(request)
                assert exact(outgoing, 1) == b'S'
                incoming.sendall(b'S')
            else:
                greeting = bytearray(self.packet(outgoing))
                low = greeting.index(0, 5) + 14
                high = low + 5
                capabilities = int.from_bytes(greeting[low:low + 2], 'little') | int.from_bytes(greeting[high:high + 2], 'little') << 16
                # Exercise the selected capability subset. In particular query
                # attributes change COM_QUERY framing even with zero attributes.
                capabilities &= ~((1 << 27) | (1 << 16) | (1 << 5) | (1 << 7))
                greeting[low:low + 2] = (capabilities & 65535).to_bytes(2, 'little')
                greeting[high:high + 2] = (capabilities >> 16).to_bytes(2, 'little')
                incoming.sendall(greeting)
                request = bytearray(self.packet(incoming))
                assert len(request) == 36 and int.from_bytes(request[4:8], 'little') & 0x800
                request[4:8] = (int.from_bytes(request[4:8], 'little') & capabilities).to_bytes(4, 'little')
                outgoing.sendall(request)
                events.append(['client', 'charset', request[12]])
            outgoing = self.refs.client_tls.wrap_socket(outgoing, server_hostname='localhost')
            incoming = self.refs.server_tls.wrap_socket(incoming, server_side=True)
            # One thread owns each pair of SSL objects. Concurrent SSL_read /
            # SSL_write on the same object is not an OpenSSL-supported pattern.
            if self.protocol == 'pg':
                header = exact(incoming, 4)
                startup = exact(incoming, struct.unpack('!I', header)[0] - 4)
                events.append(['client', 'startup', struct.unpack('!I', startup[:4])[0]])
                outgoing.sendall(header + startup)
            incoming.setblocking(False)
            outgoing.setblocking(False)
            sockets = (incoming, outgoing)
            buffers = {sock: bytearray() for sock in sockets}
            pending = {sock: bytearray() for sock in sockets}
            held = None
            ready = False
            auth_response = self.protocol == 'mysql'
            deadline = time.monotonic() + 15
            while True:
                readable, writable, _ = select.select(sockets, [sock for sock in sockets if pending[sock]], [], .2)
                readable += [sock for sock in sockets if sock.pending() and sock not in readable]
                for sock in writable:
                    try:
                        count = sock.send(pending[sock])
                        del pending[sock][:count]
                        deadline = time.monotonic() + 15
                    except (ssl.SSLWantReadError, ssl.SSLWantWriteError):
                        pass
                for sock in readable:
                    try:
                        data = sock.recv(65536)
                    except (ssl.SSLWantReadError, ssl.SSLWantWriteError):
                        continue
                    if not data:
                        return
                    deadline = time.monotonic() + 15
                    buffer = buffers[sock]
                    buffer += data
                    assert len(buffer) <= 1024 * 1024
                    header_size = 5 if self.protocol == 'pg' else 4
                    while len(buffer) >= header_size:
                        length = 1 + struct.unpack('!I', buffer[1:5])[0] if self.protocol == 'pg' else 4 + int.from_bytes(buffer[:3], 'little')
                        assert header_size <= length <= 1024 * 1024
                        if len(buffer) < length:
                            break
                        frame = bytearray(buffer[:length])
                        del buffer[:length]
                        destination = outgoing if sock is incoming else incoming
                        if sock is outgoing:
                            kind = chr(frame[0]) if self.protocol == 'pg' else 'packet'
                            if self.protocol == 'pg' and kind == 'Z' or self.protocol == 'mysql' and frame[3] >= 2 and frame[4] == 0:
                                ready = True
                            events.append(['server', kind])
                        else:
                            kind = chr(frame[0]) if self.protocol == 'pg' else (f'command:{frame[4]:02x}' if ready and frame[3] == 0 else 'authentication')
                            if auth_response:
                                frame[4:8] = (int.from_bytes(frame[4:8], 'little') & capabilities).to_bytes(4, 'little')
                                auth_response = False
                            event = ['client', kind]
                            if kind in ('Q', 'command:03'):
                                sql = frame[5:].rstrip(b'\0').decode('utf8')
                                if sql.upper().startswith(('SET ', 'SELECT @@')):
                                    event.append(sql)
                            events.append(event)
                            # Prove clients send Sync without awaiting Execute.
                            if self.protocol == 'pg' and kind == 'E':
                                assert held is None, 'multiple executions in one cycle'
                                held = bytearray()
                            if held is not None:
                                assert kind != 'H', 'Flush requires a broader contract'
                                held += frame
                                assert len(held) <= 65536
                                if kind != 'S':
                                    continue
                                frame, held = held, None
                        pending[destination] += frame
                        assert len(pending[destination]) <= 1024 * 1024
                assert time.monotonic() < deadline, 'TLS relay deadline'
        except BaseException as error:
            self.failures.append(type(error).__name__ + ': ' + str(error))
        finally:
            incoming.close()
            outgoing.close()

    @staticmethod
    def packet(sock):
        header = exact(sock, 4)
        length = int.from_bytes(header[:3], 'little')
        assert length <= 1024 * 1024
        return header + exact(sock, length)

    @staticmethod
    def pg_packet(sock):
        header = exact(sock, 5)
        length = struct.unpack('!I', header[1:])[0]
        assert 4 <= length <= 1024 * 1024
        return header + exact(sock, length - 4)

    def __exit__(self, *_):
        self.stopping.set()
        self.thread.join(timeout=5)
        self.listener.close()
        for task in self.threads:
            task.join(timeout=15)
            assert not task.is_alive()
        assert not self.failures, self.failures


def main():
    import psycopg
    import mysql.connector
    with References() as refs:
        with Recorder(refs, 'pg') as pg:
            conninfo = dict(host='localhost', port=pg.port, user='probe', password=refs.password,
                            dbname='postgres', sslmode='verify-full', sslrootcert=str(refs.ca))
            with psycopg.connect(**conninfo, autocommit=True) as connection:
                connection.execute('CREATE TABLE probe (id BIGINT PRIMARY KEY, value BIGINT)')
                for index in range(2):
                    connection.execute('INSERT INTO probe VALUES (%s, %s)', (index, index + 10), prepare=True)
                assert connection.execute('SELECT value FROM probe WHERE id = %s', (1,), prepare=True).fetchall() == [(11,)]
                assert connection.execute('UPDATE probe SET value = %s WHERE id = %s', (11, 1), prepare=True).rowcount == 1
                assert connection.execute('DELETE FROM probe WHERE id = %s', (0,), prepare=True).rowcount == 1
            environment = dict(os.environ, PGPASSWORD=refs.password, PGSSLMODE='verify-full', PGSSLROOTCERT=str(refs.ca))
            run(['psql', '-X', '-h', 'localhost', '-p', str(pg.port), '-U', 'probe', '-d', 'postgres', '-At', '-c', 'SELECT value FROM probe'], env=environment)
        with Recorder(refs, 'mysql') as my:
            with mysql.connector.connect(host='localhost', port=my.port, user='probe', password=refs.password,
                                         database='probe', ssl_ca=str(refs.ca), ssl_verify_cert=True,
                                         ssl_verify_identity=True, autocommit=True, use_pure=True,
                                         charset='utf8mb4', collation='utf8mb4_0900_bin',
                                         sql_mode='ANSI_QUOTES,NO_BACKSLASH_ESCAPES') as connection:
                cursor = connection.cursor()
                cursor.execute('SELECT @@character_set_connection, @@collation_connection, @@sql_mode')
                charset, collation, mode = cursor.fetchone()
                assert charset == 'utf8mb4' and collation == 'utf8mb4_0900_bin'
                assert set(mode.split(',')) == {'ANSI_QUOTES', 'NO_BACKSLASH_ESCAPES'}
                cursor.execute("SELECT 'a' = 'a ', 'a' = 'A', 'a\\b'")
                assert cursor.fetchone() == (0, 0, 'a\\b')
                cursor.execute('CREATE TABLE probe (id BIGINT PRIMARY KEY, value BIGINT)')
                cursor.close()
                cursor = connection.cursor(prepared=True)
                cursor.execute('INSERT INTO probe VALUES (%s, %s)', (1, 11))
                cursor.execute('SELECT value FROM probe WHERE id = %s', (1,))
                assert cursor.fetchall() == [(11,)]
                cursor.execute('UPDATE probe SET value = %s WHERE id = %s', (11, 1))
                assert cursor.rowcount == 0
                cursor.close()
                connection.reset_session()
            defaults = refs.root / 'client.cnf'
            defaults.write_text(f'[client]\npassword={refs.password}\n')
            defaults.chmod(0o600)
            try:
                run(['mysql', '--defaults-file=' + str(defaults), '--protocol=TCP', '-h', 'localhost',
                     '-P', str(my.port), '-uprobe', '--ssl-mode=VERIFY_IDENTITY', '--ssl-ca=' + str(refs.ca),
                     '--batch', '--skip-column-names', '--default-character-set=utf8mb4', '-e',
                     "SET NAMES utf8mb4 COLLATE utf8mb4_0900_bin; SET sql_mode='ANSI_QUOTES,NO_BACKSLASH_ESCAPES'; SELECT value FROM probe.probe"])
            except subprocess.CalledProcessError as error:
                raise RuntimeError(error.stderr.decode().replace(refs.password, '<redacted>')) from None
        # Every prepared write must have its Sync sent before the reference
        # server's completion. The gateway will enforce this admission boundary.
        pg_clients = [[event[1] for event in events if event[0] == 'client'] for events in pg.events]
        assert any('P' in events and 'B' in events and 'E' in events and 'S' in events for events in pg_clients)
        assert all('H' not in events for events in pg_clients), pg_clients
        assert any(event[:2] == ['client', 'command:17'] for events in my.events for event in events)
        print(json.dumps(dict(versions=dict(postgresql=run(['psql', '--version']).stdout.decode().strip(),
                                           mysql=run(['mysql', '--version']).stdout.decode().strip(),
                                           psycopg=psycopg.__version__, connector=mysql.connector.__version__),
                              postgres=pg.events, mysql=my.events), indent=2))


if __name__ == '__main__':
    main()

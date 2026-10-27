"""Real idle clients, finite native leases and bounded partial wire/TLS frames."""
import ctypes
import http.client
import json
import os
from pathlib import Path
import select
import shutil
import socket
import ssl
import struct
import subprocess
import sys
import time

from harness.processes import children
from interfaces.installation.server import Fixture
from harness.local_installation import freeze_executables
from interfaces.installation.server_sql import wait_status
from interfaces.sql_sessions.native import Client
from interfaces.cli.table_console import TableConsole


def exact(sock, size):
    data = b''
    while len(data) < size:
        part = sock.recv(size - len(data))
        if not part:
            raise EOFError('Wire connection closed')
        data += part
    return data


class Peer:
    def __init__(self, fixture, protocol, secure):
        self.protocol = protocol
        self.sock = socket.create_connection(('127.0.0.1', fixture.config['sql'][protocol]['port']), timeout=10)
        # Verify the local CA and hostname, as libpq does. Python's convenience
        # context additionally requires AKI extensions absent from this local CA.
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.load_verify_locations(cafile=str(fixture.installation / 'sql/tls/ca.pem'))
        if protocol == 'postgres':
            if secure:
                self.sock.sendall(struct.pack('!II', 8, 80877103))
                assert exact(self.sock, 1) == b'S'
                self.sock = context.wrap_socket(self.sock, server_hostname='localhost')
            startup = b'user\0owner\0database\0transit\0\0'
            self.sock.sendall(struct.pack('!II', len(startup) + 8, 196608) + startup)
            while True:
                tag, data = self.read()
                assert tag != b'E', data
                if tag == b'Z':
                    break
        else:
            self.read()  # greeting
            flags = 1 | 4 | 8 | 512 | 32768 | (1 << 19) | (2048 if secure else 0)
            prefix = struct.pack('<IIB', flags, 4194304, 45) + bytes(23)
            if secure:
                self.send(prefix, sequence=1)
                self.sock = context.wrap_socket(self.sock, server_hostname='localhost')
            self.send(prefix + b'owner\0\0transit\0caching_sha2_password\0', sequence=2 if secure else 1)
            _, data = self.read()
            assert data[0] == 0, data

    def send(self, data, sequence=0):
        self.sock.sendall(len(data).to_bytes(3, 'little') + bytes([sequence]) + data)

    def read(self):
        if self.protocol == 'postgres':
            tag = exact(self.sock, 1)
            size = struct.unpack('!I', exact(self.sock, 4))[0] - 4
        else:
            header = exact(self.sock, 4)
            tag, size = header[3:], int.from_bytes(header[:3], 'little')
        assert 0 <= size < 4194304
        return tag, exact(self.sock, size)

    def check(self):
        if self.protocol == 'mysql':
            self.send(b'\x0e')  # COM_PING
            assert self.read()[1][0] == 0
        else:
            query = b'SELECT 1\0'
            self.sock.sendall(b'Q' + struct.pack('!I', len(query) + 4) + query)
            rows = []
            while True:
                tag, data = self.read()
                assert tag != b'E', data
                if tag == b'D':
                    rows.append(data)
                if tag == b'Z':
                    assert rows == [b'\x00\x01\x00\x00\x00\x011'], rows
                    return

    def close(self):
        self.sock.close()


class Local(Client):
    def __init__(self, fixture):
        self.connection = fixture.console_config()
        self.definition = json.loads((fixture.installation / 'sql/gateway.json').read_text())['definition']
        self.instance = self.session = self.account = None
        self.last = 0
        self.transport()

    def transport(self):
        path = self.connection['endpoint'][5:]
        class Unix(http.client.HTTPConnection):
            def connect(self):
                self.sock = socket.socket(socket.AF_UNIX)
                self.sock.settimeout(10)
                self.sock.connect(path)
        self.http = Unix('local')

    def open(self):
        self.lease = self.call('hello')['hello']['session_lease_ms']
        opened = self.call(dict(open=dict(account=self.connection['account'], database='transit', authentication='peer')))['opened']
        self.session, self.account = opened['session'], opened['account']
        return self


def run(cli, node, host, board, gateway):
    report = Path('.cache/verification/server-sql-lifetimes-failure.json')
    report.unlink(missing_ok=True)
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    os.environ['TEST_TRANSIT_BOARD_BINARY'] = str(board)
    os.environ['TEST_TRANSIT_SQL_GATEWAY_BINARY'] = str(gateway)
    fixture = Fixture(cli, node, host)
    freeze_executables(fixture)
    fixture.config['applications'] = {'port': fixture.reserve_port()}
    fixture.config['logging'] = {'format': 'json'}
    fixture.config['sql'].update(postgres={'port': fixture.reserve_port()}, mysql={'port': fixture.reserve_port()},
        tls={'mode': 'optional'}, native={'session_lease_ms': 1000}, drain_ms=1000,
        accounts=[dict(name='owner', role='local_owner', authentication='trust', bootstrap_owner=True)])
    peers, native, console, psql = [], None, None, None
    success = False
    phase = 'default idle and native lease'
    query_in_flight = None

    def tail(path, limit=65536):
        try:
            with path.open('rb') as source:
                size = source.seek(0, os.SEEK_END)
                source.seek(max(0, size - limit))
                return dict(bytes=size, truncated=size > limit, text=source.read(limit).decode(errors='replace'))
        except FileNotFoundError:
            return None

    def psql_evidence():
        return dict(query=query_in_flight, returncode=psql.poll() if psql else None,
                    stderr=tail(fixture.root / 'psql.stderr'))

    def start():
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start(); fixture.ready()
        wait_status(fixture, lambda s: s['service']['state'] == 'accepting' and all(a['initialized'] for a in s['accounts']))
        return children(fixture.process.pid)

    def connect():
        for protocol in ('postgres', 'mysql'):
            for secure in (False, True):
                peers.append(Peer(fixture, protocol, secure))

    def close():
        while peers:
            peers.pop().close()

    def pg_query(query):
        nonlocal query_in_flight
        query_in_flight = query
        psql.stdin.write((query + ';\n').encode()); psql.stdin.flush()
        assert select.select([psql.stdout], [], [], 30)[0], ('psql response deadline', psql_evidence())
        row = psql.stdout.readline()
        assert row, ('psql exited before a result', psql_evidence())
        query_in_flight = None
        return row.strip()

    print(f'SQL lifetime proof: {fixture.root}', flush=True)
    try:
        pids = start()
        connect()
        console = TableConsole(fixture.cli, cwd=fixture.root)
        result = console.call('INSERT INTO items (id,value) VALUES (1,100);')
        assert result['completion']['outcome'] == 'applied', result
        pg_port = str(fixture.config['sql']['postgres']['port'])
        with (fixture.root/'psql.stderr').open('wb') as log:
            # An SQL error must close the noninteractive client and expose its
            # stderr, rather than leave us waiting for a row that cannot arrive.
            psql = subprocess.Popen(['psql', '-XqAt', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose',
                '-h', '127.0.0.1', '-p', pg_port, '-U', 'owner', '-d', 'transit'],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=log, env=os.environ | {'PGSSLMODE': 'disable'})
            assert pg_query('SELECT value FROM items') == b'100'
            assert pg_query('SHOW sql.idle_ms') == b'0'
            native = Local(fixture).open()
            assert native.lease == 1000
            time.sleep(32)  # Cross the former default, without sending keepalives.
            for peer in peers:
                peer.check()
            assert pg_query('SELECT value FROM items') == b'100'
            psql.stdin.write(b'\\q\n'); psql.stdin.flush()
            assert psql.wait(timeout=10) == 0
            native.call('touch', error='SqlSessionExpired')
            native.session = None; native.close(); native = None
        assert children(fixture.process.pid) == pids, 'Idle clients replaced a server role'
        close(); console.close(); console = None
        fixture.stop()
        print('Default idle psql, PG/MySQL plaintext/TLS sockets survive 32 seconds; native lease expires independently.', flush=True)

        phase = 'configured wire idle expiry'
        fixture.config['sql'].update(idle_ms=1000, native={'session_lease_ms': 30000})
        pids = start(); connect()
        native = Local(fixture).open()
        assert native.lease == 30000
        time.sleep(1.2)
        for peer in peers:
            tag, data = peer.read()
            assert b'idle-session timeout' in data, data
            if peer.protocol == 'postgres':
                assert tag == b'E' and b'C57P05\0' in data and b'SFATAL\0' in data, data
            else:
                assert data[:3] == b'\xff' + struct.pack('<H', 4031), data
        native.call('touch'); native.close(); native = None
        assert children(fixture.process.pid) == pids
        close(); fixture.stop()
        print('Configured idle expiry returns explicit protocol errors and does not expire a native HTTP session.', flush=True)

        phase = 'partial wire and TLS frames'
        fixture.config['sql'].update(idle_ms=0, command_ms=1000)
        pids = start(); connect()
        for i, peer in enumerate(peers):
            if i % 2:
                # An incomplete encrypted TLS record must start the same finite
                # frame deadline before a plaintext command can be decoded.
                os.write(peer.sock.fileno(), b'\x17\x03\x03\x00\x10\xff')
            else:
                peer.sock.sendall(b'Q' if peer.protocol == 'postgres' else b'\x01')
        time.sleep(1.5)
        for peer in peers:
            try:
                assert peer.sock.recv(1) == b'', 'Incomplete frame remained open'
            except (ConnectionResetError, ssl.SSLEOFError):
                pass
        assert children(fixture.process.pid) == pids
        close()
        # One TLS record contains a complete ping plus the first byte of the
        # next frame. That byte is already inside OpenSSL when the next idle
        # wait begins, so the adapter must start the deadline as it consumes it.
        buffered = Peer(fixture, 'mysql', True)
        peers.append(buffered)
        buffered.sock.sendall(b'\x01\x00\x00\x00\x0e\x01')
        assert buffered.read()[1][0] == 0
        time.sleep(1.5)
        assert buffered.sock.recv(1) == b''
        close(); fixture.stop()
        success = True
        print('Partial PostgreSQL/MySQL frames and TLS records retain finite deadlines with idle expiry disabled.', flush=True)
    except Exception as failure:
        # CI uploads verification JSON, while temporary installations disappear
        # with the runner. Keep bounded diagnostics, never configuration files
        # containing signing keys or native session credentials.
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(json.dumps(dict(
            phase=phase, failure=repr(failure), fixture=str(fixture.root),
            psql=psql_evidence(),
            manager_logs={Path(log.name).name: tail(Path(log.name)) for log in fixture.logs},
        ), indent=2) + '\n')
        print(f'Lifetime failure diagnostics: {report.resolve()}', file=sys.stderr, flush=True)
        raise
    finally:
        close()
        if native:
            native.http.close()
        for process in (psql, console.process if console else None):
            if process and process.poll() is None:
                process.kill(); process.wait(timeout=10)
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Lifetime evidence retained at {fixture.root}', file=sys.stderr, flush=True)


if __name__ == '__main__':
    run(*(Path(arg).resolve() for arg in sys.argv[1:]))

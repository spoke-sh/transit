"""Socket/account bounds and independent readiness under pressure."""
from concurrent.futures import ThreadPoolExecutor
import json
import socket
import struct
import time
import urllib.error
import urllib.request

import psycopg
from faults import PostgreSQL, cancel, exact, frame


def health(port, expected=200):
    try:
        response=urllib.request.urlopen(f'http://127.0.0.1:{port}/health', timeout=3)
    except urllib.error.HTTPError as error:
        response=error
    with response:
        assert response.status == expected
        assert json.loads(response.read())['ready'] == (expected == 200)


def connection_denied(postgres, message):
    # A failed libpq TLS startup can leave SSL_shutdown errors in OpenSSL's
    # thread-local queue. Keep that negative client off the Python ssl thread
    # which owns the already admitted raw connection and cancellation socket.
    def attempt():
        try:
            psycopg.connect(**postgres).close()
        except psycopg.Error:
            return True
        return False
    with ThreadPoolExecutor(max_workers=1) as executor:
        assert executor.submit(attempt).result(timeout=20), message


def capacity(postgres, health_port):
    # The fixture explicitly configures eight normal slots plus cancellation
    # reserve, with eight slots per account and four authentication attempts.
    connections=[]
    wire=None
    try:
        for _ in range(7):
            connections.append(psycopg.connect(**postgres))
        wire=PostgreSQL(postgres)
        connection_denied(postgres, 'Ninth ordinary session exceeded capacity')
        health(health_port)
        wire.sock.sendall(frame(b'P',b'hold\0SELECT id FROM wire_rows\0\0\0')+frame(b'B',b'portal\0hold\0\0\0\0\0\0\0')+frame(b'E',b'portal\0'+struct.pack('!I',1))+frame(b'H'))
        assert wire.until(b's',b'E')[-1][0] == b's'
        cancel(postgres,wire.key)
        wire.sock.sendall(frame(b'E',b'portal\0'+struct.pack('!I',1))+frame(b'S'))
        assert any(tag==b'E' and b'57014' in payload for tag,payload in wire.until(b'Z'))
        health(health_port)
    finally:
        if wire:
            wire.close()
        for connection in connections:
            connection.close()

    # Headers consume authentication slots, but cannot hold them indefinitely.
    held=[]
    try:
        for _ in range(4):
            raw=socket.create_connection((postgres['hostaddr'],postgres['port']),timeout=10)
            raw.sendall(struct.pack('!II',8,80877103))
            assert exact(raw,1)==b'S'
            held.append(raw)
        health(health_port)
        connection_denied(postgres, 'Authentication capacity was not enforced')
        deadline=time.monotonic()+7
        for raw in held:
            raw.settimeout(max(.1,deadline-time.monotonic()))
            assert raw.recv(1)==b''
        health(health_port)
    finally:
        for raw in held:
            raw.close()
    with psycopg.connect(**postgres) as recovered:
        assert recovered.execute('SELECT 1').fetchone()==(1,)

    wire=PostgreSQL(postgres)
    try:
        for i in range(16):
            wire.sock.sendall(frame(b'P',f'p{i}\0SELECT 1\0'.encode()+b'\0\0')+frame(b'S'))
            assert not any(tag==b'E' for tag,_ in wire.until(b'Z'))
        wire.sock.sendall(frame(b'P',b'excess\0SELECT 1\0\0\0')+frame(b'S'))
        assert any(tag==b'E' and b'54000' in payload for tag,payload in wire.until(b'Z'))
        for i in range(16):
            wire.sock.sendall(frame(b'C',f'Sp{i}\0'.encode()))
        wire.sock.sendall(frame(b'S'))
        wire.until(b'Z')
        wire.sock.sendall(frame(b'P',b'p\0SELECT 1\0\0\0')+b''.join(frame(b'B',f'b{i}\0p\0'.encode()+b'\0'*6) for i in range(5))+frame(b'S'))
        assert any(tag==b'E' and b'54000' in payload for tag,payload in wire.until(b'Z'))
        wire.sock.sendall(frame(b'Q',b'SELECT 1\0'))
        assert any(tag==b'D' for tag,_ in wire.until(b'Z'))
        # Oversized headers close before waiting for/allocating their payload.
        wire.sock.sendall(b'Q'+struct.pack('!I',4*1024*1024+8193))
        assert wire.sock.recv(1)==b''
    finally:
        wire.close()
    print(json.dumps(dict(profile='database_wire_capacity',normal_connections=8,authentications=4,reserved_cancel=True,health_progress=True,prepared_limit=16,portal_limit=4,oversized_header=True)),flush=True)


def drain(server, postgres, health_port):
    wire=PostgreSQL(postgres)
    try:
        wire.sock.sendall(frame(b'P',b'hold\0SELECT id FROM wire_rows\0\0\0')+frame(b'B',b'portal\0hold\0\0\0\0\0\0\0')+frame(b'E',b'portal\0'+struct.pack('!I',1))+frame(b'H'))
        assert wire.until(b's',b'E')[-1][0]==b's'
        server.terminate()
        deadline=time.monotonic()+2
        while True:
            try:
                health(health_port,503)
                break
            except AssertionError:
                assert time.monotonic()<deadline
                time.sleep(.01)
        assert server.wait(timeout=8)==0
    finally:
        wire.close()
    print(json.dumps(dict(profile='database_wire_drain',readiness_revoked=True,joined_exit=True)),flush=True)

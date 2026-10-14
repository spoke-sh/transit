"""Real TLS protocol failures, cycle admission and credential revocation."""
import base64
import hashlib
import hmac
import json
import os
import socket
import ssl
import struct
import time

import psycopg
import mysql.connector


def exact(sock, size):
    result = bytearray()
    while len(result) < size:
        chunk = sock.recv(size-len(result))
        if not chunk:
            raise EOFError('Peer closed frame')
        result.extend(chunk)
    return bytes(result)


def frame(tag, payload=b''):
    return tag + struct.pack('!I', len(payload)+4) + payload


class PostgreSQL:
    def __init__(self, options):
        self.sock = socket.create_connection((options['hostaddr'], options['port']), timeout=10)
        self.sock.sendall(struct.pack('!II', 8, 80877103))
        assert exact(self.sock, 1) == b'S'
        self.sock = ssl.create_default_context(cafile=options['sslrootcert']).wrap_socket(self.sock, server_hostname=options['host'])
        startup = b'user\0proof\0database\0data\0'
        self.sock.sendall(struct.pack('!II', len(startup)+9, 196608)+startup+b'\0')
        tag, payload = self.read()
        assert tag == b'R' and payload[:4] == struct.pack('!I', 10)
        nonce = base64.b64encode(os.urandom(18))
        first = b'n=proof,r='+nonce
        self.sock.sendall(frame(b'p', b'SCRAM-SHA-256\0'+struct.pack('!I', len(first)+3)+b'n,,'+first))
        tag, payload = self.read()
        assert tag == b'R' and payload[:4] == struct.pack('!I', 11)
        challenge = payload[4:]
        fields = dict(value.split(b'=', 1) for value in challenge.split(b','))
        assert fields[b'r'].startswith(nonce)
        salted = hashlib.pbkdf2_hmac('sha256', options['password'].encode(), base64.b64decode(fields[b's']), int(fields[b'i']))
        client_key = hmac.digest(salted, b'Client Key', 'sha256')
        final = b'c=biws,r='+fields[b'r']
        message = first+b','+challenge+b','+final
        signature = hmac.digest(hashlib.sha256(client_key).digest(), message, 'sha256')
        proof = bytes(a^b for a,b in zip(client_key, signature))
        self.sock.sendall(frame(b'p', final+b',p='+base64.b64encode(proof)))
        replies = self.until(b'Z')
        server = hmac.digest(hmac.digest(salted,b'Server Key','sha256'),message,'sha256')
        assert (b'R', struct.pack('!I',12)+b'v='+base64.b64encode(server)) in replies
        self.key = next(payload for tag,payload in replies if tag == b'K')

    def read(self):
        tag = exact(self.sock, 1)
        size = struct.unpack('!I', exact(self.sock, 4))[0]
        assert 4 <= size <= 4*1024*1024+8192
        return tag, exact(self.sock, size-4)

    def until(self, *tags):
        result = []
        while True:
            item = self.read()
            result.append(item)
            if item[0] in tags:
                return result

    def close(self):
        self.sock.close()

    def cycle(self, sql, tail):
        self.sock.sendall(frame(b'P', b'\0'+sql.encode()+b'\0\0\0')+frame(b'B', b'\0\0\0\0\0\0\0\0')+frame(b'E', b'\0\0\0\0\0')+tail)
        return self.until(b'Z')


def cancel(options, key):
    with socket.create_connection((options['hostaddr'],options['port']),timeout=5) as raw:
        raw.sendall(struct.pack('!II',8,80877103))
        assert exact(raw,1) == b'S'
        with ssl.create_default_context(cafile=options['sslrootcert']).wrap_socket(raw,server_hostname=options['host']) as secure:
            secure.sendall(struct.pack('!II',16,80877102)+key)
            assert secure.recv(1) == b''


def run(root, postgres, mysql_options, controls, native_access):
    def count(connection):
        deadline = time.monotonic()+10
        while True:
            try:
                return connection.execute('SELECT COUNT(*) FROM wire_rows').fetchone()[0]
            except psycopg.errors.InsufficientResources:
                # This explicit observation is a new read. No write is retried,
                # and no incomplete result is appended to an earlier result.
                assert time.monotonic() < deadline
                time.sleep(.05)
    with psycopg.connect(**postgres) as witness:
        baseline = count(witness)
        wire = PostgreSQL(postgres)
        try:
            sql = 'INSERT INTO wire_rows (id) VALUES (101)'
            for invalid in (frame(b'H')+frame(b'S'), frame(b'E', b'\0\0\0\0\0')+frame(b'S')):
                replies = wire.cycle(sql, invalid)
                assert any(tag == b'E' for tag,_ in replies)
                assert not any(tag == b'C' for tag,_ in replies)
                assert count(witness) == baseline
            replies = wire.cycle(sql, frame(b'S'))
            assert (b'C', b'INSERT 0 1\0') in replies
            assert count(witness) == baseline+1
            # Sync closes the portal. It cannot execute this write a second time.
            wire.sock.sendall(frame(b'E', b'\0\0\0\0\0')+frame(b'S'))
            assert any(tag == b'E' for tag,_ in wire.until(b'Z'))
            assert count(witness) == baseline+1
            witness.execute('INSERT INTO wire_rows (id) VALUES (102)')
            wire.sock.sendall(frame(b'P', b'hold\0SELECT id FROM wire_rows\0\0\0')+frame(b'B', b'portal\0hold\0\0\0\0\0\0\0')+frame(b'E', b'portal\0'+struct.pack('!I',1))+frame(b'H'))
            replies = wire.until(b's', b'E')
            assert sum(tag == b'D' for tag,_ in replies) == 1 and replies[-1][0] == b's'
            cancel(postgres, wire.key)
            wire.sock.sendall(frame(b'E', b'portal\0'+struct.pack('!I',1))+frame(b'S'))
            replies = wire.until(b'Z')
            assert any(tag == b'E' and b'57014' in payload for tag,payload in replies)
            assert not any(tag == b'D' for tag,_ in replies)
            wire.sock.sendall(frame(b'Q', b'SELECT 1\0'))
            assert any(tag == b'D' for tag,_ in wire.until(b'Z'))
            # A complete admitted write survives losing its database reply.
            wire.sock.sendall(frame(b'Q', b'INSERT INTO wire_rows (id) VALUES (103)\0'))
        finally:
            wire.close()
        deadline = time.monotonic()+30
        while count(witness) != baseline+3:
            assert time.monotonic() < deadline, 'Detached write did not complete'
            time.sleep(.05)
        page = controls('list')
        assert page['entries'] and all('matched' not in entry for entry in page['entries'])

    for changes in ({'password':'wrong'}, {'user':'other'}, {'dbname':'other'}, {'sslmode':'disable'}, {'host':'wrong.invalid'}, {'sslrootcert':str(root/'key.pem')}):
        try:
            psycopg.connect(**(postgres | changes)).close()
        except psycopg.Error:
            pass
        else:
            raise AssertionError(f'PostgreSQL admitted invalid connection: {list(changes)}')
    for changes in ({'password':'wrong'}, {'user':'other'}, {'database':'other'}, {'ssl_disabled':True}):
        try:
            mysql.connector.connect(**(mysql_options | changes)).close()
        except mysql.connector.Error:
            pass
        else:
            raise AssertionError(f'MySQL admitted invalid connection: {list(changes)}')

    with mysql.connector.connect(**mysql_options) as connection:
        raw = connection._socket.sock
        def command(payload):
            raw.sendall(len(payload).to_bytes(3,'little')+b'\0'+payload)
            header=exact(raw,4)
            assert header[3] == 1
            return exact(raw,int.from_bytes(header[:3],'little'))
        assert command(b'\xff')[0] == 255
        assert command(b'\x0e')[0] == 0
        assert command(b'\x03BEGIN')[0] == 255
        assert command(b'\x03SET autocommit=0')[0] == 255
        assert command(b'\x03INSERT INTO wire_rows (id) VALUES (104); INSERT INTO wire_rows (id) VALUES (105)')[0] == 255
        assert command(b'\x0e')[0] == 0

    with psycopg.connect(**postgres) as pg, mysql.connector.connect(**mysql_options) as my:
        pg.execute('SELECT id FROM wire_rows WHERE id=%s',(101,),prepare=True).fetchone()
        cursor=my.cursor(prepared=True)
        cursor.execute('SELECT id FROM wire_rows WHERE id=%s',(101,))
        cursor.fetchall()
        held=PostgreSQL(postgres)
        try:
            held.sock.sendall(frame(b'P',b'hold\0SELECT id FROM wire_rows\0\0\0')+frame(b'B',b'portal\0hold\0\0\0\0\0\0\0')+frame(b'E',b'portal\0'+struct.pack('!I',1))+frame(b'H'))
            assert held.until(b's',b'E')[-1][0] == b's'
            native_access(False)
            for execute,error in ((lambda:pg.execute('SELECT id FROM wire_rows WHERE id=%s',(101,),prepare=True),psycopg.errors.InsufficientPrivilege),(lambda:cursor.execute('SELECT id FROM wire_rows WHERE id=%s',(101,)),mysql.connector.Error)):
                try:
                    execute()
                except error:
                    pass
                else:
                    raise AssertionError('Prepared execution disclosed revoked native data')
            held.sock.sendall(frame(b'E',b'portal\0'+struct.pack('!I',1))+frame(b'S'))
            replies=held.until(b'Z')
            assert any(tag==b'E' and b'42501' in payload for tag,payload in replies)
            assert not any(tag==b'D' for tag,_ in replies)
        finally:
            native_access(True)
            held.close()
        assert pg.execute('SELECT COUNT(*) FROM wire_rows').fetchone() == (3,)
    credential_file=root/'gateway-credential.json'
    original=json.loads(credential_file.read_text())
    def replace(value):
        temporary=root/'credential-next.json'
        temporary.write_text(json.dumps(value))
        temporary.chmod(0o600)
        temporary.replace(credential_file)
    with psycopg.connect(**postgres) as pg, mysql.connector.connect(**mysql_options) as my:
        pg.execute('SELECT id FROM wire_rows WHERE id=%s',(101,),prepare=True).fetchone()
        cursor=my.cursor(prepared=True)
        cursor.execute('SELECT id FROM wire_rows WHERE id=%s',(101,))
        cursor.fetchall()
        replace(original | {'revision':original['revision']+1})
        try:
            for execute, error in ((lambda:pg.execute('SELECT 1'),psycopg.Error),(lambda:cursor.execute('SELECT 1'),mysql.connector.Error)):
                try:
                    execute()
                except error:
                    pass
                else:
                    raise AssertionError('Old authenticated session survived credential rotation')
            with psycopg.connect(**postgres) as fresh:
                assert fresh.execute('SELECT 1').fetchone() == (1,)
            replace(original | {'revision':original['revision']+2,'enabled':False})
            for connect,error in ((lambda:psycopg.connect(**postgres),psycopg.Error),(lambda:mysql.connector.connect(**mysql_options),mysql.connector.Error)):
                try:
                    connect().close()
                except error:
                    pass
                else:
                    raise AssertionError('Disabled credential authenticated')
        finally:
            replace(original | {'revision':original['revision']+3})
    print(json.dumps(dict(profile='database_wire_faults', deferred_write_cycles=True, suspended_cancel=True, detached_write=True, invalid_connections=10, native_revocation=True, credential_rotation=True)), flush=True)

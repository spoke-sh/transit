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


def exact(sock, size, deadline=None):
    result = bytearray()
    while len(result) < size:
        if deadline is not None:
            remaining = deadline-time.monotonic()
            if remaining <= 0:
                raise TimeoutError('PostgreSQL response deadline expired')
            sock.settimeout(remaining)
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

    def read(self, deadline=None):
        tag = exact(self.sock, 1, deadline)
        size = struct.unpack('!I', exact(self.sock, 4, deadline))[0]
        assert 4 <= size <= 4*1024*1024+8192
        return tag, exact(self.sock, size-4, deadline)

    def until(self, *tags, timeout=None):
        result = []
        previous = self.sock.gettimeout()
        deadline = None if timeout is None else time.monotonic()+timeout
        try:
            while True:
                item = self.read(deadline)
                result.append(item)
                if item[0] in tags:
                    return result
        finally:
            self.sock.settimeout(previous)

    def close(self):
        self.sock.close()

    def cycle(self, sql, tail, *, timeout=None):
        self.sock.sendall(frame(b'P', b'\0'+sql.encode()+b'\0\0\0')+frame(b'B', b'\0\0\0\0\0\0\0\0')+frame(b'E', b'\0\0\0\0\0')+tail)
        return self.until(b'Z', timeout=timeout)


def cancel(options, key):
    with socket.create_connection((options['hostaddr'],options['port']),timeout=5) as raw:
        raw.sendall(struct.pack('!II',8,80877103))
        assert exact(raw,1) == b'S'
        with ssl.create_default_context(cafile=options['sslrootcert']).wrap_socket(raw,server_hostname=options['host']) as secure:
            secure.sendall(struct.pack('!II',16,80877102)+key)
            assert secure.recv(1) == b''


def run(root, postgres, mysql_options, controls, inventory, read_access, write_access):
    def count(connection):
        deadline = time.monotonic()+30
        while True:
            try:
                return connection.execute('SELECT COUNT(*) FROM wire_rows').fetchone()[0]
            except (psycopg.errors.InsufficientResources, psycopg.errors.ObjectNotInPrerequisiteState):
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
            # Authentication and malformed-cycle replies keep the ten-second
            # socket bound. This valid durable write may use the configured
            # 270-second SQL wait; allow its terminal reply under one absolute
            # 300-second client deadline, without resending the statement.
            started = time.monotonic()
            replies = wire.cycle(sql, frame(b'S'), timeout=300)
            assert (b'C', b'INSERT 0 1\0') in replies
            print(json.dumps(dict(profile='database_wire_valid_write_cycle',seconds=round(time.monotonic()-started,3),client_wait_seconds=300,sql_wait_seconds=270)),flush=True)
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
            before_detached = {entry['operation'] for entry in inventory()}
            wire.sock.sendall(frame(b'Q', b'INSERT INTO wire_rows (id) VALUES (103)\0'))
        finally:
            wire.close()
        # Losing the socket does not reduce the admitted write's 270-second
        # allowance. Only fresh reads are retried; the write is never resent.
        detached_started = time.monotonic()
        deadline = detached_started+300
        while count(witness) != baseline+3:
            assert time.monotonic() < deadline, 'Detached write did not complete'
            time.sleep(.05)
        page = controls('list')
        assert page['entries'] and all('matched' not in entry for entry in page['entries'])
        detached = {entry['operation'] for entry in inventory()} - before_detached
        assert len(detached) == 1, detached
        committed_operation = detached.pop()
        while True:
            committed = controls('status',committed_operation)['terminal']
            if committed is not None:
                break
            assert time.monotonic() < deadline, 'Detached outcome did not settle'
            time.sleep(.05)
        assert (committed['state'], committed['matched'], committed['changed']) == ('applied', 1, 1), committed
        print(json.dumps(dict(profile='database_wire_detached_write',seconds=round(time.monotonic()-detached_started,3),client_wait_seconds=300,exact_operation=committed_operation)),flush=True)

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
            metadata = PostgreSQL(postgres)
            # mysql.connector.cursor() first pings the server. Acquire the
            # handle before revocation so this exercises PREPARE itself.
            metadata_cursor = my.cursor(prepared=True)
            assert read_access(False)['read'] is False
            # INSERT evidence uses current INSERT authority, independently of
            # SELECT. Inspect the exact detached DML, not an older DDL entry.
            assert controls('status',committed_operation)['terminal'] == committed
            assert write_access(False)['write'] is False
            try:
                try:
                    controls('status',committed_operation)
                except AssertionError as error:
                    assert 'AccessDenied' in str(error), str(error)
                else:
                    raise AssertionError('Operator disclosed an INSERT outcome after INSERT revocation')
            finally:
                assert write_access(True)['write'] is True
            assert controls('status',committed_operation)['terminal'] == committed
            try:
                metadata.sock.sendall(frame(b'P',b'denied\0SELECT id FROM wire_rows\0\0\0')+frame(b'D',b'Sdenied\0')+frame(b'S'))
                replies = metadata.until(b'Z')
                assert any(tag == b'E' and b'42501' in payload for tag,payload in replies)
                assert not any(tag in (b'T',b't',b'D') for tag,_ in replies)
            finally:
                metadata.close()
            try:
                metadata_cursor.execute('SELECT n FROM wire_rows')
            except mysql.connector.Error as error:
                assert error.errno == 1142 and metadata_cursor.description is None
            else:
                raise AssertionError('MySQL disclosed revoked preparation metadata')
            finally:
                metadata_cursor.close()
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
            assert read_access(True)['read'] is True
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
        password_file = root/'rotation-password'
        password_file.write_bytes(b'proof-password')
        password_file.chmod(0o600)
        assert controls('credential',password_file,credential_file,original['revision']+1)['revision'] == original['revision']+1
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
    # A password verifier is bound to a native identity, not an independent
    # source of role grants. Altering any binding fails new authentication.
    current = json.loads(credential_file.read_text())
    for field in ('principal', 'login_role', 'credential_epoch'):
        replace(current | {field: current[field] + 1})
        try:
            for connect, error in ((lambda: psycopg.connect(**postgres), psycopg.Error),
                                   (lambda: mysql.connector.connect(**mysql_options), mysql.connector.Error)):
                try:
                    connect().close()
                except error:
                    pass
                else:
                    raise AssertionError(f'Forged native {field} authenticated')
        finally:
            replace(current)
    print(json.dumps(dict(profile='database_wire_faults', deferred_write_cycles=True, suspended_cancel=True, detached_write=True, invalid_connections=10, native_revocation=True,revoked_metadata_suppressed=True,revoked_terminal_suppressed=True,select_revocation_keeps_mutation_receipt=True,exact_detached_outcome=True,credential_rotation=True, credential_cli=True,native_identity_binding=True)), flush=True)

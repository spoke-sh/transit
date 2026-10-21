"""Independent HTTPS client for the native session and durable admission contract."""
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import hmac
import http.client
import json
import os
from pathlib import Path
import ssl
import subprocess
import socket
import shutil
import time


def mac(key, text):
    return hmac.new(key, text.encode() if isinstance(text, str) else text, hashlib.sha256).digest()


class Client:
    def __init__(self, root, port):
        self.root, self.port = root, port
        self.instance = self.session = self.account = None
        self.last = 0
        self.definition = json.loads((root / 'sql-gateway.json').read_text())['definition']
        self.transport()

    def transport(self):
        self.http = http.client.HTTPSConnection('localhost', self.port, context=ssl.create_default_context(cafile=str(self.root / 'certificate.pem')), timeout=40)

    def call(self, action, *, error=None, headers=None, lane=None, patch=None, unavailable=False):
        started = time.perf_counter()
        if time.monotonic() - self.last >= .5:
            self.http.close()
            self.transport()
        name = action if isinstance(action, str) else next(iter(action))
        control = name in ('cancel', 'status', 'resume', 'operations', 'close', 'close_result')
        if isinstance(action, str):
            action = {action: {}}
        body = dict(version=1, definition=self.definition, instance=self.instance, session=self.session, action=action)
        body.update(patch or {})
        content = json.dumps(body)
        reused = self.http.sock is not None
        self.http.request('POST', lane or ('/v1/sql/control' if control else '/v1/sql/session'), content, headers or {'Content-Type': 'application/json'})
        response = self.http.getresponse()
        raw = response.read()
        self.last = time.monotonic()
        self.sample = dict(milliseconds=round((time.perf_counter()-started)*1000, 3),
                           request_bytes=len(content.encode()), response_bytes=len(raw), reused_tls=reused)
        assert response.status == 200, (response.status, raw)
        assert response.getheader('Cache-Control') == 'no-store'
        value = json.loads(raw)
        assert value['definition'] == self.definition
        if self.instance is None:
            self.instance = value['instance']
        assert value['instance'] == self.instance
        result = value['result']
        if unavailable and isinstance(result, dict) and result.get('err', {}).get('code') == 'AuthorityUnavailable':
            return None
        if error:
            assert result['err']['code'] == error, result
        else:
            assert not isinstance(result, dict) or 'err' not in result, result
        return result

    def open(self, source=None, *, password='proof-password', error=None):
        assert self.call('hello')['hello']['encoding'] == 'transit.logical.v1.hex'
        nonce = base64.b64encode(os.urandom(18)).decode()
        bare = f'n=,r={nonce}'
        challenge = self.call(dict(open=dict(account='proof', database='data', source=source, authentication='scram', first='n,,' + bare)))['challenge']
        server = challenge['message']
        values = dict(field.split('=', 1) for field in server.split(','))
        assert values['r'].startswith(nonce) and len(values['r']) > len(nonce)
        binding = json.dumps([self.definition, self.instance, 'proof', 'data', source], separators=(',', ':')).encode()
        assert values['b'] == hashlib.sha256(binding).hexdigest()
        salted = hashlib.pbkdf2_hmac('sha256', password.encode(), base64.b64decode(values['s']), int(values['i']))
        client_key = mac(salted, 'Client Key')
        final = f"c=biws,r={values['r']}"
        message = f'{bare},{server},{final}'
        signature = mac(hashlib.sha256(client_key).digest(), message)
        proof = base64.b64encode(bytes(a ^ b for a, b in zip(client_key, signature))).decode()
        result = self.call(dict(authenticate=dict(challenge=challenge['id'], final=final + ',p=' + proof)), error=error)
        if error:
            assert self.session is None
            return self
        opened = result['opened']
        assert opened['proof'] == 'v=' + base64.b64encode(mac(mac(salted, 'Server Key'), message)).decode()
        self.session, self.account = opened['session'], opened['account']
        return self

    def execute(self, sql, token=None, **kwargs):
        return self.call(dict(execute=dict(sql=sql, token=token, **kwargs)))

    def terminal(self, operation):
        deadline = time.monotonic() + (270 if operation['identity']['kind'] == 'captured' else 90)
        while operation['phase'] != 'terminal':
            assert not operation['blocked'] and time.monotonic() < deadline, operation
            time.sleep(.03)
            # A failed observation never establishes absence or authorizes
            # replay. Poll only the already admitted identity after pressure.
            observed = self.call(dict(status=dict(operation=operation['identity'])), unavailable=True)
            if observed is not None:
                operation = observed['operation']
        assert operation['outcome'] in ('applied', 'unchanged'), operation
        return operation

    def close(self):
        if self.session is not None:
            self.call('close')
            self.session = None
        self.http.close()


def run(root, port, postgres, restart, console, authorize, select_source, sources=None, faults=None, service_pid=None):
    first, second = Client(root, port).open(), Client(root, port).open()
    assert first.session != second.session and first.account == second.account
    token = list(os.urandom(16))
    created = first.execute('CREATE TABLE native_sessions (id INT64 PRIMARY KEY, value INT128)', token)['operation']
    first.terminal(created)
    # Failures are produced by the actual shared compiler, before token admission.
    for statement, code in (
        ('SELECT;', 'InvalidSqlSyntax'),
        ('SELECT absent FROM native_sessions', 'UnknownColumn'),
        ('SELECT wrong.id FROM native_sessions AS n', 'UnknownQualifier'),
        ('SELECT id AS copy, value AS copy FROM native_sessions', 'DuplicateColumn'),
    ):
        rejected = first.call(dict(execute=dict(sql=statement, token=list(os.urandom(16)))), error=code)['err']
        assert rejected['diagnostic']['outcome'] == 'not_submitted', rejected
        assert rejected['sqlstate'] in (list(b'42601'), list(b'22023')), rejected
    # Original token returns its original operation without recompiling CREATE.
    assert second.execute('CREATE TABLE native_sessions (id INT64 PRIMARY KEY, value INT128)', token)['operation']['identity'] == created['identity']
    second.call(dict(execute=dict(sql='CREATE TABLE changed (id INT64)', token=token)), error='SqlTokenConflict')
    insert_token = list(os.urandom(16))
    first.terminal(first.execute('INSERT INTO native_sessions VALUES (1, 170141183460469231731687303715884105727)', insert_token)['operation'])
    one = first.execute('SELECT * FROM native_sessions')['batch']
    assert one['rows'][0][1] == (b'\x03' + (2**127 - 1).to_bytes(16, 'little', signed=True)).hex(), one
    # Last-batch retries and a replaced HTTP connection retain the exact result.
    first.http.close()
    first.transport()
    assert first.call(dict(fetch=dict(cursor=one['cursor'], batch=one['batch'])))['batch'] == one
    first.call(dict(fetch=dict(cursor=one['cursor'], batch=one['batch'] + 2)), error='InvalidSqlCursor')
    # Invalid cursor sequencing clears the cursor, never reopens its snapshot.
    first.call(dict(fetch=dict(cursor=one['cursor'], batch=one['batch'])), error='SqlResultIncomplete')
    desc = first.execute('DESCRIBE native_sessions')['batch']
    assert desc['rows'] and len(desc['rows'][0]) == 9
    first.call(dict(close_result=desc['cursor']))
    explain = first.execute('EXPLAIN SELECT id FROM native_sessions')['batch']
    assert explain['rows']
    first.call(dict(close_result=explain['cursor']))
    with ThreadPoolExecutor(max_workers=2) as pool:
        replies = list(pool.map(lambda c: c.execute('SELECT id FROM native_sessions'), (first, second)))
    for client, reply in zip((first, second), replies):
        client.call(dict(close_result=reply['batch']['cursor']))
    # The same table is visible through the ordinary PostgreSQL adapter.
    import psycopg
    with psycopg.connect(**postgres) as wire:
        assert wire.execute('SELECT id FROM native_sessions').fetchall() == [(1,)]
    from sql_sessions.boundaries import run as boundaries
    boundaries(first, second, created['identity'])
    if faults is not None:
        faults.check(first)
    from sql_sessions.security import sessions as session_security
    session_security(Client, first, second, created['identity'])
    from sql_sessions.measurements import reads
    reads(first, second, faults, service_pid)
    reload_token = list(os.urandom(16))
    reload = first.terminal(first.execute('SELECT transit_reload_conf()', reload_token)['operation'])
    assert reload['identity']['kind'] == 'configuration' and reload['owner_operation'] is not None
    assert reload['configuration_phase'] in ('applied', 'pending_restart')
    duplicate = second.execute('SELECT transit_reload_conf()', reload_token)['operation']
    assert duplicate['identity'] == reload['identity'] and duplicate['owner_operation'] == reload['owner_operation']
    second.call(dict(cancel=dict(operation=reload['identity'])), error='ConfigurationCancellationUnsupported')
    captured = []
    for name, count in ((('kv', 41), ('document', 12), ('table', 9)) if sources is None else sources):
        select_source(name)
        selected = Client(root, port).open(name)
        context = selected.call('context')['context']
        assert {source['name'] for source in context['sources']} == ({'kv', 'document', 'table'} if sources is None else {name for name, _ in sources})
        batch = selected.execute('SELECT count(*) FROM items')['batch']
        assert batch['rows'] == [[(b'\x03' + count.to_bytes(8, 'little')).hex()]], batch
        assert batch['basis']['source']['kind'] == name
        selected.call(dict(close_result=batch['cursor']))
        token = list(os.urandom(16))
        operation = selected.execute('SELECT value FROM items', token, captured=True)['operation']
        assert operation['identity']['kind'] == 'captured' and operation['phase'] != 'reserved'
        selected.call(dict(execute=dict(sql='SELECT count(*) FROM items', token=token, captured=True)), error='SqlTokenConflict')
        captured.append((name, count, token, operation['identity']))
        selected.close()
    first.close()
    second.close()
    restart(wire=False)
    restored = Client(root, port).open()
    prior = restored.call(dict(status=dict(token=insert_token)))['operation']
    assert prior['phase'] == 'terminal' and prior['changed'] == 1
    assert restored.execute('INSERT INTO native_sessions VALUES (1, 170141183460469231731687303715884105727)', insert_token)['operation']['identity'] == prior['identity']
    recovered_reload = restored.call(dict(status=dict(token=reload_token)))['operation']
    assert recovered_reload['identity'] == reload['identity'] and recovered_reload['owner_operation'] == reload['owner_operation']
    inventory = restored.call(dict(operations=dict(after=0)))['operations']
    assert prior['identity'] in [entry['identity'] for entry in inventory['entries']]
    restored.close()
    for name, count, token, identity in captured:
        select_source(name)
        selected = Client(root, port).open(name)
        original = selected.execute('SELECT value FROM items', token, captured=True)['operation']
        assert original['identity'] == identity
        selected.terminal(original)
        result = selected.call(dict(result=identity))['batch']
        batches = [dict(selected.sample, rows=len(result['rows']))]
        rows = []
        while True:
            assert selected.call(dict(fetch=dict(cursor=result['cursor'], batch=result['batch'])))['batch'] == result
            assert result['basis']['source']['kind'] == name
            rows.extend(result['rows'])
            if result['complete']:
                break
            result = selected.call(dict(fetch=dict(cursor=result['cursor'], batch=result['batch']+1)))['batch']
            batches.append(dict(selected.sample, rows=len(result['rows'])))
        assert len(rows) == count
        print(json.dumps(dict(profile='native_sql_retained_batches', source=name, rows=count,
                              batches=batches, logical_cell_bytes=sum(len(cell)//2 for row in rows for cell in row),
                              limits='Retained result after SQL service restart. Every returned batch is retried for exact equality; retry latency/bytes are excluded here. HTTP body bytes include schema and source basis. This does not measure ledger/storage bytes or isolate concurrent recovery.')), flush=True)
        selected.call(dict(close_result=result['cursor']))
        selected.close()
    select_source(None)
    if any(name == 'kv' for name, _, _, _ in captured):
        # Admission and cancellation remain available while the captured owner
        # is stopped. Resume settles any already published step before cancel.
        selected = Client(root, port).open('kv')
        cancel_token = list(os.urandom(16))
        pending = selected.execute('SELECT value FROM items', cancel_token, captured=True)['operation']
        cancelled = selected.call(dict(cancel=dict(operation=pending['identity'])))['operation']
        assert cancelled['cancellation_requested']
        select_source('kv')
        deadline = time.monotonic() + 270
        while cancelled['phase'] != 'terminal':
            assert time.monotonic() < deadline, cancelled
            time.sleep(.1)
            cancelled = selected.call(dict(status=dict(operation=pending['identity'])))['operation']
        assert cancelled['outcome'] == 'cancelled', cancelled
        assert selected.execute('SELECT value FROM items', cancel_token, captured=True)['operation']['identity'] == pending['identity']
        selected.call(dict(result=pending['identity']), error='IncompleteResult')
        selected.close()
        select_source(None)
    first = Client(root, port).open()
    protected = first.execute('SELECT id FROM native_sessions')['batch']
    authorize(False)
    denied = first.call(dict(fetch=dict(cursor=protected['cursor'], batch=protected['batch'])), error='AccessDenied')['err']
    assert denied['sqlstate'] == list(b'42501')
    authorize(True)
    first.call(dict(fetch=dict(cursor=protected['cursor'], batch=protected['batch'])), error='SqlResultIncomplete')
    first.close()
    consumer = root/'consumer'
    consumer.mkdir()
    home = consumer/'home'
    home.mkdir()
    client_environment = {'PATH': '/unavailable', 'LANG': 'C', 'HOME': str(home)}
    certificate = consumer/'ca.pem'
    shutil.copyfile(root/'certificate.pem', certificate)
    password = consumer/'password'
    password.write_text('proof-password')
    password.chmod(0o600)
    config = consumer/'connection.yaml'
    config.write_text(f'version: 1\nendpoint: https://localhost:{port}\naccount: proof\ndatabase: data\nauthentication: scram\nca_file: {certificate}\npassword_file: {password}\nformat: json\n')
    from sql_sessions.security import console as console_security
    console_security(console, consumer, config, password, port, client_environment)
    def console_read(_):
        result = subprocess.run([console, 'console', '--config', str(config), '-c', 'SELECT id FROM native_sessions'], cwd=consumer, env=client_environment, capture_output=True, text=True, timeout=60)
        assert result.returncode == 0, result.stderr
        assert '"complete_coverage":true' in result.stdout, result.stdout
        return result.stdout
    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(console_read, range(2)))
    if faults is not None:
        restart(wire=False, idle_ms=1000)
        leased = Client(root, port).open()
        for _ in range(6):
            assert leased.call(dict(status=dict(operation=created['identity'])))['operation']['phase'] == 'terminal'
            time.sleep(.25)
        time.sleep(1.2)
        leased.call(dict(status=dict(operation=created['identity'])), error='SqlSessionExpired')
        leased.session = None
        leased.close()
        renewed = Client(root, port).open()
        assert renewed.call(dict(status=dict(operation=created['identity'])))['operation']['identity'] == created['identity']
        renewed.close()
    restart(peer=True)
    config.write_text(f'version: 1\nendpoint: unix:{root/"native.sock"}\naccount: proof\ndatabase: data\nauthentication: peer\nformat: json\n')
    password.unlink()
    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(console_read, range(2)))
    assert not list(consumer.glob('*.lock')) and not list(consumer.glob('*recovery*'))
    print(json.dumps(dict(profile='native_sql_sessions', remote_tls=True, independent_scram=True, concurrent_sessions=True, wide_logical_values=True, token_recovery_after_restart=True)), flush=True)

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

    def call(self, action, *, error=None, headers=None, lane=None):
        if time.monotonic() - self.last >= .5:
            self.http.close()
            self.transport()
        name = action if isinstance(action, str) else next(iter(action))
        control = name in ('cancel', 'status', 'resume', 'operations', 'close', 'close_result')
        if isinstance(action, str):
            action = {action: {}}
        body = dict(version=1, definition=self.definition, instance=self.instance, session=self.session, action=action)
        self.http.request('POST', lane or ('/v1/sql/control' if control else '/v1/sql/session'), json.dumps(body), headers or {'Content-Type': 'application/json'})
        response = self.http.getresponse()
        raw = response.read()
        self.last = time.monotonic()
        assert response.status == 200, (response.status, raw)
        assert response.getheader('Cache-Control') == 'no-store'
        value = json.loads(raw)
        assert value['definition'] == self.definition
        if self.instance is None:
            self.instance = value['instance']
        assert value['instance'] == self.instance
        result = value['result']
        if error:
            assert result['err']['code'] == error, result
        else:
            assert not isinstance(result, dict) or 'err' not in result, result
        return result

    def open(self, source=None):
        assert self.call('hello')['hello']['encoding'] == 'transit.logical.v1.hex'
        nonce = base64.b64encode(os.urandom(18)).decode()
        bare = f'n=,r={nonce}'
        challenge = self.call(dict(open=dict(account='proof', database='data', source=source, authentication='scram', first='n,,' + bare)))['challenge']
        server = challenge['message']
        values = dict(field.split('=', 1) for field in server.split(','))
        assert values['r'].startswith(nonce) and len(values['r']) > len(nonce)
        binding = json.dumps([self.definition, self.instance, 'proof', 'data', source], separators=(',', ':')).encode()
        assert values['b'] == hashlib.sha256(binding).hexdigest()
        salted = hashlib.pbkdf2_hmac('sha256', b'proof-password', base64.b64decode(values['s']), int(values['i']))
        client_key = mac(salted, 'Client Key')
        final = f"c=biws,r={values['r']}"
        message = f'{bare},{server},{final}'
        signature = mac(hashlib.sha256(client_key).digest(), message)
        proof = base64.b64encode(bytes(a ^ b for a, b in zip(client_key, signature))).decode()
        opened = self.call(dict(authenticate=dict(challenge=challenge['id'], final=final + ',p=' + proof)))['opened']
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
            operation = self.call(dict(status=dict(operation=operation['identity'])))['operation']
        assert operation['outcome'] in ('applied', 'unchanged'), operation
        return operation

    def close(self):
        if self.session is not None:
            self.call('close')
            self.session = None
        self.http.close()


def run(root, port, postgres, restart, console):
    first, second = Client(root, port).open(), Client(root, port).open()
    assert first.session != second.session and first.account == second.account
    token = list(os.urandom(16))
    created = first.execute('CREATE TABLE native_sessions (id INT64 PRIMARY KEY, value INT128)', token)['operation']
    first.terminal(created)
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
    reload_token = list(os.urandom(16))
    reload = first.terminal(first.execute('SELECT transit_reload_conf()', reload_token)['operation'])
    assert reload['identity']['kind'] == 'configuration' and reload['owner_operation'] is not None
    assert reload['configuration_phase'] in ('applied', 'pending_restart')
    duplicate = second.execute('SELECT transit_reload_conf()', reload_token)['operation']
    assert duplicate['identity'] == reload['identity'] and duplicate['owner_operation'] == reload['owner_operation']
    second.call(dict(cancel=dict(operation=reload['identity'])), error='ConfigurationCancellationUnsupported')
    captured = []
    for name, count in (('kv', 41), ('document', 12)):
        selected = Client(root, port).open(name)
        context = selected.call('context')['context']
        assert {source['name'] for source in context['sources']} == {'kv', 'document'}
        batch = selected.execute('SELECT count(*) FROM items')['batch']
        assert batch['rows'] == [[(b'\x03' + count.to_bytes(8, 'little')).hex()]], batch
        assert batch['basis']['source']['kind'] == name
        selected.call(dict(close_result=batch['cursor']))
        token = list(os.urandom(16))
        operation = selected.execute('SELECT value FROM items', token, captured=True)['operation']
        assert operation['identity']['kind'] == 'captured' and operation['phase'] != 'reserved'
        captured.append((name, count, token, operation['identity']))
        selected.close()
    first.close()
    second.close()
    restart()
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
        selected = Client(root, port).open(name)
        original = selected.execute('SELECT value FROM items', token, captured=True)['operation']
        assert original['identity'] == identity
        selected.terminal(original)
        result = selected.call(dict(result=identity))['batch']
        rows = []
        while True:
            assert selected.call(dict(fetch=dict(cursor=result['cursor'], batch=result['batch'])))['batch'] == result
            assert result['basis']['source']['kind'] == name
            rows.extend(result['rows'])
            if result['complete']:
                break
            result = selected.call(dict(fetch=dict(cursor=result['cursor'], batch=result['batch']+1)))['batch']
        assert len(rows) == count
        selected.call(dict(close_result=result['cursor']))
        selected.close()
    consumer = root/'consumer'
    consumer.mkdir()
    password = consumer/'password'
    password.write_text('proof-password')
    password.chmod(0o600)
    config = consumer/'connection.yaml'
    config.write_text(f'version: 1\nendpoint: https://localhost:{port}\naccount: proof\ndatabase: data\nauthentication: scram\nca_file: {root/"certificate.pem"}\npassword_file: {password}\nformat: json\n')
    def console_read(_):
        result = subprocess.run([console, 'console', '--config', str(config), '-c', 'SELECT id FROM native_sessions'], cwd=consumer, capture_output=True, text=True, timeout=60)
        assert result.returncode == 0, result.stderr
        assert '"complete_coverage":true' in result.stdout, result.stdout
        return result.stdout
    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(console_read, range(2)))
    restart(peer=True)
    config.write_text(f'version: 1\nendpoint: unix:{root/"native.sock"}\naccount: proof\ndatabase: data\nauthentication: peer\nformat: json\n')
    password.unlink()
    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(console_read, range(2)))
    assert not list(consumer.glob('*.lock')) and not list(consumer.glob('*recovery*'))
    print(json.dumps(dict(profile='native_sql_sessions', remote_tls=True, independent_scram=True, concurrent_sessions=True, wide_logical_values=True, token_recovery_after_restart=True)), flush=True)

"""Independent HTTPS client for the native session and durable admission contract."""
import base64
from concurrent.futures import ThreadPoolExecutor
from contextlib import nullcontext
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
from interfaces.sql_sessions.result_frame import Decoder, ENCODING


def mac(key, text):
    return hmac.new(key, text.encode() if isinstance(text, str) else text, hashlib.sha256).digest()


class Client:
    def __init__(self, root, port):
        self.root, self.port = root, port
        self.instance = self.session = self.account = None
        self.last = 0
        self.results = {}
        self.decoder = Decoder()
        self.definition = json.loads((root / 'sql-gateway.json').read_text())['definition']
        self.transport()

    def transport(self):
        self.http = http.client.HTTPSConnection('localhost', self.port, context=ssl.create_default_context(cafile=str(self.root / 'certificate.pem')), timeout=40)

    def call(self, action, *, error=None, headers=None, lane=None, patch=None, unavailable=False, capacity=False):
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
        value = self.decoder.response(raw, response.getheader('Content-Type'), self.definition)
        assert value['definition'] == self.definition
        if self.instance is None:
            self.instance = value['instance']
        assert value['instance'] == self.instance
        result = value['result']
        if unavailable and isinstance(result, dict) and result.get('err', {}).get('code') == 'AuthorityUnavailable':
            return None
        if capacity and isinstance(result, dict):
            failure = result.get('err', {})
            if failure.get('code') == 'AuthorityUnavailable' and failure.get('sqlstate') == list(b'53000'):
                return None
        if error:
            assert result['err']['code'] == error, result
        else:
            assert not isinstance(result, dict) or 'err' not in result, result
        if 'batch' in result:
            batch = result['batch']
            assert batch['complete'] == (batch['completion'] is not None), batch
            assert batch['rows'] or batch['complete'], batch
            assert len(batch['rows']) <= 32
            identity = tuple(batch['cursor'])
            previous = self.results.get(identity)
            if previous is None:
                assert batch['batch'] == 0, batch
                received = len(batch['rows'])
            else:
                prior, received = previous
                assert batch['schema'] == prior['schema'] and batch['observation'] == prior['observation']
                if batch['batch'] == prior['batch']:
                    assert batch == prior
                else:
                    assert not prior['complete'] and batch['batch'] == prior['batch'] + 1
                    received += len(batch['rows'])
            if batch['complete']:
                assert batch['completion']['rows'] == received, (batch, received)
            self.results[identity] = (batch, received)
        if 'operation' in result and result['operation']['phase'] == 'terminal':
            assert result['operation']['command'] is not None, result
        return result

    def open(self, source=None, *, password='proof-password', error=None, account='proof'):
        assert self.call('hello')['hello']['encoding'] == ENCODING
        nonce = base64.b64encode(os.urandom(18)).decode()
        bare = f'n=,r={nonce}'
        challenge = self.call(dict(open=dict(account=account, database='data', source=source, authentication='scram', first='n,,' + bare)))['challenge']
        server = challenge['message']
        values = dict(field.split('=', 1) for field in server.split(','))
        assert values['r'].startswith(nonce) and len(values['r']) > len(nonce)
        binding = json.dumps([self.definition, self.instance, account, 'data', source], separators=(',', ':')).encode()
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

    def concurrent_read(self, sql='SELECT id FROM native_sessions'):
        # The bounded native service may reject simultaneous requests. This
        # fixture explicitly issues another SELECT only before receiving any
        # batch. It never retries a write, fetch or an existing result snapshot.
        started = time.perf_counter()
        deadline = time.monotonic() + 15
        attempts = 0
        while True:
            attempts += 1
            result = self.call(dict(execute=dict(sql=sql, token=None)), capacity=True)
            if result is not None:
                self.sample.update(milliseconds=round((time.perf_counter()-started)*1000, 3), sql_requests=attempts)
                return result
            assert time.monotonic() < deadline, 'concurrent read capacity did not recover'
            time.sleep(.02)

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


def run(root, port, postgres, restart, console, authorize, select_source, source_pin, sources=None, faults=None, service_pid=None, authorize_reads=None):
    first, second = Client(root, port).open(), Client(root, port).open()
    rejected = first.call(dict(execute=dict(sql="SET unknown_setting = '1'", token=list(os.urandom(16)))), error='UnsupportedGatewayStatement')['err']
    assert rejected['retry'] == 'never', rejected
    assert first.session != second.session and first.account == second.account
    token = list(os.urandom(16))
    created = first.execute('CREATE TABLE native_sessions (id INT64 PRIMARY KEY, value INT128)', token)['operation']
    first.terminal(created)
    # The actual native route shares grammar, metadata and settings assistance.
    assistance_samples = []
    for text, cursor, expected, profile in (
        ('SELECT va FROM native_sessions', 9, '"value"', 'direct_table_v1'),
        ('SELECT n.va FROM native_sessions AS n', 11, '"value"', 'direct_table_v1'),
        ('.mode table\nSELECT 1; SELECT va FROM native_sessions', 31, '"value"', 'direct_table_v1'),
        ('UPDATE native_sessions SET va', 29, '"value"', 'direct_table_v1'),
        ('SET query.statement_t', 21, 'query.statement_timeout', 'configuration_v1'),
        ('SHOW STO', len('SHOW STO'), 'STORAGE', 'configuration_v1'),
        ('SHOW STORAGE FOR native_s', len('SHOW STORAGE FOR native_s'), '"native_sessions"', 'direct_table_v1'),
    ):
        result = first.call(dict(assist=dict(text=text, cursor=cursor)))['assistance']
        assistance_samples.append(dict(profile=profile, milliseconds=first.sample['milliseconds']))
        assert result['profile'] == profile and result['status'] == 'ready', (text, result)
        assert expected in [item['text'] for item in result['items']], (text, result)
        assert result['coverage'] in ('complete', 'limited') and len(result['items']) <= 8
    result = first.call(dict(assist=dict(text="SELECT 'private", cursor=15)))['assistance']
    assert result['status'] == 'inside_text' and not result['items'], result
    for text, cursor, start, end, expected in (
        ('CREATE', 6, 6, 6, 'TABLE'),
        ('create', 6, 6, 6, 'TABLE'),
        ('CREATE ', 7, 7, 7, 'TABLE'),
        ('CREATE;', 6, 6, 6, 'TABLE'),
        ('SELECT 1; CREATE', 16, 16, 16, 'TABLE'),
        ('CRE', 3, 0, 3, 'CREATE'),
        ('CREATE', 3, 0, 6, 'CREATE'),
        ('ALTER', 5, 5, 5, 'TABLE'),
        ('DROP', 4, 4, 4, 'TABLE'),
        ('DELETE', 6, 6, 6, 'FROM'),
        ('INSERT', 6, 6, 6, 'INTO'),
    ):
        result = first.call(dict(assist=dict(text=text, cursor=cursor)))['assistance']
        assert result['status'] == 'ready' and result['coverage'] == 'complete', (text, result)
        assert result['range'] == dict(start=start, end=end, quoted=False), (text, result)
        assert [item['text'] for item in result['items']] == [expected], (text, result)
    print('Native assistance: complete keywords advance grammar, partial/interior words retain their replacement.', flush=True)
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
    print(json.dumps(dict(profile="native_sql_assistance", samples=assistance_samples)), flush=True)
    # Original token returns its original operation without recompiling CREATE.
    assert second.execute('CREATE TABLE native_sessions (id INT64 PRIMARY KEY, value INT128)', token)['operation']['identity'] == created['identity']
    second.call(dict(execute=dict(sql='CREATE TABLE changed (id INT64)', token=token)), error='SqlTokenConflict')
    from interfaces.sql_sessions.storage import prepare_empty, after_insert, buffered_disclosure
    storage_statement = prepare_empty(first)
    insert_token = list(os.urandom(16))
    if faults is not None:
        before_commit_losses = faults.commit_reply_losses
        faults.fail_commit_once = True
    inserted = first.execute('INSERT INTO native_sessions VALUES (1, 170141183460469231731687303715884105727)', insert_token)['operation']
    submitted = inserted
    assert submitted['phase'] == 'terminal', submitted
    inserted = first.terminal(inserted)
    assert inserted['identity'] == submitted['identity'] and inserted['matched'] == inserted['changed'] == 1, inserted
    if faults is not None:
        assert faults.commit_reply_losses == before_commit_losses + 1
        print(json.dumps(dict(profile='native_sql_lost_commit_reply', original_commit_reply_lost=True,
                              original_identity_retained=True, matched=1, changed=1)), flush=True)
    one = first.execute('SELECT * FROM native_sessions')['batch']
    assert one['rows'][0][1] == (b'\x03' + (2**127 - 1).to_bytes(16, 'little', signed=True)).hex(), one
    # Last-batch retries and a replaced HTTP connection retain the exact result.
    first.http.close()
    first.transport()
    assert first.call(dict(fetch=dict(cursor=one['cursor'], batch=one['batch'])))['batch'] == one
    first.call(dict(fetch=dict(cursor=one['cursor'], batch=one['batch'] + 2)), error='InvalidSqlCursor')
    # Invalid cursor sequencing clears the cursor, never reopens its snapshot.
    first.call(dict(fetch=dict(cursor=one['cursor'], batch=one['batch'])), error='SqlResultIncomplete')
    after_insert(first, storage_statement, root, postgres)
    buffered_disclosure(first, authorize, faults)
    # A successful foreground DML response already contains the owner's exact
    # terminal counts. No status polling is needed to finish these statements.
    def completed(sql, matched, changed):
        token = list(os.urandom(16))
        outcome = first.execute(sql, token)['operation']
        assert outcome['phase'] == 'terminal' and outcome['outcome'] == 'applied', outcome
        assert (outcome['matched'], outcome['changed']) == (matched, changed), outcome
        return token, outcome
    completed('INSERT INTO native_sessions VALUES (2, 20)', 1, 1)
    completed('UPDATE native_sessions SET value = 21 WHERE id = 2', 1, 1)
    completed('UPDATE native_sessions SET value = 21 WHERE id = 2', 1, 0)
    deleted_token, deleted = completed('DELETE FROM native_sessions WHERE id = 2', 1, 1)
    completed('DELETE FROM native_sessions WHERE id = 2', 0, 0)
    completed('INSERT INTO native_sessions VALUES (2, 22)', 1, 1)
    original = second.execute('DELETE FROM native_sessions WHERE id = 2', deleted_token)['operation']
    assert original == deleted, (original, deleted)
    retained = first.execute('SELECT value FROM native_sessions WHERE id = 2')['batch']
    assert retained['complete'] and retained['rows'] == [[(b'\x03' + (22).to_bytes(16, 'little', signed=True)).hex()]], retained
    first.call(dict(close_result=retained['cursor']))
    completed('DELETE FROM native_sessions WHERE id = 2', 1, 1)
    print('Foreground DML: immediate terminal INSERT/UPDATE/DELETE counts, no-op/empty outcomes and original DELETE retry after reinsertion passed.', flush=True)
    if faults is not None:
        faults.check_pin_race(first, second)
    desc = first.execute('DESCRIBE native_sessions')['batch']
    assert desc['rows'] and len(desc['rows'][0]) == 9
    assert desc['observation']['metadata']['kind'] == 'catalog'
    assert len(desc['observation']['metadata']['definitions']) == 1
    assert desc['complete'] and desc['completion']['rows'] == 2
    first.call(dict(close_result=desc['cursor']))
    from interfaces.sql_sessions.storage import text
    if authorize_reads is not None:
        authorize_reads(False)
    try:
        with faults.metadata_only() if faults is not None else nullcontext() as actions:
            for sql in ('EXPLAIN SELECT id FROM native_sessions',
                        'EXPLAIN SELECT a.id FROM native_sessions AS a JOIN native_sessions AS b ON a.id = b.id'):
                explain = first.execute(sql)['batch']
                assert explain['observation']['metadata']['kind'] == 'plan'
                assert explain['complete'] and explain['completion']['rows'] == 1
                plan = json.loads(text(explain['rows'][0][0]))
                assert plan['executed'] is False and plan['basis'] is None
                traits = plan['traits']
                assert traits['target']['effects']['read'] is True
                assert not any(traits['explain_effects'].values())
                assert traits['explain_change_mode'] == 'explanation_zero_work'
                assert not any(traits['explain_work_bound'].values())
                assert first.call(dict(fetch=dict(cursor=explain['cursor'], batch=explain['batch'])))['batch'] == explain
                first.call(dict(close_result=explain['cursor']))
            if actions is not None:
                assert actions.get('lookup', 0) > 0 and actions.get('check', 0) > 0, actions
                assert set(actions) <= {'lookup', 'check', 'check_set', 'client_progress'}, actions
        print('EXPLAIN: single/join typed traits, repeated disclosure and zero pin/data actions passed.', flush=True)
        if authorize_reads is not None:
            first.call(dict(execute=dict(sql='SELECT id FROM native_sessions')), error='AccessDenied')
    finally:
        if authorize_reads is not None:
            authorize_reads(True)
    with ThreadPoolExecutor(max_workers=2) as pool:
        replies = list(pool.map(lambda c: c.concurrent_read(), (first, second)))
    for client, reply in zip((first, second), replies):
        client.call(dict(close_result=reply['batch']['cursor']))
    # The same table is visible through the ordinary PostgreSQL adapter.
    import psycopg
    with psycopg.connect(**postgres) as wire:
        assert wire.execute('SELECT id FROM native_sessions').fetchall() == [(1,)]
    from interfaces.sql_sessions.boundaries import run as boundaries
    boundaries(first, second, created['identity'])
    if faults is not None:
        faults.check(first)
    from interfaces.sql_sessions.security import sessions as session_security
    session_security(Client, first, second, created['identity'])
    from interfaces.sql_sessions.measurements import reads
    reads(first, second, faults, service_pid)
    reload_token = list(os.urandom(16))
    reload = first.terminal(first.execute('SELECT transit_reload_conf()', reload_token)['operation'])
    assert reload['identity']['kind'] == 'configuration' and reload['owner_operation'] is not None
    assert reload['configuration_phase'] in ('applied', 'pending_restart')
    duplicate = second.execute('SELECT transit_reload_conf()', reload_token)['operation']
    assert duplicate['identity'] == reload['identity'] and duplicate['owner_operation'] == reload['owner_operation']
    second.call(dict(cancel=dict(operation=reload['identity'])), error='ConfigurationCancellationUnsupported')
    captured = []
    for name, count in ((('kv', 41), ('document', 12), ('table', 41)) if sources is None else sources):
        print(json.dumps(dict(profile='native_sql_source', source=name, phase='interactive')), flush=True)
        select_source(name)
        selected = Client(root, port).open(name)
        metadata_fault = None
        if faults is not None and name == 'kv' and sources is None:
            # Fail another binding's first authority read inside context, not
            # the selected KV source's ordinary session authorization.
            bindings = json.loads((root / 'sql-gateway.json').read_text())['accounts'][0]['sources']
            faults.fail_source_once = next(binding['connection']['principal'] for binding in bindings if binding['name'] == 'document')
            metadata_fault = faults.failures
        context = selected.call('context')['context']
        if metadata_fault is not None:
            assert faults.fail_source_once is None and faults.failures == metadata_fault + 1
            print(json.dumps(dict(profile='native_sql_source_metadata_recovery', refused_observations=1)), flush=True)
        assert {source['name'] for source in context['sources']} == ({'kv', 'document', 'table'} if sources is None else {name for name, _ in sources})
        # This fixture deliberately leaves other captured owners paused. Native
        # capacity may refuse a new read; a fresh SELECT is explicit and safe
        # only before any rows have been disclosed. Never retry a mutation or
        # splice this attempt into an earlier cursor.
        deadline = time.monotonic() + 60
        refusals = 0
        while True:
            reply = selected.call(dict(execute=dict(sql='SELECT count(*) FROM items')), unavailable=True)
            if reply is not None:
                batch = reply['batch']
                break
            refusals += 1
            assert time.monotonic() < deadline, (name, refusals)
            time.sleep(.25)
        if refusals:
            print(json.dumps(dict(profile='native_sql_source_capacity', source=name, refused_reads=refusals)), flush=True)
        assert batch['rows'] == [[(b'\x03' + count.to_bytes(8, 'little')).hex()]], batch
        assert batch['observation']['data']['source']['kind'] == name
        selected.call(dict(close_result=batch['cursor']))
        if name == 'table':
            configured = next(source for source in json.loads((root/'sql-gateway.json').read_text())['accounts'][0]['sources'] if source['name'] == name)
            assert configured['connection']['resource'] != configured['workspace']['source']['resource']
            orphan = Client(root, port).open(name)
            held = orphan.concurrent_read('SELECT value FROM items')['batch']
            assert held['rows'] and not held['complete'] and held['observation']['data']['source']['kind'] == 'table'
            assert not source_pin()['released']
            # Closing transport does not close an explicit native session.
            # Physical gateway replacement must settle this exact original pin.
            orphan.http.close()
        # Capture admission belongs to the SQL account, not a running source
        # worker. Keep owners paused until after service replacement, so this
        # schedule proves durable admission before any query can complete.
        select_source(None)
        token = list(os.urandom(16))
        operation = selected.execute('SELECT value FROM items', token, captured=True)['operation']
        assert operation['identity']['kind'] == 'captured' and operation['phase'] != 'reserved'
        selected.call(dict(execute=dict(sql='SELECT count(*) FROM items', token=token, captured=True)), error='SqlTokenConflict')
        captured.append((name, count, token, operation['identity']))
        selected.close()
    first.close()
    second.close()
    restart(wire=False)
    if (root/'orphaned-source-pin.json').exists():
        deadline = time.monotonic() + 30
        while not source_pin()['released']:
            assert time.monotonic() < deadline, 'Replacement did not close the source caller pin'
            time.sleep(.05)
        print(json.dumps(dict(profile='native_sql_source_pin_recovery', original_pin_released=True,
                              independent_data_and_progress=True)), flush=True)
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
        if faults is not None and name == 'kv':
            configured = next(source for source in json.loads((root / 'sql-gateway.json').read_text())['accounts'][0]['sources'] if source['name'] == name)
            result_fault = faults.failures
            faults.fail_result_once = (configured['connection']['principal'], configured['connection']['resource'])
        result = selected.call(dict(result=identity))['batch']
        if faults is not None and name == 'kv':
            assert faults.fail_result_once is None and faults.failures == result_fault + 1, (faults.fail_result_once, faults.failures, result_fault)
            print(json.dumps(dict(profile='native_sql_retained_page_recovery', refused_observations=1, operation=identity)), flush=True)
        batches = [dict(selected.sample, rows=len(result['rows']))]
        rows = []
        while True:
            assert selected.call(dict(fetch=dict(cursor=result['cursor'], batch=result['batch'])))['batch'] == result
            assert result['observation']['data']['source']['kind'] == name
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
    for sql in ('SELECT id FROM native_sessions',
                'SELECT id FROM native_sessions WHERE id = -1',
                'DESCRIBE native_sessions', 'SHOW TABLES',
                'EXPLAIN SELECT id FROM native_sessions'):
        protected = first.execute(sql)['batch']
        with faults.readiness_outage(first) if faults is not None else nullcontext():
            authorize(False)
            try:
                denied = first.call(dict(fetch=dict(cursor=protected['cursor'], batch=protected['batch'])), error='AccessDenied')['err']
                assert denied['sqlstate'] == list(b'42501')
            finally:
                authorize(True)
        first.call(dict(fetch=dict(cursor=protected['cursor'], batch=protected['batch'])), error='SqlResultIncomplete')
    print(json.dumps(dict(profile='native_sql_buffered_disclosure', data=True, empty_terminal=True,
                          describe=True, catalog=True, storage=True, explain=True,
                          account_unready=faults is not None, denied_repeats_disclose_no_rows=True)), flush=True)
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
    from interfaces.sql_sessions.security import console as console_security
    console_security(console, consumer, config, password, port, client_environment)
    # Exercise the real terminal deadline and acceptance refresh over this TLS
    # session, not just a direct protocol call with a longer request budget.
    from interfaces.cli.console_terminal import Terminal, ANSI
    terminal = Terminal(console, config, home=home, cwd=consumer, env={'PATH': '/unavailable'})
    try:
        for before, after in (('CREATE', 'CREATE TABLE'), ('CREATE ', 'CREATE TABLE'), ('CRE', 'CREATE')):
            terminal.send(before + '\t')
            terminal.expect('transit> ' + after, timeout=10)
            assert b'\n> ' not in ANSI.sub(b'', terminal.screen), terminal.screen
            terminal.send('\x1a')
            terminal.expect('transit> ' + before)
            terminal.send('\x03')
            terminal.expect('transit> ')
        terminal.send('SELECT va FROM native_sessions\x01' + '\x1b[C' * 9 + '\t')
        terminal.expect('transit> SELECT "value" FROM native_sessions', timeout=10)
        terminal.send('\x03')
        terminal.expect('transit> ')
        terminal.send('SET query.statement_t\t')
        terminal.expect('transit> SET query.statement_timeout', timeout=10)
    finally:
        terminal.close()
    print('Native console completion: CREATE advances to TABLE without a menu flash; partial words, undo, catalog and settings passed over TLS.', flush=True)
    def console_read(_):
        deadline = time.monotonic() + 30
        while True:
            result = subprocess.run([console, 'console', '--config', str(config), '-c', 'SELECT id FROM native_sessions'], cwd=consumer, env=client_environment, capture_output=True, text=True, timeout=60)
            if result.returncode == 0:
                assert '"complete_coverage":true' in result.stdout, result.stdout
                return result.stdout
            # A refusal before result disclosure can surface at session
            # admission or as the typed query transport diagnostic. Repeat
            # only this fresh read, never splice a disclosed row prefix.
            unavailable = 'AuthorityUnavailable (53000)' in result.stderr or (
                'Code: query.transport_unavailable.' in result.stderr and
                'Cause: AuthorityUnavailable.' in result.stderr and
                'Rows already emitted: 0' in result.stderr)
            assert not result.stdout and unavailable and time.monotonic() < deadline, (result.stdout, result.stderr)
            time.sleep(.02)
    with ThreadPoolExecutor(max_workers=2) as pool:
        list(pool.map(console_read, range(2)))
    if faults is not None:
        restart(wire=False, session_lease_ms=1000)
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

"""Finite application binding: authenticated webhook, Table intent, real HTTP effect.

The fixture is the application adapter, not another Transit ingress or sink
authority. SQL owns input deduplication and atomic Dataflow output publication;
the existing finite Station caller/connector own effect identity and outcomes.
"""
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
import hashlib
import hmac
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path
import secrets
import subprocess
import threading
import time

from interfaces.installation.server_application_faults import ExistingKey, native, post
from interfaces.sql_sessions.local import Client
from performance.load.installed import read


@contextmanager
def listener(handler):
    server = HTTPServer(('127.0.0.1', 0), handler)
    thread = threading.Thread(target=server.serve_forever)
    thread.start()
    try:
        yield server.server_port
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
        assert not thread.is_alive()


def token(domain, identity):
    return list(hashlib.sha256(domain + str(identity).encode()).digest()[:16])


class Exchange:
    """Operator provisioning for one existing finite connector exchange."""
    def __init__(self, fixture, binaries, event, body, port):
        self.fixture, self.binaries = fixture, binaries
        self.realm = fixture.config['realm']
        self.port = fixture.config['ports']['node']
        self.root = fixture.root / f'exchange-{event}'
        self.root.mkdir(mode=0o700)
        self.operator = ExistingKey(self.root, fixture.installation / 'root.seed')
        self.roles = {}
        for index, role in enumerate(('caller', 'connector')):
            home = self.root / role
            home.mkdir(mode=0o700)
            seed = home / 'seed.key'
            seed.write_text(secrets.token_hex(32))
            seed.chmod(0o600)
            key = ExistingKey(home, seed)
            principal = 1024 + event * 2 + index
            pid = self.command(dict(spawn={}))
            resource = self.command(dict(create_resource=dict(writer=pid, owned=role == 'caller')))
            self.command(dict(grant=dict(subject=principal, public_key=key.public,
                permissions=4 | 8 | 16 | 64 | (32 if role == 'connector' else 0), pid=pid)))
            for subject in (0, principal):
                self.command(dict(grant_resource=dict(resource=resource, subject=subject, permissions=7)))
            self.command(dict(associate=dict(pid=pid, name=b'state'.hex(), resource=resource)))
            self.roles[role] = dict(pid=pid, resource=resource, principal=principal, seed=seed)
        for role, other, name in (('caller', 'connector', 'capture'), ('connector', 'caller', 'request')):
            current, peer = self.roles[role], self.roles[other]
            self.command(dict(associate=dict(pid=current['pid'], name=name.encode().hex(), resource=peer['resource'], required=False)))
            self.command(dict(grant_resource=dict(resource=peer['resource'], subject=current['principal'], permissions=3)))
        deadline = int(time.time() * 1000) + 240000
        caller, connector = self.roles['caller'], self.roles['connector']
        body_path = self.root / 'caller/body'
        body_path.write_bytes(body)
        headers = [{'name': 'Idempotency-Key', 'value': [{'literal': f'scenario-event-{event}'}]}]
        common = dict(url=f'http://127.0.0.1:{self.port}', realm=self.realm,
                      endpoint_revision=1, reconcile_before_ms=deadline)
        self.configs = dict(
            caller=dict(common, principal=caller['principal'], pid=caller['pid'], worker=connector['pid'],
                seed_file=str(caller['seed']), body_file=str(body_path),
                request=dict(method='POST', target=[dict(literal='/effect')], body_bytes=len(body), headers=headers)),
            connector=dict(common, principal=connector['principal'], pid=connector['pid'],
                seed_file=str(connector['seed']), activation_directory=str(self.root/'connector'), exchange=1,
                endpoint=dict(host='localhost', address='127.0.0.1', port=port, tls=False, timeout_ms=30000),
                admission=dict(caller=caller['pid'], resource=caller['resource'],
                    scope=dict(method='POST', target='/effect', headers=['idempotency-key']))))

    def query(self, kind):
        return post(self.port, '/v1/query', native(self.operator, self.realm, 0, kind))

    def command(self, command):
        sequence = self.query(dict(capabilities={}))['principal_sequence'] + 1
        saved = native(self.operator, self.realm, 0, command, sequence)
        path = self.root / f'operator-command-{sequence}.json'
        path.write_text(json.dumps(saved))
        path.chmod(0o600)
        # Retry only these exact signed bytes. Never allocate a new sequence
        # after an uncertain reply to this administrative command.
        return post(self.port, '/v1/command', saved, retry_unavailable=True)['position']

    def activate(self, role, mode):
        entry = self.roles[role]
        process = self.query(dict(process=entry['pid']))['body']['process']['process']
        self.command(dict(own=dict(pid=entry['pid'], expected_generation=process['generation'], worker=entry['principal'])))
        configured = self.configs[role] | dict(generation=process['generation'] + 1, mode=mode)
        path = self.root / role / 'config.json'
        path.write_text(json.dumps(configured))
        path.chmod(0o600)
        result = subprocess.run([self.binaries['http_caller' if role == 'caller' else 'http_worker'], str(path)],
                                capture_output=True, text=True, timeout=120)
        assert result.returncode == 0, (role, mode, result.stderr[-2000:])
        return json.loads(result.stdout)

    def deliver(self):
        after = None
        while True:
            position = self.query(dict(capabilities={}))['position']
            page = self.query(dict(outputs=dict(after=after, position=position)))['body']['outputs']
            for entry in page['entries']:
                if entry and entry['phase'] == 'pending' and entry['source'] in {r['pid'] for r in self.roles.values()}:
                    self.command(dict(deliver=entry['id']))
            after = page['next']
            if after is None:
                return


def run(journey, binaries):
    fixture = journey.fixture
    for sql in (
        'CREATE TABLE webhook_events (id BIGINT PRIMARY KEY, value BIGINT)',
        'CREATE TABLE webhook_intents (id BIGINT PRIMARY KEY, value BIGINT)',
        'CREATE TABLE webhook_outcomes (id BIGINT PRIMARY KEY, value BIGINT, phase UTF8, effect BIGINT, attempt BIGINT)',
    ):
        journey.command('setup', sql, (0, 0))
    for sql in (
        'CREATE DATAFLOW webhook_projection INTO webhook_intents AS SELECT id, value FROM webhook_events',
        'AUTHORIZE DATAFLOW webhook_projection',
        'ACTIVATE DATAFLOW webhook_projection',
    ):
        journey.command('setup', sql)
    revision = journey.settle('webhook_projection', 1, 'webhook_intents', [], 'webhook_initial')
    secret = secrets.token_bytes(32)
    ingress = Client(fixture.console_config(), fixture.record()['definition']).open()
    errors = []

    class Webhook(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def reply(self, status, value):
            payload = json.dumps(value).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def do_POST(self):
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if self.path != '/webhook' or not 0 < length <= 1024:
                    return self.reply(400, dict(error='invalid_request'))
                body = self.rfile.read(length)
                signature = hmac.digest(secret, body, 'sha256').hex()
                if not hmac.compare_digest(signature, self.headers.get('X-Signature', '')):
                    return self.reply(403, dict(error='denied'))
                value = json.loads(body)
                if (set(value) != {'id', 'value'} or any(type(v) is not int for v in value.values())
                        or not 0 < value['id'] < 1000 or not -1000000 < value['value'] < 1000000):
                    return self.reply(400, dict(error='invalid_payload'))
                sql = f"INSERT INTO webhook_events VALUES ({value['id']}, {value['value']})"
                original_token = token(b'scenario.webhook.input\0', value['id'])
                saved = fixture.root / f"webhook-{value['id']}-{hashlib.sha256(body).hexdigest()}.json"
                saved.write_text(json.dumps(dict(sql=sql, token=original_token)))
                saved.chmod(0o600)
                try:
                    operation = ingress.execute(sql, original_token)['operation']
                    operation = ingress.terminal(operation)
                except AssertionError as error:
                    detail = error.args[0] if error.args else None
                    if isinstance(detail, dict) and detail.get('err', {}).get('code') == 'SqlTokenConflict':
                        return self.reply(409, dict(error='event_conflict'))
                    raise
                self.reply(202, dict(operation=operation['identity']))
            except Exception as error:
                errors.append(error)
                self.reply(503, dict(error='unresolved'))

    expected = []
    completed = []
    exchanges = []
    admitted = {}
    received_at = {}
    try:
        with listener(Webhook) as inbound:
            def submit(event, value, signature=True):
                body = json.dumps(dict(id=event, value=value)).encode()
                peer = HTTPConnection('127.0.0.1', inbound, timeout=100)
                try:
                    peer.request('POST', '/webhook', body, headers={
                        'Content-Type': 'application/json',
                        'X-Signature': hmac.digest(secret, body, 'sha256').hex() if signature else 'invalid'})
                    response = peer.getresponse()
                    return response.status, json.loads(response.read())
                finally:
                    peer.close()

            assert submit(7, 70, False)[0] == 403
            journey.rows('webhook_denied', 'SELECT * FROM webhook_events;', [])
            for event, lost_response in ((7, False), (8, True)):
                if event not in admitted:
                    with journey.sample('webhook_accept') as sample:
                        received_at[event] = time.perf_counter_ns()
                        admitted[event] = submit(event, event * 10)
                        assert admitted[event][0] == 202 and not errors, errors
                        sample.update(verified=True, event=event)
                status, receipt = admitted[event]
                with journey.sample('webhook_duplicate') as sample:
                    assert submit(event, event * 10) == (status, receipt)
                    assert submit(event, event * 10 + 1)[0] == 409
                    sample.update(verified=True, event=event)
                expected.append((event, event * 10))
                revision = journey.settle('webhook_projection', revision + 1, 'webhook_intents', expected, 'webhook_derived', [])
                # Read the committed intent through the public SQL result owner.
                intent = read(journey.observer, f'SELECT id, value FROM webhook_intents WHERE id = {event}', 1)
                assert len(intent) == 1
                values = [int.from_bytes(bytes.fromhex(cell)[1:], 'little', signed=True) for cell in intent[0]]
                assert values == [event, event * 10]
                body = json.dumps(dict(id=values[0], value=values[1]), separators=(',', ':')).encode()
                accepted, release = threading.Event(), threading.Event()
                received, peer_errors = [], []
                response_body = b'{"accepted":true}'

                class Destination(BaseHTTPRequestHandler):
                    def log_message(self, *_):
                        pass

                    def do_POST(self):
                        try:
                            actual = self.rfile.read(int(self.headers['Content-Length']))
                            assert self.path == '/effect' and actual == body
                            assert self.headers['Idempotency-Key'] == f'scenario-event-{event}'
                            received.append(actual)
                            accepted.set()
                            assert release.wait(20), 'foreground console did not finish while HTTP was blocked'
                            if lost_response:
                                self.close_connection = True
                                return
                            self.send_response(200)
                            self.send_header('Content-Length', str(len(response_body)))
                            self.end_headers()
                            self.wfile.write(response_body)
                        except Exception as error:
                            peer_errors.append(error)
                            accepted.set()

                with listener(Destination) as destination:
                    exchange = Exchange(fixture, binaries, event, body, destination)
                    with journey.sample('effect_prepare') as sample:
                        original = exchange.activate('caller', 'publish')
                        assert original['phase'] == 'called'
                        assert exchange.activate('caller', 'publish') == original
                        exchange.deliver()
                        assert exchange.activate('connector', 'accept')['phase'] == 'ready'
                        sample['verified'] = True
                    with journey.sample('effect_unknown' if lost_response else 'effect_observed') as sample:
                        with ThreadPoolExecutor(max_workers=1) as workers:
                            dispatched = workers.submit(exchange.activate, 'connector', 'execute')
                            try:
                                assert accepted.wait(30), 'connector did not reach the destination'
                                assert not peer_errors, peer_errors
                                if not lost_response:
                                    # The application has one active dispatch
                                    # slot. Another accepted input remains in
                                    # the database while the destination stalls.
                                    with journey.sample('webhook_accept') as incoming:
                                        received_at[8] = time.perf_counter_ns()
                                        admitted[8] = submit(8, 80)
                                        assert admitted[8][0] == 202 and not errors, errors
                                        incoming.update(verified=True, event=8)
                                journey.rows('console_during_http', 'SELECT * FROM items;', [])
                            finally:
                                release.set()
                            dispatched.result(timeout=120)
                        exchange.deliver()
                        outcome = exchange.activate('caller', 'receive')
                        assert outcome['phase'] == ('closed_unknown' if lost_response else 'observed'), outcome
                        if not lost_response:
                            assert outcome['status'] == 200
                        assert len(received) == 1 and not peer_errors, peer_errors
                        sample.update(verified=True, event=event, outcome_phase=outcome['phase'], sends=len(received))
                    # This projection is application state; the connector's
                    # durable outcome remains authoritative across this write.
                    phase = outcome['phase']
                    status = 0 if lost_response else outcome['status']
                    sql = (f"INSERT INTO webhook_outcomes VALUES ({event}, {status}, '{phase}', "
                           f"{outcome['effect']}, {outcome['attempt']})")
                    outcome_token = token(b'scenario.webhook.outcome\0', event)
                    operation = journey.observer.terminal(journey.observer.execute(sql, outcome_token)['operation'])
                    completed.append((event, status))
                    journey.rows('recorded_outcomes', 'SELECT id, value FROM webhook_outcomes;', completed)
                    journey.elapsed('webhook_to_unknown_outcome' if lost_response else 'webhook_to_observed_outcome',
                                    received_at[event], event=event)
                    # Publication recovery and SQL outcome retry reuse their
                    # original identities; neither dispatches a second request.
                    assert exchange.activate('caller', 'publish') == original
                    duplicate = journey.observer.terminal(journey.observer.execute(sql, outcome_token)['operation'])
                    assert duplicate['identity'] == operation['identity']
                    if not lost_response:
                        replay = exchange.activate('caller', 'replay')
                        assert replay['sha256'] == hashlib.sha256(response_body).hexdigest()
                    assert len(received) == 1
                    exchanges.append((exchange, outcome, lost_response, response_body, original))
        assert not errors, errors
    finally:
        ingress.close()
    journey.command('setup', 'REFRESH DATAFLOW webhook_projection;')
    journey.settle('webhook_projection', revision + 1, 'webhook_intents', expected, 'webhook_refreshed')
    for exchange, _, _, _, original in exchanges:
        assert exchange.activate('caller', 'publish') == original
    journey.command('setup', 'RETIRE DATAFLOW webhook_projection;')
    def retained(restarted):
        # Both listeners are closed. Replay after actual node replacement must
        # use retained capture/outcome evidence, never a new network attempt.
        for exchange, original, unknown, payload, _ in exchanges:
            with restarted.sample('effect_replay_after_restart') as sample:
                settled = exchange.activate('connector', 'execute')
                assert settled['outcome'] == original['phase'], settled
                assert exchange.activate('caller', 'receive') == original
                if not unknown:
                    replay = exchange.activate('caller', 'replay')
                    assert replay['body_bytes'] == len(payload)
                    assert replay['sha256'] == hashlib.sha256(payload).hexdigest()
                sample['verified'] = True
        restarted.rows('outcomes_after_restart', 'SELECT id, value FROM webhook_outcomes;', completed)
    return retained

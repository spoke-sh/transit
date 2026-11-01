"""Owned authority hop for deterministic metadata and pin acquisition failures."""
import http.client
import http.server
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
import json
import os
import threading
import time
from urllib.parse import urlsplit


class Faults:
    def __init__(self, url):
        target = urlsplit(url)
        self.fail_transaction_once = False
        self.transaction_reply_losses = 0
        self.fail_commit_once = False
        self.commit_reply_losses = 0
        self.fail_open = False
        self.fail_once = False
        self.fail_snapshot_once = False
        self.before_pin_once = None
        self.lose_pin_conflict_once = False
        self.record_pins = False
        self.explain_actions = None
        self.pin_attempts = []
        self.pin_states = []
        self.fail_coordinator = None
        self.fail_source_once = None
        self.fail_result_once = None
        self.failures = 0
        self.requests = 0
        self.response_bytes = 0
        self.rejections = []
        self.settings_fault = None
        self.settings_records = []
        self.lock = threading.Lock()
        owner = self
        class Handler(http.server.BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.1'
            disable_nagle_algorithm = True
            wbufsize = 65536
            def do_POST(self):
                content = self.rfile.read(int(self.headers['Content-Length']))
                request = json.loads(content)
                envelope = request.get('query', {})
                query = envelope.get('kind', {})
                table = request.get('action', {}) if self.path == '/table/v1' else {}
                before_pin = None
                explain_failure = False
                with owner.lock:
                    if owner.explain_actions is not None and table:
                        # Count action names only. Any data read or acquisition
                        # fails before forwarding, so a successful EXPLAIN cannot
                        # hide a release-after-pin or eager scan.
                        for name in table:
                            owner.explain_actions[name] = owner.explain_actions.get(name, 0) + 1
                        explain_failure = any(name not in ('lookup', 'check', 'check_set', 'client_progress', 'historical_catalog') for name in table)
                        if 'historical_catalog' in table:
                            historical = table['historical_catalog']
                            for name in historical:
                                key = 'historical_catalog.' + name
                                owner.explain_actions[key] = owner.explain_actions.get(key, 0) + 1
                            explain_failure |= any(name not in ('lookup', 'source', 'namespace', 'list') for name in historical)
                            explain_failure |= historical.get('source', {}).get('rows', False)
                        if 'client_progress' in table:
                            explain_failure |= set(table['client_progress']) != {'inspect'}
                        for check in table.get('check_set', []):
                            if 'historical' in check:
                                explain_failure |= check['historical'].get('rows', False)

                    if 'pin' in table:
                        before_pin, owner.before_pin_once = owner.before_pin_once, None
                        if owner.record_pins:
                            owner.pin_attempts.append(dict(owner=table['pin']['owner'], expected=table['pin']['expected']))
                            del owner.pin_attempts[:-8]
                if before_pin is not None:
                    before_pin()
                configuration = request.get('configuration', {}) if self.path == '/configuration/v1' else {}
                action = configuration.get('action', {})
                stage = ('authorize' if self.path == '/v1/query' else
                         'continuation' if action.get('settings', {}).get('cursor') is not None else
                         'page' if 'settings' in action else 'reload' if 'reload' in action else None)
                settings_failure = None
                with owner.lock:
                    if owner.settings_fault is not None and stage == owner.settings_fault['stage']:
                        fault = owner.settings_fault
                        failed = fault['remaining'] > 0
                        if failed:
                            fault['remaining'] -= 1
                            settings_failure = fault.copy()
                        # Retain only metadata action/cursor and public reload
                        # identity, never signed authorization or credentials.
                        owner.settings_records.append(dict(action=action, operation=configuration.get('operation') if stage == 'reload' else None, failed=failed))
                        del owner.settings_records[:-64]
                source_failure = owner.fail_source_once is not None and envelope.get('principal') == owner.fail_source_once
                # Retained Query publications use authorized read_entries
                # batches. 00 50 + big-endian domain 3 is Publication's
                # query_result key prefix, distinct from policy/status reads.
                publication = query.get('read_entries', {})
                result_failure = owner.fail_result_once == (envelope.get('principal'), publication.get('resource')) and any(isinstance(key, str) and key.startswith('005000000003') for key in publication.get('keys', []))
                # Metadata is a pure observation and may be retried before any
                # acquisition. An uncertain pin must preserve its original
                # journal identity; only proven absence permits new preparation.
                metadata_failure = owner.fail_once and 'lookup' in table
                acquisition_failure = owner.fail_open and 'pin' in table
                snapshot_failure = owner.fail_snapshot_once and 'snapshot' in table
                if explain_failure or (settings_failure is not None and not settings_failure['after']) or source_failure or result_failure or metadata_failure or acquisition_failure or snapshot_failure or (owner.fail_coordinator is not None and request.get('connection', {}).get('principal') == owner.fail_coordinator and 'inspect' in table.get('client_progress', {})):
                    if source_failure:
                        owner.fail_source_once = None
                    if result_failure:
                        owner.fail_result_once = None
                    if snapshot_failure:
                        owner.fail_snapshot_once = False
                    owner.fail_once = False
                    owner.failures += 1
                    status, body = 503, b'{"err":"HttpCapacity"}'
                    content_type = 'application/json'
                else:
                    upstream = http.client.HTTPConnection(target.hostname, target.port, timeout=40)
                    try:
                        headers = {key: value for key, value in self.headers.items()
                                   if key.lower() not in ('host', 'connection')}
                        upstream.request('POST', self.path, content, headers)
                        response = upstream.getresponse()
                        status, body = response.status, response.read()
                        content_type = response.getheader('Content-Type', 'application/json')
                    finally:
                        upstream.close()
                # Lose a successful data-owner reply after it has reached the
                # proxy. The service must recover this original frozen request.
                with owner.lock:
                    if owner.record_pins and 'pin_status' in table and status == 200:
                        state = json.loads(body)['result']['pin_state']
                        owner.pin_states.append(dict(owner=table['pin_status']['owner'], position=state['position'], retained=state['handle'] is not None))
                        del owner.pin_states[:-8]
                    lose_pin = owner.lose_pin_conflict_once and 'pin' in table and status == 200
                    if lose_pin:
                        owner.lose_pin_conflict_once = False
                    lose_commit = owner.fail_commit_once and 'commit_saved' in table and status == 200
                    if lose_commit:
                        owner.fail_commit_once = False
                        owner.commit_reply_losses += 1
                    lose_transaction = False
                    if owner.fail_transaction_once and 'call' in table.get('transaction', {}) and status == 200:
                        result = json.loads(body).get('result', {}).get('transaction', {}).get('call')
                        if result is not None and 'settled' in result and 'decided' in result['settled']['observation']:
                            owner.fail_transaction_once = False
                            owner.transaction_reply_losses += 1
                            lose_transaction = True
                if lose_commit or lose_transaction:
                    status, body = 503, b'{"err":"HttpCapacity"}'
                    content_type = 'application/json'
                if lose_pin:
                    status, body = 409, b'{"err":"Conflict"}'
                    content_type = 'application/json'
                if settings_failure is not None:
                    code = settings_failure['code']
                    status = {'HttpCapacity': 503, 'AccessDenied': 403, 'ConfigurationSnapshotChanged': 409}[code]
                    body = json.dumps(dict(err=code)).encode()
                    content_type = 'application/json'
                self.send_response(status)
                self.send_header('Content-Type', content_type)
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                with owner.lock:
                    owner.requests += 1
                    owner.response_bytes += len(body)
                    if status >= 400:
                        # Only protocol action names and status, never SQL,
                        # credentials or protected response bodies.
                        owner.rejections.append(dict(route=self.path, action=list(table or query), status=status))
                        del owner.rejections[:-32]
            def handle(self):
                # Transport replacement and service shutdown can reset an idle
                # keepalive connection. Failed POSTs still reach the client.
                try:
                    super().handle()
                except (ConnectionResetError, BrokenPipeError):
                    pass
            def log_message(self, *_):
                pass
        self.server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.url = f'http://127.0.0.1:{self.server.server_port}'
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    @contextmanager
    def metadata_only(self):
        with self.lock:
            assert self.explain_actions is None
            actions = self.explain_actions = {}
        try:
            yield actions
        finally:
            with self.lock:
                self.explain_actions = None

    def arm_settings(self, stage, code='HttpCapacity', *, count=1, after=False):
        with self.lock:
            self.settings_fault = dict(stage=stage, code=code, remaining=count, after=after)
            self.settings_records = []

    def disarm_settings(self):
        with self.lock:
            records = self.settings_records.copy()
            self.settings_fault = None
            return records

    def wait_unready(self, client):
        configuration = json.loads((client.root / 'sql-gateway.json').read_text())
        deadline = time.monotonic() + 15
        while True:
            health = http.client.HTTPConnection('127.0.0.1', configuration['health_port'], timeout=3)
            try:
                health.request('GET', '/recovery')
                response = health.getresponse()
                response.read()
                if response.status == 503:
                    return
                assert response.status == 200, response.status
            finally:
                health.close()
            assert time.monotonic() < deadline, 'database account did not withdraw readiness'
            time.sleep(.05)

    @contextmanager
    def readiness_outage(self, client):
        # A settled account has no polling activation check. Trigger a real
        # foreground fence failure before changing disclosure rights, then keep
        # recovery unavailable while the buffered-result assertion runs.
        configuration = json.loads((client.root / 'sql-gateway.json').read_text())
        self.fail_coordinator = configuration['accounts'][0]['execution']['table_principal']
        probe = type(client)(client.root, client.port)
        with ThreadPoolExecutor(max_workers=1) as pool:
            opening = pool.submit(probe.open)
            try:
                self.wait_unready(client)
                yield
            finally:
                self.fail_coordinator = None
                try:
                    opening.result(timeout=40)
                except AssertionError as failure:
                    # The independent login can observe the temporary grant
                    # revocation too. No other login failure is acceptable.
                    assert (len(failure.args) == 1 and isinstance(failure.args[0], dict)
                            and failure.args[0].get('err', {}).get('code') == 'AccessDenied'), failure
                finally:
                    probe.close()

    def check(self, client):
        before = self.failures
        self.fail_once = True
        result = client.execute('SELECT id FROM native_sessions')['batch']
        assert self.failures == before + 1 and result['rows'], (before, self.failures, result)
        client.call(dict(close_result=result['cursor']))

        # Settled recovery does not poll the authority. A foreground activation
        # check must withdraw readiness and wake recovery; the original login
        # waits inside its unchanged request budget for authority restoration.
        configuration = json.loads((client.root / 'sql-gateway.json').read_text())
        self.fail_coordinator = configuration['accounts'][0]['execution']['table_principal']
        release = None
        pool = ThreadPoolExecutor(max_workers=1)
        try:
            started = time.monotonic()
            opening = pool.submit(lambda: type(client)(client.root, client.port).open())
            self.wait_unready(client)
            release = threading.Timer(3, lambda: setattr(self, 'fail_coordinator', None))
            release.start()
            recovered = opening.result(timeout=40)
            recovered.close()
            elapsed = time.monotonic() - started
            assert elapsed >= 2, elapsed
            print(json.dumps(dict(profile='native_sql_readiness_recovery', unavailable_seconds=3,
                                  login_seconds=round(elapsed, 3), preserved_fence=True)), flush=True)
        finally:
            self.fail_coordinator = None
            if release is not None:
                release.cancel()
                release.join()
            pool.shutdown(wait=True)
        # Change the logical frontier so this open needs a new cache pin.
        # A warm SELECT intentionally performs no acquisition.
        client.terminal(client.execute('INSERT INTO native_sessions VALUES (998, 1)', list(os.urandom(16)))['operation'])
        self.fail_open = True
        try:
            before = self.failures
            client.call(dict(execute=dict(sql='SELECT id FROM native_sessions')), error='AuthorityUnavailable')
            assert self.failures > before
        finally:
            self.fail_open = False
        client.terminal(client.execute('DELETE FROM native_sessions WHERE id = 998', list(os.urandom(16)))['operation'])
        # The retained pin exists before this failed source open. Its successful
        # cleanup must not erase the capacity diagnosis from the read attempt.
        before = self.failures
        self.fail_snapshot_once = True
        failure = client.call(dict(execute=dict(sql='SELECT id FROM native_sessions')), error='AuthorityUnavailable')['err']
        assert self.failures == before + 1 and failure['sqlstate'] == list(b'53000'), failure
        # A failed open must not publish a partially initialized cursor or
        # double-free its preparation. Reuse the same logical session.
        result = client.execute('SELECT id FROM native_sessions')['batch']
        assert result['rows']
        client.call(dict(close_result=result['cursor']))

    def check_pin_race(self, client, writer):
        def write(sql):
            outcome = writer.terminal(writer.execute(sql, list(os.urandom(16)))['operation'])
            assert outcome['matched'] == outcome['changed'] == 1, outcome
        write('INSERT INTO native_sessions VALUES (997, 1)')
        self.record_pins = True
        self.pin_attempts, self.pin_states = [], []
        self.before_pin_once = lambda: write('INSERT INTO native_sessions VALUES (996, 2)')
        try:
            result = client.execute('SELECT id FROM native_sessions')['batch']
            expected = {(b'\x03' + value.to_bytes(8, 'little', signed=True)).hex() for value in (1, 996, 997)}
            assert result['complete'] and {row[0] for row in result['rows']} == expected, result
            assert len(self.pin_attempts) == 2, self.pin_attempts
            first, second = self.pin_attempts
            assert first['owner'] != second['owner']
            assert any(item['owner'] == first['owner'] and not item['retained'] and
                       item['position']['partition'] == first['expected']['partition'] and
                       item['position']['next_lsn'] > first['expected']['next_lsn'] for item in self.pin_states), self.pin_states
            assert client.call(dict(fetch=dict(cursor=result['cursor'], batch=result['batch'])))['batch'] == result
            client.call(dict(close_result=result['cursor']))
            write('DELETE FROM native_sessions WHERE id = 997')
            write('DELETE FROM native_sessions WHERE id = 996')
            self.pin_attempts, self.pin_states = [], []
            self.lose_pin_conflict_once = True
            client.call(dict(execute=dict(sql='SELECT id FROM native_sessions')), error='Conflict')
            assert not self.lose_pin_conflict_once and self.pin_attempts, self.pin_attempts
            # Background cleanup may resolve the original unknown handle before
            # releasing it. Every acquisition must still carry that same owner
            # and exact frontier; an RPC count would reject legitimate cleanup.
            assert all(item == self.pin_attempts[0] for item in self.pin_attempts), self.pin_attempts
            assert any(item['owner'] == self.pin_attempts[0]['owner'] and item['retained'] for item in self.pin_states), self.pin_states
            print('Snapshot preparation: raced unaccepted pin is proven absent before reacquisition; a lost accepted pin reply never switches identity.', flush=True)
        finally:
            self.record_pins = False
            self.before_pin_once = None
            self.lose_pin_conflict_once = False

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def counters(self):
        with self.lock:
            return self.requests, self.response_bytes

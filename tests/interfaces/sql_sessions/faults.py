"""Owned authority hop for deterministic metadata and pin acquisition failures."""
import http.client
import http.server
import json
import os
import threading
import time
from urllib.parse import urlsplit


class Faults:
    def __init__(self, url):
        target = urlsplit(url)
        self.fail_commit_once = False
        self.commit_reply_losses = 0
        self.fail_open = False
        self.fail_once = False
        self.fail_snapshot_once = False
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
                # acquisition. A failed pin must preserve its original journal
                # identity for cleanup, never silently capture another cut.
                metadata_failure = owner.fail_once and 'lookup' in table
                acquisition_failure = owner.fail_open and 'pin' in table
                snapshot_failure = owner.fail_snapshot_once and 'snapshot' in table
                if (settings_failure is not None and not settings_failure['after']) or source_failure or result_failure or metadata_failure or acquisition_failure or snapshot_failure or (owner.fail_coordinator is not None and request.get('connection', {}).get('principal') == owner.fail_coordinator and 'inspect' in table.get('client_progress', {})):
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
                    lose_commit = owner.fail_commit_once and 'commit_saved' in table and status == 200
                    if lose_commit:
                        owner.fail_commit_once = False
                        owner.commit_reply_losses += 1
                if lose_commit:
                    status, body = 503, b'{"err":"HttpCapacity"}'
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

    def check(self, client):
        before = self.failures
        self.fail_once = True
        result = client.execute('SELECT id FROM native_sessions')['batch']
        assert self.failures == before + 1 and result['rows'], (before, self.failures, result)
        client.call(dict(close_result=result['cursor']))

        # A real failed database activation fence withdraws readiness. Login waits for
        # its recovery inside the configured request window, not 64 short polls.
        configuration = json.loads((client.root / 'sql-gateway.json').read_text())
        self.fail_coordinator = configuration['accounts'][0]['execution']['table_principal']
        release = None
        try:
            self.wait_unready(client)
            release = threading.Timer(3, lambda: setattr(self, 'fail_coordinator', None))
            release.start()
            started = time.monotonic()
            recovered = type(client)(client.root, client.port).open()
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

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def counters(self):
        with self.lock:
            return self.requests, self.response_bytes

"""Owned native hop for deterministic failure before snapshot acquisition."""
import http.client
import http.server
import json
import threading
import time
from urllib.parse import urlsplit


class Faults:
    def __init__(self, url):
        target = urlsplit(url)
        self.fail_open = False
        self.fail_once = False
        self.fail_coordinator = None
        self.fail_source_once = None
        self.failures = 0
        self.requests = 0
        self.response_bytes = 0
        self.lock = threading.Lock()
        owner = self
        class Handler(http.server.BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.1'
            disable_nagle_algorithm = True
            wbufsize = 65536
            def do_POST(self):
                content = self.rfile.read(int(self.headers['Content-Length']))
                envelope = json.loads(content).get('query', {})
                query = envelope.get('kind', {})
                source_failure = owner.fail_source_once is not None and envelope.get('principal') == owner.fail_source_once
                if source_failure or ((owner.fail_open or owner.fail_once) and 'open' in query.get('snapshot_read', {}).get('snapshot', {})) or (owner.fail_coordinator is not None and envelope.get('principal') == owner.fail_coordinator and 'process' in query):
                    if source_failure:
                        owner.fail_source_once = None
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
                self.send_response(status)
                self.send_header('Content-Type', content_type)
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                with owner.lock:
                    owner.requests += 1
                    owner.response_bytes += len(body)
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

    def check(self, client):
        before = self.failures
        self.fail_once = True
        result = client.execute('SELECT id FROM native_sessions')['batch']
        assert self.failures == before + 1 and result['rows']
        client.call(dict(close_result=result['cursor']))

        # A real failed coordinator fence withdraws readiness. Login waits for
        # its recovery inside the configured request window, not 64 short polls.
        configuration = json.loads((client.root / 'sql-gateway.json').read_text())
        self.fail_coordinator = configuration['accounts'][0]['ledger']['coordinator']
        release = None
        try:
            deadline = time.monotonic() + 15
            while True:
                health = http.client.HTTPConnection('127.0.0.1', configuration['health_port'], timeout=3)
                try:
                    health.request('GET', '/recovery')
                    response = health.getresponse()
                    response.read()
                    if response.status == 503:
                        break
                finally:
                    health.close()
                assert time.monotonic() < deadline, 'coordinator fault did not withdraw readiness'
                time.sleep(.05)
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
        self.fail_open = True
        try:
            client.call(dict(execute=dict(sql='SELECT id FROM native_sessions')), error='AuthorityUnavailable')
            assert self.failures > 0
        finally:
            self.fail_open = False
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

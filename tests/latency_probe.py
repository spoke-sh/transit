"""Bounded, opt-in HTTP attempt counters for owned performance fixtures.

The proxy changes transport costs. Compare instrumented runs separately from
unproxied timings. No request/response payloads or credentials are retained.
"""
from collections import Counter
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import threading
import time
from urllib.parse import urlsplit


class Probe:
    def __init__(self, target, port=0, native=False, before=None):
        endpoint = urlsplit(target)
        assert endpoint.scheme == 'http' and endpoint.hostname == '127.0.0.1'
        self.counts = Counter()
        self.lock = threading.Lock()
        owner = self

        class Handler(BaseHTTPRequestHandler):
            disable_nagle_algorithm = True
            wbufsize = 65536
            def log_message(self, *_):
                pass

            def forward(self):
                length = int(self.headers.get('Content-Length', 0))
                if length > 2 * 1024 * 1024 or self.headers.get('Transfer-Encoding'):
                    self.send_error(413)
                    return
                body = self.rfile.read(length)
                if before:
                    before(self.path, body)
                labels = [self.command, 'request_bytes']
                if native and self.path in ('/v3/query', '/v3/command'):
                    value = json.loads(body)
                    mutation = self.path.endswith('command')
                    envelope = value['request' if mutation else 'query']
                    operation = next(iter(envelope['command' if mutation else 'kind']))
                    # This fixture uses a fixed finite population of principals
                    # and protocol operations, never arbitrary request labels.
                    classified = ('update:' if mutation else 'read:') + operation
                    labels.append(classified)
                    labels.append('principal:' + str(envelope['principal']))
                    labels.append('principal:' + str(envelope['principal']) + ':' + classified)
                connection = HTTPConnection(endpoint.hostname, endpoint.port, timeout=60)
                started = time.monotonic_ns()
                try:
                    headers = {key: val for key, val in self.headers.items()
                               if key.lower() not in ('host', 'connection', 'content-length')}
                    connection.request(self.command, self.path, body, headers)
                    response = connection.getresponse()
                    data = response.read(4 * 1024 * 1024 + 1)
                    if len(data) > 4 * 1024 * 1024:
                        raise ValueError('fixture response exceeds probe bound')
                    with owner.lock:
                        for label in labels:
                            owner.counts[label] += length if label == 'request_bytes' else 1
                        elapsed = time.monotonic_ns() - started
                        owner.counts['elapsed_ns'] += elapsed
                        if native and self.path in ('/v3/query', '/v3/command'):
                            owner.counts[classified + ':elapsed_ns'] += elapsed
                            owner.counts['principal:' + str(envelope['principal']) + ':' + classified + ':elapsed_ns'] += elapsed
                        owner.counts['response_bytes'] += len(data)
                        owner.counts['status:' + str(response.status)] += 1
                    self.send_response(response.status)
                    for key, val in response.getheaders():
                        if key.lower() not in ('transfer-encoding', 'connection', 'content-length'):
                            self.send_header(key, val)
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                    self.wfile.flush()
                except (BrokenPipeError, ConnectionResetError):
                    with owner.lock:
                        owner.counts['disconnected'] += 1
                finally:
                    connection.close()

            do_GET = do_POST = do_PUT = do_DELETE = do_HEAD = forward

        self.server = ThreadingHTTPServer(('127.0.0.1', port), Handler)
        self.server.daemon_threads = True
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = f'http://127.0.0.1:{self.server.server_port}'

    def snapshot(self):
        with self.lock:
            return self.counts.copy()

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)

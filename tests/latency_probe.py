"""Bounded, opt-in HTTP attempt counters for owned performance fixtures.

The proxy changes transport costs. Compare instrumented runs separately from
unproxied timings. No request/response payloads or credentials are retained.
"""
from collections import Counter, deque
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
        self.events = deque(maxlen=2048)
        self.failed_events = deque(maxlen=64)
        self.completed_failures = 0
        self.started_ns = time.monotonic_ns()
        self.completed_events = 0
        self.lock = threading.Lock()
        owner = self

        class Handler(BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.1'
            disable_nagle_algorithm = True
            wbufsize = 65536
            def setup(self):
                super().setup()
                self.connection.settimeout(1 if native else 60)
                self.upstream = HTTPConnection(endpoint.hostname, endpoint.port, timeout=60)

            def finish(self):
                try:
                    super().finish()
                finally:
                    self.upstream.close()

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
                if native and self.path in ('/v1/query', '/v1/command', '/v1/blocks'):
                    value = json.loads(body)
                    mutation = self.path.endswith('command')
                    envelope = value['request' if mutation else 'query']
                    operation = next(iter(envelope['command' if mutation else 'kind']))
                    # This fixture uses a fixed finite population of principals
                    # and protocol operations, never arbitrary request labels.
                    classified = ('update:' if mutation else 'read:') + operation
                    labels.append(classified)
                    if operation == 'snapshot_read' and envelope['kind'][operation]['finish']:
                        labels.append('snapshot_finish')
                    if operation == 'snapshot_read' and 'open' in envelope['kind'][operation]['snapshot']:
                        labels.append('snapshot_open')
                    labels.append('principal:' + str(envelope['principal']))
                    labels.append('principal:' + str(envelope['principal']) + ':' + classified)
                # Preserve sequential connection reuse through the diagnostic
                # proxy. HTTP/1.0 plus a fresh upstream for every request can
                # hide exactly the socket-lifetime failures being investigated.
                connection = self.upstream
                started = time.monotonic_ns()
                event = {'start_ns': started - owner.started_ns, 'method': self.command,
                         'wait_hint': self.headers.get('X-Transit-Wait') is not None}
                if native and self.path in ('/v1/query', '/v1/command', '/v1/blocks'):
                    event.update(operation=classified, principal=envelope['principal'])
                    if mutation:
                        event['sequence'] = envelope['sequence']
                        command = envelope['command'][operation]
                        if operation == 'turn_with_versions':
                            command = command['turn']
                        if operation in ('send', 'open_view', 'turn', 'turn_with_versions'):
                            event['pid'] = command['pid']
                            if 'input' in command:
                                event['input'] = command['input']
                    elif operation == 'process':
                        event['pid'] = envelope['kind'][operation]
                with owner.lock:
                    owner.counts['attempts'] += 1
                try:
                    headers = {key: val for key, val in self.headers.items()
                               if key.lower() not in ('host', 'connection', 'content-length')}
                    connection.request(self.command, self.path, body, headers)
                    response = connection.getresponse()
                    event["status"] = response.status
                    data = response.read(4 * 1024 * 1024 + 1)
                    if len(data) > 4 * 1024 * 1024:
                        raise ValueError('fixture response exceeds probe bound')
                    event['response_ns'] = time.monotonic_ns() - owner.started_ns
                    if native and response.status == 200 and self.path in ('/v1/query', '/v1/command', '/v1/blocks'):
                        result = json.loads(data)
                        if self.path == '/v1/blocks':
                            result = result['response']
                        event['position'] = result['position']
                        if not mutation and operation == 'process':
                            head = result['body']['process']['input']
                            event['head_input'] = head['position'] if head else None
                    with owner.lock:
                        for label in labels:
                            owner.counts[label] += length if label == 'request_bytes' else 1
                        elapsed = time.monotonic_ns() - started
                        owner.counts['elapsed_ns'] += elapsed
                        owner.counts[self.command + ':elapsed_ns'] += elapsed
                        # Optional native diagnostics describe this completed
                        # attempt, independently of rate-limited event logs.
                        metrics = response.getheader('x-transit-work')
                        if native and metrics is not None:
                            values = json.loads(metrics)
                            event["work"] = values
                            for field in ('wait_ns', 'work_ns', 'cache_hits', 'cache_misses',
                                          'staged_pages', 'staged_bytes'):
                                amount = values[field]
                                if not isinstance(amount, int) or amount < 0:
                                    raise ValueError('invalid work counter')
                                owner.counts['work:' + field] += amount
                            for field in ('requests', 'failures', 'elapsed_ns',
                                          'request_payload_bytes', 'response_bytes'):
                                amount = values['provider'][field]
                                if not isinstance(amount, int) or amount < 0:
                                    raise ValueError('invalid provider counter')
                                owner.counts['work:provider:' + field] += amount
                            owner.counts['work:responses'] += 1
                        if native and self.path in ('/v1/query', '/v1/command', '/v1/blocks'):
                            owner.counts[classified + ':elapsed_ns'] += elapsed
                            owner.counts['principal:' + str(envelope['principal']) + ':' + classified + ':elapsed_ns'] += elapsed
                        owner.counts['response_bytes'] += len(data)
                        owner.counts['status:' + str(response.status)] += 1
                        if native and response.status != 200:
                            # Fixed categories distinguish admission pressure
                            # from unavailable storage/transport. Never turn a
                            # peer's arbitrary error text into a metric label.
                            try:
                                rejection = json.loads(data).get('err')
                            except (ValueError, AttributeError):
                                rejection = None
                            if rejection not in ('HttpCapacity', 'AuthorityUnavailable',
                                                 'AccessDenied', 'Conflict'):
                                rejection = 'other'
                            owner.counts['rejection:' + rejection] += 1
                            event['rejection'] = rejection
                    self.send_response(response.status)
                    for key, val in response.getheaders():
                        if key.lower() not in ('transfer-encoding', 'connection', 'content-length'):
                            self.send_header(key, val)
                    self.send_header('Content-Length', str(len(data)))
                    if response.will_close:
                        self.send_header('Connection', 'close')
                        self.close_connection = True
                    self.end_headers()
                    self.wfile.write(data)
                    self.wfile.flush()
                except (BrokenPipeError, ConnectionResetError) as error:
                    connection.close()
                    self.close_connection = True
                    event["failure"] = type(error).__name__
                    with owner.lock:
                        owner.counts['disconnected'] += 1
                except OSError as error:
                    connection.close()
                    self.close_connection = True
                    event["failure"] = type(error).__name__
                    with owner.lock:
                        owner.counts['transport_failures'] += 1
                    self.send_error(503)
                finally:
                    if native:
                        event['elapsed_ns'] = time.monotonic_ns() - started
                        with owner.lock:
                            owner.completed_events += 1
                            event['ordinal'] = owner.completed_events
                            owner.events.append(event)
                            if event.get('failure') is not None or event.get('status', 0) >= 400:
                                owner.completed_failures += 1
                                owner.failed_events.append(event)

            do_GET = do_POST = do_PUT = do_DELETE = do_HEAD = forward

        self.server = ThreadingHTTPServer(('127.0.0.1', port), Handler)
        self.server.daemon_threads = True
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = f'http://127.0.0.1:{self.server.server_port}'

    def snapshot(self):
        with self.lock:
            return self.counts.copy()

    def trace(self):
        with self.lock:
            return {'completed': self.completed_events, 'retained': list(self.events),
                    'omitted': self.completed_events - len(self.events),
                    'failed_completed': self.completed_failures,
                    'failed_retained': list(self.failed_events),
                    'failed_omitted': self.completed_failures - len(self.failed_events)}

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)

"""Make an owned courier's signed reads unavailable until its manager replaces it."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import threading
import time
from urllib.parse import urlsplit


class ReadinessOutage:
    def __init__(self, installation, launcher):
        self.installation, self.launcher = installation, launcher
        self.path = installation.path / 'delivery/config.json'
        self.original = self.path.read_bytes()
        self.config = json.loads(self.original)
        self.blocked = threading.Event()
        self.blocked.set()
        self.refusals = 0
        self.commands = 0
        self.errors = []
        self.started = time.monotonic()
        self.recovery = None
        self.cleanup_restart_started = False
        self.cleanup_restart_completed = False

    def __enter__(self):
        fault = self
        upstream = urlsplit(self.config['url'])

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_): pass

            def do_POST(self):
                try:
                    self.handle_request()
                except Exception as error:
                    fault.errors.append(type(error).__name__)
                    raise

            def handle_request(self):
                self.connection.settimeout(5)
                length = int(self.headers['Content-Length'])
                assert 0 < length <= 65536
                body = self.rfile.read(length)
                if self.path == '/v1/query' and fault.blocked.is_set():
                    query = json.loads(body)['query']
                    assert query['kind'] == {'delivery': {}}
                    assert query['realm'] == fault.config['realm']
                    assert query['principal'] == fault.config['principal']
                    fault.refusals += 1
                    code, data = 503, b'{"err":"AuthorityUnavailable"}'
                else:
                    if self.path == '/v1/command':
                        assert not fault.blocked.is_set(), 'Dispatch during refused fresh courier observation'
                        fault.commands += 1
                    connection = HTTPConnection(upstream.hostname, upstream.port, timeout=5)
                    try:
                        connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                        response = connection.getresponse()
                        code, data = response.status, response.read()
                    finally:
                        connection.close()
                self.send_response(code)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                try: self.wfile.write(data)
                except (BrokenPipeError, ConnectionResetError): pass

        class Server(ThreadingHTTPServer):
            daemon_threads = False  # server_close joins each bounded request.

        self.server = Server(('127.0.0.1', 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, kwargs={'poll_interval': .05})
        self.thread.start()
        try:
            self.path.write_text(json.dumps(self.config | {'url': f'http://127.0.0.1:{self.server.server_port}'}))
            self.launcher.restart('delivery')
            self.before = self.service()
            assert self.before['is_running']
            return self
        except BaseException:
            self.__exit__(None, None, None)
            raise

    def service(self):
        return next(process for process in self.launcher.services() if process['name'] == 'delivery')

    def recover(self, deadline):
        while time.monotonic() < deadline:
            current = self.service()
            if (current['is_running'] and current['pid'] != self.before['pid'] and
                    current['restarts'] > self.before['restarts']):
                assert self.refusals >= 15 and self.commands == 0
                self.blocked.clear()
                self.recovery = {'refused_reads': self.refusals,
                                 'restarts': current['restarts'] - self.before['restarts'],
                                 'replacement_seconds': round(time.monotonic()-self.started, 3)}
                return self.recovery
            time.sleep(.1)
        raise AssertionError('Courier did not recover after failed readiness probes')

    def __exit__(self, *_):
        self.blocked.clear()
        try:
            self.path.write_bytes(self.original)
            self.cleanup_restart_started = True
            self.launcher.restart('delivery')
            self.cleanup_restart_completed = True
        finally:
            self.server.shutdown()
            self.thread.join(timeout=5)
            self.server.server_close()
            assert not self.thread.is_alive(), 'Courier fault proxy did not join'
            assert not self.errors, ('Unexpected courier proxy errors', self.errors)

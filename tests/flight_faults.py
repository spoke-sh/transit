"""Owned native-boundary failures; credentials and result bytes stay private."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit
import threading


class NativeBoundary:
    def __init__(self, upstream):
        target = urlsplit(upstream)
        self.drop = False
        self.original = None
        self.receipt = None
        self.retries = 0
        self.pause = False
        self.reached = threading.Event()
        self.release = threading.Event()
        self.hold_count = 0
        self.held = 0
        self.lock = threading.Lock()
        self.saturated = threading.Event()
        boundary = self
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                with boundary.lock:
                    held = self.path == '/v1/query' and boundary.hold_count > 0
                    if held:
                        boundary.hold_count -= 1
                        boundary.held += 1
                        if boundary.hold_count == 0: boundary.saturated.set()
                if held and not boundary.release.wait(timeout=15): return
                if boundary.pause and self.path == '/v1/query':
                    boundary.reached.set()
                    if not boundary.release.wait(timeout=15): return
                connection = HTTPConnection(target.hostname, target.port, timeout=30)
                try:
                    connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    result = response.read()
                    if self.path == '/v1/command' and response.status == 200:
                        if boundary.original == body:
                            assert result == boundary.receipt, 'exact retry changed native receipt'
                            boundary.retries += 1
                        if boundary.drop:
                            boundary.drop = False
                            boundary.original, boundary.receipt = body, result
                            self.close_connection = True
                            return  # Acceptance occurred; no receipt is sent.
                    self.send_response(response.status)
                    self.send_header('Content-Length', str(len(result)))
                    self.end_headers()
                    self.wfile.write(result)
                except (BrokenPipeError, ConnectionResetError): pass
                finally: connection.close()
        self.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.url = f'http://127.0.0.1:{self.server.server_port}'

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, *_):
        self.release.set()
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)

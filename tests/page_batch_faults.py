"""Private segments with lost creation, incomplete coordinates or bad readback."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import subprocess
import threading


def check(binary, fixture, keys, cache, batch):
    fault = [None]
    observed = []

    class Handler(BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'
        disable_nagle_algorithm = True

        def log_message(self, *_):
            pass

        def forward(self):
            connection = HTTPConnection('127.0.0.1', fixture.port, timeout=10)
            try:
                body = self.rfile.read(int(self.headers.get('Content-Length', '0')))
                headers = {k: v for k, v in self.headers.items()
                           if k.lower() not in ('host', 'connection', 'content-length')}
                connection.request(self.command, self.path, body, headers)
                response = connection.getresponse()
                data = response.read()
                dropping = None
                selected = '/s-' in self.path and ((self.command == 'PUT' and fault[0] in ('lost', 'incomplete')) or (self.command == 'GET' and fault[0] == 'partial'))
                if selected:
                    assert 200 <= response.status < 300
                    dropping, fault[0] = fault[0], None
                    observed.append(dropping)
                    if dropping == 'lost':
                        self.close_connection = True
                        return
                if dropping == 'partial':
                    data = data.replace(b'"', b'!', 1)
                self.send_response(response.status)
                for key, value in response.getheaders():
                    if key.lower() in ('connection', 'content-length', 'transfer-encoding'):
                        continue
                    if dropping == "incomplete" and key.lower() == "stream-record-next":
                        value = str(int(value) - 1)
                    self.send_header(key, value)
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                if self.command != 'HEAD':
                    self.wfile.write(data)
            finally:
                connection.close()

        do_PUT = do_POST = do_GET = do_HEAD = forward

    proxy = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=proxy.serve_forever, daemon=True)
    thread.start()
    try:
        for mode in ('lost', 'incomplete', 'partial'):
            fault[0] = mode
            result = subprocess.run([binary, f'http://127.0.0.1:{proxy.server_port}',
                'staging_fault', str(keys), str(cache), 'packed', str(batch)],
                env=fixture.env, capture_output=True, text=True, timeout=60)
            assert result.returncode == 0, result.stderr
            assert fault[0] is None, 'batch fault was not exercised'
        assert observed == ['lost', 'incomplete', 'partial']
        print('Immutable segment faults: lost creation, incomplete coordinates and corrupt readback prevent publication; authority and retained roots unchanged.', flush=True)
    finally:
        proxy.shutdown()
        proxy.server_close()
        thread.join(timeout=5)

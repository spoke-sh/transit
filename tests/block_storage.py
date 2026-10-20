"""Owned disk blocks: retained roots, process restart and failed staging/readback."""
import base64
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import socket
import subprocess
import sys
import threading

from storage import Fixture


def run(executable):
    executable = str(Path(executable).resolve())
    with Fixture() as fixture:
        fault = {'mode': None, 'observed': 0}

        class Peer(BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.1'
            def setup(self):
                super().setup()
                self.connection.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            def log_message(self, *_): pass
            def do_HEAD(self): self.forward()
            def do_GET(self): self.forward()
            def do_POST(self): self.forward()
            def do_PUT(self): self.forward()

            def forward(self):
                body = self.rfile.read(int(self.headers.get('Content-Length', '0')))
                connection = HTTPConnection('127.0.0.1', fixture.port, timeout=10)
                try:
                    connection.request(self.command, self.path, body, dict(self.headers))
                    response = connection.getresponse()
                    data = response.read()
                    status = response.status
                    frames = data.splitlines(keepends=True)
                    encoded = next((frame.rstrip(b'\n') for frame in frames if frame.startswith(b'"VEJL')), data.rstrip(b'\n'))
                    is_block = False
                    if self.command == 'GET' and len(encoded) >= 2 and encoded[:1] == b'"' and encoded[-1:] == b'"':
                        decoded = base64.b64decode(encoded[1:-1], validate=True)
                        is_block = decoded.startswith(b'TBK1')
                    if fault['mode'] == 'lost-stage' and self.command == 'PUT' and '/s-' in self.path:
                        assert 200 <= status < 300, status
                        fault['observed'] += 1
                        fault['mode'] = None
                        self.close_connection = True
                        return
                    if is_block and fault['mode'] == 'corrupt':
                        decoded = decoded[:-1] + bytes([decoded[-1] ^ 1])
                        data = data.replace(encoded + b'\n', b'"' + base64.b64encode(decoded) + b'"\n', 1)
                        fault['observed'] += 1
                    elif is_block and fault['mode'] == 'missing':
                        status, data = 404, b''
                        fault['observed'] += 1
                    self.send_response(status)
                    for name, value in response.getheaders():
                        if name.lower() not in ('connection', 'content-length', 'transfer-encoding'):
                            self.send_header(name, value)
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    if data:
                        self.wfile.write(data)
                finally:
                    connection.close()

        peer = ThreadingHTTPServer(('127.0.0.1', 0), Peer)
        thread = threading.Thread(target=peer.serve_forever, daemon=True)
        thread.start()
        url = f'http://127.0.0.1:{peer.server_port}'
        try:
            subprocess.run([executable, url, 'write'], check=True, timeout=45)
            fixture.stop()
            fixture.start()
            subprocess.run([executable, url, 'verify'], check=True, timeout=30)
            for mode in ('lost-stage', 'corrupt', 'missing'):
                fault.update(mode=mode, observed=0)
                subprocess.run([executable, url, 'staging-fault'], check=True, timeout=30)
                assert fault['observed'] == 1, fault
            fault.update(mode=None)
            fixture.stop()
            fixture.start()
            subprocess.run([executable, url, 'verify'], check=True, timeout=30)
            for mode, expected in [('corrupt', b'CorruptBlock'), ('missing', b'BlockUnavailable')]:
                fault.update(mode=mode, observed=0)
                result = subprocess.run([executable, url, 'verify'], capture_output=True, timeout=30)
                assert result.returncode != 0 and expected in result.stderr, result.stderr
                assert fault['observed'] >= 1, fault
            fault.update(mode=None)
            subprocess.run([executable, url, 'verify'], check=True, timeout=30)
        finally:
            peer.shutdown()
            peer.server_close()
            thread.join(timeout=5)
    print('Disk blocks: full-size batch and retained roots with one resident page; SIGKILL/restart, lost staging reply, corrupt/missing bytes and unchanged publication passed.')


if __name__ == '__main__':
    run(*sys.argv[1:])

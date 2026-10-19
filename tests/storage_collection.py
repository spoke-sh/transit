"""Owned disk collection: corruption, lost deletion replies and restart."""
import base64
import hashlib
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
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
            def do_DELETE(self): self.forward()
            def forward(self):
                body = self.rfile.read(int(self.headers.get('Content-Length', '0')))
                upstream = HTTPConnection('127.0.0.1', fixture.port, timeout=20)
                try:
                    upstream.request(self.command, self.path, body, dict(self.headers))
                    response = upstream.getresponse()
                    data, status = response.read(), response.status
                    if fault['mode'] == 'corrupt' and self.command == 'GET':
                        for frame in data.splitlines(keepends=True):
                            if frame.startswith(b'"VEJL'):
                                decoded = base64.b64decode(frame.strip()[1:-1], validate=True)
                                damaged = decoded[:-1] + bytes([decoded[-1] ^ 1])
                                data = data.replace(frame, b'"' + base64.b64encode(damaged) + b'"\n', 1)
                                fault.update(mode=None, observed=fault['observed'] + 1)
                                break
                    if fault['mode'] == 'lost-delete' and self.command == 'DELETE' and '/s-' in self.path:
                        assert 200 <= status < 300, status
                        fault.update(mode=None, observed=fault['observed'] + 1)
                        self.close_connection = True
                        return
                    self.send_response(status)
                    for name, value in response.getheaders():
                        if name.lower() not in ('connection', 'content-length', 'transfer-encoding'):
                            self.send_header(name, value)
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    if data:
                        self.wfile.write(data)
                finally:
                    upstream.close()
        peer = ThreadingHTTPServer(('127.0.0.1', 0), Peer)
        thread = threading.Thread(target=peer.serve_forever, daemon=True)
        thread.start()
        def phase(name, failure=None):
            result = subprocess.run([executable, f'http://127.0.0.1:{peer.server_port}', name], capture_output=True, timeout=300)
            if failure:
                assert result.returncode and failure in result.stderr, result.stderr
                assert fault['observed'] == 1, fault
                return None
            if result.returncode:
                raise RuntimeError(result.stderr.decode())
            record = json.loads(result.stdout)
            print(json.dumps(record), flush=True)
            return record
        def restart():
            fixture.stop()
            fixture.start()
        try:
            phase('initialize')
            restart()
            fault.update(mode='corrupt', observed=0)
            phase('mark', b'CorruptBlock')
            restart()
            phase('mark')
            restart()
            phase('intent')
            restart()
            fault.update(mode='lost-delete', observed=0)
            phase('sweep', b'error:')
            restart()
            first = phase('sweep')
            restart()
            phase('verify')
            previous = phase('compact')['relocated_from']
            assert previous is not None
            restart()
            phase('mark')
            restart()
            phase('intent')
            restart()
            second = phase('sweep')
            assert second['accounting']['reclaimed_bytes'] > first['accounting']['reclaimed_bytes']
            restart()
            phase('verify')
            identity = previous['epoch'].to_bytes(8, 'big') + bytes(previous['nonce'])
            digest = hashlib.sha256(b'transit.immutable.segment.v1\0transit-collection-proof\0authority\0' + identity).digest()
            name = 's-' + base64.urlsafe_b64encode(digest).decode().rstrip('=')
            check = HTTPConnection('127.0.0.1', fixture.port, timeout=10)
            check.request('HEAD', '/transit-collection-proof/' + name)
            response = check.getresponse()
            assert response.status == 404, (name, response.status, response.read())
            check.close()
        finally:
            peer.shutdown()
            peer.server_close()
            thread.join(timeout=5)
    print('Physical collection: retained independent roots, bounded relocation, actual segment deletion, permanent late-create fences, grace, corruption, lost delete reply, process/provider restart and exact quota release passed.')


if __name__ == '__main__':
    run(*sys.argv[1:])

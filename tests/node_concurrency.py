"""Disk-backed native concurrency; barriers establish overlap without latency SLOs."""
from concurrent.futures import ThreadPoolExecutor
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import socket
import sys
import threading

from storage import Fixture, free_port, wait_ready


def run(node, signer):
    node, signer = str(Path(node).resolve()), str(Path(signer).resolve())
    signed = json.loads(subprocess.check_output([signer], timeout=10))
    with Fixture() as fixture:
        gate_lock = threading.Lock()
        entered, released = threading.Event(), threading.Event()
        gate = {'method': None}
        faults = []

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
                size = int(self.headers.get('Content-Length', '0'))
                body = self.rfile.read(size)
                with gate_lock:
                    pause = gate['method'] == self.command
                    if pause:
                        gate['method'] = None
                connection = HTTPConnection('127.0.0.1', fixture.port, timeout=10)
                try:
                    connection.request(self.command, self.path, body, dict(self.headers))
                    response = connection.getresponse()
                    data = response.read()
                    if pause:
                        entered.set()
                        if not released.wait(8):
                            faults.append('storage barrier timed out')
                    self.send_response(response.status)
                    for name, value in response.getheaders():
                        if name.lower() not in ('connection', 'content-length', 'transfer-encoding'):
                            self.send_header(name, value)
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    if data:
                        self.wfile.write(data)
                except (BrokenPipeError, ConnectionResetError):
                    pass  # A cancelled transport may close after publication.
                finally:
                    connection.close()

        peer = ThreadingHTTPServer(('127.0.0.1', 0), Peer)
        thread = threading.Thread(target=peer.serve_forever, daemon=True)
        thread.start()
        port = free_port()
        config = fixture.root / 'node.json'
        config.write_text(json.dumps(dict(
            profile='native_v1', genesis=dict(realm=42, root_key=signed['root_key'], max_clock_error_ms=10000),
            ursula_url=f'http://127.0.0.1:{peer.server_port}', bucket='node-concurrency',
            journal='authority', port=port, resident_pages=1, request_timeout_ms=10000)))
        log = (fixture.root / 'node.log').open('w+')
        authority = None

        def request(name):
            envelope = signed[name] if isinstance(name, str) else name
            path = '/v1/command' if 'request' in envelope else '/v1/query'
            connection = HTTPConnection('127.0.0.1', port, timeout=12)
            try:
                connection.request('POST', path, json.dumps(envelope), {'Content-Type': 'application/json'})
                response = connection.getresponse()
                return response.status, json.loads(response.read())
            finally:
                connection.close()

        def arm(method):
            entered.clear()
            released.clear()
            with gate_lock:
                gate['method'] = method

        try:
            subprocess.run([node, str(config), '--initialize'], check=True, timeout=30, stdout=log, stderr=log)
            authority = subprocess.Popen([node, str(config)], stdout=log, stderr=log)
            wait_ready(fixture.http, authority, f'http://127.0.0.1:{port}/health')
            for command in signed['setup']:
                result = request(command)
                assert result[0] == 200, result
            with ThreadPoolExecutor(max_workers=3) as pool:
                # The first request has received a provider response but cannot
                # observe it. Independent signed reads and control must finish
                # before that request is released, even on a single CPU.
                arm('HEAD')
                stalled = pool.submit(request, 'read')
                try:
                    assert entered.wait(5), 'read never reached provider barrier'
                    independent = pool.submit(request, 'read').result(timeout=5)
                    assert independent[0] == 200, independent
                    written = pool.submit(request, 'write').result(timeout=5)
                    assert written[0] == 200, written
                    assert not stalled.done(), 'barrier did not retain slow request'
                finally:
                    released.set()
                slow = stalled.result(timeout=5)
                assert slow[0] == 200, slow
                assert slow[1]['position'] > written[1]['position'], slow
                assert request('write') == written, 'exact retry changed receipt'
                conflicting = request('competing')
                assert conflicting[0] != 200 and conflicting[1]['err'] == 'ConflictingRetry', conflicting

                # Hold old provider evidence while a revocation completes. A
                # snapshot opened through that evidence cannot disclose success.
                arm('GET')
                reading = pool.submit(request, 'snapshot')
                try:
                    assert entered.wait(5), 'snapshot never reached provider barrier'
                    revoked = pool.submit(request, 'revoke').result(timeout=5)
                    assert revoked[0] == 200, revoked
                    assert not reading.done()
                finally:
                    released.set()
                denied = reading.result(timeout=5)
                assert denied[0] == 403, denied
                assert request('snapshot')[0] == 403

                # Two simultaneously prepared identical requests have one
                # receipt. The losing CAS can conflict, then reconcile exactly.
                left = pool.submit(request, 'lost')
                right = pool.submit(request, 'lost')
                results = [left.result(timeout=5), right.result(timeout=5)]
                assert any(status == 200 for status, _ in results), results
                assert all(status in (200, 409) for status, _ in results), results
                receipt = next(body for status, body in results if status == 200)
                assert request('lost') == (200, receipt)
            assert not faults, faults
            print('Native concurrency: blocked provider read overlaps signed read and commit; revocation rejects old evidence; concurrent exact retries preserve one receipt.')
        except BaseException:
            log.flush()
            log.seek(0)
            sys.stderr.write(log.read()[-12000:])
            raise
        finally:
            released.set()
            if authority is not None:
                if authority.poll() is None:
                    authority.kill()
                authority.wait(timeout=10)
            peer.shutdown()
            peer.server_close()
            thread.join(timeout=5)
            log.close()


if __name__ == '__main__':
    run(*sys.argv[1:])

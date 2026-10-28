"""Independent finite-relation peer for client allocation checks, not SQL execution."""
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
import socket
from socketserver import ThreadingMixIn, UnixStreamServer
import ssl
import struct
import subprocess
import sys
import tempfile
import threading

from runner.paths import ROOT
from interfaces.sql_sessions.result_frame import encode_fixture, CONTENT_TYPE, ENCODING
from query.logical.fuze_types import DEFINITION


def schema(wide):
    fields = [(b'id', 2)] + ([(b'text', 5)] if wide else [])
    value = b'FTY1' + bytes([len(DEFINITION)]) + DEFINITION + bytes([22, len(fields)])
    for name, kind in fields:
        value += bytes([len(name)]) + name + bytes([0, kind])
    return value.hex()


@contextmanager
def peer(mode, root):
    definition = re.search(r'\b([a-f0-9]{64})\b', (ROOT / 'packages/zig/transit-protocol/src/Growth.zig').read_text()).group(1)
    state = dict(requests=0, queries=0, retries=0, turnovers=0)
    active = {}
    dropped = set()
    lock = threading.Lock()
    observation = dict(metadata=dict(kind='probe', consistency='session', namespace=None, definitions=[], configuration_revision=None, session_settings=None, source=None))

    class Handler(BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'

        def log_message(self, *_):
            pass

        def setup(self):
            super().setup()
            self.requests = 0

        def do_POST(self):
            request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
            assert request['definition'] == definition and request['version'] == 1
            action, value = next(iter(request['action'].items()))
            with lock:
                state['requests'] += 1
            self.requests += 1
            binary = False
            if action == 'hello':
                result = dict(hello=dict(encoding=ENCODING, session_lease_ms=30000, maximum_message=4194304, maximum_batch=1048576, maximum_rows=32, capabilities=[]))
            elif action == 'open':
                result = dict(opened=dict(session=[3] * 32, account=[4] * 32, database='transit', proof=''))
            elif action in ('close', 'close_result', 'touch'):
                result = dict(closed={})
                if action == 'close_result':
                    active.pop(bytes(value), None)
            else:
                if action == 'execute':
                    match = re.fullmatch(r'SELECT (\d+) (wide|narrow) (retry|once)', value['sql'])
                    assert match
                    with lock:
                        state['queries'] += 1
                        cursor = state['queries'].to_bytes(32, 'little')
                    active[cursor] = int(match[1]), match[2] == 'wide', match[3] == 'retry'
                    ordinal = 0
                else:
                    assert action == 'fetch', action
                    cursor, ordinal = bytes(value['cursor']), value['batch']
                length, wide, retry = active[cursor]
                if retry and ordinal == 1 and cursor not in dropped:
                    dropped.add(cursor)
                    with lock:
                        state['retries'] += 1
                    self.close_connection = True
                    self.connection.shutdown(socket.SHUT_RDWR)
                    return
                start = ordinal * 32
                end = min(length, start + 32)
                assert start <= length
                rows = []
                for row in range(start, end):
                    cells = [(b'\x03' + struct.pack('<Q', row)).hex()]
                    if wide:
                        cells += [(b'\x03' + struct.pack('<I', 24000) + bytes([ord('a') + row % 26]) * 24000).hex()]
                    rows.append(cells)
                payload = encode_fixture(definition, [2] * 16, dict(cursor=list(cursor), batch=ordinal, schema=schema(wide), observation=observation, rows=rows, complete=end == length, completion=dict(rows=length) if end == length else None))
                binary = True
            if not binary:
                payload = json.dumps(dict(version=1, definition=definition, instance=[2] * 16, result=result)).encode()
            self.send_response(200)
            self.send_header('Content-Type', CONTENT_TYPE if binary else 'application/json')
            self.send_header('Content-Length', str(len(payload)))
            if self.requests == 256:
                with lock:
                    state['turnovers'] += 1
                self.send_header('Connection', 'close')
                self.close_connection = True
            self.end_headers()
            self.wfile.write(payload)

    class UnixServer(ThreadingMixIn, UnixStreamServer):
        daemon_threads = True

    ca = ''
    if mode == 'unix':
        path = root / 'peer.sock'
        server = UnixServer(str(path), Handler)
        endpoint = f'unix:{path}'
    else:
        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        endpoint = f'{mode}://127.0.0.1:{server.server_port}'
        if mode == 'https':
            ca = str(root / 'certificate.pem')
            key = str(root / 'key.pem')
            subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', key, '-out', ca, '-days', '1', '-subj', '/CN=127.0.0.1', '-addext', 'subjectAltName=IP:127.0.0.1'], check=True, capture_output=True)
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(ca, key)
            server.socket = context.wrap_socket(server.socket, server_side=True)
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        yield endpoint, ca, state
    finally:
        server.shutdown()
        server.server_close()
        worker.join()


def main():
    binary = str(Path(sys.argv[1]).resolve())
    for mode in ('unix', 'http', 'https'):
        with tempfile.TemporaryDirectory(prefix='transit-result-allocations-') as directory:
            with peer(mode, Path(directory)) as (endpoint, ca, state):
                result = subprocess.run([binary, endpoint, ca], capture_output=True, text=True, timeout=120)
                print(result.stdout, end='', flush=True)
                assert result.returncode == 0, result.stderr
                report = json.loads(result.stdout.splitlines()[-1])
                assert report['statements'] == 300 and state['queries'] == 301
                assert state['requests'] > 256 and state['retries'] > 0 and state['turnovers'] > 0, state
                assert report['backing']['alloc_attempts'] == report['backing']['growing_resize_attempts'] == report['backing']['remap_attempts'] == 0
                print(f'{mode}: {state}', flush=True)


if __name__ == '__main__':
    main()

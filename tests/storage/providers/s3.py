"""Actual S3 provider operations, independent wire oracle and transport faults."""
from datetime import datetime, timezone
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import hmac
import json
from pathlib import Path
import subprocess
import sys
import threading
import time
import urllib.request

from storage.providers.cold_storage import ColdStore


def request(cold, method, key, payload=b''):
    """Independent Python SigV4 client; no Transit storage code in this oracle."""
    now = datetime.now(timezone.utc)
    day, stamp = now.strftime('%Y%m%d'), now.strftime('%Y%m%dT%H%M%SZ')
    host = cold.url.split('://', 1)[1]
    path = f'/{cold.bucket}/native-conformance/{key}'
    hashed = hashlib.sha256(payload).hexdigest()
    names = 'host;x-amz-content-sha256;x-amz-date'
    canonical = f'{method}\n{path}\n\nhost:{host}\nx-amz-content-sha256:{hashed}\nx-amz-date:{stamp}\n\n{names}\n{hashed}'
    scope = f'{day}/us-east-1/s3/aws4_request'
    text = f'AWS4-HMAC-SHA256\n{stamp}\n{scope}\n{hashlib.sha256(canonical.encode()).hexdigest()}'
    signing = ('AWS4' + cold.secret).encode()
    for value in (day, 'us-east-1', 's3', 'aws4_request'):
        signing = hmac.digest(signing, value.encode(), 'sha256')
    signature = hmac.new(signing, text.encode(), hashlib.sha256).hexdigest()
    authorization = f'AWS4-HMAC-SHA256 Credential={cold.access}/{scope}, SignedHeaders={names}, Signature={signature}'
    with cold.http.open(urllib.request.Request(cold.url + path, data=payload if method == 'PUT' else None,
            method=method, headers={'Authorization': authorization, 'x-amz-date': stamp,
                                    'x-amz-content-sha256': hashed}), timeout=10) as response:
        return response.read(), dict(response.headers)


def run(binary):
    binary = str(Path(binary).resolve(strict=True))
    with ColdStore() as cold:
        root = Path(cold.directory.name)
        credentials = root / 'credentials.json'
        secret = dict(access_key_id=cold.access, secret_access_key=cold.secret)
        credentials.write_text(json.dumps(secret))
        credentials.chmod(0o600)
        options = dict(endpoint=cold.url, region='us-east-1', bucket=cold.bucket,
                       prefix='native-conformance', credentials_file=str(credentials),
                       allow_loopback_http=True, request_timeout_ms=5000)
        config = root / 's3.json'
        config.write_text(json.dumps(options))

        def invoke(mode, *args):
            subprocess.run([binary, str(config), mode, *args], check=True, timeout=90)

        invoke('write')
        raw, headers = request(cold, 'GET', 'proof/data.tseg')
        expected = bytes((i * 37 + 13) % 256 for i in range(2 * 65536 + 17))
        assert raw[:8] == b'TS3O\x01\x00\x00\x00'
        assert int.from_bytes(raw[48:56], 'little') == len(expected)
        assert raw[56:88] == hashlib.sha256(expected).digest()
        assert raw[480:512] == hashlib.sha256(raw[:480]).digest()
        checks = raw[512:512 + 3 * 32]
        assert raw[88:120] == hashlib.sha256(checks).digest()
        assert raw[512 + 3 * 32:] == expected
        for i in range(3):
            assert checks[i*32:(i+1)*32] == hashlib.sha256(expected[i*65536:(i+1)*65536]).digest()
        assert headers['ETag'].strip('"') != hashlib.sha256(expected).hexdigest(), 'Provider ETag was confused with logical content digest'
        racers = [subprocess.Popen([binary, str(config), 'race', value]) for value in ('first', 'second')]
        try:
            assert sorted(child.wait(timeout=30) for child in racers) == [0, 2]
        finally:
            for child in racers:
                if child.poll() is None: child.kill()
                child.wait(timeout=10)
        invoke('read')
        invoke('rotation')
        credentials.write_text(json.dumps(secret | {'secret_access_key': 'wrong-secret'}))
        invoke('denied')
        credentials.write_text(json.dumps(secret))
        invoke('read')
        corrupted = bytearray(raw)
        corrupted[-1] ^= 1
        request(cold, 'PUT', 'proof/data.tseg', bytes(corrupted))
        invoke('corrupt')
        request(cold, 'PUT', 'proof/data.tseg', raw)
        invoke('read')

        lost = {'dropped': False, 'puts': 0}

        class LostReply(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def exchange(self):
                body = self.rfile.read(int(self.headers.get('Content-Length', '0')))
                upstream = HTTPConnection('127.0.0.1', cold.port, timeout=10)
                try:
                    upstream.request(self.command, self.path, body, dict(self.headers))
                    response = upstream.getresponse()
                    data = response.read()
                    if self.command == 'PUT':
                        lost['puts'] += 1
                        if not lost['dropped']:
                            assert response.status == 200
                            lost['dropped'] = True
                            self.close_connection = True
                            return
                    self.send_response(response.status)
                    for name, value in response.getheaders():
                        if name.lower() not in ('connection', 'transfer-encoding'):
                            self.send_header(name, value)
                    self.end_headers()
                    if self.command != 'HEAD': self.wfile.write(data)
                finally:
                    upstream.close()
            do_PUT = do_GET = do_HEAD = exchange

        peer = ThreadingHTTPServer(('127.0.0.1', 0), LostReply)
        thread = threading.Thread(target=peer.serve_forever)
        thread.start()
        try:
            config.write_text(json.dumps(options | dict(endpoint=f'http://127.0.0.1:{peer.server_port}')))
            attempt = subprocess.run([binary, str(config), 'put'], capture_output=True, timeout=30)
            assert attempt.returncode != 0 and lost['dropped']
            assert cold.secret.encode() not in attempt.stderr
            accepted, _ = request(cold, 'GET', 'proof/lost')
            assert accepted[-len(b'original accepted content'):] == b'original accepted content'
            invoke('put')
            assert lost['puts'] == 2, 'The adapter must not hide an automatic replay'
            observed, _ = request(cold, 'GET', 'proof/lost')
            assert observed == accepted
        finally:
            peer.shutdown()
            peer.server_close()
            thread.join(timeout=5)
            assert not thread.is_alive()
            config.write_text(json.dumps(options))

        class Stalled(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_HEAD(self): time.sleep(.5)

        peer = ThreadingHTTPServer(('127.0.0.1', 0), Stalled)
        thread = threading.Thread(target=peer.serve_forever)
        thread.start()
        try:
            config.write_text(json.dumps(options | dict(endpoint=f'http://127.0.0.1:{peer.server_port}', request_timeout_ms=100)))
            invoke('timeout')
        finally:
            peer.shutdown()
            peer.server_close()
            thread.join(timeout=5)
            assert not thread.is_alive()
            config.write_text(json.dumps(options))
        invoke('delete')
        print('Native S3: real MinIO PUT/CAS/HEAD/range/DELETE, independent envelope oracle, competing clients, live credential rotation, lost accepted reply, corrupt payload and joined deadline passed.', flush=True)


if __name__ == '__main__':
    run(sys.argv[1])

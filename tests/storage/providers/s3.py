"""Actual S3 provider operations, independent wire oracle and transport faults."""
from datetime import datetime, timezone
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import hmac
import json
import select
import signal
import shutil
from pathlib import Path
import subprocess
import sys
import threading
import time
import urllib.request

from storage.providers.cold_storage import ColdStore


class CountedTransport:
    """Count immutable data requests without retaining keys, headers or payloads."""
    def __init__(self, upstream_port):
        self.lock = threading.Lock()
        self.counts = {}
        self.put_bytes = 0
        self.next_connection = 0
        self.data_connections = set()
        self.delay_path = None
        self.held = threading.Event()
        self.release = threading.Event()
        self.finished = threading.Event()
        self.delayed_status = None
        self.drop_retirement_reply = False
        self.retirement_reply_lost = threading.Event()
        measurement = self

        class Handler(BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.1'
            def handle(self):
                try:
                    super().handle()
                except ConnectionResetError:
                    # Failed requests close without draining error bodies.
                    # Caller outcomes and provider bytes are checked separately.
                    self.close_connection = True
            def setup(self):
                super().setup()
                with measurement.lock:
                    self.connection_id = measurement.next_connection
                    measurement.next_connection += 1
            def log_message(self, *_): pass
            def exchange(self):
                size = int(self.headers.get('Content-Length', '0'))
                assert 0 <= size <= 40 * 1024 * 1024
                body = self.rfile.read(size)
                delay = False
                with measurement.lock:
                    if self.command == 'PUT' and self.path == measurement.delay_path:
                        measurement.delay_path = None
                        delay = True
                if '/objects/' in self.path:
                    with measurement.lock:
                        measurement.data_connections.add(self.connection_id)
                        measurement.counts[self.command] = measurement.counts.get(self.command, 0) + 1
                        if self.command == 'PUT': measurement.put_bytes += size
                if delay:
                    measurement.held.set()
                    assert measurement.release.wait(timeout=30), 'Delayed PUT was not released'
                upstream = HTTPConnection('127.0.0.1', upstream_port, timeout=10)
                try:
                    upstream.request(self.command, self.path, body, dict(self.headers))
                    response = upstream.getresponse()
                    data = response.read(40 * 1024 * 1024 + 1)
                    assert len(data) <= 40 * 1024 * 1024
                    if delay:
                        measurement.delayed_status = response.status
                        measurement.finished.set()
                    if self.command == 'PUT' and len(body) == 512 and body[40] == 3 and measurement.drop_retirement_reply:
                        assert response.status == 200
                        measurement.drop_retirement_reply = False
                        measurement.retirement_reply_lost.set()
                        self.close_connection = True
                        return
                    self.send_response(response.status)
                    for name, value in response.getheaders():
                        if name.lower() not in ('connection', 'transfer-encoding'):
                            self.send_header(name, value)
                    self.end_headers()
                    if self.command != 'HEAD':
                        try:
                            self.wfile.write(data)
                        except (BrokenPipeError, ConnectionResetError):
                            if not delay: raise
                finally:
                    upstream.close()
            do_PUT = do_GET = do_HEAD = do_DELETE = exchange

        self.peer = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.peer.daemon_threads = False
        self.thread = threading.Thread(target=self.peer.serve_forever)
        self.url = f'http://127.0.0.1:{self.peer.server_port}'

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, *_):
        self.release.set()
        self.peer.shutdown()
        self.peer.server_close()
        self.thread.join(timeout=5)
        assert not self.thread.is_alive()

    def take(self):
        with self.lock:
            result = dict(requests=self.counts, put_body_bytes=self.put_bytes,
                          connections=len(self.data_connections))
            self.counts, self.put_bytes = {}, 0
            self.data_connections = set()
            return result


def request(cold, method, key, payload=b'', *, prefix='native-conformance'):
    """Independent Python SigV4 client; no Transit storage code in this oracle."""
    now = datetime.now(timezone.utc)
    day, stamp = now.strftime('%Y%m%d'), now.strftime('%Y%m%dT%H%M%SZ')
    host = cold.url.split('://', 1)[1]
    path = f'/{cold.bucket}/{prefix}/{key}'
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


def assert_retired(raw):
    assert len(raw) == 512 and raw[:8] == b'TS3O\x01\x00\x00\x00' and raw[40] == 3
    assert int.from_bytes(raw[48:56], 'little') == 0
    assert raw[56:88] == hashlib.sha256(b'').digest()
    assert raw[88:120] == hashlib.sha256(b'').digest()
    assert raw[480:512] == hashlib.sha256(raw[:480]).digest()


def run(binary):
    binary = str(Path(binary).resolve(strict=True))
    with ColdStore() as cold, CountedTransport(cold.port) as transport:
        root = Path(cold.directory.name)
        credentials = root / 'credentials.json'
        secret = dict(access_key_id=cold.access, secret_access_key=cold.secret)
        credentials.write_text(json.dumps(secret))
        credentials.chmod(0o600)
        options = dict(endpoint=transport.url, region='us-east-1', bucket=cold.bucket,
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

        redirected, release_redirect = threading.Event(), threading.Event()

        class RedirectTarget(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def refused(self):
                redirected.set()
                self.send_response(400)
                self.send_header('Content-Length', '0')
                self.end_headers()
            do_GET = do_HEAD = do_PUT = refused

        class Redirect(BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.1'
            def log_message(self, *_): pass
            def do_PUT(self):
                size = int(self.headers.get('Content-Length', '0'))
                assert 0 <= size <= 40 * 1024 * 1024
                self.rfile.read(size)
                self.send_response(307)
                self.send_header('Location', f'http://127.0.0.1:{target.server_port}/redirected')
                self.send_header('Content-Length', '1048576')
                self.end_headers()
                assert release_redirect.wait(timeout=10)
                self.close_connection = True

        target = ThreadingHTTPServer(('127.0.0.1', 0), RedirectTarget)
        peer = ThreadingHTTPServer(('127.0.0.1', 0), Redirect)
        target.daemon_threads = peer.daemon_threads = False
        threads = [threading.Thread(target=server.serve_forever) for server in (target, peer)]
        for thread in threads: thread.start()
        try:
            config.write_text(json.dumps(options | dict(endpoint=f'http://127.0.0.1:{peer.server_port}')))
            attempt = subprocess.run([binary, str(config), 'put'], capture_output=True, timeout=10)
            assert attempt.returncode != 0 and b'ObjectProviderFailure' in attempt.stderr, attempt.stderr
            assert not redirected.is_set(), 'The adapter forwarded a signed request through a redirect'
            print('Native S3 redirect: refused without forwarding or draining the withheld body.', flush=True)
        finally:
            release_redirect.set()
            for server in (peer, target):
                server.shutdown()
                server.server_close()
            for thread in threads:
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
        native = root / 'native'

        def tier(mode, directory=None):
            with (root / f'{mode}.log').open('w+') as log:
                child = subprocess.Popen([binary, str(config), mode, str(directory or native)], stdout=subprocess.PIPE, stderr=log)
                try:
                    ready, _, _ = select.select([child.stdout], [], [], 90)
                    line = child.stdout.readline() if ready else b''
                    if line != b'tier-proof-complete\n':
                        log.flush()
                        log.seek(0)
                        raise AssertionError((mode, child.poll(), line, log.read()[-6000:].replace(cold.secret, '<redacted>')))
                    child.kill()
                    assert child.wait(timeout=10) == -signal.SIGKILL
                finally:
                    if child.poll() is None: child.kill()
                    child.wait(timeout=10)
                    child.stdout.close()

        def remote_object(generation):
            return f'objects/{hashlib.sha256(b"table/tier-proof.tseg").hexdigest()}/{generation:016x}'

        tier('tier-write')
        try:
            request(cold, 'GET', remote_object(0))
            raise AssertionError('Foreground staging unexpectedly uploaded the object')
        except urllib.error.HTTPError as error:
            assert error.code == 404
        tier('tier-drain')
        raw, _ = request(cold, 'GET', remote_object(0))
        assert raw.endswith(b'original accepted immutable segment')
        tier('tier-read')
        tier('tier-disabled')
        original_descriptor = native / 'keys' / hashlib.sha256(b'table/tier-proof.tseg').hexdigest()
        saved_descriptor = original_descriptor.read_bytes()
        original_descriptor.unlink()
        attempt = subprocess.run([binary, str(config), 'tier-write', str(native)], capture_output=True, timeout=30)
        assert attempt.returncode != 0 and b'MissingTierDescriptor' in attempt.stderr
        assert not original_descriptor.exists(), 'Republication manufactured lost original identity'
        original_descriptor.write_bytes(saved_descriptor)
        # Losing required queue inventory cannot silently replace pending work.
        queue = native / 'tier' / 'queue'
        retained_queue = native / 'tier' / 'retained-queue'
        queue.rename(retained_queue)
        attempt = subprocess.run([binary, str(config), 'tier-read', str(native)], capture_output=True, timeout=30)
        assert attempt.returncode != 0 and b'MissingTierInventory' in attempt.stderr
        assert not queue.exists(), 'Refused recovery manufactured a new upload queue'
        retained_queue.rename(queue)
        # A self-consistent foreign payload still fails the original local digest.
        forged = bytearray(raw)
        forged[-1] ^= 1
        forged[56:88] = hashlib.sha256(forged[544:]).digest()
        forged[512:544] = forged[56:88]
        forged[88:120] = hashlib.sha256(forged[512:544]).digest()
        forged[480:512] = hashlib.sha256(forged[:480]).digest()
        request(cold, 'PUT', remote_object(0), bytes(forged))
        attempt = subprocess.run([binary, str(config), 'tier-read', str(native)], capture_output=True, timeout=30)
        assert attempt.returncode != 0 and b'ObjectDigestMismatch' in attempt.stderr
        request(cold, 'PUT', remote_object(0), raw)
        config.write_text(json.dumps(options | dict(prefix='foreign-namespace')))
        attempt = subprocess.run([binary, str(config), 'tier-read', str(native)], capture_output=True, timeout=30)
        assert attempt.returncode != 0 and b'TierNamespaceChanged' in attempt.stderr
        config.write_text(json.dumps(options))
        attempt = subprocess.run([binary, str(config), 'tier-write', str(root / 'foreign-native')], capture_output=True, timeout=30)
        assert attempt.returncode != 0 and b'TierNamespaceInUse' in attempt.stderr
        shutil.rmtree(native / 'cache')
        tier('tier-read')
        tier('tier-recreate')
        tier('tier-drain')
        retired, _ = request(cold, 'GET', remote_object(0))
        assert_retired(retired)
        tier('tier-retired')
        raw, _ = request(cold, 'GET', remote_object(2))
        assert raw.endswith(b'original accepted immutable segment')
        tier('tier-read')
        credentials.write_text(json.dumps(secret | {'secret_access_key': 'wrong-secret'}))
        tier('tier-outage')
        credentials.write_text(json.dumps(secret))
        tier('tier-drain')
        tier('tier-read')
        tier('tier-cache-fill')
        tier('tier-drain')
        tier('tier-cache-read')
        transport.take()
        tier('tier-batch-write')
        foreground = transport.take()
        assert foreground == dict(requests={}, put_body_bytes=0, connections=0), foreground
        tier('tier-drain')
        upload = transport.take()
        assert upload['requests'].get('PUT') == 8, upload
        # Independent TS3O envelope oracle: 512-byte header and one 32-byte
        # chunk digest per 1024-byte object. Excludes headers/TLS/local I/O.
        assert upload['put_body_bytes'] == 8 * (1024 + 512 + 32), upload
        assert upload['connections'] == 1, upload
        tier('tier-batch-read')
        reads = transport.take()
        assert reads['requests'].get('GET', 0) >= 8 and reads['put_body_bytes'] == 0, reads
        assert reads['connections'] == 1, reads
        print(json.dumps(dict(profile='minio_immutable_batch_cost', objects=8,
              logical_bytes=8 * 1024, foreground=foreground, background_upload=upload,
              reads=dict(cold_objects=8, warm_objects=8, **reads),
              put_body_amplification=upload['put_body_bytes'] / (8 * 1024),
              excludes=['namespace claim', 'HTTP headers', 'TLS', 'local WAL and metadata', 'physical disk writes'])), flush=True)

        # A timed-out request can still execute remotely after the client joins.
        # Keep its create-only PUT blocked while collection and recreation run.
        late_prefix = 'native-conformance-late'
        late_native = root / 'native-late'
        config.write_text(json.dumps(options | dict(prefix=late_prefix)))
        try:
            tier('tier-write', late_native)
            transport.delay_path = f'/{cold.bucket}/{late_prefix}/{remote_object(0)}'
            attempt = subprocess.run([binary, str(config), 'tier-drain', str(late_native)],
                                     capture_output=True, timeout=20)
            assert transport.held.is_set() and attempt.returncode != 0
            assert b'ObjectRequestTimeout' in attempt.stderr, attempt.stderr[-1000:]
            tier('tier-recreate', late_native)
            transport.drop_retirement_reply = True
            attempt = subprocess.run([binary, str(config), 'tier-drain', str(late_native)],
                                     capture_output=True, timeout=20)
            assert transport.retirement_reply_lost.is_set() and attempt.returncode != 0
            tier('tier-drain', late_native)
            transport.release.set()
            assert transport.finished.wait(timeout=10), 'Delayed provider request did not finish'
            assert transport.delayed_status == 412, 'Late PUT recreated a retired remote generation'
            retired, _ = request(cold, 'GET', remote_object(0), prefix=late_prefix)
            assert_retired(retired)
            current, _ = request(cold, 'GET', remote_object(2), prefix=late_prefix)
            assert current.endswith(b'original accepted immutable segment')
            tier('tier-read', late_native)
            tier('tier-retired', late_native)
            print('Native tier retirement: 512-byte permanent generation fence, zero retained payload, lost accepted retirement reply, process reopen and rejection of a delayed original PUT passed.', flush=True)
        finally:
            transport.release.set()
            config.write_text(json.dumps(options))
        print('Native tier batch: eight distinct original generations, exact retry, immediate reads, process-death reopen and verified cold provider reads passed.', flush=True)
        print('Native tier cache: 34 MiB exceeds the 32 MiB disk budget; cold A/B/A reads, eviction and original byte verification passed.', flush=True)
        print('Native tier: local staging, persisted upload intent, verified eviction, process-death reopen, cache loss, old-generation retirement, recreation, missing original descriptor refusal, provider-denied backlog and control reserve passed.', flush=True)
        print('Native S3: real MinIO PUT/CAS/HEAD/range/DELETE, independent envelope oracle, competing clients, live credential rotation, lost accepted reply, corrupt payload and joined deadline passed.', flush=True)

    with ColdStore(tls=True) as cold:
        root = Path(cold.directory.name)
        values = cold.native_config()
        options = {name: values[name] for name in ('endpoint', 'region', 'bucket', 'prefix',
                   'credentials_file', 'ca_file', 'allow_loopback_http')}
        config = root / 'tls.json'
        config.write_text(json.dumps(options))
        for mode in ('move', 'idle', 'write', 'read'):
            subprocess.run([binary, str(config), mode], check=True, timeout=90)
        for changed in (dict(ca_file=None), dict(endpoint=options['endpoint'].replace('127.0.0.1', 'localhost'))):
            config.write_text(json.dumps(options | changed))
            attempt = subprocess.run([binary, str(config), 'read'], capture_output=True, timeout=30)
            assert attempt.returncode != 0, 'Untrusted or incorrectly named provider certificate accepted'
        print('Native S3 TLS: moved connected owner, reconnect after provider idle expiry, private PEM trust, verified requests, unknown CA and hostname mismatch rejection passed.', flush=True)


if __name__ == '__main__':
    run(sys.argv[1])

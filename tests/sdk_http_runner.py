"""Installed SDK callers against one real TLS connector and disk authority."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import select
import ssl
import subprocess
import tempfile
import threading
import time


def run(node, cli, raw_library, worker, install, label):
    from client_abi import Native
    from client_abi_growing import GrowingSystem
    from station import frame
    started = time.monotonic()
    worker = str(Path(worker).resolve())
    fixture = GrowingSystem(node, cli)
    fixture.resident_pages = 64
    body = bytes((i * 17 + 3) % 256 for i in range(513))
    response_body = bytes((i * 29 + 5) % 256 for i in range(1027))
    with tempfile.TemporaryDirectory(prefix='transit-http-consumer-') as directory, fixture as system:
        target = Path(directory)
        consumer = install(target)
        native = Native(raw_library)
        admin = native.client(system.url, timeout_ms=10000)
        private = bytes.fromhex(system.seed.read_text().strip())
        sequence = 0
        children, requests, failures = [], [], []
        def command(value):
            nonlocal sequence
            sequence += 1
            operation = native.prepare(6, private, {'realm': 72, 'principal': 0, 'sequence': sequence, 'command': value})
            try: return native.call(admin, operation)['position']
            finally: native.lib.transit_operation_destroy(operation)
        def read(kind):
            operation = native.prepare(7, private, {'realm': 72, 'principal': 0, 'kind': kind})
            try: return native.call(admin, operation)
            finally: native.lib.transit_operation_destroy(operation)
        class Peer(BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.1'
            def log_message(self, *_): pass
            def do_POST(self):
                try:
                    assert self.path == '/items/%CE%BB%20%2F', self.path
                    assert self.headers.get_all('X-Tag') == ['one', 'two']
                    assert self.headers['Authorization'] == 'Bearer fixture-secret'
                    assert self.rfile.read(int(self.headers['Content-Length'])) == body
                    requests.append(self.path)
                    self.send_response(200)
                    self.send_header('Content-Length', str(len(response_body)))
                    self.send_header('Set-Cookie', 'not-for-capture')
                    self.end_headers()
                    self.wfile.write(response_body)
                except BaseException as error:
                    failures.append(repr(error))
                    raise
        delayed = {'enabled': False}
        accepted = target / 'read-accepted'
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                conn = HTTPConnection('127.0.0.1', system.port, timeout=20)
                try:
                    data = self.rfile.read(int(self.headers['Content-Length']))
                    conn.request('POST', self.path, data, {'Content-Type': 'application/json'})
                    result = conn.getresponse()
                    reply = result.read()
                    if delayed['enabled'] and self.path == '/v3/query':
                        delayed['enabled'] = False
                        accepted.touch()
                        time.sleep(0.7)
                    self.send_response(result.status)
                    self.send_header('Content-Length', str(len(reply)))
                    self.end_headers()
                    self.wfile.write(reply)
                finally: conn.close()
        peer = ThreadingHTTPServer(('127.0.0.1', 0), Peer)
        key, cert = target / 'peer.key', target / 'peer.pem'
        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', str(key),
            '-out', str(cert), '-days', '1', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost'],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        tls.load_cert_chain(cert, key)
        peer.socket = tls.wrap_socket(peer.socket, server_side=True)
        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        threads = [threading.Thread(target=server.serve_forever, daemon=True) for server in (peer, proxy)]
        for thread in threads: thread.start()
        url = f'http://127.0.0.1:{proxy.server_port}'
        def process(principal, owned):
            pid = command({'spawn': {}})
            seed, public = system.key(f'http-{principal}')
            command({'grant': {'subject': principal, 'public_key': public,
                'permissions': 88 if owned else 124, 'pid': pid}})
            resource = command({'create_resource': {'writer': pid, 'owned': owned}})
            for subject in (0, principal): command({'grant_resource': {'resource': resource, 'subject': subject, 'permissions': 7}})
            command({'associate': {'pid': pid, 'name': b'data'.hex(), 'resource': resource}})
            return {'pid': pid, 'principal': principal, 'resource': resource, 'seed_file': str(seed), 'generation': 1}
        def config_file(name, cfg):
            path = target / (name + '.json')
            path.write_text(json.dumps(cfg))
            return path
        def start(mode, cfg):
            child = subprocess.Popen(consumer.command(mode, config_file('caller', cfg)), cwd=target,
                env=consumer.environment, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
            children.append(child)
            return child
        def action(child, value):
            child.stdin.write(value + '\n'); child.stdin.flush()
            assert select.select([child.stdout], [], [], 90)[0], 'HTTP consumer timed out'
            line = child.stdout.readline()
            assert line, f'HTTP consumer exited {child.poll()}'
            return json.loads(line)
        def close(child):
            result = action(child, 'close')
            assert result['closed']
            child.stdin.close()
            assert child.wait(timeout=15) == 0
            child.stdout.close()
            children.remove(child)
            return result
        def own(cfg):
            command({'own': {'pid': cfg['pid'], 'worker': cfg['principal'], 'expected_generation': cfg['generation']}})
            cfg['generation'] += 1
        after = None
        def deliver():
            nonlocal after
            position = read({'capabilities': {}})['position']
            outputs = []
            while True:
                page = read({'outputs': {'after': after, 'position': position}})['body']['outputs']
                for item in page['entries']:
                    if item:
                        assert item['phase'] == 'pending'
                        command({'deliver': item['id']})
                        outputs.append(item)
                        after = item['id']
                if page['next'] is None: return outputs
        try:
            service, caller = process(65536, False), process(65537, True)
            for cfg, name, resource in ((service, b'request', caller['resource']), (caller, b'capture', service['resource'])):
                command({'grant_resource': {'resource': resource, 'subject': cfg['principal'], 'permissions': 3}})
                command({'associate': {'pid': cfg['pid'], 'name': name.hex(), 'resource': resource, 'required': False}})
                cfg['generation'] += 1
                own(cfg)
            deadline = time.time_ns() // 1_000_000 + 600000
            caller.update(url=url, peer=service['pid'], body=body.hex(), deadline=deadline)
            child = start('http-caller', caller)
            for _ in range(3):
                command({'send': {'pid': caller['pid'], 'value': frame(b'upload')}})
                assert action(child, 'step') == {'called': False}
            # Kill after a committed staging prefix. A fresh installed process
            # and owner reconstruct the request and continue the shared upload.
            child.kill(); child.wait(timeout=10); children.remove(child)
            child.stdin.close(); child.stdout.close()
            own(caller)
            child = start('http-caller', caller)
            for _ in range(16):
                command({'send': {'pid': caller['pid'], 'value': frame(b'upload')}})
                if action(child, 'step')['called']: break
            else: raise AssertionError('Upload failed to complete')
            outputs = deliver()
            assert len(outputs) == 1 and outputs[0]['source'] == caller['pid'] and outputs[0]['destination'] == service['pid']
            credential = target / 'credential'
            credential.write_text('fixture-secret')
            credential.chmod(0o600)
            worker_config = {**service, 'url': system.url, 'realm': 72, 'association': 'data',
                'activation_directory': str(target), 'exchange': 2**64-1, 'endpoint_revision': 7,
                'reconcile_before_ms': deadline, 'mode': 'accept',
                'endpoint': {'host': 'localhost', 'address': '127.0.0.1', 'port': peer.server_port,
                    'tls': True, 'ca_file': str(cert), 'timeout_ms': 120000},
                'credentials': [{'binding': 'api', 'version': 7, 'header': 'Authorization', 'file': str(credential)}],
                'admission': {'caller': caller['pid'], 'resource': caller['resource'],
                    'scope': {'method': 'POST', 'target': '/items/%CE%BB%20%2F', 'headers': ['x-tag', 'authorization']}}}
            # The worker config is strict; resource is fixture metadata only.
            worker_config.pop('resource')
            def invoke():
                return json.loads(subprocess.check_output([worker, config_file('worker', worker_config)], timeout=120))
            assert invoke()['phase'] == 'ready'
            own(service)
            worker_config.update(generation=service['generation'], mode='execute')
            assert invoke()['phase'] == 'complete'
            outputs = deliver()
            assert len(outputs) == 1 and outputs[0]['destination'] == caller['pid']
            caller['outcome'] = bytes.fromhex(outputs[0]['value'])[13:].hex()
            assert action(child, 'step') == {'observed': True}
            close(child)
            credential.unlink()
            child = start('http-reader', caller)
            assert action(child, 'open') == {'prefix': True}
            command({'grant_resource': {'resource': service['resource'], 'subject': caller['principal'], 'permissions': 0}})
            assert action(child, 'denied') == {'denied': True}
            command({'grant_resource': {'resource': service['resource'], 'subject': caller['principal'], 'permissions': 3}})
            assert action(child, 'reopen') == {'complete': True, 'body': response_body.hex()}
            assert close(child)['owned'] == response_body.hex()
            caller.update(ready=str(target / 'reader-ready'), accepted=str(accepted))
            caller['continue'] = str(target / 'reader-continue')
            child = start('http-async', caller)
            until = time.monotonic() + 30
            while not Path(caller['ready']).exists():
                assert child.poll() is None and time.monotonic() < until, 'Async reader did not return a prefix'
                time.sleep(0.01)
            delayed['enabled'] = True
            Path(caller['continue']).touch()
            assert json.loads(child.communicate(timeout=30)[0]) == {'joined': True}
            assert child.returncode == 0
            children.remove(child)
            assert not failures, failures
            assert requests == ['/items/%CE%BB%20%2F'], requests
            print(f'{label} HTTP SDK: installed caller, staged host recovery, wide identity, binary TLS, correlated outcome, revoked prefix, owned replay without credentials and joined async cancellation passed ({time.monotonic()-started:.2f}s).')
        finally:
            for child in children:
                child.kill(); child.wait(timeout=10)
            native.lib.transit_client_destroy(admin)
            for server in (peer, proxy): server.shutdown(); server.server_close()
            for thread in threads: thread.join(timeout=5)

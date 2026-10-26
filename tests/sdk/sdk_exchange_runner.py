"""Installed SDK callers share authority, upload, read and disposal schedules."""
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


def run(node, cli, raw_library, worker, install, label, *, public_release=False, public_followup=False, protocol="http", fault=None, preparation_failure=False):
    assert protocol in ("http", "grpc")
    rpc = protocol == "grpc"
    assert fault is None or (rpc and fault in ("published", "retirement"))
    from grpc_faults import Boundary
    boundary = Boundary()
    from sdk.client_abi import Native
    from sdk.client_abi_growing import GrowingSystem
    from station import frame
    started = time.monotonic()
    worker = str(Path(worker).resolve())
    fixture = GrowingSystem(node, cli)
    fixture.resident_pages = 64
    body = bytes((i * 17 + 3) % 256 for i in range(513))
    response_body = bytes((i * 29 + 5) % 256 for i in range(1027))
    if rpc:
        from sdk.sdk_grpc_peer import payload
        body, response_body = payload(body), payload(response_body)
    with tempfile.TemporaryDirectory(prefix=f'transit-{protocol}-consumer-') as directory, fixture as system:
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
                    if (fault or preparation_failure) and self.path == '/v1/command' and result.status == 200:
                        request = json.loads(data)['request']
                        operation = request['command']
                        if request['principal'] == 65536:
                            if 'dispatch' in operation: boundary.hit('dispatch')
                            sent = operation.get('send', {}).get('value', '')
                            if bytes.fromhex(sent)[13:17] == b'EXP1': boundary.hit('preparation_failure')
                            turn = operation.get('turn', operation.get('turn_with_versions', {}).get('turn', {}))
                            if any(value and bytes.fromhex(value['value'])[13:].startswith(b'GRR1') for value in turn.get('outputs', [])):
                                boundary.hit('published')
                    if delayed['enabled'] and self.path == '/v1/query':
                        delayed['enabled'] = False
                        accepted.touch()
                        time.sleep(0.7)
                    self.send_response(result.status)
                    self.send_header('Content-Length', str(len(reply)))
                    self.end_headers()
                    self.wfile.write(reply)
                except (BrokenPipeError, ConnectionResetError): pass
                finally: conn.close()
        key, cert = target / 'peer.key', target / 'peer.pem'
        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', str(key),
            '-out', str(cert), '-days', '1', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost'],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if rpc:
            from sdk.sdk_grpc_peer import Peer as RpcPeer
            peer = RpcPeer(key, cert, body, response_body, requests, failures)
        else:
            peer = ThreadingHTTPServer(('127.0.0.1', 0), Peer)
            tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            tls.load_cert_chain(cert, key)
            peer.socket = tls.wrap_socket(peer.socket, server_side=True)
        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        threads = [threading.Thread(target=server.serve_forever, daemon=True) for server in ((proxy,) if rpc else (peer, proxy))]
        for thread in threads: thread.start()
        url = f'http://127.0.0.1:{proxy.server_port}'
        public_keys = {}
        def process(principal, owned):
            pid = command({'spawn': {}})
            seed, public = system.key(f'http-{principal}')
            public_keys[principal] = public
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
            child = subprocess.Popen(consumer.command(mode.replace('http-', protocol+'-'), config_file('caller', cfg)), cwd=target,
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
            caller.update(url=url, realm=72, profile='native_v1', peer=service['pid'], body=body.hex(), deadline=deadline)
            if rpc:
                caller.update(descriptor=peer.descriptor.hex(), method='/test.Peer/Bidi')
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
            if rpc:
                import hashlib
                worker_config['credentials'] = [{'binding': 'api', 'version': 7, 'metadata': 'authorization', 'file': str(credential)}]
                worker_config['response_metadata'] = ['x-tag', 'x-data-bin']
                worker_config['admission']['scope'] = {'method': '/test.Peer/Bidi', 'shape': 'bidi',
                    'descriptor_digest': list(hashlib.sha256(peer.descriptor).digest()),
                    'metadata': ['x-tag', 'x-data-bin', 'authorization']}
            # The worker config is strict; resource is fixture metadata only.
            worker_config.pop('resource')
            if fault or preparation_failure: worker_config['url'] = url
            def invoke():
                return json.loads(subprocess.check_output([worker, config_file('worker', worker_config)], timeout=120))
            if preparation_failure:
                # Admit original validation evidence, lose its receipt, then fix
                # the configuration before replacement. Revalidation would now
                # succeed; only the immutable admitted record preserves the cause.
                caller['preparation_failure'] = True
                if rpc: worker_config['credentials'] = []
                else: worker_config['endpoint']['request_bytes'] = 1
                boundary.arm('preparation_failure')
                executing = subprocess.Popen([worker, config_file('worker', worker_config)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                children.append(executing)
                assert boundary.reached.wait(timeout=90), executing.poll()
                executing.kill(); executing.communicate(timeout=10); boundary.close(); children.remove(executing)
                close(child)
                system.authority.kill(); system.authority.wait(timeout=10)
                system.store.stop(); system.store.start()
                system.authority = system.start(system.node, system.config)
                from harness.services import wait_ready
                wait_ready(system.store.http, system.authority, system.url + '/health')
                own(service); worker_config['generation'] = service['generation']
                if rpc: worker_config['credentials'] = [{'binding': 'api', 'version': 7, 'metadata': 'authorization', 'file': str(credential)}]
                else: worker_config['endpoint'].pop('request_bytes')
                credential.unlink()
                result = invoke()
                assert result['phase'] == 'unknown' and result['outcome'] == 'not_dispatched', result
                evidence = result['capture_diagnostic']
                assert evidence['code'] == 'exchange.preparation_failed' and evidence['outcome'] == 'not_applicable', evidence
                assert evidence['cause'] == ('GrpcCredentialNotGranted' if rpc else 'HttpRequestTooLarge'), evidence
                fields = {f['field']: f for f in evidence['facts'] if f}
                assert fields['field_path']['value']['text'] == ('request.metadata[3]' if rpc else 'request.body_bytes'), evidence
                assert evidence['identity']['id'] == str(2**64-1) and evidence['identity']['resource'] == str(service['resource'])
                assert int(fields['native_input']['value']['unsigned']) > int(fields['first_occurrence']['value']['unsigned'])
                assert all(a is None or a['kind'] == 'inspect_status' for a in evidence['actions'])
                if rpc:
                    assert fields['expected_value']['availability'] == 'withheld' and fields['supplied_value']['availability'] == 'withheld'
                else:
                    assert fields['expected_value']['value']['unsigned'] == '1'
                    assert fields['supplied_value']['value']['unsigned'] == str(len(body))
                assert result['effect_diagnostic'] is None and requests == []
                outputs = deliver()
                assert len(outputs) == 1 and outputs[0]['destination'] == caller['pid']
                caller['outcome'] = bytes.fromhex(outputs[0]['value'])[13:].hex()
                caller['preparation_diagnostic'] = evidence
                child = start('http-caller', caller)
                assert action(child, 'step') == {'not_dispatched': True}
                close(child)
                child = start('http-reader', caller)
                assert action(child, 'preparation') == {'original': True}
                command({'grant_resource': {'resource': service['resource'], 'subject': caller['principal'], 'permissions': 0}})
                assert action(child, 'preparation-denied') == {'denied': True}
                command({'grant_resource': {'resource': service['resource'], 'subject': caller['principal'], 'permissions': 3}})
                own(service); worker_config.update(generation=service['generation'], mode='release')
                retired = invoke()
                assert retired['phase'] == 'retired' and retired['outcome'] == 'not_dispatched'
                assert retired['capture_diagnostic'] == evidence
                assert action(child, 'preparation') == {'original': True}
                close(child)
                assert requests == [] and not failures
                print(f'{label} {protocol.upper()} preparation failure: original field/cause after admitted-input receipt loss, corrected configuration, worker/node/store restart, current denial and retirement; no intent or external send ({time.monotonic()-started:.2f}s).', flush=True)
                return
            assert invoke()['phase'] == 'ready'
            own(service)
            worker_config.update(generation=service['generation'], mode='execute')
            if fault:
                boundary.arm('dispatch' if fault == 'retirement' else 'published')
                executing = subprocess.Popen([worker, config_file('worker', worker_config)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                children.append(executing)
                assert boundary.reached.wait(timeout=90), executing.poll()
                if fault == 'retirement':
                    close(child)
                    command({'terminate': caller['pid']})
                    replacement = command({'spawn': {}})
                    assert replacement != caller['pid']
                    boundary.close()
                    stdout, stderr = executing.communicate(timeout=120)
                    assert executing.returncode == 0, stderr[-2000:]
                    assert json.loads(stdout)['phase'] == 'complete'
                else:
                    executing.kill(); executing.communicate(timeout=10); boundary.close()
                children.remove(executing)
                # Restart the authority and its disk store after committed output,
                # before any delivery to the saved destination.
                system.authority.kill(); system.authority.wait(timeout=10)
                system.store.stop(); system.store.start()
                system.authority = system.start(system.node, system.config)
                from harness.services import wait_ready
                wait_ready(system.store.http, system.authority, system.url + '/health')
                own(service); worker_config['generation'] = service['generation']
                assert invoke()['phase'] == 'complete'
            else:
                assert invoke()['phase'] == 'complete'
            outputs = deliver()
            assert len(outputs) == 1 and outputs[0]['destination'] == caller['pid']
            if fault == 'retirement':
                item = read({'outputs': {'after': outputs[0]['id']-1, 'position': read({'capabilities': {}})['position']}})['body']['outputs']['entries'][0]
                assert item['id'] == outputs[0]['id'] and item['phase'] == 'retired'
                assert read({'process': replacement})['body']['process']['process']['admitted'] == 0
                assert read({'process': caller['pid']})['body']['process']['process']['lifecycle'] == 'terminated'
                assert requests == ['/test.Peer/Bidi'] and not failures
                # Disposal is an explicit controller decision even though the caller
                # can never acknowledge; termination alone did not retire capture.
                own(service); worker_config.update(generation=service['generation'], mode='release')
                assert invoke()['phase'] == 'retired'
                print(f'{label} RPC caller retirement: one authorized send, recorded destination retained across node/store restart, replacement untouched, explicit cleanup passed ({time.monotonic()-started:.2f}s).')
                return
            caller['outcome'] = bytes.fromhex(outputs[0]['value'])[13:].hex()
            assert action(child, 'step') == {'observed': True}
            close(child)
            credential.unlink()
            # Native effect evidence has its own process-inspection boundary.
            # The ordinary caller grant is scoped to its own PID; this reader
            # receives an explicit inspection scope spanning the connector PID.
            command({'grant': {'subject': caller['principal'], 'public_key': public_keys[caller['principal']],
                'permissions': 88, 'pid': None}})
            command({'grant_resource': {'resource': caller['resource'], 'subject': caller['principal'], 'permissions': 7}})
            command({'grant_resource': {'resource': service['resource'], 'subject': caller['principal'], 'permissions': 3}})
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
            command({'grant': {'subject': caller['principal'], 'public_key': public_keys[caller['principal']],
                'permissions': 88, 'pid': caller['pid']}})
            command({'grant_resource': {'resource': caller['resource'], 'subject': caller['principal'], 'permissions': 7}})
            command({'grant_resource': {'resource': service['resource'], 'subject': caller['principal'], 'permissions': 3}})
            if public_followup:
                # A public typed helper records an ordinary correlated call;
                # the service refuses unsupported followups without allocating
                # a child or obtaining credentials. Positive retry dispatch is
                # independently qualified by the shared Zig worker schedule.
                for reason in (('retry',) if rpc else ('retry', 'redirect', 'reconcile', 'cancel')):
                    caller['followup_reason'] = reason
                    child = start('http-caller', caller)
                    command({'send': {'pid': caller['pid'], 'value': frame(b'followup')}})
                    assert action(child, 'step') == {'followup': False}
                    outputs = deliver()
                    assert len(outputs) == 1 and outputs[0]['destination'] == service['pid']
                    wire = bytes.fromhex(outputs[0]['value'])[13:]
                    assert len(wire) == (166 if rpc else 133) and wire[:4] == (b'GRU1' if rpc else b'HTU1')
                    assert int.from_bytes(wire[12:20], 'little') == 2**64-1
                    assert wire[20] == ('retry', 'redirect', 'reconcile', 'cancel').index(reason) + 1
                    own(service)
                    worker_config.update(generation=service['generation'], mode='poll',
                        exchange=2**64-2, followup={'parent': 2**64-1, 'reason': reason})
                    result = invoke()
                    assert result['phase'] == 'not_admitted' and result['outcome'] == 'not_committed'
                    # An accept activation must preserve the admission failure
                    # instead of inspecting nonexistent child capture evidence.
                    own(service)
                    worker_config.update(generation=service['generation'], mode='accept')
                    refused = subprocess.run([worker, config_file('worker', worker_config)],
                                             capture_output=True, timeout=30)
                    missing_call = b'MissingGrpcCall' if rpc else b'MissingHttpCall'
                    assert refused.returncode != 0 and missing_call in refused.stderr, refused
                    assert b'ExchangeNotFound' not in refused.stderr and not refused.stdout, refused
                    outputs = deliver()
                    assert len(outputs) == 1 and outputs[0]['destination'] == caller['pid']
                    import hashlib
                    rejection = bytes.fromhex(outputs[0]['value'])[13:]
                    assert len(rejection) == 232 and rejection[:5] == (b'GRF1' if rpc else b'HTF1') + b'\x01'
                    assert int.from_bytes(rejection[6:14], 'little') > 0
                    assert rejection[14:46] == hashlib.sha256(wire).digest()
                    field = rejection[48:48 + rejection[46]].decode()
                    if reason != 'redirect':
                        assert rejection[5] == 6 and field == 'parent.disposition'
                        assert rejection[157:157 + rejection[155]] == b'closed_unknown'
                        assert rejection[200:200 + rejection[198]] == b'observed'
                    else:
                        assert rejection[80] > 0 and field == 'policy.redirect'
                    assert action(child, 'step') == {'followup': True}
                    close(child)
                worker_config['exchange'] = 2**64-1
                worker_config.pop('followup')
            if public_release:
                # A durable disposal call needs no transcript read grant and
                # can recover an acknowledgement after explicit capture cleanup.
                command({'grant_resource': {'resource': service['resource'], 'subject': caller['principal'], 'permissions': 0}})
                child = start('http-caller', caller)
                for attempt in range(2):
                    command({'send': {'pid': caller['pid'], 'value': frame(b'dispose')}})
                    assert action(child, 'step') == {'released': False}
                    outputs = deliver()
                    assert len(outputs) == 1 and outputs[0]['destination'] == service['pid']
                    own(service)
                    worker_config.update(generation=service['generation'], mode='poll')
                    assert invoke()['phase'] == ('complete' if attempt == 0 else 'retired')
                    outputs = deliver()
                    assert len(outputs) == 1 and outputs[0]['destination'] == caller['pid']
                    assert action(child, 'step') == {'released': True}
                    if attempt == 0:
                        own(service)
                        worker_config.update(generation=service['generation'], mode='release')
                        assert invoke()['phase'] == 'retired'
                close(child)
            assert not failures, failures
            assert requests == (['/test.Peer/Bidi'] if rpc else ['/items/%CE%BB%20%2F']), requests
            disposal = ', authenticated durable disposal before/after cleanup without read permission' if public_release else ''
            followups = ', typed followup calls with authenticated policy rejection and no child/send' if public_followup else ''
            print(f'{label} {protocol.upper()} SDK {fault or "ordinary"}: installed caller, staged host recovery, wide identity, binary TLS, correlated outcome, revoked prefix, owned replay without credentials and joined local stop/disposal{disposal}{followups} passed ({time.monotonic()-started:.2f}s).')
        finally:
            boundary.close()
            for child in children:
                child.kill(); child.wait(timeout=10)
            native.lib.transit_client_destroy(admin)
            for server in (peer, proxy): server.shutdown(); server.server_close()
            for thread in threads: thread.join(timeout=5)

"""Independent signed HTTP peers against real Station workers and disk authority."""
import argparse
import concurrent.futures
from contextlib import ExitStack
import hashlib
from http.client import HTTPConnection, HTTPSConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import threading
import time

from storage import Fixture, free_port, wait_ready

REALM = 49
TLS = {}


def compact(value):
    return json.dumps(value, separators=(',', ':'), ensure_ascii=False).encode()


class Key:
    def __init__(self, directory, name, seed):
        self.path = directory / (name + '.der')
        self.path.write_bytes(bytes.fromhex('302e020100300506032b657004220420') + bytes([seed]) * 32)
        self.path.chmod(0o600)
        self.seed = directory / (name + '.seed')
        self.seed.write_text((bytes([seed]) * 32).hex())
        self.seed.chmod(0o600)
        self.public = list(subprocess.check_output(['openssl', 'pkey', '-inform', 'DER', '-in', str(self.path), '-pubout', '-outform', 'DER'])[-32:])

    def sign(self, data):
        with tempfile.NamedTemporaryFile(dir=self.path.parent) as message:
            message.write(data)
            message.flush()
            return list(subprocess.check_output(['openssl', 'pkeyutl', '-sign', '-rawin', '-inkey', str(self.path), '-keyform', 'DER', '-in', message.name]))


def native_query(key, principal, kind):
    query = dict(version=3, realm=REALM, principal=principal, kind=kind)
    return dict(query=query, signature=key.sign(hashlib.sha256(b'transit.query.v3\0' + compact(query)).digest()))


def native_command(key, principal, sequence, command):
    request = dict(version=3, realm=REALM, principal=principal, sequence=sequence, command=command)
    return dict(request=request, signature=key.sign(hashlib.sha256(b'transit.request.v3\0' + compact(request)).digest()))


def frame(payload, kind=1, correlation=0):
    return (b'STN1' + bytes([kind]) + struct.pack('<Q', correlation) + payload).hex()


def submit(operation, deadline, delta=1, revision=1):
    value = struct.pack('<qq', 1, delta)
    return b'SV1c\x03' + struct.pack('<QQHQB', operation, revision, 1, deadline, len(value)) + value


def publication(revision, target, deadline, published=True):
    return b'SV1c\x01' + struct.pack('<QQQHBQ?', revision - 1, revision, target, 1, 2, deadline, published)


def policy(principal, revision=1, commands=True, reads=True, limit=1):
    return b'SV1c\x02' + struct.pack('<QQQ??B', principal, revision - 1, revision, commands, reads, limit)


def signed_read(key, principal, ingress, kind, operation=0):
    read = dict(realm=REALM, principal=principal, service=1, ingress=ingress, kind=kind, operation=operation)
    encoded = b'SV1r' + struct.pack('<QQQQBQ', REALM, principal, 1, ingress, {'discovery': 1, 'status': 2, 'result': 3, 'disposition': 4}[kind], operation)
    return dict(read=read, signature=key.sign(hashlib.sha256(b'transit.serving.read.v1\0' + encoded).digest()), identity=native_query(key, principal, {'identity': {}}))


def post(port, path, value, host=None, status=200, headers=None):
    connection = HTTPSConnection('127.0.0.1', TLS[port].port, context=TLS[port].context, timeout=10) if port in TLS else HTTPConnection('127.0.0.1', port, timeout=10)
    try:
        request_headers = {'Content-Type': 'application/json'}
        if host:
            request_headers['Host'] = host
        request_headers.update(headers or {})
        connection.request('POST', path, compact(value), request_headers)
        response = connection.getresponse()
        body = response.read()
        if status is None:
            return response.status, json.loads(body)
        assert response.status == status, (path, response.status, body, status)
        return json.loads(body)
    finally:
        connection.close()


def run(node, example, courier, tls=False, capacity=False):
    node, example, courier = [str(Path(path).resolve()) for path in (node, example, courier)]
    started = time.monotonic()
    with Fixture() as store, ExitStack() as owned:
        keys = {p: Key(store.root, f'key-{p}', seed) for p, seed in ((0, 7), (33, 8), (34, 9), (65536, 10), (65537, 11), (77, 12), (78, 13), (79, 14), (80, 15))}
        sequences = dict.fromkeys(keys, 0)
        port = free_port()
        url = f'http://127.0.0.1:{port}'
        configuration = store.root / 'node.json'
        configuration.write_text(json.dumps(dict(profile='growing_v3', genesis=dict(realm=REALM, root_key=keys[0].public, max_clock_error_ms=10000), ursula_url=store.url, bucket='serving', journal='authority', port=port, resident_pages=8, request_timeout_ms=10000)))
        children, logs = [], []

        def start(name, executable, config):
            path = store.root / (name + '.json')
            path.write_text(json.dumps(config))
            log = (store.root / (name + '.log')).open('w+')
            logs.append(log)
            process = subprocess.Popen([executable, str(path)], stdout=log, stderr=subprocess.STDOUT, env=store.env)
            children.append(process)
            return process

        def query(principal, kind):
            return post(port, '/v3/query', native_query(keys[principal], principal, kind))

        def send(command, principal=0):
            message = native_command(keys[principal], principal, sequences[principal] + 1, command)
            receipt = post(port, '/v3/command', message)
            sequences[principal] += 1
            return receipt['position']

        def cast(pid, payload, principal=33):
            return send({'send': dict(pid=pid, value=frame(payload))}, principal)

        def grant(principal, permissions, pid=None):
            return send({'grant': dict(subject=principal, public_key=keys[principal].public, permissions=permissions, pid=pid)})

        def resource_grant(resource, principal, permissions):
            send({'grant_resource': dict(resource=resource, subject=principal, permissions=permissions)})

        def provision(principal):
            pid = send({'spawn': dict(code=1, work_before_ms=None, settle_before_ms=None)})
            grant(principal, 88, pid)
            resource = send({'create_resource': dict(writer=pid, owned=True, deadline_ms=None)})
            for subject in (0, principal):
                resource_grant(resource, subject, 7)
            send({'associate': dict(pid=pid, name=b'state'.hex(), expected_revision=0, resource=resource, required=True)})
            send({'own': dict(pid=pid, expected_generation=1, worker=principal)})
            return pid, resource

        def drained(pid, timeout=30):
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                value = query(0, {'process': pid})['body']['process']
                assert value['process']['failure'] is None, value
                if value['input'] is None:
                    return
                time.sleep(.03)
            raise AssertionError(('undrained', pid, value))

        fault = {'armed': False, 'lost': None, 'retried': False, 'stall_reads': False, 'blocked': 0}
        fault_lock = threading.Lock()
        release_reads = threading.Event()

        class FaultProxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                message = json.loads(body)
                if self.path == '/v3/query' and message['query']['principal'] == 79 and 'resource' in message['query']['kind'] and fault['stall_reads']:
                    with fault_lock:
                        fault['blocked'] += 1
                    release_reads.wait(timeout=4)
                connection = HTTPConnection('127.0.0.1', port, timeout=10)
                try:
                    connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    result = response.read()
                    message = json.loads(body)
                    if self.path == '/v3/command' and message['request']['principal'] == 65536 and response.status == 200:
                        if fault['armed']:
                            fault['armed'] = False
                            fault['lost'] = body, result
                            self.close_connection = True
                            return
                        if fault['lost'] and body == fault['lost'][0]:
                            assert result == fault['lost'][1]
                            fault['retried'] = True
                    self.send_response(response.status)
                    self.send_header('Content-Length', str(len(result)))
                    self.end_headers()
                    self.wfile.write(result)
                except (BrokenPipeError, ConnectionResetError):
                    pass
                finally:
                    connection.close()

        proxy = ThreadingHTTPServer(('127.0.0.1', 0), FaultProxy)
        proxy.daemon_threads = True
        threading.Thread(target=proxy.serve_forever, daemon=True).start()
        try:
            subprocess.run([node, str(configuration), '--initialize'], check=True, capture_output=True, env=store.env, timeout=30)
            authority = start('node-live', node, json.loads(configuration.read_text()))
            wait_ready(store.http, authority, url + '/health')
            ingress, ingress_resource = provision(77)
            application, application_resource = provision(78)
            for principal in (33, 34): grant(principal, 20)
            grant(79, 16, ingress)
            resource_grant(ingress_resource, 79, 3)
            grant(80, 148)
            ingress_config = dict(url=url, realm=REALM, principal=77, seed_file=str(keys[77].seed), pid=ingress, generation=2, activation_directory=str(store.root), role={'ingress': dict(service=1, administrator=33, observer=34)})
            application_config = dict(url=url, realm=REALM, principal=78, seed_file=str(keys[78].seed), pid=application, generation=2, activation_directory=str(store.root), role={'application': dict(ingress=ingress, initializer=33)})
            ingress_worker = start('ingress', example, ingress_config)
            app_worker = start('application', example, application_config)
            cast(ingress, b'SV1c\x00')
            cast(application, b'')
            drained(ingress)
            drained(application)
            deadline_ms = int(time.time() * 1000) + 600000
            cast(ingress, publication(1, application, deadline_ms))
            for principal in (65536, 65537): cast(ingress, policy(principal))
            drained(ingress)
            # Initialize privately before exposing any untrusted native ingress.
            for principal in (65536, 65537): grant(principal, 20, ingress)
            courier_config = dict(url=url, realm=REALM, principal=80, seed_file=str(keys[80].seed), role={'courier': dict(destinations=[ingress, application])})
            courier_worker = start('courier', courier, courier_config)
            gateway_ports = [free_port(), free_port()]
            public_host = 'serving.example.test'
            gateway_config = dict(url=f'http://127.0.0.1:{proxy.server_port}', realm=REALM, principal=79, seed_file=str(keys[79].seed), role={'gateway': dict(service=1, ingress=ingress, resource=ingress_resource, port=gateway_ports[0], host=public_host, public_origin='https://' + public_host, callers=[dict(principal=p, public_key=keys[p].public) for p in (65536, 65537)])})
            gateways = []
            for index, gateway_port in enumerate(gateway_ports):
                gateway_config['role']['gateway']['port'] = gateway_port
                gateways.append(start(f'gateway-{index}', example, gateway_config))
                if tls:
                    from serving_tls import TLSProxy
                    TLS[gateway_port] = owned.enter_context(TLSProxy(store.root / f'tls-{index}', gateway_port))
            time.sleep(.4)

            def read(kind, operation=0, principal=65536, expected=200):
                return post(gateway_ports[0], '/serving/v1/read', signed_read(keys[principal], principal, ingress, kind, operation), public_host, expected)

            discovery = read('discovery')
            assert discovery['binding']['revision'] == 1 and not discovery['capabilities']['websocket'], discovery
            if tls:
                probe = signed_read(keys[65536], 65536, ingress, 'discovery')
                post(gateway_ports[0], '/serving/v1/read', probe, 'foreign.example.test', 403)
                post(gateway_ports[0], '/serving/v1/read', probe, public_host, 403, {'Origin': 'https://foreign.example.test'})
            frozen = native_command(keys[65536], 65536, 1, {'send': dict(pid=ingress, value=frame(submit(1, deadline_ms)))})
            fault['armed'] = True
            post(gateway_ports[0], '/serving/v1/command', frozen, public_host, 503)
            assert fault['lost']
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                receipts = list(pool.map(lambda p: post(p, '/serving/v1/command', frozen, public_host, 202), gateway_ports))
            assert receipts[0] == receipts[1] and receipts[0]['stage'] == 'ingress_accepted' and fault['retried'], receipts
            sequences[65536] = 1

            def completed(operation, expected):
                until = time.monotonic() + 45
                while time.monotonic() < until:
                    try:
                        status = read('status', operation)
                    except AssertionError as error:
                        if error.args[0][1] in (404, 409):
                            time.sleep(.03)
                            continue
                        raise
                    if status['stage'] == 'completed':
                        value = read('result', operation)
                        assert struct.unpack('<q', bytes.fromhex(value['operation']['result']))[0] == expected, value
                        return value
                    time.sleep(.03)
                raise AssertionError(('incomplete', operation, status))

            first = completed(1, 1)
            if capacity:
                probe = signed_read(keys[65536], 65536, ingress, 'status', 1)
                fault['stall_reads'] = True
                with concurrent.futures.ThreadPoolExecutor(max_workers=8) as readers:
                    pending = [readers.submit(post, gateway_port, '/serving/v1/read', probe, public_host) for gateway_port in gateway_ports for _ in range(4)]
                    try:
                        until = time.monotonic() + 2
                        while fault['blocked'] < 8 and time.monotonic() < until:
                            time.sleep(.005)
                        assert fault['blocked'] == 8, fault
                        rss = sum(int(next(line for line in Path(f'/proc/{worker.pid}/status').read_text().splitlines() if line.startswith('VmRSS:')).split()[1]) * 1024 for worker in gateways)
                        assert rss <= 256 * 1024 * 1024, ('aggregate gateway RSS exceeded declared qualification ceiling', rss)
                        response = post(gateway_ports[0], '/serving/v1/read', probe, public_host, 503)
                        assert response['err'] == 'HttpCapacity', response
                        health_started = time.monotonic()
                        health = HTTPSConnection('127.0.0.1', TLS[gateway_ports[0]].port, context=TLS[gateway_ports[0]].context, timeout=1) if tls else HTTPConnection('127.0.0.1', gateway_ports[0], timeout=1)
                        try:
                            health.request('GET', '/health', headers={'Host': public_host})
                            status = health.getresponse()
                            assert status.status == 200 and json.loads(status.read())['ready']
                        finally:
                            health.close()
                        elapsed = time.monotonic() - health_started
                        assert elapsed < 1, elapsed
                    finally:
                        fault['stall_reads'] = False
                        release_reads.set()
                    assert all(item.result()['operation'] == first['operation'] for item in pending)
                print(f'Serving capacity: eight delayed authorized reads, ninth refused, health {elapsed:.3f}s; two-gateway RSS {rss} bytes <= 268435456 ceiling; private 2 MiB request buffers', flush=True)
            # Same operation with a later native sequence still has one destination call.
            duplicate = native_command(keys[65536], 65536, 2, frozen['request']['command'])
            post(gateway_ports[1], '/serving/v1/command', duplicate, public_host, 202)
            sequences[65536] = 2
            drained(ingress)
            assert completed(1, 1)['operation'] == first['operation']
            conflict = native_command(keys[65536], 65536, 3, {'send': dict(pid=ingress, value=frame(submit(1, deadline_ms, delta=9)))})
            receipt = post(gateway_ports[0], '/serving/v1/command', conflict, public_host, 202)
            sequences[65536] = 3
            drained(ingress)
            assert bytes.fromhex(read('disposition', receipt['receipt']['position'])['disposition']) == b'ServingIdentityConflict'
            read('status', 1, principal=65537, expected=404)
            forged = signed_read(keys[65536], 65536, ingress, 'status', 1)
            forged['read']['principal'] = 65537
            post(gateway_ports[0], '/serving/v1/read', forged, public_host, 403)
            post(gateway_ports[0], '/serving/v1/read', signed_read(keys[65536], 65536, ingress, 'status', 1), public_host, 403, {'X-Transit-Principal': '65537'})
            # Different requests racing one native sequence cannot both publish.
            competitors = [native_command(keys[65536], 65536, 4, {'send': dict(pid=ingress, value=frame(submit(operation, deadline_ms)))}) for operation in (3, 4)]
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                races = list(pool.map(lambda item: post(item[0], '/serving/v1/command', item[1], public_host, None), zip(gateway_ports, competitors)))
            assert sorted(result[0] for result in races) == [202, 409], races
            sequences[65536] = 4
            winner = 3 + next(index for index, result in enumerate(races) if result[0] == 202)
            completed(winner, 2)
            # Growing receipts remain retained across newer native sequences.
            # Old bytes recover their receipt without becoming a fresh input.
            assert post(gateway_ports[0], '/serving/v1/command', frozen, public_host, 202) == receipts[0]
            completed(1, 1)
            print('Serving: independent codecs, scope authentication, two-gateway exact retry and once-only application update passed', flush=True)

            # Direct native callers cannot poison framework frame preprocessing.
            malformed = send({'send': dict(pid=ingress, value=b'bad-frame'.hex())}, 65536)
            drained(ingress)
            assert bytes.fromhex(read('disposition', malformed)['disposition']) == b'InvalidServingFrame'
            second_request = native_command(keys[65536], 65536, sequences[65536] + 1, {'send': dict(pid=ingress, value=frame(submit(2, deadline_ms)))})
            # Stop delivery so the admission commits before physical loss.
            courier_worker.kill(); courier_worker.wait(timeout=10)
            post(gateway_ports[0], '/serving/v1/command', second_request, public_host, 202)
            sequences[65536] += 1
            drained(ingress)
            assert read('status', 2)['stage'] == 'service_admitted'
            correlation = read('status', 2)['operation']['correlation']
            premature = send({'send': dict(pid=ingress, value=frame(b'TMO1' + struct.pack('<Q', deadline_ms - 1), 8, correlation))}, 34)
            spoofed = send({'send': dict(pid=ingress, value=frame(b'forged', 3, correlation))}, 65536)
            drained(ingress)
            assert read('status', 2)['stage'] == 'service_admitted'
            # This caller sees only its own disposition, not the observer's.
            assert read('disposition', premature)['disposition'] is None
            assert bytes.fromhex(read('disposition', spoofed)['disposition']) == b'UnexpectedServingReplySource'
            for process in (*gateways, ingress_worker, app_worker, authority):
                process.kill(); process.wait(timeout=10)
            store.stop(); store.start()
            authority = start('node-recovered', node, json.loads(configuration.read_text()))
            wait_ready(store.http, authority, url + '/health')
            for config in (ingress_config, application_config):
                send({'own': dict(pid=config['pid'], expected_generation=2, worker=config['principal'])})
                config['generation'] = 3
            ingress_worker = start('ingress-recovered', example, ingress_config)
            app_worker = start('application-recovered', example, application_config)
            courier_worker = start('courier-recovered', courier, courier_config)
            gateway_config['role']['gateway']['port'] = gateway_ports[0]
            gateways[0] = start('gateway-recovered', example, gateway_config)
            time.sleep(.4)
            # Later native sequences do not erase this retained receipt.
            post(gateway_ports[0], '/serving/v1/command', second_request, public_host, 202)
            completed(2, 3)
            completed(1, 1)
            cast(ingress, publication(2, application, deadline_ms, False))
            drained(ingress)
            completed(2, 3)
            cast(ingress, policy(65536, revision=2, reads=False))
            drained(ingress)
            read('result', 2, expected=403)
            cast(ingress, policy(65536, revision=3))
            drained(ingress)
            completed(2, 3)
            send({'revoke': 65536})
            read('result', 2, expected=403)
            print(f'Serving: worker/gateway/node/disk recovery, route retirement and current policy/native revocation passed in {time.monotonic() - started:.2f}s; 8 resident authority pages', flush=True)
            if tls:
                print('Serving TLS: real nginx template, verified certificates/hostnames, exact Host/Origin and signed recovery passed; ' + subprocess.check_output(['nginx', '-v'], stderr=subprocess.STDOUT, text=True).strip(), flush=True)
        finally:
            proxy.shutdown(); proxy.server_close()
            for child in reversed(children):
                if child.poll() is None: child.kill()
                child.wait(timeout=10)
            for log in logs:
                if sys.exc_info()[0]:
                    log.seek(0); print(log.read()[-8000:], file=sys.stderr)
                log.close()
            TLS.clear()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for name in ('node', 'example', 'courier'):
        parser.add_argument(name)
    parser.add_argument('--tls', action='store_true')
    parser.add_argument('--capacity', action='store_true')
    run(**vars(parser.parse_args()))

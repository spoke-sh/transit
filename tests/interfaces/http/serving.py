"""Independent signed HTTP peers against real Station workers and disk authority."""
import argparse
import concurrent.futures
from contextlib import ExitStack, nullcontext
import hashlib
from http.client import HTTPConnection, HTTPSConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
from types import SimpleNamespace

from harness.services import free_port, wait_ready
from interfaces.http.serving_table import authorize, bootstrap as bootstrap_counter, populate_query_rows, provision_catalog

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
    query = dict(version=1, definition='9ccbb15686fea6ace7f101548f0957d9847446c09353f098543b2c20361b2fef', realm=REALM, principal=principal, kind=kind)
    return dict(query=query, signature=key.sign(hashlib.sha256(b'transit.query.v1\0' + compact(query)).digest()))


def native_command(key, principal, sequence, command):
    if 'send' in command:
        command['send'].setdefault('role', None)
    request = dict(version=1, definition='9ccbb15686fea6ace7f101548f0957d9847446c09353f098543b2c20361b2fef', realm=REALM, principal=principal, sequence=sequence, command=command)
    return dict(request=request, signature=key.sign(hashlib.sha256(b'transit.request.v1\0' + compact(request)).digest()))


def frame(payload, kind=1, correlation=0):
    return (b'STN1' + bytes([kind]) + struct.pack('<Q', correlation) + payload).hex()


def submit(operation, deadline, delta=1, revision=1, row=1):
    value = struct.pack('<qq', row, delta)
    return b'SV1c\x03' + struct.pack('<QQHQB', operation, revision, 1, deadline, len(value)) + value


def publication(revision, target, deadline, published=True):
    return b'SV1c\x01' + struct.pack('<QQQHBQ?', revision - 1, revision, target, 1, 2, deadline, published)


def policy(principal, revision=1, commands=True, reads=True, limit=1):
    return b'SV1c\x02' + struct.pack('<QQQ??B', principal, revision - 1, revision, commands, reads, limit)


def subject_proof(key, principal, ingress, context, credential_epoch=None, role=None, realm=REALM):
    if credential_epoch is None:
        observation = key.authority_query(native_query(key, principal, {'authorization': {'role': role, 'kind': {'identity': {}}}}))
        credential_epoch = observation['body']['authorization']['body']['identity']['credential_epoch']
    claim = dict(definition='9ccbb15686fea6ace7f101548f0957d9847446c09353f098543b2c20361b2fef', realm=realm, principal=principal, credential_epoch=credential_epoch, role=role, audience=ingress, context=list(context))
    return dict(claim=claim, signature=key.sign(hashlib.sha256(b'transit.authorization.subject.v1\0' + compact(claim)).digest()))


def signed_read(key, principal, ingress, kind, operation=0):
    read = dict(realm=REALM, principal=principal, service=1, ingress=ingress, kind=kind, operation=operation)
    encoded = b'SV1r' + struct.pack('<QQQQBQ', REALM, principal, 1, ingress, {'discovery': 1, 'status': 2, 'result': 3, 'disposition': 4}[kind], operation)
    return dict(read=read, proof=subject_proof(key, principal, ingress, hashlib.sha256(b'transit.serving.read.v1\0' + encoded).digest()))


def post(port, path, value, host=None, status=200, headers=None):
    encoded = compact(value)
    request_headers = {'Content-Type': 'application/json'}
    if host:
        request_headers['Host'] = host
    request_headers.update(headers or {})
    deadline, retries = time.monotonic() + 10, 0
    while True:
        connection = HTTPSConnection('127.0.0.1', TLS[port].port, context=TLS[port].context, timeout=10) if port in TLS else HTTPConnection('127.0.0.1', port, timeout=10)
        try:
            connection.request('POST', path, encoded, request_headers)
            response = connection.getresponse()
            body = response.read()
            actual = response.status
        finally:
            connection.close()
        decoded = json.loads(body)
        # Cold recovery can temporarily exhaust authority request admission.
        # Retry the same signed command or current-credential read, never a new sequence.
        # Explicit rejection/fault assertions (status=None/503) remain visible.
        serving_capacity = actual == 503 and status == 202 and any(fact and fact['field'] == 'native_cause' and fact['value'] == {'text': 'HttpCapacity'}
                       for fact in (decoded.get('diagnostic') or {}).get('facts', []))
        credential_read = (path == '/v1/query' and set(value['query']['kind']) == {'authorization'}
                           and value['query']['kind']['authorization']['kind'] == {'identity': {}})
        native_capacity = (path == '/v1/command' or credential_read) and status == 200 and actual == 503 and decoded == {'err': 'HttpCapacity'}
        native_contention = path in ('/v1/query', '/v1/command') and status == 200 and actual == 409 and decoded == {'err': 'Conflict'}
        if (native_capacity or native_contention or (path == '/serving/v1/command' and serving_capacity)) and time.monotonic() < deadline:
            retries += 1
            time.sleep(.05)
            continue
        if retries:
            print(f'Serving exact request: {retries} temporary native capacity/contention responses before status {actual}', flush=True)
        if status is None:
            return actual, decoded
        assert actual == status, (path, actual, body, status)
        return decoded


def run(node, example, courier, host, tls=False, capacity=False, lifetimes=False, growth=False, reactive=False, reactive_browser=False, reactive_limits=False, reactive_client=False, reactive_refresh=False, reactive_views=False, reactive_views_lifecycle=False, board=None):
    reactive_views = reactive_views or reactive_views_lifecycle
    if (reactive_browser or reactive_limits or reactive_client or reactive_refresh or reactive_views) and not (reactive and tls):
        raise ValueError("reactive browser/limits proofs require --reactive --tls")
    live_profile = reactive_refresh or reactive_views
    node, example, courier, host = [str(Path(path).resolve()) for path in (node, example, courier, host)]
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix='transit-serving-') as directory, ExitStack() as owned:
        store = SimpleNamespace(root=Path(directory), env={k: v for k, v in os.environ.items() if not k.startswith('OTEL_')},
            http=urllib.request.build_opener(urllib.request.ProxyHandler({})))
        keys = {p: Key(store.root, f'key-{p}', seed) for p, seed in ((0, 7), (33, 8), (34, 9), (65536, 10), (65537, 11), (77, 12), (177, 12), (78, 13), (79, 14), (80, 15))}
        sequences = dict.fromkeys(keys, 0)
        port = free_port()
        for key in keys.values(): key.authority_query = lambda message: post(port, '/v1/query', message)
        url = f'http://127.0.0.1:{port}'
        configuration = store.root / 'node.json'
        configuration.write_text(json.dumps(dict(profile='native_v1', genesis=dict(realm=REALM, root_key=keys[0].public, max_clock_error_ms=10000, admission_ceiling=50000, control_reserve=2000), local_directory=str(store.root / 'native'), port=port, resident_pages=8, request_timeout_ms=10000)))
        children, logs = [], []

        def start(name, executable, config):
            if name == 'clock-observer': fault['clock_contention_armed'] = True
            path = store.root / (name + '.json')
            path.write_text(json.dumps(config))
            log = (store.root / (name + '.log')).open('w+')
            logs.append(log)
            process = subprocess.Popen([executable, str(path)], stdout=log, stderr=subprocess.STDOUT, env=store.env)
            children.append(process)
            return process

        def query(principal, kind):
            deadline = time.monotonic() + 10
            while True:
                status, response = post(port, '/v1/query', native_query(keys[principal], principal, kind), status=None)
                if status == 503 and response == {'err': 'HttpCapacity'} and time.monotonic() < deadline:
                    time.sleep(.05)
                    continue
                assert status == 200, ('/v1/query', status, response)
                return response

        def send(command, principal=0):
            message = native_command(keys[principal], principal, sequences[principal] + 1, command)
            receipt = post(port, '/v1/command', message)
            sequences[principal] += 1
            return receipt['position']

        def cast(pid, payload, principal=33):
            return send({'send': dict(pid=pid, value=frame(payload))}, principal)

        def grant(principal, permissions, pid=None):
            return send({'grant': dict(subject=principal, public_key=keys[principal].public, permissions=permissions, pid=pid)})

        def resource_grant(resource, principal, permissions):
            send({'grant_resource': dict(resource=resource, subject=principal, permissions=permissions)})

        def provision(principal, resource_deadline=None, work_before=None, activate=True):
            pid = send({'spawn': dict(allow_collection=False, code=1, work_before_ms=work_before, settle_before_ms=resource_deadline if work_before else None)})
            grant(principal, 88, pid)
            resource = send({'create_resource': dict(writer=pid, owned=True, deadline_ms=resource_deadline, history_ms=None)})
            for subject in (0, principal):
                resource_grant(resource, subject, 7)
            send({'associate': dict(pid=pid, name=b'state'.hex(), expected_revision=0, resource=resource, required=True)})
            if activate:
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

        fault = {'armed': False, 'lost': None, 'retried': False, 'stall_reads': False, 'serialize_upstream': False, 'blocked': 0,
                 'ingress_commit': None, 'application_commit': None, 'destination_delivery': None,
                 'reply_delivery': None, 'data_commit': None, 'data_inspected': False, 'deliveries_armed': False, 'delivery_ids': {}, 'commit_retries': set(),
                 'contention_requests': {}, 'contention_retried': set(), 'clock_contention_armed': False}
        fault_lock = threading.Lock()
        upstream_lock = threading.Lock()
        release_reads = threading.Event()

        class FaultProxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                message = json.loads(body)
                native = message.get('request') if self.path == '/v1/command' else None
                contended = native and ((native['principal'] == 77 and 'open_view' in native['command']) or
                                        (native['principal'] == 34 and fault['clock_contention_armed'] and 'send' in native['command']))
                if reactive_views and contended:
                    principal = native['principal']
                    with fault_lock:
                        reject = principal not in fault['contention_requests']
                        if reject:
                            fault['contention_requests'][principal] = body
                        elif body == fault['contention_requests'][principal]:
                            fault['contention_retried'].add(principal)
                    if reject:
                        # Model exhausted ordinary CAS reprepare before this
                        # exact command is dispatched. Never substitute a new
                        # request sequence or clock-bound view on recovery.
                        result = b'{"err":"Conflict"}'
                        self.send_response(409)
                        self.send_header('Content-Length', str(len(result)))
                        self.end_headers()
                        self.wfile.write(result)
                        return
                connection = HTTPConnection('127.0.0.1', port, timeout=10)
                try:
                    # This schedule fills gateway work after authorization. Keep
                    # its upstream exchanges sequential while the fault is armed
                    # so the node's separate admission limit is not the bottleneck.
                    with upstream_lock if fault['serialize_upstream'] else nullcontext():
                        connection.request('POST', self.path, body, {'Content-Type': 'application/json', 'Connection': 'close'})
                        response = connection.getresponse()
                        result = response.read()
                        connection.close()
                    if response.status == 200 and self.path == '/v1/query' and message['query']['principal'] == 79 and 'read_entries' in message['query']['kind'] and fault['stall_reads']:
                        # Delay the authorized reply after releasing the upstream
                        # connection. This fills gateway work, not the node's
                        # independent bounded keep-alive socket pool.
                        connection.close()
                        with fault_lock:
                            fault['blocked'] += 1
                        release_reads.wait(timeout=4)
                    message = json.loads(body)
                    if self.path == '/table/v1' and response.status == 200:
                        operation = message['action'].get('operation')
                        rows = json.loads(result)['result'].get('rows', {})
                        if operation and 'committed' in rows:
                            if operation['command'] == 'execute' and fault['data_commit'] is None:
                                fault['data_commit'] = operation['binding'], rows['committed']
                                self.close_connection = True
                                return
                            if operation['command'] == 'inspect' and fault['data_commit'] and operation['binding'] == fault['data_commit'][0]:
                                assert rows['committed'] == fault['data_commit'][1]
                                fault['data_inspected'] = True
                    if fault['deliveries_armed'] and self.path == '/v1/query' and response.status == 200 and message['query']['principal'] == 80 and 'outputs' in message['query']['kind']:
                        for entry in json.loads(result)['body']['outputs']['entries']:
                            if entry is None: continue
                            value = bytes.fromhex(entry['value'])
                            candidate = ('destination_delivery' if entry['destination'] == application and value[:5] == b'STN1\x02' and value[13:17] == b'SV1i'
                                         else 'reply_delivery' if entry['source'] == application and entry['destination'] == ingress and value[:5] == b'STN1\x03' else None)
                            if candidate and candidate not in fault['delivery_ids']:
                                fault['delivery_ids'][candidate] = entry['id']
                    if self.path == '/v1/command' and response.status == 200:
                        request = message['request']
                        turn = request['command'].get('turn', request['command'].get('turn_with_versions', {}).get('turn', {}))
                        admission = request['principal'] == 77 and any(mutation and bytes.fromhex(mutation['key']).startswith(b'\x00sv1o') for mutation in turn.get('mutations', []))
                        application_reply = request['principal'] == 78 and any(output and bytes.fromhex(output['value'])[:5] == b'STN1\x03' for output in turn.get('outputs', []))
                        stage = 'ingress_commit' if admission else 'application_commit' if application_reply else None
                        if fault['deliveries_armed'] and request['principal'] == 80 and 'deliver' in request['command']:
                            for candidate in ('destination_delivery', 'reply_delivery'):
                                if request['command']['deliver'] == fault['delivery_ids'].get(candidate):
                                    stage = candidate
                                    break
                        if stage:
                            if fault[stage] is None:
                                fault[stage] = body, result
                                self.close_connection = True
                                return
                            if body == fault[stage][0]:
                                assert result == fault[stage][1]
                                fault['commit_retries'].add(stage)
                    if self.path == '/v1/command' and message['request']['principal'] == 65536 and response.status == 200:
                        if fault['armed']:
                            fault['armed'] = False
                            fault['lost'] = body, result
                            if capacity: time.sleep(3.5)  # acceptance precedes the gateway's 3s upstream deadline
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
            ingress, ingress_resource = provision(77, activate=not live_profile)
            application, application_resource = provision(78, activate=not live_profile)
            if live_profile:
                for pid, foreign, worker in ((ingress, application_resource, 77), (application, ingress_resource, 78)):
                    send({'associate': dict(pid=pid, name=b'query-peer'.hex(), expected_revision=0, resource=foreign, required=False)})
                    send({'own': dict(pid=pid, expected_generation=2, worker=worker)})
            grant(34, 20)
            for principal in (65536, 65537):
                if reactive_views and principal == 65536:
                    # The query caller verifies proofs from both native owners;
                    # its send permission still names only the requester.
                    grant(principal, 16)
                    role = query(principal, {'authorization': dict(role=None, kind={'identity': {}})})['body']['authorization']['body']['identity']['login_role']
                    authorize(send, query, {'grant': dict(object=dict(kind='process', id=ingress), grantee=role, privileges=4, grant_options=0)})
                else:
                    grant(principal, 20, ingress)
            grant(79, 16, None if reactive else ingress)
            resource_grant(ingress_resource, 79, 3)
            if reactive: resource_grant(application_resource, 79, 3)
            grant(80, 148)
            if live_profile:
                grant(177, 16)
                for resource in (ingress_resource, application_resource): resource_grant(resource, 177, 3)
            catalog_authority = provision_catalog(REALM, application_resource, application, keys[33], send, query,
                readers=((65536, 65537, 77, 79, 177) if live_profile else (65536, 65537, 79)) if reactive else ())
            resource_grant(application_resource, 33, 3)
            settings = json.loads(configuration.read_text())
            settings['table'] = dict(catalog=catalog_authority['catalog'], registrar=dict(principal=0, seed_file=str(keys[0].seed)))
            configuration.write_text(json.dumps(settings))
            authority.terminate(); authority.wait(timeout=15)
            authority = start('node-direct', node, settings)
            wait_ready(store.http, authority, url + '/health')
            counter_definition = bootstrap_counter(host, store.root, url, catalog_authority['data'], keys[33])
            def populate_rows():
                populate_query_rows(host, store.root, url, catalog_authority['data'])
            sequences[0] = query(0, {'identity': {}})['principal_sequence']
            worker_url = f'http://127.0.0.1:{proxy.server_port}'
            ingress_config = dict(url=worker_url, realm=REALM, principal=77, seed_file=str(keys[77].seed), pid=ingress, generation=2, activation_directory=str(store.root), role={'ingress': dict(service=1, administrator=33, observer=34)})
            application_config = dict(url=worker_url, realm=REALM, principal=78, seed_file=str(keys[78].seed), pid=application, generation=2, activation_directory=str(store.root), role={'application': dict(ingress=ingress, initializer=33, data=catalog_authority['data'])})
            if live_profile:
                ingress_config['inspection_principal'] = 177
                ingress_config['generation'] = application_config['generation'] = 3
                ingress_config['role'] = {'live_ingress': dict(service=dict(service=1, administrator=33, observer=34), query_principal=65536, source=application)}
                application_config['role']['application']['queries'] = True
                resource_grant(application_resource, 77, 3)
                resource_grant(ingress_resource, 78, 3)
            ingress_worker = start('ingress', example, ingress_config)
            app_worker = start('application', example, application_config)
            cast(ingress, b'SV1c\x00')
            cast(application, b'')
            drained(ingress)
            drained(application)
            courier_config = dict(url=worker_url, realm=REALM, principal=80, seed_file=str(keys[80].seed), role={'courier': dict(destinations=[ingress, application])})
            courier_worker = start('courier', courier, courier_config)
            fault['deliveries_armed'] = True
            deadline_ms = int(time.time() * 1000) + (1800000 if growth else 600000)
            cast(ingress, publication(1, application, deadline_ms))
            for principal in (65536, 65537): cast(ingress, policy(principal))
            drained(ingress)
            # Publish listeners only after private initialization has completed.
            if live_profile:
                resource_grant(application_resource, 65536, 3)
                resource_grant(ingress_resource, 65536, 3)
            gateway_ports = [free_port(), free_port()]
            public_host = 'serving.example.test'
            tls_proxies = []
            if tls:
                from interfaces.http.serving_tls import TLSProxy
                tls_proxies = [TLSProxy(store.root / f'tls-{index}', gateway_port, read_timeout=35 if reactive or reactive_views else 6) for index, gateway_port in enumerate(gateway_ports)]
                if reactive_browser or reactive_views: public_host = f'127.0.0.1:{tls_proxies[0].port}'
            gateway_config = dict(url=f'http://127.0.0.1:{proxy.server_port}', realm=REALM, principal=79, seed_file=str(keys[79].seed), role={'gateway': dict(service=1, ingress=ingress, resource=ingress_resource, port=gateway_ports[0], host=public_host, public_origin='https://' + public_host, callers=[dict(principal=p, public_key=keys[p].public) for p in (65536, 65537)])})
            if reactive:
                gateway_config['role']['gateway'].update(reactive=True, options=dict(requests=4, request_timeout_ms=30000))
            if reactive_client or live_profile:
                gateway_config['role']['gateway']['viewer'] = dict(principal=65536, seed_file=str(keys[65536].seed))
            if live_profile:
                gateway_config['role']['gateway']['viewer']['refresh'] = True
            gateways = []
            for index, gateway_port in enumerate(gateway_ports):
                gateway_config['role']['gateway']['port'] = gateway_port
                if reactive_views:
                    gateway = gateway_config['role']['gateway']
                    gateway.update(host=f'127.0.0.1:{tls_proxies[index].port}', public_origin=f'https://127.0.0.1:{tls_proxies[index].port}', per_caller_requests=4)
                    gateway['callers'].append(dict(principal=33, public_key=keys[33].public)) if index == 0 else None
                    if index == 1:
                        gateway_config['counter_view'] = True
                        gateway['viewer'] = dict(principal=65537, seed_file=str(keys[65537].seed), snapshot_values=True)
                gateways.append(start(f'gateway-{index}', example, gateway_config))
                if tls:
                    TLS[gateway_port] = owned.enter_context(tls_proxies[index])
            time.sleep(.4)

            def read(kind, operation=0, principal=65536, expected=200):
                return post(gateway_ports[0], '/serving/v1/read', signed_read(keys[principal], principal, ingress, kind, operation), public_host, expected)

            if reactive_views:
                from interfaces.reactive.reactive_views import run as run_views
                run_views(locals(), TLS)
                assert set(fault['contention_requests']) == fault['contention_retried'] == {34, 77}, 'worker or clock observer replaced a contended native request'
                return
            if reactive_refresh:
                from interfaces.reactive.reactive_refresh import run as run_refresh
                run_refresh(locals(), TLS)
                return
            if reactive_client:
                from interfaces.reactive.reactive_client import run as run_client
                run_client(locals(), TLS)
                return
            if reactive:
                from interfaces.reactive.reactive import run_trace
                run_trace(locals(), TLS)
                return
            discovery = read('discovery')
            assert discovery['binding']['revision'] == 1 and not discovery['capabilities']['websocket'], discovery
            post(gateway_ports[0], '/serving/v1/read', signed_read(keys[65536], 65536, ingress, 'status', 0), public_host, 400)
            if tls:
                probe = signed_read(keys[65536], 65536, ingress, 'discovery')
                post(gateway_ports[0], '/serving/v1/read', probe, 'foreign.example.test', 403)
                post(gateway_ports[0], '/serving/v1/read', probe, public_host, 403, {'Origin': 'https://foreign.example.test'})
            frozen = native_command(keys[65536], 65536, 1, {'send': dict(pid=ingress, value=frame(submit(1, deadline_ms)))})
            fault['armed'] = True
            post(gateway_ports[0], '/serving/v1/command', frozen, public_host, 504 if capacity else 503)
            assert fault['lost']
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                receipts = list(pool.map(lambda p: post(p, '/serving/v1/command', frozen, public_host, 202), gateway_ports))
            assert receipts[0] == receipts[1] and receipts[0]['stage'] == 'ingress_accepted' and fault['retried'], receipts
            sequences[65536] = 1

            def operation_diagnostic(value, code, outcome):
                detail = value['diagnostic']
                assert (detail['code'], detail['outcome'], detail['evidence']) == (code, outcome, 'domain_status'), detail
                assert detail['identity'] == dict(domain='serving', id=str(value['operation']['operation']), realm=str(REALM), resource=str(ingress_resource), sequence=None), detail
                assert not any(action and action['kind'] in ('resume_exact', 'correct_input', 'reconcile_effect') for action in detail['actions']), detail
                return detail

            def completed(operation, expected):
                until = time.monotonic() + 45
                while time.monotonic() < until:
                    try:
                        status = read('status', operation)
                        if status['stage'] == 'completed':
                            value = read('result', operation)
                            assert struct.unpack('<q', bytes.fromhex(value['operation']['result']))[0] == expected, value
                            assert value['operation']['reply_bytes'] == 8, value
                            operation_diagnostic(value, 'serving.reply_recorded', 'completed')
                            return value
                    except AssertionError as error:
                        if isinstance(error.args[0], tuple) and error.args[0][1] in (404, 409, 503, 504):
                            time.sleep(.03)
                            continue
                        raise
                    except (OSError, ConnectionError):
                        # A read interruption changes no durable outcome. The
                        # outer observation deadline still bounds all retries.
                        continue
                    time.sleep(.03)
                raise AssertionError(('incomplete', operation, status))

            first = completed(1, 1)
            assert fault['data_commit'] and fault['data_inspected'], 'lost data receipt was not recovered'
            progress = query(0, {'read_entries': dict(resource=application_resource, revision=None, view=None, keys=[b'data-progress'.hex()] + [None] * 7)})['body']['read_entries']['entries'][0]
            assert int(bytes.fromhex(progress['value'])) == 1, progress
            expected_retries = {'ingress_commit', 'application_commit', 'destination_delivery', 'reply_delivery'}
            until = time.monotonic() + 5
            while fault['commit_retries'] != expected_retries and time.monotonic() < until: time.sleep(.01)
            assert fault['commit_retries'] == expected_retries, fault
            if capacity:
                probe = signed_read(keys[65536], 65536, ingress, 'status', 1)
                other = signed_read(keys[65537], 65537, ingress, 'discovery')
                fault['serialize_upstream'] = True
                fault['stall_reads'] = True
                with concurrent.futures.ThreadPoolExecutor(max_workers=8) as readers:
                    pending = [readers.submit(post, gateway_port, '/serving/v1/read', probe, public_host) for gateway_port in gateway_ports for _ in range(2)]
                    try:
                        until = time.monotonic() + 2
                        while fault['blocked'] < 4 and time.monotonic() < until:
                            time.sleep(.005)
                        assert fault['blocked'] == 4, ('blocked reads', fault['blocked'])
                        post(gateway_ports[0], '/serving/v1/read', probe, public_host, 429)
                        pending += [readers.submit(post, gateway_port, '/serving/v1/read', other, public_host) for gateway_port in gateway_ports for _ in range(2)]
                        while fault['blocked'] < 8 and time.monotonic() < until:
                            time.sleep(.005)
                        assert fault['blocked'] == 8, ('blocked reads', fault['blocked'])
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
                    assert all(item.result()['operation'] == first['operation'] for item in pending[:4])
                    assert all(item.result()['binding']['revision'] == 1 for item in pending[4:])
                fault['serialize_upstream'] = False
                print(f'Serving capacity: per-caller refusal preserves unrelated callers, eight delayed authorized reads, ninth refused, health {elapsed:.3f}s; two-gateway RSS {rss} bytes <= 268435456 ceiling; private 2 MiB request buffers', flush=True)
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
            conflict_input = receipt['receipt']['position']
            original_conflict = read('disposition', conflict_input)['disposition']
            assert original_conflict['record']['reason'] == 'ServingIdentityConflict'
            detail = original_conflict['diagnostic']
            assert (detail['code'], detail['outcome'], detail['evidence']) == ('serving.identity_conflict', 'input_rejected', 'domain_status'), detail
            facts = {fact['field']: fact['value'] for fact in detail['facts'] if fact}
            expected_digest = hashlib.sha256(b'transit.serving.command.v1\0' + b'SV1s' + submit(1, deadline_ms)[5:]).digest()
            actual_digest = hashlib.sha256(b'transit.serving.command.v1\0' + b'SV1s' + submit(1, deadline_ms, delta=9)[5:]).digest()
            assert facts['expected_schema']['digest'] == list(expected_digest), facts
            assert facts['actual_schema']['digest'] == list(actual_digest), facts
            assert original_conflict['record']['payload'] == list(hashlib.sha256(b'transit.serving.input.v1\0' + bytes.fromhex(conflict['request']['command']['send']['value'])).digest())
            assert [action['kind'] for action in detail['actions'] if action] == ['inspect_status']
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
            assert read('disposition', malformed)['disposition']['record']['reason'] == 'InvalidServingFrame'
            invalid_identity = cast(ingress, submit(2**64 - 1, deadline_ms), 65536)
            drained(ingress)
            invalid = read('disposition', invalid_identity)['disposition']
            assert invalid['record']['reason'] == 'InvalidServingIdentity' and invalid['record']['subject'] == str(2**64 - 1), invalid
            assert any(fact and fact['field'] == 'object' and fact['value'] == {'unsigned': str(2**64 - 1)} for fact in invalid['diagnostic']['facts']), invalid
            second_request = native_command(keys[65536], 65536, sequences[65536] + 1, {'send': dict(pid=ingress, value=frame(submit(2, deadline_ms)))})
            # Stop delivery so the admission commits before physical loss.
            courier_worker.kill(); courier_worker.wait(timeout=10)
            post(gateway_ports[0], '/serving/v1/command', second_request, public_host, 202)
            sequences[65536] += 1
            drained(ingress)
            admitted = read('status', 2)
            assert admitted['stage'] == 'service_admitted'
            pending_detail = operation_diagnostic(admitted, 'serving.operation_admitted', 'pending')
            assert read('result', 2, expected=409)['diagnostic'] == pending_detail
            correlation = read('status', 2)['operation']['correlation']
            premature = send({'send': dict(pid=ingress, value=frame(b'TMO1' + struct.pack('<Q', deadline_ms - 1), 8, correlation))}, 34)
            spoofed = send({'send': dict(pid=ingress, value=frame(b'forged', 3, correlation))}, 65536)
            drained(ingress)
            assert read('status', 2)['stage'] == 'service_admitted'
            # This caller sees only its own disposition, not the observer's.
            assert read('disposition', premature)['disposition'] is None
            spoof = read('disposition', spoofed)['disposition']
            assert spoof['record']['reason'] == 'UnexpectedServingReplySource'
            assert any(fact and fact['field'] == 'expected_source' and fact['value'] == {'unsigned': str(application)} for fact in spoof['diagnostic']['facts']), spoof
            if lifetimes:
                cast(ingress, submit(7, deadline_ms, row=2), 65537)
                drained(ingress)
                assert read('status', 7, principal=65537)['stage'] == 'service_admitted'
                cast(ingress, b'SV1c\x04' + struct.pack('<Q', 7), 65537)
                drained(ingress)
                cancelled = read('status', 7, principal=65537)
                assert cancelled['stage'] == 'cancelled'
                cancelled_detail = operation_diagnostic(cancelled, 'serving.wait_cancelled', 'cancelled')
                assert read('result', 7, principal=65537, expected=409)['diagnostic'] == cancelled_detail
                timeout_at = int(time.time() * 1000) + 1000
                cast(ingress, submit(8, timeout_at, row=2), 65537)
                drained(ingress)
                waiting = read('status', 8, principal=65537)['operation']['correlation']
                time.sleep(max(0, timeout_at / 1000 - time.time()))
                observation = frame(b'TMO1' + struct.pack('<Q', int(time.time() * 1000)), 8, waiting)
                send({'send': dict(pid=ingress, value=observation)}, 34)
                drained(ingress)
                terminal = read('status', 8, principal=65537)
                assert terminal['stage'] == 'timed_out'
                timeout_detail = operation_diagnostic(terminal, 'serving.wait_timed_out', 'closed_unknown')
                assert read('result', 8, principal=65537, expected=409)['diagnostic'] == timeout_detail
                send({'send': dict(pid=ingress, value=observation)}, 34)
                drained(ingress)
                assert read('status', 8, principal=65537)['operation'] == terminal['operation']
            for process in (*gateways, ingress_worker, app_worker, authority):
                process.kill(); process.wait(timeout=10)
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
            assert read('disposition', conflict_input)['disposition'] == original_conflict
            if lifetimes:
                assert read('status', 7, principal=65537)['diagnostic'] == cancelled_detail
                assert read('status', 8, principal=65537)['diagnostic'] == timeout_detail
                assert read('status', 8, principal=65537)['operation'] == terminal['operation']
                # Late application replies are consumed by Station without
                # reopening either terminal wait after physical recovery.
                until = time.monotonic() + 10
                while time.monotonic() < until:
                    resource = query(0, {'resource': ingress_resource})['body']['resource']
                    try:
                        entries = query(0, {'entries': dict(view=None, resource=ingress_resource, revision=resource['revision'], key=b'\x00disposition'.hex(), after=None)})['body']['entries']['page']['entries']
                    except AssertionError as error:
                        if error.args[0][1] in (409, 422): continue
                        raise
                    if entries[0] and bytes.fromhex(entries[0]['value']) == b'station.closed-reply.v1': break
                    time.sleep(.03)
                else: raise AssertionError('late reply was not consumed after closure')
            if growth:
                # Retained cardinality exceeds the authority's resident-page
                # budget; every lookup remains a bounded public point read.
                for ordinal in range(128):
                    operation = 100 + ordinal
                    sequences[65536] += 1
                    message = native_command(keys[65536], 65536, sequences[65536], {'send': dict(pid=ingress, value=frame(submit(operation, deadline_ms)))})
                    post(gateway_ports[0], '/serving/v1/command', message, public_host, 202)
                    completed(operation, ordinal + 4)
                    if (ordinal + 1) % 32 == 0: print(f'Serving growth: retained {ordinal + 1}/128 operations', flush=True)
                for ordinal in (0, 31, 63, 127): completed(100 + ordinal, ordinal + 4)
                completed(1, 1)
                retained = [path for path in (store.root / 'native').rglob('*') if path.is_file()]
                retained_bytes = sum(path.stat().st_size for path in retained)
                assert retained_bytes > 0
                print(f'Serving growth: {len(retained)} retained local files / {retained_bytes} bytes', flush=True)
                rss = sum(int(next(line for line in Path(f'/proc/{worker.pid}/status').read_text().splitlines() if line.startswith('VmRSS:')).split()[1]) * 1024 for worker in (authority, ingress_worker, app_worker, gateways[0]))
                assert rss <= 512 * 1024 * 1024, ('authority/workers/gateway exceeded finite growth profile ceiling', rss)
                print(f'Serving growth: 128 additional retained operations and bounded old-result reads with 8 resident authority pages; authority/two workers/gateway RSS {rss} bytes <= 536870912 ceiling', flush=True)
            cast(ingress, publication(2, application, deadline_ms, False))
            drained(ingress)
            completed(2, 3)
            assert read('disposition', conflict_input)['disposition'] == original_conflict
            cast(ingress, policy(65536, revision=2, reads=False))
            drained(ingress)
            read('result', 2, expected=403)
            read('disposition', conflict_input, expected=403)
            cast(ingress, policy(65536, revision=3))
            drained(ingress)
            completed(2, 3)
            assert read('disposition', conflict_input)['disposition'] == original_conflict
            revoked_reads = [signed_read(keys[65536], 65536, ingress, kind, operation)
                             for kind, operation in (('result', 2), ('disposition', conflict_input))]
            send({'revoke': 65536})
            for prepared_read in revoked_reads:
                post(gateway_ports[0], '/serving/v1/read', prepared_read, public_host, 403)
            if lifetimes:
                # An independently created finite ingress expires with no timer
                # observer or courier delivering a notification. No retention
                # opt-in or physical deletion is inferred from that expiry.
                courier_worker.kill(); courier_worker.wait(timeout=10)
                expires_at = int(time.time() * 1000) + 10000
                work_before = expires_at - 2000
                ephemeral, ephemeral_resource = provision(77, expires_at, work_before)
                offline = send({'spawn': dict(allow_collection=False, code=1, work_before_ms=None, settle_before_ms=None)})
                ephemeral_config = dict(ingress_config, pid=ephemeral, generation=2)
                ephemeral_worker = start('finite-ingress', example, ephemeral_config)
                cast(ephemeral, b'SV1c\x00')
                drained(ephemeral)
                cast(ephemeral, publication(1, offline, expires_at))
                cast(ephemeral, policy(65537))
                drained(ephemeral)
                grant(65537, 20, ephemeral)
                grant(79, 16, ephemeral)
                resource_grant(ephemeral_resource, 79, 3)
                too_late = cast(ephemeral, submit(10, expires_at), 65537)
                cast(ephemeral, submit(9, work_before), 65537)
                drained(ephemeral)
                gateways[0].kill(); gateways[0].wait(timeout=10)
                gateway_config['role']['gateway'].update(ingress=ephemeral, resource=ephemeral_resource)
                gateways[0] = start('finite-gateway', example, gateway_config)
                time.sleep(.2)
                finite_read = signed_read(keys[65537], 65537, ephemeral, 'status', 9)
                finite = post(gateway_ports[0], '/serving/v1/read', finite_read, public_host)
                assert finite['stage'] == 'service_admitted' and finite['operation']['deadline_ms'] == work_before
                disposition = post(gateway_ports[0], '/serving/v1/read', signed_read(keys[65537], 65537, ephemeral, 'disposition', too_late), public_host)
                assert disposition['disposition']['record']['reason'] == 'InvalidWaitLifetime'
                lease_facts = {fact['field']: fact for fact in disposition['disposition']['diagnostic']['facts'] if fact}
                assert lease_facts['budget']['value'] == {'text': 'process'}, lease_facts
                assert lease_facts['limit']['value'] == {'unsigned': str(work_before)}, lease_facts
                assert lease_facts['observed_clock']['availability'] == 'unrecorded', lease_facts
                time.sleep(max(0, (expires_at + 100) / 1000 - time.time()))
                # Linux's measured clock uncertainty can straddle the deadline.
                # Keep that explicit 503 distinct from definite unavailability.
                until = time.monotonic() + 11
                while True:
                    status, value = post(gateway_ports[0], '/serving/v1/read', finite_read, public_host, None)
                    if status == 410: break
                    assert status == 503 and time.monotonic() < until, (status, value)
                    time.sleep(.1)
                expired_command = native_command(keys[65537], 65537, sequences[65537] + 1, {'send': dict(pid=ephemeral, value=frame(submit(11, work_before)))})
                post(gateway_ports[0], '/serving/v1/command', expired_command, public_host, 410)
                print('Serving lifetimes: ordered cancellation, authenticated timeout and duplicate observation, late replies after restart, finite process/wait/resource bounds and hard expiry without observer delivery passed', flush=True)
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
    for name in ('node', 'example', 'courier', 'host'):
        parser.add_argument(name)
    parser.add_argument('--tls', action='store_true')
    parser.add_argument('--capacity', action='store_true')
    parser.add_argument('--lifetimes', action='store_true')
    parser.add_argument('--growth', action='store_true')
    parser.add_argument('--reactive', action='store_true')
    parser.add_argument('--reactive-browser', action='store_true')
    parser.add_argument('--reactive-limits', action='store_true')
    parser.add_argument('--reactive-client', action='store_true')
    parser.add_argument('--reactive-refresh', action='store_true')
    parser.add_argument('--reactive-views', action='store_true')
    parser.add_argument('--reactive-views-lifecycle', action='store_true')
    parser.add_argument('--board')
    run(**vars(parser.parse_args()))

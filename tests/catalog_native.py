"""Real catalog Table creation, exact receipt recovery and native fencing."""
import argparse
import copy
from concurrent.futures import ThreadPoolExecutor
from contextlib import nullcontext
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import threading
import time

from storage import Fixture, free_port, wait_ready
from cold_storage import ColdStore
from catalog_abi import Native, Port, Failure, check_profiles
from catalog_cli import Cli

ROOT = Path(__file__).resolve().parents[1]


def retain_recovery_fixture(fixture, cold_store, destination, recovery):
    """Retain private failed state after joining each owned native process."""
    fixture.stop()
    retained = destination.parent / 'recovery-failures' / str(time.time_ns())
    retained.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    recovery['original_fixture'] = str(fixture.root)
    shutil.move(fixture.root, retained)
    recovery['retained_fixture'] = str(retained)
    if cold_store:
        recovery['original_cold_fixture'] = str(cold_store.root)
        cold_store.stop()
        shutil.move(cold_store.root, retained / 'cold-store')
        recovery['retained_cold_fixture'] = str(retained / 'cold-store')


def diagnostic_errors(log):
    """Retain bounded error attribution before the owned log is removed.

    Only fixed runtime event/operation/error names and timing are copied. Logs
    remain observations, not receipts; no body, credential or user label is kept.
    """
    log.flush()
    log.seek(0)
    errors = {}
    dropped = 0
    for line in log:
        _, separator, encoded = line.partition('{')
        if not separator:
            continue
        try:
            value = json.loads(separator + encoded)
        except ValueError:
            continue
        event = value.get('event', {})
        if event.get('name') not in ('transit.storage.operation', 'transit.http.request', 'service.failed') or not event.get('error_type'):
            continue
        key = (event['name'], event.get('operation'), event['error_type'])
        if key not in errors:
            if len(errors) == 64:
                dropped += 1
                continue
            errors[key] = dict(event=key[0], operation=key[1], error=key[2],
                               count=0, first_time_unix_ms=value.get('time_unix_ms'), max_ns=0)
        summary = errors[key]
        summary['count'] += 1
        summary['max_ns'] = max(summary['max_ns'], value.get('duration_ns', 0))
    return dict(groups=list(errors.values()), dropped=dropped)


def run(node, proof, catalog_host, port_host, library, cli, languages=(), growth=0, initial_node=None, cold=False):
    if growth < 0: raise ValueError('Catalog growth count must be nonnegative')
    if initial_node and (languages or growth < 139):
        raise ValueError('The page-depth recovery schedule requires at least 139 additions and no optional SDKs')
    started = time.monotonic()
    counts = dict(reads=0, caller_reads=0, turns=0, max_mutations=0, max_value_bytes=0)
    upstream = {}
    metrics_lock = threading.Lock()
    growth_phases = {name: dict(calls=0, failures=0, seconds=0.0, caller_reads=0)
                     for name in ('compile', 'prepare', 'admit', 'await_application')}
    growth_current = None
    growth_baseline = None
    recovery_ready = threading.Event()
    recovery_finished = threading.Event()
    recovery_body = None
    recovery = dict(enabled=initial_node is not None, failed_attempts=0,
                    restarted=False, original_turn_sha256=None, receipt=None)
    def metrics():
        with metrics_lock:
            return copy.deepcopy(upstream)
    def growth_phase(index, name, work):
        nonlocal growth_current
        growth_current = dict(index=index, phase=name)
        began = time.monotonic()
        reads = counts['caller_reads']
        entry = growth_phases[name]
        entry['calls'] += 1
        try:
            return work()
        except BaseException:
            entry['failures'] += 1
            raise
        finally:
            entry['seconds'] += time.monotonic() - began
            entry['caller_reads'] += counts['caller_reads'] - reads
    with ColdStore() if cold else nullcontext() as cold_store, Fixture(cold_store.config() if cold_store else None) as fixture:
        root = fixture.root
        installation_started = time.monotonic()
        installed = []
        if languages:
            from sdk_catalog import install
            installed = install(root / 'catalog-sdks', languages)
        install_seconds = round(time.monotonic() - installation_started, 3)
        for name, binary in [('node', node), ('proof', proof), ('host', catalog_host), ('port', port_host), ('library.so', library), ('cli', cli)]:
            shutil.copy2(binary, root / name)
        if initial_node:
            shutil.copy2(initial_node, root / 'initial-node')
            recovery['initial_sha256'] = hashlib.sha256((root / 'initial-node').read_bytes()).hexdigest()
        node, proof = str(root / 'node'), str(root / 'proof')
        target_node = node
        if initial_node:
            node = str(root / 'initial-node')
        catalog_host = str(root / 'host')
        port_host, library = str(root / 'port'), str(root / 'library.so')
        cli = str(root / 'cli')
        clients = []
        client_names = {}
        (root / 'caller.seed').write_text('0a' * 32)
        port = free_port()
        url = f'http://127.0.0.1:{port}'
        public = json.loads(subprocess.check_output([proof, 'public'], timeout=10))
        config = root / 'node.json'
        config.write_text(json.dumps(dict(profile='native_v1',
            genesis=dict(realm=46, root_key=public, max_clock_error_ms=10000),
            ursula_url=fixture.url, bucket='catalog', journal='authority', port=port,
            resident_pages=8, request_timeout_ms=10000)))
        faults = {name: dict(lose=False, body=None, receipt=None, recovered=False) for name in ('send', 'turn')}
        faults['initialize_send'] = dict(command='send', lose=False, body=None, receipt=None, recovered=False)
        for name in ['abi_create', 'port_create', 'cli_create', 'console_create', *[name + '_create' for name, _ in installed]]:
            faults[name] = dict(command='send', lose=False, body=None, receipt=None, recovered=False)
        for name in ('host_initialize', 'host_create'):
            faults[name] = dict(command='turn', lose=False, body=None, receipt=None, recovered=False, blocked=False)
        failures = []
        active = 0
        active_lock = threading.Lock()
        metadata_gate = dict(armed=False)
        metadata_entered = threading.Event()
        metadata_release = threading.Event()

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                nonlocal active, recovery_body
                with active_lock:
                    active += 1
                body = self.rfile.read(int(self.headers['Content-Length']))
                connection = HTTPConnection('127.0.0.1', port, timeout=15)
                try:
                    envelope = json.loads(body)
                    if self.path == '/v1/query':
                        counts['reads'] += 1
                        if envelope['query']['principal'] == 1234:
                            counts['caller_reads'] += 1
                            kind = envelope['query']['kind']
                            batch = kind.get('read_entries') if isinstance(kind, dict) else None
                            if metadata_gate['armed'] and batch and batch['keys'][0].startswith((b'\0C' + struct.pack('>Q', 2**64 - 1) + b'd').hex()):
                                metadata_gate['armed'] = False
                                metadata_entered.set()
                                assert metadata_release.wait(10), 'Dependent metadata batch was not released'
                    if any(f.get('blocked') and body == f['body'] for f in faults.values()):
                        self.send_response(503)
                        self.send_header('Content-Length', '2')
                        self.end_headers()
                        self.wfile.write(b'{}')
                        return
                    if recovery_ready.is_set() and not recovery_finished.is_set() and body == recovery_body:
                        self.send_response(503)
                        data = b'{"err":"AuthorityUnavailable"}'
                        self.send_header('Content-Length', str(len(data)))
                        self.end_headers()
                        self.wfile.write(data)
                        return
                    request = envelope['query'] if self.path == '/v1/query' else envelope['request']
                    operation = request['kind'] if self.path == '/v1/query' else request['command']
                    operation = operation if isinstance(operation, str) else next(iter(operation))
                    role = {1234: 'caller', 65536: 'owner', 0: 'administrator'}.get(request['principal'], 'other')
                    label = f'{role}:{operation}'
                    began = time.monotonic_ns()
                    status = None
                    try:
                        connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                        response = connection.getresponse()
                        data = response.read()
                        status = response.status
                    finally:
                        duration = time.monotonic_ns() - began
                        with metrics_lock:
                            metric = upstream.setdefault(label, dict(attempts=0, transport_failures=0, http_errors=0, elapsed_ns=0, max_ns=0))
                            metric['attempts'] += 1
                            metric['transport_failures'] += status is None
                            metric['http_errors'] += status is not None and status != 200
                            metric['elapsed_ns'] += duration
                            metric['max_ns'] = max(metric['max_ns'], duration)
                    if initial_node and label == 'owner:turn' and growth_current == dict(index=138, phase='await_application'):
                        if not recovery_ready.is_set() and status == 503 and json.loads(data) == {'err': 'AuthorityUnavailable'}:
                            if recovery_body is None:
                                recovery_body = body
                                recovery['original_turn_sha256'] = hashlib.sha256(body).hexdigest()
                            assert body == recovery_body, 'Worker replaced its uncertain turn before recovery'
                            recovery['failed_attempts'] += 1
                            if recovery['failed_attempts'] == 2:
                                recovery_ready.set()
                        if recovery_finished.is_set() and status == 200:
                            assert body == recovery_body, 'Node replacement changed the original turn'
                            receipt = json.loads(data)
                            assert recovery['receipt'] in (None, receipt), 'Original turn receipt changed'
                            recovery['receipt'] = receipt
                    if self.path == '/v1/command' and response.status == 200:
                        command = envelope['request']['command']
                        turn = command.get('turn')
                        if turn:
                            counts['turns'] += 1
                            changes = [x for x in turn['mutations'] if x]
                            counts['max_mutations'] = max(counts['max_mutations'], len(changes))
                            for change in changes:
                                if change['value'] is not None:
                                    counts['max_value_bytes'] = max(counts['max_value_bytes'], len(bytes.fromhex(change['value'])))
                        for name, fault in faults.items():
                            if body == fault['body']:
                                assert data == fault['receipt'], 'Exact native retry changed its receipt'
                                fault['recovered'] = True
                            if fault['lose'] and fault.get('command', name) in command:
                                fault.update(lose=False, body=body, receipt=data)
                                if 'blocked' in fault:
                                    fault['blocked'] = True
                                data = b'{"position":0}'
                    self.send_response(response.status)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                except (BrokenPipeError, ConnectionResetError):
                    pass  # The schedule deliberately kills an uncertain worker.
                except BaseException as error:
                    failures.append(repr(error))
                    raise
                finally:
                    connection.close()
                    with active_lock:
                        active -= 1

        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        proxy_url = f'http://127.0.0.1:{proxy.server_port}'
        log = (root / 'node.log').open('w+')
        authority = None
        worker = None
        worker_log = (root / 'worker.log').open('w+')

        def stop_worker():
            nonlocal worker
            if worker is not None:
                worker.kill()
                worker.wait(timeout=10)
                worker = None
            deadline = time.monotonic() + 5
            while active:
                assert time.monotonic() < deadline, 'Proxy did not drain'
                time.sleep(.005)

        def start_worker():
            nonlocal worker
            worker = subprocess.Popen([catalog_host, str(root / 'host.json')], env=fixture.env,
                                      stdout=worker_log, stderr=subprocess.STDOUT)

        def await_value(fn):
            deadline = time.monotonic() + 20
            while True:
                value = fn()
                if value:
                    return value
                assert worker is None or worker.poll() is None, 'Catalog host exited'
                assert time.monotonic() < deadline, 'Catalog host did not progress'
                time.sleep(.01)

        def start():
            nonlocal authority
            authority = subprocess.Popen([node, str(config)], env=fixture.env, stdout=log, stderr=subprocess.STDOUT)
            wait_ready(fixture.http, authority, url + '/health')

        def restart():
            nonlocal authority
            authority.kill()
            authority.wait(timeout=10)
            authority = None
            fixture.stop()
            fixture.start()
            start()

        metadata_measurements = []
        def invoke(mode, *args, error=None):
            before = counts['caller_reads']
            began = time.monotonic()
            result = subprocess.run([proof, proxy_url, mode, str(root), *map(str, args)], capture_output=True, text=True, timeout=60)
            if mode in ('list', 'lookup', 'definition'):
                metadata_measurements.append(dict(operation=mode, expected_error=error,
                    reads=counts['caller_reads'] - before, seconds=round(time.monotonic() - began, 6)))
            if error:
                assert result.returncode != 0 and error in result.stderr, (mode, error, result.stdout, result.stderr)
                return None
            assert result.returncode == 0, (mode, result.stderr)
            value = json.loads(result.stdout)
            if mode == 'list':
                assert metadata_measurements[-1]['reads'] <= 5, 'Signed page exceeded its read budget'
            return value

        def absent():
            snapshot = invoke('snapshot')
            assert snapshot['entries'] == [None] * 4, snapshot
            return snapshot

        maximum = 2**64 - 1
        statement = 'CREATE TABLE items (id INT64 NOT NULL,value UTF8 NULL)'
        grown_names = []
        growth_samples = []
        report = dict(version=1, completed=False,
            revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
            dirty=bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True)),
            runner_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            resident_pages=8, requested_growth_tables=growth, selected_sdks=list(languages),
            sdk_install_seconds=install_seconds,
            sdk_artifacts={language: json.loads((root / 'catalog-sdks' / language / 'artifacts.json').read_text()) for language in languages},
            binaries={name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in ('node', 'proof', 'host', 'port', 'library.so', 'cli')})
        destination = ROOT / '.cache/verification/catalog/native.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        def record(completed=False, error=None):
            report.update(completed=completed, error=error,
                seconds=round(time.monotonic() - started, 3), counts=counts,
                catalog_growth_tables=len(grown_names), growth_samples=growth_samples,
                growth_current=growth_current, growth_baseline=growth_baseline,
                growth_phases=copy.deepcopy(growth_phases),
                upstream_operations=metrics(),
                node_recovery=copy.deepcopy(recovery),
                metadata_measurements=metadata_measurements)
            destination.write_text(json.dumps(report, indent=2) + '\n')
        record()
        try:
            subprocess.run([node, str(config), '--initialize'], env=fixture.env, check=True, capture_output=True, timeout=30)
            start()
            provision = invoke('provision')
            invoke('prepare-send', maximum, maximum, 9, statement)
            frozen_send = (root / 'send.json').read_bytes()
            frozen_prepared = (root / 'prepared.json').read_bytes()
            faults['send']['lose'] = True
            invoke('submit-send', error='InvalidAuthorityResponse')
            assert faults['send']['receipt'] is not None
            restart()
            admitted = invoke('submit-send')
            assert admitted == json.loads(faults['send']['receipt']) and faults['send']['recovered']
            assert (root / 'send.json').read_bytes() == frozen_send
            assert (root / 'prepared.json').read_bytes() == frozen_prepared
            assert invoke('observe', admitted['position']) == 'pending'
            assert invoke('status') is None
            before = absent()
            prepared = invoke('prepare-commit')
            assert prepared['mutations'] == 4 and absent() == before
            frozen_commit = (root / 'commit.json').read_bytes()
            faults['turn']['lose'] = True
            invoke('commit', error='InvalidAuthorityResponse')
            after = invoke('snapshot')
            entries = after['entries']
            assert all(entries) and len({e['revision'] for e in entries}) == 1
            assert entries[0]['revision'] == after['resource_revision']
            # Independent bytes for all four atomically visible records.
            definition = bytes.fromhex(json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition'])
            scope = struct.pack('<QQQ', 46, provision['writer']['resource'], maximum)
            schema = b'TBL1\3\2id\5value'
            body = scope + struct.pack('<QQI', maximum, maximum, 9) + b'\5items' + bytes([len(schema)]) + schema
            immutable = (b'TCA1d' + definition + scope + struct.pack('<QQ', maximum, 1) + b'\5items\1'
                         + struct.pack('<I', 9) + bytes([len(schema)]) + schema
                         + struct.pack('<QQQ', 1234, maximum, prepared['input']))
            binding = (b'TCA1n' + definition + scope + struct.pack('<QQ', maximum, 1)
                       + hashlib.sha256(b'transit.catalog.definition.v1\0' + immutable).digest())
            receipt = b'TCA1o' + definition + body + struct.pack('<QQB', 1234, prepared['input'], 1)
            assert [bytes.fromhex(e['value']) for e in entries] == [schema, immutable, binding, receipt]
            assert invoke('progress')['pending'] is None
            original_status = invoke('status')
            assert original_status['outcome'] == 'applied'
            assert original_status['request']['operation'] == maximum
            assert original_status['input'] == prepared['input']
            assert invoke('observe', admitted['position']) == 'processed'
            restart()
            recovered = invoke('commit')
            assert recovered == json.loads(faults['turn']['receipt']) and faults['turn']['recovered']
            assert (root / 'commit.json').read_bytes() == frozen_commit and invoke('snapshot') == after
            assert invoke('status') == original_status
            invoke('changed-retry', error='ConflictingRetry')
            invoke('prepare-send', maximum, maximum, 9, statement)
            invoke('submit-send')
            assert invoke('prepare-commit')['mutations'] == 0
            invoke('commit')
            assert invoke('snapshot') == after
            assert invoke('status') == original_status
            invoke('prepare-send', maximum, 1, 10, statement, error='CatalogIdentityConflict')
            # Name conflict is one durable receipt, with no new object or Table.
            invoke('prepare-send', 1, 1, 10, statement)
            invoke('submit-send')
            assert invoke('prepare-commit')['mutations'] == 1
            invoke('commit')
            conflict = invoke('snapshot')['entries']
            assert conflict[:2] == [None, None] and conflict[2] == entries[2]
            assert bytes.fromhex(conflict[3]['value'])[-1] == 2
            assert invoke('status')['outcome'] == 'name_conflict'
            # A frozen but unaccepted creation loses authority on replacement.
            invoke('prepare-send', 2, 2, 10, statement.replace('items', 'other'))
            invoke('submit-send')
            assert invoke('prepare-commit')['mutations'] == 4
            before = absent()
            invoke('reown')
            invoke('commit', error='StaleGeneration')
            assert absent() == before
            assert invoke('prepare-commit')['mutations'] == 4
            frozen = (root / 'commit.json').read_bytes()
            invoke('revoke-writer')
            invoke('commit', error='AccessDenied')
            assert absent() == before
            invoke('restore-writer')
            invoke('commit')
            assert (root / 'commit.json').read_bytes() == frozen
            assert all(invoke('snapshot')['entries'])
            # Current application inspection policy gates old receipts independently
            # of create rights and the caller's native resource read permission.
            invoke('policy', 2, 'true', 'false')
            invoke('status', error='CatalogDenied')
            assert all(invoke('snapshot')['entries'])
            invoke('policy', 3, 'false', 'true')
            assert invoke('status')['outcome'] == 'applied'
            invoke('prepare-send', 3, 3, 11, statement.replace('items', 'denied'), error='CatalogDenied')
            invoke('policy', 4, 'true', 'true')
            invoke('revoke-reader')
            invoke('snapshot', error='AccessDenied')
            invoke('status', error='AccessDenied')

            # A fresh resource uses the supplied GenServer host, not the manual
            # fixture application. Lose both initialization and creation commits.
            host_config = invoke('provision-host')
            invoke('send-policy', 1, 'true', 'true', error='CatalogNotInitialized')
            faults['initialize_send']['lose'] = True
            invoke('send-initialize', error='InvalidAuthorityResponse')
            saved_control = (root / 'control.json').read_bytes()
            restart()
            initial_receipt = invoke('retry-control')
            assert initial_receipt == json.loads(faults['initialize_send']['receipt'])
            assert (root / 'control.json').read_bytes() == saved_control
            initialized = initial_receipt['position']
            assert invoke('observe-control', initialized) == 'pending'
            assert invoke('initial-snapshot', initialized)['entries'] == [None] * 4
            faults['host_initialize']['lose'] = True
            start_worker()
            await_value(lambda: faults['host_initialize']['receipt'])
            initial = invoke('initial-snapshot', initialized)
            assert all(initial['entries']) and len({e['revision'] for e in initial['entries']}) == 1
            assert bytes.fromhex(initial['entries'][0]['value']) == b'station.genserver.v1'
            expected_scope = struct.pack('<QQQ', 46, host_config['writer']['resource'], maximum)
            assert bytes.fromhex(initial['entries'][1]['value']) == b'TCA1c' + definition + expected_scope + struct.pack('<QQ', host_config['writer']['pid'], 1234)
            assert bytes.fromhex(initial['entries'][2]['value']) == b'TCA1p' + definition + expected_scope + struct.pack('<QQBB', 1234, 1, 1, 1)
            control_payload = bytes.fromhex(json.loads((root / 'control.json').read_text())['signed']['request']['command']['send']['value'])
            initial_disposition = (b'TCA1e' + definition + expected_scope + struct.pack('<BQQ', 1, 1234, initialized)
                                   + hashlib.sha256(b'transit.catalog.input.v1\0' + control_payload).digest() + b'\1')
            assert bytes.fromhex(initial['entries'][3]['value']) == initial_disposition
            assert invoke('control-disposition', initialized)['outcome'] == 'initialized'
            stop_worker()
            restart()
            frozen = dict(definition=definition.hex(), signed=json.loads(faults['host_initialize']['body']))
            (root / 'commit.json').write_text(json.dumps(frozen, separators=(',', ':')))
            faults['host_initialize']['blocked'] = False
            assert invoke('commit') == json.loads(faults['host_initialize']['receipt'])
            assert invoke('initial-snapshot', initialized) == initial
            reused = subprocess.run([catalog_host, str(root / 'host.json')], env=fixture.env, capture_output=True, text=True, timeout=10)
            assert reused.returncode != 0 and 'FreshOwnershipRequired' in reused.stderr
            invoke('reown')
            invoke('write-host')
            start_worker()
            duplicate = invoke('send-initialize')['position']
            assert await_value(lambda: invoke('control-disposition', duplicate))['outcome'] == 'initialized'
            assert invoke('initial-snapshot', initialized)['entries'][1:3] == initial['entries'][1:3]

            invoke('prepare-send', maximum, maximum, 9, statement)
            faults['host_create']['lose'] = True
            created_input = invoke('submit-send')['position']
            await_value(lambda: faults['host_create']['receipt'])
            created_status = invoke('status')
            assert created_status['outcome'] == 'applied' and created_status['input'] == created_input
            assert invoke('input-disposition', created_input) is None
            stop_worker()
            restart()
            frozen = dict(definition=definition.hex(), signed=json.loads(faults['host_create']['body']))
            (root / 'commit.json').write_text(json.dumps(frozen, separators=(',', ':')))
            faults['host_create']['blocked'] = False
            assert invoke('commit') == json.loads(faults['host_create']['receipt'])
            assert invoke('status') == created_status
            invoke('reown')
            invoke('write-host')
            denied = invoke('send-policy', 2, 'false', 'true')['position']
            denied_control = (root / 'control.json').read_bytes()
            # Both commands prepare at policy revision one. The second must
            # retain a stale outcome when the first applies before it.
            stale = invoke('send-policy', 2, 'true', 'true')['position']
            start_worker()
            assert await_value(lambda: invoke('control-disposition', stale))['outcome'] == 'stale_policy'
            (root / 'control.json').write_bytes(denied_control)
            assert await_value(lambda: invoke('control-disposition', denied))['outcome'] == 'policy_applied'
            other = statement.replace('items', 'other')
            invoke('prepare-send', 2, 2, 10, other, error='CatalogDenied')
            invoke('prepare-raw', 2, 2, 10, other)
            rejected_prepared = (root / 'prepared.json').read_bytes()
            rejected = invoke('submit-send')['position']
            denied_status = await_value(lambda: invoke('input-disposition', rejected))
            assert denied_status['outcome'] == 'denied' and denied_status['input'] == rejected
            assert invoke('status') is None and invoke('observe', rejected) == 'processed'
            assert invoke('snapshot')['entries'] == [None] * 4
            restored = invoke('send-policy', 3, 'true', 'true')['position']
            assert await_value(lambda: invoke('control-disposition', restored))['outcome'] == 'policy_applied'
            separate = invoke('send-policy', 1, 'false', 'false', 4321)['position']
            assert await_value(lambda: invoke('control-disposition', separate))['outcome'] == 'policy_applied'
            separate = invoke('send-policy', 2, 'false', 'true', 4321)['position']
            assert await_value(lambda: invoke('control-disposition', separate))['outcome'] == 'policy_applied'
            invoke('prepare-send', 2, 2, 10, other)
            accepted = invoke('submit-send')['position']
            status = await_value(lambda: invoke('status'))
            assert status['outcome'] == 'applied' and status['input'] == accepted
            (root / 'prepared.json').write_bytes(rejected_prepared)
            assert invoke('input-disposition', rejected) == denied_status
            # Administrative control survives self-revocation, while result
            # disclosure and creation remain independently denied.
            revoked = invoke('send-policy', 4, 'false', 'false')['position']
            await_value(lambda: invoke('observe-control', revoked) == 'processed')
            invoke('control-disposition', revoked, error='CatalogDenied')
            invoke('prepare-send', 3, 3, 11, statement.replace('items', 'hidden'), error='CatalogDenied')
            duplicate = invoke('send-initialize')['position']
            await_value(lambda: invoke('observe-control', duplicate) == 'processed')
            invoke('control-disposition', duplicate, error='CatalogDenied')
            restored = invoke('send-policy', 5, 'true', 'true')['position']
            await_value(lambda: invoke('observe-control', restored) == 'processed')
            assert await_value(lambda: invoke('control-disposition', restored))['outcome'] == 'policy_applied'
            duplicate = invoke('send-policy', 5, 'true', 'true')['position']
            assert await_value(lambda: invoke('control-disposition', duplicate))['outcome'] == 'policy_applied'
            invoke('send-policy', 4, 'false', 'false', error='CatalogPolicyConflict')
            connection = dict(scope=dict(realm=46, resource=host_config['writer']['resource'], catalog=str(maximum)),
                              owner=host_config['writer']['pid'], principal=1234)
            check_profiles(port_host, root, proxy_url, connection)
            caller_results = []
            factories = [('abi', lambda: Native(library, proxy_url, connection)),
                         ('port', lambda: Port(port_host, root, proxy_url, connection)),
                         ('cli', lambda: Cli(cli, root, proxy_url, connection))]
            factories += [(name, lambda factory=factory: factory(proxy_url, connection, root)) for name, factory in installed]
            for index, (name, factory) in enumerate(factories):
                client = factory()
                clients.append(client)
                client_names[id(client)] = name
                caps = client.call({'capabilities': {}})['capabilities']
                assert caps['definition'] == definition.hex() and caps['create_table'] and caps['conditional_policy']
                description = client.call({'describe': {}})['description']
                assert description['configuration']['scope'] == connection['scope'] and description['policy']['revision'] == '5'
                for invalid_sql, code, column, offset in (
                    ('CREATE TABLE items (id UTF8 NOT NULL,value UTF8 NULL)', 'sql.unsupported_table_key', 'id', 20),
                    ('CREATE TABLE items (id INT64 NOT NULL,id UTF8 NULL)', 'sql.duplicate_column', 'id', 38),
                ):
                    try: client.call({'compile':dict(operation='1',object='1',table=1,sql=invalid_sql)})
                    except Failure as error:
                        diagnostic = error.detail['diagnostic']
                        assert error.status == 1 and not error.detail.get('diagnostic_invalid',False), (name,error)
                        assert diagnostic['code'] == code and diagnostic['outcome'] == 'not_submitted', (name,diagnostic)
                        assert diagnostic['location']['offset'] == str(offset)
                        assert diagnostic['facts'][0]['field'] == 'column' and diagnostic['facts'][0]['value'] == {'text':column}
                        assert [action['kind'] for action in diagnostic['actions'] if action] == ['correct_input']
                    else: raise AssertionError('Catalog compiler accepted an invalid declaration')
                # JSON type rejection belongs to ABI/port; CLI argument/artifact
                # types and offline rejection are covered by cli_diagnostics.py.
                invalid_actions = [] if name not in ('abi', 'port') else [
                    {'compile': dict(operation=maximum, object='1', table=1, sql=statement)},
                    {'compile': dict(operation='1', object='1', table='1', sql=statement)},
                    {'lookup': 'bad name'},
                    {'definition': dict(object=maximum, revision='1')},
                    {'definition': dict(object='01', revision='1')},
                    {'list': dict(scope=connection['scope'], resource_revision=1, after='items')},
                    {'list': dict(definition='0' * 64, scope=connection['scope'], resource_revision=1, after='items')},
                    {'submit': '{}'}]
                for invalid in invalid_actions:
                    try:
                        client.call(invalid)
                        raise AssertionError('Catalog caller accepted malformed input')
                    except Failure as error:
                        assert error.status == 1, error
                control = client.call({'prepare_initialize': dict(scope=connection['scope'], owner=connection['owner'], administrator=1234)})['prepared']
                position = client.call({'submit': control})['receipt']['position']
                assert await_value(lambda: client.call({'input_disposition': dict(prepared=control, input=position)})['disposition'])['outcome'] == 'initialized'
                control = client.call({'prepare_policy': dict(expected_revision='0', policy=dict(scope=connection['scope'], principal=6000 + index, revision='1', inspect=True, create=False))})['prepared']
                position = client.call({'submit': control})['receipt']['position']
                assert await_value(lambda: client.call({'input_disposition': dict(prepared=control, input=position)})['disposition'])['outcome'] == 'policy_applied'
                sql_name = name + '_items' if name in ('abi', 'port', 'cli') else f'sdk_{index}_items'
                identity = maximum - 100 - index
                table_id = 30 + index
                compiled = client.call({'compile': dict(operation=str(identity), object=str(identity), table=table_id, sql=statement.replace('items', sql_name))})['compiled']
                request = compiled['request']
                schema = b'TBL1\3\2id\5value'
                expected = (b'TCA1q' + definition + expected_scope + struct.pack('<QQI', identity, identity, table_id)
                            + bytes([len(sql_name)]) + sql_name.encode() + bytes([len(schema)]) + schema)
                assert compiled['canonical'] == expected.hex() and request['operation'] == str(identity)
                prepared = client.call({'prepare_create': request})['prepared']
                saved = root / f'{name}-prepared.json'
                saved.write_text(prepared)
                fault = faults[name + '_create']
                fault['lose'] = True
                try:
                    client.call({'submit': prepared})
                    raise AssertionError('Lost catalog receipt was reported as success')
                except Failure as error:
                    assert error.status == 6, error
                    diagnostic = error.detail['diagnostic']
                    assert diagnostic['code'] == 'catalog.send_unknown' and diagnostic['outcome'] == 'unknown', (name,diagnostic)
                    assert diagnostic['identity']['sequence'] == str(json.loads(prepared)['signed']['request']['sequence'])
                    assert [action['kind'] for action in diagnostic['actions'] if action] == ['inspect_status','resume_exact']
                if name == 'port':
                    client.crash()
                else:
                    client.close()
                stop_worker()
                restart()
                client = factory()
                clients.append(client)
                client_names[id(client)] = name
                prepared = saved.read_text()
                admitted = client.call({'submit': prepared})['receipt']
                assert admitted == json.loads(fault['receipt']) and fault['recovered']
                invoke('reown')
                invoke('write-host')
                start_worker()
                position = admitted['position']
                await_value(lambda: client.call({'observe': dict(prepared=prepared, input=position)})['observation'] == 'processed')
                status = client.call({'status': request})['status']
                assert status['outcome'] == 'applied' and status['request'] == request and status['input'] == position
                assert client.call({'input_disposition': dict(prepared=prepared, input=position)})['disposition'] is None
                caller_results.append((client, request, status))
            # Revoke native read rights after the list's initial policy/name
            # reads but before its dependent definition batch reaches authority.
            metadata_gate['armed'] = True
            with ThreadPoolExecutor(max_workers=1) as executor:
                blocked_read = executor.submit(invoke, 'list', error='AccessDenied')
                try:
                    assert metadata_entered.wait(5), 'Signed list did not reach its dependent batch'
                    invoke('revoke-reader')
                finally:
                    metadata_release.set()
                blocked_read.result(timeout=15)
            invoke('restore-reader')
            assert any(invoke('list')['entries'])
            report['revoked_during_metadata_read'] = True
            # Native transports and all typed SDK metadata callers share this history.
            metadata_surfaces = {'abi', 'port', 'cli', 'python-sync', 'python-async', 'node', 'rust', 'ruby', 'c', 'cpp', 'java', 'dotnet', 'erlang', 'elixir'}
            metadata_clients = [(name, result[0]) for (name, _), result in zip(factories, caller_results) if name in metadata_surfaces]
            report['metadata_surfaces'] = [name for name, _ in metadata_clients]
            def metadata_call(name, client, action, expected_error=None):
                before = counts['caller_reads']
                began = time.monotonic()
                try:
                    result = client.call(action)
                    assert expected_error is None, 'Metadata caller accepted a rejected read'
                    return result
                except Failure as error:
                    assert expected_error is not None and error.status == expected_error, error
                finally:
                    operation = next(iter(action))
                    reads = counts['caller_reads'] - before
                    metadata_measurements.append(dict(surface=name, operation=operation, expected_error=expected_error,
                        reads=reads, seconds=round(time.monotonic() - began, 6)))
                    if operation == 'list' and expected_error is None:
                        assert reads <= 5, 'Neutral catalog page exceeded its signed read budget'
            retained_pages = []
            growth_started = time.monotonic()
            growth_baseline = dict(counts=counts.copy(), upstream_operations=metrics())
            record()
            for index in range(growth):
                growing = caller_results[0][0]
                name = f'grow_{index:05}'
                identity = maximum - 10000 - index
                compiled = growth_phase(index, 'compile', lambda: growing.call({'compile': dict(operation=str(identity), object=str(identity), table=1000 + index, sql=statement.replace('items', name))})['compiled'])
                command = growth_phase(index, 'prepare', lambda: growing.call({'prepare_create': compiled['request']})['prepared'])
                position = growth_phase(index, 'admit', lambda: growing.call({'submit': command})['receipt']['position'])
                def growth_status():
                    nonlocal node
                    if initial_node and index == 138 and recovery_ready.is_set() and not recovery_finished.is_set():
                        # Keep the worker and its exact uncertain turn alive.
                        # Only the authority binary changes across disk restart;
                        # the admitted SQL input is never submitted again.
                        sends = metrics()['caller:send']['attempts']
                        recovery.update(input=position, index=index)
                        node = target_node
                        restart()
                        recovery['restarted'] = True
                        recovery_finished.set()
                        assert metrics()['caller:send']['attempts'] == sends
                    return growing.call({'status': compiled['request']})['status']
                result = growth_phase(index, 'await_application', lambda: await_value(growth_status))
                assert result['outcome'] == 'applied' and result['input'] == position
                if initial_node and index == 138:
                    assert recovery_finished.is_set() and recovery['receipt'] is not None
                grown_names.append(name)
                growth_current = None
                if (index + 1) % 16 == 0 or index + 1 == growth:
                    growth_samples.append(dict(tables=index + 1, seconds=round(time.monotonic() - growth_started, 3), counts=counts.copy(), phases=copy.deepcopy(growth_phases), upstream_operations=metrics()))
                    record()
                if index == 8:
                    assert invoke('list')['next'] is not None
                    for name, client in metadata_clients:
                        cursor = metadata_call(name, client, {'list': None})['page']['next']
                        assert cursor is not None
                        retained_pages.append((name, client, cursor))
                if index == 9:
                    invoke('list', 'continue', error='CatalogCursorChanged')
                    for name, client, cursor in retained_pages:
                        metadata_call(name, client, {'list': cursor}, 5)
            def listed():
                page = invoke('list')
                revision = page['resource_revision']
                entries = []
                while True:
                    assert page['resource_revision'] == revision
                    present = [entry for entry in page['entries'] if entry is not None]
                    assert page['entries'] == present + [None] * (8 - len(present))
                    entries.extend(present)
                    if page['next'] is None: break
                    invoke('list', 'stale', error='CatalogCursorChanged')
                    invoke('list', 'foreign', error='CatalogScopeChanged')
                    page = invoke('list', 'continue')
                names = [entry['name']['bytes'][:entry['name']['len']] for entry in entries]
                assert names == sorted(set(names)), names
                for name, entry in zip(names, entries):
                    assert invoke('lookup', name) == entry
                    assert invoke('definition', entry['object'], entry['revision']) == entry
                assert invoke('lookup', 'absent') is None
                assert invoke('definition', maximum - 9999, 1) is None
                def neutral(entry):
                    result = copy.deepcopy(entry)
                    result['scope']['catalog'] = str(result['scope']['catalog'])
                    for field in ('object', 'revision', 'operation'): result[field] = str(result[field])
                    result['name'] = result['name']['bytes'][:result['name']['len']]
                    schema = result['source']['table']['schema']
                    assert schema.pop('version') == 1
                    schema['names'] = [column['bytes'][:column['len']] for column in schema['names']]
                    return result
                expected = [neutral(entry) for entry in entries]
                for name, client in metadata_clients:
                    page = metadata_call(name, client, {'list': None})['page']
                    actual = []
                    while True:
                        assert page['resource_revision'] == revision
                        present = [entry for entry in page['entries'] if entry is not None]
                        assert page['entries'] == present + [None] * (8 - len(present))
                        actual.extend(present)
                        cursor = page['next']
                        if cursor is None: break
                        assert cursor['definition'] == definition.hex() and cursor['scope'] == connection['scope']
                        assert cursor['resource_revision'] == revision and cursor['after'] == present[-1]['name']
                        stale = dict(cursor, resource_revision=revision - 1)
                        metadata_call(name, client, {'list': stale}, 5)
                        foreign = dict(cursor, scope=dict(cursor['scope'], catalog='1'))
                        metadata_call(name, client, {'list': foreign}, 5)
                        page = metadata_call(name, client, {'list': cursor})['page']
                    assert actual == expected, (name, actual, expected)
                    for entry in expected:
                        assert metadata_call(name, client, {'lookup': entry['name']}) == dict(definition=entry)
                        assert metadata_call(name, client, {'definition': dict(object=entry['object'], revision=entry['revision'])}) == dict(definition=entry)
                    assert metadata_call(name, client, {'lookup': 'absent'}) == dict(definition=None)
                    assert metadata_call(name, client, {'definition': dict(object=str(maximum - 9999), revision='1')}) == dict(definition=None)
                return names
            expected_names = sorted(['items', 'other', *grown_names, *[request['name'] for _, request, _ in caller_results]])
            assert listed() == expected_names
            if growth:
                stop_worker()
                restart()
                assert listed() == expected_names
                invoke('reown')
                invoke('write-host')
                start_worker()
            # The SQL console publishes through the same catalog client. Its
            # query binding is explicit and independent of named publication.
            console_config = dict(version=1, profile='unified_v1', url=proxy_url, transport='loopback', seed_file='caller.seed', format='json',
                connection=dict(realm=46, principal=1234, source=connection['owner'], resource=connection['scope']['resource'], requester=connection['owner'], requests=connection['scope']['resource']),
                workspace=dict(name='items', source=dict(version=1, resource=connection['scope']['resource'], source=dict(table=dict(id=7, names=['id','value'], value_type='int64'))), limits=dict(pages='1000',segments='100',result_bytes='1048576')),
                writes=dict(recovery_file='console-writes.json', catalog=dict(connection, scope=dict(connection['scope'],catalog=maximum))))
            console_path = root/'console.json'
            console_path.write_text(json.dumps(console_config))
            def console_run(sql=None, data=None, code=0):
                args = [cli, 'console', '--no-rc', '--config', str(console_path)] + (['-c', sql] if sql is not None else [])
                result = subprocess.run(args, input=data, capture_output=True, text=True, timeout=45)
                assert result.returncode == code, (result.returncode, result.stdout, result.stderr)
                return result
            help_result = json.loads(console_run(data='.help CREATE TABLE\n').stdout)
            assert help_result['catalog_configured'] and not help_result['table_writer_configured']
            invalid = console_run('CREATE TABLE bad (id INT64, value INT64)', code=1)
            assert '.help CREATE TABLE' in invalid.stderr and not invalid.stdout
            faults['console_create']['lose'] = True
            lost = console_run('CREATE TABLE shell_items (id INT64 NOT NULL, value UTF8 NULL)', code=1)
            assert not lost.stdout and '.resume' in lost.stderr
            recovery_path = root/'console-writes.json'
            saved = recovery_path.read_bytes()
            saved_record = json.loads(saved)
            assert saved_record['operation']['creation']['pending']['signed'] == json.loads(faults['console_create']['body'])
            console_run(data='.help\n')
            assert not faults['console_create']['recovered'] and recovery_path.read_bytes() == saved
            console_run(data='.cancel\n', code=1)
            assert not faults['console_create']['recovered'] and recovery_path.read_bytes() == saved
            result = json.loads(console_run(data='.resume\n').stdout)['creation']
            assert result['phase'] == 'applied' and result['name'] == 'shell_items' and faults['console_create']['recovered']
            assert json.loads(console_run(data='.resume\n').stdout)['creation'] == result
            assert json.loads(console_run('DESCRIBE shell_items').stdout)['definition']['source']['table']['schema']['value_type'] == 'utf8'
            pages = [json.loads(line)['catalog_page'] for line in console_run('SHOW TABLES').stdout.splitlines()]
            assert pages[-1]['next'] is None
            expected_names = sorted([*expected_names, 'shell_items'])
            assert [entry['name'] for page in pages for entry in page['entries'] if entry] == expected_names
            duplicate = console_run('CREATE TABLE shell_items (id INT64 NOT NULL, value UTF8 NULL)', code=1)
            assert json.loads(duplicate.stdout)['creation']['phase'] == 'name_conflict'
            print('Console catalog: CREATE TABLE, exact lost-receipt recovery, explicit cancellation limit, DESCRIBE/SHOW TABLES and name conflicts passed.', flush=True)
            revoked = invoke('send-policy', 6, 'true', 'false')['position']
            await_value(lambda: invoke('observe-control', revoked) == 'processed')
            denied_console = console_run(data='.status\n', code=1)
            assert not denied_console.stdout and 'current writer or catalog policy' in denied_console.stderr
            invoke('list', error='CatalogDenied')
            invoke('lookup', 'items', error='CatalogDenied')
            invoke('definition', maximum, 1, error='CatalogDenied')
            for name, client in metadata_clients:
                for action in ({'list': None}, {'lookup': 'items'}, {'definition': dict(object=str(maximum), revision='1')}):
                    metadata_call(name, client, action, 4)
            for client, request, status in caller_results:
                try:
                    client.call({'status': request})
                    raise AssertionError('Revoked catalog inspection disclosed an earlier result')
                except Failure as error:
                    assert error.status == 4 and error.detail['err'] == 'CatalogDenied', error
            restored = invoke('send-policy', 7, 'true', 'true')['position']
            await_value(lambda: invoke('observe-control', restored) == 'processed')
            for client, request, status in caller_results:
                assert client.call({'status': request})['status'] == status
            invoke('revoke-reader')
            invoke('list', error='AccessDenied')
            invoke('lookup', 'items', error='AccessDenied')
            invoke('definition', maximum, 1, error='AccessDenied')
            for name, client in metadata_clients:
                for action in ({'list': None}, {'lookup': 'items'}, {'definition': dict(object=str(maximum), revision='1')}):
                    metadata_call(name, client, action, 4)
            invoke('input-disposition', rejected, error='AccessDenied')
            for client, request, _ in caller_results:
                try:
                    client.call({'status': request})
                    raise AssertionError('Revoked native reads disclosed an earlier result')
                except Failure as error:
                    assert error.status == 4, error
            stop_worker()
            assert not failures and all(f['recovered'] for f in faults.values())
            assert counts['max_mutations'] == 4 and counts['max_value_bytes'] <= 256
            if cold_store:
                assert cold_store.data_objects() > 0, 'Catalog history did not spill to cold storage'
            report.update(lost_caller_receipts=6 + len(installed), lost_writer_receipts=3, listed_definitions=len(expected_names))
        finally:
            failure = sys.exc_info()[1]
            metadata_release.set()
            cleanup_errors = []
            def cleanup(label, action):
                try:
                    action()
                except BaseException as error:
                    error.add_note(f'Catalog cleanup: {label}')
                    cleanup_errors.append(error)
            for client in clients:
                cleanup(client_names[id(client)], client.close)
            # A failed drain must not skip authority shutdown, final evidence or
            # private fixture retention. Killing the authority also releases any
            # proxy request still inside its bounded upstream wait.
            cleanup('worker and proxy drain', stop_worker)
            def stop_authority():
                if authority is not None:
                    if authority.poll() is None:
                        authority.kill()
                    authority.wait(timeout=10)
            cleanup('authority', stop_authority)
            cleanup('proxy shutdown', proxy.shutdown)
            cleanup('proxy handlers', proxy.server_close)
            def join_proxy():
                thread.join(timeout=10)
                assert not thread.is_alive(), 'Proxy thread did not join'
            cleanup('proxy thread', join_proxy)
            report['node_errors'] = diagnostic_errors(log)
            log.flush()
            log.seek(0)
            if sys.exc_info()[0]:
                sys.stderr.write(log.read()[-12000:])
                worker_log.flush()
                worker_log.seek(0)
                sys.stderr.write(worker_log.read()[-12000:])
            log.close()
            worker_log.close()
            report['storage'] = dict(cold=cold, hot_bytes_limit=(8 if cold else 64) * 1024 * 1024,
                                    cold_objects=cold_store.data_objects() if cold_store else 0,
                                    cold_file_bytes=cold_store.file_bytes() if cold_store else 0)
            def retain_fixture():
                # Retain the private failed fixture for accepted-work diagnosis,
                # after joining every owned process. This is not a passed proof.
                retain_recovery_fixture(fixture, cold_store, destination, recovery)
            if initial_node and (failure is not None or cleanup_errors):
                cleanup('private fixture retention', retain_fixture)
            report['cleanup_failures'] = [str(error) + ": " + ", ".join(error.__notes__) for error in cleanup_errors]
            record(failure is None and not cleanup_errors,
                   type(failure).__name__ if failure is not None else 'Cleanup' if cleanup_errors else None)
            print(json.dumps({key: value for key, value in report.items() if key not in ('growth_samples', 'growth_baseline', 'metadata_measurements', 'upstream_operations')}, indent=2))
            if cleanup_errors:
                raise ExceptionGroup('Catalog caller cleanup failed', cleanup_errors)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for binary in ('node', 'proof', 'catalog_host', 'port_host', 'library', 'cli'): parser.add_argument(binary)
    parser.add_argument('--sdk', choices=['python', 'node', 'rust', 'ruby', 'c', 'cpp', 'java', 'dotnet', 'erlang', 'elixir'], action='append', default=[])
    parser.add_argument('--grow', type=int, default=0)
    parser.add_argument('--cold', action='store_true', help='use the owned S3 cold tier with an 8 MiB hot-store limit')
    parser.add_argument('--initial-node', type=Path,
                        help='start with an explicit pre-fix node; recover its repeated depth failure using the built node')
    args = parser.parse_args()
    run(args.node, args.proof, args.catalog_host, args.port_host, args.library, args.cli, args.sdk, args.grow, args.initial_node, args.cold)

"""Real catalog Table creation, exact receipt recovery and native fencing."""
import argparse
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
from catalog_abi import Native, Port, Failure, check_profiles
from catalog_cli import Cli

ROOT = Path(__file__).resolve().parents[1]


def run(node, proof, catalog_host, port_host, library, cli, languages=()):
    started = time.monotonic()
    counts = dict(reads=0, turns=0, max_mutations=0, max_value_bytes=0)
    with Fixture() as fixture:
        root = fixture.root
        installation_started = time.monotonic()
        installed = []
        if languages:
            from sdk_catalog import install
            installed = install(root / 'catalog-sdks', languages)
        install_seconds = round(time.monotonic() - installation_started, 3)
        for name, binary in [('node', node), ('proof', proof), ('host', catalog_host), ('port', port_host), ('library.so', library), ('cli', cli)]:
            shutil.copy2(binary, root / name)
        node, proof = str(root / 'node'), str(root / 'proof')
        catalog_host = str(root / 'host')
        port_host, library = str(root / 'port'), str(root / 'library.so')
        cli = str(root / 'cli')
        clients = []
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
        for name in ['abi_create', 'port_create', 'cli_create', *[name + '_create' for name, _ in installed]]:
            faults[name] = dict(command='send', lose=False, body=None, receipt=None, recovered=False)
        for name in ('host_initialize', 'host_create'):
            faults[name] = dict(command='turn', lose=False, body=None, receipt=None, recovered=False, blocked=False)
        failures = []
        active = 0
        active_lock = threading.Lock()

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                nonlocal active
                with active_lock:
                    active += 1
                body = self.rfile.read(int(self.headers['Content-Length']))
                connection = HTTPConnection('127.0.0.1', port, timeout=15)
                try:
                    envelope = json.loads(body)
                    if self.path == '/v1/query':
                        counts['reads'] += 1
                    if any(f.get('blocked') and body == f['body'] for f in faults.values()):
                        self.send_response(503)
                        self.send_header('Content-Length', '2')
                        self.end_headers()
                        self.wfile.write(b'{}')
                        return
                    connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    data = response.read()
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

        def invoke(mode, *args, error=None):
            result = subprocess.run([proof, proxy_url, mode, str(root), *map(str, args)], capture_output=True, text=True, timeout=60)
            if error:
                assert result.returncode != 0 and error in result.stderr, (mode, error, result.stdout, result.stderr)
                return None
            assert result.returncode == 0, (mode, result.stderr)
            return json.loads(result.stdout)

        def absent():
            snapshot = invoke('snapshot')
            assert snapshot['entries'] == [None] * 4, snapshot
            return snapshot

        maximum = 2**64 - 1
        statement = 'CREATE TABLE items (id INT64 NOT NULL,value UTF8 NULL)'
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
                caps = client.call({'capabilities': {}})['capabilities']
                assert caps['definition'] == definition.hex() and caps['create_table'] and caps['conditional_policy']
                description = client.call({'describe': {}})['description']
                assert description['configuration']['scope'] == connection['scope'] and description['policy']['revision'] == '5'
                # JSON type rejection belongs to ABI/port; CLI argument/artifact
                # types and offline rejection are covered by cli_diagnostics.py.
                invalid_actions = [] if name not in ('abi', 'port') else [
                    {'compile': dict(operation=maximum, object='1', table=1, sql=statement)},
                    {'compile': dict(operation='1', object='1', table='1', sql=statement)},
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
                if name == 'port':
                    client.crash()
                else:
                    client.close()
                stop_worker()
                restart()
                client = factory()
                clients.append(client)
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
            revoked = invoke('send-policy', 6, 'true', 'false')['position']
            await_value(lambda: invoke('observe-control', revoked) == 'processed')
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
            report = dict(version=1, revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                          dirty=bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True)),
                          seconds=round(time.monotonic() - started, 3), resident_pages=8, counts=counts,
                          lost_caller_receipts=5 + len(installed), lost_writer_receipts=3,
                          selected_sdks=list(languages), sdk_install_seconds=install_seconds,
                          sdk_artifacts={language: json.loads((root / 'catalog-sdks' / language / 'artifacts.json').read_text()) for language in languages},
                          binaries={name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in ('node', 'proof', 'host', 'port', 'library.so', 'cli')})
            destination = ROOT / '.cache/verification/catalog/native.json'
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps(report, indent=2))
        finally:
            cleanup_errors = []
            for client in clients:
                try:
                    client.close()
                except BaseException as error:
                    cleanup_errors.append(error)
            stop_worker()
            if authority is not None:
                authority.kill()
                authority.wait(timeout=10)
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=10)
            log.flush()
            log.seek(0)
            if sys.exc_info()[0]:
                sys.stderr.write(log.read()[-12000:])
                worker_log.flush()
                worker_log.seek(0)
                sys.stderr.write(worker_log.read()[-12000:])
            log.close()
            worker_log.close()
            if cleanup_errors:
                raise ExceptionGroup('Catalog caller cleanup failed', cleanup_errors)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for binary in ('node', 'proof', 'catalog_host', 'port_host', 'library', 'cli'): parser.add_argument(binary)
    parser.add_argument('--sdk', choices=['python', 'node', 'rust'], action='append', default=[])
    args = parser.parse_args()
    run(args.node, args.proof, args.catalog_host, args.port_host, args.library, args.cli, args.sdk)

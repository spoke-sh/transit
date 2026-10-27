"""A public-SDK ring: every target is service and requester for a foreign peer."""
from runner.paths import ROOT
from harness.phases import phase
from contextlib import ExitStack
from datetime import datetime, timezone
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import os
import platform
from sdk.consumer_registry import RUNNERS
import json
from pathlib import Path
import select
import math
import struct
import subprocess
import sys
import tempfile
import threading
import time
from sdk.client_abi import Native
from sdk.client_abi_growing import GrowingSystem
from storage.providers.cold_storage import ColdStore
from query.arrow.fuze_logical_arrow import arrow_cell, read_stream
from query.files.fuze_file_query import descriptor, cell_bytes
from runtime.station.station import frame
from sdk.sdk_scenarios import check


@phase("schedule", "sdk-interop")
def run(node, cli, library, artifacts, report_path=None):
    started = time.monotonic()
    artifacts = Path(artifacts).resolve()
    with ColdStore() as cold, ExitStack() as stack:
        # The complete nested-Arrow ring retains more than the hot-only store's
        # finite capacity. Flush to owned disk-backed cold storage while keeping
        # both the provider hot cache and authority page cache bounded.
        fixture = GrowingSystem(node, cli, storage_config=cold.config())
        fixture.resident_pages = 64
        system = stack.enter_context(fixture)
        clients = []
        def install(_node, _cli, _library, installer, label):
            target = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix='transit-public-pair-')))
            clients.append((label, target, installer(target)))
        for language, folder in (('python', 'wheels'), ('node', 'node'), ('rust', 'rust'), ('ruby', 'ruby'),
                                 ('c', 'c'), ('java', 'java'), ('dotnet', 'dotnet'), ('beam', 'beam')):
            with phase("consumer-install", f"interop-{language}"):
                RUNNERS[language](node, cli, library, artifacts / folder, execute=install)
        installed_at = time.monotonic()
        fault = {'pid': None, 'lost': 0, 'reader': None, 'unavailable_reads': 0,
                 'drop_delivery': True, 'delivery_lost': 0}
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                # Reject raw double slashes rather than letting the HTTP
                # handler's normalized path conceal a native URL-joining bug.
                path = self.requestline.split()[1]
                if path not in ('/v1/command', '/v1/query', '/v1/blocks'):
                    self.send_error(400)
                    return
                body = self.rfile.read(int(self.headers['Content-Length']))
                envelope = json.loads(body)
                if fault['reader'] is not None and envelope.get('query', {}).get('principal') == fault['reader']:
                    fault['reader'] = None
                    fault['unavailable_reads'] += 1
                    data = b'{"err":"AuthorityUnavailable"}'
                    self.send_response(503)
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                    return
                command = envelope.get('request', {}).get('command', {})
                turn = command.get('turn', command.get('turn_with_versions', {}).get('turn', {}))
                connection = HTTPConnection('127.0.0.1', system.port, timeout=15)
                try:
                    connection.request('POST', path, body, {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    data = response.read()
                    if response.status == 200 and fault['drop_delivery'] and 'deliver' in command:
                        fault['drop_delivery'] = False
                        fault['delivery_lost'] += 1
                        self.close_connection = True
                        return
                    if response.status == 200 and fault['pid'] is not None and turn.get('pid') == fault['pid']:
                        fault['pid'] = None
                        fault['lost'] += 1
                        self.close_connection = True
                        return
                    self.send_response(response.status)
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                except (BrokenPipeError, ConnectionResetError): pass
                finally: connection.close()
        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        def close_proxy():
            proxy.shutdown(); proxy.server_close(); thread.join(timeout=5)
        stack.callback(close_proxy)
        native = Native(library)
        admin = native.client(f'http://127.0.0.1:{proxy.server_port}', timeout_ms=15000)
        stack.callback(native.lib.transit_client_destroy, admin)
        seed = bytes.fromhex(system.seed.read_text().strip())
        sequence, principal, after = 0, 65536, None
        admin_retries = 0
        def exchange(operation):
            nonlocal admin_retries
            frozen = native.export(operation)
            deadline = time.monotonic() + 30
            while True:
                status, result = native.exchange(admin, operation)
                assert native.export(operation) == frozen
                if status == 0: return result
                assert (status in (6, 7) and result.get('err') in
                        ('AuthorityUnavailable', 'AuthorityTimeout', 'HttpConnectionClosing')
                        and time.monotonic() < deadline), (status, result)
                admin_retries += 1
                time.sleep(.1)
        def command(body):
            nonlocal sequence
            sequence += 1
            operation = native.prepare(6, seed, {'realm': 72, 'principal': 0, 'sequence': sequence, 'command': body})
            try: return exchange(operation)['position']
            finally: native.lib.transit_operation_destroy(operation)
        def read(kind):
            operation = native.prepare(7, seed, {'realm': 72, 'principal': 0, 'kind': kind})
            try: return exchange(operation)
            finally: native.lib.transit_operation_destroy(operation)
        def provision(client, role):
            nonlocal principal
            _, target, _ = client
            principal += 1
            pid = command({'spawn': {}})
            key, public = system.key(f'interop-{principal}')
            command({'grant': {'subject': principal, 'public_key': public, 'permissions': 88, 'pid': pid}})
            resource = command({'create_resource': {'writer': pid}})
            for subject in (0, principal): command({'grant_resource': {'resource': resource, 'subject': subject, 'permissions': 7}})
            command({'associate': {'pid': pid, 'name': b'data'.hex(), 'resource': resource}})
            command({'own': {'pid': pid, 'worker': principal, 'expected_generation': 1}})
            output = target / f'output-{pid}'
            output.mkdir()
            return {'url': f'http://127.0.0.1:{proxy.server_port}/', 'realm': 72, 'principal': principal, 'pid': pid, 'generation': 2,
                    'seed_file': str(key), 'profile': 'native_v1', 'peer': pid, 'role': role, 'resource': resource,
                    'pending': str(target / f'pending-{pid}'), 'output': str(output), 'fixtures': str(target / 'unused.json'),
                    'query_results': role in ('table', 'query'), 'work_before_ms': None, 'arrow_adapter': False}
        def config(client, cfg):
            path = client[1] / f"config-{cfg['pid']}.json"
            path.write_text(json.dumps(cfg))
            return path
        def example(client, cfg, role):
            consumer = client[2]
            subprocess.run(consumer.cli(config(client, cfg), role), env=consumer.environment, cwd=client[1],
                           check=True, timeout=60, stdout=subprocess.DEVNULL)
        def own(cfg):
            command({'own': {'pid': cfg['pid'], 'worker': cfg['principal'], 'expected_generation': cfg['generation']}})
            cfg['generation'] += 1
        def send(cfg, payload): return command({'send': {'pid': cfg['pid'], 'value': frame(payload)}})
        def deliver():
            nonlocal after
            position = read({'capabilities': {}})['position']
            batch = read({'outputs': {'after': after, 'position': position}})['body']['outputs']
            for value in batch['entries']:
                if value:
                    if value['phase'] == 'pending': command({'deliver': value['id']})
                    after = value['id']
        children = []
        reconciliations = 0
        read_retries = 0
        def worker(client, cfg):
            consumer = client[2]
            child = subprocess.Popen(consumer.command('worker', config(client, cfg)), cwd=client[1], env=consumer.environment,
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
            children.append(child)
            child.stdin.write('ready\n'); child.stdin.flush()
            assert select.select([child.stdout], [], [], 90)[0], 'Public worker did not open'
            assert json.loads(child.stdout.readline()) == {'ready': True}
            return child
        def one(child):
            nonlocal reconciliations, read_retries
            action, deadline = 'one', time.monotonic() + 90
            while True:
                child.stdin.write(action + '\n'); child.stdin.flush()
                assert select.select([child.stdout], [], [], max(0, deadline-time.monotonic()))[0], 'Public mixed-language runner timed out'
                line = child.stdout.readline()
                assert line, f'Public worker exited with {child.poll()}'
                result = json.loads(line)
                if result['event'] in ('Committed', 'Idle'): return result['event']
                if result['event'] == 'ReadUnavailable':
                    assert result.get('code') in ('AuthorityUnavailable', 'AuthorityTimeout', 'HttpConnectionClosing') and time.monotonic() < deadline, result
                    read_retries += 1
                    time.sleep(.1)
                    continue
                assert (result['event'] == 'NeedsRecovery' and result.get('phase') in ('dispatch', 'observe-confirmation', 'observe_confirmation')
                        and result.get('code') in ('AuthorityUnavailable', 'AuthorityTimeout', 'HttpConnectionClosing')
                        and time.monotonic() < deadline), result
                # Each installed consumer checks its pending bytes against the
                # saved file. Reconcile the paused runner; never open a new turn
                # or rebuild a command after an uncertain dispatch.
                reconciliations += 1
                action = 'reconcile'
                time.sleep(.1)
        def close(child):
            child.stdin.write('close\n'); child.stdin.flush()
            assert json.loads(child.stdout.readline()) == {'closed': True}
            child.stdin.close()
            assert child.wait(timeout=15) == 0
            child.stdout.close()
            children.remove(child)
        def cleanup():
            for child in children:
                child.kill(); child.wait(timeout=10)
        stack.callback(cleanup)
        def state_value(cfg, key):
            revision = read({'resource': cfg['resource']})['body']['resource']['revision']
            entries = read({'entries': {'resource': cfg['resource'], 'revision': revision, 'key': key.hex()}})['body']['entries']['page']['entries']
            return next((bytes.fromhex(entry['value']) for entry in entries if entry and bytes.fromhex(entry['key']) == key), None)
        def drain_table(cfg, child, operations):
            deadline = time.monotonic() + 600
            for turns in range(4096):
                meta = state_value(cfg, b'table.queue')
                assert meta and len(meta) == 21 and meta[:4] == b'TQM\x01'
                if meta[4:] == bytes(16) + b'\1': break
                assert time.monotonic() < deadline, 'Cross-language Table queue deadline'
                deliver(); one(child)
            else: raise AssertionError('Cross-language Table queue turn budget')
            previous = 0
            for identity, state in [(2**64-1, 0), *[(identity, 1) for identity in operations]]:
                raw = state_value(cfg, f'table.done.{identity:016x}'.encode())
                assert raw and len(raw) == 38 and raw[:4] == b'TQO\x01'
                actual, admitted, completed, matched, changed, rejection = struct.unpack('<BQQQQB', raw[4:])
                assert (actual, matched, changed, rejection) == (state, state, state, 0)
                assert 0 < admitted <= completed and previous < completed
                assert state_value(cfg, f'table.work.{identity:016x}'.encode()) is None
                previous = completed
            return turns
        pairs, timings = [], []
        for index, service in enumerate(clients):
            with phase("scenario", f"interop-pair-{index}"):
                pair_started = time.monotonic()
                requester = clients[(index + 1) % len(clients)]
                source, destination = provision(service, 'service'), provision(requester, 'requester')
                destination['peer'] = source['pid']
                send(source, b'TSC\x01\x01' + (2**64-1).to_bytes(8, 'little'))
                example(service, source, 'service')
                send(destination, b'TSC\x01\x03')
                example(requester, destination, 'requester')
                own(source); own(destination); deliver()
                example(service, source, 'service'); deliver()
                example(requester, destination, 'requester')
                revision = read({'resource': destination['resource']})['body']['resource']['revision']
                page = read({'entries': {'resource': destination['resource'], 'revision': revision, 'key': b'observed'.hex()}})['body']['entries']['page']
                observed = next(entry for entry in page['entries'] if entry)
                assert bytes.fromhex(observed['value']) == b'TSU\x01' + (2**64-1).to_bytes(8, 'little')
                assert read({'process': destination['pid']})['body']['process']['process']['consumed'] == 2
                table, query = provision(service, 'table'), provision(requester, 'query')
                table['peer'], query['peer'] = query['pid'], table['pid']
                server, caller = worker(service, table), worker(requester, query)
                before_recovery = reconciliations
                before_read_retry = read_retries
                fault['pid'] = table['pid']
                fault['reader'] = table['principal']
                expected = [{'id': -(2**63), 'value': None}, {'id': 0, 'value': 2**53+1}, {'id': 2**63-1, 'value': -(2**63)}]
                operations = []
                # First DML creates a durable automatic schema entry; no explicit
                # Initialize command or host-memory initialization performs the work.
                for row in expected:
                    payload = b'TSQ\x01\x02' + row['id'].to_bytes(8, 'little', signed=True)
                    payload += b'\0' if row['value'] is None else b'\1' + row['value'].to_bytes(8, 'little', signed=True)
                    operations.append(send(table, payload)); assert one(server) == 'Committed'
                assert fault['pid'] is None and reconciliations > before_recovery
                assert fault['reader'] is None and read_retries > before_read_retry
                send(query, b'TSQ\x01\x04'); assert one(caller) == 'Committed'
                for _ in range(32):
                    deliver(); one(server); one(caller)
                    busy = state_value(query, b'not-ready')
                    if busy is not None:
                        assert busy == state_value(query, b'request')
                        break
                else: raise AssertionError('Foreign requester did not authenticate busy reply')
                close(server); own(table); server = worker(service, table)
                table_turns = drain_table(table, server, operations)
                close(caller); own(query); caller = worker(requester, query)
                send(query, b'TSQ\x01\x04'); assert one(caller) == 'Committed'
                manifest_file = Path(query['output'], 'manifest.json')
                fragments = math.ceil(65535 / 221)
                round_budget = 2 * (fragments + math.ceil(fragments / 3) + 8) + 16
                deadline = time.monotonic() + 600
                for query_round in range(round_budget):
                    assert time.monotonic() < deadline, 'Cross-language query deadline'
                    deliver()
                    assert one(server) in ('Committed', 'Idle')
                    assert one(caller) in ('Committed', 'Idle')
                    if manifest_file.exists(): break
                else: raise AssertionError('Cross-language query did not complete')
                close(server); close(caller)
                manifest = json.loads(manifest_file.read_bytes())
                assert (manifest['rows'], manifest['source'], manifest['destination'], manifest['resource']) == (3, table['pid'], query['pid'], table['resource'])
                segments = [Path(query['output'], f'{i}.arrow').read_bytes() for i in range(manifest['segments'])]
                types = [{'int64': {}}, {'int64': {}}, {'utf8': {}}, {'list': {'type': {'int64': {}}, 'nullable': False}}]
                actual = []
                for ipc in segments:
                    schema, batches = read_stream(ipc)
                    assert schema.names == ['id', 'value', 'label', 'tags']
                    fields = [{'name': name, 'type': typ, 'nullable': name == 'value', 'optional': False} for name, typ in zip(schema.names, types)]
                    assert schema.metadata[b'transit.logical_schema'] == descriptor({'structure': fields}).hex().encode()
                    for batch in batches:
                        actual.extend([[arrow_cell(batch.column(column), row, typ) for column, typ in enumerate(types)] for row in range(batch.num_rows)])
                def signed(value): return {'value': {'atom': {'signed': str(value)}}}
                expected_cells = [[signed(row['id']), {'null': {}} if row['value'] is None else signed(row['value']),
                    {'value': {'atom': {'utf8': 'example'}}}, {'value': {'list': [signed(1), signed(2)]}}] for row in expected]
                assert actual == [[cell_bytes(cell, typ) for cell, typ in zip(row, types)] for row in expected_cells]
                assert sum(map(len, segments)) == manifest['bytes']
                pair = f'{service[0]} -> {requester[0]}'
                pairs.append(pair)
                timings.append({'pair': pair, 'elapsed_seconds': round(time.monotonic()-pair_started, 3), 'table_drain_turns': table_turns, 'query_rounds': query_round + 1, 'ipc_bytes': manifest['bytes']})
                print(f'Public pair {pair}: installed CLIs, restarted durable reply, lost-receipt reconciliation, automatic schema creation, queued Table recovery, authenticated busy reply and owned nested IPC passed.', flush=True)
        assert fault['lost'] == fault['unavailable_reads'] == len(clients)
        assert fault['delivery_lost'] == 1 and admin_retries > 0
        assert cold.data_objects() > 0
        check('public-language-ring', {'pairs': pairs, 'reply_value': str(2**64-1), 'query_rows_per_pair': 3,
                                      'fresh_requesters': True, 'owned_ipc_after_close': not children})
        elapsed = time.monotonic()-started
        if report_path:
            sources = [Path(__file__), *[ROOT / 'tests/sdk/consumers' / name / f'{name}_station_sdk.py' for name in ('python', 'node', 'rust', 'ruby', 'c', 'java', 'dotnet', 'beam')]]
            report = {'version': 1, 'status': 'passed', 'recorded_at': datetime.now(timezone.utc).isoformat(),
                      'environment': {'platform': platform.system(), 'architecture': platform.machine(), 'available_cpus': len(os.sched_getaffinity(0)), 'authority_cpus': len(os.sched_getaffinity(system.authority.pid)), 'admin_timeout_ms': 15000},
                      'source_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                      'proof_sha256': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources},
                      'elapsed_seconds': round(elapsed, 3), 'consumer_install_seconds': round(installed_at-started, 3), 'pairs': timings,
                      'reconciled_transient_results': reconciliations,
                      'injected_lost_receipts': fault['lost'],
                      'transient_read_retries': read_retries, 'injected_unavailable_reads': fault['unavailable_reads'],
                      'admin_exact_retries': admin_retries, 'injected_lost_delivery_receipts': fault['delivery_lost'],
                      'storage': {'hot_bytes_limit': 8 * 1024 * 1024, 'resident_pages': fixture.resident_pages,
                                  'cold_objects': cold.data_objects(), 'cold_file_bytes': cold.file_bytes()},
                      'limits': 'Local consumer installation and ten counter/query pairs. Excludes artifact builds, CI setup/cache transfer, and other SDK failure suites. Not a hosted CI budget measurement.'}
            Path(report_path).parent.mkdir(parents=True, exist_ok=True)
            Path(report_path).write_text(json.dumps(report, indent=2) + '\n')
        print(f'Public SDK ring: {len(pairs)} counter/query pairs passed in {time.monotonic()-started:.1f}s including clean consumer installation.', flush=True)


if __name__ == '__main__': run(*sys.argv[1:])

"""Shared real-authority schedule for installed public Station runners."""
from dataclasses import dataclass
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import select
import shutil
import subprocess
import tempfile
import threading
import time
from typing import Callable


@dataclass
class Consumer:
    environment: dict[str, str]
    command: Callable[[str, Path], list]
    cli: Callable[[Path, str], list]
    invalid_handler: str
    extra_failures: tuple[str, ...] = ()


def run(node, cli, raw_library, install, label):
    from client_abi_growing import GrowingSystem
    from client_abi import Native
    from station import frame
    from sdk_scenarios import check
    root = Path(__file__).resolve().parents[1]
    fixture = GrowingSystem(node, cli)
    fixture.resident_pages = 64
    with tempfile.TemporaryDirectory(prefix='transit-station-consumer-') as temporary, fixture as system:
        target = Path(temporary)
        consumer = install(target)
        env = consumer.environment
        codec_fixture = target / 'codecs.json'
        shutil.copyfile(root / 'tests/verification/sdk-codecs-v1.json', codec_fixture)
        native = Native(raw_library)
        admin = native.client(system.url)
        private = bytes.fromhex(system.seed.read_text().strip())
        sequence, principal = 0, 65536
        def command(body):
            nonlocal sequence
            sequence += 1
            op = native.prepare(6, private, {'realm': 72, 'principal': 0, 'sequence': sequence, 'command': body})
            try: return native.call(admin, op)['position']
            finally: native.lib.transit_operation_destroy(op)
        def read(kind):
            op = native.prepare(7, private, {'realm': 72, 'principal': 0, 'kind': kind})
            try: return native.call(admin, op)
            finally: native.lib.transit_operation_destroy(op)
        fault = {'drop': False, 'delay': False, 'poison': False, 'commands': [], 'poisoned': False}
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                conn = HTTPConnection('127.0.0.1', system.port, timeout=30)
                try:
                    conn.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    result = conn.getresponse()
                    data = result.read()
                    if self.path == '/v3/command':
                        fault['commands'].append(body)
                        mutation = json.loads(body)['request']['command']
                        if ('turn' in mutation or 'turn_with_versions' in mutation) and result.status == 200:
                            if fault['delay']:
                                fault['delay_marker'].touch()
                                time.sleep(0.7)
                            if fault['drop']:
                                fault['drop'] = False
                                self.close_connection = True
                                return
                    elif fault['poison'] and not fault['poisoned'] and self.path == '/v3/query':
                        query = json.loads(body)['query']['kind']
                        if 'entries' in query and query['entries'].get('key') == b'total'.hex():
                            parsed = json.loads(data)
                            parsed['realm'] += 1
                            data = json.dumps(parsed).encode()
                            fault['poisoned'] = True
                    self.send_response(result.status)
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                finally: conn.close()
        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        url = f'http://127.0.0.1:{proxy.server_port}'
        children = []
        def provision(role='service', finite=False, lifetime_ms=240000):
            nonlocal principal
            principal += 1
            now = time.time_ns() // 1_000_000
            pid = command({'spawn': {'work_before_ms': now+lifetime_ms, 'settle_before_ms': now+lifetime_ms+30000} if finite else {}})
            seed, public = system.key(f'public-{principal}')
            command({'grant': {'subject': principal, 'public_key': public, 'permissions': 88, 'pid': pid}})
            resource = command({'create_resource': {'writer': pid}})
            for subject in (0, principal): command({'grant_resource': {'resource': resource, 'subject': subject, 'permissions': 7}})
            command({'associate': {'pid': pid, 'name': b'data'.hex(), 'resource': resource}})
            command({'own': {'pid': pid, 'worker': principal, 'expected_generation': 1}})
            output = target / f'output-{pid}'
            output.mkdir()
            cfg = {'url': url, 'realm': 72, 'principal': principal, 'pid': pid, 'generation': 2,
                'seed_file': str(seed), 'profile': 'growing_v3', 'peer': pid, 'role': role, 'resource': resource,
                'pending': str(target / f'pending-{pid}'), 'output': str(output), 'fixtures': str(codec_fixture),
                'query_results': role in ('table', 'query'), 'work_before_ms': now+lifetime_ms if finite else None}
            return cfg
        def config_file(cfg):
            path = target / f"config-{cfg['pid']}.json"
            path.write_text(json.dumps(cfg))
            return path
        def invoke(mode, cfg):
            return subprocess.check_output(consumer.command(mode, config_file(cfg)), env=env, cwd=target, timeout=90, text=True)
        def worker(cfg):
            child = subprocess.Popen(consumer.command('worker', config_file(cfg)), stdin=subprocess.PIPE, stdout=subprocess.PIPE, env=env, cwd=target, text=True)
            children.append(child)
            return child
        def one(child):
            child.stdin.write('one\n'); child.stdin.flush()
            assert select.select([child.stdout], [], [], 180)[0], 'Public runner timed out'
            value = child.stdout.readline()
            assert value, f'Worker failed with {child.poll()}'
            return json.loads(value)
        def close(child):
            child.stdin.write('close\n'); child.stdin.flush()
            assert json.loads(child.stdout.readline()) == {'closed': True}
            child.stdin.close()
            assert child.wait(timeout=15) == 0
            child.stdout.close()
            children.remove(child)
        def send(cfg, payload): command({'send': {'pid': cfg['pid'], 'value': frame(payload)}})
        def own(cfg):
            command({'own': {'pid': cfg['pid'], 'worker': cfg['principal'], 'expected_generation': cfg['generation']}})
            cfg['generation'] += 1
        after = None
        def deliver():
            nonlocal after
            position = read({'capabilities': {}})['position']
            batch = read({'outputs': {'after': after, 'position': position}})['body']['outputs']
            for value in batch['entries']:
                if value:
                    if value['phase'] == 'pending': command({'deliver': value['id']})
                    after = value['id']
        def process(cfg): return read({'process': cfg['pid']})['body']['process']['process']
        try:
            gated = provision(finite=True)
            invoke('codecs', gated)
            send(gated, b'TSC\x01\x01' + (2**53+1).to_bytes(8, 'little'))
            gates = json.loads(invoke('gates', gated))
            assert gates['gates'] == ['commit', 'open', 'permit']
            assert process(gated)['consumed'] == 1
            for mode in ('decode-stop', 'decode-block', 'handler-stop', 'handler-block', consumer.invalid_handler, *consumer.extra_failures):
                cfg = provision()
                send(cfg, b'TSC\x02\x02' if mode.startswith('decode-') else b'TSC\x01\x01' + (1).to_bytes(8, 'little'))
                invoke(mode, cfg)
                state = process(cfg)
                assert state['consumed'] == 0 and (state['failure'] is not None) == mode.endswith('-block')
                assert read({'resource': cfg['resource']})['body']['resource']['entries'] == 0
            async_cfg = provision()
            send(async_cfg, b'TSC\x01\x01' + (5).to_bytes(8, 'little'))
            fault['delay_marker'] = Path(async_cfg['output'], 'accepted')
            fault['delay'] = True
            assert json.loads(invoke('async', async_cfg))['committed']
            fault['delay'] = False
            assert process(async_cfg)['consumed'] == 1
            # Unknown accepted commit survives abrupt host loss and exact raw recovery.
            source, requester = provision(), provision('requester')
            requester['peer'] = source['pid']
            send(source, b'TSC\x01\x01' + (2**64-1).to_bytes(8, 'little'))
            service = worker(source)
            fault['drop'] = True
            assert one(service)['event'] == 'NeedsRecovery'
            accepted = fault['commands'][-1]
            service.kill(); service.wait(timeout=10); children.remove(service)
            system.authority.kill(); system.authority.wait(timeout=10)
            system.store.stop(); system.store.start()
            system.authority = system.start(node, system.config)
            from storage import wait_ready
            wait_ready(system.store.http, system.authority, system.url + '/health')
            seed_path = Path(source['seed_file'])
            saved_seed = seed_path.read_bytes(); seed_path.unlink()
            invoke('recover', source)
            exact_commit_retry = fault['commands'][-1] == accepted
            assert exact_commit_retry and process(source)['consumed'] == 1
            seed_path.write_bytes(saved_seed)
            own(source)
            send(requester, b'TSC\x01\x03')
            caller = worker(requester)
            assert one(caller)['event'] == 'Committed'
            close(caller)
            own(requester)
            deliver()
            # Run the installed documented CLI, rather than a test-only handler.
            subprocess.run(consumer.cli(config_file(source), 'service'), env=env, cwd=target, check=True, timeout=60, stdout=subprocess.DEVNULL)
            deliver()
            subprocess.run(consumer.cli(config_file(requester), 'requester'), env=env, cwd=target, check=True, timeout=60, stdout=subprocess.DEVNULL)
            assert process(requester)['consumed'] == 2
            revision = read({'resource': requester['resource']})['body']['resource']['revision']
            entries = read({'entries': {'resource': requester['resource'], 'revision': revision, 'key': b'observed'.hex()}})['body']['entries']['page']['entries']
            observed = next(entry for entry in entries if entry)
            assert bytes.fromhex(observed['value']) == b'TSU\x01' + (2**64-1).to_bytes(8, 'little')
            old = dict(source)
            own(source)
            invoke('stale', old)
            # A caught failed read must still abort the whole private turn.
            send(source, b'TSC\x01\x01' + (0).to_bytes(8, 'little'))
            fault['poison'] = True
            invoke('poison', source)
            assert fault['poisoned'] and process(source)['consumed'] == 2
            fault['poison'] = False
            command({'revoke': source['principal']})
            invoke('denied', source)
            # Bounded Table pages, retained point reads and multi-segment IPC.
            expired = provision(finite=True, lifetime_ms=2000)
            table, query_cfg = provision('table'), provision('query')
            table['peer'], query_cfg['peer'] = query_cfg['pid'], table['pid']
            service, caller = worker(table), worker(query_cfg)
            send(table, b'TSQ\x01\x01')
            assert one(service)['event'] == 'Committed'
            for index in range(41):
                key = -(2**63) if index == 0 else index
                value = None if index % 5 == 0 else 2**63-1 if index == 1 else 2**53+1
                payload = b'TSQ\x01\x02' + key.to_bytes(8, 'little', signed=True)
                payload += b'\0' if value is None else b'\1' + value.to_bytes(8, 'little', signed=True)
                send(table, payload)
                assert one(service)['event'] == 'Committed'
            send(table, b'TSQ\x01\x03')
            assert one(service)['event'] == 'Committed'
            send(table, b'TSQ\x01\x01')
            assert one(service)['event'] == 'Committed'
            send(query_cfg, b'TSQ\x01\x04')
            assert one(caller)['event'] == 'Committed'
            close(caller)
            own(query_cfg)
            caller = worker(query_cfg)
            manifest_file = Path(query_cfg['output']) / 'manifest.json'
            for _ in range(150):
                deliver()
                assert one(service)['event'] in ('Committed', 'Idle')
                assert one(caller)['event'] in ('Committed', 'Idle')
                if manifest_file.exists(): break
            else: raise AssertionError('Public query did not complete')
            close(service); close(caller)
            manifest = json.loads(manifest_file.read_bytes())
            assert (manifest['rows'], manifest['segments'], manifest['source'], manifest['destination'], manifest['resource']) == (41, 6, table['pid'], query_cfg['pid'], table['resource'])
            # Independent consumer after all foreign handles have been destroyed.
            import pyarrow as pa
            segments = [Path(query_cfg['output'], f'{i}.arrow').read_bytes() for i in range(6)]
            rows = [row for ipc in segments for row in pa.ipc.open_stream(ipc).read_all().to_pylist()]
            assert len(rows) == 41 and rows[0] == {'id': -(2**63), 'value': 17}
            assert rows[1]['value'] == 2**63-1 and rows[2]['value'] == 2**53+1
            assert sum(map(len, segments)) == manifest['bytes']
            own(query_cfg)
            send(query_cfg, b'TSQ\x01\x04')
            reader_child = subprocess.Popen(consumer.command('revoked-result', config_file(query_cfg)), stdout=subprocess.PIPE, env=env, cwd=target, text=True)
            children.append(reader_child)
            deadline = time.monotonic() + 45
            while not Path(query_cfg['output'], 'ready').exists():
                assert reader_child.poll() is None and time.monotonic() < deadline, 'Reader was not ready'
                time.sleep(0.02)
            command({'grant_resource': {'resource': query_cfg['resource'], 'subject': query_cfg['principal'], 'permissions': 0}})
            Path(query_cfg['output'], 'continue').touch()
            denied = json.loads(reader_child.communicate(timeout=30)[0])
            assert denied == {'denied': True}
            assert reader_child.returncode == 0
            children.remove(reader_child)
            query_cfg['arrow_site'] = str(Path(pa.__file__).parent.parent)
            invoke('arrow', query_cfg)
            # Expiry remains retirement, distinct from stale activation or access.
            while time.time_ns() // 1_000_000 <= expired['work_before_ms'] + 10000:
                time.sleep(0.05)
            command({'expire': expired['pid']})
            invoke('expired', expired)
            check('public-runner-lifecycle', {
                'gated_purposes': gates['gates'], 'handler_calls_after_recovery': gates['handled'],
                'mutation_dispatches': gates['dispatches'], 'exact_commit_retry': exact_commit_retry,
                'restarted_reply_value': str(int.from_bytes(bytes.fromhex(observed['value'])[4:], 'little')),
                'query_rows': manifest['rows'], 'query_segments': manifest['segments'],
                'owned_ipc_after_close': not children, 'revoked_result_denied': denied['denied'],
            })
            print(f'{label} Station: clean artifacts/examples, full-width codecs, gated mutations, callback failures, scope safety, stop/join, codec policy, poisoned reads, fencing/expiry, exact disk/host recovery, retained Tables and six owned IPC segments passed.')
        finally:
            for child in children:
                child.kill(); child.wait(timeout=10)
            native.lib.transit_client_destroy(admin)
            proxy.shutdown(); proxy.server_close(); thread.join(timeout=5)

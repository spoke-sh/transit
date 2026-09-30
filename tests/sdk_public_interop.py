"""A public-SDK ring: every target is service and requester for a foreign peer."""
from contextlib import ExitStack
from datetime import datetime, timezone
import hashlib
import os
import platform
import importlib
import json
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time
from client_abi import Native
from client_abi_growing import GrowingSystem
from arrow import simple_rows
from station import frame
from sdk_scenarios import check


def run(node, cli, library, artifacts, report_path=None):
    started = time.monotonic()
    artifacts = Path(artifacts).resolve()
    fixture = GrowingSystem(node, cli)
    fixture.resident_pages = 64
    with ExitStack() as stack, fixture as system:
        clients = []
        def install(_node, _cli, _library, installer, label):
            target = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix='transit-public-pair-')))
            clients.append((label, target, installer(target)))
        for language, folder in (('python', 'wheels'), ('node', 'node'), ('rust', 'rust'), ('ruby', 'ruby'),
                                 ('c', 'c'), ('java', 'java'), ('dotnet', 'dotnet'), ('beam', 'beam')):
            importlib.import_module(f'{language}_station_sdk').run(node, cli, library, artifacts / folder, execute=install)
        installed_at = time.monotonic()
        native = Native(library)
        admin = native.client(system.url, timeout_ms=5000)
        stack.callback(native.lib.transit_client_destroy, admin)
        seed = bytes.fromhex(system.seed.read_text().strip())
        sequence, principal, after = 0, 65536, None
        def command(body):
            nonlocal sequence
            sequence += 1
            operation = native.prepare(6, seed, {'realm': 72, 'principal': 0, 'sequence': sequence, 'command': body})
            try: return native.call(admin, operation)['position']
            finally: native.lib.transit_operation_destroy(operation)
        def read(kind):
            operation = native.prepare(7, seed, {'realm': 72, 'principal': 0, 'kind': kind})
            try: return native.call(admin, operation)
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
            # Exercise native URL joining without a path-normalizing proxy.
            return {'url': system.url + '/', 'realm': 72, 'principal': principal, 'pid': pid, 'generation': 2,
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
        def send(cfg, payload): command({'send': {'pid': cfg['pid'], 'value': frame(payload)}})
        def deliver():
            nonlocal after
            position = read({'capabilities': {}})['position']
            batch = read({'outputs': {'after': after, 'position': position}})['body']['outputs']
            for value in batch['entries']:
                if value:
                    if value['phase'] == 'pending': command({'deliver': value['id']})
                    after = value['id']
        children = []
        def worker(client, cfg):
            consumer = client[2]
            child = subprocess.Popen(consumer.command('worker', config(client, cfg)), cwd=client[1], env=consumer.environment,
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
            children.append(child)
            return child
        def one(child):
            child.stdin.write('one\n'); child.stdin.flush()
            assert select.select([child.stdout], [], [], 90)[0], 'Public mixed-language runner timed out'
            line = child.stdout.readline()
            assert line, f'Public worker exited with {child.poll()}'
            result = json.loads(line)
            assert result['event'] in ('Committed', 'Idle'), result
            return result['event']
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
        pairs, timings = [], []
        import pyarrow as pa
        for index, service in enumerate(clients):
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
            send(table, b'TSQ\x01\x01'); assert one(server) == 'Committed'
            expected = [{'id': -(2**63), 'value': None}, {'id': 0, 'value': 2**53+1}, {'id': 2**63-1, 'value': -(2**63)}]
            for row in expected:
                payload = b'TSQ\x01\x02' + row['id'].to_bytes(8, 'little', signed=True)
                payload += b'\0' if row['value'] is None else b'\1' + row['value'].to_bytes(8, 'little', signed=True)
                send(table, payload); assert one(server) == 'Committed'
            send(query, b'TSQ\x01\x04'); assert one(caller) == 'Committed'
            close(caller); own(query); caller = worker(requester, query)
            manifest_file = Path(query['output'], 'manifest.json')
            for _ in range(100):
                deliver()
                assert one(server) in ('Committed', 'Idle')
                assert one(caller) in ('Committed', 'Idle')
                if manifest_file.exists(): break
            else: raise AssertionError('Cross-language query did not complete')
            close(server); close(caller)
            manifest = json.loads(manifest_file.read_bytes())
            assert (manifest['rows'], manifest['source'], manifest['destination'], manifest['resource']) == (3, table['pid'], query['pid'], table['resource'])
            segments = [Path(query['output'], f'{i}.arrow').read_bytes() for i in range(manifest['segments'])]
            rows = [row for ipc in segments for row in simple_rows(pa.ipc.open_stream(ipc).read_all())]
            assert rows == expected and sum(map(len, segments)) == manifest['bytes']
            pair = f'{service[0]} -> {requester[0]}'
            pairs.append(pair)
            timings.append({'pair': pair, 'elapsed_seconds': round(time.monotonic()-pair_started, 3)})
            print(f'Public pair {pair}: installed CLIs, restarted durable reply, typed Table/query and owned original IPC passed.', flush=True)
        check('public-language-ring', {'pairs': pairs, 'reply_value': str(2**64-1), 'query_rows_per_pair': 3,
                                      'fresh_requesters': True, 'owned_ipc_after_close': not children})
        elapsed = time.monotonic()-started
        if report_path:
            sources = [Path(__file__), *[Path(__file__).with_name(f'{name}_station_sdk.py') for name in ('python', 'node', 'rust', 'ruby', 'c', 'java', 'dotnet', 'beam')]]
            report = {'version': 1, 'status': 'passed', 'recorded_at': datetime.now(timezone.utc).isoformat(),
                      'environment': {'platform': platform.system(), 'architecture': platform.machine(), 'available_cpus': len(os.sched_getaffinity(0)), 'authority_cpus': 1, 'admin_timeout_ms': 5000},
                      'source_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                      'proof_sha256': {str(path.relative_to(Path(__file__).resolve().parents[1])): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources},
                      'elapsed_seconds': round(elapsed, 3), 'consumer_install_seconds': round(installed_at-started, 3), 'pairs': timings,
                      'limits': 'Local consumer installation and ten counter/query pairs. Excludes artifact builds, CI setup/cache transfer, and other SDK failure suites. Not a hosted CI budget measurement.'}
            Path(report_path).parent.mkdir(parents=True, exist_ok=True)
            Path(report_path).write_text(json.dumps(report, indent=2) + '\n')
        print(f'Public SDK ring: {len(pairs)} counter/query pairs passed in {time.monotonic()-started:.1f}s including clean consumer installation.', flush=True)


if __name__ == '__main__': run(*sys.argv[1:])

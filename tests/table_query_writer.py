"""Real combined host: two-phase disk recovery and interleaved finite queries."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time

import pyarrow as pa
from cold_storage import ColdStore
from storage import Fixture, free_port, wait_ready
from unified_abi import Native as Query, Failure
from table_mutation_abi import Native as Mutation
from table_mutation_cli import Cli


def run(node, host, proof, library, cli, *, sdks=()):
    started = time.monotonic()
    with ColdStore() as cold, Fixture(cold.config()) as fixture:
        root = fixture.root
        install_started = time.monotonic()
        if sdks:
            from sdk_mutations import install
            installed = install(root/'installed', sdks)
        else:
            installed = []
        sdk_install_seconds = round(time.monotonic()-install_started, 3)
        binaries = {}
        for name, original in dict(node=node, host=host, proof=proof, library=library, cli=cli).items():
            target = root/name
            shutil.copy2(original, target)
            binaries[name] = str(target)
        node, host, proof, library = (binaries[name] for name in ('node', 'host', 'proof', 'library'))
        cli = binaries['cli']
        port = free_port()
        url = f'http://127.0.0.1:{port}'
        public = json.loads(subprocess.check_output([proof, 'public'], timeout=10))
        config = root/'node.json'
        config.write_text(json.dumps(dict(profile='native_v1', genesis=dict(realm=46, root_key=public, max_clock_error_ms=10000), ursula_url=fixture.url, bucket='combined-table', journal='authority', port=port, resident_pages=8, request_timeout_ms=10000)))
        fault = dict(phase=1, seen=threading.Event(), release=threading.Event(), frozen=None, receipt=None)
        send_fault = dict(lose=False, frozen=None, receipt=None, recovered=False)
        counts = dict(reads=0, turns=0, max_mutations=0, max_value_bytes=0, recovered_initialization_receipts=0, snapshot_pause_seconds=0.0)
        errors, processes, logs, clients = [], [], [], []
        snapshot_seen, snapshot_release = threading.Event(), threading.Event()
        pause_snapshot = False

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                upstream = HTTPConnection('127.0.0.1', port, timeout=15)
                try:
                    message = json.loads(body)
                    counts['reads'] += self.path == '/v1/query'
                    if pause_snapshot and self.path == '/v1/query' and not snapshot_seen.is_set():
                        kind = message['query']['kind']
                        if 'snapshot_entries' in kind or ('snapshot_read' in kind and 'existing' in kind['snapshot_read']['snapshot']):
                            snapshot_seen.set()
                            assert snapshot_release.wait(timeout=30), 'snapshot fault was never released'
                    upstream.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    response = upstream.getresponse()
                    data = response.read()
                    command = message.get('request', {}).get('command', {})
                    if response.status == 200 and message.get('request', {}).get('principal') == 1234 and 'send' in command:
                        if send_fault['lose']:
                            send_fault.update(lose=False, frozen=body, receipt=json.loads(data))
                            data = b'{}'
                        elif body == send_fault['frozen']:
                            assert json.loads(data)['position'] == send_fault['receipt']['position']
                            send_fault['recovered'] = True
                    turn = command.get('turn', command.get('turn_with_versions', {}).get('turn'))
                    if response.status == 200 and turn:
                        mutations = [entry for entry in turn['mutations'] if entry]
                        counts['turns'] += 1
                        counts['max_mutations'] = max(counts['max_mutations'], len(mutations))
                        assert len(mutations) <= 4
                        for entry in mutations:
                            value = bytes.fromhex(entry['value']) if entry['value'] is not None else b''
                            counts['max_value_bytes'] = max(counts['max_value_bytes'], len(value))
                            assert len(value) <= 256
                            if value.startswith(b'TQW1') and value[4] == fault['phase'] and not fault['seen'].is_set():
                                fault.update(frozen=body, receipt=json.loads(data))
                                fault['seen'].set()
                                assert fault['release'].wait(timeout=60), 'initialization fault was never released'
                                data = b'{}'
                    self.send_response(response.status)
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                except (BrokenPipeError, ConnectionResetError): pass
                except BaseException as error:
                    errors.append(error)
                    self.close_connection = True
                finally:
                    upstream.close()

        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        proxy.daemon_threads = True
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        endpoint = f'http://127.0.0.1:{proxy.server_port}'

        def start(name, args):
            log = (root/f'{name}.log').open('w+')
            logs.append(log)
            process = subprocess.Popen(args, env=fixture.env, stdout=log, stderr=log)
            processes.append(process)
            return process

        def invoke(command, *args):
            value = subprocess.run([proof, endpoint, command, str(root), *map(str, args)], env=fixture.env, capture_output=True, text=True, timeout=60)
            assert value.returncode == 0, (command, value.stdout, value.stderr)
            return json.loads(value.stdout) if value.stdout.strip() else None

        def until(callback, timeout=30):
            deadline = time.monotonic()+timeout
            while True:
                result = callback()
                if result: return result
                assert time.monotonic() < deadline, 'combined proof deadline'
                assert not errors, errors
                time.sleep(0.02)

        def replace(role):
            generation = invoke('fence' if role == 'source' else 'fence-requester')['generation']
            path = root/f'{role}.json'
            settings = json.loads(path.read_text())
            settings['generation'] = generation
            path.write_text(json.dumps(settings))
            return start(f'{role}-{generation}', [host, str(path)])

        def processed(position):
            state = invoke('combined-progress')
            return state['pending'] is None or state['pending'] > position

        def mutation(sql, namespace, caller=None, compiled=None, *, seal_only=False):
            caller = caller or mutations
            compiled = compiled or caller.call({'compile': dict(name='items', sql=sql, namespace=str(namespace))})['compiled']
            for _ in range(32):
                if seal_only:
                    status = caller.call({'status': compiled['reference']})['status']
                    if status is not None and status['phase'] == 'sealed':
                        return compiled
                prepared = caller.call({'next': compiled})['prepared']
                if prepared is None:
                    assert not seal_only, 'mutation applied before the snapshot interleave'
                    status = caller.call({'status': compiled['reference']})['status']
                    assert status['phase'] == 'applied', status
                    return status
                receipt = caller.call({'submit': prepared})['receipt']
                until(lambda: caller.call({'observe': dict(prepared=prepared, input=receipt['position'])})['observation'] == 'processed')
                assert caller.call({'rejection': dict(prepared=prepared, input=receipt['position'])})['rejection'] is None
            raise AssertionError('mutation step budget')

        def query(namespace):
            for _ in range(32):
                prepared = queries.call({'next': dict(namespace=str(namespace), bundle=(root/'bundle.bin').read_bytes().hex())})['prepared']
                if prepared is None: return
                receipt = queries.call({'submit': prepared})['receipt']
                until(lambda: 'committed' in queries.call({'observe': receipt['position']})['observation'])
            raise AssertionError('query upload step budget')

        def complete(namespace):
            def advance():
                invoke('combined-deliver')
                status = queries.call({'status': str(namespace)})['status']
                assert status['phase'] in ('admitted', 'complete'), status
                return status['phase'] == 'complete'
            until(advance, 120)

        def rows(namespace):
            result, cursor = [], None
            for _ in range(100):
                page = queries.call({'page': dict(namespace=str(namespace), cursor=cursor)})['page']
                for row in pa.ipc.open_stream(bytes.fromhex(page['ipc'])).read_all().to_pylist():
                    assert set(row) == {'id', 'value'}, row
                    for name, kind in (('id', 1), ('value', 5)):
                        assert row[name] == dict(state=3, kind=kind, value=row[name]['value'], alternatives=[]), row
                    result.append({name: cell['value'] for name, cell in row.items()})
                cursor = page['next']
                if cursor is None: return result
            raise AssertionError('result page budget')

        def denied(operation, error):
            try:
                operation()
                raise AssertionError('operation unexpectedly permitted')
            except Failure as failure:
                assert failure.detail['err'] == error, failure

        def console_rows(stdout):
            frames = [json.loads(line) for line in stdout.splitlines()]
            assert frames and frames[-1]['complete_coverage'], frames
            assert all(frame['profile'] == 'interactive_v1' for frame in frames)
            return [dict(id=int(row[0]['value']['int64']), value=row[1]['value']['utf8']) for frame in frames for row in frame['cells']]

        try:
            subprocess.run([node, str(config), '--initialize'], env=fixture.env, check=True, capture_output=True, timeout=30)
            authority = start('node', [node, str(config)])
            wait_ready(fixture.http, authority, url+'/health')
            connection = invoke('provision-combined')
            source = start('source', [host, str(root/'source.json')])
            assert fault['seen'].wait(timeout=30), 'first initialization commit missing'
            state = invoke('combined-state')
            assert state['phase'] == 'staged' and state['mutation'] is None and state['query'] is None, state
            for phase in (1, 2):
                if phase == 2:
                    fault.update(phase=2, seen=threading.Event(), release=threading.Event())
                    invoke('combined-deliver')
                    assert fault['seen'].wait(timeout=30), 'ready commit missing'
                    assert invoke('combined-state')['phase'] == 'ready'
                frozen, receipt = fault['frozen'], fault['receipt']
                source.kill(); source.wait(timeout=10)
                fault['release'].set()
                same = subprocess.run([host, str(root/'source.json')], capture_output=True, env=fixture.env, timeout=15)
                assert same.returncode and b'FreshOwnershipRequired' in same.stderr, same.stderr
                authority.kill(); authority.wait(timeout=10)
                fixture.stop(); fixture.start()
                authority = start(f'node-after-{phase}', [node, str(config)])
                wait_ready(fixture.http, authority, url+'/health')
                # Exact original signed commit recovers after physical restart.
                direct = HTTPConnection('127.0.0.1', port, timeout=15)
                direct.request('POST', '/v1/command', frozen, {'Content-Type': 'application/json'})
                response = direct.getresponse()
                recovered = json.loads(response.read())
                direct.close()
                assert response.status == 200 and recovered['position'] == receipt['position'], recovered
                counts['recovered_initialization_receipts'] += 1
                source = replace('source')
            fault['phase'] = 0
            until(lambda: invoke('combined-state')['phase'] == 'ready')
            position = invoke('combined-initialize')['position']
            until(lambda: processed(position))
            state = invoke('combined-state')
            assert state['query']['revision'] == state['mutation']['revision'] == 1
            requester = start('requester', [host, str(root/'requester.json')])
            queries = Query(library, endpoint, connection); clients.append(queries)
            mutations = Mutation(library, endpoint, dict(realm=46, principal=1234, writer=connection['source'], resource=connection['resource'], table=1)); clients.append(mutations)
            cli_mutations = Cli(cli, root, endpoint, dict(realm=46, principal=1234, writer=connection['source'], resource=connection['resource'], table=1)); clients.append(cli_mutations)
            settings = json.loads((root/'shell.json').read_text())
            settings.update(version=1, profile='unified_v1', execution='interactive', transport='loopback', format='json')
            (root/'console.json').write_text(json.dumps(settings))
            console_args = [cli, 'console', '--no-rc', '--config', str(root/'console.json'), '-c', 'SELECT * FROM items;']
            mutation("INSERT INTO items (id,value) VALUES(1,'old'),(2,'two')", 1)
            query(1)
            invoke('combined-deliver')
            snapshot = until(lambda: invoke('job', 1)['job'])
            assert snapshot['phase'] == 'capturing', snapshot
            namespace = (1 << 63) | snapshot['id']
            # Finish upload and seal before holding a live console read. Only
            # the final apply must commit after its retained snapshot. Holding
            # the request across the whole upload instead makes test setup race
            # the console's ordinary five-second per-request deadline.
            staged = mutation("UPDATE items SET value='new' WHERE id=1", namespace, cli_mutations, seal_only=True)
            apply = cli_mutations.call({'prepare': {'apply': staged['reference']}})['prepared']
            pause_snapshot = True
            console = subprocess.Popen(console_args, env=fixture.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            processes.append(console)
            assert snapshot_seen.wait(timeout=15), 'interactive query did not retain its snapshot'
            # Keep the query self continuation undelivered. A mutation is
            # committed after its retained cut using the SAME numeric namespace.
            paused = time.monotonic()
            try:
                applied = cli_mutations.call({'submit': apply})['receipt']
                until(lambda: cli_mutations.call({'observe': dict(prepared=apply, input=applied['position'])})['observation'] == 'processed')
            finally:
                counts['snapshot_pause_seconds'] = round(time.monotonic()-paused, 3)
                snapshot_release.set()
            stdout, stderr = console.communicate(timeout=30)
            assert console.returncode == 0, stderr
            assert cli_mutations.call({'rejection': dict(prepared=apply, input=applied['position'])})['rejection'] is None
            outcome = cli_mutations.call({'status': staged['reference']})['status']
            assert outcome['phase'] == 'applied' and outcome['affected_rows'] == 1 and outcome['input'] == applied['position'], outcome
            assert console_rows(stdout) == [dict(id=1, value='old'), dict(id=2, value='two')]
            pause_snapshot = False
            complete(1)
            previous = rows(1)
            assert previous == [dict(id=1, value='old'), dict(id=2, value='two')], previous
            query(2); complete(2)
            current = rows(2)
            assert current == [dict(id=1, value='new'), dict(id=2, value='two')], current
            latest = subprocess.run(console_args, env=fixture.env, capture_output=True, text=True, timeout=30)
            assert latest.returncode == 0, latest.stderr
            assert console_rows(latest.stdout) == current
            sdk_results = []
            mutation_connection = dict(realm=46, principal=1234, writer=connection['source'], resource=connection['resource'], table=1)
            for index, (label, factory) in enumerate(installed):
                caller_started = time.monotonic()
                owner = factory(endpoint, mutation_connection, root); clients.append(owner)
                sql = f"UPDATE items SET value='{label}' WHERE id=2"
                sdk_namespace = (1 << 63)+10000+index
                compiled = owner.call({'compile': dict(name='items', sql=sql, namespace=str(sdk_namespace))})['compiled']
                prepared = owner.call({'next': compiled})['prepared']
                saved = root/f'{label}-frozen.txt'; saved.write_text(prepared)
                send_fault.update(lose=True, recovered=False)
                try:
                    owner.call({'submit': prepared})
                    raise AssertionError('lost receipt reported as success')
                except Failure as failure:
                    assert failure.status == 6, failure
                owner.close(); clients.remove(owner)
                owner = factory(endpoint, mutation_connection, root); clients.append(owner)
                assert saved.read_text() == prepared
                receipt = owner.call({'submit': saved.read_text()})['receipt']
                assert send_fault['recovered'] and receipt['position'] == send_fault['receipt']['position']
                until(lambda: owner.call({'observe': dict(prepared=prepared, input=receipt['position'])})['observation'] == 'processed')
                result = mutation(sql, sdk_namespace, owner, compiled)
                assert result['affected_rows'] == 1, result
                sdk_results.append((label, owner, compiled['reference'], round(time.monotonic()-caller_started, 3)))
            position = invoke('combined-query-revoke')['position']
            until(lambda: processed(position))
            denied(lambda: rows(1), 'QueryDenied')
            mutation("UPDATE items SET value='after-revocation' WHERE id=2", (1 << 64)-1)
            position = invoke('combined-query-restore')['position']
            until(lambda: processed(position))
            position = invoke('combined-mutation-revoke')['position']
            until(lambda: processed(position))
            denied(lambda: mutation('DELETE FROM items WHERE id=1', 17), 'MutationDenied')
            query(3); complete(3)
            assert rows(3) == [dict(id=1, value='new'), dict(id=2, value='after-revocation')]
            invoke('revoke')
            denied(lambda: rows(3), 'AccessDenied')
            for _, owner, reference, _ in sdk_results:
                denied(lambda: owner.call({'status': reference}), 'AccessDenied')
            assert source.poll() is None and requester.poll() is None
            assert not errors, errors
            print(json.dumps(dict(proof='combined Table query/writer', elapsed_seconds=round(time.monotonic()-started, 3), **counts, resident_pages=8, mutation_namespace=str(namespace), installed_sdks=list(sdks), sdk_install_seconds=sdk_install_seconds, sdk_callers=[dict(caller=label, seconds=seconds) for label, _, _, seconds in sdk_results], binaries={name: hashlib.sha256(Path(path).read_bytes()).hexdigest() for name, path in binaries.items()})), flush=True)
            print('Combined Table host: both initialization commits survive lost receipts, fresh fencing and node/store restart; durable and interactive query snapshots survive interleaved same-namespace CLI mutations; independent policy and current native disclosure gates pass.', flush=True)
        except BaseException:
            for log in logs:
                log.flush()
                print(f'--- {Path(log.name).name} ---\n'+Path(log.name).read_text()[-6000:], file=sys.stderr)
            raise
        finally:
            fault['release'].set()
            snapshot_release.set()
            for client in clients: client.close()
            for process in reversed(processes):
                if process.poll() is None: process.terminate()
            for process in reversed(processes):
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired: process.kill(); process.wait(timeout=5)
            proxy.shutdown(); proxy.server_close(); thread.join(timeout=5)
            for log in logs: log.close()


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('node', 'host', 'proof', 'library', 'cli'): parser.add_argument(name)
    parser.add_argument('--sdk', action='append', default=[])
    args = parser.parse_args()
    run(args.node, args.host, args.proof, args.library, args.cli, sdks=args.sdk)

"""Real combined host: two-phase disk recovery and interleaved finite queries."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import json
from pathlib import Path
import shutil
import signal
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
        rejection_gate = dict(armed=False, seen=threading.Event(), release=threading.Event())
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
                    early_command = message.get('request', {}).get('command', {})
                    if rejection_gate['armed'] and message.get('request', {}).get('principal') == 1234 and 'send' in early_command and b'TMP1' in bytes.fromhex(early_command['send']['value']):
                        rejection_gate['armed'] = False
                        rejection_gate['seen'].set()
                        assert rejection_gate['release'].wait(timeout=15), 'policy rejection fault was never released'
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
            settings.update(version=1, profile='unified_v1', execution='interactive', transport='loopback', format='json', writes=dict(recovery_file='console-writes.json', table=dict(name='items', connection=dict(realm=46, principal=1234, writer=connection['source'], resource=connection['resource'], table=1))))
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
            # Select staged admission with a bounded 200-byte value; a small
            # request executes directly and has no sealed barrier to hold.
            updated_value = 'new-' + 'x' * 196
            staged = mutation(f"UPDATE items SET value='{updated_value}' WHERE id=1", namespace, cli_mutations, seal_only=True)
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
            assert current == [dict(id=1, value=updated_value), dict(id=2, value='two')], current
            latest = subprocess.run(console_args, env=fixture.env, capture_output=True, text=True, timeout=30)
            assert latest.returncode == 0, latest.stderr
            assert console_rows(latest.stdout) == current
            # Console SQL uses the same authorized writer and exact signed recovery.
            def console_run(sql=None, data=None, code=0):
                args = console_args[:-2] + (['-c', sql] if sql is not None else [])
                result = subprocess.run(args, input=data, env=fixture.env, capture_output=True, text=True, timeout=45)
                assert result.returncode == code, (result.returncode, result.stdout, result.stderr)
                return result
            recovery_path = root/'console-writes.json'
            help_result = json.loads(console_run(data='.help INSERT\n').stdout)
            assert help_result['table_writer_configured'] and not help_result['catalog_configured']
            assert 'transit mutate' not in help_result['help']
            for sql, affected in [("INSERT INTO items (id,value) VALUES (101,'console')", 1),
                                  ("UPDATE items SET value='changed' WHERE id=101", 1),
                                  ("DELETE FROM items WHERE id=101", 1),
                                  ("DELETE FROM items WHERE id=101", 0)]:
                result = json.loads(console_run(sql).stdout)['mutation']
                assert result['phase'] == 'applied' and result['affected_rows'] == affected, result
            rejected = console_run("INSERT INTO items (id,value) VALUES (1,'duplicate'),(101,'atomic')", code=1)
            assert json.loads(rejected.stdout)['mutation']['reason'] == 'row_exists'
            assert json.loads(rejected.stdout)['mutation']['conflict'] == dict(key='1', row=1)
            assert 'Duplicate key "id: 1" violates the primary key constraint on "items".' in rejected.stderr
            assert 'No rows were inserted.' in rejected.stderr
            assert '.resume' not in rejected.stderr and 'MutationRejected' not in rejected.stderr
            human = console_run(data=".mode table\nINSERT INTO items (value,id) VALUES ('atomic',101),('duplicate',1);\n", code=1)
            assert not human.stdout, human.stdout
            assert human.stderr.count('Constraint Error:') == 1, human.stderr
            assert 'Input row: 2. No rows were inserted.' in human.stderr
            assert '.resume' not in human.stderr and 'uncertain' not in human.stderr
            status = console_run(data='.mode table\n.status\n')
            assert 'Duplicate key "id: 1"' in status.stdout and 'Input row: 2.' in status.stdout
            assert console_rows(console_run('SELECT * FROM items').stdout) == current
            send_fault.update(lose=True, recovered=False)
            lost = console_run("INSERT INTO items (id,value) VALUES (102,'recovered')", code=1)
            assert not lost.stdout and '.resume' in lost.stderr
            saved = recovery_path.read_bytes()
            record = json.loads(saved)
            assert record['operation']['mutation']['pending']['signed'] == json.loads(send_fault['frozen'])
            assert record['operation']['mutation']['input'] is None
            assert recovery_path.stat().st_mode & 0o777 == 0o600
            console_run(data='.help\n')
            assert not send_fault['recovered'] and recovery_path.read_bytes() == saved
            status = json.loads(console_run(data='.status\n').stdout)['mutation']
            assert status['uncertain'] and not send_fault['recovered']
            for edit in ('definition', 'key', 'connection', 'signed_definition', 'schema_version'):
                altered = json.loads(saved)
                if edit == 'definition': del altered['definition']
                elif edit == 'key': altered['key'][0] ^= 1
                elif edit == 'connection': altered['table']['writer'] += 1
                elif edit == 'signed_definition': del altered['operation']['mutation']['pending']['signed']['request']['definition']
                else: del altered['operation']['mutation']['request']['plan']['schema']['version']
                recovery_path.write_text(json.dumps(altered, separators=(',', ':')))
                invalid = console_run(data='.resume\n', code=1)
                assert not invalid.stdout and not send_fault['recovered']
            recovery_path.write_bytes(saved)
            restored = json.loads(console_run(data='.resume\n').stdout)['mutation']
            assert restored['phase'] == 'applied' and restored['affected_rows'] == 1 and send_fault['recovered']
            again = json.loads(console_run(data='.resume\n').stdout)['mutation']
            assert again == restored
            # Direct admission can already be applied when cancellation is
            # requested. It must preserve that terminal outcome and its rows.
            assert b'TME1' in bytes.fromhex(json.loads(send_fault['frozen'])['request']['command']['send']['value'])
            assert json.loads(console_run(data='.cancel\n').stdout)['mutation'] == restored
            assert json.loads(console_run('DELETE FROM items WHERE id=102').stdout)['mutation']['affected_rows'] == 1
            # SIGINT retains the admitted command and stops before the next SQL.
            # Check the actual command selected: inline execution can finish
            # during reconciliation, while a staged begin remains cancellable.
            def interrupt_write(sql, command_tag):
                source.send_signal(signal.SIGSTOP)
                interrupted = subprocess.Popen(console_args[:-2], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=fixture.env)
                processes.append(interrupted)
                try:
                    interrupted.stdin.write(sql + ";\nDELETE FROM items WHERE id=1;\n")
                    interrupted.stdin.flush()
                    until(lambda: recovery_path.exists() and not json.loads(recovery_path.read_bytes())['complete'] and json.loads(recovery_path.read_bytes())['operation']['mutation']['input'] is not None)
                    pending = json.loads(recovery_path.read_bytes())['operation']['mutation']['pending']
                    frame = bytes.fromhex(pending['signed']['request']['command']['send']['value'])
                    assert frame[13:17] == command_tag, frame[13:17]
                    interrupted.send_signal(signal.SIGINT)
                    stdout, stderr = interrupted.communicate(timeout=15)
                    assert interrupted.returncode == 130 and not stdout and '.resume' in stderr, (interrupted.returncode, stdout, stderr)
                finally:
                    source.send_signal(signal.SIGCONT)
            interrupt_write("INSERT INTO items (id,value) VALUES (103,'pending')", b'TME1')
            applied = json.loads(console_run(data='.cancel\n').stdout)['mutation']
            assert applied['phase'] == 'applied' and applied['affected_rows'] == 1 and not applied['uncertain'], applied
            assert console_rows(console_run('SELECT * FROM items').stdout) == current + [dict(id=103, value='pending')]
            console_run('DELETE FROM items WHERE id=103')
            # A 200-byte cell fits the Table bound but requires staged upload.
            interrupt_write("INSERT INTO items (id,value) VALUES (103,'" + 'p' * 200 + "')", b'TMB1')
            cancelled = json.loads(console_run(data='.cancel\n').stdout)['mutation']
            assert cancelled['phase'] == 'cancelled', cancelled
            assert console_rows(console_run('SELECT * FROM items').stdout) == current
            print('Console interruption: admitted inline write applied, staged begin cancelled, later batch SQL never ran.', flush=True)
            # Revoke after a part is frozen but before its admission. A rejected
            # part must not be mistaken for a terminal mutation or lose recovery.
            rejection_gate['armed'] = True
            racing = subprocess.Popen(console_args[:-2]+['-c', "INSERT INTO items (id,value) VALUES (104,'" + 'd' * 200 + "')"], env=fixture.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            processes.append(racing)
            try:
                assert rejection_gate['seen'].wait(timeout=15), 'console did not prepare a mutation part'
                position = invoke('combined-mutation-revoke')['position']
                until(lambda: processed(position))
            finally:
                rejection_gate['release'].set()
            stdout, stderr = racing.communicate(timeout=20)
            assert racing.returncode == 1 and json.loads(stdout)['mutation']['phase'] == 'input_rejected', (racing.returncode, stdout, stderr)
            assert not json.loads(recovery_path.read_bytes())['complete']
            blocked = console_run('SELECT * FROM items', code=1)
            assert not blocked.stdout and '.cancel' in blocked.stderr
            cancelled = json.loads(console_run(data='.cancel\n').stdout)['mutation']
            assert cancelled['phase'] == 'cancelled', cancelled
            position = invoke('combined-mutation-restore')['position']
            until(lambda: processed(position))
            assert console_rows(console_run('SELECT * FROM items').stdout) == current
            print('Console writes: INSERT/UPDATE/DELETE, atomic rejection, exact lost-receipt recovery, identity checks, read-after-write, interruption, policy-raced input rejection and cancellation passed.', flush=True)
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
            denied_console = console_run('DELETE FROM items WHERE id=1', code=1)
            assert 'current writer or catalog policy' in denied_console.stderr and not denied_console.stdout
            query(3); complete(3)
            assert rows(3) == [dict(id=1, value=updated_value), dict(id=2, value='after-revocation')]
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
            rejection_gate['release'].set()
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

"""General catalog owner: explicit initialization, disk recovery and retained queries."""
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
from catalog_abi import Native as Catalog
from catalog_helpers import Cli


def run(node, host, proof, library, cli, *, sdks=()):
    started = time.monotonic()
    with ColdStore() as cold, Fixture(cold.config()) as fixture:
        root = fixture.root
        install_started = time.monotonic()
        if sdks:
            from sdk_catalog import install
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
        fault = dict(prefix=b'TCA1C', seen=threading.Event(), release=threading.Event(), frozen=None, receipt=None)
        send_fault = dict(lose=False, frozen=None, receipt=None, recovered=False)
        rejection_gate = dict(armed=False, seen=threading.Event(), release=threading.Event())
        publication_gate = dict(operation=None, seen=threading.Event(), release=threading.Event())
        disclosure_gate = dict(armed=False, seen=threading.Event(), release=threading.Event())
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
                    if disclosure_gate['armed'] and self.path == '/v1/query':
                        snapshot_read = message['query']['kind'].get('snapshot_read')
                        if snapshot_read and snapshot_read['finish']:
                            disclosure_gate['armed'] = False
                            disclosure_gate['seen'].set()
                            assert disclosure_gate['release'].wait(timeout=15), 'disclosure fault was never released'
                    if pause_snapshot and self.path == '/v1/query' and not snapshot_seen.is_set():
                        kind = message['query']['kind']
                        observed = counts.setdefault('interactive_open_requests', {})
                        operation = next(iter(kind))
                        observed[operation] = observed.get(operation, 0) + 1
                        if 'snapshot_entries' in kind or ('snapshot_read' in kind and 'existing' in kind['snapshot_read']['snapshot']):
                            snapshot_seen.set()
                            assert snapshot_release.wait(timeout=30), 'snapshot fault was never released'
                    early_command = message.get('request', {}).get('command', {})
                    if rejection_gate['armed'] and message.get('request', {}).get('principal') == 1234 and 'send' in early_command and bytes.fromhex(early_command['send']['value'])[13:18] == b'TCA1A':
                        rejection_gate['armed'] = False
                        rejection_gate['seen'].set()
                        assert rejection_gate['release'].wait(timeout=15), 'policy rejection fault was never released'
                    early_turn = early_command.get('turn', early_command.get('turn_with_versions', {}).get('turn'))
                    if early_turn and publication_gate['operation'] is not None:
                        for entry in early_turn['mutations']:
                            if not entry or entry['value'] is None: continue
                            value = bytes.fromhex(entry['value'])
                            if value.startswith(b'STW1') and value[156] == 2 and int.from_bytes(value[60:68], 'little') == publication_gate['operation']:
                                publication_gate['operation'] = None
                                publication_gate['seen'].set()
                                assert publication_gate['release'].wait(timeout=30), 'publication fault was never released'
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
                            if fault['prefix'] is not None and value.startswith(fault['prefix']) and not fault['seen'].is_set():
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
            generation = invoke('combined-fence' if role == 'source' else 'combined-fence-requester')['generation']
            path = root/f'{role}.json'
            settings = json.loads(path.read_text())
            settings['generation'] = generation
            path.write_text(json.dumps(settings))
            return start(f'{role}-{generation}', [host, str(path)])

        def processed(position):
            state = invoke('combined-progress')
            return state['pending'] is None or state['pending'] > position

        def mutation(sql, namespace, caller=None, compiled=None, *, object_id=None):
            caller = caller or mutations
            compiled = compiled or caller.call({'compile': dict(identity=dict(operation=str(namespace), namespace=str(namespace)), create_object=object_id, sql=sql)})['compiled']
            reference = compiled['intent']['reference']
            deadline = time.monotonic() + 180
            while time.monotonic() < deadline:
                step = caller.call({'next': reference})['next']
                if 'terminal' in step:
                    assert step['terminal']['phase'] == 'applied', step
                    return step['terminal']
                if 'running' in step:
                    # Ordered query self-delivery can precede this Table's
                    # continuation. Explicitly resume the SAME saved operation
                    # without bypassing the route's delivery order.
                    step = {'send': caller.call({'prepare_resume': reference})['prepared']}
                assert 'send' in step, step
                prepared = step['send']
                receipt = caller.call({'submit': prepared})['receipt']
                until(lambda: caller.call({'observe': dict(prepared=prepared, input=receipt['position'])})['observation'] == 'processed')
                assert caller.call({'input_disposition': dict(prepared=prepared, input=receipt['position'])})['disposition'] is None
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
            return [dict(id=int(row[0]['value']['atom']['signed']), value=row[1]['value']['atom']['utf8']) for frame in frames for row in frame['cells']]

        try:
            subprocess.run([node, str(config), '--initialize'], env=fixture.env, check=True, capture_output=True, timeout=30)
            authority = start('node', [node, str(config)])
            wait_ready(fixture.http, authority, url+'/health')
            connection = invoke('provision-combined')
            invoke('combined-initialize')
            source = start('source', [host, str(root/'source.json')])
            for phase, prefix in enumerate((b'TCA1C', b'UQA1'), 1):
                if phase == 2:
                    fault.update(prefix=prefix, seen=threading.Event(), release=threading.Event())
                    invoke('combined-delegate')
                assert fault['seen'].wait(timeout=30), 'explicit initialization commit missing'
                state = invoke('combined-state')
                assert state['phase'] == 'ready' and state['authorization_revision'] > 0, state
                assert (state['query'] is None) == (phase == 1), state
                frozen, receipt = fault['frozen'], fault['receipt']
                source.kill(); source.wait(timeout=10)
                fault['release'].set()
                same = subprocess.run([host, str(root/'source.json')], capture_output=True, env=fixture.env, timeout=15)
                assert same.returncode and b'FreshOwnershipRequired' in same.stderr, same.stderr
                authority.kill(); authority.wait(timeout=10)
                fixture.stop(); fixture.start()
                authority = start(f'node-after-{phase}', [node, str(config)])
                wait_ready(fixture.http, authority, url+'/health')
                direct = HTTPConnection('127.0.0.1', port, timeout=15)
                direct.request('POST', '/v1/command', frozen, {'Content-Type': 'application/json'})
                response = direct.getresponse()
                recovered = json.loads(response.read())
                direct.close()
                assert response.status == 200 and recovered['position'] == receipt['position'], recovered
                counts['recovered_initialization_receipts'] += 1
                source = replace('source')
            fault['prefix'] = None
            # Native role grants publish separately from catalog initialization.
            # Exact repeated catalog initialization remains safe.
            granted = invoke('combined-grants')['authorization_revision']
            position = invoke('combined-initialize')['position']
            until(lambda: processed(position))
            state = invoke('combined-state')
            assert state['query']['revision'] == 1 and state['authorization_revision'] == granted
            catalog_connection = dict(scope=dict(realm=46, resource=connection['resource'], catalog='1'), owner=connection['source'], principal=1234)
            mutations = Catalog(library, endpoint, catalog_connection); clients.append(mutations)
            cli_mutations = Cli(cli, root, endpoint, catalog_connection); clients.append(cli_mutations)
            mutation('CREATE TABLE items (id INT64 PRIMARY KEY, value UTF8)', 100, object_id='1')
            invoke('combined-source-export')
            requester = start('requester', [host, str(root/'requester.json')])
            queries = Query(library, endpoint, connection); clients.append(queries)
            settings = json.loads((root/'shell.json').read_text())
            settings.update(version=1, profile='unified_v1', execution='interactive', transport='loopback', format='json')
            (root/'console.json').write_text(json.dumps(settings))
            console_args = [cli, 'console', '--no-rc', '--config', str(root/'console.json'), '-c', 'SELECT * FROM items;']
            mutation("INSERT INTO items (id,value) VALUES(1,'old'),(2,'two')", 101)
            query(1)
            def capture_job():
                invoke('combined-deliver')
                return invoke('job', 1)['job']
            snapshot = until(capture_job)
            assert snapshot['phase'] == 'capturing', snapshot
            namespace = (1 << 63) | snapshot['id']
            # Freeze the actual final atomic publication. Staging is finished
            # before the interactive read's bounded HTTP request is held.
            updated_value = 'new-' + 'x' * 196
            publication_gate['operation'] = namespace
            applied, failures = [], []
            def concurrent_mutation():
                try: applied.append(mutation(f"UPDATE items SET value='{updated_value}' WHERE id=1", namespace, cli_mutations))
                except BaseException as error: failures.append(error)
            writer = threading.Thread(target=concurrent_mutation, daemon=True)
            writer.start()
            assert publication_gate['seen'].wait(timeout=120), ('final publication was not prepared', failures)
            pause_snapshot = True
            console = subprocess.Popen(console_args, env=fixture.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            processes.append(console)
            snapshot_deadline = time.monotonic() + 15
            while not snapshot_seen.wait(timeout=.05):
                if console.poll() is not None:
                    stdout, stderr = console.communicate()
                    raise AssertionError(('interactive query exited before snapshot retention',
                                          console.returncode, stdout, stderr))
                assert time.monotonic() < snapshot_deadline, (
                    'interactive query did not retain its snapshot',
                    counts.get('interactive_open_requests', {}), errors)
            paused = time.monotonic()
            try:
                publication_gate['release'].set()
                writer.join(timeout=10)
                assert not writer.is_alive() and not failures, failures
                assert applied[0]['counts'] == dict(matched='1', changed='1'), applied
            finally:
                counts['snapshot_pause_seconds'] = round(time.monotonic()-paused, 3)
                snapshot_release.set()
            stdout, stderr = console.communicate(timeout=30)
            assert console.returncode == 0, stderr
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
            # Hold the final native validation after row computation. Revoking
            # native SELECT must suppress even this already computed output.
            disclosure_gate['armed'] = True
            withheld = subprocess.Popen(console_args, env=fixture.env, stdout=subprocess.PIPE,
                                       stderr=subprocess.PIPE, text=True)
            processes.append(withheld)
            assert disclosure_gate['seen'].wait(timeout=30), 'interactive terminal validation missing'
            invoke('combined-select-revoke')
            disclosure_gate['release'].set()
            stdout, stderr = withheld.communicate(timeout=30)
            assert withheld.returncode == 1 and not stdout, (withheld.returncode, stdout, stderr)
            assert 'CatalogDenied' in stderr or 'QueryDenied' in stderr, stderr
            invoke('combined-select-restore')
            # Native SELECT is independent of retained query policy and raw
            # resource access. Empty interactive results require it as well.
            invoke('combined-select-revoke')
            for statement in ('SELECT * FROM items;', 'SELECT * FROM items LIMIT 0;'):
                denied_read = subprocess.run(console_args[:-1] + [statement], env=fixture.env,
                                             capture_output=True, text=True, timeout=30)
                assert denied_read.returncode == 1 and not denied_read.stdout, denied_read
                assert 'CatalogDenied' in denied_read.stderr or 'QueryDenied' in denied_read.stderr, denied_read.stderr
            invoke('combined-select-restore')
            restored = subprocess.run(console_args, env=fixture.env, capture_output=True, text=True, timeout=30)
            assert restored.returncode == 0, restored.stderr
            assert console_rows(restored.stdout) == current
            empty = subprocess.run(console_args[:-1] + ['SELECT * FROM items LIMIT 0;'],
                                   env=fixture.env, capture_output=True, text=True, timeout=30)
            assert empty.returncode == 0, empty.stderr
            assert console_rows(empty.stdout) == []
            # Autonomous continuations are explicitly delivered from here on.
            courier = start('courier', [host, str(root/'courier.json')])
            catalog_args = [cli, 'console', '--no-rc', '--config', str(root/'catalog-console.json')]
            def console_run(sql=None, data=None, code=0):
                args = catalog_args + (['-c', sql] if sql is not None else [])
                result = subprocess.run(args, input=data, env=fixture.env, capture_output=True, text=True, timeout=180)
                assert result.returncode == code, (result.returncode, result.stdout, result.stderr)
                return result
            def catalog_rows(stdout):
                frames = [json.loads(line) for line in stdout.splitlines()]
                assert frames[0]['profile'] == 'table_snapshot_v1' and frames[-1]['complete_coverage'], frames
                result = []
                for frame in frames:
                    if 'row' not in frame: continue
                    cells = frame['row']['value']['structure']
                    result.append(dict(id=int(cells[0]['value']['atom']['signed']), value=cells[1]['value']['atom']['utf8']))
                return result
            recovery_path = root/'console-writes.json'
            for sql in ('INSERT INTO items (typo,value) VALUES (9,1)', 'DELETE FROM absent WHERE id=9'):
                invalid = console_run(sql, code=1)
                assert not invalid.stdout and not recovery_path.exists()
            for sql, matched, changed in [("INSERT INTO items (id,value) VALUES (101,'console')", 1, 1),
                                  ("UPDATE items SET value='console' WHERE id=101", 1, 0),
                                  ("UPDATE items SET value='changed' WHERE id=101", 1, 1),
                                  ("DELETE FROM items WHERE id=101", 1, 1),
                                  ("DELETE FROM items WHERE id=101", 0, 0)]:
                result = json.loads(console_run(sql).stdout)['table_operation']
                assert result['phase'] == 'applied' and result['counts'] == dict(matched=str(matched), changed=str(changed)), result
            human = console_run(data=".mode table\nINSERT INTO items (value,id) VALUES ('atomic',101),('duplicate',1);\n", code=1)
            assert not human.stdout and human.stderr.count('Constraint Error:') == 1, human
            assert 'Duplicate key "id: 1"' in human.stderr and '.resume' not in human.stderr, human.stderr
            assert facts['column'] == {'text':'id'}, facts
            assert catalog_rows(console_run('SELECT * FROM items').stdout) == current
            send_fault.update(lose=True, recovered=False)
            lost = console_run("INSERT INTO items (id,value) VALUES (102,'recovered')", code=1)
            assert not lost.stdout and '.resume' in lost.stderr
            saved = recovery_path.read_bytes()
            record = json.loads(saved)
            assert record['pending']['signed'] == json.loads(send_fault['frozen']) and record['input'] is None
            assert recovery_path.stat().st_mode & 0o777 == 0o600
            console_run(data='.help\n')
            assert not send_fault['recovered'] and recovery_path.read_bytes() == saved
            status = json.loads(console_run(data='.status\n').stdout)['table_operation']
            assert status['uncertain'] and not send_fault['recovered']
            for edit in ('definition', 'key', 'connection', 'signed_definition', 'intent_digest'):
                altered = json.loads(saved)
                if edit == 'definition': del altered['definition']
                elif edit == 'key': altered['key'][0] ^= 1
                elif edit == 'connection': altered['connection']['owner'] += 1
                elif edit == 'signed_definition': del altered['pending']['signed']['request']['definition']
                else: altered['operation']['digest'][0] ^= 1
                recovery_path.write_text(json.dumps(altered, separators=(',', ':')))
                invalid = console_run(data='.resume\n', code=1)
                assert not invalid.stdout and not send_fault['recovered']
            recovery_path.write_bytes(saved)
            restored = json.loads(console_run(data='.resume\n').stdout)['table_operation']
            assert restored['phase'] == 'applied' and restored['counts'] == dict(matched='1', changed='1') and send_fault['recovered']
            assert json.loads(console_run(data='.resume\n').stdout)['table_operation'] == restored
            assert json.loads(console_run(data='.cancel\n').stdout)['table_operation'] == restored
            console_run('DELETE FROM items WHERE id=102')
            # SIGINT stops before the following statement. General Table upload
            # is cancellable; it does not inherit the removed inline writer's
            # small-request completion guarantee.
            source.send_signal(signal.SIGSTOP)
            interrupted = subprocess.Popen(catalog_args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=fixture.env)
            processes.append(interrupted)
            try:
                interrupted.stdin.write("INSERT INTO items VALUES (103,'" + "p" * 200 + "');\nDELETE FROM items WHERE id=1;\n")
                interrupted.stdin.flush()
                until(lambda: recovery_path.exists() and not json.loads(recovery_path.read_bytes())['complete'] and json.loads(recovery_path.read_bytes())['input'] is not None)
                pending = json.loads(recovery_path.read_bytes())['pending']
                assert bytes.fromhex(pending['signed']['request']['command']['send']['value'])[13:18] == b'TCA1B', pending
                interrupted.send_signal(signal.SIGINT)
                stdout, stderr = interrupted.communicate(timeout=15)
                assert interrupted.returncode == 130 and not stdout and '.resume' in stderr, (interrupted.returncode, stdout, stderr)
            finally:
                source.send_signal(signal.SIGCONT)
            cancelled = json.loads(console_run(data='.cancel\n').stdout)['table_operation']
            assert cancelled['phase'] == 'cancelled' and not cancelled['uncertain'], cancelled
            assert catalog_rows(console_run('SELECT * FROM items').stdout) == current
            # An accepted part rejected by current policy is an input disposition,
            # not a terminal operation result. Keep the original cancellation path.
            rejection_gate['armed'] = True
            racing = subprocess.Popen(catalog_args+['-c', "INSERT INTO items VALUES (104,'" + 'd' * 200 + "')"], env=fixture.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            processes.append(racing)
            try:
                assert rejection_gate['seen'].wait(timeout=30), 'console did not prepare a Table part'
                # Native grant publication is synchronous; it no longer
                # enqueues a policy mutation in the Table owner's mailbox.
                assert invoke('combined-mutation-revoke')['authorization_revision'] > 0
            finally:
                rejection_gate['release'].set()
            stdout, stderr = racing.communicate(timeout=30)
            rejected_input = json.loads(stdout)['table_operation']
            assert racing.returncode == 1 and rejected_input['phase'] == 'uploading', (racing.returncode, stdout, stderr)
            assert rejected_input['input_disposition'] == 'denied' and rejected_input['input_diagnostic']['outcome'] == 'input_rejected', rejected_input
            assert not json.loads(recovery_path.read_bytes())['complete']
            blocked = console_run('SELECT * FROM items', code=1)
            assert not blocked.stdout and '.cancel' in blocked.stderr
            cancelled = json.loads(console_run(data='.cancel\n').stdout)['table_operation']
            assert cancelled['phase'] == 'cancelled', cancelled
            assert invoke('combined-mutation-restore')['authorization_revision'] > 0
            assert catalog_rows(console_run('SELECT * FROM items').stdout) == current
            print('General console: atomic DML/counts, diagnostics, exact saved recovery, identity rejection, SIGINT and policy-raced cancellation passed.', flush=True)
            sdk_results = []
            for index, (label, factory) in enumerate(installed):
                caller_started = time.monotonic()
                owner = factory(endpoint, catalog_connection, root); clients.append(owner)
                result = owner.call({'scenario': {'index': index}})
                sdk_results.append(dict(caller=label, seconds=round(time.monotonic()-caller_started, 3), result=result))
            position = invoke('combined-query-revoke')['position']
            until(lambda: processed(position))
            denied(lambda: rows(1), 'QueryDenied')
            mutation("UPDATE items SET value='after-revocation' WHERE id=2", (1 << 64)-1)
            position = invoke('combined-query-restore')['position']
            until(lambda: processed(position))
            assert invoke('combined-mutation-revoke')['authorization_revision'] > 0
            denied(lambda: mutation('DELETE FROM items WHERE id=1', 17), 'CatalogDenied')
            denied_console = console_run('DELETE FROM items WHERE id=1', code=1)
            assert not denied_console.stdout
            # Inspect/read rights remain independently usable after DML denial.
            assert json.loads(console_run('DESCRIBE items').stdout)['table']['name'] == 'items'

            query(3); complete(3)
            assert rows(3) == [dict(id=1, value=updated_value), dict(id=2, value='after-revocation')]
            invoke('revoke')
            denied(lambda: rows(3), 'AccessDenied')
            denied(lambda: mutations.call({'lookup': 'items'}), 'AccessDenied')
            assert source.poll() is None and requester.poll() is None
            assert not errors, errors
            print(json.dumps(dict(proof='combined Table query/writer', elapsed_seconds=round(time.monotonic()-started, 3), **counts, resident_pages=8, mutation_namespace=str(namespace), installed_sdks=list(sdks), sdk_install_seconds=sdk_install_seconds, sdk_callers=sdk_results, binaries={name: hashlib.sha256(Path(path).read_bytes()).hexdigest() for name, path in binaries.items()})), flush=True)
            print('Combined Table host: separate initialization and delegation commits survive lost receipts, fresh fencing and node/store restart; durable and interactive query snapshots survive interleaved same-namespace CLI mutations; independent policy and current native disclosure gates pass.', flush=True)
        except BaseException:
            for log in logs:
                log.flush()
                print(f'--- {Path(log.name).name} ---\n'+Path(log.name).read_text()[-6000:], file=sys.stderr)
            raise
        finally:
            fault['release'].set()
            rejection_gate['release'].set()
            snapshot_release.set()
            publication_gate['release'].set()
            disclosure_gate['release'].set()
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

"""General typed commands through signed callers, real GenServer and disk Ursula."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import argparse
from contextlib import nullcontext
import json
import select
from pathlib import Path
import subprocess
import sys
import threading
import time

from storage import Fixture, free_port, wait_ready
from cold_storage import ColdStore


def run(node, proof, host, cli, station_host, *arguments):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk', action='append', default=[], choices=('node', 'python', 'rust', 'ruby', 'java', 'dotnet', 'erlang', 'elixir', 'c', 'cpp'))
    parser.add_argument('--grow', type=int, default=0)
    parser.add_argument('--cold', action='store_true')
    parser.add_argument('--maintained', action='store_true', help='Run the complete maintained revision schedule; requires bounded cold storage')
    options = parser.parse_args(arguments)
    if not 0 <= options.grow <= 10000:
        parser.error('growth schedule requires 0..10000 additional Tables')
    if options.maintained and not options.cold:
        parser.error('maintained history proof requires --cold; hot-only storage has a finite total capacity')
    languages = options.sdk
    node, proof, host, cli, station_host = (str(Path(binary).resolve()) for binary in (node, proof, host, cli, station_host))
    with ColdStore() if options.cold else nullcontext() as cold_store, Fixture(cold_store.config() if cold_store else None) as fixture:
        root = fixture.root
        public = json.loads(subprocess.check_output([proof, 'public'], timeout=10))
        port = free_port()
        direct = f'http://127.0.0.1:{port}'
        config = root / 'node.json'
        config.write_text(json.dumps(dict(profile='native_v1', genesis=dict(
            realm=46, root_key=public, max_clock_error_ms=10000),
            ursula_url=fixture.url, bucket='typed-tables', journal='authority',
            port=port, resident_pages=8, request_timeout_ms=10000)))
        faults, replays, failures = {}, set(), []
        armed = None
        host_committed = threading.Event()
        release_host_reply = threading.Event()
        measurements = dict(turns=0, sends=0, max_mutations=0, max_value_bytes=0, dispositions=[], client_disconnects=0)
        archived_heads = {}

        observed_commands = []
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                nonlocal armed
                body = self.rfile.read(int(self.headers['Content-Length']))
                connection = HTTPConnection('127.0.0.1', port, timeout=15)
                abandoned_host = False
                try:
                    connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == '/v1/command' and response.status == 200:
                        command = json.loads(body)['request']['command']
                        observed_commands.extend(command)
                        measurements['sends'] += int('send' in command)
                        turn = command.get('turn', command.get('turn_with_versions', {}).get('turn'))
                        if turn:
                            mutations = [entry for entry in turn.get('mutations', []) if entry]
                            measurements['turns'] += 1
                            measurements['max_mutations'] = max(measurements['max_mutations'], len(mutations))
                            for entry in mutations:
                                if entry['value']:
                                    encoded = bytes.fromhex(entry['value'])
                                    measurements['max_value_bytes'] = max(measurements['max_value_bytes'], len(encoded))
                                    if encoded.startswith(b'TCA1E'):
                                        measurements['dispositions'].append(encoded[-1])
                                    if encoded.startswith(b'STJ1'):
                                        # Head resource is inside STJ1 + STH1;
                                        # exact native retries cannot count twice.
                                        identity = encoded[48:56].hex(), entry['key']
                                        if identity in archived_heads:
                                            assert archived_heads[identity] == encoded
                                        archived_heads[identity] = encoded
                        for name, (original, receipt) in faults.items():
                            if body == original:
                                assert data == receipt, 'Exact accepted request changed its receipt'
                                replays.add(name)
                        selected = 'turn' if turn else 'send' if 'send' in command else None
                        if (armed == selected and selected is not None) or (armed == 'host_turn' and turn):
                            abandoned_host = armed == 'host_turn'
                            faults[armed] = body, data
                            armed = None
                            if abandoned_host:
                                # The native commit exists; its receipt cannot
                                # reach the worker before this process is killed.
                                host_committed.set()
                                assert release_host_reply.wait(30), 'Host fault was not released'
                            data = b'{"position":0}'
                    try:
                        self.send_response(response.status)
                        self.send_header('Content-Type', 'application/json')
                        self.send_header('Content-Length', str(len(data)))
                        self.end_headers()
                        self.wfile.write(data)
                    except (BrokenPipeError, ConnectionResetError):
                        # Killing an owned host also closes its outstanding
                        # notification wait. Upstream forwarding failures still
                        # reach the outer failure collector.
                        measurements['client_disconnects'] += 1
                except BaseException as error:
                    failures.append(repr(error))
                    raise
                finally:
                    connection.close()

        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        url = f'http://127.0.0.1:{proxy.server_port}'
        log = (root / 'node.log').open('w+')
        authority = None
        readers = []
        renewable_readers = {}
        snapshot_renewals = 0
        workers = []
        worker_logs = []
        hosted = False
        maintained = None
        started = time.monotonic()
        try:
            subprocess.run([node, str(config), '--initialize'], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=30)

            def start():
                process = subprocess.Popen([node, str(config)], stdout=log, stderr=subprocess.STDOUT)
                wait_ready(fixture.http, process, direct + '/health')
                return process

            def call(mode, *args, fail=False, expected_error=None, directory=None):
                nonlocal snapshot_renewals
                for reader, renewed_at in list(renewable_readers.items()):
                    if time.monotonic() - renewed_at >= 10:
                        reader.stdin.write('k')
                        reader.stdin.flush()
                        assert select.select([reader.stdout], [], [], 30)[0], 'Held snapshot renewal did not finish'
                        assert reader.stdout.readline() == '{"renewed":true}\n', 'Held snapshot renewal failed'
                        renewable_readers[reader] = time.monotonic()
                        snapshot_renewals += 1
                result = subprocess.run([proof, url, mode, str(directory or root), *map(str, args)], capture_output=True, text=True, timeout=300)
                if fail:
                    assert result.returncode != 0, f'{mode} unexpectedly succeeded at lost-reply boundary'
                    if expected_error:
                        assert expected_error in result.stderr, (mode, result.stderr)
                    return None
                if result.returncode:
                    raise RuntimeError(f'{mode}: {result.stderr[-12000:]}')
                return json.loads(result.stdout)

            def finish(directory=None):
                deadline = time.monotonic() + 300
                for _ in range(1000):
                    assert time.monotonic() < deadline, 'Typed operation exceeded its time budget'
                    if hosted:
                        assert all(worker.poll() is None for worker in workers), 'Supplied host stopped'
                    result = call('next', directory=directory)
                    if result['state'] == 'terminal':
                        return result
                    assert result['state'] in ('sent', 'running'), result
                    if hosted:
                        if result['state'] == 'running':
                            time.sleep(.02)
                    else:
                        pumped = call('pump', directory=directory)
                        if result['state'] == 'running' and pumped['state'] == 'idle' and pumped['committed'] == 0:
                            raise AssertionError(f'Owner stopped before terminal SQL: {measurements}')
                    if result['state'] == 'sent':
                        while True:
                            processed = call('progress', directory=directory)
                            if processed['state'] != 'pending' or not hosted:
                                break
                            assert time.monotonic() < deadline, 'Supplied host failed to process input'
                            assert all(worker.poll() is None for worker in workers), 'Supplied host stopped'
                        assert processed['state'] != 'disposed', processed
                raise AssertionError('Typed operation failed to finish within its finite proof budget')

            def execute(operation, sql, object_id='-', directory=None):
                call('compile', operation, object_id, sql, directory=directory)
                return finish(directory)

            def applied(result):
                assert result['state'] == 'terminal', result
                assert result['outcome'] == 'applied' or (result['outcome'] == 'delegated' and result['table_outcome'] == 'applied'), result

            def hold(sql, mode='select-held', second=None):
                process = subprocess.Popen([proof, url, mode, str(root), sql, *([str(second)] if second else [])], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                readers.append(process)
                assert select.select([process.stdout], [], [], 30)[0], 'Table SELECT did not acquire its snapshot'
                ready = process.stdout.readline()
                assert ready == '{"ready":true}\n', (ready, process.poll())
                return process

            def release(process, error=None):
                renewable_readers.pop(process, None)
                output, detail = process.communicate('x', timeout=30)
                if error:
                    assert process.returncode != 0 and error in detail, (output, detail)
                    assert '"complete":true' not in output, output
                    return None
                assert process.returncode == 0, detail
                return json.loads(output)

            authority = start()
            call('provision')
            call('initialize')
            call('pump')
            call('compile', 1, 100, 'CREATE TABLE people (id INTEGER PRIMARY KEY, name VARCHAR(200) NOT NULL, department_id INTEGER, active BOOLEAN DEFAULT TRUE, salary DECIMAL(18, 2))')
            armed = 'send'
            call('next', fail=True)
            original = call('retry-send')
            assert original['state'] == 'sent'
            armed = 'turn'
            call('pump', fail=True)
            assert (root / 'worker.json').exists()
            authority.kill()
            authority.wait(timeout=10)
            authority = None
            fixture.stop()
            fixture.start()
            authority = start()
            call('pump')
            result = finish()
            assert result['outcome'] == 'applied', result
            assert {'send', 'turn'} == replays and not failures, (replays, failures)
            result = execute(2, "INSERT INTO people (id, name, salary) VALUES (1, 'Ada', 125000.00), (2, 'Grace', 140000.00)")
            assert (result['matched'], result['changed']) == (2, 2), result
            data = call('inspect', 'people')
            assert data['count'] == 2 and len(data['columns']) == 5, data
            first = [cell['cell'] for cell in data['rows'][0]]
            assert first[0] == {'value': {'atom': {'signed': '1'}}}, first
            assert first[1] == {'value': {'atom': {'utf8': 'Ada'}}}, first
            assert first[2] == {'null': {}}, first
            assert first[3] == {'value': {'atom': {'boolean': True}}}, first
            assert first[4] == {'value': {'atom': {'decimal': '12500000'}}}, first
            selected = call('select', 'SELECT * FROM people')
            assert selected['complete'] and selected['rows'] == data['rows'], selected
            point = call('select', 'SELECT name, salary FROM people WHERE id=2')
            assert point['scanned'] == 1 and point['rows'][0][0]['cell']['value']['atom']['utf8'] == 'Grace', point
            missing = call('select', 'SELECT * FROM people WHERE id=999')
            assert missing['scanned'] == 0 and missing['rows'] == [], missing
            filtered_point = call('select', "SELECT * FROM people WHERE id=2 AND name='Ada'")
            # Residual predicates retain the declared scan profile. Finding a
            # key term does not discard another eagerly evaluated atom.
            assert filtered_point['scanned'] == 2 and filtered_point['rows'] == [], filtered_point
            assert call('select', 'SELECT COUNT(salary) FROM people')['rows'][0][0]['cell']['value']['atom']['unsigned'] == '2'
            assert call('select', 'SELECT * FROM people LIMIT 0')['rows'] == []
            # Snapshot backfill pauses while later transactions remain durable.
            applied(execute(910001, 'CREATE TABLE cdc_rows (k BIGINT, v BIGINT)', 910001))
            applied(execute(910002, 'INSERT INTO cdc_rows VALUES (1,10)'))
            backfill = hold('cdc_rows', 'history-snapshot-held')
            history_mutation_start = time.monotonic()
            history_turns_before = measurements['turns']
            history_records_before = len(archived_heads)
            applied(execute(910003, 'INSERT INTO cdc_rows VALUES (2,20)'))
            applied(execute(910004, 'UPDATE cdc_rows SET v = 11 WHERE k = 1'))
            applied(execute(910005, 'UPDATE cdc_rows SET v = 11 WHERE k = 1'))
            applied(execute(910006, 'DELETE FROM cdc_rows WHERE k = 2'))
            history_measurements = dict(mutation_seconds=round(time.monotonic() - history_mutation_start, 3),
                mutation_turns=measurements['turns'] - history_turns_before,
                added_history_records=len(archived_heads) - history_records_before)
            assert release(backfill)['rows'] == [[1,10]]
            saved_position = (root / 'table-tail.json').read_bytes()
            for field in ('version', 'definition'):
                malformed = json.loads(saved_position)
                del malformed[field]
                (root / 'table-tail.json').write_text(json.dumps(malformed, separators=(',', ':')))
                call('history-tail', fail=True, expected_error='MissingField')
            malformed = json.loads(saved_position)
            malformed['definition'] = 'foreign-definition'
            (root / 'table-tail.json').write_text(json.dumps(malformed, separators=(',', ':')))
            call('history-tail', fail=True, expected_error='InvalidEnumTag')
            (root / 'table-tail.json').write_bytes(saved_position)
            catchup_started = time.monotonic()
            tail = call('history-tail')
            history_measurements['tail_seconds'] = round(time.monotonic() - catchup_started, 3)
            history_measurements['transactions'] = len(tail['transactions'])
            assert tail['complete'] and len(tail['transactions']) > 4, tail
            changes = [row for tx in tail['transactions'] for row in tx['changes']]
            assert [(row['before'], row['after']) for row in changes] == [(None,[2,20]),([1,10],[1,11]),([2,20],None)], changes
            assert changes[0]['identity'] == changes[2]['identity']
            assert any(not tx['changes'] for tx in tail['transactions'])
            for previous, following in zip(tail['transactions'], tail['transactions'][1:]):
                assert following['previous'] == previous['next'] and following['commit'] > previous['commit']
            assert call('history-tail') == tail, 'Repeating a complete cursor changed its transactions'
            denied_tail = hold('cdc_rows', 'history-tail-held')
            call('table-select', 'deny')
            call('pump')
            release(denied_tail, 'CatalogDenied')
            call('table-select', 'allow')
            call('pump')
            applied(execute(910007, 'DROP TABLE cdc_rows'))
            applied(execute(910008, 'CREATE TABLE cdc_rows (v BIGINT)', 910008))
            retired_tail = call('history-tail')
            assert retired_tail['transactions'][:-1] == tail['transactions']
            assert retired_tail['transactions'][-1]['retired']
            call('select', 'SELECT * FROM people', 1, 128, 100000, fail=True, expected_error='QueryPageBudget')
            call('select', 'SELECT * FROM people', 10000, 1, 100000, fail=True, expected_error='QueryResultBudget')
            call('select', 'SELECT * FROM people', 10000, 128, 1, fail=True, expected_error='QueryResultBudget')
            # Real signed relational SQL over general Tables. Both objects live
            # in one resource, so every alias must bind one shared native cut.
            applied(execute(900001, 'CREATE TABLE rel_left (k BIGINT, v BIGINT)', 900001))
            applied(execute(900002, 'CREATE TABLE rel_right (k BIGINT, v BIGINT)', 900002))
            applied(execute(900003, 'INSERT INTO rel_left VALUES (7,10),(7,20),(9,30),(NULL,40)'))
            applied(execute(900004, 'INSERT INTO rel_right VALUES (7,1),(7,2),(7,3),(NULL,4)'))

            def relational_values(result):
                assert result['complete'], result
                values = []
                for row in result['rows']:
                    cells = []
                    for encoded in row:
                        cell = encoded['cell']
                        cells.append(None if 'null' in cell else int(next(iter(cell['value']['atom'].values()))))
                    values.append(cells)
                return values

            vector_samples = []
            for sql, expected in [
                ('SELECT v FROM rel_left WHERE k >= 7', [[10], [20], [30]]),
                ('SELECT COUNT(*) FROM rel_left', [[4]]),
                ('SELECT COUNT(k) FROM rel_left', [[3]]),
                ('SELECT v FROM rel_left LIMIT 0', []),
                ('SELECT v FROM rel_left WHERE k = 999', []),
            ]:
                for repetition in range(3):
                    for mode in (('select', 'select-batch') if repetition % 2 else ('select-batch', 'select')):
                        began = time.monotonic_ns()
                        result = call(mode, sql)
                        vector_samples.append(dict(sql=sql, engine=mode, repetition=repetition, elapsed_ns=time.monotonic_ns()-began))
                        assert relational_values(result) == expected, result
            denied_buffer = hold('SELECT v FROM rel_left', 'select-batch-buffered')
            call('table-select', 'deny')
            call('pump')
            release(denied_buffer, 'CatalogDenied')
            call('table-select', 'allow')
            call('pump')

            joined = call('relational', 'SELECT l.v AS left_value, r.v AS right_value FROM rel_left l JOIN rel_right r ON l.k = r.k')
            assert relational_values(joined) == [[10,1],[10,2],[10,3],[20,1],[20,2],[20,3]], joined
            assert joined['cuts'][0]['revision'] == joined['cuts'][1]['revision']
            assert joined['cuts'][0]['commitment'] == joined['cuts'][1]['commitment']
            grouped_sql = 'SELECT l.k, COUNT(*) AS rows, COUNT(r.v) AS present, SUM(r.v) AS total FROM rel_left l LEFT JOIN rel_right r ON l.k = r.k GROUP BY l.k'
            grouped = call('relational', grouped_sql)
            assert relational_values(grouped) == [[None,1,0,None],[7,6,6,12],[9,1,0,None]], grouped
            assert grouped['spill_bytes'] > 0
            assert relational_values(call('relational', 'SELECT COUNT(*) AS n, SUM(l.v) AS total FROM rel_left l WHERE l.k = 999')) == [[0,None]]
            assert relational_values(call('relational', 'SELECT l.k, COUNT(*) AS n FROM rel_left l WHERE l.k = 999 GROUP BY l.k')) == []
            self_join = call('relational', 'SELECT COUNT(*) AS n FROM rel_left l JOIN rel_left r ON l.k = r.k')
            assert relational_values(self_join) == [[5]], self_join
            retained_relation = hold(grouped_sql, 'relational-held')
            applied(execute(900005, 'UPDATE rel_right SET v = 100 WHERE k = 7'))
            assert relational_values(release(retained_relation)) == [[None,1,0,None],[7,6,6,12],[9,1,0,None]]
            assert relational_values(call('relational', grouped_sql)) == [[None,1,0,None],[7,6,6,600],[9,1,0,None]]
            denied_relation = hold(grouped_sql, 'relational-held')
            call('table-select', 'deny')
            call('pump')
            release(denied_relation, 'CatalogDenied')
            call('table-select', 'allow')
            call('pump')
            secondary = root / 'secondary'
            secondary.mkdir()
            call('provision', 65538, directory=secondary)
            call('initialize', directory=secondary)
            call('pump', directory=secondary)
            # Equal numeric catalog/object IDs in distinct resources remain
            # distinct identities; they must not alias a cut or schema owner.
            applied(execute(900001, 'CREATE TABLE rel_right (k BIGINT, v BIGINT)', 900001, directory=secondary))
            applied(execute(900002, 'INSERT INTO rel_right VALUES (7,2)', directory=secondary))
            separate = call('relational', grouped_sql, secondary)
            assert separate['cuts'][0]['resource'] != separate['cuts'][1]['resource']
            assert separate['cuts'][0]['commitment'] != separate['cuts'][1]['commitment']
            assert relational_values(separate) == [[None,1,0,None],[7,2,2,4],[9,1,0,None]]
            foreign_held = hold(grouped_sql, 'relational-held', secondary)
            applied(execute(900003, 'UPDATE rel_right SET v = 8', directory=secondary))
            assert relational_values(release(foreign_held)) == relational_values(separate)
            foreign_denied = hold(grouped_sql, 'relational-held', secondary)
            call('table-select', 'deny', directory=secondary)
            call('pump', directory=secondary)
            release(foreign_denied, 'CatalogDenied')
            call('table-select', 'allow', directory=secondary)
            call('pump', directory=secondary)
            # A captured job retains each resource cut across later Table
            # changes, private staging, exact lost-receipt replay and disk loss.
            call('captured-plan', grouped_sql, secondary)
            call('captured-enqueue')
            for _ in range(1000):
                call('captured-pump', 1)
                captured = call('captured-status')
                if captured['state'] == 'capturing' and captured['checkpoint']:
                    break
            else:
                raise AssertionError('Captured owner did not publish a checkpoint')
            applied(execute(900004, 'UPDATE rel_right SET v = 90', directory=secondary))
            armed = 'turn'
            call('captured-pump', 1, fail=True, expected_error='InvalidAuthorityResponse')
            assert (root / 'relational-worker.json').exists()
            authority.kill()
            authority.wait(timeout=10)
            authority = None
            fixture.stop()
            fixture.start()
            authority = start()
            call('captured-rotate')
            assert call('history-tail') == retired_tail, 'Table history changed after authority and disk restart'
            call('captured-pump')
            captured = call('captured-status')
            assert captured['state'] == 'complete' and captured['outputs'] == 3 and not captured['released'], captured
            assert relational_values(call('captured-result')) == [[None,1,0,None],[7,2,2,16],[9,1,0,None]]
            call('table-select', 'deny', directory=secondary)
            call('pump', directory=secondary)
            call('captured-result', fail=True, expected_error='CatalogDenied')
            call('table-select', 'allow', directory=secondary)
            call('pump', directory=secondary)
            call('captured-worker-deny')
            call('captured-retire')
            call('captured-clean')
            captured = call('captured-status')
            assert captured['state'] == 'retired' and captured['released'], captured
            call('captured-result', fail=True, expected_error='IncompleteResult')
            call('captured-collect')
            call('captured-clean')
            assert call('captured-status')['collected']

            def restart_maintenance():
                nonlocal authority
                authority.kill()
                authority.wait(timeout=10)
                authority = None
                fixture.stop()
                fixture.start()
                authority = start()

            def arm_maintenance():
                nonlocal armed
                armed = 'turn'

            rejected_update = execute(13, 'UPDATE people SET id = 9')
            assert rejected_update['outcome'] == 'rejected' and rejected_update['witness'] == dict(
                source='stored', row=dict(origin=1235, operation=2, ordinal=1), column=0, preview='9', truncated=False), rejected_update
            denied = hold('SELECT * FROM people')
            call('table-select', 'deny')
            call('pump')
            release(denied, 'CatalogDenied')
            call('select', 'SELECT * FROM people LIMIT 0', fail=True, expected_error='CatalogDenied')
            hidden = call('status')
            assert hidden['witness'] == dict(source='withheld', row=dict(origin=0, operation=0, ordinal=0), column=0, preview='', truncated=False), hidden
            call('table-select', 'allow')
            call('pump')
            assert call('status') == rejected_update
            frozen = hold('SELECT * FROM people')
            # This schedule proves a retained cut across mutations, rather than
            # an idle lease. Its separate restart/expiry and denial schedules
            # below intentionally receive no renewal.
            renewable_readers[frozen] = time.monotonic() - 10
            result = execute(3, "UPDATE people SET name = 'Ada Lovelace' WHERE id = 1")
            assert (result['matched'], result['changed']) == (1, 1), result
            result = execute(4, "UPDATE people SET name = 'Ada Lovelace' WHERE id = 1")
            assert (result['matched'], result['changed']) == (1, 0), result
            result = execute(5, "INSERT INTO people (id, name) VALUES (3, 'new'), (1, 'duplicate')")
            assert result['outcome'] == 'rejected' and result['reason'] == 'row_exists', result
            assert result['witness'] == dict(source='input', row=dict(origin=1235, operation=5, ordinal=1), column=0, preview='1', truncated=False), result
            rejected_insert, rejected_intent = result, (root / 'intent.bin').read_bytes()
            assert call('inspect', 'people')['count'] == 2
            applied(execute(6, 'ALTER TABLE people ADD COLUMN email VARCHAR(320)'))
            applied(execute(7, 'ALTER TABLE people RENAME COLUMN name TO full_name'))
            data = call('inspect', 'people')
            assert data['columns'] == ['id', 'full_name', 'department_id', 'active', 'salary', 'email'], data
            applied(execute(8, 'ALTER TABLE people DROP COLUMN email'))
            result = execute(9, 'DELETE FROM people WHERE id >= 1')
            assert (result['matched'], result['changed']) == (2, 2), result
            saved = (root / 'intent.bin').read_bytes()
            assert execute(10, 'DROP TABLE people')['outcome'] == 'applied'
            assert call('inspect', 'people') == {'found': False}
            assert execute(11, 'CREATE TABLE people (id INT64, name UTF8)', 101)['outcome'] == 'applied'
            result = execute(12, "INSERT INTO people VALUES (1, 'same'), (1, 'same')")
            assert result['changed'] == 2 and call('inspect', 'people')['count'] == 2
            old = release(frozen)
            assert old['object'] == 100 and old['rows'] == selected['rows'], old
            assert call('select', 'SELECT * FROM people')['object'] == 101
            (root / 'intent.bin').write_bytes(saved)
            result = call('status')
            assert result['outcome'] == 'applied' and result['changed'] == 2, result
            (root / 'intent.bin').write_bytes(rejected_intent)
            assert call('status') == rejected_insert
            assert call('inspect', 'people')['object'] == 101
            expired = hold('SELECT * FROM people')
            authority.kill()
            authority.wait(timeout=10)
            authority = None
            fixture.stop()
            fixture.start()
            authority = start()
            release(expired, 'QueryExpired')
            assert len(call('select', 'SELECT * FROM people')['rows']) == 2
            assert call('status') == rejected_insert
            # Finish the original leased-snapshot schedule before growing the
            # retained maintenance history. Its many cold-store writes are a
            # separate workload; they do not extend the snapshot's deadline.
            if options.maintained:
                from relational_maintenance_native import run as maintained_proof
                maintained = maintained_proof(call, execute, applied, secondary, root, grouped_sql,
                    restart_maintenance, arm_maintenance, hold, release, measurements)
                assert cold_store.data_objects() > 0, 'Maintenance did not exercise cold data'
                maintained['cold_objects'] = cold_store.data_objects()
                maintained['cold_bytes'] = cold_store.file_bytes()
            # Exercise the supplied deployment binary, not the fixture's manual
            # GenServer driver. One catalog owner routes every Table; a courier
            # scoped to that single destination delivers staged continuations.
            def launch(configuration):
                output = (root / f'host-{len(worker_logs)}.log').open('w+')
                worker_logs.append(output)
                process = subprocess.Popen([host, str(root / configuration)], stdout=output, stderr=subprocess.STDOUT)
                workers.append(process)
                return process

            call('host')
            deployed = launch('host.json')
            launch('courier-config.json')
            hosted = True
            applied(execute(13, 'CREATE TABLE departments (id INTEGER PRIMARY KEY, label TEXT NOT NULL, active BOOL DEFAULT TRUE)', 102))
            result = execute(14, "INSERT INTO departments (id, label) VALUES (10, 'Engineering'), (20, 'Research')")
            assert (result['matched'], result['changed']) == (2, 2), result
            assert len(call('select', 'SELECT * FROM departments')['rows']) == 2
            applied(execute(15, 'ALTER TABLE departments ADD COLUMN budget DECIMAL(18, 2) DEFAULT 1000.00'))
            assert call('select', 'SELECT budget FROM departments WHERE id=10')['rows'][0][0]['cell']['value']['atom']['decimal'] == '100000'
            original = call('status')
            deployed.kill()
            deployed.wait(timeout=10)
            workers.remove(deployed)
            reused = subprocess.run([host, str(root / 'host.json')], capture_output=True, text=True, timeout=30)
            assert reused.returncode != 0 and 'FreshOwnershipRequired' in reused.stderr, reused.stderr
            call('host')
            deployed = launch('host.json')
            assert call('status') == original, 'Fresh ownership changed the retained outcome'
            result = execute(16, 'UPDATE departments SET active=FALSE WHERE id >= 10')
            assert (result['matched'], result['changed']) == (2, 2), result
            applied(execute(17, 'DROP TABLE departments'))
            assert call('inspect', 'departments') == {'found': False}
            assert len(call('select', 'SELECT * FROM people')['rows']) == 2
            call('compile', 18, '-', "UPDATE people SET name='after restart'")
            armed = 'host_turn'
            assert call('next')['state'] == 'sent'
            assert host_committed.wait(30), 'Supplied catalog host did not commit at fault boundary'
            deployed.kill()
            deployed.wait(timeout=10)
            workers.remove(deployed)
            release_host_reply.set()
            call('host')
            launch('host.json')
            result = finish()
            assert (result['matched'], result['changed']) == (2, 2), result
            rows = call('select', 'SELECT name FROM people')['rows']
            assert len(rows) == 2 and all(row[0]['cell']['value']['atom']['utf8'] == 'after restart' for row in rows), rows
            def console(sql=None, script=None, fail=False):
                args = [cli, 'console', '--config', str(root / 'console.json')]
                if sql is not None:
                    args += ['-c', sql]
                result = subprocess.run(args, input=script, capture_output=True, text=True, timeout=300)
                assert (result.returncode != 0) == fail, (args, result.stdout, result.stderr)
                return result

            required = console(grouped_sql, fail=True)
            assert 'relational.consistency' in required.stderr, required.stderr
            console_config = json.loads((root / 'console.json').read_text())
            console_config['relational'] = dict(consistency='per_resource_snapshot_vector',
                budgets=dict(resident_bytes=16777216, spill_bytes=16777216, result_bytes=8388608,
                             output_rows=1000, work_steps=100000, source_pins=2),
                requests=100000, spill_work=100000)
            (root / 'console.json').write_text(json.dumps(console_config))
            console_join = [json.loads(line) for line in console(grouped_sql).stdout.splitlines()]
            assert console_join[0]['profile'] == 'relational_snapshot_v1', console_join
            assert console_join[0]['consistency'] == 'per_resource_snapshot_vector'
            assert console_join[-1]['complete_coverage'] and console_join[-1]['complete']['rows'] == '3', console_join
            explain_start = len(observed_commands)
            relational_explain = json.loads(console('EXPLAIN ' + grouped_sql).stdout)['explanation']
            assert relational_explain['join'] == 'left' and relational_explain['grouped']
            assert not relational_explain['executed'] and relational_explain['sources'] == 2
            assert relational_explain['basis'] is None
            explain_commands = set(observed_commands[explain_start:])
            assert explain_commands <= {'inspect'}, explain_commands
            ambiguous = console('SELECT v FROM rel_left l JOIN rel_right r ON l.k = r.k', fail=True)
            assert 'ambiguous' in ambiguous.stderr.lower() and 'line 1, column 8' in ambiguous.stderr, ambiguous.stderr
            console('CREATE TABLE console_people (id INTEGER PRIMARY KEY, name VARCHAR(200) NOT NULL, active BOOLEAN DEFAULT TRUE, salary DECIMAL(18,2))')
            listed = [json.loads(line) for line in console('SHOW TABLES').stdout.splitlines()]
            names = [name for page in listed for name in page['tables']]
            assert {'people', 'console_people'} <= set(names) and len(names) == len(set(names)), listed
            assert listed[-1]['complete'], listed
            assisted = call('assist', 'SELECT na FROM console_people', str(len('SELECT na')))
            assert assisted['profile'] == 'catalog_v1' and [item['text'] for item in assisted['items']] == ['"name"'], assisted
            relational_draft = 'SELECT r.v FROM rel_left l JOIN rel_right r ON l.k = r.k'
            assisted = call('assist', relational_draft, len('SELECT r.v'))
            assert [item['text'] for item in assisted['items']] == ['"v"'], assisted
            relational_draft = 'SELECT  FROM rel_left l JOIN rel_right r ON l.k = r.k'
            assisted = call('assist', relational_draft, len('SELECT '))
            assert {'"l"."k"', '"l"."v"', '"r"."k"', '"r"."v"'} <= {item['text'] for item in assisted['items']}, assisted
            assisted = call('assist', grouped_sql + ' ', len(grouped_sql + ' '))
            assert not {'LIMIT', 'HAVING', 'ORDER'} & {item['text'] for item in assisted['items']}, assisted
            sources = call('assist', 'SELECT * FROM console_', str(len('SELECT * FROM console_')))
            assert '"console_people"' in [item['text'] for item in sources['items']], sources
            altered = call('assist', 'ALTER TABLE console_people ALTER COLUMN name SET ', str(len('ALTER TABLE console_people ALTER COLUMN name SET ')))
            assert {'DEFAULT', 'NOT', 'DATA'} <= {item['text'] for item in altered['items']}, altered
            inserted = console("INSERT INTO console_people (id,name,salary) VALUES (1,'Ada',125000.00), (2,'Grace',140000.00)")
            assert json.loads(inserted.stdout)['table_operation']['counts'] == {'matched': '2', 'changed': '2'}, inserted.stdout
            console("INSERT INTO console_people (id,name) VALUES (1,'duplicate')", fail=True)
            observed = console(script='.status\n')
            rejected = json.loads(observed.stdout)['table_operation']
            assert rejected['phase'] == 'rejected', observed.stdout
            facts = {fact['field']: fact for fact in rejected['diagnostic']['facts'] if fact}
            assert facts['key']['value']['text'] == '1' and facts['column']['value']['text'] == 'id', facts
            assert facts['input_row']['value']['unsigned'] == '1', facts
            human_error = console(script=".mode table\nINSERT INTO console_people (id,name) VALUES (1,'duplicate');\n", fail=True)
            assert 'Duplicate key "id: 1" violates the primary key constraint.' in human_error.stderr, human_error.stderr
            table = console(script='.mode table\nSELECT id,name,salary FROM console_people;\n')
            assert '125000.00' in table.stdout and 'Ada' in table.stdout and '2 rows' in table.stdout, table.stdout
            explanation = json.loads(console('EXPLAIN SELECT name FROM console_people WHERE id=1').stdout)['explanation']
            assert explanation['scan'] == 'primary_key' and not explanation['executed'], explanation
            for invalid in ('SELECT FROM console_people', 'EXPLAIN SELECT FROM console_people',
                            'EXPLAIN SELECT name FROM console_people WHERE name ='):
                failure = console(invalid, fail=True)
                offset = invalid.index('FROM') if 'SELECT FROM' in invalid else len(invalid)
                assert f'line 1, column {offset + 1}' in failure.stderr, failure.stderr
                assert 'Table SELECT cannot be compiled' in failure.stderr, failure.stderr
            for invalid, token in (
                ('SELECT absent FROM console_people WHERE id=1', 'absent'),
                ('EXPLAIN SELECT absent FROM console_people WHERE id=1', 'absent'),
                ('SELECT name FROM console_people WHERE wrong.id=1', 'wrong'),
                ('EXPLAIN SELECT name FROM console_people WHERE salary=1.001', '1.001'),
                ('UPDATE console_people SET absent=1', 'absent'),
                ('INSERT INTO console_people (id,name) VALUES (3,NULL)', 'NULL'),
                ('ALTER TABLE console_people DROP COLUMN absent', 'absent'),
                ('CREATE TABLE bad (id INT, PRIMARY KEY(absent))', 'absent'),
            ):
                failure = console(invalid, fail=True)
                assert f'line 1, column {invalid.index(token) + 1}' in failure.stderr, failure.stderr
            replays.discard('send')
            armed = 'send'
            console("UPDATE console_people SET name='Ada Lovelace' WHERE id=1", fail=True)
            saved = json.loads((root / 'console-writes.json').read_text())
            assert saved['pending'] is not None and saved['input'] is None and not saved['complete'], saved
            resumed = console(script='.resume\n')
            assert json.loads(resumed.stdout)['table_operation']['counts'] == {'matched': '1', 'changed': '1'}, resumed.stdout
            after = json.loads((root / 'console-writes.json').read_text())
            assert after['operation'] == saved['operation'] and after['complete'], after
            assert 'send' in replays and json.loads(faults['send'][0]) == saved['pending']['signed'], 'Console did not reconcile the exact original upload command'
            armed = 'send'
            console("INSERT INTO console_people (id,name) VALUES (3,'cancelled')", fail=True)
            private = (root / 'console-writes.json').read_bytes()
            sends = measurements['sends']
            status = json.loads(console(script='.status\n').stdout)['table_operation']
            assert status['uncertain'] and measurements['sends'] == sends, status
            assert (root / 'console-writes.json').read_bytes() == private
            cancelled = json.loads(console(script='.cancel\n').stdout)['table_operation']
            assert cancelled['phase'] == 'cancelled' and not cancelled['uncertain'] and cancelled['counts'] is None, cancelled
            assert json.loads((root / 'console-writes.json').read_text())['operation'] == json.loads(private)['operation']
            empty = [json.loads(line) for line in console('SELECT * FROM console_people WHERE id=3').stdout.splitlines()]
            assert not any('row' in line for line in empty) and empty[-1]['complete']['rows'] == '0', empty
            console('ALTER TABLE console_people ADD COLUMN note TEXT')
            tightened = console('ALTER TABLE console_people ALTER COLUMN note SET NOT NULL', fail=True)
            failed = json.loads(tightened.stdout)['table_operation']
            facts = {fact['field']: fact for fact in failed['diagnostic']['facts'] if fact}
            assert failed['phase'] == 'rejected' and facts['column']['value']['text'] == 'note', failed
            assert facts['supplied_value']['value']['text'] == 'NULL' and len(facts['source_row']['value']['text']) == 40, facts
            described = json.loads(console('DESCRIBE console_people').stdout)['table']
            assert [column['name'] for column in described['columns']] == ['id', 'name', 'active', 'salary', 'note'], described
            console('DELETE FROM console_people WHERE id >= 1')
            console('DROP TABLE console_people')
            names = [name for line in console('SHOW TABLES').stdout.splitlines() for name in json.loads(line)['tables']]
            assert 'people' in names and 'console_people' not in names, names
            console('CREATE TABLE console_output (payload TEXT)')
            payload = '\x1b' * 512
            console(f"INSERT INTO console_output VALUES ('{payload}')")
            projection = ', '.join(f'payload AS c{i}' for i in range(64))
            expanded = console(f'SELECT {projection} FROM console_output')
            frames = [json.loads(line) for line in expanded.stdout.splitlines()]
            assert len(expanded.stdout) > 16384 and '\x1b' not in expanded.stdout, len(expanded.stdout)
            assert len(frames) == 3 and frames[-1]['complete']['rows'] == '1', frames[-1]
            cells = frames[1]['row']['value']['structure']
            assert len(cells) == 64 and all(cell['value']['atom']['utf8'] == payload for cell in cells)
            console('DROP TABLE console_output')
            from typed_table_bridge import run as bridge_proof
            bridge_result = bridge_proof(station_host, url, root, readers, lambda sql: call('select', sql))
            from catalog_cli import qualify as cli_proof
            def lose_cli_send():
                nonlocal armed
                armed = 'send'
            cli_result = cli_proof(cli, root, url, lambda sql: call('select', sql), lose_cli_send)
            installed = []
            if languages:
                from sdk_catalog import install
                catalog_connection = json.loads((root / 'console.json').read_text())['catalog']
                catalog_connection['scope']['catalog'] = str(catalog_connection['scope']['catalog'])
                for index, (language, factory) in enumerate(install(root / 'installed-general-tables', languages)):
                    consumer = factory(url, catalog_connection, root)
                    try:
                        installed.append(dict(language=language, result=consumer.call({'scenario': {'index': index}})))
                    finally:
                        consumer.close()

            def restart_owners():
                nonlocal authority
                for worker in workers:
                    if worker.poll() is None:
                        worker.kill()
                    worker.wait(timeout=10)
                workers.clear()
                authority.kill()
                authority.wait(timeout=10)
                authority = None
                fixture.stop()
                fixture.start()
                authority = start()
                call('host')
                launch('host.json')
                launch('courier-config.json')

            logical_types = None
            if not languages:
                from table_logical_types import qualify as logical_types_proof
                logical_types = logical_types_proof(call, execute, applied, restart_owners)
            from table_parameters_native import qualify as prepared_proof
            prepared_parameters = prepared_proof(proof, url, root, readers, call, execute, applied, finish, measurements)
            growth = None
            if options.grow:
                def actors():
                    return {'authority': authority, 'store': fixture.server,
                            **{f'worker_{index}': worker for index, worker in enumerate(workers)}}

                from table_growth import qualify as growth_proof
                growth = growth_proof(options.grow, cli, root, url, call, execute, applied, restart_owners, actors)
                if cold_store:
                    assert cold_store.data_objects() > 0, 'Growth did not exercise cold data'
                    growth['cold_objects'] = cold_store.data_objects()
                    growth['cold_bytes'] = cold_store.file_bytes()

            assert not failures, failures
            assert measurements['max_mutations'] <= 4 and measurements['max_value_bytes'] <= 256, measurements
            history_measurements.update(retained_records=len(archived_heads),
                retained_value_bytes=sum(map(len, archived_heads.values())),
                maximum_record_bytes=max(map(len, archived_heads.values())),
                paired_changes=len(changes), restart=True, current_denial=True)
            print(json.dumps(dict(profile='table-history-native', **history_measurements)))
            print(json.dumps(dict(profile='typed-table-native', seconds=round(time.monotonic() - started, 3), held_snapshot_renewals=snapshot_renewals, lost_reply_replays=sorted(replays), supplied_host_lost_receipt='host_turn' in faults, measurements=measurements, bridge=bridge_result, catalog_cli=cli_result, installed=installed, logical_types=logical_types, prepared_parameters=prepared_parameters, growth=growth, maintained=maintained, vectorization=dict(paired_native_samples=vector_samples, buffered_denial=True), relational=dict(join_rows=len(joined['rows']), grouped_rows=len(grouped['rows']), shared_cut=True, retained_update=True, current_denial=True, console=True, requests=grouped['requests'], spill_bytes=grouped['spill_bytes'], heap_peak=grouped['heap_peak'], captured=dict(checkpoint_restart=True, exact_receipt_retry=True, fresh_owner=True, retained_source_change=True, current_result_denial=True, denied_source_cleanup=True)))))
        finally:
            release_host_reply.set()
            for worker in workers:
                if worker.poll() is None:
                    worker.kill()
                worker.wait(timeout=10)
            for output in worker_logs:
                if sys.exc_info()[0]:
                    output.flush()
                    output.seek(0)
                    sys.stderr.write(output.read()[-12000:])
                output.close()
            for reader in readers:
                if reader.poll() is None:
                    reader.kill()
                reader.communicate(timeout=10)
            if authority:
                authority.kill()
                authority.wait(timeout=10)
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=10)
            if sys.exc_info()[0]:
                log.flush()
                log.seek(0)
                sys.stderr.write(log.read()[-12000:])
            log.close()
            if sys.exc_info()[0]:
                from recovery_fixture import retain_recovery_fixture
                retained = {}
                retain_recovery_fixture(fixture, cold_store, root.parent / 'typed-table-proof.json', retained)
                print(json.dumps({'failed_typed_table_fixture': retained}), file=sys.stderr, flush=True)


if __name__ == '__main__':
    run(*sys.argv[1:])

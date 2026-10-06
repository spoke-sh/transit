"""General typed commands through signed callers, real GenServer and disk Ursula."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import select
from pathlib import Path
import subprocess
import sys
import threading
import time

from storage import Fixture, free_port, wait_ready


def run(node, proof):
    node, proof = str(Path(node).resolve()), str(Path(proof).resolve())
    with Fixture() as fixture:
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
        measurements = dict(turns=0, max_mutations=0, max_value_bytes=0, dispositions=[])

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                nonlocal armed
                body = self.rfile.read(int(self.headers['Content-Length']))
                connection = HTTPConnection('127.0.0.1', port, timeout=15)
                try:
                    connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == '/v1/command' and response.status == 200:
                        command = json.loads(body)['request']['command']
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
                        for name, (original, receipt) in faults.items():
                            if body == original:
                                assert data == receipt, 'Exact accepted request changed its receipt'
                                replays.add(name)
                        selected = 'turn' if turn else 'send' if 'send' in command else None
                        if armed == selected and selected is not None:
                            faults[selected] = body, data
                            armed = None
                            data = b'{"position":0}'
                    self.send_response(response.status)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
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
        started = time.monotonic()
        try:
            subprocess.run([node, str(config), '--initialize'], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=30)

            def start():
                process = subprocess.Popen([node, str(config)], stdout=log, stderr=subprocess.STDOUT)
                wait_ready(fixture.http, process, direct + '/health')
                return process

            def call(mode, *args, fail=False, expected_error=None):
                result = subprocess.run([proof, url, mode, str(root), *map(str, args)], capture_output=True, text=True, timeout=300)
                if fail:
                    assert result.returncode != 0, f'{mode} unexpectedly succeeded at lost-reply boundary'
                    if expected_error:
                        assert expected_error in result.stderr, (mode, result.stderr)
                    return None
                if result.returncode:
                    raise RuntimeError(f'{mode}: {result.stderr[-12000:]}')
                return json.loads(result.stdout)

            def finish():
                for _ in range(1000):
                    result = call('next')
                    if result['state'] == 'terminal':
                        return result
                    assert result['state'] in ('sent', 'running'), result
                    pumped = call('pump')
                    if result['state'] == 'running' and pumped['state'] == 'idle' and pumped['committed'] == 0:
                        raise AssertionError(f'Owner stopped before terminal SQL: {measurements}')
                    if result['state'] == 'sent':
                        processed = call('progress')
                        assert processed['state'] != 'disposed', processed
                raise AssertionError('Typed operation failed to finish within its finite proof budget')

            def execute(operation, sql, object_id='-'):
                call('compile', operation, object_id, sql)
                return finish()

            def applied(result):
                assert result['state'] == 'terminal', result
                assert result['outcome'] == 'applied' or (result['outcome'] == 'delegated' and result['table_outcome'] == 'applied'), result

            def hold(sql):
                process = subprocess.Popen([proof, url, 'select-held', str(root), sql], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                readers.append(process)
                assert select.select([process.stdout], [], [], 30)[0], 'Table SELECT did not acquire its snapshot'
                ready = process.stdout.readline()
                assert ready == '{"ready":true}\n', (ready, process.poll())
                return process

            def release(process, error=None):
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
            assert call('select', 'SELECT COUNT(salary) FROM people')['rows'][0][0]['cell']['value']['atom']['unsigned'] == '2'
            assert call('select', 'SELECT * FROM people LIMIT 0')['rows'] == []
            call('select', 'SELECT * FROM people', 1, 128, 100000, fail=True, expected_error='QueryPageBudget')
            call('select', 'SELECT * FROM people', 10000, 1, 100000, fail=True, expected_error='QueryResultBudget')
            call('select', 'SELECT * FROM people', 10000, 128, 1, fail=True, expected_error='QueryResultBudget')
            denied = hold('SELECT * FROM people')
            call('policy', 'deny')
            call('pump')
            release(denied, 'CatalogDenied')
            call('select', 'SELECT * FROM people LIMIT 0', fail=True, expected_error='CatalogDenied')
            call('policy', 'allow')
            call('pump')
            frozen = hold('SELECT * FROM people')
            result = execute(3, "UPDATE people SET name = 'Ada Lovelace' WHERE id = 1")
            assert (result['matched'], result['changed']) == (1, 1), result
            result = execute(4, "UPDATE people SET name = 'Ada Lovelace' WHERE id = 1")
            assert (result['matched'], result['changed']) == (1, 0), result
            result = execute(5, "INSERT INTO people (id, name) VALUES (3, 'new'), (1, 'duplicate')")
            assert result['outcome'] == 'rejected' and result['reason'] == 'row_exists', result
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
            assert measurements['max_mutations'] <= 4 and measurements['max_value_bytes'] <= 256, measurements
            print(json.dumps(dict(profile='typed-table-native', seconds=round(time.monotonic() - started, 3), lost_reply_replays=sorted(replays), measurements=measurements)))
        finally:
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


if __name__ == '__main__':
    run(*sys.argv[1:])

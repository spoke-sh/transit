"""Named metadata, separate activation and exact native recovery on disk Ursula."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import threading
import time

from cold_storage import ColdStore
from storage import Fixture, free_port, wait_ready

SQL = 'SELECT l.k, COUNT(*) AS rows, SUM(r.v) AS total FROM rel_left l LEFT JOIN rel_right r ON l.k = r.k GROUP BY l.k'


def cells(row):
    return [None if 'null' in value['cell'] else int(next(iter(value['cell']['value']['atom'].values()))) for value in row]


def run(node, proof):
    node, proof = (str(Path(path).resolve()) for path in (node, proof))
    started = time.monotonic()
    with ColdStore() as cold, Fixture(cold.config()) as fixture:
        root = fixture.root
        port = free_port()
        direct = f'http://127.0.0.1:{port}'
        config = root / 'node.json'
        public = json.loads(subprocess.check_output([proof, 'public'], timeout=10))
        config.write_text(json.dumps(dict(profile='native_v1', genesis=dict(realm=46, root_key=public, max_clock_error_ms=10000), ursula_url=fixture.url, bucket='named-relational', journal='authority', port=port, resident_pages=8, request_timeout_ms=10000)))
        fault = dict(magic=None, original=None, receipt=None, recovered=[])
        metrics = dict(turns=0, max_mutations=0, max_value_bytes=0)
        failures = []

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                connection = HTTPConnection('127.0.0.1', port, timeout=30)
                try:
                    connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == '/v1/command' and response.status == 200:
                        command = json.loads(body)['request']['command']
                        turn = command.get('turn', command.get('turn_with_versions', {}).get('turn'))
                        if turn:
                            mutations = [entry for entry in turn['mutations'] if entry]
                            values = [bytes.fromhex(entry['value']) for entry in mutations if entry['value']]
                            metrics['turns'] += 1
                            metrics['max_mutations'] = max(metrics['max_mutations'], len(mutations))
                            metrics['max_value_bytes'] = max(metrics['max_value_bytes'], *(len(value) for value in values), 0)
                            if body == fault['original']:
                                assert data == fault['receipt'], 'Exact retry changed the accepted native receipt'
                                fault['recovered'].append(fault['label'])
                                fault['original'] = None
                            if fault['magic'] and any(value.startswith(fault['magic']) for value in values):
                                fault['original'], fault['receipt'] = body, data
                                fault['label'] = fault['magic'].decode()
                                fault['magic'] = None
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
        try:
            subprocess.run([node, str(config), '--initialize'], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=30)

            def start():
                child = subprocess.Popen([node, str(config)], stdout=log, stderr=subprocess.STDOUT)
                wait_ready(fixture.http, child, direct + '/health')
                return child

            def restart():
                nonlocal authority
                authority.kill()
                authority.wait(timeout=10)
                authority = None
                fixture.stop()
                fixture.start()
                authority = start()

            authority = start()

            def call(mode, *args, failure=None, optional_failure=None):
                result = subprocess.run([proof, url, mode, str(root), *map(str, args)], capture_output=True, text=True, timeout=180)
                if failure:
                    assert result.returncode and failure in result.stderr, (mode, result.stdout, result.stderr[-12000:])
                    return
                if optional_failure and result.returncode:
                    assert optional_failure in result.stderr, (mode, result.stderr[-12000:])
                    return None
                assert result.returncode == 0, (mode, result.stderr[-12000:])
                return json.loads(result.stdout)

            def execute(operation, sql, object_id='-'):
                call('compile', operation, object_id, sql)
                for _ in range(100):
                    state = call('next')
                    if state['state'] == 'terminal':
                        assert state.get('outcome') == 'applied' or state.get('table_outcome') == 'applied', state
                        return
                    call('pump')
                raise AssertionError('Catalog work did not finish')

            def pump(profile='captured'):
                call(profile + '-pump')

            def lost(magic, profile='captured'):
                fault['magic'] = magic.encode()
                call(profile + '-pump', failure='InvalidAuthorityResponse')
                assert fault['magic'] is None and (root / 'relational-worker.json').exists()
                restart()
                call(profile + '-rotate')
                pump(profile)
                assert magic in fault['recovered']

            call('provision', 65536)
            call('initialize')
            call('pump')
            execute(1, 'CREATE TABLE rel_left (k BIGINT, v BIGINT)', 1)
            execute(2, 'CREATE TABLE rel_right (k BIGINT, v BIGINT)', 2)
            execute(3, 'INSERT INTO rel_left VALUES (7,10),(9,30)')
            execute(4, 'INSERT INTO rel_right VALUES (7,8)')
            call('captured-plan', SQL)
            call('captured-stage')
            pump()
            assert call('captured-status')['state'] == 'absent'
            call('captured-named-initialize')
            pump()
            call('captured-named-publish', 'totals', 700, 0)
            lost('NRD1')
            first_status = call('captured-named-status', 'totals')
            assert first_status['policy'] is None and call('captured-status')['state'] == 'absent'
            first = call('captured-named-save', 'totals', 'named-first.json')
            call('captured-named-publish', 'totals', 700, 0)
            pump()
            assert call('captured-named-status', 'totals') == first_status, 'Retry charged another pin/quota or changed the revision'
            call('captured-named-authorize', 'named-first.json', 0, 'allow')
            lost('NRP1')
            assert call('captured-status')['state'] == 'absent', 'Authorization activated work'
            call('captured-named-activate', 'named-first.json', 1)
            lost('RQJ1')
            assert call('captured-status')['state'] == 'complete'
            captured = call('captured-result')
            assert captured['complete'] and [cells(row) for row in captured['rows']] == [[7, 1, 8], [9, 1, None]], captured
            call('captured-named-publish', 'totals', 700, 1)
            pump()
            second = call('captured-named-save', 'totals', 'named-second.json')
            assert second['identity']['revision'] == 2 and second != first
            assert call('captured-named-attribution') == first
            assert call('captured-result')['rows'] == captured['rows']
            # Revocation applies to the captured result even though the name
            # metadata and archived authorization are still readable.
            call('policy', 'deny')
            call('pump')
            call('captured-result', failure='CatalogDenied')
            assert call('captured-named-attribution') == first
            call('captured-retire')
            pump()
            call('policy', 'allow')
            call('pump')
            call('maintained-plan', SQL)
            call('maintained-stage')
            pump('maintained')
            call('maintained-named-publish', 'totals', 700, 2)
            pump('maintained')
            third = call('maintained-named-save', 'totals', 'named-third.json')
            call('maintained-named-authorize', 'named-third.json', 1, 'allow')
            pump('maintained')
            call('maintained-named-activate', 'named-third.json', 2)
            lost('RMH1', 'maintained')
            initial = call('maintained-result', 1)
            assert initial['complete'] and initial['manifest']['revision'] == 1
            assert call('maintained-named-attribution') == third
            # Same-resource aliases share one actual native history cut. A
            # later input is installed only through complete exact deltas.
            vector = initial['manifest']['vector']
            assert vector[0]['position'] == vector[1]['position'], vector
            execute(5, 'INSERT INTO rel_right VALUES (9,4)')
            revisions = 1
            while True:
                call('maintained-wake')
                pump('maintained')
                status = call('maintained-status')
                if status['revision'] == revisions:
                    break
                saved = (root / 'maintained-position.json').read_text()
                delta = call('maintained-next')
                (root / 'maintained-position.json').write_text(saved)
                assert call('maintained-next') == delta
                assert delta['complete'] and delta['manifest']['revision'] == revisions + 1
                revisions += 1
                assert revisions < 10
            assert revisions > 1
            final = call('maintained-result')
            values = [cells(event['values']) for event in final['events']]
            assert values == [[7, 1, 8], [9, 1, 4]], values
            # A later finite basis overflows in canonical contributor order.
            # Complete no-op heads still publish; the failing successor cannot
            # replace the most recent complete empty-right result.
            execute(6, 'DELETE FROM rel_right')
            for _ in range(10):
                before = call('maintained-status')
                call('maintained-wake')
                pump('maintained')
                if call('maintained-status')['revision'] == before['revision']:
                    break
            else:
                raise AssertionError('Empty-right maintenance did not drain')
            empty_right = call('maintained-result')
            assert [cells(event['values']) for event in empty_right['events']] == [[7, 1, None], [9, 1, None]]
            execute(7, 'INSERT INTO rel_right VALUES (7,9223372036854775807),(7,1),(7,-1)')
            fault['magic'] = b'RQF1'
            for _ in range(10):
                before = call('maintained-status')
                call('maintained-wake')
                outcome = call('maintained-pump', optional_failure='InvalidAuthorityResponse')
                if outcome is None:
                    assert fault['magic'] is None and (root / 'relational-worker.json').exists()
                    restart()
                    call('maintained-rotate')
                    pump('maintained')
                status = call('maintained-status')
                if status['state'] == 'failed':
                    assert status['revision'] == before['revision'] and status['manifest'] == before['manifest']
                    break
                assert status['state'] == 'idle'
            else:
                raise AssertionError('Ordered overflow did not close the failed successor')
            overflow = call('maintained-failure')
            assert overflow['cause'] == 'Overflow' and overflow['phase'] == 'failed', overflow
            witness = overflow['witness']
            assert witness['output'] == 2 and witness['pair']['right']['operation'] == 7 and witness['pair']['right']['ordinal'] == 1, overflow
            retained = call('maintained-result')
            assert retained['complete'] and retained['events'] == empty_right['events']
            assert 'RQF1' in fault['recovered']
            assert call('maintained-named-attribution') == third
            call('maintained-retire')
            pump('maintained')
            assert not failures, failures
            assert metrics['max_mutations'] <= 4 and metrics['max_value_bytes'] <= 256
            print(json.dumps(dict(profile='named-relational-native', seconds=round(time.monotonic()-started, 3), captured=[cells(row) for row in captured['rows']], maintained=values, revisions=revisions, overflow=overflow, same_resource_vector=True, retained_attribution=True, publication_does_not_activate=True, recovered=fault['recovered'], **metrics)))
        finally:
            if authority is not None:
                authority.terminate()
                authority.wait(timeout=15)
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=5)
            log.close()


if __name__ == '__main__':
    run(*sys.argv[1:])

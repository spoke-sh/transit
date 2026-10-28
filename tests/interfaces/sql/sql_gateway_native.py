"""Database-owned SQL recovery: exact admission, lost commits, fencing and reads."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
from harness.services import free_port, wait_ready


def run(node, catalog, gateway):
    node, catalog, gateway = [str(Path(p).resolve()) for p in (node, catalog, gateway)]
    with tempfile.TemporaryDirectory(prefix='transit-sql-database-') as directory:
        root = Path(directory)
        http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        port = free_port()
        direct = f'http://127.0.0.1:{port}'
        public = json.loads(subprocess.check_output([catalog, 'public'], timeout=10))
        config = root/'node.json'
        settings = dict(profile='native_v1', genesis=dict(realm=46, root_key=public,
                        max_clock_error_ms=10000), local_directory=str(root/'native'),
                        port=port, resident_pages=8, request_timeout_ms=10000)
        config.write_text(json.dumps(settings))
        armed = None
        accepted = None
        committed = None
        committed_saved = None
        recovered = False
        repeated = False
        saved_recoveries = 0
        capacity_binding = capacity_receipt = None
        capacity_armed = False
        capacity_repeats = 0
        sends = turns = table_calls = 0
        failures = []
        upstream = threading.local()

        class Proxy(BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.1'
            def setup(self):
                super().setup()
                self.connection.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            def log_message(self, *_): pass
            def do_POST(self):
                nonlocal armed, accepted, committed, recovered, repeated, sends, turns, table_calls
                nonlocal saved_recoveries, committed_saved
                nonlocal capacity_binding, capacity_receipt, capacity_repeats, capacity_armed
                body = self.rfile.read(int(self.headers['Content-Length']))
                connection = getattr(upstream, 'conn', None)
                if connection is None:
                    connection = upstream.conn = HTTPConnection('127.0.0.1', port, timeout=15)
                try:
                    connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    data, status = response.read(), response.status
                    request = json.loads(body)
                    if self.path == '/v1/command':
                        command = request['request']['command']
                        sends += int('send' in command)
                        turns += int('turn' in command or 'turn_with_versions' in command)
                    if self.path == '/table/v1':
                        table_calls += 1
                        action = request['action']
                        operation = action.get('operation')
                        saved = action.get('commit_saved')
                        binding = action.get('client_token', {}).get('bind')
                        if status == 200 and binding and 'table' in binding['intent']:
                            if capacity_armed:
                                # Acceptance happened, but its response looks
                                # temporarily unavailable. The runtime may only
                                # repeat this exact frozen binding and token.
                                capacity_binding = binding
                                capacity_receipt = json.loads(data)['result']['client_token']
                                capacity_armed = False
                                status, data = 503, b'{"err":"HttpCapacity"}'
                            elif capacity_binding is not None and binding['key'] == capacity_binding['key']:
                                assert binding == capacity_binding
                                assert json.loads(data)['result']['client_token'] == capacity_receipt
                                capacity_repeats += 1
                        if status == 200 and operation and committed and operation['binding'] == committed[0]:
                            if operation['command'] == 'inspect':
                                assert json.loads(data)['result'] == committed[1]
                                recovered = True
                            if operation['command'] == 'execute': repeated = True
                        if status == 200 and saved and committed and saved['binding'] == committed[0]:
                            # commit_saved is independently idempotent. Resolve
                            # the original frozen request and require its exact
                            # durable result, then check rows/counts below.
                            assert saved == committed_saved
                            assert json.loads(data)['result'] == committed[1]
                            recovered = True
                            saved_recoveries += 1
                        if status == 200 and armed == 'admission' and 'bind' in action.get('client_token', {}):
                            result = json.loads(data)
                            accepted = result['result']['client_token']
                            armed = None
                            result['context'][0] ^= 1
                            data = json.dumps(result).encode()
                        if status == 200 and armed == 'commit' and ((operation and operation['command'] == 'execute') or saved):
                            result = json.loads(data)
                            outcome = result['result'].get('ddl', result['result'].get('rows', {}))
                            if 'committed' in outcome:
                                committed = (operation or saved)['binding'], result['result']
                                committed_saved = saved
                                armed = None
                                result['context'][0] ^= 1
                                data = json.dumps(result).encode()
                    self.send_response(status)
                    self.send_header('Content-Length', str(len(data)))
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    self.wfile.write(data)
                except (BrokenPipeError, ConnectionResetError):
                    connection.close()
                    upstream.conn = None
                except BaseException as error:
                    connection.close()
                    upstream.conn = None
                    failures.append(repr(error))
        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        url = f'http://127.0.0.1:{proxy.server_port}'
        log = (root/'node.log').open('w+')
        authority = None
        started = time.monotonic()
        try:
            subprocess.run([node, str(config), '--initialize'], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=30)
            def start():
                # The old process closed every upstream keep-alive socket.
                process = subprocess.Popen([node, str(config)], stdout=log, stderr=subprocess.STDOUT)
                wait_ready(http, process, direct+'/health')
                return process
            def call(binary, mode, *args, fail=False):
                result = subprocess.run([binary, url, mode, str(root), *map(str, args)], capture_output=True, text=True, timeout=300)
                if fail:
                    assert result.returncode != 0, f'{mode}: missing fault'
                    return
                assert result.returncode == 0, f'{mode}: {result.stderr[-12000:]}'
                return json.loads(result.stdout)
            authority = start()
            call(catalog, 'provision')
            authority.terminate(); authority.wait(timeout=10)
            settings['table'] = json.loads((root/'catalog-node.json').read_text())
            config.write_text(json.dumps(settings))
            authority = start()
            call(catalog, 'initialize')
            call(gateway, 'provision')
            cancelled = call(gateway, 'enqueue', 1, 'CREATE TABLE cancelled_data (id BIGINT NOT NULL, PRIMARY KEY (id))')
            call(gateway, 'cancel', cancelled['operation'])
            call(gateway, 'run')
            assert call(gateway, 'status', cancelled['operation'])['summary'] == 'cancelled'
            sql = 'CREATE TABLE wire_data (id BIGINT NOT NULL, value BIGINT NOT NULL, PRIMARY KEY (id))'
            armed = 'admission'
            call(gateway, 'enqueue', 2, sql, fail=True)
            assert armed is None and accepted
            created = call(gateway, 'enqueue', 2, sql)
            assert created['operation'] == int(accepted['position']['next_lsn'])
            call(gateway, 'enqueue', 2, sql+' ', fail=True)
            assert call(gateway, 'status', created['operation'])['summary'] == 'none'
            assert call(gateway, 'replace')['stale_rejected']
            armed = 'commit'
            call(gateway, 'run', fail=True)
            assert armed is None and committed
            authority.kill(); authority.wait(timeout=10)
            authority = start()
            call(gateway, 'run')
            assert recovered and not repeated
            assert call(gateway, 'status', created['operation'])['summary'] == 'applied'
            assert call(catalog, 'inspect', 'wire_data')['count'] == 0
            inserted = call(gateway, 'enqueue', 3, 'INSERT INTO wire_data (id, value) VALUES (1, 10), (2, 20), (3, 30)')
            armed = 'commit'
            recovered = repeated = False
            call(gateway, 'run', fail=True)
            assert armed is None and committed
            authority.kill(); authority.wait(timeout=10)
            authority = start()
            call(gateway, 'replace')
            call(gateway, 'run')
            assert recovered and not repeated
            result = call(gateway, 'status', inserted['operation'])
            assert (result['summary'], result['matched'], result['changed']) == ('applied', 3, 3), result
            assert call(catalog, 'inspect', 'wire_data')['count'] == 3
            assert call(gateway, 'read', 'postgres', 'SELECT value FROM wire_data WHERE id = $1', 2)['rows'] == [[20]]
            assert call(gateway, 'read', 'postgres', 'SELECT value FROM wire_data WHERE id = $1', 'null')['rows'] == []
            assert call(gateway, 'read', 'mysql', 'SELECT `value` FROM `wire_data` WHERE `id` = ?', 3)['rows'] == [[30]]
            grouped = 'SELECT `a`.`id`, SUM(`b`.`value`) AS `total` FROM `wire_data` `a` JOIN `wire_data` `b` ON `a`.`id` = `b`.`id` GROUP BY `a`.`id`'
            assert call(gateway, 'read', 'mysql', grouped)['rows'] == [[1, 10], [2, 20], [3, 30]]
            updated = call(gateway, 'enqueue', 4, 'UPDATE wire_data SET value = 10 WHERE id = 1')
            call(gateway, 'run')
            result = call(gateway, 'status', updated['operation'])
            assert (result['matched'], result['changed']) == (1, 0), result
            history = call(gateway, 'history')
            assert history == dict(count=31, pages=4, empty_scheduling_indexes=True), history
            capacity_armed = True
            result = call(gateway, 'runtime', 'UPDATE wire_data SET value = 21 WHERE id = 2')
            assert (result['outcome']['state'], result['outcome']['matched'], result['outcome']['changed']) == ('applied', 1, 1), result
            values = ', '.join(f'({i}, {i * 10})' for i in range(4, 71))
            seeded = call(gateway, 'enqueue', 9001, f'INSERT INTO wire_data (id, value) VALUES {values}')
            call(gateway, 'run')
            result = call(gateway, 'status', seeded['operation'])
            assert (result['summary'], result['matched'], result['changed']) == ('applied', 67, 67), result
            call(gateway, 'app-config', 5432)
            framing = call(gateway, 'session-framing')
            assert framing == dict(framing_refusals=17, exact_repeats=15, advanced_recoveries=2, revoked_results=3), framing
            assert call(gateway, 'cancel-cleanup') == dict(cleanup_cancelled=True, joined=True)
            assert sends == turns == 0, 'SQL database work dispatched Station messages or turns'
            assert capacity_repeats == 1, capacity_repeats
            assert not failures, failures
            print(json.dumps(dict(profile='native_sql_database', exact_token_recovery=True,
                                  fenced_replacements=2, direct_outcome_recovered=recovered,
                                  explicit_execute_repeated=repeated, saved_receipt_recoveries=saved_recoveries,
                                  exact_counts=True, history=history,
                                  framing=framing, exact_capacity_retries=capacity_repeats, cleanup_cancelled_and_joined=True,
                                  station_sends=sends, station_turns=turns,
                                  table_requests=table_calls, seconds=round(time.monotonic()-started, 3))))
        finally:
            if authority is not None:
                authority.kill(); authority.wait(timeout=10)
            proxy.shutdown(); proxy.server_close(); thread.join(timeout=5)
            if sys.exc_info()[0]:
                log.flush(); log.seek(0); sys.stderr.write(log.read()[-6000:])
                if failures: print(failures, file=sys.stderr)
            log.close()

if __name__ == '__main__': run(*sys.argv[1:])

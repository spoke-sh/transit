"""Gateway ledger and coordinator against signed native ingress and disk Ursula."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import threading
import time

from storage import Fixture, free_port, wait_ready


def run(node, catalog, gateway):
    node, catalog, gateway = map(lambda p: str(Path(p).resolve()), (node, catalog, gateway))
    with Fixture() as store:
        root = store.root
        port = free_port()
        direct = f'http://127.0.0.1:{port}'
        public = json.loads(subprocess.check_output([catalog, 'public'], timeout=10))
        config = root / 'node.json'
        config.write_text(json.dumps(dict(profile='native_v1', genesis=dict(
            realm=46, root_key=public, max_clock_error_ms=10000), ursula_url=store.url,
            bucket='sql-gateway', journal='authority', port=port, resident_pages=8,
            request_timeout_ms=10000)))
        armed = None
        lost = {}
        replayed = set()
        failures = []
        sends = 0
        turns = 0
        delay_ingress = False
        detached_replies = 0
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                nonlocal armed, sends, turns, delay_ingress, detached_replies
                body = self.rfile.read(int(self.headers['Content-Length']))
                connection = HTTPConnection('127.0.0.1', port, timeout=15)
                try:
                    connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == '/v1/command' and response.status == 200:
                        request = json.loads(body)['request']
                        command = request['command']
                        sends += int('send' in command)
                        turn = command.get('turn', command.get('turn_with_versions', {}).get('turn'))
                        if turn:
                            turns += 1
                            mutations = [entry for entry in turn.get('mutations', []) if entry]
                            assert len(mutations) <= 4
                            assert all(len(bytes.fromhex(entry['value'])) <= 256 for entry in mutations if entry['value'])
                        for name, (original, receipt) in lost.items():
                            if body == original:
                                assert data == receipt
                                replayed.add(name)
                        selected = request['principal'] if 'send' in command else 'turn' if turn else None
                        if delay_ingress and selected == 2001:
                            delay_ingress = False
                            lost['detached'] = body, data
                            time.sleep(0.25)
                        if armed is not None and selected == armed:
                            lost[str(armed)] = body, data
                            armed = None
                            data = b'{"position":0}'
                    self.send_response(response.status)
                    self.send_header('Content-Length', str(len(data)))
                    self.send_header('Content-Type', 'application/json')
                    self.end_headers()
                    try:
                        self.wfile.write(data)
                    except (BrokenPipeError, ConnectionResetError):
                        # Joining a cancelled host task can close its current
                        # read/receipt socket after the authority has responded.
                        detached_replies += 1
                except BaseException as error:
                    failures.append(repr(error))
                finally:
                    connection.close()
        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        url = f'http://127.0.0.1:{proxy.server_port}'
        log = (root / 'node.log').open('w+')
        authority = None
        started = time.monotonic()
        try:
            subprocess.run([node, str(config), '--initialize'], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=30)
            def start():
                process = subprocess.Popen([node, str(config)], stdout=log, stderr=subprocess.STDOUT)
                wait_ready(store.http, process, direct + '/health')
                return process

            def call(binary, mode, *args, fail=False):
                result = subprocess.run([binary, url, mode, str(root), *map(str, args)], capture_output=True, text=True, timeout=300)
                if fail:
                    assert result.returncode != 0, f'{mode}: missing fault'
                    return
                if result.returncode:
                    raise RuntimeError(f'{mode}: {result.stderr[-12000:]}')
                return json.loads(result.stdout)

            authority = start()
            call(catalog, 'provision')
            call(catalog, 'initialize')
            call(catalog, 'pump')
            call(gateway, 'provision')
            armed = 2001
            call(gateway, 'begin', 1, fail=True)
            call(gateway, 'retry-control')
            assert '2001' in replayed
            before = sends
            inventory = call(gateway, 'list')
            assert sends == before, 'Inspection dispatched work'
            first = inventory['entries'][0]
            assert first['phase'] == 'reserved'
            call(gateway, 'cancel', first['id'])
            call(gateway, 'run')
            assert call(gateway, 'status', first['id'])['phase'] == 'abandoned'

            created = call(gateway, 'enqueue', 2, 'CREATE TABLE wire_data (id BIGINT NOT NULL, value BIGINT NOT NULL, PRIMARY KEY (id))')
            call(gateway, 'run', 'step_part')
            assert call(gateway, 'replace')['stale_rejected']
            armed = 1234
            call(gateway, 'run', fail=True)
            authority.kill()
            authority.wait(timeout=10)
            authority = None
            store.stop()
            store.start()
            authority = start()
            call(gateway, 'replace')
            call(gateway, 'run')
            assert '1234' in replayed
            assert call(gateway, 'status', created['operation'])['summary'] == 'applied'
            assert call(catalog, 'inspect', 'wire_data')['count'] == 0

            inserted = call(gateway, 'enqueue', 3, 'INSERT INTO wire_data (id, value) VALUES (1, 10), (2, 20), (3, 30)')
            call(gateway, 'run', 'after-dispatch')
            call(gateway, 'replace')
            call(gateway, 'run')
            result = call(gateway, 'status', inserted['operation'])
            assert (result['summary'], result['matched'], result['changed']) == ('applied', 3, 3), result
            assert call(catalog, 'inspect', 'wire_data')['count'] == 3
            before = sends
            assert call(gateway, 'read', 'postgres', 'SELECT value FROM wire_data WHERE id = $1', 2)['rows'] == [[20]]
            assert call(gateway, 'read', 'postgres', 'SELECT value FROM wire_data WHERE id = $1', 'null')['rows'] == []
            assert call(gateway, 'read', 'mysql', 'SELECT `value` FROM `wire_data` WHERE `id` = ?', 3)['rows'] == [[30]]
            grouped = 'SELECT `a`.`id`, SUM(`b`.`value`) AS `total` FROM `wire_data` `a` JOIN `wire_data` `b` ON `a`.`id` = `b`.`id` GROUP BY `a`.`id`'
            assert call(gateway, 'read', 'mysql', grouped)['rows'] == [[1, 10], [2, 20], [3, 30]]
            assert sends == before, 'Statement preparation/read dispatched a write'
            updated = call(gateway, 'enqueue', 4, 'UPDATE wire_data SET value = 10 WHERE id = 1')
            call(gateway, 'run')
            result = call(gateway, 'status', updated['operation'])
            assert (result['matched'], result['changed']) == (1, 0), result
            history = call(gateway, 'history')
            assert history == dict(count=31, pages=4, empty_scheduling_indexes=True), history
            delay_ingress = True
            result = call(gateway, 'runtime', 'UPDATE wire_data SET value = 21 WHERE id = 2', 'detach')
            assert (result['outcome']['state'], result['outcome']['matched'], result['outcome']['changed']) == ('applied', 1, 1), result
            assert call(gateway, 'read', 'postgres', 'SELECT value FROM wire_data WHERE id = $1', 2)['rows'] == [[21]]
            assert 'detached' in replayed and result['detached'] is not None
            assert call(gateway, 'status', result['detached'])['phase'] == 'reserved'
            call(gateway, 'cancel', result['detached'])
            call(gateway, 'run')
            assert call(gateway, 'status', result['detached'])['phase'] == 'abandoned'
            assert not failures, failures
            print(json.dumps(dict(profile='native_gateway_ledger', operations=33,
                                  lost_receipts=sorted(replayed), fenced_replacements=3,
                                  exact_counts=True, detached_replies=detached_replies, turns=turns, sends=sends,
                                  seconds=round(time.monotonic()-started, 3))))
        finally:
            if authority is not None:
                authority.kill()
                authority.wait(timeout=10)
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=5)
            if sys.exc_info()[0]:
                log.flush()
                log.seek(0)
                sys.stderr.write(log.read()[-12000:])
            log.close()


if __name__ == '__main__':
    run(*sys.argv[1:])

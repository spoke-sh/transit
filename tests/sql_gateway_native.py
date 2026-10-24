"""Gateway ledger and direct Table owner with independent accepted outcomes."""
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

from storage import free_port, wait_ready


def run(node, catalog, gateway):
    node, catalog, gateway = map(lambda p: str(Path(p).resolve()), (node, catalog, gateway))
    with tempfile.TemporaryDirectory(prefix='transit-direct-sql-ledger-') as directory:
        root = Path(directory)
        http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        port = free_port()
        direct = f'http://127.0.0.1:{port}'
        public = json.loads(subprocess.check_output([catalog, 'public'], timeout=10))
        config = root / 'node.json'
        settings = dict(profile='native_v1', genesis=dict(
            realm=46, root_key=public, max_clock_error_ms=10000), local_directory=str(root/'native'),
            port=port, resident_pages=8,
            request_timeout_ms=10000)
        config.write_text(json.dumps(settings))
        armed = None
        lost = {}
        replayed = set()
        recovered = set()
        lost_data = None
        recovered_data = False
        repeated_data = False
        receipt_inspectors = {}
        failures = []
        sends = 0
        turns = 0
        delay_ingress = False
        detached_replies = 0
        pipeline_enabled = False
        pipeline = {}
        successor_admitted = threading.Event()
        def intent_upload(request):
            send = request['command'].get('send')
            if request['principal'] != 2001 or send is None:
                return None
            frame = bytes.fromhex(send['value'])
            if len(frame) < 58 or frame[:5] != b'STN1\x01' or frame[13:17] != b'GSQ1' or frame[49] not in (4, 5):
                return None
            return frame[49], int.from_bytes(frame[50:58], 'little')
        upstream_local = threading.local()
        class Proxy(BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.1'

            def setup(self):
                super().setup()
                self.connection.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

            def log_message(self, *_):
                pass

            def do_POST(self):
                nonlocal armed, sends, turns, delay_ingress, detached_replies
                nonlocal lost_data, recovered_data, repeated_data
                body = self.rfile.read(int(self.headers['Content-Length']))
                connection = getattr(upstream_local, 'conn', None)
                if connection is None:
                    connection = HTTPConnection('127.0.0.1', port, timeout=15)
                    upstream_local.conn = connection
                try:
                    if pipeline_enabled and self.path == '/v1/command':
                        request = json.loads(body)['request']
                        upload = intent_upload(request)
                        if not pipeline and upload and upload[0] == 4:
                            pipeline.update(owner=request['command']['send']['pid'],
                                            sequence=request['sequence'], operation=upload[1], held_input=None)
                        command = request['command']
                        turn = command.get('turn', command.get('turn_with_versions', {}).get('turn'))
                        if (pipeline and turn and turn['pid'] == pipeline['owner'] and
                                pipeline['held_input'] in (None, turn['input'])):
                            pipeline['held_input'] = turn['input']
                            # Every retry of this turn waits too: a timed-out
                            # worker attempt cannot accidentally open the gate.
                            assert successor_admitted.wait(10), 'Upload waited for processing before admitting its successor'
                    try:
                        connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                        response = connection.getresponse()
                    except (ConnectionError, OSError):
                        connection.close()
                        connection = HTTPConnection('127.0.0.1', port, timeout=15)
                        upstream_local.conn = connection
                        connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                        response = connection.getresponse()
                    data = response.read()
                    if self.path == '/table/v1' and response.status == 200:
                        request = json.loads(body)
                        operation = request['action'].get('operation')
                        if operation and lost_data and operation['binding'] == lost_data[0]:
                            if operation['command'] == 'inspect':
                                assert json.loads(data)['result'] == lost_data[1], 'Original direct outcome changed'
                                recovered_data = True
                            elif operation['command'] == 'execute':
                                repeated_data = True
                        if operation and armed == 1234 and operation['command'] == 'execute':
                            result = json.loads(data)
                            outcome = result['result'].get('ddl', result['result'].get('rows'))
                            if 'committed' in outcome:
                                lost_data = operation['binding'], result['result']
                                armed = None
                                result['context'][0] ^= 1
                                data = json.dumps(result).encode()
                    if self.path == '/v1/query' and response.status == 200:
                        query = json.loads(body)['query']
                        kind = query['kind']
                        authority = kind.get('authorization') if isinstance(kind, dict) else None
                        if authority and isinstance(authority['kind'], dict) and 'receipt' in authority['kind']:
                            original_request = authority['kind']['receipt']
                            for name, (original, receipt) in list(lost.items()):
                                if original_request == json.loads(original)['request']:
                                    observed = json.loads(data)['body']['authorization']['body']['receipt']
                                    assert observed == json.loads(receipt), 'Receipt lookup changed exact acceptance'
                                    receipt_inspectors.setdefault(name, set()).add(query['principal'])
                                    # Current destination inspectors can also
                                    # verify historical acceptance. Require the
                                    # original caller's recovery separately.
                                    if query['principal'] == original_request['principal']:
                                        recovered.add(name)
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
                        for name, (original, receipt) in list(lost.items()):
                            original_request = json.loads(original)['request']
                            if (request['principal'], request['sequence']) == (original_request['principal'], original_request['sequence']):
                                assert body == original, 'Recovery replaced the original signed request'
                            if body == original:
                                assert data == receipt
                                replayed.add(name)
                        if pipeline_enabled and pipeline:
                            upload = intent_upload(request)
                            if upload and upload[1] == pipeline['operation']:
                                if request['sequence'] == pipeline['sequence'] and 'pipelined_part' not in lost:
                                    lost['pipelined_part'] = body, data
                                    pipeline['first_input'] = json.loads(data)['position']
                                    # Lose an actual accepted part's transport
                                    # reply; recovery must use identical bytes.
                                    self.close_connection = True
                                    return
                                if request['sequence'] > pipeline['sequence'] and not successor_admitted.is_set():
                                    pipeline['successor_tag'] = upload[0]
                                    pipeline['successor_input'] = json.loads(data)['position']
                                    successor_admitted.set()
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
                    connection.close()
                    upstream_local.conn = None
                    failures.append(repr(error))
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
                wait_ready(http, process, direct + '/health')
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
            authority.terminate()
            authority.wait(timeout=10)
            settings['table'] = json.loads((root/'catalog-node.json').read_text())
            config.write_text(json.dumps(settings))
            authority = start()
            call(catalog, 'initialize')
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
            assert call(gateway, 'run', 'dispatch')['stopped'] == 'dispatch'
            assert call(gateway, 'replace')['stale_rejected']
            armed = 1234
            call(gateway, 'run', fail=True)
            assert armed is None and lost_data, 'Direct Table outcome fault was not exercised'
            authority.kill()
            authority.wait(timeout=10)
            authority = None
            authority = start()
            call(gateway, 'replace')
            call(gateway, 'run')
            assert recovered_data, 'Exact direct Table outcome was not recovered after restart'
            assert not repeated_data, 'A committed direct operation was unnecessarily executed again'
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
            pipeline_enabled = True
            result = call(gateway, 'runtime', 'UPDATE wire_data SET value = 21 WHERE id = 2', 'detach')
            assert (result['outcome']['state'], result['outcome']['matched'], result['outcome']['changed']) == ('applied', 1, 1), result
            assert call(gateway, 'read', 'postgres', 'SELECT value FROM wire_data WHERE id = $1', 2)['rows'] == [[21]]
            assert 'detached' in replayed and result['detached'] is not None
            assert 'pipelined_part' in replayed, 'Lost upload receipt was not retried exactly'
            assert successor_admitted.is_set() and pipeline['held_input'] == pipeline['first_input'], pipeline
            assert pipeline['successor_tag'] == 4 and pipeline['successor_input'] > pipeline['first_input'], pipeline
            assert call(gateway, 'status', result['detached'])['phase'] == 'reserved'
            call(gateway, 'cancel', result['detached'])
            call(gateway, 'run')
            assert call(gateway, 'status', result['detached'])['phase'] == 'abandoned'
            assert not failures, failures
            print(json.dumps(dict(profile='native_gateway_ledger', operations=33,
                                  lost_receipts=sorted(replayed | recovered), exact_resubmissions=sorted(replayed),
                                  recovered_receipts=sorted(recovered), fenced_replacements=3,
                                  direct_outcome_recovered=recovered_data, direct_reexecuted=repeated_data,
                                  receipt_inspectors={name: sorted(principals) for name, principals in receipt_inspectors.items()},
                                  exact_counts=True, ingress_pipeline=pipeline, detached_replies=detached_replies, turns=turns, sends=sends,
                                  seconds=round(time.monotonic()-started, 3))))
        finally:
            if sys.exc_info()[0] and failures:
                print(json.dumps({'gateway_proxy_failures': failures}), file=sys.stderr, flush=True)
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

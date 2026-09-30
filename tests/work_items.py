"""Actual example worker, two fenced replacements and disk-backed migration."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import threading
import time

from storage import Fixture, free_port, wait_ready


def run(node, worker_binary, caller):
    node, worker_binary, caller = [str(Path(path).resolve()) for path in (node, worker_binary, caller)]
    with Fixture() as fixture:
        started = time.monotonic()
        public = json.loads(subprocess.check_output([caller, 'public'], timeout=10))
        port = free_port()
        url = f'http://127.0.0.1:{port}'
        config = fixture.root/'node.json'
        config.write_text(json.dumps(dict(profile='native_v1', genesis=dict(realm=51,
            root_key=public, max_clock_error_ms=10000, allow_history_trim=True),
            ursula_url=fixture.url, bucket='work-items', journal='authority', port=port,
            resident_pages=16, request_timeout_ms=10000)))
        faults, retries, failures = {}, set(), []
        observed = dict(turns=0, max_mutations=0, max_value_bytes=0, pages=0)

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                upstream = HTTPConnection('127.0.0.1', port, timeout=15)
                try:
                    envelope = json.loads(body)
                    upstream.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    response = upstream.getresponse()
                    data = response.read()
                    if self.path == '/v1/query' and response.status == 200:
                        query = envelope['query']['kind']
                        if 'entries' in query and query['entries'].get('key') is None:
                            observed['pages'] += 1
                    if self.path == '/v1/command' and response.status == 200:
                        command = envelope['request']['command']
                        selected = None
                        if 'send' in command:
                            payload = bytes.fromhex(command['send']['value'])
                            if b'WI1i\x04' in payload: selected = 'operator-step'
                        turn = command.get('turn', command.get('turn_with_versions', {}).get('turn', {}))
                        if turn:
                            changes = [item for item in turn['mutations'] if item]
                            observed['turns'] += 1
                            observed['max_mutations'] = max(observed['max_mutations'], len(changes))
                            for change in changes:
                                if change['value']:
                                    observed['max_value_bytes'] = max(observed['max_value_bytes'], len(bytes.fromhex(change['value'])))
                                if bytes.fromhex(change['key']).startswith(b'\0r\x02\0\0\0'):
                                    selected = 'worker-copy'
                        for name, (request, receipt) in faults.items():
                            if body == request:
                                assert data == receipt, 'exact retry changed native receipt'
                                retries.add(name)
                        if selected and selected not in faults:
                            faults[selected] = (body, data)
                            data = b'{"position":0}'
                    self.send_response(response.status)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                except (BrokenPipeError, ConnectionResetError):
                    pass  # The test deliberately kills clients at completed boundaries.
                except BaseException as error:
                    failures.append(repr(error))
                    raise
                finally: upstream.close()

        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        origin = f'http://127.0.0.1:{proxy.server_port}'
        processes, logs = [], []
        def spawn(name, args):
            log = (fixture.root/f'{name}.log').open('w+')
            logs.append((name, log))
            process = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT)
            processes.append(process)
            return process
        def authority():
            process = spawn('node', [node, str(config)])
            wait_ready(fixture.http, process, url+'/health')
            return process
        def invoke(phase):
            subprocess.run([caller, origin, phase, str(fixture.root)], check=True, timeout=180)
        def worker(name):
            return spawn(name, [worker_binary, str(fixture.root/'worker.json')])
        try:
            subprocess.run([node, str(config), '--initialize'], check=True, timeout=30)
            current_node = authority()
            invoke('setup')
            current_worker = worker('worker-first')
            invoke('seed')
            invoke('step')
            until = time.monotonic()+10
            while 'worker-copy' not in retries:
                assert current_worker.poll() is None and time.monotonic() < until
                time.sleep(.05)
            current_worker.kill(); current_worker.wait(timeout=10)
            current_node.kill(); current_node.wait(timeout=10)
            fixture.stop(); fixture.start()
            current_node = authority()
            invoke('fence')
            # The old accepted proposal is not a capability after worker-key
            # replacement, even though its receipt remains retained.
            stale = HTTPConnection('127.0.0.1', port, timeout=15)
            try:
                stale.request('POST', '/v1/command', faults['worker-copy'][0], {'Content-Type': 'application/json'})
                reply = stale.getresponse()
                assert reply.status in (401, 403, 409), (reply.status, reply.read())
                reply.read()
            finally: stale.close()
            current_worker = worker('worker-copy-recovered')
            invoke('deny')
            for _ in range(9): invoke('step')
            # The copy is complete, but activation must still wait for verification.
            current_worker.kill(); current_worker.wait(timeout=10)
            invoke('fence')
            current_worker = worker('worker-verify-recovered')
            invoke('finish')
            assert not failures, failures
            assert set(faults) == retries == {'operator-step', 'worker-copy'}, (faults.keys(), retries)
            assert observed['pages'] > 0
            assert observed['max_mutations'] == 4 and observed['max_value_bytes'] <= 256, observed
            print(f'Work items: actual worker, 19 rows, two fresh-key fenced replacements, disk restart, exact operator/worker retries, complete verification and old epoch rejection passed in {time.monotonic()-started:.2f}s; {observed}', flush=True)
        except BaseException:
            for name, log in logs:
                log.flush(); log.seek(0)
                print(name, log.read()[-6000:], file=sys.stderr)
            raise
        finally:
            for process in reversed(processes):
                if process.poll() is None: process.kill()
                process.wait(timeout=10)
            proxy.shutdown(); proxy.server_close(); thread.join(timeout=10)
            for _, log in logs: log.close()


if __name__ == '__main__': run(*sys.argv[1:])

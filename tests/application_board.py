"""Actual embedded editor, native operator signatures and independent restart."""
import json
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import subprocess
import sys
import time
import threading
import urllib.error
import urllib.request
from harness.ursula import Fixture
from harness.services import free_port, wait_ready
from serving import Key


def run(node, proof, board):
    node, proof, board = (str(Path(path).resolve()) for path in (node, proof, board))
    with Fixture() as fixture:
        processes, logs = [], []
        def start(name, command):
            log = (fixture.root / f'{name}.log').open('w+')
            logs.append(log)
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=fixture.env)
            processes.append(process)
            return process
        port, board_port = free_port(), free_port()
        url, origin = f'http://127.0.0.1:{port}', f'http://127.0.0.1:{board_port}'
        lost = dict(armed=False, request=None, receipt=None, recovered=False)
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                connection = HTTPConnection('127.0.0.1', port, timeout=10)
                try:
                    connection.request('POST', self.path, body, {'Content-Type':'application/json'})
                    response = connection.getresponse(); data = response.read()
                    if self.path == '/v1/command' and response.status == 200:
                        if lost['armed']:
                            lost.update(armed=False, request=body, receipt=json.loads(data))
                            self.close_connection = True
                            return
                        if body == lost['request']:
                            assert json.loads(data) == lost['receipt']
                            lost['recovered'] = True
                    self.send_response(response.status)
                    self.send_header('Content-Type','application/json')
                    self.send_header('Content-Length',str(len(data)))
                    self.end_headers(); self.wfile.write(data)
                finally: connection.close()
        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        proxy_thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        proxy_thread.start()
        proxy_url = f'http://127.0.0.1:{proxy.server_port}'
        public = json.loads(subprocess.check_output([proof, 'public'], timeout=10))
        node_config = fixture.root / 'node.json'
        node_config.write_text(json.dumps({'profile': 'native_v1', 'genesis': {'realm': 49, 'root_key': public, 'max_clock_error_ms': 10000}, 'ursula_url': fixture.url, 'bucket': 'application-browser', 'journal': 'authority', 'port': port, 'resident_pages': 64, 'request_timeout_ms': 10000}))
        manifest = fixture.root / 'application.json'
        def request(path, value=None, status=200, origin_header=origin):
            time.sleep(.15)
            headers = {'Content-Type': 'application/json'}
            if origin_header: headers['Origin'] = origin_header
            req = urllib.request.Request(origin + path, None if value is None else json.dumps(value).encode(), headers)
            try: response = fixture.http.open(req, timeout=10)
            except urllib.error.HTTPError as error: response = error
            with response:
                body = response.read()
                assert response.status == status, (response.status, body[:500])
                assert response.headers['Cache-Control'] == 'no-store'
                return json.loads(body)
        try:
            subprocess.run([node, str(node_config), '--initialize'], check=True, capture_output=True, timeout=30)
            authority = start('node', [node, str(node_config)])
            wait_ready(fixture.http, authority, url + '/health')
            worker = start('worker', [proof, url, 'serve', str(manifest)])
            deadline = time.monotonic() + 30
            while not manifest.exists():
                assert worker.poll() is None and time.monotonic() < deadline
                time.sleep(.05)
            saved = json.loads(manifest.read_text())
            scope = {'realm': 49, 'application': 9, 'pid': saved['pid'], 'resource': saved['resource'], 'namespace': '19'}
            seed = fixture.root / 'inspector.seed'
            seed.write_text('0a' * 32 + '\n')
            config = fixture.root / 'board.json'
            options = {'upstream': proxy_url, 'realm': 49, 'principal': 65538, 'profile': 'native_v1', 'seed_file': str(seed), 'public_origin': origin, 'development_allow_insecure_http': True, 'port': board_port, 'request_timeout_ms': 5000, 'upstream_timeout_ms': 1500, 'interface': scope}
            config.write_text(json.dumps(options))
            serving = start('board-disabled', [board, str(config)])
            wait_ready(fixture.http, serving, origin + '/health')
            request('/api/v1/application', {'info': {}}, status=404)
            serving.terminate(); serving.wait(timeout=10)
            options['application'] = {'scope': scope, 'operators': [65537] + [None] * 15}
            config.write_text(json.dumps(options))
            serving = start('board', [board, str(config)])
            wait_ready(fixture.http, serving, origin + '/health')
            assert request('/api/v1/application', {'info': {}})['info']['scope'] == scope
            request('/api/v1/application', {'info': {}}, status=403, origin_header=None)
            request('/api/v1/application', {'info': {}}, status=403, origin_header='https://untrusted.example')
            bad_request = request('/api/v1/application', {'compile': {'source': 7}}, status=400)['diagnostic']
            assert bad_request['code'] == 'application.invalid_request' and bad_request['outcome'] == 'not_submitted'
            for source, code in [('DROP INTERFACE board;', 'application.unsupported_interface_statement'),
                                 ('CREATE INTERFACE broken WITH (realm = 49);', 'application.missing_interface_option')]:
                detail = request('/api/v1/application', {'compile': {'source': source}}, status=400)['diagnostic']
                assert detail['code'] == code and detail['outcome'] == 'not_submitted' and detail['location'] is not None
                assert [a['kind'] for a in detail['actions'] if a] == ['correct_input']
            denied = request('/api/v1/application', {'prepare': {'principal': 65538, 'sequence': '1', 'command': {'initialize': {}}}}, status=403)['diagnostic']
            assert denied['code'] == 'application.operator_denied' and denied['outcome'] == 'not_submitted'
            prepared = request('/api/v1/application', {'prepare': {'principal': 65537, 'sequence': '2', 'command': {'initialize': {}}}})['prepared']
            denied = request('/api/v1/application', {'submit': {'prepared': prepared, 'signature': [0] * 64}}, status=403)['diagnostic']
            assert denied['code'] == 'application.command_rejected' and denied['outcome'] == 'not_applicable'
            assert denied['identity']['sequence'] == '2' and denied['evidence'] == 'none'
            assert 'resume_exact' not in [a['kind'] for a in denied['actions'] if a]
            modified = json.loads(json.dumps(prepared)); modified['digest'][0] ^= 1
            invalid = request('/api/v1/application', {'submit': {'prepared': modified, 'signature': [0] * 64}}, status=400)['diagnostic']
            assert invalid['code'] == 'application.digest_mismatch' and invalid['outcome'] == 'not_submitted'
            operator = Key(fixture.root, 'operator-diagnostic', 9)
            read = request('/api/v1/application', {'prepare_read':{'principal':65537,'selection':{'identity':{}}}})['prepared_read']
            identity = request('/api/v1/application', {'read':{'prepared':read,'signature':operator.sign(bytes(read['digest']))}})['observation']['identity']
            next_sequence = str(int(identity['sequence']) + 1)
            prepared = request('/api/v1/application', {'prepare':{'principal':65537,'sequence':next_sequence,'command':{'initialize':{}}}})['prepared']
            signed = dict(prepared=prepared, signature=operator.sign(bytes(prepared['digest'])))
            lost['armed'] = True
            uncertain = request('/api/v1/application', {'submit':signed}, status=503)['diagnostic']
            assert uncertain['code'] == 'application.send_unknown' and uncertain['outcome'] == 'unknown'
            assert uncertain['identity']['sequence'] == next_sequence and uncertain['evidence'] == 'saved_intent'
            assert [a['kind'] for a in uncertain['actions'] if a] == ['inspect_status','resume_exact']
            recovered = request('/api/v1/application', {'submit':signed})['admitted']
            assert lost['request'] is not None and lost['recovered'] and recovered['position'] > 0
            env = dict(os.environ, BOARD_TEST_URL=origin)
            subprocess.run(['vp', 'exec', '--filter', '@transit/board-web', 'playwright', 'test', 'application.spec.ts'], check=True, env=env, timeout=300)
            published = request('/api/v1/interface')['published']
            assert published['head']['revision'] == '1'
            assert published['compiled']['definition']['theme'] == 'dense'
            assert published['compiled']['definition']['screens'][0]['label'] == 'My atlas'
            worker.kill(); worker.wait(timeout=10)
            authority.kill(); authority.wait(timeout=10)
            fixture.stop(); fixture.start()
            authority = start('node-restart', [node, str(node_config)])
            wait_ready(fixture.http, authority, url + '/health')
            worker = start('worker-restart', [proof, url, 'resume', str(manifest)])
            assert request('/api/v1/interface')['published'] == published
            subprocess.run([proof, url, 'deny-reader', str(manifest)], check=True, timeout=20)
            denied = request('/api/v1/interface', status=403)['diagnostic']
            assert denied['category'] == 'access' and denied['outcome'] == 'not_applicable'
            subprocess.run([proof, url, 'restore-reader', str(manifest)], check=True, timeout=20)
            assert request('/api/v1/interface')['published'] == published
            print('Application Board: actual browser SQL/Form/Canvas, disabled/invalid/signed ingress, exact lost reply, publication, disk/worker restart and current read denial passed.', flush=True)
        except BaseException:
            for log in logs:
                log.flush(); log.seek(0); sys.stderr.write(log.read()[-8000:])
            raise
        finally:
            for process in reversed(processes):
                if process.poll() is None: process.terminate()
            for process in reversed(processes):
                try: process.wait(timeout=10)
                except subprocess.TimeoutExpired: process.kill(); process.wait(timeout=10)
            for log in logs: log.close()
            proxy.shutdown(); proxy.server_close(); proxy_thread.join(timeout=10)


if __name__ == '__main__': run(*sys.argv[1:])

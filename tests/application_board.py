"""Actual embedded editor, native operator signatures and independent restart."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import urllib.error
import urllib.request
from storage import Fixture, free_port, wait_ready


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
            options = {'upstream': url, 'realm': 49, 'principal': 65538, 'profile': 'native_v1', 'seed_file': str(seed), 'public_origin': origin, 'development_allow_insecure_http': True, 'port': board_port, 'request_timeout_ms': 5000, 'upstream_timeout_ms': 1500, 'interface': scope}
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
            request('/api/v1/application', {'compile': {'source': 'DROP INTERFACE board;'}}, status=400)
            request('/api/v1/application', {'prepare': {'principal': 65538, 'sequence': '1', 'command': {'initialize': {}}}}, status=403)
            prepared = request('/api/v1/application', {'prepare': {'principal': 65537, 'sequence': '2', 'command': {'initialize': {}}}})['prepared']
            request('/api/v1/application', {'submit': {'prepared': prepared, 'signature': [0] * 64}}, status=403)
            env = dict(os.environ, BOARD_TEST_URL=origin)
            subprocess.run(['vp', 'exec', '--filter', '@rey/transit-board-web', 'playwright', 'test', 'application.spec.ts'], check=True, env=env, timeout=300)
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
            request('/api/v1/interface', status=403)
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


if __name__ == '__main__': run(*sys.argv[1:])

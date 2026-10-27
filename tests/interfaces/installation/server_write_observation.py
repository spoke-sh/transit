"""Lost native-session replies retain server-owned operations without SQL replay."""
from concurrent.futures import ThreadPoolExecutor
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler
import json
import os
import socket
import socketserver
import subprocess
import threading
import time

from interfaces.cli.table_console import atom


def run(fixture):
    connection = fixture.console_config()
    upstream_path = connection['endpoint'][5:]
    state = dict(mode=None, observations=[], executions=[], entered=threading.Event(), release=threading.Event())

    class Upstream(HTTPConnection):
        def connect(self):
            self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.sock.settimeout(30)
            self.sock.connect(upstream_path)

    class Proxy(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_POST(self):
            body = self.rfile.read(int(self.headers['Content-Length']))
            request = json.loads(body)
            action = next(iter(request['action']))
            if action == 'execute':
                state['executions'].append(request['action']['execute'])
            if state['mode'] == 'refuse_execute' and action == 'execute':
                state['mode'] = None
                self.send_response(503)
                self.send_header('Content-Length', '0')
                self.end_headers()
                return
            upstream = Upstream('local')
            try:
                upstream.request('POST', self.path, body, {'Content-Type': 'application/json'})
                response = upstream.getresponse()
                data = response.read()
                if action in ('execute', 'status'):
                    observed = json.loads(data).get('result', {})
                    state['observations'].append((action, {key: observed.get('operation', {}).get(key) for key in ('phase', 'outcome', 'blocked')}, observed.get('err', {}).get('code')))
                if state['mode'] == 'drop_'+action:
                    state['mode'] = None
                    self.close_connection = True
                    return
                if state['mode'] == 'hold_execute' and action == 'execute':
                    state['mode'] = None
                    state['entered'].set()
                    assert state['release'].wait(30)
                self.send_response(response.status)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            finally:
                upstream.close()

    class Server(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
        daemon_threads = True

    path = fixture.root/'session-observation.sock'
    with Server(str(path), Proxy) as proxy:
        os.chmod(path, 0o600)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        try:
            config = fixture.root/'observation-console.json'
            config.write_text(json.dumps(dict(connection, endpoint='unix:'+str(path), request_timeout_ms=5000)))
            def invoke(text, expected=0):
                value = subprocess.run([fixture.cli, 'console', '--no-rc', '--format', 'json', '--config', str(config)], input=text+'\n', text=True, capture_output=True, timeout=60, cwd=fixture.root)
                assert value.returncode == expected, (state['observations'][-8:], value)
                return value
            def applied(value):
                completion = json.loads(value.stdout)['completion']
                assert completion['outcome'] == 'applied', completion
                assert (completion['matched'], completion['changed']) == (1, 1), completion

            applied(invoke('INSERT INTO items (id,value) VALUES (-81,810);'))
            applied(invoke('DELETE FROM items WHERE id=-81;'))
            for mode, key in [('drop_execute', -82), ('drop_status', -83)]:
                if mode == 'drop_status':
                    fixture.boundary.pause()
                before = len(state['executions'])
                state['mode'] = mode
                try:
                    if mode == 'drop_status':
                        wake = threading.Timer(.5, fixture.boundary.resume)
                        wake.start()
                    completed = invoke(f'INSERT INTO items (id,value) VALUES ({key},820);')
                finally:
                    if mode == 'drop_status':
                        wake.cancel()
                        wake.join(timeout=5)
                        fixture.boundary.resume()
                applied(completed)
                assert len(state['executions']) == before+1, 'Console automatically replayed SQL'
                token = state['executions'][-1]['token']
                operation = fixture.sql_session(dict(status=dict(token=token)))['operation']
                assert operation['outcome'] == 'applied'
                assert atom(fixture.console(f'SELECT value FROM items WHERE id={key};\n')[-1], 'signed') == '820'
                applied(invoke(f'DELETE FROM items WHERE id={key};'))
            state['mode'] = 'refuse_execute'
            before = len(state['executions'])
            failed = invoke('INSERT INTO items VALUES (-84,840);', 1)
            assert 'Could not confirm' in failed.stderr and 'may apply changes twice' in failed.stderr
            token = state['executions'][-1]['token']
            assert len(state['executions']) == before+1
            fixture.sql_session(dict(status=dict(token=token)), error='MissingGatewayOperation')
            assert atom(fixture.console('SELECT COUNT(*) FROM items WHERE id=-84;\n')[-1], 'unsigned') == '0'
            state['mode'] = 'hold_execute'
            with ThreadPoolExecutor(max_workers=1) as pool:
                pending = pool.submit(invoke, 'INSERT INTO items VALUES (-85,850);')
                try:
                    assert state['entered'].wait(30)
                    assert atom(fixture.console('SELECT COUNT(*) FROM items;\n')[-1], 'unsigned') in ('0', '1')
                finally:
                    state['release'].set()
                applied(pending.result(timeout=60))
            applied(invoke('DELETE FROM items WHERE id=-85;'))
            assert not list(fixture.installation.glob('console-*'))
            print('SQL session reply loss: console confirms original outcomes without SQL replay; capacity rejection leaves no operation; another console progresses during a held reply.', flush=True)
        finally:
            state['release'].set()
            proxy.shutdown()
            thread.join(timeout=5)
    path.unlink()

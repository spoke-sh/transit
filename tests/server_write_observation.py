"""Real console observation pressure and uncertain-send recovery, without replay."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from concurrent.futures import ThreadPoolExecutor
import json
import os
import signal
import subprocess
import threading
from server import children, command


def run(fixture):
    state = {'mode': 'reads', 'admitted': False, 'commands': [],
             'remaining': {'process': 2, 'read_entries': 1}, 'refusals': 0, 'preflight': 1,
             'receipt_checkpoint': None, 'waits': 0, 'ordinary_after_wait': 0}
    wait_seen = threading.Event()

    class Proxy(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_POST(self):
            body = self.rfile.read(int(self.headers['Content-Length']))
            envelope = json.loads(body)
            hint = self.headers.get('X-Transit-Wait')
            if self.path == '/v1/query' and hint:
                state['waits'] += 1
                wait_seen.set()
                if state['mode'] in ('wait_capacity', 'wait_denied'):
                    denied = state['mode'] == 'wait_denied'
                    self.send_response(403 if denied else 503)
                    data = b'{"err":"AccessDenied"}' if denied else b'{"err":"HttpCapacity"}'
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                    return
            elif self.path == '/v1/query' and wait_seen.is_set():
                state['ordinary_after_wait'] += 1
            if self.path == '/v1/command' and state['mode'] == 'refuse_send':
                state['commands'].append(body)
                state['mode'] = None
                self.send_response(503)
                data = b'{"err":"HttpCapacity"}'
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)
                return
            if self.path == '/v1/query' and state['mode'] == 'reads':
                operation = next(iter(envelope['query']['kind']))
                if operation == 'process' and state['receipt_checkpoint'] is None and saved.exists():
                    record = json.loads(saved.read_text())
                    if record['operation']['mutation']['input'] is not None:
                        state['receipt_checkpoint'] = saved.read_bytes()
                refuse = False
                if not state['admitted'] and state['preflight']:
                    state['preflight'] -= 1
                    refuse = True
                elif state['admitted'] and state['remaining'].get(operation, 0):
                    state['remaining'][operation] -= 1
                    refuse = True
                if refuse:
                    state['refusals'] += 1
                    self.send_response(503)
                    data = b'{"err":"HttpCapacity"}'
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                    return
            upstream = HTTPConnection('127.0.0.1', fixture.config['ports']['gateway'], timeout=10)
            try:
                headers = {'Content-Type': 'application/json'}
                if hint:
                    headers['X-Transit-Wait'] = hint
                upstream.request('POST', self.path, body, headers)
                response = upstream.getresponse()
                data = response.read()
                if self.path == '/v1/command':
                    state['commands'].append(body)
                    if response.status == 200:
                        state['admitted'] = True
                        if state['mode'] == 'drop_send':
                            state['mode'] = None
                            self.close_connection = True
                            return  # Accepted command, deliberately lost receipt.
                self.send_response(response.status)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            finally:
                upstream.close()

    with ThreadingHTTPServer(('127.0.0.1', 0), Proxy) as proxy:
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        try:
            config = fixture.console_config()
            config.update(execution='interactive', url=f'http://127.0.0.1:{proxy.server_port}')
            done = fixture.record()['provision']
            saved = fixture.root / 'observation-writes.json'
            config['writes'] = {'recovery_file': str(saved), 'table': {'name': 'items',
                'connection': {'realm': fixture.config['realm'], 'principal': 10,
                               'writer': done[4], 'resource': done[5], 'table': 1}}}
            path = fixture.root / 'observation-console.json'
            path.write_text(json.dumps(config))

            def invoke(text, expected=0):
                result = subprocess.run([fixture.cli, 'console', '--no-rc', '--format', 'json',
                                         '--config', str(path)], input=text + '\n',
                                        text=True, capture_output=True, timeout=30, cwd=fixture.root)
                assert result.returncode == expected, result
                return result

            def applied(result, affected=1):
                value = json.loads(result.stdout)['mutation']
                assert value['phase'] == 'applied' and value['affected_rows'] == affected, value

            applied(invoke('INSERT INTO items (id, value) VALUES (-81, 810);'))
            assert state['refusals'] == 4 and len(state['commands']) == 1, state['refusals']
            assert json.loads(saved.read_text())['complete']
            assert fixture.console('SELECT value FROM items WHERE id = -81;\n')[-1]['cells'][0][0]['value']['int64'] == '810'
            state['mode'] = None
            # Crash before replacing the acknowledged-input checkpoint with the
            # terminal checkpoint: observation must recover without another send.
            assert state['receipt_checkpoint'] is not None
            saved.write_bytes(state['receipt_checkpoint'])
            before = len(state['commands'])
            applied(invoke('.resume'))
            assert len(state['commands']) == before
            assert json.loads(saved.read_text())['complete']
            applied(invoke('DELETE FROM items WHERE id = -81;'))

            state.update(mode='drop_send', admitted=False)
            before = len(state['commands'])
            failed = invoke('INSERT INTO items (id, value) VALUES (-82, 820);', expected=1)
            assert not failed.stdout and 'HttpConnectionClosing' in failed.stderr, failed
            assert len(state['commands']) == before + 1, 'uncertain send was automatically retried'
            record = json.loads(saved.read_text())
            pending = record['operation']['mutation']
            assert not record['complete'] and pending['pending'] is not None and pending['input'] is None
            applied(invoke('.resume'))
            assert len(state['commands']) == before + 2
            assert state['commands'][-1] == state['commands'][-2], 'explicit recovery changed signed bytes'
            assert fixture.console('SELECT value FROM items WHERE id = -82;\n')[-1]['cells'][0][0]['value']['int64'] == '820'
            applied(invoke('DELETE FROM items WHERE id = -82;'))
            state.update(mode='refuse_send', admitted=False)
            before = len(state['commands'])
            failed = invoke('INSERT INTO items (id, value) VALUES (-83, 830);', expected=1)
            assert 'native_cause: HttpCapacity' in failed.stderr, failed.stderr
            assert len(state['commands']) == before + 1, '503 was automatically retried'
            assert not json.loads(saved.read_text())['complete']
            applied(invoke('.resume'))
            assert state['commands'][-1] == state['commands'][-2]
            applied(invoke('DELETE FROM items WHERE id = -83;'))
            # Hold the real owner before admission so pending observation is
            # deterministic. Exhausted wait admission must fall back to an
            # ordinary current read; denial must never use that fallback.
            owners = [pid for pid in children(fixture.process.pid)
                      if 'table_query_writer' in command(pid)]
            assert len(owners) == 1, 'missing unique Table owner'
            owner = owners[0]
            for mode, key in [('wait_capacity', -84), ('wait_denied', -85)]:
                wait_seen.clear()
                state.update(mode=mode, waits=0, ordinary_after_wait=0)
                before = len(state['commands'])
                os.kill(owner, signal.SIGSTOP)
                try:
                    with ThreadPoolExecutor(max_workers=1) as pool:
                        pending = pool.submit(invoke, f'INSERT INTO items (id, value) VALUES ({key}, 840);',
                                              1 if mode == 'wait_denied' else 0)
                        try:
                            if not wait_seen.wait(timeout=5):
                                if pending.done():
                                    raise AssertionError(('caller exited before wait', pending.result()))
                                raise AssertionError('caller never used bounded wait')
                            if mode == 'wait_denied':
                                denied = pending.result(timeout=5)
                                assert 'AccessDenied' in denied.stderr, denied
                                assert state['ordinary_after_wait'] == 0
                                assert not json.loads(saved.read_text())['complete']
                        finally:
                            os.kill(owner, signal.SIGCONT)
                        result = pending.result(timeout=10)
                        if mode == 'wait_capacity':
                            applied(result)
                            assert state['ordinary_after_wait'] > 0, 'wait capacity starved ordinary observation'
                finally:
                    os.kill(owner, signal.SIGCONT)
                assert len(state['commands']) == before + 1, 'observation resubmitted accepted work'
                state['mode'] = None
                if mode == 'wait_denied':
                    applied(invoke('.resume'))
                    assert len(state['commands']) == before + 1
                applied(invoke(f'DELETE FROM items WHERE id = {key};'))
            print('Transit write observation: capacity retries preserve one send; lost receipt requires explicit exact recovery.', flush=True)
            print('Mutation completion waits: bounded hints, exhausted-wait ordinary reads and denied observation recovery passed.', flush=True)
        finally:
            proxy.shutdown()
            thread.join(timeout=5)

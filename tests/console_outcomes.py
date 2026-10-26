"""Independent native peer: statement presentation, no replay, and interrupt races.
This checks client behavior, not native write durability (covered by server proofs).
"""
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]

@contextmanager
def peer(mode):
    definition = re.search(r'\b([a-f0-9]{64})\b', (ROOT/'packages/zig/transit-protocol/src/Growth.zig').read_text()).group(1)
    logical = json.loads((ROOT/'packages/zig/transit-sql-protocol/src/fixtures/logical.json').read_text())
    state = dict(actions=[], token=None, entered=threading.Event(), expired=False, observations=0, submitted=None)
    def failure(code, state='HY000'):
        return dict(err=dict(code=code, sqlstate=list(state.encode()), message=code, retry='never', operation=None, diagnostic=None))
    def operation(outcome=None):
        return dict(operation=dict(identity=dict(account=[4]*32, id=42, kind='table'), token=state['token'], phase='terminal' if outcome else 'active', blocked=mode == 'transient_status' and outcome is None, outcome=outcome, matched=1 if outcome == 'applied' else 0, changed=1 if outcome == 'applied' else 0))
    class Handler(BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'
        def log_message(self, *_): pass
        def handle(self):
            try: super().handle()
            except ConnectionResetError: pass
        def do_POST(self):
            request = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
            assert request['definition'] == definition
            action, value = next(iter(request['action'].items()))
            state['actions'].append((action, value))
            instance = [2]*16
            if action == 'hello':
                result = dict(hello=dict(encoding='transit.logical.v1.hex', session_lease_ms=30000, maximum_message=4194304, maximum_batch=1048576, maximum_rows=32, capabilities=[]))
            elif action == 'open':
                result = dict(opened=dict(session=[5 if state['expired'] else 3]*32, account=[4]*32, database='transit'))
            elif action in ('close', 'close_result', 'touch'):
                result = dict(closed={})
            elif action == 'execute':
                state['token'] = value['token']
                state['submitted'] = time.monotonic()
                assert not value.get('captured', False)
                if mode == 'interrupt_execute':
                    state['entered'].set()
                    time.sleep(2)
                if mode in ('drop_execute', 'slow_acceptance', 'missing', 'timeout_discovery', 'denied', 'expired', 'instance_changed'):
                    self.close_connection = True
                    return
                if mode in ('rows', 'incomplete', 'empty', 'interrupt_fetch'):
                    result = dict(batch=dict(cursor=[6]*32, batch=0, schema=logical['schema'], rows=[] if mode == 'empty' else [logical['cells']], complete=mode == 'empty'))
                else:
                    result = operation()
            elif action == 'fetch':
                if mode == 'interrupt_fetch':
                    state['entered'].set()
                    time.sleep(2)
                result = failure('SqlResultIncomplete') if mode == 'incomplete' else dict(batch=dict(cursor=[6]*32, batch=1, schema=logical['schema'], rows=[], complete=True))
            elif action == 'status':
                assert value == dict(token=state['token'])
                state['observations'] += 1
                if mode == 'transient_status' and state['observations'] == 1: result = failure('AuthorityUnavailable')
                elif mode == 'transient_timeout' and state['observations'] == 1: result = failure('AuthorityTimeout')
                elif mode in ('slow_acceptance', 'expired') and state['observations'] == 2: result = operation()
                elif mode == 'slow_acceptance' and time.monotonic() - state['submitted'] < .5: result = operation()
                elif mode == 'missing': result = failure('MissingGatewayOperation')
                elif mode == 'timeout_discovery': result = failure('AuthorityTimeout')
                elif mode == 'denied': result = failure('AccessDenied', '42501')
                elif mode == 'expired' and not state['expired']:
                    state['expired'] = True
                    result = failure('SqlSessionExpired')
                elif mode.startswith('interrupt'):
                    state['entered'].set()
                    result = operation()
                else: result = operation(mode if mode in ('rejected', 'partial', 'unchanged') else 'applied')
                if mode == 'instance_changed': instance = [9]*16
            elif action == 'cancel':
                if 'query' in value: result = dict(closed={})
                else:
                    assert value == dict(token=state['token'])
                    if mode == 'interrupt_stall': time.sleep(2)
                    result = operation('applied' if mode == 'interrupt_applied' else 'cancelled')
            else: raise AssertionError(action)
            payload = json.dumps(dict(version=1, definition=definition, instance=instance, result=result)).encode()
            try:
                self.send_response(200)
                self.send_header('Content-Length', str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
            except (BrokenPipeError, ConnectionResetError): pass
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try: yield f'http://127.0.0.1:{server.server_port}', state
    finally:
        server.shutdown(); server.server_close(); thread.join()


def check(binary):
    with tempfile.TemporaryDirectory(prefix='transit-outcomes-') as directory:
        root = Path(directory)
        config = root/'console.json'
        for mode in ('applied', 'transient_status', 'transient_timeout', 'rejected', 'partial', 'unchanged', 'drop_execute', 'slow_acceptance', 'missing', 'timeout_discovery', 'denied', 'expired', 'instance_changed', 'rows', 'empty', 'incomplete', 'interrupt_execute', 'interrupt_fetch', 'interrupt_cancelled', 'interrupt_applied', 'interrupt_stall'):
            with peer(mode) as (endpoint, state):
                config.write_text(json.dumps(dict(version=1, endpoint=endpoint, authentication='trust', request_timeout_ms=200)))
                args = [binary, 'console', '--no-rc', '--config', str(config), '--format', 'json']
                process = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                process.stdin.write('SELECT * FROM items;\n' if mode in ('rows', 'empty', 'incomplete', 'interrupt_fetch') else 'INSERT INTO items VALUES (1);\n')
                process.stdin.flush()
                if mode.startswith('interrupt'):
                    assert state['entered'].wait(5), mode
                    process.stdin.write('INSERT INTO items VALUES (2);\n'); process.stdin.flush()
                    started = time.monotonic()
                    process.send_signal(signal.SIGINT)
                try:
                    stdout, stderr = process.communicate(timeout=8)
                except subprocess.TimeoutExpired:
                    process.kill()
                    output = process.communicate()
                    raise AssertionError((mode, state['actions'][-5:], output))
                if mode.startswith('interrupt'):
                    assert time.monotonic()-started < 2, (mode, stderr)
                    assert process.returncode == 130, (mode, process.returncode, stderr)
                    if mode == 'interrupt_applied': assert json.loads(stdout)['completion']['changed'] == 1
                    elif mode in ('interrupt_cancelled', 'interrupt_execute'): assert 'Statement was cancelled' in stderr and not stdout
                    elif mode == 'interrupt_fetch': assert 'partial result' in stderr and '"complete_coverage":true' not in stdout
                    else: assert 'Could not confirm' in stderr and not stdout
                elif mode in ('missing', 'timeout_discovery', 'denied', 'instance_changed'):
                    assert process.returncode == 1 and not stdout and 'may apply changes twice' in stderr, (mode, stdout, stderr)
                    if mode == 'denied': assert 'Permissions prevented' in stderr
                elif mode == 'incomplete':
                    assert process.returncode == 1 and '"complete_coverage":true' not in stdout and 'partial result' in stderr, (mode, stdout, stderr)
                elif mode in ('rejected', 'partial'):
                    assert process.returncode == 1 and not stdout, (mode, stdout, stderr)
                    assert ('was rejected' if mode == 'rejected' else 'only partially') in stderr
                elif mode == 'unchanged':
                    assert process.returncode == 0 and json.loads(stdout)['completion']['changed'] == 0, (mode, stdout, stderr)
                elif mode in ('rows', 'empty'):
                    assert process.returncode == 0 and '"complete_coverage":true' in stdout, (mode, stdout, stderr)
                else:
                    assert process.returncode == 0, (mode, stderr)
                    assert json.loads(stdout)['completion']['changed'] == 1, (mode, stdout)
                executions = [value for action, value in state['actions'] if action == 'execute']
                assert len(executions) == 1, (mode, state['actions'])
                if mode == 'transient_timeout': assert state['observations'] == 2, state['actions']
                if mode == 'timeout_discovery': assert time.monotonic() - state['submitted'] < 2, state['actions']
                assert 'token:' not in stdout+stderr and '.resume' not in stdout+stderr and '"operation"' not in stdout
                if mode == 'expired': assert len([1 for action, _ in state['actions'] if action == 'open']) == 2
    print('Console outcomes: original-token observation, expired session, denial, instance changes, incomplete rows and cancellation races passed without SQL replay.')

if __name__ == '__main__':
    import sys
    check(str(Path(sys.argv[1]).resolve()))

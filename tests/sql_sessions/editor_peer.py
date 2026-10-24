"""Small session peer for editor-only tests; never evidence of SQL execution."""
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
import threading


@contextmanager
def peer(*, structured=False, lease_ms=30000, assist=None, execute=None, instance=None):
    definition = re.search(r'\b([a-f0-9]{64})\b', (Path(__file__).resolve().parents[2]/'packages/zig/transit-protocol/src/Growth.zig').read_text()).group(1)
    actions = []
    diagnostic = dict(version=1, definition=definition, code='sql.unknown_column', category='binding', stage='bind', outcome='not_submitted', evidence='local_before_dispatch', message='Unknown column in this scope', cause='UnknownColumn', identity=None,
                      location=dict(source=None, source_encoding='utf8', source_truncated=False, statement=None, offset='7', length='0', line='1', byte_column='8'),
                      facts=[dict(field='column', origin='caller', availability='provided', value=dict(text='typo'))]+[None]*15,
                      actions=[dict(kind='correct_input', target=None)]+[None]*3) if structured else None
    class Handler(BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'
        def log_message(self, *_):
            pass
        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
            assert body['definition'] == definition and body['version'] == 1
            action, value = next(iter(body['action'].items()))
            actions.append((action, value))
            if action == 'hello':
                result = dict(hello=dict(encoding='transit.logical.v1.hex', session_lease_ms=lease_ms, maximum_message=4194304, maximum_batch=1048576, maximum_rows=32, capabilities=[]))
            elif action == 'open':
                result = dict(opened=dict(session=[3]*32, account=[4]*32, database='transit', proof=''))
            elif action == 'close':
                result = dict(closed={})
            elif action == 'assist':
                assert assist is not None, 'Unexpected metadata request'
                result = assist(value)
            elif action == 'touch':
                result = dict(completion=dict(kind="show", matched=0, changed=0))
            else:
                assert action == 'execute', action
                if execute is not None:
                    execute(value)
                result = dict(err=dict(code='InvalidSqlSyntax', sqlstate=list(b'42601'), message='Editor fixture rejects execution', retry='never', operation=None, diagnostic=diagnostic))
            payload = json.dumps(dict(version=1, definition=definition, instance=instance(action) if instance else [2]*16, result=result)).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(payload)))
            self.end_headers()
            try:
                self.wfile.write(payload)
            except (BrokenPipeError, ConnectionResetError):
                pass  # A cancelled read is allowed to close its transport.
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f'http://127.0.0.1:{server.server_port}', actions
    finally:
        server.shutdown()
        server.server_close()
        thread.join()

"""Real session limits, control isolation and native client trust failures."""
import http.server
import json
import subprocess
import threading


def sessions(Client, first, second, operation):
    Client(first.root, first.port).open(password='wrong-password', error='AuthenticationFailed').close()
    # The ordinary and native adapters share a session budget. Exhausting it
    # must leave control requests on an existing session independently usable.
    others = []
    try:
        for _ in range(6):
            others.append(Client(first.root, first.port).open())
        Client(first.root, first.port).open(error='GatewayConnectionCapacity').close()
        assert first.call(dict(status=dict(operation=operation)))['operation']['phase'] == 'terminal'
    finally:
        for other in others:
            other.close()
    value = first.execute('SELECT id FROM native_sessions')['batch']
    protected = second.execute('SELECT id FROM native_sessions')['batch']
    second.call(dict(cancel=dict(query=value['cursor'])), error='SqlResultIncomplete')
    assert first.call(dict(fetch=dict(cursor=value['cursor'], batch=value['batch'])))['batch'] == value
    first.call(dict(cancel=dict(query=value['cursor'])))
    first.call(dict(fetch=dict(cursor=value['cursor'], batch=value['batch'])), error='SqlResultIncomplete')
    assert second.call(dict(fetch=dict(cursor=protected['cursor'], batch=protected['batch'])))['batch'] == protected
    second.call(dict(close_result=protected['cursor']))
    # SET remains local to the logical session, including transport replacement.
    first.execute('SET query.statement_timeout = 123456')
    first.http.close()
    first.last = 0
    one = first.execute('SHOW query.statement_timeout')['batch']
    two = second.execute('SHOW query.statement_timeout')['batch']
    assert one['rows'] != two['rows']
    for client, batch in ((first, one), (second, two)):
        client.call(dict(close_result=batch['cursor']))
    first.execute('RESET query.statement_timeout')


def console(binary, cwd, config, password, port, environment):
    original = config.read_text()
    def rejected(text):
        config.write_text(text)
        result = subprocess.run([binary, 'console', '--config', str(config), '-c',
                                 'CREATE TABLE must_not_run (id INT64)'], cwd=cwd,
                                env=environment, capture_output=True, text=True, timeout=45)
        assert result.returncode != 0 and not result.stdout, result
        assert 'proof-password' not in result.stderr
    try:
        # The certificate names localhost only; trust and hostname checks are
        # independent. No explicit CA means the system roots, never trust-all.
        rejected(original.replace(f'https://localhost:{port}', f'https://127.0.0.1:{port}'))
        rejected('\n'.join(line for line in original.splitlines() if not line.startswith('ca_file:')) + '\n')
        password.write_text('wrong-password')
        rejected(original)
    finally:
        password.write_text('proof-password')
        config.write_text(original)
    reached = []
    class Redirect(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            self.rfile.read(int(self.headers['Content-Length']))
            reached.append(self.path)
            self.send_response(307)
            self.send_header('Location', f'http://127.0.0.1:{self.server.server_port}/forwarded')
            self.send_header('Content-Length', '0')
            self.end_headers()
        def log_message(self, *_):
            pass
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Redirect)
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        rejected(json.dumps(dict(version=1, endpoint=f'http://127.0.0.1:{server.server_port}',
                                 account='proof', database='data', authentication='trust')))
        assert reached == ['/v1/sql/session'], reached
    finally:
        config.write_text(original)
        server.shutdown()
        server.server_close()
        worker.join()

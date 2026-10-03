"""Owned fault peers for local applications; never used by the production manager."""
import ctypes
import hashlib
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time

from server import children, joined
from storage import free_port
from serving import compact


class ExistingKey:
    def __init__(self, directory, seed_file):
        self.path = directory / (Path(seed_file).stem + '-proof.der')
        self.path.write_bytes(bytes.fromhex('302e020100300506032b657004220420') + bytes.fromhex(Path(seed_file).read_text().strip()))
        self.path.chmod(0o600)
        self.public = list(subprocess.check_output(['openssl', 'pkey', '-inform', 'DER', '-in', str(self.path), '-pubout', '-outform', 'DER'])[-32:])

    def sign(self, data):
        with tempfile.NamedTemporaryFile(dir=self.path.parent) as message:
            message.write(data)
            message.flush()
            return list(subprocess.check_output(['openssl', 'pkeyutl', '-sign', '-rawin', '-inkey', str(self.path), '-keyform', 'DER', '-in', message.name]))


def native(key, realm, principal, value, sequence=None):
    if sequence is None:
        body = dict(version=1, definition='695a46c853d1442c3eae1b8079694b2f04b616b1798d25f50fc243325f596ee2', realm=realm, principal=principal, kind=value)
        return dict(query=body, signature=key.sign(hashlib.sha256(b'transit.query.v1\0' + compact(body)).digest()))
    body = dict(version=1, definition='695a46c853d1442c3eae1b8079694b2f04b616b1798d25f50fc243325f596ee2', realm=realm, principal=principal, sequence=sequence, command=value)
    return dict(request=body, signature=key.sign(hashlib.sha256(b'transit.request.v1\0' + compact(body)).digest()))


def post(port, path, value, expected=200, headers=None):
    connection = HTTPConnection('127.0.0.1', port, timeout=7)
    try:
        connection.request('POST', path, compact(value), headers or {'Content-Type': 'application/json'})
        response = connection.getresponse()
        data = response.read()
        assert response.status == expected, (response.status, data)
        return json.loads(data)
    finally:
        connection.close()


def management(key, config, command, operation='probe'):
    request = dict(version=1, installation=config['installation'], realm=config['realm'], principal=config['principal'], operation=operation, command=command)
    return dict(request=request, public_key=key.public, identity=native(key, config['realm'], config['principal'], {'identity': {}}),
        signature=key.sign(hashlib.sha256(b'transit.application.v1\0' + compact(request)).digest()))


def descendants(pid):
    result = children(pid)
    for child in list(result):
        result.update(descendants(child))
    return result


def node(real, directory, args):
    """Explicit test node executable: real disk authority behind an owned peer.

    The manager owns this process group; the authority also arms parent death.
    No private Transit installation checkpoint is edited by the fault injector.
    """
    directory = Path(directory)
    if '--maintain' in args:
        os.execv(real, [real, *args])
    source = json.loads(Path(args[0]).read_text())
    external = source['port']
    source['port'] = free_port()
    backend = directory / 'backend-node.json'
    backend.write_text(json.dumps(source))
    expected_parent = os.getpid()

    def death():
        if ctypes.CDLL(None).prctl(1, signal.SIGKILL, 0, 0, 0) != 0 or os.getppid() != expected_parent:
            os._exit(1)

    process = subprocess.Popen([real, str(backend), *args[1:]], preexec_fn=death)
    stop = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    signal.signal(signal.SIGINT, lambda *_: stop.set())
    mutex = threading.Lock()

    class Peer(BaseHTTPRequestHandler):
        def log_message(self, *_): pass
        def do_GET(self): self.forward()
        def do_POST(self): self.forward()
        def forward(self):
            body = self.rfile.read(int(self.headers.get('Content-Length', 0)))
            upstream = HTTPConnection('127.0.0.1', source['port'], timeout=4)
            try:
                upstream.request(self.command, self.path, body, {'Content-Type': 'application/json'})
                response = upstream.getresponse()
                data = response.read()
                if self.path == '/v1/command' and response.status == 200:
                    envelope = json.loads(body)
                    with mutex:
                        # Saved before dropping: native receipt remains real and
                        # every replay is checked for byte/receipt equality.
                        for saved in directory.glob('dropped-*.json'):
                            frozen = json.loads(saved.read_text())
                            if body.hex() == frozen['body']:
                                assert data.hex() == frozen['receipt']
                                (directory / ('retried-' + saved.stem[8:])).touch()
                        if envelope['request']['principal'] >= 2**52 and ('turn' in envelope['request']['command'] or 'turn_with_versions' in envelope['request']['command']):
                            frozen_worker = directory / 'accepted-worker.json'
                            if not frozen_worker.exists():
                                frozen_worker.write_text(json.dumps(envelope))
                        armed = directory / 'drop-next'
                        if armed.exists():
                            selection = json.loads(armed.read_text())
                            selected = selection['label']
                            if selection['command'] in envelope['request']['command'] and (selection.get('principal') is None or selection['principal'] == envelope['request']['principal']) and (selection.get('resource') is None or selection['resource'] == envelope['request']['command'][selection['command']].get('resource')):
                                frozen = dict(body=body.hex(), receipt=data.hex())
                                (directory / ('dropped-' + selected + '.json')).write_text(json.dumps(frozen))
                                armed.unlink()
                                # Hold the reply so the test can kill management
                                # after the native commit but before its receipt.
                                release = directory / ('release-' + selected)
                                deadline = time.monotonic() + 8
                                while not release.exists() and not stop.is_set() and time.monotonic() < deadline:
                                    time.sleep(.02)
                                self.close_connection = True
                                return
                self.send_response(response.status)
                self.send_header('Content-Length', str(len(data)))
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(data)
            except (OSError, ConnectionError):
                self.close_connection = True
            except BaseException as error:
                (directory / 'peer-failure').write_text(repr(error))
                self.close_connection = True
            finally:
                upstream.close()

    server = ThreadingHTTPServer(('127.0.0.1', external), Peer)
    server.timeout = .1
    try:
        while not stop.is_set() and process.poll() is None:
            server.handle_request()
    finally:
        server.server_close()
        if process.poll() is None:
            process.terminate()
        try:
            process.wait(timeout=1)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def install_peer(fixture):
    real = fixture.config['executables']['node']
    wrapper = fixture.root / 'fault-node'
    wrapper.write_text('#!' + sys.executable + '\nimport sys\nsys.path.insert(0, ' + repr(str(Path(__file__).parent)) + ')\nfrom server_application_faults import node\nnode(' + repr(real) + ', ' + repr(str(fixture.root)) + ', sys.argv[1:])\n')
    wrapper.chmod(0o700)
    fixture.config['executables']['node'] = str(wrapper)
    fixture.path.write_text(json.dumps(fixture.config))


def wait_file(path, timeout=20):
    deadline = time.monotonic() + timeout
    while not path.exists():
        assert time.monotonic() < deadline, path
        time.sleep(.02)


def arm(fixture, command, label=None, principal=None):
    (fixture.root / 'drop-next').write_text(json.dumps(dict(command=command, label=label or command, principal=principal)))


def run(cli, node_binary, host, worker, operator):
    from server_applications import Applications
    import concurrent.futures
    import shutil
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    fixture = Applications(cli, node_binary, host)
    install_peer(fixture)
    started = time.monotonic()
    success = False
    operator, worker = str(Path(operator).resolve()), str(Path(worker).resolve())
    print(f'Application fault proof: {fixture.root}', flush=True)
    owned = set()

    def stop(kill=False):
        owned.update(descendants(fixture.process.pid))
        fixture.stop(kill=kill)
        joined(owned)
        owned.clear()

    def domain(caller, mode, operation=None, *args, fail=False):
        argv = [operator, str(fixture.root / (caller + '.json')), mode]
        if operation:
            argv.append(str(fixture.root / (operation + '.json')))
        command = [*argv, *map(str, args)]
        deadline = time.monotonic() + 40
        while True:
            result = subprocess.run(command, capture_output=True, text=True, timeout=max(1, deadline-time.monotonic()))
            if fail or result.returncode == 0 or result.stderr.strip() not in (
                    'error: AuthorityUnavailable', 'error: AuthorityTimeout', 'error: HttpConnectionClosing') or time.monotonic() >= deadline:
                break
            # As in server_applications, retry through the same public recovery
            # file. Never prepare a new operation to hide an uncertain result.
            time.sleep(.05)
        if fail:
            assert result.returncode != 0, result
            return result
        assert result.returncode == 0, result
        return json.loads(result.stdout)

    try:
        fixture.start(initialize=True)
        fixture.ready()
        declaration = json.loads(subprocess.check_output([operator, 'manifest', worker], text=True))
        manifest = fixture.root / 'application.json'
        manifest.write_text(json.dumps(declaration))
        arm(fixture, 'spawn')
        fixture.app('install', '--file', manifest, '--operation', 'install')
        wait_file(fixture.root / 'dropped-spawn.json')
        stop(kill=True)
        arm(fixture, 'rotate_worker')
        fixture.start()
        fixture.ready()
        wait_file(fixture.root / 'dropped-rotate_worker.json')
        stop(kill=True)
        fixture.start()
        fixture.ready()
        ready = fixture.active()
        for label in ('spawn', 'rotate_worker'):
            wait_file(fixture.root / ('retried-' + label))
        fixture.app('retry', '--operation', 'install')
        principal = ready['roles'][0]['principal']
        for caller in ('writer', 'inspector', 'operator'):
            fixture.app('connect', '--application', 'work-items', '--caller', caller, '--output', fixture.root / (caller + '.json'))
        management_config = {key: json.loads(value) for key, value in (line.split(': ', 1) for line in fixture.management.read_text().splitlines())}
        installer = ExistingKey(fixture.root, management_config['seed_file'])
        port = fixture.config['applications']['port']
        writer = json.loads((fixture.root / 'writer.json').read_text())
        writer_key = ExistingKey(fixture.root, writer['seed_file'])
        foreign = dict(management_config, principal=writer['principal'])
        denied = management(writer_key, foreign, {'connect': {'application': 'work-items', 'caller': 'operator'}})
        assert post(port, '/applications/v1', denied, 403)['err'] == 'AccessDenied'
        assert post(port, '/applications/v1', {}, 400)['err'] == 'InvalidRequest'
        good = management(installer, management_config, {'status': {'application': 'work-items', 'after': 0}})
        changed = json.loads(json.dumps(good))
        changed['request']['installation'][0] ^= 1
        post(port, '/applications/v1', changed, 403)
        changed = dict(good, unknown=True)
        post(port, '/applications/v1', changed, 400)
        post(port, '/applications/v1', good, 403, {'Host': f'127.0.0.1:{port}', 'Origin': 'http://localhost'})
        post(port, '/applications/v1', {'padding': 'x' * 65536}, 413)
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            tasks = [pool.submit(post, port, '/applications/v1', denied, 403) for _ in range(20)]
            attempt = time.monotonic()
            connection = HTTPConnection('127.0.0.1', port, timeout=5)
            connection.request('GET', '/health')
            assert connection.getresponse().status == 200
            connection.close()
            latency = time.monotonic() - attempt
            assert latency < 5
            for task in tasks:
                task.result()
        domain('operator', 'authorize', 'authorize')
        for i in range(5):
            domain('writer', 'put', f'put-{i}', i, i % 2)
        domain('operator', 'begin', 'begin')
        arm(fixture, 'send', 'copy-send', json.loads((fixture.root / 'operator.json').read_text())['principal'])
        domain('operator', 'step', 'copy-1', fail=True)
        (fixture.root / 'release-copy-send').touch()
        fixture.kill_role('/applications/work-items/data.bootstrap.json')
        fresh = fixture.active(previous=ready['roles'][0]['generation'])
        domain('operator', 'step', 'copy-1')
        wait_file(fixture.root / 'retried-copy-send')
        frozen = json.loads((fixture.root / 'accepted-worker.json').read_text())
        post(fixture.config['ports']['node'], '/v1/command', frozen, 403)
        # Lose a committed worker turn reply. Its live host must retry exact
        # bytes; this is separate from reconstructing work after owner loss.
        arm(fixture, 'turn', 'worker-copy', principal)
        domain('operator', 'step', 'copy-2')
        (fixture.root / 'release-worker-copy').touch()
        wait_file(fixture.root / 'retried-worker-copy')
        for ordinal in range(3, 20):
            state = domain('operator', 'inspect')
            if state['cursor']['phase'] == 'ready':
                break
            domain('operator', 'step', f'copy-{ordinal}')
        else:
            raise AssertionError('Migration did not reach verified activation')
        arm(fixture, 'send', 'activation-send', json.loads((fixture.root / 'operator.json').read_text())['principal'])
        domain('operator', 'step', 'activate', fail=True)
        (fixture.root / 'release-activation-send').touch()
        domain('operator', 'step', 'activate')
        wait_file(fixture.root / 'retried-activation-send')
        assert domain('inspector', 'inspect')['head']['epoch'] == '2'
        # Root credentials are used only by this adversarial fixture to revoke
        # current native rights. The application workflow above never reads them.
        root = ExistingKey(fixture.root, fixture.installation / 'root.seed')
        def revoke(command):
            current = post(fixture.config['ports']['node'], '/v1/query', native(root, 73, 0, {'capabilities': {}}))
            return post(fixture.config['ports']['node'], '/v1/command', native(root, 73, 0, command, current['principal_sequence'] + 1))
        inspector = json.loads((fixture.root / 'inspector.json').read_text())
        revoke({'grant_resource': {'resource': ready['resources'][0]['id'], 'subject': inspector['principal'], 'permissions': 0}})
        assert 'AccessDenied' in domain('inspector', 'inspect', fail=True).stderr
        # Revoking a worker's coarse grant cannot be repaired by replacement.
        revoke({'revoke': principal})
        deadline = time.monotonic() + 45
        while not any(role['state'] == 'failed' for role in fixture.status()['roles']):
            assert time.monotonic() < deadline
            time.sleep(.1)
        assert 'AccessDenied' in fixture.status()['roles'][0]['error_name'] or fixture.status()['roles'][0]['error_name'] in ('Conflict', 'Rejected', 'InvalidRegistration')
        revoke({'revoke': management_config['principal']})
        post(port, '/applications/v1', good, 403)
        assert not (fixture.root / 'peer-failure').exists(), (fixture.root / 'peer-failure').read_text() if (fixture.root / 'peer-failure').exists() else ''
        stop()
        print(json.dumps({'application_faults': 'passed', 'lost_replies': ['spawn', 'rotate_worker', 'copy-send', 'worker-copy', 'activation-send'],
            'control_seconds': round(latency, 3), 'elapsed_seconds': round(time.monotonic() - started, 3)}), flush=True)
        success = True
    finally:
        if fixture.process is not None:
            stop()
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Failed application fault evidence retained: {fixture.root}', file=sys.stderr)


if __name__ == '__main__':
    run(*sys.argv[1:])

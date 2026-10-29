"""Private installed-test proxy: stop direct execution while native control runs."""
from runner.paths import TESTS
import ctypes
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import threading
from harness.processes import joined
from interfaces.installation.server import Fixture


def process_start(pid):
    try:
        return Path(f'/proc/{pid}/stat').read_text().rsplit(') ', 1)[1].split()[19]
    except FileNotFoundError:
        return None


class Boundary:
    def __init__(self, fixture):
        self.directory = fixture.root / 'direct-boundary'
        self.directory.mkdir(mode=0o700)
        self.blocked = self.directory / 'block-execute'
        self.observed = self.directory / 'observed.json'
        self.upstream = fixture.reserve_port()
        wrapper = fixture.root / 'direct-node'
        module = str(TESTS)
        configured = fixture.config.setdefault('executables', {}).get('node')
        binary = [configured] if configured else [fixture.cli, '__transit_role_v1', 'node']
        wrapper.write_text(f'#!{sys.executable}\nimport sys\nsys.path.insert(0, {module!r})\n'
                           f'from interfaces.installation.server_direct_boundary import run_node\n'
                           f'run_node({binary!r}, {str(self.directory)!r}, {self.upstream})\n')
        wrapper.chmod(0o700)
        fixture.config['executables']['node'] = str(wrapper)
        fixture.path.write_text(json.dumps(fixture.config))

    def pause(self):
        self.observed.unlink(missing_ok=True)
        self.blocked.touch(mode=0o600)

    def resume(self):
        self.blocked.unlink(missing_ok=True)

    def reap(self):
        # SIGKILL of the manager kills this proxy and its node via PDEATHSIG.
        # The proof's subreaper also joins the adopted node, including nodes
        # from earlier supervisor replacements. Never act on a reused PID.
        for path in self.directory.glob('node-*.pid'):
            pid, started = path.read_text().split()
            pid = int(pid)
            if process_start(pid) == started:
                joined({pid})


class FaultFixture(Fixture):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.boundary = Boundary(self)

    def stop(self, kill=False):
        super().stop(kill=kill)
        self.boundary.reap()


def parent_death():
    parent = os.getppid()
    assert ctypes.CDLL(None).prctl(1, signal.SIGKILL, 0, 0, 0) == 0
    if os.getppid() != parent or parent == 1:
        os._exit(1)


def run_node(binary, directory, upstream_port):
    parent_death()
    directory = Path(directory)
    configuration = json.loads(Path(sys.argv[1]).read_text())
    front_port = configuration['port']
    configuration['port'] = upstream_port
    upstream_config = directory / 'node.json'
    upstream_config.write_text(json.dumps(configuration))
    upstream_config.chmod(0o600)
    stopping = threading.Event()
    lock = threading.Lock()
    slots = threading.BoundedSemaphore(32)

    class Proxy(BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'

        def log_message(self, *_):
            pass

        def reply(self, status, body):
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(body)
            self.close_connection = True

        def forward(self):
            if not slots.acquire(blocking=False):
                return self.reply(503, b'{"err":"AuthorityUnavailable"}')
            try:
                count = int(self.headers.get('Content-Length', 0))
                assert 0 <= count <= 8 * 1024 * 1024
                body = self.rfile.read(count)
                assert len(body) == count
                if self.path == '/table/v1':
                    request = json.loads(body)
                    operation = request['action'].get('operation') or request['action'].get('namespace_operation')
                    if 'commit_saved' in request['action']:
                        operation = dict(command='execute', binding=request['action']['commit_saved']['binding'])
                    if operation and operation['command'] == 'execute' and (directory / 'block-execute').exists():
                        # Record only the exact operation binding, never signing
                        # material, credentials or a Table's row payload.
                        with lock:
                            temporary = directory / 'observed.pending'
                            temporary.write_text(json.dumps(operation['binding']))
                            temporary.replace(directory / 'observed.json')
                        return self.reply(503, b'{"err":"AuthorityUnavailable"}')
                upstream = HTTPConnection('127.0.0.1', upstream_port, timeout=60)
                try:
                    headers = {key: value for key, value in self.headers.items()
                               if key.lower() not in ('host', 'connection', 'content-length')}
                    upstream.request(self.command, self.path, body if count else None, headers)
                    response = upstream.getresponse()
                    self.reply(response.status, response.read())
                finally:
                    upstream.close()
            except (ConnectionError, OSError, TimeoutError):
                self.close_connection = True
            finally:
                slots.release()

        do_GET = do_POST = forward

    server = ThreadingHTTPServer(('127.0.0.1', front_port), Proxy)
    server.daemon_threads = True
    for name in (signal.SIGTERM, signal.SIGINT):
        signal.signal(name, lambda *_: stopping.set())
    child = subprocess.Popen([*binary, str(upstream_config), *sys.argv[2:]], preexec_fn=parent_death,
                             env=os.environ | {"TEST_TRANSIT_DIRECT_BOUNDARY": str(directory)})
    (directory / f'node-{child.pid}.pid').write_text(f'{child.pid} {process_start(child.pid)}')
    thread = threading.Thread(target=server.serve_forever, kwargs={'poll_interval': .05}, daemon=True)
    thread.start()
    try:
        while not stopping.wait(.05):
            if child.poll() is not None:
                break
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
        if child.poll() is None:
            child.terminate()
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait(timeout=5)
    raise SystemExit(child.returncode if not stopping.is_set() else 0)

"""Owned native transport peer: admission pressure and a lost retry receipt."""
import ctypes
import hashlib
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import threading
import time


def configure(installation):
    port = installation.reserve_port()
    wrapper = installation.root / 'native-transport'
    records = installation.root / 'lifecycle-transport.jsonl'
    wrapper.write_text('#!' + sys.executable + '\nimport sys\n'
        'sys.path.insert(0,' + repr(str(Path(__file__).resolve().parents[2])) + ')\n'
        'from runtime.station.station_service_transport import run\n'
        'run(' + repr(installation.cli) + ',' + str(port) + ',' + repr(str(records)) + ',sys.argv[1:])\n')
    wrapper.chmod(0o700)
    installation.config['executables']['node'] = str(wrapper)


def run(binary, port, record_path, args):
    path = Path(args[0])
    config = json.loads(path.read_text())
    front = config['port']
    config['port'] = port
    target = path.with_name('transport-native.json')
    target.write_text(json.dumps(config))
    target.chmod(0o600)
    parent = os.getpid()

    def owned_child():
        assert ctypes.CDLL(None).prctl(1, signal.SIGKILL, 0, 0, 0) == 0
        if os.getppid() != parent: os._exit(1)

    node = subprocess.Popen([binary, '__transit_role_v1', 'node', str(target), *args[1:]], preexec_fn=owned_child)
    records = Path(record_path)
    pressure = records.with_name('station-pressure.json')
    pressure_observed = records.with_name('station-pressure-observed.json')
    lock = threading.Lock()

    class Proxy(BaseHTTPRequestHandler):
        def log_message(self, *_): pass

        def forward(self, method):
            body = self.rfile.read(int(self.headers.get('Content-Length', '0')))
            upstream = HTTPConnection('127.0.0.1', port, timeout=10)
            try:
                envelope = json.loads(body) if body else {}
                request = envelope.get('request', {})
                query = envelope.get('query', {})
                if query.get('principal') == 5 and pressure.exists() and time.monotonic() < json.loads(pressure.read_text())['until']:
                    status, data = 503, b'{"err":"HttpCapacity"}'
                    with lock:
                        count = json.loads(pressure_observed.read_text())['count'] if pressure_observed.exists() else 0
                        temporary = pressure_observed.with_suffix('.tmp')
                        temporary.write_text(json.dumps(dict(count=count + 1)))
                        temporary.replace(pressure_observed)
                else:
                    upstream.request(method, self.path, body, {'Content-Type': 'application/json'})
                    response = upstream.getresponse()
                    data, status = response.read(), response.status
                if request.get('principal') == 6 and 'retry' in request.get('command', {}) and status == 200:
                    with lock:
                        first = not records.exists()
                        # Digests establish byte-for-byte replay without retaining
                        # credentials or arbitrary native application payloads.
                        with records.open('a') as output:
                            output.write(json.dumps(dict(sha256=hashlib.sha256(body).hexdigest(), sequence=request['sequence'], position=json.loads(data)['position'])) + '\n')
                            output.flush()
                            os.fsync(output.fileno())
                        if first:
                            self.close_connection = True
                            return
            except (ConnectionError, TimeoutError):
                status, data = 503, b'{"err":"AuthorityUnavailable"}'
            finally:
                upstream.close()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            try: self.wfile.write(data)
            except (BrokenPipeError, ConnectionResetError): pass

        def do_GET(self): self.forward('GET')
        def do_POST(self): self.forward('POST')

    proxy = ThreadingHTTPServer(('127.0.0.1', front), Proxy)
    proxy.daemon_threads = True
    try:
        proxy.serve_forever(poll_interval=.05)
    finally:
        proxy.server_close()
        node.terminate()
        node.wait(timeout=10)

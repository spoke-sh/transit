"""Ordinary retained recovery behind a private, faulting storage peer."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import threading

from harness.ursula import Fixture
from harness.services import free_port, wait_ready


def run(node, caller):
    node, caller = str(Path(node).resolve()), str(Path(caller).resolve())
    with Fixture() as fixture:
        public = json.loads(subprocess.check_output([caller, 'public'], timeout=10))
        config = dict(profile='native_v1', genesis=dict(realm=42, root_key=public),
                      ursula_url=fixture.url, bucket='node-recovery', journal='authority', port=free_port())
        path = fixture.root / 'node.json'
        path.write_text(json.dumps(config))
        log = (fixture.root / 'node.log').open('w+')
        subprocess.run([node, str(path), '--initialize'], check=True, timeout=20, stdout=log, stderr=log)
        # Recover the disk WAL before interposing faults; ordinary opens below
        # must never issue a provider mutation, including an implicit bootstrap.
        fixture.stop()
        fixture.start()
        fault = dict(mode='recover', reads=0, writes=0, drops=0, unavailable=0, tail=None)

        class Peer(BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.1'
            def log_message(self, *_): pass
            def do_HEAD(self): self.forward()
            def do_GET(self): self.forward()
            def do_POST(self): self.forward()
            def do_PUT(self): self.forward()
            def do_DELETE(self): self.forward()

            def forward(self):
                if self.command not in ('GET', 'HEAD'):
                    fault['writes'] += 1
                    self.send_error(500)
                    return
                fault['reads'] += 1
                if fault['mode'] == 'recover' and fault['reads'] == 1:
                    fault['drops'] += 1
                    self.close_connection = True
                    return
                status = None
                if fault['mode'] == 'unavailable' or (fault['mode'] == 'recover' and fault['reads'] == 2):
                    fault['unavailable'] += 1
                    status = 503
                elif fault['mode'] == 'denied':
                    status = 403
                elif fault['mode'] == 'missing':
                    status = 404
                if status is not None:
                    self.send_response(status)
                    self.send_header('Content-Length', '0')
                    self.end_headers()
                    return
                connection = HTTPConnection('127.0.0.1', fixture.port, timeout=5)
                try:
                    connection.request(self.command, self.path)
                    response = connection.getresponse()
                    body = response.read()
                    headers = response.getheaders()
                    if self.command == 'HEAD':
                        # Retain the provider's exact published record coordinate
                        # for comparison across successful read-only recovery.
                        coordinate = dict((k.lower(), v) for k, v in headers).get('stream-record-next')
                        if coordinate is not None:
                            if fault['tail'] is not None:
                                assert coordinate == fault['tail'], (coordinate, fault['tail'])
                            fault['tail'] = coordinate
                    if self.command == 'GET' and fault['mode'] in ('foreign-definition', 'missing-definition', 'corrupt') and '/authority?' in self.path:
                        entry = json.loads(body)
                        if fault['mode'] == 'foreign-definition':
                            entry['genesis']['head']['definition'] = '0' * 64
                        elif fault['mode'] == 'missing-definition':
                            del entry['genesis']['head']['definition']
                        body = b'{' if fault['mode'] == 'corrupt' else json.dumps(entry).encode()
                    self.send_response(response.status)
                    for key, value in headers:
                        if key.lower() not in ('connection', 'transfer-encoding', 'content-length'):
                            self.send_header(key, value)
                    self.send_header('Content-Length', str(len(body)))
                    self.end_headers()
                    if body:
                        self.wfile.write(body)
                finally:
                    connection.close()

        peer = ThreadingHTTPServer(('127.0.0.1', 0), Peer)
        thread = threading.Thread(target=peer.serve_forever, daemon=True)
        thread.start()
        config['ursula_url'] = f'http://127.0.0.1:{peer.server_port}'
        process = None
        try:
            for mode in ('recover', 'unavailable', 'denied', 'missing', 'foreign-definition', 'missing-definition', 'corrupt', 'wrong-genesis'):
                fault.update(mode=mode, reads=0)
                if mode == 'wrong-genesis':
                    config['genesis']['realm'] = 43
                path.write_text(json.dumps(config))
                process = subprocess.Popen([node, str(path)], stdout=log, stderr=log)
                if mode == 'recover':
                    wait_ready(fixture.http, process, f"http://127.0.0.1:{config['port']}/health")
                    assert fault['drops'] == 1 and fault['unavailable'] == 1, fault
                    assert fault['tail'] == '1', fault
                    process.terminate()
                    process.wait(timeout=10)
                else:
                    assert process.wait(timeout=10) != 0, mode
                    expected = 3 if mode == 'unavailable' else 1 if mode in ('denied', 'missing') else 2
                    assert fault['reads'] == expected, (mode, fault)
                process = None
                assert fault['writes'] == 0, (mode, fault)
            print('Node recovery: connection loss and 503 retry, finite exhaustion, denied/missing/genesis/definition/corruption rejection; unchanged tail and no storage writes.')
        except BaseException:
            log.flush()
            log.seek(0)
            sys.stderr.write(log.read()[-12000:])
            raise
        finally:
            if process is not None:
                if process.poll() is None:
                    process.kill()
                process.wait(timeout=10)
            peer.shutdown()
            peer.server_close()
            thread.join(timeout=5)
            log.close()


if __name__ == '__main__':
    run(*sys.argv[1:])

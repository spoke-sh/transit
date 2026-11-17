"""Native bulk publication, exact retry and qualified reads over native disk and the MinIO immutable tier."""
from runner.paths import ROOT
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
from http.client import HTTPConnection, RemoteDisconnected
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import socket
import subprocess
import sys
import threading
import time

from interfaces.http.serving import Key, compact
from harness.native import Fixture
from storage.providers.cold_storage import ColdStore
from harness.services import free_port, wait_ready

DEFINITION = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
DOMAIN = b'transit.immutable.block.v1\0'


def spec(value):
    return dict(bytes=len(value), digest=list(hashlib.sha256(DOMAIN + value).digest()))


def run(node):
    node = str(Path(node).resolve())
    with Fixture() as store, ColdStore() as cold:
        key = Key(store.root, 'root', 71)
        port = free_port()
        fault = dict(reply=False, block=False, block_fault=None, writes=0, reply_hits=0, corrupt_hits=0, missing_hits=0, barrier_timed_out=False)
        entered, released = threading.Event(), threading.Event()

        class Peer(BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.1'
            def setup(self):
                super().setup()
                self.connection.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            def log_message(self, *_): pass
            def do_GET(self): self.forward()
            def do_HEAD(self): self.forward()
            def do_POST(self): self.forward()
            def do_PUT(self): self.forward()
            def do_DELETE(self): self.forward()
            def forward(self):
                body = self.rfile.read(int(self.headers.get('Content-Length', 0)))
                upstream = cold.port if self.server.provider else port
                connection = HTTPConnection('127.0.0.1', upstream, timeout=15)
                try:
                    connection.request(self.command, self.path, body, dict(self.headers))
                    response = connection.getresponse()
                    data = response.read()
                    status = response.status
                    if self.server.provider:
                        if self.command in ('POST', 'PUT', 'DELETE'):
                            fault['writes'] += 1
                        if self.command == 'GET' and data.startswith(b'TNAT\x01b'):
                            if fault['block']:
                                fault['block'] = False
                                entered.set()
                                if not released.wait(8):
                                    fault['barrier_timed_out'] = True
                                    raise AssertionError('block read barrier timed out')
                            if fault['block_fault'] == 'corrupt':
                                fault['corrupt_hits'] += 1
                                data = data[:-1] + bytes([data[-1] ^ 1])
                            elif fault['block_fault'] == 'missing':
                                fault['missing_hits'] += 1
                                status, data = 404, b''
                    elif fault['reply'] and self.path == '/v1/command' and status == 200:
                        command = json.loads(body)['request']['command']
                        if 'turn' in command or 'turn_with_versions' in command:
                            fault['reply'] = False
                            fault['reply_hits'] += 1
                            self.close_connection = True
                            return
                    self.send_response(status)
                    for name, value in response.getheaders():
                        if name.lower() not in ('connection', 'content-length', 'transfer-encoding'):
                            self.send_header(name, value)
                    self.send_header('Content-Length', response.getheader('Content-Length') if self.command == 'HEAD' else str(len(data)))
                    self.end_headers()
                    if data: self.wfile.write(data)
                except (RemoteDisconnected, BrokenPipeError, ConnectionResetError):
                    self.close_connection = True
                finally:
                    connection.close()

        peers = []
        for provider in (True, False):
            peer = ThreadingHTTPServer(('127.0.0.1', 0), Peer)
            peer.provider = provider
            thread = threading.Thread(target=peer.serve_forever, daemon=True)
            thread.start()
            peers.append((peer, thread))
        config = store.root / 'node.json'
        options = cold.native_config()
        options['endpoint'] = f'http://127.0.0.1:{peers[0][0].server_port}'
        config.write_text(json.dumps(dict(profile='native_v1', genesis=dict(realm=42, root_key=key.public, max_clock_error_ms=10000), local_directory=str(store.native_directory), storage=dict(object_storage=options), port=port, resident_pages=1, request_timeout_ms=10000)))
        log = (store.root / 'node.log').open('w+')
        authority = None
        sequence = 0

        def request(envelope, path=None):
            path = path or ('/v1/command' if 'request' in envelope else '/v1/blocks')
            connection = HTTPConnection('127.0.0.1', peers[1][0].server_port, timeout=15)
            try:
                connection.request('POST', path, compact(envelope), {'Content-Type': 'application/json'})
                response = connection.getresponse()
                return response.status, json.loads(response.read())
            finally:
                connection.close()

        def signed(command):
            nonlocal sequence
            sequence += 1
            value = dict(version=1, definition=DEFINITION, realm=42, principal=0, sequence=sequence, command=command)
            return dict(request=value, signature=key.sign(hashlib.sha256(b'transit.request.v1\0' + compact(value)).digest()))

        def command(value):
            envelope = signed(value)
            result = request(envelope)
            assert result[0] == 200, result
            return result[1]['position']

        def query(source):
            value = dict(version=1, definition=DEFINITION, realm=42, principal=0, kind=dict(block_entries=dict(source=source, keys=[b'a'.hex(), b'b'.hex()] + [None]*6, after=None)))
            return dict(query=value, signature=key.sign(hashlib.sha256(b'transit.query.v1\0' + compact(value)).digest()))

        def read(envelope, expected):
            status, result = request(envelope)
            assert status == 200, (status, result)
            assert result['response']['definition'] == DEFINITION and result['response']['realm'] == 42
            raw = base64.b64decode(result['blocks'], validate=True)
            assert base64.b64encode(raw).decode() == result['blocks']
            assert raw == b''.join(value for value in expected if value is not None)
            entries = result['response']['body']['block_entries']['entries']
            for entry, value in zip(entries, expected):
                if value is None: assert entry is None
                else: assert entry['value'] == spec(value)
            assert all(entry is None for entry in entries[len(expected):])

        def start():
            child = subprocess.Popen([node, str(config)], stdout=log, stderr=log)
            wait_ready(store.http, child, f'http://127.0.0.1:{port}/health')
            return child

        def drain():
            until = time.monotonic() + 120
            while True:
                value = dict(version=1, definition=DEFINITION, realm=42, principal=0, kind=dict(storage={}))
                signed_read = dict(query=value, signature=key.sign(hashlib.sha256(b'transit.query.v1\0' + compact(value)).digest()))
                status, observation = request(signed_read, '/v1/query')
                assert status == 200, observation
                tier = observation['body']['storage']['object_tier']
                if tier['pending_objects'] == 0:
                    assert tier['pending_upload_bytes'] == 0 and not tier['recovery_required']
                    return
                assert time.monotonic() < until, tier
                time.sleep(.05)

        def cold_restart():
            nonlocal authority
            drain()
            authority.kill(); authority.wait(timeout=10); authority = None
            authority = start()  # DiskCache reopen deliberately purges disposable bytes.

        def turn(input_id, view, revision, mutations):
            return dict(pid=pid, generation=2, input=input_id, expected_revision=revision, permit=None, views=[view, None, None, None], current_views=[None]*4, write_view=view, mutations=[dict(key=b'head'.hex(), value=b'published'.hex())]+[None]*3, blocks=mutations, outputs=[dict(pid=pid, value=b'output'.hex())]+[None]*3, effect=None, failed=False, authorization=None)

        try:
            subprocess.run([node, str(config), '--initialize'], check=True, timeout=30, stdout=log, stderr=log)
            authority = start()
            pid = command(dict(spawn=dict(allow_collection=False, code=1, work_before_ms=None, settle_before_ms=None)))
            resource = command(dict(create_resource=dict(writer=pid, owned=False, deadline_ms=None, history_ms=None)))
            command(dict(grant_resource=dict(resource=resource, subject=0, permissions=7)))
            command(dict(associate=dict(pid=pid, name=b'data'.hex(), expected_revision=0, resource=resource, required=False)))
            command(dict(own=dict(pid=pid, expected_generation=1, worker=0)))
            input_id = command(dict(send=dict(pid=pid, value='', role=None)))
            view = command(dict(open_view=dict(pid=pid, generation=2, input=input_id, expected_revision=0, resource=resource, revision=resource, deadline_ms=int(time.time()*1000)+30000)))
            first, second = bytes(range(256))*256, b'\xe7'*65536
            mutations = [dict(key=b'a'.hex(), value=spec(first)), dict(key=b'b'.hex(), value=spec(second))] + [dict(key=bytes([i]).hex(), value=spec(b'')) for i in range(1, 15)]
            pending = signed(dict(turn=turn(input_id, view, 0, mutations)))
            pending['blocks'] = base64.b64encode(first+second).decode()
            inventory = sorted((store.native_directory / 'keys').iterdir())
            corrupt = dict(pending, blocks=base64.b64encode(b'\xff'+first[1:]+second).decode())
            rejected = request(corrupt)
            assert rejected[0] == 422 and rejected[1]['err'] == 'InvalidBlockBody', rejected
            missing = request({name: value for name, value in pending.items() if name != 'blocks'})
            assert missing[0] == 422 and missing[1]['err'] == 'InvalidBlockBody', missing
            assert sorted((store.native_directory / 'keys').iterdir()) == inventory, 'invalid bytes reached native storage'
            fault['reply'] = True
            try:
                request(pending)
                raise AssertionError('accepted reply was not lost')
            except RemoteDisconnected:
                pass
            assert fault['reply_hits'] == 1
            authority.kill(); authority.wait(timeout=10); authority = None
            authority = start()
            inventory = sorted((store.native_directory / 'keys').iterdir())
            identity = {name: value for name, value in pending.items() if name != 'blocks'}
            status, receipt = request(identity)
            assert status == 200 and receipt['position'] == 8, (status, receipt)
            assert sorted((store.native_directory / 'keys').iterdir()) == inventory, 'exact retry restaged data'
            read(query(dict(resource=dict(id=resource, revision=8))), [first, second])
            input_id = command(dict(send=dict(pid=pid, value='', role=None)))
            view = command(dict(open_view=dict(pid=pid, generation=2, input=input_id, expected_revision=8, resource=resource, revision=8, deadline_ms=int(time.time()*1000)+30000)))
            mutations = [dict(key=b'a'.hex(), value=None), dict(key=b'b'.hex(), value=spec(b'new'))] + [None]*14
            newer = signed(dict(turn_with_versions=dict(turn=turn(input_id, view, 8, mutations), reads=[None]*4, retain=[view, None, None, None], release=[None]*4)))
            newer['blocks'] = base64.b64encode(b'new').decode()
            status, receipt = request(newer)
            assert status == 200, (status, receipt)
            read(query(dict(resource=dict(id=resource, revision=receipt['position']))), [None, b'new'])
            retained = query(dict(version=dict(id=dict(pid=pid, input=input_id, index=0), generation=2)))
            read(retained, [first, second])
            for mode in ('corrupt', 'missing'):
                cold_restart()
                fault['block_fault'] = mode
                status, result = request(retained)
                assert status != 200 and 'blocks' not in result, (status, result)
                assert fault[mode + '_hits'] > 0, fault
                fault['block_fault'] = None
            cold_restart()
            fault['block_fault'] = None
            fault['block'] = True
            with ThreadPoolExecutor(max_workers=1) as pool:
                blocked = pool.submit(request, retained)
                try:
                    assert entered.wait(5), 'read did not reach immutable bytes'
                    command(dict(grant_resource=dict(resource=resource, subject=0, permissions=0)))
                    assert not fault['barrier_timed_out'] and not blocked.done(), 'revoke did not complete while provider read was held'
                finally:
                    released.set()
                status, result = blocked.result(timeout=12)
                assert status == 403 and 'blocks' not in result, (status, result)
                assert not fault['barrier_timed_out'], 'provider timeout cannot prove revocation'
            assert request(identity)[0] != 200, 'receipt bypassed current rights'
            command(dict(grant_resource=dict(resource=resource, subject=0, permissions=7)))
            authority.kill(); authority.wait(timeout=10); authority = None
            authority = start()
            read(retained, [first, second])
        except BaseException:
            log.flush(); log.seek(0)
            sys.stderr.write(log.read()[-10000:])
            raise
        finally:
            released.set()
            if authority is not None:
                authority.kill(); authority.wait(timeout=10)
            for peer, thread in peers:
                peer.shutdown(); peer.server_close(); thread.join(timeout=5)
            log.close()
    print('Native blocks: 16 records/128 KiB, lost accepted reply, exact retry without restaging, verified tier eviction, retained bytes, corrupt/missing MinIO reads and revocation during I/O passed across native owner restart.')


if __name__ == '__main__':
    run(*sys.argv[1:])

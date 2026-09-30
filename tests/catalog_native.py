"""Real catalog Table creation, exact receipt recovery and native fencing."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import threading
import time

from storage import Fixture, free_port, wait_ready

ROOT = Path(__file__).resolve().parents[1]


def run(node, proof):
    started = time.monotonic()
    counts = dict(reads=0, turns=0, max_mutations=0, max_value_bytes=0)
    with Fixture() as fixture:
        root = fixture.root
        for name, binary in [('node', node), ('proof', proof)]:
            shutil.copy2(binary, root / name)
        node, proof = str(root / 'node'), str(root / 'proof')
        port = free_port()
        url = f'http://127.0.0.1:{port}'
        public = json.loads(subprocess.check_output([proof, 'public'], timeout=10))
        config = root / 'node.json'
        config.write_text(json.dumps(dict(profile='native_v1',
            genesis=dict(realm=46, root_key=public, max_clock_error_ms=10000),
            ursula_url=fixture.url, bucket='catalog', journal='authority', port=port,
            resident_pages=8, request_timeout_ms=10000)))
        faults = {name: dict(lose=False, body=None, receipt=None, recovered=False) for name in ('send', 'turn')}
        failures = []

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                connection = HTTPConnection('127.0.0.1', port, timeout=15)
                try:
                    envelope = json.loads(body)
                    if self.path == '/v1/query':
                        counts['reads'] += 1
                    connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == '/v1/command' and response.status == 200:
                        command = envelope['request']['command']
                        turn = command.get('turn')
                        if turn:
                            counts['turns'] += 1
                            changes = [x for x in turn['mutations'] if x]
                            counts['max_mutations'] = max(counts['max_mutations'], len(changes))
                            for change in changes:
                                if change['value'] is not None:
                                    counts['max_value_bytes'] = max(counts['max_value_bytes'], len(bytes.fromhex(change['value'])))
                        for name, fault in faults.items():
                            if body == fault['body']:
                                assert data == fault['receipt'], 'Exact native retry changed its receipt'
                                fault['recovered'] = True
                            if fault['lose'] and name in command:
                                fault.update(lose=False, body=body, receipt=data)
                                data = b'{"position":0}'
                    self.send_response(response.status)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                except BaseException as error:
                    failures.append(repr(error))
                    raise
                finally:
                    connection.close()

        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        proxy_url = f'http://127.0.0.1:{proxy.server_port}'
        log = (root / 'node.log').open('w+')
        authority = None

        def start():
            nonlocal authority
            authority = subprocess.Popen([node, str(config)], env=fixture.env, stdout=log, stderr=subprocess.STDOUT)
            wait_ready(fixture.http, authority, url + '/health')

        def restart():
            nonlocal authority
            authority.kill()
            authority.wait(timeout=10)
            authority = None
            fixture.stop()
            fixture.start()
            start()

        def invoke(mode, *args, error=None):
            result = subprocess.run([proof, proxy_url, mode, str(root), *map(str, args)], capture_output=True, text=True, timeout=60)
            if error:
                assert result.returncode != 0 and error in result.stderr, (mode, error, result.stdout, result.stderr)
                return None
            assert result.returncode == 0, (mode, result.stderr)
            return json.loads(result.stdout)

        def absent():
            snapshot = invoke('snapshot')
            assert snapshot['entries'] == [None] * 4, snapshot
            return snapshot

        maximum = 2**64 - 1
        statement = 'CREATE TABLE items (id INT64 NOT NULL,value UTF8 NULL)'
        try:
            subprocess.run([node, str(config), '--initialize'], env=fixture.env, check=True, capture_output=True, timeout=30)
            start()
            provision = invoke('provision')
            invoke('prepare-send', maximum, maximum, 9, statement)
            frozen_send = (root / 'send.json').read_bytes()
            frozen_prepared = (root / 'prepared.json').read_bytes()
            faults['send']['lose'] = True
            invoke('submit-send', error='InvalidAuthorityResponse')
            assert faults['send']['receipt'] is not None
            restart()
            admitted = invoke('submit-send')
            assert admitted == json.loads(faults['send']['receipt']) and faults['send']['recovered']
            assert (root / 'send.json').read_bytes() == frozen_send
            assert (root / 'prepared.json').read_bytes() == frozen_prepared
            assert invoke('observe', admitted['position']) == 'pending'
            assert invoke('status') is None
            before = absent()
            prepared = invoke('prepare-commit')
            assert prepared['mutations'] == 4 and absent() == before
            frozen_commit = (root / 'commit.json').read_bytes()
            faults['turn']['lose'] = True
            invoke('commit', error='InvalidAuthorityResponse')
            after = invoke('snapshot')
            entries = after['entries']
            assert all(entries) and len({e['revision'] for e in entries}) == 1
            assert entries[0]['revision'] == after['resource_revision']
            # Independent bytes for all four atomically visible records.
            definition = bytes.fromhex(json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition'])
            scope = struct.pack('<QQQ', 46, provision['writer']['resource'], maximum)
            schema = b'TBL1\3\2id\5value'
            body = scope + struct.pack('<QQI', maximum, maximum, 9) + b'\5items' + bytes([len(schema)]) + schema
            immutable = (b'TCA1d' + definition + scope + struct.pack('<QQ', maximum, 1) + b'\5items\1'
                         + struct.pack('<I', 9) + bytes([len(schema)]) + schema
                         + struct.pack('<QQQ', 1234, maximum, prepared['input']))
            binding = (b'TCA1n' + definition + scope + struct.pack('<QQ', maximum, 1)
                       + hashlib.sha256(b'transit.catalog.definition.v1\0' + immutable).digest())
            receipt = b'TCA1o' + definition + body + struct.pack('<QQB', 1234, prepared['input'], 1)
            assert [bytes.fromhex(e['value']) for e in entries] == [schema, immutable, binding, receipt]
            assert invoke('progress')['pending'] is None
            original_status = invoke('status')
            assert original_status['outcome'] == 'applied'
            assert original_status['request']['operation'] == maximum
            assert original_status['input'] == prepared['input']
            assert invoke('observe', admitted['position']) == 'processed'
            restart()
            recovered = invoke('commit')
            assert recovered == json.loads(faults['turn']['receipt']) and faults['turn']['recovered']
            assert (root / 'commit.json').read_bytes() == frozen_commit and invoke('snapshot') == after
            assert invoke('status') == original_status
            invoke('changed-retry', error='ConflictingRetry')
            invoke('prepare-send', maximum, maximum, 9, statement)
            invoke('submit-send')
            assert invoke('prepare-commit')['mutations'] == 0
            invoke('commit')
            assert invoke('snapshot') == after
            assert invoke('status') == original_status
            invoke('prepare-send', maximum, 1, 10, statement, error='CatalogIdentityConflict')
            # Name conflict is one durable receipt, with no new object or Table.
            invoke('prepare-send', 1, 1, 10, statement)
            invoke('submit-send')
            assert invoke('prepare-commit')['mutations'] == 1
            invoke('commit')
            conflict = invoke('snapshot')['entries']
            assert conflict[:2] == [None, None] and conflict[2] == entries[2]
            assert bytes.fromhex(conflict[3]['value'])[-1] == 2
            assert invoke('status')['outcome'] == 'name_conflict'
            # A frozen but unaccepted creation loses authority on replacement.
            invoke('prepare-send', 2, 2, 10, statement.replace('items', 'other'))
            invoke('submit-send')
            assert invoke('prepare-commit')['mutations'] == 4
            before = absent()
            invoke('reown')
            invoke('commit', error='StaleGeneration')
            assert absent() == before
            assert invoke('prepare-commit')['mutations'] == 4
            frozen = (root / 'commit.json').read_bytes()
            invoke('revoke-writer')
            invoke('commit', error='AccessDenied')
            assert absent() == before
            invoke('restore-writer')
            invoke('commit')
            assert (root / 'commit.json').read_bytes() == frozen
            assert all(invoke('snapshot')['entries'])
            # Current application inspection policy gates old receipts independently
            # of create rights and the caller's native resource read permission.
            invoke('policy', 2, 'true', 'false')
            invoke('status', error='CatalogDenied')
            assert all(invoke('snapshot')['entries'])
            invoke('policy', 3, 'false', 'true')
            assert invoke('status')['outcome'] == 'applied'
            invoke('prepare-send', 3, 3, 11, statement.replace('items', 'denied'), error='CatalogDenied')
            invoke('policy', 4, 'true', 'true')
            invoke('revoke-reader')
            invoke('snapshot', error='AccessDenied')
            invoke('status', error='AccessDenied')
            assert not failures and all(f['recovered'] for f in faults.values())
            assert counts['max_mutations'] == 4 and counts['max_value_bytes'] <= 256
            report = dict(version=1, revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                          dirty=bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True)),
                          seconds=round(time.monotonic() - started, 3), resident_pages=8, counts=counts,
                          lost_caller_receipts=1, lost_writer_receipts=1,
                          binaries={name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in ('node', 'proof')})
            destination = ROOT / '.cache/verification/catalog/native.json'
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(json.dumps(report, indent=2) + '\n')
            print(json.dumps(report, indent=2))
        finally:
            if authority is not None:
                authority.kill()
                authority.wait(timeout=10)
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=10)
            log.flush()
            log.seek(0)
            if sys.exc_info()[0]:
                sys.stderr.write(log.read()[-12000:])
            log.close()


if __name__ == '__main__':
    run(*sys.argv[1:])

"""Independent signed payload lifecycle against the real local disk node."""
import base64
import hashlib
from http.client import HTTPConnection
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request

from harness.services import free_port, wait_ready
from interfaces.http.serving import Key, compact
from interfaces.installation.server_application_faults import native, post


def run(node, caller):
    root = Path(tempfile.mkdtemp(prefix='transit-local-payload-', dir='/var/tmp'))
    keys = {0: Key(root, 'root', 9), 65536: Key(root, 'publisher', 10),
            65537: Key(root, 'reader', 11), 65538: Key(root, 'maintenance', 12)}
    sequence = {principal: 0 for principal in keys}
    port = free_port()
    config = dict(profile='native_v1', genesis=dict(realm=42, root_key=keys[0].public),
                  local_directory=str(root / 'native'), port=port, resident_pages=1,
                  request_timeout_ms=2000)
    config_path = root / 'node.json'
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    child = None
    log_path = root / 'node.log'

    def query(kind, principal=0):
        return post(port, '/v1/query', native(keys[principal], 42, principal, kind))

    def send(command, principal=0, expected=200):
        request = native(keys[principal], 42, principal, command, sequence[principal] + 1)
        result = post(port, '/v1/command', request, expected=expected)
        if expected == 200:
            sequence[principal] += 1
        return result

    def request(kind, ref, principal=65536, data=None):
        identity = query({'authorization': dict(role=None, kind={'identity': {}})}, principal)
        operation = dict(kind=kind, payload=ref, content=None if data is None else
                         dict(bytes=len(data), sha256=list(hashlib.sha256(data).digest())))
        definition = identity['definition']
        context = hashlib.sha256(b'transit.native.payload.v1\0' + bytes.fromhex(definition) + compact(operation)).digest()
        claim = dict(definition=definition, realm=42, principal=principal,
                     credential_epoch=identity['body']['authorization']['body']['identity']['credential_epoch'],
                     role=None, audience=ref['pid'], context=list(context))
        signature = keys[principal].sign(hashlib.sha256(b'transit.authorization.subject.v1\0' + compact(claim)).digest())
        return dict(operation=operation, proof=dict(claim=claim, signature=signature),
                    body=base64.b64encode(data or b'').decode())

    def payload(kind, ref, principal=65536, data=None, expected=200):
        return post(port, '/v1/payload', request(kind, ref, principal, data), expected=expected)

    def stop():
        nonlocal child
        if child is not None:
            child.kill()
            child.wait(timeout=10)
            child = None

    with log_path.open('w') as log:
        def start(*args):
            nonlocal child
            config_path.write_text(json.dumps(config))
            child = subprocess.Popen([node, str(config_path), *args], stdout=log,
                                     stderr=subprocess.STDOUT, env={**os.environ, 'LOG_FORMAT': 'json'})
            wait_ready(http, child, f'http://127.0.0.1:{port}/health')

        try:
            start('--bootstrap')
            pid = send({'spawn': dict(allow_collection=False, code=1, work_before_ms=None, settle_before_ms=None)})['position']
            for principal, permissions in ((65536, 80), (65537, 16), (65538, 161)):
                send({'create_principal': dict(subject=principal, public_key=keys[principal].public,
                                              permissions=permissions, pid=None if principal == 65538 else pid)})
            data = bytes(range(256)) * 256
            ref = dict(pid=pid, payload=send({'declare_payload': dict(
                pid=pid, sha256=list(hashlib.sha256(data).digest()), bytes=len(data), allow_delete=True)}, 65536)['position'])
            assert payload('verify', ref, expected=503)['err'] == 'AuthorityUnavailable'
            payload('read', ref, expected=422)
            payload('create', ref, 65537, data, expected=403)
            payload('verify', ref, 0, expected=403)  # publisher identity is separate from admin
            payload('create', ref, data=b'incorrect declaration bytes', expected=422)
            forged = request('create', ref, data=data)
            forged['body'] = base64.b64encode(b'x' * len(data)).decode()
            post(port, '/v1/payload', forged, expected=400)
            assert not list((root / 'native').glob('.payload-*')), 'denied/invalid calls created an attempt'

            # Lose the HTTP reply after sending the one allowed creation attempt.
            original = request('create', ref, data=data)
            connection = HTTPConnection('127.0.0.1', port, timeout=4)
            connection.request('POST', '/v1/payload', compact(original), {'Content-Type': 'application/json'})
            connection.getresponse()  # receive headers, deliberately discard the result body
            connection.close()
            marker = root / 'native' / f'.payload-{ref["payload"]:016x}'
            assert marker.exists()
            attempted = marker.read_bytes()
            stop()
            start()
            verified = payload('verify', ref)
            assert verified['outcome'] == 'verified' and verified['payload']['phase'] == 'creating'
            assert post(port, '/v1/payload', original)['outcome'] == 'verify_required'
            assert marker.read_bytes() == attempted
            ready = send({'payload_ready': ref}, 65536)
            read = request('read', ref, 65537)
            response = post(port, '/v1/payload', read)
            assert response['outcome'] == 'read' and base64.b64decode(response['body']) == data
            saved = root / 'payload-read.json'
            saved.write_bytes(compact(read))
            consumed = json.loads(subprocess.check_output([caller, f'http://127.0.0.1:{port}', 'payload', str(saved)], timeout=15))
            assert consumed == response, 'shared Zig client changed the authenticated payload result'
            send({'revoke': 65537})
            post(port, '/v1/payload', read, expected=403)
            # A different PID cannot reuse otherwise valid publisher credentials.
            other = send({'spawn': dict(allow_collection=False, code=1, work_before_ms=None, settle_before_ms=None)})['position']
            payload('read', dict(pid=other, payload=ref['payload']), expected=403)

            # Unlimited retention is independent of a neighboring opted-in payload.
            retained = b'keep without retention opt-in'
            unlimited = dict(pid=pid, payload=send({'declare_payload': dict(
                pid=pid, sha256=list(hashlib.sha256(retained).digest()), bytes=len(retained), allow_delete=False)}, 65536)['position'])
            payload('create', unlimited, data=retained)
            send({'payload_ready': unlimited}, 65536)
            stop()
            start()
            assert base64.b64decode(payload('read', ref)['body']) == data
            # Exact native readiness receipt survives independent byte publication.
            original_ready = native(keys[65536], 42, 65536, {'payload_ready': ref}, 2)
            assert post(port, '/v1/command', original_ready) == ready
            send({'terminate': pid})
            send({'retire_payload': unlimited}, expected=422)
            stop()
            config['maintenance'] = dict(principal=65538, seed_file=str(keys[65538].seed), interval_ms=20,
                                         operation_timeout_ms=2000)
            start()
            deadline = time.monotonic() + 15
            while True:
                observed = query({'inspection': dict(resource='payloads', pid=pid, cut=None, after=0)})['body']['inspection']
                records = {item['id']: item for item in observed['payloads'] if item}
                if records[ref['payload']]['phase'] == 'deleted':
                    break
                assert time.monotonic() < deadline, records
                time.sleep(.025)
            assert records[unlimited['payload']]['phase'] == 'ready'
            assert marker.read_bytes() == attempted, 'deletion removed the permanent attempt fence'
            assert base64.b64decode(payload('read', unlimited)['body']) == retained
            post(port, '/v1/payload', original, expected=422)
            payload('read', ref, expected=422)
        except BaseException:
            print(f'Retained payload failure: {root}', file=sys.stderr)
            print(log_path.read_text()[-6000:], file=sys.stderr)
            raise
        finally:
            stop()
    shutil.rmtree(root)
    print('Local payload service: signed bounded bytes, original verification, restart, current denial and opt-in maintenance deletion passed.')


if __name__ == '__main__':
    run(*(str(Path(value).resolve()) for value in sys.argv[1:]))

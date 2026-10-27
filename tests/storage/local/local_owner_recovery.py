"""Real local node recovery after a durable write loses its sync outcome."""
from http.client import HTTPConnection, HTTPException
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import urllib.request

from harness.services import free_port, wait_ready
from interfaces.http.serving import Key, compact
from interfaces.installation.server_application_faults import native


def run(node):
    # Physical disk is deliberate: tmpfs is not a durable-owner qualification.
    root = Path(tempfile.mkdtemp(prefix='transit-owner-recovery-', dir='/var/tmp'))
    key = Key(root, 'owner', 9)
    port = free_port()
    config = root / 'node.json'
    config.write_text(json.dumps(dict(
        profile='native_v1', genesis=dict(realm=42, root_key=key.public),
        local_directory=str(root / 'native'), port=port, resident_pages=1,
        request_timeout_ms=2000)))
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    child = None
    log_path = root / 'node.log'

    def exchange(path, request):
        connection = HTTPConnection('127.0.0.1', port, timeout=4)
        try:
            connection.request('POST', path, compact(request), {'Content-Type': 'application/json'})
            response = connection.getresponse()
            return response.status, json.loads(response.read())
        finally:
            connection.close()

    def retry(path, request):
        until = time.monotonic() + 15
        while True:
            assert child.poll() is None, 'owner exited before recovery'
            try:
                status, value = exchange(path, request)
                if status == 200:
                    return value
                assert status in (409, 503), (status, value)
            except (OSError, HTTPException):
                pass
            assert time.monotonic() < until, 'original request did not resolve'
            time.sleep(.025)

    with log_path.open('w') as log:
        def start(*args):
            nonlocal child
            child = subprocess.Popen([node, str(config), *args], stdout=log,
                                     stderr=subprocess.STDOUT, env={**os.environ,
                                     'TRANSIT_TEST_OWNER_FAULT': str(root), 'LOG_FORMAT': 'json'})
            wait_ready(http, child, f'http://127.0.0.1:{port}/health')

        try:
            start('--bootstrap')
            process = child.pid
            receipts = []
            pending = None
            for sequence, selection in enumerate((
                    '/native/wal/', '/native/native-allocations/queue/',
                    '/native/wal/', '/native/wal/')):
                pending = native(key, 42, 0, {'create_principal': dict(
                    subject=65536 + sequence, public_key=key.public,
                    permissions=1, pid=None)}, sequence + 1)
                (root / 'pending.json').write_bytes(compact(pending))
                (root / 'arm').write_text(selection)
                try:
                    status, result = exchange('/v1/command', pending)
                    assert status == 503, (status, result)
                except (OSError, HTTPException):
                    pass
                assert int((root / 'fired').read_text()) == sequence + 1
                if sequence == 3:
                    assert child.wait(timeout=15) != 0, 'reopen budget did not stop the owner'
                    child = None
                    assert 'LocalWalReopenBudget' in log_path.read_text()
                    break
                receipt = retry('/v1/command', pending)
                assert child.pid == process, 'test replaced the node instead of reopening its owner'
                assert retry('/v1/command', pending) == receipt, 'exact retry changed its receipt'
                receipts.append(receipt)
                state = retry('/v1/query', native(key, 42, 0, {'identity': {}}))
                assert state['principal_sequence'] == sequence + 1, state
            # An exhausted process preserves its history and pending request.
            start()
            last = retry('/v1/command', pending)
            assert retry('/v1/command', pending) == last
            state = retry('/v1/query', native(key, 42, 0, {'identity': {}}))
            assert state['principal_sequence'] == 4, state
            for sequence, receipt in enumerate(receipts):
                request = native(key, 42, 0, {'create_principal': dict(
                    subject=65536 + sequence, public_key=key.public,
                    permissions=1, pid=None)}, sequence + 1)
                assert retry('/v1/command', request) == receipt
        except BaseException:
            print(f'Retained local owner failure: {root}', file=sys.stderr)
            print(log_path.read_text()[-6000:], file=sys.stderr)
            raise
        finally:
            if child is not None:
                child.kill()
                child.wait(timeout=10)
    import shutil
    shutil.rmtree(root)
    print('Local owner recovery: original receipts, native allocation queue, bounded reopen and restart passed.')


if __name__ == '__main__':
    run(str(Path(sys.argv[1]).resolve()))

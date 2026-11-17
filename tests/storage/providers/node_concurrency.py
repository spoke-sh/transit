"""Concurrent public requests against one exclusive native disk owner.

Physical I/O barriers belong to transit-backend-local/native_test.zig. The
MinIO block service proof separately holds remote bytes across revocation.
"""
from concurrent.futures import ThreadPoolExecutor
from http.client import HTTPConnection
import json
from pathlib import Path
import subprocess
import sys

from harness.native import Fixture
from harness.services import free_port, wait_ready


def run(node, signer):
    node, signer = str(Path(node).resolve()), str(Path(signer).resolve())
    signed = json.loads(subprocess.check_output([signer], timeout=10))
    with Fixture() as fixture:
        port = free_port()
        config = fixture.root / 'node.json'
        config.write_text(json.dumps(dict(profile='native_v1',
            genesis=dict(realm=42, root_key=signed['root_key'], max_clock_error_ms=10000),
            local_directory=str(fixture.native_directory), port=port,
            resident_pages=1, request_timeout_ms=10000)))
        authority = None
        with (fixture.root / 'node.log').open('w+') as log:
            def request(name):
                envelope = signed[name] if isinstance(name, str) else name
                path = '/v1/command' if 'request' in envelope else '/v1/query'
                connection = HTTPConnection('127.0.0.1', port, timeout=12)
                try:
                    connection.request('POST', path, json.dumps(envelope), {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    return response.status, json.loads(response.read())
                finally:
                    connection.close()
            try:
                subprocess.run([node, str(config), '--initialize'], check=True, timeout=30, stdout=log, stderr=log)
                authority = subprocess.Popen([node, str(config)], stdout=log, stderr=log)
                wait_ready(fixture.http, authority, f'http://127.0.0.1:{port}/health')
                for command in signed['setup']:
                    result = request(command)
                    assert result[0] == 200, result
                with ThreadPoolExecutor(max_workers=3) as pool:
                    reads = [pool.submit(request, 'read') for _ in range(2)]
                    written = pool.submit(request, 'write').result(timeout=10)
                    assert written[0] == 200, written
                    assert all(read.result(timeout=10)[0] == 200 for read in reads)
                    assert request('write') == written
                    conflict = request('competing')
                    assert conflict[0] != 200 and conflict[1]['err'] == 'ConflictingRetry', conflict
                    assert request('snapshot')[0] == 200
                    assert request('revoke')[0] == 200
                    assert request('snapshot')[0] == 403
                    left, right = pool.submit(request, 'lost'), pool.submit(request, 'lost')
                    results = [left.result(timeout=10), right.result(timeout=10)]
                    assert results[0] == results[1] and results[0][0] == 200, results
                    assert request('lost') == results[0]
                print('Native concurrency: independent signed requests, exact retry, conflicting retry and current revocation passed.')
            except BaseException:
                log.flush(); log.seek(0)
                sys.stderr.write(log.read()[-12000:])
                raise
            finally:
                if authority is not None:
                    if authority.poll() is None: authority.kill()
                    authority.wait(timeout=10)


if __name__ == '__main__':
    run(*sys.argv[1:])

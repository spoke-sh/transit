"""Real Board over the signed finite-computation fixture's independent reader."""
from http.client import HTTPConnection
from contextlib import closing
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.request
from runner.paths import ROOT
from harness.services import free_port, wait_ready


def exercise(board, root, endpoint, profile, reads, browser=False):
    port = free_port()
    origin = f'http://127.0.0.1:{port}'
    seed = root / 'board-computation-reader.seed'
    seed.write_text('1f' * 32)
    seed.chmod(0o600)
    inspector = root / 'board-computation-inspector.seed'
    inspector.write_text('0c' * 32)
    inspector.chmod(0o600)
    catalog = profile['catalog']
    connection = dict(scope=dict(catalog['scope'], catalog=str(catalog['scope']['catalog'])),
                      branch=str(catalog['branch']), audience=catalog['audience'], principal=102, role=None)
    config = dict(upstream=endpoint, realm=42, principal=104, seed_file=str(inspector),
                  public_origin=origin, port=port, request_timeout_ms=5000, upstream_timeout_ms=1000,
                  workbench=dict(catalog=dict(seed_file=str(seed), connection=connection)))
    path = root / 'board-computations.json'
    path.write_text(json.dumps(config))
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    def request(revision=None, expected=None, status=200, name='managed_projection'):
        body = dict(definition=profile['definition'], namespace=1, name=name, expected=expected, revision=revision)
        deadline = time.monotonic() + 10
        while True:
            with closing(HTTPConnection('127.0.0.1', port, timeout=5)) as client:
                client.request('POST', '/api/v1/computations', json.dumps(body), {'Origin': origin, 'Content-Type': 'application/json'})
                response = client.getresponse()
                value = json.loads(response.read())
            if response.status == 429 and status != 429:
                assert time.monotonic() < deadline
                time.sleep(.15)
                continue
            assert response.status == status, (response.status, value)
            return value
    with (root / 'board-computations.log').open('w+') as log:
        child = subprocess.Popen([str(Path(board).resolve()), str(path)], stdout=log, stderr=subprocess.STDOUT)
        try:
            wait_ready(http, child, origin + '/health')
            current = request()
            assert current['current']['state'] == 'retired', current
            assert current['completed']['revision'] == '5' and current['completed']['rows'] == '4'
            assert current['binding']['name'] == 'managed_projection'
            assert current['source']['name'] == 'managed_input'
            assert current['output']['name'] == 'managed_output'
            expected = current['binding']['interpretation']
            for revision, count in [('1', '3'), ('2', '4'), ('4', '0')]:
                selected = request(revision, expected)
                assert selected['current'] is None
                assert selected['completed']['revision'] == revision and selected['completed']['rows'] == count
                assert selected['completed']['decision']['outcome'] == 'committed'
            assert request('6', expected, 404)['err'] == 'NotFound'
            for invalid in ('0', '-1', '01', '18446744073709551616'):
                assert request(invalid, expected, 400)['err'] == 'InvalidQuery'
            blocked = request(name='managed_budget')
            assert blocked['completed'] is None and blocked['current']['blocked'] == 'budget'
            changed = dict(expected, digest='00'*32)
            assert request(None, changed, 409)['err'] == 'QueryConflict'
            if browser:
                evidence = root / 'computation-evidence.json'
                evidence.write_text(json.dumps(current))
                subprocess.run(['vp', 'exec', '--filter', '@transit/board-web', 'playwright', 'test', 'computations.spec.ts'], cwd=ROOT,
                               env=dict(os.environ, BOARD_TEST_URL=origin, BOARD_COMPUTATION_EVIDENCE=str(evidence)), check=True, timeout=180)
            # Every Table request caused by Board is an observation. In particular
            # there are no result-page reads, pins, SQL submissions or controls.
            allowed = {'managed_inspection', 'describe', 'namespaces', 'list', 'lookup', 'storage', 'node_storage'}
            assert reads and set(reads) <= allowed, reads
            print('Board computations: independent reader, retained nonempty/empty metadata, exact identity, missing revision and read-only requests passed.', flush=True)
        finally:
            if child.poll() is None:
                child.terminate()
            child.wait(timeout=15)

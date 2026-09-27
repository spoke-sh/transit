"""Real v2 Board boundary over the recovered source; inspection stays separate."""
import json
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.request

from storage import free_port, wait_ready


def check(binary, root, kind, invoke, expected, fixture, start, browser=False):
    inspector = invoke('board-provision', direct=True)
    caller = json.loads((root/'shell.json').read_text())
    port = free_port()
    origin = f'http://127.0.0.1:{port}'
    options = dict(upstream=caller['url'], realm=46, principal=55, profile='growing_v3',
                   seed_file=inspector['seed_file'], public_origin=origin, port=port,
                   request_timeout_ms=5000, upstream_timeout_ms=3500,
                   query_v2={k: caller[k] for k in ('connection', 'seed_file', 'workspace')})
    config = root/'board-v2.json'
    config.write_text(json.dumps(options))
    server = start('board-v2', [binary, str(config)])
    wait_ready(fixture.http, server, origin+'/health')

    def request(path, operation=None, status=200, headers=None):
        for attempt in range(12):
            time.sleep(0.12)
            body = None if operation is None else json.dumps(operation).encode()
            req = urllib.request.Request(origin+path, body,
                {'Origin': origin, 'Content-Type': 'application/json'} | (headers or {}))
            try: response = fixture.http.open(req, timeout=10)
            except urllib.error.HTTPError as error: response = error
            with response:
                data = json.loads(response.read())
                if response.status == 429 and status != 429: continue
                read = operation is None or next(iter(operation)) in ('describe', 'status', 'page', 'observe')
                if read and status == 200 and response.status == 409 and data.get('err') == 'QueryExpired': continue
                assert response.status == status, (path, operation and next(iter(operation)), response.status, data)
                assert response.headers['Cache-Control'] == 'no-store'
                return data
        raise AssertionError('Board read did not stabilize')

    def api(operation, **kwargs): return request('/api/v1/query-v2', operation, **kwargs)
    caps = request('/api/v1/capabilities')
    assert caps['read_only'] and caps['query_enabled'] and caps['max_request_bytes'] == 49152
    atlas = request('/api/v1/atlas')
    assert atlas['identity']['permissions'] == 16 and atlas['query_version'] == 2
    assert atlas['query_resource'] == caller['connection']['resource']
    description = api({'describe': {}})['description']
    assert kind in description['source']['source']['source'] and not description['sql']['writes']
    api({'describe': {}}, headers={'Origin': 'https://untrusted.example'}, status=403)
    api({'compile': {'sql': 'DELETE FROM items'}}, status=400)
    api({'submit': {'token': '{}'}}, status=400)
    request('/api/v1/query', {'describe': {}}, status=404)
    assert api({'status': '3'})['status'] is None
    first = api({'page': {'namespace': '1'}})['page']
    assert first['evidence']['next'] and first['cells']
    invoke('revoke', direct=True)
    api({'compile': {'sql': 'SELECT * FROM items'}}, status=403)
    api({'page': {'namespace': '1', 'cursor': first['evidence']['next']}}, status=403)
    assert request('/api/v1/atlas')['identity']['permissions'] == 16
    invoke('restore', direct=True)
    sql = 'SELECT * FROM items LIMIT 33' if kind == 'document' else 'SELECT value FROM items LIMIT 33'
    compiled = api({'compile': {'sql': sql}})['compiled']
    deadline = time.monotonic()+300
    while True:
        prepared = api({'next': {'namespace': '3', 'bundle': compiled['bundle']}})['prepared']
        if prepared is None: break
        receipt = api({'submit': prepared})['receipt']
        assert api({'submit': prepared})['receipt'] == receipt
        while 'pending' in api({'observe': receipt['position']})['observation']:
            assert time.monotonic() < deadline
        assert 'committed' in api({'observe': receipt['position']})['observation']
    while api({'status': '3'})['status']['phase'] != 'complete':
        assert time.monotonic() < deadline
        time.sleep(0.1)
    cursor, rows, pages = None, [], []
    while True:
        page = api({'page': {'namespace': '3', 'cursor': cursor}})['page']
        assert page['evidence']['manifest']['basis']['kind'] == kind
        assert page['evidence']['manifest']['basis']['contract'] == compiled['contract']
        rows += page['cells']; pages.append(page)
        cursor = page['evidence']['next']
        if cursor is None: break
    assert [row[0]['value']['utf8'] for row in rows] == [row['value']['value'] for row in expected[:33]]
    subprocess.run(['node', 'tests/unified_board_client.mjs'],
        input=json.dumps([{'description': description}, {'compiled': compiled}, *[{'page': p} for p in pages]]).encode(),
        check=True, timeout=15)
    if browser:
        marker = root/'board-browser-ready'
        process = start('board-v2-browser', ['vp', 'exec', '--filter', '@rey/transit-board-web',
            'node', 'browser/unified-query.mjs', origin, str(marker), str(caller['connection']['resource']), kind])
        try:
            until = time.monotonic()+240
            while not marker.exists():
                assert process.poll() is None and time.monotonic() < until, 'browser did not reach verified result'
                time.sleep(0.2)
            invoke('revoke', direct=True)
            assert process.wait(timeout=30) == 0
            invoke('restore', direct=True)
        finally:
            if process.poll() is None: process.kill(); process.wait(timeout=10)
    print(f'Unified {kind} Board: separate inspection/query grants, scoped SQL, identical signed retry, '
          f'current prefix denial, nested provenance and generated client passed; browser={browser}.', flush=True)
    server.terminate(); assert server.wait(timeout=10) in (0, -15)

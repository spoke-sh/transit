"""Real v2 Board boundary over the recovered source; inspection stays separate."""
import json
from concurrent.futures import ThreadPoolExecutor
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
    second_port = free_port()
    second_origin = f'http://127.0.0.1:{second_port}'
    second_config = root/'board-v2-second.json'
    second_config.write_text(json.dumps(options | dict(public_origin=second_origin, port=second_port)))
    second = start('board-v2-second', [binary, str(second_config)])
    wait_ready(fixture.http, second, second_origin+'/health')

    def request(path, operation=None, status=200, headers=None, instance=0):
        endpoint = second_origin if instance else origin
        for attempt in range(12):
            time.sleep(0.12)
            body = None if operation is None else json.dumps(operation).encode()
            req = urllib.request.Request(endpoint+path, body,
                {'Origin': endpoint, 'Content-Type': 'application/json'} | (headers or {}))
            try: response = fixture.http.open(req, timeout=10)
            except urllib.error.HTTPError as error: response = error
            with response:
                data = json.loads(response.read())
                if response.status == 429 and status != 429: continue
                if status is None: return response.status, data
                read = operation is None or next(iter(operation)) in ('describe', 'status', 'page', 'observe', 'draft_status')
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
    assisted = api({'assist': {'sql':'SELECT * FROM it','cursor':16,'generation':7}})['assistance']
    assert assisted['version'] == 1 and assisted['generation'] == 7 and assisted['profile'] == 'unified_v2'
    assert assisted['resource'] == caller['connection']['resource']
    assert assisted['range'] == dict(start=14,end=16,quoted=False)
    assert [item['text'] for item in assisted['items']] == ['"items"']
    assert api({'assist': {'sql':'SELECT hidden','cursor':13,'generation':8}})['assistance']['items'] == []
    api({'assist': {'sql':'SELECT','cursor':7,'generation':8}}, status=400)
    suggestions = api({'suggest': {'search': 'count'}})['suggestions']
    assert suggestions['resource'] == caller['connection']['resource']
    assert suggestions['items'][0] == {'label': 'Count', 'sql': 'SELECT COUNT(*) FROM items'}
    assert len(suggestions['items']) <= 8  # Document column names can also contain 'count'.
    api({'compile': {'sql': suggestions['items'][0]['sql']}})
    assert api({'suggest': {'search': 'hidden_source'}})['suggestions']['items'] == []
    assert kind in description['source']['source']['source'] and not description['sql']['writes']
    api({'suggest': {'search': 'x'*129}}, status=400)
    api({'describe': {}}, headers={'Origin': 'https://untrusted.example'}, status=403)
    api({'compile': {'sql': 'DELETE FROM items'}}, status=400)
    api({'submit': {'token': '{}'}}, status=400)
    request('/api/v1/query', {'describe': {}}, status=404)
    assert api({'status': '3'})['status'] is None
    first = api({'page': {'namespace': '1'}})['page']
    assert first['evidence']['next'] and first['cells']
    invoke('revoke', direct=True)
    api({'assist': {'sql':'SE','cursor':2,'generation':9}}, status=403)
    api({'suggest': {'search': ''}}, status=403)
    api({'compile': {'sql': 'SELECT * FROM items'}}, status=403)
    api({'page': {'namespace': '1', 'cursor': first['evidence']['next']}}, status=403)
    assert request('/api/v1/atlas')['identity']['permissions'] == 16
    invoke('restore', direct=True)
    sql = 'SELECT * FROM items LIMIT 33' if kind == 'document' else 'SELECT value FROM items LIMIT 33'
    compiled = api({'compile': {'sql': sql}})['compiled']
    deadline = time.monotonic()+300
    # Independent instances have disposable locks. The native sequence and
    # requester-owned active slot must arbitrate their actual competing work.
    prepared = [api({'next': {'namespace': str(3+i), 'bundle': compiled['bundle']}}, instance=i)['prepared'] for i in range(2)]
    with ThreadPoolExecutor(max_workers=2) as pool:
        admissions = list(pool.map(lambda i: api({'submit': prepared[i]}, instance=i, status=None), range(2)))
    assert sorted(code for code, _ in admissions) == [200, 409], admissions
    winner = next(i for i, (code, _) in enumerate(admissions) if code == 200)
    namespace, refused = str(3+winner), str(4-winner)
    receipt = admissions[winner][1]['receipt']
    with ThreadPoolExecutor(max_workers=2) as pool:
        retries = list(pool.map(lambda i: api({'submit': prepared[winner]}, instance=i)['receipt'], range(2)))
    assert retries == [receipt, receipt]
    while 'pending' in api({'observe': receipt['position']})['observation']:
        assert time.monotonic() < deadline
    contender = api({'next': {'namespace': refused, 'bundle': compiled['bundle']}}, instance=1)['prepared']
    refused_receipt = api({'submit': contender}, instance=1)['receipt']
    while 'pending' in (observed := api({'observe': refused_receipt['position']})['observation']):
        assert time.monotonic() < deadline
    assert bytes.fromhex(observed['rejected']) == b'QueryBusy', observed
    assert api({'status': refused})['status'] is None
    while True:
        prepared = api({'next': {'namespace': namespace, 'bundle': compiled['bundle']}})['prepared']
        if prepared is None: break
        receipt = api({'submit': prepared})['receipt']
        assert api({'submit': prepared})['receipt'] == receipt
        while 'pending' in api({'observe': receipt['position']})['observation']:
            assert time.monotonic() < deadline
        assert 'committed' in api({'observe': receipt['position']})['observation']
    while api({'status': namespace})['status']['phase'] != 'complete':
        assert time.monotonic() < deadline
        time.sleep(0.1)
    cursor, rows, pages = None, [], []
    while True:
        page = api({'page': {'namespace': namespace, 'cursor': cursor}})['page']
        assert page['evidence']['manifest']['basis']['kind'] == kind
        assert page['evidence']['manifest']['basis']['contract'] == compiled['contract']
        rows += page['cells']; pages.append(page)
        cursor = page['evidence']['next']
        if cursor is None: break
    assert [row[0]['value']['utf8'] for row in rows] == [row['value']['value'] for row in expected[:33]]
    subprocess.run(['node', 'tests/unified_board_client.mjs'],
        input=json.dumps([{'description': description}, {'compiled': compiled}, *[{'page': p} for p in pages]]).encode(),
        check=True, timeout=15)
    with ThreadPoolExecutor(max_workers=2) as pool:
        pending_pages = [pool.submit(lambda i: api({'page': {'namespace': namespace}}, instance=i)['page'], i) for i in range(2)]
        rss = 0
        while not all(pending.done() for pending in pending_pages):
            rss = max(rss, sum(int(next(line for line in Path(f'/proc/{child.pid}/status').read_text().splitlines() if line.startswith('VmRSS:')).split()[1])*1024 for child in (server, second)))
            time.sleep(.005)
        concurrent_pages = [pending.result() for pending in pending_pages]
    assert concurrent_pages[0] == concurrent_pages[1] == pages[0]
    assert rss <= 256*1024*1024, ('two Board result readers exceeded declared 256 MiB RSS ceiling', rss)
    print(f'Board concurrent {kind}: competing prepared sequences and durable active quota, identical cross-instance retry, bounded Arrow/escaped JSON readers; two-instance RSS {rss} bytes.', flush=True)
    if kind == 'table':
        draft_started = time.monotonic()
        assert api({'draft_status': None})['draft'] is None

        def settle(prepared):
            receipt = api({'submit': prepared})['receipt']
            # Losing the response does not move the generation or native sequence.
            assert api({'submit': prepared}, instance=1)['receipt'] == receipt
            until = time.monotonic()+120
            while 'pending' in (observed := api({'observe': receipt['position']})['observation']):
                assert time.monotonic() < until
            assert 'committed' in observed, observed

        open_draft = {'draft_open': {'expected': '0', 'limit': 1}}
        settle(api(open_draft)['prepared'])
        draft = api({'draft_status': None})['draft']
        assert draft['generation'] == '1' and draft['starts'] == 0 and draft['enabled']
        draft_bundle = api({'compile': {'sql': 'SELECT value FROM items LIMIT 1'}})['compiled']
        while True:
            prepared = api({'next_draft': {'namespace': '20', 'generation': '1', 'bundle': draft_bundle['bundle']}})['prepared']
            if prepared is None: break
            settle(prepared)
        until = time.monotonic()+120
        while api({'status': '20'})['status']['phase'] != 'complete':
            assert time.monotonic() < until
        result = api({'page': {'namespace': '20'}})['page']
        assert result['evidence']['manifest']['rows'] == '1'
        assert result['evidence']['manifest']['basis']['contract'] == draft['contract']
        consumed = api({'draft_status': '1'})['draft']
        assert consumed['starts'] == 1 and consumed['namespaces'] == ['20'] + ['0']*7
        settle(api(open_draft)['prepared'])
        assert api({'draft_status': '1'})['draft'] == consumed
        api({'next_draft': {'namespace': '21', 'generation': '1', 'bundle': draft_bundle['bundle']}}, status=409)
        assert api({'next_draft': {'namespace': '20', 'generation': '1', 'bundle': draft_bundle['bundle']}})['prepared'] is None
        settle(api({'draft_close': '1'})['prepared'])
        settle(api(open_draft)['prepared'])
        assert not api({'draft_status': '1'})['draft']['enabled']
        settle(api({'draft_open': {'expected': '1', 'limit': 2}})['prepared'])
        assert api({'draft_status': None})['draft']['generation'] == '2'
        invoke('revoke', direct=True)
        api({'next_draft': {'namespace': '21', 'generation': '2', 'bundle': draft_bundle['bundle']}}, status=403)
        invoke('restore', direct=True)
        assert api({'draft_status': '2'})['draft']['starts'] == 0
        settle(api({'draft_close': '2'})['prepared'])
        print(f'Board Table draft budget: atomic finite query, cross-instance exact retries, exhaustion, closed-generation replay and current source denial passed in {time.monotonic()-draft_started:.2f}s.', flush=True)
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
            print((root/'board-v2-browser.log').read_text(), end='', flush=True)
            invoke('restore', direct=True)
        finally:
            if process.poll() is None: process.kill(); process.wait(timeout=10)
    print(f'Unified {kind} Board: separate inspection/query grants, scoped SQL, identical signed retry, '
          f'current prefix denial, nested provenance and generated client passed; browser={browser}.', flush=True)
    server.terminate(); assert server.wait(timeout=10) in (0, -15)
    second.terminate(); assert second.wait(timeout=10) in (0, -15)

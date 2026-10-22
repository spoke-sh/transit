"""Real Board relational route, private origin, current authority and host loss."""
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.request
from storage import free_port, wait_ready


def exercise(board, fixture, url, root, policy, typed, sql, proof, browser):
    port = free_port()
    origin = f'http://127.0.0.1:{port}'
    caller = json.loads((root / 'relational-caller.json').read_text())
    config = dict(upstream=url, realm=46, principal=1240, seed_file=str(root / 'board-inspector.seed'), public_origin=origin, port=port,
        request_timeout_ms=5000, upstream_timeout_ms=1000,
        relational=dict(seed_file=caller['seed_file'], query=caller['query_client']['relational']))
    config['relational']['query']['options']['output_rows'] = '1000'
    path = root / 'relational-board.json'
    log = (root / 'relational-board.log').open('w+')
    child = None
    def start():
        path.write_text(json.dumps(config))
        process = subprocess.Popen([board, str(path)], stdout=log, stderr=subprocess.STDOUT)
        wait_ready(fixture.http, process, origin + '/health')
        return process
    def stop():
        if child is not None and child.poll() is None:
            child.terminate()
            child.wait(timeout=15)
    def request(action, status=200, extra=None):
        headers = {'Origin': origin, 'Content-Type': 'application/json'}
        if extra: headers.update(extra)
        payload = json.dumps(action).encode()
        for attempt in range(6):
            req = urllib.request.Request(origin + '/api/v1/relational', payload, headers)
            try: response = fixture.http.open(req, timeout=10)
            except urllib.error.HTTPError as error: response = error
            with response:
                actual, value = response.status, json.loads(response.read())
            if actual == 429 and attempt < 5:
                time.sleep(.12)
                continue
            assert actual == status, (action, actual, value)
            return value
        raise AssertionError('Board stayed rate-limited')
    try:
        child = start()
        request({'describe': {}}, 403, {'Origin':'http://foreign.invalid'})
        description = request({'describe': {}})['description']
        assert description['active'] is None and len(description['routes']) == 2
        assert description['capabilities']['interactive'] and not description['capabilities']['maintained']
        observed = [dict(description=description)]
        for index, routes, expected in ((201, [0, 0], [[None,1,0,None],[7,6,6,12],[9,1,0,None]]), (202, [0, 1], [[None,1,0,None],[7,2,2,16],[9,1,0,None]])):
            statement = dict(sql=sql, routes=routes)
            proposed = request(dict(query=dict(explain=statement)))['query']['explained']
            opened = request(dict(query=dict(open=dict(id=f'{index:032x}', statement=statement))))['query']['opened']
            assert opened['description'] == proposed and proposed['plan'] == typed(routes)['plan']
            reference = opened['reference']
            recovered = request({'describe': {}})['description']['active']
            assert recovered['opened'] == opened and recovered['ordinal'] == '0' and not recovered['read']
            rows = []
            for ordinal in range(4):
                query = dict(page=dict(reference=reference, ordinal=str(ordinal)))
                page = request(dict(query=query))['query']['page']
                assert request(dict(query=query))['query']['page'] == page
                observed.append(dict(query=dict(page=page)))
                if page['complete_coverage']:
                    assert ordinal == 3 and page['row'] is None
                else:
                    rows.append([None if 'null' in c else int(next(iter(c['value']['atom'].values()))) for c in page['row']['cells']])
            assert rows == expected
            recovered = request({'describe': {}})['description']['active']
            assert recovered['read'] and recovered['ordinal'] == '3'
            observed.extend([dict(query=dict(explained=proposed)), dict(query=dict(opened=opened))])
            request(dict(query=dict(close=reference)))
            request(dict(query=dict(close=reference)))
        reference = request(dict(query=dict(open=dict(id=f'{203:032x}', statement=dict(sql=sql, routes=[0,1])))))['query']['opened']['reference']
        request(dict(query=dict(page=dict(reference=reference, ordinal='0'))))
        policy(False)
        denied = request(dict(query=dict(page=dict(reference=reference, ordinal='0'))), 403)
        assert denied['diagnostic']['category'] == 'access'
        request({'describe': {}}, 403)
        request(dict(query=dict(close=reference)))
        policy(True)
        reference = request(dict(query=dict(open=dict(id=f'{204:032x}', statement=dict(sql=sql, routes=[0,1])))))['query']['opened']['reference']
        stop(); child = start()
        lost = request(dict(query=dict(page=dict(reference=reference, ordinal='0'))), 400)
        assert lost['diagnostic'] is not None
        assert request({'describe': {}})['description']['active'] is None
        subprocess.run(['vp', 'exec', 'node', 'tests/board_relational_client.mjs'], input=json.dumps(observed), text=True, check=True, timeout=30)
        if browser:
            env = os.environ | dict(BOARD_TEST_URL=origin, BOARD_RELATIONAL_PROOF=proof, BOARD_RELATIONAL_AUTHORITY=url, BOARD_RELATIONAL_ROOT=str(root), BOARD_RELATIONAL_SQL=sql)
            subprocess.run(['vp', 'exec', '--filter', '@transit/board-web', 'playwright', 'test', 'relational.spec.ts'], env=env, check=True, timeout=180)
        stop()
        del config['relational']
        child = start()
        assert request({'describe': {}}, 404)['err'] == 'QueryDisabled'
        return dict(layouts=2, rows_per_layout=3, exact_typed_plans=True, repeat_pages=True, current_denial=True, active_inspection=True, host_loss=True, explicit_configuration=True, browser=browser)
    except BaseException:
        log.flush(); log.seek(0)
        print(log.read()[-10000:])
        raise
    finally:
        stop(); log.close()

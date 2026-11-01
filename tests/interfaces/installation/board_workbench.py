"""Installed Board over public catalog callers and shared SQL result readers."""
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import struct
import sys

from runner.paths import ROOT
from interfaces.installation.server_board import Board
from harness.local_installation import freeze_executables
from interfaces.http.serving import compact
from interfaces.installation.server_application_faults import ExistingKey, native, post


def retained_metrics(fixture, definition, connection, seed, operation=900030):
    """Provision through the signed owner, outside Board's read-only boundary."""
    key = ExistingKey(fixture.root, seed)
    port = fixture.config['ports']['node']
    realm, principal = connection['scope']['realm'], connection['principal']
    identity = post(port, '/v1/query', native(key, realm, principal,
        dict(authorization=dict(role=None, kind=dict(identity={})))))['body']['authorization']['body']['identity']

    def call(action):
        body = dict(definition=definition, connection=connection, nonce=[91]*16,
                    action=dict(historical_catalog=action), delegation=None, closure=None,
                    borrow=None, lease=None, transaction=None)
        context = hashlib.sha256(b'transit.table.direct.request.v1\0' + compact(body)).digest()
        claim = dict(definition=definition, realm=realm, principal=principal,
                     credential_epoch=identity['credential_epoch'], role=None,
                     audience=connection['audience'], context=list(context))
        signature = key.sign(hashlib.sha256(b'transit.authorization.subject.v1\0' + compact(claim)).digest())
        return post(port, '/table/v1', dict(body, proof=dict(claim=claim, signature=signature)))['result']['historical_catalog']

    owner = dict(scope=connection['scope'], principal=principal, operation=operation)
    selection = call(dict(select=dict(selection=dict(owner=owner, branch=connection['branch'], directory=None),
        namespace=1, name=dict(len=7, bytes=list(b'metrics')+[0]*56))))['selection']
    token = dict(definition=definition, connection=connection, account=[91]*32, token=list(operation.to_bytes(16, 'little')))
    intent = dict(connection=connection, namespace=1, operation=owner['operation'],
                  selection=selection['directory'], common=None)
    # Save the exact acquisition before dispatch; every subsequent call addresses
    # this identity. The test never reacquires a moving head after uncertainty.
    (fixture.root / f'history-intent-{operation}.json').write_text(json.dumps(dict(key=token, intent=intent)))
    status = call(dict(acquire=dict(key=token, intent=intent,
        budget=dict(limits=dict(operations=1000000, bytes=4294967296, pending=1024), bytes=4608))))['status']
    for _ in range(32):
        if status['state']['phase'] == 'published':
            break
        assert status['state']['phase'] in ('acquiring', 'verifying'), status
        status = call(dict(advance=token))['status']
    else:
        raise AssertionError('Retained source did not publish within its bounded schedule')
    snapshot = status['state']['snapshot']
    content, sources = snapshot['catalog_root'], snapshot['sources_root']
    position = snapshot['consistency']['single_partition']
    scope = owner['scope']
    selector = (b'THSNAP01' + bytes.fromhex(definition)
        + struct.pack('<6Q', scope['realm'], scope['resource'], scope['catalog'], principal, owner['operation'], connection['branch'])
        + struct.pack('<Q', content['bytes']) + bytes(content['sha256'])
        + struct.pack('<Q', sources['bytes']) + bytes(sources['sha256'])
        + struct.pack('<QBQQ', 1, 1, position['partition'], position['next_lsn']) + bytes(104)).hex()

    def release():
        status = call(dict(release=token))['status']
        for _ in range(32):
            if status['state']['phase'] == 'released':
                return
            status = call(dict(advance=token))['status']
        raise AssertionError('Retained source did not release within its bounded schedule')
    return selector, release


def run(cli, node, host, board, gateway=None, browser=False, *, embedded=False):
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    fixture = Board(cli, node, host, board)
    if embedded:
        # The copied release executable owns every runtime role and frontend
        # asset. No sibling executable, source asset or developer PATH is used.
        fixture.config['executables'] = {}
    else:
        fixture.config['executables']['sql_gateway'] = str(Path(gateway).resolve())
        freeze_executables(fixture)
    config_file = fixture.root / 'workbench.json'
    config_file.write_text('{}')
    fixture.config['board']['workbench_file'] = str(config_file)
    fixture.path.write_text(json.dumps(fixture.config))
    success = False
    print(f'Installed Board workbench proof: {fixture.root}', flush=True)
    try:
        fixture.start()
        fixture.ready()
        # Explicit proof-only configuration of a strong SQL account. The Board
        # read gate must refuse writes even though this account can perform them.
        sql = fixture.console_config()
        sql['request_timeout_ms'] = 2000
        account_dir = fixture.installation / 'sql/accounts' / sql['account']
        account = json.loads((account_dir / 'account.json').read_text())
        node_config = json.loads((fixture.installation / 'node.json').read_text())
        catalog = node_config['table']['catalog']
        connection = dict(scope=dict(catalog['scope'], catalog=str(catalog['scope']['catalog'])),
                          branch=str(catalog['branch']), audience=catalog['audience'],
                          principal=account['principals']['table'], role=None)
        config_file.write_text(json.dumps(dict(sql=sql, catalog=dict(
            seed_file=str(account_dir / 'table.seed'), connection=connection))))
        fixture.console('CREATE TABLE metrics (id BIGINT PRIMARY KEY, label UTF8);\n')
        for start in range(0, 145, 16):
            values = ','.join(f"({i},'row {i}')" for i in range(start, min(145, start + 16)))
            fixture.console(f'INSERT INTO metrics VALUES {values};\n')
        fixture.console('CREATE TABLE empty_metrics (id BIGINT);\n')
        for index in range(8):
            fixture.console(f'CREATE TABLE zz_catalog_{index} (id BIGINT);\n')
        fixture.stop()
        fixture.start()
        fixture.ready()
        definition = fixture.record()['definition']
        def request(route, action, expected=200):
            return json.loads(fixture.request('/api/v1/' + route,
                {'Origin': fixture.board_url, 'Content-Type': 'application/json'},
                method='POST', body=json.dumps(dict(definition=definition, action=action)).encode(), expected=expected))
        def run_sql(number, statement, expected=200, binding=None):
            return request('sql-read', dict(run=dict(id=f'{number:032x}', sql=statement, expected_definition=binding)), expected)
        def close(number):
            assert request('sql-read', dict(close=f'{number:032x}')) == {'closed': {}}
        tables = request('catalog', dict(tables=dict(namespace=1, cursor=None)))['catalog']['tables']
        entries = [item for item in tables['entries'] if item]
        assert len(entries) == 8 and tables['next'] is not None
        cursor = tables['next']
        pages = 1
        while cursor is not None:
            assert pages < 4, 'Catalog continuation did not terminate'
            rest = request('catalog', dict(tables=dict(namespace=1, cursor=cursor)))['catalog']['tables']
            assert rest['next'] != cursor
            entries.extend(item for item in rest['entries'] if item)
            cursor = rest['next']
            pages += 1
        assert len(entries) == 11, [item['name'] for item in entries]
        assert {item['name'] for item in entries} == {'items', 'metrics', 'empty_metrics', *[f'zz_catalog_{i}' for i in range(8)]}
        entry = next(item for item in entries if item['name'] == 'metrics')
        table = request('catalog', dict(table=dict(namespace=1, name='metrics', expected=entry['interpretation'])))['table']
        assert table['metadata']['row_count'] == '145'
        native_connection = dict(scope=catalog['scope'], branch=catalog['branch'], audience=catalog['audience'],
                                 principal=account['principals']['table'], role=None)
        selector, _ = retained_metrics(fixture, definition, native_connection, account_dir / 'table.seed')
        def history(action, expected=200):
            return request('catalog', dict(history=action), expected)
        namespace = history(dict(namespace=dict(selector=selector, name='public')))['history']['namespace']
        assert namespace['id'] == 1
        retained = history(dict(list=dict(selector=selector, namespace=1, after=None)))['history']['listing']
        assert retained['snapshot']['selector'] == selector and retained['next'] is None
        assert [item['name'] for item in retained['entries']] == ['metrics']
        historical_object = retained['entries'][0]['declaration']['interpretation']['object']['object']
        source = history(dict(source=dict(selector=selector, object=historical_object)))['history']['source']
        assert source['rows'] == '145'
        definitions = history(dict(definitions=dict(selector=selector, object=historical_object, after=None)))['history']['coverage']
        assert definitions['total_rows'] == '145' and definitions['definitions']['rows'] == '145'
        coverage_request = dict(selector=selector, object=historical_object, after=None)
        locations = history(dict(locations=coverage_request))['history']['coverage']
        assert len(locations['locations']) == 8 and locations['next'] is not None
        next_locations = history(dict(locations=dict(coverage_request, after=locations['next'])))['history']['coverage']
        assert len(next_locations['locations']) == 8 and next_locations['next'] != locations['next']
        assert {json.dumps(item['identity'], sort_keys=True) for item in locations['locations']}.isdisjoint(
            json.dumps(item['identity'], sort_keys=True) for item in next_locations['locations'])
        # The Board request contract cannot carry retention controls or row scans.
        for forbidden in ('select', 'acquire', 'advance', 'abandon', 'release', 'scan'):
            history({forbidden: {}}, 400)
        first = run_sql(1, table['preview_sql'], binding=table['expected_definition'])['result']['view']
        assert len(first['rows']) == 100 and first['start'] == '0' and first['delivered'] == '100'
        assert first['complete_rows'] is None and first['stopped'] == 'row_limit'
        prefix = [int(row[0]['value']['atom']['signed']) for row in first['rows']]
        assert len(set(prefix)) == 100
        assert request('sql-read', dict(observe=f'{1:032x}'))['result']['view'] == first
        advanced = request('sql-read', dict(next=dict(id=f'{1:032x}', after='100')))['result']['view']
        assert len(advanced['rows']) == 45 and advanced['complete_rows'] == '145' and advanced['stopped'] == 'complete'
        assert advanced['result'] == first['result'] and advanced['observation'] == first['observation']
        suffix = [int(row[0]['value']['atom']['signed']) for row in advanced['rows']]
        assert sorted(prefix + suffix) == list(range(145))
        assert request('sql-read', dict(next=dict(id=f'{1:032x}', after='100')))['result']['view'] == advanced
        run_sql(1, table['preview_sql'], 409, '{}')
        close(1)
        empty = run_sql(2, 'SELECT * FROM empty_metrics')['result']['view']
        assert empty['rows'] == [] and empty['complete_rows'] == '0' and empty['stopped'] == 'complete'
        assert request('sql-read', dict(observe=f'{2:032x}'))['result']['view'] == empty
        close(2)
        for index, statement in enumerate(('SHOW TABLES', 'DESCRIBE metrics', 'EXPLAIN SELECT * FROM metrics'), 3):
            result = run_sql(index, statement)['result']['view']
            assert result['rows'] and result['observation_kind'] == 'metadata'
            close(index)
        for index, statement in enumerate(('INSERT INTO metrics VALUES (999, NULL)', 'DROP TABLE metrics', 'SET sql.idle_ms = 1', 'SELECT transit_reload_conf()'), 6):
            response = run_sql(index, statement, 400)
            assert response['err'] in ('ReadOnlyStatementRequired', 'UnsupportedQuery'), response
            count = fixture.console('SELECT COUNT(*) FROM metrics;\n')[0]
            assert count['rows'][0][0]['value']['atom']['unsigned'] == '145', count
        assert run_sql(15, table['preview_sql'], 409, '{}')['err'] == 'QueryConflict'
        # Four readers are bounded independently of total dataset cardinality.
        for index in range(10, 14):
            run_sql(index, 'SELECT * FROM empty_metrics')
        assert run_sql(14, 'SHOW TABLES', 429)['err'] == 'ReadWorkspaceCapacity'
        for index in range(10, 14):
            close(index)
        request('sql-read', dict(observe=f'{1:032x}'), 410)
        if browser:
            screenshots = ROOT / '.cache/board-workbench'
            screenshots.mkdir(parents=True, exist_ok=True)
            env = dict(os.environ, BOARD_TEST_URL=fixture.board_url,
                BOARD_SCREENSHOT=str(screenshots / 'workbench.png'), BOARD_HISTORY_SELECTOR=selector)
            subprocess.run(['vp', 'exec', '--filter', '@transit/board-web', 'playwright', 'test',
                'workbench.spec.ts'], cwd=ROOT, env=env, check=True)
        released_selector, release_history = retained_metrics(fixture, definition, native_connection,
                                                              account_dir / 'table.seed', operation=900031)
        release_history()
        assert history(dict(source=dict(selector=released_selector, object=historical_object)), 409)['err'] == 'QueryExpired'
        # A completed buffered result is not a continuing grant. Revoke its SQL
        # principal through the current public owner, then require no disclosure.
        run_sql(20, 'SELECT * FROM empty_metrics')
        fixture.revoke({'revoke': account['principals']['table']})
        assert request('sql-read', dict(observe=f'{20:032x}'), 403)['err'] == 'Forbidden'
        request('catalog', dict(tables=dict(namespace=1, cursor=None)), 403)
        history(dict(source=dict(selector=selector, object=historical_object)), 403)
        history(dict(locations=coverage_request), 403)
        close(20)
        fixture.stop()
        success = True
        print('Board workbench: exact 145-row traversal, empty/metadata results, definition guards, read-only admission, capacity, retained definitions/placement and terminal revocation passed.', flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Workbench evidence retained: {fixture.root}', file=sys.stderr)


def installed(prefix, browser=False):
    binary = Path(prefix).resolve() / 'bin/transit'
    run(binary, binary, binary, binary, browser=browser, embedded=True)


if __name__ == '__main__':
    if sys.argv[1] == '--installed':
        installed(sys.argv[2], browser='--browser' in sys.argv[3:])
    else:
        run(*sys.argv[1:6], browser='--browser' in sys.argv[6:])

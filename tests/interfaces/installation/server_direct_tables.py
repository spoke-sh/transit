"""Installed native SQL uses the direct Table owner and retains bootstrap identity."""
import ctypes
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

from harness.processes import children, command
from interfaces.installation.server import Fixture
from interfaces.cli.table_console import atom, records
from interfaces.installation.server_application_faults import ExistingKey, native, post
from interfaces.http.serving import compact


class LifecycleFixture(Fixture):
    def console(self, text, expected=0):
        # This correctness schedule configures 120-second server commands.
        # Use the same discovery budget in the real CLI; its default 30 seconds
        # can expire before the admission reply, correctly leaving uncertainty.
        # Accepted work has the CLI's separate 270-second settlement budget.
        # Let it report that result instead of killing it after 180 seconds.
        return super().console(text, expected, request_timeout_ms=120000, timeout=300)


def signed_direct(fixture, record, action):
    key = ExistingKey(fixture.root, fixture.installation / 'caller.seed')
    port = fixture.config['ports']['gateway']
    connection = record['default_table']['connection']
    identity = post(port, '/v1/query', native(key, record['realm'], 10,
        dict(authorization=dict(role=None, kind=dict(identity={})))))['body']['authorization']['body']['identity']
    body = dict(definition=record['definition'], connection=connection, nonce=[71]*16,
                action=action, delegation=None, closure=None, borrow=None)
    context = hashlib.sha256(b'transit.table.direct.request.v1\0' + compact(body)).digest()
    claim = dict(definition=record['definition'], realm=record['realm'], principal=10,
                 credential_epoch=identity['credential_epoch'], role=None,
                 audience=connection['audience'], context=list(context))
    signature = key.sign(hashlib.sha256(b'transit.authorization.subject.v1\0' + compact(claim)).digest())
    return port, dict(body, proof=dict(claim=claim, signature=signature))


def gateway_lookup(fixture, record):
    port, request = signed_direct(fixture, record, dict(lookup=dict(namespace=1, name='items')))
    missing_delegation = dict(request)
    del missing_delegation['delegation']
    post(port, '/table/v1', missing_delegation, expected=400)
    result = post(port, '/table/v1', request)
    assert result['result']['lookup']['interpretation']['interpretation']['object']['object'] == 1
    # Ordinary Table reads cannot consume the reserved control lane via a hint.
    post(port, '/table/v1', request, expected=400, headers={'Content-Type': 'application/json', 'x-transit-control': 'table'})


def storage(fixture, record):
    target = record['default_table']['binding']['target']
    port, request = signed_direct(fixture, record, dict(storage=dict(object=target, pending_limit=1024)))
    return post(port, '/table/v1', request)['result']['storage']


def lazy_schema(fixture, record):
    before = storage(fixture, record)
    assert before['pending']['complete'] and before['pending']['rows'] == 1, before
    segments = set((fixture.installation / 'data/native').rglob('*.tseg'))
    assert segments, 'The UPDATE must supply an old physical segment beside the WAL row'
    fixture.console('ALTER TABLE items ADD COLUMN score BIGINT DEFAULT 7;\n'
                    'ALTER TABLE items ALTER COLUMN score SET DEFAULT 9;\n'
                    'ALTER TABLE items RENAME COLUMN score TO metric;\n')
    assert sorted(records(fixture.console('SELECT id, metric FROM items;\n')[-1]), key=lambda row: int(row['id'])) == [
        dict(id='1', metric='7'), dict(id='2', metric='7')]
    assert atom(fixture.console('SELECT COUNT(*) FROM items WHERE metric = 7;\n')[-1], 'unsigned') == '2'
    assert atom(fixture.console('SELECT COUNT(*) FROM items WHERE metric = 9;\n')[-1], 'unsigned') == '0'
    fixture.console('ALTER TABLE items DROP COLUMN metric;\n'
                    'ALTER TABLE items ADD COLUMN metric BIGINT DEFAULT 42;\n')
    assert sorted(records(fixture.console('SELECT id, value, metric FROM items;\n')[-1]), key=lambda row: int(row['id'])) == [
        dict(id='1', value='11', metric='42'), dict(id='2', value='20', metric='42')]
    after = storage(fixture, record)
    assert after['pending'] == before['pending'] and after['live_rows'] == before['live_rows'], (before, after)
    assert set((fixture.installation / 'data/native').rglob('*.tseg')) == segments, 'Compatible ALTER rewrote segments'
    print('Installed SQL lazy schema: mixed WAL/segment values, frozen ADD default, rename/drop/name reuse and unchanged physical coverage passed.', flush=True)


def enable_default_flushing(fixture, record):
    # The earlier SIGKILL/restart recovered these current WAL rows while
    # automatic maintenance was disabled. Remove only the explicit override;
    # runtime defaults must now relocate them without a caller flush command.
    before = storage(fixture, record)
    assert before['pending']['complete'] and before['pending']['rows'] == 1, before
    segments = set((fixture.installation / 'data/native').rglob('*.tseg'))
    fixture.stop(kill=True)
    del fixture.config['storage']
    fixture.path.write_text(json.dumps(fixture.config))
    fixture.start()
    fixture.ready(timeout=300)
    node = json.loads((fixture.installation / 'node.json').read_text())
    assert node['storage']['maintenance']['flush']['enabled'] is True, node['storage']
    assert node['maintenance']['operation_timeout_ms'] == 2000
    started = time.monotonic()
    deadline = started + 60
    while True:
        current = storage(fixture, record)
        assert current['changed_lsn'] == before['changed_lsn'] and current['live_rows'] == 2, current
        if current['pending']['complete'] and current['pending']['rows'] == 0:
            break
        assert time.monotonic() < deadline, current
        time.sleep(.1)
    created = set((fixture.installation / 'data/native').rglob('*.tseg')) - segments
    assert created, 'No segment was created by default maintenance'
    for path in created:
        data = path.read_bytes()
        assert data[:8] == b'TSEG\x01\0\0\0' and data[-4:] == b'TSEG', path.name
        assert hashlib.sha256(data).hexdigest() in path.name, path.name
    assert sorted(records(fixture.console('SELECT id, value, metric FROM items;\n')[-1]), key=lambda row: int(row['id'])) == [
        dict(id='1', value='11', metric='42'), dict(id='2', value='20', metric='42')]
    print(f'Installed SQL default flush: WAL recovery before enablement, accepted segment coverage and unchanged values; convergence after readiness {time.monotonic() - started:.3f}s.', flush=True)


def run(cli, node, host, board, gateway):
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    os.environ['TEST_TRANSIT_BOARD_BINARY'] = str(Path(board).resolve())
    os.environ['TEST_TRANSIT_SQL_GATEWAY_BINARY'] = str(Path(gateway).resolve())
    fixture = LifecycleFixture(cli, node, host)
    fixture.config['sql'].update(command_ms=120000, request_timeout_ms=30000)
    fixture.config['storage'] = dict(maintenance=dict(flush=dict(enabled=False)))
    fixture.path.write_text(json.dumps(fixture.config))
    success = False
    print(f'Direct installed SQL proof: {fixture.root}', flush=True)

    def schemas():
        return {row['schema'] for row in records(fixture.console('SHOW SCHEMAS;\n')[-1])}

    try:
        fixture.start()
        fixture.ready(timeout=300)
        before = fixture.record()
        configuration = json.loads((fixture.installation / 'node.json').read_text())
        assert configuration['table']['catalog']['scope']['resource'] == before['provision'][5]
        assert configuration['table']['registrar']['principal'] == 26
        assert before['table_registrar_receipt'] and before['default_table_complete']
        assert before['default_table']['binding']['target']['object'] == 1
        gateway_lookup(fixture, before)
        for text, cursor, expected, profile in (
            ('SELECT va FROM items', 9, '"value"', 'direct_table_v1'),
            ('.mode table\nSELECT 1; SELECT va FROM items', 31, '"value"', 'direct_table_v1'),
            ('SET query.statement_t', 21, 'query.statement_timeout', 'configuration_v1'),
        ):
            result = fixture.sql_session(dict(assist=dict(text=text, cursor=cursor)))['assistance']
            assert result['profile'] == profile and result['status'] == 'ready', (text, result)
            assert expected in [item['text'] for item in result['items']], (text, result)
            assert result['coverage'] in ('complete', 'limited') and len(result['items']) <= 8
        assert atom(fixture.console('SELECT COUNT(*) FROM items;\n')[-1], 'unsigned') == '0'
        # The old query worker is unrelated to direct Table mutation acceptance.
        source = next(pid for pid in children(fixture.process.pid) if '"unified_source":' in command(pid))
        os.kill(source, signal.SIGSTOP)
        try:
            fixture.console('INSERT INTO items (id, value) VALUES (1, 10), (2, 20);\n')
            pending = storage(fixture, before)
            assert pending['pending']['complete'] and pending['pending']['rows'] == 2, pending
            assert not list((fixture.installation / 'data/native').rglob('*.tseg'))
            assert sorted(records(fixture.console('SELECT id, value FROM items;\n')[-1]), key=lambda row: int(row['id'])) == [
                dict(id='1', value='10'), dict(id='2', value='20')]
            values = fixture.console('UPDATE items SET value = 11 WHERE id = 1;\n'
                                     'SELECT COUNT(*) FROM items;\n')
            assert atom(values[-1], 'unsigned') == '2', values
            lazy_schema(fixture, before)
            try:
                for statement in (
                        'CREATE TABLE IF NOT EXISTS items (ignored TEXT)',
                        'DROP TABLE IF EXISTS absent_name',
                        'CREATE TABLE other (id BIGINT PRIMARY KEY)',
                        'ALTER TABLE other ADD COLUMN label TEXT',
                        'ALTER TABLE other RENAME TO renamed',
                        'DROP TABLE renamed'):
                    print('Direct installed SQL statement:', statement, flush=True)
                    fixture.console(statement + ';\n')
                from interfaces.sql_sessions.local import Client
                peer = Client(fixture.console_config(), before['definition']).open()

                def peer_console(statement, expected=0):
                    # The prepared statement belongs to a separate session.
                    # Renew its existing lease while the CLI waits on its own
                    # operation; an idle session may expire after 30 seconds.
                    with ThreadPoolExecutor(max_workers=1) as pool:
                        result = pool.submit(fixture.console, statement, expected)
                        while True:
                            try:
                                return result.result(timeout=5)
                            except TimeoutError:
                                peer.call('touch')

                try:
                    existing_schemas = schemas()
                    prepared = peer.call(dict(prepare=dict(sql='CREATE SCHEMA application_data')))['described']
                    assert prepared['mutation'] and prepared['schema'] is None and prepared['parameters'] == []
                    assert schemas() == existing_schemas
                    created_schema = peer.execute('CREATE SCHEMA application_data', list(os.urandom(16)))['operation']
                    peer.terminal(created_schema)
                    assert schemas() == existing_schemas | {'application_data'}
                    stale_drop = peer.call(dict(prepare=dict(sql='DROP SCHEMA application_data')))['described']
                    peer_console('ALTER SCHEMA application_data RENAME TO application_archive;\n')
                    peer.call(dict(describe=stale_drop['statement']), error='CatalogDefinitionChanged')
                    assert schemas() == existing_schemas | {'application_archive'}
                    peer_console('DROP SCHEMA application_archive;\nCREATE SCHEMA application_archive;\n')
                    assert schemas() == existing_schemas | {'application_archive'}
                    blocked = peer_console('DROP SCHEMA public;\n', expected=1)
                    completion = json.loads(blocked.stdout)['completion']
                    assert completion['kind'] == 'drop_schema' and completion['outcome'] == 'rejected', completion
                    assert completion['counts'] == dict(matched='0', changed='0'), completion
                    diagnostic = completion['diagnostic']
                    assert diagnostic['code'] == 'schema.drop_restricted' and diagnostic['evidence'] == 'domain_status', diagnostic
                    assert 'dependency' in diagnostic['message'], diagnostic
                    assert diagnostic['identity']['id'] == completion['operation']['id'], completion
                finally:
                    peer.close()
            except subprocess.TimeoutExpired as error:
                print('Timed-out DDL batch stdout:', error.stdout, file=sys.stderr)
                print('Timed-out DDL batch stderr:', error.stderr, file=sys.stderr)
                raise
        finally:
            failure = sys.exception()
            try:
                os.kill(source, signal.SIGCONT)
            except ProcessLookupError:
                # Preserve the SQL failure if a supervisor restart already
                # joined the stopped worker. Unexpected loss still fails.
                if failure is None:
                    raise
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready(timeout=300)
        after = fixture.record()
        for name in ('default_table', 'table_registrar_receipt', 'provision', 'authorization_steps'):
            assert before[name] == after[name], name
        assert 'application_archive' in schemas()
        original_schema = fixture.sql_session(dict(status=dict(operation=created_schema['identity'])))['operation']
        assert original_schema['outcome'] == 'applied' and original_schema['matched'] == original_schema['changed'] == 0
        assert atom(fixture.console('SELECT COUNT(*) FROM items;\n')[-1], 'unsigned') == '2'
        assert atom(fixture.console('SELECT COUNT(*) FROM items WHERE metric = 42;\n')[-1], 'unsigned') == '2'
        enable_default_flushing(fixture, after)
        fixture.console('DELETE FROM items WHERE id = 2;\nDROP TABLE items;\n')
        fixture.stop()
        fixture.start()
        fixture.ready(timeout=300)
        fixture.console('SELECT COUNT(*) FROM items;\n', expected=1)
        fixture.console('CREATE TABLE items (id BIGINT PRIMARY KEY);\nINSERT INTO items (id) VALUES (7);\n')
        assert atom(fixture.console('SELECT COUNT(*) FROM items;\n')[-1], 'unsigned') == '1'
        fixture.stop()
        success = True
        print('Direct installed SQL: default Table, CRUD/DDL and namespace lifecycle while query worker is stopped, inert preparation, stale schema rejection, RESTRICT, conditional outcomes, abrupt restart, no bootstrap recreation and name reuse passed.', flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Failed direct installed SQL evidence retained at {fixture.root}', flush=True)


if __name__ == '__main__':
    run(*sys.argv[1:])

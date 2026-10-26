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

from harness.processes import children, command
from server import Fixture
from table_console import atom, records
from server_application_faults import ExistingKey, native, post
from serving import compact


class LifecycleFixture(Fixture):
    def console(self, text, expected=0):
        # This correctness schedule configures 120-second server commands.
        # Use the same discovery budget in the real CLI; its default 30 seconds
        # can expire before the admission reply, correctly leaving uncertainty.
        # Accepted work has the CLI's separate 270-second settlement budget.
        # Let it report that result instead of killing it after 180 seconds.
        return super().console(text, expected, request_timeout_ms=120000, timeout=300)


def gateway_lookup(fixture, record):
    key = ExistingKey(fixture.root, fixture.installation / 'caller.seed')
    port = fixture.config['ports']['gateway']
    connection = record['default_table']['connection']
    identity = post(port, '/v1/query', native(key, record['realm'], 10,
        dict(authorization=dict(role=None, kind=dict(identity={})))))['body']['authorization']['body']['identity']
    body = dict(definition=record['definition'], connection=connection, nonce=[71]*16,
                action=dict(lookup=dict(namespace=1, name='items')), delegation=None, closure=None, borrow=None)
    context = hashlib.sha256(b'transit.table.direct.request.v1\0' + compact(body)).digest()
    claim = dict(definition=record['definition'], realm=record['realm'], principal=10,
                 credential_epoch=identity['credential_epoch'], role=None,
                 audience=connection['audience'], context=list(context))
    signature = key.sign(hashlib.sha256(b'transit.authorization.subject.v1\0' + compact(claim)).digest())
    request = dict(body, proof=dict(claim=claim, signature=signature))
    missing_delegation = dict(request)
    del missing_delegation['delegation']
    post(port, '/table/v1', missing_delegation, expected=400)
    result = post(port, '/table/v1', request)
    assert result['result']['lookup']['interpretation']['interpretation']['object']['object'] == 1
    # Ordinary Table reads cannot consume the reserved control lane via a hint.
    post(port, '/table/v1', request, expected=400, headers={'Content-Type': 'application/json', 'x-transit-control': 'table'})


def run(cli, node, host, board, gateway):
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    os.environ['TEST_TRANSIT_BOARD_BINARY'] = str(Path(board).resolve())
    os.environ['TEST_TRANSIT_SQL_GATEWAY_BINARY'] = str(Path(gateway).resolve())
    fixture = LifecycleFixture(cli, node, host)
    fixture.config['sql'].update(command_ms=120000, request_timeout_ms=30000)
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
            values = fixture.console('INSERT INTO items (id, value) VALUES (1, 10), (2, 20);\n'
                                     'UPDATE items SET value = 11 WHERE id = 1;\n'
                                     'SELECT COUNT(*) FROM items;\n')
            assert atom(values[-1], 'unsigned') == '2', values
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
                from sql_sessions.local import Client
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
                    assert 'dependency' in blocked.stderr, blocked
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

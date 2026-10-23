"""Installed native SQL uses the direct Table owner and retains bootstrap identity."""
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import sys

from server import Fixture, children, command
from table_console import atom
from server_application_faults import ExistingKey, native, post
from serving import compact


def gateway_lookup(fixture, record):
    key = ExistingKey(fixture.root, fixture.installation / 'caller.seed')
    port = fixture.config['ports']['gateway']
    connection = record['default_table']['connection']
    identity = post(port, '/v1/query', native(key, record['realm'], 10,
        dict(authorization=dict(role=None, kind=dict(identity={})))))['body']['authorization']['body']['identity']
    body = dict(definition=record['definition'], connection=connection, nonce=[71]*16,
                action=dict(lookup=dict(namespace=1, name='items')), delegation=None)
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
    fixture = Fixture(cli, node, host)
    fixture.config['sql'].update(command_ms=120000, request_timeout_ms=30000)
    fixture.path.write_text(json.dumps(fixture.config))
    success = False
    print(f'Direct installed SQL proof: {fixture.root}', flush=True)
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
        assert atom(fixture.console('SELECT COUNT(*) FROM items;\n')[-1], 'unsigned') == '0'
        # The old query worker is unrelated to direct Table mutation acceptance.
        source = next(pid for pid in children(fixture.process.pid) if '"unified_source":' in command(pid))
        os.kill(source, signal.SIGSTOP)
        try:
            values = fixture.console('INSERT INTO items (id, value) VALUES (1, 10), (2, 20);\n'
                                     'UPDATE items SET value = 11 WHERE id = 1;\n'
                                     'SELECT COUNT(*) FROM items;\n')
            assert atom(values[-1], 'unsigned') == '2', values
            fixture.console('CREATE TABLE IF NOT EXISTS items (ignored TEXT);\n'
                            'DROP TABLE IF EXISTS absent_name;\n'
                            'CREATE TABLE other (id BIGINT PRIMARY KEY);\n'
                            'ALTER TABLE other ADD COLUMN label TEXT;\n'
                            'ALTER TABLE other RENAME TO renamed;\n'
                            'DROP TABLE renamed;\n')
        finally:
            os.kill(source, signal.SIGCONT)
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready(timeout=300)
        after = fixture.record()
        for name in ('default_table', 'table_registrar_receipt', 'provision', 'authorization_steps'):
            assert before[name] == after[name], name
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
        print('Direct installed SQL: default Table, CRUD/DDL while query worker is stopped, conditional outcomes, abrupt restart, no bootstrap recreation and name reuse passed.', flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Failed direct installed SQL evidence retained at {fixture.root}', flush=True)


if __name__ == '__main__':
    run(*sys.argv[1:])

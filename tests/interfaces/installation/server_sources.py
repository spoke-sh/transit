"""Installed SOURCE declarations: original SQL outcomes and no HTTP execution."""
import ctypes
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import sys
import threading
import time

from interfaces.installation.server_direct_tables import LifecycleFixture as Fixture
from interfaces.installation.server_application_faults import ExistingKey, native, post
from interfaces.installation.board_workbench import direct_client
from interfaces.http.serving import Key
from interfaces.cli.table_console import records
from interfaces.sql_sessions.local import Client

STREAM = ('CREATE STREAM captures (capture_id UUID NOT NULL, source_sequence UINT64 NOT NULL, '
          'observed_at TIMESTAMPTZ NOT NULL, http_status INTEGER NOT NULL, body_ref BINARY NOT NULL, '
          'body_bytes UINT64 NOT NULL, body_sha256 BINARY NOT NULL)')
SOURCE = ("CREATE SOURCE earthquakes FROM HTTP CONNECTION upstream INTO STREAM captures WITH "
          "(method='GET', path='/feed', poll_interval='1s', request_timeout='1s', response_max_bytes=4096)")


def metadata(fixture, sql):
    return records(fixture.console(sql + ';\n')[-1])


def settle(client, target):
    deadline = time.monotonic() + 180
    while True:
        value = client.call(dict(status=target))['operation']
        if value['phase'] == 'terminal':
            assert value['outcome'] == 'applied', value
            return value
        assert time.monotonic() < deadline, value
        client.call(dict(resume=value['identity']))
        time.sleep(.05)


def reader_proof(fixture, declaration, connection_definition):
    record = fixture.record()
    key = ExistingKey(fixture.root, fixture.installation / 'root.seed')
    port, realm = fixture.config['ports']['node'], record['realm']
    def query(kind):
        return post(port, '/v1/query', native(key, realm, 0, kind), retry_unavailable=True)
    def authority(kind):
        return query(dict(authorization=dict(role=None, kind=kind)))['body']['authorization']
    def command(value):
        sequence = query(dict(capabilities={}))['principal_sequence'] + 1
        saved = native(key, realm, 0, dict(authorization=value), sequence)
        return post(port, '/v1/command', saved, retry_unavailable=True)['position']
    def change(action):
        original = command(dict(begin=dict(expected_revision=authority(dict(identity={}))['revision'], role=None, action=action)))
        deadline = time.monotonic() + 30
        while True:
            current = authority(dict(change=original))['body']['change']
            if current['status'] == 'ready':
                command(dict(publish=original))
                assert authority(dict(change=original))['body']['change']['status'] == 'published'
                return
            assert current['status'] == 'preparing' and time.monotonic() < deadline, current
            command(dict(advance=original))
    reader = Key(fixture.root, 'source-reader', 73)
    name = b'source_reader'.hex()
    change(dict(create_role=dict(name=name, login=True, create_role=False)))
    role = authority(dict(resolve=name))['body']['resolve']['id']
    # Native authorization IDs currently have a 53-bit counter ceiling.
    principal = 9007199254740990
    change(dict(bind_credential=dict(principal=principal, role=role, public_key=reader.public, pid=None)))
    reader_connection = dict(record['default_table']['connection'], principal=principal, role=None)
    direct, identity = direct_client(fixture, record['definition'], reader_connection, reader.seed)
    assert identity['login_role'] == role
    source = dict(kind='domain', id=declaration['properties']['authorization'])
    schema = authority(dict(object=source))['body']['object']['parent']
    database = authority(dict(object=schema))['body']['object']['parent']
    for object_ref in (database, schema):
        change(dict(grant=dict(object=object_ref, grantee=role, privileges=1, grant_options=0)))
    owner, _ = direct_client(fixture, record['definition'], record['default_table']['connection'], fixture.installation / 'caller.seed')
    named = lambda value: dict(len=len(value), bytes=list(value.encode()) + [0]*(63-len(value)))
    source_identity = owner(dict(source=dict(lookup=dict(selection=dict(namespace=1, kind='source'), name=named('earthquakes')))))['source']['metadata']['state']['declaration']['interpretation']
    connection_identity = owner(dict(source=dict(lookup=dict(selection=dict(namespace=1, kind='connection'), name=named('upstream')))))['source']['metadata']['state']['declaration']['interpretation']
    direct(dict(source=dict(inspect=source_identity)), expected=403)
    change(dict(grant=dict(object=source, grantee=role, privileges=1, grant_options=0)))
    observed = direct(dict(source=dict(inspect=source_identity)))['source']['metadata']
    assert observed['definition'] == declaration and observed['execution_supported'] is False
    page = direct(dict(source=dict(list=dict(selection=dict(namespace=1, kind='source'), cursor=None))))['source']['page']
    assert sum(value is not None for value in page['entries']) == 1
    direct(dict(source=dict(inspect=connection_identity)), expected=403)
    change(dict(revoke_privileges=dict(object=source, grantee=role, privileges=1, grant_option_only=False, behavior='restrict')))
    direct(dict(source=dict(inspect=source_identity)), expected=403)
    assert not any(direct(dict(source=dict(list=dict(selection=dict(namespace=1, kind='source'), cursor=None))))['source']['page']['entries'])
    assert json.loads(metadata(fixture, 'SHOW CONNECTION upstream')[0]['definition']) == connection_definition
    client = Client(fixture.console_config(), record['definition']).open()
    try:
        batch = client.execute('SHOW SOURCE earthquakes')['batch']
        assert batch['complete'] and len(batch['rows']) == 1
        replay = dict(fetch=dict(cursor=batch['cursor'], batch=batch['batch']))
        assert client.call(replay)['batch'] == batch
        change(dict(revoke_privileges=dict(object=source, grantee=declaration['owner'], privileges=1, grant_option_only=False, behavior='restrict')))
        try:
            client.call(replay, error='AccessDenied')
        finally:
            change(dict(grant=dict(object=source, grantee=declaration['owner'], privileges=1, grant_options=0)))
        client.call(replay, error='SqlResultIncomplete')
    finally:
        client.close()
    print('Installed SOURCE: independent maximum-range principal, scoped metadata and revocation after SQL buffering passed.', flush=True)


def empty_destination(fixture, definition):
    record = fixture.record()
    direct, _ = direct_client(fixture, record['definition'], record['default_table']['connection'], fixture.installation / 'caller.seed')
    observed = direct(dict(stream=dict(observe=dict(definition=record['definition'], interpretation=definition, partition=0))))['stream']['cut']
    assert observed['next'] == 0 and observed['retained_from'] == 0, observed


def missing_executor(cli, node, host):
    fixture = Fixture(cli, node, host)
    fixture.use_private_runtime()
    success = False
    try:
        fixture.start()
        fixture.ready(timeout=300)
        client = Client(fixture.console_config(), fixture.record()['definition']).open()
        try:
            for sql in (SOURCE, 'EXPLAIN ' + SOURCE):
                refused = client.call(dict(execute=dict(sql=sql, token=list(os.urandom(16)))), error='SourceExecutorNotConfigured')
                assert refused['err'].get('operation') is None, refused
        finally:
            client.close()
        assert metadata(fixture, 'SHOW SOURCES') == []
        success = True
        print('Installed SOURCE: omitted executor rejects CREATE and EXPLAIN before admission.', flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Failed executor evidence retained at {fixture.root}', flush=True)


def run(cli, node, host, board, gateway):
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    os.environ['TEST_TRANSIT_BOARD_BINARY'] = str(Path(board).resolve())
    os.environ['TEST_TRANSIT_SQL_GATEWAY_BINARY'] = str(Path(gateway).resolve())
    fixture = Fixture(cli, node, host)
    fixture.use_private_runtime()
    fixture.config['sql'].update(command_ms=120000, request_timeout_ms=30000)
    fixture.config['sql'].setdefault('native', {})['source_executor'] = 99
    fixture.path.write_text(json.dumps(fixture.config))
    class Peer(BaseHTTPRequestHandler):
        requests = 0
        def parse_request(self):
            parsed = super().parse_request()
            if parsed:
                type(self).requests += 1
            return parsed
        def do_GET(self):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'{}')
        def log_message(self, *_args):
            pass
    peer = ThreadingHTTPServer(('127.0.0.1', 0), Peer)
    worker = threading.Thread(target=peer.serve_forever, daemon=True)
    worker.start()
    success = False
    print(f'Installed SOURCE proof: {fixture.root}', flush=True)
    try:
        fixture.start()
        fixture.ready(timeout=300)
        fixture.console(STREAM + ';\n')
        connection_client = Client(fixture.console_config(), fixture.record()['definition']).open()
        try:
            malformed = connection_client.call(dict(execute=dict(sql="CREATE SOURCE broken FROM HTTP CONNECTION upstream WITH (capture_stream='captures')", token=list(os.urandom(16)))), error='InvalidSqlSyntax')['err']
            assert malformed['sqlstate'] == list(b'42601') and malformed.get('operation') is None, malformed
            created = connection_client.execute(f"CREATE CONNECTION upstream TO HTTP (endpoint='http://127.0.0.1:{peer.server_port}')", token=list(os.urandom(16)))['operation']
            settle(connection_client, dict(operation=created['identity']))
        finally:
            connection_client.close()
        assert len(metadata(fixture, 'SHOW CONNECTIONS')) == 1
        connection = metadata(fixture, 'DESCRIBE CONNECTION upstream')[0]
        assert json.loads(connection['definition'])['payload']['connection']['endpoint'].endswith(str(peer.server_port))
        explained = json.loads(metadata(fixture, 'EXPLAIN ' + SOURCE)[0]['plan'])
        assert explained['executed'] is False and explained['identity'] is None
        assert explained['proposal']['payload']['source']['executor'] == 99
        assert metadata(fixture, 'SHOW SOURCES') == []
        transaction = Client(fixture.console_config(), fixture.record()['definition']).open()
        try:
            begin = transaction.execute('BEGIN', token=list(os.urandom(16)))['operation']
            settle(transaction, dict(operation=begin['identity']))
            transaction.call(dict(execute=dict(sql=SOURCE, token=list(os.urandom(16)))), error='UnsupportedSourceStatement')
            rollback = transaction.execute('ROLLBACK', token=list(os.urandom(16)))['operation']
            settle(transaction, dict(operation=rollback['identity']))
        finally:
            transaction.close()
        client = Client(fixture.console_config(), fixture.record()['definition']).open()
        token = list(os.urandom(16))
        try:
            client.call(dict(execute=dict(sql=SOURCE, token=token)), discard_response=True)
            original = settle(client, dict(token=token))
            assert original['command'] == 'create_source' and original['identity']['kind'] == 'connector'
            assert client.call(dict(execute=dict(sql=SOURCE, token=token)))['operation'] == original
            refused = client.call(dict(execute=dict(sql=SOURCE.replace('earthquakes', 'competing'), token=list(os.urandom(16)))), error='SourceDeclarationConflict')
            assert refused['err'].get('operation') is None, refused
            for control in ('AUTHORIZE', 'ACTIVATE', 'SUSPEND', 'RESUME'):
                refused = client.call(dict(execute=dict(sql=f'{control} SOURCE earthquakes', token=list(os.urandom(16)))), error='SourceExecutionUnsupported')
                assert refused['err'].get('operation') is None, refused
        finally:
            client.close()
        published = metadata(fixture, 'SHOW SOURCE earthquakes')[0]
        assert published['state'] == 'published' and published['epoch'] == '1'
        assert published['execution_supported'] is False and published['execution'] == 'never_run'
        declaration = json.loads(published['definition'])
        assert declaration['payload']['source']['executor'] == 99
        reader_proof(fixture, declaration, json.loads(connection['definition']))
        empty_destination(fixture, declaration['payload']['source']['destination'])
        fixture.console('DROP SOURCE earthquakes;\n', expected=1)
        fixture.console('DROP CONNECTION upstream;\n', expected=1)
        fixture.console('DROP STREAM captures;\n', expected=1)
        fixture.console('SELECT * FROM earthquakes;\n', expected=1)
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready(timeout=300)
        assert json.loads(metadata(fixture, 'DESCRIBE SOURCE earthquakes')[0]['definition']) == declaration
        recovered = Client(fixture.console_config(), fixture.record()['definition']).open()
        try:
            assert recovered.call(dict(status=dict(token=token)))['operation'] == original
            assert recovered.execute(SOURCE, token=token)['operation'] == original
        finally:
            recovered.close()
        fixture.console('RETIRE SOURCE earthquakes;\n')
        retired = metadata(fixture, 'SHOW SOURCE earthquakes')[0]
        assert retired['state'] == 'retired' and retired['epoch'] == '2'
        assert json.loads(retired['definition']) == declaration
        fixture.console('DROP SOURCE earthquakes RESTRICT;\nDROP CONNECTION upstream RESTRICT;\n')
        assert metadata(fixture, 'SHOW SOURCES') == []
        assert metadata(fixture, 'SHOW CONNECTIONS') == []
        fixture.console(f"CREATE CONNECTION upstream TO HTTP (endpoint='http://127.0.0.1:{peer.server_port}');\n" + SOURCE + ';\n')
        replacement = json.loads(metadata(fixture, 'SHOW SOURCE earthquakes')[0]['definition'])
        assert replacement['object'] != declaration['object']
        recovered = Client(fixture.console_config(), fixture.record()['definition']).open()
        try:
            assert recovered.call(dict(status=dict(token=token)))['operation'] == original
            assert recovered.execute(SOURCE, token=token)['operation'] == original
        finally:
            recovered.close()
        fixture.console('RETIRE SOURCE earthquakes;\nDROP SOURCE earthquakes;\nDROP CONNECTION upstream;\n')
        empty_destination(fixture, declaration['payload']['source']['destination'])
        assert Peer.requests == 0, Peer.requests
        fixture.stop()
        missing_executor(cli, node, host)
        success = True
        print('Installed SOURCE: explicit executor, pure EXPLAIN, lost reply, original recovery, restart, retire/drop and zero HTTP requests passed.', flush=True)
    finally:
        fixture.cleanup()
        peer.shutdown()
        peer.server_close()
        worker.join()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f'Failed SOURCE evidence retained at {fixture.root}', flush=True)


if __name__ == '__main__':
    run(*sys.argv[1:])

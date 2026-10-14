"""Original-subject Table service isolation against disk-backed native authority."""
import argparse
import hashlib
from http.client import HTTPConnection
import json
import os
from pathlib import Path
import struct
import subprocess
import time

from inspection import System
from storage import free_port, wait_ready


def canonical(value):
    return json.dumps(value, separators=(',', ':'), ensure_ascii=False).encode()


ROOT = Path(__file__).resolve().parents[1]


def run(node, cli, host, service, report=None):
    started = time.monotonic()
    with System(node, cli, clock_error_ms=10000, request_timeout_ms=30000) as system:
        definition = system.native_query({'capabilities': {}})['definition']
        def query(kind, principal=0, seed=None):
            return system.native_query({'authorization': {'role': None, 'kind': kind}}, principal, seed)['body']['authorization']

        def apply(action):
            change = system.command({'authorization': {'begin': {'expected_revision': query({'identity': {}})['revision'], 'role': None, 'action': action}}})
            for _ in range(10000):
                status = query({'change': change})['body']['change']
                if status['status'] == 'ready':
                    system.command({'authorization': {'publish': change}})
                    return query({'change': change})['body']['change']['created_id']
                assert status['status'] == 'preparing', status
                system.command({'authorization': {'advance': change}})
            raise AssertionError('authorization staging budget exceeded')

        owner_key, owner_public = system.key('owner')
        reader_key, reader_public = system.key('reader')
        worker_key, worker_public = system.key('worker')
        service_key, service_public = system.key('service')
        courier_key, courier_public = system.key('courier')
        owner_role = apply({'create_role': {'name': b'owner'.hex(), 'login': True, 'create_role': False}})
        reader_role = apply({'create_role': {'name': b'reader'.hex(), 'login': True, 'create_role': False}})
        for principal, role, key in ((101, owner_role, owner_public), (104, reader_role, reader_public)):
            apply({'bind_credential': {'principal': principal, 'role': role, 'public_key': key, 'pid': None}})
        pid = system.command({'spawn': {}})
        resource = system.command({'create_resource': {'writer': pid}})
        system.command({'grant_resource': {'resource': resource, 'subject': 0, 'permissions': 7}})
        system.command({'associate': {'pid': pid, 'name': b'state'.hex(), 'resource': resource}})
        for principal, public, permissions, scope in ((20, worker_public, 255, pid), (102, service_public, 16, pid), (103, courier_public, 148, None)):
            system.command({'grant': {'subject': principal, 'public_key': public, 'permissions': permissions, 'pid': scope}})
        for principal, permissions in ((20, 7), (101, 3), (102, 3)):
            system.command({'grant_resource': {'resource': resource, 'subject': principal, 'permissions': permissions}})
        for role in (owner_role, reader_role):
            apply({'grant': {'object': {'kind': 'process', 'id': pid}, 'grantee': role, 'privileges': 20, 'grant_options': 0}})
        generation = system.native_query({'process': pid})['body']['process']['process']['generation']
        system.command({'own': {'pid': pid, 'expected_generation': generation, 'worker': 20}})
        generation += 1
        domains = [apply({'register_domain': {'registrar': 20, 'actions': mask}}) for mask in (1, 3, 15)]
        scope = dict(realm=72, resource=resource, catalog=1)
        def binding(kind, identity):
            return list(hashlib.sha256(b'transit.catalog.authorization.binding.v1\0' + bytes.fromhex(definition) + struct.pack('<QQQBQ', 72, resource, 1, kind, identity)).digest())
        database = apply({'register_object': {'domain': domains[0], 'owner': owner_role, 'schema': None, 'binding': binding(1, 0)}})
        schema = apply({'register_object': {'domain': domains[1], 'owner': owner_role, 'schema': {'kind': 'domain', 'id': database}, 'binding': binding(2, 1)}})
        profile = dict(database_domain=domains[0], schema_domain=domains[1], table_domain=domains[2], database=database, initial_schema=1, initial_schema_authority=schema)
        configuration = dict(scope=scope, owner=pid, administrator=101, table_limits=dict(record_bytes=2097152, staging_bytes=4194304, staging_records=2), authority=profile)
        activation = system.root / 'activation'
        activation.mkdir()
        host_config = system.root / 'catalog.json'
        host_config.write_text(json.dumps(dict(url=system.url, realm=72, principal=20, seed_file=str(worker_key), pid=pid, generation=generation, activation_directory=str(activation), request_timeout_ms=30000, role=dict(catalog=configuration))))
        worker = system.start(host, host_config)
        courier_config = system.root / 'courier.json'
        courier_config.write_text(json.dumps(dict(url=system.url, realm=72, principal=103, seed_file=str(courier_key), request_timeout_ms=30000, role=dict(courier=dict(destinations=[pid])))))
        courier = system.start(host, courier_config)
        # Independent public control encoding; no private record edits.
        control = b'TCA1I' + bytes.fromhex(definition) + struct.pack('<QQQQQIQI', 72, resource, 1, pid, 101, 2097152, 4194304, 2) + struct.pack('<QQQQQQ', *profile.values())
        frame = b'STN1\1' + bytes(8) + control
        system.available_post('/v1/command', system.signed({'send': {'pid': pid, 'value': frame.hex()}}, 1, 101, owner_key))
        port = free_port()
        service_config = system.root / 'service.json'
        service_config.write_text(json.dumps(dict(upstream=system.url, realm=72, principal=102, seed_file=str(service_key), scope=dict(scope, catalog='1'), owner=pid, port=port, upstream_timeout_ms=30000)))
        serving = system.start(service, service_config)
        wait_ready(system.store.http, serving, f'http://127.0.0.1:{port}/health')

        def signed(action, principal=101, key=owner_key):
            connection = dict(scope=dict(scope, catalog='1'), owner=pid, principal=principal, role=None, namespace=1)
            request = dict(definition=definition, connection=connection, nonce=list(os.urandom(16)), action=action)
            epoch = query({'identity': {}}, principal, key)['body']['identity']['credential_epoch']
            claim = dict(definition=definition, realm=72, principal=principal, credential_epoch=epoch, role=None, audience=pid,
                         context=list(hashlib.sha256(b'transit.table.service.request.v1\0' + canonical(request)).digest()))
            digest = hashlib.sha256(b'transit.authorization.subject.v1\0' + canonical(claim)).digest()
            private = system.root / 'signing.der'
            private.write_bytes(bytes.fromhex('302e020100300506032b657004220420') + bytes.fromhex(key.read_text().strip()))
            private.chmod(0o600)
            message = system.root / 'signing.digest'
            message.write_bytes(digest)
            signature = subprocess.check_output(['openssl', 'pkeyutl', '-sign', '-rawin', '-inkey', str(private), '-keyform', 'DER', '-in', str(message)])
            return dict(request, proof=dict(claim=claim, signature=list(signature)))

        class Changed(Exception):
            pass

        def post(request, expected=200):
            connection = HTTPConnection('127.0.0.1', port, timeout=35)
            try:
                connection.request('POST', '/table/v1', canonical(request), {'Content-Type': 'application/json'})
                response = connection.getresponse()
                value = json.loads(response.read())
                if expected == 200 and response.status == 409 and value.get('err') in ('StaleStateResource', 'StaleAuthorizationRevision', 'QueryExpired'):
                    raise Changed()
                if response.status != expected:
                    time.sleep(.3)  # Let bounded diagnostic sinks flush the failing attempt.
                assert response.status == expected, (response.status, value, expected, next(iter(request['action'])))
                return value
            finally:
                connection.close()

        def call(action, principal=101, key=owner_key, expected=200):
            deadline = time.monotonic() + 30
            while True:
                try:
                    return post(signed(action, principal, key), expected)
                except Changed:
                    assert time.monotonic() < deadline, "read acquisition stayed stale"

        deadline = time.monotonic() + 30
        while True:
            assert worker.poll() is None and courier.poll() is None
            result = system.native_query({'process': pid})['body']['process']
            if result['process']['consumed']:
                break
            assert time.monotonic() < deadline
            time.sleep(.02)
        call({'describe': {}})

        def execute(sql, operation, object_id=None):
            saved = call({'compile': dict(identity=dict(operation=str(operation), namespace=str(operation + 1000)), create_object=str(object_id) if object_id else None, sql=sql)})['result']['compiled']['saved']
            deadline = time.monotonic() + 180
            while True:
                assert worker.poll() is None and courier.poll() is None
                sequence = system.native_query({'authorization': {'role': None, 'kind': {'identity': {}}}}, 101, owner_key)['principal_sequence'] + 1
                step = call({'next': dict(saved=saved, sequence=sequence)})['result']['next']
                if 'terminal' in step:
                    assert step['terminal']['phase'] == 'applied', step
                    return
                if 'send' in step:
                    candidate = step['send']['request']
                    assert candidate['principal'] == 101 and candidate['sequence'] == sequence
                    system.available_post('/v1/command', system.signed(candidate['command'], sequence, 101, owner_key))
                else:
                    assert 'running' in step, step
                    time.sleep(.02)
                assert time.monotonic() < deadline, step

        execute('CREATE TABLE readable (id INTEGER PRIMARY KEY, value TEXT)', 1, 100)
        execute('CREATE TABLE private_data (id INTEGER PRIMARY KEY, value TEXT)', 2, 101)
        execute("INSERT INTO readable VALUES (1, 'visible')", 3)
        execute("INSERT INTO private_data VALUES (1, 'never-disclose')", 4)
        readable = call({'lookup': 'readable'})['result']['lookup']['authorization']
        private_object = call({'lookup': 'private_data'})['result']['lookup']['authorization']
        assert readable != private_object
        for object_id in (database, schema):
            apply({'grant': {'object': {'kind': 'domain', 'id': object_id}, 'grantee': reader_role, 'privileges': 1, 'grant_options': 0}})
        grant = apply({'grant': {'object': {'kind': 'domain', 'id': readable}, 'grantee': reader_role, 'privileges': 1, 'grant_options': 0}})
        result = call({'query': dict(sql='SELECT * FROM readable', rows=8, reads=100)}, 104, reader_key)['result']['query']
        assert result['complete'] and 'visible' in json.dumps(result) and 'never-disclose' not in json.dumps(result), result
        entries = call({'list': None}, 104, reader_key)['result']['list']['entries']
        assert [entry['metadata']['name'] for entry in entries if entry] == ['readable'], entries
        assert call({'lookup': 'private_data'}, 104, reader_key)['result']['lookup'] is None
        call({'definition': dict(object='101', revision='1')}, 104, reader_key, 403)
        call({'compile': dict(identity=dict(operation='5', namespace='1005'), create_object=None,
                              sql="INSERT INTO readable VALUES (2, 'denied')")}, 104, reader_key, 403)
        call({'compile': dict(identity=dict(operation='6', namespace='1006'), create_object='102',
                              sql='CREATE TABLE denied (id INTEGER)')}, 104, reader_key, 403)
        call({'query': dict(sql='SELECT * FROM private_data', rows=8, reads=100)}, 104, reader_key, 400)
        revision = system.native_query({'resource': resource})['body']['resource']['revision']
        for raw in ({'resource': resource}, {'read_access': resource}, {'entries': {'resource': resource, 'revision': revision}},
                    {'open_snapshot': {'resource': resource, 'nonce': list(range(16))}},
                    {'read_entries': {'resource': resource, 'keys': ['0000'] + [None] * 7}}):
            assert system.native_query(raw, 104, reader_key, 403)['err'] == 'AccessDenied'
        forged = signed({'lookup': 'readable'}, 104, reader_key)
        forged['action'] = {'lookup': 'private_data'}
        post(forged, 403)
        forged = signed({'lookup': 'readable'}, 104, reader_key)
        forged['connection']['principal'] = 101
        post(forged, 403)
        # A signed proof cannot survive replacement of its credential epoch.
        previous = signed({'lookup': 'readable'}, 104, reader_key)
        replacement_key, replacement_public = system.key('reader-replacement')
        apply({'rotate_credential': {'principal': 104, 'expected_epoch': previous['proof']['claim']['credential_epoch'], 'public_key': replacement_public}})
        post(previous, 403)
        reader_key = replacement_key
        assert call({'lookup': 'readable'}, 104, reader_key)['result']['lookup'] is not None
        # The mediation service carries no durable grants or operation authority.
        serving.kill()
        serving.wait(timeout=10)
        serving = system.start(service, service_config)
        wait_ready(system.store.http, serving, f'http://127.0.0.1:{port}/health')
        assert call({'lookup': 'readable'}, 104, reader_key)['result']['lookup'] is not None
        apply({'revoke': {'id': grant, 'privileges': 1, 'grant_option_only': False, 'behavior': 'cascade'}})
        call({'query': dict(sql='SELECT * FROM readable', rows=8, reads=100)}, 104, reader_key, 400)
        assert not any(call({'list': None}, 104, reader_key)['result']['list']['entries'])
        # Restart authority and disk store after revocation, without reprovisioning.
        serving.kill()
        serving.wait(timeout=10)
        worker.kill()
        worker.wait(timeout=10)
        courier.kill()
        courier.wait(timeout=10)
        system.authority.kill()
        system.authority.wait(timeout=10)
        system.store.stop()
        system.store.start()
        system.authority = system.start(node, system.config)
        wait_ready(system.store.http, system.authority, system.url + '/health')
        serving = system.start(service, service_config)
        wait_ready(system.store.http, serving, f'http://127.0.0.1:{port}/health')
        assert not any(call({'list': None}, 104, reader_key)['result']['list']['entries'])
        call({'query': dict(sql='SELECT * FROM readable', rows=8, reads=100)}, 104, reader_key, 400)
        assert 'visible' in json.dumps(call({'query': dict(sql='SELECT * FROM readable', rows=8, reads=100)}))
        observations = dict(shared_resource=resource, tables=[100, 101], restricted_reader=104,
                            service_restarts=2, authority_and_disk_restarts=1, credential_rotations=1)
    result = dict(assertions='passed', definition=definition, observations=observations,
                  revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                  dirty=bool(subprocess.check_output(['git', 'diff', '--name-only'], cwd=ROOT, text=True)),
                  binaries={name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in
                            [('node', node), ('cli', cli), ('host', host), ('service', service)]},
                  elapsed_seconds=time.monotonic() - started)
    if report:
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for binary in ('node', 'cli', 'host', 'service'):
        parser.add_argument(binary, type=lambda value: Path(value).resolve(strict=True))
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    run(args.node, args.cli, args.host, args.service, args.report)

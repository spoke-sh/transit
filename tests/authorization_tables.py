"""Original-subject Table service isolation against disk-backed native authority."""
import argparse
import hashlib
from http.client import HTTPConnection
import json
from operation_helpers import operations
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


def run(node, cli, host, service, transit, report=None, serving_example=None, languages=()):
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
        for role, rights in ((owner_role, 20), (reader_role, 4)):
            apply({'grant': {'object': {'kind': 'process', 'id': pid}, 'grantee': role, 'privileges': rights, 'grant_options': 0}})
        # The direct catalog CLI is a privileged native reader. Its explicit
        # realm inspection grant remains separate from raw resource permission;
        # the restricted reader uses only the mediated service and receives neither.
        apply({'grant': {'object': {'kind': 'realm', 'id': 0}, 'grantee': owner_role, 'privileges': 16, 'grant_options': 0}})
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
        configuration = dict(scope=scope, owner=pid, administrator=101, table_limits=dict(record_bytes=2097152, staging_bytes=4194304, staging_records=2), authority=profile, database_name=dict(len=7, bytes=list(b'transit') + [0]*56))
        activation = system.root / 'activation'
        activation.mkdir()
        host_config = system.root / 'catalog.json'
        host_config.write_text(json.dumps(dict(url=system.url, realm=72, principal=20, seed_file=str(worker_key), pid=pid, generation=generation, activation_directory=str(activation), request_timeout_ms=30000, role=dict(catalog=configuration))))
        worker = system.start(host, host_config)
        courier_config = system.root / 'courier.json'
        courier_config.write_text(json.dumps(dict(url=system.url, realm=72, principal=103, seed_file=str(courier_key), request_timeout_ms=30000, role=dict(courier=dict(destinations=[pid])))))
        courier = system.start(host, courier_config)
        # Independent public control encoding; no private record edits.
        control = b'TCA1I' + bytes.fromhex(definition) + struct.pack('<QQQQQIQI', 72, resource, 1, pid, 101, 2097152, 4194304, 2) + struct.pack('<QQQQQQ', *profile.values()) + bytes([7]) + b'transit' + bytes(56)
        frame = b'STN1\1' + bytes(8) + control
        system.available_post('/v1/command', system.signed({'send': {'pid': pid, 'value': frame.hex()}}, 1, 101, owner_key))
        port = free_port()
        service_config = system.root / 'service.json'
        spill_directory = system.root / 'query-spill'
        spill_directory.mkdir(mode=0o700)
        service_config.write_text(json.dumps(dict(upstream=system.url, realm=72, principal=102, seed_file=str(service_key), scope=dict(scope, catalog='1'), owner=pid, port=port, upstream_timeout_ms=30000, spill_directory=str(spill_directory))))
        serving = system.start(service, service_config)
        wait_ready(system.store.http, serving, f'http://127.0.0.1:{port}/health')

        def signed(action, principal=101, key=owner_key, namespace=1):
            connection = dict(scope=dict(scope, catalog='1'), owner=pid, principal=principal, role=None, namespace=namespace)
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

        def call(action, principal=101, key=owner_key, expected=200, namespace=1):
            deadline = time.monotonic() + 30
            while True:
                try:
                    return post(signed(action, principal, key, namespace), expected)
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

        def owner_sequence():
            return system.native_query({'authorization': {'role': None, 'kind': {'identity': {}}}}, 101, owner_key)['principal_sequence'] + 1

        def sql_plan(sql, operation=0, namespace=None):
            return call({'compile_authorization': dict(sql=sql, identity=dict(operation=operation, schema=namespace))})['result']['authorization_plan']

        def schema_outcome(plan):
            request = plan['action']['schema']
            deadline = time.monotonic() + 60
            while True:
                result = call({'schema_status': request})['result']['schema_outcome']
                if result and result['state'] != 'scanning':
                    return result
                assert time.monotonic() < deadline, 'schema operation did not complete'
                time.sleep(.02)

        def execute_schema(sql, operation, namespace=None):
            plan = sql_plan(sql, operation, namespace)
            candidate = call({'schema_plan_prepare': dict(plan=plan, sequence=owner_sequence())})['result']['candidate']['request']
            system.available_post('/v1/command', system.signed(candidate['command'], candidate['sequence'], 101, owner_key))
            return plan, schema_outcome(plan)

        # CLI and service resolve the same SQL to the same stable typed plan.
        catalog_config = system.root / 'catalog-caller.json'
        catalog_config.write_text(json.dumps(dict(version=1, url=system.url, seed_file=str(owner_key),
            request_timeout_ms=30000, connection=dict(scope=dict(scope, catalog='1'), owner=pid, principal=101, role=None, namespace=1))))
        schema_sql = system.root / 'schema.sql'
        schema_sql.write_text('CREATE SCHEMA reporting AUTHORIZATION CURRENT_USER')
        schema_plan_file = system.root / 'schema-plan.json'
        compilation = subprocess.run([operations(), 'catalog', 'compile-authorization', '--config', str(catalog_config),
            '--file', str(schema_sql), '--output', str(schema_plan_file), '--operation', '50', '--schema', '2'],
            capture_output=True, text=True, timeout=30)
        assert compilation.returncode == 0, (compilation.returncode, compilation.stdout, compilation.stderr)
        plan = json.loads(schema_plan_file.read_text())['authorization_plan']
        assert plan == sql_plan(schema_sql.read_text(), 50, 2)
        step_file = system.root / 'schema-step.json'
        prepared = subprocess.run([operations(), 'catalog', 'prepare-schema', '--config', str(catalog_config),
            '--file', str(schema_plan_file), '--output', str(step_file)], capture_output=True, text=True, timeout=30)
        assert prepared.returncode == 0, (prepared.returncode, prepared.stdout, prepared.stderr)
        saved_schema = json.loads(json.loads(prepared.stdout)['prepared'])
        candidate = call({'schema_plan_prepare': dict(plan=plan, sequence=owner_sequence())})['result']['candidate']['request']
        assert saved_schema['signed']['request'] == candidate
        subprocess.run([operations(), 'catalog', 'submit', '--config', str(catalog_config), '--file', str(step_file)],
                       capture_output=True, text=True, check=True, timeout=30)
        assert schema_outcome(plan)['state'] == 'applied'
        first_schema = call({'schema_lookup': 'reporting'})['result']['schema']
        assert first_schema['id'] == 2
        _, renamed = execute_schema('ALTER SCHEMA reporting RENAME TO reports', 51)
        assert renamed['state'] == 'applied'
        assert call({'schema_lookup': 'reporting'})['result']['schema'] is None
        assert call({'schema_lookup': 'reports'})['result']['schema']['authorization'] == first_schema['authorization']
        _, dropped = execute_schema('DROP SCHEMA reports RESTRICT', 52)
        assert dropped['state'] == 'applied'
        assert call({'schema_lookup': 'reports'})['result']['schema'] is None
        _, reused = execute_schema('CREATE SCHEMA reporting', 53, 3)
        assert reused['state'] == 'applied'
        reporting = call({'schema_lookup': 'reporting'})['result']['schema']
        assert reporting['id'] == 3 and reporting['authorization'] != first_schema['authorization']

        def owner_apply(plan):
            action = plan['action']['authorization']
            command = {'authorization': {'begin': dict(expected_revision=plan['expected_revision'], role=owner_role, action=action)}}
            position = system.available_post('/v1/command', system.signed(command, owner_sequence(), 101, owner_key))['position']
            for _ in range(128):
                status = query({'change': position}, 101, owner_key)['body']['change']
                if status['status'] == 'published':
                    return status['created_id']
                command = {'authorization': {('publish' if status['status'] == 'ready' else 'advance'): position}}
                system.available_post('/v1/command', system.signed(command, owner_sequence(), 101, owner_key))
            raise AssertionError('owner authorization staging budget exceeded')

        def execute(sql, operation, object_id=None, namespace=1):
            saved = call({'compile': dict(identity=dict(operation=str(operation), namespace=str(operation + 1000)), create_object=str(object_id) if object_id else None, sql=sql)}, namespace=namespace)['result']['compiled']['saved']
            deadline = time.monotonic() + 180
            while True:
                assert worker.poll() is None and courier.poll() is None
                sequence = owner_sequence()
                step = call({'next': dict(saved=saved, sequence=sequence)}, namespace=namespace)['result']['next']
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

        execute('CREATE TABLE readable (id INT64 PRIMARY KEY, value TEXT)', 1, 100)
        execute('CREATE TABLE private_data (id INT64 PRIMARY KEY, value TEXT)', 2, 101)
        execute("INSERT INTO readable VALUES (1, 'visible')", 3)
        execute("INSERT INTO private_data VALUES (1, 'never-disclose')", 4)
        _, nonempty = execute_schema('DROP SCHEMA public RESTRICT', 54)
        assert nonempty['state'] == 'rejected' and nonempty['reason'] == 'not_empty'
        readable = call({'lookup': 'readable'})['result']['lookup']['authorization']
        private_object = call({'lookup': 'private_data'})['result']['lookup']['authorization']
        assert readable != private_object
        for object_id in (database, schema):
            apply({'grant': {'object': {'kind': 'domain', 'id': object_id}, 'grantee': reader_role, 'privileges': 1, 'grant_options': 0}})
        select_plan = sql_plan('GRANT SELECT ON TABLE public.readable TO reader')
        assert select_plan['action']['authorization'] == {'grant': {'object': {'kind': 'domain', 'id': readable}, 'grantee': reader_role, 'privileges': 1, 'grant_options': 0}}
        grant = owner_apply(select_plan)
        assert call({'schema_lookup': 'reporting'}, 104, reader_key)['result']['schema'] is None
        owner_apply(sql_plan('GRANT USAGE ON SCHEMA reporting TO reader'))
        assert call({'schema_lookup': 'reporting'}, 104, reader_key)['result']['schema']['id'] == 3
        execute('CREATE TABLE before_default (id INTEGER)', 60, 200, namespace=3)
        owner_apply(sql_plan('ALTER DEFAULT PRIVILEGES IN SCHEMA reporting GRANT SELECT ON TABLES TO reader'))
        execute('CREATE TABLE after_default (id INTEGER)', 61, 201, namespace=3)
        assert call({'lookup': 'before_default'}, 104, reader_key, namespace=3)['result']['lookup'] is None
        assert call({'lookup': 'after_default'}, 104, reader_key, namespace=3)['result']['lookup'] is not None
        print('Table authorization: CLI/service SQL agreement, schema rename/reuse, nonempty DROP and future-only default grants passed.', flush=True)
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
        join_sql = 'SELECT r.id FROM readable r JOIN private_data p ON r.id = p.id'
        empty_join_sql = join_sql + ' WHERE p.id = 999'
        for text in (join_sql, empty_join_sql):
            call({'query': dict(sql=text, rows=8, reads=256)}, 104, reader_key, 400)
        private_grant = apply({'grant': {'object': {'kind': 'domain', 'id': private_object},
            'grantee': reader_role, 'privileges': 1, 'grant_options': 0}})
        assert len(call({'query': dict(sql=join_sql, rows=8, reads=256)}, 104, reader_key)['result']['query']['rows']) == 1
        assert call({'query': dict(sql=empty_join_sql, rows=8, reads=256)}, 104, reader_key)['result']['query']['rows'] == []
        aggregate = call({'query': dict(sql='SELECT COUNT(*) FROM readable', rows=8, reads=256)}, 104, reader_key)['result']['query']
        assert aggregate['complete'] and len(aggregate['rows']) == 1
        apply({'revoke': {'id': private_grant, 'privileges': 1, 'grant_option_only': False, 'behavior': 'cascade'}})
        for text in (join_sql, empty_join_sql):
            call({'query': dict(sql=text, rows=8, reads=256)}, 104, reader_key, 400)
        assert list(spill_directory.iterdir()) == [], 'query spill must remain private and unlinked'
        serving_evidence = None
        if serving_example:
            from authorization_serving import run as serving_proof
            execute('CREATE TABLE watchable (id INT64 PRIMARY KEY, value INT64)', 72, 300)
            execute('INSERT INTO watchable VALUES (1, 7)', 73)
            serving_evidence = serving_proof(system, serving_example, apply, query, owner_key,
                reader_role, database, schema, pid, resource, call({'lookup': 'watchable'})['result']['lookup'])
        revision = system.native_query({'resource': resource})['body']['resource']['revision']
        for raw in ({'process': pid}, {'resource': resource}, {'read_access': resource}, {'entries': {'resource': resource, 'revision': revision}},
                    {'open_snapshot': {'resource': resource, 'nonce': list(range(16))}},
                    {'read_entries': {'resource': resource, 'keys': ['0000'] + [None] * 7}}):
            assert system.native_query(raw, 104, reader_key, 403)['err'] == 'AccessDenied'
        forged = signed({'lookup': 'readable'}, 104, reader_key)
        forged['action'] = {'lookup': 'private_data'}
        post(forged, 403)
        forged = signed({'lookup': 'readable'}, 104, reader_key)
        forged['connection']['principal'] = 101
        post(forged, 403)

        mediated_config = system.root / 'mediated-caller.json'
        def configure_reader():
            mediated_config.write_text(json.dumps(dict(version=1, url=system.url,
                table_service_url=f'http://127.0.0.1:{port}', seed_file=str(reader_key), request_timeout_ms=30000,
                connection=dict(scope=dict(scope, catalog='1'), owner=pid, principal=104, role=None, namespace=1))))
        configure_reader()

        def mediated(mode, *args, ok=True):
            result = subprocess.run([operations(), '--structured', 'catalog', mode,
                '--config', str(mediated_config), *map(str, args)], capture_output=True, text=True, timeout=90)
            assert (result.returncode == 0) == ok, (mode, result.returncode, result.stdout, result.stderr)
            return json.loads(result.stdout) if ok else result

        assert mediated('lookup', '--name', 'readable')['definition'] is not None
        assert mediated('lookup', '--name', 'private_data')['definition'] is None
        query_sql = system.root / 'mediated-read.sql'
        query_sql.write_text('SELECT * FROM readable')
        assert len(mediated('query', '--file', query_sql, '--rows', 8, '--reads', 256)['result']['query']['rows']) == 1
        query_sql.write_text(empty_join_sql)
        mediated('query', '--file', query_sql, ok=False)
        # These object writes use an original caller with no process inspection
        # or raw-resource access, including every progress and disposition read.
        write_grant = apply({'grant': {'object': {'kind': 'domain', 'id': readable},
            'grantee': reader_role, 'privileges': 10, 'grant_options': 0}})

        def mediated_write(operation, text):
            sql = system.root / f'mediated-{operation}.sql'
            sql.write_text(text)
            intent = system.root / f'mediated-{operation}-intent.json'
            mediated('compile', '--file', sql, '--operation', operation, '--namespace', operation, '--output', intent)
            deadline = time.monotonic() + 90
            latest = None
            for index in range(256):
                assert time.monotonic() < deadline, 'mediated write deadline'
                step = system.root / f'mediated-{operation}-step-{index}.json'
                result = mediated('next', '--file', intent, '--output', step)
                if 'next' in result and 'terminal' in result['next']:
                    assert result['next']['terminal']['phase'] == 'applied', result
                    assert latest is not None
                    return intent, latest[0], latest[1]
                if 'prepared' not in result:
                    time.sleep(.02)
                    continue
                receipt = mediated('submit', '--file', step)['receipt']
                latest = step, receipt
                assert mediated('receipt', '--file', step)['receipt_status'] == receipt
                while True:
                    progress = mediated('progress', '--file', step, '--intent', intent, '--input', receipt['position'])['progress']
                    if 'processed' in progress:
                        assert progress['processed']['disposition'] is None, progress
                        break
                    assert time.monotonic() < deadline
                    time.sleep(.02)
                assert mediated('observe', '--file', step, '--input', receipt['position'])['observation'] == 'processed'
                assert mediated('disposition', '--file', step, '--input', receipt['position'])['disposition'] is None
                for mode in ('observe', 'disposition'):
                    mediated(mode, '--file', step, '--input', receipt['position'] + 1, ok=False)
            raise AssertionError('mediated write step budget')

        installed = []
        if languages:
            from sdk_catalog import install
            sdk_key, sdk_public = system.key('sdk-writer')
            sdk_login = apply({'create_role': {'name': b'sdk-login'.hex(), 'login': True, 'create_role': False}})
            sdk_role = apply({'create_role': {'name': b'sdk-data'.hex(), 'login': False, 'create_role': False}})
            apply({'bind_credential': {'principal': 105, 'role': sdk_login, 'public_key': sdk_public, 'pid': None}})
            apply({'membership': {'member': sdk_login, 'role': sdk_role, 'inherit': False, 'set': True, 'admin': False}})
            apply({'grant': {'object': {'kind': 'process', 'id': pid}, 'grantee': sdk_role, 'privileges': 4, 'grant_options': 0}})
            apply({'grant': {'object': {'kind': 'domain', 'id': schema}, 'grantee': sdk_role, 'privileges': 3, 'grant_options': 0}})
            sdk_state = system.root / 'sdk-state'
            sdk_state.mkdir(mode=0o700)
            (sdk_state / 'caller.seed').write_bytes(sdk_key.read_bytes())
            (sdk_state / 'caller.seed').chmod(0o600)
            connection = dict(scope=dict(scope, catalog='1'), owner=pid, principal=105, role=sdk_role, namespace=1)
            for index, (language, factory) in enumerate(install(system.root / 'installed-restricted-tables', languages)):
                apply({'grant': {'object': {'kind': 'domain', 'id': database}, 'grantee': sdk_role, 'privileges': 1, 'grant_options': 0}})
                assert system.native_query({'read_access': resource}, 105, sdk_key, 403)['err'] == 'AccessDenied'
                sdk_started = time.monotonic()
                consumer = factory(system.url, connection, sdk_state, table_service_url=f'http://127.0.0.1:{port}')
                try:
                    result = consumer.call({'scenario': {'index': index}})
                    apply({'revoke_privileges': {'object': {'kind': 'domain', 'id': database}, 'grantee': sdk_role, 'privileges': 1, 'behavior': 'cascade'}})
                    assert consumer.call({'denied': {}}) == {'denied': True}
                    installed.append(dict(language=language, result=result, raw_read_denied=True, revoked_connect_denied=True, seconds=round(time.monotonic() - sdk_started, 3)))
                    print(json.dumps(dict(profile='restricted-sdk', **installed[-1])), flush=True)
                finally:
                    consumer.close()

        saved_intent, old_step, old_receipt = mediated_write(70, "INSERT INTO readable VALUES (2, 'mediated')")
        rows = call({'query': dict(sql='SELECT * FROM readable', rows=8, reads=100)}, 104, reader_key)['result']['query']['rows']
        assert len(rows) == 2
        mediated_write(71, 'DELETE FROM readable WHERE id = 2')
        apply({'revoke': {'id': write_grant, 'privileges': 10, 'grant_option_only': False, 'behavior': 'restrict'}})
        # A signed proof cannot survive replacement of its credential epoch.
        previous = signed({'lookup': 'readable'}, 104, reader_key)
        replacement_key, replacement_public = system.key('reader-replacement')
        apply({'rotate_credential': {'principal': 104, 'expected_epoch': previous['proof']['claim']['credential_epoch'], 'public_key': replacement_public}})
        post(previous, 403)
        reader_key = replacement_key
        configure_reader()
        assert mediated('receipt', '--file', old_step)['receipt_status'] == old_receipt
        assert mediated('progress', '--file', old_step, '--intent', saved_intent, '--input', old_receipt['position'])['progress']['processed']['outcome']['phase'] == 'applied'
        assert call({'lookup': 'readable'}, 104, reader_key)['result']['lookup'] is not None
        # The mediation service carries no durable grants or operation authority.
        serving.kill()
        serving.wait(timeout=10)
        serving = system.start(service, service_config)
        wait_ready(system.store.http, serving, f'http://127.0.0.1:{port}/health')
        assert call({'lookup': 'readable'}, 104, reader_key)['result']['lookup'] is not None
        apply({'revoke': {'id': grant, 'privileges': 1, 'grant_option_only': False, 'behavior': 'cascade'}})
        mediated('progress', '--file', old_step, '--intent', saved_intent, '--input', old_receipt['position'], ok=False)
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
        observations = dict(shared_resource=resource, tables=[100, 101, 200, 201] + ([300] if serving_example else []), restricted_reader=104,
                            service_restarts=2, authority_and_disk_restarts=1, credential_rotations=1,
                            schema_lifecycle=True, sql_cli_service_agreement=True, future_only_defaults=True,
                            mediated_cli_write_recovery=True, no_native_process_inspection=True,
                            multisource_queries=True, noncontributing_source_revocation=True, serving=serving_evidence, installed=installed)
    result = dict(assertions='passed', definition=definition, observations=observations,
                  revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                  dirty=bool(subprocess.check_output(['git', 'diff', '--name-only'], cwd=ROOT, text=True)),
                  binaries={name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in
                            [('node', node), ('cli', cli), ('host', host), ('service', service), ('transit', transit)] + ([('serving_example', serving_example)] if serving_example else [])},
                  elapsed_seconds=time.monotonic() - started)
    if report:
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for binary in ('node', 'cli', 'host', 'service', 'transit'):
        parser.add_argument(binary, type=lambda value: Path(value).resolve(strict=True))
    parser.add_argument('--report', type=Path)
    parser.add_argument('--serving-example', type=lambda value: Path(value).resolve(strict=True))
    parser.add_argument('--sdk', action='append', default=[], choices=('node', 'python', 'rust', 'ruby', 'java', 'dotnet', 'erlang', 'elixir', 'c', 'cpp'))
    args = parser.parse_args()
    run(args.node, args.cli, args.host, args.service, args.transit, args.report, args.serving_example, args.sdk)

"""Direct C ABI and native-port callers against the actual disk-backed owner.

The proxy verifies acceptance before corrupting the response. Recovery never
recompiles that write, and both caller loss and node loss precede inspection.
"""
import copy
import json
from pathlib import Path

from catalog.tables.catalog_abi import CONTRACT, Native, Port, check_profiles
from query.unified.unified_abi import Failure, Native as QueryNative, Port as QueryPort


def exercise(library, host, root, authority, service, profile, restart, policy):
    library, host = str(Path(library).resolve()), str(Path(host).resolve())
    definition = CONTRACT['definition']
    connection = dict(scope=dict(profile['catalog']['scope'], catalog=str(profile['catalog']['scope']['catalog'])),
                      branch='1', audience=profile['catalog']['audience'], principal=941002, role=profile['role'])
    (root / 'caller.seed').write_text('7b' * 32)
    (root / 'caller.seed').chmod(0o600)
    check_profiles(host, root, authority, connection)
    for family, offset in (('native', 0), ('port', 10)):
        def open_client():
            if family == 'native':
                return Native(library, authority, connection, seed_byte=123, service_url=service)
            return Port(host, root, authority, connection, service_url=service)

        query_config = dict(definition=definition, catalogs=[connection], service_url=service,
            spill_directory=str(root), options=dict(consistency='independent_table_snapshots',
                resident_bytes='16777216', spill_bytes='16777216', result_bytes='8388608',
                output_rows='1000', work_steps='100000', source_pins=2, requests='100000', spill_work='100000'))
        def open_query_client():
            if family == 'native':
                return QueryNative(library, authority, relational=query_config, seed_byte=123)
            return QueryPort(host, root, authority, relational=query_config)
        query = open_query_client()
        def query_call(action, expected_error=None):
            try:
                value = query.call(dict(relational=action))['relational']
            except Failure as failure:
                if expected_error is None:
                    raise
                assert failure.detail['err'] == expected_error, failure
                assert failure.detail['diagnostic']['outcome'] in ('not_applicable', 'not_submitted'), failure
                return failure.detail
            assert expected_error is None, (expected_error, value)
            return value

        client = open_client()
        name = 'abi_' + family
        object_id = str((1 << 64) - 2 - offset)
        def compile_sql(sql, operation, create_object=None):
            return client.call(dict(compile=dict(namespace=1, operation=str(operation),
                create_object=create_object, sql=sql, dialect='transit', ingestion='point')))['compiled']

        def stage(compiled):
            # The serialized immutable work survives replacement independently
            # of the local session digest returned by load.
            saved = root / f'{family}-{compiled["summary"]["id"]["digest"]}.json'
            saved.write_text(json.dumps(compiled['saved']))
            loaded = client.call(dict(load=json.loads(saved.read_text())))['loaded']
            assert loaded == compiled['summary']
            return client.call(dict(stage=loaded['id']))['staged']

        def operate(reference, command):
            return client.call(dict(operation=dict(reference=reference, command=command, steps=32)))['observation']

        def uncertain(action, operation):
            try:
                client.call(action)
            except Failure as failure:
                assert failure.status == CONTRACT['statuses']['uncertain'], failure
                assert failure.detail['diagnostic']['outcome'] == 'unknown', failure
                assert failure.detail['diagnostic']['identity']['id'] == str(operation), failure
            else:
                raise AssertionError('Accepted corrupted retention reply was reported as success')

        def complete(compiled):
            reference = stage(compiled)
            admitted = client.call(dict(admit=reference))['observation']
            assert 'admitted' in admitted['ddl'], admitted
            state = operate(reference, 'execute')['ddl']
            assert 'committed' in state, state
            return reference, state['committed']

        try:
            caps = client.call(dict(catalog=dict(capabilities={})))['catalog']['capabilities']
            assert caps['definition'] == definition and caps['resident_intents'] == 1
            assert caps['max_action_bytes'] == CONTRACT['limits']['catalog_action_bytes']
            assert caps['max_intent_bytes'] == CONTRACT['limits']['catalog_intent_bytes']
            create = compile_sql(f'CREATE TABLE {name} (id BIGINT PRIMARY KEY, payload BINARY)', offset + 1, object_id)
            _, created = complete(create)
            assert created['binding']['target']['object'] == object_id
            metadata = client.call(dict(lookup=dict(namespace=1, name=name)))['metadata']
            assert metadata['row_count'] == '0'
            columns = {column['name']: column['id'] for column in metadata['schema']['columns']}
            def assignment(column, atom):
                return dict(column=columns[column], value=dict(cell=dict(value=dict(atom=atom))))
            rows = [[assignment('id', dict(signed=str(i))),
                     assignment('payload', dict(binary=(bytes([i]) * 32768).hex()))]
                    for i in range(9)]
            action = dict(prepare=dict(definition=definition, namespace=1, operation=str(offset + 2), name=name,
                          action=dict(mutate=dict(basis=metadata['binding'], ingestion='bulk',
                                      mutation=dict(action=dict(insert=rows), predicate=None)))))
            assert len(json.dumps(action)) > CONTRACT['limits']['handler_action_bytes']
            compiled = client.call(action)['compiled']
            preview = client.call(dict(preview=compiled['summary']['id']))['preview']['rows']
            assert preview['current']['row_count'] == '0'
            assert client.call(dict(lookup=dict(namespace=1, name=name)))['metadata']['row_count'] == '0'
            reference = stage(compiled)
            recovery_path = root / f'{family}-recovery.json'
            recovery_path.write_text(json.dumps(reference))
            original = recovery_path.read_bytes()
            assert 'admitted' in client.call(dict(admit=reference))['observation']['rows']
            try:
                operate(reference, 'execute')
            except Failure as failure:
                assert failure.status == CONTRACT['statuses']['uncertain'], failure
                diagnostic = failure.detail['diagnostic']
                assert diagnostic['outcome'] == 'unknown' and diagnostic['evidence'] == 'saved_intent', diagnostic
                assert diagnostic['identity']['id'] == str(offset + 2), diagnostic
            else:
                raise AssertionError('Accepted corrupted reply was reported as success')
            if family == 'port':
                client.crash()
            else:
                client.close()
            restart()
            client = open_client()
            reference = json.loads(recovery_path.read_bytes())
            recovered = operate(reference, 'inspect')['rows']['committed']
            assert recovered['outcome']['matched'] == '9' and recovered['outcome']['affected'] == '9'
            assert recovered['outcome']['live_rows'] == '9'
            assert operate(reference, 'execute')['rows']['committed'] == recovered
            owner = dict(definition=definition, connection=connection,
                         object=reference['table']['binding']['target'], operation=str(90000 + offset))
            acquisition = dict(owner=owner, expected=recovered['outcome']['position'])
            pin_path = root / f'{family}-pin-acquisition.json'
            pin_path.write_text(json.dumps(acquisition))
            uncertain(dict(retention=dict(acquire=acquisition)), 90000 + offset)
            if family == 'port':
                client.crash()
            else:
                client.close()
            restart()
            client = open_client()
            acquisition = json.loads(pin_path.read_bytes())
            retained = client.call(dict(retention=dict(status=acquisition['owner'])))['retention']['status']
            assert not retained['released'] and retained['snapshot'] is not None
            snapshot = retained['snapshot']
            pin_metadata = client.call(dict(retention=dict(metadata=snapshot)))['retention']['metadata']
            assert pin_metadata['accepted'] == acquisition['expected']
            assert pin_metadata['row_count'] == '9'
            assert pin_metadata['schema']['object'] == object_id
            statement = dict(namespace=1, sql=f'SELECT id FROM {name}', routes=[0])
            explanation = query_call(dict(explain=statement))['explained']
            binding = explanation['sources'][0]['binding']
            assert explanation['sources'][0]['position']['partition'] == acquisition['expected']['partition']
            assert int(explanation['sources'][0]['position']['next_lsn']) >= int(acquisition['expected']['next_lsn'])
            retained_description = copy.deepcopy(explanation)
            retained_description['sources'][0]['position'] = acquisition['expected']
            assert binding['interpretation'] == pin_metadata['interpretation']
            saved_open = dict(id=f'{offset + 1:032x}', statement=statement, bindings=[binding], snapshots=[snapshot])
            (root / f'{family}-relational-open.json').write_text(json.dumps(saved_open))
            opened = query_call(dict(open=saved_open))['opened']
            assert query_call(dict(open=saved_open))['opened'] == opened
            assert opened['description'] == retained_description
            assert opened['cuts'][0]['position'] == acquisition['expected']
            first = query_call(dict(page=dict(reference=opened['reference'], ordinal='0')))['page']
            assert first['row']['cells'][0] == dict(value=dict(atom=dict(signed='0')))
            assert not first['complete_coverage']
            assert query_call(dict(page=dict(reference=opened['reference'], ordinal='0')))['page'] == first
            policy(False)
            try:
                denied = query_call(dict(page=dict(reference=opened['reference'], ordinal='0')), 'AccessDenied')
                assert denied['diagnostic']['category'] == 'access'
                query_call(dict(open=saved_open), 'AccessDenied')
            finally:
                policy(True)
            assert query_call(dict(page=dict(reference=opened['reference'], ordinal='0')))['page'] == first
            # Caller loss expires only the row cursor, never the saved pin.
            query.close()
            query = open_query_client()
            query_call(dict(page=dict(reference=opened['reference'], ordinal='0')), 'InvalidQueryCursor')
            # Loading malformed or foreign saved work must neither replace the
            # valid active work nor submit any operation.
            client.call(dict(load=compiled['saved']))
            for field in ('definition', 'namespace'):
                malformed = copy.deepcopy(compiled['saved'])
                del malformed['table'][field]
                try:
                    client.call(dict(load=malformed))
                except Failure as failure:
                    assert failure.status == CONTRACT['statuses']['invalid_argument'], failure
                    assert failure.detail['diagnostic']['outcome'] == 'not_submitted'
                else:
                    raise AssertionError('Missing saved compatibility or scope was accepted')
            foreign = copy.deepcopy(compiled['saved'])
            foreign['table']['definition'] = '0' * 64
            try:
                client.call(dict(load=foreign))
            except Failure as failure:
                assert failure.status in (1, 10), failure
                assert failure.detail['diagnostic']['outcome'] == 'not_submitted'
            else:
                raise AssertionError('Foreign saved work was accepted')
            client.call(dict(forget=compiled['summary']['id']))
            complete(compile_sql(f'DROP TABLE {name}', offset + 3))
            assert client.call(dict(lookup=dict(namespace=1, name=name)))['metadata'] is None
            complete(compile_sql(f'CREATE TABLE {name} (id BIGINT PRIMARY KEY)', offset + 4, str(int(object_id) - 1)))
            assert operate(reference, 'inspect')['rows']['committed'] == recovered
            assert client.call(dict(retention=dict(metadata=snapshot)))['retention']['metadata'] == pin_metadata
            # A fresh explicit open uses the exact original pin and definition,
            # after both caller replacement and DROP/reuse of its old name.
            saved_open = json.loads((root / f'{family}-relational-open.json').read_text())
            opened = query_call(dict(open=saved_open))['opened']
            assert opened['description'] == retained_description
            for ordinal in range(10):
                page = query_call(dict(page=dict(reference=opened['reference'], ordinal=str(ordinal))))['page']
                assert query_call(dict(page=dict(reference=opened['reference'], ordinal=str(ordinal))))['page'] == page
                assert page['complete_coverage'] == (ordinal == 9)
                if ordinal < 9:
                    assert page['row']['cells'][0] == dict(value=dict(atom=dict(signed=str(ordinal))))
                else:
                    assert page['row'] is None
            policy(False)
            try:
                query_call(dict(page=dict(reference=opened['reference'], ordinal='9')), 'AccessDenied')
            finally:
                policy(True)
            assert query_call(dict(page=dict(reference=opened['reference'], ordinal='9')))['page']['complete_coverage']
            query_call(dict(page=dict(reference=opened['reference'], ordinal='10')), 'InvalidQueryCursor')
            query_call(dict(close=opened['reference']))
            query_call(dict(close=opened['reference']))
            # Local closure does not release durable retention.
            assert not client.call(dict(retention=dict(status=acquisition['owner'])))['retention']['status']['released']
            changed = copy.deepcopy(saved_open)
            changed['id'] = f'{offset + 2:032x}'
            changed['bindings'][0]['interpretation']['interpretation']['digest'] = 'ab' * 32
            query_call(dict(open=changed), 'InvalidQueryRequest')
            changed['bindings'][0]['interpretation']['content']['sha256'] = 'ab' * 32
            query_call(dict(open=changed), 'RelationalSourceChanged')
            uncertain(dict(retention=dict(release=snapshot)), 90000 + offset)
            released = client.call(dict(retention=dict(status=acquisition['owner'])))['retention']['status']
            assert released['released'] and released['retired']
            assert client.call(dict(retention=dict(release=snapshot)))['retention']['released'] == snapshot
            assert recovery_path.read_bytes() == original
        finally:
            query.close()
            client.close()

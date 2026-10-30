"""Serving fixture bootstrap and independent general Table/query declarations.

The metadata commitment comes from authorized catalog discovery. The Python
encoders exercise the public wire contracts without using the Zig encoders.
"""
from runner.paths import ROOT
import hashlib
import json
import os
from pathlib import Path
import struct
import time
from urllib.request import Request, build_opener, ProxyHandler
from catalog.tables.catalog_abi import Port
from query.unified.unified_abi import Failure


def current_definition():
    return bytes.fromhex(json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition'])


def authorize(send, query, action):
    def read(kind):
        return query(0, {'authorization': dict(role=None, kind=kind)})['body']['authorization']
    change = send({'authorization': {'begin': dict(expected_revision=read({'identity': {}})['revision'], role=None, action=action)}})
    for _ in range(128):
        status = read({'change': change})['body']['change']
        if status['status'] == 'published': return status['created_id']
        assert status['status'] in ('ready', 'preparing'), status
        send({'authorization': {'publish' if status['status'] == 'ready' else 'advance': change}})
    raise AssertionError('Serving catalog authorization staging exceeded its bound')


def provision_catalog(realm, resource, audience, key, send, query, readers=()):
    """Fixture provisioning through independent signed native administration."""
    def read(kind, principal=0):
        return query(principal, {'authorization': dict(role=None, kind=kind)})['body']['authorization']
    def apply(action):
        return authorize(send, query, action)
    owner = apply({'create_role': dict(name=b'serving-owner'.hex(), login=True, create_role=False)})
    apply({'bind_credential': dict(principal=33, role=owner, public_key=key.public, pid=None)})
    apply({'grant': dict(object=dict(kind='realm', id=0), grantee=owner, privileges=20, grant_options=0)})
    worker_role = read({'identity': {}}, 78)['body']['identity']['login_role']
    apply({'membership': dict(member=worker_role, role=owner, admin=False, inherit=False, set=True)})
    domains = [apply({'register_domain': dict(registrar=0, actions=mask, lifetime_resource=resource)}) for mask in (1, 3, 15, 31, 31, 7)]
    def binding(kind, identity):
        return list(hashlib.sha256(b'transit.catalog.authorization.binding.v1\0' + current_definition()
            + struct.pack('<QQQBQ', realm, resource, 1, kind, identity)).digest())
    database = apply({'register_object': dict(domain=domains[0], owner=owner, schema=None, binding=binding(1, 0))})
    schema = apply({'register_object': dict(domain=domains[1], owner=owner, schema=dict(kind='domain', id=database), binding=binding(2, 1))})
    for principal in readers:
        role = read({'identity': {}}, principal)['body']['identity']['login_role']
        for target in (database, schema):
            apply({'grant': dict(object=dict(kind='domain', id=target), grantee=role, privileges=1, grant_options=0)})
        apply({'default_grant': dict(creator=owner, schema=dict(kind='domain', id=schema), domain=domains[2], grantee=role, privileges=1, grant_options=0)})
    def name(value):
        return dict(len=len(value), bytes=list(value.encode()) + [0] * (63-len(value)))
    scope = dict(realm=realm, resource=resource, catalog=1)
    catalog = dict(scope=scope, branch=1, partition=1, audience=audience,
        authority=dict(database_domain=domains[0], schema_domain=domains[1], table_domain=domains[2], stream_domain=domains[3], queue_domain=domains[4], kv_domain=domains[5],
            database=database, initial_schema=1, initial_schema_authority=schema),
        database_name=name('serving'), initial_schema_name=name('public'))
    data = dict(definition=current_definition().hex(), scope=scope, branch=1,
        audience=audience, namespace=1, object=1, role=owner)
    return dict(catalog=catalog, data=data)


def bootstrap(host, root, url, data, key):
    """The installer uses the public direct catalog port before activating the app."""
    directory = root / 'counter-installer'
    directory.mkdir()
    seed = directory / 'caller.seed'
    seed.write_bytes(key.seed.read_bytes())
    seed.chmod(0o600)
    connection = dict(scope=dict(data['scope'], catalog=str(data['scope']['catalog'])),
        branch=str(data['branch']), audience=data['audience'], principal=33, role=None)
    # Catalog initialization is an explicit native direct operation. Host SDK
    # sessions inspect/use an installed catalog; opening one never provisions it.
    from interfaces.http.serving import compact, native_query, subject_proof
    http = build_opener(ProxyHandler({}))
    def post(path, value):
        with http.open(Request(url + path, data=compact(value), headers={'Content-Type': 'application/json'}), timeout=15) as response:
            return json.loads(response.read())
    native_connection = dict(scope=data['scope'], branch=data['branch'], audience=data['audience'], principal=33, role=None)
    epoch = post('/v1/query', native_query(key, 33, {'authorization': dict(role=None, kind={'identity': {}})}))['body']['authorization']['body']['identity']['credential_epoch']
    request = dict(definition=current_definition().hex(), connection=native_connection, nonce=list(os.urandom(16)),
        action={'initialize': {}}, delegation=None, closure=None, borrow=None, lease=None, transaction=None)
    context = hashlib.sha256(b'transit.table.direct.request.v1\0' + compact(request)).digest()
    request['proof'] = subject_proof(key, 33, data['audience'], context, credential_epoch=epoch, realm=data['scope']['realm'])
    (directory / 'catalog-initialize.json').write_bytes(compact(request))
    initialized = post('/table/v1', request)
    assert initialized['definition'] == current_definition().hex() and bytes(initialized['context']) == context
    assert initialized['result'] == {'initialized': {}}
    client = Port(host, directory, url, connection)
    try:
        compiled = client.call(dict(compile=dict(namespace=data['namespace'], operation='1', create_object=str(data['object']),
            sql='CREATE TABLE counter (id BIGINT NOT NULL, "count" BIGINT, PRIMARY KEY (id))', dialect='transit', ingestion='point')))['compiled']
        reference = client.call(dict(stage=compiled['summary']['id']))['staged']
        (directory / 'counter-intent.json').write_text(json.dumps(reference))
        client.call(dict(admit=reference))
        for _ in range(128):
            observed = client.call(dict(operation=dict(reference=reference, command='execute', steps=32)))['observation']['ddl']
            if 'committed' in observed: break
            assert 'admitted' in observed, observed
        else: raise AssertionError('Counter declaration did not complete')
        definition = client.call(dict(lookup=dict(namespace=data['namespace'], name='counter')))['metadata']
        assert definition is not None
        return definition
    finally:
        client.close()


def populate_query_rows(host, root, url, data):
    """Prepare the browser's finite dataset through the installed direct owner."""
    directory = root / 'counter-installer'
    connection = dict(scope=dict(data['scope'], catalog=str(data['scope']['catalog'])),
        branch=str(data['branch']), audience=data['audience'], principal=33, role=None)
    client = Port(host, directory, url, connection)
    def call(action):
        deadline = time.monotonic() + 10
        while True:
            try:
                return client.call(action)
            except Failure as failure:
                if (not isinstance(failure.detail, dict) or failure.detail.get('protocol_error') != 'HttpCapacity'
                        or time.monotonic() >= deadline):
                    raise
                # Admission capacity is an attempt, not a new Table operation.
                # Reuse the exact action and saved intent; never recompile a
                # dispatched mutation or allocate a replacement identity.
                time.sleep(.05)
    try:
        values = ','.join(f'({row},1)' for row in range(2, 21))
        compiled = call(dict(compile=dict(namespace=data['namespace'], operation='2', create_object=None,
            sql='INSERT INTO counter (id, "count") VALUES ' + values, dialect='transit', ingestion='bulk')))['compiled']
        saved = directory / 'query-rows-intent.json'
        saved.write_text(json.dumps(compiled['saved']))
        loaded = call(dict(load=json.loads(saved.read_text())))['loaded']
        assert loaded == compiled['summary']
        reference = call(dict(stage=loaded['id']))['staged']
        (directory / 'query-rows-reference.json').write_text(json.dumps(reference))
        call(dict(admit=reference))
        for _ in range(128):
            state = call(dict(operation=dict(reference=reference, command='execute', steps=32)))['observation']['rows']
            if 'committed' in state:
                outcome = state['committed']['outcome']
                assert outcome['matched'] == outcome['affected'] == '19'
                assert outcome['live_rows'] == '20'
                print('Reactive query setup: 19 rows committed through one direct bulk operation.', flush=True)
                return
            assert 'admitted' in state, state
        raise AssertionError('Reactive query setup did not complete')
    finally:
        client.close()


def watch(definition, owner, expected=0, revision=1, published=True):
    source = _native_source(definition, owner)['source']['table']
    scope, interpretation = source['scope'], source['interpretation']['interpretation']
    return (struct.pack('<6QB3Q', expected, revision, owner, scope['resource'], scope['realm'], scope['catalog'],
                source['branch'], source['namespace'], source['object'], interpretation['revision'])
            + bytes(interpretation['digest']) + bytes([published]))


def _native_source(definition, owner):
    binding = definition['binding']
    stored = binding['interpretation']
    interpretation = stored['interpretation']
    target = interpretation['object']
    scope = {name: int(value) for name, value in target['scope'].items()}
    native_target = dict(scope=scope, branch=int(target['branch']), object=int(target['object']))
    native_stored = dict(interpretation=dict(object=native_target, revision=int(interpretation['revision']), digest=list(bytes.fromhex(interpretation['digest']))),
        content=dict(bytes=int(stored['content']['bytes']), sha256=list(bytes.fromhex(stored['content']['sha256']))),
        schema_fingerprint=list(bytes.fromhex(stored['schema_fingerprint'])), retired=stored['retired'])
    fields = [dict(name=c['name'], type=c['type'], nullable=c['nullable'], optional=False) for c in definition['schema']['columns']]
    return dict(version=1, resource=scope['resource'], source={'table': dict(scope=scope, owner=owner,
        branch=native_target['branch'], namespace=binding['namespace'], object=native_target['object'],
        interpretation=native_stored, row_type={'structure': fields})})


def source_value(definition, owner):
    """The public query value uses decimal strings for data identities."""
    value = _native_source(definition, owner)
    source = value['source']['table']
    stored = source['interpretation']
    source['scope']['catalog'] = str(source['scope']['catalog'])
    source['branch'] = str(source['branch'])
    source['object'] = str(source['object'])
    source['interpretation'] = dict(revision=str(stored['interpretation']['revision']),
        digest=stored['interpretation']['digest'], bytes=str(stored['content']['bytes']),
        schema=stored['schema_fingerprint'])
    source['collations'] = [column['collation'] for column in definition['schema']['columns']]
    return value


def query_bytes(definition, owner, limits, *, requester, requests, principal, executor, operation, proof):
    value = _native_source(definition, owner)
    fields = value['source']['table']['row_type']['structure']
    assert fields == [dict(name='id', type={'int64': {}}, nullable=False, optional=False), dict(name='count', type={'int64': {}}, nullable=True, optional=False)], fields
    types = b'transit.fuze.types.v1.2026-09-30'
    descriptor = b'FTY1' + bytes([len(types)]) + types + b'\x16\2\2id\0\1\5count\1\1'
    table_source = value['source']['table']
    scope, stored = table_source['scope'], table_source['interpretation']
    interpretation = stored['interpretation']
    contract = current_definition()
    table = (b'TQS1' + contract + struct.pack('<8Q', scope['realm'], scope['resource'], scope['catalog'], owner,
                table_source['branch'], table_source['namespace'], table_source['object'], interpretation['revision'])
             + bytes(interpretation['digest']) + struct.pack('<Q', stored['content']['bytes'])
             + bytes(stored['schema_fingerprint']) + struct.pack('<H', len(descriptor)) + descriptor + b'\0\0')
    source = b'UQS1' + contract + struct.pack('<QBH', scope['resource'], 2, len(table)) + table
    declaration = hashlib.sha256(b'transit.table.query.declaration.v1\0' + table).digest()
    plan_definition = hashlib.sha256(b'transit.fuze.logical-plan.v1:bound-schema:ordered-predicates:output-names:nullable-parameters:collations').digest()
    plan = b'FQP1' + plan_definition + declaration + hashlib.sha256(descriptor).digest() + b'\0\2\0\1\0\0\0' + struct.pack('<Q', 0) + b'\0\0\0'
    header = b'UQB1' + contract + struct.pack('<HH', len(source), len(plan)) + limits
    description = header + b'\0\0' + source + plan
    purpose = hashlib.sha256(b'transit.query.direct-retention.v1\0' + struct.pack('<4Q', owner, scope['resource'], requester, requests) + description).digest()
    connection = dict(scope=scope, branch=table_source['branch'], audience=owner, principal=principal, role=None)
    expected = {name: int(value) for name, value in definition['position'].items()}
    binding = dict(definition=contract.hex(), connection=connection, executor=executor, interpretation=interpretation,
        expected=expected, selection='current', owner=dict(scope=scope, principal=principal, operation=operation),
        retention='snapshot', purpose=list(purpose))
    grant_context = hashlib.sha256(b'transit.table.read-delegation.v1\0' + json.dumps(binding, separators=(',', ':')).encode()).digest()
    delegated = proof(grant_context)
    grant_claim = delegated['claim']
    assert grant_claim['principal'] == principal and grant_claim['role'] is None
    grant = (b'TRG1' + contract + struct.pack('<6QB4Q', scope['realm'], scope['resource'], scope['catalog'],
        table_source['branch'], owner, principal, 0, 0, executor, table_source['object'], interpretation['revision'])
        + bytes(interpretation['digest']) + struct.pack('<3QBB', expected['partition'], expected['next_lsn'], operation, 0, 2)
        + purpose + struct.pack('<Q', grant_claim['credential_epoch']) + grant_context + bytes(delegated['signature']))
    assert len(grant) == 311
    unsigned = header + b'\0\1' + grant + source + plan
    context = hashlib.sha256(b'transit.query.original-subject.v1\0' + struct.pack('<QQ', requester, requests) + unsigned).digest()
    original = proof(context)
    claim = original['claim']
    assert claim['audience'] == owner and bytes(claim['context']) == context
    authorization = (b'\1' + struct.pack('<QQ', requester, requests) + contract
        + struct.pack('<QQQBQQ', claim['realm'], claim['principal'], claim['credential_epoch'], claim['role'] is not None, claim['role'] or 0, claim['audience'])
        + context + bytes(original['signature']))
    assert len(authorization) == 186
    bundle = header + authorization + b'\1' + grant + source + plan
    return source, declaration, bundle


def query_policy(definition, owner, peer, requests, principal, limits, revision=1, allow=True):
    scope = definition['binding']['connection']['scope']
    # The authenticated requester's committed catalog mapping supplies caller
    # authority; a source digest alone cannot authorize a Table read.
    return (b'UQA1' + current_definition() + struct.pack('<QQQ', peer, requests, revision) + b'\2'
            + struct.pack('<5Q', scope['realm'], scope['resource'], int(scope['catalog']), owner, principal)
            + bytes([allow]) + limits)

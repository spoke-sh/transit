"""Serving fixture bootstrap and independent general Table/query declarations.

The metadata commitment comes from authorized catalog discovery. The Python
encoders exercise the public wire contracts without using the Zig encoders.
"""
import hashlib
import json
from pathlib import Path
import struct
import time

from catalog_helpers import Cli

TABLE_LIMITS = dict(record_bytes=4096, staging_bytes=32768, staging_records=8)


def current_definition():
    return bytes.fromhex(json.loads((Path(__file__).resolve().parents[1] / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition'])


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


def provision_catalog(realm, resource, key, send, query, readers=()):
    """Fixture provisioning through independent signed native administration."""
    def read(kind, principal=0):
        return query(principal, {'authorization': dict(role=None, kind=kind)})['body']['authorization']
    def apply(action):
        return authorize(send, query, action)
    owner = apply({'create_role': dict(name=b'serving-owner'.hex(), login=True, create_role=False)})
    apply({'bind_credential': dict(principal=33, role=owner, public_key=key.public, pid=None)})
    apply({'grant': dict(object=dict(kind='realm', id=0), grantee=owner, privileges=20, grant_options=0)})
    domains = [apply({'register_domain': dict(registrar=78, actions=mask)}) for mask in (1, 3, 15)]
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
    return dict(authority=dict(database_domain=domains[0], schema_domain=domains[1], table_domain=domains[2],
        database=database, initial_schema=1, initial_schema_authority=schema),
        database_name=dict(len=7, bytes=list(b'serving') + [0]*56))


def bootstrap(cli, root, url, realm, owner, resource, key, cast, drained, query, sequences, readers=()):
    client = Cli(cli, root, url, dict(scope=dict(realm=realm, resource=resource, catalog='1'), owner=owner, principal=33))
    config = json.loads(client.config.read_text())
    config['seed_file'] = str(key.seed)
    client.config.write_text(json.dumps(config))
    cast(owner, b'create-counter')
    until = time.monotonic() + 90
    while True:
        definition = client.call({'lookup': 'counter'})['definition']
        if definition is not None: break
        state = query(0, {'process': owner})['body']['process']
        assert state['process']['failure'] is None and time.monotonic() < until, 'counter Table not published'
        time.sleep(.03)
    sequences[33] = query(33, {'identity': {}})['principal_sequence']
    drained(owner)
    client.close()
    return definition


def watch(definition, owner, expected=0, revision=1, published=True):
    metadata = definition['metadata']
    scope = metadata['scope']
    spec = metadata['commitment']
    return (struct.pack('<8QI', expected, revision, owner, scope['resource'], scope['realm'], int(scope['catalog']), int(metadata['object']), int(metadata['revision']), spec['length'])
            + bytes(spec['digest']) + bytes([published]))


def source_value(definition, owner):
    metadata = definition['metadata']
    fields = [dict(name=c['name'], type=c['type'], nullable=c['nullable'], optional=False) for c in definition['schema']['columns']]
    return dict(version=1, resource=metadata['scope']['resource'], source={'table': dict(scope=metadata['scope'], owner=owner, object=metadata['object'], metadata=dict(id=metadata['revision'], spec=metadata['commitment']), row_type={'structure': fields})})


def query_bytes(definition, owner, limits, *, requester, requests, proof):
    value = source_value(definition, owner)
    fields = value['source']['table']['row_type']['structure']
    assert fields == [dict(name='id', type={'int64': {}}, nullable=False, optional=False), dict(name='count', type={'int64': {}}, nullable=True, optional=False)], fields
    types = b'transit.fuze.types.v1.2026-09-30'
    descriptor = b'FTY1' + bytes([len(types)]) + types + b'\x16\2\2id\0\1\5count\1\1'
    metadata = definition['metadata']
    scope, spec = metadata['scope'], metadata['commitment']
    contract = current_definition()
    table = (b'TQS1' + contract + struct.pack('<QQQQQQII', scope['realm'], scope['resource'], int(scope['catalog']), owner, int(metadata['object']), int(metadata['revision']), spec['format'], spec['length'])
             + bytes(spec['digest']) + struct.pack('<H', len(descriptor)) + descriptor)
    source = b'UQS1' + contract + struct.pack('<QBH', scope['resource'], 2, len(table)) + table
    declaration = hashlib.sha256(b'transit.table.query.declaration.v1\0' + table).digest()
    plan_definition = hashlib.sha256(b'transit.fuze.logical-plan.v1:bound-schema:ordered-predicates:output-names:nullable-parameters').digest()
    plan = b'FQP1' + plan_definition + declaration + hashlib.sha256(descriptor).digest() + b'\0\2\0\1\0\0\0' + struct.pack('<Q', 0) + b'\0'
    header = b'UQB1' + contract + struct.pack('<HH', len(source), len(plan)) + limits
    unsigned = header + b'\0' + source + plan
    context = hashlib.sha256(b'transit.query.original-subject.v1\0' + struct.pack('<QQ', requester, requests) + unsigned).digest()
    original = proof(context)
    claim = original['claim']
    assert claim['audience'] == owner and bytes(claim['context']) == context
    authorization = (b'\1' + struct.pack('<QQ', requester, requests) + contract
        + struct.pack('<QQQBQQ', claim['realm'], claim['principal'], claim['credential_epoch'], claim['role'] is not None, claim['role'] or 0, claim['audience'])
        + context + bytes(original['signature']))
    assert len(authorization) == 186
    bundle = header + authorization + source + plan
    return source, declaration, bundle


def query_policy(definition, owner, peer, requests, principal, limits, revision=1, allow=True):
    scope = definition['metadata']['scope']
    # The authenticated requester's committed catalog mapping supplies caller
    # authority; a source digest alone cannot authorize a Table read.
    return (b'UQA1' + current_definition() + struct.pack('<QQQ', peer, requests, revision) + b'\2'
            + struct.pack('<5Q', scope['realm'], scope['resource'], int(scope['catalog']), owner, principal)
            + bytes([allow]) + limits)

"""Restricted watch callers against real serving workers and native authority.

The fixture provisions a direct Table, then exercises the same caller through
HTTP snapshots, SSE and WebSocket. All provisioning uses public operations.
"""
import copy
import argparse
import hashlib
import json
import os
import struct
import time
from pathlib import Path
from urllib.request import Request

from reactive import SSE, WebSocket
from serving import post, Key, compact, subject_proof
from serving_table import watch
from harness.services import free_port, wait_ready


def run(system, executable, apply, query, owner_key, reader_role, database, schema,
        source_pid, source_resource, declaration):
    principal, worker_principal, gateway_principal = 107, 105, 106
    caller_key, caller_public = system.key('watch-caller')
    worker_key, worker_public = system.key('watch-worker')
    gateway_key, gateway_public = system.key('watch-gateway')
    role = apply({'create_role': dict(name=b'watch-reader'.hex(), login=True, create_role=False)})
    apply({'bind_credential': dict(principal=principal, role=role, public_key=caller_public, pid=None)})
    selected = apply({'create_role': dict(name=b'watch-select'.hex(), login=False, create_role=False)})
    membership = apply({'membership': dict(member=role, role=selected, admin=False, inherit=False, set=True)})
    ingress = system.command({'spawn': {}})
    resource = system.command({'create_resource': {'writer': ingress}})
    system.command({'grant_resource': dict(resource=resource, subject=0, permissions=7)})
    system.command({'associate': dict(pid=ingress, name=b'state'.hex(), resource=resource)})
    system.command({'grant': dict(subject=worker_principal, public_key=worker_public, permissions=88, pid=ingress)})
    system.command({'grant_resource': dict(resource=resource, subject=worker_principal, permissions=7)})
    system.command({'grant': dict(subject=gateway_principal, public_key=gateway_public, permissions=16, pid=None)})
    for target in (resource, source_resource):
        system.command({'grant_resource': dict(resource=target, subject=gateway_principal, permissions=3)})
    generation = system.native_query({'process': ingress})['body']['process']['process']['generation']
    system.command({'own': dict(pid=ingress, expected_generation=generation, worker=worker_principal)})
    owner_role = query({'identity': {}}, 101, owner_key)['body']['identity']['login_role']
    for target_role in (selected, owner_role):
        apply({'grant': dict(object=dict(kind='process', id=ingress), grantee=target_role, privileges=4, grant_options=0)})
    for target in (database, schema):
        apply({'grant': dict(object=dict(kind='domain', id=target), grantee=selected, privileges=1, grant_options=0)})
    select = apply({'grant': dict(object=dict(kind='domain', id=declaration['authorization']), grantee=selected, privileges=1, grant_options=0)})
    # The gateway's own direct-read grant supplies bytes. The separate original
    # watch subject still needs its current selected-role grant for disclosure.
    gateway_role = query({'identity': {}}, gateway_principal, gateway_key)['body']['identity']['login_role']
    for target in (database, schema, declaration['authorization']):
        apply({'grant': dict(object=dict(kind='domain', id=target), grantee=gateway_role, privileges=1, grant_options=0)})
    activation = system.root / 'watch-activation'
    activation.mkdir()
    worker_config = system.root / 'watch-worker.json'
    worker_config.write_text(json.dumps(dict(url=system.url, realm=72, principal=worker_principal,
        seed_file=str(worker_key), pid=ingress, generation=generation+1,
        activation_directory=str(activation), request_timeout_ms=30000,
        role=dict(ingress=dict(service=1, administrator=101, observer=101)))))
    worker = system.start(executable, worker_config)

    def drain():
        until = time.monotonic()+30
        while True:
            state = system.native_query({'process': ingress})['body']['process']
            assert worker.poll() is None and state['process']['failure'] is None, state
            if state['input'] is None: return
            assert time.monotonic() < until, state
            time.sleep(.02)

    def cast(payload):
        sequence = system.native_query({'authorization': dict(role=None, kind={'identity': {}})}, 101, owner_key)['principal_sequence']+1
        frame = b'STN1\1'+bytes(8)+payload
        receipt = system.available_post('/v1/command', system.signed({'send': dict(pid=ingress, value=frame.hex())}, sequence, 101, owner_key))
        drain()
        return receipt['position']

    cast(b'SV1c\0')
    now = int(time.time()*1000)
    cast(b'SV1c\1'+struct.pack('<QQQHBQ?', 0, 1, source_pid, 1, 2, now+600000, True))
    cast(b'SV1c\2'+struct.pack('<QQQ??B', principal, 0, 1, True, True, 1))
    cast(b'SV1c\5\0'+watch(declaration, source_pid))
    cast(b'SV1c\5\1'+struct.pack('<Q', now))
    port = free_port()
    hostname = 'authorization.example.test'
    gateway_config = system.root / 'watch-gateway.json'
    config = dict(url=system.url, realm=72, principal=gateway_principal, seed_file=str(gateway_key),
        request_timeout_ms=30000, role=dict(gateway=dict(service=1, ingress=ingress, resource=resource,
        port=port, host=hostname, public_origin='http://'+hostname, development_allow_insecure_http=True,
        callers=[dict(principal=principal, public_key=caller_public)], reactive=True,
        viewer=dict(principal=principal, seed_file=str(caller_key), snapshot_values=True, role=selected),
        options=dict(request_timeout_ms=30000))))

    def start_gateway():
        gateway_config.write_text(json.dumps(config))
        process = system.start(executable, gateway_config)
        wait_ready(system.store.http, process, Request(f'http://127.0.0.1:{port}/health', headers={'Host': hostname}))
        return process

    gateway = start_gateway()
    def client(action, expected=200):
        return post(port, '/reactive/v1/client', action, hostname, expected, {'Origin': 'http://'+hostname})

    def control(command):
        prepared = client({'prepare': command})['prepared']
        receipt = client({'submit': prepared})['receipt']['receipt']
        drain()
        assert client({'observe': prepared})['observation'] == {'committed': {}}
        return prepared, receipt['position']

    now = int(time.time()*1000)
    cast(b'SV1c\5\1'+struct.pack('<Q', now))
    lease = now+28000
    opened, generation = control({'open': dict(session=1, source_revision=1, lease_before_ms=lease)})
    identity = dict(session=1, generation=generation)
    nonce = list(os.urandom(16))
    control({'attach': dict(identity=identity, expected=0, nonce=nonce)})
    _, subscription_generation = control({'subscribe': dict(identity=identity, expected=0, subscription=1, operation=0)})
    scope = dict(realm=72, principal=principal, service=1, ingress=ingress, session=1,
                 generation=generation, subscription=1, subscription_generation=subscription_generation)
    read = dict(scope=scope, kind='snapshot', attachment=1, nonce=nonce, cursor=None)

    lease_renewals = []

    def maintain(stage):
        nonlocal lease
        started = time.monotonic()
        now = int(time.time()*1000)
        cast(b'SV1c\5\1'+struct.pack('<Q', now))
        previous, lease = lease, now+28000
        control({'renew': dict(identity=identity, expected=previous, lease_before_ms=lease)})
        remaining = lease-int(time.time()*1000)
        assert remaining > 0, ('lease elapsed during renewal', stage, remaining)
        lease_renewals.append(dict(stage=stage, seconds=round(time.monotonic()-started, 3), remaining_ms=remaining))

    def signed_read():
        return client({'sign_read': read})['signed_read']

    def snapshot(signed, expected=200):
        return post(port, '/reactive/v1/read', signed, hostname, expected)

    def open_stream(websocket=False):
        session_read = dict(read, kind='session', attachment=0, nonce=[0]*16)
        session_read['scope'] = dict(scope, subscription=0, subscription_generation=0)
        proof = client({'sign_read': session_read})['signed_read']
        peer = WebSocket(port, hostname, {}, headers={'Origin': 'http://'+hostname}, timeout=30) if websocket else None
        challenge = peer.until('challenge') if peer else post(port, '/reactive/v1/challenge', proof, hostname)['challenge']
        attach = client({'prepare': {'attach': dict(identity=identity, expected=read['attachment'], nonce=challenge['nonce'])}})['prepared']
        read['attachment'] += 1
        read['nonce'] = challenge['nonce']
        events = client({'sign_read': dict(read, kind='events')})['signed_read']
        bootstrap = dict(version=1, attach=attach, read=events)
        if peer:
            peer.send({'attach': bootstrap})
        else:
            peer = SSE(port, hostname, {}, bootstrap, origin='http://'+hostname, timeout=30)
        assert peer.until('attached')['attachment'] == read['attachment']
        assert peer.until('event')['event']['source_changed']
        return peer

    current = signed_read()
    assert current['proof']['claim']['role'] == selected
    started = time.monotonic()
    result = snapshot(current)
    snapshot_seconds = time.monotonic()-started
    resident_bytes = int(next(line.split()[1] for line in Path(f'/proc/{gateway.pid}/status').read_text().splitlines() if line.startswith('VmRSS:')))*1024
    assert result['snapshot']['rows'][0] == dict(key='1', value='7'), result
    assert not result['snapshot']['more']
    print(f'Serving authorization: restricted snapshot passed in {snapshot_seconds:.3f} s.', flush=True)
    for kind in ({'process': ingress}, {'resource': resource}, {'resource': source_resource},
                 {'read_access': source_resource}, {'open_snapshot': dict(resource=source_resource, nonce=list(range(16)))}):
        assert system.native_query(kind, principal, caller_key, 403)['err'] in ('AccessDenied', 'Forbidden')
    forged = copy.deepcopy(current)
    forged['proof']['claim']['role'] = reader_role
    snapshot(forged, 403)
    missing = copy.deepcopy(current)
    del missing['proof']['claim']['definition']
    snapshot(missing, 400)
    maintain('before_credential_rotation')
    replacement_key, replacement_public = system.key('watch-replacement')
    apply({'rotate_credential': dict(principal=principal,
        expected_epoch=current['proof']['claim']['credential_epoch'], public_key=replacement_public)})
    snapshot(current, 403)
    gateway.kill(); gateway.wait(timeout=10)
    config['role']['gateway']['callers'][0]['public_key'] = replacement_public
    config['role']['gateway']['viewer']['seed_file'] = str(replacement_key)
    gateway = start_gateway()
    maintain('after_credential_rotation')
    assert client({'observe': opened})['observation'] == {'committed': {}}
    snapshot(signed_read())
    maintain('before_sse')
    stream = open_stream()
    retained = signed_read()
    maintain('before_membership_revocation')
    apply({'revoke_membership': dict(id=membership, option='set', behavior='restrict')})
    terminal = stream.until('terminal')
    assert terminal['reason'] == 'denied', terminal
    stream.close()
    snapshot(retained, 403)
    client({'sign_read': read}, 403)
    apply({'membership': dict(member=role, role=selected, admin=False, inherit=False, set=True)})
    maintain('after_membership_restoration')
    snapshot(signed_read())
    stream = open_stream(websocket=True)
    maintain('before_select_revocation')
    apply({'revoke': dict(id=select, privileges=1, grant_option_only=False, behavior='cascade')})
    terminal = stream.until('terminal')
    assert terminal['reason'] == 'denied', terminal
    stream.close()
    # Renewal is an independent control. Keep the session live so the next
    # assertion distinguishes current SELECT denial from lease expiry.
    maintain('before_revoked_snapshot')
    snapshot(signed_read(), 403)
    gateway.kill(); gateway.wait(timeout=10)
    gateway = start_gateway()
    maintain('after_gateway_restart')
    snapshot(signed_read(), 403)
    # Session inspection remains an independent service-policy operation.
    session_read = dict(read, kind='session', attachment=0, nonce=[0]*16)
    session_read['scope'] = dict(scope, subscription=0, subscription_generation=0)
    status = post(port, '/reactive/v1/read', client({'sign_read': session_read})['signed_read'], hostname)
    assert status['session']['generation'] == generation
    assert status['source'] is None, status
    worker.kill(); worker.wait(timeout=10)
    print('Serving authorization: private snapshots, no native inspection, proof tampering, credential rotation, exact control recovery, revoke and gateway restart passed.', flush=True)
    return dict(principal=principal, raw_access_denied=True, credential_rotation=True,
                exact_control_recovery=True, source_revocation=True, sse_revocation=True, websocket_revocation=True, selected_role=selected, membership_revocation=True,
                snapshot_seconds=snapshot_seconds, gateway_resident_bytes=resident_bytes, gateway_restarts=2,
                lease_renewals=lease_renewals)


def main():
    from inspection import System
    from catalog_abi import Port
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('node', 'admin', 'host', 'serving'):
        parser.add_argument(name, type=lambda value: Path(value).resolve(strict=True))
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    report = dict(completed=False, profile='direct-table/native-local', observations=None)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + '\n')
    with System(args.node, args.admin, clock_error_ms=10000, request_timeout_ms=30000, local=True) as system:
        definition = system.native_query({'capabilities': {}})['definition']

        def query(kind, principal=0, seed=None):
            return system.native_query({'authorization': dict(role=None, kind=kind)}, principal, seed)['body']['authorization']

        def apply(action):
            change = system.command({'authorization': {'begin': dict(expected_revision=query({'identity': {}})['revision'], role=None, action=action)}})
            for _ in range(128):
                status = query({'change': change})['body']['change']
                if status['status'] == 'published': return status['created_id']
                assert status['status'] in ('ready', 'preparing'), status
                system.command({'authorization': {'publish' if status['status'] == 'ready' else 'advance': change}})
            raise AssertionError('Authorization staging exceeded its bound')

        owner = Key(system.root, 'table-owner', 121)
        owner_role = apply({'create_role': dict(name=b'table-owner'.hex(), login=True, create_role=False)})
        apply({'bind_credential': dict(principal=101, role=owner_role, public_key=owner.public, pid=None)})
        reader_role = apply({'create_role': dict(name=b'unselected-reader'.hex(), login=False, create_role=False)})
        source = system.command({'spawn': {}})
        resource = system.command({'create_resource': dict(writer=source)})
        system.command({'grant_resource': dict(resource=resource, subject=0, permissions=7)})
        domains = [apply({'register_domain': dict(registrar=0, actions=mask, lifetime_resource=resource)}) for mask in (1, 3, 15)]
        scope = dict(realm=72, resource=resource, catalog=1)

        def binding(kind, identity):
            return list(hashlib.sha256(b'transit.catalog.authorization.binding.v1\0' + bytes.fromhex(definition)
                + struct.pack('<QQQBQ', 72, resource, 1, kind, identity)).digest())

        database = apply({'register_object': dict(domain=domains[0], owner=owner_role, schema=None, binding=binding(1, 0))})
        schema = apply({'register_object': dict(domain=domains[1], owner=owner_role, schema=dict(kind='domain', id=database), binding=binding(2, 1))})
        def name(text):
            return dict(len=len(text), bytes=list(text.encode()) + [0] * (63-len(text)))
        catalog = dict(scope=scope, branch=1, partition=1, audience=source,
            authority=dict(database_domain=domains[0], schema_domain=domains[1], table_domain=domains[2],
                database=database, initial_schema=1, initial_schema_authority=schema),
            database_name=name('serving'), initial_schema_name=name('public'))
        settings = json.loads(system.config.read_text())
        settings['table'] = dict(catalog=catalog, registrar=dict(principal=0, seed_file=str(system.seed)))
        system.authority.terminate(); system.authority.wait(timeout=15)
        system.config.write_text(json.dumps(settings))
        system.authority = system.start(args.node, system.config)
        wait_ready(system.store.http, system.authority, system.url + '/health')
        connection = dict(scope=scope, branch=1, audience=source, principal=101, role=None)
        request = dict(definition=definition, connection=connection, nonce=list(os.urandom(16)),
            action={'initialize': {}}, delegation=None, closure=None, borrow=None)
        context = hashlib.sha256(b'transit.table.direct.request.v1\0' + compact(request)).digest()
        epoch = query({'identity': {}}, 101, owner.seed)['body']['identity']['credential_epoch']
        request['proof'] = subject_proof(owner, 101, source, context, credential_epoch=epoch, realm=72)
        assert system.available_post('/table/v1', request)['result'] == {'initialized': {}}
        directory = system.root / 'direct-caller'
        directory.mkdir()
        (directory / 'caller.seed').write_bytes(owner.seed.read_bytes())
        (directory / 'caller.seed').chmod(0o600)
        caller = Port(args.host, directory, system.url, dict(connection, scope=dict(scope, catalog='1'), branch='1'))
        try:
            for operation, sql, create_object, kind in (
                    ('1', 'CREATE TABLE watchable (id BIGINT PRIMARY KEY, value BIGINT)', '300', 'ddl'),
                    ('2', 'INSERT INTO watchable VALUES (1, 7)', None, 'rows')):
                compiled = caller.call(dict(compile=dict(namespace=1, operation=operation, create_object=create_object,
                    sql=sql, dialect='transit', ingestion='point')))['compiled']
                reference = caller.call(dict(stage=compiled['summary']['id']))['staged']
                (directory / (operation + '-intent.json')).write_text(json.dumps(compiled['saved']))
                caller.call(dict(admit=reference))
                for _ in range(128):
                    state = caller.call(dict(operation=dict(reference=reference, command='execute', steps=32)))['observation'][kind]
                    if 'committed' in state: break
                    assert 'admitted' in state, state
                else: raise AssertionError('Direct Table operation exceeded its bound')
            declaration = caller.call(dict(lookup=dict(namespace=1, name='watchable')))['metadata']
            # Registration used the configured root registrar's native sequence.
            # All prior admin operations are settled; begin the next one from
            # the currently observed principal sequence.
            system.sequence = system.native_query({'identity': {}})['principal_sequence']
            report['observations'] = run(system, args.serving, apply, query, owner.seed, reader_role,
                database, schema, source, resource, declaration)
        finally:
            caller.close()
    report['completed'] = True
    args.report.write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()

"""Restricted watch callers against real serving workers and native authority.

Invoked by authorization_tables after its catalog/data setup. All provisioning
uses signed public operations; no stored records are synthesized or edited.
"""
import copy
import json
import os
import struct
import time
from pathlib import Path
from urllib.request import Request

from reactive import SSE, WebSocket
from serving import post
from serving_table import watch
from storage import free_port, wait_ready


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
        sequence = system.native_query({'identity': {}}, 101, owner_key)['principal_sequence']+1
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

    def maintain():
        nonlocal lease
        now = int(time.time()*1000)
        cast(b'SV1c\5\1'+struct.pack('<Q', now))
        previous, lease = lease, now+28000
        control({'renew': dict(identity=identity, expected=previous, lease_before_ms=lease)})

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
    replacement_key, replacement_public = system.key('watch-replacement')
    apply({'rotate_credential': dict(principal=principal,
        expected_epoch=current['proof']['claim']['credential_epoch'], public_key=replacement_public)})
    snapshot(current, 403)
    gateway.kill(); gateway.wait(timeout=10)
    config['role']['gateway']['callers'][0]['public_key'] = replacement_public
    config['role']['gateway']['viewer']['seed_file'] = str(replacement_key)
    gateway = start_gateway()
    maintain()
    assert client({'observe': opened})['observation'] == {'committed': {}}
    snapshot(signed_read())
    maintain()
    stream = open_stream()
    retained = signed_read()
    apply({'revoke_membership': dict(id=membership, option='set', behavior='restrict')})
    terminal = stream.until('terminal')
    assert terminal['reason'] == 'denied', terminal
    stream.close()
    snapshot(retained, 403)
    client({'sign_read': read}, 403)
    apply({'membership': dict(member=role, role=selected, admin=False, inherit=False, set=True)})
    maintain()
    snapshot(signed_read())
    stream = open_stream(websocket=True)
    apply({'revoke': dict(id=select, privileges=1, grant_option_only=False, behavior='cascade')})
    terminal = stream.until('terminal')
    assert terminal['reason'] == 'denied', terminal
    stream.close()
    snapshot(signed_read(), 403)
    gateway.kill(); gateway.wait(timeout=10)
    gateway = start_gateway()
    maintain()
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
                snapshot_seconds=snapshot_seconds, gateway_resident_bytes=resident_bytes, gateway_restarts=2)
